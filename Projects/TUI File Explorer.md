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

 Gate this behind a config flag (Stage 10) since not every terminal font supports these glyphs — falling back to plain text/ASCII markers (`[D]`, `[F]`) keeps the app usable everywhere.

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

 Good luck — build it stage by stage, commit as you go, and don't skip Tip #3.