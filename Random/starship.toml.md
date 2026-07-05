# My Starship Config

Maintaining the config here due to this being kind of patched together. 

```toml

format = """\
[█](bg:#030B16 fg:#EEE8D5)\
[󰀵 ](bg:#EEE8D5 fg:#090c0c)\
[](fg:#EEE8D5 bg:#9EACAD)\
${custom.giturl}\
$time\
[](fg:#9EACAD bg:#B58900)\
$directory\
[ ](fg:#B58900)\
$git_branch\
$git_status\
$fill\
$python\
$lua\
$nodejs\
$typst\
$golang\
$haskell\
$rust\
$ruby\
$username\
$package\
$aws\
$docker_context\
$jobs\
$cmd_duration\
$line_break\
$character\
"""

add_newline = true
palette = "nord"

# [character]
# success_symbol = '[ ➜](bold green) '
# error_symbol = '[ ✗](#E84D44) '


[env_var.STARSHIP_SHELL]
disabled = true


[directory]
# home_symbol = ""
format = "[ $path ]($style)"
style = "bold fg:white bg:#B58900"
truncation_length = 3
truncation_symbol = '…/'
truncate_to_repo = false


[time]
disabled = false
time_format = "%R %A" # Hour:Minute and Day format
style = "bold bg:#1d2230"
format = '[[ 󱑍 $time ](bold bg:#9EACAD fg:#00141A)]($style)'

[custom.giturl]
description = "Display symbol for remote Git server"
command = """
GIT_REMOTE=$(command git ls-remote --get-url 2> /dev/null)
if [[ "$GIT_REMOTE" =~ "github" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "gitlab" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "bitbucket" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "git" ]]; then
    GIT_REMOTE_SYMBOL=" "
else
    GIT_REMOTE_SYMBOL=" "
fi
echo "$GIT_REMOTE_SYMBOL "
"""
when = "git rev-parse --is-inside-work-tree 2> /dev/null"
format = "$output"
require_repo = true
ignore_timeout = true


[git_status]
style = 'fg:green'
format = '([$all_status$ahead_behind]($style) )'
staged = " "
modified = " "
untracked = "❓"
renamed = " "
ahead = "⇡${count} "
behind = "⇣${count} "
diverged = "⇕ "

[jobs]
symbol = ' '
style = '#BF616A'
number_threshold = 1
format = '[$symbol]($style)'


[lua]
symbol = ' '

[aws]
symbol = ' '
style = '#EBCB8B'
format = '[$symbol($profile )(\[$duration\] )]($style)'

[nodejs]
style = 'blue'
symbol = ' '

[python]
style = 'teal'
symbol = ' '
format = '[${symbol}${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'
pyenv_version_name = true
pyenv_prefix = ''

[hg_branch]
format = "[$branch ]($style)"
symbol = " "

[fill]
symbol = ' '

[directory.substitutions]
'Documents' = '󰈙'
'Downloads' = ' '
'Music' = ' '
'Pictures' = ' '

[docker_context]
symbol = ' '
style = 'fg:#06969A'
format = '[$symbol]($style) $path'
detect_files = ['docker-compose.yml', 'docker-compose.yaml', 'Dockerfile']
detect_extensions = ['Dockerfile']

[package]
symbol = '󰏗 '

[palettes.nord]
dark_blue = '#5E81AC'
blue = '#81A1C1'
teal = '#88C0D0'
red = '#BF616A'
orange = '#D08770'
green = '#A3BE8C'
yellow = '#EBCB8B'
purple = '#B48EAD'
gray = '#434C5E'
black = '#2E3440'
white='#D8DEE9'

```