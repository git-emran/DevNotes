Issue number 3907

## Root Cause: `close_events = {}` in `vim/health.lua`

The bug lives in **`runtime/lua/vim/health.lua`**, lines **408–415**:

lua

bufnr, float_winid = vim.lsp.util.open_floating_preview({}, '', {

  height = max_height,

  width = max_width,

  offset_x = math.floor((vim.o.columns - max_width) / 2),

  offset_y = math.floor((available_lines - max_height) / 2),

  relative = 'editor',

  close_events = {},   -- <-- THE PROBLEM

})

`close_events = {}` is intentionally passed as an **empty table** — meaning _no_ cursor-movement events will close it. That's by design (you don't want the health float disappearing as you scroll). But the consequence is it **also suppresses the `BufLeave` auto-close mechanism** — not directly, but indirectly.

---

## How `close_preview_autocmd` works

In **`runtime/lua/vim/lsp/util.lua`**, `close_preview_autocmd` (line 1498) sets up two things:

lua

local function close_preview_autocmd(events, winnr, floating_bufnr, bufnr)

  local augroup = ...

  -- 1. Always registers a BufLeave on the *source* buffer

  api.nvim_create_autocmd('BufLeave', {

    group = augroup,

    buf = bufnr,           -- source buffer that opened the float

    callback = function()

      vim.schedule(function()

        if api.nvim_get_option_value('filetype', { buf = 0 }) ~= 'qf' then

          close_preview_window(winnr, { floating_bufnr, bufnr })

        end

      end)

    end,

  })

  -- 2. Registers additional events (e.g. CursorMoved) only if events is non-empty

  if #events > 0 then

    api.nvim_create_autocmd(events, { ... })

  end

end

**Part 1** (the `BufLeave` autocmd) looks correct — it watches `buf = bufnr`, i.e. the buffer that was _current when `:checkhealth` was called_.

---

## Why it still fails

The key is what `bufnr` is at call time. Back in `health.lua`:

lua

-- open_floating_preview is called here:

bufnr, float_winid = vim.lsp.util.open_floating_preview(...)

-- Then immediately:

vim.api.nvim_set_current_win(float_winid)   -- focus jumps INTO the float

Inside `open_floating_preview` (line 1685):

lua

local bufnr = api.nvim_get_current_buf()  -- captured BEFORE the window opens

So `bufnr` is the buffer that was current at the time — **your original buffer**. The `BufLeave` autocmd is attached to _that_ buffer.

But then `vim.api.nvim_set_current_win(float_winid)` makes the **float itself** the current window. The float's buffer is now `floating_bufnr`.

When you run `:spl foo.lua`, the focus moves away from the floating window — not from the original source buffer. So:

- `BufLeave` fires on **`floating_bufnr`** (the health:// buffer), not on `bufnr` (the original buffer)
- The autocmd is registered on `bufnr`, so it **never fires**
- The float stays open

---

## Summary

|Step|What happens|
|---|---|
|`:checkhealth` with `style='float'`|`open_floating_preview` captures `bufnr` = original buffer|
|`nvim_set_current_win(float_winid)`|Focus moves INTO the float|
|`BufLeave` autocmd|Attached to original `bufnr`, not the float's buffer|
|`:spl foo.lua`|`BufLeave` fires on the float buffer — wrong buffer, autocmd never triggers|
|Result|Float stays open ❌|

---

## The Fix

In `health.lua`, after calling `open_floating_preview` and moving focus into the float, a `WinLeave`/`BufLeave` autocmd should be registered on `float_winid` or `floating_bufnr` — not left to the LSP util's default which tracks the _source_ buffer. Something like:

lua

-- After nvim_set_current_win(float_winid):

vim.api.nvim_create_autocmd('WinLeave', {

  once = true,

  callback = function()

    if vim.api.nvim_win_is_valid(float_winid) then

      vim.api.nvim_win_close(float_winid, true)

    end

  end,

})

Or alternatively, change the `open_floating_preview` call to NOT move focus into the float (remove `nvim_set_current_win`), so the source buffer remains active and the existing `BufLeave` on `bufnr` works as intended.


Fix:

## The `q` Mapping Chain (float style)

### Step 1 — `open_floating_preview` sets `q` first

**`lsp/util.lua` line 1761–1767:**

lua

api.nvim_buf_set_keymap(

  floating_bufnr, 'n', 'q', '<cmd>bdelete<cr>',

  { silent = true, noremap = true, nowait = true }

)

This puts `q` → `:bdelete` on the float buffer as a first-pass default.

---

### Step 2 — `health.lua` overrides it

**`health.lua` lines 504–516**, run _after all healthchecks complete_:

lua

vim._with({ buf = bufnr }, function()   -- bufnr = floating_bufnr

  if vim.tbl_get(vim.g, 'health', 'style') == 'float'

    or vim.fn.maparg('q', 'n', false, false) == ''

  then

    vim.keymap.set('n', 'q', function()

      if not pcall(vim.cmd.close) then  -- try :close first

        vim.cmd.bdelete()               -- fallback: wipe the buffer

      end

    end, { buf = bufnr, silent = true, noremap = true, nowait = true })

  end

end)

Since `style == 'float'` is true, the condition passes and `q` is **overridden** with `vim.cmd.close` (`:bdelete` stays as a fallback).

---

### Step 3 — `setfiletype('checkhealth')` — does NOT touch `q`

**`health.lua` line 520:** `vim.cmd.setfiletype('checkhealth')` triggers:

- `ftplugin/checkhealth.vim` → `runtime! ftplugin/help.vim`
- `ftplugin/checkhealth.lua` → sets `gO`, `]]`, `[[` only

Neither file touches `q`, so the mapping from Step 2 survives.

---

## So why might `q` not work?

There is a **timing problem**. The flow is:

open_floating_preview() called

  └─ bufnr (util-internal) = original buffer   ← BufLeave autocmd attached here

  └─ returns: floating_bufnr, floating_winnr

nvim_set_current_win(float_winid)              ← BufLeave fires on original buffer

                                                  BUT: current buf is now floating_bufnr

                                                  → ignored by close_preview_window's guard

[all healthchecks run and write content]

q mapping set on floating_bufnr                ← Step 2 override

setfiletype('checkhealth')                     ← Step 3

The `q` mapping itself is fine when **inside the float**. The problem is:

> When `:spl foo.lua` moves focus **away from the float**, `q` is now in a different window. The float sits orphaned — you can't easily get back to it to press `q`.

The `BufLeave` autocmd was watching the **original** buffer (`bufnr` inside `open_floating_preview`). Once you entered the float, that buffer was left — `BufLeave` fired, but `close_preview_window` bailed out because `floating_bufnr` is in the ignore list. It never fires again for `:spl`.

---

## The Fix

The cleanest fix is to attach a `WinLeave` autocmd directly to the **float window** itself, right after `nvim_set_current_win(float_winid)` in `health.lua`:

lua

-- in health.lua, after nvim_set_current_win(float_winid):

vim.api.nvim_create_autocmd('WinLeave', {

  once = true,

  callback = function()

    if vim.api.nvim_win_is_valid(float_winid) then

      vim.api.nvim_win_close(float_winid, true)

    end

  end,

})

This fires the moment focus leaves the float window (via `:spl`, `:tabe`, `<C-w>w`, etc.) — regardless of which buffer is current — and closes it cleanly. The `once = true` ensures it only fires once and self-cleans.