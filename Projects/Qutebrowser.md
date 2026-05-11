Qutebrowser config. For macOS it lives in `~/.qutebrowser/config.py`

This is a No Window decoration setup. To enable the 

```python
# import catppuccin
# catppuccin.setup(c, "mocha", True)
config.load_autoconfig(False)

config.set("content.cookies.accept", "all", "chrome-devtools://*")
config.set("content.cookies.accept", "all", "devtools://*")

config.set("content.images", True, "chrome-devtools://*")
config.set("content.images", True, "devtools://*")
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 ({os_info}; rv:136.0) Gecko/20100101 Firefox/139.0",
    "https://accounts.google.com/*",
)

base00 = "#181818"
base01 = "#282828"
base02 = "#383838"
base03 = "#585858"
base04 = "#b8b8b8"
base05 = "#d8d8d8"
base06 = "#e8e8e8"
base07 = "#f8f8f8"
base08 = "#ab4642"
base09 = "#dc9656"
base0A = "#f7ca88"
base0B = "#a1b56c"
base0C = "#86c1b9"
base0D = "#7cafc2"
base0E = "#ba8baf"
base0F = "#a16946"
base0G = "#8fae5f"
base0BC = "#627536"


# completion
c.colors.completion.fg = base05
c.colors.completion.odd.bg = base01
c.colors.completion.even.bg = base00
c.colors.completion.category.fg = base0A
c.colors.completion.category.bg = base00
c.colors.completion.category.border.top = base00
c.colors.completion.category.border.bottom = base00
c.colors.completion.item.selected.fg = base05
c.colors.completion.item.selected.bg = base02
c.colors.completion.item.selected.border.top = base02
c.colors.completion.item.selected.border.bottom = base02
c.colors.completion.item.selected.match.fg = base09
c.colors.completion.match.fg = base0G
c.colors.completion.scrollbar.fg = base05


# hints
c.colors.hints.fg = base00
c.colors.hints.bg = base0A
c.colors.hints.match.fg = base05

# statusbar
c.colors.statusbar.url.fg = base05
c.colors.statusbar.url.hover.fg = base0E
c.colors.statusbar.url.success.https.fg = base0B
c.colors.statusbar.url.warn.fg = base0E
c.colors.statusbar.progress.bg = base0D
c.colors.statusbar.command.private.fg = base05
c.colors.statusbar.command.private.bg = base00
c.colors.statusbar.normal.fg = base06
c.colors.statusbar.normal.bg = base00
c.colors.statusbar.insert.fg = base07
c.colors.statusbar.insert.bg = base0BC
c.colors.statusbar.caret.fg = base00
c.colors.statusbar.caret.bg = base0E
c.colors.statusbar.caret.selection.fg = base00
c.colors.statusbar.caret.selection.bg = base0D

# tabs
c.colors.tabs.bar.bg = base00
c.colors.tabs.indicator.start = base0D
c.colors.tabs.indicator.stop = base0C
c.colors.tabs.indicator.error = base08
c.colors.tabs.selected.even.fg = base05
c.colors.tabs.selected.even.bg = base02
c.colors.tabs.selected.odd.fg = base05
c.colors.tabs.selected.odd.bg = base02
c.colors.tabs.odd.fg = base05
c.colors.tabs.odd.bg = base00
c.colors.tabs.even.fg = base05
c.colors.tabs.even.bg = base00

config.set("content.javascript.enabled", True, "chrome-devtools://*")
config.set("content.javascript.enabled", True, "devtools://*")
config.set("content.javascript.enabled", True, "chrome://*/*")
config.set("content.javascript.enabled", True, "qute://*/*")

# Determine architecture for the path (mac_arm64 for M-series, mac_x64 for Intel)

# Path to the actual library file
# Pass this to the Qt engine via args
# We combine this with your existing remote-debugging arg
# Use the absolute path to mpv
# Keep Safari as the backup for Udemy/Netflix

# Send the current page to mpv
config.bind("v", "spawn /opt/homebrew/bin/mpv {url}")
config.bind("V", "hint links spawn /opt/homebrew/bin/mpv {hint-url}")
config.set("content.javascript.enabled", True, "chrome-devtools://*")

c.tabs.padding = {"top": 7, "bottom": 7, "left": 8, "right": 8}
c.tabs.indicator.width = 0
c.tabs.last_close = "default-page"
c.tabs.new_position.stacking = False


c.content.autoplay = False
c.content.pdfjs = True
c.content.blocking.method = "both"


c.completion.shrink = True
c.completion.height = "40%"
c.completion.use_best_match = True
c.completion.timestamp_format = ""
c.completion.open_categories = ["quickmarks", "bookmarks", "history"]
c.completion.scrollbar.width = 6

c.fonts.default_family = "JetBrainsMono Nerd Font"
c.fonts.default_size = "12pt"
c.window.hide_decoration = True

c.scrolling.smooth = True


c.window.title_format = "{perc} - {current_title}"
c.window.transparent = True
c.zoom.levels = [
    "25%",
    "33%",
    "50%",
    "60%",
    "67%",
    "75%",
    "90%",
    "100%",
    "110%",
    "125%",
    "150%",
    "175%",
    "200%",
    "250%",
    "300%",
    "400%",
    "500%",
]
# c.window.title_format = "{perc}{current_title}"
# c.window.hide_decoration = True

c.content.cookies.accept = "no-3rdparty"
c.qt.args = ["--remote-debugging-port=9000"]

c.url.default_page = str(config.configdir / "startpage.html")
c.url.start_pages = c.url.default_page


```