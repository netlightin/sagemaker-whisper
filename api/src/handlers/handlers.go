package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sagemakerruntime"
	"github.com/whisper-sagemaker/api/src/config"
	"github.com/whisper-sagemaker/api/src/utils"
)

type Handler struct {
	cfg              *config.Config
	logger           *utils.Logger
	sagemakerClient  *sagemakerruntime.Client
}

type TranscriptionResponse struct {
	Text     string  `json:"text"`
	Language string  `json:"language,omitempty"`
	Duration float64 `json:"duration,omitempty"`
}

// SageMaker response format from the inference endpoint
type SageMakerResponse struct {
	Success      bool                       `json:"success"`
	Transcription string                     `json:"transcription"`
	Metadata      SageMakerResponseMetadata `json:"metadata"`
}

type SageMakerResponseMetadata struct {
	Language                 string  `json:"language"`
	Task                     string  `json:"task"`
	Model                    string  `json:"model"`
	InferenceTimeSeconds     float64 `json:"inference_time_seconds"`
	AudioDurationSeconds     float64 `json:"audio_duration_seconds"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type HealthResponse struct {
	Status   string `json:"status"`
	Endpoint string `json:"endpoint"`
}

func NewHandler(cfg *config.Config, logger *utils.Logger) *Handler {
	// Load AWS configuration
	awsCfg, err := awsconfig.LoadDefaultConfig(context.TODO(),
		awsconfig.WithRegion(cfg.AWSRegion),
	)
	if err != nil {
		logger.Fatal("Failed to load AWS config:", err)
	}

	return &Handler{
		cfg:             cfg,
		logger:          logger,
		sagemakerClient: sagemakerruntime.NewFromConfig(awsCfg),
	}
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:   "healthy",
		Endpoint: h.cfg.SageMakerEndpoint,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) Transcribe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form
	err := r.ParseMultipartForm(h.cfg.MaxFileSize)
	if err != nil {
		h.logger.Error("Failed to parse multipart form:", err)
		h.sendError(w, "Failed to parse form data", http.StatusBadRequest)
		return
	}

	// Get the uploaded file
	file, header, err := r.FormFile("audio")
	if err != nil {
		h.logger.Error("Failed to get audio file:", err)
		h.sendError(w, "No audio file provided", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Validate file extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	allowedFormats := []string{".mp3", ".wav", ".m4a", ".flac", ".ogg", ".webm"}
	if !contains(allowedFormats, ext) {
		h.sendError(w, fmt.Sprintf("Unsupported audio format: %s. Allowed formats: %v", ext, allowedFormats), http.StatusBadRequest)
		return
	}

	// Validate file size
	if header.Size > h.cfg.MaxFileSize {
		h.sendError(w, fmt.Sprintf("File size exceeds maximum of %d MB", h.cfg.MaxFileSize/(1024*1024)), http.StatusBadRequest)
		return
	}

	h.logger.Info(fmt.Sprintf("Processing audio file: %s (%d bytes)", header.Filename, header.Size))

	// Read file content
	audioData, err := io.ReadAll(file)
	if err != nil {
		h.logger.Error("Failed to read audio file:", err)
		h.sendError(w, "Failed to read audio file", http.StatusInternalServerError)
		return
	}

	// Invoke SageMaker endpoint
	transcription, err := h.invokeSageMaker(audioData)
	if err != nil {
		h.logger.Error("SageMaker invocation failed:", err)
		h.sendError(w, "Transcription failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Send response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(transcription)
}

func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	// Extract job ID from path
	jobID := strings.TrimPrefix(r.URL.Path, "/status/")

	if jobID == "" {
		h.sendError(w, "Job ID required", http.StatusBadRequest)
		return
	}

	// For now, return a simple response
	// In a real implementation, you would check job status from a database or cache
	response := map[string]string{
		"jobId":  jobID,
		"status": "not_implemented",
		"message": "Async processing not yet implemented",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) invokeSageMaker(audioData []byte) (*TranscriptionResponse, error) {
	ctx := context.TODO()

	// Invoke the SageMaker endpoint
	input := &sagemakerruntime.InvokeEndpointInput{
		EndpointName: aws.String(h.cfg.SageMakerEndpoint),
		ContentType:  aws.String("application/octet-stream"),
		Body:         audioData,
	}

	h.logger.Info("Invoking SageMaker endpoint...")
	result, err := h.sagemakerClient.InvokeEndpoint(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("SageMaker invocation error: %w", err)
	}

	// Parse SageMaker response
	var sagemakerResp SageMakerResponse
	if err := json.Unmarshal(result.Body, &sagemakerResp); err != nil {
		return nil, fmt.Errorf("failed to parse SageMaker response: %w", err)
	}

	// Check if transcription was successful
	if !sagemakerResp.Success {
		return nil, fmt.Errorf("transcription failed")
	}

	// Convert to API response format
	transcription := &TranscriptionResponse{
		Text:     sagemakerResp.Transcription,
		Language: sagemakerResp.Metadata.Language,
		Duration: sagemakerResp.Metadata.AudioDurationSeconds,
	}

	h.logger.Info("Transcription completed successfully")
	return transcription, nil
}

func (h *Handler) sendError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(ErrorResponse{Error: message})
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
