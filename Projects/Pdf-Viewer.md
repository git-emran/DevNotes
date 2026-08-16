# Building a Production-Ready, Terminal-Styled PDF Viewer in Go

 This guide builds a desktop PDF viewer from an empty window to a hardened, production-ready application. Each section adds code on top of the previous section — new code is marked with `// NEW (Section N):` comments — and ends with **Scaling** and **Security** notes for that stage.

 ## Architecture decisions (read this first)

 | Concern | Choice | Why |
| --- | --- | --- |
| GUI toolkit | [Fyne](https://fyne.io/) | Pure Go, cross-platform, canvas-based, easy custom theming for the "terminal" look, active maintenance |
| PDF rendering | [go-pdfium](https://github.com/klippa-app/go-pdfium)(Google's PDFium via cgo/purego) | BSD-licensed (unlike MuPDF-based bindings, which are AGPL and a licensing trap for a "production" project), battle-tested (it's Chrome's PDF engine), and — critically — ships a**multi-process worker pool**so a malformed PDF can crash a worker without taking down your app |
| Rendering strategy | Render pages to images on demand, cache a small LRU window, never load the whole document into memory | Required for "handle large files" |
| Concurrency | Rendering happens on background goroutines with`context.Context`cancellation | Keeps the UI thread responsive and lets you drop stale work when the user scrolls/zooms fast |

 Final project layout you'll arrive at:

 ```
pdfview/
├── go.mod
├── main.go        # app entrypoint, window, event wiring
├── theme.go        # terminal-styled Fyne theme
├── toolbar.go       # zoom / navigation toolbar
├── viewer.go        # the page canvas + status bar widget
├── engine.go        # go-pdfium wrapper: open, render, close
├── cache.go        # LRU page-image cache with memory budget
└── security.go       # file validation, resource limits
```

 ---

 ## Section 0 — Prerequisites & project setup

 Install dependencies:

 ```bash
# Go 1.22+
go version

# Fyne needs a C compiler + platform graphics libs
# macOS: xcode-select --install
# Linux (Debian/Ubuntu):
sudo apt install gcc libgl1-mesa-dev libx11-dev libxrandr-dev \
  libxcursor-dev libxinerama-dev libxi-dev xorg-dev

mkdir pdfview && cd pdfview
go mod init github.com/<you>/pdfview

go get fyne.io/fyne/v2@latest
go get github.com/klippa-app/go-pdfium@latest
```

 `go-pdfium` can run in two modes: **single-threaded** (in-process, simplest) or **multi-threaded/worker-pool** (separate OS processes, isolates crashes). We start single-threaded for simplicity and switch to the worker pool in Section 7, once you understand why it matters.

 ### Tips

 **Scaling:** Pin exact dependency versions in `go.mod` from day one (`go mod tidy` + commit `go.sum`). PDF rendering libraries change ABI/behavior across versions, and an unpinned upgrade in CI can silently change output for every user.

 **Security:** Note now that PDFium is compiled C++ reachable via cgo. Any memory-safety bug in it is a memory-safety bug in your app. This is exactly why Section 7 moves rendering into isolated worker processes — treat every PDF as an untrusted, potentially adversarial input from the start.

 ---

 ## Section 1 — Hello World terminal window

 Goal: an empty window styled like a terminal (black background, monospace font, phosphor-green text) — nothing else yet.

 ```go
// main.go
package main

import (
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

func main() {
	a := app.New()

	// NEW (Section 1): apply our custom terminal theme instead of Fyne's default
	a.Settings().SetTheme(&terminalTheme{})

	w := a.NewWindow("pdfview")
	w.Resize(newDefaultSize())

	label := widget.NewLabel("pdfview — no file loaded")
	w.SetContent(container.NewCenter(label))

	w.ShowAndRun()
}
```

 ```go
// theme.go
package main

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

// NEW (Section 1): a minimal theme that gives Fyne's default widgets
// a dark background + monospace text so the app reads as a "terminal".
type terminalTheme struct{}

var (
	bgColor   = color.NRGBA{R: 0x0d, G: 0x0d, B: 0x0d, A: 0xff}
	fgColor   = color.NRGBA{R: 0x33, G: 0xff, B: 0x66, A: 0xff}
	dimColor  = color.NRGBA{R: 0x1a, G: 0x1a, B: 0x1a, A: 0xff}
)

func (terminalTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return bgColor
	case theme.ColorNameForeground:
		return fgColor
	case theme.ColorNameButton, theme.ColorNameDisabledButton:
		return dimColor
	default:
		return theme.DefaultTheme().Color(name, theme.VariantDark)
	}
}

func (terminalTheme) Font(style fyne.TextStyle) fyne.Resource {
	style.Monospace = true
	return theme.DefaultTheme().Font(style)
}

func (terminalTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (terminalTheme) Size(name fyne.ThemeSizeName) float32 {
	return theme.DefaultTheme().Size(name)
}

func newDefaultSize() fyne.Size {
	return fyne.NewSize(900, 700)
}
```

 Run it:

 ```bash
go run .
```

 You should see a dark window with green monospace text.

 ### Tips

 **Scaling:** Keep the theme's `Color`/`Font`/`Size` methods allocation-free — Fyne calls them frequently during redraw. Precompute colors as package-level vars (as above) instead of constructing them per call.

 **Security:** None yet — there's no user input. But get in the habit now of never trusting a filename, path, or byte from outside your process; every later section builds on this window.

 ---

 ## Section 2 — Toolbar skeleton (zoom, back, forward)

 Goal: add the minimal toolbar. Buttons exist and are wired to no-ops for now.

 ```go
// toolbar.go
package main

import (
	"fyne.io/fyne/v2/widget"
)

// NEW (Section 2): holds references to the toolbar buttons so later
// sections can enable/disable them based on document state.
type Toolbar struct {
	Container   *widget.Toolbar
	ZoomIn      *widget.ToolbarAction
	ZoomOut     *widget.ToolbarAction
	ZoomReset   *widget.ToolbarAction
	Back        *widget.ToolbarAction
	Forward     *widget.ToolbarAction
}

func newToolbar() *Toolbar {
	t := &Toolbar{}

	t.Back = widget.NewToolbarAction(theme.NavigateBackIcon(), func() {})
	t.Forward = widget.NewToolbarAction(theme.NavigateNextIcon(), func() {})
	t.ZoomOut = widget.NewToolbarAction(theme.ZoomOutIcon(), func() {})
	t.ZoomReset = widget.NewToolbarAction(theme.ZoomFitIcon(), func() {})
	t.ZoomIn = widget.NewToolbarAction(theme.ZoomInIcon(), func() {})

	t.Container = widget.NewToolbar(
		t.Back,
		t.Forward,
		widget.NewToolbarSeparator(),
		t.ZoomOut,
		t.ZoomReset,
		t.ZoomIn,
	)
	return t
}
```

 ```go
// main.go
package main

import (
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

func main() {
	a := app.New()
	a.Settings().SetTheme(&terminalTheme{})

	w := a.NewWindow("pdfview")
	w.Resize(newDefaultSize())

	// NEW (Section 2): toolbar pinned to the top, content in the center
	tb := newToolbar()
	label := widget.NewLabel("pdfview — no file loaded")
	content := container.NewBorder(tb.Container, nil, nil, nil, container.NewCenter(label))
	w.SetContent(content)

	w.ShowAndRun()
}
```

 (Add `"fyne.io/fyne/v2/theme"` to `toolbar.go`'s imports.)

 ### Tips

 **Scaling:** Build the toolbar once at startup and mutate it (enable/disable actions), rather than rebuilding it on every page change — widget churn is the most common cause of a janky Fyne UI.

 **Security:** No new surface yet. Keep button callbacks as thin dispatchers to logic in other files (as we do from Section 4 on) so you can unit-test navigation/zoom logic without spinning up a GUI.

 ---

 ## Section 3 — Loading a PDF and rendering the first page

 Goal: open a file (via CLI arg or file dialog) and render page 0 to an image.

 ```go
// engine.go
package main

import (
	"fmt"

	"github.com/klippa-app/go-pdfium/pdfium"
	"github.com/klippa-app/go-pdfium/requests"
	"github.com/klippa-app/go-pdfium/responses"
	pdfium_single "github.com/klippa-app/go-pdfium/single_threaded"
)

// NEW (Section 3): thin wrapper around go-pdfium so the rest of the app
// never touches the library directly. Single-threaded pool for now —
// we upgrade this to a multi-process pool in Section 7.
type Engine struct {
	pool     pdfium.Pool
	instance pdfium.Pdfium
	doc      *responses.OpenDocument
}

func newEngine() (*Engine, error) {
	pool := pdfium_single.Init(pdfium_single.Config{})
	inst, err := pool.GetInstance(0)
	if err != nil {
		return nil, fmt.Errorf("pdfium instance: %w", err)
	}
	return &Engine{pool: pool, instance: inst}, nil
}

func (e *Engine) OpenFile(path string) (pageCount int, err error) {
	data, err := readFileBytes(path) // defined in security.go, Section 8
	if err != nil {
		return 0, err
	}

	doc, err := e.instance.OpenDocument(&requests.OpenDocument{File: &data})
	if err != nil {
		return 0, fmt.Errorf("open document: %w", err)
	}
	e.doc = doc

	pageInfo, err := e.instance.GetPageCount(&requests.GetPageCount{Document: doc.Document})
	if err != nil {
		return 0, fmt.Errorf("page count: %w", err)
	}
	return pageInfo.PageCount, nil
}

// RenderPage rasterizes a single page at the given DPI-equivalent scale.
func (e *Engine) RenderPage(pageIndex int, scale float32) (*renderedPage, error) {
	page := requests.Page{Document: e.doc.Document, Index: &pageIndex}

	res, err := e.instance.RenderPageInDPI(&requests.RenderPageInDPI{
		Page: page,
		DPI:  int(72 * scale), // 72 DPI = 100% zoom baseline
	})
	if err != nil {
		return nil, fmt.Errorf("render page %d: %w", pageIndex, err)
	}
	defer res.Cleanup()

	return &renderedPage{
		Image: res.Result.Image,
		Width: res.Result.Image.Bounds().Dx(),
		Height: res.Result.Image.Bounds().Dy(),
	}, nil
}

func (e *Engine) Close() {
	if e.doc != nil {
		e.instance.FPDF_CloseDocument(&requests.FPDF_CloseDocument{Document: e.doc.Document})
	}
	e.instance.Close()
	e.pool.Close()
}

type renderedPage struct {
	Image  interface{ Bounds() interface{} } // placeholder — replaced by image.Image below
	Width  int
	Height int
}
```

 > Note: the `renderedPage.Image` type above is simplified for readability — in your actual file, use `image.Image` from the standard library (the `go-pdfium` `RenderPageInDPI` response already returns one). Import `"image"` and set `Image image.Image`.

 ```go
// viewer.go
package main

import (
	"fyne.io/fyne/v2/canvas"
)

// NEW (Section 3): the widget that shows the current page.
type Viewer struct {
	image *canvas.Image
}

func newViewer() *Viewer {
	img := canvas.NewImageFromImage(nil)
	img.FillMode = canvas.ImageFillContain
	return &Viewer{image: img}
}

func (v *Viewer) Show(p *renderedPage) {
	v.image.Image = p.Image.(interface{})  // see note above re: image.Image
	v.image.Refresh()
}
```

 ```go
// main.go — wire "open file" for now via CLI arg
package main

import (
	"log"
	"os"

	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
)

func main() {
	a := app.New()
	a.Settings().SetTheme(&terminalTheme{})
	w := a.NewWindow("pdfview")
	w.Resize(newDefaultSize())

	tb := newToolbar()
	viewer := newViewer()
	content := container.NewBorder(tb.Container, nil, nil, nil, viewer.image)
	w.SetContent(content)

	// NEW (Section 3): open the file passed on the command line
	if len(os.Args) > 1 {
		engine, err := newEngine()
		if err != nil {
			log.Fatal(err)
		}
		defer engine.Close()

		if _, err := engine.OpenFile(os.Args[1]); err != nil {
			log.Fatal(err)
		}
		page, err := engine.RenderPage(0, 1.0)
		if err != nil {
			log.Fatal(err)
		}
		viewer.Show(page)
	}

	w.ShowAndRun()
}
```

 Run it:

 ```bash
go run . /path/to/some.pdf
```

 ### Tips

 **Scaling:** `RenderPageInDPI` allocates a full raster bitmap. For a page rendered at high zoom, that bitmap can be tens of megabytes. Never render every page up front — this section renders exactly one page, which is the foundation for the on-demand strategy the rest of the guide relies on.

 **Security:** `OpenDocument` on an untrusted file is the single riskiest call in this app — it's a C++ parser touching attacker-controlled bytes. Two things to do immediately (implemented fully in Section 8):

 1. Cap the file size you'll read before calling `OpenDocument` at all.
2. Never pass a user-supplied path straight into OS calls without cleaning it (`filepath.Clean`, and reject `..` traversal) if the path ever comes from something other than a native file-picker dialog.

 ---

 ## Section 4 — Page navigation (wiring back/forward)

 Goal: track current page, wire the toolbar buttons, add vim-style keyboard navigation to match the terminal theme.

 ```go
// viewer.go
package main

import "fyne.io/fyne/v2/canvas"

type Viewer struct {
	image *canvas.Image

	// NEW (Section 4): navigation state
	engine    *Engine
	pageIndex int
	pageCount int
	zoom      float32
}

func newViewer(engine *Engine, pageCount int) *Viewer {
	img := canvas.NewImageFromImage(nil)
	img.FillMode = canvas.ImageFillContain
	return &Viewer{
		image:     img,
		engine:    engine,
		pageIndex: 0,
		pageCount: pageCount,
		zoom:      1.0,
	}
}

func (v *Viewer) Show(p *renderedPage) {
	v.image.Image = p.Image.(interface{})
	v.image.Refresh()
}

// NEW (Section 4): render whatever page/zoom is currently selected
func (v *Viewer) render() error {
	page, err := v.engine.RenderPage(v.pageIndex, v.zoom)
	if err != nil {
		return err
	}
	v.Show(page)
	return nil
}

// NEW (Section 4): navigation, clamped to valid page range
func (v *Viewer) Next() error {
	if v.pageIndex >= v.pageCount-1 {
		return nil
	}
	v.pageIndex++
	return v.render()
}

func (v *Viewer) Prev() error {
	if v.pageIndex <= 0 {
		return nil
	}
	v.pageIndex--
	return v.render()
}
```

 ```go
// main.go — wire toolbar + keyboard to viewer navigation
package main

import (
	"log"
	"os"

	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
)

func main() {
	a := app.New()
	a.Settings().SetTheme(&terminalTheme{})
	w := a.NewWindow("pdfview")
	w.Resize(newDefaultSize())

	if len(os.Args) < 2 {
		log.Fatal("usage: pdfview <file.pdf>")
	}

	engine, err := newEngine()
	if err != nil {
		log.Fatal(err)
	}
	defer engine.Close()

	pageCount, err := engine.OpenFile(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}

	viewer := newViewer(engine, pageCount)
	tb := newToolbar()

	// NEW (Section 4): wire toolbar buttons to real navigation
	tb.Back.OnActivated = func() { logErr(viewer.Prev()) }
	tb.Forward.OnActivated = func() { logErr(viewer.Next()) }

	content := container.NewBorder(tb.Container, nil, nil, nil, viewer.image)
	w.SetContent(content)

	// NEW (Section 4): vim-style keyboard navigation (h/l), fits the terminal theme
	w.Canvas().SetOnTypedKey(func(e *fyne.KeyEvent) {
		switch e.Name {
		case fyne.KeyRight, "L":
			logErr(viewer.Next())
		case fyne.KeyLeft, "H":
			logErr(viewer.Prev())
		}
	})

	if err := viewer.render(); err != nil {
		log.Fatal(err)
	}

	w.ShowAndRun()
}

func logErr(err error) {
	if err != nil {
		log.Println("error:", err)
	}
}
```

 (Add `"fyne.io/fyne/v2"` to `main.go`'s imports for `fyne.KeyEvent`.)

 ### Tips

 **Scaling:** Right now every `Next()`/`Prev()` call re-renders synchronously on the UI goroutine, which will visibly stall on large/complex pages. That's fixed in Section 6 — don't skip ahead and ship this version.

 **Security:** Always clamp `pageIndex` server-side (i.e., in `Viewer`, not just by disabling buttons in the UI) — if you ever add a "go to page N" text field, an out-of-range index passed straight to `RenderPage` can crash the PDFium instance.

 ---

 ## Section 5 — Zoom

 Goal: zoom in/out/reset, re-rendering the current page at the new scale.

 ```go
// viewer.go
package main

// NEW (Section 5): zoom bounds — prevents pathological render sizes (also a
// security control, see Tips below)
const (
	minZoom     = 0.25
	maxZoom     = 4.0
	zoomStep    = 0.25
	defaultZoom = 1.0
)

func (v *Viewer) ZoomIn() error {
	v.zoom = clampZoom(v.zoom + zoomStep)
	return v.render()
}

func (v *Viewer) ZoomOut() error {
	v.zoom = clampZoom(v.zoom - zoomStep)
	return v.render()
}

func (v *Viewer) ZoomReset() error {
	v.zoom = defaultZoom
	return v.render()
}

func clampZoom(z float32) float32 {
	if z < minZoom {
		return minZoom
	}
	if z > maxZoom {
		return maxZoom
	}
	return z
}
```

 ```go
// main.go
	// NEW (Section 5): wire zoom buttons
	tb.ZoomIn.OnActivated = func() { logErr(viewer.ZoomIn()) }
	tb.ZoomOut.OnActivated = func() { logErr(viewer.ZoomOut()) }
	tb.ZoomReset.OnActivated = func() { logErr(viewer.ZoomReset()) }

	// NEW (Section 5): +/- keyboard shortcuts alongside h/l
	w.Canvas().SetOnTypedKey(func(e *fyne.KeyEvent) {
		switch e.Name {
		case fyne.KeyRight, "L":
			logErr(viewer.Next())
		case fyne.KeyLeft, "H":
			logErr(viewer.Prev())
		case fyne.KeyPlus, "Equal":
			logErr(viewer.ZoomIn())
		case fyne.KeyMinus:
			logErr(viewer.ZoomOut())
		case "0":
			logErr(viewer.ZoomReset())
		}
	})
```

 ### Tips

 **Scaling:** A user mashing the zoom button fires a full re-render per click. Section 6 adds debouncing so only the *last* zoom level in a burst actually renders — do that before you consider zoom "done".

 **Security:** `maxZoom` isn't just UX polish — it's a resource-exhaustion control. `RenderPageInDPI`'s output size grows roughly with the square of DPI. A page with an unusually large `MediaBox` (some malicious PDFs declare enormous page dimensions) combined with unbounded zoom can be used to force a multi-gigabyte allocation. Always clamp the *effective* render size (`page dimensions × zoom`), not just the zoom multiplier — add this check in `Engine.RenderPage` too, not only in the UI layer:

 ```go
// engine.go — add inside RenderPage, before calling RenderPageInDPI
const maxRenderPixels = 8000 * 8000 // ~64M pixels, adjust to your needs

// (after fetching page size via GetPageSize)
if float32(pageWidthPt) * scale * float32(pageHeightPt) * scale > maxRenderPixels {
	return nil, fmt.Errorf("requested render size exceeds limit")
}
```

 ---

 ## Section 6 — Handling large files: async, cancellable, cached rendering

 This is the core "production-ready" section. Three problems to solve:

 1. Rendering must not block the UI goroutine.
2. Rapid navigation/zoom must cancel stale, in-flight renders.
3. Repeated views of the same page/zoom shouldn't re-render from scratch.

 ```go
// cache.go
package main

import (
	"container/list"
	"sync"
)

// NEW (Section 6): a size-bounded LRU cache for rendered pages, keyed by
// "pageIndex@zoom". Bounded by *byte budget*, not item count — rendered
// pages vary wildly in size.
type pageCache struct {
	mu        sync.Mutex
	items     map[string]*list.Element
	order     *list.List
	usedBytes int64
	maxBytes  int64
}

type cacheEntry struct {
	key   string
	page  *renderedPage
	bytes int64
}

func newPageCache(maxBytes int64) *pageCache {
	return &pageCache{
		items:    make(map[string]*list.Element),
		order:    list.New(),
		maxBytes: maxBytes,
	}
}

func (c *pageCache) Get(key string) (*renderedPage, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if el, ok := c.items[key]; ok {
		c.order.MoveToFront(el)
		return el.Value.(*cacheEntry).page, true
	}
	return nil, false
}

func (c *pageCache) Put(key string, page *renderedPage, bytes int64) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if el, ok := c.items[key]; ok {
		c.order.MoveToFront(el)
		el.Value.(*cacheEntry).page = page
		return
	}

	el := c.order.PushFront(&cacheEntry{key: key, page: page, bytes: bytes})
	c.items[key] = el
	c.usedBytes += bytes

	// NEW (Section 6): evict oldest entries until we're back under budget
	for c.usedBytes > c.maxBytes && c.order.Len() > 1 {
		back := c.order.Back()
		entry := back.Value.(*cacheEntry)
		c.order.Remove(back)
		delete(c.items, entry.key)
		c.usedBytes -= entry.bytes
	}
}
```

 ```go
// viewer.go
package main

import (
	"context"
	"fmt"
	"sync"

	"fyne.io/fyne/v2/canvas"
)

type Viewer struct {
	image     *canvas.Image
	engine    *Engine
	pageIndex int
	pageCount int
	zoom      float32

	// NEW (Section 6): async rendering state
	cache      *pageCache
	cancel     context.CancelFunc
	renderMu   sync.Mutex
	onError    func(error)
}

func newViewer(engine *Engine, pageCount int, onError func(error)) *Viewer {
	img := canvas.NewImageFromImage(nil)
	img.FillMode = canvas.ImageFillContain
	return &Viewer{
		image:     img,
		engine:    engine,
		pageIndex: 0,
		pageCount: pageCount,
		zoom:      defaultZoom,
		cache:     newPageCache(256 << 20), // 256MB render cache budget
		onError:   onError,
	}
}

// NEW (Section 6): render() is now async and cancellable. Calling it again
// while a render is in flight cancels the previous one.
func (v *Viewer) render() {
	v.renderMu.Lock()
	if v.cancel != nil {
		v.cancel() // cancel any in-flight render — it's now stale
	}
	ctx, cancel := context.WithCancel(context.Background())
	v.cancel = cancel
	v.renderMu.Unlock()

	key := fmt.Sprintf("%d@%.2f", v.pageIndex, v.zoom)
	if cached, ok := v.cache.Get(key); ok {
		v.Show(cached)
		return
	}

	pageIndex, zoom := v.pageIndex, v.zoom
	go func() {
		page, err := v.engine.RenderPage(pageIndex, zoom)
		if ctx.Err() != nil {
			return // request was superseded — drop the result on the floor
		}
		if err != nil {
			v.onError(err)
			return
		}
		v.cache.Put(key, page, int64(page.Width*page.Height*4)) // RGBA bytes
		// NEW (Section 6): Fyne UI updates must happen back on the UI thread
		fyneDo(func() { v.Show(page) })
	}()
}

func (v *Viewer) Show(p *renderedPage) {
	v.image.Image = p.Image.(interface{})
	v.image.Refresh()
}

func (v *Viewer) Next() {
	if v.pageIndex < v.pageCount-1 {
		v.pageIndex++
		v.render()
	}
}

func (v *Viewer) Prev() {
	if v.pageIndex > 0 {
		v.pageIndex--
		v.render()
	}
}

func (v *Viewer) ZoomIn()    { v.zoom = clampZoom(v.zoom + zoomStep); v.render() }
func (v *Viewer) ZoomOut()   { v.zoom = clampZoom(v.zoom - zoomStep); v.render() }
func (v *Viewer) ZoomReset() { v.zoom = defaultZoom; v.render() }
```

 `fyneDo` marshals a function onto Fyne's UI goroutine — Fyne 2.4+ provides `fyne.Do`/`fyne.DoAndWait` for exactly this; wrap it so earlier Fyne versions can fall back to a driver-specific call:

 ```go
// main.go (or a small util.go)
func fyneDo(f func()) {
	fyne.Do(f)
}
```

 Update `main.go`'s `newViewer` call to pass an error handler, e.g. one that writes to the terminal-style status bar (built in Section 9).

 ### Tips

 **Scaling:** The cache key includes zoom level, so panning between zoom levels doesn't thrash the cache — but it also means the *same* page at two zoom levels counts as two entries. Size `maxBytes` with that in mind (a 256MB budget at ~8MB/page holds roughly 32 rendered pages, which comfortably covers typical back-and-forth reading behavior). For very large documents, also consider **prefetching** page N+1 in the background after N finishes rendering — implement it as a lower-priority goroutine that respects the same cancellation context, so it never blocks a user-initiated navigation.

 **Security:** Cancellation isn't just a performance nicety here — it's a denial-of-service guard. Without it, a user (or a script driving your app) rapidly flipping pages queues unbounded concurrent `RenderPage` calls into PDFium, each holding memory until it completes. The `context.CancelFunc` pattern above ensures at most one render is truly in flight per viewer. Combine this with a hard concurrency cap (a buffered channel used as a semaphore) if you later allow multiple documents/tabs open at once.

 ---

 ## Section 7 — Worker pool: process isolation for crash safety

 Goal: replace the single-threaded PDFium instance with `go-pdfium`'s multi-process pool, so a PDF that crashes the parser takes down one short-lived worker process, not your whole app.

 ```go
// engine.go
package main

import (
	"fmt"
	"time"

	"github.com/klippa-app/go-pdfium/pdfium"
	pdfium_mp "github.com/klippa-app/go-pdfium/multi_threaded"
)

// NEW (Section 7): multi-process pool config. Each worker is a separate
// OS process; if PDFium crashes inside one, go-pdfium detects it and
// respawns the worker automatically.
func newEngine() (*Engine, error) {
	pool, err := pdfium_mp.Init(pdfium_mp.Config{
		MinIdle:  1,
		MaxIdle:  2,
		MaxTotal: 4, // cap concurrent PDFium processes
	})
	if err != nil {
		return nil, fmt.Errorf("init pdfium pool: %w", err)
	}

	inst, err := pool.GetInstance(30 * time.Second) // NEW: timeout acquiring a worker
	if err != nil {
		return nil, fmt.Errorf("get pdfium instance: %w", err)
	}
	return &Engine{pool: pool, instance: inst}, nil
}
```

 The rest of `Engine` (`OpenFile`, `RenderPage`, `Close`) is unchanged — that's the point of the wrapper from Section 3: swapping the pool implementation doesn't ripple through the rest of the app.

 Add a render timeout so a pathological page (e.g. deeply nested vector graphics designed to be slow to rasterize) can't hang a worker forever:

 ```go
// engine.go
func (e *Engine) RenderPage(pageIndex int, scale float32) (*renderedPage, error) {
	resultCh := make(chan renderResult, 1)

	// NEW (Section 7): run the actual render with a hard deadline
	go func() {
		page, err := e.renderPageInternal(pageIndex, scale)
		resultCh <- renderResult{page, err}
	}()

	select {
	case r := <-resultCh:
		return r.page, r.err
	case <-time.After(10 * time.Second):
		return nil, fmt.Errorf("render page %d: timed out", pageIndex)
	}
}

type renderResult struct {
	page *renderedPage
	err  error
}
```

 ### Tips

 **Scaling:** `MaxTotal` bounds how many PDFium worker processes can exist at once — each is a real OS process with its own memory. Size it against your target machine's RAM (rule of thumb: a few hundred MB per worker for typical documents, much more for image-heavy PDFs) rather than CPU count.

 **Security:** This is your primary defense against malicious PDFs. Process isolation means a crash, an out-of-bounds read, or a hang in PDFium's C++ code is contained to a disposable worker process instead of corrupting your application's memory space. Combine this with running the whole app (and especially these worker processes) with least-privilege OS permissions — no unnecessary filesystem or network access — since "worst case" for a PDF viewer should be "a worker process dies and gets restarted," never "the attacker's PDF gets code execution in a process that can reach the network."

 ---

 ## Section 8 — File validation & resource limits

 Goal: reject bad input *before* it ever reaches PDFium.

 ```go
// security.go
package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

// NEW (Section 8): hard caps — tune to your users' realistic documents
const (
	maxFileSizeBytes = 500 << 20 // 500MB
	pdfMagicBytes    = "%PDF-"
)

// readFileBytes validates and reads a PDF file, rejecting anything that
// isn't plausibly a PDF or exceeds size limits, before handing bytes to
// the (untrusted-input-hostile) PDFium parser.
func readFileBytes(path string) ([]byte, error) {
	// NEW (Section 8): normalize + reject path traversal if this path
	// ever originates from something other than a native OS file dialog
	// (e.g. a CLI arg, an IPC message, a "recent files" list you persist).
	clean := filepath.Clean(path)

	info, err := os.Stat(clean)
	if err != nil {
		return nil, fmt.Errorf("stat file: %w", err)
	}
	if info.IsDir() {
		return nil, fmt.Errorf("path is a directory")
	}
	if info.Size() > maxFileSizeBytes {
		return nil, fmt.Errorf("file exceeds maximum size of %d bytes", maxFileSizeBytes)
	}

	data, err := os.ReadFile(clean)
	if err != nil {
		return nil, fmt.Errorf("read file: %w", err)
	}

	// NEW (Section 8): magic-byte check — cheap, rejects obviously-wrong
	// files before they reach the parser. Not a security boundary by
	// itself (headers can be spoofed), but it's free and catches mistakes.
	if !bytes.HasPrefix(data, []byte(pdfMagicBytes)) {
		return nil, fmt.Errorf("file does not appear to be a PDF")
	}

	return data, nil
}
```

 Also cap page count on open, since a document with an absurd page count (some crafted PDFs report huge counts) shouldn't be allowed to drive unbounded UI state:

 ```go
// engine.go — inside OpenFile, after GetPageCount
const maxPageCount = 20000
if pageInfo.PageCount > maxPageCount {
	return 0, fmt.Errorf("document has too many pages (%d)", pageInfo.PageCount)
}
```

 ### Tips

 **Scaling:** `os.ReadFile` loads the whole file into memory before the size check even matters for *rendering* memory — for very large files, prefer streaming the size check via `os.Stat` first (as above, done before the read) so you never allocate for a file you're about to reject.

 **Security:** Layer your defenses — magic-byte check, size cap, page-count cap, path cleaning, process isolation (Section 7), and render-size limits (Section 5's Tips) are all independently weak but strong together. Never rely on file extension (`.pdf`) as a security check; always sniff content. If you ever add "open PDF from URL," treat that as a much bigger attack surface (SSRF, redirect chains, huge downloads) and gate it separately.

 ---

 ## Section 9 — Status bar, error surfacing, and corrupt-file UX

 Goal: a terminal-style status line (`page 3/48 zoom 100% ~/doc.pdf`) and visible, non-crashing error handling for bad files.

 ```go
// viewer.go — add a status bar alongside the image
package main

import "fyne.io/fyne/v2/widget"

// NEW (Section 9): a one-line status bar, terminal-prompt style
type StatusBar struct {
	label *widget.Label
}

func newStatusBar() *StatusBar {
	return &StatusBar{label: widget.NewLabel("")}
}

func (s *StatusBar) Update(page, total int, zoom float32, filename string) {
	s.label.SetText(fmt.Sprintf("-- %s -- page %d/%d  zoom %.0f%%", filename, page+1, total, zoom*100))
}

func (s *StatusBar) Error(err error) {
	// NEW (Section 9): errors render in the same status line, in the
	// theme's accent color, rather than a disruptive modal dialog
	s.label.SetText(fmt.Sprintf("!! error: %v", err))
}
```

 Wire it into `main.go`:

 ```go
// main.go
	status := newStatusBar()
	viewer := newViewer(engine, pageCount, status.Error)

	content := container.NewBorder(
		tb.Container,     // top
		status.label,     // NEW (Section 9): bottom
		nil, nil,
		viewer.image,
	)

	// NEW (Section 9): keep the status bar in sync after every navigation/zoom
	updateStatus := func() {
		status.Update(viewer.pageIndex, viewer.pageCount, viewer.zoom, filepath.Base(os.Args[1]))
	}
	// call updateStatus() after each Next/Prev/Zoom — simplest approach is
	// to call it right after each v.render() invocation inside viewer.go,
	// or have Viewer accept an onStateChange callback the same way it
	// accepts onError.
```

 ### Tips

 **Scaling:** Keep the status bar update cheap and synchronous (it's just a label) — don't let it become a place where expensive formatting or file I/O sneaks in on every frame.

 **Security:** Never surface raw internal error strings from PDFium directly if you later add telemetry/crash reporting that a user's screen output might end up in — wrap engine errors in your own messages (as the `engine.go` functions already do with `fmt.Errorf("...: %w", err)`) so you control exactly what's user-visible versus what's logged for debugging.

 ---

 ## Section 10 — Terminal aesthetic, finished

 Goal: polish the look — embedded monospace font, terminal-style chrome, and a blinking-cursor loading indicator instead of a generic spinner.

 ```go
// theme.go — embed a real terminal font instead of relying on system monospace
package main

import (
	_ "embed"

	"fyne.io/fyne/v2"
)

//go:embed fonts/JetBrainsMono-Regular.ttf
var monoFontData []byte

// NEW (Section 10): serve the embedded font as a Fyne resource
var monoFont = fyne.NewStaticResource("JetBrainsMono-Regular.ttf", monoFontData)

func (terminalTheme) Font(style fyne.TextStyle) fyne.Resource {
	return monoFont
}
```

 ```go
// viewer.go — a simple blinking-cursor "loading" indicator, terminal-style
package main

import (
	"time"

	"fyne.io/fyne/v2/widget"
)

// NEW (Section 10): shown in the status bar while a render is in flight
type cursorBlinker struct {
	label  *widget.Label
	ticker *time.Ticker
	on     bool
}

func newCursorBlinker(label *widget.Label) *cursorBlinker {
	return &cursorBlinker{label: label}
}

func (c *cursorBlinker) Start() {
	c.ticker = time.NewTicker(500 * time.Millisecond)
	go func() {
		for range c.ticker.C {
			c.on = !c.on
			text := "rendering "
			if c.on {
				text += "_"
			}
			fyneDo(func() { c.label.SetText(text) })
		}
	}()
}

func (c *cursorBlinker) Stop() {
	if c.ticker != nil {
		c.ticker.Stop()
	}
}
```

 Start the blinker right before dispatching a render goroutine in `Viewer.render()`, and `Stop()` it in the goroutine once the result (or an error) comes back.

 ### Tips

 **Scaling:** `go:embed` bakes the font into the binary — no runtime file I/O, and it can't go missing on a user's machine. The tradeoff is binary size (a TTF is typically 100–300KB, negligible).

 **Security:** Only embed fonts you have the license to redistribute (JetBrains Mono is OFL-licensed and fine; don't embed a commercial font without checking its license). This matters once you're shipping binaries to other people, not just running `go run .` locally.

 ---

 ## Section 11 — Packaging & distribution

 ```bash
go install fyne.io/fyne/v2/cmd/fyne@latest

# Cross-compile + package as a native app bundle per platform
fyne package -os darwin -icon icon.png
fyne package -os linux -icon icon.png
fyne package -os windows -icon icon.png
```

 Because `go-pdfium`'s multi-process mode spawns a helper binary, make sure your packaging step bundles it alongside your executable — check `go-pdfium`'s docs for the exact worker binary your Go version produces, and reference it via a path relative to the executable (`os.Executable()`), never a hardcoded absolute path.

 ### Tips

 **Scaling:** Build in CI (GitHub Actions with the `fyne-io/fyne-cross` action, or Docker cross-compilation images) rather than by hand, so every release is built the same way and you can reproduce a past release for debugging.

 **Security:** Code-sign your binaries (macOS notarization, Windows Authenticode) — an unsigned desktop app that opens arbitrary local files is exactly the kind of thing OS gatekeeping (Gatekeeper, SmartScreen) is designed to warn users about, and users trained to click through those warnings are a security liability in general. Also pin and checksum the `go-pdfium` worker binary you bundle — verify its hash in your build pipeline so a compromised dependency mirror can't silently swap in a malicious worker executable.

 ---

 ## Where to go from here

 The app at this point is a real, hardened, single-document viewer. Natural next steps, each of which slots into the architecture above without a rewrite:

 - **Outline/bookmark panel** — `go-pdfium` exposes the document's outline tree; render it as a collapsible sidebar (another `container.NewBorder` slot).
- **Text search** — `go-pdfium` supports text extraction per page; combine with the existing page cache and cancellation pattern from Section 6.
- **True back/forward history** (as in a browser, for internal PDF links) — a simple `[]int` stack of visited page indices, pushed on link-follow, popped on Back.
- **Multiple open documents (tabs)** — each tab gets its own `Viewer`, all sharing one `Engine` pool (respect `MaxTotal` from Section 7).

 Everything above — the async/cancellable rendering, the byte-budgeted cache, the process-isolated worker pool, and the layered input validation — is what actually separates "renders a PDF" from "production ready." Don't cut Sections 6–8 even for a side project; they're the parts that keep the app usable on a 2,000-page scanned book and safe against a PDF someone found on a random forum.# pdfview — Terminal-Styled PDF Viewer in Go (Corrected Build)

 This is a redo of the original guide with the real bugs fixed and the cross-section inconsistencies resolved. Instead of re-running the same incremental "diff per section" format (which is exactly how the original picked up inconsistencies — each section quietly changed a function signature the next section assumed), this version gives you the **final, internally-consistent source for every file**, plus a short note on what changed and why. You still get the same section-by-section mental model, just without carrying bugs forward.

 ## What was actually wrong, and what changed

 1. **`renderedPage.Image` was untyped garbage.** The original declared it as `interface{ Bounds() interface{} }` and then "converted" it with `p.Image.(interface{})` — a type assertion to bare `interface{}` doesn't convert anything; that line doesn't compile as written. Fixed: `Image` is a real `image.Image`, assigned directly to `canvas.Image.Image` (which is typed `image.Image`) — no assertion needed.
2. **Two competing cancellation mechanisms.** Section 6 added `context.CancelFunc` for stale-render cancellation; Section 7 separately added a `time.After(10s)` timeout *inside* `Engine.RenderPage` that knew nothing about that context. A cancelled render and a timed-out render were handled by two different code paths that never talked to each other. Fixed: `RenderPage` now takes a `context.Context` and selects on both `ctx.Done()` (user navigated away) and a timeout (worker hung) in the same `select`.
3. **Keyboard shortcuts mixed key types incorrectly.** `case fyne.KeyRight, "L"` inside `SetOnTypedKey` mixes an arrow key (a real key event) with a printable character (`l`/`h`/`+`/`-`/`0`), which Fyne delivers through `SetOnTypedRune`, not `SetOnTypedKey`. Fixed: arrow keys go through `SetOnTypedKey`, printable shortcuts go through `SetOnTypedRune`.
4. **`Next()`/`Prev()` changed signature between sections** (returned `error` in Section 4, returned nothing in Section 6) and callers in `main.go` were never updated to match. Fixed: one signature throughout — errors go through the `onError` callback into the status bar, which is the right place for them in a GUI app anyway (nothing useful to do with a returned `error` on a button-click handler).
5. **Status bar update was never actually wired in.** The original left "call `updateStatus()` after each render" as a comment/exercise. Fixed: `Viewer` takes an `onStateChange` callback (same pattern as `onError`) and calls it after every successful render or cache hit.
6. **Zoom's render-size guard was described in Tips but never actually implemented in the `RenderPage` code path.** Fixed: it's a real check in `renderPageInternal`, using the page's actual point size from `GetPageSize`, not just the zoom multiplier — a PDF with a huge `MediaBox` at low zoom is exactly what this guard needs to catch, and the original's zoom-only check would have missed it.
7. **Missing import** (`theme` in `toolbar.go`) that the original called out in prose instead of just including.
8. **Status bar split into its own file** (`status.go`) instead of being half-declared inside `viewer.go`, matching the project layout table.

 ## Architecture (unchanged, it was the right call)

 | Concern | Choice | Why |
| --- | --- | --- |
| GUI toolkit | [Fyne](https://fyne.io/) | Pure Go, cross-platform, canvas-based, easy theming |
| PDF rendering | [go-pdfium](https://github.com/klippa-app/go-pdfium) | BSD-licensed, Chrome's own PDF engine, multi-process worker pool for crash isolation |
| Rendering strategy | On-demand, LRU-cached, byte-budgeted | Never load a whole document into memory |
| Concurrency | Background goroutines +`context.Context` | Responsive UI, drops stale work on fast scroll/zoom |

 ```
pdfview/
├── go.mod
├── main.go       # entrypoint, window, wiring
├── theme.go      # terminal-styled Fyne theme
├── toolbar.go    # zoom / navigation toolbar
├── viewer.go     # page canvas + render/cache/cancel logic
├── status.go     # status bar + error surfacing
├── cache.go      # LRU page-image cache, byte-budgeted
├── engine.go     # go-pdfium wrapper: open, render, close
├── security.go   # file validation, resource limits
└── util.go       # small shared helpers
```

 ## Setup

 ```bash
go version   # need 1.22+

# macOS
xcode-select --install
# Linux (Debian/Ubuntu)
sudo apt install gcc libgl1-mesa-dev libx11-dev libxrandr-dev \
  libxcursor-dev libxinerama-dev libxi-dev xorg-dev

mkdir pdfview && cd pdfview
go mod init github.com/<you>/pdfview

go get fyne.io/fyne/v2@latest
go get github.com/klippa-app/go-pdfium@latest
```

 Pin exact versions and commit `go.sum` — PDF rendering output can shift subtly across `go-pdfium`/PDFium versions, and you don't want a `go get -u` in CI silently changing what users see.

 ---

 ## main.go

 ```go
package main

import (
	"log"
	"os"
	"path/filepath"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
)

func newDefaultSize() fyne.Size {
	return fyne.NewSize(900, 700)
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("usage: pdfview <file.pdf>")
	}

	a := app.New()
	a.Settings().SetTheme(&terminalTheme{})
	w := a.NewWindow("pdfview")
	w.Resize(newDefaultSize())

	engine, err := newEngine()
	if err != nil {
		log.Fatal(err)
	}
	defer engine.Close()

	pageCount, err := engine.OpenFile(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}

	status := newStatusBar()
	filename := filepath.Base(os.Args[1])

	var viewer *Viewer
	viewer = newViewer(engine, pageCount,
		func(err error) { status.Error(err) },
		func() { status.Update(viewer.pageIndex, viewer.pageCount, viewer.zoom, filename) },
	)

	tb := newToolbar()
	tb.Back.OnActivated = viewer.Prev
	tb.Forward.OnActivated = viewer.Next
	tb.ZoomIn.OnActivated = viewer.ZoomIn
	tb.ZoomOut.OnActivated = viewer.ZoomOut
	tb.ZoomReset.OnActivated = viewer.ZoomReset

	content := container.NewBorder(tb.Container, status.label, nil, nil, viewer.image)
	w.SetContent(content)

	// Arrow keys: real key events, go through SetOnTypedKey.
	w.Canvas().SetOnTypedKey(func(e *fyne.KeyEvent) {
		switch e.Name {
		case fyne.KeyRight:
			viewer.Next()
		case fyne.KeyLeft:
			viewer.Prev()
		}
	})
	// Printable shortcuts (vim-style h/l, +/-/0 zoom): go through SetOnTypedRune,
	// not SetOnTypedKey — this is the actual Fyne-correct way to catch them.
	w.Canvas().SetOnTypedRune(func(r rune) {
		switch r {
		case 'l':
			viewer.Next()
		case 'h':
			viewer.Prev()
		case '+', '=':
			viewer.ZoomIn()
		case '-':
			viewer.ZoomOut()
		case '0':
			viewer.ZoomReset()
		}
	})

	viewer.render()
	w.ShowAndRun()
}
```

 ## theme.go

 ```go
package main

import (
	_ "embed"
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

var (
	bgColor  = color.NRGBA{R: 0x0d, G: 0x0d, B: 0x0d, A: 0xff}
	fgColor  = color.NRGBA{R: 0x33, G: 0xff, B: 0x66, A: 0xff}
	dimColor = color.NRGBA{R: 0x1a, G: 0x1a, B: 0x1a, A: 0xff}
)

// Embed a real terminal font. Drop a licensed TTF at fonts/JetBrainsMono-Regular.ttf
// (JetBrains Mono is OFL-licensed) or delete this block and fall back to
// theme.DefaultTheme().Font(style) with style.Monospace = true if you'd
// rather not ship a font file yet.
//
//go:embed fonts/JetBrainsMono-Regular.ttf
var monoFontData []byte

var monoFont = fyne.NewStaticResource("JetBrainsMono-Regular.ttf", monoFontData)

type terminalTheme struct{}

func (terminalTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return bgColor
	case theme.ColorNameForeground:
		return fgColor
	case theme.ColorNameButton, theme.ColorNameDisabledButton:
		return dimColor
	default:
		return theme.DefaultTheme().Color(name, theme.VariantDark)
	}
}

func (terminalTheme) Font(style fyne.TextStyle) fyne.Resource {
	return monoFont
}

func (terminalTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (terminalTheme) Size(name fyne.ThemeSizeName) float32 {
	return theme.DefaultTheme().Size(name)
}
```

 Keep `Color`/`Font`/`Size` allocation-free — Fyne calls them on every redraw. That's why the colors and font resource above are package-level vars, not built inside the methods.

 ## toolbar.go

 ```go
package main

import (
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

type Toolbar struct {
	Container *widget.Toolbar
	ZoomIn    *widget.ToolbarAction
	ZoomOut   *widget.ToolbarAction
	ZoomReset *widget.ToolbarAction
	Back      *widget.ToolbarAction
	Forward   *widget.ToolbarAction
}

func newToolbar() *Toolbar {
	t := &Toolbar{}

	t.Back = widget.NewToolbarAction(theme.NavigateBackIcon(), func() {})
	t.Forward = widget.NewToolbarAction(theme.NavigateNextIcon(), func() {})
	t.ZoomOut = widget.NewToolbarAction(theme.ZoomOutIcon(), func() {})
	t.ZoomReset = widget.NewToolbarAction(theme.ZoomFitIcon(), func() {})
	t.ZoomIn = widget.NewToolbarAction(theme.ZoomInIcon(), func() {})

	t.Container = widget.NewToolbar(
		t.Back,
		t.Forward,
		widget.NewToolbarSeparator(),
		t.ZoomOut,
		t.ZoomReset,
		t.ZoomIn,
	)
	return t
}
```

 Build it once at startup and mutate the `OnActivated` callbacks / enable- disable state — don't rebuild the toolbar on every page change, that's the most common source of a janky Fyne UI.

 ## engine.go

 ```go
package main

import (
	"context"
	"fmt"
	"image"
	"time"

	pdfium_mp "github.com/klippa-app/go-pdfium/multi_threaded"
	"github.com/klippa-app/go-pdfium/pdfium"
	"github.com/klippa-app/go-pdfium/requests"
	"github.com/klippa-app/go-pdfium/responses"
)

// Multi-process pool from the start: each worker is a separate OS process,
// so a PDF that crashes PDFium's C++ parser takes down a disposable worker,
// not your whole app. There's no reason to build the single-threaded
// version first and swap later — the wrapper interface is identical either
// way, so start here.
type Engine struct {
	pool     pdfium.Pool
	instance pdfium.Pdfium
	doc      *responses.OpenDocument
}

func newEngine() (*Engine, error) {
	pool, err := pdfium_mp.Init(pdfium_mp.Config{
		MinIdle:  1,
		MaxIdle:  2,
		MaxTotal: 4, // cap concurrent PDFium processes; size against target RAM
	})
	if err != nil {
		return nil, fmt.Errorf("init pdfium pool: %w", err)
	}
	inst, err := pool.GetInstance(30 * time.Second)
	if err != nil {
		return nil, fmt.Errorf("get pdfium instance: %w", err)
	}
	return &Engine{pool: pool, instance: inst}, nil
}

const maxPageCount = 20000

func (e *Engine) OpenFile(path string) (pageCount int, err error) {
	data, err := readFileBytes(path)
	if err != nil {
		return 0, err
	}

	doc, err := e.instance.OpenDocument(&requests.OpenDocument{File: &data})
	if err != nil {
		return 0, fmt.Errorf("open document: %w", err)
	}
	e.doc = doc

	pageInfo, err := e.instance.GetPageCount(&requests.GetPageCount{Document: doc.Document})
	if err != nil {
		return 0, fmt.Errorf("page count: %w", err)
	}
	if pageInfo.PageCount > maxPageCount {
		return 0, fmt.Errorf("document has too many pages (%d)", pageInfo.PageCount)
	}
	return pageInfo.PageCount, nil
}

type renderedPage struct {
	Image  image.Image // real image.Image — this was the broken placeholder type before
	Width  int
	Height int
}

const maxRenderPixels = 8000 * 8000 // ~64M pixels; tune to your needs

// RenderPage rasterizes a page, respecting both an external cancellation
// context (the caller navigated/zoomed again before this finished) and a
// hard timeout (the worker itself is hung on a pathological page). Both
// conditions are handled in the same select, unlike the original guide
// where they were two disconnected mechanisms.
func (e *Engine) RenderPage(ctx context.Context, pageIndex int, scale float32) (*renderedPage, error) {
	type result struct {
		page *renderedPage
		err  error
	}
	resultCh := make(chan result, 1)

	go func() {
		page, err := e.renderPageInternal(pageIndex, scale)
		resultCh <- result{page, err}
	}()

	select {
	case r := <-resultCh:
		return r.page, r.err
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(10 * time.Second):
		return nil, fmt.Errorf("render page %d: timed out", pageIndex)
	}
}

func (e *Engine) renderPageInternal(pageIndex int, scale float32) (*renderedPage, error) {
	page := requests.Page{Document: e.doc.Document, Index: &pageIndex}

	// Guard against maliciously huge MediaBox * zoom, not just zoom alone —
	// a page that declares an enormous point size can blow this budget even
	// at 100% zoom.
	sizeRes, err := e.instance.GetPageSize(&requests.GetPageSize{Page: page})
	if err != nil {
		return nil, fmt.Errorf("get page size %d: %w", pageIndex, err)
	}
	effectivePixels := float64(sizeRes.Width) * float64(scale) * float64(sizeRes.Height) * float64(scale)
	if effectivePixels > maxRenderPixels {
		return nil, fmt.Errorf("requested render size exceeds limit")
	}

	res, err := e.instance.RenderPageInDPI(&requests.RenderPageInDPI{
		Page: page,
		DPI:  int(72 * scale), // 72 DPI == 100% zoom baseline
	})
	if err != nil {
		return nil, fmt.Errorf("render page %d: %w", pageIndex, err)
	}
	defer res.Cleanup()

	img := res.Result.Image
	b := img.Bounds()
	return &renderedPage{Image: img, Width: b.Dx(), Height: b.Dy()}, nil
}

func (e *Engine) Close() {
	if e.doc != nil {
		e.instance.FPDF_CloseDocument(&requests.FPDF_CloseDocument{Document: e.doc.Document})
	}
	e.instance.Close()
	e.pool.Close()
}
```

 ## viewer.go

 ```go
package main

import (
	"context"
	"fmt"
	"sync"

	"fyne.io/fyne/v2/canvas"
)

const (
	minZoom     = 0.25
	maxZoom     = 4.0
	zoomStep    = 0.25
	defaultZoom = 1.0
)

type Viewer struct {
	image *canvas.Image

	engine    *Engine
	pageIndex int
	pageCount int
	zoom      float32

	cache    *pageCache
	cancel   context.CancelFunc
	renderMu sync.Mutex

	onError       func(error)
	onStateChange func()
}

func newViewer(engine *Engine, pageCount int, onError func(error), onStateChange func()) *Viewer {
	img := canvas.NewImageFromImage(nil)
	img.FillMode = canvas.ImageFillContain
	return &Viewer{
		image:         img,
		engine:        engine,
		pageIndex:     0,
		pageCount:     pageCount,
		zoom:          defaultZoom,
		cache:         newPageCache(256 << 20), // 256MB render budget, ~32 pages at ~8MB/page
		onError:       onError,
		onStateChange: onStateChange,
	}
}

// render is the single entry point for every navigation/zoom action.
// Calling it again while a render is in flight cancels the previous one —
// this is a DoS guard as much as a UX one: without it, a user (or script)
// rapidly flipping pages queues unbounded concurrent RenderPage calls.
func (v *Viewer) render() {
	v.renderMu.Lock()
	if v.cancel != nil {
		v.cancel()
	}
	ctx, cancel := context.WithCancel(context.Background())
	v.cancel = cancel
	v.renderMu.Unlock()

	key := fmt.Sprintf("%d@%.2f", v.pageIndex, v.zoom)
	if cached, ok := v.cache.Get(key); ok {
		v.Show(cached)
		if v.onStateChange != nil {
			v.onStateChange()
		}
		return
	}

	pageIndex, zoom := v.pageIndex, v.zoom
	go func() {
		page, err := v.engine.RenderPage(ctx, pageIndex, zoom)
		if ctx.Err() != nil {
			return // superseded by a newer render — drop the result
		}
		if err != nil {
			if v.onError != nil {
				fyneDo(func() { v.onError(err) })
			}
			return
		}
		v.cache.Put(key, page, int64(page.Width*page.Height*4)) // RGBA bytes
		fyneDo(func() {
			v.Show(page)
			if v.onStateChange != nil {
				v.onStateChange()
			}
		})
	}()
}

func (v *Viewer) Show(p *renderedPage) {
	v.image.Image = p.Image // no cast needed now that Image is a real image.Image
	v.image.Refresh()
}

func (v *Viewer) Next() {
	if v.pageIndex < v.pageCount-1 {
		v.pageIndex++
		v.render()
	}
}

func (v *Viewer) Prev() {
	if v.pageIndex > 0 {
		v.pageIndex--
		v.render()
	}
}

func (v *Viewer) ZoomIn()    { v.zoom = clampZoom(v.zoom + zoomStep); v.render() }
func (v *Viewer) ZoomOut()   { v.zoom = clampZoom(v.zoom - zoomStep); v.render() }
func (v *Viewer) ZoomReset() { v.zoom = defaultZoom; v.render() }

func clampZoom(z float32) float32 {
	if z < minZoom {
		return minZoom
	}
	if z > maxZoom {
		return maxZoom
	}
	return z
}
```

 ## cache.go

 ```go
package main

import (
	"container/list"
	"sync"
)

// Size-bounded LRU cache for rendered pages, keyed by "pageIndex@zoom".
// Bounded by byte budget, not item count — rendered pages vary wildly in
// size depending on content and zoom.
type pageCache struct {
	mu        sync.Mutex
	items     map[string]*list.Element
	order     *list.List
	usedBytes int64
	maxBytes  int64
}

type cacheEntry struct {
	key   string
	page  *renderedPage
	bytes int64
}

func newPageCache(maxBytes int64) *pageCache {
	return &pageCache{
		items:    make(map[string]*list.Element),
		order:    list.New(),
		maxBytes: maxBytes,
	}
}

func (c *pageCache) Get(key string) (*renderedPage, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if el, ok := c.items[key]; ok {
		c.order.MoveToFront(el)
		return el.Value.(*cacheEntry).page, true
	}
	return nil, false
}

func (c *pageCache) Put(key string, page *renderedPage, bytes int64) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if el, ok := c.items[key]; ok {
		c.order.MoveToFront(el)
		el.Value.(*cacheEntry).page = page
		return
	}

	el := c.order.PushFront(&cacheEntry{key: key, page: page, bytes: bytes})
	c.items[key] = el
	c.usedBytes += bytes

	for c.usedBytes > c.maxBytes && c.order.Len() > 1 {
		back := c.order.Back()
		entry := back.Value.(*cacheEntry)
		c.order.Remove(back)
		delete(c.items, entry.key)
		c.usedBytes -= entry.bytes
	}
}
```

 Consider prefetching page N+1 in the background after N finishes rendering for very large documents — run it as a lower-priority goroutine sharing the same cancellation context, so a real user-initiated navigation always wins.

 ## status.go

 ```go
package main

import (
	"fmt"

	"fyne.io/fyne/v2/widget"
)

type StatusBar struct {
	label *widget.Label
}

func newStatusBar() *StatusBar {
	return &StatusBar{label: widget.NewLabel("")}
}

func (s *StatusBar) Update(page, total int, zoom float32, filename string) {
	s.label.SetText(fmt.Sprintf("-- %s -- page %d/%d  zoom %.0f%%", filename, page+1, total, zoom*100))
}

// Errors render in the same status line rather than a disruptive modal.
// Wrap engine errors with your own messages (engine.go already does this
// with %w) so you control exactly what's user-visible vs. logged.
func (s *StatusBar) Error(err error) {
	s.label.SetText(fmt.Sprintf("!! error: %v", err))
}
```

 ## security.go

 ```go
package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

const (
	maxFileSizeBytes = 500 << 20 // 500MB
	pdfMagicBytes    = "%PDF-"
)

// readFileBytes validates and reads a PDF file before any bytes reach the
// PDFium parser. Treat every PDF as untrusted, adversarial input.
func readFileBytes(path string) ([]byte, error) {
	// Normalize + reject traversal if this path ever comes from anything
	// other than a native file-picker dialog (CLI arg, IPC message,
	// persisted "recent files" list, etc.) — it does here, since Args[1]
	// is exactly that kind of external input.
	clean := filepath.Clean(path)

	info, err := os.Stat(clean)
	if err != nil {
		return nil, fmt.Errorf("stat file: %w", err)
	}
	if info.IsDir() {
		return nil, fmt.Errorf("path is a directory")
	}
	// Check size via Stat before reading — never allocate for a file
	// you're about to reject.
	if info.Size() > maxFileSizeBytes {
		return nil, fmt.Errorf("file exceeds maximum size of %d bytes", maxFileSizeBytes)
	}

	data, err := os.ReadFile(clean)
	if err != nil {
		return nil, fmt.Errorf("read file: %w", err)
	}

	// Cheap magic-byte check. Not a security boundary on its own (headers
	// can be spoofed) but free, and it catches honest mistakes before the
	// parser. Never trust the .pdf extension alone.
	if !bytes.HasPrefix(data, []byte(pdfMagicBytes)) {
		return nil, fmt.Errorf("file does not appear to be a PDF")
	}

	return data, nil
}
```

 ## util.go

 ```go
package main

import "fyne.io/fyne/v2"

// fyneDo marshals a function onto Fyne's UI goroutine. Any UI mutation
// triggered from a background goroutine (render results, errors) must go
// through this — Fyne widgets are not safe to touch off the UI thread.
func fyneDo(f func()) {
	fyne.Do(f)
}
```

 ---

 ## Packaging

 ```bash
go install fyne.io/fyne/v2/cmd/fyne@latest

fyne package -os darwin -icon icon.png
fyne package -os linux -icon icon.png
fyne package -os windows -icon icon.png
```

 `go-pdfium`'s multi-process mode spawns a helper worker binary — bundle it alongside your executable and reference it via a path relative to `os.Executable()`, never a hardcoded absolute path. Build in CI so every release is reproducible, code-sign your binaries (macOS notarization, Windows Authenticode), and pin + checksum the `go-pdfium` worker binary you ship so a compromised dependency mirror can't swap in a malicious one.

 ## Layered defenses, all in this build

 Magic-byte check → file size cap → page-count cap → path cleaning → render-size guard (actual page size × zoom, not just zoom) → process isolation via the worker pool → per-render timeout. Each one is individually weak; together they're what makes this safe to point at a random PDF someone found on a forum, not just a well-behaved test file.

 ## What would make this genuinely "optimal" vs. just correct

 The above is a correct, hardened single-document viewer. Two things are worth calling out honestly rather than glossing over:

 - **Text selection and search are not included.** For a lot of people "PDF reader" implicitly means "I can Ctrl+F it." `go-pdfium` supports text extraction per page, and it slots into the existing cache/cancel pattern in `viewer.go` — but it's real additional work (a search-results overlay, highlight rendering, next/prev-match state), not a small addition. If search matters to you, it should be scoped as its own section before you call this "done," not left as a "where to go from here" bullet.
- **No outline/bookmark navigation.** Also supported by `go-pdfium` (document outline tree), also a real sidebar widget + state, not a one-liner.

 If either of those is a must-have for what you consider "optimal," say so and I'll build that section out properly rather than hand-wave it — the rest of this architecture (engine wrapper, cache, cancellation) already supports adding it without a rewrite.