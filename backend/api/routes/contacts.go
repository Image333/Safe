package routes

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"gpe/telegram"

	"github.com/gofiber/fiber/v2"
)

var nonDigitRE = regexp.MustCompile(`\D+`)

type CreateContactRequest struct {
	ContactName  string  `json:"contact_name"`
	PhoneNumber  string  `json:"phone_number"`
	Email        *string `json:"email"`
	ContactType  string  `json:"contact_type"`
	PriorityOrder int    `json:"priority_order"`
}

type UpdateContactRequest struct {
	ContactName   *string `json:"contact_name"`
	PhoneNumber   *string `json:"phone_number"`
	Email         *string `json:"email"`
	ContactType   *string `json:"contact_type"`
	PriorityOrder *int    `json:"priority_order"`
}

type InviteEmailRequest struct {
	Email string `json:"email"`
}

type ContactResponse struct {
	ContactID         int     `json:"contact_id"`
	ContactName       string  `json:"contact_name"`
	PhoneNumber       string  `json:"phone_number"`
	Email             *string `json:"email"`
	ContactType       *string `json:"contact_type"`
	PriorityOrder     int     `json:"priority_order"`
	TelegramLinked    bool    `json:"telegram_linked"`
	TelegramLinkedAt  *string `json:"telegram_linked_at,omitempty"`
	InviteToken       string  `json:"invite_token"`
	InviteLink        string  `json:"invite_link"`
}

// RegisterContactRoutes registers trusted-contact endpoints.
func RegisterContactRoutes(router fiber.Router, db *sql.DB, tg *telegram.Service) {
	router.Post("/contacts", ProtectedRoute(), createContact(db, tg))
	router.Get("/contacts", ProtectedRoute(), listContacts(db, tg))
	router.Get("/contacts/:id", ProtectedRoute(), getContact(db, tg))
	router.Put("/contacts/:id", ProtectedRoute(), updateContact(db, tg))
	router.Delete("/contacts/:id", ProtectedRoute(), deleteContact(db))
	// Stub for a later SMTP phase — contract frozen.
	router.Post("/contacts/:id/invite/email", ProtectedRoute(), inviteContactByEmailStub())
}

func inviteContactByEmailStub() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Contract frozen for the next phase (SMTP + optional email upsert).
		var req InviteEmailRequest
		_ = c.BodyParser(&req)
		return c.Status(fiber.StatusNotImplemented).JSON(fiber.Map{
			"error":   "Envoi d'email d'invitation non encore disponible",
			"code":    "invite_email_not_implemented",
			"message": "Utilisez invite_link et copiez-le pour l'instant.",
		})
	}
}

func createContact(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		if userID == 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Utilisateur non authentifié"})
		}

		// JWT peut venir d'une autre DB (ex. cluster distant) alors que l'API locale est vide.
		var exists int
		if err := db.QueryRow(`SELECT 1 FROM users WHERE user_id = ?`, userID).Scan(&exists); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
					"error": "Session invalide pour cette API. Déconnectez-vous puis créez un compte / reconnectez-vous.",
					"code":  "user_not_found_on_this_api",
				})
			}
			log.Printf("Erreur SQL vérif user: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		var req CreateContactRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		req.ContactName = strings.TrimSpace(req.ContactName)
		req.PhoneNumber = strings.TrimSpace(req.PhoneNumber)
		if req.ContactName == "" || req.PhoneNumber == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "contact_name et phone_number requis"})
		}
		if req.PriorityOrder <= 0 {
			req.PriorityOrder = 1
		}

		var email any
		if req.Email != nil {
			e := strings.TrimSpace(*req.Email)
			if e == "" {
				email = nil
			} else {
				email = e
			}
		}

		token, err := generateInviteToken()
		if err != nil {
			log.Printf("Erreur génération invite_token: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		contactType := req.ContactType
		if contactType == "" {
			contactType = "trusted"
		}

		tx, err := db.Begin()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer tx.Rollback()

		result, err := tx.Exec(
			`INSERT INTO contacts (contact_name, phone_number, email, contact_type, priority_order, invite_token)
			 VALUES (?, ?, ?, ?, ?, ?)`,
			req.ContactName, req.PhoneNumber, email, contactType, req.PriorityOrder, token,
		)
		if err != nil {
			log.Printf("Erreur SQL INSERT contact: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de créer le contact"})
		}
		contactID, _ := result.LastInsertId()

		if _, err := tx.Exec(
			`INSERT INTO user_contacts (user_id, contact_id) VALUES (?, ?)`,
			userID, contactID,
		); err != nil {
			log.Printf("Erreur SQL INSERT user_contacts: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible d'associer le contact"})
		}

		if err := tx.Commit(); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		contact, err := fetchUserContact(db, tg, userID, int(contactID))
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Contact créé mais lecture impossible"})
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message": "Contact créé avec succès",
			"data":    contact,
		})
	}
}

