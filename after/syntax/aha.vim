" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists('main_syntax')
  let main_syntax = 'aha'
endif

runtime! syntax/markdown.vim ftplugin/markdown.vim ftplugin/markdown_*.vim ftplugin/markdown/*.vim
unlet! b:current_syntax

let b:current_syntax = "aha"
if main_syntax ==# 'aha'
  unlet main_syntax
endif
