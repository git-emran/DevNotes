# Flag Debt Scanner — Production Build Plan

**A companion tool for Optimizely Feature Experimentation / Web Experimentation that finds, tracks, and cleans up dead feature-flag code.**

This document is a complete, phase-by-phase build specification. It is written so that a human engineer or an autonomous coding agent can pick it up and implement the product end to end without needing additional product decisions. Where a decision is ambiguous, this doc states the default choice explicitly rather than leaving it open.

---

## 1. Problem Statement

Optimizely Feature Experimentation and Web Experimentation track flag lifecycle status (Draft, Live, Running, Paused, Stale, Archived) _inside_ the Optimizely platform. They have no visibility into a customer's actual source code. Over time this creates **flag debt**:

- Flags that are Archived/Stale in Optimizely but still referenced in application code.
- Winning-variant branches that were never inlined after an experiment concluded, leaving dead losing-variant code behind.
- Flags referenced in code that don't exist (or were deleted) in the Optimizely project — usually typos or leftover code from abandoned experiments.
- Long-running flags (e.g. "Running" for 8+ months) with no corresponding code changes, suggesting they were forgotten rather than intentionally kept as permanent kill-switches.

No one owns cleanup of this debt. It accumulates linearly with flag count and becomes a genuine maintenance and readability cost. This tool closes that gap by connecting the Optimizely API (source of truth for flag _state_) with static analysis of the customer's actual codebase (source of truth for flag _usage_).

## 2. Goals

- **G1**: Detect every reference to an Optimizely flag key across a codebase, regardless of language/SDK.
- **G2**: Cross-reference code references against live Optimizely flag/experiment state via the Optimizely REST API.
- **G3**: Surface a prioritized, actionable "flag debt report" (dashboard + CI check).
- **G4**: For the safe/mechanical subset of cases, auto-generate a cleanup pull request.
- **G5**: Be safe by default — never merge code automatically, never delete a flag from Optimizely itself, always leave a human as the final approver.

## 3. Non-Goals (explicitly out of scope for v1–v3)

- Not a replacement for Optimizely's own flag management UI.
- Not an experimentation/statistics engine — no independent stats calculations. We only relay Optimizely's own experiment results/status.
- Not a general-purpose dead-code detector — scope is intentionally limited to flag-related code paths.
- No support for mobile SDKs (iOS/Android/React Native) in v1. Web/Node/Python backend only. Mobile support is a Phase 5+ consideration.

## 4. High-Level Architecture

```
                       ┌─────────────────────────┐
                       │   Optimizely REST API    │
                       │ (flags, experiments,     │
                       │  projects, environments)  │
                       └───────────┬──────────────┘
                                   │ polled / webhook
                                   ▼
┌──────────────┐   scan trigger   ┌────────────────────┐
│ GitHub App /  │ ───────────────▶│   Scan Orchestrator  │
│ GitLab webhook│                  │   (Quart, async)     │
└──────────────┘                  └─────────┬────────────┘
                                             │ enqueues job
                                             ▼
                                   ┌────────────────────┐
                                   │   Job Queue (Redis   │
                                   │   + arq/RQ)          │
                                   └─────────┬────────────┘
                                             │
                                             ▼
                                   ┌────────────────────┐
                                   │  Scanner Workers     │
                                   │  (clone repo, run     │
                                   │  AST analyzers)       │
                                   └─────────┬────────────┘
                                             │ results
                                             ▼
                                   ┌────────────────────┐
                                   │   Postgres (findings, │
                                   │   flag state cache,   │
                                   │   repo/project config)│
                                   └─────────┬────────────┘
                                             │
                        ┌────────────────────┼─────────────────────┐
                        ▼                    ▼                     ▼
                ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐
                │ Dashboard UI  │   │  CI Check API      │   │  PR Generator     │
                │ (React)       │   │  (status checks)    │   │  (GitHub API)      │
                └──────────────┘   └──────────────────┘   └──────────────────┘
```

**Core insight driving the architecture**: scanning is I/O- and CPU-bound and can be slow on large monorepos, so it must be a background job, never a synchronous request. Everything the user _sees_ (dashboard, CI status) reads from Postgres, never triggers a live scan directly.

