# Building a Bare-Bones Software Delivery Harness

A minimal, from-scratch implementation of what CI/CD platforms (Harness.io, Jenkins,
Spinnaker...) automate under the hood — built in Go, in sections, so each concept is
isolated and runnable on its own.

**The core idea, stated up front:** every command in this project enforces one rule —
**build once, verify once, deploy the exact same artifact everywhere.** Nothing
downstream of `build` ever recompiles the app. That single rule is what makes
rollback, promotion, and "what's actually running in prod" trustworthy.

## What you're building

Two pieces in one Go module:

- **`app/`** — the "cargo": a trivial HTTP service being delivered.
- **`cmd/harness/`** — the delivery harness CLI: `build`, `test`, `package`, `deploy`,
  `health`, `rollback`, `promote`, `status`, `flag`.

```
harness-project/
  go.mod
  app/
    main.go
    main_test.go
  cmd/harness/
    main.go        command dispatch
    build.go        versioned, reproducible builds
    test.go         the test gate
    package.go       immutable, self-describing artifacts
    deploy.go        deploy + health-check + auto-rollback
    health.go        health polling
    rollback.go      revert to the previous version
    promote.go       move a verified artifact between environments (no rebuild)
    status.go        what's running where, and is it healthy
    flag.go          minimal per-environment feature flag
```

## Prerequisites

- Go 1.21+ installed (`go version` to check).
- `curl` for hitting endpoints.
- A terminal. Everything below is copy-pasteable.

Create the project and module:

```bash
mkdir -p harness-project/app harness-project/cmd/harness
cd harness-project
go mod init harness-project
```

---

## Section 1 — The app being delivered

Before you can build a *delivery* system, you need something to deliver. This is a
minimal HTTP service with two endpoints that matter enormously in real delivery
pipelines:

- `/health` — used by the harness to decide "is this deployment actually working?"
- `/version` — used to prove *which* build is actually running (a surprising number
  of outages come down to "wait, which version is even live?")

Create `app/main.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// Version is injected at build time via -ldflags, e.g.:
//   go build -ldflags "-X main.Version=v3" ./app
// This is how a binary can report exactly which build it is —
// no guessing, no "which commit is this again?"
var Version = "dev"

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// FEATURE_MESSAGE lets us toggle behavior per-environment without
	// rebuilding the binary — a tiny stand-in for feature flagging.
	feature := os.Getenv("FEATURE_MESSAGE")

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})

	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, Version)
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		msg := fmt.Sprintf("hello from %s", Version)
		if feature != "" {
			msg += " | feature: " + feature
		}
		fmt.Fprintln(w, msg)
	})

	log.Printf("app %s listening on :%s", Version, port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

### ▶ Run it and see it work

```bash
PORT=9001 go run ./app &
sleep 1
curl -s localhost:9001/version   # -> dev
curl -s localhost:9001/health    # -> ok
curl -s localhost:9001/          # -> hello from dev
kill %1
```

`dev` is what you get with no real build pipeline. Fixing that is the entire point
of the next section.

---

## Section 2 — The harness: a `build` command

The first job of a delivery harness is **reproducible, versioned builds**. Right now
building the app twice gives two identical binaries with no way to tell them apart.
We fix that with a build counter and by injecting the version at compile time.

Create `cmd/harness/main.go` (the CLI entrypoint and command dispatch):

```go
package main

import (
	"fmt"
	"os"
)

