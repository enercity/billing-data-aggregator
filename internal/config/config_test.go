package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) {
	os.Setenv("BDA_CLIENT_ID", "test-client")
	os.Setenv("BDA_DB_HOST", "localhost")
	os.Setenv("BDA_DB_PASSWORD", "test-password")
	os.Setenv("BDA_S3_BUCKET", "test-bucket")
	defer cleanupEnv()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	if cfg.ClientID != "test-client" {
		t.Errorf("ClientID = %v, want test-client", cfg.ClientID)
	}
}

func cleanupEnv() {
	os.Unsetenv("BDA_CLIENT_ID")
	os.Unsetenv("BDA_DB_HOST")
	os.Unsetenv("BDA_DB_PASSWORD")
	os.Unsetenv("BDA_S3_BUCKET")
}
