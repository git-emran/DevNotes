The two big external APIs you'll need are:

- a way to talk to the process (shell, NeoVim, whatever) running inside the terminal
    
- a way to draw the terminal output to the screen
    

For the first one, you'll need to use the Unix "pseudoterminal" API, probably something like [`nix::pty::forkpty()`](https://docs.rs/nix/0.20.0/nix/pty/fn.forkpty.html). The idea is that you get a "master" file descriptor and a "slave" file descriptor; you launch a new process with its stdin/stdout/stderr set to the slave file descriptor, then you can read its output from the master, write its input to the master, and apply configuration changes (like "window size") to the master and they'll be communicated to the child process.

For the second one, that's tricky... there's a lot of Rust bindings for low-level graphics APIs like OpenGL or Vulkan, but you don't need that fancy stuff and they don't provide things you do need, like "draw text". There's rust bindings for high-level APIs like GTK+ and Windows, but they're all about buttons and sliders and it takes some messing around to get a canvas to just draw on. I don't have any recommendations here, you'll have to figure it out on your own.

Once you have those two, it's down to the fun part: building a data structure to represent the terminal emulator state, decoding terminal control sequences to update that data structure, and encoding control sequences to represent key-press and mouse events. You'll definitely get familiar with things like [the VT220 Programmer's Reference Manual](https://vt100.net/docs/vt220-rm/contents.html), the [xterm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) document, and [vttest](https://invisible-island.net/vttest/vttest.html).

You _don't_ need to care about terminal UI libraries like ncurses, since they just produce control sequences like those documented above - if you handle the control sequence correctly, you'll handle it whether it was produced by ncurses or by hard-coding.

Oh, you might also find the `/usr/bin/script` tool handy - it lets you run a terminal app and log its output, including all the terminal control sequences. That means if your terminal misbehaves with a given app, you can record it and feed the recording into your terminal emulator repeatedly to test it, instead of having to manually run the application every time.



A Quick to Follow along:

# Building a Terminal Emulator in Go — A Staged, Hands-On Guide

 ## What you're actually building

 A terminal emulator is three things duct-taped together with a very old protocol:

 1. **A PTY (pseudo-terminal)** — a kernel construct that fools a shell into thinking it's talking to a real terminal.
2. **A parser** for the escape-sequence language (VT100/ANSI/xterm) that programs use to say "move cursor here," "make this text red," "clear the screen."
3. **A screen model + renderer** — a grid of cells that gets mutated by the parser and painted to your actual terminal.

 None of this is exotic once you see the shape of it. The goal of this guide is to build it in 8 stages, each one a working program, each one replacing something crude with something correct. By the end you'll have a real architecture: `pty`, `vt` (parser + screen buffer), `render`, `input`, wired together in `cmd/term`.

 We'll use `github.com/creack/pty` for the actual PTY syscalls (allocating pseudo-terminals involves ioctls and platform-specific cgo that isn't worth hand-rolling — the learning value is in the terminal, not in re-deriving `posix_openpt`). Everything else — the parser, the screen buffer, the renderer, the state machine — we write ourselves.

 ```bash
mkdir termite && cd termite
go mod init github.com/git-emran/termite
go get github.com/creack/pty
go get golang.org/x/term
```

 Final package layout we're building toward:

 ```
termite/
  cmd/term/main.go        # wiring only, no logic
  internal/pty/           # spawn shell, resize handling
  internal/vt/            # escape-sequence parser + screen buffer (the heart of it)
  internal/render/        # diff-based renderer
  internal/input/         # keyboard → escape sequence translation
```

 ---

 ## Stage 1 — The dumbest possible terminal (raw passthrough)

 Before any parsing, prove the plumbing works: spawn a shell in a PTY, copy bytes in both directions, put your real terminal in raw mode so keystrokes go through un-mangled. This *is* a terminal — a bad one, because it can't interpret anything the shell sends (colors will look like garbage escape codes), but it proves stage 0 of the pipeline.

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"
	"os/exec"

	"github.com/creack/pty"
	"golang.org/x/term"
)