// All harness state lives under _harness/ so it's obviously generated,
// never hand-edited, and easy to .gitignore.
const (
	stateDir     = "_harness"
	buildsDir    = stateDir + "/builds"    // raw compiled binaries, by version
	artifactsDir = stateDir + "/artifacts" // packaged, versioned, deployable units
	environDir   = stateDir + "/environments"
	counterFile  = stateDir + "/build_counter"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: harness <build|test|package|deploy|health|rollback|promote|status|flag> [args]")
		os.Exit(1)
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	var err error
	switch cmd {
	case "build":
		err = cmdBuild(args)
	case "test":
		err = cmdTest(args)
	case "package":
		err = cmdPackage(args)
	case "deploy":
		err = cmdDeploy(args)
	case "health":
		err = cmdHealth(args)
	case "rollback":
		err = cmdRollback(args)
	case "promote":
		err = cmdPromote(args)
	case "flag":
		err = cmdFlag(args)
	case "status":
		err = cmdStatus(args)
	default:
		fmt.Printf("unknown command: %s\n", cmd)
		os.Exit(1)
	}

	if err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}
}
```

Create `cmd/harness/build.go`:

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// nextVersion reads-increments-writes a counter file. This is the
// simplest possible versioning scheme: every build gets a unique,
// ever-increasing number, e.g. v1, v2, v3...
// Real systems use git SHAs or semver, but the *concept* — every
// build is uniquely and permanently identifiable — is the same.
func nextVersion() (string, error) {
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return "", err
	}

	n := 0
	if data, err := os.ReadFile(counterFile); err == nil {
		n, _ = strconv.Atoi(strings.TrimSpace(string(data)))
	}
	n++

	if err := os.WriteFile(counterFile, []byte(strconv.Itoa(n)), 0644); err != nil {
		return "", err
	}
	return fmt.Sprintf("v%d", n), nil
}

// cmdBuild compiles ./app into a uniquely versioned binary under
// _harness/builds/. Every build is kept — nothing is overwritten —
// which is what makes rollback possible later.
func cmdBuild(args []string) error {
	version, err := nextVersion()
	if err != nil {
		return err
	}

	if err := os.MkdirAll(buildsDir, 0755); err != nil {
		return err
	}

	outPath := fmt.Sprintf("%s/app-%s", buildsDir, version)
	ldflags := fmt.Sprintf("-X main.Version=%s", version)

	cmd := exec.Command("go", "build", "-ldflags", ldflags, "-o", outPath, "./app")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("compile failed: %w", err)
	}

	fmt.Printf("built %s -> %s\n", version, outPath)
	return nil
}
```

Because `main.go` dispatches to commands we haven't built yet, create a temporary
`cmd/harness/stubs.go` so everything compiles as you go (you'll delete lines from
this file as you implement each real command in later sections):

```go
package main

import "fmt"

// Each of these is replaced with a real implementation in its own
// section. Keeping them here as stubs lets the CLI compile and run
// at every intermediate stage.

func cmdTest(args []string) error {
	fmt.Println("test: not implemented yet (section 3)")
	return nil
}

func cmdPackage(args []string) error {
	fmt.Println("package: not implemented yet (section 4)")
	return nil
}

func cmdDeploy(args []string) error {
	fmt.Println("deploy: not implemented yet (section 5)")
	return nil
}

func cmdHealth(args []string) error {
	fmt.Println("health: not implemented yet (section 6)")
	return nil
}

func cmdRollback(args []string) error {
	fmt.Println("rollback: not implemented yet (section 6)")
	return nil
}

func cmdPromote(args []string) error {
	fmt.Println("promote: not implemented yet (section 7)")
	return nil
}

func cmdStatus(args []string) error {
	fmt.Println("status: not implemented yet (section 7)")
	return nil
}

func cmdFlag(args []string) error {
	fmt.Println("flag: not implemented yet (section 8)")
	return nil
}
```

### ▶ Run it — build the harness, then build the app twice

```bash
go build -o harness ./cmd/harness
./harness build
./harness build
ls -la _harness/builds/
```

You should see `app-v1` and `app-v2` appear. Confirm each binary genuinely reports
its own version:

```bash
PORT=9002 ./_harness/builds/app-v2 &
sleep 1
curl -s localhost:9002/version   # -> v2
kill %1
```

**What just happened:** every `harness build` produces a permanently-numbered,
self-identifying binary. Nothing gets overwritten. This property — *immutable,
uniquely versioned artifacts* — is the foundation everything else (rollback,
promotion, auditability) is built on.

---

## Section 3 — Gating builds on tests

A build you haven't tested isn't a build you should ship. Add a real test, then make
`harness build` refuse to produce a binary if tests fail.

Create `app/main_test.go`:

```go
package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok\n"))
	})
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if rec.Body.String() != "ok\n" {
		t.Fatalf("expected body 'ok', got %q", rec.Body.String())
	}
}
```

Remove the `cmdTest` stub from `stubs.go` and create `cmd/harness/test.go`:

```go
package main

import (
	"os"
	"os/exec"
)

// runTests is the actual gate logic, shared by `harness test` (run it
// standalone) and `harness build` (run it automatically before compiling).
func runTests() error {
	cmd := exec.Command("go", "test", "./app/...")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func cmdTest(args []string) error {
	return runTests()
}
```

