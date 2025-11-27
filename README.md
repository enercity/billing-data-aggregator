# billing-data-aggregator

Modern Go-based batch service that aggregates billing data from the Octopus data warehouse and exports results to S3. This is the clean rewrite of `ed4-bi-batch-boil` with improved architecture, better error handling, and enhanced observability.

## Overview

**Purpose**: Daily aggregation of financial billing data for downstream BI/analytics processes.

**Tech Stack**:

- **Language**: Go 1.24+
- **Database**: PostgreSQL (Octopus DWH)
- **Storage**: AWS S3
- **Runtime**: AWS Batch (Docker containers)
- **Deployment**: Terraform + FluxCD
- **CI/CD**: GitHub Actions

**Data Sources**:

- **Tripica**: Billing charges, account balances, dunning processes, write-offs
- **Bookkeeper**: SAP bookings, journal entries, tax calculations

## Quick Start

### Local Development

```bash
# Clone and setup
git clone https://github.com/enercity/billing-data-aggregator.git
cd billing-data-aggregator
go mod download

# Run tests
go test ./...

# Build
go build -o dist/billing-data-aggregator ./cmd/aggregator

# Configure environment
export BDA_CLIENT_ID=enercity
export BDA_ENVIRONMENT=dev
export BDA_DB_HOST=localhost
export BDA_DB_PASSWORD=your-secret-password
export BDA_S3_BUCKET=billing-exports-dev

# Run
./dist/billing-data-aggregator
```

### Docker

```bash
docker build -t billing-data-aggregator:local .

docker run --rm \
  -e BDA_CLIENT_ID=enercity \
  -e BDA_ENVIRONMENT=dev \
  -e BDA_DB_HOST=host.docker.internal \
  -e BDA_DB_PASSWORD=secret \
  -e BDA_S3_BUCKET=billing-exports-dev \
  billing-data-aggregator:local
```

## Architecture

### High-Level Data Flow

```text
┌──────────────────────────────────────────────────────────────────┐
│                    Octopus Data Warehouse (PostgreSQL)           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │ Tripica     │  │ Bookkeeper  │  │ Dunning     │               │
│  │ Vault       │  │ Vault       │  │ Vault       │               │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘               │
│         │                 │                 │                    │
│         └─────────────────┴─────────────────┘                    │
│                           ↓                                      │
│              ┌────────────────────────────┐                      │
│              │  billing-data-aggregator   │                      │
│              │  (Go Application)          │                      │
│              │                            │                      │
│              │  1. Init Scripts (setup)   │                      │
│              │  2. Processors (transform) │                      │
│              │  3. Export (CSV)           │                      │
│              │  4. Archive Scripts        │                      │
│              └────────────┬───────────────┘                      │
│                           ↓                                      │
│              ┌────────────────────────────┐                      │
│              │  report_oibl Schema        │                      │
│              │  - tripica_results         │                      │
│              │  - bookkeeper_results      │                      │
│              └────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────┘
                            ↓
                 ┌──────────────────────┐
                 │   AWS S3 Bucket      │
                 │   CSV Files          │
                 │   client/environment/│
                 └──────────────────────┘
```

### Component Architecture

```text
cmd/aggregator/main.go
    ↓
internal/config/          → Environment variable configuration
    ↓
internal/database/        → Connection pooling, script execution
    ↓
internal/processors/      → Business logic orchestration
    ├── tripica.go       → Tripica data processing
    └── bookkeeper.go    → Bookkeeper data processing
    ↓
internal/export/          → Result export
    ├── csv.go           → CSV file generation (chunked)
    └── s3.go            → S3 upload with retry logic
    ↓
scripts/                  → SQL transformation scripts
    ├── init/            → Data preparation (system-specific)
    └── archive/         → Export queries (final results)
```

## Configuration

All configuration via environment variables with `BDA_` prefix:

### Core Settings

```bash
# Required
BDA_CLIENT_ID=enercity              # Client identifier
BDA_ENVIRONMENT=prod                # Environment (dev/stage/prod)
BDA_DB_HOST=octopus.db.example.com  # PostgreSQL host
BDA_DB_PASSWORD=xxxxx               # Database password
BDA_S3_BUCKET=billing-exports       # S3 destination bucket
```

