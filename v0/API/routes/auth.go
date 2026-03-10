package routes

import (
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type AuthSignupInput struct {
	Name      string `json:"name"`
	Firstname string `json:"firstname"`
	Email     string `json:"email"`
	Password  string `json:"password"`
}

type AuthLoginInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func signUp(db *sql.DB, secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var in AuthSignupInput
		if err := c.BodyParser(&in); err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_json", err)
		}
		if in.Name == "" || in.Firstname == "" || in.Email == "" || in.Password == "" {
			return fiberErr(c, fiber.StatusBadRequest, "missing_fields", errors.New("name, firstname, email, password required"))
		}

		hashed, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "hash_error", err)
		}

		const q = "INSERT INTO `user` (name, firstname, email, password, registration_date) VALUES (?, ?, ?, ?, NOW())"
		res, err := db.Exec(q, in.Name, in.Firstname, in.Email, string(hashed))
		if err != nil {
			if isDuplicateEntry(err) {
				return fiberErr(c, fiber.StatusConflict, "email_already_exists", err)
			}
			return fiberErr(c, fiber.StatusInternalServerError, "db_insert_error", err)
		}
		id64, _ := res.LastInsertId()
		uid := int(id64)

		token, err := makeToken(uid, in.Email, secret)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "jwt_error", err)
		}

		const getQ = "SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = ?"
		var u User
		if err := db.QueryRow(getQ, uid).Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate); err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_fetch_created_error", err)
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"token": token,
			"user":  u,
		})
	}
}

func login(db *sql.DB, secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var in AuthLoginInput
		if err := c.BodyParser(&in); err != nil {
			return fiberErr(c, fiber.StatusBadRequest, "invalid_json", err)
		}
		if in.Email == "" || in.Password == "" {
			return fiberErr(c, fiber.StatusBadRequest, "missing_fields", errors.New("email, password required"))
		}

		const q = "SELECT user_id, name, firstname, email, password, registration_date FROM `user` WHERE email = ? LIMIT 1"
		var (
			id        int
			name      string
			firstname string
			email     string
			passHash  string
			regDate   string
		)
		err := db.QueryRow(q, in.Email).Scan(&id, &name, &firstname, &email, &passHash, &regDate)
		if errors.Is(err, sql.ErrNoRows) {
			return fiberErr(c, fiber.StatusUnauthorized, "invalid_credentials", nil)
		}
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "db_query_error", err)
		}

		if err := bcrypt.CompareHashAndPassword([]byte(passHash), []byte(in.Password)); err != nil {
			return fiberErr(c, fiber.StatusUnauthorized, "invalid_credentials", nil)
		}

		token, err := makeToken(id, email, secret)
		if err != nil {
			return fiberErr(c, fiber.StatusInternalServerError, "jwt_error", err)
		}

		u := User{
			UserID:           id,
			Name:             name,
			Firstname:        firstname,
			Email:            email,
			RegistrationDate: regDate,
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"token": token,
			"user":  u,
		})
	}
}

func me(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		val := c.Locals("user_id")
		userID, ok := val.(int)
		if !ok || userID <= 0 {
			return fiberErr(c, fiber.StatusUnauthorized, "unauthorized", nil)
		}

		const q = "SELECT user_id, name, firstname, email, registration_date FROM `user` WHERE user_id = ?"
		var u User
		if err := db.QueryRow(q, userID).Scan(&u.UserID, &u.Name, &u.Firstname, &u.Email, &u.RegistrationDate); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return fiberErr(c, fiber.StatusNotFound, "user_not_found", nil)
			}
			return fiberErr(c, fiber.StatusInternalServerError, "db_query_error", err)
		}
		return c.Status(fiber.StatusOK).JSON(u)
	}
}

func makeToken(userID int, email string, secret []byte) (string, error) {
	claims := jwt.MapClaims{
		"sub":   userID,
		"email": email,
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(7 * 24 * time.Hour).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(secret)
}

func requireAuth(secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		auth := c.Get("Authorization")
		if auth == "" || !strings.HasPrefix(auth, "Bearer ") {
			return fiberErr(c, fiber.StatusUnauthorized, "missing_bearer_token", nil)
		}
		tokenStr := strings.TrimPrefix(auth, "Bearer ")

		tok, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, errors.New("unexpected_signing_method")
			}
			return secret, nil
		})
		if err != nil || !tok.Valid {
			return fiberErr(c, fiber.StatusUnauthorized, "invalid_token", err)
		}

		claims, ok := tok.Claims.(jwt.MapClaims)
		if !ok {
			return fiberErr(c, fiber.StatusUnauthorized, "invalid_claims", nil)
		}
		sub, ok := claims["sub"].(float64)
		if !ok || int(sub) <= 0 {
			return fiberErr(c, fiber.StatusUnauthorized, "invalid_subject", nil)
		}
		emailStr, _ := claims["email"].(string)

		c.Locals("user_id", int(sub))
		c.Locals("email", emailStr)
		return c.Next()
	}
}