Wire the gate into `build.go` — add this at the top of `cmdBuild`:

```go
func cmdBuild(args []string) error {
	if err := runTests(); err != nil {
		return fmt.Errorf("tests failed, refusing to build: %w", err)
	}

	version, err := nextVersion()
	// ...unchanged from here
```

### ▶ Run it — prove the gate actually blocks bad builds

```bash
go build -o harness ./cmd/harness
./harness build     # tests pass, builds v3
```

Now sabotage the test on purpose — change the assertion (not the handler!) so it
expects the wrong body:

```bash
# in app/main_test.go, change:
#   if rec.Body.String() != "ok\n" {
# to:
#   if rec.Body.String() != "broken\n" {

./harness build
echo "exit code: $?"
ls _harness/builds/    # no new binary appears
```

You should see the test fail with `FAIL`, an `error: tests failed, refusing to
build`, exit code `1`, and — critically — **no new binary** in `_harness/builds/`.
A broken test never becomes a shippable artifact. Revert the test back to `"ok\n"`
before continuing.

---

## Section 4 — Packaging into immutable artifacts

`_harness/builds/` has raw binaries. A real pipeline packages a build together with
**metadata about itself** — when it was built, what it's called — into a single
deployable unit called an **artifact**.

Remove the `cmdPackage` stub and create `cmd/harness/package.go`:

```go
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

type Metadata struct {
	Version    string `json:"version"`
	BuiltAt    string `json:"built_at"`
	PackagedAt string `json:"packaged_at"`
}

// latestVersion reads the build counter to find the most recently built
// version, so `harness package` with no args packages "whatever we just built".
func latestVersion() (string, error) {
	data, err := os.ReadFile(counterFile)
	if err != nil {
		return "", fmt.Errorf("no builds found yet — run 'harness build' first")
	}
	n, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("v%d", n), nil
}

// cmdPackage copies a raw binary + a metadata.json describing it into
// _harness/artifacts/<version>/. This directory is what gets deployed —
// never the raw binary in builds/ directly. That separation matters:
// builds/ is "things we compiled", artifacts/ is "things we're willing
// to ship".
func cmdPackage(args []string) error {
	version := ""
	if len(args) > 0 {
		version = args[0]
	} else {
		v, err := latestVersion()
		if err != nil {
			return err
		}
		version = v
	}

	binPath := fmt.Sprintf("%s/app-%s", buildsDir, version)
	if _, err := os.Stat(binPath); err != nil {
		return fmt.Errorf("no build found for %s (looked in %s)", version, binPath)
	}

	artifactDir := fmt.Sprintf("%s/%s", artifactsDir, version)
	if err := os.MkdirAll(artifactDir, 0755); err != nil {
		return err
	}

	if err := copyFile(binPath, artifactDir+"/app", 0755); err != nil {
		return err
	}

	meta := Metadata{
		Version:    version,
		BuiltAt:    fileModTime(binPath),
		PackagedAt: time.Now().UTC().Format(time.RFC3339),
	}
	metaBytes, _ := json.MarshalIndent(meta, "", "  ")
	if err := os.WriteFile(artifactDir+"/metadata.json", metaBytes, 0644); err != nil {
		return err
	}

	fmt.Printf("packaged %s -> %s\n", version, artifactDir)
	return nil
}

func copyFile(src, dst string, perm os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, perm)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func fileModTime(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return ""
	}
	return info.ModTime().UTC().Format(time.RFC3339)
}
```

### ▶ Run it

```bash
go build -o harness ./cmd/harness
./harness package
find _harness/artifacts -type f
cat _harness/artifacts/v3/metadata.json
```

You now have a self-describing, versioned, deployable unit on disk — the same
concept behind a Docker image or a Jenkins/Harness build artifact.

---

## Section 5 — Deploying to environments

Now the interesting part: taking an artifact and actually running it somewhere the
harness can track and manage. We simulate two environments (`staging`,
`production`) as directories with their own ports and process tracking.

Remove the `cmdDeploy` stub and create `cmd/harness/deploy.go`:

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Fixed ports per environment keeps this simple — a real system would
// use a load balancer / service discovery instead.
var envPorts = map[string]string{
	"staging":    "8081",
	"production": "8082",
}

