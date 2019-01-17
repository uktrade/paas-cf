package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/google/go-github/v21/github"
	"golang.org/x/oauth2"
	yaml "gopkg.in/yaml.v2"
)

type Buildpack struct {
	Name         string       `yaml:"name"`
	RepoName     string       `yaml:"repo_name"`
	Stack        string       `yaml:"stack"`
	Version      string       `yaml:"version"`
	Sha          string       `yaml:"sha"`
	Filename     string       `yaml:"filename"`
	Url          string       `yaml:"url"`
	Dependencies []Dependency `yaml:"dependencies"`
}

type Buildpacks struct {
	Buildpacks []Buildpack `yaml:"buildpacks"`
}

type DefaultVersion struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type Dependency struct {
	Name    string   `yaml:"name"`
	Version string   `yaml:"version"`
	Stacks  []string `yaml:"cf_stacks"`
}

type Manifest struct {
	DefaultVersions []DefaultVersion `yaml:"default_versions"`
	Dependencies    []Dependency     `yaml:"dependencies"`
}

func readManifest(githubClient *github.Client, buildpack Buildpack, ctx context.Context) (manifest Manifest) {
	fileContent, _, _, err := githubClient.Repositories.GetContents(
		ctx,
		"cloudfoundry",
		buildpack.RepoName,
		"manifest.yml",
		&github.RepositoryContentGetOptions{},
	)
	if err != nil {
		// log.Fatalf("could not get contents for manifest for %s, %v", buildpack.RepoName, err)
		return manifest
	}
	fileBytes, err := fileContent.GetContent()
	if err != nil {
		log.Fatalf("could not read contents for manifest for %s, %v", buildpack.RepoName, err)
	}
	err = yaml.Unmarshal([]byte(fileBytes), &manifest)
	if err != nil {
		log.Fatalf("could not unmarshal manifest as YAML, %v", err)
	}
	return manifest
}

func main() {
	stdin, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		log.Fatalf("couldn't read all of stdin, %v", err)
	}
	var result *Buildpacks

	err = yaml.Unmarshal(stdin, &result)
	if err != nil {
		log.Fatalf("could not unmarshal YAML: %v", err)
	}

	ctx := context.Background()
	githubToken, ok := os.LookupEnv("GITHUB_API_TOKEN")
	if !ok {
		log.Fatalf("environment variable GITHUB_API_TOKEN must be set")
	}
	ts := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: githubToken})
	tc := oauth2.NewClient(ctx, ts)
	githubClient := github.NewClient(tc)
	buildpackConfig := Buildpacks{}
	for _, buildpack := range result.Buildpacks {
		release, _, err := githubClient.Repositories.GetLatestRelease(ctx, "cloudfoundry", buildpack.RepoName)
		if err != nil {
			log.Fatalf("could not get latest release for %s, %v", buildpack.RepoName, err)
		}

		var newBuildpackUrl string
		var newBuildpackFilename string
		var newBuildpackShasum string
		for _, asset := range release.Assets {
			assetName := *asset.Name
			if !strings.Contains(*asset.Name, buildpack.Stack) {
				continue
			}
			if strings.HasSuffix(assetName, ".zip") {
				newBuildpackUrl = *asset.BrowserDownloadURL
				newBuildpackFilename = assetName
			}
			if strings.HasSuffix(assetName, "SHA256SUM.txt") {
				resp, err := http.Get(*asset.BrowserDownloadURL)
				if err != nil {
					log.Fatalf("could not download shasum for %s, %v", buildpack.RepoName, err)
				}
				defer resp.Body.Close()
				body, err := ioutil.ReadAll(resp.Body)
				if err != nil {
					log.Fatalf("could not read response for shasum for %s, %v", buildpack.RepoName, err)
				}
				newBuildpackShasum = strings.Split(string(body), " ")[0]
			}
		}

		if newBuildpackUrl == "" {
			for _, asset := range release.Assets {
				assetName := *asset.Name
				if strings.HasSuffix(assetName, ".zip") {
					newBuildpackUrl = *asset.BrowserDownloadURL
					newBuildpackFilename = assetName
				}
				if strings.HasSuffix(assetName, "SHA256SUM.txt") {
					resp, err := http.Get(*asset.BrowserDownloadURL)
					if err != nil {
						log.Fatalf("could not download shasum for %s, %v", buildpack.RepoName, err)
					}
					defer resp.Body.Close()
					body, err := ioutil.ReadAll(resp.Body)
					if err != nil {
						log.Fatalf("could not read response for shasum for %s, %v", buildpack.RepoName, err)
					}
					newBuildpackShasum = strings.Split(string(body), " ")[0]
				}
			}
		}

		manifest := readManifest(githubClient, buildpack, ctx)
		newBuildpack := Buildpack{
			Name:         buildpack.Name,
			RepoName:     buildpack.RepoName,
			Stack:        buildpack.Stack,
			Filename:     newBuildpackFilename,
			Sha:          newBuildpackShasum,
			Url:          newBuildpackUrl,
			Version:      *release.TagName,
			Dependencies: manifest.Dependencies,
		}

		buildpackConfig.Buildpacks = append(buildpackConfig.Buildpacks, newBuildpack)
	}
	newYaml, err := yaml.Marshal(buildpackConfig)
	if err != nil {
		log.Fatalf("could not marshal buildpackConfig into yaml, %v", err)
	}
	fmt.Println(string(newYaml))
}