## 5. Tech Stack (with rationale)

|Layer|Choice|Why|
|---|---|---|
|Backend API|Python 3.14, Quart (async)|Async I/O for many concurrent Optimizely API + GitHub API calls; matches modern async Python patterns|
|Type checking|Pyright, strict mode|Catch integration bugs against Optimizely/GitHub API response shapes at dev time|
|Job queue|Redis + `arq`|Lightweight async-native queue, avoids Celery's sync-first overhead|
|Database|Postgres|Relational data (repos, flags, findings) with clear foreign keys; JSONB columns for raw API payloads|
|ORM|SQLAlchemy 2.0 (async) + Alembic migrations|Standard, well-typed, works cleanly with Quart|
|Static analysis (JS/TS)|`ts-morph` (via a small Node sidecar service)|Best-in-class TS/JS AST manipulation; needed for accurate detection and for auto-generating fixes|
|Static analysis (Python)|Python `ast` + `libcst`|`libcst` preserves formatting/comments, required for auto-PR generation to produce clean diffs|
|Frontend|React + TypeScript, Vite|Matches team's existing frontend strengths; component reuse with recharts for debt trend charts|
|Auth|GitHub OAuth App + Optimizely API token (per-project, encrypted at rest)|No new credential system to manage|
|Hosting|Containerized (Docker), deployable to any cloud (Fly.io / Render / AWS ECS)|Keep infra-agnostic for v1|

**Why a Node sidecar for TS/JS analysis instead of pure Python?** There is no mature Python library for parsing TypeScript AST with full type information. Rather than hand-rolling a regex-based scanner (which will produce false positives/negatives on flag key detection), a small dedicated Node/`ts-morph` microservice does the parsing and returns structured JSON findings to the Quart backend over an internal HTTP call. This keeps the "smart" analysis in the best tool for each language while keeping orchestration, storage, and business logic centralized in Python.

## 6. Data Model

### 6.1 Core tables

```sql
-- A customer's Optimizely account/project + connected repo(s)
CREATE TABLE workspace (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    optimizely_project_id TEXT NOT NULL,
    optimizely_api_token_encrypted TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE repository (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('github', 'gitlab')),
    external_repo_id TEXT NOT NULL,       -- e.g. GitHub repo ID
    full_name TEXT NOT NULL,              -- e.g. "org/repo"
    default_branch TEXT NOT NULL DEFAULT 'main',
    installation_id TEXT,                 -- GitHub App installation ID
    last_scanned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cached snapshot of Optimizely flag state (refreshed on a schedule + webhook)
CREATE TABLE optimizely_flag (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
    flag_key TEXT NOT NULL,
    status TEXT NOT NULL,                 -- Draft/Live/Running/Paused/Stale/Archived
    environments JSONB NOT NULL,          -- per-env enabled state
    winning_variation_key TEXT,           -- null if no concluded experiment
    experiment_id TEXT,
    last_modified_at TIMESTAMPTZ,
    raw_payload JSONB NOT NULL,           -- full API response, for future-proofing
    synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (workspace_id, flag_key)
);

-- A single scan run
CREATE TABLE scan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repository_id UUID NOT NULL REFERENCES repository(id) ON DELETE CASCADE,
    commit_sha TEXT NOT NULL,
    trigger TEXT NOT NULL CHECK (trigger IN ('push', 'scheduled', 'manual', 'pr')),
    status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'completed', 'failed')),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    error_message TEXT
);

-- Each flag reference found in code
CREATE TABLE flag_reference (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id UUID NOT NULL REFERENCES scan(id) ON DELETE CASCADE,
    flag_key TEXT NOT NULL,
    file_path TEXT NOT NULL,
    line_number INT NOT NULL,
    column_number INT,
    call_type TEXT NOT NULL,              -- e.g. 'isFeatureEnabled', 'getVariation', 'decide'
    language TEXT NOT NULL,               -- 'typescript' | 'javascript' | 'python'
    snippet TEXT NOT NULL                 -- small surrounding code snippet for display
);

-- A computed debt finding (the actionable unit shown in the dashboard)
CREATE TABLE finding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
    repository_id UUID NOT NULL REFERENCES repository(id) ON DELETE CASCADE,
    flag_key TEXT NOT NULL,
    finding_type TEXT NOT NULL CHECK (finding_type IN (
        'archived_flag_still_referenced',
        'stale_flag_no_code_change',
        'orphaned_flag_no_optimizely_entry',
        'dead_variant_branch',
        'inlineable_winner'
    )),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pr_opened', 'resolved', 'ignored')),
    reference_ids UUID[] NOT NULL,        -- flag_reference rows this finding is based on
    pr_url TEXT,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);
```