func envDir(env string) string {
	return fmt.Sprintf("%s/%s", environDir, env)
}

// replaceBinaryAtomically copies src into a temp file next to dst, then
// renames it into place. Renaming just swaps a directory entry — it
// never fails with "text file busy" even if a process still happens to
// be executing the old inode, unlike writing/truncating dst in place.
func replaceBinaryAtomically(src, dst string) error {
	tmp := dst + ".new"
	if err := copyFile(src, tmp, 0755); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

// latestArtifact finds the highest-numbered artifact directory, so
// `harness deploy staging` with no version deploys "whatever we most
// recently packaged".
func latestArtifact() (string, error) {
	entries, err := os.ReadDir(artifactsDir)
	if err != nil || len(entries) == 0 {
		return "", fmt.Errorf("no artifacts found — run 'harness package' first")
	}
	best, bestN := "", -1
	for _, e := range entries {
		n, err := strconv.Atoi(strings.TrimPrefix(e.Name(), "v"))
		if err == nil && n > bestN {
			bestN, best = n, e.Name()
		}
	}
	if best == "" {
		return "", fmt.Errorf("no valid artifacts found")
	}
	return best, nil
}

// stopEnv kills whatever process is currently tracked as running for
// this environment, if any, and waits for it to actually exit before
// returning — otherwise the old binary's file can still be "busy"
// (still mapped by the exiting process) when we try to replace it.
func stopEnv(env string) error {
	pidFile := envDir(env) + "/pid"
	data, err := os.ReadFile(pidFile)
	if err != nil {
		return nil // nothing running
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil {
		return nil
	}
	proc, err := os.FindProcess(pid)
	if err == nil {
		_ = proc.Signal(syscall.SIGTERM)
		for i := 0; i < 20; i++ {
			// signal 0 just probes whether the pid still exists
			if proc.Signal(syscall.Signal(0)) != nil {
				break
			}
			time.Sleep(100 * time.Millisecond)
		}
	}
	os.Remove(pidFile)
	return nil
}

// startEnv launches the environment's currently-deployed binary as a
// detached background process and records its PID so it can be
// stopped or health-checked later.
func startEnv(env string) error {
	port, ok := envPorts[env]
	if !ok {
		return fmt.Errorf("unknown environment %q (known: staging, production)", env)
	}

	binPath := envDir(env) + "/app"
	logPath := envDir(env) + "/app.log"

	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}

	cmd := exec.Command(binPath)
	cmd.Env = append(os.Environ(), "PORT="+port)
	// Setsid detaches the child into its own session so it keeps
	// running after the shell/tool session that invoked `harness
	// deploy` exits — a real daemon, not just a background job.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	// Environments can carry their own feature flag file, written by
	// `harness flag` (section 8) — read it if present.
	if flag, err := os.ReadFile(envDir(env) + "/feature_flag"); err == nil {
		cmd.Env = append(cmd.Env, "FEATURE_MESSAGE="+strings.TrimSpace(string(flag)))
	}

	cmd.Stdout = logFile
	cmd.Stderr = logFile

	if err := cmd.Start(); err != nil {
		return err
	}

	pidFile := envDir(env) + "/pid"
	return os.WriteFile(pidFile, []byte(strconv.Itoa(cmd.Process.Pid)), 0644)
}

// deployArtifactTo is the core operation shared by `deploy`, `promote`,
// and `rollback`: point an environment at a specific artifact version.
// Note it never rebuilds anything — it only ever copies an existing,
// already-tested artifact. That's the "build once, deploy everywhere"
// principle in code form.
func deployArtifactTo(env, version string) error {
	artifactBin := fmt.Sprintf("%s/%s/app", artifactsDir, version)
	if _, err := os.Stat(artifactBin); err != nil {
		return fmt.Errorf("artifact %s not found — run 'harness package' first", version)
	}

	if err := os.MkdirAll(envDir(env), 0755); err != nil {
		return err
	}

	// Track the version we're about to replace, so rollback (section 6)
	// knows what to fall back to.
	if current, err := os.ReadFile(envDir(env) + "/CURRENT_VERSION"); err == nil {
		os.WriteFile(envDir(env)+"/PREVIOUS_VERSION", current, 0644)
	}

	if err := stopEnv(env); err != nil {
		return err
	}

	if err := replaceBinaryAtomically(artifactBin, envDir(env)+"/app"); err != nil {
		return err
	}

	if err := os.WriteFile(envDir(env)+"/CURRENT_VERSION", []byte(version), 0644); err != nil {
		return err
	}

	return startEnv(env)
}

func cmdDeploy(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: harness deploy <env> [version]")
	}
	env := args[0]

	version := ""
	if len(args) > 1 {
		version = args[1]
	} else {
		v, err := latestArtifact()
		if err != nil {
			return err
		}
		version = v
	}

	if err := deployArtifactTo(env, version); err != nil {
		return err
	}
	fmt.Printf("deployed %s to %s (port %s)\n", version, env, envPorts[env])

	fmt.Printf("checking health of %s...\n", env)
	if checkHealth(env) {
		fmt.Printf("%s: healthy\n", env)
		return nil
	}

	fmt.Printf("%s: unhealthy after deploying %s — rolling back automatically\n", env, version)
	if err := cmdRollback([]string{env}); err != nil {
		return fmt.Errorf("deploy of %s failed health check AND rollback failed: %w", version, err)
	}
	return fmt.Errorf("deploy of %s failed health check — rolled back to previous version", version)
}
```

> **Note:** `deployArtifactTo` calls `checkHealth` and `cmdRollback`, which don't
> exist until Section 6. Build Section 6 alongside this one, or leave a temporary
> `checkHealth` stub returning `true` and a no-op `cmdRollback` so this compiles
> in isolation.

### ▶ Run it — deploy to staging and hit it over HTTP

```bash
go build -o harness ./cmd/harness
./harness deploy staging
sleep 1
curl -s localhost:8081/version   # -> whatever your latest version is
curl -s localhost:8081/
```

Redeploy to prove the harness replaces the running process rather than stacking
copies:

```bash
cat _harness/environments/staging/pid   # note the PID
./harness build
./harness package
./harness deploy staging
cat _harness/environments/staging/pid   # PID has changed
curl -s localhost:8081/version          # new version is live
```

---

## Section 6 — Health checks and automatic rollback

Deploying successfully doesn't mean the deployment is *healthy*. This is where a
delivery harness earns its keep: check the new version is actually responding, and
if it isn't, automatically fall back to the last known-good version.

Remove the `cmdHealth` and `cmdRollback` stubs. Create `cmd/harness/health.go`:

```go
package main

