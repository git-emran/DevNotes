

##### Navigation:


- Moving `<-` with B - to backward word by word
-  `v a w ` to select around a around 
- Shift + v to select the entire line
- ` v a t` to select around a `<tag>`

##### Braces around word
```
-     Old text                    Command         New text
--------------------------------------------------------------------------------
   surr*ound_words             ysiw)           (surround_words)
   *make strings               ys$"            "make strings"
   [delete ar*ound me!]        ds]             delete around me!
   remove <b>HTML t*ags</b>    dst             remove HTML tags
   'change quot*es'            cs'"            "change quotes"
   <b>or tag* types</b>        csth1<CR>       <h1>or tag types</h1>
   delete(functi*on calls)     dsf             function calls
 

```


# Neovim Text Editing Tricks

| Shortcut                           | Description                               | Notes                                                                         |
| ---------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| `i`                                | Enter insert mode before cursor           | Core Neovim; use `<Esc>` to exit. LazyVim doesn't remap.                      |
| `I`                                | Enter insert mode at line start           | Inserts at first non-blank character. Works in normal mode.                   |
| `a`                                | Enter insert mode after cursor            | Appends after cursor. LazyVim preserves default.                              |
| `A`                                | Enter insert mode at line end             | Appends at end of line, past last character. Use instead of `$i`.             |
| `o`                                | Open new line below and enter insert mode | Adds newline below cursor. LazyVim keeps default.                             |
| `O`                                | Open new line above and enter insert mode | Adds newline above cursor. Works in normal mode.                              |
| `v`                                | Start character-wise Visual mode          | Selects individual characters. Use `j`, `k`, etc., to extend.                 |
| `V`                                | Start line-wise Visual mode               | Selects entire line(s). Use for full-line operations (e.g., `Vy` to yank).    |
| `Ctrl-v`                           | Start block-wise Visual mode              | Selects rectangular blocks. Useful for column editing.                        |
| `y`                                | Yank (copy) selected text                 | Use after `v`, `V`, or with motions (e.g., `yy` for full line).               |
| `d`                                | Delete selected text or motion            | E.g., `dd` deletes line, `dw` deletes word. Stores in register.               |
| `c`                                | Change (delete and enter insert mode)     | E.g., `cw` changes word, `cc` changes line. LazyVim preserves.                |
| `p`                                | Paste after cursor                        | Pastes from default register. Use `P` to paste before.                        |
| `u`                                | Undo last change                          | Moves backward in undo stack. LazyVim doesn't remap.                          |
| `Ctrl-r`                           | Redo last undone change                   | Moves forward in undo stack. Check `:map <C-r>` for conflicts.                |
| `x`                                | Delete character under cursor             | Like `dl`. LazyVim keeps default.                                             |
| `X`                                | Delete character before cursor            | Like `dh`. Works in normal mode.                                              |
| `r`                                | Replace character under cursor            | E.g., `ra` replaces with `a`. Stays in normal mode.                           |
| `R`                                | Enter replace mode                        | Overwrites text as you type. Use `<Esc>` to exit.                             |
| `s`                                | Substitute character (delete and insert)  | Like `cl`. Deletes character and enters insert mode.                          |
| `S`                                | Substitute line (delete line and insert)  | Like `cc`. Deletes entire line and enters insert mode.                        |
| `.`                                | Repeat last change                        | Repeats last insert, delete, or change. LazyVim preserves.                    |
| `~`                                | Toggle case of character under cursor     | Switches between upper/lowercase. Works in normal mode.                       |
| `gU<motion>`                       | Uppercase text in motion                  | E.g., `gUw` uppercases word. Use `gu` for lowercase.                          |
| `>>`                               | Indent line                               | Shifts line right. Use `<<` to unindent. Works in normal mode.                |
| `==`                               | Auto-indent current line                  | Uses file’s indent rules. Requires proper `filetype` settings.                |
| `ciw`                              | Change inside word                        | Deletes word under cursor and enters insert mode. Works anywhere in word.     |
| `diw`                              | Delete inside word                        | Deletes word under cursor. Stays in normal mode.                              |
| `yiw`                              | Yank inside word                          | Yanks word under cursor. LazyVim preserves.                                   |
| `ci"`                              | Change inside quotes                      | Deletes text inside `""` and enters insert mode. Works for `'`, `` ` ``, etc. |
| `viw`                              | Select inside word                        | Visual-selects word under cursor. Use with `y`, `d`, etc.                     |
| `vaf`                              | Select around function                    | Requires `nvim-treesitter`. Selects entire function (signature + body).       |
| `vif`                              | Select inside function                    | Requires `nvim-treesitter`. Selects function body only.                       |
| `va{`                              | Select around curly braces                | Selects `{}` and contents. Use `vi{` for just contents.                       |
| `va(`                              | Select around parentheses                 | Selects `()` and contents. Use `vi(` for just contents.                       |
| `vat`                              | Select around tag                         | Selects HTML/XML tag and contents. Requires `nvim-treesitter` or tag support. |
| `]d`                               | Go to next diagnostic                     | Moves to next error/warning. LazyVim default with LSP.                        |
| `[d`                               | Go to previous diagnostic                 | Moves to previous error/warning. LazyVim default.                             |
| `<leader>tr`                       | Open Trouble diagnostics                  | Shows all workspace errors (via `trouble.nvim`). LazyVim default.             |
| `<leader>xd`                       | Open document diagnostics                 | Shows current file errors (via `trouble.nvim`). Check `:map <leader>x`.       |
| `:lua vim.diagnostic.open_float()` | Show error details                        | Displays diagnostic under cursor in floating window. LazyVim LSP.             |
| `:tabclose`                        | Close current tab                         | Closes active tab. Use `:tabclose!` if unsaved changes.                       |
| `J`                                | Join lines                                | Merges current line with next, adding a space. LazyVim preserves.             |
| `*`                                | Search forward for word under cursor      | Jumps to next occurrence. Use `#` for backward.                               |
| `%`                                | Jump to matching brace/paren              | Works with `{}`, `()`, `[]`. Requires proper syntax settings.                 |
| `:s/foo/bar/g`                     | Replace in current line                   | Substitutes `foo` with `bar` on current line. Use `:%s` for whole file.       |
| `gq<motion>`                       | Format text to fit width                  | E.g., `gqip` formats paragraph. Uses `textwidth` or LSP formatting.           |
| `<leader>cf`                       | Format file or selection                  | LazyVim default (via LSP or `conform.nvim`). Check `:map <leader>c`.          |

## Notes

- **LazyVim Defaults**: Most shortcuts are core Neovim commands. LazyVim adds LSP and plugin-specific bindings (e.g., `<leader>xx` for `trouble.nvim`). Check `:map` for custom mappings in `~/.config/nvim/lua/config/keymaps.lua`.
- **Treesitter Text Objects**: `vaf`, `vif`, `vat`, etc., require `nvim-treesitter` with `textobjects` enabled. Verify with `:TSModuleInfo`.
- **LSP Integration**: Diagnostics (`]d`, `[d`, `<leader>xx`) rely on `nvim-lspconfig`. Ensure LSP is active (`:LspInfo`).
- **Troubleshooting**: If a shortcut fails, check for conflicts with `:map <shortcut>` or ensure plugins (e.g., `trouble.nvim`, `treesitter`) are installed via `:checkhealth`.
- **Cursor Placement**: Most motions (e.g., `ciw`, `vaf`) work anywhere within the target (word, function, etc.). Precise placement noted where required.



### Color schemes

Rose pine
```
return {
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		priority = 1000,
		config = function()
			-- Theme state
			local bg_transparent = true

			-- Setup Rose Pine with your custom configuration
			local function setup_rose_pine()
				require("rose-pine").setup({
					variant = "moon", -- auto, main, moon, dawn
					dark_variant = "", -- main, moon, dawn
					dim_inactive_windows = false,
					extend_background_behind_borders = true,

					enable = {
						terminal = true,
						legacy_highlights = true,
						migrations = true,
					},

					styles = {
						bold = true,
						italic = false,
						transparency = bg_transparent,
					},

					groups = {
						border = "muted",
						link = "iris",
						panel = "surface",

						error = "love",
						hint = "iris",
						info = "foam",
						note = "pine",
						todo = "rose",
						warn = "gold",

						git_add = "foam",
						git_change = "rose",
						git_delete = "love",
						git_dirty = "rose",
						git_ignore = "muted",
						git_merge = "iris",
						git_rename = "pine",
						git_stage = "iris",
						git_text = "rose",
						git_untracked = "subtle",

						headings = {
							h1 = "iris",
							h2 = "foam",
							h3 = "rose",
							h4 = "gold",
							h5 = "pine",
							h6 = "foam",
						},
					},

					palette = {},
					highlight_groups = {
						-- Enable italics for comments and conditionals only
						Comment = { italic = true },
						Conditional = { italic = true },
						-- Treesitter equivalents
						["@comment"] = { italic = true },
						["@conditional"] = { italic = true },
						["@keyword.conditional"] = { italic = true },
					},

					before_highlight = function(group, highlight, palette)
						-- Disable all undercurls
						-- if highlight.undercurl then
						--     highlight.undercurl = false
						-- end
						--
						-- Change palette colours
						-- if highlight.fg == palette.pine then
						--     highlight.fg = palette.foam
						-- end
					end,
				})

				vim.cmd.colorscheme("rose-pine")
			end

			setup_rose_pine()
		end,
	},
}

```

#####  Craftzdog osaka color 

```
return {
	{
		"craftzdog/solarized-osaka.nvim",
		lazy = false, -- load immediately
		priority = 1000,
		opts = {
			transparent = true,
		},
		config = function()
			vim.cmd.colorscheme("solarized-osaka")
		end,
	},
}

```