# README_EMRAN — Neovim repository structure + startup flow

Date: 2026-05-12. This file is intended for contributors who want a *map of the codebase* and a *precise startup flow* they can follow in code/debugger.

## What this guide covers

- Repository structure: what each folder is responsible for and where common changes belong.
- Control flow: which modules call which (at a subsystem level).
- A startup user-flow: from process start to the first visible UI.
- A full index of files, grouped by directory, so you can locate things quickly.

## Contribution compass (where to change what)

- Startup/config sourcing: `src/nvim/main.c`, `src/nvim/runtime.c`, `runtime/lua/vim/_core/*`
- Remote UI + UI events: `src/nvim/ui.*`, `src/nvim/api/ui.*`, `src/nvim/api/ui_events.in.h`
- TUI issues: `src/nvim/tui/*`
- API/RPC issues: `src/nvim/api/*`, `src/nvim/msgpack_rpc/*`, `src/nvim/channel.c`
- Vimscript language: `src/nvim/eval/*`
- Lua runtime behavior: `runtime/lua/vim/*`, `src/nvim/lua/*`
- Filetype/syntax/indent: `runtime/filetype.lua`, `runtime/ftplugin/`, `runtime/indent/`, `runtime/syntax/`
- Tests: `test/functional/`, `test/unit/`, docs in `runtime/doc/dev_test.txt`

## Key entrypoints (recommended reading order)


### Startup orchestration

- `src/nvim/main.c`
- `src/nvim/runtime.c`

### Event loop + async I/O

- `src/nvim/event/loop.c`
- `src/nvim/event/multiqueue.c`
- `src/nvim/event/proc.c`
- `src/nvim/event/rstream.c`
- `src/nvim/event/wstream.c`

### UI / rendering

- `src/nvim/ui.c`
- `src/nvim/ui_compositor.c`
- `src/nvim/drawscreen.c`
- `src/nvim/drawline.c`
- `src/nvim/grid.c`
- `src/nvim/tui/tui.c`

### Lua bridge + runtime

- `src/nvim/lua/executor.c`
- `src/nvim/lua/stdlib.c`
- `runtime/lua/vim/_core/defaults.lua`
- `runtime/lua/vim/_core/options.lua`

### API / RPC

- `src/nvim/api/ui.c`
- `src/nvim/msgpack_rpc/channel.c`
- `src/nvim/msgpack_rpc/server.c`

## Startup user-flow (what happens after `nvim` is launched)

This is the *actual* high-level control-flow implemented in `src/nvim/main.c`, with pointers to the relevant functions and their responsibilities.

### 0. Entry conditions (how startup mode is chosen)

Startup behavior is heavily affected by CLI flags and whether stdin/stdout/stderr are TTYs. Key modes:

- **Default interactive**: built-in TUI (terminal UI) is started if a terminal is present and `--headless/--embed/-es` are not used.
- **Headless**: `--headless` disables UIs; useful for automation and tests.
- **Embedded**: `--embed` makes stdin/stdout a msgpack-rpc channel so an external UI/client can drive Nvim.
- **Silent/batch**: `-es/-Es` disables most prompts and UI.

### 1. `main()` bootstraps params and does early scanning

File: `src/nvim/main.c`

- Validates `$NVIM_APPNAME`.
- Creates and initializes `mparm_T params` (startup parameters passed between stages).
- Detects `--clean` early (before full argument scan).

### 2. `event_init()` brings up core services

File: `src/nvim/main.c`

- Initializes the main `Loop main_loop` (event loop).
- Initializes environment (`env_init()`), autocmd/event system, signals, RPC channels, terminal core, UI core.

Why it matters: almost everything after this point assumes the event loop and queues exist.

### 3. `early_init()` creates the minimal editor world

File: `src/nvim/main.c`

Key responsibilities:

- Initializes eval globals and builtin tables (`eval_init()`, `init_normal_cmds()`).
- Initializes runtime path handling (`runtime_init()`, `init_path()`).
- Sets locale and creates the *first tabpage, window, and buffer* (`win_alloc_first()`).
- Initializes default highlights and the quickfix stack.

