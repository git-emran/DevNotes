# Release Notes - Writer v3.0.0

🎉 **Simple Notes / Writer v3.0.0** is a major release packed with powerful new editor capabilities, performance optimizations, canvas visual tools, and sleek UI refinements!

---

## 🚀 Key Highlights

### 📊 Native Spreadsheet Support (Univer)
- **Univer Spreadsheet Integration**: Edit and organize tabular data directly within your workspace using full-featured Univer spreadsheets.
- **Slash Command Trigger**: Quickly create or insert spreadsheets using expanded editor slash commands.

### 🎨 Revamped Canvas Editor (Excalidraw)
- **Excalidraw Engine**: Migrated the infinite canvas editor to Excalidraw for smoother drawing, diagramming, and hand-drawn aesthetics.
- **Theme Synchronization**: Perfect dark and light theme alignment via imperative APIs and CSS overrides.
- **Enhanced Save Reliability**: Atomic write handling ensures your canvas diagrams are saved instantly and safely.

### 📖 Interactive Table of Contents
- **Live Document TOC**: Added an interactive, auto-updating Table of Contents component built into `MarkdownPreview`.
- **Smooth Navigation**: Jump instantly to any header section in long notes.

### 🪟 Transparency & Visual Customization
- **Window Transparency & Blur**: Native macOS window transparency with frosted glass backdrop blur effects.
- **Background Mode Toggle**: Easily switch between transparent backdrop and solid background modes.
- **Refined Typography & Gutters**: Relative line numbers and updated gutter styling matched to your selected color themes (Catppuccin, Gruvbox, and more).

---

## ⚡ Performance & Engine Upgrades

- **Fast Application Startup**: Implemented lazy component loading and manual bundle chunking for reduced initial bundle footprint and quicker launch times.
- **Native CodeMirror Slash Commands**: Replaced custom regex filtering with native CodeMirror completion matching for instant `/` command responses.
- **Atomic File Saver**: Optimized editor auto-save lifecycle with atomic file writes to protect note integrity during rapid typing.
- **High-Performance Terminal**: Upgraded terminal rendering with WebGL graphics acceleration and font ligature support.

---

## 📂 Sidebar & Workspace Improvements

- **Note Status & Tag Filters**: Filter notes by status and tags directly in the sidebar file explorer.
- **Folder Notes Panel**: Dedicated panel for folder notes with compact preview metadata and timeline grouping.
- **Reveal in File Explorer**: Context menu action to reveal files in macOS Finder or system file manager.
- **Note Header Emojis**: Quick emoji picker in note headers to customize note icons.
- **File Previews**: Live preview snippet displaying the first meaningful line of notes inside the file tree.

---

## ✍️ Markdown & Formatting Enhancements

- **GitHub-Style Markdown Alerts**: Support for `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, and `[!CAUTION]` callouts with syntax highlighting.
- **Mermaid Diagram Controls**: Interactive controls and preview tools for Mermaid diagrams in the settings tab.
- **Code Block Enhancements**: Auto-completion for code block languages, inline metadata decoration, and triple-backtick auto-expansion.
- **OS Native Spellcheck**: Built-in support for operating system spellcheck capabilities.
- **Template Palette**: Dedicated modal for choosing and inserting note templates.

---

## 🛠️ Maintenance & Refactoring

- Removed legacy search dependencies in favor of unified command palette search.
- Streamlined editor tab state preservation across tab switches.
- Enhanced type safety across renderer build configuration and Jotai state atoms.

---

*Thank you for using Writer!* 🚀
