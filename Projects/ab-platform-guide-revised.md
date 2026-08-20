# Building a Production-Minded A/B Testing Platform — An Incremental Guide

> Stack: **Go** (backend/API/bucketing engine), **PostgreSQL** (system of record), **Redis** (assignment cache + rate limiting), **React + TypeScript** (dashboard), a tiny **JS SDK** (client integration), **Docker Compose** (local infra), **GitHub Actions** (CI). This mirrors your existing React/TypeScript/Go stack. If you'd rather swap Go for Quart/Python, the domain logic in Phases 2–7 ports over 1:1 — only the folder layout and syntax change.

> **Revision note:** This version fixes several correctness and operational gaps in the original guide: migrations now run automatically in Compose and correctly in CI, event aggregation counts unique users instead of raw event rows, event shutdown is synchronized instead of using a sleep, JWT parsing pins the signing algorithm, admin bootstrap uses PostgreSQL `pgcrypto`, the bucketing tests use safe user IDs, and the guide no longer overstates Redis TTL-based assignments as permanently sticky.

## How this guide works

- Each phase **builds on the previous one** — nothing is thrown away, nothing is rewritten (unless a phase explicitly says "refactor").
- Every phase ends with: a **full folder tree** (with new/changed files marked `# NEW` or `# CHANGED`), the **full contents of every new file**, and a **checkpoint** — a command you run to prove that phase works before moving to the next.
- Code comments are **minimal and load-bearing** — only where the "why" isn't obvious from the code itself. No comment-per-line noise.
- "Production-minded" here means: input validation, error handling that doesn't leak internals, structured logging, graceful shutdown, migrations (not `AutoMigrate`-style magic), connection pooling, auth, rate limiting, health checks, tests, and a working CI pipeline — not just a demo that runs on your laptop.

## What we're building

A single-tenant **A/B testing platform**, scoped to the core loop every real experimentation platform needs:

1. Define an experiment with N variants and traffic allocation.
2. Deterministically **bucket** a user into a variant (same user -> same variant for the lifetime of the cached assignment, without a DB write on the hot path).
3. Track **exposures** (who saw what) and **conversion events** (what they did).
4. Compute **statistical significance** between variants (two-proportion z-test) and expose results.
5. Manage all of this through an authenticated **dashboard**, and let any client fetch an assignment through a tiny **SDK**.

Explicitly out of scope (noted, not built): multi-armed bandits, CUPED/variance reduction, feature-flag kill-switches beyond a basic pause, multi-tenancy, and Bayesian stats. The architecture leaves room for all of them — we call this out where relevant.

---

## Phase 0 — Architecture & final folder structure

Before writing code, know where you're going. This is the **end state** after all phases. Every later phase shows only the diff against this tree, with new files marked.

```
ab-platform/
├── backend/
│   ├── cmd/
│   │   └── api/
│   │       └── main.go              # entrypoint: wires config, db, redis, router, graceful shutdown
│   ├── internal/
│   │   ├── config/
│   │   │   └── config.go            # env-based config loader
│   │   ├── db/
│   │   │   ├── db.go                # pgx pool setup
│   │   │   └── migrations/
│   │   │       ├── 0001_experiments.sql
│   │   │       ├── 0002_events.sql
│   │   │       └── 0003_users.sql
│   │   ├── domain/
│   │   │   ├── experiment.go        # core structs + validation
│   │   │   └── errors.go            # typed domain errors
│   │   ├── bucketing/
│   │   │   ├── hash.go              # deterministic bucketing algorithm
│   │   │   └── hash_test.go
│   │   ├── repository/
│   │   │   ├── experiment_repo.go
│   │   │   └── event_repo.go
│   │   ├── cache/
│   │   │   └── redis.go             # assignment cache
│   │   ├── service/
│   │   │   ├── experiment_service.go
│   │   │   ├── assignment_service.go
│   │   │   ├── event_service.go
│   │   │   └── stats_service.go     # z-test + results aggregation
│   │   ├── handler/
│   │   │   ├── health_handler.go
│   │   │   ├── experiment_handler.go
│   │   │   ├── assignment_handler.go
│   │   │   ├── event_handler.go
│   │   │   └── router.go
│   │   ├── middleware/
│   │   │   ├── auth.go              # JWT auth
│   │   │   ├── logging.go           # structured request logging
│   │   │   ├── recover.go           # panic recovery -> 500
│   │   │   └── ratelimit.go         # token-bucket per-IP limiter
│   │   └── platform/
│   │       └── logger.go            # slog setup
│   ├── go.mod
│   ├── go.sum
│   ├── Makefile
│   └── Dockerfile
├── sdk/
│   └── js/
│       ├── src/
│       │   └── index.ts             # getVariant(), trackConversion()
│       ├── package.json
│       └── tsconfig.json
├── frontend/
│   ├── src/
│   │   ├── api/
│   │   │   └── client.ts
│   │   ├── pages/
│   │   │   ├── Login.tsx
│   │   │   ├── ExperimentList.tsx
│   │   │   ├── ExperimentDetail.tsx
│   │   │   └── ExperimentCreate.tsx
│   │   ├── components/
│   │   │   ├── VariantAllocationEditor.tsx
│   │   │   └── ResultsChart.tsx
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   └── vite.config.ts
├── infra/
│   ├── docker-compose.yml
│   └── docker-compose.ci.yml
├── .github/
│   └── workflows/
│       └── ci.yml
└── README.md

```

**Why Go for the backend, specifically:** the assignment endpoint is the single hottest path in any experimentation platform — every page load on every experiment-gated surface can call it. It needs to be low-latency and cheap to horizontally scale. Go's low per-request overhead and simple concurrency model fit that better than an async Python framework would, without reaching for anything exotic.

**Checkpoint for this phase:** none — this is a map, not code. Phase 1 starts filling it in.

---

## Phase 1 — Hello World: a booting Go service with structured logging and graceful shutdown

Goal: one endpoint (`GET /healthz`), but built the way the real server will be built — config from env, structured logs, graceful shutdown. Skipping this discipline now means retrofitting it under pressure later.

### Folder tree after this phase

```
ab-platform/
└── backend/
    ├── cmd/api/main.go              # NEW
    ├── internal/
    │   ├── config/config.go         # NEW
    │   ├── platform/logger.go       # NEW
    │   └── handler/
    │       ├── health_handler.go    # NEW
    │       └── router.go            # NEW
    ├── go.mod                       # NEW
    └── Makefile                     # NEW

```

### `backend/go.mod`

```
module github.com/emran/ab-platform/backend

go 1.23

```

Run `go mod tidy` after Phase 2 adds real dependencies — for hello-world alone, no external packages are needed beyond the standard library.

### `backend/internal/config/config.go`

```go
package config

import (
	"fmt"
	"os"
)

// Config holds every value the app needs from its environment. Centralizing
// this means no other package reads os.Getenv directly — one place to see
// every knob the service exposes.
type Config struct {
	Port        string
	Environment string // "development" | "production"
}

func Load() (Config, error) {
	cfg := Config{
		Port:        getEnv("PORT", "8080"),
		Environment: getEnv("APP_ENV", "development"),
	}
	if cfg.Port == "" {
		return Config{}, fmt.Errorf("PORT must not be empty")
	}
	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}

```

### `backend/internal/platform/logger.go`

```go
package platform

import (
	"log/slog"
	"os"
)

// NewLogger returns JSON logs in production (machine-parseable, ships to
// log aggregators cleanly) and human-readable text logs in development.
func NewLogger(env string) *slog.Logger {
	level := slog.LevelInfo
	if env == "development" {
		level = slog.LevelDebug
	}
	opts := &slog.HandlerOptions{Level: level}

	if env == "production" {
		return slog.New(slog.NewJSONHandler(os.Stdout, opts))
	}
	return slog.New(slog.NewTextHandler(os.Stdout, opts))
}

```

### `backend/internal/handler/health_handler.go`

```go
package handler

import (
	"encoding/json"
	"net/http"
)

// HealthHandler reports liveness. It intentionally does no dependency
// checks yet (DB, Redis) -- those arrive in Phase 2/4 as a separate
// /readyz, so a slow dependency never flips the liveness probe and
// causes an unnecessary pod restart.
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

```

### `backend/internal/handler/router.go`

```
package handler

import "net/http"

// NewRouter is the single place routes are registered. Every later phase
// adds lines here instead of scattering mux.Handle calls across the codebase.
func NewRouter() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", HealthHandler)
	return mux
}

```

### `backend/cmd/api/main.go`

```
package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/emran/ab-platform/backend/internal/config"
	"github.com/emran/ab-platform/backend/internal/handler"
	"github.com/emran/ab-platform/backend/internal/platform"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic(err) // fails fast: a bad config must never boot the process
	}

	logger := platform.NewLogger(cfg.Environment)
	router := handler.NewRouter()

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Run the server in a goroutine so the main goroutine can wait on
	// an OS signal and drive graceful shutdown.
	go func() {
		logger.Info("server starting", "port", cfg.Port, "env", cfg.Environment)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	logger.Info("shutdown signal received")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}
	logger.Info("server stopped cleanly")
}

```

### `backend/Makefile`

```
.PHONY: run test build

run:
	go run ./cmd/api

test:
	go test ./... -v -race

build:
	go build -o bin/api ./cmd/api

```

### Checkpoint

```
cd backend
go run ./cmd/api
# in another terminal:
curl -s localhost:8080/healthz
# {"status":"ok"}

```

Ctrl+C the running process and confirm you see `"shutdown signal received"` then `"server stopped cleanly"` in the logs, not a hard kill. That graceful-shutdown path is what stops in-flight requests from being dropped every time you deploy.

---

## Phase 2 — Domain models & PostgreSQL schema

Goal: real tables via versioned SQL migrations (no ORM auto-migrate — every schema change is an explicit, reviewable, reversible file), a pooled DB connection, and Go structs with validation.

### Folder tree after this phase

```
ab-platform/
├── infra/
│   └── docker-compose.yml               # NEW (postgres + redis for local dev)
└── backend/
    ├── internal/
    │   ├── db/
    │   │   ├── db.go                    # NEW
    │   │   └── migrations/
    │   │       └── 0001_experiments.sql # NEW
    │   └── domain/
    │       ├── experiment.go            # NEW
    │       └── errors.go                # NEW
    └── go.mod                           # CHANGED (adds pgx, golang-migrate)

```

### `infra/docker-compose.yml`

```
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ab_platform
      POSTGRES_PASSWORD: ab_platform
      POSTGRES_DB: ab_platform
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ab_platform"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:

```

### `backend/internal/db/migrations/0001_experiments.sql`

```
-- +migrate Up
CREATE TABLE experiments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key             TEXT NOT NULL UNIQUE,       -- stable identifier used by SDK calls, e.g. "checkout-button-color"
    name            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'running', 'paused', 'completed')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE variants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_id   UUID NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    key             TEXT NOT NULL,               -- e.g. "control", "treatment"
    allocation_pct  NUMERIC(5,2) NOT NULL CHECK (allocation_pct >= 0 AND allocation_pct <= 100),
    is_control      BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (experiment_id, key)
);

-- enforced in application code at write time (Postgres can't sum a window
-- constraint declaratively without a trigger); see experiment_service.go
COMMENT ON TABLE variants IS 'allocation_pct across all variants of one experiment must sum to 100';

CREATE INDEX idx_variants_experiment_id ON variants(experiment_id);

-- +migrate Down
DROP TABLE variants;
DROP TABLE experiments;

```

### `backend/internal/domain/errors.go`

```
package domain

import "errors"

// Typed sentinel errors let handlers map domain failures to HTTP status
// codes with errors.Is, instead of string-matching error messages.
var (
	ErrNotFound            = errors.New("resource not found")
	ErrInvalidAllocation   = errors.New("variant allocations must sum to 100")
	ErrDuplicateKey        = errors.New("key already exists")
	ErrExperimentNotEditable = errors.New("experiment is not editable in its current status")
)

```

