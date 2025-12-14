package config

import (
	"fmt"
	"log"
	"os"
)

type Config struct {
	Port                 string
	SageMakerEndpoint    string
	AWSRegion            string
	MaxFileSize          int64
	AllowedOrigins       []string
	LogLevel             string
}

func Load() *Config {
	cfg := &Config{
		Port:              getEnv("PORT", "8080"),
		SageMakerEndpoint: getEnv("SAGEMAKER_ENDPOINT_NAME", ""),
		AWSRegion:         getEnv("AWS_REGION", "eu-west-1"),
		MaxFileSize:       getEnvAsInt64("MAX_FILE_SIZE", 100*1024*1024), // 100MB default
		AllowedOrigins:    []string{getEnv("ALLOWED_ORIGINS", "*")},
		LogLevel:          getEnv("LOG_LEVEL", "info"),
	}

	if cfg.SageMakerEndpoint == "" {
		log.Fatal("SAGEMAKER_ENDPOINT_NAME environment variable is required")
	}

	return cfg
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt64(key string, defaultValue int64) int64 {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}
	var value int64
	_, err := fmt.Sscanf(valueStr, "%d", &value)
	if err != nil {
		return defaultValue
	}
	return value
}
