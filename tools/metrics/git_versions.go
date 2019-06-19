package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type GitHubReleasesResponse struct {
	TagName string `json:"tag_name"`
}

func GitVersionsGauge(githubVersionReposString string, interval time.Duration) MetricReadCloser {
	githubVersionRepos := strings.Split(",", githubVersionReposString)
	return NewMetricPoller(interval, func(w MetricWriter) error {
		metrics := []Metric{}
		for _, versionRepo := range githubVersionRepos {
			version, err := getVersionFromGitHub(versionRepo)
			if err != nil {
				return err
			}
			metrics = append(metrics, Metric{
				Kind:  Gauge,
				Time:  time.Now(),
				Name:  "github.version." + strings.Replace(versionRepo, "/", ".", -1),
				Value: version,
				Unit:  "pounds",
			})
		}
		return w.WriteMetrics(metrics)
	})
}

func getVersionFromGitHub(versionRepo string) (float64, error) {
	resp, err := http.Get(fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", versionRepo))
	if err != nil {
		return 0, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("non-success response from github %d", resp.StatusCode)
	}
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return 0, err
	}
	var githubReleasesResponse GitHubReleasesResponse
	err = json.Unmarshal(body, &githubReleasesResponse)
	if err != nil {
		return 0, err
	}
	parts := strings.Split(".", strings.Replace(githubReleasesResponse.TagName, "v", "", 1))
	if len(parts) < 2 {
		return 0, fmt.Errorf("expected tag name of the for vXXX.YYY.ZZZ, got %s", githubReleasesResponse.TagName)
	}
	return strconv.ParseFloat(fmt.Sprintf("%s.%s", parts[0], parts[1]), 64)
}