func listContacts(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := getCurrentUserID(c)
		contacts, err := fetchUserContacts(db, tg, userID)
		if err != nil {
			log.Printf("Erreur listContacts: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"count": len(contacts),
			"data":  contacts,
		})
	}
}

func getContact(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID contact invalide"})
		}
		userID := getCurrentUserID(c)
		contact, err := fetchUserContact(db, tg, userID, id)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Contact non trouvé"})
			}
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		return c.Status(fiber.StatusOK).JSON(contact)
	}
}

func updateContact(db *sql.DB, tg *telegram.Service) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID contact invalide"})
		}
		userID := getCurrentUserID(c)

		if code, msg := checkContactOwnership(db, id, userID); code != 0 {
			return c.Status(code).JSON(fiber.Map{"error": msg})
		}

		var req UpdateContactRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Format JSON invalide"})
		}

		existing, err := fetchUserContact(db, tg, userID, id)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		name := existing.ContactName
		phone := existing.PhoneNumber
		email := existing.Email
		ctype := ""
		if existing.ContactType != nil {
			ctype = *existing.ContactType
		}
		priority := existing.PriorityOrder

		if req.ContactName != nil {
			name = strings.TrimSpace(*req.ContactName)
		}
		if req.PhoneNumber != nil {
			phone = strings.TrimSpace(*req.PhoneNumber)
		}
		if req.Email != nil {
			e := strings.TrimSpace(*req.Email)
			if e == "" {
				email = nil
			} else {
				email = &e
			}
		}
		if req.ContactType != nil {
			ctype = strings.TrimSpace(*req.ContactType)
		}
		if req.PriorityOrder != nil {
			priority = *req.PriorityOrder
		}
		if name == "" || phone == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "contact_name et phone_number requis"})
		}

		var emailVal any
		if email != nil {
			emailVal = *email
		}

		if _, err := db.Exec(
			`UPDATE contacts SET contact_name = ?, phone_number = ?, email = ?, contact_type = ?, priority_order = ?
			 WHERE contact_id = ?`,
			name, phone, emailVal, ctype, priority, id,
		); err != nil {
			log.Printf("Erreur SQL UPDATE contact: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Impossible de mettre à jour le contact"})
		}

		contact, err := fetchUserContact(db, tg, userID, id)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"message": "Contact mis à jour",
			"data":    contact,
		})
	}
}

func deleteContact(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID contact invalide"})
		}
		userID := getCurrentUserID(c)
		if code, msg := checkContactOwnership(db, id, userID); code != 0 {
			return c.Status(code).JSON(fiber.Map{"error": msg})
		}

		tx, err := db.Begin()
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		defer tx.Rollback()

		if _, err := tx.Exec(`DELETE FROM user_contacts WHERE user_id = ? AND contact_id = ?`, userID, id); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		if _, err := tx.Exec(`DELETE FROM contacts WHERE contact_id = ?`, id); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}
		if err := tx.Commit(); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Erreur serveur"})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{"message": "Contact supprimé"})
	}
}

