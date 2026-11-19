package routes

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"gpe/telegram"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
)

// fakeAlertSender records what the workers try to send.
type fakeAlertSender struct {
	mu       sync.Mutex
	chats    []int64
	messages []string
	pins     int
	failMsg  bool
}

func (f *fakeAlertSender) SendMessage(chatID int64, text string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.chats = append(f.chats, chatID)
	f.messages = append(f.messages, text)
	if f.failMsg {
		return errors.New("telegram indisponible")
	}
	return nil
}

func (f *fakeAlertSender) SendLocation(int64, float64, float64) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.pins++
	return nil
}

func (f *fakeAlertSender) FetchAudio(string) (*telegram.AudioFile, error) { return nil, nil }
func (f *fakeAlertSender) SendAudioFile(int64, *telegram.AudioFile, string) error {
	return nil
}

// TestBuildAlertNotification_QueuesLinkedContacts: linked contacts are reported
// as queued, unlinked ones as not_linked, and only linked ones become recipients.
func TestBuildAlertNotification_QueuesLinkedContacts(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	defer db.Close()

	mock.ExpectQuery(`SELECT c.contact_id, c.contact_name, c.telegram_chat_id`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "contact_name", "telegram_chat_id"}).
			AddRow(4, "Maman", int64(444)).
			AddRow(5, "Papa", nil))

	job, results, err := buildAlertNotification(db, 1, "<b>Jean</b>", 7, alertNotifyOpts{Trigger: "sos"})
	if err != nil {
		t.Fatalf("erreur inattendue: %s", err)
	}
	if len(results) != 2 {
		t.Fatalf("2 résultats attendus, obtenus: %d", len(results))
	}
	if results[0].Status != "queued" || results[0].Channel != "telegram" {
		t.Errorf("contact lié attendu en queued, obtenu: %+v", results[0])
	}
	if results[1].Status != "not_linked" {
		t.Errorf("contact non lié attendu en not_linked, obtenu: %+v", results[1])
	}
	if len(job.recipients) != 1 || job.recipients[0].chatID != 444 {
		t.Errorf("destinataires inattendus: %+v", job.recipients)
	}
	if strings.Contains(job.message, "<b>Jean</b>") || !strings.Contains(job.message, "&lt;b&gt;Jean") {
		t.Errorf("le nom doit être échappé, message: %s", job.message)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("attentes SQL non respectées: %s", err)
	}
}

// TestBuildAlertNotification_WithPin: valid coordinates become a native map pin.
func TestBuildAlertNotification_WithPin(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	defer db.Close()

	mock.ExpectQuery(`SELECT c.contact_id, c.contact_name, c.telegram_chat_id`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "contact_name", "telegram_chat_id"}))

	lat, lng := 48.8566, 2.3522
	job, _, err := buildAlertNotification(db, 1, "Jean", 7, alertNotifyOpts{Latitude: &lat, Longitude: &lng})
	if err != nil {
		t.Fatalf("erreur inattendue: %s", err)
	}
	if job.pin == nil || job.pin.lat != lat || job.pin.lng != lng {
		t.Errorf("pin inattendu: %+v", job.pin)
	}
}

// TestAlertJob_DeliverSendsMessageAndPin: the worker sends the text then the pin.
func TestAlertJob_DeliverSendsMessageAndPin(t *testing.T) {
	sender := &fakeAlertSender{}
	n := &Notifier{sender: sender, attempts: 1}

	alertJob{
		alertID: 7,
		message: "urgence",
		pin:     &geoPoint{lat: 48.85, lng: 2.35},
		recipients: []alertRecipient{
			{contactID: 4, name: "Maman", chatID: 444},
		},
	}.deliver(n)

	if len(sender.chats) != 1 || sender.chats[0] != 444 {
		t.Errorf("envois inattendus: %v", sender.chats)
	}
	if sender.pins != 1 {
		t.Errorf("1 pin attendu, obtenu: %d", sender.pins)
	}
}