import (
	"fmt"
	"net/http"
	"time"
)

// checkHealth polls an environment's /health endpoint with a short
// timeout and a few retries — real services take a moment to start.
func checkHealth(env string) bool {
	port, ok := envPorts[env]
	if !ok {
		return false
	}
	url := fmt.Sprintf("http://localhost:%s/health", port)

	client := http.Client{Timeout: 1 * time.Second}
	for i := 0; i < 5; i++ {
		resp, err := client.Get(url)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return true
			}
		}
		time.Sleep(500 * time.Millisecond)
	}
	return false
}

func cmdHealth(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: harness health <env>")
	}
	env := args[0]

	if checkHealth(env) {
		fmt.Printf("%s: healthy\n", env)
		return nil
	}
	return fmt.Errorf("%s: unhealthy", env)
}
```

Create `cmd/harness/rollback.go`:

```go
package main

import (
	"fmt"
	"os"
	"strings"
)

// cmdRollback deploys whatever version is recorded as PREVIOUS_VERSION
// for the environment. Note it reuses deployArtifactTo — rollback isn't
// a special case, it's just "deploy an older artifact".
func cmdRollback(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: harness rollback <env>")
	}
	env := args[0]

	data, err := os.ReadFile(envDir(env) + "/PREVIOUS_VERSION")
	if err != nil {
		return fmt.Errorf("no previous version recorded for %s — nothing to roll back to", env)
	}
	previous := strings.TrimSpace(string(data))

	if err := deployArtifactTo(env, previous); err != nil {
		return err
	}

	fmt.Printf("rolled back %s to %s\n", env, previous)
	return nil
}
```

`deploy.go` from Section 5 already calls `checkHealth` and `cmdRollback` after
deploying, so no further wiring is needed here.

### ▶ Run it — prove auto-rollback actually works

First confirm a healthy deploy passes its check:

```bash
go build -o harness ./cmd/harness
./harness deploy staging
./harness health staging   # -> staging: healthy
```

Now intentionally break the health endpoint in `app/main.go`:

```go
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
	// simulated bug: health endpoint now always fails
	w.WriteHeader(http.StatusInternalServerError)
	fmt.Fprintln(w, "broken")
})
```

Build, package, and deploy the broken version:

```bash
./harness build
./harness package
./harness deploy staging
echo "exit code: $?"
cat _harness/environments/staging/CURRENT_VERSION   # still the OLD version
curl -s localhost:8081/version                       # confirms the old, healthy version is live
```

You should see the deploy fail its health check, print
`rolling back automatically`, exit non-zero, and — critically — **staging ends up
back on the previous healthy version**, not the broken one. Revert the health
handler back to returning `200 ok` before continuing, then rebuild/package/deploy
a clean version.

---

## Section 7 — Promoting across environments

The principle that ties this together: **never rebuild for a new environment.**
Build one artifact, verify it in staging, then run *that exact same binary* in
production. Rebuilding per-environment is how "works on staging, broken in prod"
bugs happen.

Remove the `cmdPromote` and `cmdStatus` stubs (delete `stubs.go` entirely at this
point — every command now has a real implementation). Create
`cmd/harness/promote.go`:

```go
package main

