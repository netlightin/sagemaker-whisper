package middleware

import (
	"encoding/json"
	"net/http"

	"github.com/loud-meadow/api/src/utils"
)

type ErrorResponse struct {
	Error string `json:"error"`
}

// Auth middleware validates the x-api-key header
func Auth(apiKey string, logger *utils.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Get the x-api-key header
			providedKey := r.Header.Get("x-api-key")

			// Check if key is provided and matches
			if providedKey != apiKey {
				logger.Info("auth_failed", "path", r.URL.Path, "method", r.Method)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusUnauthorized)
				json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid or missing API key"})
				return
			}

			// Key is valid, proceed
			next.ServeHTTP(w, r)
		})
	}
}
