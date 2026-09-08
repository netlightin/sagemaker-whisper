package routes

import (
	"net/http"

	"github.com/loud-meadow/api/src/config"
	"github.com/loud-meadow/api/src/handlers"
	"github.com/loud-meadow/api/src/middleware"
	"github.com/loud-meadow/api/src/utils"
)

func SetupRoutes(cfg *config.Config, logger *utils.Logger) http.Handler {
	logger.Info("Setting up routes...")

	// Create handler instance
	h := handlers.NewHandler(cfg, logger)

	// Create a multiplexer for protected routes (with auth)
	protectedMux := http.NewServeMux()
	logger.Info("Registering /transcribe endpoint (protected)")
	protectedMux.HandleFunc("/transcribe", h.Transcribe)
	logger.Info("Registering /status/ endpoint (protected)")
	protectedMux.HandleFunc("/status/", h.Status)
	logger.Info("Registering /load-test endpoint (protected)")
	protectedMux.HandleFunc("/load-test", h.Test)
	logger.Info("Registering /load-test/status endpoint (protected)")
	protectedMux.HandleFunc("/load-test/status", h.TestStatus)
	logger.Info("Registering /batch-transcribe endpoint (protected)")
	protectedMux.HandleFunc("/batch-transcribe", h.BatchTranscribe)
	logger.Info("Registering /batch-transcribe/status endpoint (protected)")
	protectedMux.HandleFunc("/batch-transcribe/status", h.BatchTranscribeStatus)

	// Protected routes with auth middleware
	protectedHandler := middleware.CORS(cfg)(
		middleware.Logging(logger)(
			middleware.Auth(cfg.APIKey, logger)(
				protectedMux,
			),
		),
	)

	// Create main multiplexer for all routes
	mainMux := http.NewServeMux()

	// Health check endpoint - no auth required
	logger.Info("Registering /health endpoint (unprotected)")
	healthMux := http.NewServeMux()
	healthMux.HandleFunc("/health", h.HealthCheck)
	healthHandler := middleware.CORS(cfg)(
		middleware.Logging(logger)(
			healthMux,
		),
	)

	// Route /health to unprotected handler
	mainMux.Handle("/health", healthHandler)
	// Route everything else to protected handler
	mainMux.Handle("/", protectedHandler)

	logger.Info("Routes setup completed")
	return mainMux
}
