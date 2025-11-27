package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/enercity/billing-data-aggregator/internal/config"
	"github.com/enercity/billing-data-aggregator/internal/database"
	"github.com/enercity/billing-data-aggregator/internal/export"
	"github.com/enercity/billing-data-aggregator/internal/processors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

var (
	version = "dev"
	commit  = "unknown"
	date    = "unknown"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Info().Msg("Received shutdown signal")
		cancel()
	}()

	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	setupLogging(cfg)

	log.Info().
		Str("version", version).
		Str("commit", commit).
		Str("date", date).
		Str("client_id", cfg.ClientID).
		Str("environment", cfg.Environment).
		Msg("Starting billing-data-aggregator")

	if err := run(ctx, cfg); err != nil {
		log.Error().Err(err).Msg("Application failed")
		os.Exit(1)
	}

	log.Info().Msg("Application completed successfully")
}

func setupLogging(cfg *config.Config) {
	level := zerolog.InfoLevel
	switch cfg.LogLevel {
	case "debug":
		level = zerolog.DebugLevel
	case "info":
		level = zerolog.InfoLevel
	case "warn":
		level = zerolog.WarnLevel
	case "error":
		level = zerolog.ErrorLevel
	}
	zerolog.SetGlobalLevel(level)

	if cfg.Environment == "local" {
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})
	}

	log.Logger = log.With().
		Str("service", "billing-data-aggregator").
		Str("client_id", cfg.ClientID).
		Str("environment", cfg.Environment).
		Logger()

	if jobID := os.Getenv("AWS_BATCH_JOB_ID"); jobID != "" {
		log.Logger = log.With().Str("batch_job_id", jobID).Logger()
	}
}
func run(ctx context.Context, cfg *config.Config) error {
	// Initialize database connection
	log.Info().Msg("Initializing database connection")
	db, err := database.NewConnection(
		cfg.ConnectionString(),
		cfg.DBMaxConnections,
		cfg.DBMaxIdleConns,
		cfg.DBConnMaxIdleTime,
	)
	if err != nil {
		return fmt.Errorf("failed to initialize database: %w", err)
	}
	defer db.Close()

	// Create script executor
	executor := database.NewScriptExecutor(db, cfg.IgnoreSystems)
	// Execute initialization scripts
	log.Info().Msg("Executing initialization scripts")
	if err := executor.ExecuteScriptsInDir(ctx, "scripts/init"); err != nil {
		return fmt.Errorf("failed to execute init scripts: %w", err)
	}

	// Run processors based on configured systems
	log.Info().Strs("systems", cfg.Systems).Msg("Running processors")
	for _, system := range cfg.Systems {
		var processor processors.Processor
		
		switch system {
		case "tripica":
			processor = processors.NewTripicaProcessor(db, executor, "scripts")
		case "bookkeeper":
			processor = processors.NewBookkeeperProcessor(db, executor, "scripts")
		default:
			log.Warn().Str("system", system).Msg("Unknown system, skipping")
			continue
		}
		
		log.Info().Str("system", processor.Name()).Msg("Processing system")
		if err := processor.Process(ctx); err != nil {
			return fmt.Errorf("processor %s failed: %w", processor.Name(), err)
		}
	}

	// Export results to CSV
	log.Info().Msg("Exporting results to CSV")
	exporter := export.NewCSVExporter(db.DB(), "/tmp/exports", cfg.MaxRowSizeFile)
	
	var allFiles []string
	for _, system := range cfg.Systems {
		tableName := fmt.Sprintf("%s_results", system)
		files, err := exporter.ExportTable(ctx, tableName, system)
		if err != nil {
			log.Warn().Err(err).Str("table", tableName).Msg("Failed to export table, continuing")
		} else {
			allFiles = append(allFiles, files...)
		}
	}

	// Upload to S3
	log.Info().Int("files", len(allFiles)).Msg("Uploading files to S3")
	uploader, err := export.NewS3Uploader(ctx, cfg.S3.Region, cfg.S3.Bucket, fmt.Sprintf("%s/%s", cfg.ClientID, cfg.Environment))
	if err != nil {
		return fmt.Errorf("failed to create S3 uploader: %w", err)
	}
	
	if len(allFiles) > 0 {
		if err := uploader.UploadFiles(ctx, allFiles); err != nil {
			return fmt.Errorf("failed to upload files: %w", err)
		}
	}

	// Execute archive scripts
	log.Info().Msg("Executing archive scripts")
	if err := executor.ExecuteScriptsInDir(ctx, "scripts/archive"); err != nil {
		return fmt.Errorf("failed to execute archive scripts: %w", err)
	}

	log.Info().Msg("Job completed successfully")
	return nil
}