### `backend/internal/domain/experiment.go`

```
package domain

import (
	"fmt"
	"time"
)

type ExperimentStatus string

const (
	StatusDraft     ExperimentStatus = "draft"
	StatusRunning   ExperimentStatus = "running"
	StatusPaused    ExperimentStatus = "paused"
	StatusCompleted ExperimentStatus = "completed"
)

type Variant struct {
	ID            string
	ExperimentID  string
	Key           string
	AllocationPct float64
	IsControl     bool
}

type Experiment struct {
	ID        string
	Key       string
	Name      string
	Status    ExperimentStatus
	Variants  []Variant
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Validate runs invariants that must hold regardless of which layer
// constructed the struct (HTTP handler, repository scan, or a test).
func (e Experiment) Validate() error {
	if e.Key == "" {
		return fmt.Errorf("key is required")
	}
	if e.Name == "" {
		return fmt.Errorf("name is required")
	}
	if len(e.Variants) < 2 {
		return fmt.Errorf("experiment needs at least 2 variants")
	}

	var total float64
	controls := 0
	seen := map[string]bool{}
	for _, v := range e.Variants {
		if seen[v.Key] {
			return fmt.Errorf("duplicate variant key %q", v.Key)
		}
		seen[v.Key] = true
		total += v.AllocationPct
		if v.IsControl {
			controls++
		}
	}
	if controls != 1 {
		return fmt.Errorf("exactly one variant must be marked as control, got %d", controls)
	}
	// float tolerance for the 100% sum check
	if total < 99.99 || total > 100.01 {
		return ErrInvalidAllocation
	}
	return nil
}

```

### `backend/internal/db/db.go`

```
package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool opens a connection pool, not a single connection -- every
// concurrent request borrows and returns a connection instead of
// contending on one. Sizes are conservative defaults for a single
// service instance; tune via env vars once you have real traffic data.
func NewPool(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse dsn: %w", err)
	}
	poolCfg.MaxConns = 20
	poolCfg.MinConns = 2
	poolCfg.MaxConnLifetime = time.Hour
	poolCfg.MaxConnIdleTime = 15 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return pool, nil
}

```

### `backend/go.mod` (changed)

```
module github.com/emran/ab-platform/backend

go 1.23

require (
	github.com/jackc/pgx/v5 v5.6.0
	github.com/golang-migrate/migrate/v4 v4.17.1
)

```

Run `go mod tidy` to resolve exact versions and populate `go.sum`.

### Running the migration

Install the migrate CLI once (`brew install golang-migrate` or `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest`), then:

```
docker compose -f infra/docker-compose.yml up -d
migrate -database "postgres://ab_platform:ab_platform@localhost:5432/ab_platform?sslmode=disable" \
        -path backend/internal/db/migrations up

```

### Checkpoint

```
psql "postgres://ab_platform:ab_platform@localhost:5432/ab_platform?sslmode=disable" \
     -c "\d experiments"

```

You should see the `experiments` table with the `status` check constraint listed. `go build ./...` from `backend/` should compile cleanly with no `main.go` changes yet — the domain package has no callers until Phase 3.

---

## Phase 3 — The bucketing engine (the core IP of the platform)

This is the piece that actually makes it an experimentation platform rather than a CRUD app: given a `userID` and an `experimentKey`, deterministically and statelessly decide which variant that user falls into — same answer every time for a fixed experiment definition, no database row required to remember the decision, uniform distribution across variants, and independent between experiments (a user in "treatment" on experiment A must not be biased toward "treatment" on experiment B).

### Folder tree after this phase

```
ab-platform/
└── backend/
    └── internal/
        └── bucketing/
            ├── hash.go          # NEW
            └── hash_test.go     # NEW

```

### The algorithm

1. Concatenate `experimentKey + ":" + userID` — salting with the experiment key is what makes bucketing independent across experiments; without it, the same user would land in the same relative "slot" in every experiment, correlating results.
2. Hash it with FNV-1a (fast, good-enough avalanche for bucketing, no crypto needed here — this isn't a security boundary).
3. Take the hash mod 10,000 to get a bucket in `[0, 10000)` — using 10,000 instead of 100 gives two decimal places of allocation precision (e.g. 33.33%).
4. Walk the experiment's variants in a **stable order** (sorted by key), accumulating allocation ranges, and return the variant whose range contains the bucket.

### `backend/internal/bucketing/hash.go`

```
package bucketing

import (
	"hash/fnv"
	"sort"

	"github.com/emran/ab-platform/backend/internal/domain"
)

const bucketSpace = 10_000 // 2 decimal places of allocation precision

// BucketOf returns a stable integer in [0, bucketSpace) for a given
// experiment+user pair. Same inputs -> same output, forever, across
// process restarts and machines -- it's a pure function of its inputs.
func BucketOf(experimentKey, userID string) int {
	h := fnv.New32a()
	h.Write([]byte(experimentKey + ":" + userID))
	return int(h.Sum32() % bucketSpace)
}

// Assign maps a user into one of an experiment's variants. Variants are
// sorted by key before walking allocation ranges so the mapping is
// independent of slice/DB ordering -- reordering rows must never
// reshuffle who's in which bucket.
func Assign(exp domain.Experiment, userID string) (domain.Variant, bool) {
	if len(exp.Variants) == 0 {
		return domain.Variant{}, false
	}

	sorted := make([]domain.Variant, len(exp.Variants))
	copy(sorted, exp.Variants)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].Key < sorted[j].Key })

	bucket := BucketOf(exp.Key, userID)

	cursor := 0.0
	for _, v := range sorted {
		width := int(v.AllocationPct / 100 * bucketSpace)
		if bucket >= int(cursor) && bucket < int(cursor)+width {
			return v, true
		}
		cursor += v.AllocationPct / 100 * bucketSpace
	}
	// Rounding can leave the last few buckets unclaimed (e.g. 33.33% x 3
	// truncates to 9999 of 10000 buckets). Fall back to the last variant
	// rather than returning "no assignment" for a real user.
	return sorted[len(sorted)-1], true
}

```

### `backend/internal/bucketing/hash_test.go`

```
package bucketing

import (
	"fmt"
	"testing"

	"github.com/emran/ab-platform/backend/internal/domain"
)

func TestBucketOf_IsDeterministic(t *testing.T) {
	a := BucketOf("checkout-button-color", "user-42")
	b := BucketOf("checkout-button-color", "user-42")
	if a != b {
		t.Fatalf("expected same bucket for same inputs, got %d and %d", a, b)
	}
}

func TestBucketOf_DiffersAcrossExperiments(t *testing.T) {
	// Not a strict guarantee for every user, but across many users the
	// distributions must be uncorrelated -- checked via the distribution
	// test below, not per-user equality.
	a := BucketOf("experiment-a", "user-1")
	b := BucketOf("experiment-b", "user-1")
	if a == b {
		t.Log("collision on one user is fine; see distribution test for the real guarantee")
	}
}

func TestAssign_RespectsAllocation(t *testing.T) {
	exp := domain.Experiment{
		Key: "checkout-button-color",
		Variants: []domain.Variant{
			{Key: "control", AllocationPct: 50, IsControl: true},
			{Key: "treatment", AllocationPct: 50},
		},
	}

	counts := map[string]int{}
	const n = 100_000
	for i := 0; i < n; i++ {
		userID := randomUserID(i)
		v, ok := Assign(exp, userID)
		if !ok {
			t.Fatal("expected an assignment")
		}
		counts[v.Key]++
	}

	for key, count := range counts {
		pct := float64(count) / float64(n) * 100
		if pct < 48 || pct > 52 {
			t.Errorf("variant %q got %.2f%% of traffic, expected ~50%%", key, pct)
		}
	}
}

func TestAssign_UnevenSplit(t *testing.T) {
	exp := domain.Experiment{
		Key: "pricing-page",
		Variants: []domain.Variant{
			{Key: "control", AllocationPct: 90, IsControl: true},
			{Key: "treatment", AllocationPct: 10},
		},
	}

	counts := map[string]int{}
	const n = 100_000
	for i := 0; i < n; i++ {
		v, _ := Assign(exp, randomUserID(i))
		counts[v.Key]++
	}

	treatmentPct := float64(counts["treatment"]) / float64(n) * 100
	if treatmentPct < 9 || treatmentPct > 11 {
		t.Errorf("expected ~10%% in treatment, got %.2f%%", treatmentPct)
	}
}

func randomUserID(i int) string {
	return fmt.Sprintf("user-%d-synthetic", i)
}

```

### Checkpoint

```
cd backend
go test ./internal/bucketing/... -v

```

All four tests should pass, and `TestAssign_RespectsAllocation` / `TestAssign_UnevenSplit` prove the hash distributes close to the configured allocation over 100k synthetic users — this is the test you re-run any time you touch the hashing algorithm.

---

## Phase 4 — Repository, service, and CRUD API for experiments

Goal: wire the domain + bucketing logic into a real HTTP API backed by Postgres, with the classic three layers kept separate: **repository** (SQL only, no business rules), **service** (business rules, no SQL, no HTTP), **handler** (HTTP only, no SQL, no business rules). This separation is what keeps the codebase testable as it grows — you can unit-test `experiment_service.go` with a fake repository and never touch a real database.

### Folder tree after this phase

```
ab-platform/
└── backend/
    ├── internal/
    │   ├── repository/
    │   │   └── experiment_repo.go      # NEW
    │   ├── service/
    │   │   └── experiment_service.go   # NEW
    │   ├── handler/
    │   │   ├── experiment_handler.go   # NEW
    │   │   └── router.go               # CHANGED
    │   └── db/
    │       └── migrations/
    │           └── 0001_experiments.sql # (unchanged, from Phase 2)
    └── cmd/api/main.go                 # CHANGED (wires DB + real handlers)

```

### `backend/internal/repository/experiment_repo.go`

```
package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type ExperimentRepository struct {
	pool *pgxpool.Pool
}

func NewExperimentRepository(pool *pgxpool.Pool) *ExperimentRepository {
	return &ExperimentRepository{pool: pool}
}

// Create inserts the experiment and its variants in one transaction --
// either both succeed or neither does. A half-written experiment
// (rows in `experiments` with no matching `variants`) is worse than a
// failed request the client can retry.
func (r *ExperimentRepository) Create(ctx context.Context, exp domain.Experiment) (domain.Experiment, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return domain.Experiment{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) // no-op if Commit succeeds

	var id string
	err = tx.QueryRow(ctx,
		`INSERT INTO experiments (key, name, status) VALUES ($1, $2, $3) RETURNING id`,
		exp.Key, exp.Name, domain.StatusDraft,
	).Scan(&id)
	if err != nil {
		if isUniqueViolation(err) {
			return domain.Experiment{}, domain.ErrDuplicateKey
		}
		return domain.Experiment{}, fmt.Errorf("insert experiment: %w", err)
	}

	for _, v := range exp.Variants {
		_, err = tx.Exec(ctx,
			`INSERT INTO variants (experiment_id, key, allocation_pct, is_control) VALUES ($1, $2, $3, $4)`,
			id, v.Key, v.AllocationPct, v.IsControl,
		)
		if err != nil {
			return domain.Experiment{}, fmt.Errorf("insert variant %q: %w", v.Key, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return domain.Experiment{}, fmt.Errorf("commit tx: %w", err)
	}

	exp.ID = id
	exp.Status = domain.StatusDraft
	return exp, nil
}

func (r *ExperimentRepository) GetByKey(ctx context.Context, key string) (domain.Experiment, error) {
	var exp domain.Experiment
	err := r.pool.QueryRow(ctx,
		`SELECT id, key, name, status, created_at, updated_at FROM experiments WHERE key = $1`,
		key,
	).Scan(&exp.ID, &exp.Key, &exp.Name, &exp.Status, &exp.CreatedAt, &exp.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Experiment{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.Experiment{}, fmt.Errorf("select experiment: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT id, experiment_id, key, allocation_pct, is_control FROM variants WHERE experiment_id = $1`,
		exp.ID,
	)
	if err != nil {
		return domain.Experiment{}, fmt.Errorf("select variants: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var v domain.Variant
		if err := rows.Scan(&v.ID, &v.ExperimentID, &v.Key, &v.AllocationPct, &v.IsControl); err != nil {
			return domain.Experiment{}, fmt.Errorf("scan variant: %w", err)
		}
		exp.Variants = append(exp.Variants, v)
	}
	return exp, rows.Err()
}

