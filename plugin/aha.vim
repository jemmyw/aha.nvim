if exists('g:loaded_aha') | finish | endif " Prevent loading twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset to defaults

hi def link AhaHeader      Number
hi def link AhaSubHeader   Identifier
" Command to run
command! Aha lua require'aha'.aha()

let &cpo = s:save_cpo " restore
unlet s:save_cpo

let g:loaded_aha = 1

