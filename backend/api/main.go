package main

import (
	"database/sql"
	"fmt"
	"gpe/routes"
	"gpe/telegram"
	"log"
	"os"
	"time"

	"github.com/ansrivas/fiberprometheus/v2"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/mysql"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/joho/godotenv"
)

func main() {
	// Load backend/api/.env when present (ignored if missing).
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found — using system environment variables")
	}

	// for local usage : kubectl port-forward svc/my-mariadb -n gpe 3306:3306
	dbUser := getEnv("DB_USER", "gpe-user")
	dbPass := getEnv("DB_PASSWORD", "CHANGE_ME")
	dbHost := getEnv("DB_HOST", "127.0.0.1")
	dbPort := getEnv("DB_PORT", "3306")
	dbName := getEnv("DB_NAME", "gpe-db")

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&multiStatements=true", dbUser, dbPass, dbHost, dbPort, dbName)

	log.Printf("Attempting database connection to %s on %s:%s...", dbName, dbHost, dbPort)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Database configuration error: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	err = db.Ping()
	if err != nil {
		log.Fatalf("Cannot reach database: %v", err)
	}

	log.Println("Db up")
	log.Println("Run database migration...")
	if err := runMigrations(db, dbName); err != nil {
		log.Fatalf("Migration failed : %v", err)
	}
	log.Println("Database updated")

	app := fiber.New(fiber.Config{
		AppName: "Safe API v1.0",
	})

	app.Use(logger.New())
	app.Use(recover.New())

	prometheus := fiberprometheus.New("gpe-backend")
	prometheus.RegisterAt(app, "/metrics")
	prometheus.SetSkipPaths([]string{"/health"})
	app.Use(prometheus.Middleware)

	routes.HealthRoutes(app)

	api := app.Group("/api/v1")

	tg := telegram.NewService()

	// Telegram webhook first: no X-API-Key / JWT (Telegram cannot send them).
	routes.RegisterTelegramRoutes(api, db, tg)

	appKey := getEnv("API_KEY_APP", "")
	devKey := getEnv("API_KEY_DEV", "")
	var keyMiddleware fiber.Handler
	if appKey != "" && devKey != "" {
		keyMiddleware = routes.ApiKeyMiddleware(appKey, devKey)
		log.Println("API Key auth enabled")
	} else {
		keyMiddleware = func(c *fiber.Ctx) error { return c.Next() }
		log.Println("API Key auth DISABLED (keys missing)")
	}

	routes.RegisterUserRoutes(api, db, keyMiddleware)
	routes.RegisterConfigurationRoutes(api, db, keyMiddleware)
	routes.RegisterContactRoutes(api, db, keyMiddleware, tg)
	routes.RegisterAlertRoutes(api, db, keyMiddleware, tg)
	routes.RegisterAudioRoutes(api, db, keyMiddleware, tg)

	log.Println("Server starting on :8080...")
	if err := app.Listen(":8080"); err != nil {
		log.Fatalf("Error when launching server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

func runMigrations(db *sql.DB, dbName string) error {
	driver, err := mysql.WithInstance(db, &mysql.Config{})
	if err != nil {
		return fmt.Errorf("impossible de créer le driver de migration: %w", err)
	}

	m, err := migrate.NewWithDatabaseInstance(
		"file://migrations",
		dbName,
		driver,
	)
	if err != nil {
		return fmt.Errorf("erreur initialisation migrate: %w", err)
	}

	err = m.Up()
	if err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("erreur durant l'exécution des migrations: %w", err)
	}

	if err == migrate.ErrNoChange {
		log.Println("Aucun changement détecté (la base est déjà à jour).")
	} else {
		log.Println("Nouvelles tables créées avec succès.")
	}

	return nil
}
