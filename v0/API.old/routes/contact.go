package routes

import (
	"database/sql"
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
)

type Contact struct {
	ID            int    `json:"id"`
	Email         string `json:"email"`
	UserRef       string `json:"user_ref"`
	ContactName   string `json:"contact_name"`
	PhoneNumber   string `json:"phone_number"`
	ContactType   string `json:"contact_type"`
	PriorityOrder int    `json:"priority_order"`
}

type ContactInput struct {
	Email         string `json:"email"`
	ContactName   string `json:"contact_name"`
	PhoneNumber   string `json:"phone_number"`
	ContactType   string `json:"contact_type"`
	PriorityOrder int    `json:"priority_order"`
}

// GET /api/contact/
func getContacts(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		const q = `
			SELECT id, email, user_ref, contact_name, phone_number, contact_type, priority_order
			FROM contact
			ORDER BY priority_order ASC, id ASC;
		`
		rows, err := db.Query(q)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_query_error", err)
		}
		defer rows.Close()

		list := make([]Contact, 0)
		for rows.Next() {
			var ct Contact
			if err := rows.Scan(&ct.ID, &ct.Email, &ct.UserRef, &ct.ContactName, &ct.PhoneNumber, &ct.ContactType, &ct.PriorityOrder); err != nil {
				return fiberErr(c, fiber.StatusInternalServerError, "db_scan_error", err)
			}
			list = append(list, ct)
		}
		if err := rows.Err(); err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_rows_error", err)
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"count": len(list),
			"data":  list,
		})
	}
}

// POST /api/contact/
func createContact(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userEmailAny := c.Locals("email")
		userEmail, _ := userEmailAny.(string)
		if userEmail == "" {
			return fiberErr(c, fiber.StatusUnauthorized, "unauthorized", errors.New("missing user email in context"))
		}

		var in ContactInput
		if err := c.BodyParser(&in); err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_json", err)
		}
		if in.ContactName == "" || in.PhoneNumber == "" {
			return fiberErr(c, fiber.StatusBadRequest, "missing_fields", errors.New("contact_name, phone_number required"))
		}

		const q = `
			INSERT INTO contact (email, user_ref, contact_name, phone_number, contact_type, priority_order)
			VALUES (?, ?, ?, ?, ?, ?)
		`
		res, err := db.Exec(q, in.Email, userEmail, in.ContactName, in.PhoneNumber, in.ContactType, in.PriorityOrder)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_insert_error", err)
		}

		id64, _ := res.LastInsertId()
		id := int(id64)

		const getQ = `
			SELECT id, email, user_ref, contact_name, phone_number, contact_type, priority_order
			FROM contact WHERE id = ?
		`
		var ct Contact
		if err := db.QueryRow(getQ, id).Scan(&ct.ID, &ct.Email, &ct.UserRef, &ct.ContactName, &ct.PhoneNumber, &ct.ContactType, &ct.PriorityOrder); err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_fetch_created_error", err)
		}

		return c.Status(fiber.StatusOK).JSON(ct)
	}
}

// DELETE /api/contact/:id
func deleteContact(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_id", err)
		}

		const q = `DELETE FROM contact WHERE id = ?`
		res, err := db.Exec(q, id)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_delete_error", err)
		}
		aff, _ := res.RowsAffected()
		if aff == 0 {
			return fiberErr(c, fiber.StatusNotFound, "contact_not_found", nil)
		}
		return c.SendStatus(fiber.StatusNoContent)
	}
}
