package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
)

// generateID generates a random ID string
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

// categorizeError categorizes errors based on their type and message
func categorizeError(errStr string) string {
	if errStr == "" {
		return ""
	}

	lowerErr := strings.ToLower(errStr)

	// Common SageMaker error patterns
	patterns := map[string][]string{
		"throttling":          {"throttling", "too many requests", "rate exceeded"},
		"timeout":             {"timeout", "deadline exceeded", "context deadline"},
		"service_unavailable": {"unavailable", "service unavailable", "temporarily unavailable"},
		"out_of_memory":       {"out of memory", "memory", "allocation"},
		"gpu_error":           {"gpu", "graphics", "compute"},
		"connection_error":    {"connection refused", "connection reset", "network"},
		"invalid_request":     {"invalid", "malformed", "bad request"},
	}

	for category, keywords := range patterns {
		for _, keyword := range keywords {
			if strings.Contains(lowerErr, keyword) {
				return category
			}
		}
	}

	return "other_error"
}

// TestRequest represents a single request in the load test
type TestRequest struct {
	RequestID     int           `json:"request_id"`
	StartTime     time.Time     `json:"start_time"`
	EndTime       time.Time     `json:"end_time"`
	Duration      float64       `json:"duration_ms"`
	Transcription string        `json:"transcription"`
	Error         string        `json:"error,omitempty"`
	InferenceTime float64       `json:"inference_time_seconds,omitempty"`
	AudioDuration float64       `json:"audio_duration_seconds,omitempty"`
}

// LoadTestState holds the current state of a load test
type LoadTestState struct {
	ID                     string         `json:"id"`
	Status                 string         `json:"status"`
	StartTime              time.Time      `json:"start_time"`
	EndTime                time.Time      `json:"end_time,omitempty"`
	TotalDuration          float64        `json:"total_duration_seconds,omitempty"`
	NumberOfRequests       int            `json:"number_of_requests"`
	CompletedRequests      int            `json:"completed_requests"`
	SuccessfulRequests     int            `json:"successful_requests"`
	FailedRequests         int            `json:"failed_requests"`
	AverageLatency         float64        `json:"average_latency_ms"`
	MaxLatency             float64        `json:"max_latency_ms"`
	MinLatency             float64        `json:"min_latency_ms"`
	Results                []TestRequest  `json:"results"`
	ErrorMessage           string         `json:"error_message,omitempty"`
	ErrorSummary           map[string]int `json:"error_summary,omitempty"`
}

// Global test states - map of ID to test state
var (
	testStates = make(map[string]*LoadTestState)
	stateMutex sync.RWMutex
)

// StartLoadTest begins a new load test asynchronously and returns a test ID
func (h *Handler) StartLoadTest(audioPath string, numberOfRequests int) (string, error) {
	testID := generateID()

	testState := &LoadTestState{
		ID:               testID,
		Status:           "running",
		StartTime:        time.Now(),
		NumberOfRequests: numberOfRequests,
		CompletedRequests: 0,
		SuccessfulRequests: 0,
		FailedRequests:   0,
		Results:          []TestRequest{},
		ErrorSummary:     make(map[string]int),
	}

	stateMutex.Lock()
	testStates[testID] = testState
	stateMutex.Unlock()

	// Run test in goroutine to respond immediately
	go h.runLoadTest(testID, audioPath, numberOfRequests)

	return testID, nil
}

// runLoadTest executes the load test with the specified number of concurrent requests
func (h *Handler) runLoadTest(testID string, audioPath string, numberOfRequests int) {
	defer func() {
		stateMutex.Lock()
		if state, exists := testStates[testID]; exists && state.Status == "running" {
			state.Status = "Succeeded"
			state.EndTime = time.Now()
			state.TotalDuration = state.EndTime.Sub(state.StartTime).Seconds()
			calculateStats(state)
		}
		stateMutex.Unlock()
	}()

	// Read the audio file once
	audioData, err := os.ReadFile(audioPath)
	if err != nil {
		stateMutex.Lock()
		if state, exists := testStates[testID]; exists {
			state.Status = "Failed"
			state.ErrorMessage = "Failed to read audio file: " + err.Error()
		}
		stateMutex.Unlock()
		h.logger.Error("Failed to read audio file:", err)
		return
	}

	h.logger.Info(fmt.Sprintf("Load test %s starting with %d concurrent requests", testID, numberOfRequests))

	// Submit all requests concurrently, synchronized to start at the same time
	var wg sync.WaitGroup
	cycleStartTime := time.Now()

	for i := range numberOfRequests {
		wg.Add(1)
		go func(reqID int) {
			defer wg.Done()

			// Wait for synchronization point - all requests start nearly at the same time
			time.Sleep(time.Until(cycleStartTime))

			testRequest := TestRequest{
				RequestID: reqID,
				StartTime: time.Now(),
			}

			// Invoke SageMaker
			transcription, err := h.invokeSageMaker(audioData)
			testRequest.EndTime = time.Now()
			testRequest.Duration = testRequest.EndTime.Sub(testRequest.StartTime).Seconds() * 1000 // Convert to ms

			if err != nil {
				errMsg := err.Error()
				testRequest.Error = errMsg
				errCategory := categorizeError(errMsg)

				stateMutex.Lock()
				if state, exists := testStates[testID]; exists {
					state.FailedRequests++
					state.CompletedRequests++
					if state.ErrorSummary == nil {
						state.ErrorSummary = make(map[string]int)
					}
					state.ErrorSummary[errCategory]++
				}
				stateMutex.Unlock()
			} else {
				testRequest.Transcription = transcription.Text
				testRequest.InferenceTime = transcription.Duration
				testRequest.AudioDuration = transcription.Duration
				stateMutex.Lock()
				if state, exists := testStates[testID]; exists {
					state.SuccessfulRequests++
					state.CompletedRequests++
				}
				stateMutex.Unlock()
			}

			// Store result
			stateMutex.Lock()
			if state, exists := testStates[testID]; exists {
				state.Results = append(state.Results, testRequest)
			}
			stateMutex.Unlock()
		}(i)
	}

	wg.Wait()
}

// GetTestStatus returns the current test status for a given ID
func (h *Handler) GetTestStatus(testID string) *LoadTestState {
	stateMutex.RLock()
	defer stateMutex.RUnlock()

	if state, exists := testStates[testID]; exists {
		// Create a copy to avoid race conditions
		stateCopy := *state
		return &stateCopy
	}

	return &LoadTestState{
		ID:     testID,
		Status: "not_found",
	}
}

// calculateStats computes statistics for the test results
func calculateStats(state *LoadTestState) {
	if len(state.Results) == 0 {
		return
	}

	totalLatency := 0.0
	maxLatency := 0.0
	minLatency := float64(time.Hour.Milliseconds()) // Large initial value

	for _, result := range state.Results {
		latency := result.Duration // Already in milliseconds
		totalLatency += latency

		if latency > maxLatency {
			maxLatency = latency
		}
		if latency < minLatency {
			minLatency = latency
		}
	}

	state.AverageLatency = totalLatency / float64(len(state.Results))
	state.MaxLatency = maxLatency
	if minLatency == float64(time.Hour.Milliseconds()) {
		state.MinLatency = 0
	} else {
		state.MinLatency = minLatency
	}
}