### 6.2 Why findings are separate from raw references

`flag_reference` rows are per-scan and disposable (a new scan replaces them). `finding` rows persist across scans by flag_key + repository so that debt can be tracked over time (age, "first seen 6 months ago" style aging reports) and so a finding can carry state like `ignored` (user dismissed) without losing that decision on the next scan. This is a deliberate append/reconcile pattern: each scan diffs new references against open findings, closes findings that no longer reproduce, and creates new ones for newly detected issues.

## 7. Optimizely API Integration Details

Use Optimizely's REST API (Feature Experimentation / Web Experimentation) for:

- `GET /flags` — list flags per project, including status and environment enablement.
- `GET /experiments/{id}` — pull experiment results and winning variation, when a flag has an associated experiment.
- `GET /projects/{id}` — validate token scope and project metadata on workspace setup.

**Polling + webhook hybrid**: Optimizely does not guarantee webhook delivery for every state change relevant to this tool at the time of writing, so v1 uses scheduled polling (every 15 minutes, configurable) as the reliable source of truth, with webhook support added opportunistically where available to reduce staleness. Always re-verify current webhook support against Optimizely's published API docs before implementation, since this is the kind of detail that changes between releases — do not hardcode assumptions from this doc into the implementation without checking.

**Credential handling**: Optimizely personal API tokens are scoped per-project. Store encrypted at rest (e.g. via `cryptography.fernet` with a key from a secrets manager, never in plaintext columns). Never log token values. Provide a "test connection" button in onboarding that makes one read-only call before saving.

## 8. Flag Reference Detection Logic (the hard part)

### 8.1 TypeScript/JavaScript (via `ts-morph` sidecar)

Detect calls matching known Optimizely SDK method signatures:

- `optimizelyClient.isFeatureEnabled('flag_key', ...)`
- `optimizelyClient.getEnabledFeatures(...)` (harder — dynamic, flag lots as "needs manual review" rather than false-positive-matching)
- `optimizelyClient.getFeatureVariable*('flag_key', 'variable_key', ...)`
- `optimizelyClient.decide('flag_key', ...)` (FX v3+ Decide API)
- React SDK: `<OptimizelyFeature feature="flag_key">`, `useFeature('flag_key')`, `useDecision('flag_key')`

Implementation approach: walk the AST for call expressions and JSX elements, match against a configurable list of known method/prop names (kept in a config file so new SDK versions can be supported without code changes), and extract the flag key argument **only when it is a string literal**. When the flag key is a variable/dynamic expression, emit a lower-confidence finding tagged `dynamic_key_needs_review` rather than silently skipping it — silent skips are a worse failure mode than a noisy-but-flagged unknown.

### 8.2 Python (via `libcst`)

Same approach, matching against the Python SDK equivalents (`optimizely_client.is_feature_enabled`, `.decide`, `.get_feature_variable_*`). `libcst` is used instead of the stdlib `ast` module specifically because Phase 3 (auto-PR generation) needs to modify and re-emit source code with formatting/comments intact, and `ast` cannot round-trip source faithfully.

### 8.3 Confidence scoring

Every reference gets a `confidence` value (not stored as its own column in the current schema — add `confidence NUMERIC` to `flag_reference` if implementing this from day one, recommended). High confidence: string-literal flag key matched against a known SDK method. Low confidence: dynamic key, or method name ambiguous (e.g. wrapped in a custom helper function like `myFeatureCheck(key)`). Low-confidence findings should still surface in the dashboard but should never be eligible for Phase 3 auto-PR generation.

## 9. Finding Classification Logic

