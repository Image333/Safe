package routes

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"strconv"
	"strings"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

var allowedAlertStatuses = map[string]bool{
	"PENDING":   true,
	"TRIGGERED": true,
	"RESOLVED":  true,
	"CANCELLED": true,
}

type CreateAlertRequest struct {
	ConfigID int `json:"config_id"`
}

type UpdateAlertRequest struct {
	Status string `json:"status"`
}

type AlertResponse struct {
	AlertID   int    `json:"alert_id"`
	Timestamp string `json:"timestamp"`
	Status    string `json:"status"`
	UserID    int    `json:"user_id"`
	ConfigID  int    `json:"config_id"`
}

type NotifyResult struct {
	ContactID      int    `json:"contact_id"`
	ContactName    string `json:"contact_name"`
	Status         string `json:"status"` // sent | not_linked | error
	Channel        string `json:"channel,omitempty"`
	Error          string `json:"error,omitempty"`
}

// RegisterAlertRoutes registers alert endpoints with Telegram fan-out on create.
func RegisterAlertRoutes(router fiber.Router, db *sql.DB, tg *telegram.Service) {
	router.Post("/alerts", ProtectedRoute(), createAlert(db, tg))
	router.Get("/alerts", ProtectedRoute(), listAlerts(db))
	router.Get("/alerts/:id", ProtectedRoute(), getAlert(db))
	router.Put("/alerts/:id", ProtectedRoute(), updateAlert(db))
	router.Delete("/alerts/:id", ProtectedRoute(), deleteAlert(db))
}

func createAlert(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		if userID == 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Utilisateur non authentifié"})
		}

		var req CreateAlertRequest
		_ = c.BodyParser(&req)

		configID, err := resolveConfigID(db, userID, req.ConfigID)
		if err != nil {
			log.Printf("resolveConfigID: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de résoudre la configuration"})
		}

		result, err := db.Exec(
			`INSERT INTO alerts (user_id, config_id, status) VALUES (?, ?, 'TRIGGERED')`,
			userID, configID,
		)
		if err != nil {
			log.Printf("Erreur SQL INSERT alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer l'alerte"})
		}
		alertID, _ := result.LastInsertId()

		userName := loadUserDisplayName(db, userID)
		notifications := notifyTrustedContacts(db, tg, userID, userName, int(alertID))

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":       "Alerte créée avec succès",
			"alert_id":      alertID,
			"notifications": notifications,
		})
	}
}

func resolveConfigID(db *sql.DB, userID, requested int) (int, error) {
	if requested > 0 {
		var id int
		err := db.QueryRow(`SELECT config_id FROM configurations WHERE config_id = ?`, requested).Scan(&id)
		if err == nil {
			return id, nil
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return 0, err
		}
	}

	var userConfig sql.NullInt64
	err := db.QueryRow(`SELECT config_id FROM users WHERE user_id = ?`, userID).Scan(&userConfig)
	if err != nil {
		return 0, err
	}
	if userConfig.Valid && userConfig.Int64 > 0 {
		return int(userConfig.Int64), nil
	}

	res, err := db.Exec(
		`INSERT INTO configurations (alert_word, app_disguise) VALUES (?, ?)`,
		"aide", "calculator",
	)
	if err != nil {
		return 0, err
	}
	newID, _ := res.LastInsertId()
	_, _ = db.Exec(`UPDATE users SET config_id = ? WHERE user_id = ?`, newID, userID)
	return int(newID), nil
}

func loadUserDisplayName(db *sql.DB, userID int) string {
	var firstname, name string
	err := db.QueryRow(`SELECT firstname, name FROM users WHERE user_id = ?`, userID).Scan(&firstname, &name)
	if err != nil {
		return "Un utilisateur SAFE"
	}
	full := strings.TrimSpace(firstname + " " + name)
	if full == "" {
		return "Un utilisateur SAFE"
	}
	return full
}

func notifyTrustedContacts(db *sql.DB, tg *telegram.Service, userID int, userName string, alertID int) []NotifyResult {
	rows, err := db.Query(`
		SELECT c.contact_id, c.contact_name, c.telegram_chat_id, c.email, c.invite_token
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ?`, userID)
	if err != nil {
		log.Printf("notifyTrustedContacts query: %v", err)
		return []NotifyResult{}
	}
	defer rows.Close()

	msg := fmt.Sprintf(
		"🚨 <b>Alerte SAFE</b>\n\n%s a déclenché une alerte d'urgence.\nAlerte #%d\n\n🎤 Un enregistrement audio suivra dès qu'il sera disponible.",
		userName, alertID,
	)

	results := []NotifyResult{}
	for rows.Next() {
		var (
			contactID int
			name      string
			chatID    sql.NullInt64
			email     sql.NullString
			token     sql.NullString
		)
		if err := rows.Scan(&contactID, &name, &chatID, &email, &token); err != nil {
			log.Printf("notify scan: %v", err)
			continue
		}

		r := NotifyResult{
			ContactID:   contactID,
			ContactName: name,
		}

		if chatID.Valid && tg != nil {
			if err := tg.SendMessage(chatID.Int64, msg); err != nil {
				r.Status = "error"
				r.Channel = "telegram"
				r.Error = err.Error()
			} else {
				r.Status = "sent"
				r.Channel = "telegram"
			}
		} else if chatID.Valid && tg == nil {
			r.Status = "error"
			r.Channel = "telegram"
			r.Error = "telegram non configuré"
		} else {
			r.Status = "not_linked"
		}
		results = append(results, r)
	}
	return results
}

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

		if _, err := db.Exec(`UPDATE alerts SET status = ? WHERE alert_id = ?`, req.Status, id); err != nil {
			log.Printf("Erreur SQL UPDATE alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de mettre à jour l'alerte"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Statut de l'alerte mis à jour"})
	}
}

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
