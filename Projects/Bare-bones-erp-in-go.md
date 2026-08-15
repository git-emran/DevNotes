# Building a Bare-Bones ERP in Go — From Hello World to Working Product

**Stack:** Go (stdlib net/http + chi) · PostgreSQL · golang-migrate · database/sql + repository pattern · log/slog · JWT + bcrypt · Docker Compose · table-driven tests · **Angular (standalone components, Angular CLI)**

**Why this stack:** no ORM magic, no framework magic on the backend. Every SQL query, every route, every auth check is code you wrote and can debug. This is what most production Go backends actually look like — boring on purpose. The frontend is a real SPA (Angular) so you get proper client-side routing, forms, and HTTP interceptors for JWT, while the Go API stays pure JSON.

**How to use this guide:** work through sections in order. Every section ends with **Run & Verify** (a command you run and an output you should see) and **Tips to Remember** (things that will bite you later if you skip them). Don't skip the Run & Verify steps — ERPs are exactly the kind of software where a silent bug (wrong stock count, double-booked invoice) is worse than a crash.

---

## Section 0 — Project Setup & Domain Sketch

Before code: what is a "bare-bones ERP"? We're building the smallest set of modules that still deserves the name:

- **Auth** — users, orgs (multi-tenant from day one — this is the #1 thing people bolt on too late), login, JWT
- **Products/Inventory** — items, stock levels, stock movements (append-only ledger, not just a mutable counter)
- **Customers & Suppliers** — parties you transact with
- **Sales Orders → Invoices** — the money-in flow
- **Purchase Orders** — the money-out flow (mirrors sales, built faster)
- **A minimal dashboard UI** — Angular SPA (standalone components, no NgModules), served as static assets by the Go server

We will **NOT** build: full double-entry accounting, tax engines, multi-currency, or a plugin system. Those are honest 10x-scope-up features — the guide flags where you'd hook them in.

```bash
mkdir erp-go && cd erp-go
go mod init github.com/<you>/erp-go
git init
```

Create the skeleton now, even though most of it is empty — production Go projects settle into this shape and it's easier to grow into it than restructure later:

```
erp-go/
├── cmd/
│   └── api/                 # main.go — the only place with func main()
├── internal/
│   ├── config/              # env/config loading
│   ├── db/                  # connection pool, migrations runner
│   ├── httpserver/          # router, middleware, server lifecycle, static file serving
│   ├── auth/                # users, sessions, JWT
│   ├── product/             # products + inventory
│   ├── party/               # customers/suppliers
│   ├── sales/               # sales orders + invoices
│   └── purchasing/          # purchase orders
├── migrations/              # .sql files, ordered
├── frontend/                # Angular app (created with Angular CLI)
├── docker-compose.yml
├── Dockerfile
├── .env.example
└── go.mod
```

**Why internal/:** Go enforces that packages under `internal/` can't be imported by other modules. For an app (not a library) this doesn't matter much practically, but it signals intent clearly and it's the community convention — anyone opening this repo instantly knows where the app logic lives vs. the entrypoint.

### Tips to Remember

- Module path should match where you'll actually host it (`github.com/you/erp-go`) — changing it later means rewriting every import.
- Multi-tenancy (an `org_id` on almost every table) is dramatically cheaper to add on day one than to retrofit. We're adding it in Section 4 even though you're the only "org" for now.
- Resist the urge to add a backend framework (Gin, Echo, Fiber) — chi is a thin router, not a framework, and you'll actually see how middleware composition works.
- Keep the Angular app in its own `frontend/` directory so the Go build and Angular build stay cleanly separated until the final Docker multi-stage stage.

---

## Section 1 — Hello World HTTP Server

`cmd/api/main.go`:

```go
package main

import (
	"log/slog"
	"net/http"
	"os"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	logger.Info("starting server", "addr", ":8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		logger.Error("server failed", "error", err)
		os.Exit(1)
	}
}
```

Note we're using Go's net/http pattern-based routing (`"GET /healthz"`) — this has been in the stdlib since Go 1.22, no third-party router needed for something this simple. We'll swap to chi in Section 3 once we need middleware chains and route groups, not because stdlib can't route.

Also note: `slog.NewJSONHandler` from the very first line. Production services log structured JSON, not `fmt.Println` — this costs you nothing today and saves you from a painful mid-project migration later when you need to grep logs by field.

### Run & Verify

```bash
go run ./cmd/api
# in another terminal:
curl -i localhost:8080/healthz
# expect: HTTP/1.1 200 OK, body "ok"
```

### Tips to Remember

- `log/slog` is stdlib (Go 1.21+) — no dependency needed for structured logging. Use it from line one; retrofitting logging is always worse than starting with it.
- A `/healthz` endpoint isn't decoration — it's what load balancers, Docker healthchecks, and Kubernetes liveness probes call. You'll wire it into Docker in Section 12.
- `http.ListenAndServe` returning means the server died. Always check that error — a silently-dead server is a classic "why is prod down" 2am page.

---

## Section 2 — Configuration Management

Hardcoded `:8080` doesn't survive contact with Docker, staging, or a teammate's machine. `internal/config/config.go`:

```go
package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	HTTPPort    int
	DatabaseURL string
	JWTSecret   string
	Env         string // "dev", "staging", "prod"
}

func Load() (*Config, error) {
	port, err := strconv.Atoi(getenv("HTTP_PORT", "8080"))
	if err != nil {
		return nil, fmt.Errorf("invalid HTTP_PORT: %w", err)
	}

	cfg := &Config{
		HTTPPort:    port,
		DatabaseURL: getenv("DATABASE_URL", ""),
		JWTSecret:   getenv("JWT_SECRET", ""),
		Env:         getenv("APP_ENV", "dev"),
	}

	if cfg.Env == "prod" {
		if cfg.DatabaseURL == "" {
			return nil, fmt.Errorf("DATABASE_URL is required in prod")
		}
		if len(cfg.JWTSecret) < 32 {
			return nil, fmt.Errorf("JWT_SECRET must be at least 32 chars in prod")
		}
	}

	return cfg, nil
}

func getenv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}
```

`.env.example` (commit this, never commit `.env` itself):

```
HTTP_PORT=8080
DATABASE_URL=postgres://erp:erp@localhost:5432/erp?sslmode=disable
JWT_SECRET=change-me-to-something-long-and-random
APP_ENV=dev
```

Update `main.go` to call `config.Load()` and use `cfg.HTTPPort`. Add `github.com/joho/godotenv` if you want `.env` autoloading in dev (`godotenv.Load()` at the top of main, ignore the error if the file doesn't exist — prod won't have one, it'll get real env vars).

### Run & Verify

```bash
cp .env.example .env
go run ./cmd/api
# still works — now change HTTP_PORT in .env to 9090, restart, curl localhost:9090/healthz
```

### Tips to Remember

- Fail loudly at startup on bad config (as above), never at request-time. A missing `JWT_SECRET` should crash the process on boot, not silently issue unsigned tokens three weeks later.
- `.gitignore` your `.env` immediately. This is the single most common way secrets end up in git history.
- Different validation per environment (strict in prod, lenient in dev) is a normal, good pattern — don't force dev to have the same ceremony as prod.

---

## Section 3 — PostgreSQL, Docker Compose, and Migrations

`docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: erp
      POSTGRES_PASSWORD: erp
      POSTGRES_DB: erp
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U erp"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
docker compose up -d postgres
```

Install golang-migrate (CLI, not a library — keeps migration tooling decoupled from your app binary):

```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

Create your first migration:

```bash
migrate create -ext sql -dir migrations -seq create_orgs_and_users
```

This gives you `migrations/000001_create_orgs_and_users.up.sql` and `.down.sql`. Every migration gets a down file — no exceptions. You will need to roll back a bad migration in production eventually; write the rollback while the forward migration is still fresh in your head, not in a panic later.

`000001_create_orgs_and_users.up.sql`:

```sql
CREATE TABLE orgs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    email         TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'staff', -- 'admin' | 'staff'
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (org_id, email)
);
```

`000001_create_orgs_and_users.down.sql`:

```sql
DROP TABLE users;
DROP TABLE orgs;
```

Run it:

```bash
migrate -database "postgres://erp:erp@localhost:5432/erp?sslmode=disable" -path migrations up
```

### Run & Verify

```bash
docker exec -it $(docker compose ps -q postgres) psql -U erp -d erp -c '\dt'
# expect to see: orgs, users, schema_migrations
```

### Tips to Remember

- `UNIQUE (org_id, email)` not `UNIQUE (email)` — a real multi-tenant app allows the same email across different orgs. Getting this constraint wrong is exactly the kind of thing that's painless to fix now and a painful migration later.
- `gen_random_uuid()` needs the pgcrypto extension on older Postgres; Postgres 16 has `gen_random_uuid()` built into core, so you're fine — but if you ever downgrade, remember `CREATE EXTENSION IF NOT EXISTS pgcrypto;`.
- Never edit an already-applied migration file. If you got it wrong, write a new migration that fixes it. Editing history breaks anyone who already ran it.
- `schema_migrations` table (created automatically) is how golang-migrate tracks what's applied — don't hand-edit it.

---

## Section 4 — Connecting Go to Postgres, and the Repository Pattern

`internal/db/db.go`:

```go
package db

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // pgx driver, registered as "pgx"
)