### Database Settings

```bash
BDA_DB_PORT=5432                    # Default: 5432
BDA_DB_NAME=octopus                 # Default: octopus
BDA_DB_USER=billing_aggregator      # Default: billing_aggregator
BDA_DB_MAX_CONNS=4                  # Default: 4
BDA_DB_MAX_IDLE=0                   # Default: 0 (unlimited)
BDA_DB_MINUTES_IDLE=5               # Default: 5
```

### Processing Settings

```bash
BDA_SYSTEMS=tripica,bookkeeper      # Default: tripica,bookkeeper
BDA_IGNORE_SYSTEMS=                 # Systems to skip (optional)
BDA_MAX_ROW_SIZE_FILE=1000000       # Rows per CSV file (default: 1M)
BDA_LOG_LEVEL=info                  # debug|info|warn|error
```

### AWS Settings

```bash
BDA_S3_REGION=eu-central-1          # Default: eu-central-1
BDA_S3_URL=                         # Optional: Custom S3 endpoint
BDA_S3_ACCESS_KEY=                  # Optional: Explicit AWS credentials
BDA_S3_SECRET_ACCESS_KEY=           # Optional: Explicit AWS credentials
```

### Complete Configuration Reference

| Variable                   | Required | Default              | Description                          |
| -------------------------- | -------- | -------------------- | ------------------------------------ |
| `BDA_CLIENT_ID`            | ✅       | -                    | Client identifier (enercity, etc)    |
| `BDA_ENVIRONMENT`          | ✅       | auto-detect          | Environment: dev, stage, prod        |
| `BDA_LOG_LEVEL`            | ❌       | `info`               | Log level: debug, info, warn, error  |
| `BDA_DB_HOST`              | ✅       | -                    | PostgreSQL hostname                  |
| `BDA_DB_PORT`              | ❌       | `5432`               | PostgreSQL port                      |
| `BDA_DB_NAME`              | ❌       | `octopus`            | Database name                        |
| `BDA_DB_USER`              | ❌       | `billing_aggregator` | Database username                    |
| `BDA_DB_PASSWORD`          | ✅       | -                    | Database password                    |
| `BDA_DB_MAX_CONNS`         | ❌       | `4`                  | Maximum concurrent connections       |
| `BDA_DB_MAX_IDLE`          | ❌       | `0`                  | Max idle connections (0=unlimited)   |
| `BDA_DB_MINUTES_IDLE`      | ❌       | `5`                  | Idle connection timeout (minutes)    |
| `BDA_S3_BUCKET`            | ✅       | -                    | S3 bucket for CSV exports            |
| `BDA_S3_REGION`            | ❌       | `eu-central-1`       | AWS region                           |
| `BDA_S3_URL`               | ❌       | -                    | Custom S3 endpoint (LocalStack, etc) |
| `BDA_S3_ACCESS_KEY`        | ❌       | -                    | AWS access key (uses IAM if empty)   |
| `BDA_S3_SECRET_ACCESS_KEY` | ❌       | -                    | AWS secret key (uses IAM if empty)   |
| `BDA_SYSTEMS`              | ❌       | `tripica,bookkeeper` | Comma-separated systems to process   |
| `BDA_IGNORE_SYSTEMS`       | ❌       | -                    | Comma-separated systems to skip      |
| `BDA_MAX_ROW_SIZE_FILE`    | ❌       | `1000000`            | Maximum rows per CSV file            |
| `BDA_SCRIPTS_DIR`          | ❌       | `/app/scripts`       | Base directory for SQL scripts       |

## Project Structure

