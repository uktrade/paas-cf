package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	addr := ":" + os.Getenv("PORT")
	srv := &http.Server{
		Addr:         addr,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
	}
	fmt.Println("Listening on", addr)

	http.HandleFunc("/", staticHandler)
	http.HandleFunc("/long-response", longResponseHandler)
	http.HandleFunc("/db", dbHandler)
	http.HandleFunc("/mongo-test", mongoHandler)
	http.HandleFunc("/elasticsearch-test", elasticsearchHandler)
	http.HandleFunc("/redis-test", redisHandler)
	http.HandleFunc("/compose-redis-test", composeRedisHandler)

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Reset(syscall.SIGINT, syscall.SIGTERM)

	shutdownComplete := make(chan bool, 1)

	go func() {
		signal := <-signalChan
		fmt.Printf("Received %s signal, shutting down\n", signal)
		_, shutdown := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdown()
		/*err := srv.Shutdown(ctx)
		if err != nil {
			fmt.Printf("Shutdown returned an error: %s\n", err.Error())
		}*/
		fmt.Println("Shutdown complete")
		shutdownComplete <- true
	}()

	go func() {
		err := srv.ListenAndServe()
		if err != http.ErrServerClosed {
			fmt.Printf("ListenAndServe returned an error: %s\n", err.Error())
		}
	}()

	<-shutdownComplete
	fmt.Println("Exiting")
}

func staticHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "max-age=0,no-store,no-cache")
	http.ServeFile(w, r, "static/"+r.URL.Path[1:])
}

func longResponseHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "max-age=0,no-store,no-cache")
	time.Sleep(10 * time.Second)
	http.ServeFile(w, r, "static/index.html")
}

func writeJson(w http.ResponseWriter, data interface{}) {
	output, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Cache-Control", "max-age=0,no-store,no-cache")
	w.Header().Set("Content-Type", "application/json")
	w.Write(output)
}

func buildTLSConfigWithCACert(caCertBase64 string) (*tls.Config, error) {
	ca, err := base64.StdEncoding.DecodeString(caCertBase64)
	if err != nil {
		return nil, err
	}
	roots := x509.NewCertPool()
	ok := roots.AppendCertsFromPEM(ca)
	if !ok {
		return nil, fmt.Errorf("Failed to parse CA certificate")
	}

	return &tls.Config{RootCAs: roots}, nil
}
