# billing-data-aggregator

Daily batch job that aggregates billing data (charges, balances, bookings) from the Octopus data warehouse and exports results to S3.

## Purpose

This service processes financial data from multiple sources:

- **Tripica**: Billing charges, account balances, dunning, write-offs
- **Bookkeeper**: SAP bookings, journal entries, taxes

The aggregated data is exported as CSV files to S3 for downstream BI/analytics processes.

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     Octopus Data Warehouse                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ datalake_    │  │ bookkeeper_  │  │ dunning_     │     │
│  │ vault        │  │ vault        │  │ vault        │     │
│  │ (Tripica)    │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │            │
│         └──────────────────┴──────────────────┘            │
│                            ↓                                │
│                   ┌─────────────────┐                      │
│                   │  Aggregator     │                      │
│                   │  (Go Binary)    │                      │
│                   └─────────────────┘                      │
│                            ↓                                │
│              ┌──────────────────────────┐                  │
│              │   report_oibl Schema     │                  │
│              │ - base_data_* (temp)     │                  │
│              │ - data_charges           │                  │
│              │ - data_balances          │                  │
│              │ - oibl_customer (final)  │                  │
│              └──────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    ┌───────────────┐
                    │   S3 Bucket   │
                    │   CSV Export  │
                    └───────────────┘
```

## Quick Start

### Prerequisites

- Go 1.24+
- PostgreSQL (for local testing)
- AWS credentials (for S3 access)

### Local Development

```bash
# Install dependencies
go mod download
go mod vendor

# Run tests
go test ./...

# Build
go build -o dist/billing-data-aggregator ./cmd/aggregator

# Run locally (requires DB connection)
export BDA_CLIENT_ID=local
export BDA_ENVIRONMENT=dev
export BDA_DB_HOST=localhost
export BDA_DB_PASSWORD=your-password
./dist/billing-data-aggregator
```

### Docker

```bash
# Build
docker build -t billing-data-aggregator:local .

# Run
docker run --rm \
  -e BDA_CLIENT_ID=local \
  -e BDA_DB_HOST=host.docker.internal \
  billing-data-aggregator:local
```

## Configuration

Environment variables (prefix: `BDA_`):

| Variable                | Default              | Description                          |
| ----------------------- | -------------------- | ------------------------------------ |
| `BDA_CLIENT_ID`         | -                    | Client identifier (e.g., enercity)   |
| `BDA_ENVIRONMENT`       | -                    | Environment (dev, stage, prod)       |
| `BDA_LOG_LEVEL`         | `info`               | Log level (debug, info, warn, error) |
| `BDA_DB_HOST`           | -                    | PostgreSQL host                      |
| `BDA_DB_PORT`           | `5432`               | PostgreSQL port                      |
| `BDA_DB_NAME`           | `octopus`            | Database name                        |
| `BDA_DB_USER`           | `billing_aggregator` | Database user                        |
| `BDA_DB_PASSWORD`       | -                    | Database password                    |
| `BDA_DB_MAX_CONNS`      | `4`                  | Max DB connections                   |
| `BDA_S3_BUCKET`         | -                    | S3 bucket for exports                |
| `BDA_S3_REGION`         | `eu-central-1`       | AWS region                           |
| `BDA_SYSTEMS`           | `tripica,bookkeeper` | Systems to process                   |
| `BDA_MAX_ROW_SIZE_FILE` | `1000000`            | Max rows per CSV file                |

## Project Structure

```text
billing-data-aggregator/
├── cmd/
│   └── aggregator/          # Main application entry point
├── internal/                # Private packages
│   ├── config/              # Configuration management
│   ├── database/            # Database connection & script execution
│   ├── processors/          # Business logic (Tripica, Bookkeeper)
│   ├── export/              # CSV generation, S3 upload
│   ├── history/             # Historical data management
│   └── validators/          # Pre-execution checks
├── scripts/                 # SQL scripts
│   ├── init/                # Data transformation scripts
│   ├── archive/             # Export queries
│   ├── history/             # Historization scripts
│   └── prechecks/           # Validation scripts
├── terraform/               # Infrastructure as Code
├── test/                    # Integration tests
└── .github/workflows/       # CI/CD pipelines
```

## CI/CD

This project uses GitHub Actions for CI/CD:

- **CI**: Lint, test, build on every PR
- **Release**: On tags (e.g., `v1.0.0`), creates GitHub release and pushes Docker image to ECR
- **Deployment**: Via FluxCD + Terraform Controller

See `.github/workflows/ci.yml` for details.

## Deployment

The service runs as an AWS Batch job, scheduled daily via CloudWatch Events.

Infrastructure is managed via Terraform and deployed through FluxCD.

See `terraform/` directory and FluxCD configuration in the `fluxcd-environment` repository.

## Documentation

Detailed documentation available in the Obsidian repository:

- `/Users/anton.feldmann/lynq/ed4-bi-batch-boil/`

Key documents:

- `overview.md` - System overview
- `architecture.md` - Design decisions
- `components.md` - Component details
- `migration-strategy.md` - Migration from old system

## Development

### Code Style

- Follow Go best practices
- Run `golangci-lint run` before committing
- Add tests for new functionality
- Keep packages focused and single-purpose

### Testing

```bash
# Unit tests
go test ./...

# With coverage
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out

# Integration tests (requires Docker)
cd test
docker-compose up -d
go test -tags=integration ./...
docker-compose down
```

## License

Proprietary - Enercity AG

## Maintainers

- **Squad**: Billing / Data Engineering
- **Contact**: DevOps Team
