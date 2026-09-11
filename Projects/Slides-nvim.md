### 1. Installation Options

#### Option A: Local Development (Testing from this current folder)

If you are developing this plugin locally on your machine (`/Users/emranhossain/Programming/slides-nvim`):

**Using [lazy.nvim](https://github.com/folke/lazy.nvim):**

```
lua-- In your plugins configuration:{  dir = "/Users/emranhossain/Programming/slides-nvim",  name = "slides.nvim",  cmd = { "Slides" },  opts = {    options = {      mode = "tab", -- "tab" (default) or "buffer"      vertical_align = "center",      horizontal_align = "left",      show_footer = true,      footer_align = "left",    },  },}
```

**Using pure `init.lua` (without any plugin manager):**

```
lua-- Add local repo to Neovim's runtime path:vim.opt.rtp:prepend("/Users/emranhossain/Programming/slides-nvim")-- Setup the plugin:require("slides").setup({  options = {    mode = "tab",  },})
```

---

#### Option B: Installing from GitHub

**Using [lazy.nvim](https://github.com/folke/lazy.nvim):**

```
lua{  "git-emran/slides.nvim",  cmd = { "Slides" },  opts = {    options = {      mode = "tab",      vertical_align = "center",      horizontal_align = "left",      show_footer = true,      footer_align = "left",    },  },}
```

**Using [packer.nvim](https://github.com/wbthomason/packer.nvim):**

```
luause({  "git-emran/slides.nvim",  config = function()    require("slides").setup({      options = {        mode = "tab",      },    })  end,})
```

**Using [vim-plug](https://github.com/junegunn/vim-plug):**

```
Plug 'git-emran/slides.nvim'

" In your lua config:
lua require('slides').setup()

```

---

### 2. Available Configuration Options

You can pass any overrides to `require("slides").setup(opts)`:

```lua
require("slides").setup({
  options = {
    -- Display mode: "tab" (opens in a dedicated new tabpage) or "buffer" (replaces current window buffer)
    mode = "tab",

    -- Wrap lines inside the slide window
    wrap = true,

    -- Vertical alignment: "center" (vertically centered) or "top"
    vertical_align = "center",

    -- Horizontal alignment: "left" (default), "center" (block-centered), or "line" (each line centered)
    horizontal_align = "left",

    -- Show slide indicator counter at the bottom of the slide (e.g. "9/11  Scroll down")
    show_footer = true,

    -- Footer alignment: "left" (default), "right", or "center"
    footer_align = "left",

    -- Show slide indicator in the Neovim window statusline bar (false by default)
    show_statusline = false,
  },

  -- Separator regex patterns for each filetype
  separator = {
    markdown = "^#+ ",
    org = "^*+ ",
    adoc = "^==+ ",
    asciidoctor = "^==+ ",
  },

  -- Retain header/separator lines as part of slide content
  keep_separator = true,

  -- Strip YAML frontmatter between leading '---' lines
  parse_frontmatter = false,

  -- Local buffer keymaps active during presentation
  keymaps = {
    ["n"] = function() Slides.next() end,
    ["p"] = function() Slides.prev() end,
    ["q"] = function() Slides.quit() end,
    ["f"] = function() Slides.first() end,
    ["l"] = function() Slides.last() end,
    ["<CR>"] = function() Slides.next() end,
    ["<BS>"] = function() Slides.prev() end,
    ["j"] = function() Slides.scroll_down(1) end,
    ["k"] = function() Slides.scroll_up(1) end,
    ["<Down>"] = function() Slides.scroll_down(1) end,
    ["<Up>"] = function() Slides.scroll_up(1) end,
    ["<C-d>"] = function() Slides.scroll_down(5) end,
    ["<C-u>"] = function() Slides.scroll_up(5) end,
    ["<C-f>"] = function() Slides.scroll_page_down() end,
    ["<C-b>"] = function() Slides.scroll_page_up() end,
    ["<PageDown>"] = function() Slides.scroll_page_down() end,
    ["<PageUp>"] = function() Slides.scroll_page_up() end,
    ["d"] = function() Slides.scroll_down(5) end,
    ["u"] = function() Slides.scroll_up(5) end,
    ["gg"] = function() Slides.scroll_to_top() end,
    ["G"] = function() Slides.scroll_to_bottom() end,
  },

  -- Optional user hook to configure the slide buffer (e.g. disable spellcheck, lsp, etc.)
  configure_slide_buffer = function(buf)
    -- Example: vim.opt_local.spell = false
  end,
})

```

---

### 3. Quick Usage

1. Open any Markdown or Org file in Neovim.
2. Run `:Slides` to toggle presentation mode.
3. Use `n` / `p` for slide navigation, `j` / `k` / `d` / `u` for scrolling long text, and `q` to exit.




# Complete Guide to Developing, Testing & Maintaining `slides.nvim`

---

## 1. Local Development Workflow

### How Neovim Finds Your Code

Because you symlinked your git repository to Neovim's `pack/plugins/start/` directory:

- Neovim automatically loads `plugin/slides.lua` and adds your `lua/` directory to runtime `package.path` at startup.
- In your `~/.config/nvim/init.lua` (or wherever you configure plugins), all you need is:


```lua

require("slides").setup({
  -- your test config overrides here
})
```

### Live Testing in an Isolated Neovim Instance

When testing changes to ensure they aren't contaminated by other plugins or personal config:

```lua

# Launch a clean Neovim session loading only slides.nvim and opening the sample presentation
nvim --clean -u NONE \
  --cmd "set rtp+=." \
  --cmd "runtime plugin/slides.lua" \
  examples/presentation.md

```

Then run `:Slides` to test your changes.

---

## 2. Testing Suite

The repository has an isolated test runner (`tests/runner.lua`) that requires no external test harness or plugin dependencies (like `plenary.nvim`).

### Running Automated Tests

From the root of your project:

```
bashmake test
```

Or directly with:

```
bashnvim --headless --clean -u NONE -c "luafile tests/runner.lua"
```

### Adding New Tests

All test specs live in the ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/folders/folder-red-code.svg)

tests/ directory:

- ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/lua.svg)

  parser_spec.lua: Markdown parsing, headings, horizontal rules, frontmatter stripping.
- ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/lua.svg)

  view_spec.lua: Buffer creation, tabs, window scrolling, footer rendering, and layout.
- ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/lua.svg)

  slides_spec.lua: End-to-end integration, navigation, keybindings, command execution, and lifecycle cleanup.