```text
billing-data-aggregator/
├── cmd/
│   └── aggregator/
│       └── main.go                 # Application entry point
│
├── internal/                       # Private application packages
│   ├── config/                     # Configuration management
│   │   ├── config.go              # Environment variable loading
│   │   └── config_test.go         # Configuration tests
│   │
│   ├── database/                   # Database layer
│   │   ├── connection.go          # Connection pooling & retry logic
│   │   ├── scripts.go             # SQL script execution engine
│   │   └── database_test.go       # Database tests
│   │
│   ├── processors/                 # Business logic processors
│   │   ├── processor.go           # Processor interface
│   │   ├── tripica.go             # Tripica data processing
│   │   ├── bookkeeper.go          # Bookkeeper data processing
│   │   └── processor_test.go      # Processor tests
│   │
│   ├── export/                     # Export functionality
│   │   ├── csv.go                 # CSV generation with chunking
│   │   ├── s3.go                  # S3 upload with retry
│   │   └── export_test.go         # Export tests
│   │
│   ├── history/                    # Historical data management
│   ├── validators/                 # Pre-execution validation
│   └── ...                         # Future packages
│
├── scripts/                        # SQL transformation scripts
│   ├── init/                       # Data preparation scripts
│   │   ├── tripica/               # Tripica-specific transformations
│   │   └── bookkeeper/            # Bookkeeper-specific transformations
│   ├── archive/                    # Export/archive queries
│   │   ├── customer/              # Customer data exports
│   │   └── ...
│   ├── history/                    # Historization scripts
│   └── prechecks/                  # Validation/precheck scripts
│
├── terraform/                      # Infrastructure as Code
│   ├── _init.tf                   # Terraform initialization
│   ├── batch.tf                   # AWS Batch configuration
│   ├── s3.tf                      # S3 bucket setup
│   ├── iam.tf                     # IAM roles & policies
│   └── variables.tf               # Terraform variables
│
├── test/                           # Integration tests
│   ├── fixtures/                  # Test data
│   └── integration_test.go        # Integration test suite
│
├── .github/
│   └── workflows/
│       └── ci.yml                 # CI/CD pipeline
│
├── .golangci.yml                   # Linter configuration
├── .goreleaser.yaml                # Release automation
├── Dockerfile                      # Container image definition
├── go.mod                          # Go module definition
├── go.sum                          # Dependency checksums
└── README.md                       # This file
```

## Code Examples

### Configuration Loading

```go
package main

import (
    "github.com/enercity/billing-data-aggregator/internal/config"
)

func main() {
    // Load configuration from environment variables
    cfg, err := config.Load()
    if err != nil {
        log.Fatal(err)
    }

    // Access configuration
    log.Printf("Client: %s", cfg.ClientID)
    log.Printf("Environment: %s", cfg.Environment)
    log.Printf("DB: %s", cfg.Database.Host)

    // Get connection string
    connStr := cfg.ConnectionString()
}
```

### Database Connection

```go
import (
    "context"
    "github.com/enercity/billing-data-aggregator/internal/database"
)

// Create connection with pooling and retry logic
db, err := database.NewConnection(
    cfg.ConnectionString(),
    cfg.DBMaxConnections,    // 4
    cfg.DBMaxIdleConns,      // 0
    cfg.DBConnMaxIdleTime,   // 5 minutes
)
if err != nil {
    return fmt.Errorf("database connection failed: %w", err)
}
defer db.Close()

// Execute query
rows, err := db.QueryContext(ctx, "SELECT * FROM customers LIMIT 10")
```

### Script Execution

```go
import (
    "github.com/enercity/billing-data-aggregator/internal/database"
)

// Create script executor with system filtering
executor := database.NewScriptExecutor(db, cfg.IgnoreSystems)

// Execute all scripts in a directory
// Scripts are executed per system, alphabetically sorted
if err := executor.ExecuteScriptsInDir(ctx, "scripts/init"); err != nil {
    return fmt.Errorf("init scripts failed: %w", err)
}

// Directory structure:
// scripts/init/
//   tripica/
//     110-charges.sql
//     120-balances.sql
//   bookkeeper/
//     100-bookings.sql
```

### Processor Usage

```go
import (
    "github.com/enercity/billing-data-aggregator/internal/processors"
)

// Run configured processors
for _, system := range cfg.Systems {
    var processor processors.Processor

    switch system {
    case "tripica":
        processor = processors.NewTripicaProcessor(db, executor, "scripts")
    case "bookkeeper":
        processor = processors.NewBookkeeperProcessor(db, executor, "scripts")
    }

    if err := processor.Process(ctx); err != nil {
        return fmt.Errorf("processor %s failed: %w", processor.Name(), err)
    }
}
```

