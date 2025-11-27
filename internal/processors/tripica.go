package processors

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/enercity/billing-data-aggregator/internal/database"
	"github.com/rs/zerolog/log"
)

type TripicaProcessor struct {
	db         *database.Connection
	executor   *database.ScriptExecutor
	scriptsDir string
}

func NewTripicaProcessor(db *database.Connection, executor *database.ScriptExecutor, scriptsDir string) *TripicaProcessor {
	return &TripicaProcessor{
		db:         db,
		executor:   executor,
		scriptsDir: scriptsDir,
	}
}

func (p *TripicaProcessor) Process(ctx context.Context) error {
	log.Info().Msg("Starting Tripica processor")

	initDir := filepath.Join(p.scriptsDir, "init")
	if err := p.executor.ExecuteScriptsInDir(ctx, initDir); err != nil {
		return fmt.Errorf("failed to execute Tripica init scripts: %w", err)
	}

	log.Info().Msg("Tripica processing completed")
	return nil
}

func (p *TripicaProcessor) Name() string {
	return "tripica"
}
