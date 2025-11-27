// Package database provides database connection pooling and query execution.
package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	// PostgreSQL driver for database/sql
	_ "github.com/lib/pq"
	"github.com/rs/zerolog/log"
)

// Connection wraps a database connection pool.
type Connection struct {
	db *sql.DB
}

// NewConnection creates a new database connection with the given parameters.
// It verifies the connection before returning.
func NewConnection(connStr string, maxConns, maxIdle, minutesIdle int) (*Connection, error) {
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	db.SetMaxOpenConns(maxConns)
	db.SetMaxIdleConns(maxIdle)
	db.SetConnMaxIdleTime(time.Duration(minutesIdle) * time.Minute)

	if err := verifyConnection(db); err != nil {
		_ = db.Close() // Ignore close error during error handling
		return nil, err
	}

	log.Info().
		Int("max_conns", maxConns).
		Int("max_idle", maxIdle).
		Int("minutes_idle", minutesIdle).
		Msg("Database connection established")

	return &Connection{db: db}, nil
}

func verifyConnection(db *sql.DB) error {
	waitSeconds := []time.Duration{0, 5, 10, 20, 60}
	maxRetries := len(waitSeconds)

	var lastErr error
	for retry := 0; retry < maxRetries; retry++ {
		if retry > 0 {
			log.Warn().
				Int("retry", retry).
				Dur("wait", waitSeconds[retry]*time.Second).
				Err(lastErr).
				Msg("Retrying database connection")
			time.Sleep(waitSeconds[retry] * time.Second)
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		lastErr = db.PingContext(ctx)
		cancel()

		if lastErr == nil {
			return nil
		}
	}

	return fmt.Errorf("failed to connect after %d retries: %w", maxRetries, lastErr)
}

// DB returns the underlying sql.DB instance.
func (c *Connection) DB() *sql.DB {
	return c.db
}

// Close closes the database connection pool.
func (c *Connection) Close() error {
	if c.db != nil {
		return c.db.Close()
	}
	return nil
}

// Ping verifies the database connection is alive.
func (c *Connection) Ping(ctx context.Context) error {
	return c.db.PingContext(ctx)
}

// ExecContext executes a query without returning any rows.
func (c *Connection) ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error) {
	return c.db.ExecContext(ctx, query, args...)
}

// QueryContext executes a query that returns rows.
func (c *Connection) QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
	return c.db.QueryContext(ctx, query, args...)
}

// QueryRowContext executes a query that is expected to return at most one row.
func (c *Connection) QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row {
	return c.db.QueryRowContext(ctx, query, args...)
}

// BeginTx begins a transaction with the given options.
func (c *Connection) BeginTx(ctx context.Context, opts *sql.TxOptions) (*sql.Tx, error) {
	return c.db.BeginTx(ctx, opts)
}
