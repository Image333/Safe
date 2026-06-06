package routes

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

func setupTestEnv(t *testing.T) (*fiber.App, sqlmock.Sqlmock) {
	app := fiber.New()

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Erreur initialisation mock DB: %s", err)
	}

	// On attache directement les routes à notre fausse DB
	RegisterUserRoutes(app, db)

	// Go fermera automatiquement la DB à la fin du test qui appelle ce helper
	t.Cleanup(func() {
		db.Close()
	})

	return app, mock
}

func generateTestJWT(t *testing.T, userID int, email string) string {
	claims := jwt.MapClaims{
		"user_id": userID,
		"email":   email,
		"exp":     time.Now().Add(time.Minute * 5).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(jwtSecret) // Utilise la même variable jwtSecret
	if err != nil {
		t.Fatalf("Erreur génération JWT de test : %v", err)
	}

	return tokenString
}

// //
// // Create user
// //
func TestRegisterUserRoutes_Success(t *testing.T) {
	app, mock := setupTestEnv(t)

	// Configuration des attentes spécifiques à CE test
	mock.ExpectExec("INSERT INTO users").
		WithArgs("Dupont", "Jean", "jean.dupont@etna.fr", sqlmock.AnyArg()).
		WillReturnResult(sqlmock.NewResult(1, 1))

	body := CreateUserRequest{
		Email: "jean.dupont@etna.fr", Password: "Pwd", Firstname: "Jean", Name: "Dupont",
	}
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req, -1)

	if err != nil {
		t.Fatalf("Erreur lors de l'exécution de la requête de test: %s", err)
	}

	if resp.StatusCode != http.StatusCreated {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusCreated, resp.StatusCode)
	}
}

func TestRegisterUserRoutes_BadRequest(t *testing.T) {
	// On récupère encore un environnement tout neuf sans pollution
	app, _ := setupTestEnv(t)

	body := CreateUserRequest{Email: "invalide@etna.fr"} // Il manque le reste
	jsonBody, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusCreated, resp.StatusCode)
	}
}

// //
// // Get User
// //
func TestGetUserByEmail_Success(t *testing.T) {
	app, mock := setupTestEnv(t)

	emailCible := "bob@etna.fr"

	colonnes := []string{"user_id", "name", "firstname", "email", "registration_date", "role_id", "config_id"}
	lignesResultat := sqlmock.NewRows(colonnes).
		AddRow(1, "bob", "bob", emailCible, "2026-06-07T12:00:00Z", 2, nil)

	mock.ExpectQuery(`SELECT user_id, name, firstname, email, registration_date, role_id, config_id FROM users WHERE email = \?`).
		WithArgs(emailCible).
		WillReturnRows(lignesResultat)

	req := httptest.NewRequest(http.MethodGet, "/users/"+emailCible, nil)

	tokenString := generateTestJWT(t, 1, emailCible)
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur exécution requête: %s", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}

	var user UserResponse
	json.NewDecoder(resp.Body).Decode(&user)

	if user.Email != emailCible || user.Name != "bob" {
		t.Errorf("Données utilisateur incorrectes dans la réponse JSON")
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non respectées: %s", err)
	}
}

func TestGetUserByEmail_NotFound(t *testing.T) {
	app, mock := setupTestEnv(t)
	fauxEmail := "inconnu@etna.fr"

	mock.ExpectQuery(`SELECT user_id, name, firstname, email, registration_date, role_id, config_id FROM users WHERE email = \?`).
		WithArgs(fauxEmail).
		WillReturnRows(sqlmock.NewRows([]string{})) // Tableau vide -> Simule ErrNoRows

	req := httptest.NewRequest(http.MethodGet, "/users/"+fauxEmail, nil)

	tokenString := generateTestJWT(t, 1, "test@etna.fr")
	req.Header.Set("Authorization", "Bearer "+tokenString)

	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusNotFound, resp.StatusCode)
	}
}

func TestGetUserByEmail_WithoutJWT(t *testing.T) {
	app, _ := setupTestEnv(t)
	fauxEmail := "inconnu@etna.fr"

	req := httptest.NewRequest(http.MethodGet, "/users/"+fauxEmail, nil)
	resp, _ := app.Test(req, -1)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// //
// // Login
// //
func TestLogin_Success(t *testing.T) {
	userPassword := "azerty1234"
	userEmail := "bob@etna.fr"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(userPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Erreur hachage: %v", err)
	}
	app, mock := setupTestEnv(t)

	colonnes := []string{"user_id", "password"}
	lignesResultat := sqlmock.NewRows(colonnes).
		AddRow(1, hashedPassword)

	mock.ExpectQuery(`SELECT user_id, password FROM users WHERE email = \?`).
		WithArgs(userEmail).
		WillReturnRows(lignesResultat)

	body := LoginRequest{
		Email:    userEmail,
		Password: userPassword,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur lors de l'exécution de la requête: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusOK, resp.StatusCode)
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	userPassword := "azerty1234"
	testedPassword := "toto"
	userEmail := "bob@etna.fr"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(userPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Erreur hachage: %v", err)
	}
	app, mock := setupTestEnv(t)

	colonnes := []string{"user_id", "password"}
	lignesResultat := sqlmock.NewRows(colonnes).
		AddRow(1, hashedPassword)

	mock.ExpectQuery(`SELECT user_id, password FROM users WHERE email = \?`).
		WithArgs(userEmail).
		WillReturnRows(lignesResultat)

	body := LoginRequest{
		Email:    userEmail,
		Password: testedPassword,
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("Erreur lors de l'exécution de la requête: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("Statut attendu: %d, obtenu: %d", http.StatusUnauthorized, resp.StatusCode)
	}
}