func (r *ExperimentRepository) List(ctx context.Context) ([]domain.Experiment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, key, name, status, created_at, updated_at FROM experiments ORDER BY created_at DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("list experiments: %w", err)
	}
	defer rows.Close()

	var out []domain.Experiment
	for rows.Next() {
		var e domain.Experiment
		if err := rows.Scan(&e.ID, &e.Key, &e.Name, &e.Status, &e.CreatedAt, &e.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan experiment: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *ExperimentRepository) UpdateStatus(ctx context.Context, key string, status domain.ExperimentStatus) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE experiments SET status = $1, updated_at = now() WHERE key = $2`,
		status, key,
	)
	if err != nil {
		return fmt.Errorf("update status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

```

### `backend/internal/service/experiment_service.go`

```
package service

import (
	"context"
	"fmt"

	"github.com/emran/ab-platform/backend/internal/domain"
)

// ExperimentRepository is defined here, at the consumer, not in the
// repository package -- Go convention: accept interfaces, return
// structs. This is also the seam unit tests use to inject a fake.
type ExperimentRepository interface {
	Create(ctx context.Context, exp domain.Experiment) (domain.Experiment, error)
	GetByKey(ctx context.Context, key string) (domain.Experiment, error)
	List(ctx context.Context) ([]domain.Experiment, error)
	UpdateStatus(ctx context.Context, key string, status domain.ExperimentStatus) error
}

type ExperimentService struct {
	repo ExperimentRepository
}

func NewExperimentService(repo ExperimentRepository) *ExperimentService {
	return &ExperimentService{repo: repo}
}

func (s *ExperimentService) Create(ctx context.Context, exp domain.Experiment) (domain.Experiment, error) {
	if err := exp.Validate(); err != nil {
		return domain.Experiment{}, fmt.Errorf("%w: %s", domain.ErrInvalidAllocation, err.Error())
	}
	return s.repo.Create(ctx, exp)
}

func (s *ExperimentService) Get(ctx context.Context, key string) (domain.Experiment, error) {
	return s.repo.GetByKey(ctx, key)
}

func (s *ExperimentService) List(ctx context.Context) ([]domain.Experiment, error) {
	return s.repo.List(ctx)
}

// Start moves a draft experiment to running. Variant definitions are intentionally immutable after creation in this guide; changing allocations or variant keys after exposure begins would invalidate the bucketing and historical analysis. Only drafts can start --
// you can't "start" a completed experiment back into live traffic
// without explicitly creating a new one, which keeps historical
// results from a finished experiment immutable.
func (s *ExperimentService) Start(ctx context.Context, key string) error {
	exp, err := s.repo.GetByKey(ctx, key)
	if err != nil {
		return err
	}
	if exp.Status != domain.StatusDraft && exp.Status != domain.StatusPaused {
		return domain.ErrExperimentNotEditable
	}
	return s.repo.UpdateStatus(ctx, key, domain.StatusRunning)
}

func (s *ExperimentService) Pause(ctx context.Context, key string) error {
	return s.repo.UpdateStatus(ctx, key, domain.StatusPaused)
}

func (s *ExperimentService) Complete(ctx context.Context, key string) error {
	return s.repo.UpdateStatus(ctx, key, domain.StatusCompleted)
}

```

### `backend/internal/handler/experiment_handler.go`

```
package handler

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/emran/ab-platform/backend/internal/domain"
)

// ExperimentService is the interface the handler needs -- again defined
// at the consumer so the handler package has zero import dependency on
// the concrete service implementation.
type ExperimentService interface {
	Create(ctx context.Context, exp domain.Experiment) (domain.Experiment, error)
	Get(ctx context.Context, key string) (domain.Experiment, error)
	List(ctx context.Context) ([]domain.Experiment, error)
	Start(ctx context.Context, key string) error
	Pause(ctx context.Context, key string) error
	Complete(ctx context.Context, key string) error
}

type ExperimentHandler struct {
	svc    ExperimentService
	logger *slog.Logger
}

func NewExperimentHandler(svc ExperimentService, logger *slog.Logger) *ExperimentHandler {
	return &ExperimentHandler{svc: svc, logger: logger}
}

type createVariantRequest struct {
	Key           string  `json:"key"`
	AllocationPct float64 `json:"allocationPct"`
	IsControl     bool    `json:"isControl"`
}

type createExperimentRequest struct {
	Key      string                  `json:"key"`
	Name     string                  `json:"name"`
	Variants []createVariantRequest `json:"variants"`
}

func (h *ExperimentHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createExperimentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	exp := domain.Experiment{Key: req.Key, Name: req.Name}
	for _, v := range req.Variants {
		exp.Variants = append(exp.Variants, domain.Variant{
			Key: v.Key, AllocationPct: v.AllocationPct, IsControl: v.IsControl,
		})
	}

	created, err := h.svc.Create(r.Context(), exp)
	if err != nil {
		h.handleError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (h *ExperimentHandler) Get(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	exp, err := h.svc.Get(r.Context(), key)
	if err != nil {
		h.handleError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, exp)
}

func (h *ExperimentHandler) List(w http.ResponseWriter, r *http.Request) {
	exps, err := h.svc.List(r.Context())
	if err != nil {
		h.handleError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, exps)
}

func (h *ExperimentHandler) Start(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Start(r.Context(), r.PathValue("key")); err != nil {
		h.handleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ExperimentHandler) Pause(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Pause(r.Context(), r.PathValue("key")); err != nil {
		h.handleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleError maps domain errors to HTTP status codes in one place, and
// logs unexpected errors server-side without leaking internals
// (SQL fragments, file paths) into the response body.
func (h *ExperimentHandler) handleError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, domain.ErrNotFound):
		writeError(w, http.StatusNotFound, "experiment not found")
	case errors.Is(err, domain.ErrDuplicateKey):
		writeError(w, http.StatusConflict, "an experiment with this key already exists")
	case errors.Is(err, domain.ErrInvalidAllocation):
		writeError(w, http.StatusUnprocessableEntity, err.Error())
	case errors.Is(err, domain.ErrExperimentNotEditable):
		writeError(w, http.StatusConflict, err.Error())
	default:
		h.logger.Error("unhandled error", "error", err)
		writeError(w, http.StatusInternalServerError, "internal server error")
	}
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

```

### `backend/internal/handler/router.go` (changed)

```
package handler

import "net/http"

func NewRouter(experiments *ExperimentHandler) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", HealthHandler)

	mux.HandleFunc("POST /v1/experiments", experiments.Create)
	mux.HandleFunc("GET /v1/experiments", experiments.List)
	mux.HandleFunc("GET /v1/experiments/{key}", experiments.Get)
	mux.HandleFunc("POST /v1/experiments/{key}/start", experiments.Start)
	mux.HandleFunc("POST /v1/experiments/{key}/pause", experiments.Pause)

	return mux
}

```

### `backend/cmd/api/main.go` (changed — new lines marked)

```
package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/emran/ab-platform/backend/internal/config"
	"github.com/emran/ab-platform/backend/internal/db"                // NEW
	"github.com/emran/ab-platform/backend/internal/handler"
	"github.com/emran/ab-platform/backend/internal/platform"
	"github.com/emran/ab-platform/backend/internal/repository"        // NEW
	"github.com/emran/ab-platform/backend/internal/service"           // NEW
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic(err)
	}

	logger := platform.NewLogger(cfg.Environment)

	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg.DatabaseURL) // NEW
	if err != nil {
		logger.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// NEW: wire repository -> service -> handler, each layer only
	// knowing about the layer directly below it.
	expRepo := repository.NewExperimentRepository(pool)
	expSvc := service.NewExperimentService(expRepo)
	expHandler := handler.NewExperimentHandler(expSvc, logger)

	router := handler.NewRouter(expHandler)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("server starting", "port", cfg.Port, "env", cfg.Environment)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	logger.Info("shutdown signal received")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}
	logger.Info("server stopped cleanly")
}

```

Also add the new field to `backend/internal/config/config.go`:

```
// add to Config struct:
DatabaseURL string

// add to Load():
DatabaseURL: getEnv("DATABASE_URL", "postgres://ab_platform:ab_platform@localhost:5432/ab_platform?sslmode=disable"),

```

Add `github.com/jackc/pgx/v5/pgxpool` usage is already covered by the Phase 2 `go.mod`; run `go mod tidy`.

### Checkpoint

```
cd backend && go run ./cmd/api

curl -s -X POST localhost:8080/v1/experiments \
  -H "Content-Type: application/json" \
  -d '{
    "key": "checkout-button-color",
    "name": "Checkout button color test",
    "variants": [
      {"key": "control", "allocationPct": 50, "isControl": true},
      {"key": "treatment", "allocationPct": 50}
    ]
  }'
# 201, echoes back the created experiment with variant IDs

curl -s localhost:8080/v1/experiments/checkout-button-color
curl -s -X POST localhost:8080/v1/experiments/checkout-button-color/start
curl -s localhost:8080/v1/experiments/checkout-button-color | grep running

```

Also re-run `curl -X POST` with the same `key` a second time and confirm you get **409 Conflict**, not a duplicate row — that's `ErrDuplicateKey` doing its job end-to-end from Postgres constraint to HTTP response.

---

## Phase 5 — The assignment endpoint: Redis-cached, sticky, low-latency

This is the endpoint every page load can hit. Goals: (1) a user's assignment is **sticky while cached**, so repeated calls return the same variant even if the experiment definition changes; (2) the hot path avoids a Postgres round-trip on every call; (3) a paused/draft experiment never gets served to real traffic. For true lifetime stickiness, persist assignments or use a cache-retention policy longer than the maximum experiment lifetime.

### Folder tree after this phase

```
ab-platform/
└── backend/
    ├── internal/
    │   ├── cache/
    │   │   └── redis.go                  # NEW
    │   ├── domain/
    │   │   └── errors.go                 # CHANGED (adds ErrExperimentNotRunning)
    │   ├── service/
    │   │   └── assignment_service.go     # NEW
    │   ├── handler/
    │   │   ├── assignment_handler.go     # NEW
    │   │   └── router.go                 # CHANGED
    │   └── config/config.go              # CHANGED (adds RedisURL)
    └── cmd/api/main.go                   # CHANGED

```

### `backend/internal/domain/errors.go` (add one line)

```
ErrExperimentNotRunning = errors.New("experiment is not running")

```

### `backend/internal/cache/redis.go`

```
package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type Cache struct {
	client *redis.Client
}

func NewCache(addr string) *Cache {
	return &Cache{client: redis.NewClient(&redis.Options{Addr: addr})}
}

func (c *Cache) Ping(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}

// GetJSON returns false (no error) on a cache miss -- callers treat a
// miss as "go compute it", not as a failure.
func (c *Cache) GetJSON(ctx context.Context, key string, dest any) (bool, error) {
	raw, err := c.client.Get(ctx, key).Bytes()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("redis get %q: %w", key, err)
	}
	if err := json.Unmarshal(raw, dest); err != nil {
		return false, fmt.Errorf("unmarshal cached value: %w", err)
	}
	return true, nil
}

func (c *Cache) SetJSON(ctx context.Context, key string, value any, ttl time.Duration) error {
	raw, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("marshal value: %w", err)
	}
	if err := c.client.Set(ctx, key, raw, ttl).Err(); err != nil {
		return fmt.Errorf("redis set %q: %w", key, err)
	}
	return nil
}

```

### `backend/internal/service/assignment_service.go`

```
package service

import (
	"context"
	"errors"
	"time"

	"github.com/emran/ab-platform/backend/internal/bucketing"
	"github.com/emran/ab-platform/backend/internal/domain"
)

// assignmentTTL is deliberately long, not infinite: a sticky assignment
// that outlives an experiment by 30 days is fine; caching every
// assignment forever would grow Redis memory unbounded across a
// platform's lifetime.
const assignmentTTL = 30 * 24 * time.Hour

// experimentDefTTL is short: a paused/completed status change should
// take effect on new assignment calls within seconds, not whenever a
// long TTL happens to expire.
const experimentDefTTL = 30 * time.Second

type AssignmentCache interface {
	GetJSON(ctx context.Context, key string, dest any) (bool, error)
	SetJSON(ctx context.Context, key string, value any, ttl time.Duration) error
}

type AssignmentService struct {
	experiments ExperimentRepository
	cache       AssignmentCache
}

func NewAssignmentService(experiments ExperimentRepository, cache AssignmentCache) *AssignmentService {
	return &AssignmentService{experiments: experiments, cache: cache}
}

func (s *AssignmentService) GetAssignment(ctx context.Context, experimentKey, userID string) (domain.Variant, error) {
	assignmentKey := "assignment:" + experimentKey + ":" + userID

	var cached domain.Variant
	if hit, err := s.cache.GetJSON(ctx, assignmentKey, &cached); err == nil && hit {
		return cached, nil
	}
	// A cache read error is logged upstream by the handler via the
	// returned error path only for the exp lookup below -- a cache
	// error here degrades to "treat as miss" so one Redis blip doesn't
	// take down assignment entirely.

	exp, err := s.getExperimentDef(ctx, experimentKey)
	if err != nil {
		return domain.Variant{}, err
	}
	if exp.Status != domain.StatusRunning {
		return domain.Variant{}, domain.ErrExperimentNotRunning
	}

	variant, ok := bucketing.Assign(exp, userID)
	if !ok {
		return domain.Variant{}, errors.New("experiment has no variants configured")
	}

	// Best-effort cache write: a failure here means the next call for
	// this user recomputes instead of reading cache -- bucketing is
	// deterministic, so recomputation yields the identical variant.
	_ = s.cache.SetJSON(ctx, assignmentKey, variant, assignmentTTL)

	return variant, nil
}

// getExperimentDef caches the experiment definition itself (short TTL)
// so a burst of first-time visitors to a popular experiment doesn't
// each individually hit Postgres.
func (s *AssignmentService) getExperimentDef(ctx context.Context, key string) (domain.Experiment, error) {
	cacheKey := "experiment-def:" + key

	var exp domain.Experiment
	if hit, err := s.cache.GetJSON(ctx, cacheKey, &exp); err == nil && hit {
		return exp, nil
	}

	exp, err := s.experiments.GetByKey(ctx, key)
	if err != nil {
		return domain.Experiment{}, err
	}
	_ = s.cache.SetJSON(ctx, cacheKey, exp, experimentDefTTL)
	return exp, nil
}

```

### `backend/internal/handler/assignment_handler.go`

```
package handler

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type AssignmentService interface {
	GetAssignment(ctx context.Context, experimentKey, userID string) (domain.Variant, error)
}

type AssignmentHandler struct {
	svc    AssignmentService
	logger *slog.Logger
}

func NewAssignmentHandler(svc AssignmentService, logger *slog.Logger) *AssignmentHandler {
	return &AssignmentHandler{svc: svc, logger: logger}
}

func (h *AssignmentHandler) Assign(w http.ResponseWriter, r *http.Request) {
	experimentKey := r.URL.Query().Get("experimentKey")
	userID := r.URL.Query().Get("userId")
	if experimentKey == "" || userID == "" {
		writeError(w, http.StatusBadRequest, "experimentKey and userId are required query params")
		return
	}

	variant, err := h.svc.GetAssignment(r.Context(), experimentKey, userID)
	if err != nil {
		switch {
		case errors.Is(err, domain.ErrNotFound):
			writeError(w, http.StatusNotFound, "experiment not found")
		case errors.Is(err, domain.ErrExperimentNotRunning):
			// 200, not an error, with a null variant: callers should
			// fall back to control/default behavior, not treat a
			// paused experiment as an application error.
			writeJSON(w, http.StatusOK, map[string]any{"variant": nil, "status": "not_running"})
		default:
			h.logger.Error("assignment failed", "error", err, "experimentKey", experimentKey)
			writeError(w, http.StatusInternalServerError, "internal server error")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"variant": variant.Key, "status": "assigned"})
}

```

### `backend/internal/handler/router.go` (changed)

```
func NewRouter(experiments *ExperimentHandler, assignments *AssignmentHandler) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", HealthHandler)

	mux.HandleFunc("POST /v1/experiments", experiments.Create)
	mux.HandleFunc("GET /v1/experiments", experiments.List)
	mux.HandleFunc("GET /v1/experiments/{key}", experiments.Get)
	mux.HandleFunc("POST /v1/experiments/{key}/start", experiments.Start)
	mux.HandleFunc("POST /v1/experiments/{key}/pause", experiments.Pause)

	mux.HandleFunc("GET /v1/assign", assignments.Assign) // NEW

	return mux
}

```

### `backend/cmd/api/main.go` (add after `expHandler := ...`)

```
redisCache := cache.NewCache(cfg.RedisAddr)
if err := redisCache.Ping(ctx); err != nil {
	logger.Error("failed to connect to redis", "error", err)
	os.Exit(1)
}

assignSvc := service.NewAssignmentService(expRepo, redisCache)
assignHandler := handler.NewAssignmentHandler(assignSvc, logger)

router := handler.NewRouter(expHandler, assignHandler) // CHANGED: now takes 2 args

```

Add the import `"github.com/emran/ab-platform/backend/internal/cache"` and add `RedisAddr string` to `config.Config`, loaded via `getEnv("REDIS_ADDR", "localhost:6379")`. Also add `github.com/redis/go-redis/v9` to `go.mod`, then run `go mod tidy`.

### Checkpoint

```
curl -s "localhost:8080/v1/assign?experimentKey=checkout-button-color&userId=user-42"
# {"status":"assigned","variant":"control"}   (or "treatment")

# call it 5 more times with the same userId -- must return the identical variant every time
for i in 1 2 3 4 5; do
  curl -s "localhost:8080/v1/assign?experimentKey=checkout-button-color&userId=user-42"
done

# confirm it's actually cached, not recomputed identically by luck:
redis-cli GET "assignment:checkout-button-color:user-42"

```

Then pause the experiment (`POST /v1/experiments/checkout-button-color/pause`) and confirm a **new** user gets `"status":"not_running"` within \~30 seconds (the `experimentDefTTL` cache expiring) — proving status changes propagate without a redeploy.

---

## Phase 6 — Event tracking: exposures and conversions, batched writes

Every exposure and conversion is an analytics write (assignment itself can remain a read-only bucketing operation). At real traffic volumes, one Postgres `INSERT` per HTTP request will fall over long before the API layer does. This phase adds an **in-memory batching writer**: events are enqueued in the handler (non-blocking) and flushed to Postgres in batches on a timer or when the buffer fills.

### Folder tree after this phase

```
ab-platform/
└── backend/
    ├── internal/
    │   ├── db/migrations/
    │   │   └── 0002_events.sql          # NEW
    │   ├── domain/
    │   │   └── event.go                 # NEW
    │   ├── repository/
    │   │   └── event_repo.go            # NEW
    │   ├── service/
    │   │   └── event_service.go         # NEW
    │   └── handler/
    │       ├── event_handler.go         # NEW
    │       └── router.go                # CHANGED
    └── cmd/api/main.go                  # CHANGED

```

### `backend/internal/db/migrations/0002_events.sql`

```
-- +migrate Up
CREATE TABLE events (
    id              BIGSERIAL PRIMARY KEY,
    experiment_key  TEXT NOT NULL,
    variant_key     TEXT NOT NULL,
    user_id         TEXT NOT NULL,
    event_type      TEXT NOT NULL CHECK (event_type IN ('exposure', 'conversion')),
    metric_name     TEXT,               -- required for conversion, null for exposure
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- results queries filter by experiment+type first, then aggregate by
-- variant -- this composite index matches that access pattern directly.
CREATE INDEX idx_events_experiment_type ON events (experiment_key, event_type, variant_key);

-- NOTE (production scale-out, not built here): once event volume
-- justifies it, convert this to a table PARTITION BY RANGE (occurred_at)
-- with monthly partitions, so old data can be dropped/archived by
-- detaching a partition instead of a slow DELETE.

-- +migrate Down
DROP TABLE events;

```

### `backend/internal/domain/event.go`

```
package domain

import "time"

type EventType string

const (
	EventExposure   EventType = "exposure"
	EventConversion EventType = "conversion"
)

type Event struct {
	ExperimentKey string
	VariantKey    string
	UserID        string
	Type          EventType
	MetricName    string // empty for exposures
	OccurredAt    time.Time
}

```

### `backend/internal/repository/event_repo.go`

```
package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type EventRepository struct {
	pool *pgxpool.Pool
}

func NewEventRepository(pool *pgxpool.Pool) *EventRepository {
	return &EventRepository{pool: pool}
}

// BatchInsert uses pgx's CopyFrom, which streams rows over the Postgres
// binary copy protocol instead of one INSERT statement per row --
// orders of magnitude faster for bulk writes.
func (r *EventRepository) BatchInsert(ctx context.Context, events []domain.Event) error {
	if len(events) == 0 {
		return nil
	}
	rows := make([][]any, len(events))
	for i, e := range events {
		rows[i] = []any{e.ExperimentKey, e.VariantKey, e.UserID, string(e.Type), nullIfEmpty(e.MetricName), e.OccurredAt}
	}

	_, err := r.pool.CopyFrom(
		ctx,
		pgx.Identifier{"events"},
		[]string{"experiment_key", "variant_key", "user_id", "event_type", "metric_name", "occurred_at"},
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		return fmt.Errorf("batch insert %d events: %w", len(events), err)
	}
	return nil
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

type VariantCounts struct {
	VariantKey  string
	Exposures   int64
	Conversions int64
}

// ResultsFor powers the stats service (Phase 8): unique exposed users and
// unique converting users per variant for one experiment + metric. Counting
// distinct users prevents duplicate event delivery from inflating conversion rates.
func (r *EventRepository) ResultsFor(ctx context.Context, experimentKey, metricName string) ([]VariantCounts, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT
			variant_key,
			COUNT(DISTINCT user_id) FILTER (WHERE event_type = 'exposure')                                  AS exposures,
			COUNT(DISTINCT user_id) FILTER (WHERE event_type = 'conversion' AND metric_name = $2)            AS conversions
		FROM events
		WHERE experiment_key = $1
		GROUP BY variant_key
	`, experimentKey, metricName)
	if err != nil {
		return nil, fmt.Errorf("query results: %w", err)
	}
	defer rows.Close()

	var out []VariantCounts
	for rows.Next() {
		var vc VariantCounts
		if err := rows.Scan(&vc.VariantKey, &vc.Exposures, &vc.Conversions); err != nil {
			return nil, fmt.Errorf("scan results row: %w", err)
		}
		out = append(out, vc)
	}
	return out, rows.Err()
}