### CSV Export

```go
import (
    "github.com/enercity/billing-data-aggregator/internal/export"
)

// Create CSV exporter with chunking
exporter := export.NewCSVExporter(
    db.DB(),
    "/tmp/exports",        // Output directory
    cfg.MaxRowSizeFile,    // 1,000,000 rows per file
)

// Export table to CSV files
files, err := exporter.ExportTable(ctx, "tripica_results", "tripica")
if err != nil {
    return fmt.Errorf("export failed: %w", err)
}

// Result: tripica_tripica_results_0000.csv, _0001.csv, etc.
log.Printf("Exported %d files", len(files))
```

### S3 Upload

```go
import (
    "github.com/enercity/billing-data-aggregator/internal/export"
)

// Create S3 uploader
uploader, err := export.NewS3Uploader(
    ctx,
    cfg.S3.Region,                                    // eu-central-1
    cfg.S3.Bucket,                                    // billing-exports
    fmt.Sprintf("%s/%s", cfg.ClientID, cfg.Environment), // enercity/prod
)
if err != nil {
    return err
}

// Upload files with retry logic (3 attempts)
if err := uploader.UploadFiles(ctx, files); err != nil {
    return fmt.Errorf("S3 upload failed: %w", err)
}

// S3 path: s3://billing-exports/enercity/prod/tripica_results_0000.csv
```

## Development

## Testing

The project uses a comprehensive testing strategy with multiple approaches:

### Test Structure

- **Unit Tests**: Testing individual components with mocks
- **Table-Driven Tests**: Multiple scenarios in a single test
- **BDD/Gherkin Tests**: Behavior-driven tests in German
- **Integration Tests**: End-to-end testing with real dependencies

### Quick Test Commands

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Run BDD tests
make test-bdd

# Generate coverage report
make test-coverage
open coverage.html

# Run tests with race detector
go test -race ./...

# Run specific package
go test ./internal/config/... -v

