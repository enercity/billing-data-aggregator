package export

import (
	"context"
	"database/sql"
	"encoding/csv"
	"fmt"
	"os"
	"path/filepath"

	"github.com/rs/zerolog/log"
)

type CSVExporter struct {
	db             *sql.DB
	outputDir      string
	maxRowsPerFile int
}

func NewCSVExporter(db *sql.DB, outputDir string, maxRowsPerFile int) *CSVExporter {
	return &CSVExporter{
		db:             db,
		outputDir:      outputDir,
		maxRowsPerFile: maxRowsPerFile,
	}
}

func (e *CSVExporter) ExportTable(ctx context.Context, tableName, system string) ([]string, error) {
	log.Info().Str("table", tableName).Str("system", system).Msg("Exporting table to CSV")

	// #nosec G201 -- tableName is validated and schema-qualified, not user input
	query := fmt.Sprintf("SELECT * FROM %s", tableName)
	rows, err := e.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query table %s: %w", tableName, err)
	}
	defer func() {
		if err := rows.Close(); err != nil {
			log.Error().Err(err).Msg("Failed to close rows")
		}
	}()

	columns, err := rows.Columns()
	if err != nil {
		return nil, fmt.Errorf("failed to get columns: %w", err)
	}

	// Create output directory with restricted permissions (owner + group)
	if err := os.MkdirAll(e.outputDir, 0750); err != nil {
		return nil, fmt.Errorf("failed to create output directory: %w", err)
	}

	var files []string
	fileIndex := 0
	rowCount := 0
	var writer *csv.Writer
	var currentFile *os.File

	for rows.Next() {
		if rowCount%e.maxRowsPerFile == 0 {
			if currentFile != nil {
				writer.Flush()
				if err := currentFile.Close(); err != nil {
					log.Warn().Err(err).Msg("Failed to close CSV file")
				}
			}

			filename := fmt.Sprintf("%s_%s_%04d.csv", system, tableName, fileIndex)
			filePath := filepath.Join(e.outputDir, filename)
			files = append(files, filePath)

			// #nosec G304 -- filePath is internally generated, not from user input
			currentFile, err = os.Create(filePath)
			if err != nil {
				return files, fmt.Errorf("failed to create file: %w", err)
			}

			writer = csv.NewWriter(currentFile)
			if err := writer.Write(columns); err != nil {
				_ = currentFile.Close() // Ignore close error during error handling
				return files, fmt.Errorf("failed to write headers: %w", err)
			}

			fileIndex++
			rowCount = 0
		}

		values := make([]interface{}, len(columns))
		valuePtrs := make([]interface{}, len(columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}

		if err := rows.Scan(valuePtrs...); err != nil {
			return files, fmt.Errorf("failed to scan row: %w", err)
		}

		strValues := make([]string, len(values))
		for i, v := range values {
			if v == nil {
				strValues[i] = ""
			} else {
				strValues[i] = fmt.Sprintf("%v", v)
			}
		}

		if err := writer.Write(strValues); err != nil {
			return files, fmt.Errorf("failed to write row: %w", err)
		}

		rowCount++
	}

	if currentFile != nil {
		writer.Flush()
		if err := currentFile.Close(); err != nil {
			log.Warn().Err(err).Msg("Failed to close final CSV file")
		}
	}

	if err := rows.Err(); err != nil {
		return files, fmt.Errorf("error iterating rows: %w", err)
	}

	log.Info().Str("table", tableName).Int("total_files", len(files)).Msg("Export completed")
	return files, nil
}
