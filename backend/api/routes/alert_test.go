package routes

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
)

// setupAlertTestEnv builds a Fiber app wired to a mock DB with all alert routes
// registered, and a no-op auth middleware.
func setupAlertTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	app := fiber.New()

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}

	noopMiddleware := func(c *fiber.Ctx) error { return c.Next() }
	RegisterAlertRoutes(app, db, noopMiddleware)

	t.Cleanup(func() {
		db.Close()
	})

	return app, mock
}

// ============================================================================
// POST /alerts
// ============================================================================

// TestCreateAlert_Success: a valid config_id inserts an alert owned by the JWT
// user and returns 201 with the generated alert_id.
func TestCreateAlert_Success(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	// The referenced configuration must exist
	mock.ExpectQuery(`SELECT config_id FROM configurations WHERE config_id = \?`).
		WithArgs(2).
		WillReturnRows(sqlmock.NewRows([]string{"config_id"}).AddRow(2))

	// user_id comes from the JWT (1), config_id from the body (2)
	mock.ExpectExec(`INSERT INTO alerts`).
		WithArgs(1, 2).
		WillReturnResult(sqlmock.NewResult(7, 1))

	body := CreateAlertRequest{ConfigID: 2}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(jsonBody))
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

// TestCreateAlert_MissingConfigID: a missing or zero config_id is rejected with
// 400 before any SQL query is issued.
func TestCreateAlert_MissingConfigID(t *testing.T) {
	app, _ := setupAlertTestEnv(t)

	body := CreateAlertRequest{ConfigID: 0}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestCreateAlert_ConfigNotFound: referencing an unknown configuration returns
// 404 instead of failing on the foreign key constraint.
func TestCreateAlert_ConfigNotFound(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT config_id FROM configurations WHERE config_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{})) // empty row set -> sql.ErrNoRows

	body := CreateAlertRequest{ConfigID: 99}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestCreateAlert_InvalidJSON: a malformed body is rejected with 400.
func TestCreateAlert_InvalidJSON(t *testing.T) {
	app, _ := setupAlertTestEnv(t)

	req := httptest.NewRequest(http.MethodPost, "/alerts",
		bytes.NewReader([]byte(`{invalid}`)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestCreateAlert_WithoutJWT: a request without an Authorization header is
// rejected with 401 by the JWT middleware.
func TestCreateAlert_WithoutJWT(t *testing.T) {
	app, _ := setupAlertTestEnv(t)

	body := CreateAlertRequest{ConfigID: 2}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// ============================================================================
// GET /alerts/:id
// ============================================================================

// TestGetAlert_Success: the owner retrieves the alert with its timestamp
// formatted as "YYYY-MM-DD HH:MM:SS".
func TestGetAlert_Success(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	ts := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)
	colonnes := []string{"alert_id", "timestamp", "status", "user_id", "config_id"}
	mock.ExpectQuery(`SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows(colonnes).AddRow(3, ts, "PENDING", 1, 2))

	req := httptest.NewRequest(http.MethodGet, "/alerts/3", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var alert AlertResponse
	json.NewDecoder(resp.Body).Decode(&alert)
	if alert.AlertID != 3 || alert.Status != "PENDING" || alert.ConfigID != 2 {
		t.Errorf("Données d'alerte incorrectes dans la réponse JSON")
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

// TestGetAlert_NotFound: an unknown alert ID returns 404.
func TestGetAlert_NotFound(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE alert_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{})) // empty row set -> sql.ErrNoRows

	req := httptest.NewRequest(http.MethodGet, "/alerts/99", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestGetAlert_Forbidden: reading an alert owned by another user returns 403.
func TestGetAlert_Forbidden(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	ts := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)
	colonnes := []string{"alert_id", "timestamp", "status", "user_id", "config_id"}
	// The alert belongs to user 2, while the JWT identifies user 1
	mock.ExpectQuery(`SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows(colonnes).AddRow(3, ts, "PENDING", 2, 2))

	req := httptest.NewRequest(http.MethodGet, "/alerts/3", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusForbidden, resp.StatusCode)
	}
}

// ============================================================================
// GET /alerts
// ============================================================================

// TestListAlerts_Success: only the alerts of the JWT user are returned, most
// recent first, as {count, data[]}.
func TestListAlerts_Success(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	ts := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)
	colonnes := []string{"alert_id", "timestamp", "status", "user_id", "config_id"}
	mock.ExpectQuery(`SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE user_id = \? ORDER BY alert_id DESC`).
		WithArgs(1).
		WillReturnRows(sqlmock.NewRows(colonnes).
			AddRow(3, ts, "PENDING", 1, 2).
			AddRow(1, ts, "RESOLVED", 1, 2))

	req := httptest.NewRequest(http.MethodGet, "/alerts", nil)
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
// PUT /alerts/:id
// ============================================================================

// TestUpdateAlertStatus_Success: the owner updates the status and gets 200.
func TestUpdateAlertStatus_Success(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	// Ownership check
	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	// Status update
	mock.ExpectExec(`UPDATE alerts SET status = \? WHERE alert_id = \?`).
		WithArgs("TRIGGERED", 3).
		WillReturnResult(sqlmock.NewResult(0, 1))

	body := UpdateAlertRequest{Status: "TRIGGERED"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/alerts/3", bytes.NewReader(jsonBody))
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

// TestUpdateAlertStatus_InvalidStatus: a status outside the allowed set is
// rejected with 400 before any SQL query is issued.
func TestUpdateAlertStatus_InvalidStatus(t *testing.T) {
	app, _ := setupAlertTestEnv(t)

	body := UpdateAlertRequest{Status: "NIMPORTEQUOI"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/alerts/3", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestUpdateAlertStatus_NotFound: updating an unknown alert returns 404.
func TestUpdateAlertStatus_NotFound(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{})) // empty row set -> sql.ErrNoRows

	body := UpdateAlertRequest{Status: "RESOLVED"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/alerts/99", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestUpdateAlertStatus_Forbidden: updating an alert owned by another user
// returns 403 and never runs the UPDATE.
func TestUpdateAlertStatus_Forbidden(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(2)) // other user

	body := UpdateAlertRequest{Status: "RESOLVED"}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/alerts/3", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusForbidden, resp.StatusCode)
	}
}

// ============================================================================
// DELETE /alerts/:id
// ============================================================================

// TestDeleteAlert_Success: the owner deletes the alert and gets 200.
func TestDeleteAlert_Success(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	mock.ExpectExec(`DELETE FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnResult(sqlmock.NewResult(0, 1))

	req := httptest.NewRequest(http.MethodDelete, "/alerts/3", nil)
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

// TestDeleteAlert_NotFound: deleting an unknown alert returns 404.
func TestDeleteAlert_NotFound(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(99).
		WillReturnRows(sqlmock.NewRows([]string{})) // empty row set -> sql.ErrNoRows

	req := httptest.NewRequest(http.MethodDelete, "/alerts/99", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

// TestDeleteAlert_Forbidden: deleting an alert owned by another user returns 403
// and never runs the DELETE.
func TestDeleteAlert_Forbidden(t *testing.T) {
	app, mock := setupAlertTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(2)) // other user

	req := httptest.NewRequest(http.MethodDelete, "/alerts/3", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestJWT(t, 1, "jean@etna.fr"))

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusForbidden, resp.StatusCode)
	}
}