# Watch mode (auto-rerun on changes)
make watch-test
```

### Unit Tests

Unit tests use `testify` for assertions:

```go
package config_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestLoad(t *testing.T) {
    // Setup
    os.Setenv("BDA_CLIENT_ID", "test-client")
    defer os.Unsetenv("BDA_CLIENT_ID")

    // Execute
    cfg, err := config.Load()

    // Assert
    require.NoError(t, err)
    assert.Equal(t, "test-client", cfg.ClientID)
    assert.Equal(t, 5432, cfg.Database.Port)
}
```

### Table-Driven Tests

For testing multiple scenarios efficiently:

```go
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        cfg     *Config
        wantErr bool
        errMsg  string
    }{
        {
            name: "valid config",
            cfg: &Config{
                ClientID: "enercity",
                Database: DBConfig{Host: "localhost"},
                S3: S3Config{Bucket: "my-bucket"},
            },
            wantErr: false,
        },
        {
            name: "missing client ID",
            cfg: &Config{
                Database: DBConfig{Host: "localhost"},
            },
            wantErr: true,
            errMsg: "CLIENT_ID is required",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.cfg.Validate()
            if tt.wantErr {
                assert.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### BDD/Gherkin Tests

Behavior-driven tests in German using `godog`:

**Feature File** (`features/configuration.feature`):

```gherkin
# language: de
Funktionalität: Konfiguration

  Szenario: Erfolgreiche Konfiguration laden
    Angenommen die Umgebung ist sauber
    Und die folgenden Umgebungsvariablen sind gesetzt:
      | Variable         | Wert              |
      | BDA_CLIENT_ID    | enercity          |
      | BDA_ENVIRONMENT  | dev               |
      | BDA_DB_HOST      | localhost         |
      | BDA_DB_PASSWORD  | secret            |
      | BDA_S3_BUCKET    | test-bucket       |
    Wenn ich die Konfiguration lade
    Dann sollte die Konfiguration erfolgreich geladen werden
    Und die Client-ID sollte "enercity" sein
    Und der Datenbankhost sollte "localhost" sein
```

**Step Definitions** (`test/bdd_test.go`):

```go
func (c *ConfigurationSteps) ichDieKonfigurationLade() error {
    c.cfg, c.err = config.Load()
    return nil
}

func (c *ConfigurationSteps) sollteDieKonfigurationErfolgreichGeladenWerden() error {
    if c.err != nil {
        return fmt.Errorf("expected no error, got: %v", c.err)
    }
    if c.cfg == nil {
        return fmt.Errorf("expected config to be loaded, got nil")
    }
    return nil
}
```

**Running BDD Tests**:

```bash
# Via Makefile
make test-bdd

# Direct with godog
godog run features/

# Specific feature
godog run features/configuration.feature

# With tags
godog run --tags=@unit features/
```

### Test Coverage

The project maintains high test coverage:

```bash
# Generate coverage report
go test ./... -coverprofile=coverage.out
go tool cover -func=coverage.out

# HTML report
go tool cover -html=coverage.out -o coverage.html

# Via Makefile (opens browser)
make test-coverage
```

**Coverage Targets**:

- `internal/config`: 90%+
- `internal/database`: 80%+
- `internal/export`: 85%+
- `internal/processors`: 75%+

### Integration Tests

Integration tests require a PostgreSQL database:

```bash
# Start test database with Docker
docker run -d \
  --name billing-test-db \
  -e POSTGRES_PASSWORD=test \
  -p 5432:5432 \
  postgres:15

# Run integration tests
export BDA_DB_HOST=localhost
export BDA_DB_PASSWORD=test
go test ./test/... -v

# Cleanup
docker stop billing-test-db
docker rm billing-test-db
```

### Test Fixtures

Test data is stored in `test/fixtures/`:

```text
test/fixtures/
├── sql/
│   ├── schema.sql              # Test database schema
│   └── seed.sql                # Test data
├── csv/
│   └── sample_export.csv       # Sample CSV data
└── config/
    └── test.env                # Test environment variables
```

### Continuous Integration

Tests run automatically in GitHub Actions:

- **Unit Tests**: On every push/PR
- **BDD Tests**: On every push/PR (with `continue-on-error: true`)
- **Coverage Report**: Uploaded as artifact
- **Test Summary**: Displayed in PR comments

### Test Best Practices

1. **Keep tests isolated**: Use `t.Parallel()` where possible
2. **Use table-driven tests**: For multiple scenarios
3. **Mock external dependencies**: Database, S3, etc.
4. **Test error paths**: Not just happy paths
5. **Use descriptive names**: `TestExportTable_WithLargeDataset_ShouldChunk`
6. **Clean up resources**: Use `defer` for cleanup
7. **Test concurrency**: Use `-race` detector
8. **Keep tests fast**: Mock slow operations

### Example: Complete Test

```go
func TestCSVExporter_Export(t *testing.T) {
    // Setup: Create temporary directory
    tmpDir := t.TempDir()

    // Setup: Mock database
    db, mock, err := sqlmock.New()
    require.NoError(t, err)
    defer db.Close()

    // Setup: Define expected query and result
    rows := sqlmock.NewRows([]string{"id", "name", "amount"}).
        AddRow(1, "Customer A", 100.50).
        AddRow(2, "Customer B", 200.75)

    mock.ExpectQuery("SELECT .* FROM customers").WillReturnRows(rows)

    // Execute: Create exporter and export
    exporter := export.NewCSVExporter(db, tmpDir, 1000000)
    files, err := exporter.ExportTable(context.Background(), "customers", "test")

    // Assert: No errors
    require.NoError(t, err)
    assert.Len(t, files, 1)

    // Assert: File exists and has correct content
    content, err := os.ReadFile(files[0])
    require.NoError(t, err)
    assert.Contains(t, string(content), "Customer A")
    assert.Contains(t, string(content), "100.50")

    // Assert: All expectations met
    assert.NoError(t, mock.ExpectationsWereMet())
}
```

### Testing Tips

**Running Specific Tests**:

```bash
# By name pattern
go test -run TestCSVExporter ./...

# By file
go test ./internal/export/csv_test.go

# Verbose output
go test -v ./...

# Show test names only
go test -v ./... | grep -E "^(PASS|FAIL|---)"
```

**Debugging Tests**:

```bash
# Print test output
go test -v ./... 2>&1 | tee test.log

# Run with debugger (dlv)
dlv test ./internal/config -- -test.run TestLoad

# Show coverage per function
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```

### Prerequisites

- **Go**: 1.24 or later
- **Docker**: For local testing
- **PostgreSQL**: For database tests (optional)
- **golangci-lint**: For linting
- **pre-commit**: For Git hooks (optional)

### Setup

```bash
# Install dependencies
go mod download

# Install development tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Install pre-commit hooks (optional)
pip install pre-commit
pre-commit install
```

### Linting

```bash
# Run all linters
golangci-lint run

# Run specific linter
golangci-lint run --disable-all --enable=errcheck

# Auto-fix issues
golangci-lint run --fix
```

### Building

```bash
# Development build
go build -o dist/billing-data-aggregator ./cmd/aggregator

# Production build with optimizations
go build -ldflags="-s -w" -o dist/billing-data-aggregator ./cmd/aggregator

# Cross-compile for Linux
GOOS=linux GOARCH=amd64 go build -o dist/billing-data-aggregator ./cmd/aggregator

# Build Docker image
docker build -t billing-data-aggregator:$(git describe --tags) .
```

## CI/CD Pipeline

### Workflow Structure

The GitHub Actions workflow (`.github/workflows/ci.yml`) implements:

1. **Code Quality** (PRs only):

   - Commit message validation
   - Pre-commit hooks (formatting, linting)

2. **Build & Test** (all branches):

   - Go version detection from `go.mod`
   - Unit tests
   - Binary compilation for Linux/amd64
   - Artifact upload

3. **Docker** (all branches, push on tags):

   - Docker image build
   - Trivy security scan
   - ECR push (conditional)

4. **Infrastructure** (iac/\* tags only):
   - Terraform validation
   - Terraform plan
   - Terraform apply (manual approval)

### Tag Strategy

| Tag Pattern | Trigger                    | Example       |
| ----------- | -------------------------- | ------------- |
| `dev_*`     | Development deployment     | `dev_1.0.0`   |
| `stage_*`   | Staging deployment         | `stage_1.0.0` |
| `prod_*`    | Production deployment      | `prod_1.0.0`  |
| `v*`        | Versioned release          | `v1.0.0`      |
| `iac/v*`    | Infrastructure-only update | `iac/v1.2.0`  |

### Creating a Release

```bash
# Tag a development release
git tag dev_1.0.0
git push origin dev_1.0.0

# Tag a production release
git tag prod_1.0.0
git push origin prod_1.0.0

# Tag infrastructure update
git tag iac/v1.0.0
git push origin iac/v1.0.0
```

## Deployment

### AWS Batch Runtime

The application runs as an AWS Batch job:

- **Schedule**: Daily at 2:00 AM UTC (configurable)
- **Compute**: Fargate (serverless containers)
- **Memory**: 2 GB (adjustable in Terraform)
- **vCPUs**: 1 (adjustable in Terraform)
- **Timeout**: 2 hours
- **Retries**: 2 attempts on failure

### Infrastructure

Infrastructure is managed via Terraform:

```bash
cd terraform/

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

Key resources:

- **AWS Batch Job Definition**: Container configuration
- **AWS Batch Job Queue**: Job execution queue
- **CloudWatch Events Rule**: Daily schedule
- **IAM Roles**: Execution permissions
- **S3 Bucket**: Export storage with lifecycle policies
- **ECR Repository**: Docker image storage

### FluxCD Deployment

Deployment via FluxCD + Terraform Controller:

1. Terraform code in `terraform/` directory
2. FluxCD HelmRelease triggers Terraform
3. Terraform Controller applies infrastructure
4. AWS Batch job definition updated with new image

See `datalynq` repository for FluxCD configuration.

## Monitoring & Observability

### Logging

Structured JSON logging with zerolog:

```json
{
  "level": "info",
  "service": "billing-data-aggregator",
  "client_id": "enercity",
  "environment": "prod",
  "batch_job_id": "abc-123",
  "message": "Processing tripica data",
  "timestamp": "2025-11-27T10:30:00Z"
}
```

Log levels:

- **DEBUG**: Detailed execution flow, SQL queries
- **INFO**: Normal operations, progress updates
- **WARN**: Non-critical issues, retries
- **ERROR**: Critical failures requiring attention

### Metrics

AWS CloudWatch metrics:

- Job execution duration
- Success/failure rate
- Rows processed
- CSV files generated
- S3 upload size

### Alerts

CloudWatch alarms for:

- Job failures (SNS notification)
- Execution timeout
- High error rate
- S3 upload failures

## Troubleshooting

### Common Issues

**Database connection timeout**:

```bash
# Check network connectivity
psql -h $BDA_DB_HOST -U $BDA_DB_USER -d $BDA_DB_NAME

# Verify credentials
export BDA_DB_PASSWORD=xxxxx
```

**S3 upload permission denied**:

```bash
# Check IAM role permissions
aws sts get-caller-identity
aws s3 ls s3://$BDA_S3_BUCKET/

# Verify bucket policy
aws s3api get-bucket-policy --bucket $BDA_S3_BUCKET
```

**Script execution failure**:

```bash
# Enable debug logging
export BDA_LOG_LEVEL=debug

# Check script syntax
psql -f scripts/init/tripica/110-charges.sql
```

### Debug Mode

Enable verbose logging:

```bash
export BDA_LOG_LEVEL=debug
./dist/billing-data-aggregator 2>&1 | tee debug.log
```

### Health Checks

```bash
# Test database connectivity
./dist/billing-data-aggregator --health-check

# Validate configuration
./dist/billing-data-aggregator --validate-config

# Dry-run (no S3 upload)
export BDA_DRY_RUN=true
./dist/billing-data-aggregator
```

## Migration from ed4-bi-batch-boil

This project replaces the legacy `ed4-bi-batch-boil` service.

### Key Improvements

- ✅ **Go instead of Node.js**: Better performance, type safety
- ✅ **Modular architecture**: Clear separation of concerns
- ✅ **Retry logic**: Automatic recovery from transient failures
- ✅ **Chunked CSV export**: Memory-efficient large data handling
- ✅ **Structured logging**: Better observability
- ✅ **Comprehensive tests**: Higher code quality
- ✅ **Modern CI/CD**: GitHub Actions workflows
- ✅ **IaC**: Full Terraform infrastructure

### Migration Strategy

See detailed migration plan in Obsidian documentation:
`/Users/anton.feldmann/lynq/billing-data-aggregator/migration-strategy.md`

## Documentation

### Obsidian Knowledge Base

Comprehensive documentation in Obsidian:

```text
/Users/anton.feldmann/lynq/billing-data-aggregator/
├── README.md                    # Overview & navigation
├── overview.md                  # System overview
├── architecture.md              # Architecture decisions
├── components.md                # Component details
├── configuration.md             # Configuration guide
├── development.md               # Development guide
├── deployment.md                # Deployment procedures
├── troubleshooting.md           # Common issues & solutions
├── migration-strategy.md        # Migration from old system
└── api-reference.md             # Code API documentation
```

### Additional Resources

- **GitHub Wiki**: https://github.com/enercity/billing-data-aggregator/wiki
- **Confluence**: Internal documentation & runbooks
- **Jira**: Issue tracking & project management

## License

Proprietary - Enercity AG

## Maintainers

- **Team**: Billing Data / DevOps
- **Contact**: devops@enercity.com
- **Slack**: `#team-billing-data`

## Contributing

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and add tests
3. Run linters: `golangci-lint run`
4. Run tests: `go test ./...`
5. Commit with conventional commits: `feat(export): add CSV compression`
6. Create Pull Request
7. Wait for CI checks and review
8. Merge to `main`

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.
