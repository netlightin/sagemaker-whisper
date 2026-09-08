package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sagemakerruntime"
)

// S3 bucket for batch transcription - hardcoded as per user preference
const BatchTranscriptionBucket = "loud-meadow-transcription"

// BatchFileResult represents the result for a single file
type BatchFileResult struct {
	InputKey      string    `json:"input_key"`
	OutputKey     string    `json:"output_key,omitempty"`
	Language      string    `json:"language"`
	Status        string    `json:"status"` // "pending", "processing", "completed", "failed"
	StartTime     time.Time `json:"start_time,omitempty"`
	EndTime       time.Time `json:"end_time,omitempty"`
	DurationMs    float64   `json:"duration_ms,omitempty"`
	Error         string    `json:"error,omitempty"`
}

// BatchJobState holds the current state of a batch transcription job
type BatchJobState struct {
	ID              string            `json:"id"`
	Status          string            `json:"status"` // "pending", "running", "completed", "failed"
	StartTime       time.Time         `json:"start_time"`
	EndTime         time.Time         `json:"end_time,omitempty"`
	TotalDuration   float64           `json:"total_duration_seconds,omitempty"`
	TotalFiles      int               `json:"total_files"`
	ProcessedFiles  int               `json:"processed_files"`
	SuccessfulFiles int               `json:"successful_files"`
	FailedFiles     int               `json:"failed_files"`
	Results         []BatchFileResult `json:"results"`
	ErrorMessage    string            `json:"error_message,omitempty"`
}

// Global batch job states - map of ID to job state
var (
	batchJobStates = make(map[string]*BatchJobState)
	batchJobMutex  sync.RWMutex
)

// BatchTranscribe handles GET /batch-transcribe
func (h *Handler) BatchTranscribe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	jobID, err := h.StartBatchJob()
	if err != nil {
		h.logger.Error("Failed to start batch job:", err)
		h.sendError(w, "Failed to start batch job: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":     jobID,
		"status": "running",
		"bucket": BatchTranscriptionBucket,
	})
}

