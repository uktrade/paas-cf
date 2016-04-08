package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	interval := getInterval()
	timeout := getTimeout()
	targetURL := getTargetURL(port)
	skipSSLValidation := os.Getenv("SKIP_SSL_VALIDATION") == ""

	addr := ":" + port
	fmt.Println("Listening on port", port)
	fmt.Println("Targeting", targetURL)
	fmt.Println("Timeout set to", timeout)
	fmt.Println("Interval set to", interval)
	fmt.Println("skipSSLValidation set to", skipSSLValidation)

	server := newServer(targetURL, timeout, interval, skipSSLValidation)
	err := http.ListenAndServe(addr, server)
	if err != nil {
		log.Fatal(err)
	}
}

func getTimeout() time.Duration {
	timeoutString := os.Getenv("TIMEOUT")
	var timeout time.Duration
	var err error

	if timeoutString == "" {
		timeout = 15 * time.Second
	} else {
		timeout, err = time.ParseDuration(timeoutString)
		if err != nil {
			log.Fatalln("Unable to decode timeout", timeoutString)
		}
	}

	return timeout
}

func getInterval() time.Duration {
	intervalString := os.Getenv("INTERVAL")
	var interval time.Duration
	var err error

	if intervalString == "" {
		interval = time.Millisecond * 200
	} else {
		interval, err = time.ParseDuration(intervalString)
		if err != nil {
			log.Fatalln("Unable to decode interval", intervalString)
		}
	}

	return interval
}

type VcapApplication struct {
	Uris []string `json:"uris"`
}

func getTargetURL(port string) string {
	app_metadata := os.Getenv("VCAP_APPLICATION")
	if app_metadata == "" {
		return fmt.Sprintf("http://localhost:%v", port)
	} else {
		vcapApplication := VcapApplication{}

		err := json.Unmarshal([]byte(app_metadata), &vcapApplication)
		if err != nil {
			log.Fatalln("Unable to decode VCAP_APPLICATION json")
		}
		return fmt.Sprintf("https://%v", vcapApplication.Uris[0])
	}
}

func buildHTTPClient(timeout time.Duration, skipSSLValidation bool) http.Client {
	var tr *http.Transport

	if skipSSLValidation {
		tr = &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
	} else {
		tr = &http.Transport{}
	}

	return http.Client{
		Timeout:   timeout,
		Transport: tr,
	}
}

type pollingServer struct {
	TargetURL  string
	DoneCh     chan struct{}
	ResultsCh  chan string
	Success    bool
	HealthCode int
	Delay      int
	HTTPClient http.Client
	interval   time.Duration
}

func newServer(targetURL string, timeout time.Duration,
	interval time.Duration, skipSSLValidation bool) *pollingServer {
	s := &pollingServer{
		TargetURL: targetURL,
		interval:  interval,
		DoneCh:    make(chan struct{}),
		ResultsCh: make(chan string),
	}
	s.HTTPClient = buildHTTPClient(timeout, skipSSLValidation)
	return s
}

func (s *pollingServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	output := ""
	returnCode := 200

	switch r.URL.Path {
	case "/healthcheck":
		output, returnCode = s.healthcheck()
	case "/start":
		go s.start()
		output = "Started"
	case "/stop":
		output = s.stop()
	case "/breakit":
		code := r.URL.Query().Get("code")
		output = s.breakIt(code)
	case "/healit":
		output = s.healIt()
	case "/slowit":
		delay := r.URL.Query().Get("delay")
		output = s.slowIt(delay)
	default:
		fmt.Println("404: Unknown action")
		http.Error(w, "Unknown action", http.StatusNotFound)
		return
	}

	if returnCode == 200 {
		fmt.Fprint(w, output)
	} else {
		http.Error(w, output, returnCode)
	}
}

func (s *pollingServer) start() {
	fmt.Println("Starting")
	result_string := ""
	s.Success = true
	s.HealthCode = 200
	s.Delay = 0
	var maxTime time.Duration
	tkr := time.NewTicker(s.interval)
	defer tkr.Stop()

	for {
		select {
		case <-s.DoneCh:
			if s.Success {
				result_string = "OK"
			} else {
				result_string = "FAIL"
			}
			s.ResultsCh <- result_string
			return
		case _ = <-tkr.C:
			start := time.Now()
			resp, err := s.HTTPClient.Get(fmt.Sprintf("%v/healthcheck", s.TargetURL))
			elapsed := time.Since(start)
			if elapsed > maxTime {
				maxTime = elapsed
			}
			if err != nil {
				fmt.Println(err)
				s.Success = false
			} else {
				switch resp.StatusCode {
				case 200:
					fmt.Println("Successful polling, time", elapsed)
				default:
					fmt.Println("ERROR when polling, time", elapsed)
					s.Success = false
				}
			}
		}
	}
}

func (s *pollingServer) stop() string {
	fmt.Println("Stopping")
	s.DoneCh <- struct{}{}
	return <-s.ResultsCh
}

func (s *pollingServer) healthcheck() (string, int) {
	resultString := ""
	if s.HealthCode == 200 {
		resultString = "WORKING"
	} else {
		resultString = "NOT WORKING"
	}
	time.Sleep(time.Duration(s.Delay) * time.Second)
	return resultString, s.HealthCode
}

func extractInt(stringValue string, defaultValue int) int {
	var newInt int
	newIntTmp, err := strconv.Atoi(stringValue)
	if err != nil {
		fmt.Println("Unable to convert value:", stringValue)
		newInt = defaultValue
	} else {
		newInt = newIntTmp
	}
	return newInt
}

func (s *pollingServer) breakIt(code string) string {
	if code == "" {
		s.HealthCode = 500
	} else {
		s.HealthCode = extractInt(code, s.HealthCode)
	}
	return fmt.Sprintln("Health code set to", s.HealthCode)
}

func (s *pollingServer) slowIt(delay string) string {
	if delay == "" {
		s.Delay = 10
	} else {
		s.Delay = extractInt(delay, s.Delay)
	}
	return fmt.Sprintln("Delay set to ", s.Delay)
}

func (s *pollingServer) healIt() string {
	s.HealthCode = 200
	s.Delay = 0
	return fmt.Sprintln("Health code set to", s.HealthCode,
		", delay set to", s.Delay)
}