func main() {
	cmd := exec.Command(os.Getenv("SHELL"))

	ptmx, err := pty.Start(cmd)
	if err != nil {
		log.Fatal(err)
	}
	defer ptmx.Close()

	// Put our own stdin into raw mode so keystrokes (Ctrl-C, arrow keys, etc.)
	// pass straight through instead of being line-buffered/echoed by our own tty.
	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		log.Fatal(err)
	}
	defer term.Restore(int(os.Stdin.Fd()), oldState)

	// stdin -> pty (your keystrokes go to the shell)
	go func() { _, _ = io.Copy(ptmx, os.Stdin) }()

	// pty -> stdout (the shell's output goes to your screen, unparsed)
	_, _ = io.Copy(os.Stdout, ptmx)
}
```

 Run it: `go run ./cmd/term`. You'll get a working shell. Type `ls --color`, and you'll see raw escape codes like `^[[0m` mixed into the output — that's the proof you need a parser. Ctrl-D or `exit` to quit (there's no clean shutdown yet — that's Stage 2).

 **What's wrong with this, on purpose:** no resize handling (resize your window, the shell's `$COLUMNS` won't update), no clean exit, and most importantly — no interpretation of anything. We're passing the shell's raw byte stream directly to your *real* terminal, which does the escape-code interpretation for us. A real terminal emulator can't outsource that job — it has to render into a window/canvas itself. Removing that crutch is what Stage 3 onward is about.

 ---

 ## Stage 2 — Lifecycle: resize, signals, clean exit

 Two problems to fix before touching the parser: SIGWINCH (your terminal window resized, and the child shell needs to know), and clean teardown when the child process exits instead of relying on Ctrl-D.

 ```go
// internal/pty/pty.go
package pty

import (
	"os"
	"os/exec"
	"os/signal"
	"syscall"

	creackpty "github.com/creack/pty"
)

type Session struct {
	Cmd  *exec.Cmd
	File *os.File // the pty master
}

func Spawn(shell string) (*Session, error) {
	cmd := exec.Command(shell)
	f, err := creackpty.Start(cmd)
	if err != nil {
		return nil, err
	}
	return &Session{Cmd: cmd, File: f}, nil
}

// WatchResize syncs the pty's window size to the real terminal (fd) whenever
// SIGWINCH fires, and once immediately so the initial size is correct.
func (s *Session) WatchResize(fd int) {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGWINCH)
	go func() {
		for range ch {
			_ = creackpty.InheritSize(os.Stdin, s.File)
		}
	}()
	ch <- syscall.SIGWINCH // trigger initial sync
}

func (s *Session) Close() error {
	return s.File.Close()
}
```

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"

	"golang.org/x/term"

	"github.com/git-emran/termite/internal/pty"
)

func main() {
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}

	sess, err := pty.Spawn(shell)
	if err != nil {
		log.Fatal(err)
	}
	defer sess.Close()

	sess.WatchResize(int(os.Stdin.Fd()))

	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		log.Fatal(err)
	}
	defer term.Restore(int(os.Stdin.Fd()), oldState)

	go func() { _, _ = io.Copy(sess.File, os.Stdin) }()

	_, _ = io.Copy(os.Stdout, sess.File)
	// io.Copy returns when the pty closes, i.e. when the shell exits.
	// That's our natural program end — no signal juggling needed for the happy path.
}
```

 Now resize your window mid-session and run `vim` or `htop` — the child program will correctly redraw to the new size, because it's actually getting `SIGWINCH` itself now (the pty forwards it).

 Notice the shape forming: `main.go` does *wiring*, `internal/pty` does *one job*. That separation is the whole architectural philosophy of this project — every stage from here adds a package, never adds logic to `main.go`.

 ---

 ## Stage 3 — Stop cheating: introduce the screen buffer

 This is the real start of the project. Up to now we've been forwarding the shell's raw bytes straight to your real terminal, which parses them for us. A genuine terminal emulator can't do that — it needs its own model of "what's on screen," because eventually you'd render that model into a GUI canvas, not just relay bytes to another terminal.

 The model is boringly simple: a 2D grid of cells.

 ```go
// internal/vt/screen.go
package vt

// Cell is one character position on the screen, with its rendering attributes.
type Cell struct {
	Ch   rune
	FG   Color
	BG   Color
	Bold bool
}

type Color struct {
	R, G, B uint8
	Default bool // true = "use terminal default", ignore RGB
}

var DefaultColor = Color{Default: true}

// Screen is the grid of cells plus cursor state. This is the single source of
// truth that the parser mutates and the renderer reads — they never talk to
// each other directly.
type Screen struct {
	Cols, Rows int
	Cells      [][]Cell
	CursorX    int
	CursorY    int
	curFG      Color
	curBG      Color
	curBold    bool
}

func NewScreen(cols, rows int) *Screen {
	s := &Screen{Cols: cols, Rows: rows}
	s.Cells = make([][]Cell, rows)
	for i := range s.Cells {
		s.Cells[i] = make([]Cell, cols)
		for j := range s.Cells[i] {
			s.Cells[i][j] = Cell{Ch: ' ', FG: DefaultColor, BG: DefaultColor}
		}
	}
	return s
}

// Put writes a rune at the cursor using current attributes, then advances
// the cursor — this is what happens for every ordinary printable character.
func (s *Screen) Put(r rune) {
	if s.CursorX >= s.Cols {
		s.CursorX = 0
		s.newline()
	}
	s.Cells[s.CursorY][s.CursorX] = Cell{Ch: r, FG: s.curFG, BG: s.curBG, Bold: s.curBold}
	s.CursorX++
}

func (s *Screen) newline() {
	s.CursorY++
	if s.CursorY >= s.Rows {
		s.scrollUp()
		s.CursorY = s.Rows - 1
	}
}

func (s *Screen) scrollUp() {
	copy(s.Cells, s.Cells[1:])
	last := make([]Cell, s.Cols)
	for i := range last {
		last[i] = Cell{Ch: ' ', FG: DefaultColor, BG: DefaultColor}
	}
	s.Cells[s.Rows-1] = last
}

func (s *Screen) CarriageReturn() { s.CursorX = 0 }
func (s *Screen) Newline()        { s.newline() }

func (s *Screen) MoveCursor(x, y int) {
	s.CursorX = clamp(x, 0, s.Cols-1)
	s.CursorY = clamp(y, 0, s.Rows-1)
}

func (s *Screen) Clear() {
	for y := range s.Cells {
		for x := range s.Cells[y] {
			s.Cells[y][x] = Cell{Ch: ' ', FG: DefaultColor, BG: DefaultColor}
		}
	}
	s.CursorX, s.CursorY = 0, 0
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
```

 Now a *minimal* interpreter that only understands three things: printable bytes, `\n`, `\r`, and treats everything else (real escape codes) as invisible for now:

 ```go
// internal/vt/interpret.go
package vt

// Feed is the crudest possible consumer: printable runs through, control
// bytes get minimal handling, and ESC sequences are swallowed whole and
// ignored. This is intentionally wrong — Stage 4 replaces it with a real
// state machine. The point here is proving the Screen model end-to-end.
func (s *Screen) Feed(data []byte) {
	for i := 0; i < len(data); i++ {
		b := data[i]
		switch {
		case b == '\r':
			s.CarriageReturn()
		case b == '\n':
			s.Newline()
		case b == 0x1b: // ESC — skip until we hit a letter (crude, temporary)
			i++
			for i < len(data) && !isFinalByte(data[i]) {
				i++
			}
		case b >= 0x20:
			s.Put(rune(b))
		}
	}
}

func isFinalByte(b byte) bool {
	return b >= 0x40 && b <= 0x7e
}
```

 Wire it up with a renderer that just dumps the whole grid every frame (crude, but correct — diffing comes in Stage 5):

 ```go
// internal/render/render.go
package render

import (
	"fmt"
	"strings"

	"github.com/git-emran/termite/internal/vt"
)

// Full redraws the entire screen every call. Simple, correct, and wasteful —
// exactly the baseline you want before optimizing.
func Full(s *vt.Screen) string {
	var b strings.Builder
	b.WriteString("\x1b[H\x1b[2J") // reset cursor, clear real terminal
	for y := 0; y < s.Rows; y++ {
		for x := 0; x < s.Cols; x++ {
			b.WriteRune(s.Cells[y][x].Ch)
		}
		if y < s.Rows-1 {
			b.WriteString("\r\n")
		}
	}
	fmt.Fprintf(&b, "\x1b[%d;%dH", s.CursorY+1, s.CursorX+1)
	return b.String()
}
```

 And `main.go` now reads from the pty into the `Screen` instead of piping straight to stdout:

 ```go
// cmd/term/main.go (relevant loop, replacing the final io.Copy)
buf := make([]byte, 4096)
screen := vt.NewScreen(80, 24)
for {
	n, err := sess.File.Read(buf)
	if n > 0 {
		screen.Feed(buf[:n])
		os.Stdout.WriteString(render.Full(screen))
	}
	if err != nil {
		break
	}
}
```

 Run it. Plain text (`echo hello`, `cat somefile`) will render correctly. Anything with color (`ls --color`, your shell prompt) will look *worse* than Stage 1 — you'll see stray characters where escape sequences got eaten. That's expected: we're now doing our own interpretation, and it's currently too dumb to understand color codes. Stage 4 fixes that properly instead of just "skipping" escape sequences.

 ---

 ## Stage 4 — A real ANSI/VT100 parser (proper state machine)

 Terminal escape sequences aren't random — they follow a formal grammar (the same one xterm and every VT100-descendant uses). The clean way to parse them is a small state machine, not the string-skipping hack from Stage 3:

 - **Ground** — normal characters, printed directly.
- **Escape** — just saw `ESC` (`0x1b`), waiting to see what kind of sequence this is.
- **CSI** (Control Sequence Introducer, `ESC [`) — waiting to collect parameters (digits, `;`) until a final letter arrives, e.g. `ESC [ 1 ; 31 m` (bold red).

 ```go
// internal/vt/parser.go
package vt

type state int

const (
	stateGround state = iota
	stateEscape
	stateCSI
)

// Parser turns a raw byte stream into calls against a Screen. It owns no
// rendering logic and no I/O — feed it bytes, it mutates the Screen. That
// separation is what makes it unit-testable without a pty or a real terminal.
type Parser struct {
	state  state
	params []int // accumulated CSI numeric parameters
	cur    int   // parameter currently being accumulated
	hasCur bool
	screen *Screen
}

func NewParser(s *Screen) *Parser {
	return &Parser{screen: s}
}

func (p *Parser) Feed(data []byte) {
	for _, b := range data {
		p.step(b)
	}
}

func (p *Parser) step(b byte) {
	switch p.state {
	case stateGround:
		p.ground(b)
	case stateEscape:
		p.escape(b)
	case stateCSI:
		p.csi(b)
	}
}

func (p *Parser) ground(b byte) {
	switch b {
	case 0x1b:
		p.state = stateEscape
	case '\r':
		p.screen.CarriageReturn()
	case '\n':
		p.screen.Newline()
	case '\b':
		p.screen.MoveCursor(p.screen.CursorX-1, p.screen.CursorY)
	default:
		if b >= 0x20 {
			p.screen.Put(rune(b))
		}
	}
}

func (p *Parser) escape(b byte) {
	switch b {
	case '[':
		p.state = stateCSI
		p.params = p.params[:0]
		p.cur = 0
		p.hasCur = false
	default:
		// Unrecognized escape (we're not handling OSC, DCS, etc. yet) —
		// bail back to ground rather than getting stuck.
		p.state = stateGround
	}
}

func (p *Parser) csi(b byte) {
	switch {
	case b >= '0' && b <= '9':
		p.cur = p.cur*10 + int(b-'0')
		p.hasCur = true
	case b == ';':
		p.params = append(p.params, p.paramOrDefault(0))
		p.cur, p.hasCur = 0, false
	case b >= 0x40 && b <= 0x7e:
		p.params = append(p.params, p.paramOrDefault(0))
		p.dispatch(b, p.params)
		p.state = stateGround
	}
}

func (p *Parser) paramOrDefault(def int) int {
	if !p.hasCur {
		return def
	}
	return p.cur
}

// dispatch handles the final byte of a CSI sequence — this is where the
// "language" of the terminal actually lives. Each case is one command.
func (p *Parser) dispatch(final byte, params []int) {
	arg := func(i, def int) int {
		if i < len(params) && params[i] != 0 {
			return params[i]
		}
		return def
	}
	switch final {
	case 'H', 'f': // Cursor Position: ESC[row;colH
		row, col := arg(0, 1), arg(1, 1)
		p.screen.MoveCursor(col-1, row-1)
	case 'A': // Cursor Up
		p.screen.MoveCursor(p.screen.CursorX, p.screen.CursorY-arg(0, 1))
	case 'B': // Cursor Down
		p.screen.MoveCursor(p.screen.CursorX, p.screen.CursorY+arg(0, 1))
	case 'C': // Cursor Forward
		p.screen.MoveCursor(p.screen.CursorX+arg(0, 1), p.screen.CursorY)
	case 'D': // Cursor Back
		p.screen.MoveCursor(p.screen.CursorX-arg(0, 1), p.screen.CursorY)
	case 'J': // Erase in Display (we only implement "clear all" — mode 2)
		if arg(0, 0) == 2 {
			p.screen.Clear()
		}
	case 'm': // SGR — the color/style command
		p.screen.ApplySGR(params)
	}
}
```

 `ApplySGR` lives on `Screen` because it mutates the "current attribute" state that gets stamped onto every subsequent `Put`:

 ```go
// internal/vt/sgr.go — append to package vt
func (s *Screen) ApplySGR(params []int) {
	if len(params) == 0 {
		params = []int{0}
	}
	for i := 0; i < len(params); i++ {
		switch p := params[i]; {
		case p == 0:
			s.curFG, s.curBG, s.curBold = DefaultColor, DefaultColor, false
		case p == 1:
			s.curBold = true
		case p == 22:
			s.curBold = false
		case p >= 30 && p <= 37:
			s.curFG = ansi16[p-30]
		case p == 39:
			s.curFG = DefaultColor
		case p >= 40 && p <= 47:
			s.curBG = ansi16[p-40]
		case p == 49:
			s.curBG = DefaultColor
		case p == 38 || p == 48:
			// Extended color: 38;5;N (256-color) or 38;2;R;G;B (truecolor)
			if i+1 < len(params) && params[i+1] == 2 && i+4 < len(params) {
				c := Color{R: uint8(params[i+2]), G: uint8(params[i+3]), B: uint8(params[i+4])}
				if p == 38 {
					s.curFG = c
				} else {
					s.curBG = c
				}
				i += 4
			} else if i+1 < len(params) && params[i+1] == 5 && i+2 < len(params) {
				c := palette256(params[i+2])
				if p == 38 {
					s.curFG = c
				} else {
					s.curBG = c
				}
				i += 2
			}
		}
	}
}

var ansi16 = [8]Color{
	{R: 0, G: 0, B: 0}, {R: 205, G: 0, B: 0}, {R: 0, G: 205, B: 0}, {R: 205, G: 205, B: 0},
	{R: 0, G: 0, B: 238}, {R: 205, G: 0, B: 205}, {R: 0, G: 205, B: 205}, {R: 229, G: 229, B: 229},
}

func palette256(n int) Color {
	// Simplified: real xterm 256-color has a 6x6x6 cube + grayscale ramp.
	// Good enough to get non-garbled color; refine later if you care.
	if n < 8 {
		return ansi16[n]
	}
	v := uint8((n * 255) / 255)
	return Color{R: v, G: v, B: v}
}
```

 Swap `Screen.Feed` out for `Parser.Feed` in `main.go`. Run `ls --color` again — it should render actual colors now instead of garbage. This is the single biggest milestone in the project: you now have a genuine terminal, not a relay.

 **Why a state machine and not a big regex or string search?** Escape sequences are *streamed* one byte at a time from a pipe — you can't assume a full sequence arrives in one `Read()`. A state machine carries its position across reads naturally (the `state` field *is* "where we are"), while regex-on-buffered-chunks breaks the moment a sequence straddles two reads. This is the same reason JSON/HTTP parsers are usually hand-rolled state machines rather than regex.

 ---

 ## Stage 5 — Diff-based rendering (stop repainting everything)

 `render.Full` redraws all 80×24 cells every single frame — noticeably wasteful, and it'll flicker once you're feeding it output at any real rate (e.g. `yes` or a build log). Real terminals diff the previous frame against the new one and only emit the minimal set of cursor-moves + writes for cells that actually changed.

 ```go
// internal/render/diff.go
package render

import (
	"fmt"
	"strings"

	"github.com/git-emran/termite/internal/vt"
)

// Diff renders only cells that changed since prev, moving the cursor with
// absolute positioning only when the sequence of writes isn't contiguous.
// prev is replaced by curr's contents in-place for the next call.
type Diff struct {
	prev [][]vt.Cell
}

func NewDiff(cols, rows int) *Diff {
	prev := make([][]vt.Cell, rows)
	for i := range prev {
		prev[i] = make([]vt.Cell, cols)
	}
	return &Diff{prev: prev}
}

func (d *Diff) Render(s *vt.Screen) string {
	var b strings.Builder
	lastY, lastX := -2, -2 // force a cursor move on first write

	for y := 0; y < s.Rows; y++ {
		for x := 0; x < s.Cols; x++ {
			cell := s.Cells[y][x]
			if d.prev[y][x] == cell {
				continue
			}
			if y != lastY || x != lastX {
				fmt.Fprintf(&b, "\x1b[%d;%dH", y+1, x+1)
			}
			writeCell(&b, cell)
			d.prev[y][x] = cell
			lastY, lastX = y, x+1
		}
	}
	fmt.Fprintf(&b, "\x1b[%d;%dH", s.CursorY+1, s.CursorX+1)
	return b.String()
}

func writeCell(b *strings.Builder, c vt.Cell) {
	b.WriteString(sgrFor(c))
	if c.Ch == 0 {
		b.WriteRune(' ')
	} else {
		b.WriteRune(c.Ch)
	}
}

func sgrFor(c vt.Cell) string {
	var codes []string
	codes = append(codes, "0") // reset first, then re-apply — simplest correct approach
	if c.Bold {
		codes = append(codes, "1")
	}
	if !c.FG.Default {
		codes = append(codes, fmt.Sprintf("38;2;%d;%d;%d", c.FG.R, c.FG.G, c.FG.B))
	}
	if !c.BG.Default {
		codes = append(codes, fmt.Sprintf("48;2;%d;%d;%d", c.BG.R, c.BG.G, c.BG.B))
	}
	return "\x1b[" + strings.Join(codes, ";") + "m"
}
```

 Swap `render.Full(screen)` for a `diff := render.NewDiff(80,24)` created once, then `diff.Render(screen)` each loop iteration. Test it by running something that repaints fast (`htop`, or `yes | head -1000`) — output should feel smoother and CPU usage on your *own* process should drop noticeably versus Stage 3/4's full-redraw.

 This is also your first real lesson in the classic terminal-emulator tradeoff: **correctness vs. throughput**. Emitting `\x1b[0m` + full color codes for every changed cell is correct but verbose; production terminals track "last emitted SGR state" and only emit deltas. Worth doing once you're comfortable — I'd leave it as a deliberate follow-up exercise rather than Stage 6, so you feel the difference before optimizing it.

 ---

 ## Stage 6 — Scrollback buffer

 Right now, `scrollUp()` in `Screen` just throws the top line away. A usable terminal keeps history you can scroll back through.

 ```go
// internal/vt/scrollback.go — extend Screen
type Screen struct {
	// ...existing fields...
	Scrollback   [][]Cell
	MaxScrollback int
	ViewOffset    int // 0 = live view; >0 = scrolled back N lines
}

func (s *Screen) scrollUp() {
	// Push the line that's about to be discarded into scrollback.
	discarded := make([]Cell, s.Cols)
	copy(discarded, s.Cells[0])
	s.Scrollback = append(s.Scrollback, discarded)
	if s.MaxScrollback > 0 && len(s.Scrollback) > s.MaxScrollback {
		s.Scrollback = s.Scrollback[len(s.Scrollback)-s.MaxScrollback:]
	}

	copy(s.Cells, s.Cells[1:])
	last := make([]Cell, s.Cols)
	for i := range last {
		last[i] = Cell{Ch: ' ', FG: DefaultColor, BG: DefaultColor}
	}
	s.Cells[s.Rows-1] = last
}

// VisibleLine returns the cells for screen row y, accounting for ViewOffset —
// this is what the renderer should read instead of Cells directly once
// scrollback exists, so scrolling doesn't require mutating live state.
func (s *Screen) VisibleLine(y int) []Cell {
	if s.ViewOffset == 0 {
		return s.Cells[y]
	}
	sb := len(s.Scrollback)
	idx := sb - s.ViewOffset + y
	if idx >= 0 && idx < sb {
		return s.Scrollback[idx]
	}
	return s.Cells[y-(sb-idx)] // falls through to live cells near the bottom
}
```

 Wire `Diff.Render` to call `s.VisibleLine(y)` instead of indexing `s.Cells` directly, and bind Shift+PageUp/PageDown (or a mouse wheel event, in Stage 7) to adjust `ViewOffset`. Keep `MaxScrollback` bounded (e.g. 2000 lines) — unbounded scrollback is a classic memory leak in toy terminal emulators.

 ---

 ## Stage 7 — Input: keys, not just bytes

 So far, `io.Copy(sess.File, os.Stdin)` forwards raw stdin bytes straight through — fine for printable characters, but arrow keys, Home/End, function keys, and Ctrl-combinations need to be translated into the escape sequences the *shell-side* program expects to receive (e.g. Up Arrow → `ESC [ A`).

 ```go
// internal/input/keys.go
package input

// Key is a semantic keypress, decoupled from any specific input source
// (terminal reads today; could be a GUI key event later).
type Key int

const (
	KeyUp Key = iota
	KeyDown
	KeyLeft
	KeyRight
	KeyHome
	KeyEnd
)

// Encode returns the byte sequence a shell-side program expects for a given
// key, in the standard ("normal mode") xterm encoding.
func Encode(k Key) []byte {
	switch k {
	case KeyUp:
		return []byte("\x1b[A")
	case KeyDown:
		return []byte("\x1b[B")
	case KeyRight:
		return []byte("\x1b[C")
	case KeyLeft:
		return []byte("\x1b[D")
	case KeyHome:
		return []byte("\x1b[H")
	case KeyEnd:
		return []byte("\x1b[F")
	}
	return nil
}

// Decode reads raw stdin bytes and turns recognized escape sequences into
// Keys, passing everything else through untouched. This mirrors the
// structure of the vt.Parser — same reason: it's a small state machine
// because sequences can straddle reads.
func Decode(data []byte, emit func(raw []byte, key *Key)) {
	for i := 0; i < len(data); i++ {
		if data[i] == 0x1b && i+2 < len(data) && data[i+1] == '[' {
			switch data[i+2] {
			case 'A':
				k := KeyUp
				emit(nil, &k)
				i += 2
				continue
			case 'B':
				k := KeyDown
				emit(nil, &k)
				i += 2
				continue
			case 'C':
				k := KeyRight
				emit(nil, &k)
				i += 2
				continue
			case 'D':
				k := KeyLeft
				emit(nil, &k)
				i += 2
				continue
			}
		}
		emit(data[i:i+1], nil)
	}
}
```

 This is more valuable as a boundary than it might look: your input pipeline now goes stdin → `Decode` → semantic `Key` or raw byte → `Encode` (if needed) → pty. That means later, if you ever add a config file for custom keybindings, or want to support a different input source (say, feeding synthetic keys in tests), you're modifying `Decode`/`Encode`, never touching the pty or parser code.

 ---

 ## Stage 8 — Making it a real project: tests, interfaces, wiring

 Everything above works because each piece only knows about the data structure it needs, not about the pieces around it. Formalize that with interfaces and lock in behavior with tests, so refactors later don't silently break the parser.

 ```go
// internal/vt/parser_test.go
package vt

import "testing"

func TestCursorPosition(t *testing.T) {
	s := NewScreen(10, 5)
	p := NewParser(s)
	p.Feed([]byte("\x1b[3;5Hx"))
	if s.CursorY != 2 || s.CursorX != 5 { // 3;5H is 1-indexed → (row2, col5) after the Put
		t.Fatalf("cursor at (%d,%d), want (2,5)", s.CursorY, s.CursorX)
	}
	if s.Cells[2][4].Ch != 'x' {
		t.Fatalf("expected 'x' at (2,4), got %q", s.Cells[2][4].Ch)
	}
}

func TestSGRColor(t *testing.T) {
	s := NewScreen(10, 5)
	p := NewParser(s)
	p.Feed([]byte("\x1b[31mred\x1b[0m"))
	want := ansi16[1] // red
	for i, ch := range "red" {
		if s.Cells[0][i].Ch != ch {
			t.Fatalf("cell %d: got %q want %q", i, s.Cells[0][i].Ch, ch)
		}
		if s.Cells[0][i].FG != want {
			t.Fatalf("cell %d: got FG %+v want %+v", i, s.Cells[0][i].FG, want)
		}
	}
}

func TestScrollback(t *testing.T) {
	s := NewScreen(5, 2)
	s.MaxScrollback = 10
	p := NewParser(s)
	p.Feed([]byte("row1\r\nrow2\r\nrow3"))
	if len(s.Scrollback) != 1 {
		t.Fatalf("expected 1 scrollback line, got %d", len(s.Scrollback))
	}
}
```

 Run with `go test ./...`. This is exactly the kind of thing that pays off across an interview: "how do you test something that's fundamentally about byte streams and rendering?" — answer: decouple the parser from all I/O so it's a pure function of `(bytes in) → (screen state)`, which is trivially unit-testable without a pty at all.

 Finally, formalize the seam between packages so `main.go` stays pure wiring:

 ```go
// internal/vt/interfaces.go
package vt

// Renderer is anything that can turn a Screen into terminal output.
// render.Full and render.Diff both satisfy this.
type Renderer interface {
	Render(s *Screen) string
}
```

 ```go
// cmd/term/main.go — final shape
func main() {
	shell := os.Getenv("SHELL")
	sess, err := pty.Spawn(shell)
	must(err)
	defer sess.Close()
	sess.WatchResize(int(os.Stdin.Fd()))

	old, err := term.MakeRaw(int(os.Stdin.Fd()))
	must(err)
	defer term.Restore(int(os.Stdin.Fd()), old)

	screen := vt.NewScreen(80, 24)
	parser := vt.NewParser(screen)
	renderer := render.NewDiff(80, 24)

	go func() { _, _ = io.Copy(sess.File, os.Stdin) }()

	buf := make([]byte, 4096)
	for {
		n, err := sess.File.Read(buf)
		if n > 0 {
			parser.Feed(buf[:n])
			os.Stdout.WriteString(renderer.Render(screen))
		}
		if err != nil {
			return
		}
	}
}

func must(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
```

 ---

 ## Where to go from here (deliberately left as exercises)

 Roughly in order of value-to-effort:

 1. **Dynamic resize of the `Screen` itself** — right now cols/rows are hardcoded to 80×24; wire `SIGWINCH` (Stage 2) to also call a `Screen.Resize(cols, rows)` that reflows the grid.
2. **Alt-screen buffer** (`ESC[?1049h/l`) — what `vim`/`less` use to take over the screen and restore it on exit. Straightforward once you have `Screen` as a struct: just swap in a second instance.
3. **Wide/combining Unicode characters** — CJK characters are 2 cells wide; emoji and combining marks need special handling. This is where most toy terminal emulators quietly give up; doing it right involves a Unicode width table (`go get golang.org/x/text/width` territory conceptually, though you can hand-roll a simplified East-Asian-width table).
4. **Mouse reporting** (`ESC[?1000h` and friends) — programs like `tmux`/`vim` request mouse events in a specific encoded format.
5. **True incremental SGR** (mentioned in Stage 5) — track last-emitted attribute state in the renderer instead of resetting every cell.

 I'd genuinely stop and sit with Stage 4 and Stage 5 for a while before moving on — that's where the actual "terminal emulator" concepts live, and everything after is breadth, not depth.