# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o billing-data-aggregator \
    ./cmd/aggregator

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/billing-data-aggregator /usr/local/bin/

# Copy SQL scripts
COPY scripts/ /app/scripts/

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

# Environment defaults
ENV BDA_SCRIPTS_DIR=/app/scripts \
    BDA_LOG_LEVEL=info

ENTRYPOINT ["/usr/local/bin/billing-data-aggregator"]
