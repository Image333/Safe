package routes

import (
	"database/sql"
	"errors"
	"log"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
)

// On crée une structure pour valider le JSON reçu
type CreateUserRequest struct {
	Email     string `json:"email"`
	Password  string `json:"password"`
	Firstname string `json:"firstname"`
	Name      string `json:"name"`
	RoleID    int    `json:"role_id"`
}

type UserResponse struct {
	UserID           int    `json:"user_id"`
	Name             string `json:"name"`
	Firstname        string `json:"firstname"`
	Email            string `json:"email"`
	RegistrationDate string `json:"registration_date"`
	RoleID           *int   `json:"role_id"`
	ConfigID         *int   `json:"config_id"`
}

// RegisterUserRoutes prend le routeur ET la BDD en paramètre
func RegisterUserRoutes(router fiber.Router, db *sql.DB) {

	//
	// Create User
	//
	router.Post("/users", func(c *fiber.Ctx) error {
		var req CreateUserRequest

		// Parse JSON from body Body
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Format JSON invalide",
			})
		}

		switch {
		case req.Name == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Nom requis"})
		case req.Firstname == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Prénom requis"})
		case req.Email == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Email requis"})
		case req.Password == "":
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Mot de passe requis"})
		}

		// hash password
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			log.Printf("Erreur hachage: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Erreur interne du serveur",
			})
		}

		query := `INSERT INTO users (name, firstname, email, password) 
                  VALUES (?, ?, ?, ?)`

		// On exécute la requête (db.Exec renvoie un objet 'result')
		result, err := db.Exec(query, req.Name, req.Firstname, req.Email, string(hashedPassword))
		if err != nil {
			log.Printf("Erreur SQL INSERT: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Impossible de créer l'utilisateur (email déjà utilisé ?)",
			})
		}

		newID, err := result.LastInsertId()
		if err != nil {
			log.Printf("Erreur récupération LastInsertId: %v", err)
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"message": "Utilisateur créé avec succès",
			"user_id": newID,
		})

	})

	//
	// Get user by email
	//
	router.Get("/users/:email", func(c *fiber.Ctx) error {
		// get email from params
		emailParam := c.Params("email")
		if emailParam == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Email requis dans l'URL",
			})
		}

		query := `SELECT user_id, name, firstname, email, registration_date, role_id, config_id
		          FROM users
		          WHERE email = ?`

		var user UserResponse

		// 3. Exécuter et scanner la ligne
		// QueryRow s'attend à trouver exactement 1 ligne
		err := db.QueryRow(query, emailParam).Scan(
			&user.UserID,
			&user.Name,
			&user.Firstname,
			&user.Email,
			&user.RegistrationDate,
			&user.RoleID,
			&user.ConfigID,
		)

		if err != nil {
			// Si l'utilisateur n'existe pas en BDD
			if errors.Is(err, sql.ErrNoRows) {
				return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
					"error": "Utilisateur non trouvé",
				})
			}
			// Pour toute autre erreur technique SQL
			log.Printf("Erreur SQL SELECT: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Erreur lors de la récupération de l'utilisateur",
			})
		}

		// 4. Renvoyer les infos de l'utilisateur trouvé
		return c.Status(fiber.StatusOK).JSON(user)
	})
}