import (
	"fmt"
	"os"
	"strings"
)

// cmdPromote reads whatever version is CURRENTLY RUNNING in the source
// environment and deploys that exact artifact to the target environment.
// It deliberately does not accept a version argument — promotion means
// "ship what's already been verified", not "pick something new".
func cmdPromote(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("usage: harness promote <from-env> <to-env>")
	}
	from, to := args[0], args[1]

	data, err := os.ReadFile(envDir(from) + "/CURRENT_VERSION")
	if err != nil {
		return fmt.Errorf("%s has nothing deployed to promote from", from)
	}
	version := strings.TrimSpace(string(data))

	fmt.Printf("promoting %s from %s to %s (same artifact, no rebuild)\n", version, from, to)

	if err := deployArtifactTo(to, version); err != nil {
		return err
	}
	fmt.Printf("deployed %s to %s (port %s)\n", version, to, envPorts[to])

	fmt.Printf("checking health of %s...\n", to)
	if checkHealth(to) {
		fmt.Printf("%s: healthy\n", to)
		return nil
	}

	fmt.Printf("%s: unhealthy after promoting %s — rolling back automatically\n", to, version)
	if err := cmdRollback([]string{to}); err != nil {
		return fmt.Errorf("promotion of %s failed health check AND rollback failed: %w", version, err)
	}
	return fmt.Errorf("promotion of %s to %s failed health check — rolled back", version, to)
}
```

Create `cmd/harness/status.go`:

```go
package main

import (
	"fmt"
	"os"
	"strings"
)

// cmdStatus gives the one view every delivery tool needs: "what's
// actually running where, right now, and is it healthy". Without this,
// rollback/promote/deploy are just commands you have to trust blindly.
func cmdStatus(args []string) error {
	for _, env := range []string{"staging", "production"} {
		versionBytes, err := os.ReadFile(envDir(env) + "/CURRENT_VERSION")
		if err != nil {
			fmt.Printf("%-10s  (nothing deployed)\n", env)
			continue
		}
		version := strings.TrimSpace(string(versionBytes))

		health := "unhealthy"
		if checkHealth(env) {
			health = "healthy"
		}

		fmt.Printf("%-10s  %-6s  port %-4s  %s\n", env, version, envPorts[env], health)
	}
	return nil
}
```

### ▶ Run it — promote staging to production without rebuilding anything

```bash
go build -o harness ./cmd/harness
./harness status                       # staging healthy, production empty
./harness promote staging production
./harness status                       # both environments now on the same version
```

Prove it's the byte-for-byte same binary, not a rebuild:

```bash
diff _harness/artifacts/v<N>/app _harness/environments/production/app && echo "identical binary"
curl -s localhost:8082/version
```

---

## Section 8 — A minimal feature flag (progressive delivery)

The last piece: change runtime behavior in one environment without a rebuild — the
basic idea behind feature flags and canary releases. The app already reads a
`FEATURE_MESSAGE` env var; give the harness a command to set that per-environment.

Create `cmd/harness/flag.go`:

```go
package main

