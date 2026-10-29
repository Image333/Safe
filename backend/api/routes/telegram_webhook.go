package routes

import (
	"database/sql"
	"log"
	"os"
	"strings"
	"time"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

// TelegramUpdate is a minimal Bot API Update payload.
type TelegramUpdate struct {
	UpdateID int `json:"update_id"`
	Message  *struct {
		MessageID int    `json:"message_id"`
		Text      string `json:"text"`
		Chat      struct {
			ID int64 `json:"id"`
		} `json:"chat"`
		From *struct {
			ID int64 `json:"id"`
		} `json:"from"`
		Contact *struct {
			PhoneNumber string `json:"phone_number"`
			UserID      int64  `json:"user_id"`
		} `json:"contact"`
	} `json:"message"`
}

// RegisterTelegramRoutes registers the Telegram webhook (no JWT / X-API-Key —
// verified via mandatory secret header).
func RegisterTelegramRoutes(router fiber.Router, db *sql.DB, tg *telegram.Service) {
	router.Post("/telegram/webhook", telegramWebhook(db, tg))
}

func telegramWebhook(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		secret := os.Getenv("TELEGRAM_WEBHOOK_SECRET")
		if secret == "" {
			log.Printf("telegram webhook: TELEGRAM_WEBHOOK_SECRET is not set")
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "webhook secret non configuré"})
		}
		got := c.Get("X-Telegram-Bot-Api-Secret-Token")
		if got != secret {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "secret invalide"})
		}

		var update TelegramUpdate
		if err := c.BodyParser(&update); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "payload invalide"})
		}

		if update.Message == nil {
			return c.SendStatus(fiber.StatusOK)
		}

		chatID := update.Message.Chat.ID
		text := strings.TrimSpace(update.Message.Text)

		// /start <token>
		if strings.HasPrefix(text, "/start") {
			parts := strings.Fields(text)
			token := ""
			if len(parts) >= 2 {
				token = parts[1]
			}
			if token != "" {
				ok, err := linkContactByInviteToken(db, token, chatID)
				if err != nil {
					log.Printf("telegram link token: %v", err)
					return c.SendStatus(fiber.StatusOK)
				}
				if ok {
					log.Printf("telegram: contact linked via invite_token (chat_id=%d)", chatID)
					if tg != nil {
						_ = tg.SendMessage(chatID, "✅ Compte lié à SAFE. Vous recevrez les alertes d'urgence ici.")
					}
					return c.SendStatus(fiber.StatusOK)
				}
				log.Printf("telegram: unknown or already-linked invite_token %q (chat_id=%d)", token, chatID)
			}
			// No/invalid token → ask to share phone
			if tg != nil {
				_ = tg.SendContactRequestKeyboard(
					chatID,
					"Bienvenue sur SAFE. Pour lier votre compte, partagez votre numéro de téléphone (celui enregistré comme contact de confiance).",
				)
			}
			return c.SendStatus(fiber.StatusOK)
		}

		// Contact shared via request_contact — require proof of possession.
		if update.Message.Contact != nil {
			if update.Message.From == nil ||
				update.Message.Contact.UserID == 0 ||
				update.Message.Contact.UserID != update.Message.From.ID {
				log.Printf("telegram: rejected phone share without possession proof (chat_id=%d)", chatID)
				if tg != nil {
					_ = tg.RemoveKeyboard(chatID, "❌ Partagez votre propre numéro via le bouton Telegram (pas un contact de l'annuaire).")
				}
				return c.SendStatus(fiber.StatusOK)
			}

			phone := update.Message.Contact.PhoneNumber
			ok, err := linkContactByPhone(db, phone, chatID)
			if err != nil {
				log.Printf("telegram link phone: %v", err)
				return c.SendStatus(fiber.StatusOK)
			}
			if tg != nil {
				if ok {
					_ = tg.RemoveKeyboard(chatID, "✅ Numéro reconnu. Vous êtes lié à SAFE et recevrez les alertes ici.")
				} else {
					_ = tg.RemoveKeyboard(chatID, "❌ Aucun contact SAFE ne correspond à ce numéro. Demandez un nouveau lien d'invitation.")
				}
			}
			return c.SendStatus(fiber.StatusOK)
		}

		return c.SendStatus(fiber.StatusOK)
	}
}

func linkContactByInviteToken(db *sql.DB, token string, chatID int64) (bool, error) {
	res, err := db.Exec(
		`UPDATE contacts SET telegram_chat_id = ?, telegram_linked_at = ?
		 WHERE invite_token = ? AND telegram_chat_id IS NULL`,
		chatID, time.Now().UTC(), token,
	)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func linkContactByPhone(db *sql.DB, phone string, chatID int64) (bool, error) {
	// Only unlinked contacts — avoids full-table scan of already-linked rows
	// and prevents hijacking an existing telegram_chat_id.
	rows, err := db.Query(
		`SELECT contact_id, phone_number FROM contacts WHERE telegram_chat_id IS NULL`,
	)
	if err != nil {
		return false, err
	}
	defer rows.Close()

	var matchID int
	found := false
	for rows.Next() {
		var (
			id     int
			stored string
		)
		if err := rows.Scan(&id, &stored); err != nil {
			return false, err
		}
		if PhonesMatch(phone, stored) {
			matchID = id
			found = true
			break
		}
	}
	if err := rows.Err(); err != nil {
		return false, err
	}
	if !found {
		return false, nil
	}

	res, err := db.Exec(
		`UPDATE contacts SET telegram_chat_id = ?, telegram_linked_at = ?
		 WHERE contact_id = ? AND telegram_chat_id IS NULL`,
		chatID, time.Now().UTC(), matchID,
	)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}