```

### `backend/internal/service/event_service.go`

```
package service

import (
	"context"
	"log/slog"
	"time"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type EventBatchWriter interface {
	BatchInsert(ctx context.Context, events []domain.Event) error
}

const (
	bufferSize    = 10_000
	flushInterval = 2 * time.Second
	maxBatchSize  = 500
)

// EventService decouples "a request happened" from "a row was written".
// Enqueue is non-blocking (buffered channel); a background goroutine
// drains it in batches. This trades a small window of at-risk data
// (buffered events lost on a hard crash) for the ability to absorb
// traffic spikes without the assignment/event endpoints blocking on DB I/O.
type EventService struct {
	repo   EventBatchWriter
	logger *slog.Logger
	buffer chan domain.Event
	stop   chan struct{}
	done   chan struct{}
}

func NewEventService(repo EventBatchWriter, logger *slog.Logger) *EventService {
	return &EventService{
		repo:   repo,
		logger: logger,
		buffer: make(chan domain.Event, bufferSize),
		stop:   make(chan struct{}),
		done:   make(chan struct{}),
	}
}

// Enqueue never blocks on database I/O. Unlike the original version, the
// caller is told when the bounded buffer is full instead of silently losing
// an analytics event.
func (s *EventService) Enqueue(e domain.Event) bool {
	select {
	case s.buffer <- e:
		return true
	default:
		s.logger.Warn("event buffer full", "experimentKey", e.ExperimentKey)
		return false
	}
}

// Run owns the buffer and is the only goroutine that writes batches.
// Failed batches are retained for a later retry instead of being discarded.
func (s *EventService) Run(ctx context.Context) {
	defer close(s.done)

	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()

	batch := make([]domain.Event, 0, maxBatchSize)
	flush := func(flushCtx context.Context) {
		if len(batch) == 0 {
			return
		}
		if err := s.repo.BatchInsert(flushCtx, batch); err != nil {
			s.logger.Error("event batch flush failed", "error", err, "batchSize", len(batch))
			return
		}
		batch = batch[:0]
	}

	for {
		select {
		case e := <-s.buffer:
			batch = append(batch, e)
			if len(batch) >= maxBatchSize {
				flush(ctx)
			}
		case <-ticker.C:
			flush(ctx)
		case <-s.stop:
			// Drain everything already accepted into the buffer, then make
			// a bounded final attempt to persist it.
			flushCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			for {
				select {
				case e := <-s.buffer:
					batch = append(batch, e)
					if len(batch) >= maxBatchSize {
						flush(flushCtx)
					}
				default:
					flush(flushCtx)
					cancel()
					return
				}
			}
		}
	}
}

// Shutdown waits for the worker to finish draining. The caller supplies a
// deadline so shutdown cannot hang forever on an unhealthy database.
func (s *EventService) Shutdown(ctx context.Context) error {
	close(s.stop)
	select {
	case <-s.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

```

### `backend/internal/handler/event_handler.go`

```
package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type EventEnqueuer interface {
	Enqueue(e domain.Event) bool
}

type EventHandler struct {
	events EventEnqueuer
}

func NewEventHandler(events EventEnqueuer) *EventHandler {
	return &EventHandler{events: events}
}

type trackEventRequest struct {
	ExperimentKey string `json:"experimentKey"`
	VariantKey    string `json:"variantKey"`
	UserID        string `json:"userId"`
	EventType     string `json:"eventType"`  // "exposure" | "conversion"
	MetricName    string `json:"metricName"` // required if eventType == conversion
}

func (h *EventHandler) Track(w http.ResponseWriter, r *http.Request) {
	var req trackEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.ExperimentKey == "" || req.VariantKey == "" || req.UserID == "" {
		writeError(w, http.StatusBadRequest, "experimentKey, variantKey, and userId are required")
		return
	}
	if req.EventType != string(domain.EventExposure) && req.EventType != string(domain.EventConversion) {
		writeError(w, http.StatusBadRequest, "eventType must be 'exposure' or 'conversion'")
		return
	}
	if req.EventType == string(domain.EventConversion) && req.MetricName == "" {
		writeError(w, http.StatusBadRequest, "metricName is required for conversion events")
		return
	}

	accepted := h.events.Enqueue(domain.Event{
		ExperimentKey: req.ExperimentKey,
		VariantKey:    req.VariantKey,
		UserID:        req.UserID,
		Type:          domain.EventType(req.EventType),
		MetricName:    req.MetricName,
		OccurredAt:    time.Now().UTC(),
	})
	if !accepted {
		writeError(w, http.StatusServiceUnavailable, "event queue is full; retry later")
		return
	}

	// 202: accepted for asynchronous processing, not yet durably persisted.
	w.WriteHeader(http.StatusAccepted)
}

```

### `backend/internal/handler/router.go` (add one line)

```
mux.HandleFunc("POST /v1/events", events.Track) // NEW

```

(and add `events *EventHandler` to `NewRouter`'s parameters)

### `backend/cmd/api/main.go` (add, and change shutdown sequence)

```
eventRepo := repository.NewEventRepository(pool)
eventSvc := service.NewEventService(eventRepo, logger)
go eventSvc.Run(ctx)
eventHandler := handler.NewEventHandler(eventSvc)

router := handler.NewRouter(expHandler, assignHandler, eventHandler) // CHANGED: 3 args now

```

In the shutdown sequence, flush events **before** closing the DB pool (order matters — a closed pool can't accept the final flush):

```
if err := srv.Shutdown(shutdownCtx); err != nil {
	logger.Error("graceful shutdown failed", "error", err)
	os.Exit(1)
}
eventFlushCtx, cancelFlush := context.WithTimeout(context.Background(), 5*time.Second)
defer cancelFlush()
if err := eventSvc.Shutdown(eventFlushCtx); err != nil {
	logger.Error("event flush did not finish before shutdown deadline", "error", err)
	os.Exit(1)
}
logger.Info("server stopped cleanly")

```

### Checkpoint

```
curl -s -X POST localhost:8080/v1/events -H "Content-Type: application/json" -d '{
  "experimentKey": "checkout-button-color", "variantKey": "control",
  "userId": "user-42", "eventType": "exposure"
}'
# 202 Accepted

curl -s -X POST localhost:8080/v1/events -H "Content-Type: application/json" -d '{
  "experimentKey": "checkout-button-color", "variantKey": "control",
  "userId": "user-42", "eventType": "conversion", "metricName": "purchase"
}'

sleep 3   # wait past the 2s flush interval
psql "$DATABASE_URL" -c "SELECT * FROM events;"
# both rows present

```

Kill the server with Ctrl+C immediately after posting an event (before the 2s ticker fires) and confirm the row still lands in Postgres — that's the drain-on-shutdown path being exercised.

---

## Phase 7 — The client SDK

A tiny TypeScript SDK so any frontend (or another service) integrates in a few lines instead of hand-rolling `fetch` calls against `/v1/assign` and `/v1/events`. It also auto-fires the exposure event — the single most common integration bug in hand-rolled experimentation code is "we bucketed the user but forgot to log that they were exposed," which silently invalidates results.

### Folder tree after this phase

```
ab-platform/
└── sdk/
    └── js/
        ├── src/
        │   └── index.ts      # NEW
        ├── package.json      # NEW
        └── tsconfig.json     # NEW

```

### `sdk/js/package.json`

```
{
  "name": "@ab-platform/sdk",
  "version": "0.1.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc"
  },
  "devDependencies": {
    "typescript": "^5.5.0"
  }
}

