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

type AssetDetails struct {
	Url      string
	Filename string
	Sha      string
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

func downloadSha(url, repoName string) (shasum string) {
	resp, err := http.Get(url)
	if err != nil {
		log.Fatalf("could not download shasum for %s, %v", repoName, err)
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatalf("could not read response for shasum for %s, %v", repoName, err)
	}
	return strings.Split(string(body), " ")[0]
}

func getAssetDetails(assets []github.ReleaseAsset, repoName, nameFilter string) (assetDetails AssetDetails, ok bool) {
	ok = false
	for _, asset := range assets {
		assetName := *asset.Name
		if nameFilter != "" && !strings.Contains(assetName, nameFilter) {
			continue
		}
		if strings.HasSuffix(assetName, ".zip") {
			assetDetails.Url = *asset.BrowserDownloadURL
			assetDetails.Filename = assetName
			ok = true
		}
		if strings.HasSuffix(assetName, "SHA256SUM.txt") {
			assetDetails.Sha = downloadSha(*asset.BrowserDownloadURL, repoName)
		}
	}
	return assetDetails, ok
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

		assetDetails, ok := getAssetDetails(release.Assets, buildpack.RepoName, buildpack.Stack)
		if !ok {
			assetDetails, ok = getAssetDetails(release.Assets, buildpack.RepoName, "")
			if !ok {
				log.Fatalf("could not find assets for release %s", *release.URL)
			}
		}

		manifest := readManifest(githubClient, buildpack, ctx)
		newBuildpack := Buildpack{
			Name:         buildpack.Name,
			RepoName:     buildpack.RepoName,
			Stack:        buildpack.Stack,
			Filename:     assetDetails.Filename,
			Sha:          assetDetails.Sha,
			Url:          assetDetails.Url,
			Version:      *release.TagName,
			Dependencies: manifest.Dependencies,
		}

		buildpackConfig.Buildpacks = append(buildpackConfig.Buildpacks, newBuildpack)
	}
	newBuildpacksYaml, err := yaml.Marshal(buildpackConfig)
	if err != nil {
		log.Fatalf("could not marshal buildpackConfig into yaml, %v", err)
	}
	fmt.Println(string(newBuildpacksYaml))
}