Given the set of `flag_reference` rows for a flag_key in a given repo, plus the corresponding `optimizely_flag` row (may be null if no matching flag exists in Optimizely):

```
if no matching optimizely_flag row exists:
    → finding_type = 'orphaned_flag_no_optimizely_entry', severity = medium
    (likely a typo, or a flag deleted in Optimizely without code cleanup)

elif optimizely_flag.status == 'Archived' and references exist:
    → finding_type = 'archived_flag_still_referenced', severity = high
    (highest-confidence, safest cleanup candidate)

elif optimizely_flag.status == 'Stale'
     and optimizely_flag.last_modified_at < now() - 90 days
     and no code changes to referencing files since last_modified_at:
    → finding_type = 'stale_flag_no_code_change', severity = medium

elif optimizely_flag.winning_variation_key is not null
     and all references to this flag resolve to a single branch check
     (i.e. simple if/else pattern, not compound logic):
    → finding_type = 'inlineable_winner', severity = low
    (eligible for auto-PR in Phase 3)

elif references include an explicit losing-variant-only code branch
     (i.e. an else/default branch that can never execute given winning_variation_key):
    → finding_type = 'dead_variant_branch', severity = low
```

This classification logic should live in a single, well-tested pure function (`classify_finding(flag, references) -> FindingType | None`) with a comprehensive unit test suite covering each branch — this is the most important piece of business logic in the whole system and regressions here directly cause either false cleanup suggestions (bad) or missed debt (less bad but still undesirable).

## 10. Auto-PR Generation (Phase 3 detail)

Only runs for `finding_type = 'inlineable_winner'` with all underlying references at high confidence, and only when explicitly enabled per-repository (opt-in setting, default off).

Process:

1. Clone repo at default branch HEAD into an ephemeral workspace.
2. For each qualifying reference, use `libcst`/`ts-morph` to rewrite the AST: replace the conditional with the winning branch's body, remove the flag check import if now unused.
3. Run the repo's existing formatter if detected (`prettier` config present → run prettier; `black`/`ruff format` present → run it) so the diff matches house style.
4. Open a PR via GitHub API with:
    - Title: `Remove flag: {flag_key} (winner: {winning_variation_key})`
    - Body: link to the Optimizely experiment results, list of files changed, and an explicit note that this was generated automatically and should be reviewed like any other PR — **never auto-merge**.
    - Label: `flag-debt-cleanup` (auto-created if missing).
5. Update `finding.status = 'pr_opened'` and store `pr_url`.

**Safety rule, non-negotiable for v1–v3**: this tool never merges its own PRs, never pushes directly to a protected branch, and never deletes anything from the Optimizely project itself (Optimizely flag deletion stays a manual, human action in the Optimizely UI). The tool's blast radius is strictly "open a PR for a human to review."

## 11. CI Integration

Expose a GitHub Check Run (via the Checks API) on every PR:

- **Fails the check** only for `orphaned_flag_no_optimizely_entry` findings introduced _by that PR's diff_ (i.e. new code referencing a flag key with no Optimizely record) — this is the one case worth blocking merges over, since it's very likely a typo or leftover debug code.
- All other finding types are informational-only annotations on the PR (via review comments), never blocking, to avoid the tool being disabled by frustrated teams. This is a deliberate product decision: a debt tool that blocks merges on stylistic/debt grounds gets uninstalled; one that blocks only on likely-bugs earns trust.

## 12. Dashboard (Frontend)

Views required for v1:

1. **Overview** — total open findings by severity, trend line of findings-over-time (recharts), per-repository breakdown.
2. **Findings list** — filterable/sortable table (flag_key, repo, finding_type, severity, age, status), with a detail drawer showing the exact code snippet(s) and matching Optimizely flag state.
3. **Repository settings** — connect/disconnect repos, toggle auto-PR generation, configure scan schedule.
4. **Flag detail view** — for a single flag_key, show every repo/reference across the whole workspace (useful for flags shared across microservices).

Keep the frontend a thin read/write layer over the REST API described in section 13 — no business logic in the frontend beyond display formatting.

## 13. Backend REST API Surface

