package main

import (
	"flag"
	"fmt"
	"log"
	"net/url"

	cfclient "github.com/cloudfoundry-community/go-cfclient"
)

func main() {
	var (
		api   = flag.String("api", "", "hostname")
		token = flag.String("token", "", "token")
	)
	flag.Parse()

	config := &cfclient.Config{
		ApiAddress: *api,
		Token:      *token,
	}
	client, err := cfclient.NewClient(config)
	if err != nil {
		log.Fatalln(err)
	}

	params := url.Values{}
	apps, err := client.ListAppsByQuery(params)
	if err != nil {
		log.Fatalln(err)
	}
	for _, app := range apps {
		if app.DockerImage != "" {
			fmt.Println(app.Name, app.State, app.Guid, app.SpaceGuid)
		}
	}
}
