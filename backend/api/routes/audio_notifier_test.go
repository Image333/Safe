package routes

import (
	"errors"
	"strings"
	"sync"
	"testing"

	"gpe/telegram"

	"github.com/DATA-DOG/go-sqlmock"
)

// fakeAudioSender records sends and fails the first failFetch fetches.
type fakeAudioSender struct {
	mu        sync.Mutex
	fetches   int
	failFetch int
	sent      []int64
	captions  []string
}

func (f *fakeAudioSender) FetchAudio(string) (*telegram.AudioFile, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.fetches++
	if f.fetches <= f.failFetch {
		return nil, errors.New("minio indisponible")
	}
	return &telegram.AudioFile{Filename: "clip.m4a", Data: []byte("audio")}, nil
}

func (f *fakeAudioSender) SendAudioFile(chatID int64, _ *telegram.AudioFile, caption string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sent = append(f.sent, chatID)
	f.captions = append(f.captions, caption)
	return nil
}

// TestAudioNotifier_DeliverDownloadsOnce: the clip is fetched once (with retry)
// and sent to every recipient.
func TestAudioNotifier_DeliverDownloadsOnce(t *testing.T) {
	sender := &fakeAudioSender{failFetch: 1}
	n := &audioNotifier{sender: sender}

	n.deliver(audioJob{
		alertID: 3,
		blobURL: "http://minio-service:9000/audio-bucket/clip.m4a",
		caption: "caption",
		recipients: []audioRecipient{
			{contactID: 1, name: "A", chatID: 111},
			{contactID: 2, name: "B", chatID: 222},
		},
	})

	if sender.fetches != 2 {
		t.Errorf("Téléchargements attendus: 2 (1 échec + 1 retry), obtenus: %d", sender.fetches)
	}
	if len(sender.sent) != 2 || sender.sent[0] != 111 || sender.sent[1] != 222 {
		t.Errorf("Envois inattendus: %v", sender.sent)
	}
}

// TestAudioNotifier_EnqueueBounded: enqueue never blocks once the queue is full.
func TestAudioNotifier_EnqueueBounded(t *testing.T) {
	n := &audioNotifier{jobs: make(chan audioJob, 1)}

	if !n.enqueue(audioJob{alertID: 1}) {
		t.Fatal("Le premier envoi doit être accepté")
	}
	if n.enqueue(audioJob{alertID: 2}) {
		t.Error("La file pleine doit refuser l'envoi")
	}
}

// TestBuildAudioJob_EscapesUserName: recipients are loaded from the DB and the
// HTML caption escapes the user name.
func TestBuildAudioJob_EscapesUserName(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}
	defer db.Close()

	mock.ExpectQuery(`SELECT c.contact_id, c.contact_name, c.telegram_chat_id`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "contact_name", "telegram_chat_id"}).
			AddRow(4, "Maman", int64(444)))
	mock.ExpectQuery(`SELECT firstname, name FROM users WHERE user_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"firstname", "name"}).AddRow("<b>Jean</b>", "Dupont"))

	job, err := buildAudioJob(db, 1, 3, "http://minio-service:9000/audio-bucket/clip.m4a")
	if err != nil {
		t.Fatalf("Erreur inattendue: %s", err)
	}
	if len(job.recipients) != 1 || job.recipients[0].chatID != 444 {
		t.Errorf("Destinataires inattendus: %+v", job.recipients)
	}
	if strings.Contains(job.caption, "<b>Jean</b>") || !strings.Contains(job.caption, "&lt;b&gt;Jean") {
		t.Errorf("Le nom doit être échappé, caption: %s", job.caption)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestBuildAudioJob_NoLinkedContact: no recipient means nothing to send and no
// user lookup.
func TestBuildAudioJob_NoLinkedContact(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}
	defer db.Close()

	mock.ExpectQuery(`SELECT c.contact_id, c.contact_name, c.telegram_chat_id`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "contact_name", "telegram_chat_id"}))

	job, err := buildAudioJob(db, 1, 3, "http://minio-service:9000/audio-bucket/clip.m4a")
	if err != nil {
		t.Fatalf("Erreur inattendue: %s", err)
	}
	if len(job.recipients) != 0 {
		t.Errorf("Aucun destinataire attendu: %+v", job.recipients)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}
