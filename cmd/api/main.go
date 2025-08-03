package main

import (
	"bufio"
	"context"
	"database/sql"
	"expvar"
	"flag"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"greenlight.tundeosborne/internal/data"
	"greenlight.tundeosborne/internal/jsonlog"
	"greenlight.tundeosborne/internal/mailer"

	_ "github.com/lib/pq"
)

var (
	buildTime string
	version   string
)

type config struct {
	port int
	env  string
	db   struct {
		dsn          string
		maxOpenConns int
		maxIdleConns int
		maxIdleTime  string
	}
	limiter struct {
		rps     float64
		burst   int
		enabled bool
	}
	smtp struct {
		host     string
		port     int
		username string
		password string
		sender   string
	}

	cors struct {
		trustedOrigins []string
	}
}

type application struct {
	config config
	logger *jsonlog.Logger
	models data.Models
	mailer mailer.Mailer
	wg     sync.WaitGroup
}

// getEnv returns the value of an environment variable or a default value if not set
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt returns the value of an environment variable as an integer or a default value if not set or invalid
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

// getEnvBool returns the value of an environment variable as a boolean or a default value if not set or invalid
func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}

// loadEnvFile loads environment variables from a .env file if it exists
func loadEnvFile() {
	file, err := os.Open(".env")
	if err != nil {
		// .env file doesn't exist, that's okay
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Split on first = sign
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])

			// Remove quotes if present
			if (strings.HasPrefix(value, `"`) && strings.HasSuffix(value, `"`)) ||
				(strings.HasPrefix(value, `'`) && strings.HasSuffix(value, `'`)) {
				value = value[1 : len(value)-1]
			}

			// Only set if not already set (environment variables take precedence)
			if os.Getenv(key) == "" {
				os.Setenv(key, value)
			}
		}
	}
}

