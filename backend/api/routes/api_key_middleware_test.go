package routes

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

// TestApiKeyMiddleware_Missing: a request without X-API-Key is rejected with 401.
func TestApiKeyMiddleware_Missing(t *testing.T) {
	app := fiber.New()
	app.Use(ApiKeyMiddleware("app-key", "dev-key"))
	app.Get("/ping", func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected %d, got %d", http.StatusUnauthorized, resp.StatusCode)
	}
}

// TestApiKeyMiddleware_Invalid: a wrong X-API-Key is rejected with 403.
func TestApiKeyMiddleware_Invalid(t *testing.T) {
	app := fiber.New()
	app.Use(ApiKeyMiddleware("app-key", "dev-key"))
	app.Get("/ping", func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	req.Header.Set("X-API-Key", "wrong")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected %d, got %d", http.StatusForbidden, resp.StatusCode)
	}
}

// TestApiKeyMiddleware_ValidAppKey: the application key is accepted and the
// handler runs.
func TestApiKeyMiddleware_ValidAppKey(t *testing.T) {
	app := fiber.New()
	app.Use(ApiKeyMiddleware("app-key", "dev-key"))
	app.Get("/ping", func(c *fiber.Ctx) error {
		return c.SendString("ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	req.Header.Set("X-API-Key", "app-key")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("request error: %s", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected %d, got %d", http.StatusOK, resp.StatusCode)
	}
}
