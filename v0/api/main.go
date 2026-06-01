package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dbUser := getEnv("DB_USER", "gpe-user")
	dbPass := getEnv("DB_PASSWORD", "azerty1234")
	dbHost := getEnv("DB_HOST", "127.0.0.1")
	dbPort := getEnv("DB_PORT", "3306")
	dbName := getEnv("DB_NAME", "gpe-db")

	// Format: username:password@tcp(host:port)/dbname?parseTime=true
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true", dbUser, dbPass, dbHost, dbPort, dbName)

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
}

// Fonction utilitaire pour lire les variables d'environnement avec une valeur de repli
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