```
POST   /api/workspaces                      create workspace + store Optimizely token
GET    /api/workspaces/:id
POST   /api/workspaces/:id/repositories      connect a repo (triggers GitHub App install flow)
DELETE /api/repositories/:id
POST   /api/repositories/:id/scan            manual scan trigger
GET    /api/repositories/:id/scans           scan history
GET    /api/findings?workspace_id=&status=&severity=&repo_id=   filterable findings list
GET    /api/findings/:id
PATCH  /api/findings/:id                     { status: 'ignored' | 'resolved' }
GET    /api/flags?workspace_id=              list cached Optimizely flags + reference counts
POST   /api/webhooks/github                  GitHub App webhook receiver
POST   /api/webhooks/optimizely               Optimizely webhook receiver (if/when available)
```

All list endpoints support cursor-based pagination (`?cursor=&limit=`) from day one — retrofitting pagination onto a dashboard already assuming full-list responses is disproportionately painful later.

## 14. Security Considerations

- Encrypt Optimizely API tokens and GitHub installation tokens at rest.
- Scope the GitHub App to the minimum permissions needed: `contents: read/write` (for cloning + PR branches), `pull_requests: write`, `checks: write`. Explicitly do **not** request `admin` or org-wide permissions.
- Ephemeral scan workspaces (cloned repos) must be deleted immediately after each scan completes, including on failure paths (`finally` block, not just the happy path).
- Rate-limit the manual scan trigger endpoint per repository to prevent abuse/cost blowup.
- Multi-tenant isolation: every query must be scoped by `workspace_id`; add this as a required parameter at the ORM/repository layer rather than trusting each call site to remember it, to prevent cross-tenant data leaks as the codebase grows.

## 15. Testing Strategy

