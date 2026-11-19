package routes

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
)

// testWebhookSecret is the value injected into TELEGRAM_WEBHOOK_SECRET for the
// webhook tests that expect the secret check to pass.
const testWebhookSecret = "test-telegram-secret"

// setupTelegramTestEnv builds a Fiber app wired to a mock DB with the Telegram
// webhook registered, and sets the webhook secret for the duration of the test.
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

// webhookRequest builds a signed webhook request; an empty secret omits the
// X-Telegram-Bot-Api-Secret-Token header.
func webhookRequest(body string, secret string) *http.Request {
	req := httptest.NewRequest(http.MethodPost, "/telegram/webhook", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	if secret != "" {
		req.Header.Set("X-Telegram-Bot-Api-Secret-Token", secret)
	}
	return req
}

// ============================================================================
// POST /telegram/webhook
// ============================================================================

// TestTelegramWebhook_MissingSecretEnv: an unset TELEGRAM_WEBHOOK_SECRET
// rejects every call with 401 instead of accepting unsigned updates.
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

// TestTelegramWebhook_InvalidSecret: a wrong
// X-Telegram-Bot-Api-Secret-Token header is rejected with 401.
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

// TestTelegramWebhook_StartToken_Success: "/start <invite_token>" links the chat
// to the matching contact and answers 200.
func TestTelegramWebhook_StartToken_Success(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "invite-abc").
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := `{"update_id":1,"message":{"message_id":1,"text":"/start invite-abc","chat":{"id":42,"type":"private"},"from":{"id":99}}}`
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

// TestTelegramWebhook_StartToken_AlreadyLinked: an invite token that is already
// used updates no row and still answers 200, so the bot stays idempotent.
func TestTelegramWebhook_StartToken_AlreadyLinked(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "invite-abc").
		WillReturnResult(sqlmock.NewResult(0, 0))

	body := `{"update_id":1,"message":{"message_id":1,"text":"/start invite-abc","chat":{"id":42,"type":"private"},"from":{"id":99}}}`
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

// TestTelegramWebhook_PhoneShare_WithoutProof: a shared contact whose user_id
// does not match the sender is ignored and no SQL write is issued.
func TestTelegramWebhook_PhoneShare_WithoutProof(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	body := `{
		"update_id":1,
		"message":{
			"message_id":1,
			"chat":{"id":42,"type":"private"},
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

// TestTelegramWebhook_PhoneShare_Success: a shared phone number matching an
// unlinked contact binds the chat to that contact.
func TestTelegramWebhook_PhoneShare_Success(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	mock.ExpectQuery(`SELECT contact_id FROM contacts`).
		WithArgs("612345678").
		WillReturnRows(sqlmock.NewRows([]string{"contact_id"}).AddRow(7))

	mock.ExpectExec(`UPDATE contacts SET telegram_chat_id`).
		WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), 7).
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := `{
		"update_id":1,
		"message":{
			"message_id":1,
			"chat":{"id":42,"type":"private"},
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

// ============================================================================
// Linking helpers
// ============================================================================

// TestLinkContactByInviteToken_RequiresNullChat: the UPDATE is scoped to
// telegram_chat_id IS NULL, so an existing link cannot be hijacked.
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

// TestLinkContactByPhone_NoMatch: a phone number with no matching contact
// returns false and performs no write.
func TestLinkContactByPhone_NoMatch(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}
	t.Cleanup(func() { db.Close() })

	mock.ExpectQuery(`SELECT contact_id FROM contacts`).
		WithArgs("612345678").
		WillReturnRows(sqlmock.NewRows([]string{"contact_id"}))

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

// TestTelegramWebhook_GroupChatIgnored: a group chat is accepted (200) but never
// linked, so alert broadcasts cannot reach a group.
func TestTelegramWebhook_GroupChatIgnored(t *testing.T) {
	app, mock := setupTelegramTestEnv(t)

	body := `{"update_id":1,"message":{"message_id":1,"text":"/start invite-abc","chat":{"id":-100123,"type":"group"},"from":{"id":99}}}`
	req := webhookRequest(body, testWebhookSecret)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("aucune requête SQL attendue: %s", err)
	}
}
