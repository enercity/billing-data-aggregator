// Package config provides configuration loading and validation for the billing data aggregator.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// EnvPrefix is the prefix for all environment variables used by this application.
const EnvPrefix = "BDA_"

// Config holds the complete application configuration.
type Config struct {
	ClientID    string
	Environment string
	LogLevel    string
	Database    DBConfig
	S3          S3Config
	Systems     []string
	IgnoreSystems []string
	MaxRowSizeFile int
	ScriptsDir  string
	InitScriptsDir string
	ArchiveScriptsDir string
	HistoryScriptsDir string
	PrechecksScriptsDir string
	DBMaxConnections int
	DBMaxIdleConns int
	DBConnMaxIdleTime int
}

// DBConfig holds database connection configuration.
type DBConfig struct {
	Host        string
	Port        int
	Database    string
	User        string
	Password    string
	MaxConns    int
	MaxIdle     int
	MinutesIdle int
}

// S3Config holds S3 storage configuration.
type S3Config struct {
	Region          string
	Bucket          string
	URL             string
	AccessKeyID     string
	SecretAccessKey string
}

// Load reads configuration from environment variables and returns a Config instance.
func Load() (*Config, error) {
	cfg := &Config{
		ClientID:    getEnv("CLIENT_ID", ""),
		Environment: getEnv("ENVIRONMENT", detectEnvironment()),
		LogLevel:    getEnv("LOG_LEVEL", defaultLogLevel()),
		Database: DBConfig{
			Host:        getEnv("DB_HOST", ""),
			Port:        getEnvInt("DB_PORT", 5432),
			Database:    getEnv("DB_NAME", "octopus"),
			User:        getEnv("DB_USER", "billing_aggregator"),
			Password:    getEnv("DB_PASSWORD", ""),
			MaxConns:    getEnvInt("DB_MAX_CONNS", 4),
			MaxIdle:     getEnvInt("DB_MAX_IDLE", 0),
			MinutesIdle: getEnvInt("DB_MINUTES_IDLE", 5),
		},
		S3: S3Config{
			Region:          getEnv("S3_REGION", "eu-central-1"),
			Bucket:          getEnv("S3_BUCKET", ""),
			URL:             getEnv("S3_URL", ""),
			AccessKeyID:     getEnv("S3_ACCESS_KEY", ""),
			SecretAccessKey: getEnv("S3_SECRET_ACCESS_KEY", ""),
		},
		Systems:        parseSystems(getEnv("SYSTEMS", "tripica,bookkeeper")),
		IgnoreSystems:  parseSystems(getEnv("IGNORE_SYSTEMS", "")),
		MaxRowSizeFile: getEnvInt("MAX_ROW_SIZE_FILE", 1000000),
		ScriptsDir:     getEnv("SCRIPTS_DIR", "/app/scripts"),
		DBMaxConnections: getEnvInt("DB_MAX_CONNS", 4),
		DBMaxIdleConns: getEnvInt("DB_MAX_IDLE", 0),
		DBConnMaxIdleTime: getEnvInt("DB_MINUTES_IDLE", 5),
	}

	if cfg.InitScriptsDir == "" {
		cfg.InitScriptsDir = cfg.ScriptsDir + "/init"
	}
	if cfg.ArchiveScriptsDir == "" {
		cfg.ArchiveScriptsDir = cfg.ScriptsDir + "/archive"
	}
	if cfg.HistoryScriptsDir == "" {
		cfg.HistoryScriptsDir = cfg.ScriptsDir + "/history"
	}
	if cfg.PrechecksScriptsDir == "" {
		cfg.PrechecksScriptsDir = cfg.ScriptsDir + "/prechecks"
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Validate checks if the configuration is valid and returns an error if not.
func (c *Config) Validate() error {
	if c.ClientID == "" {
		return fmt.Errorf("CLIENT_ID is required")
	}
	if c.Database.Host == "" {
		return fmt.Errorf("DB_HOST is required")
	}
	if c.Database.Password == "" {
		return fmt.Errorf("DB_PASSWORD is required")
	}
	if c.S3.Bucket == "" {
		return fmt.Errorf("S3_BUCKET is required")
	}
	return nil
}

// ConnectionString returns a PostgreSQL connection string from the config.
func (c *Config) ConnectionString() string {
	return c.Database.ConnectionString()
}

// ConnectionString returns a PostgreSQL connection string from the database config.
func (c *DBConfig) ConnectionString() string {
	sslMode := "require"
	if detectEnvironment() == "local" {
		sslMode = "disable"
	}
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		c.User, c.Password, c.Host, c.Port, c.Database, sslMode,
	)
}

func getEnv(key, defaultValue string) string {
	key = EnvPrefix + key
	if v, exists := os.LookupEnv(key); exists {
		return v
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	key = EnvPrefix + key
	if v, exists := os.LookupEnv(key); exists {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultValue
}

func detectEnvironment() string {
	if v := os.Getenv("ED4ENV"); v != "" {
		return v
	}
	if os.Getenv("AWS_BATCH_JOB_ID") != "" {
		return "prod"
	}
	return "local"
}

func defaultLogLevel() string {
	if detectEnvironment() == "local" {
		return "debug"
	}
	return "info"
}

func parseSystems(systemsStr string) []string {
	systems := []string{}
	for _, s := range strings.Split(systemsStr, ",") {
		s = strings.TrimSpace(s)
		if s != "" {
			systems = append(systems, s)
		}
	}
	return systems
}