After this stage, Nvim has a core state (buffers/windows/options exist), but it has not yet sourced user config or loaded plugins.

### 4. CLI scan + argument expansion

File: `src/nvim/main.c`

- `command_line_scan(&params)` reads all options, fills the global arglist, sets mode flags.
- File arguments are expanded (wildcards, `--` handling, etc.).
- `nlua_init(...)` starts the embedded Lua interpreter.

### 5. UI selection and attachment

File: `src/nvim/main.c`

Decision points:

- If builtin TUI is needed, a UI client process/instance is started (`ui_client_start_server()`), then `ui_client_run()` takes over for the UI side.
- Otherwise Nvim continues as a server (headless/embedded/remote UI).
- In embedded-with-UI situations, Nvim may wait for a UI attach (`remote_ui_wait_for_attach()`) so early prompts/messages are visible.

### 6. Screen + option stage 2 init

File: `src/nvim/main.c`

- Establishes screen size (`win_init_size()`), allocates the default grid, initializes highlight groups, UI compositor, and runs `set_init_2(headless_mode)` for option initialization that depends on screen/UI state.

### 7. Pre-config commands, filetype/indent priming, and config sourcing

File: `src/nvim/main.c`

Order is intentionally subtle:

1. `exe_pre_commands(&params)` runs `--cmd` commands (before user config).
2. If `-u` is not `NONE` (or `--clean`), `filetype_plugin_enable()` sources baseline ftplugin + indent defaults *before* user startup scripts.
3. `source_startup_scripts(&params)` sources system and user startup scripts. This is where `init.lua`/`init.vim` discovery happens.
4. Then filetype and syntax are finalized (`filetype_maybe_enable()`, `syn_maybe_enable()`), allowing user init to disable them.

### 8. Plugin loading, buffers/windows, and post-config commands

File: `src/nvim/main.c`

- `load_plugins()` sources runtime plugins and packages.
- Buffers/windows are created based on CLI (`create_windows(&params)`) and autocmds begin firing (e.g. `BufEnter`).
- `exe_commands(&params)` runs `+cmd`, `-c cmd`, and `-S session` after config and the first file is available.
- `VimEnter` is fired; `UIEnter` for UI-attached cases.
- `normal_enter(...)` enters the main input loop.


## Repository structure (folder-by-folder)

This section is the *human guide*: what each folder is for, and how it interacts with others.


### `cmake/`

**Purpose**

CMake helper modules.


### `cmake.config/`

**Purpose**

CMake config definitions.


### `cmake.deps/`

**Purpose**

Subproject that fetches/builds dependencies.


### `cmake.packaging/`

**Purpose**

Packaging helpers for release artifacts.


### `contrib/`

**Purpose**

Contributor helpers (minimal configs, debug aids, templates).


### `deps/`

**Purpose**

Dependency-related sources/manifests used by build tooling.


### `runtime/`

**Purpose**

Runtime files shipped with Neovim (docs, plugins, Lua stdlib, ft/syntax).


**Runtime layering (important for contributors)**

- `runtime/doc/`: user + developer help docs (`:help`).
- `runtime/lua/vim/`: public Lua stdlib modules (lazy-loaded, user-facing).
- `runtime/lua/vim/_core/`: internal-only core Lua modules; some are compiled-in and required very early.
- `runtime/plugin/`: opt-out runtime plugins loaded on startup.
- `runtime/pack/`: opt-in packages (plugins) loaded by `:packadd` or by default dist packages.
- `runtime/ftplugin/`, `runtime/indent/`, `runtime/syntax/`: filetype behaviors and highlighting.
- `runtime/queries/`: Treesitter queries.


### `scripts/`

**Purpose**

Developer scripts (lint, generators, CI helpers).


### `src/`

**Purpose**

All sources (core + vendored components).


**Key conventions**

- Core C code is `src/nvim/` (the editor).
- Vendored components are other `src/*` directories; some are periodically synced from upstream.
- Neovim uses code generation: look for `*.in.h` inputs and `*.generated.*` outputs.


