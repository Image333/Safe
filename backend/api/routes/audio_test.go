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

func setupAudioTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	app := fiber.New()

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}

	RegisterAudioRoutes(app, db)

	t.Cleanup(func() {
		db.Close()
	})

	return app, mock
}

// ============================================================================
// POST /alerts/:alertId/audio
// ============================================================================

func TestCreateAudio_Success(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	// Vérification : l'alerte existe et appartient à l'utilisateur
	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	// Vérification : pas d'audio existant sur cette alerte
	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM audio_records WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"COUNT(*)"}).AddRow(0))

	// Insertion
	mock.ExpectExec(`INSERT INTO audio_records`).
		WithArgs(
			"http://minio-service:9000/audio-bucket/test.mp3",
			45,
			"mp3",
			3,
		).
		WillReturnResult(sqlmock.NewResult(1, 1))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

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

func TestCreateAudio_InvalidJSON(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio",
		bytes.NewReader([]byte(`{invalid}`)))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestCreateAudio_MissingBlobURL(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM audio_records WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"COUNT(*)"}).AddRow(0))

	body := CreateAudioRequest{
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestCreateAudio_InvalidDuration(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM audio_records WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"COUNT(*)"}).AddRow(0))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 0,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestCreateAudio_MissingFormat(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM audio_records WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"COUNT(*)"}).AddRow(0))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestCreateAudio_AlertNotFound(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(999).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/999/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

func TestCreateAudio_AlertBelongsToOtherUser(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	// L'alerte 3 appartient à l'utilisateur 42, mais le JWT est pour l'utilisateur 1
	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(42))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusForbidden, resp.StatusCode)
	}
}

func TestCreateAudio_AlreadyExists(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT user_id FROM alerts WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"user_id"}).AddRow(1))

	mock.ExpectQuery(`SELECT COUNT\(\*\) FROM audio_records WHERE alert_id = \?`).
		WithArgs(3).
		WillReturnRows(sqlmock.NewRows([]string{"COUNT(*)"}).AddRow(1))

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusConflict {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusConflict, resp.StatusCode)
	}
}

func TestCreateAudio_WithoutJWT(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	body := CreateAudioRequest{
		BlobURL:  "http://minio-service:9000/audio-bucket/test.mp3",
		Duration: 45,
		Format:   "mp3",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/alerts/3/audio", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// ============================================================================
// GET /audio/:id
// ============================================================================

func TestGetAudioByID_Success(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	ts := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)

	colonnes := []string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}
	lignes := sqlmock.NewRows(colonnes).
		AddRow(1, "http://minio-service:9000/bucket/test.mp3", 45, "mp3", 3, ts, "PENDING")

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE a.audio_id = \? AND al.user_id = \?`).
		WithArgs(1, 1).
		WillReturnRows(lignes)

	req := httptest.NewRequest(http.MethodGet, "/audio/1", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var audio AudioResponse
	json.NewDecoder(resp.Body).Decode(&audio)

	if audio.AudioID != 1 || audio.AlertID != 3 {
		t.Errorf("Données audio incorrectes dans la réponse JSON")
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

func TestGetAudioByID_NotFound(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE a.audio_id = \? AND al.user_id = \?`).
		WithArgs(999, 1).
		WillReturnRows(sqlmock.NewRows([]string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}))

	req := httptest.NewRequest(http.MethodGet, "/audio/999", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

func TestGetAudioByID_InvalidID(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/audio/abc", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestGetAudioByID_WithoutJWT(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/audio/1", nil)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// ============================================================================
// GET /alerts/:alertId/audio
// ============================================================================

func TestGetAudioByAlert_Success(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	ts := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)

	colonnes := []string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}
	lignes := sqlmock.NewRows(colonnes).
		AddRow(1, "http://minio-service:9000/bucket/test.mp3", 45, "mp3", 3, ts, "PENDING")

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE a.alert_id = \? AND al.user_id = \?`).
		WithArgs(3, 1).
		WillReturnRows(lignes)

	req := httptest.NewRequest(http.MethodGet, "/alerts/3/audio", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

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

func TestGetAudioByAlert_NotFound(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE a.alert_id = \? AND al.user_id = \?`).
		WithArgs(999, 1).
		WillReturnRows(sqlmock.NewRows([]string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}))

	req := httptest.NewRequest(http.MethodGet, "/alerts/999/audio", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

func TestGetAudioByAlert_InvalidAlertID(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/alerts/abc/audio", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusBadRequest, resp.StatusCode)
	}
}

func TestGetAudioByAlert_WithoutJWT(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/alerts/3/audio", nil)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// ============================================================================
// GET /me/audio
// ============================================================================

func TestGetMyAudio_Success(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	ts1 := time.Date(2026, 7, 17, 11, 41, 49, 0, time.UTC)
	ts2 := time.Date(2026, 7, 17, 12, 0, 0, 0, time.UTC)

	colonnes := []string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}
	lignes := sqlmock.NewRows(colonnes).
		AddRow(1, "http://minio-service:9000/bucket/rec1.mp3", 45, "mp3", 3, ts1, "PENDING").
		AddRow(2, "http://minio-service:9000/bucket/rec2.mp3", 30, "mp3", 5, ts2, "PENDING")

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE al.user_id = \? ORDER BY al.timestamp DESC`).
		WithArgs(1).
		WillReturnRows(lignes)

	req := httptest.NewRequest(http.MethodGet, "/me/audio", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var audios []AudioResponse
	json.NewDecoder(resp.Body).Decode(&audios)

	if len(audios) != 2 {
		t.Errorf("Nombre d'audios attendu: 2, obtenu: %d", len(audios))
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

func TestGetMyAudio_Empty(t *testing.T) {
	app, mock := setupAudioTestEnv(t)

	colonnes := []string{"audio_id", "blob_url", "duration", "format", "alert_id", "timestamp", "status"}
	lignes := sqlmock.NewRows(colonnes)

	mock.ExpectQuery(`SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id, al.timestamp, al.status FROM audio_records a JOIN alerts al ON a.alert_id = al.alert_id WHERE al.user_id = \? ORDER BY al.timestamp DESC`).
		WithArgs(1).
		WillReturnRows(lignes)

	req := httptest.NewRequest(http.MethodGet, "/me/audio", nil)

	tokenString := generateTestJWT(t, 1, "jean@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var audios []AudioResponse
	json.NewDecoder(resp.Body).Decode(&audios)

	if len(audios) != 0 {
		t.Errorf("Nombre d'audios attendu: 0, obtenu: %d", len(audios))
	}
}

func TestGetMyAudio_WithoutJWT(t *testing.T) {
	app, _ := setupAudioTestEnv(t)

	req := httptest.NewRequest(http.MethodGet, "/me/audio", nil)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}
