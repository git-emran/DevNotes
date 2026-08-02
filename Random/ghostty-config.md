# My ghostty config

```bash

# vim: set ft=conf

shell-integration = detect
shell-integration-features = no-title

theme = Dracula
background-opacity = 0.9
background = #0E1419
background-blur = true

# cells
adjust-cell-width = -5%
adjust-cell-height = 20%
adjust-underline-position = 6
adjust-underline-thickness = 30%

# window
window-padding-balance = true


# fonts
font-family = "JetBrains Mono Nerd"
font-family-italic = "JetBrains Mono Nerd"
font-family-bold-italic = "JetBrains Mono Nerd"
font-size = 13

# cursor
cursor-style = block
cursor-style-blink = true
adjust-cursor-thickness = 150%

#keybind = global:cmd+ctrl+shift+j=toggle_visibility
macos-option-as-alt = true
macos-window-shadow = false
macos-titlebar-style = tabs
# vim: set ft=conf

shell-integration = detect
shell-integration-features = no-title

mouse-hide-while-typing

theme = Dracula
background-opacity = 0.9
background = #0E1419
background-blur = true

# cells
adjust-cell-width = -5%
adjust-cell-height = 20%
adjust-underline-position = 6
adjust-underline-thickness = 30%

# window
window-padding-balance = true
window-new-tab-position = end

# fonts
font-family = "JetBrains Mono Nerd"
font-family-italic = "JetBrains Mono Nerd"
font-family-bold-italic = "JetBrains Mono Nerd"
font-size = 14
font-feature = "-calt, -liga, -dlig"

# cursor
cursor-style = block
cursor-style-blink = true
adjust-cursor-thickness = 150%

macos-option-as-alt = true
macos-titlebar-style = tabs

split-divider-color = green

# global keybinds
#keybind = global:cmd+ctrl+shift+j=toggle_visibility
keybind = super+shift+n=new_split:right

keybind = super+h=goto_split:left
keybind = super+j=goto_split:down
keybind = super+k=goto_split:up
keybind = super+l=goto_split:right

keybind = super+shift+n=new_split:right
keybind = super+n=new_split:down
keybind = super+t=new_tab
keybind = super+w=close_surface

keybind = super+down=resize_split:down,10
keybind = super+left=resize_split:left,10
keybind = super+up=resize_split:up,10
keybind = super+right=resize_split:right,10
keybind = super+ctrl+equal=equalize_splits
keybind = super+z=toggle_split_zoom

keybind = super+alt+i=inspector:toggle


```