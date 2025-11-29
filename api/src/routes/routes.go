package routes

import (
	"net/http"

	"github.com/whisper-sagemaker/api/src/config"
	"github.com/whisper-sagemaker/api/src/handlers"
	"github.com/whisper-sagemaker/api/src/middleware"
	"github.com/whisper-sagemaker/api/src/utils"
)

func SetupRoutes(cfg *config.Config, logger *utils.Logger) http.Handler {
	mux := http.NewServeMux()

	// Create handler instance
	h := handlers.NewHandler(cfg, logger)

	// Apply middleware
	handler := middleware.CORS(cfg)(
		middleware.Logging(logger)(
			mux,
		),
	)

	// Health check
	mux.HandleFunc("/health", h.HealthCheck)

	// Transcription endpoint
	mux.HandleFunc("/transcribe", h.Transcribe)

	// Status endpoint (for async operations)
	mux.HandleFunc("/status/", h.Status)

	return handler
}
