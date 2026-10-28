package routes

import (
	"database/sql"
	"errors"
	"log"
	"strconv"

	"github.com/gofiber/fiber/v2"
)

// allowedAlertStatuses lists the accepted alert statuses
var allowedAlertStatuses = map[string]bool{
	"PENDING":   true,
	"TRIGGERED": true,
	"RESOLVED":  true,
	"CANCELLED": true,
}

// CreateAlertRequest is the payload for creating an alert
type CreateAlertRequest struct {
	ConfigID int `json:"config_id"`
}

// UpdateAlertRequest is the payload for updating an alert
type UpdateAlertRequest struct {
	Status string `json:"status"`
}

// AlertResponse is an alert returned by the API
type AlertResponse struct {
	AlertID   int    `json:"alert_id"`
	Timestamp string `json:"timestamp"`
	Status    string `json:"status"`
	UserID    int    `json:"user_id"`
	ConfigID  int    `json:"config_id"`
}

// RegisterAlertRoutes registers all alert endpoints
func RegisterAlertRoutes(router fiber.Router, db *sql.DB, keyMiddleware fiber.Handler) {
	router.Post("/alerts", keyMiddleware, ProtectedRoute(), createAlert(db))
	router.Get("/alerts", keyMiddleware, ProtectedRoute(), listAlerts(db))
	router.Get("/alerts/:id", keyMiddleware, ProtectedRoute(), getAlert(db))
	router.Put("/alerts/:id", keyMiddleware, ProtectedRoute(), updateAlert(db))
	router.Delete("/alerts/:id", keyMiddleware, ProtectedRoute(), deleteAlert(db))
}

// POST /api/v1/alerts — Creates an alert owned by the authenticated user
func createAlert(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)

		var req CreateAlertRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		if req.ConfigID <= 0 {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "config_id requis"})
		}

		// The referenced configuration must exist (FK config_id NOT NULL)
		var configID int
		err := db.QueryRow(`SELECT config_id FROM configurations WHERE config_id = ?`, req.ConfigID).Scan(&configID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Configuration non trouvée"})
			}
			log.Printf("Erreur SQL vérification configuration: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		result, err := db.Exec(
			`INSERT INTO alerts (user_id, config_id) VALUES (?, ?)`,
			userID, req.ConfigID,
		)
		if err != nil {
			log.Printf("Erreur SQL INSERT alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer l'alerte"})
		}

		newID, _ := result.LastInsertId()

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":  "Alerte créée avec succès",
			"alert_id": newID,
		})
	}
}

// GET /api/v1/alerts — Lists the alerts of the authenticated user
func listAlerts(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)

		query := `SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE user_id = ? ORDER BY alert_id DESC`
		rows, err := db.Query(query, userID)
		if err != nil {
			log.Printf("Erreur SQL listAlerts: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer rows.Close()

		alerts := []AlertResponse{}
		for rows.Next() {
			var (
				alert AlertResponse
				ts    sql.NullTime
			)
			if err := rows.Scan(&alert.AlertID, &ts, &alert.Status, &alert.UserID, &alert.ConfigID); err != nil {
				log.Printf("Erreur scan listAlerts: %v", err)
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
			}
			if ts.Valid {
				alert.Timestamp = ts.Time.Format("2006-01-02 15:04:05")
			}
			alerts = append(alerts, alert)
		}
		if err := rows.Err(); err != nil {
			log.Printf("Erreur rows listAlerts: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"count": len(alerts),
			"data":  alerts,
		})
	}
}

// GET /api/v1/alerts/:id — Returns an alert by its ID (owner only)
func getAlert(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		userID := getCurrentUserID(c)

		var (
			alert   AlertResponse
			ownerID int
			ts      sql.NullTime
		)
		query := `SELECT alert_id, timestamp, status, user_id, config_id FROM alerts WHERE alert_id = ?`
		err = db.QueryRow(query, id).Scan(&alert.AlertID, &ts, &alert.Status, &ownerID, &alert.ConfigID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Alerte non trouvée"})
			}
			log.Printf("Erreur SQL getAlert: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		if ownerID != userID {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Cette alerte ne vous appartient pas"})
		}

		alert.UserID = ownerID
		if ts.Valid {
			alert.Timestamp = ts.Time.Format("2006-01-02 15:04:05")
		}

		return c.Status(fiber.StatusOK).JSON(alert)
	}
}

// PUT /api/v1/alerts/:id — Updates an alert status (owner only)
func updateAlert(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		var req UpdateAlertRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		if !allowedAlertStatuses[req.Status] {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Statut invalide"})
		}

		userID := getCurrentUserID(c)

		if code, msg := checkAlertOwnership(db, id, userID); code != 0 {
			return c.Status(code).JSON(fiber.Map{"error": msg})
		}

		// No RowsAffected check here: MySQL reports 0 when the status is left
		// unchanged, which must NOT be mistaken for a 404. Existence is already
		// guaranteed by the ownership check above.
		if _, err := db.Exec(`UPDATE alerts SET status = ? WHERE alert_id = ?`, req.Status, id); err != nil {
			log.Printf("Erreur SQL UPDATE alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de mettre à jour l'alerte"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Statut de l'alerte mis à jour"})
	}
}

// DELETE /api/v1/alerts/:id — Deletes an alert (owner only)
func deleteAlert(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		userID := getCurrentUserID(c)

		if code, msg := checkAlertOwnership(db, id, userID); code != 0 {
			return c.Status(code).JSON(fiber.Map{"error": msg})
		}

		if _, err := db.Exec(`DELETE FROM alerts WHERE alert_id = ?`, id); err != nil {
			log.Printf("Erreur SQL DELETE alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur lors de la suppression de l'alerte"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Alerte supprimée avec succès"})
	}
}

// checkAlertOwnership verifies that the alert exists and belongs to userID.
// It returns (0, "") on success, otherwise the HTTP status and the JSON error message.
func checkAlertOwnership(db *sql.DB, alertID, userID int) (int, string) {
	var ownerID int
	err := db.QueryRow(`SELECT user_id FROM alerts WHERE alert_id = ?`, alertID).Scan(&ownerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fiber.StatusNotFound, "Alerte non trouvée"
		}
		log.Printf("Erreur SQL vérification alerte: %v", err)
		return fiber.StatusInternalServerError, "Erreur serveur"
	}

	if ownerID != userID {
		return fiber.StatusForbidden, "Cette alerte ne vous appartient pas"
	}

	return 0, ""
}
