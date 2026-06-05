package routes

import "github.com/gofiber/fiber/v2"

// RegisterHealthRoutes enregistre les endpoints liés à l'état du système
func HealthRoutes(router fiber.Router) {
	router.Get("/health", getHealth)
}

// Le handler lui-même, isolé du reste
func getHealth(c *fiber.Ctx) error {
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status":  "healthy",
		"message": "API Safe opérationnelle",
	})
}
