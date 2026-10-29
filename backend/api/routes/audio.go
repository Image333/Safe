package routes

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"strconv"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

// AudioResponse représente un enregistrement audio avec les infos de son alerte
type AudioResponse struct {
	AudioID        int    `json:"audio_id"`
	BlobURL        string `json:"blob_url"`
	Duration       int    `json:"duration"`
	Format         string `json:"format"`
	AlertID        int    `json:"alert_id"`
	AlertTimestamp string `json:"alert_timestamp"`
	AlertStatus    string `json:"alert_status"`
}

// CreateAudioRequest représente la requête de création d'un enregistrement audio
type CreateAudioRequest struct {
	BlobURL  string `json:"blob_url"`
	Duration int    `json:"duration"`
	Format   string `json:"format"`
}

// RegisterAudioRoutes registers all audio endpoints (CRUD + Telegram fan-out on create).
func RegisterAudioRoutes(router fiber.Router, db *sql.DB, keyMiddleware fiber.Handler, tg *telegram.Service) {
	router.Get("/audio/:id", keyMiddleware, ProtectedRoute(), getAudioByID(db))
	router.Get("/alerts/:alertId/audio", keyMiddleware, ProtectedRoute(), getAudioByAlert(db))
	router.Get("/me/audio", keyMiddleware, ProtectedRoute(), getMyAudio(db))
	router.Post("/alerts/:alertId/audio", keyMiddleware, ProtectedRoute(), createAudio(db, tg))
}

// GET /api/v1/audio/:id — Récupère un enregistrement audio par son ID
func getAudioByID(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		audioID, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID audio invalide"})
		}

		userID := getCurrentUserID(c)

		query := `
			SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id,
			       al.timestamp, al.status
			FROM audio_records a
			JOIN alerts al ON a.alert_id = al.alert_id
			WHERE a.audio_id = ? AND al.user_id = ?
		`

		var audio AudioResponse
		var timestamp sql.NullTime

		err = db.QueryRow(query, audioID, userID).Scan(
			&audio.AudioID,
			&audio.BlobURL,
			&audio.Duration,
			&audio.Format,
			&audio.AlertID,
			&timestamp,
			&audio.AlertStatus,
		)

		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Enregistrement audio non trouvé"})
			}
			log.Printf("Erreur SQL getAudioByID: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		if timestamp.Valid {
			audio.AlertTimestamp = timestamp.Time.Format("2006-01-02 15:04:05")
		}

		return c.Status(fiber.StatusOK).JSON(audio)
	}
}

// GET /api/v1/alerts/:alertId/audio — Récupère l'audio lié à une alerte
func getAudioByAlert(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		alertID, err := strconv.Atoi(c.Params("alertId"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		userID := getCurrentUserID(c)

		query := `
			SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id,
			       al.timestamp, al.status
			FROM audio_records a
			JOIN alerts al ON a.alert_id = al.alert_id
			WHERE a.alert_id = ? AND al.user_id = ?
		`

		var audio AudioResponse
		var timestamp sql.NullTime

		err = db.QueryRow(query, alertID, userID).Scan(
			&audio.AudioID,
			&audio.BlobURL,
			&audio.Duration,
			&audio.Format,
			&audio.AlertID,
			&timestamp,
			&audio.AlertStatus,
		)

		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Aucun enregistrement audio pour cette alerte"})
			}
			log.Printf("Erreur SQL getAudioByAlert: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		if timestamp.Valid {
			audio.AlertTimestamp = timestamp.Time.Format("2006-01-02 15:04:05")
		}

		return c.Status(fiber.StatusOK).JSON(audio)
	}
}

// GET /api/v1/me/audio — Récupère tous les enregistrements audio de l'utilisateur connecté
func getMyAudio(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)

		query := `
			SELECT a.audio_id, a.blob_url, a.duration, a.format, a.alert_id,
			       al.timestamp, al.status
			FROM audio_records a
			JOIN alerts al ON a.alert_id = al.alert_id
			WHERE al.user_id = ?
			ORDER BY al.timestamp DESC
		`

		rows, err := db.Query(query, userID)
		if err != nil {
			log.Printf("Erreur SQL getMyAudio: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer rows.Close()

		var audios []AudioResponse

		for rows.Next() {
			var audio AudioResponse
			var timestamp sql.NullTime

			err := rows.Scan(
				&audio.AudioID,
				&audio.BlobURL,
				&audio.Duration,
				&audio.Format,
				&audio.AlertID,
				&timestamp,
				&audio.AlertStatus,
			)
			if err != nil {
				log.Printf("Erreur scan getMyAudio: %v", err)
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
			}

			if timestamp.Valid {
				audio.AlertTimestamp = timestamp.Time.Format("2006-01-02 15:04:05")
			}

			audios = append(audios, audio)
		}

		if audios == nil {
			audios = []AudioResponse{}
		}

		return c.Status(fiber.StatusOK).JSON(audios)
	}
}

// POST /api/v1/alerts/:alertId/audio — Ajoute un enregistrement audio à une alerte
func createAudio(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		alertID, err := strconv.Atoi(c.Params("alertId"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		userID := getCurrentUserID(c)

		var req CreateAudioRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		switch {
		case req.BlobURL == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "blob_url requis"})
		case req.Duration <= 0:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "duration doit être positif"})
		case req.Format == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "format requis"})
		}

		var ownerID int
		checkQuery := `SELECT user_id FROM alerts WHERE alert_id = ?`
		err = db.QueryRow(checkQuery, alertID).Scan(&ownerID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Alerte non trouvée"})
			}
			log.Printf("Erreur SQL vérification alerte: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		if ownerID != userID {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Cette alerte ne vous appartient pas"})
		}

		var existingCount int
		countQuery := `SELECT COUNT(*) FROM audio_records WHERE alert_id = ?`
		err = db.QueryRow(countQuery, alertID).Scan(&existingCount)
		if err != nil {
			log.Printf("Erreur SQL vérification audio existant: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		if existingCount > 0 {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "Un enregistrement audio existe déjà pour cette alerte"})
		}

		insertQuery := `
			INSERT INTO audio_records (blob_url, duration, format, alert_id)
			VALUES (?, ?, ?, ?)
		`

		result, err := db.Exec(insertQuery, req.BlobURL, req.Duration, req.Format, alertID)
		if err != nil {
			log.Printf("Erreur SQL INSERT audio: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer l'enregistrement audio"})
		}

		newID, _ := result.LastInsertId()

		// Fan-out audio clip to linked Telegram contacts (same behaviour as before main merge).
		if tg != nil {
			userName := loadUserDisplayName(db, userID)
			go notifyTrustedContactsAudio(db, tg, userID, userName, alertID, req.BlobURL)
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":  "Enregistrement audio créé avec succès",
			"audio_id": newID,
		})
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