func Connect(ctx context.Context, dsn string) (*sql.DB, error) {
	conn, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	// production connection pool tuning — the defaults are unbounded, which
	// will eventually exhaust postgres's max_connections under load
	conn.SetMaxOpenConns(25)
	conn.SetMaxIdleConns(25)
	conn.SetConnMaxLifetime(5 * time.Minute)

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := conn.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}

	return conn, nil
}
```

```bash
go get github.com/jackc/pgx/v5
```

Now the repository pattern: each domain package owns its own data access, behind an interface, so handlers never write raw SQL and your business logic is testable without a real database.

`internal/auth/repository.go`:

```go
package auth

import (
	"context"
	"database/sql"
	"errors"
)

var ErrNotFound = errors.New("not found")

type User struct {
	ID           string
	OrgID        string
	Email        string
	PasswordHash string
	Role         string
}

type Repository interface {
	CreateUser(ctx context.Context, u User) (User, error)
	GetUserByEmail(ctx context.Context, orgID, email string) (User, error)
}

type pgRepository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &pgRepository{db: db}
}

func (r *pgRepository) CreateUser(ctx context.Context, u User) (User, error) {
	const q = `
		INSERT INTO users (org_id, email, password_hash, role)
		VALUES ($1, $2, $3, $4)
		RETURNING id`
	err := r.db.QueryRowContext(ctx, q, u.OrgID, u.Email, u.PasswordHash, u.Role).Scan(&u.ID)
	return u, err
}