func checkContactOwnership(db *sql.DB, contactID, userID int) (int, string) {
	var found int
	err := db.QueryRow(
		`SELECT 1 FROM user_contacts WHERE user_id = ? AND contact_id = ?`,
		userID, contactID,
	).Scan(&found)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fiber.StatusNotFound, "Contact non trouvé"
		}
		log.Printf("Erreur checkContactOwnership: %v", err)
		return fiber.StatusInternalServerError, "Erreur serveur"
	}
	return 0, ""
}

func fetchUserContacts(db *sql.DB, tg *telegram.Service, userID int) ([]ContactResponse, error) {
	rows, err := db.Query(`
		SELECT c.contact_id, c.contact_name, c.phone_number, c.email, c.contact_type, c.priority_order,
		       c.telegram_chat_id, c.invite_token, c.telegram_linked_at
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ?
		ORDER BY c.priority_order ASC, c.contact_id ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []ContactResponse{}
	for rows.Next() {
		contact, err := scanContact(rows, tg)
		if err != nil {
			return nil, err
		}
		out = append(out, contact)
	}
	return out, rows.Err()
}

func fetchUserContact(db *sql.DB, tg *telegram.Service, userID, contactID int) (*ContactResponse, error) {
	row := db.QueryRow(`
		SELECT c.contact_id, c.contact_name, c.phone_number, c.email, c.contact_type, c.priority_order,
		       c.telegram_chat_id, c.invite_token, c.telegram_linked_at
		FROM contacts c
		INNER JOIN user_contacts uc ON uc.contact_id = c.contact_id
		WHERE uc.user_id = ? AND c.contact_id = ?`, userID, contactID)

	contact, err := scanContact(row, tg)
	if err != nil {
		return nil, err
	}
	return &contact, nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanContact(row rowScanner, tg *telegram.Service) (ContactResponse, error) {
	var (
		c          ContactResponse
		email      sql.NullString
		ctype      sql.NullString
		chatID     sql.NullInt64
		token      sql.NullString
		linkedAt   sql.NullTime
	)
	err := row.Scan(
		&c.ContactID, &c.ContactName, &c.PhoneNumber, &email, &ctype, &c.PriorityOrder,
		&chatID, &token, &linkedAt,
	)
	if err != nil {
		return c, err
	}
	if email.Valid {
		c.Email = &email.String
	}
	if ctype.Valid {
		c.ContactType = &ctype.String
	}
	c.TelegramLinked = chatID.Valid
	if linkedAt.Valid {
		s := linkedAt.Time.Format(time.RFC3339)
		c.TelegramLinkedAt = &s
	}
	if token.Valid {
		c.InviteToken = token.String
		c.InviteLink = buildInviteLink(tg, token.String)
	}
	return c, nil
}

func buildInviteLink(tg *telegram.Service, token string) string {
	if tg != nil {
		return tg.InviteLink(token)
	}
	username := os.Getenv("TELEGRAM_BOT_USERNAME")
	if username == "" {
		username = "SafeAlertBot"
	}
	return "https://t.me/" + username + "?start=" + token
}

func generateInviteToken() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

// NormalizePhoneDigits keeps digits only for fuzzy matching.
func NormalizePhoneDigits(phone string) string {
	return nonDigitRE.ReplaceAllString(phone, "")
}

// PhonesMatch compares normalized phones (exact or last 9 digits).
func PhonesMatch(a, b string) bool {
	da := NormalizePhoneDigits(a)
	db := NormalizePhoneDigits(b)
	if da == "" || db == "" {
		return false
	}
	if da == db {
		return true
	}
	const n = 9
	if len(da) >= n && len(db) >= n {
		return da[len(da)-n:] == db[len(db)-n:]
	}
	return false
}
