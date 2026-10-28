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

// setupConfigurationTestEnv builds a Fiber app wired to a mock DB with all
// configuration routes registered, and a no-op auth middleware.
func setupConfigurationTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	app := fiber.New()

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}

	noopMiddleware := func(c *fiber.Ctx) error { return c.Next() }
	RegisterConfigurationRoutes(app, db, noopMiddleware)

	t.Cleanup(func() {
		db.Close()
	})

	return app, mock
}

// ============================================================================
// POST /configurations
// ============================================================================

// TestCreateConfiguration_Success: a valid payload inserts one row and returns
// 201 with the generated config_id.
func TestCreateConfiguration_Success(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectExec(`INSERT INTO configurations`).
		WithArgs("help", "Weather").
		WillReturnResult(sqlmock.NewResult(1, 1))

	body := CreateConfigurationRequest{AlertWord: "help", AppDisguise: "Weather"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/configurations", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusCreated {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusCreated, resp.StatusCode)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestCreateConfiguration_MissingAlertWord: an empty alert_word is rejected with
// 400 before any SQL query is issued.
func TestCreateConfiguration_MissingAlertWord(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	body := CreateConfigurationRequest{AppDisguise: "Weather"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/configurations", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestCreateConfiguration_MissingAppDisguise: an empty app_disguise is rejected
// with 400 before any SQL query is issued.
func TestCreateConfiguration_MissingAppDisguise(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	body := CreateConfigurationRequest{AlertWord: "help"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/configurations", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestCreateConfiguration_InvalidJSON: a malformed body is rejected with 400.
func TestCreateConfiguration_InvalidJSON(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	req := httptest.NewRequest(http.MethodPost, "/configurations",
		bytes.NewReader([]byte(`{invalid}`)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestCreateConfiguration_WithoutJWT: a request without an Authorization header
// is rejected with 401 by the JWT middleware.
func TestCreateConfiguration_WithoutJWT(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	body := CreateConfigurationRequest{AlertWord: "help", AppDisguise: "Weather"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/configurations", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// ============================================================================
// GET /configurations/:id
// ============================================================================

// TestGetConfiguration_Success: an existing ID returns 200 with the full
// configuration payload.
func TestGetConfiguration_Success(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	colonnes := []string{"config_id", "alert_word", "app_disguise"}
	mock.ExpectQuery(`SELECT config_id, alert_word, app_disguise FROM configurations WHERE config_id = \?`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows(colonnes).AddRow(1, "help", "Weather"))

	req := httptest.NewRequest(http.MethodGet, "/configurations/1", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var cfg ConfigurationResponse
	json.NewDecoder(resp.Body).Decode(&cfg)
	if cfg.ConfigID != 1 || cfg.AlertWord != "help" || cfg.AppDisguise != "Weather" {
		t.Errorf("Données de configuration incorrectes dans la réponse JSON")
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestGetConfiguration_NotFound: an unknown ID returns 404.
func TestGetConfiguration_NotFound(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectQuery(`SELECT config_id, alert_word, app_disguise FROM configurations WHERE config_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{})) // empty row set -> sql.ErrNoRows

	req := httptest.NewRequest(http.MethodGet, "/configurations/99", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestGetConfiguration_InvalidID: a non-numeric ID is rejected with 400 without
// touching the database.
func TestGetConfiguration_InvalidID(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/configurations/abc", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// ============================================================================
// GET /configurations
// ============================================================================

// TestListConfigurations_Success: the collection is returned as {count, data[]}
// with one entry per row.
func TestListConfigurations_Success(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	colonnes := []string{"config_id", "alert_word", "app_disguise"}
	mock.ExpectQuery(`SELECT config_id, alert_word, app_disguise FROM configurations ORDER BY config_id`).
		WillReturnRows(sqlmock.NewRows(colonnes).
			AddRow(1, "help", "Weather").
			AddRow(2, "sos", "Notes"))

	req := httptest.NewRequest(http.MethodGet, "/configurations", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// ============================================================================
// PUT /configurations/:id
// ============================================================================

// TestUpdateConfiguration_Success: a valid payload updates the row and returns
// 200.
func TestUpdateConfiguration_Success(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectExec(`UPDATE configurations SET alert_word = \?, app_disguise = \? WHERE config_id = \?`).
		WithArgs("tonnerre", "Calculette", 1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := UpdateConfigurationRequest{AlertWord: "tonnerre", AppDisguise: "Calculette"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/configurations/1", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestUpdateConfiguration_NotFound: zero affected rows maps to a 404.
func TestUpdateConfiguration_NotFound(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectExec(`UPDATE configurations SET alert_word = \?, app_disguise = \? WHERE config_id = \?`).
		WithArgs("tonnerre", "Calculette", 99).
		WillReturnResult(sqlmock.NewResult(0, 0)) // 0 rows affected

	body := UpdateConfigurationRequest{AlertWord: "tonnerre", AppDisguise: "Calculette"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/configurations/99", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestUpdateConfiguration_MissingFields: an incomplete payload is rejected with
// 400 before any SQL query is issued.
func TestUpdateConfiguration_MissingFields(t *testing.T) {
	app, _ := setupConfigurationTestEnv(t)

	body := UpdateConfigurationRequest{AlertWord: "tonnerre"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/configurations/1", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// ============================================================================
// DELETE /configurations/:id
// ============================================================================

// TestDeleteConfiguration_Success: deleting an existing row returns 200.
func TestDeleteConfiguration_Success(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectExec(`DELETE FROM configurations WHERE config_id = \?`).
		WithArgs(1).
		WillReturnResult(sqlmock.NewResult(0, 1))

	req := httptest.NewRequest(http.MethodDelete, "/configurations/1", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestDeleteConfiguration_NotFound: deleting an unknown row returns 404.
func TestDeleteConfiguration_NotFound(t *testing.T) {
	app, mock := setupConfigurationTestEnv(t)

	mock.ExpectExec(`DELETE FROM configurations WHERE config_id = \?`).
		WithArgs(99).
		WillReturnResult(sqlmock.NewResult(0, 0)) // 0 rows affected

	req := httptest.NewRequest(http.MethodDelete, "/configurations/99", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}