func (r *pgRepository) GetUserByEmail(ctx context.Context, orgID, email string) (User, error) {
	const q = `
		SELECT id, org_id, email, password_hash, role
		FROM users WHERE org_id = $1 AND email = $2`
	var u User
	err := r.db.QueryRowContext(ctx, q, orgID, email).Scan(&u.ID, &u.OrgID, &u.Email, &u.PasswordHash, &u.Role)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}
```

Why an interface with one implementation? Because in Section 6 you'll write a `mockRepository` for unit tests that never touches Postgres. This isn't premature abstraction — it's the standard shape for testable Go services.

### Run & Verify

Wire this into `main.go`: connect to the DB on boot, log success, exit(1) on failure. Then:

```bash
go run ./cmd/api
# expect a log line confirming DB connection before "starting server"
```

### Tips to Remember

- pgx as the driver (via stdlib compatibility shim) over lib/pq — lib/pq is in maintenance mode, pgx is the actively maintained, faster option. Using `database/sql` on top (rather than pgx's native API) keeps you portable if you ever need another driver.
- Always `QueryRowContext`/`ExecContext`/`QueryContext` — the Context variants, always. This is what lets a client disconnect or a timeout actually cancel the in-flight query instead of your server holding a connection open forever.
- `sql.ErrNoRows` → your own `ErrNotFound`. Never let raw `database/sql` errors leak up to your HTTP handlers; translate them at the repository boundary.

---

## Section 5 — Routing with chi, and Your First Real Endpoint

```bash
go get github.com/go-chi/chi/v5
```

`internal/httpserver/router.go`:

```go
package httpserver

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func NewRouter() *chi.Mux {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	return r
}
```

`middleware.Recoverer` matters more than it looks: without it, a panic in any handler kills the whole process and drops every other in-flight request. With it, a panic becomes a 500 for that one request and the server keeps running.

Now a real handler pattern, `internal/auth/handler.go`:

```go
package auth