```

### `sdk/js/tsconfig.json`

```
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "declaration": true,
    "outDir": "dist",
    "strict": true,
    "moduleResolution": "bundler"
  },
  "include": ["src"]
}

```

### `sdk/js/src/index.ts`

```
export interface ABPlatformConfig {
  baseUrl: string;
  userId: string;
}

export interface AssignmentResult {
  variant: string | null;
  status: "assigned" | "not_running";
}

export class ABPlatformClient {
  private readonly baseUrl: string;
  private readonly userId: string;
  // in-memory only: one exposure event per experiment per page session,
  // even if getVariant() is called multiple times for the same key.
  private readonly exposedThisSession = new Set<string>();

  constructor(config: ABPlatformConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.userId = config.userId;
  }

  async getVariant(experimentKey: string): Promise<string | null> {
    const res = await fetch(
      `${this.baseUrl}/v1/assign?experimentKey=${encodeURIComponent(experimentKey)}&userId=${encodeURIComponent(this.userId)}`
    );
    if (!res.ok) {
      // fail open: a platform outage must not break the calling
      // application's UI. Callers should treat null as "render control."
      return null;
    }

    const data: AssignmentResult = await res.json();
    if (data.status === "assigned" && data.variant && !this.exposedThisSession.has(experimentKey)) {
      this.exposedThisSession.add(experimentKey);
      void this.track(experimentKey, data.variant, "exposure");
    }
    return data.variant;
  }

  async trackConversion(experimentKey: string, variantKey: string, metricName: string): Promise<void> {
    await this.track(experimentKey, variantKey, "conversion", metricName);
  }

  private async track(
    experimentKey: string,
    variantKey: string,
    eventType: "exposure" | "conversion",
    metricName?: string
  ): Promise<void> {
    try {
      await fetch(`${this.baseUrl}/v1/events`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        // navigator.sendBeacon would be preferable for conversion events
        // fired on page unload; left as a documented follow-up rather
        // than added speculatively here.
        body: JSON.stringify({ experimentKey, variantKey, userId: this.userId, eventType, metricName }),
      });
    } catch {
      // tracking failures must never throw into the host application
    }
  }
}

```

### Checkpoint

```
cd sdk/js && npm install && npm run build

```

```
// smoke test, e.g. in a scratch .ts file or ts-node REPL
import { ABPlatformClient } from "./dist/index.js";

const client = new ABPlatformClient({ baseUrl: "http://localhost:8080", userId: "user-42" });
const variant = await client.getVariant("checkout-button-color");
console.log(variant); // "control" or "treatment"

```

Confirm in the server logs / `events` table that exactly **one** exposure row was written even if you call `getVariant("checkout-button-color")` three times in the same script run.

---

## Phase 8 — Statistical significance: two-proportion z-test

Raw counts ("treatment converted at 12.3%, control at 11.1%") are meaningless without knowing whether that gap could plausibly be noise. This phase adds a results endpoint that computes a two-proportion z-test against the designated control variant for a given conversion metric. The p-values are pairwise comparisons; if you compare many variants or many metrics, add multiple-comparison control before treating a result as confirmatory.

### Folder tree after this phase

```
ab-platform/
└── backend/
    └── internal/
        ├── service/
        │   └── stats_service.go        # NEW
        └── handler/
            ├── results_handler.go      # NEW
            └── router.go                # CHANGED

```

### `backend/internal/service/stats_service.go`

```
package service

import (
	"context"
	"fmt"
	"math"

	"github.com/emran/ab-platform/backend/internal/domain"
	"github.com/emran/ab-platform/backend/internal/repository"
)

type VariantResult struct {
	VariantKey     string  `json:"variantKey"`
	IsControl      bool    `json:"isControl"`
	Exposures      int64   `json:"exposures"`
	Conversions    int64   `json:"conversions"`
	ConversionRate float64 `json:"conversionRate"`
	UpliftVsControl *float64 `json:"upliftVsControl,omitempty"` // relative %, nil for the control row itself
	PValue          *float64 `json:"pValue,omitempty"`
	Significant     *bool    `json:"significant,omitempty"` // p < 0.05
}

type EventResultsReader interface {
	ResultsFor(ctx context.Context, experimentKey, metricName string) ([]repository.VariantCounts, error)
}

type StatsService struct {
	experiments ExperimentRepository
	events      EventResultsReader
}

