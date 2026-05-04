Qutebrowser config. For macOS it lives in `~/.qutebrowser/config.py`

This is a No Window decoration setup. To enable the 

```python
import catppuccin

catppuccin.setup(c, "mocha", True)
config.load_autoconfig(False)


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


c.content.autoplay = True
c.content.pdfjs = True


c.completion.shrink = True
c.completion.height = "40%"
c.completion.use_best_match = True
c.completion.timestamp_format = ""
c.completion.open_categories = ["quickmarks", "bookmarks", "history"]
c.completion.scrollbar.width = 6

c.fonts.default_family = "JetBrainsMono Nerd Font"
c.fonts.default_size = "12pt"

# window-decoration: set it False to view window decoration.
c.window.hide_decoration = True


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