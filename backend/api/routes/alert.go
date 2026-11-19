package routes

import (
	"database/sql"
	"errors"
	"fmt"
	"html"
	"log"
	"strconv"
	"strings"
	"time"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

// allowedAlertStatuses lists the accepted alert statuses
var allowedAlertStatuses = map[string]bool{
	"PENDING":   true,
	"TRIGGERED": true,
	"RESOLVED":  true,
	"CANCELLED": true,
}

var parisLocation *time.Location

func init() {
	loc, err := time.LoadLocation("Europe/Paris")
	if err != nil {
		parisLocation = time.FixedZone("CET", 3600)
		return
	}
	parisLocation = loc
}

// CreateAlertRequest is the payload for creating an alert
type CreateAlertRequest struct {
	ConfigID  int      `json:"config_id"`
	Latitude  *float64 `json:"latitude"`
	Longitude *float64 `json:"longitude"`
	Trigger   string   `json:"trigger"`
}

// alertNotifyOpts carries optional context for the Telegram fan-out.
type alertNotifyOpts struct {
	Trigger   string
	Latitude  *float64
	Longitude *float64
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

// NotifyResult is the Telegram delivery outcome for one trusted contact
type NotifyResult struct {
	ContactID   int    `json:"contact_id"`
	ContactName string `json:"contact_name"`
	Status      string `json:"status"` // queued | not_linked | error
	Channel     string `json:"channel,omitempty"`
	Error       string `json:"error,omitempty"`
}

// RegisterAlertRoutes registers all alert endpoints
func RegisterAlertRoutes(router fiber.Router, db *sql.DB, keyMiddleware fiber.Handler, tg *telegram.Service) *Notifier {
	var notifier *Notifier
	if tg != nil {
		notifier = NewNotifier(tg, alertNotifyWorkers, alertNotifyQueue, alertNotifyAttempts)
	}

	router.Post("/alerts", keyMiddleware, ProtectedRoute(), createAlert(db, notifier))
	router.Get("/alerts", keyMiddleware, ProtectedRoute(), listAlerts(db))
	router.Get("/alerts/:id", keyMiddleware, ProtectedRoute(), getAlert(db))
	router.Put("/alerts/:id", keyMiddleware, ProtectedRoute(), updateAlert(db))
	router.Delete("/alerts/:id", keyMiddleware, ProtectedRoute(), deleteAlert(db))

	return notifier
}

// POST /api/v1/alerts — Creates an alert owned by the authenticated user,
// then notifies the trusted contacts linked to Telegram
func createAlert(db *sql.DB, notifier *Notifier) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		if userID == 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Utilisateur non authentifié"})
		}

		var req CreateAlertRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		// config_id is optional: falls back to the user's configuration (FK config_id NOT NULL)
		configID, err := resolveConfigID(db, userID, req.ConfigID)
		if err != nil {
			log.Printf("resolveConfigID: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de résoudre la configuration"})
		}

		opts := alertNotifyOpts{Trigger: strings.TrimSpace(strings.ToLower(req.Trigger))}
		if validCoords(req.Latitude, req.Longitude) {
			opts.Latitude = req.Latitude
			opts.Longitude = req.Longitude
		}

		// Alert and geolocation are inserted in the same transaction
		alertID, err := insertAlertWithGeolocation(db, userID, configID, opts)
		if err != nil {
			log.Printf("Erreur SQL INSERT alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer l'alerte"})
		}

		userName := loadUserDisplayName(db, userID)
		job, notifications, err := buildAlertNotification(db, userID, userName, int(alertID), opts)
		if err != nil {
			log.Printf("buildAlertNotification: %v", err)
			notifications = []NotifyResult{}
		}
		switch {
		case len(job.recipients) == 0:
			// Nothing linked: every contact is already reported as not_linked.
		case notifier == nil:
			notifications = markUndelivered(notifications, "telegram non configuré")
		case !notifier.enqueue(job):
			log.Printf("File d'envoi Telegram pleine, alerte=%d", alertID)
			notifications = markUndelivered(notifications, "file d'envoi saturée")
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":       "Alerte créée avec succès",
			"alert_id":      alertID,
			"notifications": notifications,
		})
	}
}

// insertAlertWithGeolocation creates the alert (default status PENDING) and,
// when coordinates are provided, its geolocation row
func insertAlertWithGeolocation(db *sql.DB, userID, configID int, opts alertNotifyOpts) (int64, error) {
	tx, err := db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	result, err := tx.Exec(
		`INSERT INTO alerts (user_id, config_id) VALUES (?, ?)`,
		userID, configID,
	)
	if err != nil {
		return 0, err
	}
	alertID, err := result.LastInsertId()
	if err != nil {
		return 0, err
	}

	if validCoords(opts.Latitude, opts.Longitude) {
		if _, err := tx.Exec(
			`INSERT INTO geolocations (latitude, longitude, alert_id) VALUES (?, ?, ?)`,
			*opts.Latitude, *opts.Longitude, alertID,
		); err != nil {
			return 0, err
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return alertID, nil
}

func validCoords(lat, lng *float64) bool {
	if lat == nil || lng == nil {
		return false
	}
	return *lat >= -90 && *lat <= 90 && *lng >= -180 && *lng <= 180
}

func triggerLabel(trigger string) string {
	switch strings.ToLower(strings.TrimSpace(trigger)) {
	case "volume":
		return "Volume"
	case "voice":
		return "Mot-clé vocal"
	case "sos":
		return "Bouton SOS"
	default:
		return "Alerte d'urgence"
	}
}

// buildAlertTelegramMessage builds the HTML (parse_mode) alert text.
// userName is user-controlled and must be escaped.
func buildAlertTelegramMessage(userName string, opts alertNotifyOpts) string {
	var b strings.Builder
	b.WriteString("🚨 <b>URGENCE — SAFE</b>\n\n")
	b.WriteString(fmt.Sprintf("%s a besoin d'aide maintenant.\n", html.EscapeString(userName)))
	b.WriteString(fmt.Sprintf("📅 %s\n", time.Now().In(parisLocation).Format("02/01/2006 · 15:04")))
	b.WriteString(fmt.Sprintf("⚡ Déclenchement : %s\n", triggerLabel(opts.Trigger)))
	if validCoords(opts.Latitude, opts.Longitude) {
		b.WriteString(fmt.Sprintf(
			"\n📍 Ouvrir la position :\nhttps://maps.google.com/?q=%g,%g\n",
			*opts.Latitude, *opts.Longitude,
		))
	}
	b.WriteString("\n🎤 Un enregistrement audio suivra.")
	return b.String()
}

func resolveConfigID(db *sql.DB, userID, requested int) (int, error) {
	var userConfig sql.NullInt64
	if err := db.QueryRow(`SELECT config_id FROM users WHERE user_id = ?`, userID).Scan(&userConfig); err != nil {
		return 0, err
	}

	// Only the configuration attached to this user may be referenced: a config_id
	// from another account is ignored instead of being trusted.
	if requested > 0 && userConfig.Valid && int(userConfig.Int64) == requested {
		return requested, nil
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
