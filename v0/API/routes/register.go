package routes

import (
	"database/sql"
	"os"

	"github.com/gofiber/fiber/v2"
)

func Register(app *fiber.App, db *sql.DB) {
	api := app.Group("/api")

	// Auth
	secret := []byte(os.Getenv("JWT_SECRET"))
	auth := api.Group("/auth")
	auth.Post("/signup", signUp(db, secret))
	auth.Post("/login", login(db, secret))
	auth.Get("/me", requireAuth(secret), me(db))

	// Users
	users := api.Group("/users")
	users.Get("/", getUsers(db))
	users.Get("/:id", getUserByID(db))
	users.Post("/", createUser(db))
	users.Put("/:id", updateUser(db))
	users.Delete("/:id", deleteUser(db))

	// Contacts
	contacts := api.Group("/contact")
	contacts.Get("/", getContacts(db))
	contacts.Post("/", requireAuth(secret), createContact(db))
	contacts.Delete("/:id", requireAuth(secret), deleteContact(db))

	recordings := api.Group("/recordings")
	recordings.Post("/", requireAuth(secret), uploadRecording())
}
