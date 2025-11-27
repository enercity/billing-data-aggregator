package database

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/rs/zerolog/log"
)

type ScriptExecutor struct {
	conn           *Connection
	ignoredSystems []string
	alwaysSeparate bool
}

func NewScriptExecutor(conn *Connection, ignoredSystems []string) *ScriptExecutor {
	return &ScriptExecutor{
		conn:           conn,
		ignoredSystems: ignoredSystems,
		alwaysSeparate: true,
	}
}

func (e *ScriptExecutor) ExecuteScriptsInDir(ctx context.Context, dir string) error {
	log.Info().Str("directory", dir).Msg("Executing scripts in directory")

	scriptsBySystem, err := e.orderScripts(dir)
	if err != nil {
		return fmt.Errorf("failed to order scripts: %w", err)
	}

	for system, scripts := range scriptsBySystem {
		if e.isSystemIgnored(system) {
			log.Info().Str("system", system).Msg("Skipping ignored system")
			continue
		}

		log.Info().Str("system", system).Int("scripts", len(scripts)).Msg("Processing system")

		for _, script := range scripts {
			if err := e.executeScript(ctx, script); err != nil {
				return fmt.Errorf("failed to execute script %s: %w", script, err)
			}
		}
	}

	return nil
}

func (e *ScriptExecutor) orderScripts(dir string) (map[string][]string, error) {
	scriptsBySystem := make(map[string][]string)

	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			log.Warn().Str("directory", dir).Msg("Directory does not exist, skipping")
			return scriptsBySystem, nil
		}
		return nil, err
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		system := entry.Name()
		systemDir := filepath.Join(dir, system)

		scripts, err := e.collectScripts(systemDir)
		if err != nil {
			return nil, fmt.Errorf("failed to collect scripts from %s: %w", systemDir, err)
		}

		if len(scripts) > 0 {
			scriptsBySystem[system] = scripts
		}
	}

	return scriptsBySystem, nil
}

func (e *ScriptExecutor) collectScripts(dir string) ([]string, error) {
	var scripts []string

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		if strings.HasPrefix(info.Name(), "NOEXEC_") {
			log.Debug().Str("file", path).Msg("Skipping NOEXEC file")
			return nil
		}

		if strings.HasSuffix(info.Name(), ".sql") {
			scripts = append(scripts, path)
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	sort.Strings(scripts)
	return scripts, nil
}

func (e *ScriptExecutor) executeScript(ctx context.Context, scriptPath string) error {
	log.Info().Str("script", scriptPath).Msg("Executing script")

	content, err := os.ReadFile(scriptPath)
	if err != nil {
		return fmt.Errorf("failed to read script: %w", err)
	}

	script := string(content)

	if e.alwaysSeparate {
		return e.executeSeparateStatements(ctx, script, scriptPath)
	}

	return e.executeAsWhole(ctx, script, scriptPath)
}

func (e *ScriptExecutor) executeSeparateStatements(ctx context.Context, script, scriptPath string) error {
	statements := e.splitStatements(script)

	log.Debug().
		Str("script", scriptPath).
		Int("statements", len(statements)).
		Msg("Executing statements separately")

	for i, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" {
			continue
		}

		if err := e.executeStatement(ctx, stmt); err != nil {
			return fmt.Errorf("statement %d failed: %w", i+1, err)
		}
	}

	return nil
}

func (e *ScriptExecutor) executeAsWhole(ctx context.Context, script, scriptPath string) error {
	return e.executeStatement(ctx, script)
}

func (e *ScriptExecutor) executeStatement(ctx context.Context, stmt string) error {
	_, err := e.conn.ExecContext(ctx, stmt)
	return err
}

func (e *ScriptExecutor) splitStatements(script string) []string {
	statements := strings.Split(script, ";")
	
	var result []string
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt != "" {
			result = append(result, stmt)
		}
	}
	
	return result
}

func (e *ScriptExecutor) isSystemIgnored(system string) bool {
	for _, ignored := range e.ignoredSystems {
		if system == ignored {
			return true
		}
	}
	return false
}
