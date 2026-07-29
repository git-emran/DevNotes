## Fav colorthemes

Rose pine

```lua
local add = require('vim-pack').add

add {
    {
        src = 'rose-pine/neovim',
        module_name = 'rose-pine',

        opts = {
             variant = 'moon',
             dark_variant = '',
        
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
                 transparency = true, -- bg_transparent
             },
        
             groups = {
                 border = 'muted',
                 link = 'iris',
                 panel = 'surface',
        
                 error = 'love',
                 hint = 'iris',
                 info = 'foam',
                 note = 'pine',
                 todo = 'rose',
                 warn = 'gold',
        
                 git_add = 'foam',
                 git_change = 'rose',
                 git_delete = 'love',
                 git_dirty = 'rose',
                 git_ignore = 'muted',
                 git_merge = 'iris',
                 git_rename = 'pine',
                 git_stage = 'iris',
                 git_text = 'rose',
                 git_untracked = 'subtle',
        
                 headings = {
                     h1 = 'iris',
                     h2 = 'foam',
                     h3 = 'rose',
                     h4 = 'gold',
                     h5 = 'pine',
                     h6 = 'foam',
                 },
             },
        
             highlight_groups = {
                 WinBar = { bg = 'NONE' },
                 Comment = { italic = true },
                 Conditional = { italic = true },
        
                 ['@comment'] = { italic = true },
                 ['@conditional'] = { italic = true },
                 ['@keyword.conditional'] = { italic = true },
             },
         },

        on_setup = function()
            -- apply colorscheme AFTER setup
            vim.cmd.colorscheme 'rose-pine'
        end,
    },
}


```



## Neocodeium:

```lua

-- AI completions.
return {
    {
        'monkoose/neocodeium',
        event = 'VeryLazy',
        config = function()
            local neocodeium = require 'neocodeium'
            neocodeium.setup({
			-- Manually enable neocodeium
			enabled = false
            })
            vim.keymap.set('i', '<A-f>', neocodeium.accept)
        end,
        keys = {
            {
                '<M-,>',
                function()
                    require('neocodeium').accept()
                end,
                desc = 'Accept AI suggestion',
                mode = 'i',
            },
            {
                '<M-w>',
                function()
                    require('neocodeium').accept_word()
                end,
                desc = 'Accept AI suggestion word',
                mode = 'i',
            },
            {
                '<M-l>',
                function()
                    require('neocodeium').accept_line()
                end,
                desc = 'Accept AI suggestion line',
                mode = 'i',
            },
        },
    },
}

```


## Solarized Osaka (vim-pack)


```lua


local add = require('vim-pack').add

add {
    {
        src = 'craftzdog/solarized-osaka.nvim',
        module_name = 'solarized-osaka',
        opts = {
          transparent = true
        },

        on_setup = function()
            -- apply colorscheme AFTER setup
            vim.cmd.colorscheme 'solarized-osaka'
        end,
    },
}


```


### Techbase Colortheme (vim-pack)

```lua



local add = require('vim-pack').add

add {
    {
        src = 'mcauley-penney/techbase.nvim',
        module_name = 'techbase',
        opts = {
          transparent = true
        },

        on_setup = function()
            -- apply colorscheme AFTER setup
            vim.cmd.colorscheme 'techbase'
        end,
    },
}



```