func main() {
	// Load .env file before parsing flags
	loadEnvFile()

	var cfg config

	// Read configuration from environment variables first
	cfg.smtp.host = getEnv("SMTP_HOST", "")
	cfg.smtp.port = getEnvInt("SMTP_PORT", 0)
	cfg.smtp.username = getEnv("SMTP_USERNAME", "")
	cfg.smtp.password = getEnv("SMTP_PASSWORD", "")
	cfg.smtp.sender = getEnv("SMTP_SENDER", "")

	cfg.db.dsn = getEnv("GREENLIGHT_DB_DSN", "")
	cfg.port = getEnvInt("PORT", 4000)
	cfg.env = getEnv("ENV", "development")
	cfg.limiter.enabled = getEnvBool("LIMITER_ENABLED", true)

	// Parse CORS trusted origins from environment
	if corsOrigins := getEnv("CORS_TRUSTED_ORIGINS", ""); corsOrigins != "" {
		cfg.cors.trustedOrigins = strings.Fields(corsOrigins)
	}

	flag.IntVar(&cfg.port, "port", cfg.port, "API server port (overrides PORT env var)")
	flag.StringVar(&cfg.env, "env", cfg.env, "Environment (overrides ENV env var)")

	flag.StringVar(&cfg.db.dsn, "db-dsn", cfg.db.dsn, "PostgreSQL DSN (overrides GREENLIGHT_DB_DSN env var)")

	flag.IntVar(&cfg.db.maxOpenConns, "db-max-open-conns", 25, "PostgreSQL max open connections")

	flag.IntVar(&cfg.db.maxIdleConns, "db-max-idle-conns", 25, "PostgreSQL max idle connections")

	flag.StringVar(&cfg.db.maxIdleTime, "db-max-idle-time", "15m", "PostgreSQL max connection idle time")

	flag.Float64Var(&cfg.limiter.rps, "limiter-rps", 2, "Rate limiter maximum requests per second")
	flag.IntVar(&cfg.limiter.burst, "limiter-burst", 4, "Rate limiter maximum burst")
	flag.BoolVar(&cfg.limiter.enabled, "limiter-enabled", cfg.limiter.enabled, "Enable rate limiter (overrides LIMITER_ENABLED env var)")

	// SMTP flags can override environment variables
	flag.StringVar(&cfg.smtp.host, "smtp-host", cfg.smtp.host, "SMTP host (overrides SMTP_HOST env var)")
	flag.IntVar(&cfg.smtp.port, "smtp-port", cfg.smtp.port, "SMTP port (overrides SMTP_PORT env var)")
	flag.StringVar(&cfg.smtp.username, "smtp-username", cfg.smtp.username, "SMTP username (overrides SMTP_USERNAME env var)")
	flag.StringVar(&cfg.smtp.password, "smtp-password", cfg.smtp.password, "SMTP password (overrides SMTP_PASSWORD env var)")
	flag.StringVar(&cfg.smtp.sender, "smtp-sender", cfg.smtp.sender, "SMTP sender (overrides SMTP_SENDER env var)")

	flag.Func("cors-trusted-origins", "Trusted CORS origins (space separated, overrides CORS_TRUSTED_ORIGINS env var)", func(val string) error {
		cfg.cors.trustedOrigins = strings.Fields(val)
		return nil
	})

	displayVersion := flag.Bool("version", false, "Display version and exit")

	flag.Parse()

	if *displayVersion {
		fmt.Printf("Version:\t%s\n", version)
		fmt.Printf("Build time:\t%s\n", buildTime)
		os.Exit(0)
	}

	// Validate database configuration
	if cfg.db.dsn == "" {
		fmt.Fprintf(os.Stderr, "Error: Database DSN is required\n")
		fmt.Fprintf(os.Stderr, "Set GREENLIGHT_DB_DSN environment variable or use -db-dsn flag\n")
		fmt.Fprintf(os.Stderr, "Example: GREENLIGHT_DB_DSN='postgres://user:pass@localhost/greenlight?sslmode=disable'\n")
		os.Exit(1)
	}

	// Validate SMTP configuration and show configuration source
	logger := jsonlog.New(os.Stdout, jsonlog.LevelInfo)

	if cfg.smtp.host == "" {
		fmt.Fprintf(os.Stderr, "Error: SMTP host is required\n")
		fmt.Fprintf(os.Stderr, "Set SMTP_HOST environment variable or use -smtp-host flag\n")
		fmt.Fprintf(os.Stderr, "Example: SMTP_HOST=sandbox.smtp.mailtrap.io\n")
		os.Exit(1)
	}
	if cfg.smtp.port == 0 {
		fmt.Fprintf(os.Stderr, "Error: SMTP port is required\n")
		fmt.Fprintf(os.Stderr, "Set SMTP_PORT environment variable or use -smtp-port flag\n")
		fmt.Fprintf(os.Stderr, "Example: SMTP_PORT=2525\n")
		os.Exit(1)
	}
	if cfg.smtp.username == "" {
		fmt.Fprintf(os.Stderr, "Error: SMTP username is required\n")
		fmt.Fprintf(os.Stderr, "Set SMTP_USERNAME environment variable or use -smtp-username flag\n")
		fmt.Fprintf(os.Stderr, "Get credentials from your SMTP provider (e.g., Mailtrap, Gmail, SendGrid)\n")
		os.Exit(1)
	}
	if cfg.smtp.password == "" {
		fmt.Fprintf(os.Stderr, "Error: SMTP password is required\n")
		fmt.Fprintf(os.Stderr, "Set SMTP_PASSWORD environment variable or use -smtp-password flag\n")
		fmt.Fprintf(os.Stderr, "Get credentials from your SMTP provider (e.g., Mailtrap, Gmail, SendGrid)\n")
		os.Exit(1)
	}
	if cfg.smtp.sender == "" {
		fmt.Fprintf(os.Stderr, "Error: SMTP sender is required\n")
		fmt.Fprintf(os.Stderr, "Set SMTP_SENDER environment variable or use -smtp-sender flag\n")
		fmt.Fprintf(os.Stderr, "Example: SMTP_SENDER='Your App <noreply@yourapp.com>'\n")
		os.Exit(1)
	}

	// Log configuration source for debugging
	envHost := os.Getenv("SMTP_HOST")
	envPort := os.Getenv("SMTP_PORT")
	envDB := os.Getenv("GREENLIGHT_DB_DSN")

	if envDB != "" {
		logger.PrintInfo("Database configuration loaded from environment variables", map[string]string{
			"dsn": cfg.db.dsn,
		})
	}

	if envHost != "" && envPort != "" {
		logger.PrintInfo("SMTP configuration loaded from environment variables", map[string]string{
			"host":     cfg.smtp.host,
			"port":     fmt.Sprintf("%d", cfg.smtp.port),
			"username": cfg.smtp.username,
		})
	}

	db, err := openDB(cfg)
	if err != nil {
		logger.PrintFatal(err, nil)
	}

	defer db.Close()

	logger.PrintInfo("database connection pool established", nil)

	expvar.NewString("version").Set(version)

	expvar.Publish("goroutines", expvar.Func(func() interface{} {
		return runtime.NumGoroutine()
	}))

	expvar.Publish("database", expvar.Func(func() interface{} {
		return db.Stats()
	}))

	expvar.Publish("timestamp", expvar.Func(func() interface{} {
		return time.Now().Unix()
	}))

	app := &application{
		config: cfg,
		logger: logger,
		models: data.NewModels(db),
		mailer: mailer.New(cfg.smtp.host, cfg.smtp.port, cfg.smtp.username, cfg.smtp.password, cfg.smtp.sender),
	}

	err = app.serve()
	if err != nil {
		logger.PrintFatal(err, nil)
	}

}

func openDB(cfg config) (*sql.DB, error) {

	db, err := sql.Open("postgres", cfg.db.dsn)
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(cfg.db.maxOpenConns)

	db.SetMaxIdleConns(cfg.db.maxIdleConns)

	duration, err := time.ParseDuration(cfg.db.maxIdleTime)
	if err != nil {
		return nil, err
	}
	db.SetConnMaxIdleTime(duration)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = db.PingContext(ctx)
	if err != nil {
		return nil, err
	}

	return db, nil
}