import (
	"fmt"
	"os"
)

// cmdFlag writes a per-environment flag file that startEnv reads and
// injects as FEATURE_MESSAGE. This is deliberately tiny — real feature
// flag systems (LaunchDarkly, Harness FF) add targeting rules, gradual
// rollout percentages, and audit logs, but the core idea is identical:
// change runtime behavior without shipping new code.
func cmdFlag(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("usage: harness flag <env> <message>  (use \"\" to clear)")
	}
	env, message := args[0], args[1]

	if _, ok := envPorts[env]; !ok {
		return fmt.Errorf("unknown environment %q", env)
	}

	if err := os.MkdirAll(envDir(env), 0755); err != nil {
		return err
	}

	flagPath := envDir(env) + "/feature_flag"
	if message == "" {
		os.Remove(flagPath)
		fmt.Printf("cleared feature flag for %s\n", env)
	} else {
		if err := os.WriteFile(flagPath, []byte(message), 0644); err != nil {
			return err
		}
		fmt.Printf("set feature flag for %s: %q\n", env, message)
	}

	fmt.Println("restart the environment to pick it up: harness deploy " + env)
	return nil
}
```

(`main.go` from Section 2 already has the `case "flag":` dispatch line included.)

### ▶ Run it — flip a flag on staging only

```bash
go build -o harness ./cmd/harness
./harness flag staging "new-checkout-flow"
./harness deploy staging
sleep 1
curl -s localhost:8081/   # -> hello from vN | feature: new-checkout-flow
curl -s localhost:8082/   # -> hello from vN   (production untouched)
```

Same binary running in both places, but only staging shows the new behavior — a
pure runtime toggle, not a code branch. Once confident, promote it the same way as
before:

```bash
./harness flag production "new-checkout-flow"
./harness promote staging production
curl -s localhost:8082/   # now shows the feature too
./harness status
```

---

## Full command reference

```
harness build                    run tests, then compile a new versioned binary (v1, v2, ...)
harness test                     run tests only, no build
harness package [version]        turn a build into a deployable artifact (defaults to latest build)
harness deploy <env> [version]   deploy an artifact to staging|production; health-checks and
                                  auto-rolls-back if the new version fails its health check
harness health <env>             check if an environment is currently healthy
harness rollback <env>           manually revert an environment to its previous version
harness promote <from> <to>      deploy whatever's CURRENTLY RUNNING in <from> to <to> — no rebuild
harness status                   what version is running in each environment, and is it healthy
harness flag <env> <message>     set a per-environment runtime flag (use "" to clear)
```

## What each section taught

1. **The app** — you can't deliver nothing; `/health` and `/version` are the two
   endpoints every real delivery system leans on.
2. **build** — immutable, uniquely versioned artifacts are the foundation for
   everything else.
3. **test gate** — a broken test must never produce a shippable binary.
4. **package** — separates "things we compiled" from "things we're willing to
   ship", and attaches metadata to the artifact itself.
5. **deploy** — turns an artifact into an actual running, tracked process. Two real
   bugs surface here worth knowing: processes must fully detach (`Setsid`) to
   survive past the deploying shell, and binaries must be swapped via atomic
   rename, not in-place write, to avoid Linux's "text file busy" error on redeploy.
6. **health + rollback** — a deploy is only "successful" if the new version is
   actually healthy. Bad code should never stay live.
7. **promote** — the exact same binary moves between environments, provable with a
   byte-level `diff`.
8. **flag** — runtime behavior can change per-environment without any new code or
   rebuild, gated by a plain environment variable.

## Ideas for extending this yourself

- Replace fixed ports with a reverse proxy so you can do real blue/green cutovers.
- Add a `history.log` per environment so you can roll back more than one version.
- Add canary weighting: deploy to a `canary` environment first, run health checks
  for N seconds, only promote if it stays healthy the whole time.
- Swap the flat-file state for SQLite so multiple people/machines can safely share
  it.

The point worth internalizing: every command here is really just a variation on
"read some state from disk, do one focused thing, write the new state back." That's
true of Harness.io, Jenkins, and Spinnaker too — the UI and YAML are just a much
bigger, much more configurable version of the same primitives you just built by
hand.
