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