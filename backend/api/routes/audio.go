package routes

import (
	"database/sql"
	"errors"
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

// RegisterAudioRoutes enregistre tous les endpoints audio
// tg peut être nil : le clip n'est alors pas transmis aux contacts Telegram
func RegisterAudioRoutes(router fiber.Router, db *sql.DB, keyMiddleware fiber.Handler, tg *telegram.Service) *Notifier {
	var notifier *Notifier
	if tg != nil {
		notifier = NewNotifier(tg, audioNotifyWorkers, audioNotifyQueue, audioNotifyAttempts)
	}

	router.Get("/audio/:id", keyMiddleware, ProtectedRoute(), getAudioByID(db))
	router.Get("/alerts/:alertId/audio", keyMiddleware, ProtectedRoute(), getAudioByAlert(db))
	router.Get("/me/audio", keyMiddleware, ProtectedRoute(), getMyAudio(db))
	router.Post("/alerts/:alertId/audio", keyMiddleware, ProtectedRoute(), createAudio(db, notifier))

	return notifier
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
func createAudio(db *sql.DB, notifier *Notifier) fiber.Handler {
	return func(c *fiber.Ctx) error {
		alertID, err := strconv.Atoi(c.Params("alertId"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID alerte invalide"})
		}

		userID := getCurrentUserID(c)

		// Parser le body en premier (avant les requêtes DB)
		var req CreateAudioRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		// Validation
		switch {
		case req.BlobURL == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "blob_url requis"})
		case req.Duration <= 0:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "duration doit être positif"})
		case req.Format == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "format requis"})
		}

		// Vérifier que l'alerte existe et appartient à l'utilisateur
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

		// Vérifier qu'il n'y a pas déjà un audio pour cette alerte (UNIQUE)
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

		// Insérer
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

		// Transmettre le clip aux contacts Telegram liés (envoi en arrière-plan,
		// les données sont lues en base avant la réponse)
		if notifier != nil {
			job, err := buildAudioJob(db, userID, alertID, req.BlobURL)
			if err != nil {
				log.Printf("Erreur préparation envoi audio Telegram alerte=%d: %v", alertID, err)
			} else if len(job.recipients) > 0 && !notifier.enqueue(job) {
				recordTelegramSend("audio", "dropped")
				log.Printf("File d'envoi audio Telegram pleine, clip non transmis alerte=%d", alertID)
			}
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message":  "Enregistrement audio créé avec succès",
			"audio_id": newID,
		})
	}
}

// getCurrentUserID extrait le user_id du contexte JWT
// Retourne un int (le JWT stocke les nombres en float64, on convertit)
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