func NewStatsService(experiments ExperimentRepository, events EventResultsReader) *StatsService {
	return &StatsService{experiments: experiments, events: events}
}

func (s *StatsService) Results(ctx context.Context, experimentKey, metricName string) ([]VariantResult, error) {
	exp, err := s.experiments.GetByKey(ctx, experimentKey)
	if err != nil {
		return nil, err
	}
	controlKey := ""
	for _, v := range exp.Variants {
		if v.IsControl {
			controlKey = v.Key
		}
	}
	if controlKey == "" {
		return nil, fmt.Errorf("experiment %q has no control variant configured", experimentKey)
	}

	counts, err := s.events.ResultsFor(ctx, experimentKey, metricName)
	if err != nil {
		return nil, err
	}

	byKey := map[string]repository.VariantCounts{}
	for _, c := range counts {
		byKey[c.VariantKey] = c
	}

	control := byKey[controlKey]
	controlRate := rate(control.Conversions, control.Exposures)

	var results []VariantResult
	for _, v := range exp.Variants {
		c := byKey[v.Key]
		r := VariantResult{
			VariantKey:     v.Key,
			IsControl:      v.IsControl,
			Exposures:      c.Exposures,
			Conversions:    c.Conversions,
			ConversionRate: rate(c.Conversions, c.Exposures),
		}
		if !v.IsControl {
			uplift := relativeUplift(controlRate, r.ConversionRate)
			p := twoProportionPValue(control.Conversions, control.Exposures, c.Conversions, c.Exposures)
			sig := p < 0.05
			r.UpliftVsControl = &uplift
			r.PValue = &p
			r.Significant = &sig
		}
		results = append(results, r)
	}
	return results, nil
}

func rate(conversions, exposures int64) float64 {
	if exposures == 0 {
		return 0
	}
	return float64(conversions) / float64(exposures)
}

func relativeUplift(controlRate, variantRate float64) float64 {
	if controlRate == 0 {
		return 0
	}
	return (variantRate - controlRate) / controlRate * 100
}

// twoProportionPValue runs a standard two-proportion z-test (pooled
// variance, two-tailed). Returns 1.0 (i.e. "no evidence of a
// difference") when either group has too little traffic for the
// normal approximation to be meaningful, rather than a misleadingly
// precise but statistically invalid p-value.
func twoProportionPValue(convA, nA, convB, nB int64) float64 {
	if nA < 30 || nB < 30 {
		return 1.0
	}
	pA := float64(convA) / float64(nA)
	pB := float64(convB) / float64(nB)
	pPooled := float64(convA+convB) / float64(nA+nB)

	se := math.Sqrt(pPooled * (1 - pPooled) * (1/float64(nA) + 1/float64(nB)))
	if se == 0 {
		return 1.0
	}
	z := (pB - pA) / se
	return 2 * (1 - standardNormalCDF(math.Abs(z)))
}

func standardNormalCDF(x float64) float64 {
	return 0.5 * (1 + math.Erf(x/math.Sqrt2))
}

```

### `backend/internal/handler/results_handler.go`

```
package handler

import (
	"context"
	"net/http"

	"github.com/emran/ab-platform/backend/internal/service"
)

type StatsService interface {
	Results(ctx context.Context, experimentKey, metricName string) ([]service.VariantResult, error)
}

type ResultsHandler struct {
	svc StatsService
}

func NewResultsHandler(svc StatsService) *ResultsHandler {
	return &ResultsHandler{svc: svc}
}

func (h *ResultsHandler) Get(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	metric := r.URL.Query().Get("metric")
	if metric == "" {
		writeError(w, http.StatusBadRequest, "metric query param is required")
		return
	}

	results, err := h.svc.Results(r.Context(), key, metric)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to compute results")
		return
	}
	writeJSON(w, http.StatusOK, results)
}

```

### `backend/internal/handler/router.go` (add one line, add param)

```
mux.HandleFunc("GET /v1/experiments/{key}/results", results.Get) // NEW

```

### `backend/cmd/api/main.go` (add)

```
statsSvc := service.NewStatsService(expRepo, eventRepo)
resultsHandler := handler.NewResultsHandler(statsSvc)

router := handler.NewRouter(expHandler, assignHandler, eventHandler, resultsHandler) // CHANGED: 4 args

```

### Checkpoint

Seed enough synthetic traffic to clear the `n < 30` guard, then:

```
curl -s "localhost:8080/v1/experiments/checkout-button-color/results?metric=purchase" | python3 -m json.tool

```

```
[
  {"variantKey": "control", "isControl": true, "exposures": 512, "conversions": 58, "conversionRate": 0.1133},
  {"variantKey": "treatment", "isControl": false, "exposures": 498, "conversions": 71, "conversionRate": 0.1426,
   "upliftVsControl": 25.9, "pValue": 0.14, "significant": false}
]

```

Sanity-check the math independently for one pair of numbers against a known-good online two-proportion z-test calculator before trusting this in production — statistical code is exactly the kind of thing that should never ship on "looks right to me."

---

## Phase 9 — Auth, rate limiting, and locking down the admin surface

Up to now, anyone can create or pause experiments. This phase adds JWT auth in front of the admin endpoints (experiment CRUD, results), while keeping `/v1/assign` and `/v1/events` public — those are called directly from end-user browsers via the SDK and can't carry an admin credential. Public endpoints get IP-based rate limiting instead, since they're the ones exposed to arbitrary internet traffic.

### Folder tree after this phase

```
ab-platform/
└── backend/
    └── internal/
        ├── db/migrations/
        │   └── 0003_users.sql           # NEW
        ├── domain/
        │   └── user.go                  # NEW
        ├── repository/
        │   └── user_repo.go             # NEW
        ├── service/
        │   └── auth_service.go          # NEW
        ├── handler/
        │   ├── auth_handler.go          # NEW
        │   └── router.go                # CHANGED
        ├── middleware/
        │   ├── auth.go                  # NEW
        │   ├── ratelimit.go             # NEW
        │   ├── logging.go               # NEW
        │   └── recover.go               # NEW
        └── config/config.go             # CHANGED (adds JWTSecret)

```

### `backend/internal/db/migrations/0003_users.sql`

```
-- +migrate Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +migrate Down
DROP TABLE users;

```

### `backend/internal/domain/user.go`

```
package domain

type User struct {
	ID           string
	Email        string
	PasswordHash string
}

