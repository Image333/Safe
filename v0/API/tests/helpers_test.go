package tests

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"os"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gofiber/fiber/v2"

	"API/routes"
)

func newSQLMock(t *testing.T) (*sql.DB, sqlmock.Sqlmock) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New: %v", err)
	}
	return db, mock
}

func newTestApp(db *sql.DB) *fiber.App {
	app := fiber.New()
	routes.Register(app, db)
	return app
}

func jsonBody(v any) *bytes.Reader {
	b, _ := json.Marshal(v)
	return bytes.NewReader(b)
}

func setJWTSecretForTests() {
	_ = os.Setenv("JWT_SECRET", "test-secret")
}
