# Building a Yazi-Style TUI File Explorer in Go — From Hello World to Working Product

 This guide walks you through building a terminal file explorer inspired by [yazi](https://github.com/sxyazi/yazi), step by step, in Go. Each stage adds one concept on top of the last, includes runnable code, explains *why* it works, and ends with tips worth remembering.

 ---

 ## 0. Why This Stack

 | Concern | Choice | Reason |
| --- | --- | --- |
| Language | Go | You already have deep Go/terminal-tooling experience — this builds directly on that. |
| TUI framework | [Bubble Tea](https://github.com/charmbracelet/bubbletea) | Elm-architecture (Model-Update-View), predictable state, huge community, what most modern Go TUIs (including real file managers) are built on. |
| Styling | [Lip Gloss](https://github.com/charmbracelet/lipgloss) | Declarative styling for terminal UIs — borders, colors, layout, padding. This is how you get the "amazing UI" look. |
| Components | [Bubbles](https://github.com/charmbracelet/bubbles) | Pre-built list, viewport, textinput, spinner, key-help components. You'll use some, and hand-roll others where yazi's behavior is custom. |
| Key handling | [Bubble Tea's`key`package](https://github.com/charmbracelet/bubbles/tree/master/key) | Lets you declare vim-style keymaps (`j`,`k`,`gg`,`G`,`dd`, etc.) as data instead of a giant switch statement. |
| File icons | Nerd Font glyphs (optional) | Yazi's polish comes partly from icons — we'll add these late, behind a fallback. |

 Why not just wrap `ls`/shell out? Because seamless navigation, live preview, and instant redraw need an in-memory model of directory state — exactly what Bubble Tea's architecture is built for.

 **Final project layout** (what you're working toward):

 ```
tui-explorer/
├── main.go
├── go.mod
├── internal/
│   ├── model/
│   │   ├── model.go        # root Bubble Tea model
│   │   ├── update.go       # message handling / keybindings
│   │   └── view.go         # rendering
│   ├── fs/
│   │   ├── entry.go        # DirEntry type + sorting
│   │   └── scan.go         # reading directories (async)
│   ├── preview/
│   │   └── preview.go      # file preview logic
│   ├── keymap/
│   │   └── keymap.go       # vim-style key bindings
│   ├── theme/
│   │   └── theme.go        # lipgloss styles / colors
│   └── config/
│       └── config.go       # user config (TOML)
└── README.md
```

 You won't build that tree all at once — it emerges naturally as each stage outgrows a single file. Restructuring as you grow is normal and expected; it's called out at the point it happens.

 > **Tip #1 — commit after every stage.** Each stage below is a working, runnable program. `git init` now, and `git commit` at the end of every stage. If stage 6 breaks something, you can diff against stage 5 instead of debugging blind.

 ---

 ## 1. Environment Setup

 ```bash
mkdir tui-explorer && cd tui-explorer
go mod init github.com/<you>/tui-explorer
go get github.com/charmbracelet/bubbletea@latest
go get github.com/charmbracelet/lipgloss@latest
go get github.com/charmbracelet/bubbles@latest
```

 Check your Go version supports generics-era tooling comfortably:

 ```bash
go version   # 1.21+ recommended
```

 > **Tip #2 — use a real terminal for testing, not an IDE's embedded one.** Embedded terminals in editors often mis-report terminal size or lack true color support, which will make yazi-style styling look wrong even when your code is correct. iTerm2, Alacritty, Kitty, or Windows Terminal all work well.

 ---

 ## 2. Stage 0 — Hello World

 The absolute minimum Bubble Tea program. This establishes the **Model / Update / View** loop you'll build everything else on top of.

 ```go
// main.go
package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

type model struct{}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "q" || msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m model) View() string {
	return "Hello, TUI World! Press q to quit.\n"
}

func main() {
	p := tea.NewProgram(model{})
	if _, err := p.Run(); err != nil {
		fmt.Println("error running program:", err)
		os.Exit(1)
	}
}
```

 Run it:

 ```bash
go run main.go
```

 **What's happening:**

 - `Init()` runs once at startup — for side effects like loading initial data.
- `Update()` runs on every event (`tea.Msg`) — keypresses, window resizes, timers, or messages your own code sends. It returns a **new** model (Bubble Tea models are treated as immutable per update) plus an optional `tea.Cmd` (a function that produces the *next* message, e.g. "read this directory" or "tick in 1 second").
- `View()` is called after every `Update()` and just renders the current model state to a string. It should have **no side effects** — no file reads, no mutation.

 > **Tip #3 — never do I/O inside `View()`.** It's called on every render (potentially many times a second). Directory reads, file stats, anything slow belongs in a `tea.Cmd` dispatched from `Update()`, whose result comes back as a message. This single rule prevents 90% of "my TUI feels laggy" bugs.

 ---

 ## 3. Stage 1 — List the Current Directory

 Now replace the static string with a real (if plain) file listing.

 ```go
// main.go
package main

import (
	"fmt"
	"os"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

type entry struct {
	name  string
	isDir bool
}

type model struct {
	cwd     string
	entries []entry
	cursor  int
}

func readDir(path string) []entry {
	files, err := os.ReadDir(path)
	if err != nil {
		return nil
	}
	var out []entry
	for _, f := range files {
		out = append(out, entry{name: f.Name(), isDir: f.IsDir()})
	}
	sort.Slice(out, func(i, j int) bool {
		// directories first, then alphabetical — matches yazi's default
		if out[i].isDir != out[j].isDir {
			return out[i].isDir
		}
		return strings.ToLower(out[i].name) < strings.ToLower(out[j].name)
	})
	return out
}

func initialModel() model {
	cwd, _ := os.Getwd()
	return model{
		cwd:     cwd,
		entries: readDir(cwd),
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "down", "j":
			if m.cursor < len(m.entries)-1 {
				m.cursor++
			}
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		}
	}
	return m, nil
}

func (m model) View() string {
	var b strings.Builder
	b.WriteString(m.cwd + "\n\n")
	for i, e := range m.entries {
		cursor := "  "
		if i == m.cursor {
			cursor = "> "
		}
		name := e.name
		if e.isDir {
			name += "/"
		}
		b.WriteString(fmt.Sprintf("%s%s\n", cursor, name))
	}
	return b.String()
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}
}
```

 You now have `j`/`k` navigation over a real directory listing — the seed of vim-style movement.

 > **Tip #4 — `os.ReadDir` vs `os.Open` + `Readdir`.** `os.ReadDir` (Go 1.16+) returns already-sorted-by-name `DirEntry` values and is lazier/cheaper than `os.File.Readdir`, since it doesn't `Stat` every file up front. Use `DirEntry.Info()` only when you actually need size/mtime (e.g. for the status bar later) — deferring that cost matters once you're in large directories.

 ---

 ## 4. Stage 2 — Full Vim-Style Navigation

 Real vim/yazi navigation needs more than `j`/`k`:

 - `h` — go to parent directory
- `l` / `Enter` — enter directory / open file
- `g g` — jump to top (two-key sequence)
- `G` — jump to bottom
- `Ctrl+d` / `Ctrl+u` — half-page down/up

 Two-key sequences (`gg`) need a tiny piece of state: "did the user just press `g`?" Bubble Tea doesn't give you that for free — you track it.

 ```go
type model struct {
	cwd       string
	entries   []entry
	cursor    int
	pendingG  bool // true if the last key was 'g', waiting for a second 'g'
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		key := msg.String()

		// handle the pending "gg" sequence first
		if m.pendingG {
			m.pendingG = false
			if key == "g" {
				m.cursor = 0
				return m, nil
			}
			// fall through — not a real "gg", handle key normally below
		}

		switch key {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "j", "down":
			if m.cursor < len(m.entries)-1 {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "g":
			m.pendingG = true
		case "G":
			m.cursor = len(m.entries) - 1
		case "h", "left":
			m = m.goToParent()
		case "l", "right", "enter":
			m = m.enterSelected()
		case "ctrl+d":
			m.cursor = min(m.cursor+10, len(m.entries)-1)
		case "ctrl+u":
			m.cursor = max(m.cursor-10, 0)
		}
	}
	return m, nil
}

func (m model) goToParent() model {
	parent := filepath.Dir(m.cwd)
	if parent == m.cwd {
		return m // already at root
	}
	m.cwd = parent
	m.entries = readDir(parent)
	m.cursor = 0
	return m
}

func (m model) enterSelected() model {
	if len(m.entries) == 0 {
		return m
	}
	sel := m.entries[m.cursor]
	if sel.isDir {
		newPath := filepath.Join(m.cwd, sel.name)
		m.cwd = newPath
		m.entries = readDir(newPath)
		m.cursor = 0
	}
	// if it's a file, later stages will open/preview it
	return m
}
```

 (Add `"path/filepath"` to imports, and small `min`/`max` helpers if your Go version predates the builtin generics versions — Go 1.21+ has them built-in.)

 > **Tip #5 — model methods that return `model`, not `*model`.** Bubble Tea models are conventionally value types. Writing `func (m model) foo() model` and doing `m = m.foo()` keeps state changes explicit and traceable — exactly the property that makes Elm-architecture apps easy to reason about even as they grow. Resist the urge to switch to pointer receivers "for performance" — it isn't the bottleneck here, and it breaks the mental model.

 ---

 ## 5. Stage 3 — The Three-Pane Yazi Layout

 This is the visual leap that makes it *feel* like yazi: **parent | current | preview**, side by side, each independently scrollable.

 Restructure the model to track three panes:

 ```go
type model struct {
	cwd      string
	parent   pane // left: parent directory listing, selected entry highlighted
	current  pane // middle: current directory, this is what you navigate
	preview  pane // right: preview of the file/dir under the cursor
	width    int
	height   int
}

type pane struct {
	path    string
	entries []entry
	cursor  int
}
```

 Every time `current` changes (you moved the cursor or changed directory), recompute `parent` and `preview`:

 ```go
func (m model) refreshPanes() model {
	m.parent = pane{
		path:    filepath.Dir(m.cwd),
		entries: readDir(filepath.Dir(m.cwd)),
	}
	// highlight cwd's own name inside the parent listing
	for i, e := range m.parent.entries {
		if e.name == filepath.Base(m.cwd) {
			m.parent.cursor = i
		}
	}

	if len(m.current.entries) > 0 {
		sel := m.current.entries[m.current.cursor]
		selPath := filepath.Join(m.cwd, sel.name)
		if sel.isDir {
			m.preview = pane{path: selPath, entries: readDir(selPath)}
		}
		// file preview comes in Stage 5
	}
	return m
}
```

 Call `m.refreshPanes()` at the end of every navigation handler (`j`, `k`, `h`, `l`, `gg`, `G`).

 ### Laying out three columns with Lip Gloss

 ```go
import "github.com/charmbracelet/lipgloss"

func (m model) View() string {
	colWidth := m.width / 3

	parentView := renderPane(m.parent, colWidth, false)
	currentView := renderPane(m.current, colWidth, true)
	previewView := renderPane(m.preview, colWidth, false)

	row := lipgloss.JoinHorizontal(lipgloss.Top, parentView, currentView, previewView)
	return row
}

func renderPane(p pane, width int, active bool) string {
	style := lipgloss.NewStyle().
		Width(width).
		Height(20).
		Padding(0, 1)

	if active {
		style = style.BorderStyle(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("212"))
	} else {
		style = style.BorderStyle(lipgloss.NormalBorder()).BorderForeground(lipgloss.Color("240"))
	}

	var b strings.Builder
	for i, e := range p.entries {
		line := e.name
		if e.isDir {
			line += "/"
		}
		if i == p.cursor {
			line = lipgloss.NewStyle().Reverse(true).Render(line)
		}
		b.WriteString(line + "\n")
	}
	return style.Render(b.String())
}
```

 You need `m.width`/`m.height`, which come from Bubble Tea's resize message — handle it in `Update`:

 ```go
case tea.WindowSizeMsg:
	m.width = msg.Width
	m.height = msg.Height
```

 > **Tip #6 — always handle `tea.WindowSizeMsg`.** If you hardcode dimensions, resizing the terminal (or opening in a smaller pane/tmux split) breaks your layout instantly. Bubble Tea sends this message once at startup and again on every resize — treat width/height as *state*, not constants.

 > **Tip #7 — `lipgloss.JoinHorizontal`/`JoinVertical` over manual string concatenation.** Lip Gloss handles multi-line block alignment (padding shorter columns, respecting each block's own height) — hand-rolling this with string splitting is exactly the kind of bug (misaligned borders, off-by-one line counts) that eats hours. Let the library do it.

 ---

 ## 6. Stage 4 — Real Styling: Colors, Borders, Icons

 Yazi's look comes from consistent theming, not one-off colors. Centralize it:

 ```go
// internal/theme/theme.go
package theme

import "github.com/charmbracelet/lipgloss"

var (
	Primary   = lipgloss.Color("212") // active pane border / selection
	Muted     = lipgloss.Color("240") // inactive borders
	DirColor  = lipgloss.Color("39")  // blue-ish, directories
	FileColor = lipgloss.Color("252") // default text
	ExecColor = lipgloss.Color("42")  // green, executables
	Cursor    = lipgloss.NewStyle().Reverse(true)

	ActivePane = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(Primary)

	InactivePane = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			BorderForeground(Muted)

	StatusBar = lipgloss.NewStyle().
			Background(lipgloss.Color("236")).
			Foreground(lipgloss.Color("252")).
			Padding(0, 1)
)

func EntryColor(isDir, isExec bool) lipgloss.Color {
	switch {
	case isDir:
		return DirColor
	case isExec:
		return ExecColor
	default:
		return FileColor
	}
}
```

 Apply per-entry color when rendering:

 ```go
name := lipgloss.NewStyle().Foreground(theme.EntryColor(e.isDir, e.isExec)).Render(e.name)
```

 ### Optional: Nerd Font icons

 ```go
func iconFor(e entry) string {
	switch {
	case e.isDir:
		return " " // folder glyph, requires a Nerd Font
	case strings.HasSuffix(e.name, ".go"):
		return " "
	case strings.HasSuffix(e.name, ".md"):
		return " "
	default:
		return " "
	}
}
```

 Gate this behind a config flag (Stage 10) since not every terminal font supports these glyphs — falling back to plain text/ASCII markers (`[D]fsf, `[F]`) keeps the app usable everywhere.

 > **Tip #8 — never hardcode ANSI 16-color assumptions.** Lip Gloss's `lipgloss.Color("212")` uses the 256-color palette, which renders consistently across modern terminals. If you instead print raw ANSI escape codes by hand, you'll get inconsistent results across terminal emulators — one more reason to let Lip Gloss own all color/style output.

 > **Tip #9 — test your theme against both light and dark terminal backgrounds.** `lipgloss.HasDarkBackground()` exists for a reason — yazi itself adapts. A hardcoded near-white foreground is invisible on a light theme.

 ---

 ## 7. Stage 5 — File Preview

 This is where yazi really shines: select a text file, see its contents in the right pane; select an image, see a rendered preview (advanced, optional); select a directory, see its listing (you already built this in Stage 3).

 Start with text preview:

 ```go
// internal/preview/preview.go
package preview

import (
	"bufio"
	"os"
	"strings"
)

const maxPreviewLines = 200 // don't read a 2GB log file into memory

func TextPreview(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	var b strings.Builder
	scanner := bufio.NewScanner(f)
	lines := 0
	for scanner.Scan() && lines < maxPreviewLines {
		b.WriteString(scanner.Text() + "\n")
		lines++
	}
	return b.String(), nil
}
```

 Wire it into `refreshPanes`, but **as a command, not inline** — file reads are I/O and shouldn't block the update loop (see Tip #3):

 ```go
type previewLoadedMsg struct {
	path    string
	content string
	err     error
}

func loadPreviewCmd(path string) tea.Cmd {
	return func() tea.Msg {
		content, err := preview.TextPreview(path)
		return previewLoadedMsg{path: path, content: content, err: err}
	}
}
```

 In `Update`, dispatch this command whenever the selection changes, and handle the result:

 ```go
case previewLoadedMsg:
	if msg.path == m.selectedPath() { // guard against stale/out-of-order results
		m.previewContent = msg.content
	}
```

 > **Tip #10 — guard against stale async results.** If the user presses `j` five times quickly, you'll fire five preview-load commands. They can return out of order. Always check "is this result still relevant to what's currently selected?" before applying it — otherwise you'll flash a wrong preview for a frame.

 > **Tip #11 — cap what you read.** Yazi previews only what fits on screen. Reading an entire multi-GB file to preview the first 40 lines is wasted I/O and memory. `bufio.Scanner` with a line cap (above) or `io.LimitReader` for byte-based caps are both good tools here.

 Binary files: detect and show a placeholder instead of garbage bytes:

 ```go
func isLikelyBinary(sample []byte) bool {
	for _, b := range sample {
		if b == 0 {
			return true // NUL byte is a strong binary signal
		}
	}
	return false
}
```

 Read the first ~512 bytes, check for NUL bytes, and show `"[binary file]"` in the preview pane if detected, rather than attempting a text render.

 ---

 ## 8. Stage 6 — Selection & File Operations

 Yazi lets you multi-select (`Space` toggles), then act: yank/copy (`y`), cut (`x`), paste (`p`), delete (`d d` or `D`), rename (`r`).

 ```go
type model struct {
	// ...
	selected map[string]bool // absolute paths currently selected
	yanked   []string        // paths staged for copy
	cutMode  bool            // true = move, false = copy
}
```

 ```go
case " ":
	path := m.selectedEntryPath()
	if m.selected[path] {
		delete(m.selected, path)
	} else {
		if m.selected == nil {
			m.selected = map[string]bool{}
		}
		m.selected[path] = true
	}
	m.cursorDown()

case "y":
	m.yanked = m.selectedPaths()
	m.cutMode = false

case "x":
	m.yanked = m.selectedPaths()
	m.cutMode = true

case "p":
	return m, pasteCmd(m.yanked, m.cwd, m.cutMode)
```

 File operations are **destructive** — always run them as `tea.Cmd`s that report success/failure back as a message, and always confirm before delete:

 ```go
type confirmDeleteMsg struct{ paths []string }

case "d":
	// require a second 'd' (dd) or route through a confirm modal — never
	// delete on a single keypress
```

 ```go
func pasteCmd(paths []string, destDir string, move bool) tea.Cmd {
	return func() tea.Msg {
		for _, src := range paths {
			dst := filepath.Join(destDir, filepath.Base(src))
			var err error
			if move {
				err = os.Rename(src, dst)
			} else {
				err = copyPath(src, dst) // recursive copy, write this helper for dirs
			}
			if err != nil {
				return operationErrMsg{err}
			}
		}
		return operationDoneMsg{dir: destDir}
	}
}
```

 > **Tip #12 — never wire `d` directly to `os.RemoveAll` on a single keypress.** Yazi requires confirmation for destructive ops (or a trash/undo model). At minimum: require `dd` (two keys) like vim, and show a yes/no prompt for anything recursive. A file explorer's #1 job is to not destroy your files by accident.

 > **Tip #13 — `os.Rename` fails across filesystems/devices.** A "move" from one mounted drive to another can't use `os.Rename` — you'll get an `EXDEV` error. Fall back to copy-then-delete when that happens.

 ---

 ## 9. Stage 7 — Search / Filter

 Yazi's `/` opens an incremental filter of the current pane; typing narrows the list live.

 ```go
type model struct {
	// ...
	filtering  bool
	filterText string
}
```

 ```go
case "/":
	m.filtering = true
	m.filterText = ""
	return m, nil
```

 While `m.filtering` is true, route *all* key input into building the filter string instead of your normal navigation keys:

 ```go
if m.filtering {
	switch msg.String() {
	case "esc":
		m.filtering = false
		m.filterText = ""
	case "enter":
		m.filtering = false // keep the filter applied, just stop editing it
	case "backspace":
		if len(m.filterText) > 0 {
			m.filterText = m.filterText[:len(m.filterText)-1]
		}
	default:
		if len(msg.String()) == 1 {
			m.filterText += msg.String()
		}
	}
	return m, nil
}
```

 Apply the filter at render time (or cache the filtered slice on every change — cheap for normal directory sizes):

 ```go
func (m model) visibleEntries() []entry {
	if m.filterText == "" {
		return m.current.entries
	}
	var out []entry
	for _, e := range m.current.entries {
		if strings.Contains(strings.ToLower(e.name), strings.ToLower(m.filterText)) {
			out = append(out, e)
		}
	}
	return out
}
```

 > **Tip #14 — mode-based input routing (`if m.filtering { ... }`) is the standard Bubble Tea pattern for anything vim-modal.** You'll reuse this exact shape for rename-input, the command palette, and confirm dialogs. Think of your model as always being in exactly one "mode" (normal, filter, rename, confirm) — and let that mode decide how keys are interpreted, exactly like vim's normal/insert/visual modes.

 ---

 ## 10. Stage 8 — Bookmarks and Tabs

 Two more yazi staples:

 **Jump marks** (`m` + letter to set a mark, `'` + letter to jump):

 ```go
type model struct {
	// ...
	marks map[rune]string // letter -> absolute path
}
```

 **Tabs** (multiple independent panes you switch between with `Tab`/numbers):

 ```go
type model struct {
	tabs       []tabState
	activeTab  int
}

type tabState struct {
	cwd     string
	current pane
	// each tab is essentially its own mini file-explorer state
}
```

 Switching tabs is just swapping which `tabState` your render/update functions read from — the navigation logic you wrote in Stages 2–3 doesn't change, it just now operates on `m.tabs[m.activeTab]` instead of a single flat field.

 > **Tip #15 — this is why Stage 3's `refreshPanes` was written as a function that returns a new `model`.** Once state is a slice of tabs instead of a single tab, every function that mutates "the current pane" should already be structured to work on *some* pane, not implicitly the only one. If you find yourself hardcoding `m.current` deep inside a function instead of receiving it as a parameter, that's the refactor signal to fix before adding tabs.

 ---

 ## 11. Stage 9 — Status Bar & Help Menu

 The status bar (bottom row) shows: current path, selection count, file size/permissions of the item under the cursor, and available keys.

 ```go
func (m model) renderStatusBar() string {
	left := m.cwd
	right := fmt.Sprintf("%d/%d  %s",
		m.current.cursor+1, len(m.current.entries),
		selectedInfo(m))

	gap := m.width - lipgloss.Width(left) - lipgloss.Width(right)
	if gap < 1 {
		gap = 1
	}
	bar := left + strings.Repeat(" ", gap) + right
	return theme.StatusBar.Width(m.width).Render(bar)
}
```

 A help overlay (triggered by `?`) is just another "mode" (Tip #14) that, when active, renders a floating box (via `lipgloss.Place`) listing your keymap instead of/on top of the normal view.

 ```go
if m.showHelp {
	helpBox := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		Padding(1, 2).
		Render(helpText())
	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, helpBox)
}
```

 > **Tip #16 — `lipgloss.Width()`, not `len()`, for layout math.** ANSI color codes and multi-byte runes (icons, unicode box characters) make `len(styledString)` lie about visible width. `lipgloss.Width` strips escape sequences and counts display cells correctly — use it anywhere you're computing padding/gaps like the status bar above.

 ---

 ## 12. Stage 10 — Config File & Custom Keybindings

 Move hardcoded keys into a config so keybindings (and colors) are user-editable, the way yazi's `keymap.toml` works.

 ```go
// internal/config/config.go
package config

type Config struct {
	Keymap struct {
		Down       []string `toml:"down"`
		Up         []string `toml:"up"`
		Parent     []string `toml:"parent"`
		Enter      []string `toml:"enter"`
		Quit       []string `toml:"quit"`
	} `toml:"keymap"`
	Theme struct {
		Primary string `toml:"primary"`
		DirColor string `toml:"dir_color"`
	} `toml:"theme"`
}

func Default() Config {
	c := Config{}
	c.Keymap.Down = []string{"j", "down"}
	c.Keymap.Up = []string{"k", "up"}
	c.Keymap.Parent = []string{"h", "left"}
	c.Keymap.Enter = []string{"l", "right", "enter"}
	c.Keymap.Quit = []string{"q", "ctrl+c"}
	c.Theme.Primary = "212"
	c.Theme.DirColor = "39"
	return c
}
```

 Load from `~/.config/tui-explorer/config.toml` if present, falling back to `Default()`. Use `github.com/BurntSushi/toml` or `github.com/pelletier/go-toml/v2` for parsing.

 Bubble Tea's own `key.Binding` type (from the `bubbles/key` package) is worth adopting here instead of raw string matching — it gives you auto-generated help text for free:

 ```go
import "github.com/charmbracelet/bubbles/key"

type keymap struct {
	Down key.Binding
	Up   key.Binding
}

func newKeymap(cfg config.Config) keymap {
	return keymap{
		Down: key.NewBinding(key.WithKeys(cfg.Keymap.Down...), key.WithHelp("j", "down")),
		Up:   key.NewBinding(key.WithKeys(cfg.Keymap.Up...), key.WithHelp("k", "up")),
	}
}

// in Update:
if key.Matches(msg, m.keymap.Down) { m.cursorDown() }
```

 > **Tip #17 — `key.Matches` over manual string comparison once you have more than ~5 bindings.** It cleanly supports multiple physical keys mapping to one logical action (both `j` and `down` triggering "move down"), which is exactly what configurable vim-style bindings need, and it feeds your `?` help screen automatically via `key.WithHelp`.

 ---

 ## 13. Stage 11 — Performance for Large Directories

 At this point the app works. Now make it not choke on `/usr/lib` or a 100k-file directory.

 1. **Read directories asynchronously.** Wrap `readDir` in a `tea.Cmd` (same pattern as preview loading in Stage 5) so entering a huge directory doesn't freeze the UI while it reads.
2. **Debounce the filter.** If you added live filtering over a huge directory, filter on every keystroke only up to a reasonable entry count; above that, debounce with a short timer message.
3. **Virtualize the list.** Don't render 100k lines of string — only render the slice of entries that fits in the pane's visible height, offset by scroll position. `bubbles/viewport` or `bubbles/list` handle this for you if you migrate the pane rendering onto them.
4. **Cache `os.Stat` results** you use in the status bar; don't re-stat on every render frame — only when the selection changes.

 > **Tip #18 — profile before optimizing.** Go's built-in `pprof` works fine against a TUI app (guard it behind a debug flag so it doesn't interfere with terminal rendering). Don't virtualize the list before you've confirmed rendering, not directory reading, is actually your bottleneck.

 ---

 ## 14. Stage 12 — Final Polish

 - **Startup argument**: `tui-explorer /some/path` should open there instead of `cwd`. Parse `os.Args` in `main()`.
- **Open file in `$EDITOR`**: on `enter` over a file (not dir), suspend the TUI and shell out:

 ```go
case "enter":
	if !sel.isDir {
		cmd := exec.Command(os.Getenv("EDITOR"), fullPath)
		return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
			return editorClosedMsg{err}
		})
	}
```

 `tea.ExecProcess` is the correct way to hand the terminal to another program and get it back cleanly — don't call `cmd.Run()` directly, it will fight with Bubble Tea's terminal control.

 - **Graceful resize/redraw** — you already handle `tea.WindowSizeMsg` (Tip #6); double check nothing assumes a fixed size anywhere left.
- **Exit cleanly** — if you changed terminal modes (alt screen, mouse capture) via `tea.WithAltScreen()` / `tea.WithMouseCellMotion()`, Bubble Tea restores the terminal automatically on `tea.Quit`, but verify by testing `ctrl+c` mid-operation (e.g. mid-paste) doesn't leave the terminal in a weird state.

 > **Tip #19 — `tea.WithAltScreen()` is what gives you the "takes over the whole terminal, restores it on exit" behavior yazi has.** Without it, your app's output just scrolls the normal terminal buffer, which looks unpolished and leaves screen garbage behind on exit.

 ---

 ## 15. Recap: The Full Learning Path

 | Stage | What you added | Core concept learned |
| --- | --- | --- |
| 0 | Hello world | Model-Update-View loop |
| 1 | Directory listing | Reading FS state into the model |
| 2 | Vim navigation | Multi-key sequences, mode-free key handling |
| 3 | Three-pane layout | Lip Gloss layout composition, resize handling |
| 4 | Colors/theme | Centralized styling, 256-color palette |
| 5 | File preview | Async`tea.Cmd`, stale-result guarding |
| 6 | Selection/ops | Destructive-action safety, cross-device edge cases |
| 7 | Search/filter | Modal input routing |
| 8 | Bookmarks/tabs | State restructuring for multi-instance panes |
| 9 | Status bar/help | `lipgloss.Width`, overlay rendering |
| 10 | Config/keybindings | `key.Binding`, user-facing configurability |
| 11 | Performance | Virtualization, async I/O, caching |
| 12 | Polish | Process handoff, terminal mode hygiene |

 ---

 ## 16. All Tips, Collected

 1. Commit after every stage — each one is a working checkpoint.
2. Never do I/O inside `View()`.
3. Test in a real terminal, not an IDE's embedded one.
4. Prefer `os.ReadDir` over `os.Open`+`Readdir`; defer `Stat` calls.
5. Model methods return `model`, not `*model` — keep state changes explicit.
6. Always handle `tea.WindowSizeMsg`; never hardcode dimensions.
7. Use `lipgloss.JoinHorizontal`/`JoinVertical` instead of manual string joins.
8. Use Lip Gloss color functions, not raw ANSI escapes.
9. Test your theme on both light and dark terminal backgrounds.
10. Guard async results (like preview loads) against staleness.
11. Cap how much of a file you read for preview.
12. Never bind single-key deletion to something destructive — require confirmation.
13. Handle `EXDEV` (cross-device) errors on move by falling back to copy+delete.
14. Route input through an explicit "mode" (normal/filter/rename/confirm).
15. Structure per-pane logic to take a pane as a parameter once tabs exist.
16. Use `lipgloss.Width()`, never `len()`, for layout math.
17. Use `bubbles/key` + `key.Matches` once you have more than a handful of bindings.
18. Profile before optimizing — confirm the actual bottleneck.
19. Use `tea.WithAltScreen()` for the full-terminal-takeover feel.

 ---

 ## 17. Where to Go From Here

 Once Stage 12 is solid, natural next steps (each is its own mini-project):

 - **Image previews** via terminal graphics protocols (Kitty graphics protocol / Sixel) — yazi supports this; it's a meaningfully harder feature involving raw escape sequences.
- **Plugin system** — yazi's is Lua-based; a Go equivalent could use `github.com/yuin/gopher-lua` or a simple exec-based plugin protocol. Given your existing LSP work on `simple-notes`, an LSP-style request/response protocol for plugins would be a very natural extension of skills you already have. If you'd like, next time I can also lay out a companion guide for the image-preview or plugin-system extensions in the same staged format.
- **Mouse support** via `tea.WithMouseCellMotion()`.
- **Trash/undo** instead of hard delete — a `~/.local/share/Trash`-style staging directory before permanent deletion.

 Good luck — build it stage by stage, commit as you go, and don't skip Tip #3.# Building a Yazi-Style TUI File Explorer in Go — From Hello World to Working Product

Every stage below is a **runnable checkpoint**. Each one tells you:

1. **Which files to create or edit** (exact paths)
2. **The full contents** of each file — new/changed lines are marked with
   a `// STAGE N: ...` comment so you know exactly what this stage added
3. **How it wires into `main.go`**
4. **What to run, and what you should see** before moving to the next stage

Don't skip the "run it" step. If a stage doesn't build or doesn't behave as
described, stop there — don't layer the next stage on top of a broken one.

---

## Project skeleton (do this once)

```bash
mkdir tui-explorer && cd tui-explorer
go mod init github.com/<you>/tui-explorer
go get github.com/charmbracelet/bubbletea@latest
go get github.com/charmbracelet/lipgloss@latest
go mod tidy
```

Replace `github.com/<you>/tui-explorer` everywhere below with whatever's
actually in your `go.mod` — that module path is what makes
`internal/fs`, `internal/tui`, etc. resolve as imports.

**Where every file will eventually live** (you'll create these
directories as each stage calls for them, not all at once):

```
tui-explorer/
├── main.go
├── go.mod
└── internal/
    ├── fs/
    │   └── entry.go
    ├── preview/
    │   └── preview.go
    ├── theme/
    │   ├── theme.go
    │   └── icons.go
    └── tui/
        ├── model.go
        ├── update.go
        └── view.go
```

---

## Stage 0 — Hello World

**Files this stage touches:** `main.go` only.

```bash
touch main.go
```

```go
// main.go
package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

// STAGE 0: the smallest possible Bubble Tea model — no fields yet.
type model struct{}

// STAGE 0: Init runs once at startup. Nothing to load yet.
func (m model) Init() tea.Cmd { return nil }

// STAGE 0: Update runs on every event. We only handle quit keys for now.
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if k, ok := msg.(tea.KeyMsg); ok {
		if k.String() == "q" || k.String() == "ctrl+c" {
			return m, tea.Quit
		}
	}
	return m, nil
}

// STAGE 0: View renders the current state. Static text for now.
func (m model) View() string {
	return "Hello, TUI World! Press q to quit.\n"
}

func main() {
	p := tea.NewProgram(model{})
	if _, err := p.Run(); err != nil {
		fmt.Println("error running program:", err)
		os.Exit(1)
	}
}
```

**How it connects:** this stage *is* `main.go` — nothing to wire yet.

**Run it:**

```bash
go run main.go
```

**You should see:** `Hello, TUI World! Press q to quit.` printed, and
pressing `q` (or `Ctrl+C`) exits cleanly back to your shell prompt.

> **Tip #1 — commit after every stage.** `git init && git add -A && git commit -m "stage 0: hello world"` right now, and again at the end of every stage from here on.

> **Tip #2 — never do I/O inside `View()`.** It's called on every render. File reads belong in a `tea.Cmd`, whose result comes back as a message — you'll see this pattern for real starting Stage 5.

---

## Stage 1 — Read a Real Directory

**Files this stage touches:**
- **New:** `internal/fs/entry.go`
- **Edit:** `main.go`

```bash
mkdir -p internal/fs
touch internal/fs/entry.go
```

```go
// internal/fs/entry.go
// STAGE 1: new package. This package never imports Bubble Tea or Lip Gloss —
// it only knows how to read a directory into a sorted slice. Keep it that
// way permanently (see Tip #14 later) so it stays testable on its own.
package fs

import (
	"os"
	"sort"
	"strings"
)

// STAGE 1: Entry describes one file/directory. Exported (capital E, capital
// fields) because main.go and later internal/tui will need to read it.
type Entry struct {
	Name  string
	IsDir bool
}

// STAGE 1: ReadDir lists a directory, directories first then alphabetical —
// this matches yazi's default sort.
func ReadDir(path string) []Entry {
	files, err := os.ReadDir(path)
	if err != nil {
		return nil
	}

	var out []Entry
	for _, f := range files {
		out = append(out, Entry{Name: f.Name(), IsDir: f.IsDir()})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].IsDir != out[j].IsDir {
			return out[i].IsDir
		}
		return strings.ToLower(out[i].Name) < strings.ToLower(out[j].Name)
	})

	return out
}
```

Now update `main.go` to use it — replace the whole file:

```go
// main.go
package main

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/fs" // STAGE 1: new import
)

// STAGE 1: model now holds a directory listing and a cursor position.
type model struct {
	cwd     string
	entries []fs.Entry
	cursor  int
}

// STAGE 1: build the initial model from the current working directory.
func initialModel() model {
	cwd, _ := os.Getwd()
	return model{
		cwd:     cwd,
		entries: fs.ReadDir(cwd),
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if k, ok := msg.(tea.KeyMsg); ok {
		switch k.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		// STAGE 1: basic up/down cursor movement over the listing.
		case "down", "j":
			if m.cursor < len(m.entries)-1 {
				m.cursor++
			}
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		}
	}
	return m, nil
}

// STAGE 1: render the directory listing with a cursor marker.
func (m model) View() string {
	var b strings.Builder
	b.WriteString(m.cwd + "\n\n")
	for i, e := range m.entries {
		cursor := "  "
		if i == m.cursor {
			cursor = "> "
		}
		name := e.Name
		if e.IsDir {
			name += "/"
		}
		b.WriteString(fmt.Sprintf("%s%s\n", cursor, name))
	}
	return b.String()
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Println("error running program:", err)
		os.Exit(1)
	}
}
```

**How it connects:** `main.go` imports `internal/fs` and calls
`fs.ReadDir()` inside `initialModel()`. `main.go` still owns the whole
Bubble Tea model directly — that changes in Stage 2, when the model itself
moves into its own package.

**Run it:**

```bash
go run main.go
```

**You should see:** the real contents of the directory you ran it from,
with a `>` cursor you can move using `j`/`k` or the arrow keys.

> **Tip #3 — `os.ReadDir` over `os.Open`+`Readdir`.** It doesn't `Stat` every file up front; defer that cost until you actually need file size/mtime (Stage 9's status bar).

---

## Stage 2 — Move the Model into `internal/tui`, Add Panes + Vim Nav

This is the biggest structural jump in the whole guide: the model moves
out of `main.go` into its own package, and gains three panes
(parent/current/preview) instead of one flat listing.

**Files this stage touches:**
- **New:** `internal/tui/model.go`
- **New:** `internal/tui/update.go`
- **New:** `internal/tui/view.go`
- **Edit:** `main.go` (shrinks down to just wiring)

```bash
mkdir -p internal/tui
touch internal/tui/model.go internal/tui/update.go internal/tui/view.go
```

```go
// internal/tui/model.go
// STAGE 2: new package — everything Bubble Tea-related lives here from now on.
package tui

import (
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/fs"
)

// STAGE 2: a pane is one column — parent, current, or preview. Using panes
// from the start (instead of a flat cursor/entries on Model) avoids having
// to retrofit every call site later.
type pane struct {
	path    string
	entries []fs.Entry
	cursor  int
}

// STAGE 2: Model replaces Stage 1's flat model — capital M because main.go
// (a different package) needs to construct it.
type Model struct {
	cwd      string
	parent   pane
	current  pane
	preview  pane
	width    int
	height   int
	pendingG bool // STAGE 2: true right after a lone 'g', waiting for a second 'g' (vim's "gg")
}

// STAGE 2: InitialModel replaces Stage 1's initialModel() — now exported
// so main.go can call it.
func InitialModel() Model {
	cwd, _ := os.Getwd()
	m := Model{
		cwd:     cwd,
		current: pane{path: cwd, entries: fs.ReadDir(cwd)},
	}
	m, _ = m.refreshPanes()
	return m
}

func (m Model) selectedPath() string {
	if len(m.current.entries) == 0 || m.current.cursor >= len(m.current.entries) {
		return ""
	}
	return filepath.Join(m.cwd, m.current.entries[m.current.cursor].Name)
}

// STAGE 2: refreshPanes recomputes parent + preview from the current
// selection. It returns a tea.Cmd (nil for now) because Stage 5 turns file
// preview into an async operation — writing the signature this way now
// avoids reworking every caller later.
func (m Model) refreshPanes() (Model, tea.Cmd) {
	parentPath := filepath.Dir(m.cwd)
	m.parent = pane{path: parentPath, entries: fs.ReadDir(parentPath)}
	for i, e := range m.parent.entries {
		if e.Name == filepath.Base(m.cwd) {
			m.parent.cursor = i
		}
	}

	m.preview = pane{}
	if len(m.current.entries) > 0 && m.current.cursor < len(m.current.entries) {
		sel := m.current.entries[m.current.cursor]
		selPath := filepath.Join(m.cwd, sel.Name)
		if sel.IsDir {
			m.preview = pane{path: selPath, entries: fs.ReadDir(selPath)}
		}
		// non-dir case: nothing to show yet — Stage 5 adds file content preview
	}
	return m, nil
}
```

```go
// internal/tui/update.go
// STAGE 2: Init/Update and all navigation live here.
package tui

import (
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/fs"
)

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	// STAGE 2: track terminal size — needed for layout in Stage 3.
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

	case tea.KeyMsg:
		key := msg.String()
		var cmd tea.Cmd

		// STAGE 2: "gg" two-key sequence handling.
		if m.pendingG {
			m.pendingG = false
			if key == "g" {
				m.current.cursor = 0
				m, cmd = m.refreshPanes()
				return m, cmd
			}
		}

		switch key {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "j", "down":
			if m.current.cursor < len(m.current.entries)-1 {
				m.current.cursor++
				m, cmd = m.refreshPanes()
			}
		case "k", "up":
			if m.current.cursor > 0 {
				m.current.cursor--
				m, cmd = m.refreshPanes()
			}
		case "g":
			m.pendingG = true
		case "G": // STAGE 2: jump to bottom
			m.current.cursor = len(m.current.entries) - 1
			m, cmd = m.refreshPanes()
		case "h", "left": // STAGE 2: go to parent directory
			m, cmd = m.goToParent()
		case "l", "right", "enter": // STAGE 2: enter selected directory
			m, cmd = m.enterSelected()
		case "ctrl+d": // STAGE 2: half-page down
			m.current.cursor = min(m.current.cursor+10, len(m.current.entries)-1)
			m, cmd = m.refreshPanes()
		case "ctrl+u": // STAGE 2: half-page up
			m.current.cursor = max(m.current.cursor-10, 0)
			m, cmd = m.refreshPanes()
		}
		return m, cmd
	}
	return m, nil
}

func (m Model) goToParent() (Model, tea.Cmd) {
	parent := filepath.Dir(m.cwd)
	if parent == m.cwd {
		return m, nil
	}
	m.cwd = parent
	m.current = pane{path: parent, entries: fs.ReadDir(parent)}
	return m.refreshPanes()
}

func (m Model) enterSelected() (Model, tea.Cmd) {
	if len(m.current.entries) == 0 {
		return m, nil
	}
	sel := m.current.entries[m.current.cursor]
	if sel.IsDir {
		newPath := filepath.Join(m.cwd, sel.Name)
		m.cwd = newPath
		m.current = pane{path: newPath, entries: fs.ReadDir(newPath)}
		return m.refreshPanes()
	}
	return m, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
```

```go
// internal/tui/view.go
// STAGE 2: a minimal single-column View for now — Stage 3 upgrades this
// to the real three-pane layout. This exists so the package compiles and
// is runnable at the end of THIS stage, per the "always runnable" rule.
package tui

import "strings"

func (m Model) View() string {
	var b strings.Builder
	b.WriteString(m.cwd + "\n\n")
	for i, e := range m.current.entries {
		cursor := "  "
		if i == m.current.cursor {
			cursor = "> "
		}
		name := e.Name
		if e.IsDir {
			name += "/"
		}
		b.WriteString(cursor + name + "\n")
	}
	return b.String()
}
```

Now shrink `main.go` down to pure wiring — replace the whole file:

```go
// main.go
// STAGE 2: main.go no longer defines the model — it just wires tui.Model
// into a Bubble Tea program. This file stays this small for the rest of
// the guide.
package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/tui"
)

func main() {
	p := tea.NewProgram(tui.InitialModel())
	if _, err := p.Run(); err != nil {
		fmt.Println("error running program:", err)
		os.Exit(1)
	}
}
```

**How it connects:** `main.go` imports `internal/tui`, calls
`tui.InitialModel()` to get a `tui.Model`, and hands it to
`tea.NewProgram()`. `internal/tui` imports `internal/fs` to read
directories. Nothing else imports Bubble Tea except `internal/tui` and
`main.go`.

**Run it:**

```bash
go build ./...   # checks every package, not just main — catches cross-package mistakes
go run main.go
```

**You should see:** the same listing as Stage 1, but now `h` goes to the
parent directory, `l`/`Enter` enters a selected directory, `gg` jumps to
top, `G` jumps to bottom, `Ctrl+d`/`Ctrl+u` half-page. The view still
looks like Stage 1 — that's expected, panes aren't rendered yet.

> **Tip #4 — model methods return `Model`, not `*Model`.** `m, cmd = m.foo()` keeps every state change explicit and traceable.

> **Tip #5 — `go build ./...`, not just `go run main.go`, once you have more than one package.** `go run` only compiles what `main` needs; a broken `internal/tui` file with no current callers can hide until later.

---

## Stage 3 — Real Three-Pane Layout

**Files this stage touches:**
- **Edit:** `internal/tui/view.go` (full rewrite)

```go
// internal/tui/view.go
// STAGE 3: replaces Stage 2's placeholder single-column view with the real
// parent | current | preview layout, using Lip Gloss for borders + width.
package tui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// STAGE 3: renders one pane (parent, current, or preview) as a bordered box.
func renderPane(p pane, width int, active bool) string {
	style := lipgloss.NewStyle().Width(width).Height(20).Padding(0, 1)
	if active {
		style = style.BorderStyle(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("212"))
	} else {
		style = style.BorderStyle(lipgloss.NormalBorder()).BorderForeground(lipgloss.Color("240"))
	}

	var b strings.Builder
	for i, e := range p.entries {
		line := e.Name
		if e.IsDir {
			line += "/"
		}
		if i == p.cursor {
			line = lipgloss.NewStyle().Reverse(true).Render(line)
		}
		b.WriteString(line + "\n")
	}
	return style.Render(b.String())
}

// STAGE 3: View now joins three panes side by side instead of one column.
func (m Model) View() string {
	if m.width == 0 {
		return "loading..." // STAGE 3: guards against rendering before the first WindowSizeMsg arrives
	}
	colWidth := m.width / 3

	parentView := renderPane(m.parent, colWidth, false)
	currentView := renderPane(m.current, colWidth, true)
	previewView := renderPane(m.preview, colWidth, false)

	return lipgloss.JoinHorizontal(lipgloss.Top, parentView, currentView, previewView)
}
```

**How it connects:** nothing else changes — `model.go` and `update.go`
already populate `m.parent`/`m.current`/`m.preview` via `refreshPanes()`
from Stage 2; this stage only changes how those three fields get drawn.
`main.go` is untouched.

**Run it:**

```bash
go get github.com/charmbracelet/lipgloss@latest   # if you haven't already
go build ./...
go run main.go
```

**You should see:** three bordered columns. The middle one (current
directory) has a highlighted/rounded border; moving the cursor updates
the left (parent) and right (preview, when on a directory) panes live.

> **Tip #6 — always handle `tea.WindowSizeMsg`.** Without it `m.width` stays `0` forever and you'd only ever see the `"loading..."` placeholder — this is why Stage 2's `update.go` already had that case even though it wasn't visibly used until now.

> **Tip #7 — `lipgloss.JoinHorizontal`, not manual string concatenation.** It correctly aligns multi-line blocks of different heights; hand-rolled joining is a common source of misaligned borders.

---

## Stage 4 — `internal/theme`: Centralized Colors

**Files this stage touches:**
- **New:** `internal/theme/theme.go`
- **Edit:** `internal/tui/view.go` (small addition, not a full rewrite)

```bash
mkdir -p internal/theme
touch internal/theme/theme.go
```

```go
// internal/theme/theme.go
// STAGE 4: new package — centralizes color/style so view.go stays about
// layout, not color literals scattered across render functions.
package theme

import "github.com/charmbracelet/lipgloss"

var (
	Primary   = lipgloss.Color("212")
	Muted     = lipgloss.Color("240")
	DirColor  = lipgloss.Color("39")
	FileColor = lipgloss.Color("252")
	ExecColor = lipgloss.Color("42")

	ActivePane = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(Primary)

	InactivePane = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			BorderForeground(Muted)

	StatusBar = lipgloss.NewStyle().
			Background(lipgloss.Color("236")).
			Foreground(lipgloss.Color("252")).
			Padding(0, 1)
)

// STAGE 4: picks a color for an entry based on type.
func EntryColor(isDir, isExec bool) lipgloss.Color {
	switch {
	case isDir:
		return DirColor
	case isExec:
		return ExecColor
	default:
		return FileColor
	}
}
```

Edit `internal/tui/view.go` — inside `renderPane`, change the line-building
loop to color each entry (this replaces just the loop body, not the whole
file):

```go
	// STAGE 4: color each entry by type instead of plain text.
	var b strings.Builder
	for i, e := range p.entries {
		name := e.Name
		if e.IsDir {
			name += "/"
		}
		line := lipgloss.NewStyle().
			Foreground(theme.EntryColor(e.IsDir, false)). // STAGE 4
			Render(name)
		if i == p.cursor {
			line = lipgloss.NewStyle().Reverse(true).Render(line)
		}
		b.WriteString(line + "\n")
	}
```

Add the import at the top of `view.go`:

```go
import (
	"strings"

	"github.com/charmbracelet/lipgloss"

	"github.com/<you>/tui-explorer/internal/theme" // STAGE 4: new import
)
```

**How it connects:** `internal/tui/view.go` imports `internal/theme` and
calls `theme.EntryColor()`. `internal/theme` doesn't import `internal/tui`
or `internal/fs` — it only knows about colors, so it stays reusable.

**Run it:**

```bash
go build ./...
go run main.go
```

**You should see:** the same three-pane layout, but directory names are
now colored differently from file names (blue-ish for directories by
default, per `DirColor` above).

> **Tip #8 — use Lip Gloss color functions, not raw ANSI escapes.** `lipgloss.Color("212")` renders consistently across terminals; hand-rolled escape codes don't.

---

## Stage 4b — Icons

**Files this stage touches:**
- **New:** `internal/theme/icons.go`
- **Edit:** `internal/tui/model.go` (add one field)
- **Edit:** `internal/tui/view.go` (use the icon in each line)

```bash
touch internal/theme/icons.go
```

```go
// internal/theme/icons.go
// STAGE 4b: icon lookup. Two icon sets exist — Plain (safe default, works
// in any terminal) and Nerd (needs a patched Nerd Font installed). See the
// note below the code for why Plain is the default.
package theme

import (
	"path/filepath"
	"strings"

	"github.com/<you>/tui-explorer/internal/fs"
)

type IconSet int

const (
	IconSetPlain IconSet = iota // STAGE 4b: default — ASCII markers, works everywhere
	IconSetNerd                 // STAGE 4b: opt-in — needs a Nerd Font terminal font
)

// STAGE 4b: extension -> nerd font codepoint. Written as \uXXXX escapes,
// not pasted glyph characters — keeps diffs/grep readable regardless of
// the reader's own editor font.
var nerdIconsByExt = map[string]string{
	".go":   "\uE627",
	".mod":  "\uE627",
	".py":   "\uE73C",
	".js":   "\uE74E",
	".ts":   "\uE628",
	".rs":   "\uE7A8",
	".md":   "\uF48A",
	".json": "\uE60B",
	".yaml": "\uF481",
	".yml":  "\uF481",
	".toml": "\uF481",
	".sh":   "\uF489",
	".png":  "\uF1C5",
	".jpg":  "\uF1C5",
	".jpeg": "\uF1C5",
	".gif":  "\uF1C5",
	".pdf":  "\uF1C1",
	".zip":  "\uF410",
	".tar":  "\uF410",
	".gz":   "\uF410",
}

const (
	nerdFolder      = "\uF07B"
	nerdFolderOpen  = "\uF07C"
	nerdFileDefault = "\uF15B"

	plainFolder      = "[D]"
	plainFileDefault = "[F]"
)

// STAGE 4b: IconFor returns the right icon string for an entry, honoring
// the active IconSet. selected swaps folder -> open-folder, like yazi.
func IconFor(set IconSet, e fs.Entry, selected bool) string {
	if set == IconSetPlain {
		if e.IsDir {
			return plainFolder
		}
		return plainFileDefault
	}

	if e.IsDir {
		if selected {
			return nerdFolderOpen
		}
		return nerdFolder
	}

	ext := strings.ToLower(filepath.Ext(e.Name))
	if icon, ok := nerdIconsByExt[ext]; ok {
		return icon
	}
	return nerdFileDefault
}
```

Edit `internal/tui/model.go` — add one field to `Model` and set it in
`InitialModel()`:

```go
type Model struct {
	cwd      string
	parent   pane
	current  pane
	preview  pane
	width    int
	height   int
	pendingG bool
	icons    theme.IconSet // STAGE 4b: which icon set to render with
}
```

```go
func InitialModel() Model {
	cwd, _ := os.Getwd()
	m := Model{
		cwd:     cwd,
		current: pane{path: cwd, entries: fs.ReadDir(cwd)},
		icons:   theme.IconSetPlain, // STAGE 4b: safe default — see Tip #10
	}
	m, _ = m.refreshPanes()
	return m
}
```

Add the import to `model.go`:

```go
import (
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/fs"
	"github.com/<you>/tui-explorer/internal/theme" // STAGE 4b: new import
)
```

Edit `internal/tui/view.go` — `renderPane` needs the icon set passed in,
and needs to prepend the icon to each line:

```go
// STAGE 4b: renderPane now takes an IconSet parameter.
func renderPane(p pane, width int, active bool, icons theme.IconSet) string {
	style := lipgloss.NewStyle().Width(width).Height(20).Padding(0, 1)
	if active {
		style = style.BorderStyle(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("212"))
	} else {
		style = style.BorderStyle(lipgloss.NormalBorder()).BorderForeground(lipgloss.Color("240"))
	}

	var b strings.Builder
	for i, e := range p.entries {
		icon := theme.IconFor(icons, e, i == p.cursor) // STAGE 4b
		text := icon + " " + e.Name                     // STAGE 4b: icon prepended
		if e.IsDir {
			text += "/"
		}
		line := lipgloss.NewStyle().
			Foreground(theme.EntryColor(e.IsDir, false)).
			Render(text)
		if i == p.cursor {
			line = lipgloss.NewStyle().Reverse(true).Render(line)
		}
		b.WriteString(line + "\n")
	}
	return style.Render(b.String())
}

func (m Model) View() string {
	if m.width == 0 {
		return "loading..."
	}
	colWidth := m.width / 3

	// STAGE 4b: pass m.icons into every renderPane call.
	parentView := renderPane(m.parent, colWidth, false, m.icons)
	currentView := renderPane(m.current, colWidth, true, m.icons)
	previewView := renderPane(m.preview, colWidth, false, m.icons)

	return lipgloss.JoinHorizontal(lipgloss.Top, parentView, currentView, previewView)
}
```

**How it connects:** `internal/theme/icons.go` depends on `internal/fs`
(to read `Entry.IsDir`/`Name`) but nothing depends on `icons.go` except
`internal/tui`. `Model.icons` is read once in `View()` via `renderPane`'s
new parameter — nothing else needs to know the icon set exists.

**Run it:**

```bash
go build ./...
go run main.go
```

**You should see:** `[D]` before directory names and `[F]` before file
names (the `IconSetPlain` default). To try the Nerd Font glyphs instead —
**only if your terminal font is actually a Nerd Font variant** (see
nerdfonts.com) — temporarily change `theme.IconSetPlain` to
`theme.IconSetNerd` in `InitialModel()` and re-run; you should see proper
folder/file glyphs instead of boxes. Change it back to `IconSetPlain` if
you don't have a Nerd Font installed — Stage 10 makes this a real config
setting instead of a hardcoded line.

> **Tip #9 — icon codepoints as `\uXXXX` escapes, not pasted glyphs, in source.** Pasted private-use-area characters render differently per-editor-font and can get mangled on save; `\uF07B` is unambiguous.

> **Tip #10 — default to `IconSetPlain`.** Shipping Nerd Font icons as the default means users without that font see broken boxes — reads as "buggy," not "polished."

---

## Stage 5 — `internal/preview`: Fa  ile Content Preview

**Files this stage touches:**
- **New:** `internal/preview/preview.go`
- **Edit:** `internal/tui/model.go` (preview fields + async branch)
- **Edit:** `internal/tui/update.go` (handle the async result message)
- **Edit:** `internal/tui/view.go` (render text preview when present)

```bash
mkdir -p internal/preview
touch internal/preview/preview.go
```

```go
// internal/preview/preview.go
// STAGE 5: new package — reads a text file's first N lines for the preview
// pane, and detects binary files so we don't dump garbage bytes on screen.
package preview

import (
	"bufio"
	"io"
	"os"
	"strings"
)

const MaxPreviewLines = 200 // STAGE 5: cap so a huge file doesn't get fully read just to preview it

func TextPreview(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	bin, err := isBinary(f)
	if err != nil {
		return "", err
	}
	if bin {
		return "[binary file]", nil
	}
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		return "", err
	}

	var b strings.Builder
	scanner := bufio.NewScanner(f)
	lines := 0
	for scanner.Scan() && lines < MaxPreviewLines {
		b.WriteString(scanner.Text() + "\n")
		lines++
	}
	return b.String(), nil
}

// STAGE 5: checks the first 512 bytes for a NUL byte — a strong binary signal.
func isBinary(f *os.File) (bool, error) {
	buf := make([]byte, 512)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return false, err
	}
	for i := 0; i < n; i++ {
		if buf[i] == 0 {
			return true, nil
		}
	}
	return false, nil
}
```

Edit `internal/tui/model.go` — add preview-text fields to `Model`, and
change `refreshPanes` to dispatch a load command for files:

```go
type Model struct {
	cwd         string
	parent      pane
	current     pane
	preview     pane
	previewText string // STAGE 5: file content preview (when selection is a file)
	previewPath string // STAGE 5: which path previewText belongs to — used to detect stale results
	width       int
	height      int
	pendingG    bool
	icons       theme.IconSet
}
```

```go
func (m Model) refreshPanes() (Model, tea.Cmd) {
	parentPath := filepath.Dir(m.cwd)
	m.parent = pane{path: parentPath, entries: fs.ReadDir(parentPath)}
	for i, e := range m.parent.entries {
		if e.Name == filepath.Base(m.cwd) {
			m.parent.cursor = i
		}
	}

	m.preview = pane{}
	m.previewText = "" // STAGE 5: clear stale preview text on every refresh
	m.previewPath = ""

	if len(m.current.entries) == 0 || m.current.cursor >= len(m.current.entries) {
		return m, nil
	}

	sel := m.current.entries[m.current.cursor]
	selPath := filepath.Join(m.cwd, sel.Name)

	if sel.IsDir {
		m.preview = pane{path: selPath, entries: fs.ReadDir(selPath)}
		return m, nil
	}

	// STAGE 5: it's a file — dispatch an async load instead of reading here.
	return m, loadPreviewCmd(selPath)
}
```

Edit `internal/tui/update.go` — add the command constructor and the
message handler:

```go
// STAGE 5: message carrying the result of an async preview load.
type previewLoadedMsg struct {
	path    string
	content string
	err     error
}

// STAGE 5: wraps preview.TextPreview as a tea.Cmd (runs off the update loop).
func loadPreviewCmd(path string) tea.Cmd {
	return func() tea.Msg {
		content, err := preview.TextPreview(path)
		return previewLoadedMsg{path: path, content: content, err: err}
	}
}
```

Add the case inside `Update`'s `switch msg := msg.(type)` block (alongside
the existing `tea.WindowSizeMsg` and `tea.KeyMsg` cases):

```go
	// STAGE 5: handle async preview results.
	case previewLoadedMsg:
		// staleness guard — only apply if this is still the current selection
		if msg.path == m.selectedPath() {
			if msg.err != nil {
				m.previewText = "[error reading file]"
			} else {
				m.previewText = msg.content
			}
			m.previewPath = msg.path
		}
		return m, nil
```

Add the import to `update.go`:

```go
import (
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/<you>/tui-explorer/internal/fs"
	"github.com/<you>/tui-explorer/internal/preview" // STAGE 5: new import
)
```

Edit `internal/tui/view.go` — render `previewText` when it's set, instead
of the directory-listing pane:

```go
// STAGE 5: renders file content preview in a bordered box.
func renderTextPreview(content string, width int) string {
	style := lipgloss.NewStyle().
		Width(width).
		Height(20).
		Padding(0, 1).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("240"))
	return style.Render(content)
}

func (m Model) View() string {
	if m.width == 0 {
		return "loading..."
	}
	colWidth := m.width / 3

	parentView := renderPane(m.parent, colWidth, false, m.icons)
	currentView := renderPane(m.current, colWidth, true, m.icons)

	// STAGE 5: choose text preview vs. directory preview based on what's selected.
	var previewView string
	if m.previewText != "" {
		previewView = renderTextPreview(m.previewText, colWidth)
	} else {
		previewView = renderPane(m.preview, colWidth, false, m.icons)
	}

	return lipgloss.JoinHorizontal(lipgloss.Top, parentView, currentView, previewView)
}
```

**How it connects:** `internal/tui/model.go` and `update.go` import the
new `internal/preview` package. The flow: cursor moves → `refreshPanes()`
returns a `tea.Cmd` (`loadPreviewCmd`) instead of doing I/O directly →
Bubble Tea runs that command off the update loop → it produces a
`previewLoadedMsg` → `Update()` receives it, checks it's still relevant via
`selectedPath()`, and applies it to `m.previewText` → `View()` picks it up
on the next render.

**Run it:**

```bash
go build ./...
go run main.go
```

**You should see:** selecting a directory still shows its listing in the
right pane (Stage 3 behavior, unchanged); selecting a text file (e.g. a
`.go` or `.md` file) now shows its actual contents in the right pane
instead. Selecting a binary file shows `[binary file]`.

> **Tip #11 — guard against stale async results.** Rapid `j`/`k` presses can fire multiple preview loads that return out of order; `selectedPath()` is what prevents a stale one from flashing onto screen.

> **Tip #12 — cap what you read.** `MaxPreviewLines` stops a multi-GB file from being fully read just to preview the first screen.

---

## Stages 6–12 — What's Left, and Where It'll Go

Same format continues for these — ask for any one by name and you'll get
it broken down exactly like Stages 0–5 above, against your actual files:

| Stage | What it adds | Files it will touch |
|---|---|---|
| 6 | Selection, yank/cut/paste, delete-with-confirm | `tui/update.go` (+ new `tui/fileops.go`) |
| 7 | `/` incremental filter | `tui/update.go` |
| 8 | Bookmarks (`m`/`'`) and tabs | `tui/model.go` |
| 9 | Status bar, `?` help overlay | `tui/view.go` |
| 10 | Config file (TOML), real keybinding config, icon-set toggle | new `internal/config/config.go` |
| 11 | Async dir reads, list virtualization for huge dirs | `internal/fs`, `tui/view.go` |
| 12 | `$EDITOR` handoff, alt-screen, startup path arg | `main.go`, `tui/update.go` |

---

## All Tips, Collected

1. Commit after every stage.
2. Never do I/O inside `View()`.
3. Prefer `os.ReadDir`; defer `Stat`/file-info calls until needed.
4. Model methods return `Model`, not `*Model`.
5. `go build ./...`, not just `go run main.go`, once you have more than one package.
6. Always handle `tea.WindowSizeMsg`; never hardcode dimensions.
7. Use `lipgloss.JoinHorizontal`/`JoinVertical`, not manual string joins.
8. Use Lip Gloss color functions, not raw ANSI escapes.
9. Write icon codepoints as `\uXXXX` escapes, not pasted glyphs, in source.
10. Default to plain ASCII icons; make Nerd Font icons an opt-in.
11. Guard async results (preview loads) against staleness.
12. Cap how much of a file you read for preview.
13. Never bind single-key deletion to something destructive — require confirmation (relevant from Stage 6).
14. Keep `internal/fs` free of any Bubble Tea/Lip Gloss imports — it should stay usable outside a TUI context forever.

---

Build it stage by stage, run it after every file change, and don't move on
until the "you should see" line for that stage actually matches what's on
your screen.