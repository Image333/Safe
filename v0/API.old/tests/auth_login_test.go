package tests

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"golang.org/x/crypto/bcrypt"
)

func TestLogin_HappyPath_Strict(t *testing.T) {
	setJWTSecretForTests()
	db, mock := newSQLMock(t)
	defer db.Close()

	hash, _ := bcrypt.GenerateFromPassword([]byte("Azerty123!"), bcrypt.DefaultCost)

	mock.ExpectQuery("^SELECT user_id, name, firstname, email, password, registration_date FROM `user` WHERE email = \\? LIMIT 1$").
		WithArgs("john@example.com").
		WillReturnRows(
			sqlmock.NewRows([]string{
				"user_id", "name", "firstname", "email", "password", "registration_date",
			}).AddRow(8, "Doe", "John", "john@example.com", string(hash), "2025-11-12 11:09:03"),
		)

	app := newTestApp(db)
	body := map[string]any{"email": "john@example.com", "password": "Azerty123!"}
	req := httptest.NewRequest(http.MethodPost, "/api/auth/login", jsonBody(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	assert.NoError(t, mock.ExpectationsWereMet())
}
