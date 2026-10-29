package routes

import (
	"github.com/gofiber/fiber/v2"
)

// ApiKeyMiddleware protects endpoints with an API key.
// Two keys are accepted: one for the mobile app, one for developers.
func ApiKeyMiddleware(appKey, devKey string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		apiKey := c.Get("X-API-Key")

		if apiKey == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "API key requise",
			})
		}

		if apiKey != appKey && apiKey != devKey {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "API key invalide",
			})
		}

		return c.Next()
	}
}
