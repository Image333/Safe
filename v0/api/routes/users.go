package routes

import (
	"database/sql"
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

// RegisterUserRoutes prend le routeur ET la BDD en paramètre
func RegisterUserRoutes(router fiber.Router, db *sql.DB) {
	// On crée un handler inline (closure) pour avoir accès à la variable 'db'
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
}
