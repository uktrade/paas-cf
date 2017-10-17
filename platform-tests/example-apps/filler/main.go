package main

import (
	"crypto/tls"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	mysql "github.com/go-sql-driver/mysql"
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

func main() {
	var dbs []*dbInstance
	var err error

	postgresUris, err := getVCAPServiceUris("postgres")
	if err != nil {
		log.Fatalln(err)
	}

	for _, postgresURI := range postgresUris {
		pqDB, err := connectDB("postgres", postgresURI)
		if err != nil {
			log.Fatalln(err)
		}
		dbs = append(dbs, pqDB)
	}

	mysqlUris, err := getVCAPServiceUris("mysql")
	if err != nil {
		log.Fatalln(err)
	}

	for _, mysqlURI := range mysqlUris {
		mysqlDB, err := connectDB("mysql", mysqlURI)
		if err != nil {
			log.Fatalln(err)
		}
		dbs = append(dbs, mysqlDB)
	}

	for _, db := range dbs {
		err = insertUntilErr(db)
		if err != nil {
			log.Println(err)
		}
	}
}

func getVCAPServiceUris(label string) ([]string, error) {
	var allServices map[string][]struct {
		Credentials struct {
			URI      string `json:"uri"`
			Host     string `json:"host"`
			Jdbcuri  string `json:"jdbcuri"`
			Name     string `json:"name"`
			Password string `json:"password"`
			Port     int64  `json:"port"`
			Username string `json:"username"`
		} `json:"credentials"`
	}

	err := json.Unmarshal([]byte(os.Getenv("VCAP_SERVICES")), &allServices)
	if err != nil {
		return nil, err
	}
	services, _ := allServices[label]

	var uris []string
	for _, service := range services {
		if label == "mysql" {
			if err := mysql.RegisterTLSConfig("custom", &tls.Config{ServerName: service.Credentials.Host}); err != nil {
				return nil, err
			}
			uris = append(uris, fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=custom", service.Credentials.Username, service.Credentials.Password, service.Credentials.Host, service.Credentials.Port, service.Credentials.Name))
		} else {
			uris = append(uris, service.Credentials.URI)
		}
	}

	return uris, nil
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

func insertUntilErr(db *dbInstance) (err error) {
	for err == nil {
		err = db.insert()
	}

	return err
}

func (i *dbInstance) create() error {
	table := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (value text);", dbtable)
	_, err := i.Connection.Exec(table)
	if err != nil {
		return err
	}

	return nil
}

func (i *dbInstance) insert() error {
	statement := fmt.Sprintf("INSERT INTO %s VALUES (\"%s\");", dbtable, story)
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
