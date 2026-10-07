package routes

import (
	"database/sql"
	"fmt"
	"log"
	"strconv"
	"strings"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

type CreateAudioRequest struct {
	BlobURL  string `json:"blob_url"`
	Duration int    `json:"duration"`
	Format   string `json:"format"`
}

// RegisterAudioRoutes registers audio attach + list endpoints.
func RegisterAudioRoutes(router fiber.Router, db *sql.DB, tg *telegram.Service) {
	router.Post("/alerts/:id/audio", ProtectedRoute(), createAlertAudio(db, tg))
	router.Get("/me/audio", ProtectedRoute(), listMyAudio(db))
}

func createAlertAudio(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		if userID == 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Utilisateur non authentifié"})
		}

		alertID, err := strconv.Atoi(c.Params("id"))
		if err != nil || alertID <= 0 {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		if code, msg := checkAlertOwnership(db, alertID, userID); code != 0 {
			return c.Status(code).JSON(fiber.Map{"error": msg})
		}

		var req CreateAudioRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		req.BlobURL = strings.TrimSpace(req.BlobURL)
		req.Format = strings.TrimSpace(strings.ToLower(req.Format))
		if req.BlobURL == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "blob_url requis"})
		}
		if req.Duration <= 0 {
			req.Duration = 1
		}
		if req.Format == "" {
			req.Format = "m4a"
		}

		result, err := db.Exec(
			`INSERT INTO audio_records (blob_url, duration, format, alert_id) VALUES (?, ?, ?, ?)`,
			req.BlobURL, req.Duration, req.Format, alertID,
		)
		if err != nil {
			if isDuplicateKey(err) {
				return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "Un audio est déjà lié à cette alerte"})
			}
			log.Printf("Erreur SQL INSERT audio: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible d'enregistrer l'audio"})
		}
		audioID, _ := result.LastInsertId()

		userName := loadUserDisplayName(db, userID)
		go notifyTrustedContactsAudio(db, tg, userID, userName, alertID, req.BlobURL)

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":  "Enregistrement audio créé",
			"audio_id": audioID,
		})
	}
}

func listMyAudio(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		if userID == 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Utilisateur non authentifié"})
		}

		rows, err := db.Query(`
			SELECT ar.audio_id, ar.blob_url, ar.duration, ar.format, ar.alert_id,
			       a.timestamp, a.status
			FROM audio_records ar
			INNER JOIN alerts a ON a.alert_id = ar.alert_id
			WHERE a.user_id = ?
			ORDER BY ar.audio_id DESC`, userID)
		if err != nil {
			log.Printf("Erreur SQL listMyAudio: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer rows.Close()

		out := make([]fiber.Map, 0)
		for rows.Next() {
			var (
				audioID, duration, alertID int
				blobURL, format, status    string
				ts                         sql.NullTime
			)
			if err := rows.Scan(&audioID, &blobURL, &duration, &format, &alertID, &ts, &status); err != nil {
				log.Printf("Erreur scan listMyAudio: %v", err)
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
			}
			item := fiber.Map{
				"audio_id":     audioID,
				"blob_url":     blobURL,
				"duration":     duration,
				"format":       format,
				"alert_id":     alertID,
				"alert_status": status,
			}
			if ts.Valid {
				item["alert_timestamp"] = ts.Time.Format("2006-01-02 15:04:05")
			}
			out = append(out, item)
		}
		if err := rows.Err(); err != nil {
			log.Printf("Erreur rows listMyAudio: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		return c.Status(fiber.StatusOK).JSON(out)
	}
}

func notifyTrustedContactsAudio(db *sql.DB, tg *telegram.Service, userID int, userName string, alertID int, blobURL string) {
	rows, err := db.Query(`
		SELECT c.contact_id, c.contact_name, c.telegram_chat_id
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ? AND c.telegram_chat_id IS NOT NULL`, userID)
	if err != nil {
		log.Printf("notifyTrustedContactsAudio query: %v", err)
		return
	}
	defer rows.Close()

	caption := fmt.Sprintf(
		"🎤 <b>Enregistrement d'urgence</b>\n\n%s — alerte #%d",
		userName, alertID,
	)

	for rows.Next() {
		var (
			contactID int
			name      string
			chatID    sql.NullInt64
		)
		if err := rows.Scan(&contactID, &name, &chatID); err != nil {
			log.Printf("notify audio scan: %v", err)
			continue
		}
		if !chatID.Valid || tg == nil {
			continue
		}
		if err := tg.SendAudio(chatID.Int64, blobURL, caption); err != nil {
			log.Printf("telegram SendAudio contact=%d (%s): %v", contactID, name, err)
		} else {
			log.Printf("telegram SendAudio OK contact=%d (%s) alert=#%d", contactID, name, alertID)
		}
	}
}

func isDuplicateKey(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "Duplicate entry")
}