### `test/`

**Purpose**

Test suites and harness.


**Test taxonomy**

- `test/functional/`: end-to-end and integration-style tests (Lua).
- `test/unit/`: smaller unit tests (often C).
- `test/benchmark/`: performance checks.


### `build/`

**Purpose**

Generated build output (not source-of-truth).


**Note**

This directory is generated. Read it when debugging build issues, but avoid editing it in PRs.


## `src/nvim/` subsystems (who owns what)


### `src/nvim/api/`

**Purpose**

Public API (msgpack-rpc) and in-process API used by `vim.api`.

**What controls what**

- Remote clients (UIs, LSP tools, plugins) call API over msgpack-rpc.
- Lua `vim.api.*` uses the same API layer in-process with conversion glue in `src/nvim/lua/*`.

### `src/nvim/eval/`

**Purpose**

Vimscript engine: expressions, functions, variables, execution.

**What controls what**

- Ex commands call into eval for expression/function evaluation.
- Lua ↔ Vimscript bridging happens via typval conversion (`src/nvim/lua/converter.*`) and eval call helpers.

### `src/nvim/event/`

**Purpose**

Event loop subsystem (libuv-based): timers, job control, streams, multiqueue.

**What controls what**

- Most async work schedules callbacks onto `main_loop` queues.
- UI redraw notifications and RPC notifications are produced from events and processed in the main loop.

### `src/nvim/lua/`

**Purpose**

Embedded Lua interpreter integration (`vim` module, `vim.api`, schedulers, treesitter bindings).

**What controls what**

- `nlua_init()` sets up global state and registers the `vim` module.
- Core Lua modules under `runtime/lua/vim/_core/` are treated as internal and are loaded very early.

### `src/nvim/msgpack_rpc/`

**Purpose**

Msgpack-RPC transport: channels, server, request/notification dispatch.

**What controls what**

- UI clients attach via RPC and receive UI events.
- External clients use this for API access (`--listen`, `--embed`).

### `src/nvim/os/`

**Purpose**

Platform abstraction layer: filesystem, process, signals, clipboard, input, stdpaths.

**What controls what**

- Everything that touches the OS should prefer this layer over direct syscalls.

### `src/nvim/tui/`

**Purpose**

Built-in terminal UI (TUI): input decoding, screen paint, terminal capabilities.

**What controls what**

- Used when running interactively in a terminal without a remote UI.
- Talks to the core via UI events and input feeding.

### `src/nvim/viml/`

**Purpose**

VimL parsing and helpers (legacy language tooling).

**What controls what**

- Supports the Vimscript ecosystem; most execution is still in `eval/`.

### `src/nvim/vterm/`

**Purpose**

Terminal emulator used by `:terminal`.

**What controls what**

- `terminal.c` integrates this with buffers and UI.

### `src/nvim/lib/`

**Purpose**

Generic data structures/utilities used across subsystems.

**What controls what**

- Prefer these local utilities to avoid reinventing structures.

---

# README_EMRAN — Neovim maintenance blueprint

Date: 2026-05-12. This file is for contributors who want a *blueprint* of Neovim: subsystem boundaries, ownership, and the real startup/control flow.


## How to read this

Use this document in three modes:

1. **Orientation**: read *Architecture map* + *Startup pipeline*.
2. **Making a change**: jump to the subsystem section (UI, API, Lua, eval, …) and follow the *Change checklist*.
3. **Debugging**: use the *Control-flow maps* and the grep commands in *Navigation*.

Non-goal: enumerating every file. Use `rg`/`git grep` for discovery once you know the right subsystem.


## Architecture map (subsystems and responsibilities)

Think of Neovim as a few big layers:

- **Kernel/editor core (C)**: buffers/windows/state machine/options, redraw scheduling, event loop integration.
- **Language runtimes**: Vimscript (eval) + Lua (vim.* + builtin plugins).
- **UI transport**: internal UI events → either built-in TUI or remote UIs via msgpack-rpc.
- **Runtime (shipped files)**: docs, ft/syntax/indent, builtin plugins, Lua stdlib modules.

