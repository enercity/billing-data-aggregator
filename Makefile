.PHONY: help test test-unit test-bdd test-coverage lint fmt build clean

# Default target
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests (unit + BDD)"
	@echo "  test-unit     - Run unit tests only"
	@echo "  test-bdd      - Run BDD/Gherkin tests"
	@echo "  test-coverage - Run tests with coverage report"
	@echo "  lint          - Run linters (golangci-lint)"
	@echo "  fmt           - Format code (gofmt + goimports)"
	@echo "  build         - Build the application"
	@echo "  clean         - Clean build artifacts"

# Run all tests
test: test-unit test-bdd

# Run unit tests
test-unit:
	@echo "Running unit tests..."
	go test -v -race ./internal/...

# Run BDD tests
test-bdd:
	@echo "Running BDD tests..."
	go test -v ./test/... -godog.format=pretty

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run specific BDD feature
test-feature:
	@if [ -z "$(FEATURE)" ]; then \
		echo "Usage: make test-feature FEATURE=configuration"; \
		exit 1; \
	fi
	go test -v ./test/... -godog.format=pretty -godog.paths=features/$(FEATURE).feature

# Run linters
lint:
	@echo "Running linters..."
	golangci-lint run --enable=staticcheck,govet,errcheck,unused,ineffassign,misspell,gocyclo,gosec --disable=revive ./...

# Format code
fmt:
	@echo "Formatting code..."
	gofmt -w -s .
	@if command -v goimports >/dev/null 2>&1; then \
		goimports -w .; \
	else \
		echo "goimports not found, skipping..."; \
	fi

# Build application
build:
	@echo "Building application..."
	go build -o dist/billing-data-aggregator ./cmd/aggregator

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf dist/
	rm -f coverage.out coverage.html
	go clean -cache

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod tidy

# Install development tools
dev-tools:
	@echo "Installing development tools..."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install golang.org/x/tools/cmd/goimports@latest

# Run quick checks (lint + test)
check: lint test-unit
	@echo "All checks passed!"

# Watch tests (requires entr)
watch-test:
	@if ! command -v entr >/dev/null 2>&1; then \
		echo "entr not found. Install with: brew install entr"; \
		exit 1; \
	fi
	@echo "Watching for changes..."
	find . -name '*.go' | entr -c make test-unit

# Generate test fixtures
generate-fixtures:
	@echo "Generating test fixtures..."
	@mkdir -p test/fixtures
	@echo "Fixtures generated in test/fixtures/"

# Docker build
docker-build:
	@echo "Building Docker image..."
	docker build -t billing-data-aggregator:latest .

# Docker test
docker-test:
	@echo "Running tests in Docker..."
	docker run --rm billing-data-aggregator:latest go test -v ./...

# Benchmark tests
benchmark:
	@echo "Running benchmarks..."
	go test -bench=. -benchmem ./...

# Show test statistics
test-stats:
	@echo "Test Statistics:"
	@echo "=================="
	@find . -name '*_test.go' -not -path './vendor/*' | wc -l | xargs echo "Test files:"
	@find . -name '*_test.go' -not -path './vendor/*' -exec grep -h "^func Test" {} \; | wc -l | xargs echo "Test functions:"
	@find features -name '*.feature' 2>/dev/null | wc -l | xargs echo "Feature files:"
	@find features -name '*.feature' -exec grep -h "Szenario:" {} \; 2>/dev/null | wc -l | xargs echo "BDD Scenarios:"

# Verify module
verify:
	@echo "Verifying module..."
	go mod verify

# Security audit
audit:
	@echo "Running security audit..."
	@if command -v gosec >/dev/null 2>&1; then \
		gosec ./...; \
	else \
		echo "gosec not found. Install with: go install github.com/securego/gosec/v2/cmd/gosec@latest"; \
	fi

# All pre-commit checks
pre-commit: fmt lint test-unit
	@echo "Pre-commit checks completed!"
