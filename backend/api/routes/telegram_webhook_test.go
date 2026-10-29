package routes

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
)

const testWebhookSecret = "test-telegram-secret"

func setupTelegramTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	t.Helper()
	t.Setenv("TELEGRAM_WEBHOOK_SECRET", testWebhookSecret)

	app := fiber.New()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	RegisterTelegramRoutes(app, db, nil)
	t.Cleanup(func() { db.Close() })
	return app, mock
}

func webhookRequest(body string, secret string) *http.Request {
	req := httptest.NewRequest(http.MethodPost, "/telegram/webhook", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	if secret != "" {
		req.Header.Set("X-Telegram-Bot-Api-Secret-Token", secret)
	}
	return req
}

func TestTelegramWebhook_MissingSecretEnv(t *testing.T) {
	t.Setenv("TELEGRAM_WEBHOOK_SECRET", "")

	app := fiber.New()
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	t.Cleanup(func() { db.Close() })
	RegisterTelegramRoutes(app, db, nil)

	req := webhookRequest(`{"update_id":1}`, "anything")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected %d, got %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

func TestTelegramWebhook_InvalidSecret(t *testing.T) {
	app, _ := setupTelegramTestEnv(t)

	req := webhookRequest(`{"update_id":1}`, "wrong-secret")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected %d, got %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

func TestTelegramWebhook_StartToken_Success(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "invite-abc").
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := `{"update_id":1,"message":{"message_id":1,"text":"/start invite-abc","chat":{"id":42},"from":{"id":99}}}`
	req := webhookRequest(body, testWebhookSecret)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestTelegramWebhook_StartToken_AlreadyLinked(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "invite-abc").
		WillReturnResult(sqlmock.NewResult(0, 0))

	body := `{"update_id":1,"message":{"message_id":1,"text":"/start invite-abc","chat":{"id":42},"from":{"id":99}}}`
	req := webhookRequest(body, testWebhookSecret)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestTelegramWebhook_PhoneShare_WithoutProof(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	body := `{
		"update_id":1,
		"message":{
			"message_id":1,
			"chat":{"id":42},
			"from":{"id":99},
			"contact":{"phone_number":"+33612345678","user_id":111}
		}
	}`
	req := webhookRequest(body, testWebhookSecret)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestTelegramWebhook_PhoneShare_Success(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectQuery(`SELECT contact_id, phone_number FROM contacts WHERE telegram_chat_id IS NULL`).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "phone_number"}).
			AddRow(7, "+33612345678"))

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), 7).
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := `{
		"update_id":1,
		"message":{
			"message_id":1,
			"chat":{"id":42},
			"from":{"id":99},
			"contact":{"phone_number":"0612345678","user_id":99}
		}
	}`
	req := webhookRequest(body, testWebhookSecret)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestLinkContactByInviteToken_RequiresNullChat(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	t.Cleanup(func() { db.Close() })

	mock.ExpectExec(`telegram_chat_id IS NULL`).
		WithArgs(int64(42), sqlmock.AnyArg(), "tok").
		WillReturnResult(sqlmock.NewResult(0, 0))

	ok, err := linkContactByInviteToken(db, "tok", 42)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected ok=false when no row updated")
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestLinkContactByPhone_NoMatch(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	t.Cleanup(func() { db.Close() })

	mock.ExpectQuery(`WHERE telegram_chat_id IS NULL`).
		WillReturnRows(sqlmock.NewRows([]string{"contact_id", "phone_number"}).
			AddRow(1, "+33700000000"))

	ok, err := linkContactByPhone(db, "+33612345678", 42)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Error("expected ok=false when phone does not match")
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}
