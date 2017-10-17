package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
)

type dbInstance struct {
	Connection *sql.DB
}

const (
	value = 5
)

var (
	dbtable string

	chars = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_")
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func connectDB(engine, url string) (*dbInstance, error) {
	dbtable = RandStringRunes(16)

	conn, err := sql.Open(engine, url)
	if err != nil {
		return nil, err
	}

	db := dbInstance{conn}

	err = db.create()
	if err != nil {
		return nil, err
	}

	return &db, nil
}

func main() {
	var dbs []*dbInstance

	postgresUris, err := getVCAPServiceUris("postgres")
	if err != nil {
		log.Fatalln(err)
	}
	for postgresUri := range postgresUris {
		pqDB, err := connectDB("postgres", postgresUri)
		if err != nil {
			log.Fatalln(err)
		}
		dbs = append(dbs, pqDB)
	}

	mysqlUris, err := getVCAPServiceUris("mysql")
	if err != nil {
		log.Fatalln(err)
	}
	for mysqlUri := range mysqlUris {
		mysqlDB, err := connectDB("mysql", mysqlUri)
		if err != nil {
			log.Fatalln(err)
		}
		dbs = append(dbs, pqDB)
	}

	for db, _ := range dbs {
		err = insertUntilErr(db)
		if err != nil {
			log.Println(err)
		}
	}
}

func insertUntilErr(db *dbInstance) (err error) {
	for err == nil {
		err = db.insert()
	}
}

func (i *dbInstance) create() error {
	table := fmt.Sprintf("CREATE TABLE IF NOT EXISTS \"%s\" (value integer);", dbtable)
	_, err := i.Connection.Exec(table)
	if err != nil {
		return err
	}

	return nil
}

func (i *dbInstance) insert() error {
	statement := fmt.Sprintf("INSERT INTO \"%s\" VALUES (%d);", dbtable, value)
	_, err := i.Connection.Exec(statement)
	if err != nil {
		return err
	}

	return nil
}

// RandStringRunes asda
func RandStringRunes(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = chars[rand.Intn(len(chars))]
	}
	return string(b)
}
