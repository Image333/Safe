package routes

import (
	"github.com/gofiber/fiber/v2"
)

// getCurrentUserID extracts user_id from JWT context.
// JWT numbers are decoded as float64.
func getCurrentUserID(c *fiber.Ctx) int {
	userID := c.Locals("user_id")
	switch v := userID.(type) {
	case float64:
		return int(v)
	case int:
		return v
	default:
		return 0
	}
}
