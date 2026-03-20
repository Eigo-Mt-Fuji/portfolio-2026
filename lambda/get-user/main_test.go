package main

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func makeRequest(userID string) events.APIGatewayProxyRequest {
	return events.APIGatewayProxyRequest{
		PathParameters: map[string]string{
			"id": userID,
		},
	}
}

func makeRequestNoParams() events.APIGatewayProxyRequest {
	return events.APIGatewayProxyRequest{}
}

func TestHandler_Success(t *testing.T) {
	resp, err := Handler(context.Background(), makeRequest("1"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected status 200, got %d", resp.StatusCode)
	}

	var user User
	if err := json.Unmarshal([]byte(resp.Body), &user); err != nil {
		t.Fatalf("failed to unmarshal response body: %v", err)
	}
	if user.ID != "1" {
		t.Errorf("expected id '1', got '%s'", user.ID)
	}
	if user.Name != "Alice Tanaka" {
		t.Errorf("expected name 'Alice Tanaka', got '%s'", user.Name)
	}
	if user.Email != "alice@example.com" {
		t.Errorf("expected email 'alice@example.com', got '%s'", user.Email)
	}
}

func TestHandler_AllMockUsers(t *testing.T) {
	ids := []string{"1", "2", "3"}
	for _, id := range ids {
		t.Run("user_"+id, func(t *testing.T) {
			resp, err := Handler(context.Background(), makeRequest(id))
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if resp.StatusCode != http.StatusOK {
				t.Fatalf("expected status 200, got %d (body: %s)", resp.StatusCode, resp.Body)
			}
			var user User
			if err := json.Unmarshal([]byte(resp.Body), &user); err != nil {
				t.Fatalf("failed to unmarshal response: %v", err)
			}
			if user.ID != id {
				t.Errorf("expected id %s, got %s", id, user.ID)
			}
		})
	}
}

func TestHandler_NotFound(t *testing.T) {
	resp, err := Handler(context.Background(), makeRequest("999"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", resp.StatusCode)
	}

	var errResp ErrorResponse
	if err := json.Unmarshal([]byte(resp.Body), &errResp); err != nil {
		t.Fatalf("failed to unmarshal error response: %v", err)
	}
	if errResp.Message == "" {
		t.Error("expected non-empty error message")
	}
}

func TestHandler_MissingID(t *testing.T) {
	resp, err := Handler(context.Background(), makeRequestNoParams())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", resp.StatusCode)
	}
}

func TestHandler_ContentTypeHeader(t *testing.T) {
	resp, err := Handler(context.Background(), makeRequest("1"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	ct := resp.Headers["Content-Type"]
	if ct != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got '%s'", ct)
	}
}
