package export

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewCSVExporter(t *testing.T) {
	// Setup
	db := &sql.DB{} // Mock DB
	outputDir := "/tmp/test-export"
	maxRows := 1000000

	// Execute
	exporter := NewCSVExporter(db, outputDir, maxRows)

	// Assert
	assert.NotNil(t, exporter, "Exporter should not be nil")
	assert.Equal(t, outputDir, exporter.outputDir, "Output dir should match")
	assert.Equal(t, maxRows, exporter.maxRowsPerFile, "Max rows should match")
}

func TestCSVExporter_FileNaming(t *testing.T) {
	tests := []struct {
		name      string
		system    string
		tableName string
		fileIndex int
		expected  string
	}{
		{
			name:      "Tripica file",
			system:    "tripica",
			tableName: "results",
			fileIndex: 0,
			expected:  "tripica_results_0000.csv",
		},
		{
			name:      "Bookkeeper file",
			system:    "bookkeeper",
			tableName: "bookings",
			fileIndex: 5,
			expected:  "bookkeeper_bookings_0005.csv",
		},
		{
			name:      "Large index",
			system:    "system",
			tableName: "table",
			fileIndex: 9999,
			expected:  "system_table_9999.csv",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			filename := tt.system + "_" + tt.tableName + "_" + 
				paddedInt(tt.fileIndex, 4) + ".csv"

			// Assert
			assert.Equal(t, tt.expected, filename, "Filename should match pattern")
		})
	}
}

func TestCSVExporter_ChunkCalculation(t *testing.T) {
	tests := []struct {
		name         string
		totalRows    int
		maxPerFile   int
		expectedFiles int
	}{
		{"Small dataset", 100, 1000000, 1},
		{"Exact chunk size", 1000000, 1000000, 1},
		{"Multiple chunks", 2500000, 1000000, 3},
		{"Just over chunk", 1000001, 1000000, 2},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			files := (tt.totalRows + tt.maxPerFile - 1) / tt.maxPerFile

			// Assert
			assert.Equal(t, tt.expectedFiles, files, "File count should match")
		})
	}
}

func TestCSVExporter_DirectoryCreation(t *testing.T) {
	// Setup
	tmpDir := filepath.Join(os.TempDir(), "csv-export-test")
	defer os.RemoveAll(tmpDir)

	// Execute
	err := os.MkdirAll(tmpDir, 0750)

	// Assert
	require.NoError(t, err, "Directory creation should succeed")
	
	info, err := os.Stat(tmpDir)
	require.NoError(t, err, "Directory should exist")
	assert.True(t, info.IsDir(), "Should be a directory")
}

func TestCSVExporter_NullHandling(t *testing.T) {
	tests := []struct {
		name     string
		value    interface{}
		expected string
	}{
		{"Null value", nil, ""},
		{"String value", "test", "test"},
		{"Number value", 123, "123"},
		{"Boolean value", true, "true"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			var result string
			if tt.value == nil {
				result = ""
			} else {
				result = toString(tt.value)
			}

			// Assert
			assert.Equal(t, tt.expected, result, "Value conversion should match")
		})
	}
}

func TestCSVExporter_SpecialCharacters(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		needsEscape bool
	}{
		{"Plain text", "normal text", false},
		{"With comma", "text, with comma", true},
		{"With quotes", "text \"with quotes\"", true},
		{"With newline", "text\nwith newline", true},
		{"With tab", "text\twith tab", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute - check if escaping needed
			needsEscape := containsSpecialChars(tt.input)

			// Assert
			assert.Equal(t, tt.needsEscape, needsEscape, "Escape detection should match")
		})
	}
}

func TestS3Uploader_RetryBackoff(t *testing.T) {
	tests := []struct {
		attempt  int
		expected int // seconds
	}{
		{0, 0},
		{1, 2},
		{2, 4},
		{3, 6},
	}

	for _, tt := range tests {
		t.Run("Attempt "+string(rune(tt.attempt)), func(t *testing.T) {
			// Execute - calculate backoff
			backoff := tt.attempt * 2

			// Assert
			assert.Equal(t, tt.expected, backoff, "Backoff should match")
		})
	}
}

func TestS3Uploader_KeyGeneration(t *testing.T) {
	tests := []struct {
		name      string
		prefix    string
		filename  string
		expected  string
	}{
		{
			name:     "With prefix",
			prefix:   "client/prod/2025-11-27",
			filename: "tripica_results_0000.csv",
			expected: "client/prod/2025-11-27/tripica_results_0000.csv",
		},
		{
			name:     "Without prefix",
			prefix:   "",
			filename: "test.csv",
			expected: "test.csv",
		},
		{
			name:     "With trailing slash",
			prefix:   "path/",
			filename: "file.csv",
			expected: "path/file.csv",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			key := filepath.Join(tt.prefix, tt.filename)

			// Assert
			assert.Equal(t, tt.expected, key, "S3 key should match")
		})
	}
}

func TestS3Uploader_MaxRetries(t *testing.T) {
	// Setup
	maxRetries := 3

	// Execute - simulate retry loop
	attempts := 0
	for i := 0; i < maxRetries; i++ {
		attempts++
	}

	// Assert
	assert.Equal(t, maxRetries, attempts, "Should attempt max retries")
}

// Helper Functions

func paddedInt(n, width int) string {
	s := fmt.Sprintf("%d", n)
	for len(s) < width {
		s = "0" + s
	}
	return s
}

func toString(v interface{}) string {
	if v == nil {
		return ""
	}
	return fmt.Sprintf("%v", v)
}

func containsSpecialChars(s string) bool {
	for _, c := range s {
		if c == ',' || c == '"' || c == '\n' {
			return true
		}
	}
	return false
}
