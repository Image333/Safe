package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/mysql"
	_ "github.com/golang-migrate/migrate/v4/source/file"
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