// BatchTranscribeStatus handles GET /batch-transcribe/status?id=xxx
func (h *Handler) BatchTranscribeStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	jobID := r.URL.Query().Get("id")
	if jobID == "" {
		h.sendError(w, "id parameter required", http.StatusBadRequest)
		return
	}

	status := h.GetBatchJobStatus(jobID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

// StartBatchJob begins a new batch transcription job asynchronously and returns a job ID
func (h *Handler) StartBatchJob() (string, error) {
	jobID := generateID()

	jobState := &BatchJobState{
		ID:              jobID,
		Status:          "running",
		StartTime:       time.Now(),
		TotalFiles:      0,
		ProcessedFiles:  0,
		SuccessfulFiles: 0,
		FailedFiles:     0,
		Results:         []BatchFileResult{},
	}

	batchJobMutex.Lock()
	batchJobStates[jobID] = jobState
	batchJobMutex.Unlock()

	// Run job in goroutine to respond immediately
	go h.runBatchJob(jobID)

	return jobID, nil
}

// runBatchJob executes the batch transcription job
func (h *Handler) runBatchJob(jobID string) {
	defer func() {
		batchJobMutex.Lock()
		if state, exists := batchJobStates[jobID]; exists && state.Status == "running" {
			if state.FailedFiles > 0 && state.SuccessfulFiles == 0 {
				state.Status = "failed"
			} else {
				state.Status = "completed"
			}
			state.EndTime = time.Now()
			state.TotalDuration = state.EndTime.Sub(state.StartTime).Seconds()
		}
		batchJobMutex.Unlock()
	}()

	ctx := context.TODO()

	// List files in input/swedish/ and input/english/
	languagePrefixes := map[string]string{
		"input/swedish/": "sv",
		"input/english/": "en",
	}

	var allFiles []BatchFileResult

	for prefix, language := range languagePrefixes {
		files, err := h.listS3Files(ctx, BatchTranscriptionBucket, prefix)
		if err != nil {
			h.logger.Error(fmt.Sprintf("Failed to list files in %s: %v", prefix, err))
			continue
		}

		for _, key := range files {
			allFiles = append(allFiles, BatchFileResult{
				InputKey: key,
				Language: language,
				Status:   "pending",
			})
		}
	}

	// Update total file count
	batchJobMutex.Lock()
	if state, exists := batchJobStates[jobID]; exists {
		state.TotalFiles = len(allFiles)
		state.Results = allFiles
	}
	batchJobMutex.Unlock()

	if len(allFiles) == 0 {
		h.logger.Info("No files found to process")
		return
	}

	h.logger.Info(fmt.Sprintf("Batch job %s: Found %d files to process", jobID, len(allFiles)))

	// Process each file sequentially
	for i, fileResult := range allFiles {
		// Update status to processing
		batchJobMutex.Lock()
		if state, exists := batchJobStates[jobID]; exists {
			state.Results[i].Status = "processing"
			state.Results[i].StartTime = time.Now()
		}
		batchJobMutex.Unlock()

		// Invoke SageMaker with S3 URL
		s3URL := fmt.Sprintf("s3://%s/%s", BatchTranscriptionBucket, fileResult.InputKey)
		transcription, err := h.invokeSageMakerWithS3URL(s3URL, fileResult.Language)

		endTime := time.Now()

		batchJobMutex.Lock()
		if state, exists := batchJobStates[jobID]; exists {
			state.Results[i].EndTime = endTime
			state.Results[i].DurationMs = endTime.Sub(state.Results[i].StartTime).Seconds() * 1000
			state.ProcessedFiles++

			if err != nil {
				state.Results[i].Status = "failed"
				state.Results[i].Error = err.Error()
				state.FailedFiles++
				h.logger.Error(fmt.Sprintf("Failed to transcribe %s: %v", fileResult.InputKey, err))
			} else {
				// Write output to S3
				outputKey := h.getOutputKey(fileResult.InputKey)
				writeErr := h.writeTranscriptionToS3(ctx, BatchTranscriptionBucket, outputKey, transcription.Text)

				if writeErr != nil {
					state.Results[i].Status = "failed"
					state.Results[i].Error = "Failed to write output: " + writeErr.Error()
					state.FailedFiles++
					h.logger.Error(fmt.Sprintf("Failed to write output for %s: %v", fileResult.InputKey, writeErr))
				} else {
					state.Results[i].Status = "completed"
					state.Results[i].OutputKey = outputKey
					state.SuccessfulFiles++
					h.logger.Info(fmt.Sprintf("Successfully transcribed %s -> %s", fileResult.InputKey, outputKey))
				}
			}
		}
		batchJobMutex.Unlock()
	}
}

// GetBatchJobStatus returns the current job status for a given ID
func (h *Handler) GetBatchJobStatus(jobID string) *BatchJobState {
	batchJobMutex.RLock()
	defer batchJobMutex.RUnlock()

	if state, exists := batchJobStates[jobID]; exists {
		// Create a copy to avoid race conditions
		stateCopy := *state
		resultsCopy := make([]BatchFileResult, len(state.Results))
		copy(resultsCopy, state.Results)
		stateCopy.Results = resultsCopy
		return &stateCopy
	}

	return &BatchJobState{
		ID:     jobID,
		Status: "not_found",
	}
}

// listS3Files lists all files in an S3 bucket with a given prefix
func (h *Handler) listS3Files(ctx context.Context, bucket, prefix string) ([]string, error) {
	var files []string

	paginator := s3.NewListObjectsV2Paginator(h.s3Client, &s3.ListObjectsV2Input{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, err
		}

		for _, obj := range page.Contents {
			key := aws.ToString(obj.Key)
			// Skip directories (keys ending with /)
			if !strings.HasSuffix(key, "/") {
				// Only include audio files
				ext := strings.ToLower(filepath.Ext(key))
				if isAudioFile(ext) {
					files = append(files, key)
				}
			}
		}
	}

	return files, nil
}

// isAudioFile checks if the file extension is a supported audio format
func isAudioFile(ext string) bool {
	supportedFormats := []string{".mp3", ".wav", ".m4a", ".flac", ".ogg", ".webm"}
	for _, format := range supportedFormats {
		if ext == format {
			return true
		}
	}
	return false
}

// getOutputKey converts input key to output key
// e.g., input/swedish/audio1.mp3 -> output/swedish/audio1.txt
func (h *Handler) getOutputKey(inputKey string) string {
	// Replace input/ with output/
	outputKey := strings.Replace(inputKey, "input/", "output/", 1)
	// Replace extension with .txt
	ext := filepath.Ext(outputKey)
	outputKey = outputKey[:len(outputKey)-len(ext)] + ".txt"
	return outputKey
}

// invokeSageMakerWithS3URL invokes SageMaker with an S3 audio URL
func (h *Handler) invokeSageMakerWithS3URL(audioURL, language string) (*TranscriptionResponse, error) {
	ctx := context.TODO()

	// Build JSON payload matching inference.py's expected format
	payload := map[string]string{
		"audio_url": audioURL,
		"language":  language,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %w", err)
	}

	input := &sagemakerruntime.InvokeEndpointInput{
		EndpointName: aws.String(h.cfg.SageMakerEndpoint),
		ContentType:  aws.String("application/json"),
		Body:         payloadBytes,
	}

	h.logger.Info(fmt.Sprintf("Invoking SageMaker with S3 URL: %s (language: %s)", audioURL, language))
	result, err := h.sagemakerClient.InvokeEndpoint(ctx, input)
	if err != nil {
		return nil, fmt.Errorf("SageMaker invocation error: %w", err)
	}

	// Parse SageMaker response
	var sagemakerResp SageMakerResponse
	if err := json.Unmarshal(result.Body, &sagemakerResp); err != nil {
		return nil, fmt.Errorf("failed to parse SageMaker response: %w", err)
	}

	if !sagemakerResp.Success {
		return nil, fmt.Errorf("transcription failed")
	}

	return &TranscriptionResponse{
		Text:     sagemakerResp.Transcription,
		Language: sagemakerResp.Metadata.Language,
		Duration: sagemakerResp.Metadata.AudioDurationSeconds,
	}, nil
}

// writeTranscriptionToS3 writes the transcription text to S3
func (h *Handler) writeTranscriptionToS3(ctx context.Context, bucket, key, text string) error {
	_, err := h.s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader([]byte(text)),
		ContentType: aws.String("text/plain; charset=utf-8"),
	})
	return err
}
