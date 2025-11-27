package processors

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/enercity/billing-data-aggregator/internal/database"
	"github.com/rs/zerolog/log"
)

type BookkeeperProcessor struct {
	db         *database.Connection
	executor   *database.ScriptExecutor
	scriptsDir string
}

func NewBookkeeperProcessor(db *database.Connection, executor *database.ScriptExecutor, scriptsDir string) *BookkeeperProcessor {
	return &BookkeeperProcessor{
		db:         db,
		executor:   executor,
		scriptsDir: scriptsDir,
	}
}

func (p *BookkeeperProcessor) Process(ctx context.Context) error {
	log.Info().Msg("Starting Bookkeeper processor")

	initDir := filepath.Join(p.scriptsDir, "init")
	if err := p.executor.ExecuteScriptsInDir(ctx, initDir); err != nil {
		return fmt.Errorf("failed to execute Bookkeeper init scripts: %w", err)
	}

	log.Info().Msg("Bookkeeper processing completed")
	return nil
}

func (p *BookkeeperProcessor) Name() string {
	return "bookkeeper"
}