- **Classification logic (`classify_finding`)**: exhaustive unit tests, one per branch in section 9, plus edge cases (flag with no experiment, flag with multiple environments in conflicting states, compound conditionals that shouldn't be marked inlineable).
- **AST detection**: golden-file tests — a folder of sample TS/Python files with known expected findings, diffed against actual scanner output on every CI run. This is the highest-value test suite in the repo since detection accuracy is the entire product.
- **Auto-PR generation**: snapshot tests on the rewritten AST output for representative before/after code samples; never let this ship without a human-reviewed diff in the test suite itself.
- **API layer**: standard integration tests against a test Postgres instance (via testcontainers or equivalent), covering multi-tenant isolation explicitly (a test that asserts workspace A can never see workspace B's findings).

## 16. Build Phases

### Phase 0 — Foundations (1–2 weeks)

- Repo scaffolding: Quart backend, Postgres + Alembic, Redis, Node sidecar service skeleton.
- Workspace creation + encrypted Optimizely token storage + "test connection" call.
- Optimizely API client wrapper (typed, with Pyright strict mode) covering `GET /flags` and `GET /experiments/{id}`.
- Scheduled polling job that syncs `optimizely_flag` table.

**Exit criteria**: given a real Optimizely project token, the system correctly mirrors flag status into Postgres on a schedule.

### Phase 1 — Read-Only Scanning + Dashboard (2–4 weeks)

- GitHub App registration + OAuth install flow; repo connection endpoint.
- TS/JS AST scanner (Node sidecar) covering the method list in section 8.1, string-literal keys only (defer dynamic-key handling to Phase 1.5).
- Python scanner (libcst) covering section 8.2.
- Scan orchestrator + job queue wiring (`arq` workers).
- `classify_finding` implementation + full unit test suite (section 9, 15).
- Findings persistence + reconciliation logic (open/resolve findings across scans).
- Minimal dashboard: Overview + Findings list views only (skip flag-detail view for now).

**Exit criteria**: connect a real repo, run a scan, see accurate findings in the dashboard with no auto-PR capability yet. This phase alone is a shippable, valuable v1 product — do not let scope creep from later phases delay this release.

### Phase 2 — CI Integration (1–2 weeks)

- GitHub Checks API integration (section 11).
- Scan-on-PR trigger (webhook-driven, scoped to changed files for speed rather than full-repo rescans on every PR).
- Ignore/resolve actions wired into the dashboard (`PATCH /api/findings/:id`).

**Exit criteria**: opening a PR that introduces an orphaned flag reference produces a failing check with a clear message; other finding types annotate without blocking.

### Phase 3 — Auto-PR Generation (3–4 weeks, highest risk phase)

- AST rewrite logic for `inlineable_winner` cases, both TS/JS and Python.
- Formatter detection + invocation post-rewrite.
- PR creation via GitHub API, opt-in toggle per repository.
- Confidence scoring added to `flag_reference` (schema migration) and enforced as a gate before any auto-PR eligibility.
- Extensive golden-file/snapshot test coverage before enabling for any real repository.

**Exit criteria**: on a test repository, an inlineable-winner flag reliably produces a correct, cleanly formatted, human-reviewable PR with zero false rewrites across the test suite.

### Phase 4 — Hardening & Multi-Language Expansion (ongoing)

- Add Go and Java/Kotlin SDK detection (common in backend-heavy Optimizely Feature Experimentation customers).
- Flag-detail cross-repo view (section 12, item 4).
- Webhook support from Optimizely if/when generally available, reducing reliance on polling.
- Usage-based dashboard improvements: debt trend over time, "oldest open findings" leaderboard to drive team accountability.

### Phase 5 — Stretch Goals (post-v1, not required for a viable product)

- Mobile SDK support (iOS/Android/React Native) — meaningfully harder due to binary/compiled analysis constraints, treat as a separate research spike before committing to a timeline.
- GitLab support (currently GitHub-only) — mirror the GitHub App model using a GitLab-native integration.
- Slack notifications for new high-severity findings, mirroring Optimizely's own Slack integration pattern so it feels native to teams already using that workflow.

## 17. Success Metrics (post-launch)

- **Detection accuracy**: false-positive rate on findings, tracked via the `ignored` finding status as a proxy (high ignore rate on a finding_type signals a classification bug).
- **Time-to-resolution**: median age of findings before they reach `resolved` status, trending down over time indicates the tool is actually driving cleanup, not just cataloguing debt.
- **Auto-PR acceptance rate**: percentage of Phase 3 generated PRs that get merged as-is vs. closed/heavily edited — this is the clearest signal of whether the auto-PR feature is trustworthy enough to keep enabled by default for a given repo.

---

## Appendix A — Example: Detecting a React SDK reference

Input source:

```tsx
const isEnabled = useFeature('new_checkout_flow')[0];
```

Expected `ts-morph` walk: find `CallExpression` where the callee identifier is `useFeature` (configured in the known-methods list), first argument is a `StringLiteral`, extract `new_checkout_flow` as `flag_key`, record `call_type: 'useFeature'`, `language: 'typescript'`, and the enclosing line/column for the `flag_reference` row.

## Appendix B — Example: Classification walkthrough

Given:

- `optimizely_flag`: `flag_key='new_checkout_flow'`, `status='Archived'`
- Three `flag_reference` rows in `checkout.tsx`, `checkout.test.tsx`, `analytics.ts`

Result: one `finding` row, `finding_type='archived_flag_still_referenced'`, `severity='high'`, `reference_ids` containing all three reference IDs. This is the highest-priority, lowest-ambiguity case and should be the first finding_type implemented and tested in Phase 1.

## Appendix C — Config file format for known SDK methods

Keep this outside of code so new Optimizely SDK versions/methods can be added without a deploy:

```yaml
# sdk_methods.yaml
typescript:
  - method: isFeatureEnabled
    key_arg_index: 0
  - method: getFeatureVariableString
    key_arg_index: 0
  - method: decide
    key_arg_index: 0
  - jsx_component: OptimizelyFeature
    key_prop: feature
  - hook: useFeature
    key_arg_index: 0
  - hook: useDecision
    key_arg_index: 0
python:
  - method: is_feature_enabled
    key_arg_index: 0
  - method: get_feature_variable_string
    key_arg_index: 0
  - method: decide
    key_arg_index: 0
```

---

**Implementation note for whoever builds this**: verify current Optimizely REST API endpoint names, authentication scheme, and webhook availability against the live API docs before starting Phase 0 — API surfaces evolve, and this document's section 7 should be treated as a starting point for that verification, not a final source of truth.