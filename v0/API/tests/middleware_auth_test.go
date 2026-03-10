package tests

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
)

func makeTestToken(sub int, email, secret string) string {
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":   sub,
		"email": email,
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(1 * time.Hour).Unix(),
	})
	s, _ := tok.SignedString([]byte(secret))
	return s
}

func TestRequireAuthMiddleware_Strict(t *testing.T) {
	setJWTSecretForTests()
	db, _ := newSQLMock(t)
	defer db.Close()

	app := newTestApp(db)

	// Sans token -> 401
	req1 := httptest.NewRequest(http.MethodPost, "/api/contact", nil)
	resp1, err := app.Test(req1)
	assert.NoError(t, err)
	assert.Equal(t, http.StatusUnauthorized, resp1.StatusCode)

	token := makeTestToken(8, "john@example.com", "test-secret")
	req2 := httptest.NewRequest(http.MethodPost, "/api/contact", nil)
	req2.Header.Set("Authorization", "Bearer "+token)

	resp2, err := app.Test(req2)
	assert.NoError(t, err)
	assert.NotEqual(t, http.StatusUnauthorized, resp2.StatusCode)
}
