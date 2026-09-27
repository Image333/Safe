package routes

import (
	"database/sql"
	"errors"
	"log"
	"strconv"

	"github.com/gofiber/fiber/v2"
)

// CreateConfigurationRequest is the payload for creating a configuration
type CreateConfigurationRequest struct {
	AlertWord   string `json:"alert_word"`
	AppDisguise string `json:"app_disguise"`
}

// UpdateConfigurationRequest is the payload for updating a configuration
type UpdateConfigurationRequest struct {
	AlertWord   string `json:"alert_word"`
	AppDisguise string `json:"app_disguise"`
}

// ConfigurationResponse is a configuration returned by the API
type ConfigurationResponse struct {
	ConfigID    int    `json:"config_id"`
	AlertWord   string `json:"alert_word"`
	AppDisguise string `json:"app_disguise"`
}

// RegisterConfigurationRoutes registers all configuration endpoints
func RegisterConfigurationRoutes(router fiber.Router, db *sql.DB, keyMiddleware fiber.Handler) {
	router.Post("/configurations", keyMiddleware, ProtectedRoute(), createConfiguration(db))
	router.Get("/configurations", keyMiddleware, ProtectedRoute(), listConfigurations(db))
	router.Get("/configurations/:id", keyMiddleware, ProtectedRoute(), getConfiguration(db))
	router.Put("/configurations/:id", keyMiddleware, ProtectedRoute(), updateConfiguration(db))
	router.Delete("/configurations/:id", keyMiddleware, ProtectedRoute(), deleteConfiguration(db))
}

// POST /api/v1/configurations — Creates a configuration
func createConfiguration(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var req CreateConfigurationRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		switch {
		case req.AlertWord == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "alert_word requis"})
		case req.AppDisguise == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "app_disguise requis"})
		}

		result, err := db.Exec(
			`INSERT INTO configurations (alert_word, app_disguise) VALUES (?, ?)`,
			req.AlertWord, req.AppDisguise,
		)
		if err != nil {
			log.Printf("Erreur SQL INSERT configuration: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer la configuration"})
		}

		newID, _ := result.LastInsertId()

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":   "Configuration créée avec succès",
			"config_id": newID,
		})
	}
}

// GET /api/v1/configurations — Lists every configuration
func listConfigurations(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		query := `SELECT config_id, alert_word, app_disguise FROM configurations ORDER BY config_id`
		rows, err := db.Query(query)
		if err != nil {
			log.Printf("Erreur SQL listConfigurations: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer rows.Close()

		configs := []ConfigurationResponse{}
		for rows.Next() {
			var cfg ConfigurationResponse
			if err := rows.Scan(&cfg.ConfigID, &cfg.AlertWord, &cfg.AppDisguise); err != nil {
				log.Printf("Erreur scan listConfigurations: %v", err)
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
			}
			configs = append(configs, cfg)
		}
		if err := rows.Err(); err != nil {
			log.Printf("Erreur rows listConfigurations: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"count": len(configs),
			"data":  configs,
		})
	}
}

// GET /api/v1/configurations/:id — Returns a configuration by its ID
func getConfiguration(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID configuration invalide"})
		}

		var cfg ConfigurationResponse
		query := `SELECT config_id, alert_word, app_disguise FROM configurations WHERE config_id = ?`
		err = db.QueryRow(query, id).Scan(&cfg.ConfigID, &cfg.AlertWord, &cfg.AppDisguise)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Configuration non trouvée"})
			}
			log.Printf("Erreur SQL getConfiguration: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		return c.Status(fiber.StatusOK).JSON(cfg)
	}
}

// PUT /api/v1/configurations/:id — Updates a configuration
func updateConfiguration(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID configuration invalide"})
		}

		var req UpdateConfigurationRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		switch {
		case req.AlertWord == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "alert_word requis"})
		case req.AppDisguise == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "app_disguise requis"})
		}

		result, err := db.Exec(
			`UPDATE configurations SET alert_word = ?, app_disguise = ? WHERE config_id = ?`,
			req.AlertWord, req.AppDisguise, id,
		)
		if err != nil {
			log.Printf("Erreur SQL UPDATE configuration: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de mettre à jour la configuration"})
		}

		affected, _ := result.RowsAffected()
		if affected == 0 {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Configuration non trouvée"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Configuration mise à jour avec succès"})
	}
}

// DELETE /api/v1/configurations/:id — Deletes a configuration
func deleteConfiguration(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID configuration invalide"})
		}

		result, err := db.Exec(`DELETE FROM configurations WHERE config_id = ?`, id)
		if err != nil {
			log.Printf("Erreur SQL DELETE configuration: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur lors de la suppression de la configuration"})
		}

		affected, _ := result.RowsAffected()
		if affected == 0 {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Configuration non trouvée"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Configuration supprimée avec succès"})
	}
}
