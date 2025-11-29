package main

import (
	"fmt"
	"net/http"

	"github.com/whisper-sagemaker/api/src/config"
	"github.com/whisper-sagemaker/api/src/routes"
	"github.com/whisper-sagemaker/api/src/utils"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize logger
	logger := utils.NewLogger()
	logger.Info("Starting Whisper SageMaker API...")
	logger.Info(fmt.Sprintf("SageMaker Endpoint: %s", cfg.SageMakerEndpoint))
	logger.Info(fmt.Sprintf("AWS Region: %s", cfg.AWSRegion))

	// Setup routes
	router := routes.SetupRoutes(cfg, logger)

	// Start server
	addr := ":" + cfg.Port
	logger.Info(fmt.Sprintf("Server listening on %s", addr))

	if err := http.ListenAndServe(addr, router); err != nil {
		logger.Fatal("Server failed to start:", err)
	}
}