```

### `backend/internal/repository/user_repo.go`

```
package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/emran/ab-platform/backend/internal/domain"
)

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (domain.User, error) {
	var u domain.User
	err := r.pool.QueryRow(ctx,
		`SELECT id, email, password_hash FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &u.Email, &u.PasswordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.User{}, fmt.Errorf("select user: %w", err)
	}
	return u, nil
}

```

### `backend/internal/service/auth_service.go`

```
package service

import (
	"context"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/emran/ab-platform/backend/internal/domain"
)

var ErrInvalidCredentials = errors.New("invalid email or password")

type UserGetter interface {
	GetByEmail(ctx context.Context, email string) (domain.User, error)
}

type AuthService struct {
	users     UserGetter
	jwtSecret []byte
}

func NewAuthService(users UserGetter, jwtSecret string) *AuthService {
	return &AuthService{users: users, jwtSecret: []byte(jwtSecret)}
}

func (s *AuthService) Login(ctx context.Context, email, password string) (string, error) {
	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			// same error for "no such user" and "wrong password" --
			// distinguishing them lets an attacker enumerate valid emails.
			return "", ErrInvalidCredentials
		}
		return "", err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return "", ErrInvalidCredentials
	}

	claims := jwt.RegisteredClaims{
		Subject:   user.ID,
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}

func (s *AuthService) ValidateToken(tokenStr string) (userID string, err error) {
	claims := &jwt.RegisteredClaims{}
	token, err := jwt.ParseWithClaims(
		tokenStr,
		claims,
		func(t *jwt.Token) (any, error) {
			return s.jwtSecret, nil
		},
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
	)
	if err != nil || !token.Valid {
		return "", errors.New("invalid or expired token")
	}
	return claims.Subject, nil
}

```

### `backend/internal/handler/auth_handler.go`

```
package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/emran/ab-platform/backend/internal/service"
)

type AuthService interface {
	Login(ctx context.Context, email, password string) (string, error)
}

type AuthHandler struct {
	svc AuthService
}

func NewAuthHandler(svc AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	token, err := h.svc.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCredentials) {
			writeError(w, http.StatusUnauthorized, "invalid email or password")
			return
		}
		writeError(w, http.StatusInternalServerError, "internal server error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"token": token})
}

```

### `backend/internal/middleware/auth.go`

```
package middleware

import (
	"context"
	"net/http"
	"strings"
)

type TokenValidator interface {
	ValidateToken(token string) (userID string, err error)
}

type contextKey string

const userIDContextKey contextKey = "userID"

// RequireAuth wraps a handler so it 401s before any business logic runs
// if the bearer token is missing or invalid. The validated userID is
// injected into the request context for handlers that need it (e.g. audit logging).
func RequireAuth(validator TokenValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			token, ok := strings.CutPrefix(authHeader, "Bearer ")
			if !ok || token == "" {
				http.Error(w, `{"error":"missing or malformed Authorization header"}`, http.StatusUnauthorized)
				return
			}

			userID, err := validator.ValidateToken(token)
			if err != nil {
				http.Error(w, `{"error":"invalid or expired token"}`, http.StatusUnauthorized)
				return
			}

			ctx := context.WithValue(r.Context(), userIDContextKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

```

### `backend/internal/middleware/ratelimit.go`

```
package middleware

import (
	"net"
	"net/http"
	"sync"
	"time"
)

// bucket is a simple token bucket: refills at `rate` tokens/sec up to
// `capacity`, decremented once per request.
type bucket struct {
	tokens    float64
	capacity  float64
	rate      float64
	updatedAt time.Time
}

// IPRateLimiter is process-local -- fine for a single instance. Once
// this service runs behind a load balancer with multiple replicas,
// swap the in-memory map for a Redis-backed limiter (e.g. INCR +
// EXPIRE per window) so limits are enforced across all instances,
// not per-instance.
type IPRateLimiter struct {
	mu       sync.Mutex
	buckets  map[string]*bucket
	rate     float64
	capacity float64
}

func NewIPRateLimiter(requestsPerSecond, burst float64) *IPRateLimiter {
	return &IPRateLimiter{
		buckets:  make(map[string]*bucket),
		rate:     requestsPerSecond,
		capacity: burst,
	}
}

func (l *IPRateLimiter) allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	b, exists := l.buckets[ip]
	if !exists {
		b = &bucket{tokens: l.capacity, capacity: l.capacity, rate: l.rate, updatedAt: time.Now()}
		l.buckets[ip] = b
	}

	elapsed := time.Since(b.updatedAt).Seconds()
	b.tokens = min(b.capacity, b.tokens+elapsed*b.rate)
	b.updatedAt = time.Now()

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

func (l *IPRateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			ip = r.RemoteAddr
		}
		if !l.allow(ip) {
			http.Error(w, `{"error":"rate limit exceeded"}`, http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

```

### `backend/internal/middleware/logging.go`

```
package middleware

import (
	"log/slog"
	"net/http"
	"time"
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

// Logging records one structured line per request -- method, path,
// status, and latency -- which is the minimum needed to debug
// production traffic without reaching for a debugger.
func Logging(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rec, r)
			logger.Info("request",
				"method", r.Method, "path", r.URL.Path,
				"status", rec.status, "duration_ms", time.Since(start).Milliseconds(),
			)
		})
	}
}

```

### `backend/internal/middleware/recover.go`

```
package middleware

import (
	"log/slog"
	"net/http"
)

// Recover converts a panic anywhere downstream into a 500 instead of
// crashing the whole process and dropping every other in-flight request.
func Recover(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					logger.Error("panic recovered", "error", rec, "path", r.URL.Path)
					http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

```

### `backend/internal/handler/router.go` (final version for this phase)

```
package handler

import "net/http"

type Middleware func(http.Handler) http.Handler

func NewRouter(
	experiments *ExperimentHandler,
	assignments *AssignmentHandler,
	events *EventHandler,
	results *ResultsHandler,
	auth *AuthHandler,
	requireAuth Middleware,
	publicRateLimit Middleware,
) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", HealthHandler)
	mux.HandleFunc("POST /v1/auth/login", auth.Login)

	// Public, called directly from end-user browsers via the SDK --
	// rate-limited per-IP instead of authenticated.
	mux.Handle("GET /v1/assign", publicRateLimit(http.HandlerFunc(assignments.Assign)))
	mux.Handle("POST /v1/events", publicRateLimit(http.HandlerFunc(events.Track)))

	// Admin surface -- requires a valid JWT.
	mux.Handle("POST /v1/experiments", requireAuth(http.HandlerFunc(experiments.Create)))
	mux.Handle("GET /v1/experiments", requireAuth(http.HandlerFunc(experiments.List)))
	mux.Handle("GET /v1/experiments/{key}", requireAuth(http.HandlerFunc(experiments.Get)))
	mux.Handle("POST /v1/experiments/{key}/start", requireAuth(http.HandlerFunc(experiments.Start)))
	mux.Handle("POST /v1/experiments/{key}/pause", requireAuth(http.HandlerFunc(experiments.Pause)))
	mux.Handle("POST /v1/experiments/{key}/complete", requireAuth(http.HandlerFunc(experiments.Complete)))
	mux.Handle("GET /v1/experiments/{key}/results", requireAuth(http.HandlerFunc(results.Get)))

	return mux
}

```

### `backend/cmd/api/main.go` (final wiring changes for this phase)

```
userRepo := repository.NewUserRepository(pool)
authSvc := service.NewAuthService(userRepo, cfg.JWTSecret)
authHandler := handler.NewAuthHandler(authSvc)

requireAuth := middleware.RequireAuth(authSvc)
publicLimiter := middleware.NewIPRateLimiter(5, 20) // 5 req/s sustained, burst of 20

router := handler.NewRouter(
	expHandler, assignHandler, eventHandler, resultsHandler,
	authHandler, requireAuth, publicLimiter.Middleware,
)

// wrap the whole mux, not individual routes, so every request --
// including 404s -- gets logged and panic-recovered.
var finalHandler http.Handler = router
finalHandler = middleware.Recover(logger)(finalHandler)
finalHandler = middleware.Logging(logger)(finalHandler)

srv := &http.Server{
	Addr:    ":" + cfg.Port,
	Handler: finalHandler, // CHANGED: was `router`
	// ... ReadTimeout / WriteTimeout / IdleTimeout unchanged
}

```

Add to `go.mod`: `github.com/golang-jwt/jwt/v5` and `golang.org/x/crypto` (for bcrypt). Add `JWTSecret string` to `Config`, loaded via `getEnv("JWT_SECRET", "")` — and make `config.Load()` **fail** if the secret is empty or shorter than 32 bytes in production. The JWT parser must also restrict the accepted signing algorithm to HS256, as shown above.

### Checkpoint

```
# seed one local-only admin using Postgres' bcrypt implementation.
# Do not use this password outside local development.
psql "$DATABASE_URL" -c "INSERT INTO users (email, password_hash) VALUES ('you@example.com', crypt('correcthorsebatterystaple', gen_salt('bf')));"

curl -s -X POST localhost:8080/v1/auth/login -d '{"email":"you@example.com","password":"correcthorsebatterystaple"}'
# {"token": "eyJ..."}

TOKEN="eyJ..."
curl -s localhost:8080/v1/experiments -H "Authorization: Bearer $TOKEN"   # 200
curl -s localhost:8080/v1/experiments                                     # 401, no token

# hammer the public endpoint past its burst of 20 and confirm 429s appear
for i in $(seq 1 30); do curl -s -o /dev/null -w "%{http_code}\n" "localhost:8080/v1/assign?experimentKey=checkout-button-color&userId=user-$i"; done

```

---

## Phase 10 — React dashboard

A minimal but real admin UI: login, list experiments, create an experiment with a variant allocation editor that enforces the 100% rule client-side too, and a detail page showing live results with a chart.

### Folder tree after this phase

```
ab-platform/
└── frontend/
    ├── src/
    │   ├── api/
    │   │   └── client.ts                    # NEW
    │   ├── auth/
    │   │   └── AuthContext.tsx               # NEW
    │   ├── pages/
    │   │   ├── Login.tsx                     # NEW
    │   │   ├── ExperimentList.tsx             # NEW
    │   │   ├── ExperimentCreate.tsx           # NEW
    │   │   └── ExperimentDetail.tsx           # NEW
    │   ├── components/
    │   │   ├── VariantAllocationEditor.tsx    # NEW
    │   │   └── ResultsChart.tsx               # NEW
    │   ├── App.tsx                            # NEW
    │   └── main.tsx                           # NEW
    ├── index.html                             # NEW
    ├── package.json                           # NEW
    ├── tsconfig.json                          # NEW
    └── vite.config.ts                         # NEW

```

### `frontend/package.json`

```
{
  "name": "ab-platform-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.26.0",
    "recharts": "^2.12.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.5.0",
    "vite": "^5.4.0"
  }
}

```

### `frontend/vite.config.ts`

```
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    // proxy avoids CORS entirely in dev; production serves frontend and
    // backend from the same origin behind a reverse proxy (see Phase 11).
    proxy: { "/v1": "http://localhost:8080" },
  },
});

```

### `frontend/index.html`

```
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>A/B Platform</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>

```

### `frontend/src/api/client.ts`

```
const BASE_URL = "/v1";

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

// Every call reads the token fresh from AuthContext's storage rather
// than being constructed once with a stale token baked in.
//
// Demo note: localStorage is convenient for this tutorial but exposes bearer
// tokens to JavaScript running in the page. For a real admin dashboard,
// prefer a Secure, HttpOnly, SameSite cookie plus CSRF protection.
async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem("ab_platform_token");
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({ error: res.statusText }));
    throw new ApiError(res.status, body.error ?? "request failed");
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export interface Variant {
  key: string;
  allocationPct: number;
  isControl: boolean;
}

export interface Experiment {
  id: string;
  key: string;
  name: string;
  status: "draft" | "running" | "paused" | "completed";
  variants: Variant[];
}

export interface VariantResult {
  variantKey: string;
  isControl: boolean;
  exposures: number;
  conversions: number;
  conversionRate: number;
  upliftVsControl?: number;
  pValue?: number;
  significant?: boolean;
}

export const api = {
  login: (email: string, password: string) =>
    request<{ token: string }>("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) }),
  listExperiments: () => request<Experiment[]>("/experiments"),
  getExperiment: (key: string) => request<Experiment>(`/experiments/${key}`),
  createExperiment: (payload: { key: string; name: string; variants: Variant[] }) =>
    request<Experiment>("/experiments", { method: "POST", body: JSON.stringify(payload) }),
  startExperiment: (key: string) => request<void>(`/experiments/${key}/start`, { method: "POST" }),
  pauseExperiment: (key: string) => request<void>(`/experiments/${key}/pause`, { method: "POST" }),
  completeExperiment: (key: string) => request<void>(`/experiments/${key}/complete`, { method: "POST" }),
  getResults: (key: string, metric: string) =>
    request<VariantResult[]>(`/experiments/${key}/results?metric=${encodeURIComponent(metric)}`),
};

export { ApiError };

```

### `frontend/src/auth/AuthContext.tsx`

```
import { createContext, useContext, useState, type ReactNode } from "react";
import { api } from "../api/client";

interface AuthState {
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(!!localStorage.getItem("ab_platform_token"));

  async function login(email: string, password: string) {
    const { token } = await api.login(email, password);
    localStorage.setItem("ab_platform_token", token);
    setIsAuthenticated(true);
  }

  function logout() {
    localStorage.removeItem("ab_platform_token");
    setIsAuthenticated(false);
  }

  return <AuthContext.Provider value={{ isAuthenticated, login, logout }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

```

### `frontend/src/components/VariantAllocationEditor.tsx`

```
import type { Variant } from "../api/client";

interface Props {
  variants: Variant[];
  onChange: (variants: Variant[]) => void;
}

// Mirrors the backend's Experiment.Validate() rules client-side: exactly
// one control, allocations summing to 100. This doesn't replace server
// validation -- it just avoids a round-trip for the common typo.
export function VariantAllocationEditor({ variants, onChange }: Props) {
  const total = variants.reduce((sum, v) => sum + v.allocationPct, 0);

  function update(index: number, patch: Partial<Variant>) {
    const next = variants.map((v, i) => (i === index ? { ...v, ...patch } : v));
    onChange(next);
  }

  function addVariant() {
    onChange([...variants, { key: "", allocationPct: 0, isControl: false }]);
  }

  function setControl(index: number) {
    onChange(variants.map((v, i) => ({ ...v, isControl: i === index })));
  }

  return (
    <div>
      {variants.map((v, i) => (
        <div key={i} style={{ display: "flex", gap: 8, marginBottom: 8 }}>
          <input placeholder="variant key" value={v.key} onChange={(e) => update(i, { key: e.target.value })} />
          <input
            type="number"
            value={v.allocationPct}
            onChange={(e) => update(i, { allocationPct: Number(e.target.value) })}
          />
          <label>
            <input type="radio" checked={v.isControl} onChange={() => setControl(i)} /> control
          </label>
        </div>
      ))}
      <button type="button" onClick={addVariant}>
        + add variant
      </button>
      <p style={{ color: Math.abs(total - 100) < 0.01 ? "green" : "red" }}>Total allocation: {total}%</p>
    </div>
  );
}

```

### `frontend/src/components/ResultsChart.tsx`

```
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { VariantResult } from "../api/client";

export function ResultsChart({ results }: { results: VariantResult[] }) {
  const data = results.map((r) => ({
    name: r.variantKey,
    "conversion rate %": +(r.conversionRate * 100).toFixed(2),
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" />
        <YAxis />
        <Tooltip />
        <Legend />
        <Bar dataKey="conversion rate %" fill="#4f46e5" />
      </BarChart>
    </ResponsiveContainer>
  );
}

```

### `frontend/src/pages/Login.tsx`

```
import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const { login } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await login(email, password);
      navigate("/experiments");
    } catch {
      setError("Invalid email or password");
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <h1>Sign in</h1>
      <input placeholder="email" value={email} onChange={(e) => setEmail(e.target.value)} />
      <input type="password" placeholder="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button type="submit">Sign in</button>
      {error && <p style={{ color: "red" }}>{error}</p>}
    </form>
  );
}

```

### `frontend/src/pages/ExperimentList.tsx`

```
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, type Experiment } from "../api/client";

export function ExperimentList() {
  const [experiments, setExperiments] = useState<Experiment[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.listExperiments().then(setExperiments).catch(() => setError("failed to load experiments"));
  }, []);

  if (error) return <p style={{ color: "red" }}>{error}</p>;
  if (!experiments) return <p>Loading…</p>;

  return (
    <div>
      <h1>Experiments</h1>
      <Link to="/experiments/new">+ new experiment</Link>
      <ul>
        {experiments.map((e) => (
          <li key={e.id}>
            <Link to={`/experiments/${e.key}`}>{e.name}</Link> — {e.status}
          </li>
        ))}
      </ul>
    </div>
  );
}

```

### `frontend/src/pages/ExperimentCreate.tsx`

```
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, type Variant, ApiError } from "../api/client";
import { VariantAllocationEditor } from "../components/VariantAllocationEditor";

export function ExperimentCreate() {
  const [key, setKey] = useState("");
  const [name, setName] = useState("");
  const [variants, setVariants] = useState<Variant[]>([
    { key: "control", allocationPct: 50, isControl: true },
    { key: "treatment", allocationPct: 50, isControl: false },
  ]);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  async function handleSubmit() {
    setError(null);
    try {
      const created = await api.createExperiment({ key, name, variants });
      navigate(`/experiments/${created.key}`);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to create experiment");
    }
  }

  return (
    <div>
      <h1>New experiment</h1>
      <input placeholder="key (e.g. checkout-button-color)" value={key} onChange={(e) => setKey(e.target.value)} />
      <input placeholder="name" value={name} onChange={(e) => setName(e.target.value)} />
      <VariantAllocationEditor variants={variants} onChange={setVariants} />
      <button onClick={handleSubmit}>Create</button>
      {error && <p style={{ color: "red" }}>{error}</p>}
    </div>
  );
}

```

### `frontend/src/pages/ExperimentDetail.tsx`

```
import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api, type Experiment, type VariantResult } from "../api/client";
import { ResultsChart } from "../components/ResultsChart";

export function ExperimentDetail() {
  const { key } = useParams<{ key: string }>();
  const [experiment, setExperiment] = useState<Experiment | null>(null);
  const [results, setResults] = useState<VariantResult[] | null>(null);
  const [metric, setMetric] = useState("purchase");

  useEffect(() => {
    if (!key) return;
    api.getExperiment(key).then(setExperiment);
  }, [key]);

  useEffect(() => {
    if (!key || !metric) return;
    api.getResults(key, metric).then(setResults).catch(() => setResults(null));
  }, [key, metric]);

  if (!experiment) return <p>Loading…</p>;

  return (
    <div>
      <h1>{experiment.name}</h1>
      <p>Status: {experiment.status}</p>
      {experiment.status === "draft" && <button onClick={() => key && api.startExperiment(key)}>Start</button>}
      {experiment.status === "running" && <button onClick={() => key && api.pauseExperiment(key)}>Pause</button>}

      <h2>Results</h2>
      <input value={metric} onChange={(e) => setMetric(e.target.value)} placeholder="metric name" />
      {results && (
        <>
          <ResultsChart results={results} />
          <table>
            <thead>
              <tr>
                <th>Variant</th><th>Exposures</th><th>Conversions</th><th>Rate</th><th>Uplift</th><th>p-value</th>
              </tr>
            </thead>
            <tbody>
              {results.map((r) => (
                <tr key={r.variantKey}>
                  <td>{r.variantKey}{r.isControl ? " (control)" : ""}</td>
                  <td>{r.exposures}</td>
                  <td>{r.conversions}</td>
                  <td>{(r.conversionRate * 100).toFixed(2)}%</td>
                  <td>{r.upliftVsControl?.toFixed(2) ?? "—"}%</td>
                  <td style={{ fontWeight: r.significant ? "bold" : "normal" }}>{r.pValue?.toFixed(4) ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}

```

### `frontend/src/App.tsx`

```
import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth/AuthContext";
import { Login } from "./pages/Login";
import { ExperimentList } from "./pages/ExperimentList";
import { ExperimentCreate } from "./pages/ExperimentCreate";
import { ExperimentDetail } from "./pages/ExperimentDetail";

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/experiments" element={<ProtectedRoute><ExperimentList /></ProtectedRoute>} />
        <Route path="/experiments/new" element={<ProtectedRoute><ExperimentCreate /></ProtectedRoute>} />
        <Route path="/experiments/:key" element={<ProtectedRoute><ExperimentDetail /></ProtectedRoute>} />
        <Route path="*" element={<Navigate to="/experiments" replace />} />
      </Routes>
    </AuthProvider>
  );
}

```

### `frontend/src/main.tsx`

```
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>
);

```

### Checkpoint

```
cd frontend && npm install && npm run dev

```

Open `http://localhost:5173`, log in with the user seeded in Phase 9, create an experiment, hit `/v1/assign` a few times via curl with different `userId`s to generate traffic, post a few conversion events, then reload the experiment detail page and confirm the chart and table update.

---

## Phase 11 — Dockerize and ship: multi-stage builds, compose, CI

Goal: a single `docker compose up` brings up Postgres, Redis, the Go API, and the built frontend, plus a GitHub Actions pipeline that runs migrations, tests, and builds images on every push.

### Folder tree after this phase

```
ab-platform/
├── backend/
│   └── Dockerfile                    # NEW
├── frontend/
│   └── Dockerfile                    # NEW
├── infra/
│   ├── docker-compose.yml            # CHANGED (adds api + web services)
│   └── nginx.conf                    # NEW
└── .github/
    └── workflows/
        └── ci.yml                    # NEW

```

### `backend/Dockerfile`

```
# --- build stage ---
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# CGO disabled + static binary -> the runtime stage can be `scratch`-adjacent
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/api ./cmd/api

# --- runtime stage ---
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /out/api /usr/local/bin/api
# runs as non-root: a compromised process shouldn't get root inside the container
RUN adduser -D -H apprunner
USER apprunner
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api"]

```

### `frontend/Dockerfile`

```
# --- build stage ---
FROM node:20-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- runtime stage: static files served by nginx, not node ---
FROM nginx:1.27-alpine
COPY --from=build /src/dist /usr/share/nginx/html
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

```

### `infra/nginx.conf`

```
server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;  # client-side routing: unknown paths fall back to the SPA
    }

    location /v1/ {
        proxy_pass http://api:8080/v1/;
        proxy_set_header Host $host;
    }
}

```

### `infra/docker-compose.yml` (full version)

```
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ab_platform
      POSTGRES_PASSWORD: ab_platform
      POSTGRES_DB: ab_platform
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ab_platform"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  migrate:
    image: migrate/migrate:v4.17.1
    volumes:
      - ../backend/internal/db/migrations:/migrations:ro
    command:
      - -path=/migrations
      - -database=postgres://ab_platform:ab_platform@postgres:5432/ab_platform?sslmode=disable
      - up
    depends_on:
      postgres:
        condition: service_healthy

  api:
    build: { context: ../backend, dockerfile: Dockerfile }
    environment:
      APP_ENV: production
      PORT: "8080"
      DATABASE_URL: postgres://ab_platform:ab_platform@postgres:5432/ab_platform?sslmode=disable
      REDIS_ADDR: redis:6379
      JWT_SECRET: ${JWT_SECRET:?JWT_SECRET must be set}
    ports: ["8080:8080"]
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
      migrate: { condition: service_completed_successfully }

  web:
    build: { context: ../frontend, dockerfile: Dockerfile }
    ports: ["8081:80"]
    depends_on: [api]

volumes:
  pgdata:

```

### `.github/workflows/ci.yml`

```
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  backend:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: ab_platform
          POSTGRES_PASSWORD: ab_platform
          POSTGRES_DB: ab_platform
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U ab_platform"
          --health-interval 5s --health-timeout 3s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: "1.23" }

      - name: Run migrations
        run: |
          go run -tags postgres github.com/golang-migrate/migrate/v4/cmd/migrate@v4.17.1 \
            -path=backend/internal/db/migrations \
            -database="postgres://ab_platform:ab_platform@localhost:5432/ab_platform?sslmode=disable" \
            up

      - name: Test
        working-directory: backend
        run: go test ./... -race -cover

      - name: Build
        working-directory: backend
        run: go build ./...

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20" }
      - working-directory: frontend
        run: npm ci && npm run build

  docker-images:
    needs: [backend, frontend]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Build backend image
        run: docker build -t ab-platform-api:${{ github.sha }} backend
      - name: Build frontend image
        run: docker build -t ab-platform-web:${{ github.sha }} frontend
      # push step intentionally omitted -- wire in your registry
      # (ECR/GHCR/GCR) credentials as repo secrets before enabling push

```

### Checkpoint

```
JWT_SECRET=$(openssl rand -hex 32) docker compose -f infra/docker-compose.yml up --build

```

- `curl localhost:8080/healthz` → `{"status":"ok"}`
- Open `localhost:8081` → dashboard loads and its API calls (proxied through nginx to `api:8080`) succeed
- Push a branch and confirm the GitHub Actions `backend` and `frontend` jobs go green — migrations, tests, and both builds run against a real Postgres service container, not a mock

---

## Phase 12 — Production readiness checklist & deliberate scope cuts

> This is a production-minded learning project, not a claim that the resulting system is safe for arbitrary production traffic. Phase 12 lists the remaining work required before that claim would be justified.

### What this build already has

- [x] Deterministic, stateless bucketing with test-verified distribution
- [x] Sticky assignment via Redis, decoupled from the hot path hitting Postgres
- [x] Transactional writes for experiment+variants (no half-written state)
- [x] Batched, non-blocking event ingestion with graceful-shutdown flush
- [x] Two-proportion z-test with a minimum-sample guard against bogus p-values
- [x] JWT auth on the admin surface, per-IP rate limiting on the public surface
- [x] Structured logs, panic recovery, graceful HTTP shutdown, DB connection pooling
- [x] Versioned SQL migrations (reversible, reviewable)
- [x] Non-root Docker images, multi-stage builds, CI with a real Postgres service container

### What you should add before this touches real production traffic

1. **Observability beyond logs** — Prometheus metrics (`/metrics` via `promhttp`) for request latency histograms, assignment cache hit rate, event buffer depth (the `dropped event` warning in `event_service.go` needs a counter, not just a log line — that's the signal your batching layer is falling behind). Wire an alert on buffer-drop-rate > 0.
2. **Distributed rate limiting** — swap `IPRateLimiter`'s in-memory map for Redis-backed counters the moment you run more than one API replica; the current version only rate-limits per-instance.
3. **Event durability** — the batching writer trades some durability for throughput (buffered events are lost on a hard crash/OOM kill). If that's not acceptable for your conversion metric, add a write-ahead log (even a local file synced periodically) or switch to a proper queue (SQS/Kafka) between the handler and the batch writer.
4. **Multi-tenancy** — every table currently assumes one organization. Adding `tenant_id` to `experiments`, `events`, and `users`, plus scoping every query and the JWT claims by tenant, is a schema migration + a systematic handler audit, best done as its own project rather than bolted on later.
5. **Experiment partition strategy** — the note left in `0002_events.sql` about `PARTITION BY RANGE (occurred_at)`: do this before the `events` table crosses tens of millions of rows, not after query latency alerts fire.
6. **Refresh tokens** — the current JWT is a 24h bearer token with no revocation path. For an admin dashboard this is a reasonable tradeoff; add short-lived access tokens + refresh tokens before exposing this to more than a small trusted team.
7. **SRM (Sample Ratio Mismatch) monitoring** — a chi-squared test comparing actual traffic split per variant against configured `allocationPct`; catches bucketing bugs and bot traffic skew before they silently invalidate a result. This is the single highest-leverage addition once the core loop above is stable.
8. **Identity and event idempotency** — the SDK example is intentionally small, but production ingestion should accept a client-generated event ID and enforce idempotency so retries do not create duplicate exposure/conversion records. The results query already uses distinct users, but idempotency still matters for storage volume, auditability, and exact event semantics.
9. **Admin token storage** — replace the dashboard's localStorage JWT with a Secure, HttpOnly, SameSite cookie and CSRF protection before exposing the admin UI to untrusted networks.

### Recommended build order if you're doing this yourself

Phases 0–4 (bucketing + CRUD) are the load-bearing core — get those genuinely solid, with the distribution test passing and the transaction behavior verified, before moving on. Phases 5–8 (caching, events, stats) are where an experimentation platform either becomes trustworthy or becomes a liability; don't skip the checkpoints. Phases 9–11 (auth, dashboard, deploy) are important but comparatively mechanical once the core is right.