Subsystem boundaries that matter in practice:

- Startup orchestration: `src/nvim/main.c`
- UI/redraw: `src/nvim/ui.c`, `src/nvim/drawscreen.c`, `src/nvim/ui_compositor.c`, `src/nvim/tui/`
- API/RPC: `src/nvim/api/`, `src/nvim/msgpack_rpc/`, `src/nvim/channel.c`
- Vimscript eval: `src/nvim/eval/`, Ex commands: `src/nvim/ex_docmd.c`
- Lua integration: `src/nvim/lua/` + runtime Lua modules in `runtime/lua/vim/`
- Async/event loop: `src/nvim/event/` + OS glue in `src/nvim/os/`


## Startup pipeline (user-flow: `nvim` → first screen)

The canonical pipeline lives in `src/nvim/main.c`. Ordering is part of the contract: config sourcing, filetype/syntax enabling, and plugin loading depend on being in the right place.

### High-level phases

1. **Bootstrap parameters** (argv, env, `mparm_T`).
2. **Bring up core services** (event loop, autocmd, signals, channels, terminal, UI core).
3. **Create minimal editor world** (first tab/window/buffer, locale, runtime path).
4. **Parse CLI fully** and pick a startup mode (TUI vs headless vs embed).
5. **Initialize Lua** (so init.lua and runtime Lua modules can run).
6. **Initialize screen/grid** (so UI redraw has a target).
7. **Source config** (system init → user init → exrc if enabled).
8. **Enable filetype/syntax** (with deliberate ordering).
9. **Load runtime plugins**.
10. **Open buffers/windows** (files, splits, diff, quickfix).
11. **Fire VimEnter/UIEnter** and enter the main loop.

### Concrete sequence (functions you can trace)

- Entry: `main(argc, argv)`
- Core services: `event_init()` → `early_init(&params)`
- CLI parse: `command_line_scan(&params)`
- Lua: `nlua_init(argv, argc, params.lua_arg0)`
- UI selection: `ui_client_start_server(...)` + `ui_client_run()` (TUI path)
- Screen/grid: `win_init_size()` → `default_grid_alloc()` → `set_init_2(headless_mode)`
- Pre-config: `exe_pre_commands(&params)` (`--cmd`)
- ft/indent priming: `filetype_plugin_enable()` (before user startup scripts)
- Config: `source_startup_scripts(&params)` (system + user init discovery and sourcing)
- ft + syntax finalization: `filetype_maybe_enable()` then `syn_maybe_enable()`
- Plugins: `load_plugins()`
- Open buffers/windows: `create_windows(&params)`
- Enter: `apply_autocmds(EVENT_VIMENTER, ...)` → `do_autocmd_uienter_all()` → `normal_enter(...)`

### Visual overview (control flow)

```mermaid
flowchart TD
  A[main()] --> B[event_init] --> C[early_init]
  C --> D[command_line_scan]
  D --> E[nlua_init]
  E --> F{UI mode?}
  F -->|builtin TUI| G[ui_client_start_server] --> H[ui_client_run (client)]
  F -->|server/headless/embed| I[server_init + grid init]
  I --> J[--cmd] --> K[filetype_plugin_enable]
  K --> L[source_startup_scripts]
  L --> M[filetype_maybe_enable + syn_maybe_enable]
  M --> N[load_plugins]
  N --> O[create_windows]
  O --> P[VimEnter / UIEnter]
  P --> Q[normal_enter main loop]
```


## Subsystem blueprint: where to change what

Each subsystem section below has:

- **Owns**: responsibilities and boundaries
- **Key entrypoints**: files/functions to start reading
- **Control flow**: who calls into it
- **Change checklist**: how to contribute safely
- **Tests**: where to add coverage


### Startup + configuration sourcing

**Owns**

