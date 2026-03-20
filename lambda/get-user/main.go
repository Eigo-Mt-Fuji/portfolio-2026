package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// User represents a user record.
type User struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"createdAt"`
}

// mockUsers is the in-memory mock data store.
var mockUsers = map[string]User{
	"1": {
		ID:        "1",
		Name:      "Alice Tanaka",
		Email:     "alice@example.com",
		CreatedAt: time.Date(2025, 1, 15, 9, 0, 0, 0, time.UTC),
	},
	"2": {
		ID:        "2",
		Name:      "Bob Suzuki",
		Email:     "bob@example.com",
		CreatedAt: time.Date(2025, 3, 22, 14, 30, 0, 0, time.UTC),
	},
	"3": {
		ID:        "3",
		Name:      "Carol Yamamoto",
		Email:     "carol@example.com",
		CreatedAt: time.Date(2025, 6, 10, 11, 15, 0, 0, time.UTC),
	},
}

// ErrorResponse is the JSON body returned on error.
type ErrorResponse struct {
	Message string `json:"message"`
}

func buildResponse(statusCode int, body interface{}) (events.APIGatewayProxyResponse, error) {
	b, err := json.Marshal(body)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError}, err
	}
	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(b),
	}, nil
}

// Handler is the Lambda entry point.
func Handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	userID, ok := req.PathParameters["id"]
	if !ok || userID == "" {
		return buildResponse(http.StatusBadRequest, ErrorResponse{Message: "missing path parameter: id"})
	}

	user, found := mockUsers[userID]
	if !found {
		return buildResponse(http.StatusNotFound, ErrorResponse{Message: fmt.Sprintf("user not found: %s", userID)})
	}

	return buildResponse(http.StatusOK, user)
}

func main() {
	lambda.Start(Handler)
}
