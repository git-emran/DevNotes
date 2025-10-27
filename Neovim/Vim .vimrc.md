This is my vimrc config

```vimrc
set nocompatible

filetype plugin indent on
let mapleader = " "

let g:solarized_termcolors=256



" sets line numbers
" ---------------------
set number
set encoding=utf-8

syntax on
syntax enable


inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction



"-------------------------
" Plugins
"-------------------------

call plug#begin('~/.vim/plugged')

Plug 'jiangmiao/auto-pairs'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'altercation/vim-colors-solarized'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'plasticboy/vim-markdown'
Plug 'kaarmu/typst.vim'
Plug 'chomosuke/typst-preview.nvim', {'tag': 'v1.*'}

call plug#end()

" end plugins--------------------

"-------------------------
" Colorscheme
"-------------------------
colorscheme solarized

set tabstop=4
set shiftwidth=4
set expandtab
set modeline
set background=dark

" self explanatory
set relativenumber

" status-line
set laststatus=2

" searching
set ignorecase
set incsearch
set smartcase
set gdefault
set hlsearch
set showmatch

"-------------------------
" Terminal Colors in Vim
"-------------------------
highlight Normal       ctermbg=NONE guibg=NONE
highlight NonText      ctermbg=NONE guibg=NONE
highlight LineNr       ctermbg=NONE guibg=NONE
highlight SignColumn   ctermbg=NONE guibg=NONE
highlight EndOfBuffer  ctermbg=NONE guibg=NONE


set hlsearch
set t_Co=256

set wildmenu


```
