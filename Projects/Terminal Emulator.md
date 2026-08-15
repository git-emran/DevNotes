# Building a Terminal Emulator in Go — Corrected, Incremental Guide

 I built every stage of this in a real sandbox (`go build`, `go vet`, `go test`, and actually drove the binary through a pty) before writing it down. The original guide had five bugs that would stop a reader cold — including Stage 1 crashing before it prints anything, a struct that gets redeclared and fails to compile in Stage 6, and a `VisibleLine` function that panics on the most common scroll-back case. All of that is fixed below, and every stage now shows the **complete** file, not a fragment — so you're never guessing how a snippet fits into what you already have.

 Each stage ends with a command you can literally run to confirm it worked, and a short note on what's still broken on purpose (so the next stage has something to fix).

 ## What you're building

 1. **A PTY (pseudo-terminal)** — a kernel construct that fools a shell into thinking it's talking to a real terminal.
2. **A parser** for the escape-sequence language (VT100/ANSI/xterm) programs use to say "move cursor here," "make this text red," "clear the screen."
3. **A screen model + renderer** — a grid of cells the parser mutates and the renderer paints.

 We use `github.com/creack/pty` for the actual PTY syscalls — allocating pseudo-terminals involves ioctls and platform-specific cgo that isn't worth hand-rolling. Everything else (parser, screen buffer, renderer, state machine) we write ourselves.

 Final layout:

 ```
termite/
  cmd/term/main.go        # wiring only, no logic
  internal/pty/           # spawn shell, resize handling
  internal/vt/             # escape-sequence parser + screen buffer (the heart of it)
  internal/render/         # diff-based renderer
  internal/input/          # keyboard → escape sequence translation
```

 ## Setup

 ```bash
mkdir -p termite/cmd/term
cd termite
go mod init github.com/git-emran/termite
go get github.com/creack/pty
go get golang.org/x/term
```

 **Bug fixed:** the original setup only ran `mkdir termite && cd termite`. It never created `cmd/term/`, so the very first `go run ./cmd/term` fails with "no such directory" before you've written a line of your own code. Use `mkdir -p termite/cmd/term` up front.

 ---

 ## Stage 1 — Raw passthrough

 Prove the plumbing works: spawn a shell in a PTY, copy bytes in both directions, put your own terminal in raw mode so keystrokes pass through unmangled.

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

// shellPath falls back to /bin/bash when $SHELL is unset — which is the
// normal case in Docker containers, CI runners, and anything launched
// without a login shell, not an edge case.
func shellPath() string {
	if s := os.Getenv("SHELL"); s != "" {
		return s
	}
	return "/bin/bash"
}

func main() {
	cmd := exec.Command(shellPath())

	ptmx, err := pty.Start(cmd)
	if err != nil {
		log.Fatal(err)
	}
	defer ptmx.Close()

	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		log.Fatal(err)
	}
	defer term.Restore(int(os.Stdin.Fd()), oldState)

	go func() { _, _ = io.Copy(ptmx, os.Stdin) }()
	_, _ = io.Copy(os.Stdout, ptmx)
}
```

 **Bug fixed — and this is the one you flagged:** the original used `exec.Command(os.Getenv("SHELL"))` with no fallback. I ran that exact code and it dies immediately with `exec: no command`, because `$SHELL` is empty in this sandbox — and it's empty in plenty of real environments too (containers, CI, some terminal launchers, `su` without `-`). `exec.Command("")` isn't a "sometimes" bug, it's a coin flip on whether the guide's first program even starts. Confirmed fixed by driving the binary through a real pty and getting a working shell session instead of an instant crash.

 **Run it:**

 ```bash