- Startup ordering and mode selection (TUI/headless/embed/silent).
- Discovery and sourcing of system/user init files (`init.lua`/`init.vim`) and exrc logic.
- Sequencing of `--cmd`, `-c`, `+cmd`, sessions, plugin load, VimEnter/UIEnter.

**Key entrypoints**

- `src/nvim/main.c` — Search for `source_startup_scripts`, `do_user_initialization`, `exe_pre_commands`, `load_plugins`.
- `runtime/doc/starting.txt` — CLI and startup options reference.
- `runtime/doc/dev_arch.txt` — Architecture notes about runtime and Lua layering.

**Control flow notes**

- Everything flows from `main()` in `src/nvim/main.c`.
- Runtime sourcing is coordinated here, but file IO/runtimepath helpers live in `src/nvim/runtime.c`.

**Change checklist**

- State exactly where in the pipeline you are changing behavior (before/after user init, before/after plugins).
- Be careful with `-u NONE/NORC` and `--clean` interactions.
- Add a functional test that reproduces behavior with `nvim --clean` and with explicit `-u` where relevant.

**Tests**

- `test/functional/` for startup/config behavior (most changes should land here).

### UI + redraw pipeline (built-in + remote)

**Owns**

- UI attachment/detachment, UI events emission, redraw scheduling.
- Grid composition (multiple grids, floats, extmarks) and translation into UI redraw messages.
- Built-in TUI client implementation and transport to the core via RPC/channel.

**Key entrypoints**

- `src/nvim/ui.c` — UI attach, ui_call_* entrypoints, redraw notifications.
- `src/nvim/drawscreen.c` — When/why redraw happens, invalidation, update passes.
- `src/nvim/ui_compositor.c` — Grid stacking/composition.
- `src/nvim/api/ui.c` — UI event forwarding over RPC to remote UIs.
- `src/nvim/tui/tui.c` — Terminal UI client.

**Control flow notes**

- Editor core invalidates state → redraw is scheduled → drawscreen updates grids → ui layer emits redraw events.
- Remote UIs get the same UI events through msgpack-rpc (`api/ui.c`).

**Change checklist**

- Classify the issue first: invalidation bug vs compositor layering vs UI transport/encoding.
- Keep UI event shapes stable (remote UIs depend on them).
- Prefer adding UI-functional tests where possible; otherwise add focused unit tests for algorithms.

**Tests**

- `test/functional/ui/` (if present) and UI-related functional tests under `test/functional/`.

### API + msgpack-rpc (external clients and UIs)

**Owns**

- Public API surface (`nvim_*`), request/notification dispatch, encoding/decoding.
- Channels and RPC server lifecycle (`--listen`, `--embed`, UI clients).

**Key entrypoints**

- `src/nvim/api` — Start with `api.c` and the file relevant to your API area.
- `src/nvim/msgpack_rpc` — Channel/server dispatch and protocol framing.
- `src/nvim/channel.c` — Channel abstraction; stdio/job/socket channels.
- `runtime/doc/api.txt` — API documentation and conventions.

**Control flow notes**

- External client sends msgpack-rpc → msgpack_rpc dispatch → API implementation → updates core state → triggers UI events.

**Change checklist**

- Treat API changes as compatibility changes: document them and add tests.
- When adding UI events, consider remote UI impact and metadata generation.
- Keep error handling consistent (use `Error` patterns in api layer).

**Tests**

- `test/functional/api/` (if present) and general functional tests for API behavior.

### Lua runtime integration (`vim.*`, builtin Lua)

**Owns**

- Lua interpreter lifecycle and bridging between C state and Lua state.
- `vim.api` bindings and typval conversions between Vimscript and Lua.
- Shipped Lua modules: internal core (`runtime/lua/vim/_core`) and public stdlib (`runtime/lua/vim`).

**Key entrypoints**

- `src/nvim/lua/executor.c` — Core: `nlua_init`, module loader, execution, scheduling.
- `src/nvim/lua/converter.c` — Typval <-> Lua conversions (when you see weird types).
- `runtime/doc/dev_arch.txt` — Lua layering rules: plugin vs stdlib vs core.
- `runtime/lua/vim/_core/defaults.lua` — Startup defaults set in Lua.

