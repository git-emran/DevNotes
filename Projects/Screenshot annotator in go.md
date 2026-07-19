# Screenshot Annotator — Full Build Guide (Go + Wails + TypeScript)

 This is the whole project, built in the order you'd actually write it, with complete code at every step — not fragments. Type it in as you go (or copy it, then read *why* it's written that way — the "key things to remember" callouts are the part that actually teaches you something).

 Scope for this build: capture full screen → draw arrow / rectangle / freehand / text / blur → undo/redo → export to PNG. Tray icon and global hotkey are called out at the end as a deliberate "extend after this works" step — bolting them on before the core loop is solid just gives you two sets of bugs at once.

 ---

 ## Step 0 — Prerequisites

 ```bash
go version        # 1.21+
node -v            # 18+
go install github.com/wailsapp/wails/v2/cmd/wails@latest
wails doctor       # fix anything it flags before continuing
```

 **Key thing to remember:** `wails doctor` checks OS-specific requirements (WebView2 on Windows, Xcode CLI tools on macOS). Skipping it means your first build failure looks like a code bug when it's actually a missing system dependency — always rule this out first.

 ---

 ## Step 1 — Scaffold and full folder structure

 ```bash
wails init -n screenshot-annotator -t vanilla-ts
cd screenshot-annotator
```

 Target structure — create these now so you're not restructuring mid-build:

 ```
screenshot-annotator/
├── main.go
├── app.go
├── internal/
│   ├── capture/capture.go
│   ├── export/export.go
│   └── config/config.go
├── frontend/
│   ├── index.html
│   ├── src/
│   │   ├── main.ts
│   │   ├── style.css
│   │   ├── state/store.ts
│   │   ├── canvas/shapes.ts
│   │   ├── canvas/layers.ts
│   │   └── canvas/history.ts
│   └── wailsjs/            # auto-generated — never hand-edit
└── go.mod
```

 **Key thing to remember:** `internal/` packages take and return plain Go types — no Wails-specific code inside them. `app.go` is the *only* file that binds them to the frontend. This is what lets you test `capture.CaptureFullScreen()` with a plain `go test`, with zero webview involved.

 ---

 ## Step 2 — Backend: capture

 ```bash
go get github.com/kbinani/screenshot
```

 **`internal/capture/capture.go`**

 ```go
package capture

import (
	"bytes"
	"encoding/base64"
	"errors"
	"image"
	"image/png"

	"github.com/kbinani/screenshot"
)

// FullScreen grabs display 0 and returns it as a base64-encoded PNG string,
// ready to hand straight to the frontend across the Wails bridge.
func FullScreen() (string, error) {
	n := screenshot.NumActiveDisplays()
	if n == 0 {
		return "", errors.New("no active displays found")
	}

	bounds := screenshot.GetDisplayBounds(0)
	img, err := screenshot.CaptureRect(bounds)
	if err != nil {
		return "", err
	}

	if isBlank(img) {
		return "", errors.New("captured image is blank — check screen recording permission")
	}

	return encodeBase64PNG(img)
}

func encodeBase64PNG(img image.Image) (string, error) {
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

// isBlank is a cheap heuristic: sample a handful of pixels and check if
// they're all pure black, which is the classic signature of a macOS
// Screen Recording permission failure rather than a genuinely black screen.
func isBlank(img image.Image) bool {
	b := img.Bounds()
	samples := 0
	blackCount := 0
	for x := b.Min.X; x < b.Max.X; x += b.Dx() / 10 {
		for y := b.Min.Y; y < b.Max.Y; y += b.Dy() / 10 {
			r, g, bl, _ := img.At(x, y).RGBA()
			samples++
			if r == 0 && g == 0 && bl == 0 {
				blackCount++
			}
		}
	}
	return samples > 0 && blackCount == samples
}
```

 **Key things to remember:**

 - **The `isBlank` check is not paranoia — it's the single most common support issue this kind of app has.** On macOS without Screen Recording permission granted, `CaptureRect` doesn't error, it just silently hands you an all-black image. Catching that here means you can show the user a real message instead of a black screenshot they'll assume is a bug in your app.
