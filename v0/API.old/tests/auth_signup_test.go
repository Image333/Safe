package tests

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestSignup_HappyPath_Strict(t *testing.T) {
	setJWTSecretForTests()
	db, mock := newSQLMock(t)
	defer db.Close()

	mock.ExpectExec("^INSERT INTO `user` \\(name, firstname, email, password, registration_date\\) VALUES \\(\\?, \\?, \\?, \\?, NOW\\(\\)\\)$").
		WithArgs(
			"Doe",
			"John",
			"john@example.com",
			sqlmock.AnyArg(),
		).
		WillReturnResult(sqlmock.NewResult(8, 1))

	mock.ExpectQuery("^SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = \\?$").
		WithArgs(8).
		WillReturnRows(
			sqlmock.NewRows([]string{"user_id", "name", "firstname", "email", "registration_date"}).
				AddRow(8, "Doe", "John", "john@example.com", "2025-11-12 11:09:03"),
		)

	app := newTestApp(db)
	body := map[string]any{
		"name":      "Doe",
		"firstname": "John",
		"email":     "john@example.com",
		"password":  "Azerty123!",
	}
	req := httptest.NewRequest(http.MethodPost, "/api/auth/signup", jsonBody(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	assert.NoError(t, err)
	assert.Equal(t, http.StatusCreated, resp.StatusCode)

	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestSignup_DuplicateEmail(t *testing.T) {
	setJWTSecretForTests()
	db, mock := newSQLMock(t)
	defer db.Close()

	mock.ExpectExec("^INSERT INTO `user` \\(name, firstname, email, password, registration_date\\) VALUES \\(\\?, \\?, \\?, \\?, NOW\\(\\)\\)$").
		WithArgs("Doe", "John", "john@example.com", sqlmock.AnyArg()).
		WillReturnError(errors.New("Error 1062: Duplicate entry 'john@example.com' for key 'email'"))

	app := newTestApp(db)
	body := map[string]any{
		"name":      "Doe",
		"firstname": "John",
		"email":     "john@example.com",
		"password":  "Azerty123!",
	}
	req := httptest.NewRequest(http.MethodPost, "/api/auth/signup", jsonBody(body))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	assert.Equal(t, http.StatusConflict, resp.StatusCode)
}