**Control flow notes**

- Startup initializes Lua (`nlua_init`) → core Lua modules can be required → user init.lua executes → plugins run.
- `vim.api` calls route into the C API layer (with fast-path optimizations in some cases).

**Change checklist**

- Decide if code belongs in a plugin (`runtime/plugin`), public stdlib (`runtime/lua/vim`), or core (`runtime/lua/vim/_core`).
- Avoid breaking `vim.*` public contracts; add tests for observable Lua API behaviors.
- Be mindful of thread/loop constraints (some core modules are main-thread only).

**Tests**

- `test/functional/lua/` (if present) and general functional tests that execute Lua code.

### Vimscript (eval) + Ex commands

**Owns**

- Expression evaluation, functions, variables, and Vimscript runtime semantics.
- Ex command parsing/execution (":set", ":autocmd", ":edit", …).

**Key entrypoints**

- `src/nvim/eval` — Language engine; start with higher-level files like `eval.c` then drill down.
- `src/nvim/ex_docmd.c` — Ex command parsing/execution pipeline.
- `src/nvim/eval/funcs.c` — Built-in functions.

**Control flow notes**

- User command → ex_docmd parses → dispatch to command implementation → eval called for expressions/functions.

**Change checklist**

- Assume compatibility constraints unless explicitly changing behavior.
- Add minimal reproducer tests (functional) for semantics changes.
- Avoid hidden global state changes; be careful with reentrancy via autocmds.

**Tests**

- Most behavior changes should be validated in `test/functional/`.

### Event loop + jobs + OS abstraction

**Owns**

- Async IO, timers, job control, streams, and scheduling work onto the main loop.
- OS-specific implementations (filesystem, processes, signals, stdpaths, input).

**Key entrypoints**

- `src/nvim/event` — Loop, multiqueue, proc, streams.
- `src/nvim/os` — Filesystem/process/signal/input abstractions.
- `src/nvim/main.c` — Teardown paths: `event_teardown()` is where shutdown order matters.

**Control flow notes**

- Async sources (jobs, RPC, UI input) enqueue events → processed on `main_loop` queues → mutate editor state → schedule redraw.

**Change checklist**

- Do not block the main loop; use async primitives and queues.
- Always consider teardown: ensure resources close cleanly on exit/restart.
- Add tests for racey behavior where feasible (often functional tests).

**Tests**

- `test/functional/` for job/RPC behavior; `test/unit/` for lower-level components.

## Common contribution recipes (quick routes)

These are fast pointers for common changes, optimized to reduce wandering:

- **Change startup ordering**: start at `src/nvim/main.c` and locate the phase you need (pre-cmd, config sourcing, plugins, create_windows).
- **Change default options**: check `runtime/lua/vim/_core/options.lua` and `src/nvim/option.c` interplay.
- **Change filetype detection**: `runtime/filetype.lua` (and tests).
- **Change a builtin plugin**: likely `runtime/plugin/` (opt-out) or `runtime/pack/dist/` (opt-in).
- **Change UI redraw behavior**: start at `drawscreen.c` (invalidation + update loop) then `ui.c`/`ui_compositor.c`.
- **Add API/UI event**: start at `src/nvim/api` and `src/nvim/api/ui_events.in.h` (generator-driven).


## Navigation: commands that work well in this repo

- Find a symbol: `rg -n "\bSYMBOL\b" src/nvim runtime`
- Find callsites: `rg -n "SYMBOL\(" src/nvim`
- Follow startup steps: `rg -n "source_startup_scripts\|load_plugins\|create_windows\|normal_enter" src/nvim/main.c`
- Find runtime sourcing: `rg -n "do_source\|:runtime\|runtimepath" src/nvim/runtime.c src/nvim/main.c`


## AI-assisted work

Neovim allows AI-assisted contributions, but you must review output carefully. If you commit changes and AI helped, add a commit trailer line: `AI-assisted: Codex` (per `AGENTS.md`).