- Returning base64 directly from this function (instead of an `image.Image`) keeps the Wails-bridge concern out of `app.go`'s hands but still leaves `capture` package dependency-free from Wails itself — a reasonable middle ground for a project this size.

 ### Unit test: `internal/capture/capture_test.go`

 `FullScreen()` itself talks to real hardware (an actual display) — that's exactly the kind of thing you *don't* unit test directly. What you test is the pure logic wrapped around it: `isBlank`.

 ```go
package capture

import (
	"image"
	"image/color"
	"testing"
)

func TestIsBlank(t *testing.T) {
	tests := []struct {
		name string
		img  image.Image
		want bool
	}{
		{"all black", solidImage(color.Black), true},
		{"all white", solidImage(color.White), false},
		{"mixed", mixedImage(), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isBlank(tt.img); got != tt.want {
				t.Errorf("isBlank() = %v, want %v", got, tt.want)
			}
		})
	}
}

func solidImage(c color.Color) image.Image {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for x := 0; x < 100; x++ {
		for y := 0; y < 100; y++ {
			img.Set(x, y, c)
		}
	}
	return img
}

func mixedImage() image.Image {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for x := 0; x < 100; x++ {
		for y := 0; y < 100; y++ {
			if x < 50 {
				img.Set(x, y, color.Black)
			} else {
				img.Set(x, y, color.White)
			}
		}
	}
	return img
}
```

 **Key thing to remember:** this is the general pattern for testing anything that touches hardware or the OS — wrap the OS call as thinly as possible (`FullScreen` is barely more than a call to `screenshot.CaptureRect`), and put your actual test effort into the logic that surrounds it (`isBlank`). You're not testing "can Go take a screenshot," you're testing "does our blank-detection heuristic correctly classify a black image vs a real one."

 **🏃 Run it now:**

 ```bash
go test ./internal/capture/... -v
```

 You should see `TestIsBlank` pass with all three subtests (`all_black`, `all_white`, `mixed`) reported individually — table-driven subtests like this show up as separate named results, which is exactly why the pattern is worth using even for a 3-case test.

 ---

 ## Step 3 — Backend: export

 **`internal/export/export.go`**

 ```go
package export

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// SavePNG decodes a base64 PNG data string and writes it to dir with a
// timestamped filename, returning the full path it wrote to.
func SavePNG(base64Data string, dir string) (string, error) {
	base64Data = strings.TrimPrefix(base64Data, "data:image/png;base64,")

	bytes, err := base64.StdEncoding.DecodeString(base64Data)
	if err != nil {
		return "", fmt.Errorf("invalid image data: %w", err)
	}

	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("couldn't create save folder: %w", err)
	}

	filename := fmt.Sprintf("screenshot-%s.png", time.Now().Format("2006-01-02-150405"))
	path := filepath.Join(dir, filename)

	if err := os.WriteFile(path, bytes, 0644); err != nil {
		return "", fmt.Errorf("couldn't write file: %w", err)
	}

	return path, nil
}
```

 **Key thing to remember:** every returned error here is already a sentence a user could read ("couldn't create save folder: …"), not a bare Go error. Wrap errors at the boundary where they're about to cross into a user-facing message — don't make the frontend guess what `mkdir: permission denied` means.

 ### Unit test: `internal/export/export_test.go`

 ```go
package export

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSavePNG(t *testing.T) {
	dir := t.TempDir()
	encoded := base64.StdEncoding.EncodeToString([]byte("fake-png-bytes"))

	path, err := SavePNG(encoded, dir)
	if err != nil {
		t.Fatalf("SavePNG returned error: %v", err)
	}
	if !strings.HasPrefix(filepath.Base(path), "screenshot-") {
		t.Errorf("filename %q doesn't have the expected prefix", filepath.Base(path))
	}
	if _, err := os.Stat(path); err != nil {
		t.Errorf("expected file to exist at %s: %v", path, err)
	}
}

func TestSavePNG_StripsDataURLPrefix(t *testing.T) {
	dir := t.TempDir()
	encoded := "data:image/png;base64," + base64.StdEncoding.EncodeToString([]byte("fake"))
	if _, err := SavePNG(encoded, dir); err != nil {
		t.Fatalf("expected the data-URL prefix to be stripped cleanly, got error: %v", err)
	}
}

func TestSavePNG_InvalidBase64(t *testing.T) {
	dir := t.TempDir()
	if _, err := SavePNG("not-valid-base64!!!", dir); err == nil {
		t.Error("expected an error for invalid base64 data, got nil")
	}
}
```

 **Key thing to remember:** `t.TempDir()` gives each test its own throwaway directory that Go cleans up automatically — never write test output into your real project folder or a hardcoded path. Notice the third test deliberately targets the *failure* path (garbage input), not just the happy path — that's the test that would actually catch a regression if someone later removed the error check in `SavePNG`.

 **🏃 Run it now:**

 ```bash
go test ./internal/export/... -v
```

 All three should pass. Then open your `t.TempDir()` concern from the other direction: add `t.Log(path)` temporarily inside `TestSavePNG` and run with `-v` — you'll see Go prints a fresh temp path per run, proving nothing is leaking into your real filesystem.

 ---

 ## Step 4 — Backend: settings persistence

 **`internal/config/config.go`**

 ```go
package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Settings struct {
	DefaultSaveDir  string `json:"defaultSaveDir"`
	LastColor       string `json:"lastColor"`
	LastStrokeWidth int    `json:"lastStrokeWidth"`
}

func defaults() Settings {
	home, _ := os.UserHomeDir()
	return Settings{
		DefaultSaveDir:  filepath.Join(home, "Pictures", "Screenshots"),
		LastColor:       "#ff3b30",
		LastStrokeWidth: 4,
	}
}

func path() (string, error) {
	dir, err := os.UserConfigDir() // ~/Library/Application Support, %AppData%, ~/.config
	if err != nil {
		return "", err
	}
	appDir := filepath.Join(dir, "screenshot-annotator")
	if err := os.MkdirAll(appDir, 0755); err != nil {
		return "", err
	}
	return filepath.Join(appDir, "settings.json"), nil
}

func Load() Settings {
	p, err := path()
	if err != nil {
		return defaults()
	}
	data, err := os.ReadFile(p)
	if err != nil {
		return defaults() // first run, no file yet — not an error
	}
	var s Settings
	if err := json.Unmarshal(data, &s); err != nil {
		return defaults()
	}
	return s
}

func Save(s Settings) error {
	p, err := path()
	if err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(p, data, 0644)
}
```

 **Key thing to remember:** `os.UserConfigDir()` resolves to the *correct* per-OS location automatically — never hardcode `~/.config`, that's Linux-only and wrong on macOS/Windows. A missing settings file on first run is expected behavior, not an error path — `Load()` should fall back to `defaults()` silently.

 ### Unit test: `internal/config/config_test.go`

 ```go
package config

import "testing"

func TestLoad_DefaultsWhenNoFile(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // isolate from your real settings.json
	s := Load()
	if s.DefaultSaveDir == "" {
		t.Error("expected a non-empty default save dir")
	}
	if s.LastStrokeWidth != 4 {
		t.Errorf("expected default stroke width 4, got %d", s.LastStrokeWidth)
	}
}

func TestSaveThenLoad_RoundTrips(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())

	want := Settings{DefaultSaveDir: "/tmp/whatever", LastColor: "#00ff00", LastStrokeWidth: 9}
	if err := Save(want); err != nil {
		t.Fatalf("Save returned error: %v", err)
	}

	got := Load()
	if got != want {
		t.Errorf("Load() = %+v, want %+v", got, want)
	}
}
```

 **Key thing to remember:** `t.Setenv("XDG_CONFIG_HOME", ...)` redirects `os.UserConfigDir()` for the duration of the test on Linux, and Go restores the real environment afterward automatically — this is what keeps the test suite from ever touching your actual settings file. Be aware this specific trick is Linux/CI-flavored: `os.UserConfigDir()` on macOS ignores `XDG_CONFIG_HOME` and always uses `~/Library/Application Support`. If you later run this suite on a Mac and want the same isolation, you'd override `$HOME` instead. Small platform detail, but exactly the kind of thing that quietly breaks a "works on my machine" test suite.

 **🏃 Run it now:**

 ```bash
go test ./internal/config/... -v
```

 Then run the whole backend test suite together for the first time:

 ```bash
go test ./... -v
```

 Three packages, all green, is your signal that the entire backend layer is correct in isolation — *before* you've wired a single line of frontend to it. This is worth pausing on: everything you've built so far works and is proven to work without a UI at all.

 ---

 ## Step 5 — Wire it together: `app.go` and `main.go`

 **`app.go`**

 ```go
package main

import (
	"context"

	"screenshot-annotator/internal/capture"
	"screenshot-annotator/internal/config"
	"screenshot-annotator/internal/export"
)

type App struct {
	ctx      context.Context
	settings config.Settings
}

func NewApp() *App {
	return &App{settings: config.Load()}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// --- Methods below are bound and callable directly from the frontend ---

func (a *App) CaptureFullScreen() (string, error) {
	return capture.FullScreen()
}

func (a *App) SaveImage(base64Data string) (string, error) {
	return export.SavePNG(base64Data, a.settings.DefaultSaveDir)
}

func (a *App) GetSettings() config.Settings {
	return a.settings
}

func (a *App) UpdateSettings(s config.Settings) error {
	a.settings = s
	return config.Save(s)
}
```

 **`main.go`**

 ```go
package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()

	err := wails.Run(&options.App{
		Title:  "Screenshot Annotator",
		Width:  1000,
		Height: 700,
		AssetServer: nil, // wails scaffolds this from `assets` — leave as generated
		OnStartup:  app.startup,
		Bind: []interface{}{
			app,
		},
	})
	if err != nil {
		println("Error:", err.Error())
	}
}
```

 **Key thing to remember:** everything on `App` that's meant to be called from TypeScript must be an **exported method with a capital letter** (`CaptureFullScreen`, not `captureFullScreen`) — this is the same Go export rule as always, but it's easy to trip on here because a lowercase method just silently isn't callable from the frontend, with no compile error to warn you.

 Run `wails generate module` (or just `wails dev`) and Wails will generate typed stubs in `frontend/wailsjs/go/main/App.ts` — that's what the frontend imports next.

 **🏃 Run it now — first real checkpoint:**

 ```bash
wails dev
```

 What you'll see: the default `vanilla-ts` scaffold page, not your app — you haven't touched the frontend yet, so that's expected. What actually matters here isn't what's on screen, it's confirming two things silently happened correctly:

 1. The build didn't error — your Go backend, `internal/` packages, and `app.go` all compile together cleanly.
