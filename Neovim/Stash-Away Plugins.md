#### Folke-noice 
Custom noice to show recording @q. Previously it was swallowed by the noice UI

```lua

{
		"folke/noice.nvim",
		event = "VeryLazy",
		opts = function(_, opts)
			opts.routes = opts.routes or {}

			-- 1️⃣ Skip useless notifications
			table.insert(opts.routes, {
				filter = {
					event = "notify",
					find = "No information available",
				},
				opts = { skip = true },
			})

			-- 2️⃣ Fix macro recording messages (`q`)
			table.insert(opts.routes, 1, {
				filter = {
					event = "msg_showmode",
					find = "recording",
				},
				opts = { stop = false }, -- don't swallow the event
				view = "cmdline", -- show it in bottom-left cmdline
			})

			-- 3️⃣ Focus handling (keep your logic)
			local focused = true
			vim.api.nvim_create_autocmd("FocusGained", {
				callback = function()
					focused = true
				end,
			})
			vim.api.nvim_create_autocmd("FocusLost", {
				callback = function()
					focused = false
				end,
			})

			table.insert(opts.routes, 1, {
				filter = {
					cond = function()
						return not focused
					end,
				},
				view = "notify_send",
				opts = { stop = false },
			})

			-- 4️⃣ Commands
			opts.commands = {
				all = {
					view = "split",
					opts = { enter = true, format = "details" },
					filter = {},
				},
			}

			-- 5️⃣ Markdown keys
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = function(event)
					vim.schedule(function()
						require("noice.text.markdown").keys(event.buf)
					end)
				end,
			})

			-- 6️⃣ Presets
			opts.presets = opts.presets or {}
			opts.presets.lsp_doc_border = true
		end,
	}
```

##### Craftzdog osaka color

```lua
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

##### Color scheme

Rose pine

```lua
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