go run ./cmd/term
```

 You'll get a working shell. Type `ls --color`, and you'll see raw escape codes like `^[[0m` mixed into the output — that's your proof you need a parser. Ctrl-D or `exit` to quit (no clean shutdown yet — that's Stage 2).

 **What's still wrong, on purpose:** no resize handling (resize your window, the shell's `$COLUMNS` won't update), and no interpretation of anything — we're relying on *your real terminal* to decode the escape codes for us. A real terminal emulator can't outsource that job.

 ---

 ## Stage 2 — Lifecycle: resize, signals, clean exit

 Two problems: SIGWINCH (your terminal resized, the child shell needs to know), and giving the pty/shell logic its own package instead of stuffing it into `main.go`.

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
	// io.Copy returns when the pty closes, i.e. when the shell exits — that's
	// our natural program end, no signal juggling needed for the happy path.
}
```

 **Run it:**

 ```bash
go run ./cmd/term
```

 Resize your window mid-session and run `vim` or `htop` — the child program redraws to the new size correctly, because it's now actually receiving `SIGWINCH` (the pty forwards it). Notice the shape: `main.go` does wiring, `internal/pty` does one job. Every stage from here adds a package; it never adds logic to `main.go`.

 ---

 ## Stage 3 — Stop cheating: introduce the screen buffer

 Up to now we've forwarded the shell's raw bytes straight to your *real* terminal, which parses them for us. A real terminal emulator can't do that — it needs its own model of "what's on screen." The model is a 2D grid of cells.

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
// truth that the parser mutates and the renderer reads.
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

 A minimal interpreter that only understands printable bytes, `\n`, `\r`, and swallows real escape codes whole for now:

 ```go
// internal/vt/interpret.go
package vt

// Feed is the crudest possible consumer: printable runs through, control
// bytes get minimal handling, ESC sequences are swallowed and ignored.
// This is intentionally wrong — Stage 4 replaces it with a real state
// machine. The point here is proving the Screen model end-to-end.
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

 A renderer that dumps the whole grid every frame (crude but correct — diffing is Stage 5):

 ```go
// internal/render/render.go
package render

import (
	"fmt"
	"strings"

	"github.com/git-emran/termite/internal/vt"
)

// Full redraws the entire screen every call. Simple, correct, wasteful —
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

 And the **complete** `main.go` — the original guide only showed "the relevant loop, replacing the final `io.Copy`," which leaves you guessing whether the stdin-forwarding goroutine from Stage 2 is still needed (it is):

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"

	"golang.org/x/term"

	"github.com/git-emran/termite/internal/pty"
	"github.com/git-emran/termite/internal/render"
	"github.com/git-emran/termite/internal/vt"
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

	screen := vt.NewScreen(80, 24)
	buf := make([]byte, 4096)
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
}
```

 **Run it:**

 ```bash
go run ./cmd/term
```

 Plain text (`echo hello`, `cat somefile`) renders correctly. Anything with color (`ls --color`, your shell prompt) will look *worse* than Stage 1 — stray characters where escape sequences got eaten. Expected: we're doing our own interpretation now, and it's currently too dumb to understand color codes. Stage 4 fixes that properly.

 ---

 ## Stage 4 — A real ANSI/VT100 parser

 Escape sequences follow a formal grammar — the same one xterm and every VT100-descendant uses. The clean way to parse them is a small state machine:

 - **Ground** — normal characters, printed directly.
- **Escape** — just saw `ESC` (`0x1b`), waiting to see what kind of sequence this is.
- **CSI** (`ESC [`) — collecting parameters (digits, `;`) until a final letter arrives, e.g. `ESC [ 1 ; 31 m` (bold red).

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
	params []int
	cur    int
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
		// Unrecognized escape (no OSC/DCS handling yet) — bail to ground
		// rather than getting stuck.
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
	case 'A':
		p.screen.MoveCursor(p.screen.CursorX, p.screen.CursorY-arg(0, 1))
	case 'B':
		p.screen.MoveCursor(p.screen.CursorX, p.screen.CursorY+arg(0, 1))
	case 'C':
		p.screen.MoveCursor(p.screen.CursorX+arg(0, 1), p.screen.CursorY)
	case 'D':
		p.screen.MoveCursor(p.screen.CursorX-arg(0, 1), p.screen.CursorY)
	case 'J': // Erase in Display — we only implement "clear all" (mode 2)
		if arg(0, 0) == 2 {
			p.screen.Clear()
		}
	case 'm': // SGR — color/style
		p.screen.ApplySGR(params)
	}
}
```

 `ApplySGR` mutates the "current attribute" state that gets stamped onto every subsequent `Put`:

 ```go
// internal/vt/sgr.go
package vt

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

// palette256 is a placeholder, not a real xterm 256-color mapping — it's a
// TODO left for you, not "good enough." Real 256-color has a 6x6x6 cube plus
// a grayscale ramp above index 15; this just clamps to grayscale for now.
func palette256(n int) Color {
	if n < 8 {
		return ansi16[n]
	}
	v := uint8(n % 256)
	return Color{R: v, G: v, B: v}
}
```

 Full `main.go`, wired to the real parser:

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"

	"golang.org/x/term"

	"github.com/git-emran/termite/internal/pty"
	"github.com/git-emran/termite/internal/render"
	"github.com/git-emran/termite/internal/vt"
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

	screen := vt.NewScreen(80, 24)
	parser := vt.NewParser(screen)

	buf := make([]byte, 4096)
	for {
		n, err := sess.File.Read(buf)
		if n > 0 {
			parser.Feed(buf[:n])
			os.Stdout.WriteString(render.Full(screen))
		}
		if err != nil {
			break
		}
	}
}
```

 **Test the parser in isolation first** (no pty needed — this is the payoff of keeping the parser pure):

 ```go
// internal/vt/parser_test.go
package vt

import "testing"

func TestCursorPosition(t *testing.T) {
	s := NewScreen(10, 5)
	p := NewParser(s)
	p.Feed([]byte("\x1b[3;5Hx"))
	if s.CursorY != 2 || s.CursorX != 5 {
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
	want := ansi16[1]
	for i, ch := range "red" {
		if s.Cells[0][i].Ch != ch {
			t.Fatalf("cell %d: got %q want %q", i, s.Cells[0][i].Ch, ch)
		}
		if s.Cells[0][i].FG != want {
			t.Fatalf("cell %d: got FG %+v want %+v", i, s.Cells[0][i].FG, want)
		}
	}
}
```

 ```bash
go test ./internal/vt/... -v
```

 Both pass — the parser correctly tracks cursor position and color state.

 **Bug fixed:** the original guide said "Run `ls --color` again — it should render actual colors now instead of garbage." **That's false as written.** `render.Full` — the only renderer that exists at this point — never emits an SGR/color escape code; it only writes `b.WriteRune(cell.Ch)`. I ran it: garbling stops (parser correctly consumes the codes instead of leaking stray bytes), but nothing is actually colored yet, because nothing in the render path knows how to. That's genuinely true only once Stage 5 ships. Don't go looking for color here — you won't find it, and it's not because your parser is wrong.

 **Run it:**

 ```bash
go run ./cmd/term
```

 `ls --color` should render clean text with no stray escape-code garbage (that part of the original claim holds). Color itself is next.

 ---

 ## Stage 5 — Diff-based rendering (and where color actually shows up)

 `render.Full` redraws all 80×24 cells every frame — wasteful, and it'll flicker under any real load (`yes`, a build log). Real terminals diff the previous frame against the new one and emit only the minimal cursor-moves + writes for cells that changed — and this is also the renderer that actually emits color:

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

 Full `main.go`:

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"

	"golang.org/x/term"

	"github.com/git-emran/termite/internal/pty"
	"github.com/git-emran/termite/internal/render"
	"github.com/git-emran/termite/internal/vt"
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

	screen := vt.NewScreen(80, 24)
	parser := vt.NewParser(screen)
	renderer := render.NewDiff(80, 24)

	buf := make([]byte, 4096)
	for {
		n, err := sess.File.Read(buf)
		if n > 0 {
			parser.Feed(buf[:n])
			os.Stdout.WriteString(renderer.Render(screen))
		}
		if err != nil {
			break
		}
	}
}
```

 **Run it:**

 ```bash
go run ./cmd/term
```

 Run `ls --color` — **this is the first stage where you'll actually see color**, because `sgrFor` emits real `38;2;R;G;B` truecolor codes. I verified this directly: with `render.Full` (Stage 4) a red `printf` prints as plain white text; with `render.NewDiff` (this stage) the exact `\x1b[38;2;205;0;0m` sequence shows up in the output stream. Run something that repaints fast (`htop`, `yes | head -1000`) — it should feel smoother and your own process's CPU use should drop versus Stage 3/4's full-redraw.

 This is your first real lesson in the classic terminal-emulator tradeoff: **correctness vs. throughput**. Emitting `\x1b[0m` plus full color codes for every changed cell is correct but verbose; production terminals track "last emitted SGR state" and only emit deltas. Worth doing once you're comfortable — I'd leave it as a deliberate follow-up exercise rather than folding it into the next stage, so you feel the difference before optimizing it.

 ---

 ## Stage 6 — Scrollback buffer

 Right now `scrollUp()` just throws the top line away. A usable terminal keeps history you can scroll back through. **This stage edits `Screen` in place** — it does not redeclare it in a new file. (The original guide showed this as a fresh `type Screen struct { ... }` in a new `scrollback.go` with a `// ...existing fields...` comment. I tried that literally: it fails to compile with `Screen redeclared in this block` and `method Screen.scrollUp already declared` — Go doesn't support extending a struct or overriding a method across files that way. You have to edit the original.)

 Add three fields to `Screen` in `internal/vt/screen.go`:

 ```go
// internal/vt/screen.go — Screen struct, with three new fields added
type Screen struct {
	Cols, Rows int
	Cells      [][]Cell
	CursorX    int
	CursorY    int
	curFG      Color
	curBG      Color
	curBold    bool

	Scrollback    [][]Cell
	MaxScrollback int
	ViewOffset    int // 0 = live view; >0 = scrolled back N lines
}
```

 Replace the existing `scrollUp` method (same file) with:

 ```go
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
```

 New file, only the new function:

 ```go
// internal/vt/scrollback.go
package vt

// VisibleLine returns the cells for screen row y, accounting for ViewOffset.
// ViewOffset counts how many lines back from "live" the viewport is
// scrolled; it's clamped here to the amount of scrollback that actually
// exists, so a stale or oversized offset can't index out of range.
func (s *Screen) VisibleLine(y int) []Cell {
	if s.ViewOffset == 0 {
		return s.Cells[y]
	}
	sb := len(s.Scrollback)
	offset := s.ViewOffset
	if offset > sb {
		offset = sb
	}
	idx := sb - offset + y // logical line index: scrollback, then live rows
	if idx < sb {
		return s.Scrollback[idx]
	}
	return s.Cells[idx-sb]
}
```

 **Bug fixed:** the original `VisibleLine` used `s.Cells[y-(sb-idx)]` as its fallback, with no clamping on `ViewOffset`. I wrote a test that scrolls a 3-row screen back by 1 line after 2 lines have gone into scrollback — the single most ordinary "user hit PageUp once" scenario — and it panics: `index out of range [3] with length 3`. The math only worked by accident when `idx` stayed inside `[0, sb)`; as soon as a real scroll pushed `idx` past `sb` (which happens constantly once you have more live rows than backlog), the fallback formula produced a negative offset and read off the end of the slice. The fixed version above clamps `ViewOffset` and computes the fallback index directly from the logical line-index arithmetic instead of the reversed subtraction.

 **Test it** (this is the same scenario that crashed the original):

 ```go
// internal/vt/scrollback_test.go
package vt

import "testing"

func TestScrollback(t *testing.T) {
	s := NewScreen(5, 2)
	s.MaxScrollback = 10
	p := NewParser(s)
	p.Feed([]byte("row1\r\nrow2\r\nrow3"))
	if len(s.Scrollback) != 1 {
		t.Fatalf("expected 1 scrollback line, got %d", len(s.Scrollback))
	}
}

func TestVisibleLineDoesNotPanic(t *testing.T) {
	s := NewScreen(5, 3)
	s.MaxScrollback = 100
	p := NewParser(s)
	p.Feed([]byte("L1\r\nL2\r\nL3\r\nL4\r\nL5")) // pushes L1, L2 into scrollback
	s.ViewOffset = 1
	for y := 0; y < s.Rows; y++ {
		_ = s.VisibleLine(y) // would panic on the original code
	}
}
```

 ```bash
go test ./internal/vt/... -v
```

 Both pass. Wire `render.Diff.Render` to call `s.VisibleLine(y)` instead of indexing `s.Cells` directly if you want the renderer to respect scrolling, and bind Shift+PageUp/PageDown (or a mouse wheel event in Stage 7) to adjust `ViewOffset`. Keep `MaxScrollback` bounded (e.g. 2000 lines) — unbounded scrollback is a classic memory leak in toy terminal emulators.

 ---

 ## Stage 7 — Input: keys, not just bytes

 So far `io.Copy(sess.File, os.Stdin)` forwards raw stdin bytes straight through — fine for printable characters, but arrow keys and other special keys need translating into the sequences the shell-side program expects (Up Arrow → `ESC [ A`).

 ```go
// internal/input/keys.go
package input

// Key is a semantic keypress, decoupled from any specific input source.
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
// Keys, passing everything else through untouched. Note: this only
// recognizes arrow keys (A/B/C/D) — Home/End round-trip through Encode but
// Decode doesn't parse the sequences xterm actually sends for them (which
// vary by terminal). Treat this as a starting point, not a complete map.
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

 This is more valuable as a boundary than it looks: your input pipeline goes stdin → `Decode` → semantic `Key` or raw byte → `Encode` (if needed) → pty. Later, a config file for custom keybindings, or a different input source (synthetic keys in tests), means touching `Decode`/`Encode` only — never the pty or parser code.

 Sanity-check it compiles and behaves with a quick unit test:

 ```go
// internal/input/keys_test.go
package input

import "testing"

func TestDecodeArrowKey(t *testing.T) {
	var got *Key
	Decode([]byte("\x1b[A"), func(raw []byte, key *Key) {
		if key != nil {
			got = key
		}
	})
	if got == nil || *got != KeyUp {
		t.Fatalf("expected KeyUp, got %v", got)
	}
}
```

 ```bash
go test ./internal/input/... -v
```

 This stage is standalone — it isn't wired into `main.go` yet, so there's nothing to run end-to-end here beyond the test above. Wiring it in (swapping the raw `io.Copy` for a `Decode`/`Encode` loop) is a reasonable next exercise once Stage 8's structure is in place.

 ---

 ## Stage 8 — Making it a real project: tests, interfaces, wiring

 Everything above works because each piece only knows about the data structure it needs. Formalize that with an interface, and lock in behavior with tests.

 ```go
// internal/vt/interfaces.go
package vt

// Renderer is anything that can turn a Screen into terminal output.
type Renderer interface {
	Render(s *Screen) string
}
```

 **Bug fixed:** the original guide said "`render.Full` and `render.Diff` both satisfy this." **That's not possible in Go, and I confirmed it fails to compile.** `render.Full` is a plain package-level function (`func Full(s *vt.Screen) string`); it has no method, so it cannot implement an interface that requires a `Render` method — only `render.Diff`, which has an actual `Render` method on the `*Diff` type, does. I wrote exactly the line the guide implies (`var r vt.Renderer = render.Full`) and `go vet` rejects it: *"does not implement vt.Renderer (missing method Render)."* If you want `Full` to satisfy the interface too, give it a type to hang the method off of:

 ```go
// internal/render/render.go — Full turned into a type with a Render method,
// so it can satisfy vt.Renderer the way Diff does.
package render

import (
	"fmt"
	"strings"

	"github.com/git-emran/termite/internal/vt"
)

type FullRenderer struct{}

func (FullRenderer) Render(s *vt.Screen) string {
	var b strings.Builder
	b.WriteString("\x1b[H\x1b[2J")
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

 Now both really do satisfy `vt.Renderer` — `var r vt.Renderer = render.FullRenderer{}` and `var r vt.Renderer = render.NewDiff(80, 24)` both compile, verified.

 ```bash
go test ./... -v
go vet ./...
go build ./...
```

 All three succeed clean. Final `main.go` — pure wiring, no logic:

 ```go
// cmd/term/main.go
package main

import (
	"io"
	"log"
	"os"

	"golang.org/x/term"

	"github.com/git-emran/termite/internal/pty"
	"github.com/git-emran/termite/internal/render"
	"github.com/git-emran/termite/internal/vt"
)

func must(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/bin/bash"
	}

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
```

 ```bash
go run ./cmd/term
```

 This is exactly the kind of thing that pays off in an interview: "how do you test something that's fundamentally about byte streams and rendering?" — decouple the parser from all I/O so it's a pure function of `(bytes in) → (screen state)`, unit-testable without a pty at all. That's what made it possible to catch the Stage 6 panic and the Stage 8 interface bug with `go test` and `go vet` instead of by staring at output in a live terminal.

 ### Summary of what was fixed in Stages 1–8

 | Stage | Original claim | What actually happens | Fix |
| --- | --- | --- | --- |
| Setup | `mkdir termite && cd termite` | `go run ./cmd/term`fails —`cmd/term/`was never created | `mkdir -p termite/cmd/term` |
| 1 | Works out of the box | Crashes with`exec: no command`whenever`$SHELL`is unset (common in containers/CI) | Fallback to`/bin/bash` |
| 3 | Shows "the relevant loop" | Ambiguous how it merges with Stage 2's stdin goroutine | Every stage now shows the complete file |
| 4 | "You'll see actual colors now" | `render.Full`never emits SGR codes — no renderer at this stage can show color | Corrected claim; color is genuinely Stage 5's milestone |
| 6 | New file redeclares`Screen`and`scrollUp` | Fails to compile: "Screen redeclared," "method already declared" | Edit`screen.go`in place; new file only adds`VisibleLine` |
| 6 | `VisibleLine`fallback formula | Panics with index-out-of-range on an ordinary single-PageUp scroll | Rewrote with clamped offset + logical-index math |
| 8 | "`render.Full`and`render.Diff`both satisfy`Renderer`" | Doesn't compile —`Full`is a function, not a method, so it can't implement an interface | Wrapped`Full`in a`FullRenderer`type with a`Render`method |

 Every code block through Stage 8 was actually built (`go build`), vetted (`go vet`), and where applicable unit-tested or driven through a live pty with a real shell.

 ---

 ## Stage 9 — A real window (kitty/iTerm-style), not a passthrough

 Everything above (Stages 1–8) runs *inside* whatever terminal launched it and hands escape codes back to that outer terminal to render. This stage is different: it opens its own OS window and becomes a standalone app you'd launch from a dock or app switcher — the way you'd launch kitty or iTerm2 — instead of running it from inside another terminal.

 I built and verified this in a real sandbox: installed Go, SDL2 + dev headers, a monospace font, fetched the SDL bindings, wrote the code below, and ran `go build ./...`, `go vet ./...`, `gofmt -l .`, and an actual headless run of the compiled binary (`SDL_VIDEODRIVER=dummy`) — it initialized SDL/TTF, opened the font, created the window and renderer, spawned a real `/bin/bash`, and sat in the event loop for several seconds with no panic or error output. I don't have a display in that sandbox, so I could not verify actual pixel output, live keyboard/mouse interaction, or on-screen glyph alignment — that part is one `go run ./cmd/termgui` away on a machine with a display.

 **The key design decision: `internal/vt` and `internal/pty` barely change.** That's the payoff of Stage 4's insistence that the parser be a pure `(bytes in) → (screen state)` function with no I/O — `cmd/term` (terminal passthrough) and `cmd/termgui` (new window) end up being two different renderers plugged into the same `Screen`/`Parser`/`pty.Session`. The only additions to the existing packages are two resize methods — a GUI window can be resized by dragging an edge, and there's no `SIGWINCH`-from-a-real-terminal to inherit, so the window has to push the new size itself:

 ```go
// internal/vt/screen.go — add this method to the existing Screen type
// (alongside VisibleLine from Stage 6)

// Resize reflows the grid to new dimensions, preserving existing content in
// the top-left region. The GUI needs this because, unlike a fixed-size
// terminal.exe window, a resizable app window can change cols/rows every
// frame the user drags an edge.
func (s *Screen) Resize(cols, rows int) {
	if cols == s.Cols && rows == s.Rows {
		return
	}
	newCells := make([][]Cell, rows)
	for y := 0; y < rows; y++ {
		newCells[y] = make([]Cell, cols)
		for x := 0; x < cols; x++ {
			if y < s.Rows && x < s.Cols {
				newCells[y][x] = s.Cells[y][x]
			} else {
				newCells[y][x] = Cell{Ch: ' ', FG: DefaultColor, BG: DefaultColor}
			}
		}
	}
	s.Cells = newCells
	s.Cols, s.Rows = cols, rows
	s.CursorX = clamp(s.CursorX, 0, cols-1)
	s.CursorY = clamp(s.CursorY, 0, rows-1)
}
```

 ```go
// internal/pty/pty.go — add this method to the existing Session type

// Resize tells the pty (and therefore the shell/program inside it) the
// terminal is now cols x rows. This is what the GUI window calls on every
// resize/maximize event — there's no SIGWINCH to inherit from, because
// there's no controlling terminal; the GUI window IS the terminal now.
func (s *Session) Resize(cols, rows int) error {
	return creackpty.Setsize(s.File, &creackpty.Winsize{
		Rows: uint16(rows),
		Cols: uint16(cols),
	})
}
```

 **Library choice:** I originally reached for `gioui.org`, the more idiomatic pure-Go option — but it's served from a vanity import domain (`gioui.org`) that wasn't network-reachable from my sandbox (403, not in the egress allowlist), and the same problem hits `golang.org/x/...` packages under a strict `GOPROXY=direct` setup. `github.com/veandco/go-sdl2` resolves as a direct GitHub import with no redirect, and SDL2 is a reasonable real-world choice here too: a hardware-accelerated 2D renderer, real font rendering via SDL_ttf, and proper text-input event handling that correctly deals with IME/dead-keys instead of hand-rolling it the way Stage 7's `Decode()` sketch did.

 New package, `internal/gui`:

 ```go
// internal/gui/gui.go
//
// Package gui is the new layer this stage adds. Everything in internal/vt
// and internal/pty is otherwise untouched — that's the whole point of
// having kept the parser and screen model free of any I/O or rendering
// assumptions back in Stage 4. A GUI build and a terminal-passthrough
// build (cmd/term) are just two different renderers plugged into the same
// Screen/Parser/pty.Session.
//
// This is closer to how kitty/iTerm/alacritty actually work than the
// Stage 1-8 build: instead of re-emitting ANSI escape codes into whatever
// terminal launched you, this package opens its own OS window, rasterizes
// glyphs itself, and IS the terminal — there's no "outer" terminal
// interpreting anything for you anymore.
package gui

import (
	"fmt"
	"runtime"

	"github.com/veandco/go-sdl2/sdl"
	"github.com/veandco/go-sdl2/ttf"

	"github.com/git-emran/termite/internal/pty"
	"github.com/git-emran/termite/internal/vt"
)

func init() {
	// SDL's event loop and renderer must stay pinned to one OS thread for
	// the lifetime of the app — this is an SDL requirement, not a Go one.
	runtime.LockOSThread()
}

// Config controls window/font setup. FontPath must point at a monospace
// TTF; cell width/height are derived from the font's own metrics rather
// than hardcoded, so swapping fonts doesn't require touching layout code.
type Config struct {
	FontPath string
	FontSize int
	Cols     int
	Rows     int
	Title    string
	Shell    string
}

// App owns the window, the glyph cache, and the terminal session. Nothing
// outside this package needs to know SDL exists.
type App struct {
	cfg Config

	window   *sdl.Window
	renderer *sdl.Renderer
	font     *ttf.Font

	cellW, cellH int32 // pixel size of one character cell, derived from the font

	glyphs map[glyphKey]*sdl.Texture // rendered-once glyph cache (see atlas.go)

	screen *vt.Screen
	parser *vt.Parser
	sess   *pty.Session

	fromPTY chan []byte // pty.File.Read() results, decoupled from the SDL event loop
	quit    chan struct{}
}

// New creates the window, loads the font, measures the cell size from it,
// and sizes the initial Screen to fit — this mirrors what a real terminal
// app does on launch: pick a window size, THEN tell the shell what
// cols/rows that maps to, not the other way around.
func New(cfg Config) (*App, error) {
	if err := sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS); err != nil {
		return nil, fmt.Errorf("sdl init: %w", err)
	}
	if err := ttf.Init(); err != nil {
		return nil, fmt.Errorf("ttf init: %w", err)
	}

	font, err := ttf.OpenFont(cfg.FontPath, cfg.FontSize)
	if err != nil {
		return nil, fmt.Errorf("open font %s: %w", cfg.FontPath, err)
	}

	// Measure a representative glyph to get the fixed cell size. Monospace
	// fonts guarantee every glyph advances by the same width; height comes
	// from the font's own line-height metric, not a guess.
	metrics, err := font.GlyphMetrics('M')
	if err != nil {
		return nil, fmt.Errorf("glyph metrics: %w", err)
	}
	cellW := int32(metrics.Advance)
	cellH := int32(font.Height())

	winW := cellW * int32(cfg.Cols)
	winH := cellH * int32(cfg.Rows)

	window, err := sdl.CreateWindow(cfg.Title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
		winW, winH, sdl.WINDOW_SHOWN|sdl.WINDOW_RESIZABLE)
	if err != nil {
		return nil, fmt.Errorf("create window: %w", err)
	}

	renderer, err := sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED)
	if err != nil {
		// Fall back to software rendering — some CI/headless/VM setups have
		// no GPU-accelerated renderer available at all.
		renderer, err = sdl.CreateRenderer(window, -1, sdl.RENDERER_SOFTWARE)
		if err != nil {
			return nil, fmt.Errorf("create renderer: %w", err)
		}
	}

	sdl.StartTextInput() // enables TextInputEvent delivery for handleTextInput

	sess, err := pty.Spawn(cfg.Shell)
	if err != nil {
		return nil, fmt.Errorf("spawn shell: %w", err)
	}
	_ = sess.Resize(cfg.Cols, cfg.Rows)

	screen := vt.NewScreen(cfg.Cols, cfg.Rows)
	screen.MaxScrollback = 2000

	a := &App{
		cfg:      cfg,
		window:   window,
		renderer: renderer,
		font:     font,
		cellW:    cellW,
		cellH:    cellH,
		glyphs:   make(map[glyphKey]*sdl.Texture),
		screen:   screen,
		parser:   vt.NewParser(screen),
		sess:     sess,
		fromPTY:  make(chan []byte, 64),
		quit:     make(chan struct{}),
	}
	return a, nil
}

// Run starts the pty-reader goroutine and blocks on the SDL event loop
// until the window is closed or the child shell exits. This is the "new
// window" entry point — cmd/termgui calls only this.
func (a *App) Run() error {
	go a.readPTY()

	// No timer subsystem needed: WaitEventTimeout below already wakes the
	// loop at least every 20ms even with no window events pending, which
	// is what drives the redraw cadence.
	running := true
	for running {
		event := sdl.WaitEventTimeout(20)
		for event != nil {
			switch e := event.(type) {
			case *sdl.QuitEvent:
				running = false
			case *sdl.WindowEvent:
				if e.Event == sdl.WINDOWEVENT_RESIZED || e.Event == sdl.WINDOWEVENT_SIZE_CHANGED {
					a.handleResize(e.Data1, e.Data2)
				}
			case *sdl.KeyboardEvent:
				if e.Type == sdl.KEYDOWN {
					a.handleKeyDown(e.Keysym)
				}
			case *sdl.TextInputEvent:
				a.handleTextInput(e.GetText())
			case *sdl.MouseWheelEvent:
				a.handleScroll(e.Y)
			}
			event = sdl.PollEvent()
		}

		select {
		case data, ok := <-a.fromPTY:
			if !ok {
				running = false
				break
			}
			a.parser.Feed(data)
		case <-a.quit:
			running = false
		default:
		}

		if err := a.draw(); err != nil {
			return err
		}
	}
	return a.Close()
}

// readPTY runs on its own goroutine because File.Read blocks — it can't
// share a thread with the SDL event loop without stalling rendering
// whenever the shell goes quiet (e.g. sitting at an idle prompt).
func (a *App) readPTY() {
	buf := make([]byte, 4096)
	for {
		n, err := a.sess.File.Read(buf)
		if n > 0 {
			chunk := make([]byte, n)
			copy(chunk, buf[:n])
			a.fromPTY <- chunk
		}
		if err != nil {
			close(a.fromPTY)
			return
		}
	}
}

// handleResize recomputes cols/rows from the new pixel size and propagates
// that to both the Screen (so the parser lays text out correctly) and the
// pty (so the shell/program gets SIGWINCH with correct values) — this is
// the GUI equivalent of Stage 2's WatchResize, minus the "inherit from a
// real controlling terminal" part, because here there isn't one.
func (a *App) handleResize(pixelW, pixelH int32) {
	cols := int(pixelW / a.cellW)
	rows := int(pixelH / a.cellH)
	if cols < 1 {
		cols = 1
	}
	if rows < 1 {
		rows = 1
	}
	if cols == a.screen.Cols && rows == a.screen.Rows {
		return
	}
	a.screen.Resize(cols, rows)
	_ = a.sess.Resize(cols, rows)
}

func (a *App) handleScroll(y int32) {
	a.screen.ViewOffset += int(y) * 3
	if a.screen.ViewOffset < 0 {
		a.screen.ViewOffset = 0
	}
	if a.screen.ViewOffset > len(a.screen.Scrollback) {
		a.screen.ViewOffset = len(a.screen.Scrollback)
	}
}

func (a *App) Close() error {
	for _, tex := range a.glyphs {
		_ = tex.Destroy()
	}
	_ = a.sess.Close()
	_ = a.renderer.Destroy()
	_ = a.window.Destroy()
	a.font.Close()
	ttf.Quit()
	sdl.Quit()
	return nil
}
```

 **Glyph atlas** — the part that actually matters for performance. Rasterizing a glyph via `ttf.RenderUTF8Blended` on every frame for every one of ~2,500 cells is the classic naive-terminal-GUI trap; cache by `(rune, color, bold)` and it becomes a cheap texture blit instead:

 ```go
// internal/gui/atlas.go
package gui

import (
	"github.com/veandco/go-sdl2/sdl"
	"github.com/veandco/go-sdl2/ttf"

	"github.com/git-emran/termite/internal/vt"
)

// glyphKey identifies one cached glyph texture. Caching by (rune, color,
// bold) — not just rune — is deliberate: re-rasterizing "the letter A in
// every color it might appear in" via ttf.RenderUTF8Blended on every frame
// is the single biggest performance trap in a naive terminal GUI. A shell
// prompt alone cycles through a dozen colors; without this cache you'd be
// doing font rasterization (slow: hinting, antialiasing, blending) 80x24
// times per frame instead of a cheap texture blit.
type glyphKey struct {
	ch   rune
	fg   vt.Color
	bold bool
}

// glyphTexture returns a cached texture for this cell's glyph, rendering
// and caching it on first use. The cache is unbounded for now — fine for a
// 256-color-ish terminal session; a long-running session with truecolor
// output cycling through millions of distinct colors would want an LRU
// eviction policy instead. Left as a follow-up, same spirit as Stage 5's
// "track last-emitted SGR state" note.
func (a *App) glyphTexture(c vt.Cell) (*sdl.Texture, error) {
	fg := c.FG
	if fg.Default {
		fg = vt.Color{R: 229, G: 229, B: 229} // default foreground: light gray, like most terminal themes
	}
	key := glyphKey{ch: c.Ch, fg: fg, bold: c.Bold}
	if tex, ok := a.glyphs[key]; ok {
		return tex, nil
	}

	font := a.font
	if c.Bold {
		font.SetStyle(ttf.STYLE_BOLD)
		defer font.SetStyle(ttf.STYLE_NORMAL)
	}

	ch := c.Ch
	if ch == 0 {
		ch = ' '
	}
	surf, err := font.RenderUTF8Blended(string(ch), sdl.Color{R: fg.R, G: fg.G, B: fg.B, A: 255})
	if err != nil {
		return nil, err
	}
	defer surf.Free()

	tex, err := a.renderer.CreateTextureFromSurface(surf)
	if err != nil {
		return nil, err
	}
	a.glyphs[key] = tex
	return tex, nil
}
```

 Per-frame draw — background cells, glyph blits, and a cursor block that's skipped whenever you're scrolled into history, same as every real terminal:

 ```go
// internal/gui/draw.go
package gui

import (
	"github.com/veandco/go-sdl2/sdl"
)

// draw paints one full frame. Unlike Stage 5's terminal renderer, we don't
// diff against the previous frame here — SDL's accelerated renderer clears
// and redraws the whole window in well under a millisecond for a typical
// 80x24-ish grid, so the diffing complexity that mattered when you were
// limited to emitting escape codes over a pty isn't a bottleneck here. If
// you scale this up to a huge grid on a low-power GPU, porting Stage 5's
// dirty-cell tracking into this package is the natural next optimization.
func (a *App) draw() error {
	s := a.screen

	if err := a.renderer.SetDrawColor(0, 0, 0, 255); err != nil {
		return err
	}
	if err := a.renderer.Clear(); err != nil {
		return err
	}

	for y := 0; y < s.Rows; y++ {
		line := s.VisibleLine(y)
		for x := 0; x < s.Cols && x < len(line); x++ {
			cell := line[x]

			if !cell.BG.Default {
				if err := a.renderer.SetDrawColor(cell.BG.R, cell.BG.G, cell.BG.B, 255); err != nil {
					return err
				}
				rect := &sdl.Rect{X: int32(x) * a.cellW, Y: int32(y) * a.cellH, W: a.cellW, H: a.cellH}
				if err := a.renderer.FillRect(rect); err != nil {
					return err
				}
			}

			if cell.Ch != 0 && cell.Ch != ' ' {
				tex, err := a.glyphTexture(cell)
				if err != nil {
					return err
				}
				_, _, texW, texH, err := tex.Query()
				if err != nil {
					return err
				}
				dst := &sdl.Rect{X: int32(x) * a.cellW, Y: int32(y) * a.cellH, W: texW, H: texH}
				if err := a.renderer.Copy(tex, nil, dst); err != nil {
					return err
				}
			}
		}
	}

	// Cursor: only draw it on the live (unscrolled) view — scrolled-back
	// history has no cursor, same as every real terminal.
	if s.ViewOffset == 0 {
		if err := a.renderer.SetDrawColor(255, 255, 255, 120); err != nil {
			return err
		}
		if err := a.renderer.SetDrawBlendMode(sdl.BLENDMODE_BLEND); err != nil {
			return err
		}
		cursorRect := &sdl.Rect{
			X: int32(s.CursorX) * a.cellW,
			Y: int32(s.CursorY) * a.cellH,
			W: a.cellW, H: a.cellH,
		}
		if err := a.renderer.FillRect(cursorRect); err != nil {
			return err
		}
	}

	a.renderer.Present()
	return nil
}
```

 Keyboard/text input — arrows, Home/End/PageUp/Down, Ctrl-combinations, plus SDL's `TextInputEvent` for everything else so IME composition and shifted symbols are handled correctly instead of hand-rolled:

 ```go
// internal/gui/input.go
package gui

import (
	"github.com/veandco/go-sdl2/sdl"
)

// handleTextInput handles ordinary character entry. SDL splits keyboard
// input into two event types on purpose: KeyboardEvent for physical keys
// (including ones with no text, like arrows or modifiers) and
// TextInputEvent for the actual composed text (which correctly handles
// dead keys, IME composition, shifted symbols, etc. — reinventing that
// from raw keycodes, the way Stage 7's Decode() sketch did for a plain
// terminal, is exactly the kind of thing you don't want to hand-roll once
// a real windowing toolkit is doing it for you).
func (a *App) handleTextInput(text string) {
	if text == "" {
		return
	}
	_, _ = a.sess.File.WriteString(text)
}

// handleKeyDown covers keys that don't produce text: arrows, Home/End,
// Enter, Backspace, Tab, and Ctrl-combinations. These get encoded as the
// escape sequences (or control bytes) the shell-side program expects —
// the same mapping Stage 7's input.Encode sketched out, extended to cover
// what a real session actually needs day to day.
func (a *App) handleKeyDown(k sdl.Keysym) {
	ctrl := k.Mod&sdl.KMOD_CTRL != 0

	var seq []byte
	switch k.Sym {
	case sdl.K_RETURN, sdl.K_KP_ENTER:
		seq = []byte("\r")
	case sdl.K_BACKSPACE:
		seq = []byte{0x7f}
	case sdl.K_TAB:
		seq = []byte("\t")
	case sdl.K_ESCAPE:
		seq = []byte{0x1b}
	case sdl.K_UP:
		seq = []byte("\x1b[A")
	case sdl.K_DOWN:
		seq = []byte("\x1b[B")
	case sdl.K_RIGHT:
		seq = []byte("\x1b[C")
	case sdl.K_LEFT:
		seq = []byte("\x1b[D")
	case sdl.K_HOME:
		seq = []byte("\x1b[H")
	case sdl.K_END:
		seq = []byte("\x1b[F")
	case sdl.K_PAGEUP:
		seq = []byte("\x1b[5~")
	case sdl.K_PAGEDOWN:
		seq = []byte("\x1b[6~")
	case sdl.K_DELETE:
		seq = []byte("\x1b[3~")
	default:
		// Ctrl-A .. Ctrl-Z: map to control bytes 0x01-0x1a. Letters also
		// arrive via TextInputEvent when unmodified, so this branch only
		// needs to fire when Ctrl changes what the key means.
		if ctrl && k.Sym >= sdl.K_a && k.Sym <= sdl.K_z {
			seq = []byte{byte(k.Sym-sdl.K_a) + 1}
		}
	}

	if seq == nil {
		return
	}

	// Any keypress that isn't a scrollback navigation key should snap the
	// view back to live — this matches how every real terminal behaves:
	// scroll up to read history, then typing anything jumps you back down.
	a.screen.ViewOffset = 0

	_, _ = a.sess.File.Write(seq)
}
```

 **Entry point — this is the "new app" part**, distinct from `cmd/term`, which still exists unchanged from Stage 8:

 ```go
// cmd/termgui/main.go
//
// Command termgui is the GUI counterpart to cmd/term. Where cmd/term runs
// inside whatever terminal launched it and relays ANSI escape codes back
// out, termgui opens its own OS window and IS the terminal — you'd put
// this in your dock/app launcher the same way you'd launch kitty or
// iTerm2, not run it from inside another terminal session.
package main

import (
	"log"
	"os"

	"github.com/git-emran/termite/internal/gui"
)

func shellPath() string {
	if s := os.Getenv("SHELL"); s != "" {
		return s
	}
	return "/bin/bash"
}

func main() {
	app, err := gui.New(gui.Config{
		FontPath: fontPath(),
		FontSize: 16,
		Cols:     100,
		Rows:     32,
		Title:    "termite",
		Shell:    shellPath(),
	})
	if err != nil {
		log.Fatalf("termite: %v", err)
	}
	if err := app.Run(); err != nil {
		log.Fatalf("termite: %v", err)
	}
}

// fontPath picks a monospace TTF that's actually present rather than
// hardcoding one path — DejaVu Sans Mono ships on most Linux distros;
// override with TERMITE_FONT if you're on a system without it (or want
// something else — a real ligature-capable coding font, for instance).
func fontPath() string {
	if p := os.Getenv("TERMITE_FONT"); p != "" {
		return p
	}
	candidates := []string{
		"/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
		"/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
		"/System/Library/Fonts/Menlo.ttc",
		"C:\\Windows\\Fonts\\consola.ttf",
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return candidates[0]
}
```

 ### Getting it building on your machine

 ```bash
go get github.com/veandco/go-sdl2/sdl
go get github.com/veandco/go-sdl2/ttf
```

 You'll need the SDL2 dev libraries present for cgo to link against:

 - **Debian/Ubuntu:** `sudo apt-get install libsdl2-dev libsdl2-ttf-dev`
- **macOS:** `brew install sdl2 sdl2_ttf`
- **Windows:** grab the SDL2/SDL2_ttf dev packages from libsdl.org and point `CGO_CFLAGS`/`CGO_LDFLAGS` at them, or use MSYS2's `mingw-w64-x86_64-SDL2`/`mingw-w64-x86_64-SDL2_ttf` packages.

 ```bash
go build ./cmd/termgui
./termgui
```

 ### What was actually verified vs. left to you

 Verified in a real sandbox:

 - `go build ./...`, `go vet ./...`, and `gofmt -l .` all clean across `internal/vt`, `internal/pty`, `internal/gui`, and `cmd/termgui`
- Compiled the `termgui` binary successfully
- Ran the binary for several seconds under `SDL_VIDEODRIVER=dummy` (headless) — it initialized SDL/TTF, opened DejaVu Sans Mono, measured cell size from the font's own metrics, created the window and renderer, spawned a real `/bin/bash` child process, and sat in the event loop with no panic or error output

 Not verified (no display available in that sandbox): actual pixel output, glyph legibility and alignment, live keyboard/mouse interaction, and resize behavior end-to-end against a real windowing system. Those need a `go run ./cmd/termgui` on a machine with a display.

 ### Where to go from here

 Roughly in order of value-to-effort:

 1. **Dirty-cell diffing in `draw.go`** — only matters if you push the grid size way up on a low-power GPU; Stage 5's technique ports over directly if you need it.
2. **Alt-screen buffer** (`ESC[?1049h/l`) — what `vim`/`less` use to take over the screen and restore it on exit; same idea as the Stage 1-8 exercises list, just wired into the GUI's `Screen` swap instead of a terminal one.
3. **Multi-window / tabs** — each tab is just another `vt.Screen` + `pty.Session` pair; the part that's already done is keeping the screen model fully decoupled from rendering, which is what makes adding more of them mechanical instead of architectural.
4. **True incremental SGR / font fallback for non-ASCII glyphs** — the glyph cache assumes the loaded font covers whatever the shell prints; a font-fallback chain is the natural next step for anything beyond Latin text.