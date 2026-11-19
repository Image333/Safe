package main

import (
	"database/sql"
	"fmt"
	"gpe/routes"
	_ "gpe/routes"
	"gpe/telegram"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ansrivas/fiberprometheus/v2"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/mysql"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/prometheus/client_golang/prometheus"
)

func main() {
	// for local usage : kubectl port-forward svc/my-mariadb -n gpe 3306:3306
	dbUser := getEnv("DB_USER", "gpe-user")
	dbPass := getEnv("DB_PASSWORD", "azerty1234")
	dbHost := getEnv("DB_HOST", "127.0.0.1")
	dbPort := getEnv("DB_PORT", "3306")
	dbName := getEnv("DB_NAME", "gpe-db")

	// Format: username:password@tcp(host:port)/dbname?parseTime=true
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&multiStatements=true", dbUser, dbPass, dbHost, dbPort, dbName)

	log.Printf("Tentative de connexion à la base de données %s sur %s:%s...", dbName, dbHost, dbPort)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Erreur de configuration de la base de données: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(25)                 // nombre de connexions simultanées
	db.SetMaxIdleConns(5)                  // Nombre de connexions gardées au repos
	db.SetConnMaxLifetime(5 * time.Minute) // Durée de vie max d'une connexion

	// try connection to db
	err = db.Ping()
	if err != nil {
		log.Fatalf("Impossible de joindre la base de données: %v", err)
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

	// Activate logger
	app.Use(logger.New())

	// Ensure api to not crash in case of panic
	app.Use(recover.New())

	// Serve the default registry so the app's own go_/process_ collectors and the
	// telegram_* counters are exposed next to the HTTP metrics.
	prom := fiberprometheus.NewWithRegistry(prometheus.DefaultRegisterer, "gpe-backend", "http", "", nil)
	prom.RegisterAt(app, "/metrics")
	prom.SetSkipPaths([]string{"/health"})
	app.Use(prom.Middleware)

	routes.HealthRoutes(app)

	api := app.Group("/api/v1")

	// Service Telegram (nil si TELEGRAM_BOT_TOKEN absent → notifications désactivées)
	tg := telegram.NewService()

	// Webhook Telegram — enregistré sans X-API-Key / JWT (Telegram ne peut pas les envoyer),
	// protégé par TELEGRAM_WEBHOOK_SECRET
	routes.RegisterTelegramRoutes(api, db, tg)

	// API Key middleware — protège toutes les routes /api/v1
	appKey := getEnv("API_KEY_APP", "")
	devKey := getEnv("API_KEY_DEV", "")
	var keyMiddleware fiber.Handler
	if appKey != "" && devKey != "" {
		keyMiddleware = routes.ApiKeyMiddleware(appKey, devKey)
		log.Println("API Key auth activée")
	} else {
		keyMiddleware = func(c *fiber.Ctx) error { return c.Next() }
		log.Println("API Key auth DÉSACTIVÉE (clés manquantes)")
	}

	routes.RegisterUserRoutes(api, db, keyMiddleware)
	audioNotifier := routes.RegisterAudioRoutes(api, db, keyMiddleware, tg)
	routes.RegisterConfigurationRoutes(api, db, keyMiddleware)
	alertNotifier := routes.RegisterAlertRoutes(api, db, keyMiddleware, tg)
	routes.RegisterContactRoutes(api, db, keyMiddleware, tg)

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-shutdown
		log.Println("Arrêt demandé — fermeture des files d'envoi")
		if err := app.Shutdown(); err != nil {
			log.Printf("arrêt HTTP: %v", err)
		}
	}()

	log.Println("Server starting on :8080...")
	if err := app.Listen(":8080"); err != nil {
		log.Fatalf("Error when lauching server: %v", err)
	}

	// Drain the Telegram queues so in-flight notifications are not lost.
	if alertNotifier != nil {
		alertNotifier.Close()
	}
	if audioNotifier != nil {
		audioNotifier.Close()
	}
}

// URead ENV var with fallback value
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
