package routes

import (
	"database/sql"
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
)

// --- Modèles ---

type User struct {
	UserID           int    `json:"id"`
	Name             string `json:"name"`
	Firstname        string `json:"firstname"`
	Email            string `json:"email"`
	RegistrationDate string `json:"registration_date"`
}

// Payload attendu en création/mise à jour
type UserInput struct {
	Name      string `json:"name"`
	Firstname string `json:"firstname"`
	Email     string `json:"email"`
	Password  string `json:"password,omitempty"`
}

func getUsers(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		const q = "SELECT user_id, name, firstname, email, registration_date FROM `user` ORDER BY user_id DESC"

		rows, err := db.Query(q)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_query_error", err)
		}
		defer rows.Close()

		list := make([]User, 0)
		for rows.Next() {
			var u User
			if err := rows.Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate); err != nil {
				return fiberErr(c, fiber.StatusInternalServerError, "db_scan_error", err)
			}
			list = append(list, u)
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

func getUserByID(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := paramID(c)
		if err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_id", err)
		}

		const q = "SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = ? LIMIT 1"
		var u User
		err = db.QueryRow(q, id).Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate)
		if errors.Is(err, sql.ErrNoRows) {
			return fiberErr(c, fiber.StatusNotFound, "user_not_found", nil)
		}
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_query_error", err)
		}

		return c.Status(fiber.StatusOK).JSON(u)
	}
}

func createUser(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var in UserInput
		if err := c.BodyParser(&in); err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_json", err)
		}
		if in.Name == "" || in.Firstname == "" || in.Email == "" || in.Password == "" {
			return fiberErr(c, fiber.StatusBadRequest, "missing_fields", errors.New("name, firstname, email, password required"))
		}

		// Hash du mot de passe
		hashed, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "hash_error", err)
		}

		const q = "INSERT INTO `user` (name, firstname, email, password, registration_date) VALUES (?, ?, ?, ?, NOW())"
		res, err := db.Exec(q, in.Name, in.Firstname, in.Email, string(hashed))
		if err != nil {
			// Gestion duplication email
			if isDuplicateEntry(err) {
				return fiberErr(c, fiber.StatusConflict, "email_already_exists", err)
			}
			return fiberErr(c, fiber.StatusInternalServerError, "db_insert_error", err)
		}
		id64, _ := res.LastInsertId()
		id := int(id64)

		// Retourne l'utilisateur créé (sans mot de passe)
		const getQ = "SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = ?"
		var u User
		if err := db.QueryRow(getQ, id).Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate); err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_fetch_created_error", err)
		}

		return c.Status(fiber.StatusCreated).JSON(u)
	}
}

func updateUser(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := paramID(c)
		if err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_id", err)
		}

		var in UserInput
		if err := c.BodyParser(&in); err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_json", err)
		}

		// Vérifier que l'user existe
		const checkQ = "SELECT 1 FROM `user` WHERE user_id = ?"
		var ok int
		if err := db.QueryRow(checkQ, id).Scan(&ok); errors.Is(err, sql.ErrNoRows) {
			return fiberErr(c, fiber.StatusNotFound, "user_not_found", nil)
		} else if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_check_error", err)
		}

		// Si password fourni, on le hash; sinon on n’y touche pas.
		if in.Password != "" {
			hashed, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
			if err != nil {
				return fiberErr(c, fiber.StatusInternalServerError, "hash_error", err)
			}
			const q = "UPDATE `user` SET name = ?, firstname = ?, email = ?, password = ? WHERE user_id = ?"
			if _, err := db.Exec(q, in.Name, in.Firstname, in.Email, string(hashed), id); err != nil {
				if isDuplicateEntry(err) {
					return fiberErr(c, fiber.StatusConflict, "email_already_exists", err)
				}
				return fiberErr(c, fiber.StatusInternalServerError, "db_update_error", err)
			}
		} else {
			const q = "UPDATE `user` SET name = ?, firstname = ?, email = ? WHERE user_id = ?"
			if _, err := db.Exec(q, in.Name, in.Firstname, in.Email, id); err != nil {
				if isDuplicateEntry(err) {
					return fiberErr(c, fiber.StatusConflict, "email_already_exists", err)
				}
				return fiberErr(c, fiber.StatusInternalServerError, "db_update_error", err)
			}
		}

		// Retourne l'user à jour
		const getQ = "SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = ?"
		var u User
		if err := db.QueryRow(getQ, id).Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate); err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_fetch_updated_error", err)
		}
		return c.Status(fiber.StatusOK).JSON(u)
	}
}

func deleteUser(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		id, err := paramID(c)
		if err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_id", err)
		}

		const q = "DELETE FROM `user` WHERE user_id = ?"
		res, err := db.Exec(q, id)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_delete_error", err)
		}
		aff, _ := res.RowsAffected()
		if aff == 0 {
			return fiberErr(c, fiber.StatusNotFound, "user_not_found", nil)
		}

		return c.SendStatus(fiber.StatusNoContent)
	}
}

// --- Helpers ---

func paramID(c *fiber.Ctx) (int, error) {
	return strconv.Atoi(c.Params("id"))
}

func isDuplicateEntry(err error) bool {
	// Vérif sur le texte du message
	return err != nil && (contains(err.Error(), "Duplicate entry") || contains(err.Error(), "1062"))
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && ( // micro opti
	func() bool { return (len(s) > 0 && len(sub) > 0) && (indexOf(s, sub) >= 0) })()
}

func indexOf(s, sub string) int {
	// (utiliser strings.Index)
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

func fiberErr(c *fiber.Ctx, code int, key string, err error) error {
	msg := key
	if err != nil {
		msg = key + ": " + err.Error()
	}
	return c.Status(code).JSON(fiber.Map{
		"error": key,
		"msg":   msg,
	})
}