To add a new assertion, use the helper functions in ![](vscode-file://vscode-app/Applications/Antigravity%20IDE.app/Contents/Resources/app/extensions/theme-symbols/src/icons/files/lua.svg)

test_helper.lua:

```lua
local helper = require("tests.test_helper")
local describe, it = helper.describe, helper.it
local assert_equal = helper.assert_equal

describe("my new feature", function()
  it("does something expected", function()
    assert_equal(1 + 1, 2, "Math should work")
  end)
end)

```

---

## 3. Fast Iteration & Hot-Reloading

Lua caches loaded modules in `package.loaded`. If you make changes to a file while Neovim is already open and don't want to restart Neovim completely:

Run this command inside Neovim to wipe the cache and reload:

```
vim:lua for k in pairs(package.loaded) do if k:match("^slides") then package.loaded[k] = nil end end | lua require('slides').setup()
```

You can map this to a quick keybinding in your personal config during development:

```lua



vim.keymap.set("n", "<leader>rs", function()
  for k in pairs(package.loaded) do
    if k:match("^slides") then
      package.loaded[k] = nil
    end
  end
  require("slides").setup()
  vim.notify("slides.nvim reloaded!", vim.log.levels.INFO)
end, { desc = "Reload slides.nvim" })

```

---

## 4. Code Quality & Formatting

To keep the codebase clean and adhere to standard Neovim plugin conventions:

1. **StyLua** (Code Formatter): Install via brew: `brew install stylua` Format the codebase:

   ```bash
   
   stylua lua/ tests/ plugin/
   
   ```
   
2. **Luacheck / Lua Language Server** (Linter): Catch undeclared globals or syntax issues:

   ```bash
   
   luacheck lua/ plugin/ --globals vim
   ```

---

## 5. Continuous Integration (GitHub Actions)

To automatically run `make test` on every push or pull request, add a GitHub workflow file at `.github/workflows/test.yml`:

```yaml
name: Tests

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    name: Run Test Suite
    runs-on: ubuntu-latest
    strategy:
      matrix:
        neovim-version: ['stable', 'nightly', 'v0.9.5', 'v0.10.0']
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.neovim-version }}
      - name: Run tests
        run: make test

```

---

## 6. Release & Version Management

When you are ready to publish updates to your users:

1. Commit and push your changes to your remote repository:
```bash

git add .
git commit -m "feat: improve scrolling and tab naming"
git push origin main
```

2. Tag semantic releases so users pinned to tags (via Lazy/Packer) can update safely:
```bash

git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```



# 🚀 Release & Versioning Guide for `slides.nvim`

This guide explains step-by-step how to version, tag, and publish releases for **slides.nvim** so that users and Neovim plugin managers (like `vim.pack`, `lazy.nvim`, `packer.nvim`) can consume your updates reliably.

---

## 📑 Table of Contents
1. [Understanding Semantic Versioning (SemVer)](#1-understanding-semantic-versioning-semver)
2. [How Neovim Plugin Managers Consume Releases](#2-how-neovim-plugin-managers-consume-releases)
3. [Pre-Release Checklist](#3-pre-release-checklist)
4. [Step-by-Step: Creating a Git Tag](#4-step-by-step-creating-a-git-tag)
5. [Publishing a GitHub Release](#5-publishing-a-github-release)
6. [Hotfixing a Bug (Patch Releases)](#6-hotfixing-a-bug-patch-releases)
7. [Useful Git Tag Commands (Cheatsheet)](#7-useful-git-tag-commands-cheatsheet)

---

## 1. Understanding Semantic Versioning (SemVer)

Neovim plugins follow **Semantic Versioning** (`vMAJOR.MINOR.PATCH`):

```text
v1.2.3
 │ │ └─ PATCH: Bug fixes and small patches (no new features)
 │ └─── MINOR: New features added (backwards-compatible)
 └───── MAJOR: Breaking changes (changes to user config, removed functions)
```

### Examples:
- **`v0.1.0`**: Your very first public preview/release.
- **`v0.1.1`**: You fixed a scrolling rendering bug or a syntax highlight glitch.
- **`v0.2.0`**: You added support for a new file format (e.g. Typst) or a new navigation command without breaking existing user configurations.
- **`v1.0.0`**: First stable API contract. (From this point forward, breaking changes require `v2.0.0`).
- **`v2.0.0`**: You completely redesigned the `setup({...})` configuration options, requiring users to change their `init.lua`.

---

## 2. How Neovim Plugin Managers Consume Releases

Different users configure their package managers differently:

| Plugin Manager | Default Tracking | Tagged Version Tracking |
| :--- | :--- | :--- |
| **`vim.pack`** | Tracks default branch (`main`) | Follows SemVer range: `version = vim.version.range('1.0')` or tag `version = 'v0.1.0'` |
| **`lazy.nvim`** | Tracks default branch (`main`) | `version = "*"` (follows latest tagged release) or `version = "v1.0.0"` |
| **`packer.nvim`** | Tracks default branch (`main`) | `tag = "v1.0.0"` or `tag = "release"` |
| **Manual clone** | Tracks whatever commit was cloned | `git checkout v0.1.0` |

By publishing Git tags and GitHub releases, users who prefer stability over bleeding-edge commits can safely lock onto your releases.

---

## 3. Pre-Release Checklist

Before creating any release, complete these checks:

- [ ] **Run the test suite**:
  ```bash
  make test
  ```
  Ensure all 21+ tests pass with zero failures.

- [ ] **Check working tree status**:
  ```bash
  git status
  ```
  Ensure all desired changes are committed and your working directory is clean.

- [ ] **Update documentation if necessary**:
  If you added a new option or command, make sure [README.md](README.md) reflects it.

- [ ] **Push all commits to `main`**:
  ```bash
  git push origin main
  ```

---

## 4. Step-by-Step: Creating a Git Tag

### Step 4.1: Create an Annotated Tag
Always use **annotated tags** (`-a`) rather than lightweight tags. Annotated tags store the tagger's name, email, date, and a release message.

```bash
git tag -a v0.1.0 -m "Release v0.1.0: Initial release with scrollable slides, isolated tabs, and full markup support"
```

### Step 4.2: Verify the Tag Locally
Check that the tag was created correctly:
```bash
# View list of tags
git tag

# Show tag details and release message
git show v0.1.0
```

### Step 4.3: Push the Tag to GitHub
Tags are **not** pushed automatically when you do `git push`. You must push them explicitly:

```bash
# Push a specific tag
git push origin v0.1.0

# (Or push all local tags that haven't been pushed yet)
git push origin --tags
```

---

## 5. Publishing a GitHub Release

Pushing a tag creates a tag on GitHub, but creating an official **GitHub Release** attaches release notes, marks it on the repository homepage, and notifies watchers.

### Option A: Using the GitHub Web UI (Recommended for beginners)

1. Open your repository on GitHub: `https://github.com/git-emran/slides.nvim`
2. On the right-hand sidebar, click **Releases** (or go to `https://github.com/git-emran/slides.nvim/releases`).
3. Click **Draft a new release**.
4. Click **Choose a tag** and select the tag you pushed (e.g., `v0.1.0`).
5. Set the **Release title** (e.g., `v0.1.0 - First Release`).
6. Write the release description:
   - Click **Generate release notes** to automatically list all merged commits/PRs.
   - Or write a structured summary like:
     ```markdown
     ## 🌟 What's New
     - Pure Lua slide presentations in dedicated tabs or buffers.
     - Smooth native window scrolling for long slides (`Scroll down` / `End` indicators).
     - Markdown, Org-mode, and AsciiDoc support with frontmatter stripping.
     - Zero external dependencies.

     ## 📦 Installation
     See [README.md](https://github.com/git-emran/slides.nvim#readme) for setup with `vim.pack`, `lazy.nvim`, or `packer.nvim`.
     ```
7. (Optional) Check **"Set as the latest release"**.
8. Click **Publish release**.

---

### Option B: Using GitHub CLI (`gh`)

If you have the GitHub CLI installed (`brew install gh`):

```bash
gh release create v0.1.0 \
  --title "v0.1.0 - First Release" \
  --notes "Initial public release of slides.nvim featuring scrollable slides, tab isolation, and zero dependencies."
```

---

## 6. Hotfixing a Bug (Patch Releases)

If a bug is found after a release:

1. Fix the bug in your code.
2. Add a test case in `tests/` verifying the fix.
3. Run `make test` to verify everything passes.
4. Commit and push the fix:
   ```bash
   git add .
   git commit -m "fix: resolve window footer height calculation on small terminals"
   git push origin main
   ```
5. Bump the **PATCH** number and create a new tag:
   ```bash
   git tag -a v0.1.1 -m "Release v0.1.1: Fix footer height on small terminals"
   git push origin v0.1.1
   ```
6. Create the GitHub release for `v0.1.1`.

---

## 7. Useful Git Tag Commands (Cheatsheet)

| Task | Command |
| :--- | :--- |
| **List all tags** | `git tag -l -n` |
| **View tag details** | `git show <tag_name>` |
| **Create annotated tag** | `git tag -a <tag_name> -m "<message>"` |
| **Push a single tag** | `git push origin <tag_name>` |
| **Push all local tags** | `git push origin --tags` |
| **Delete a local tag** | `git tag -d <tag_name>` |
| **Delete a remote tag on GitHub** | `git push --delete origin <tag_name>` |
| **Checkout code at a specific tag** | `git checkout <tag_name>` |
