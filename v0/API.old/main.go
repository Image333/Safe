package main

import (
	"API/routes"
	"database/sql"
	"fmt"
	"os"
	"reflect"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gofiber/fiber/v2"
	"github.com/joho/godotenv"
)

func main() {
	db := db_connect()
	defer db.Close()

	app := fiber.New(fiber.Config{
		BodyLimit: 50 * 1024 * 1024, // 50 MB
	})

	// Santé
	app.Get("/health", func(c *fiber.Ctx) error { return c.SendString("ok") })

	// Routes CRUD
	routes.Register(app, db)

	// Démarrage serveur
	if err := app.Listen("0.0.0.0:3002"); err != nil {
		panic(err)
	}

}

func db_connect() *sql.DB {
	godotenv.Load(".env")
	var (
		host     = os.Getenv("MARIADB_ADDRESS")
		dbport   = os.Getenv("MARIADB_PORT")
		user     = os.Getenv("MARIADB_USER")
		password = os.Getenv("MARIADB_PASSWORD")
		dbname   = os.Getenv("MARIADB_DATABASE")
	)
	mysqlInfo := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s", user, password, host, dbport, dbname)
	db, err := sql.Open("mysql", mysqlInfo)
	if err != nil {
		panic(err)
	}

	err = db.Ping()
	if err != nil {
		panic(err)
	}

	fmt.Printf("Successfully connected to %s!", dbname)
	return db
}

func dbprint[T any](rows []T) {
	switch reflect.TypeOf(rows) {
	case reflect.TypeOf([]routes.User{}):
		users := any(rows).([]routes.User)
		fmt.Println("\n\n=========== Start User Print ===========")
		for i := 0; i < len(users); i++ {
			fmt.Printf("\n --- user %d ---\n", users[i].UserID)
			fmt.Printf("user_id : %d\n", users[i].UserID)
			fmt.Printf("name : %s\n", users[i].Name)
			fmt.Printf("firstname : %s\n", users[i].Firstname)
			fmt.Printf("email : %s\n", users[i].Email)
			fmt.Printf("registration_date : %s\n", users[i].RegistrationDate)

		}
		fmt.Println("\n\n=========== End User Print ===========")
	// case reflect.TypeOf([]routes.Contact{}):
	// 	contacts := any(rows).([]routes.Contact)
	// 	fmt.Println("\n\n=========== Start Contact Print ===========")
	// 	if len(contacts) == 0 {
	// 		fmt.Println("contact table is empty !")
	// 	}

	// 	for i := 0; i < len(contacts); i++ {
	// 		fmt.Printf("\n --- user %d ---\n", contacts[i].Id)
	// 		fmt.Printf("user_id : %d\n", contacts[i].Id)
	// 		fmt.Printf("name : %s\n", contacts[i].Name)
	// 		fmt.Printf("phone number : %d\n", contacts[i].PhoneNumber)
	// 		fmt.Printf("type : %s\n", contacts[i].Type)
	// 		fmt.Printf("priority order : %d\n", contacts[i].PriorityOrder)

	// 	}
	// 	fmt.Println("\n\n=========== End Contact Print ===========")
	default:
		fmt.Println("this type is not suported")

	}

}