import (
	"encoding/json"
	"net/http"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

type registerRequest struct {
	OrgName  string `json:"org_name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Email == "" || req.Password == "" || req.OrgName == "" {
		writeError(w, http.StatusBadRequest, "org_name, email, and password are required")
		return
	}

	user, err := h.svc.Register(r.Context(), req.OrgName, req.Email, req.Password)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not register user")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": user.ID, "email": user.Email})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
```

Note the handler → service → repository layering: handler does HTTP concerns (decode, status codes), service does business logic (hash the password, create the org), repository does SQL. Never let a handler talk to the database directly — this is the seam that makes every later feature (validation rules, audit logging, rate limiting) have one obvious place to live.

### Run & Verify

```bash
curl -i -X POST localhost:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"org_name":"Acme","email":"a@acme.com","password":"secretpass"}'
# expect 201 and a JSON body with id + email
```

### Tips to Remember

- `middleware.Recoverer` before `middleware.Logger` in the chain — middleware order matters, each wraps the next, and you generally want recovery to be the outermost safety net.
- `writeError` returning a generic message ("could not register user") to the client while logging the real error server-side is deliberate — never leak internal error strings (which can include SQL fragments) to API consumers.
- Validate at the handler boundary (empty-string checks) even though you'll also validate in the service — defense in depth, and it gives you cheap, specific 400s instead of the service layer's more generic error.

---

## Section 6 — Password Hashing, JWTs, and Auth Middleware

```bash
go get golang.org/x/crypto/bcrypt github.com/golang-jwt/jwt/v5
```

`internal/auth/service.go`:

```go
package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var ErrInvalidCredentials = errors.New("invalid credentials")

type Service struct {
	repo      Repository
	orgRepo   OrgRepository
	jwtSecret []byte
}

func NewService(repo Repository, orgRepo OrgRepository, jwtSecret string) *Service {
	return &Service{repo: repo, orgRepo: orgRepo, jwtSecret: []byte(jwtSecret)}
}

func (s *Service) Register(ctx context.Context, orgName, email, password string) (User, error) {
	org, err := s.orgRepo.Create(ctx, orgName)
	if err != nil {
		return User{}, fmt.Errorf("create org: %w", err)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return User{}, fmt.Errorf("hash password: %w", err)
	}

	return s.repo.CreateUser(ctx, User{
		OrgID:        org.ID,
		Email:        email,
		PasswordHash: string(hash),
		Role:         "admin", // first user of an org is its admin
	})
}

func (s *Service) Login(ctx context.Context, orgID, email, password string) (string, error) {
	user, err := s.repo.GetUserByEmail(ctx, orgID, email)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return "", ErrInvalidCredentials
		}
		return "", err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return "", ErrInvalidCredentials
	}

	return s.issueToken(user)
}

func (s *Service) issueToken(u User) (string, error) {
	claims := jwt.MapClaims{
		"sub":    u.ID,
		"org_id": u.OrgID,
		"role":   u.Role,
		"exp":    time.Now().Add(24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}
```

Auth middleware, `internal/httpserver/auth_middleware.go`:

```go
package httpserver

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type ctxKey string

const (
	ctxUserID ctxKey = "user_id"
	ctxOrgID  ctxKey = "org_id"
	ctxRole   ctxKey = "role"
)

func RequireAuth(secret []byte) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			tokenStr := strings.TrimPrefix(header, "Bearer ")
			if tokenStr == header { // no "Bearer " prefix found
				http.Error(w, "missing bearer token", http.StatusUnauthorized)
				return
			}

			token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
				return secret, nil
			})
			if err != nil || !token.Valid {
				http.Error(w, "invalid token", http.StatusUnauthorized)
				return
			}

			claims := token.Claims.(jwt.MapClaims)
			ctx := context.WithValue(r.Context(), ctxUserID, claims["sub"])
			ctx = context.WithValue(ctx, ctxOrgID, claims["org_id"])
			ctx = context.WithValue(ctx, ctxRole, claims["role"])

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func OrgIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(ctxOrgID).(string)
	return v
}
```

Mount it on a route group so public routes (`/auth/login`, `/auth/register`) stay open and everything else requires a valid token:

```go
r.Group(func(r chi.Router) {
	r.Use(httpserver.RequireAuth(jwtSecret))
	r.Route("/products", func(r chi.Router) { /* ... */ })
})
```

### Run & Verify

```bash
TOKEN=$(curl -s -X POST localhost:8080/auth/login \
  -d '{"org_id":"<id from register>","email":"a@acme.com","password":"secretpass"}' \
  -H 'Content-Type: application/json' | jq -r .token)

curl -i localhost:8080/products -H "Authorization: Bearer $TOKEN"
# without the header: expect 401
# with it: expect 200 (once Section 7 adds the route)
```

### Tips to Remember

- bcrypt, never plain SHA-256/MD5 for passwords — bcrypt is deliberately slow (defends against brute force) and salts automatically. This is non-negotiable in real software, ERP or not.
- Put `org_id` into every JWT claim, and every single repository query below must filter by it. This is the entire mechanism of your multi-tenancy — miss it once in one query and you've built a cross-tenant data leak. Section 7 shows the pattern to make this hard to forget.
- JWT `exp` of 24h with no refresh token is a fine bare-bones choice; note in your head that a real product needs short-lived access tokens + refresh tokens, and revocation (a blocklist or short expiry) for a "log out everywhere" feature.

---

## Section 7 — Products & Inventory (the first real domain module)

Migration `000002_create_products.up.sql`:

```sql
CREATE TABLE products (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    sku         TEXT NOT NULL,
    name        TEXT NOT NULL,
    unit_price  NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (org_id, sku)
);

-- append-only stock ledger, not a mutable "quantity" column.
-- current stock = SUM(quantity_delta) for a product. This gives you a full
-- audit trail for free and makes "why is stock wrong" answerable.
CREATE TABLE stock_movements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity_delta  INTEGER NOT NULL, -- positive = stock in, negative = stock out
    reason          TEXT NOT NULL,    -- 'purchase', 'sale', 'adjustment'
    reference_id    UUID,             -- e.g. the sales_order or purchase_order id
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
```

This ledger design is the single most important modeling decision in the whole ERP. A mutable `products.quantity` column looks simpler but silently rots: two concurrent sales can race and leave stock wrong with zero trace of what happened. An append-only ledger where current stock is a `SUM()` is slower to read (fixable with a materialized view or a maintained counter later) but cannot lose history and makes concurrent writes safe by construction (`INSERT` never conflicts the way `UPDATE ... SET qty = qty - 1` under a race can, if you're not careful with locking).

Repository (`internal/product/repository.go`) — the org-scoping pattern to hold onto for every module from here on:

```go
func (r *pgRepository) GetByID(ctx context.Context, orgID, productID string) (Product, error) {
	const q = `SELECT id, org_id, sku, name, unit_price FROM products
	           WHERE org_id = $1 AND id = $2`
	var p Product
	err := r.db.QueryRowContext(ctx, q, orgID, productID).Scan(&p.ID, &p.OrgID, &p.SKU, &p.Name, &p.UnitPrice)
	if errors.Is(err, sql.ErrNoRows) {
		return Product{}, ErrNotFound
	}
	return p, err
}

func (r *pgRepository) CurrentStock(ctx context.Context, orgID, productID string) (int, error) {
	const q = `SELECT COALESCE(SUM(quantity_delta), 0) FROM stock_movements
	           WHERE org_id = $1 AND product_id = $2`
	var qty int
	err := r.db.QueryRowContext(ctx, q, orgID, productID).Scan(&qty)
	return qty, err
}

func (r *pgRepository) RecordMovement(ctx context.Context, m StockMovement) error {
	const q = `INSERT INTO stock_movements (org_id, product_id, quantity_delta, reason, reference_id)
	           VALUES ($1, $2, $3, $4, $5)`
	_, err := r.db.ExecContext(ctx, q, m.OrgID, m.ProductID, m.QuantityDelta, m.Reason, m.ReferenceID)
	return err
}
```

Every query has `WHERE org_id = $1`. Make this a habit now, because Sales Orders and Purchase Orders in Sections 9–10 depend on it and there's no framework enforcing it for you — this is a discipline, not a library.

Wire up `GET /products`, `POST /products`, `GET /products/{id}/stock` following the Section 5 handler pattern.

### Run & Verify

```bash
curl -s -X POST localhost:8080/products -H "Authorization: Bearer $TOKEN" \
  -d '{"sku":"WIDGET-1","name":"Widget","unit_price":9.99}'

curl -s localhost:8080/products/<id>/stock -H "Authorization: Bearer $TOKEN"
# expect {"stock": 0} — no movements recorded yet
```

### Tips to Remember

- Append-only ledgers over mutable counters is a pattern you'll reuse for accounting, audit logs, and anywhere "how did we get here" matters. Learn it once here, apply it everywhere.
- `NUMERIC(12,2)` for money, never `FLOAT`/`REAL`. Floating point money is a classic bug generator (rounding errors that accumulate over thousands of transactions).
- If you ever catch yourself writing a query without `WHERE org_id = ...`, stop — that's the multi-tenant leak. Consider writing a small linter/grep check (`grep -rn "FROM products" internal/ | grep -v org_id`) as a pre-commit sanity check once the codebase grows.

---

## Section 8 — Testing: Unit Tests with Mocks, Integration Tests with Real Postgres

Two layers, both matter:

**Unit tests** — mock the repository interface, test business logic in isolation, fast (`internal/auth/service_test.go`):

```go
package auth

import (
	"context"
	"testing"
)

type mockRepo struct {
	users map[string]User
}

func (m *mockRepo) CreateUser(ctx context.Context, u User) (User, error) {
	u.ID = "test-id"
	m.users[u.Email] = u
	return u, nil
}

func (m *mockRepo) GetUserByEmail(ctx context.Context, orgID, email string) (User, error) {
	u, ok := m.users[email]
	if !ok {
		return User{}, ErrNotFound
	}
	return u, nil
}

func TestLogin_WrongPassword(t *testing.T) {
	repo := &mockRepo{users: map[string]User{}}
	svc := NewService(repo, &mockOrgRepo{}, "test-secret")

	_, _ = svc.Register(context.Background(), "Acme", "a@acme.com", "correct-password")

	_, err := svc.Login(context.Background(), "org-1", "a@acme.com", "wrong-password")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}
```

**Integration tests** — real Postgres, verifies your actual SQL (typos in column names don't show up in mocks!). Use testcontainers-go so tests spin up a throwaway Postgres automatically:

```bash
go get github.com/testcontainers/testcontainers-go/modules/postgres
```

```go
func TestProductRepository_CurrentStock(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}
	ctx := context.Background()
	pgContainer, err := postgres.Run(ctx, "postgres:16-alpine",
		postgres.WithDatabase("erp_test"),
		postgres.WithUsername("erp"), postgres.WithPassword("erp"))
	if err != nil {
		t.Fatal(err)
	}
	defer pgContainer.Terminate(ctx)

	dsn, _ := pgContainer.ConnectionString(ctx, "sslmode=disable")
	conn, _ := db.Connect(ctx, dsn)
	// run migrations against `conn` here (reuse your migrate setup), then:

	repo := product.NewRepository(conn)
	// ... insert a product, record movements, assert CurrentStock math
}
```

### Run & Verify

```bash
go test ./... -short          # unit tests only, fast, run these constantly
go test ./... -v              # everything including integration (needs Docker running)
```

### Tips to Remember

- `testing.Short()` gating is the standard Go idiom for "skip slow tests in quick iteration, run everything in CI." Wire `-short` into your editor's test runner.
- Table-driven tests (`for _, tc := range []struct{...}{...}`) are the idiomatic Go way to cover many cases without copy-pasting test functions — worth adopting once you have 3+ similar test cases in one function.
- Integration tests catch real bugs unit tests structurally cannot: a typo'd column name, a missing index causing a slow query, a constraint violation you didn't anticipate. Don't skip them just because they're slower — run the full suite before every merge.

---

## Section 9 — Customers, Suppliers, and Sales Orders (with real DB transactions)

Migration `000003_create_parties_and_sales.up.sql` (abbreviated — full version follows the same shape as products):

```sql
CREATE TABLE parties ( -- customers AND suppliers, distinguished by `kind`
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id     UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL CHECK (kind IN ('customer','supplier')),
    name       TEXT NOT NULL,
    email      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sales_orders (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES parties(id),
    status      TEXT NOT NULL DEFAULT 'draft', -- draft -> confirmed -> fulfilled -> cancelled
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sales_order_lines (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sales_order_id  UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES products(id),
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL -- snapshot price at order time, NOT a live join to products
);
```

Why snapshot `unit_price` on the line item rather than joining to `products.unit_price` at read time: if you change a product's price next week, last month's invoices must not silently reprice. This is a very common ERP correctness bug — always snapshot financial facts at the moment of the transaction.

Now the part that needs a real transaction — confirming a sales order must (a) check stock is available, (b) record stock-out movements, and (c) flip order status, atomically. If step (c) fails after (b) succeeded, you've shipped stock for an order that's still "draft." `internal/sales/service.go`:

```go
func (s *Service) ConfirmOrder(ctx context.Context, orgID, orderID string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback() // no-op if we already committed

	lines, err := s.repo.GetOrderLinesTx(ctx, tx, orgID, orderID)
	if err != nil {
		return fmt.Errorf("get lines: %w", err)
	}

	for _, line := range lines {
		stock, err := s.productRepo.CurrentStockTx(ctx, tx, orgID, line.ProductID)
		if err != nil {
			return fmt.Errorf("check stock: %w", err)
		}
		if stock < line.Quantity {
			return fmt.Errorf("%w: product %s has %d, order needs %d",
				ErrInsufficientStock, line.ProductID, stock, line.Quantity)
		}
		if err := s.productRepo.RecordMovementTx(ctx, tx, product.StockMovement{
			OrgID: orgID, ProductID: line.ProductID,
			QuantityDelta: -line.Quantity, Reason: "sale", ReferenceID: &orderID,
		}); err != nil {
			return fmt.Errorf("record movement: %w", err)
		}
	}

	if err := s.repo.UpdateStatusTx(ctx, tx, orgID, orderID, "confirmed"); err != nil {
		return fmt.Errorf("update status: %w", err)
	}

	return tx.Commit()
}
```

Each repository method now needs a `...Tx(ctx, tx *sql.Tx, ...)` variant that runs against the transaction instead of the pool directly — mechanically the same SQL, just called via `tx.QueryRowContext` instead of `db.QueryRowContext`. A common pattern is a small interface both `*sql.DB` and `*sql.Tx` satisfy (they share the same method set for Query/Exec), so you can write one repository method that accepts either.

### Run & Verify

```bash
# create a product with 5 in stock (via a stock adjustment), a customer, an order for 3 units
curl -s -X POST localhost:8080/sales-orders/<id>/confirm -H "Authorization: Bearer $TOKEN"
curl -s localhost:8080/products/<id>/stock -H "Authorization: Bearer $TOKEN"
# expect stock now shows 2

# now try to confirm an order for more than remaining stock
# expect a 409/422 with "insufficient stock", and stock UNCHANGED (transaction rolled back)
```

### Tips to Remember

- `defer tx.Rollback()` immediately after `BeginTx`, before any error can occur — a rolled-back-after-commit call is a documented no-op in `database/sql`, so this is always safe and is the standard idiom for "guarantee cleanup on any early return."
- Snapshot financial values (price, tax rate, etc.) onto line items at transaction time. Never trust a live join to current master data for anything that appears on a historical invoice.
- This "check-then-act" stock check has a subtler race even inside a transaction, depending on isolation level — two concurrent transactions can both read `stock=5` before either commits. For a bare-bones ERP, Postgres's default `READ COMMITTED` plus this being a genuinely rare race (you'd need two people confirming the same product's orders in the same instant) is an acceptable tradeoff. If you want it airtight, add `SELECT ... FOR UPDATE` on the product row when checking stock — worth knowing this exists even if you don't need it yet.

---

## Section 10 — Purchase Orders (same shape, opposite direction)

This section is intentionally short — it's a strong signal your architecture is working when a new module is mostly copy-adapt, not copy-paste-and-diverge.

`purchase_orders` / `purchase_order_lines` mirror `sales_orders` / `sales_order_lines` exactly, with `supplier_id` instead of `customer_id`. `ReceiveOrder` mirrors `ConfirmOrder` with one sign flip: `quantity_delta` is positive (stock in) and reason is `"purchase"`.

### Run & Verify

```bash
curl -s -X POST localhost:8080/purchase-orders/<id>/receive -H "Authorization: Bearer $TOKEN"
curl -s localhost:8080/products/<id>/stock -H "Authorization: Bearer $TOKEN"
# expect stock increased by the received quantity
```

### Tips to Remember

- When a new feature is "copy an existing module and flip a sign," that's your architecture rewarding you — don't fight the urge to DRY it into a shared generic "Order" abstraction too early. Two concrete, boring, similar modules are easier to reason about than one clever abstraction that has to branch on `type == 'sale'` vs `'purchase'` everywhere.
- If/when you do see a third order type wanting the same shape, that's the actual signal to extract a shared orderable interface or table — "rule of three," not "rule of two."

---

## Section 11 — A Minimal Dashboard (Angular SPA)

No server-rendered templates this time. We use Angular (standalone components) so the frontend is a proper SPA with client-side routing, reactive forms, and HTTP interceptors for JWT. The Go server serves the built static assets and the API under the same origin (no CORS headaches in production).

### 11.1 Create the Angular app

```bash
# from the erp-go root
npx @angular/cli@19 new frontend --routing --style=css --ssr=false --standalone
cd frontend
```

(Use the latest stable Angular CLI that matches your Node version; the guide assumes standalone components, which have been the default for a while.)

### 11.2 Core structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── core/                 # auth interceptor, auth service, guards
│   │   ├── products/             # products list + create
│   │   ├── sales/                # sales orders
│   │   ├── shared/               # models, pipes, etc.
│   │   ├── app.component.ts
│   │   ├── app.config.ts
│   │   └── app.routes.ts
│   ├── environments/
│   │   ├── environment.ts        # { apiUrl: 'http://localhost:8080' }
│   │   └── environment.prod.ts   # { apiUrl: '' }  // same origin when served by Go
│   └── index.html
├── angular.json
└── package.json
```

### 11.3 Auth interceptor (the important piece)

`frontend/src/app/core/auth.interceptor.ts`:

```typescript
import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.getToken();
  if (token) {
    req = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` }
    });
  }
  return next(req);
};
```

Register it in `app.config.ts`:

```typescript
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authInterceptor } from './core/auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
  ]
};
```

`AuthService` simply stores the JWT in `localStorage` (or sessionStorage) after login and clears it on logout. A route guard checks for the presence of a token before allowing access to `/products`, `/sales`, etc.

### 11.4 Products list component (example)

`frontend/src/app/products/products.component.ts` (standalone):

```typescript
import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';

interface Product {
  id: string;
  sku: string;
  name: string;
  unit_price: number;
}

@Component({
  selector: 'app-products',
  standalone: true,
  imports: [CommonModule],
  template: `
    <h1>Products</h1>
    <table>
      <thead>
        <tr><th>SKU</th><th>Name</th><th>Price</th><th>Stock</th></tr>
      </thead>
      <tbody>
        @for (p of products; track p.id) {
          <tr>
            <td>{{ p.sku }}</td>
            <td>{{ p.name }}</td>
            <td>{{ p.unit_price | number:'1.2-2' }}</td>
            <td>{{ stock[p.id] ?? '…' }}</td>
          </tr>
        }
      </tbody>
    </table>
  `
})
export class ProductsComponent implements OnInit {
  private http = inject(HttpClient);
  products: Product[] = [];
  stock: Record<string, number> = {};

  ngOnInit() {
    this.http.get<Product[]>(`${environment.apiUrl}/products`).subscribe(list => {
      this.products = list;
      list.forEach(p => {
        this.http.get<{ stock: number }>(`${environment.apiUrl}/products/${p.id}/stock`)
          .subscribe(s => this.stock[p.id] = s.stock);
      });
    });
  }
}
```

(You can later improve this with a single endpoint that returns products + current stock, or use Angular signals / RxJS `forkJoin`.)

### 11.5 Serving the Angular build from Go

In production the Go binary serves the built `frontend/dist/frontend/browser` (or whatever the output path is) as static files, with a fallback to `index.html` for client-side routing.

In `internal/httpserver/router.go` (or a dedicated static handler):

```go
// after API routes
fs := http.FileServer(http.Dir("frontend/dist/frontend/browser"))
r.Handle("/*", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	// if the path looks like an API call, 404
	if strings.HasPrefix(r.URL.Path, "/auth") || strings.HasPrefix(r.URL.Path, "/products") /* etc */ {
		http.NotFound(w, r)
		return
	}
	// try the static file; if missing, serve index.html (SPA fallback)
	path := filepath.Join("frontend/dist/frontend/browser", r.URL.Path)
	if _, err := os.Stat(path); os.IsNotExist(err) {
		http.ServeFile(w, r, "frontend/dist/frontend/browser/index.html")
		return
	}
	fs.ServeHTTP(w, r)
}))
```

In development you normally run `ng serve` on port 4200 and proxy API calls to the Go server (or set `environment.apiUrl = 'http://localhost:8080'` and enable CORS on the Go side for `localhost:4200` only).

### 11.6 Environment & proxy for local dev

`frontend/src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080'
};
```

`frontend/proxy.conf.json` (optional, if you prefer same-origin during `ng serve`):

```json
{
  "/auth": { "target": "http://localhost:8080", "secure": false },
  "/products": { "target": "http://localhost:8080", "secure": false },
  "/sales-orders": { "target": "http://localhost:8080", "secure": false }
}
```

Then `ng serve --proxy-config proxy.conf.json`.

### Run & Verify

```bash
# terminal 1 – Go API
go run ./cmd/api

# terminal 2 – Angular
cd frontend
ng serve
# open http://localhost:4200
# log in, navigate to Products — you should see the table populated from the API
# stock cells fill in after the individual stock requests
```

After a production build:

```bash
cd frontend && ng build --configuration production
# then restart the Go server (it now serves the dist folder)
# open http://localhost:8080 — same SPA, now same-origin
```

### Tips to Remember

- Always put the JWT in an HTTP interceptor, never manually in every component. One place to change the header format later.
- Use `environment.prod.ts` with `apiUrl: ''` so the production build talks to the same origin the Go server is serving.
- SPA fallback (`index.html` for unknown paths) is required for Angular Router to work when the user refreshes on `/products/123`.
- Keep CORS disabled (or restricted to `localhost:4200`) in production — same-origin static serving eliminates the whole class of problems.
- Standalone components + `provideHttpClient(withInterceptors(...))` is the modern Angular way; avoid NgModules unless you have a strong reason.
- For larger lists, prefer a single backend endpoint that returns products + stock together instead of N+1 HTTP calls from the browser.

---

## Section 12 — Containerization & Bringing It All Together

`Dockerfile` (multi-stage — this matters for image size and attack surface):

```dockerfile
# --- Angular build stage ---
FROM node:22-alpine AS frontend-build
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build -- --configuration production

# --- Go build stage ---
FROM golang:1.23-alpine AS backend-build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /erp-api ./cmd/api

# --- run stage ---
FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=backend-build /erp-api /erp-api
COPY --from=frontend-build /app/dist/frontend/browser /frontend/dist/frontend/browser
EXPOSE 8080
USER nobody
ENTRYPOINT ["/erp-api"]
```

Full `docker-compose.yml` now includes the app itself:

```yaml
services:
  postgres:
    # (as in Section 3)
  api:
    build: .
    environment:
      DATABASE_URL: postgres://erp:erp@postgres:5432/erp?sslmode=disable
      JWT_SECRET: ${JWT_SECRET}
      APP_ENV: prod
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/healthz"]
      interval: 10s
```

### Run & Verify

```bash
docker compose up --build
curl localhost:8080/healthz
# open http://localhost:8080 in a browser — Angular SPA loads, API calls work same-origin
# same green-path checks from every earlier section, now running fully containerized
```

### Tips to Remember

- Multi-stage builds: the final image contains only the compiled binary + the Angular static files + ca-certificates. No Node, no Go toolchain, no source.
- `CGO_ENABLED=0` produces a static binary — required for it to run on the minimal alpine base without missing shared libraries.
- `USER nobody` — don't run your container as root. It's one line and it's standard practice; skipping it is the kind of thing a security review will flag immediately.
- `depends_on: condition: service_healthy` (not just `depends_on: postgres`) — plain `depends_on` only waits for the container to start, not for Postgres to actually be ready to accept connections. This is a very common source of "works on my machine, flaky in CI" bugs.
- The Angular `dist` path can change slightly between Angular versions; always check `angular.json` → `outputPath` and adjust the `COPY` accordingly.

---

## What You've Built, and Where Real Scope Lives Next

At this point you have: multi-tenant auth, an append-only inventory ledger, sales and purchase order flows with real transactional stock updates, a proper Angular SPA dashboard (with JWT interceptor and client-side routing), tests at two layers, and a containerized deployable service. That's a genuine bare-bones ERP — not a toy.

**Honest next steps**, roughly in the order a real product would need them:

1. Double-entry accounting ledger underneath sales/purchases (debits/credits, a chart of accounts) — the natural next "append-only ledger" to add, same philosophy as `stock_movements`.
2. RBAC beyond admin/staff — per-module permissions, not just a role string.
3. Idempotency keys on money-moving endpoints (confirm order, receive PO) so a retried request from a flaky client can't double-book.
4. Observability: Prometheus metrics (`/metrics` via promhttp), request tracing (OpenTelemetry), and log aggregation — you have structured logs from Section 1, this is wiring them somewhere queryable.
5. sqlc to generate typed Go from your SQL instead of hand-written `Scan()` calls, once the number of queries grows past what's comfortable to maintain by hand.
6. Background jobs (e.g. low-stock email alerts) — a simple table-based job queue is enough at this scale; you don't need Kafka for a bare-bones ERP.
7. Angular improvements: signals for state, proper form validation with reactive forms, lazy-loaded feature modules/routes, and a shared API service layer.

**Final tip to remember:** every pattern in this guide (repository interfaces, org-scoped queries, append-only ledgers, snapshotted financial values, `defer tx.Rollback()`, multi-stage Docker builds, and a clean Angular interceptor + environment split) is something you'll reach for again outside ERPs specifically. This is a genuinely representative slice of what production Go + modern SPA backend work looks like.