2. Open `frontend/wailsjs/go/main/App.ts` (auto-generated, don't edit it) and confirm you see typed exports for `CaptureFullScreen`, `SaveImage`, `GetSettings`, and `UpdateSettings`.

 If any of your four methods is missing from that generated file, stop and go back to `app.go` — it's almost always the capital-letter export rule from the callout above. Catching this now, before any frontend code references these functions, saves you from a confusing import error three steps from now that looks like a frontend bug but isn't one.

 ---

 ## Step 6 — Frontend: shape data model

 This is the core architectural decision on the frontend side: **annotations are data, rendered fresh every time — never baked into pixels until final export.** Everything else follows from this.

 **`frontend/src/canvas/shapes.ts`**

 ```ts
export type Point = { x: number; y: number };

export type Shape =
  | { type: 'arrow'; from: Point; to: Point; color: string; width: number }
  | { type: 'rect'; from: Point; to: Point; color: string; width: number }
  | { type: 'freehand'; points: Point[]; color: string; width: number }
  | { type: 'text'; position: Point; content: string; color: string; fontSize: number }
  | { type: 'blur'; from: Point; to: Point };

export function drawShape(ctx: CanvasRenderingContext2D, shape: Shape, sourceImage?: CanvasImageSource) {
  switch (shape.type) {
    case 'arrow': return drawArrow(ctx, shape);
    case 'rect': return drawRect(ctx, shape);
    case 'freehand': return drawFreehand(ctx, shape);
    case 'text': return drawText(ctx, shape);
    case 'blur': return sourceImage && drawBlur(ctx, shape, sourceImage);
  }
}

function drawArrow(ctx: CanvasRenderingContext2D, s: Extract<Shape, { type: 'arrow' }>) {
  const headLength = Math.max(10, s.width * 3);
  const angle = Math.atan2(s.to.y - s.from.y, s.to.x - s.from.x);

  ctx.strokeStyle = s.color;
  ctx.lineWidth = s.width;
  ctx.lineCap = 'round';

  ctx.beginPath();
  ctx.moveTo(s.from.x, s.from.y);
  ctx.lineTo(s.to.x, s.to.y);
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(s.to.x, s.to.y);
  ctx.lineTo(s.to.x - headLength * Math.cos(angle - Math.PI / 6), s.to.y - headLength * Math.sin(angle - Math.PI / 6));
  ctx.moveTo(s.to.x, s.to.y);
  ctx.lineTo(s.to.x - headLength * Math.cos(angle + Math.PI / 6), s.to.y - headLength * Math.sin(angle + Math.PI / 6));
  ctx.stroke();
}

function drawRect(ctx: CanvasRenderingContext2D, s: Extract<Shape, { type: 'rect' }>) {
  ctx.strokeStyle = s.color;
  ctx.lineWidth = s.width;
  const w = s.to.x - s.from.x;
  const h = s.to.y - s.from.y;
  ctx.strokeRect(s.from.x, s.from.y, w, h);
}

function drawFreehand(ctx: CanvasRenderingContext2D, s: Extract<Shape, { type: 'freehand' }>) {
  if (s.points.length < 2) return;
  ctx.strokeStyle = s.color;
  ctx.lineWidth = s.width;
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(s.points[0].x, s.points[0].y);
  for (const p of s.points.slice(1)) ctx.lineTo(p.x, p.y);
  ctx.stroke();
}

function drawText(ctx: CanvasRenderingContext2D, s: Extract<Shape, { type: 'text' }>) {
  ctx.fillStyle = s.color;
  ctx.font = `${s.fontSize}px -apple-system, sans-serif`;
  ctx.textBaseline = 'top';
  ctx.fillText(s.content, s.position.x, s.position.y);
}

// Pixelation: sample the region from the ORIGINAL screenshot (sourceImage),
// downscale hard, then scale back up with smoothing off. Re-sampling the
// source each render (instead of caching blurred pixels) is what keeps this
// shape draggable/undoable like everything else.
function drawBlur(ctx: CanvasRenderingContext2D, s: Extract<Shape, { type: 'blur' }>, sourceImage: CanvasImageSource) {
  const x = Math.min(s.from.x, s.to.x);
  const y = Math.min(s.from.y, s.to.y);
  const w = Math.abs(s.to.x - s.from.x);
  const h = Math.abs(s.to.y - s.from.y);
  if (w < 1 || h < 1) return;

  const scale = 0.08;
  const tmp = document.createElement('canvas');
  tmp.width = Math.max(1, w * scale);
  tmp.height = Math.max(1, h * scale);
  const tctx = tmp.getContext('2d')!;
  tctx.drawImage(sourceImage, x, y, w, h, 0, 0, tmp.width, tmp.height);

  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(tmp, 0, 0, tmp.width, tmp.height, x, y, w, h);
  ctx.imageSmoothingEnabled = true;
}
```

 **Key thing to remember:** the `blur` shape doesn't store pixels — it stores a rectangle and re-samples the original screenshot every render. That's 4 lines of real pixelation logic, and it's the single most-used feature in any screenshot tool (redacting emails, keys, faces) — worth understanding this snippet fully rather than treating it as a black box.

 ### Frontend test setup + unit test: `frontend/src/canvas/shapes.test.ts`

 ```bash
cd frontend
npm install -D vitest
```

 Add to `frontend/package.json`:

 ```json
"scripts": {
  "test": "vitest run"
}
```

 `shapes.ts` is pure logic (given a context and a shape, call the right drawing calls) — no real `<canvas>` needed to test it, just a mock object that records what was called on it.

 ```ts
import { describe, it, expect, vi } from 'vitest';
import { drawShape } from './shapes';

function mockCtx() {
  return {
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    stroke: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    drawImage: vi.fn(),
    strokeStyle: '', fillStyle: '', lineWidth: 0,
    lineCap: '', lineJoin: '', font: '', textBaseline: '',
    imageSmoothingEnabled: true,
  } as unknown as CanvasRenderingContext2D;
}

describe('drawShape', () => {
  it('draws an arrow as a shaft plus a two-stroke arrowhead', () => {
    const ctx = mockCtx();
    drawShape(ctx, { type: 'arrow', from: { x: 0, y: 0 }, to: { x: 10, y: 0 }, color: '#fff', width: 2 });
    expect(ctx.stroke).toHaveBeenCalledTimes(2);
  });

  it('draws a rect with a single strokeRect call', () => {
    const ctx = mockCtx();
    drawShape(ctx, { type: 'rect', from: { x: 0, y: 0 }, to: { x: 5, y: 5 }, color: '#fff', width: 2 });
    expect(ctx.strokeRect).toHaveBeenCalledWith(0, 0, 5, 5);
  });

  it('skips freehand shapes with fewer than 2 points', () => {
    const ctx = mockCtx();
    drawShape(ctx, { type: 'freehand', points: [{ x: 0, y: 0 }], color: '#fff', width: 2 });
    expect(ctx.stroke).not.toHaveBeenCalled();
  });

  it('renders text via fillText at the given position', () => {
    const ctx = mockCtx();
    drawShape(ctx, { type: 'text', position: { x: 1, y: 1 }, content: 'hi', color: '#fff', fontSize: 12 });
    expect(ctx.fillText).toHaveBeenCalledWith('hi', 1, 1);
  });
});
```

 **Key thing to remember:** mocking the canvas context instead of pulling in `jsdom` + a real canvas polyfill is a deliberate scope decision — these tests confirm "did we call the right drawing primitives with the right arguments," not "does the pixel output look correct." That split is usually the right one: logic bugs (wrong arguments, wrong call count) belong in unit tests; visual correctness you confirm by eye, which is exactly what the run-it-now checkpoint at the end of Step 11 is for.

 **🏃 Run it now:**

 ```bash
npx vitest run src/canvas/shapes.test.ts
```

 Four passing tests confirms your shape-drawing logic is correct *before* it's wired to real mouse events — the same "prove the layer works in isolation" discipline you used on the Go side in Step 5.

 ---

 ## Step 7 — Frontend: undo/redo history

 **`frontend/src/canvas/history.ts`**

 ```ts
import type { Shape } from './shapes';

export class History {
  private past: Shape[][] = [];
  private future: Shape[][] = [];

  constructor(private onChange: (shapes: Shape[]) => void) {}

  commit(shapes: Shape[]) {
    this.past.push(structuredClone(shapes));
    this.future = []; // any new action invalidates redo history
  }

  undo(current: Shape[]): Shape[] {
    if (this.past.length === 0) return current;
    this.future.push(structuredClone(current));
    return this.past.pop()!;
  }

  redo(current: Shape[]): Shape[] {
    if (this.future.length === 0) return current;
    this.past.push(structuredClone(current));
    return this.future.pop()!;
  }
}
```

 **Key thing to remember:** `commit()` is called *before* a mutation (snapshotting what the state looked like beforehand), and any new action clears `future` — this is the standard undo/redo contract. Doing a new action after an undo should discard the redo branch, exactly like every text editor you've ever used; getting this backwards is the classic undo/redo bug.

 ### Unit test: `frontend/src/canvas/history.test.ts`

 This is the one worth testing carefully, precisely because the undo/redo contract is easy to get subtly wrong.

 ```ts
import { describe, it, expect } from 'vitest';
import { History } from './history';
import type { Shape } from './shapes';

const shape = (id: number): Shape => ({ type: 'rect', from: { x: id, y: 0 }, to: { x: id, y: 1 }, color: '#fff', width: 1 });

describe('History', () => {
  it('undo restores the previous snapshot', () => {
    const h = new History(() => {});
    let shapes: Shape[] = [];
    h.commit(shapes);
    shapes = [shape(1)];
    expect(h.undo(shapes)).toEqual([]);
  });

  it('redo re-applies an undone change', () => {
    const h = new History(() => {});
    let shapes: Shape[] = [];
    h.commit(shapes);
    shapes = [shape(1)];
    const afterUndo = h.undo(shapes);
    expect(h.redo(afterUndo)).toEqual([shape(1)]);
  });

  it('a new commit after an undo discards the redo branch', () => {
    const h = new History(() => {});
    let shapes: Shape[] = [];
    h.commit(shapes);
    shapes = [shape(1)];
    shapes = h.undo(shapes);   // future now holds [shape(1)]
    h.commit(shapes);          // a new action — this should clear future
    shapes = [shape(2)];
    expect(h.redo(shapes)).toEqual([shape(2)]); // nothing left to redo, so unchanged
  });
});
```

 **Key thing to remember:** that third test is the one that actually matters. It directly encodes the "new action clears the redo branch" rule from the callout above — if you ever refactor `History` and this test starts passing when redo *shouldn't* still work, that's a genuine regression, not a flaky test. This is the difference between a test that just confirms code runs and a test that actually protects a behavioral contract.

 **🏃 Run it now:**

 ```bash
npx vitest run src/canvas/history.test.ts
```

 Or run everything together going forward:

 ```bash
npx vitest run
```

 Two test files, seven total cases, all green — your entire non-UI logic layer (Go backend + shape drawing + undo/redo) is now proven correct before you've clicked a single button in the actual app.

 ---

 ## Step 8 — Frontend: state store, tying shapes + history together

 **`frontend/src/state/store.ts`**

 ```ts
import type { Shape } from '../canvas/shapes';
import { History } from '../canvas/history';

export type Tool = 'select' | 'arrow' | 'rect' | 'freehand' | 'text' | 'blur';

class Store {
  shapes: Shape[] = [];
  activeTool: Tool = 'arrow';
  color = '#ff3b30';
  strokeWidth = 4;
  screenshotBase64 = '';

  private listeners: Array<() => void> = [];
  private history = new History(() => {});

  subscribe(fn: () => void) {
    this.listeners.push(fn);
  }

  private notify() {
    this.listeners.forEach((fn) => fn());
  }

  addShape(shape: Shape) {
    this.history.commit(this.shapes);
    this.shapes = [...this.shapes, shape];
    this.notify();
  }

  undo() {
    this.shapes = this.history.undo(this.shapes);
    this.notify();
  }

  redo() {
    this.shapes = this.history.redo(this.shapes);
    this.notify();
  }

  setTool(tool: Tool) {
    this.activeTool = tool;
    this.notify();
  }

  setColor(color: string) {
    this.color = color;
    this.notify();
  }
}

export const store = new Store();
```

 **Key thing to remember:** this is a deliberately tiny hand-rolled store (subscribe/notify), not Redux/Zustand — for a project this size a full state library is overhead you don't need. Recognize *why* it's this small: one file, ~40 lines, does the job. Reaching for a framework here would be the wrong instinct, not the disciplined one.

 ---

 ## Step 9 — Frontend: canvas layers (screenshot + annotations, mouse handling)

 **`frontend/src/canvas/layers.ts`**

 ```ts
import { store } from '../state/store';
import { drawShape, type Point, type Shape } from './shapes';

export function initCanvases(baseCanvas: HTMLCanvasElement, annotationCanvas: HTMLCanvasElement) {
  const baseCtx = baseCanvas.getContext('2d')!;
  const annoCtx = annotationCanvas.getContext('2d')!;
  const image = new Image();

  let drawing = false;
  let start: Point | null = null;
  let livePoints: Point[] = []; // for freehand

  function loadScreenshot(base64: string) {
    image.onload = () => {
      baseCanvas.width = annotationCanvas.width = image.width;
      baseCanvas.height = annotationCanvas.height = image.height;
      baseCtx.drawImage(image, 0, 0);
      render();
    };
    image.src = `data:image/png;base64,${base64}`;
  }

  function render(preview?: Shape) {
    annoCtx.clearRect(0, 0, annotationCanvas.width, annotationCanvas.height);
    for (const shape of store.shapes) drawShape(annoCtx, shape, image);
    if (preview) drawShape(annoCtx, preview, image);
  }

  function pointFromEvent(e: MouseEvent): Point {
    const rect = annotationCanvas.getBoundingClientRect();
    // scale from CSS-displayed size back to the canvas's actual pixel
    // dimensions — these differ whenever the canvas is styled to a
    // different size than image.width/height, which HiDPI displays do.
    const scaleX = annotationCanvas.width / rect.width;
    const scaleY = annotationCanvas.height / rect.height;
    return { x: (e.clientX - rect.left) * scaleX, y: (e.clientY - rect.top) * scaleY };
  }

  annotationCanvas.addEventListener('mousedown', (e) => {
    if (store.activeTool === 'select') return;
    drawing = true;
    start = pointFromEvent(e);
    livePoints = [start];

    if (store.activeTool === 'text') {
      const content = prompt('Text:');
      drawing = false;
      if (content) store.addShape({ type: 'text', position: start, content, color: store.color, fontSize: 20 });
      render();
    }
  });

  annotationCanvas.addEventListener('mousemove', (e) => {
    if (!drawing || !start || store.activeTool === 'text') return;
    const point = pointFromEvent(e);

    if (store.activeTool === 'freehand') {
      livePoints.push(point);
      render({ type: 'freehand', points: livePoints, color: store.color, width: store.strokeWidth });
      return;
    }

    const preview = buildShape(store.activeTool, start, point);
    if (preview) render(preview);
  });

  annotationCanvas.addEventListener('mouseup', (e) => {
    if (!drawing || !start || store.activeTool === 'text') return;
    drawing = false;
    const point = pointFromEvent(e);

    const shape =
      store.activeTool === 'freehand'
        ? { type: 'freehand' as const, points: livePoints, color: store.color, width: store.strokeWidth }
        : buildShape(store.activeTool, start, point);

    if (shape) store.addShape(shape);
    start = null;
    render();
  });

  function buildShape(tool: string, from: Point, to: Point): Shape | null {
    switch (tool) {
      case 'arrow': return { type: 'arrow', from, to, color: store.color, width: store.strokeWidth };
      case 'rect': return { type: 'rect', from, to, color: store.color, width: store.strokeWidth };
      case 'blur': return { type: 'blur', from, to };
      default: return null;
    }
  }

  store.subscribe(() => render());

  return { loadScreenshot, getFlattenedPNG: () => flatten(baseCanvas, annotationCanvas) };
}

function flatten(base: HTMLCanvasElement, anno: HTMLCanvasElement): string {
  const out = document.createElement('canvas');
  out.width = base.width;
  out.height = base.height;
  const ctx = out.getContext('2d')!;
  ctx.drawImage(base, 0, 0);
  ctx.drawImage(anno, 0, 0);
  return out.toDataURL('image/png');
}
```

 **Key things to remember:**

 - **`render()` clears and redraws every shape, every time** — this looks wasteful but for a screenshot-sized canvas it's sub-millisecond, and it's what makes undo trivial (state changes → re-render, full stop). Don't be tempted to "optimize" this into incremental drawing until you've actually measured a real performance problem.
- **`pointFromEvent`'s scale correction is not optional.** If the canvas is ever styled to a CSS size different from its pixel `width`/`height` (which you'll do for responsive layout), raw `clientX/clientY` coordinates land in the wrong place on the actual pixel grid. This is the HiDPI/coordinate-system gotcha flagged back in Step 2 — this is where it actually bites you if you skip it.
- Committing to `store.shapes` only happens on `mouseup`, never during `mousemove` — the live preview is drawn separately and thrown away, so your undo history doesn't fill with every intermediate mouse position.

 ---

 ## Step 10 — Frontend: toolbar

 **`frontend/index.html`**

 ```html
<!doctype html>
<html>
<head><meta charset="UTF-8" /><link rel="stylesheet" href="src/style.css" /></head>
<body>
  <div id="toolbar">
    <button data-tool="arrow" class="tool active">Arrow</button>
    <button data-tool="rect" class="tool">Rect</button>
    <button data-tool="freehand" class="tool">Pen</button>
    <button data-tool="text" class="tool">Text</button>
    <button data-tool="blur" class="tool">Blur</button>
    <input type="color" id="colorPicker" value="#ff3b30" />
    <input type="range" id="widthPicker" min="1" max="20" value="4" />
    <button id="undoBtn">Undo</button>
    <button id="redoBtn">Redo</button>
    <button id="saveBtn">Save</button>
  </div>
  <div id="canvasStack">
    <canvas id="baseCanvas"></canvas>
    <canvas id="annotationCanvas"></canvas>
  </div>
  <script type="module" src="/src/main.ts"></script>
</body>
</html>
```

 **`frontend/src/style.css`**

 ```css
body { margin: 0; font-family: -apple-system, sans-serif; background: #1e1e1e; color: #eee; }
#toolbar { display: flex; gap: 8px; padding: 8px; background: #2a2a2a; align-items: center; }
.tool { padding: 6px 12px; background: #3a3a3a; border: none; color: #eee; border-radius: 6px; cursor: pointer; }
.tool.active { background: #0a84ff; }
#canvasStack { position: relative; }
#canvasStack canvas { position: absolute; top: 0; left: 0; max-width: 100%; }
```

 **`frontend/src/main.ts`**

 ```ts
import { store } from './state/store';
import { initCanvases } from './canvas/layers';
import { CaptureFullScreen, SaveImage } from '../wailsjs/go/main/App';

const baseCanvas = document.getElementById('baseCanvas') as HTMLCanvasElement;
const annoCanvas = document.getElementById('annotationCanvas') as HTMLCanvasElement;
const { loadScreenshot, getFlattenedPNG } = initCanvases(baseCanvas, annoCanvas);

// Capture on launch — replace with a "Capture" button/hotkey once the core loop works.
CaptureFullScreen().then((base64) => loadScreenshot(base64));

document.querySelectorAll<HTMLButtonElement>('.tool').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelector('.tool.active')?.classList.remove('active');
    btn.classList.add('active');
    store.setTool(btn.dataset.tool as any);
  });
});

document.getElementById('colorPicker')!.addEventListener('input', (e) => {
  store.setColor((e.target as HTMLInputElement).value);
});

document.getElementById('widthPicker')!.addEventListener('input', (e) => {
  store.strokeWidth = Number((e.target as HTMLInputElement).value);
});

document.getElementById('undoBtn')!.addEventListener('click', () => store.undo());
document.getElementById('redoBtn')!.addEventListener('click', () => store.redo());

document.getElementById('saveBtn')!.addEventListener('click', async () => {
  const dataUrl = getFlattenedPNG();
  const path = await SaveImage(dataUrl);
  alert(`Saved to ${path}`);
});

window.addEventListener('keydown', (e) => {
  const mod = e.metaKey || e.ctrlKey;
  if (mod && e.key === 'z' && !e.shiftKey) store.undo();
  if (mod && e.key === 'z' && e.shiftKey) store.redo();
  if (mod && e.key === 's') document.getElementById('saveBtn')!.click();
});
```

 **Key thing to remember:** `import { CaptureFullScreen, SaveImage } from '../wailsjs/go/main/App'` only exists after you've run `wails dev` or `wails generate module` at least once — that's Wails reading your `app.go` bound methods and generating matching typed TS stubs. If this import errors, that's your signal to go regenerate bindings, not a bug in this file.

 ---

 ## Step 11 — Run it, and actually watch it come alive

 Everything up to here has been backend + pure logic, each proven correct in isolation by its own test. This step wires it into the window and is the first time you'll *see* it work end to end.

 ```bash
wails dev
```

 Go through this sequence deliberately, in order — each item confirms a specific piece from earlier steps, not just "does it look okay":

 1. **Window opens, screenshot appears automatically.** This is `main.ts`'s `CaptureFullScreen().then(loadScreenshot)` from Step 10 firing on launch, which calls all the way down through `app.go` (Step 5) into `capture.FullScreen()` (Step 2). If you see a black canvas instead of your actual screen, that's the `isBlank` check from Step 2 doing its job — go grant Screen Recording permission (macOS) and relaunch.
