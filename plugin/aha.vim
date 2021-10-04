if exists('g:loaded_aha') | finish | endif " Prevent loading twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset to defaults

hi def link AhaHeader      Number
hi def link AhaSubHeader   Identifier

" Command to run
command! -nargs=* Aha lua require'aha'.aha(<f-args>)
command! ATeams lua require'ahatelescope'.pick_team()
command! ASearch lua require'ahatelescope'.live_search()

augroup aha_autocmds
  au!
  au BufEnter aha://* lua require'aha'.configure_aha_buffer()
augroup END

let &cpo = s:save_cpo " restore
unlet s:save_cpo

let g:loaded_aha = 1