// TestAlertJob_SkipsPinWhenMessageFails: a failed message must not send the pin.
func TestAlertJob_SkipsPinWhenMessageFails(t *testing.T) {
	sender := &fakeAlertSender{failMsg: true}
	n := &Notifier{sender: sender, attempts: 1}

	alertJob{
		alertID:    7,
		message:    "urgence",
		pin:        &geoPoint{lat: 48.85, lng: 2.35},
		recipients: []alertRecipient{{contactID: 4, name: "Maman", chatID: 444}},
	}.deliver(n)

	if sender.pins != 0 {
		t.Errorf("aucun pin attendu après un échec d'envoi, obtenu: %d", sender.pins)
	}
}

// TestMarkUndelivered: queued entries become errors when scheduling fails,
// while not_linked entries stay untouched.
func TestMarkUndelivered(t *testing.T) {
	results := []NotifyResult{
		{ContactID: 4, Status: "queued", Channel: "telegram"},
		{ContactID: 5, Status: "not_linked"},
	}

	got := markUndelivered(results, "telegram non configuré")

	if got[0].Status != "error" || got[0].Error != "telegram non configuré" {
		t.Errorf("contact en attente non marqué en erreur: %+v", got[0])
	}
	if got[1].Status != "not_linked" {
		t.Errorf("not_linked ne doit pas changer: %+v", got[1])
	}
}

// TestCreateAlert_QueuesNotifications: the handler returns 201 without calling
// Telegram, reports the linked contact as queued, and leaves the delivery to the
// worker queue.
func TestCreateAlert_QueuesNotifications(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	defer db.Close()

	mock.ExpectQuery(`SELECT config_id FROM users WHERE user_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"config_id"}).AddRow(2))
	mock.ExpectBegin()
	mock.ExpectExec(`^INSERT INTO alerts \(user_id, config_id\) VALUES \(\?, \?\)$`).
		WithArgs(1, 2).
		WillReturnResult(sqlmock.NewResult(7, 1))
	mock.ExpectCommit()
	mock.ExpectQuery(`SELECT firstname, name FROM users WHERE user_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"firstname", "name"}).AddRow("Jean", "Dupont"))
	mock.ExpectQuery(`SELECT c.contact_id, c.contact_name, c.telegram_chat_id`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "contact_name", "telegram_chat_id"}).
			AddRow(4, "Maman", int64(444)))

	sender := &fakeAlertSender{}
	n := &Notifier{sender: sender, jobs: make(chan telegramJob, 4), attempts: 1}

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", float64(1))
		return c.Next()
	})
	app.Post("/alerts", createAlert(db, n))

	body, _ := json.Marshal(CreateAlertRequest{ConfigID: 2})
	req := httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("requête: %s", err)
	}
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("statut attendu %d, obtenu %d", http.StatusCreated, resp.StatusCode)
	}

	var payload struct {
		AlertID       int            `json:"alert_id"`
		Notifications []NotifyResult `json:"notifications"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("décodage réponse: %s", err)
	}
	if payload.AlertID != 7 {
		t.Errorf("alert_id attendu 7, obtenu %d", payload.AlertID)
	}
	if len(payload.Notifications) != 1 || payload.Notifications[0].Status != "queued" {
		t.Errorf("notification attendue en queued, obtenu: %+v", payload.Notifications)
	}
	if len(sender.chats) != 0 {
		t.Errorf("aucun envoi synchrone attendu, obtenu: %v", sender.chats)
	}

	select {
	case job := <-n.jobs:
		job.deliver(n)
	default:
		t.Fatal("le job n'a pas été enfilé")
	}
	if len(sender.chats) != 1 || sender.chats[0] != 444 {
		t.Errorf("envoi asynchrone attendu vers 444, obtenu: %v", sender.chats)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("attentes SQL non respectées: %s", err)
	}
}
