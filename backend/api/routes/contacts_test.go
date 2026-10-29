package routes

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
)

func setupContactTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	t.Helper()
	app := fiber.New()

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("mock DB init: %s", err)
	}

	noopMiddleware := func(c *fiber.Ctx) error { return c.Next() }
	RegisterContactRoutes(app, db, noopMiddleware, nil)

	t.Cleanup(func() {
		db.Close()
	})

	return app, mock
}

func TestCreateContact_Success(t *testing.T) {
	app, mock := setupContactTestEnv(t)

	mock.ExpectQuery(`SELECT 1 FROM users WHERE user_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))

	mock.ExpectBegin()
	mock.ExpectExec(`INSERT INTO contacts`).
		WithArgs("Alice", "+33612345678", nil, "trusted", 1, sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(10, 1))
	mock.ExpectExec(`INSERT INTO user_contacts`).
		WithArgs(1, 10).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	mock.ExpectQuery(`SELECT c.contact_id`).
		WithArgs(1, 10).
		WillReturnRows(sqlmock.NewRows([]string{
			"contact_id", "contact_name", "phone_number", "email", "contact_type", "priority_order",
			"telegram_chat_id", "invite_token", "telegram_linked_at",
		}).AddRow(10, "Alice", "+33612345678", nil, "trusted", 1, nil, "tokentokentokentokentokentoken12", nil))

	body := CreateContactRequest{
		ContactName: "Alice",
		PhoneNumber: "+33612345678",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/contacts", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusCreated {
		t.Errorf("expected status %d, got %d", http.StatusCreated, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestCreateContact_MissingFields(t *testing.T) {
	app, mock := setupContactTestEnv(t)

	mock.ExpectQuery(`SELECT 1 FROM users WHERE user_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))

	body := CreateContactRequest{ContactName: "Alice"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/contacts", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestGetContact_NotFound(t *testing.T) {
	app, mock := setupContactTestEnv(t)

	mock.ExpectQuery(`SELECT 1 FROM contacts WHERE contact_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{"1"})) // empty → ErrNoRows

	req := httptest.NewRequest(http.MethodGet, "/contacts/99", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestGetContact_Forbidden(t *testing.T) {
	app, mock := setupContactTestEnv(t)

	mock.ExpectQuery(`SELECT 1 FROM contacts WHERE contact_id = \?`).
		WithArgs(5).
		WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))
	mock.ExpectQuery(`SELECT 1 FROM user_contacts WHERE user_id = \? AND contact_id = \?`).
		WithArgs(1, 5).
		WillReturnRows(sqlmock.NewRows([]string{"1"})) // empty → ErrNoRows → 403

	req := httptest.NewRequest(http.MethodGet, "/contacts/5", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected status %d, got %d", http.StatusForbidden, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestDeleteContact_Forbidden(t *testing.T) {
	app, mock := setupContactTestEnv(t)

	mock.ExpectQuery(`SELECT 1 FROM contacts WHERE contact_id = \?`).
		WithArgs(5).
		WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))
	mock.ExpectQuery(`SELECT 1 FROM user_contacts WHERE user_id = \? AND contact_id = \?`).
		WithArgs(1, 5).
		WillReturnRows(sqlmock.NewRows([]string{"1"}))

	req := httptest.NewRequest(http.MethodDelete, "/contacts/5", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected status %d, got %d", http.StatusForbidden, resp.StatusCode)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("unmet SQL expectations: %s", err)
	}
}

func TestPhonesMatch(t *testing.T) {
	if !PhonesMatch("+33612345678", "0612345678") {
		t.Error("expected last-9-digit match")
	}
	if PhonesMatch("+33612345678", "+33799999999") {
		t.Error("expected mismatch")
	}
}

func TestInviteEmailStub_NotImplemented(t *testing.T) {
	app, _ := setupContactTestEnv(t)

	req := httptest.NewRequest(http.MethodPost, "/contacts/1/invite/email", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusNotImplemented {
		t.Errorf("expected status %d, got %d", http.StatusNotImplemented, resp.StatusCode)
	}
}