2. **Click the Arrow tool, drag on the canvas, release.** You should see the shaft-plus-arrowhead shape from Step 6 appear, and it should stay exactly where you drew it (not jump) even if your display is HiDPI/Retina — that "doesn't jump" behavior is the coordinate scaling from Step 9 actually working, not a given.
3. **Press Cmd/Ctrl+Z.** The arrow should vanish. This is `store.undo()` (Step 8) calling into `History.undo()` (Step 7) — the same function your unit test exercised, now driven by a real keypress.
4. **Press Cmd/Ctrl+Shift+Z.** The arrow should reappear exactly as drawn. If it doesn't, or if it reappears in the wrong position, that's a real bug — go back to the `History` test from Step 7 and check whether it actually covers this path, since apparently something slipped through.
5. **Draw a second, different shape (say, a rectangle) right after undoing.** Then try redo again — it should do nothing, because the redo branch was discarded the moment you drew something new. This is exactly the third `History` test from Step 7, now happening via the UI instead of asserted in code.
6. **Switch to the Blur tool, drag over a piece of text or an icon on your real screenshot.** You should see it visibly pixelate — this confirms `drawBlur`'s re-sampling from the *original* screenshot (Step 6) is working, not just drawing a gray box.
7. **Resize the window, then draw a shape near the edge of the canvas.** If it lands in the wrong place, the scale correction in `pointFromEvent` (Step 9) has a bug — this is the single most common thing to get subtly wrong in this whole build, so don't skip this check.
8. **Press Cmd/Ctrl+S (or click Save).** You should get an alert with a file path. Open that file outside the app (Finder/Explorer) and confirm the arrow, rectangle, and blur you drew are all actually baked into the saved PNG — this proves `flatten()`'s two-canvas composite (Step 9) isn't silently dropping the annotation layer.

 If all eight land, the entire core loop — capture, draw, undo/redo, redact, export — is genuinely working, not just "looks like it probably works." That distinction is the whole point of testing each piece in isolation on the way here: by the time you got to this step, the only new thing being tested was the wiring itself, not the logic underneath it.

 ---

 ## What's deliberately not in this build

 - **Global hotkey + tray icon** — real, but genuinely separate cross-platform problems (`golang.design/x/hotkey` for the hotkey, `wails` tray support for the icon) that deserve their own focused pass once the drawing/export loop above is solid. Bolting them on now means debugging two unfamiliar APIs at once instead of one.
- **CI release pipeline, first-run permission modal, README** — these matter for shipping to other people, not for getting this working for yourself first. Once the above runs cleanly end to end, that's the natural next thing to add.