package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

var rawJSON []byte
var jsonError error

func init() {
	data, err := os.ReadFile("/data.json")
	if err != nil {
		log.Printf("Error reading data.json: %v", err)
		jsonError = err
		return
	}
	if !json.Valid(data) {
		log.Printf("Invalid JSON in data.json")
		jsonError = fmt.Errorf("invalid JSON in data.json")
		return
	}
	rawJSON = data
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "could not get hostname"})
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"name": hostname})
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if jsonError != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": jsonError.Error()})
		return
	}
	w.Write(rawJSON)
}

func main() {
	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/api", apiHandler)
	log.Println("Starting server on :80")
	http.ListenAndServe(":80", nil)
}
