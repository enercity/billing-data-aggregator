package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/enercity/billing-data-aggregator/internal/config"
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
	log.Info().Msg("Application logic not yet implemented")
	
	log.Info().
		Strs("systems", cfg.Systems).
		Str("db_host", cfg.Database.Host).
		Str("s3_bucket", cfg.S3.Bucket).
		Msg("Configuration loaded")
	
	return nil
}
