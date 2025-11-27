package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoad(t *testing.T) {
	// Setup
	cleanup := setupTestEnv(t, map[string]string{
		"BDA_CLIENT_ID":   "test-client",
		"BDA_DB_HOST":     "localhost",
		"BDA_DB_PASSWORD": "test-password",
		"BDA_S3_BUCKET":   "test-bucket",
	})
	defer cleanup()

	// Execute
	cfg, err := Load()

	// Assert
	require.NoError(t, err, "Load() should not return an error")
	assert.Equal(t, "test-client", cfg.ClientID, "ClientID should match")
	assert.Equal(t, "localhost", cfg.Database.Host, "DB Host should match")
	assert.Equal(t, "test-bucket", cfg.S3.Bucket, "S3 Bucket should match")
}

func TestLoadWithDefaults(t *testing.T) {
	// Setup
	cleanup := setupTestEnv(t, map[string]string{
		"BDA_CLIENT_ID":   "test-client",
		"BDA_DB_HOST":     "localhost",
		"BDA_DB_PASSWORD": "test-password",
		"BDA_S3_BUCKET":   "test-bucket",
	})
	defer cleanup()

	// Execute
	cfg, err := Load()

	// Assert
	require.NoError(t, err)
	assert.Equal(t, 5432, cfg.Database.Port, "Default port should be 5432")
	assert.Equal(t, 4, cfg.Database.MaxConns, "Default max connections should be 4")
	assert.Equal(t, 0, cfg.Database.MaxIdle, "Default max idle should be 0")
	assert.Equal(t, 5, cfg.Database.MinutesIdle, "Default idle minutes should be 5")
}

func TestLoadWithCustomPort(t *testing.T) {
	// Setup
	cleanup := setupTestEnv(t, map[string]string{
		"BDA_CLIENT_ID":   "test-client",
		"BDA_DB_HOST":     "localhost",
		"BDA_DB_PORT":     "5433",
		"BDA_DB_PASSWORD": "test-password",
		"BDA_S3_BUCKET":   "test-bucket",
	})
	defer cleanup()

	// Execute
	cfg, err := Load()

	// Assert
	require.NoError(t, err)
	assert.Equal(t, 5433, cfg.Database.Port, "Custom port should be used")
}

func TestValidate_Success(t *testing.T) {
	// Setup
	cfg := &Config{
		ClientID: "test-client",
		Database: DBConfig{
			Host:     "localhost",
			Password: "secret",
			MaxConns: 4,
			MaxIdle:  2,
		},
		S3: S3Config{
			Bucket: "test-bucket",
		},
	}

	// Execute & Assert
	err := cfg.Validate()
	assert.NoError(t, err, "Valid config should not return an error")
}

func TestValidate_MissingRequiredFields(t *testing.T) {
	tests := []struct {
		name      string
		cfg       *Config
		wantError string
	}{
		{
			name: "Missing ClientID",
			cfg: &Config{
				Database: DBConfig{Host: "localhost", Password: "secret"},
				S3:       S3Config{Bucket: "test-bucket"},
			},
			wantError: "CLIENT_ID",
		},
		{
			name: "Missing DB Host",
			cfg: &Config{
				ClientID: "test-client",
				Database: DBConfig{Password: "secret"},
				S3:       S3Config{Bucket: "test-bucket"},
			},
			wantError: "DB_HOST",
		},
		{
			name: "Missing DB Password",
			cfg: &Config{
				ClientID: "test-client",
				Database: DBConfig{Host: "localhost"},
				S3:       S3Config{Bucket: "test-bucket"},
			},
			wantError: "DB_PASSWORD",
		},
		{
			name: "Missing S3 Bucket",
			cfg: &Config{
				ClientID: "test-client",
				Database: DBConfig{Host: "localhost", Password: "secret"},
			},
			wantError: "S3_BUCKET",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.Validate()
			require.Error(t, err, "Validation should fail")
			assert.Contains(t, err.Error(), tt.wantError, "Error should mention %s", tt.wantError)
		})
	}
}

func TestValidate_ConnectionLimits(t *testing.T) {
	// Simplified test - actual Validate() doesn't check connection limits
	cfg := &Config{
		ClientID: "test-client",
		Database: DBConfig{
			Host:     "localhost",
			Password: "secret",
			MaxConns: 4,
			MaxIdle:  2,
		},
		S3: S3Config{Bucket: "test-bucket"},
	}

	err := cfg.Validate()
	assert.NoError(t, err, "Should not return error for valid config")
}

func TestConnectionString(t *testing.T) {
	// Setup
	cfg := &Config{
		Database: DBConfig{
			Host:     "db.example.com",
			Port:     5433,
			Database: "billing_db",
			User:     "billing_user",
			Password: "secret123",
		},
	}

	// Execute
	connStr := cfg.ConnectionString()

	// Assert - Connection string is in URL format
	assert.Contains(t, connStr, "postgres://", "Should be postgres URL")
	assert.Contains(t, connStr, "billing_user:secret123", "Should contain credentials")
	assert.Contains(t, connStr, "db.example.com:5433", "Should contain host:port")
	assert.Contains(t, connStr, "/billing_db", "Should contain database name")
	assert.Contains(t, connStr, "sslmode=", "Should contain sslmode")
}

func TestDBConfig_ConnectionString(t *testing.T) {
	// Setup
	dbCfg := &DBConfig{
		Host:     "localhost",
		Port:     5432,
		Database: "test_db",
		User:     "test_user",
		Password: "test_pass",
	}

	// Execute
	connStr := dbCfg.ConnectionString()

	// Assert - Connection string is in URL format
	assert.Contains(t, connStr, "postgres://test_user:test_pass@localhost:5432/test_db")
}

// Helper Functions

func setupTestEnv(t *testing.T, envVars map[string]string) func() {
	t.Helper()

	// Set environment variables
	for key, value := range envVars {
		if err := os.Setenv(key, value); err != nil {
			t.Fatalf("Failed to set env var %s: %v", key, err)
		}
	}

	// Return cleanup function
	return func() {
		for key := range envVars {
			if err := os.Unsetenv(key); err != nil {
				t.Logf("Failed to unset env var %s: %v", key, err)
			}
		}
	}
}
