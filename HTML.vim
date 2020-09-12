" ---- Author & Copyright: ---------------------------------------------- {{{1
"
" Author:      Christian J. Robinson <heptite@gmail.com>
" URL:         http://christianrobinson.name/vim/HTML/
" Last Change: September 11, 2020
" Version:     0.43
" Original Concept: Doug Renze
"
"
" The original Copyright goes to Doug Renze, although nearly all of his
" efforts have been modified in this implementation.  My changes and additions
" are Copyrighted by me, on the dates marked in the ChangeLog.
"
" (Doug Renze has authorized me to place the original "code" under the GPL.)
"
" ----------------------------------------------------------------------------
"
" This program is free software; you can redistribute it and/or modify it
" under the terms of the GNU General Public License as published by the Free
" Software Foundation; either version 2 of the License, or (at your option)
" any later version.
"
" This program is distributed in the hope that it will be useful, but WITHOUT
" ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
" FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
" more details.
"
" ---- Original Author's Notes: ----------------------------------------------
"
" HTML Macros
"        I wrote these HTML macros for my personal use.  They're
"        freely-distributable and freely-modifiable.
"
"        If you do make any major additions or changes, or even just
"        have a suggestion for improvement, feel free to let me
"        know.  I'd appreciate any suggestions.
"
"        Credit must go to Eric Tilton, Carl Steadman and Tyler
"        Jones for their excellent book "Web Weaving" which was
"        my primary source.
"
"        Doug Renze
"
" ---- TODO: ------------------------------------------------------------ {{{1
"
" - Add more HTML 5 tags:
"   https://www.w3schools.com/html/html5_new_elements.asp
" - Find a way to make "gv", after executing a visual mapping, re-select the
"   right text.  (Currently my extra code that wraps around the visual
"   mappings can tweak the selected area significantly.)
"   + This should probably exclude the newly created tag text, so things like
"     visual selection ;ta, then gv and ;tr, then gv and ;td work.
"
" ---- RCS Information: ------------------------------------------------- {{{1
" $Id: HTML.vim,v 1.247 2020/09/12 03:00:13 Heptite Exp $
" ----------------------------------------------------------------------- }}}1

" ---- Initialization: -------------------------------------------------- {{{1

if v:version < 800
  echoerr "HTML.vim no longer supports Vim versions prior to 8."
  sleep 2
  finish
endif

scriptencoding utf8

" Save cpoptions and remove some junk that will throw us off (reset at the end
" of the script):
let s:savecpo = &cpoptions
set cpoptions&vim

let s:doing_internal_html_mappings = 1

if ! exists("b:did_html_mappings_init")
let b:did_html_mappings_init = 1

let s:savecb=&clipboard
silent! setlocal clipboard+=html
setlocal matchpairs+=<:>

" ---- Init Functions and Commands: ------------------------------------- {{{2

command! -nargs=+ HTMLWARN :echohl WarningMsg | echomsg <q-args> | echohl None
command! -nargs=+ HTMLERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
command! -nargs=+ HTMLMESG :echohl Todo | echo <q-args> | echohl None
command! -nargs=+ SetIfUnset call SetIfUnset(<f-args>)

" s:BoolVar()  {{{3
"
" Given a string, test to see if a variable by that string name exists, and if
" so, whether it's set to 1|true|yes / 0|false|no   (Actually, anything not
" listed here also returns as 1.)
"
" Arguments:
"  1 - String:  The name of the variable to test (not its value!)
" Return Value:
"  1/0
"
" Limitations:
"  This /will not/ work on function-local variable names.
function! s:BoolVar(var)
  if a:var =~ '^[bgstvw]:'
    let l:var = a:var
  else
    let l:var = 'g:' . a:var
  endif

  if l:var->s:IsSet()
    execute "let l:varval = " . l:var
    return l:varval->s:Bool()
  else
    return 0
  endif
endfunction

" s:Bool() {{{3
"
" Helper to s:BoolVar() -- Test the string passed to it and return true/false
" based on that string.
"
" Arguments:
"  1 - String:  1|true|yes / 0|false|no
" Return Value:
"  1/0
function! s:Bool(str)
  return a:str !~? '^no$\|^false$\|^0$\|^$'
endfunction

" SetIfUnset()  {{{3
"
" Set a variable if it's not already set.
"
" Arguments:
"  1       - String:  The variable name
"  2 ... N - String:  The default value to use, "-" for the null string
" Return Value:
"  0  - The variable already existed
"  1  - The variable didn't exist and was set
"  -1 - An error occurred
function! SetIfUnset(var, ...)
  if a:var =~ '^[bgstvw]:'
    let l:var = a:var
  else
    let l:var = 'g:' . a:var
  endif

  if a:0 == 0
    exe "HTMLERROR E119: Not enough arguments for function: " . expand('<sfile>')
    return -1
  else
    let l:val = a:000->join(' ')
  endif

  if ! l:var->s:IsSet()
    if l:val == "-"
      execute "let " . l:var . "= \"\""
    else
      execute "let " . l:var . "= l:val"
    endif
    return 1
  endif
  return 0
endfunction

" s:IsSet() {{{3
"
" Given a string, test to see if a variable by that string name exists.
"
" Arguments:
"  1 - String:  The variable name
" Return Value:
"  1/0
function! s:IsSet(str)
  execute "let varisset = exists(\"" . a:str . "\")"
  return varisset
endfunction  "}}}3

" ----------------------------------------------------------------------- }}}2

SetIfUnset g:html_bgcolor           #FFFFFF
SetIfUnset g:html_textcolor         #000000
SetIfUnset g:html_linkcolor         #0000EE
SetIfUnset g:html_alinkcolor        #FF0000
SetIfUnset g:html_vlinkcolor        #990066
SetIfUnset g:html_tag_case          lowercase
SetIfUnset g:html_map_leader        ;
SetIfUnset g:html_map_entity_leader &
"SetIfUnset g:html_default_charset   iso-8859-1
SetIfUnset g:html_default_charset   UTF-8
" No way to know sensible defaults here so just make sure the
" variables are set:
SetIfUnset g:html_authorname  -
SetIfUnset g:html_authoremail -

if g:html_map_entity_leader ==# g:html_map_leader
  HTMLERROR "g:html_map_entity_leader" and "g:html_map_leader" have the same value!
  HTMLERROR Resetting "g:html_map_entity_leader" to "&".
  sleep 2
  let g:html_map_entity_leader = '&'
endif

if exists('b:html_tag_case')
  let b:html_tag_case_save = b:html_tag_case
endif

" Detect whether to force uppper or lower case:  {{{2
if &filetype ==? "xhtml"
      \ || s:BoolVar('g:do_xhtml_mappings')
      \ || s:BoolVar('b:do_xhtml_mappings')
  let b:do_xhtml_mappings = 1
else
  let b:do_xhtml_mappings = 0

  if s:BoolVar('g:html_tag_case_autodetect')
        \ && (line('$') != 1 || getline(1) != '')

    let s:found_upper = search('\C<\(\s*/\)\?\s*\u\+\_[^<>]*>', 'wn')
    let s:found_lower = search('\C<\(\s*/\)\?\s*\l\+\_[^<>]*>', 'wn')

    if s:found_upper && ! s:found_lower
      let b:html_tag_case = 'uppercase'
    elseif ! s:found_upper && s:found_lower
      let b:html_tag_case = 'lowercase'
    endif

    unlet s:found_upper s:found_lower
  endif
endif

if s:BoolVar('b:do_xhtml_mappings')
  let b:html_tag_case = 'lowercase'
endif
" }}}2

call SetIfUnset('b:html_tag_case', g:html_tag_case)

let s:thisfile = expand("<sfile>:p")
" ----------------------------------------------------------------------------


" ---- Functions: ------------------------------------------------------- {{{1

if ! exists("g:did_html_functions")
let g:did_html_functions = 1

" HTMLencodeString()  {{{2
"
" Encode the characters in a string to/from their HTML representations.
"
" Arguments:
"  1 - String:  The string to encode/decode.
"  2 - String:  Optional, whether to decode rather than encode the string:
"               - d/decode: Decode the %XX, &#...;, and &#x...; elements of
"                           the provided string
"               - %:        Encode as a %XX string
"               - x:        Encode as a &#x...; string
"               - omitted:  Encode as a &#...; string
"               - other:    No change to the string
" Return Value:
"  String:  The encoded string.
function! HTMLencodeString(string, ...)
  let l:out = a:string

  if a:0 == 0
    let l:out = l:out->substitute('.', '\=printf("&#%d;",  submatch(0)->char2nr())', 'g')
  elseif a:1 == 'x'
    let l:out = l:out->substitute('.', '\=printf("&#x%x;", submatch(0)->char2nr())', 'g')
  elseif a:1 == '%'
    let l:out = l:out->substitute('[\x00-\x99]', '\=printf("%%%02X", submatch(0)->char2nr())', 'g')
  elseif a:1 =~? '^d\(ecode\)\=$'
    let l:out = l:out->substitute('\(&#x\x\+;\|&#\d\+;\|%\x\x\)', '\=submatch(1)->HTMLdecodeSymbol()', 'g')
  endif

  return l:out
endfunction

" HTMLdecodeSymbol()  {{{2
"
" Decode the HTML symbol string to its literal character counterpart
"
" Arguments:
"  1 - String:  The string to decode.
" Return Value:
"  Character:  The decoded character.
function! HTMLdecodeSymbol(symbol)
  if a:symbol =~ '&#\(x\x\+\);'
    let l:char = nr2char('0' . strpart(a:symbol, 2, strlen(a:symbol) - 3))
  elseif a:symbol =~ '&#\(\d\+\);'
    let l:char = nr2char(strpart(a:symbol, 2, strlen(a:symbol) - 3))
  elseif a:symbol =~ '%\(\x\x\)'
    let l:char = nr2char('0x' . strpart(a:symbol, 1, strlen(a:symbol) - 1))
  else
    let l:char = a:symbol
  endif

  return l:char
endfunction

" HTMLmap()  {{{2
"
" Define the HTML mappings with the appropriate case, plus some extra stuff.
"
" Arguments:
"  1 - String:  Which map command to run.
"  2 - String:  LHS of the map.
"  3 - String:  RHS of the map.
"  4 - Integer: Optional, applies only to visual maps:
"                -1: Don't add any extra special code to the mapping.
"                 0: Mapping enters insert mode.
"               Applies only when filetype indenting is on:
"                 1: re-selects the region, moves down a line, and re-indents.
"                 2: re-selects the region and re-indents.
"                 (Don't use these two arguments for maps that enter insert
"                 mode!)
let s:modes = {
      \ 'n': 'normal',
      \ 'v': 'visual',
      \ 'o': 'operator-pending',
      \ 'i': 'insert',
      \ 'c': 'command-line',
      \ 'l': 'langmap',
    \}
function! HTMLmap(cmd, map, arg, ...)
  let l:mode = a:cmd->strpart(0, 1)
  let l:map = a:map->substitute('^<lead>\c', escape(g:html_map_leader, '&~\'), '')
  let l:map = l:map->substitute('^<elead>\c', escape(g:html_map_entity_leader, '&~\'), '')

  if exists('s:modes[mode]') && l:map->s:MapCheck(l:mode) >= 2
    return
  endif

  let l:arg = a:arg->s:ConvertCase()
  if ! s:BoolVar('b:do_xhtml_mappings')
    let l:arg = l:arg->substitute(' \?/>', '>', 'g')
  endif

  if l:mode == 'v'
    " If 'selection' is "exclusive" all the visual mode mappings need to
    " behave slightly differently:
    let l:arg = substitute(arg, "`>a\\C", "`>i<C-R>=<SID>VI()<CR>", 'g')

    if a:0 >= 1 && a:1 < 0
      execute a:cmd . " <buffer> <silent> " . l:map . " " . l:arg
    elseif a:0 >= 1 && a:1 >= 1
      execute a:cmd . " <buffer> <silent> " . l:map . " <C-C>:call <SID>TO(0)<CR>gv" . l:arg
        \ . ":call <SID>TO(1)<CR>m':call <SID>ReIndent(line(\"'<\"), line(\"'>\"), " . a:1 . ")<CR>``"
    elseif a:0 >= 1
      execute a:cmd . " <buffer> <silent> " . l:map . " <C-C>:call <SID>TO(0)<CR>gv" . l:arg
        \ . "<C-O>:call <SID>TO(1)<CR>"
    else
      execute a:cmd . " <buffer> <silent> " . l:map . " <C-C>:call <SID>TO(0)<CR>gv" . l:arg
        \ . ":call <SID>TO(1)<CR>"
    endif
  else
    execute a:cmd . " <buffer> <silent> " . l:map . " " . l:arg
  endif

  if exists('s:modes[mode]')
    let b:HTMLclearMappings = b:HTMLclearMappings . ':' . l:mode . "unmap <buffer> " . l:map . "\<CR>"
  else
    let b:HTMLclearMappings = b:HTMLclearMappings . ":unmap <buffer> " . l:map . "\<CR>"
  endif

  call s:ExtraMappingsAdd(':call HTMLmap("' . a:cmd . '", "' . a:map->escape('"\')
        \ . '", "' . a:arg->escape('"\') . (a:0 >= 1 ? ('", ' . a:1) : '"' ) . ')')
endfunction

" HTMLmapo()  {{{2
"
" Define a map that takes an operator to its corresponding visual mode
" mapping.
"
" Arguments:
"  1 - String:  The mapping.
"  2 - Boolean: Whether to enter insert mode after the mapping has executed.
"               (A value greater than 1 tells the mapping not to move right one
"               character.)
function! HTMLmapo(map, insert)
  let map = substitute(a:map, "^<lead>", g:html_map_leader, '')

  if s:MapCheck(map, 'o') >= 2
    return
  endif

  execute 'nnoremap <buffer> <silent> ' . map
    \ . " :let b:htmltagaction='" . map . "'<CR>"
    \ . ":let b:htmltaginsert=" . a:insert . "<CR>"
    \ . ':set operatorfunc=<SID>WR<CR>g@'

  let b:HTMLclearMappings = b:HTMLclearMappings . ":nunmap <buffer> " . map . "\<CR>"
  call s:ExtraMappingsAdd(':call HTMLmapo("' . a:map->escape('"\') . '", ' . a:insert . ')')
endfunction

" s:MapCheck()  {{{2
"
" Check to see if a mapping for a mode already exists.  If there is, and
" overriding hasn't been suppressed, print an error.
"
" Arguments:
"  1 - String:    The map sequence (LHS).
"  2 - Character: The mode for the mapping.
" Return Value:
"  0 - No mapping was found.
"  1 - A mapping was found, but overriding has /not/ been suppressed.
"  2 - A mapping was found and overriding has been suppressed.
"  3 - The mapping to be defined was suppressed by g:no_html_maps.
"
" (Note that suppression only works for the internal mappings.)
function! s:MapCheck(map, mode)
  if exists('s:doing_internal_html_mappings') &&
        \ ( (exists('g:no_html_maps') && a:map =~# g:no_html_maps) ||
        \   (exists('b:no_html_maps') && a:map =~# b:no_html_maps) )
    return 3
  elseif exists('s:modes[a:mode]') && maparg(a:map, a:mode) != ''
    if s:BoolVar('g:no_html_map_override') && exists('s:doing_internal_html_mappings')
      return 2
    else
      exe "HTMLWARN WARNING: A mapping to \"" . a:map . "\" for " . s:modes[a:mode] . " mode has been overridden for this buffer."

      return 1
    endif
  endif

  return 0
endfunction

" s:SI()  {{{2
" 
" 'Escape' special characters with a control-v so Vim doesn't handle them as
" special keys during insertion.  For use in <C-R>=... type calls in mappings.
"
" Arguments:
"  1 - String: The string to escape.
" Return Value:
"  String: The 'escaped' string.
"
" Limitations:
"  Null strings have to be left unescaped, due to a limitation in Vim itself.
"  (VimL represents newline characters as nulls...ouch.)
function! s:SI(str)
  return a:str->substitute('[^\x00\x20-\x7E]', '\="\x16" . submatch(0)', 'g')
endfunction

" s:WR()  {{{2
" Function set in 'operatorfunc' for mappings that take an operator:
function! s:WR(type)
  let l:sel_save = &selection
  let &selection = "inclusive"

  if a:type == 'line'
    execute "normal `[V`]" . b:htmltagaction
  elseif a:type == 'block'
    execute "normal `[\<C-V>`]" . b:htmltagaction
  else
    execute "normal `[v`]" . b:htmltagaction
  endif

  let &selection = l:sel_save

  if b:htmltaginsert
    if b:htmltaginsert < 2
      execute "normal \<Right>"
    endif
    startinsert
  endif

  " Leave these set so .-repeating of operator mappings works:
  "unlet b:htmltagaction b:htmltaginsert
endfunction

" s:ExtraMappingsAdd()  {{{2
"
" Add to the b:HTMLextraMappings variable if necessary.
"
" Arguments:
"  1 - String: The command necessary to re-define the mapping.
function! s:ExtraMappingsAdd(arg)
  if ! exists('s:doing_internal_html_mappings') && ! exists('s:doing_extra_html_mappings')
    if ! exists('b:HTMLextraMappings')
      let b:HTMLextraMappings = ''
    endif
    let b:HTMLextraMappings = b:HTMLextraMappings . a:arg . ' |'
  endif
endfunction

" s:TO()  {{{2
"
" Used to make sure the 'showmatch', 'indentexpr', and 'formatoptions' options
" are off temporarily to prevent the visual mappings from causing a
" (visual)bell or inserting improperly.
"
" Arguments:
"  1 - Integer: 0 - Turn options off.
"               1 - Turn options back on, if they were on before.
function! s:TO(s)
  if a:s == 0
    let s:savesm=&l:sm | let &l:sm=0
    let s:saveinde=&l:inde | let &l:inde=''
    let s:savefo=&l:fo | let &l:fo=''

    " A trick to make leading indent on the first line of visual-line
    " selections is handled properly (turn it into a character-wise
    " selection and exclude the leading indent):
    if visualmode() ==# 'V'
      let s:visualmode_save = visualmode()
      exe "normal `<^v`>\<C-C>"
    endif
  else
    let &l:sm=s:savesm | unlet s:savesm
    let &l:inde=s:saveinde | unlet s:saveinde
    let &l:fo=s:savefo | unlet s:savefo

    " Restore the last visual mode if it was changed:
    if exists('s:visualmode_save')
      exe "normal gv" . s:visualmode_save . "\<C-C>"
      unlet s:visualmode_save
    endif
  endif
endfunction

" s:TC()  {{{2
"
" Used to make sure the 'comments' option is off temporarily to prevent
" certain mappings from inserting unwanted comment leaders.
"
" Arguments:
"  1 - Integer: 0 - Turn option off.
"               1 - Turn option back on, if they were on before.
function! s:TC(s)
  if a:s == 0
    let s:savecom=&l:com | let &l:com=''
  else
    let &l:com=s:savecom | unlet s:savecom
  endif
endfunction

" s:ToggleClipboard()  {{{2
"
" Used to turn off/on the inclusion of "html" in the 'clipboard' option when
" switching buffers.
"
" Arguments:
"  1 - Integer: 0 - Remove 'html' if it was removed before.
"               1 - Add 'html'.
"               2 - Auto detect which to do.
function! s:ToggleClipboard(i)
  if a:i == 2
    if exists("b:did_html_mappings")
      let l:i=1
    else
      let l:i=0
    endif
  else
    let l:i=a:i
  endif
  if l:i == 0
    let &clipboard=s:savecb
  else
    if &clipboard !~? 'html'
      let s:savecb=&clipboard
    endif
    silent! set clipboard+=html
  endif
endfunction

" s:VI() {{{2
"
" Used by HTMLmap() to enter insert mode in Visual mappings in the right
" place, depending on what 'selection' is set to.
"
" Arguments:
"   None
" Return Value:
"   The proper movement command based on the value of 'selection'.
function! s:VI()
  if &selection == 'inclusive'
    return "\<right>"
  else
    return "\<C-O>`>"
  endif
endfunction

" s:ConvertCase()  {{{2
"
" Convert special regions in a string to the appropriate case determined by
" b:html_tag_case.
"
" Arguments:
"  1 - String: The string with the regions to convert surrounded by [{...}].
" Return Value:
"  The converted string.
function! s:ConvertCase(str)
  if (! exists('b:html_tag_case')) || b:html_tag_case =~? 'u\(pper\(case\)\?\)\?' || b:html_tag_case == ''
    let l:str = a:str->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g')
  elseif b:html_tag_case =~? 'l\(ower\(case\)\?\)\?'
    let l:str = a:str->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g')
  else
    exe "HTMLWARN WARNING: b:html_tag_case = '" . b:html_tag_case . "' invalid, overriding to 'upppercase'."
    let b:html_tag_case = 'uppercase'
    let l:str = a:str->s:ConvertCase()
  endif
  return l:str
endfunction

" s:ReIndent()  {{{2
"
" Re-indent a region.  (Usually called by HTMLmap.)
"  Nothing happens if filetype indenting isn't enabled or 'indentexpr' is
"  unset.
"
" Arguments:
"  1 - Integer: Start of region.
"  2 - Integer: End of region.
"  3 - Integer: 1: Add an extra line below the region to re-indent.
"               *: Don't add an extra line.
function! s:ReIndent(first, last, extraline)
  " To find out if filetype indenting is enabled:
  redir =>l:filetype_output | silent! filetype | redir END

  if l:filetype_output =~ "indent:OFF" && &indentexpr == ''
    return
  endif

  " Make sure the range is in the proper order:
  if a:last >= a:first
    let l:firstline = a:first
    let l:lastline = a:last
  else
    let l:lastline = a:first
    let l:firstline = a:last
  endif

  " Make sure the full region to be re-indendted is included:
  if a:extraline == 1
    if l:firstline == lastline
      let l:lastline = lastline + 2
    else
      let l:lastline = lastline + 1
    endif
  endif

  execute l:firstline . ',' . l:lastline . 'norm =='
endfunction

" s:ByteOffset()  {{{2
"
" Return the byte number of the current position.
"
" Arguments:
"  None
" Return Value:
"  The byte offset
function! s:ByteOffset()
  return line('.')->line2byte() + col('.') - 1
endfunction

" HTMLnextInsertPoint()  {{{2
"
" Position the cursor at the next point in the file that needs data.
"
" Arguments:
"  1 - Character: Optional, the mode the function is being called from. 'n'
"                 for normal, 'i' for insert.  If 'i' is used the function
"                 enables an extra feature where if the cursor is on the start
"                 of a closing tag it places the cursor after the tag.
"                 Default is 'n'.
" Return Value:
"  None.
" Known problems:
"  Due to the necessity of running the search twice (why doesn't Vim support
"  cursor offset positioning in search()?) this function
"    a) won't ever position the cursor on an "empty" tag that starts on the
"       first character of the first line of the buffer
"    b) won't let the cursor "escape" from an "empty" tag that it can match on
"       the first line of the buffer when the cursor is on the first line and
"       tab is successively pressed
function! HTMLnextInsertPoint(...)
  let l:saveerrmsg  = v:errmsg | let v:errmsg = ''
  let l:saveruler   = &ruler   | let &ruler   = 0
  let l:saveshowcmd = &showcmd | let &showcmd = 0
  let l:byteoffset  = s:ByteOffset()

  " Tab in insert mode on the beginning of a closing tag jumps us to
  " after the tag:
  if a:0 >= 1 && a:1 == 'i'
    if line('.')->getline()->strpart(col('.') - 1, 2) == '</'
      normal %
      let l:done = 1
    elseif line('.')->getline()->strpart(col('.') - 1) =~ '^ *-->'
      normal f>
      let l:done = 1
    else
      let l:done = 0
    endif

    if l:done == 1
      if col('.') == col('$') - 1
        startinsert!
      else
        normal l
      endif

      let v:errmsg = l:saveerrmsg
      let &ruler   = l:saveruler
      let &showcmd = l:saveshowcmd

      return
    endif
  endif


  normal 0

  " Running the search twice is inefficient, but it squelches error
  " messages and the second search puts the cursor where it's needed...

  if search('<\([^ <>]\+\)\_[^<>]*>\_s*<\/\1>\|<\_[^<>]*""\_[^<>]*>\|<!--\_s*-->', 'w') == 0
    if l:byteoffset == -1
      go 1
    else
      execute ':go ' . l:byteoffset
      if a:0 >= 1 && a:1 == 'i' && col('.') == col('$') - 1
        startinsert!
      endif
    endif
  else
    normal 0
    silent! execute ':go ' . (s:ByteOffset() - 1)
    execute 'silent! keeppatterns normal! /<\([^ <>]\+\)\_[^<>]*>\_s*<\/\1>\|<\_[^<>]*""\_[^<>]*>\|<!--\_s*-->/;/>\_s*<\|""\|<!--\_s*-->/e' . "\<CR>"

    " Handle cursor positioning for comments and/or open+close tags spanning
    " multiple lines:
    if getline('.') =~ '<!-- \+-->'
      execute "normal F\<space>"
    elseif getline('.') =~ '^ *-->' && getline(line('.')-1) =~ '<!-- *$'
      normal 0
      normal t-
    elseif getline('.') =~ '^ *-->' && getline(line('.')-1) =~ '^ *$'
      normal k$
    elseif getline('.') =~ '^ *<\/[^<>]\+>' && getline(line('.')-1) =~ '^ *$'
      normal k$
    endif

  endif

  let v:errmsg = l:saveerrmsg
  let &ruler   = l:saveruler
  let &showcmd = l:saveshowcmd
endfunction

" s:tag()  {{{2
"
" Causes certain tags (such as bold, italic, underline) to be closed then
" opened rather than opened then closed where appropriate, if syntax
" highlighting is on.
"
" Arguments:
"  1 - String: The tag name.
"  2 - Character: The mode:
"                  'i' - Insert mode
"                  'v' - Visual mode
" Return Value:
"  The string to be executed to insert the tag.

" s:smarttags[tag][mode][open/close] = keystrokes  {{{
"  tag        - The literal tag, without the <>'s
"  mode       - i = insert, v = visual
"               (no "o", because o-mappings invoke visual mode)
"  open/close - c = When inside an equivalent tag, close then open it
"               o = When not inside an equivalent tag
"  keystrokes - The mapping keystrokes to execute
let s:smarttags = {}
let s:smarttags['i'] = {
      \ 'i': {
        \ 'o': "<[{I></I}]>\<C-O>F<",
        \ 'c': "<[{/I><I}]>\<C-O>F<",
      \ },
      \ 'v': {
        \ 'o': "`>a</[{I}]>\<C-O>`<<[{I}]>",
        \ 'c': "`>a<[{I}]>\<C-O>`<</[{I}]>",
      \ }
    \ }

let s:smarttags['em'] = {
      \ 'i': {
        \ 'o': "<[{EM></EM}]>\<C-O>F<",
        \ 'c': "<[{/EM><EM}]>\<C-O>F<",
      \ },
      \ 'v': {
        \ 'o': "`>a</[{EM}]>\<C-O>`<<[{EM}]>",
        \ 'c': "`>a<[{EM}]>\<C-O>`<</[{EM}]>",
      \ }
    \ }

let s:smarttags['b'] = {
      \ 'i': {
        \ 'o': "<[{B></B}]>\<C-O>F<",
        \ 'c': "<[{/B><B}]>\<C-O>F<",
      \},
      \ 'v': {
        \ 'o': "`>a</[{B}]>\<C-O>`<<[{B}]>",
        \ 'c': "`>a<[{B}]>\<C-O>`<</[{B}]>",
      \ }
    \ }

let s:smarttags['strong']  = {
      \ 'i': {
        \ 'o': "<[{STRONG></STRONG}]>\<C-O>F<",
        \ 'c': "<[{/STRONG><STRONG}]>\<C-O>F<",
      \},
      \ 'v': {
        \ 'o': "`>a</[{STRONG}]>\<C-O>`<<[{STRONG}]>",
        \ 'c': "`>a<[{STRONG}]>\<C-O>`<</[{STRONG}]>",
      \ }
    \ }

let s:smarttags['u'] = {
      \ 'i': {
        \ 'o': "<[{U></U}]>\<C-O>F<",
        \ 'c': "<[{/U><U}]>\<C-O>F<",
      \},
      \ 'v': {
        \ 'o': "`>a</[{U}]>\<C-O>`<<[{U}]>",
        \ 'c': "`>a<[{U}]>\<C-O>`<</[{U}]>",
      \ }
    \ }

let s:smarttags['comment'] = {
      \ 'i': {
        \ 'o': "<!--  -->\<C-O>F ",
        \ 'c': " --><!-- \<C-O>F<",
      \},
      \ 'v': {
        \ 'o': "`>a -->\<C-O>`<<!-- ",
        \ 'c': "`>a<!-- \<C-O>`< -->",
      \ }
    \ }
" }}}

function! s:tag(tag, mode)
  let l:attr=synID(line('.'), col('.') - 1, 1)->synIDattr("name")
  echomsg l:attr
  if ( a:tag == 'i' && l:attr =~? 'italic' )
        \ || ( a:tag == 'em' && l:attr =~? 'italic' )
        \ || ( a:tag == 'b' && l:attr =~? 'bold' )
        \ || ( a:tag == 'strong' && l:attr =~? 'bold' )
        \ || ( a:tag == 'u' && l:attr =~? 'underline' )
        \ || ( a:tag == 'comment' && l:attr =~? 'comment' )
    let l:ret=s:smarttags[a:tag][a:mode]['c']->s:ConvertCase()
  else
    let l:ret=s:smarttags[a:tag][a:mode]['o']->s:ConvertCase()
  endif
  if a:mode == 'v'
    " If 'selection' is "exclusive" all the visual mode mappings need to
    " behave slightly differently:
    let l:ret = l:ret->substitute("`>a\\C", "`>i" . s:VI(), 'g')
  endif
  return l:ret
endfunction

" s:DetectCharset()  {{{2
"
" Detects the HTTP-EQUIV Content-Type charset based on Vim's current
" encoding/fileencoding.
"
" Arguments:
"  None
" Return Value:
"  The value for the Content-Type charset based on 'fileencoding' or
"  'encoding'.

" TODO: This table needs to be expanded:
let s:charsets = {}
let s:charsets['latin1']    = 'iso-8859-1'
let s:charsets['utf_8']     = 'UTF-8'
let s:charsets['utf_16']    = 'UTF-16'
let s:charsets['shift_jis'] = 'Shift_JIS'
let s:charsets['euc_jp']    = 'EUC-JP'
let s:charsets['cp950']     = 'Big5'
let s:charsets['big5']      = 'Big5'

function! s:DetectCharset()

  if exists("g:html_charset")
    return g:html_charset
  endif

  if &fileencoding != ''
    let l:enc=tolower(&fileencoding)
  else
    let l:enc=tolower(&encoding)
  endif

  " The iso-8859-* encodings are valid for the Content-Type charset header:
  if l:enc =~? '^iso-8859-'
    return l:enc
  endif

  let enc=l:enc->substitute('\W', '_', 'g')

  if s:charsets[l:enc] != ''
    return s:charsets[l:enc]
  endif

  return g:html_default_charset
endfunction

" HTMLgenerateTable()  {{{2
"
" Interactively creates a table.
"
" Arguments:
"  None
" Return Value:
"  None
function! HTMLgenerateTable()
  let l:byteoffset = s:ByteOffset()

  let l:rows    = inputdialog("Number of rows: ") + 0
  let l:columns = inputdialog("Number of columns: ") + 0

  if ! (l:rows > 0 && l:columns > 0)
    HTMLERROR Rows and columns must be integers.
    return
  endif

  let l:border = inputdialog("Border width of table [none]: ") + 0

  if l:border
    execute s:ConvertCase("normal o<[{TABLE BORDER}]=" . l:border . ">\<ESC>")
  else
    execute s:ConvertCase("normal o<[{TABLE}]>\<ESC>")
  endif

  for l:r in range(l:rows)
    execute s:ConvertCase("normal o<[{TR}]>\<ESC>")

    for l:c in range(l:columns)
      execute s:ConvertCase("normal o<[{TD}]></[{TD}]>\<ESC>")
    endfor

    execute s:ConvertCase("normal o</[{TR}]>\<ESC>")
  endfor

  execute s:ConvertCase("normal o</[{TABLE}]>\<ESC>")

  execute ":go " . (l:byteoffset <= 0 ? 1 : l:byteoffset)

  normal jjj$F<

endfunction

" s:MappingsControl()  {{{2
"
" Disable/enable all the mappings defined by HTMLmap()/HTMLmapo().
"
" Arguments:
"  1 - String:  Whether to disable or enable the mappings:
"                d/disable: Clear the mappings
"                e/enable:  Redefine the mappings
"                r/reload:  Completely reload the script
"                h/html:    Reload the mapppings in HTML mode
"                x/xhtml:   Reload the mapppings in XHTML mode
" Return Value:
"  None
silent! function! s:MappingsControl(dowhat)
  if ! exists('b:did_html_mappings_init')
    HTMLERROR The HTML mappings were not sourced for this buffer.
    return
  endif

  if b:did_html_mappings_init < 0
    unlet b:did_html_mappings_init
  endif

  if a:dowhat =~? '^d\(isable\)\=\|off$'
    if exists('b:did_html_mappings')
      silent execute b:HTMLclearMappings
      unlet b:did_html_mappings
      if exists("g:did_html_menus")
        call s:MenuControl('disable')
      endif
    elseif ! exists('s:quiet_errors')
      HTMLERROR "The HTML mappings are already disabled."
    endif
  elseif a:dowhat =~? '^e\(nable\)\=\|on$'
    if exists('b:did_html_mappings')
      HTMLERROR "The HTML mappings are already enabled."
    else
      execute "source " . s:thisfile
      if exists('b:HTMLextraMappings')
        let s:doing_extra_html_mappings = 1
        silent execute b:HTMLextraMappings
        unlet s:doing_extra_html_mappings
      endif
    endif
  elseif a:dowhat =~? '^r\(eload\|einit\)\=$'
    let s:quiet_errors = 1
    HTMLmappings off
    let b:did_html_mappings_init=-1
    silent! unlet g:did_html_menus g:did_html_toolbar g:did_html_functions
    silent! unmenu HTML
    silent! unmenu! HTML
    HTMLmappings on
    unlet s:quiet_errors
  elseif a:dowhat =~? '^h\(tml\)\=$'
    if exists('b:html_tag_case_save')
      let b:html_tag_case = b:html_tag_case_save
    endif
    let b:do_xhtml_mappings=0
    HTMLmappings off
    let b:did_html_mappings_init=-1
    HTMLmappings on
  elseif a:dowhat =~? '^x\(html\)\=$'
    let b:do_xhtml_mappings=1
    HTMLmappings off
    let b:did_html_mappings_init=-1
    HTMLmappings on
  else
    exe "HTMLERROR Invalid argument: " . a:dowhat
  endif
endfunction

command! -nargs=1 HTMLmappings call <SID>MappingsControl(<f-args>)
command! -nargs=1 HTML call <SID>MappingsControl(<f-args>)


" s:MenuControl()  {{{2
"
" Disable/enable the HTML menu and toolbar.
"
" Arguments:
"  1 - String:  Optional, Whether to disable or enable the menus:
"                empty: Detect which to do
"                "disable": Disable the menu and toolbar
"                "enable": Enable the menu and toolbar
" Return Value:
"  None
function! s:MenuControl(...)
  if a:0 > 0
    if a:1 !~? '^\(dis\|en\)able$'
      echoerr "Invalid argument: " . a:1
      return
    else
      let l:bool = a:1
    endif
  else
    let l:bool = ''
  endif

  if l:bool == 'disable' || ! exists("b:did_html_mappings")
    amenu disable HTML
    amenu disable HTML.*
    if exists('g:did_html_toolbar')
      amenu disable ToolBar.*
      amenu enable ToolBar.Open
      amenu enable ToolBar.Save
      amenu enable ToolBar.SaveAll
      amenu enable ToolBar.Cut
      amenu enable ToolBar.Copy
      amenu enable ToolBar.Paste
      amenu enable ToolBar.Find
      amenu enable ToolBar.Replace
    endif
    if exists('b:did_html_mappings_init') && ! exists('b:did_html_mappings')
      amenu enable HTML
      amenu disable HTML.Control.*
      amenu enable HTML.Control
      amenu enable HTML.Control.Enable\ Mappings
      amenu enable HTML.Control.Reload\ Mappings
    endif
  elseif l:bool == 'enable' || exists("b:did_html_mappings_init")
    amenu enable HTML
    if exists("b:did_html_mappings")
      amenu enable HTML.*
      amenu enable HTML.Control.*
      amenu disable HTML.Control.Enable\ Mappings

      if s:BoolVar('b:do_xhtml_mappings')
        amenu disable HTML.Control.Switch\ to\ XHTML\ mode
        amenu enable  HTML.Control.Switch\ to\ HTML\ mode
      else
        amenu enable  HTML.Control.Switch\ to\ XHTML\ mode
        amenu disable HTML.Control.Switch\ to\ HTML\ mode
      endif

      if exists('g:did_html_toolbar')
        amenu enable ToolBar.*
      endif
    else
      amenu enable HTML.Control.Enable\ Mappings
    endif
  endif
endfunction

" s:ShowColors()  {{{2
"
" Create a window to display the HTML colors, highlighted
"
" Arguments:
"  None
" Return Value:
"  None
function! s:ShowColors(...)
  if ! exists('g:did_html_menus')
    HTMLERROR The HTML menu was not created.
    return
  endif

  if ! exists('b:did_html_mappings_init')
    HTMLERROR Not in an html buffer.
    return
  endif

  let l:curbuf = bufnr('%')
  let l:maxw = 0

  silent new [HTML\ Colors\ Display]
  setlocal buftype=nofile noswapfile bufhidden=wipe

  for l:key in keys(s:color_list)
    if strlen(l:key) > l:maxw
      let l:maxw = strlen(l:key)
    endif
  endfor

  let l:col = 0
  let l:line = ''
  for l:key in keys(s:color_list)->sort()
    let l:col += 1

    let l:line .= repeat(' ', l:maxw - strlen(l:key)) . l:key . ' = ' . s:color_list[l:key]

    if l:col >= 2
      call append('$', line)
      let l:line = ''
      let l:col = 0
    else
      let l:line .= '      '
    endif

    let l:key2 = l:key->substitute(' ', '', 'g')

    execute 'syntax match hc_' . l:key2 . ' /' . s:color_list[l:key] . '/'
    execute 'highlight hc_' . l:key2 . ' guibg=' . s:color_list[l:key]
  endfor

  if l:line != ''
    call append('$', l:line)
  endif

  call append(0, [
        \'+++ q = quit  <space> = page down   b = page up           +++',
        \'+++ <tab> = Go to next color                              +++',
        \'+++ <enter> or <double click> = Select color under cursor +++',
      \])
  exe 0
  exe '1,3center ' . ((maxw + 13) * 2)

  setlocal nomodifiable

  syntax match hc_colorsKeys =^\%<4l\s*+++ .\+ +++$=
  highlight link hc_colorsKeys Comment

  wincmd _

  noremap <silent> <buffer> q <C-w>c
  inoremap <silent> <buffer> q <C-o><C-w>c
  noremap <silent> <buffer> <space> <C-f>
  inoremap <silent> <buffer> <space> <C-o><C-f>
  noremap <silent> <buffer> b <C-b>
  inoremap <silent> <buffer> b <C-o><C-b>
  noremap <silent> <buffer> <tab> :call search('[A-Za-z][A-Za-z ]\+ = #\x\{6\}')<CR>
  inoremap <silent> <buffer> <tab> <C-o>:call search('[A-Za-z][A-Za-z ]\+ = #\x\{6\}')<CR>

  if a:0 >= 1
    let l:ext = ', "' . escape(a:1, '"') . '"'
  else
    let l:ext = ''
  endif

  execute 'noremap <silent> <buffer> <cr> :call <SID>ColorSelect(' . l:curbuf . l:ext . ')<CR>'
  execute 'inoremap <silent> <buffer> <cr> <C-o>:call <SID>ColorSelect(' . l:curbuf . l:ext . ')<CR>'
  execute 'noremap <silent> <buffer> <2-leftmouse> :call <SID>ColorSelect(' . l:curbuf . l:ext . ')<CR>'
  execute 'inoremap <silent> <buffer> <2-leftmouse> <C-o>:call <SID>ColorSelect(' . l:curbuf . l:ext . ')<CR>'

  stopinsert
endfunction

function! s:ColorSelect(bufnr, ...)
  let l:line  = getline('.')
  let l:col   = col('.')
  let l:color = substitute(l:line, '.\{-\}\%<' . (l:col + 1) . 'c\([A-Za-z][A-Za-z ]\+ = #\x\{6\}\)\%>' . l:col . 'c.*', '\1', '') 

  if l:color == l:line
    return ''
  endif

  let l:colora = split(l:color, ' = ')

  close
  if bufwinnr(a:bufnr) == -1
    exe 'buffer ' . a:bufnr
  else
    exe bufwinnr(a:bufnr) . 'wincmd w'
  endif

  if a:0 >= 1
    let l:which = a:1
  else
    let l:which = 'i'
  endif

  exe 'normal ' . l:which . l:colora[1]
  stopinsert
  echo l:color
endfunction

" s:ShellEscape()  {{{2
"
" Quote a string and escape characters that the shell may treat as special.
"
" Arguments:
"  String
" Return Value:
"  Escaped string
"
" Limitations:
"  This function doesn't know how to escape for non-Unix OSes if the
"  shellescape() internal Vim function is nonexistant.
function! s:ShellEscape(str)
	if exists('*shellescape')
		return a:str->shellescape()
	else
    if has('unix')
      return "'" . a:str->substitute("'", "'\\\\''", 'g') . "'"
    else
      return a:str
    endif
	endif
endfunction

" ---- Template Creation Stuff: {{{2

" HTMLtemplate()  {{{3
"
" Determine whether to insert the HTML template.
"
" Arguments:
"  None
" Return Value:
"  0 - The cursor is not on an insert point.
"  1 - The cursor is on an insert point.
function! HTMLtemplate()
  let ret = 0
  let save_ruler = &ruler
  let save_showcmd = &showcmd
  set noruler noshowcmd
  if line('$') == 1 && getline(1) == ''
    let ret = s:HTMLtemplate2()
  else
    let YesNoOverwrite = confirm("Non-empty file.\nInsert template anyway?", "&Yes\n&No\n&Overwrite", 2, "W")
    if YesNoOverwrite == 1
      let ret = s:HTMLtemplate2()
    elseif YesNoOverwrite == 3
      execute "1,$delete"
      let ret = s:HTMLtemplate2()
    endif
  endif
  let &ruler = save_ruler
  let &showcmd = save_showcmd
  return ret
endfunction  " }}}3

" s:HTMLtemplate2()  {{{3
"
" Actually insert the HTML template.
"
" Arguments:
"  None
" Return Value:
"  0 - The cursor is not on an insert point.
"  1 - The cursor is on an insert point.
function! s:HTMLtemplate2()

  if g:html_authoremail != ''
    let g:html_authoremail_encoded = HTMLencodeString(g:html_authoremail)
  else
    let g:html_authoremail_encoded = ''
  endif

  let template = ''

  if exists('b:html_template') && b:html_template != ''
    let template = b:html_template
  elseif exists('g:html_template') && g:html_template != ''
    let template = g:html_template
  endif

  if template != ''
    if expand(template)->filereadable()
      silent execute "0read " . template
    else
      exe HTMLERROR "Unable to insert template file: " . template
      HTMLERROR "Either it doesn't exist or it isn't readable."
      return 0
    endif
  else
    0put =b:internal_html_template
  endif

  if getline('$') =~ '^\s*$'
    $delete
  endif

  " Replace the various tokens with appropriate values:
  silent! %s/\C%authorname%/\=g:html_authorname/g
  silent! %s/\C%authoremail%/\=g:html_authoremail_encoded/g
  silent! %s/\C%bgcolor%/\=g:html_bgcolor/g
  silent! %s/\C%textcolor%/\=g:html_textcolor/g
  silent! %s/\C%linkcolor%/\=g:html_linkcolor/g
  silent! %s/\C%alinkcolor%/\=g:html_alinkcolor/g
  silent! %s/\C%vlinkcolor%/\=g:html_vlinkcolor/g
  silent! %s/\C%date%/\=strftime('%B %d, %Y')/g
  "silent! %s/\C%date\s*\([^%]\{-}\)\s*%/\=strftime(substitute(submatch(1),'\\\@<!!','%','g'))/g
  silent! %s/\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%/\=strftime(substitute(substitute(submatch(1),'\\%','%%','g'),'\\\@<!!','%','g'))/g
  silent! %s/\C%time%/\=strftime('%r %Z')/g
  silent! %s/\C%time12%/\=strftime('%r %Z')/g
  silent! %s/\C%time24%/\=strftime('%T')/g
  silent! %s/\C%charset%/\=<SID>DetectCharset()/g
  silent! %s/\C%vimversion%/\=strpart(v:version, 0, 1) . '.' . (strpart(v:version, 1, 2) + 0)/g

  go 1

  call HTMLnextInsertPoint('n')
  if getline('.')[col('.') - 2] . getline('.')[col('.') - 1] == '><'
        \ || (getline('.') =~ '^\s*$' && line('.') != 1)
    return 1
  else
    return 0
  endif

endfunction  " }}}3

endif " ! exists("g:did_html_functions")

let s:internal_html_template =
  \" <[{HEAD}]>\n\n" .
  \"  <[{TITLE></TITLE}]>\n\n" .
  \"  <[{META HTTP-EQUIV}]=\"Content-Type\" [{CONTENT}]=\"text/html; charset=%charset%\" />" .
  \"  <[{META NAME}]=\"Generator\" [{CONTENT}]=\"Vim %vimversion% (Vi IMproved editor; http://www.vim.org/)\" />\n" .
  \"  <[{META NAME}]=\"Author\" [{CONTENT}]=\"%authorname%\" />\n" .
  \"  <[{META NAME}]=\"Copyright\" [{CONTENT}]=\"Copyright (C) %date% %authorname%\" />\n" .
  \"  <[{LINK REL}]=\"made\" [{HREF}]=\"mailto:%authoremail%\" />\n\n" .
  \"  <[{STYLE TYPE}]=\"text/css\">\n" .
  \"   <!--\n" .
  \"   [{BODY}] {background: %bgcolor%; color: %textcolor%;}\n" .
  \"   [{A}]:link {color: %linkcolor%;}\n" .
  \"   [{A}]:visited {color: %vlinkcolor%;}\n" .
  \"   [{A}]:hover, [{A}]:active, [{A}]:focus {color: %alinkcolor%;}\n" .
  \"   -->\n" .
  \"  </[{STYLE}]>\n\n" .
  \" </[{HEAD}]>\n" .
  \" <[{BODY}]>\n\n" .
  \"  <[{H1 STYLE}]=\"text-align: center;\"></[{H1}]>\n\n" .
  \"  <[{P}]>\n" .
  \"  </[{P}]>\n\n" .
  \"  <[{HR STYLE}]=\"width: 75%;\" />\n\n" .
  \"  <[{P}]>\n" .
  \"  Last Modified: <[{I}]>%date%</[{I}]>\n" .
  \"  </[{P}]>\n\n" .
  \"  <[{ADDRESS}]>\n" .
  \"   <[{A HREF}]=\"mailto:%authoremail%\">%authorname% &lt;%authoremail%&gt;</[{A}]>\n" .
  \"  </[{ADDRESS}]>\n" .
  \" </[{BODY}]>\n" .
  \"</[{HTML}]>"

if s:BoolVar('b:do_xhtml_mappings')
  let b:internal_html_template = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n" .
        \ " \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n" .
        \ "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" .
        \ s:internal_html_template
else
  let b:internal_html_template = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
        \ " \"http://www.w3.org/TR/html4/loose.dtd\">\n" .
        \ "<[{HTML}]>\n" .
        \ s:internal_html_template
  let b:internal_html_template = substitute(b:internal_html_template, ' />', '>', 'g')
endif

let b:internal_html_template = s:ConvertCase(b:internal_html_template)

" ----------------------------------------------------------------------------

endif " ! exists("b:did_html_mappings_init")


" ---- Miscellaneous Mappings: ------------------------------------------ {{{1

if ! exists("b:did_html_mappings")
let b:did_html_mappings = 1

let b:HTMLclearMappings = 'normal '

" Make it easy to use a ; (or whatever the map leader is) as normal:
call HTMLmap("inoremap", '<lead>' . g:html_map_leader, g:html_map_leader)
call HTMLmap("vnoremap", '<lead>' . g:html_map_leader, g:html_map_leader, -1)
call HTMLmap("nnoremap", '<lead>' . g:html_map_leader, g:html_map_leader)
" Make it easy to insert a & (or whatever the entity leader is):
call HTMLmap("inoremap", "<lead>" . g:html_map_entity_leader, g:html_map_entity_leader)

if ! s:BoolVar('g:no_html_tab_mapping')
  " Allow hard tabs to be inserted:
  call HTMLmap("inoremap", "<lead><tab>", "<tab>")
  call HTMLmap("nnoremap", "<lead><tab>", "<tab>")

  " Tab takes us to a (hopefully) reasonable next insert point:
  call HTMLmap("inoremap", "<tab>", "<C-O>:call HTMLnextInsertPoint('i')<CR>")
  call HTMLmap("nnoremap", "<tab>", ":call HTMLnextInsertPoint('n')<CR>")
  call HTMLmap("vnoremap", "<tab>", "<C-C>:call HTMLnextInsertPoint('n')<CR>", -1)
else
  call HTMLmap("inoremap", "<lead><tab>", "<C-O>:call HTMLnextInsertPoint('i')<CR>")
  call HTMLmap("nnoremap", "<lead><tab>", ":call HTMLnextInsertPoint('n')<CR>")
  call HTMLmap("vnoremap", "<lead><tab>", "<C-C>:call HTMLnextInsertPoint('n')<CR>", -1)
endif

" Update an image tag's WIDTH & HEIGHT attributes (experimental!):
runtime! MangleImageTag.vim
if exists("*MangleImageTag")
  call HTMLmap("nnoremap", "<lead>mi", ":call MangleImageTag()<CR>")
  call HTMLmap("inoremap", "<lead>mi", "<C-O>:call MangleImageTag()<CR>")
endif

call HTMLmap("nnoremap", "<lead>html", ":if HTMLtemplate() \\| startinsert \\| endif<CR>")

" ----------------------------------------------------------------------------


" ---- General Markup Tag Mappings: ------------------------------------- {{{1

"       SGML Doctype Command
if ! s:BoolVar('b:do_xhtml_mappings')
  " Transitional HTML (Looser):
  call HTMLmap("nnoremap", "<lead>4", ":call append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"') \\\| call append(1, ' \"http://www.w3.org/TR/html4/loose.dtd\">')<CR>")
  " Strict HTML:
  call HTMLmap("nnoremap", "<lead>s4", ":call append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"') \\\| call append(1, ' \"http://www.w3.org/TR/html4/strict.dtd\">')<CR>")
else
  " Transitional XHTML (Looser):
  call HTMLmap("nnoremap", "<lead>4", ":call append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"') \\\| call append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">')<CR>")
  " Strict XHTML:
  call HTMLmap("nnoremap", "<lead>s4", ":call append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"') \\\| call append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">')<CR>")
endif
call HTMLmap("imap", "<lead>4", "<C-O>" . g:html_map_leader . "4")
call HTMLmap("imap", "<lead>s4", "<C-O>" . g:html_map_leader . "s4")

"       HTML5 Doctype Command           HTML 5
call HTMLmap("nnoremap", "<lead>5", ":call append(0, '<!DOCTYPE html>')<CR>")
call HTMLmap("imap", "<lead>5", "<C-O>" . g:html_map_leader . "5")

"       Content-Type META tag
call HTMLmap("inoremap", "<lead>ct", "<[{META HTTP-EQUIV}]=\"Content-Type\" [{CONTENT}]=\"text/html; charset=<C-R>=<SID>DetectCharset()<CR>\" />")

"       Comment Tag
call HTMLmap("inoremap", "<lead>cm", "<C-R>=<SID>tag('comment','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>cm", "<C-C>:execute \"normal \" . <SID>tag('comment','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>cm', 0)

"       A HREF  Anchor Hyperlink        HTML 2.0
call HTMLmap("inoremap", "<lead>ah", "<[{A HREF=\"\"></A}]><C-O>F\"")
call HTMLmap("inoremap", "<lead>aH", "<[{A HREF=\"<C-R>*\"></A}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>ah", "<ESC>`>a</[{A}]><C-O>`<<[{A HREF}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>aH", "<ESC>`>a\"></[{A}]><C-O>`<<[{A HREF}]=\"<C-O>f<", 0)
" Motion mappings:
call HTMLmapo('<lead>ah', 1)
call HTMLmapo('<lead>aH', 1)

"       A HREF  Anchor Hyperlink, with TARGET=""
call HTMLmap("inoremap", "<lead>at", "<[{A HREF=\"\" TARGET=\"\"></A}]><C-O>3F\"")
call HTMLmap("inoremap", "<lead>aT", "<[{A HREF=\"<C-R>*\" TARGET=\"\"></A}]><C-O>F\"")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>at", "<ESC>`>a</[{A}]><C-O>`<<[{A HREF=\"\" TARGET}]=\"\"><C-O>3F\"", 0)
call HTMLmap("vnoremap", "<lead>aT", "<ESC>`>a\" [{TARGET=\"\"></A}]><C-O>`<<[{A HREF}]=\"<C-O>3f\"", 0)
" Motion mappings:
call HTMLmapo('<lead>at', 1)
call HTMLmapo('<lead>aT', 1)

"       A NAME  Named Anchor            HTML 2.0
"       (note this is not HTML 5 compatible, use ID attributes instead)
call HTMLmap("inoremap", "<lead>an", "<[{A NAME=\"\"></A}]><C-O>F\"")
call HTMLmap("inoremap", "<lead>aN", "<[{A NAME=\"<C-R>*\"></A}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>an", "<ESC>`>a</[{A}]><C-O>`<<[{A NAME}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>aN", "<ESC>`>a\"></[{A}]><C-O>`<<[{A NAME}]=\"<C-O>f<", 0)
" Motion mappings:
call HTMLmapo('<lead>an', 1)
call HTMLmapo('<lead>aN', 1)

"       ABBR  Abbreviation              HTML 4.0
call HTMLmap("inoremap", "<lead>ab", "<[{ABBR TITLE=\"\"></ABBR}]><C-O>F\"")
call HTMLmap("inoremap", "<lead>aB", "<[{ABBR TITLE=\"<C-R>*\"></ABBR}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>ab", "<ESC>`>a</[{ABBR}]><C-O>`<<[{ABBR TITLE}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>aB", "<ESC>`>a\"></[{ABBR}]><C-O>`<<[{ABBR TITLE}]=\"<C-O>f<", 0)
" Motion mappings:
call HTMLmapo('<lead>ab', 1)
call HTMLmapo('<lead>aB', 1)

"       ACRONYM                         HTML 4.0
"       (note this is not HTML 5 compatible, use ABBR instead)
call HTMLmap("inoremap", "<lead>ac", "<[{ACRONYM TITLE=\"\"></ACRONYM}]><C-O>F\"")
call HTMLmap("inoremap", "<lead>aC", "<[{ACRONYM TITLE=\"<C-R>*\"></ACRONYM}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>ac", "<ESC>`>a</[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>aC", "<ESC>`>a\"></[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]=\"<C-O>f<", 0)
" Motion mappings:
call HTMLmapo('<lead>ac', 1)
call HTMLmapo('<lead>aC', 1)

"       ADDRESS                         HTML 2.0
call HTMLmap("inoremap", "<lead>ad", "<[{ADDRESS></ADDRESS}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ad", "<ESC>`>a</[{ADDRESS}]><C-O>`<<[{ADDRESS}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>ad', 0)

"       ARTICLE Self-contained content  HTML 5
call HTMLmap("inoremap", "<lead>ar", "<[{ARTICLE}]><CR></[{ARTICLE}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ar", "<ESC>`>a<CR></[{ARTICLE}]><C-O>`<<[{ARTICLE}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>ar', 0)

"       ASIDE   Content aside from context HTML 5
call HTMLmap("inoremap", "<lead>as", "<[{ASIDE}]><CR></[{ASIDE}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>as", "<ESC>`>a<CR></[{ASIDE}]><C-O>`<<[{ASIDE}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>as', 0)

"       AUDIO  Audio with controls      HTML 5
call HTMLmap("inoremap", "<lead>au", "<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC=\"\" TYPE}]=\"\"><CR>Your browser does not support the audio tag.<CR></[{AUDIO}]><ESC>kk$3F\"i")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>au", "<ESC>`>a<CR></[{AUDIO}]><C-O>`<<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC=\"\" TYPE}]=\"\"><CR><ESC>k$3F\"l", 1)
" Motion mapping:
call HTMLmapo('<lead>au', 0)

"       B       Boldfaced Text          HTML 2.0
call HTMLmap("inoremap", "<lead>bo", "<C-R>=<SID>tag('b','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bo", "<C-C>:execute \"normal \" . <SID>tag('b','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>bo', 0)

"       BASE                            HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>bh", "<[{BASE HREF}]=\"\" /><C-O>F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bh", "<ESC>`>a\" /><C-O>`<<[{BASE HREF}]=\"<ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>bh', 0)

"       BASE TARGET                     HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>bt", "<[{BASE TARGET}]=\"\" /><C-O>F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bt", "<ESC>`>a\" /><C-O>`<<[{BASE TARGET}]=\"<ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>bt', 0)

"       BIG                             HTML 3.0
"       (note this is not HTML 5 compatible, use CSS instead)
call HTMLmap("inoremap", "<lead>bi", "<[{BIG></BIG}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bi", "<ESC>`>a</[{BIG}]><C-O>`<<[{BIG}]><ESC>")
" Motion mapping:
call HTMLmapo('<lead>bi', 0)

"       BLOCKQUOTE                      HTML 2.0
call HTMLmap("inoremap", "<lead>bl", "<[{BLOCKQUOTE}]><CR></[{BLOCKQUOTE}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bl", "<ESC>`>a<CR></[{BLOCKQUOTE}]><C-O>`<<[{BLOCKQUOTE}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>bl', 0)

"       BODY                            HTML 2.0
call HTMLmap("inoremap", "<lead>bd", "<[{BODY}]><CR></[{BODY}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bd", "<ESC>`>a<CR></[{BODY}]><C-O>`<<[{BODY}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>bd', 0)

"       BR      Line break              HTML 2.0
call HTMLmap("inoremap", "<lead>br", "<[{BR}] />")

"       BUTTON  Generic Button
call HTMLmap("inoremap", "<lead>bn", "<[{BUTTON TYPE}]=\"button\"></[{BUTTON}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>bn", "<ESC>`>a</[{BUTTON}]><C-O>`<<[{BUTTON TYPE}]=\"button\"><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>bn', 0)

"       CANVAS                          HTML 5
call HTMLmap("inoremap", "<lead>cv", "<[{CANVAS WIDTH=\"\" HEIGHT=\"\"></CANVAS}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>cv", "<ESC>`>a</[{CANVAS}]><C-O>`<<[{CANVAS WIDTH=\"\" HEIGHT=\"\"}]><C-O>3F\"", 0)
" Motion mapping:
call HTMLmapo('<lead>cv', 1)

"       CENTER                          NETSCAPE
"       (note this is not HTML 5 compatible, use CSS instead)
call HTMLmap("inoremap", "<lead>ce", "<[{CENTER></CENTER}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ce", "<ESC>`>a</[{CENTER}]><C-O>`<<[{CENTER}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>ce', 0)

"       CITE                            HTML 2.0
call HTMLmap("inoremap", "<lead>ci", "<[{CITE></CITE}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ci", "<ESC>`>a</[{CITE}]><C-O>`<<[{CITE}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>ci', 0)

"       CODE                            HTML 2.0
call HTMLmap("inoremap", "<lead>co", "<[{CODE></CODE}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>co", "<ESC>`>a</[{CODE}]><C-O>`<<[{CODE}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>co', 0)

"       DEFINITION LIST COMPONENTS      HTML 5
"               DL      Description List
"               DT      Description Term
"               DD      Description Body
call HTMLmap("inoremap", "<lead>dl", "<[{DL}]><CR></[{DL}]><ESC>O")
call HTMLmap("inoremap", "<lead>dt", "<[{DT}]></[{DT}]><C-O>F<")
call HTMLmap("inoremap", "<lead>dd", "<[{DD}]></[{DD}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>dl", "<ESC>`>a<CR></[{DL}]><C-O>`<<[{DL}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>dt", "<ESC>`>a</[{DT}]><C-O>`<<[{DT}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>dd", "<ESC>`>a</[{DD}]><C-O>`<<[{DD}]><ESC>", 2)
" Motion mappings:
call HTMLmapo('<lead>dl', 0)
call HTMLmapo('<lead>dt', 0)
call HTMLmapo('<lead>dd', 0)

"       DEL     Deleted Text            HTML 3.0
call HTMLmap("inoremap", "<lead>de", "<lt>[{DEL></DEL}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>de", "<ESC>`>a</[{DEL}]><C-O>`<<lt>[{DEL}]><ESC>")
" Motion mapping:
call HTMLmapo('<lead>de', 0)

"       DETAILS Expandable details      HTML 5
call HTMLmap("inoremap", "<lead>ds", "<[{DETAILS}]><CR><[{SUMMARY}]></[{SUMMARY}]><CR><[{P}]><CR></[{P}]><CR></[{DETAILS}]><ESC>3k$F<i")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ds", "<ESC>`>a<CR></[{DETAILS}]><C-O>`<<[{DETAILS}]><CR><[{SUMMARY></SUMMARY}]><CR><ESC>k$F<i", 0)
" Motion mapping:
call HTMLmapo('<lead>ds', 1)

"       DFN     Defining Instance       HTML 3.0
call HTMLmap("inoremap", "<lead>df", "<[{DFN></DFN}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>df", "<ESC>`>a</[{DFN}]><C-O>`<<[{DFN}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>df', 0)

"       DIV     Document Division       HTML 3.0
call HTMLmap("inoremap", "<lead>dv", "<[{DIV}]><CR></[{DIV}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>dv", "<ESC>`>a<CR></[{DIV}]><C-O>`<<[{DIV}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>dv', 0)

"       SPAN    Delimit Arbitrary Text  HTML 4.0
call HTMLmap("inoremap", "<lead>sn", "<[{SPAN></SPAN}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sn", "<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>sn', 0)

"       EM      Emphasize               HTML 2.0
call HTMLmap("inoremap", "<lead>em", "<C-R>=<SID>tag('em','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>em", "<C-C>:execute \"normal \" . <SID>tag('em','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>em', 0)

"       FONT                            NETSCAPE
"       (note this is not HTML 5 compatible, use CSS instead)
call HTMLmap("inoremap", "<lead>fo", "<[{FONT SIZE=\"\"></FONT}]><C-O>F\"")
call HTMLmap("inoremap", "<lead>fc", "<[{FONT COLOR=\"\"></FONT}]><C-O>F\"")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>fo", "<ESC>`>a</[{FONT}]><C-O>`<<[{FONT SIZE}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>fc", "<ESC>`>a</[{FONT}]><C-O>`<<[{FONT COLOR}]=\"\"><C-O>F\"", 0)
" Motion mappings:
call HTMLmapo('<lead>fo', 1)
call HTMLmapo('<lead>fc', 1)

"       FIGURE                          HTML 5
call HTMLmap("inoremap", "<lead>fg", "<[{FIGURE><CR></FIGURE}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>fg", "<ESC>`>a<CR></[{FIGURE}]><C-O>`<<[{FIGURE}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>fg', 0)

"       Figure Caption                  HTML 5
call HTMLmap("inoremap", "<lead>fp", "<[{FIGCAPTION></FIGCAPTION}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>fp", "<ESC>`>a</[{FIGCAPTION}]><C-O>`<<[{FIGCAPTION}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>fp', 0)

"       FOOOTER                         HTML 5
call HTMLmap("inoremap", "<lead>ft", "<[{FOOTER><CR></FOOTER}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ft", "<ESC>`>a<CR></[{FOOTER}]><C-O>`<<[{FOOTER}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>ft', 0)

"       HEADER                          HTML 5
call HTMLmap("inoremap", "<lead>hd", "<[{HEADER><CR></HEADER}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>hd", "<ESC>`>a<CR></[{HEADER}]><C-O>`<<[{HEADER}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>hd', 0)

"       HEADINGS, LEVELS 1-6            HTML 2.0
call HTMLmap("inoremap", "<lead>h1", "<[{H1}]></[{H1}]><C-O>F<")
call HTMLmap("inoremap", "<lead>h2", "<[{H2}]></[{H2}]><C-O>F<")
call HTMLmap("inoremap", "<lead>h3", "<[{H3}]></[{H3}]><C-O>F<")
call HTMLmap("inoremap", "<lead>h4", "<[{H4}]></[{H4}]><C-O>F<")
call HTMLmap("inoremap", "<lead>h5", "<[{H5}]></[{H5}]><C-O>F<")
call HTMLmap("inoremap", "<lead>h6", "<[{H6}]></[{H6}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H1", "<[{H1 STYLE}]=\"text-align: center;\"></[{H1}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H2", "<[{H2 STYLE}]=\"text-align: center;\"></[{H2}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H3", "<[{H3 STYLE}]=\"text-align: center;\"></[{H3}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H4", "<[{H4 STYLE}]=\"text-align: center;\"></[{H4}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H5", "<[{H5 STYLE}]=\"text-align: center;\"></[{H5}]><C-O>F<")
call HTMLmap("inoremap", "<lead>H6", "<[{H6 STYLE}]=\"text-align: center;\"></[{H6}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>h1", "<ESC>`>a</[{H1}]><C-O>`<<[{H1}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>h2", "<ESC>`>a</[{H2}]><C-O>`<<[{H2}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>h3", "<ESC>`>a</[{H3}]><C-O>`<<[{H3}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>h4", "<ESC>`>a</[{H4}]><C-O>`<<[{H4}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>h5", "<ESC>`>a</[{H5}]><C-O>`<<[{H5}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>h6", "<ESC>`>a</[{H6}]><C-O>`<<[{H6}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H1", "<ESC>`>a</[{H1}]><C-O>`<<[{H1 STYLE}]=\"text-align: center;\"><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H2", "<ESC>`>a</[{H2}]><C-O>`<<[{H2 STYLE}]=\"text-align: center;\"><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H3", "<ESC>`>a</[{H3}]><C-O>`<<[{H3 STYLE}]=\"text-align: center;\"><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H4", "<ESC>`>a</[{H4}]><C-O>`<<[{H4 STYLE}]=\"text-align: center;\"><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H5", "<ESC>`>a</[{H5}]><C-O>`<<[{H5 STYLE}]=\"text-align: center;\"><ESC>", 2)
call HTMLmap("vnoremap", "<lead>H6", "<ESC>`>a</[{H6}]><C-O>`<<[{H6 STYLE}]=\"text-align: center;\"><ESC>", 2)
" Motion mappings:
call HTMLmapo("<lead>h1", 0)
call HTMLmapo("<lead>h2", 0)
call HTMLmapo("<lead>h3", 0)
call HTMLmapo("<lead>h4", 0)
call HTMLmapo("<lead>h5", 0)
call HTMLmapo("<lead>h6", 0)
call HTMLmapo("<lead>H1", 0)
call HTMLmapo("<lead>H2", 0)
call HTMLmapo("<lead>H3", 0)
call HTMLmapo("<lead>H4", 0)
call HTMLmapo("<lead>H5", 0)
call HTMLmapo("<lead>H6", 0)

"       HEAD                            HTML 2.0
call HTMLmap("inoremap", "<lead>he", "<[{HEAD}]><CR></[{HEAD}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>he", "<ESC>`>a<CR></[{HEAD}]><C-O>`<<[{HEAD}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>he', 0)

"       HR      Horizontal Rule         HTML 2.0 W/NETSCAPISM
call HTMLmap("inoremap", "<lead>hr", "<[{HR}] />")
"       HR      Horizontal Rule         HTML 2.0 W/NETSCAPISM
call HTMLmap("inoremap", "<lead>Hr", "<[{HR STYLE}]=\"width: 75%;\" />")

"       HTML
if ! s:BoolVar('b:do_xhtml_mappings')
  call HTMLmap("inoremap", "<lead>ht", "<[{HTML}]><CR></[{HTML}]><ESC>O")
  " Visual mapping:
  call HTMLmap("vnoremap", "<lead>ht", "<ESC>`>a<CR></[{HTML}]><C-O>`<<[{HTML}]><CR><ESC>", 1)
else
  call HTMLmap("inoremap", "<lead>ht", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><CR></html><ESC>O")
  " Visual mapping:
  call HTMLmap("vnoremap", "<lead>ht", "<ESC>`>a<CR></html><C-O>`<<html xmlns=\"http://www.w3.org/1999/xhtml\"><CR><ESC>", 1)
endif
" Motion mapping:
call HTMLmapo('<lead>ht', 0)

"       I       Italicized Text         HTML 2.0
call HTMLmap("inoremap", "<lead>it", "<C-R>=<SID>tag('i','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>it", "<C-C>:execute \"normal \" . <SID>tag('i','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>it', 0)

"       IMG     Image                   HTML 2.0
call HTMLmap("inoremap", "<lead>im", "<[{IMG SRC=\"\" ALT}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>iM", "<[{IMG SRC=\"<C-R>*\" ALT}]=\"\" /><C-O>F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>im", "<ESC>`>a\" /><C-O>`<<[{IMG SRC=\"\" ALT}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>iM", "<ESC>`>a\" [{ALT}]=\"\" /><C-O>`<<[{IMG SRC}]=\"<C-O>3f\"", 0)
" Motion mapping:
call HTMLmapo('<lead>im', 1)
call HTMLmapo('<lead>iM', 1)

"       INS     Inserted Text           HTML 3.0
call HTMLmap("inoremap", "<lead>in", "<lt>[{INS></INS}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>in", "<ESC>`>a</[{INS}]><C-O>`<<lt>[{INS}]><ESC>")
" Motion mapping:
call HTMLmapo('<lead>in', 0)

"       KBD     Keyboard Text           HTML 2.0
call HTMLmap("inoremap", "<lead>kb", "<[{KBD></KBD}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>kb", "<ESC>`>a</[{KBD}]><C-O>`<<[{KBD}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>kb', 0)

"       LI      List Item               HTML 2.0
call HTMLmap("inoremap", "<lead>li", "<[{LI}]></[{LI}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>li", "<ESC>`>a</[{LI}]><C-O>`<<[{LI}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>li', 0)

"       LINK                            HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>lk", "<[{LINK HREF}]=\"\" /><C-O>F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>lk", "<ESC>`>a\" /><C-O>`<<[{LINK HREF}]=\"<ESC>")
" Motion mapping:
call HTMLmapo('<lead>lk', 0)

"       MAIN                            HTML 5
call HTMLmap("inoremap", "<lead>ma", "<[{MAIN><CR></MAIN}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ma", "<ESC>`>a<CR></[{MAIN}]><C-O>`<<[{MAIN}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>ma', 0)

"       METER                           HTML 5
call HTMLmap("inoremap", "<lead>mt", "<[{METER VALUE=\"\" MIN=\"\" MAX=\"\"></METER}]><C-O>5F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>mt", "<ESC>`>a</[{METER}]><C-O>`<<[{METER VALUE=\"\" MIN=\"\" MAX}]=\"\"><C-O>5F\"", 0)
" Motion mapping:
call HTMLmapo('<lead>mt', 1)

"       MARK                            HTML 5
call HTMLmap("inoremap", "<lead>mk", "<[{MARK></MARK}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>mk", "<ESC>`>a</[{MARK}]><C-O>`<<[{MARK}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>mk', 0)

"       META    Meta Information        HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>me", "<[{META NAME=\"\" CONTENT}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>mE", "<[{META NAME=\"\" CONTENT}]=\"<C-R>*\" /><C-O>3F\"")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>me", "<ESC>`>a\" [{CONTENT}]=\"\" /><C-O>`<<[{META NAME}]=\"<C-O>3f\"", 0)
call HTMLmap("vnoremap", "<lead>mE", "<ESC>`>a\" /><C-O>`<<[{META NAME=\"\" CONTENT}]=\"<C-O>2F\"", 0)
" Motion mappings:
call HTMLmapo('<lead>me', 1)
call HTMLmapo('<lead>mE', 1)

"       META    Meta http-equiv         HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>mh", "<[{META HTTP-EQUIV=\"\" CONTENT}]=\"\" /><C-O>3F\"")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>mh", "<ESC>`>a\" /><C-O>`<<[{META HTTP-EQUIV=\"\" CONTENT}]=\"<C-O>2F\"", 0)
" Motion mappings:
call HTMLmapo('<lead>mh', 1)

"       NAV                             HTML 5
call HTMLmap("inoremap", "<lead>na", "<[{NAV><CR></NAV}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>na", "<ESC>`>a<CR></[{NAV}]><C-O>`<<[{NAV}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>na', 1)

"       OL      Ordered List            HTML 3.0
call HTMLmap("inoremap", "<lead>ol", "<[{OL}]><CR></[{OL}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ol", "<ESC>`>a<CR></[{OL}]><C-O>`<<[{OL}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>ol', 0)

"       P       Paragraph               HTML 3.0
call HTMLmap("inoremap", "<lead>pp", "<[{P}]><CR></[{P}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>pp", "<ESC>`>a<CR></[{P}]><C-O>`<<[{P}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>pp', 0)
" A special mapping... If you're between <P> and </P> this will insert the
" close tag and then the open tag in insert mode:
call HTMLmap("inoremap", "<lead>/p", "</[{P}]><CR><CR><[{P}]><CR>")

"       PRE     Preformatted Text       HTML 2.0
call HTMLmap("inoremap", "<lead>pr", "<[{PRE}]><CR></[{PRE}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>pr", "<ESC>`>a<CR></[{PRE}]><C-O>`<<[{PRE}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>pr', 0)

"       PROGRESS                        HTML 5
call HTMLmap("inoremap", "<lead>pg", "<[{PROGRESS VALUE=\"\" MAX=\"\"></PROGRESS}]><C-O>3F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>pg", "<ESC>`>a\" [{MAX=\"\"></PROGRESS}]><C-O>`<<[{PROGRESS VALUE}]=\"<C-O>3f\"", 0)
" Motion mapping:
call HTMLmapo('<lead>pg', 1)

"       Q       Quote                   HTML 3.0
call HTMLmap("inoremap", "<lead>qu", "<[{Q></Q}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>qu", "<ESC>`>a</[{Q}]><C-O>`<<[{Q}]><ESC>")
" Motion mapping:
call HTMLmapo('<lead>qu', 0)

"       STRIKE  Strikethrough           HTML 3.0
"       (note this is not HTML 5 compatible, use DEL instead)
call HTMLmap("inoremap", "<lead>sk", "<[{STRIKE></STRIKE}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sk", "<ESC>`>a</[{STRIKE}]><C-O>`<<[{STRIKE}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>sk', 0)

"       SAMP    Sample Text             HTML 2.0
call HTMLmap("inoremap", "<lead>sa", "<[{SAMP></SAMP}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sa", "<ESC>`>a</[{SAMP}]><C-O>`<<[{SAMP}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>sa', 0)

"       SECTION                         HTML 5
call HTMLmap("inoremap", "<lead>sc", "<[{SECTION><CR></SECTION}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sc", "<ESC>`>a<CR></[{SECTION}]><C-O>`<<[{SECTION}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>sc', 1)

"       SMALL   Small Text              HTML 3.0
call HTMLmap("inoremap", "<lead>sm", "<[{SMALL></SMALL}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sm", "<ESC>`>a</[{SMALL}]><C-O>`<<[{SMALL}]><ESC>")
" Motion mapping:
call HTMLmapo('<lead>sm', 0)

"       STRONG  Bold Text               HTML 2.0
call HTMLmap("inoremap", "<lead>st", "<C-R>=<SID>tag('strong','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>st", "<C-C>:execute \"normal \" . <SID>tag('strong','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>st', 0)

"       STYLE                           HTML 4.0        HEADER
call HTMLmap("inoremap", "<lead>cs", "<[{STYLE TYPE}]=\"text/css\"><CR><!--<CR>--><CR></[{STYLE}]><ESC>kO")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>cs", "<ESC>`>a<CR> --><CR></[{STYLE}]><C-O>`<<[{STYLE TYPE}]=\"text/css\"><CR><!--<CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>cs', 0)

"       Linked CSS stylesheet
call HTMLmap("inoremap", "<lead>ls", "<[{LINK REL}]=\"stylesheet\" [{TYPE}]=\"text/css\" [{HREF}]=\"\" /><C-O>F\"")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ls", "<ESC>`>a\" /><C-O>`<<[{LINK REL}]=\"stylesheet\" [{TYPE}]=\"text/css\" [{HREF}]=\"<ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>ls', 0)

"       SUB     Subscript               HTML 3.0
call HTMLmap("inoremap", "<lead>sb", "<[{SUB></SUB}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sb", "<ESC>`>a</[{SUB}]><C-O>`<<[{SUB}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>sb', 0)

"       SUP     Superscript             HTML 3.0
call HTMLmap("inoremap", "<lead>sp", "<[{SUP></SUP}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>sp", "<ESC>`>a</[{SUP}]><C-O>`<<[{SUP}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>sp', 0)

"       TITLE                           HTML 2.0        HEADER
call HTMLmap("inoremap", "<lead>ti", "<[{TITLE></TITLE}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ti", "<ESC>`>a</[{TITLE}]><C-O>`<<[{TITLE}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>ti', 0)

"       TIME    Human readable date/time HTML 5
call HTMLmap("inoremap", "<lead>tm", "<[{TIME DATETIME=\"\"></TIME}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>tm", "<ESC>`>a</[{TIME}]><C-O>`<<[{TIME DATETIME=\"\"}]><ESC>F\"i", 0)
" Motion mapping:
call HTMLmapo('<lead>tm', 1)

"       TT      Teletype Text (monospaced)      HTML 2.0
"       (note this is not HTML 5 compatible, use CSS instead)
call HTMLmap("inoremap", "<lead>tt", "<[{TT></TT}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>tt", "<ESC>`>a</[{TT}]><C-O>`<<[{TT}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>tt', 0)

"       U       Underlined Text         HTML 2.0
call HTMLmap("inoremap", "<lead>un", "<C-R>=<SID>tag('u','i')<CR>")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>un", "<C-C>:execute \"normal \" . <SID>tag('u','v')<CR>", 2)
" Motion mapping:
call HTMLmapo('<lead>un', 0)

"       UL      Unordered List          HTML 2.0
call HTMLmap("inoremap", "<lead>ul", "<[{UL}]><CR></[{UL}]><ESC>O")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>ul", "<ESC>`>a<CR></[{UL}]><C-O>`<<[{UL}]><CR><ESC>", 1)
" Motion mapping:
call HTMLmapo('<lead>ul', 0)

"       VAR     Variable                HTML 3.0
call HTMLmap("inoremap", "<lead>va", "<[{VAR></VAR}]><C-O>F<")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>va", "<ESC>`>a</[{VAR}]><C-O>`<<[{VAR}]><ESC>", 2)
" Motion mapping:
call HTMLmapo('<lead>va', 0)

"       Embedded JavaScript
call HTMLmap("inoremap", "<lead>js", "<C-O>:call <SID>TC(0)<CR><[{SCRIPT TYPE}]=\"text/javascript\"><CR><!--<CR>// --><CR></[{SCRIPT}]><ESC>:call <SID>TC(1)<CR>kko")

"       Sourced JavaScript
call HTMLmap("inoremap", "<lead>sj", "<[{SCRIPT SRC}]=\"\" [{TYPE}]=\"text/javascript\"></[{SCRIPT}]><C-O>3F\"")

"       EMBED                           HTML 5
call HTMLmap("inoremap", "<lead>eb", "<[{EMBED SRC=\"\" WIDTH=\"\" HEIGHT}]=\"\" /><ESC>$5F\"i")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>eb", "<ESC>`>a\" [{WIDTH=\"\" HEIGHT}]=\"\" /><C-O>`<<[{EMBED SRC}]=\"<ESC>$3F\"i", 0)
" Motion mapping:
call HTMLmapo('<lead>eb', 1)

"       NOSCRIPT
call HTMLmap("inoremap", "<lead>ns", "<[{NOSCRIPT}]><CR></[{NOSCRIPT}]><C-O>O")
call HTMLmap("vnoremap", "<lead>ns", "<ESC>`>a<CR></[{NOSCRIPT}]><C-O>`<<[{NOSCRIPT}]><CR><ESC>", 1)
call HTMLmapo('<lead>ns', 0)

"       OBJECT
call HTMLmap("inoremap", "<lead>ob", "<[{OBJECT DATA=\"\" WIDTH=\"\" HEIGHT}]=\"\"><CR></[{OBJECT}]><ESC>k$5F\"i")
call HTMLmap("vnoremap", "<lead>ob", "<ESC>`>a<CR></[{OBJECT}]><C-O>`<<[{OBJECT DATA=\"\" WIDTH=\"\" HEIGHT}]=\"\"><CR><ESC>k$5F\"", 1)
call HTMLmapo('<lead>ob', 0)

"       PARAM (Object Parameter)
call HTMLmap("inoremap", "<lead>pm", "<[{PARAM NAME=\"\" VALUE}]=\"\" /><ESC>3F\"i")
call HTMLmap("vnoremap", "<lead>pm", "<ESC>`>a\" [{VALUE}]=\"\" /><C-O>`<<[{PARAM NAME}]=\"<ESC>3f\"i", 0)
call HTMLmapo('<lead>pm', 0)

"       VIDEO  Video with controls      HTML 5
call HTMLmap("inoremap", "<lead>vi", "<[{VIDEO WIDTH=\"\" HEIGHT=\"\" CONTROLS}]><CR><[{SOURCE SRC=\"\" TYPE}]=\"\"><CR>Your browser does not support the video tag.<CR></[{VIDEO}]><ESC>kkk$3F\"i")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>vi", "<ESC>`>a<CR></[{VIDEO}]><C-O>`<<[{VIDEO WIDTH=\"\" HEIGHT=\"\" CONTROLS}]><CR><[{SOURCE SRC=\"\" TYPE}]=\"\"><CR><ESC>kk$3F\"", 1)
" Motion mapping:
call HTMLmapo('<lead>vi', 0)

"       WBR     Possible line break     HTML 5
call HTMLmap("inoremap", "<lead>wb", "<[{WBR}] />")


" Table stuff:
call HTMLmap("inoremap", "<lead>ca", "<[{CAPTION></CAPTION}]><C-O>F<")
call HTMLmap("inoremap", "<lead>ta", "<[{TABLE}]><CR></[{TABLE}]><ESC>O")
call HTMLmap("inoremap", "<lead>tH", "<[{THEAD}]><CR></[{THEAD}]><ESC>O")
call HTMLmap("inoremap", "<lead>tb", "<[{TBODY}]><CR></[{TBODY}]><ESC>O")
call HTMLmap("inoremap", "<lead>tf", "<[{TFOOT}]><CR></[{TFOOT}]><ESC>O")
call HTMLmap("inoremap", "<lead>tr", "<[{TR}]><CR></[{TR}]><ESC>O")
call HTMLmap("inoremap", "<lead>td", "<[{TD></TD}]><C-O>F<")
call HTMLmap("inoremap", "<lead>th", "<[{TH></TH}]><C-O>F<")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>ca", "<ESC>`>a<CR></[{CAPTION}]><C-O>`<<[{CAPTION}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>ta", "<ESC>`>a<CR></[{TABLE}]><C-O>`<<[{TABLE}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>tH", "<ESC>`>a<CR></[{THEAD}]><C-O>`<<[{THEAD}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>tb", "<ESC>`>a<CR></[{TBODY}]><C-O>`<<[{TBODY}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>tf", "<ESC>`>a<CR></[{TFOOT}]><C-O>`<<[{TFOOT}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>tr", "<ESC>`>a<CR></[{TR}]><C-O>`<<[{TR}]><CR><ESC>", 1)
call HTMLmap("vnoremap", "<lead>td", "<ESC>`>a</[{TD}]><C-O>`<<[{TD}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>th", "<ESC>`>a</[{TH}]><C-O>`<<[{TH}]><ESC>", 2)
" Motion mappings:
call HTMLmapo("<lead>ca", 0)
call HTMLmapo("<lead>ta", 0)
call HTMLmapo("<lead>tH", 0)
call HTMLmapo("<lead>tb", 0)
call HTMLmapo("<lead>tf", 0)
call HTMLmapo("<lead>tr", 0)
call HTMLmapo("<lead>td", 0)
call HTMLmapo("<lead>th", 0)

" Interactively generate a table of Rows x Columns:
call HTMLmap("nnoremap", "<lead>tA", ":call HTMLgenerateTable()<CR>")

" Frames stuff:
"       (note this is not HTML 5 compatible)
call HTMLmap("inoremap", "<lead>fs", "<[{FRAMESET ROWS=\"\" COLS}]=\"\"><CR></[{FRAMESET}]><ESC>k$3F\"i")
call HTMLmap("inoremap", "<lead>fr", "<[{FRAME SRC}]=\"\" /><C-O>F\"")
call HTMLmap("inoremap", "<lead>nf", "<[{NOFRAMES}]><CR></[{NOFRAMES}]><ESC>O")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>fs", "<ESC>`>a<CR></[{FRAMESET}]><C-O>`<<[{FRAMESET ROWS=\"\" COLS}]=\"\"><CR><ESC>k$3F\"", 1)
call HTMLmap("vnoremap", "<lead>fr", "<ESC>`>a\" /><C-O>`<<[{FRAME SRC}]=\"<ESC>")
call HTMLmap("vnoremap", "<lead>nf", "<ESC>`>a<CR></[{NOFRAMES}]><C-O>`<<[{NOFRAMES}]><CR><ESC>", 1)
" Motion mappings:
call HTMLmapo("<lead>fs", 0)
call HTMLmapo("<lead>fr", 0)
call HTMLmapo("<lead>nf", 0)

"       IFRAME  Inline Frame            HTML 4.0
call HTMLmap("inoremap", "<lead>if", "<[{IFRAME SRC=\"\" WIDTH=\"\" HEIGHT}]=\"\"><CR></[{IFRAME}]><ESC>k$5F\"i")
" Visual mapping:
call HTMLmap("vnoremap", "<lead>if", "<ESC>`>a<CR></[{IFRAME}]><C-O>`<<[{IFRAME SRC=\"\" WIDTH=\"\" HEIGHT}]=\"\"><CR><ESC>k$5F\"", 1)
" Motion mapping:
call HTMLmapo('<lead>if', 0)

" Forms stuff:
call HTMLmap("inoremap", "<lead>fm", "<[{FORM ACTION}]=\"\"><CR></[{FORM}]><ESC>k$F\"i")
call HTMLmap("inoremap", "<lead>bu", "<[{INPUT TYPE=\"BUTTON\" NAME=\"\" VALUE}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>ch", "<[{INPUT TYPE=\"CHECKBOX\" NAME=\"\" VALUE}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>ra", "<[{INPUT TYPE=\"RADIO\" NAME=\"\" VALUE}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>hi", "<[{INPUT TYPE=\"HIDDEN\" NAME=\"\" VALUE}]=\"\" /><C-O>3F\"")
call HTMLmap("inoremap", "<lead>pa", "<[{INPUT TYPE=\"PASSWORD\" NAME=\"\" VALUE=\"\" SIZE}]=\"20\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>te", "<[{INPUT TYPE=\"TEXT\" NAME=\"\" VALUE=\"\" SIZE}]=\"20\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>fi", "<[{INPUT TYPE=\"FILE\" NAME=\"\" VALUE=\"\" SIZE}]=\"20\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>@", "<[{INPUT TYPE=\"EMAIL\" NAME=\"\" VALUE=\"\" SIZE}]=\"20\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>#", "<[{INPUT TYPE=\"TEL\" NAME=\"\" VALUE=\"\" SIZE}]=\"15\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>nu", "<[{INPUT TYPE=\"NUMBER\" NAME=\"\" VALUE=\"\" STYLE}]=\"width: 5em;\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>ur", "<[{INPUT TYPE=\"URL\" NAME=\"\" VALUE=\"\" SIZE}]=\"20\" /><C-O>5F\"")
call HTMLmap("inoremap", "<lead>se", "<[{SELECT NAME}]=\"\"><CR></[{SELECT}]><ESC>O")
call HTMLmap("inoremap", "<lead>ms", "<[{SELECT NAME=\"\" MULTIPLE}]><CR></[{SELECT}]><ESC>O")
call HTMLmap("inoremap", "<lead>op", "<[{OPTION></OPTION}]><C-O>F<")
call HTMLmap("inoremap", "<lead>og", "<[{OPTGROUP LABEL}]=\"\"><CR></[{OPTGROUP}]><ESC>k$F\"i")
call HTMLmap("inoremap", "<lead>tx", "<[{TEXTAREA NAME=\"\" ROWS=\"10\" COLS}]=\"50\"><CR></[{TEXTAREA}]><ESC>k$5F\"i")
call HTMLmap("inoremap", "<lead>su", "<[{INPUT TYPE=\"SUBMIT\" VALUE}]=\"Submit\" />")
call HTMLmap("inoremap", "<lead>re", "<[{INPUT TYPE=\"RESET\" VALUE}]=\"Reset\" />")
call HTMLmap("inoremap", "<lead>la", "<[{LABEL FOR=\"\"></LABEL}]><C-O>F\"")
" Visual mappings:
call HTMLmap("vnoremap", "<lead>fm", "<ESC>`>a<CR></[{FORM}]><C-O>`<<[{FORM ACTION}]=\"\"><CR><ESC>k$F\"", 1)
call HTMLmap("vnoremap", "<lead>bu", "<ESC>`>a\" /><C-O>`<<[{INPUT TYPE=\"BUTTON\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>ch", "<ESC>`>a\" /><C-O>`<<[{INPUT TYPE=\"CHECKBOX\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>ra", "<ESC>`>a\" /><C-O>`<<[{INPUT TYPE=\"RADIO\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>hi", "<ESC>`>a\" /><C-O>`<<[{INPUT TYPE=\"HIDDEN\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>pa", "<ESC>`>a\" [{SIZE}]=\"20\" /><C-O>`<<[{INPUT TYPE=\"PASSWORD\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>te", "<ESC>`>a\" [{SIZE}]=\"20\" /><C-O>`<<[{INPUT TYPE=\"TEXT\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>fi", "<ESC>`>a\" [{SIZE}]=\"20\" /><C-O>`<<[{INPUT TYPE=\"FILE\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>@", "<ESC>`>a\" [{SIZE}]=\"20\" /><C-O>`<<[{INPUT TYPE=\"EMAIL\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>#", "<ESC>`>a\" [{SIZE}]=\"15\" /><C-O>`<<[{INPUT TYPE=\"TEL\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>nu", "<ESC>`>a\" [{STYLE}]=\"width: 5em;\" /><C-O>`<<[{INPUT TYPE=\"NUMBER\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>ur", "<ESC>`>a\" [{SIZE}]=\"20\" /><C-O>`<<[{INPUT TYPE=\"URL\" NAME=\"\" VALUE}]=\"<C-O>2F\"", 0)
call HTMLmap("vnoremap", "<lead>se", "<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME}]=\"\"><CR><ESC>k$F\"", 1)
call HTMLmap("vnoremap", "<lead>ms", "<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME=\"\" MULTIPLE}]><CR><ESC>k$F\"", 1)
call HTMLmap("vnoremap", "<lead>op", "<ESC>`>a</[{OPTION}]><C-O>`<<[{OPTION}]><ESC>", 2)
call HTMLmap("vnoremap", "<lead>og", "<ESC>`>a<CR></[{OPTGROUP}]><C-O>`<<[{OPTGROUP LABEL}]=\"\"><CR><ESC>k$F\"", 1)
call HTMLmap("vnoremap", "<lead>tx", "<ESC>`>a<CR></[{TEXTAREA}]><C-O>`<<[{TEXTAREA NAME=\"\" ROWS=\"10\" COLS}]=\"50\"><CR><ESC>k$5F\"", 1)
call HTMLmap("vnoremap", "<lead>la", "<ESC>`>a</[{LABEL}]><C-O>`<<[{LABEL FOR}]=\"\"><C-O>F\"", 0)
call HTMLmap("vnoremap", "<lead>lA", "<ESC>`>a\"></[{LABEL}]><C-O>`<<[{LABEL FOR}]=\"<C-O>f<", 0)
" Motion mappings:
call HTMLmapo("<lead>fm", 0)
call HTMLmapo("<lead>bu", 1)
call HTMLmapo("<lead>ch", 1)
call HTMLmapo("<lead>ra", 1)
call HTMLmapo("<lead>hi", 1)
call HTMLmapo("<lead>pa", 1)
call HTMLmapo("<lead>te", 1)
call HTMLmapo("<lead>fi", 1)
call HTMLmapo("<lead>@", 1)
call HTMLmapo("<lead>#", 1)
call HTMLmapo("<lead>nu", 1)
call HTMLmapo("<lead>ur", 1)
call HTMLmapo("<lead>se", 0)
call HTMLmapo("<lead>ms", 0)
call HTMLmapo("<lead>op", 0)
call HTMLmapo("<lead>og", 0)
call HTMLmapo("<lead>tx", 0)
call HTMLmapo("<lead>la", 1)
call HTMLmapo("<lead>lA", 1)

" ----------------------------------------------------------------------------


" ---- Special Character (Character Entities) Mappings: ----------------- {{{1

" Convert the character under the cursor or the highlighted string to decimal
" HTML entities:
call HTMLmap("vnoremap", "<lead>&", "s<C-R>=<SID>SI(HTMLencodeString(@\"))<CR><Esc>")
call HTMLmapo("<lead>&", 0)

" Convert the character under the cursor or the highlighted string to hex
" HTML entities:
call HTMLmap("vnoremap", "<lead>*", "s<C-R>=<SID>SI(HTMLencodeString(@\", 'x'))<CR><Esc>")
call HTMLmapo("<lead>*", 0)

" Convert the character under the cursor or the highlighted string to a %XX
" string:
call HTMLmap("vnoremap", "<lead>%", "s<C-R>=<SID>SI(HTMLencodeString(@\", '%'))<CR><Esc>")
call HTMLmapo("<lead>%", 0)

" Decode a &#...; or %XX encoded string:
call HTMLmap("vnoremap", "<lead>^", "s<C-R>=<SID>SI(HTMLencodeString(@\", 'd'))<CR><Esc>")
call HTMLmapo("<lead>^", 0)

call HTMLmap("inoremap", "<elead>&", "&amp;")
call HTMLmap("inoremap", "<elead>cO", "&copy;")
call HTMLmap("inoremap", "<elead>rO", "&reg;")
call HTMLmap("inoremap", "<elead>tm", "&trade;")
call HTMLmap("inoremap", "<elead>'", "&quot;")
call HTMLmap("inoremap", "<elead>l'", "&lsquo;")
call HTMLmap("inoremap", "<elead>r'", "&rsquo;")
call HTMLmap("inoremap", "<elead>l\"", "&ldquo;")
call HTMLmap("inoremap", "<elead>r\"", "&rdquo;")
call HTMLmap("inoremap", "<elead><", "&lt;")
call HTMLmap("inoremap", "<elead>>", "&gt;")
call HTMLmap("inoremap", "<elead><space>", "&nbsp;")
call HTMLmap("inoremap", "<lead><space>", "&nbsp;")
call HTMLmap("inoremap", "<elead>#", "&pound;")
call HTMLmap("inoremap", "<elead>E=", "&euro;")
call HTMLmap("inoremap", "<elead>Y=", "&yen;")
call HTMLmap("inoremap", "<elead>c\\|", "&cent;")
call HTMLmap("inoremap", "<elead>A`", "&Agrave;")
call HTMLmap("inoremap", "<elead>A'", "&Aacute;")
call HTMLmap("inoremap", "<elead>A^", "&Acirc;")
call HTMLmap("inoremap", "<elead>A~", "&Atilde;")
call HTMLmap("inoremap", '<elead>A"', "&Auml;")
call HTMLmap("inoremap", "<elead>Ao", "&Aring;")
call HTMLmap("inoremap", "<elead>AE", "&AElig;")
call HTMLmap("inoremap", "<elead>C,", "&Ccedil;")
call HTMLmap("inoremap", "<elead>E`", "&Egrave;")
call HTMLmap("inoremap", "<elead>E'", "&Eacute;")
call HTMLmap("inoremap", "<elead>E^", "&Ecirc;")
call HTMLmap("inoremap", '<elead>E"', "&Euml;")
call HTMLmap("inoremap", "<elead>I`", "&Igrave;")
call HTMLmap("inoremap", "<elead>I'", "&Iacute;")
call HTMLmap("inoremap", "<elead>I^", "&Icirc;")
call HTMLmap("inoremap", '<elead>I"', "&Iuml;")
call HTMLmap("inoremap", "<elead>N~", "&Ntilde;")
call HTMLmap("inoremap", "<elead>O`", "&Ograve;")
call HTMLmap("inoremap", "<elead>O'", "&Oacute;")
call HTMLmap("inoremap", "<elead>O^", "&Ocirc;")
call HTMLmap("inoremap", "<elead>O~", "&Otilde;")
call HTMLmap("inoremap", '<elead>O"', "&Ouml;")
call HTMLmap("inoremap", "<elead>O/", "&Oslash;")
call HTMLmap("inoremap", "<elead>U`", "&Ugrave;")
call HTMLmap("inoremap", "<elead>U'", "&Uacute;")
call HTMLmap("inoremap", "<elead>U^", "&Ucirc;")
call HTMLmap("inoremap", '<elead>U"', "&Uuml;")
call HTMLmap("inoremap", "<elead>Y'", "&Yacute;")
call HTMLmap("inoremap", "<elead>a`", "&agrave;")
call HTMLmap("inoremap", "<elead>a'", "&aacute;")
call HTMLmap("inoremap", "<elead>a^", "&acirc;")
call HTMLmap("inoremap", "<elead>a~", "&atilde;")
call HTMLmap("inoremap", '<elead>a"', "&auml;")
call HTMLmap("inoremap", "<elead>ao", "&aring;")
call HTMLmap("inoremap", "<elead>ae", "&aelig;")
call HTMLmap("inoremap", "<elead>c,", "&ccedil;")
call HTMLmap("inoremap", "<elead>e`", "&egrave;")
call HTMLmap("inoremap", "<elead>e'", "&eacute;")
call HTMLmap("inoremap", "<elead>e^", "&ecirc;")
call HTMLmap("inoremap", '<elead>e"', "&euml;")
call HTMLmap("inoremap", "<elead>i`", "&igrave;")
call HTMLmap("inoremap", "<elead>i'", "&iacute;")
call HTMLmap("inoremap", "<elead>i^", "&icirc;")
call HTMLmap("inoremap", '<elead>i"', "&iuml;")
call HTMLmap("inoremap", "<elead>n~", "&ntilde;")
call HTMLmap("inoremap", "<elead>o`", "&ograve;")
call HTMLmap("inoremap", "<elead>o'", "&oacute;")
call HTMLmap("inoremap", "<elead>o^", "&ocirc;")
call HTMLmap("inoremap", "<elead>o~", "&otilde;")
call HTMLmap("inoremap", '<elead>o"', "&ouml;")
call HTMLmap("inoremap", "<elead>u`", "&ugrave;")
call HTMLmap("inoremap", "<elead>u'", "&uacute;")
call HTMLmap("inoremap", "<elead>u^", "&ucirc;")
call HTMLmap("inoremap", '<elead>u"', "&uuml;")
call HTMLmap("inoremap", "<elead>y'", "&yacute;")
call HTMLmap("inoremap", '<elead>y"', "&yuml;")
call HTMLmap("inoremap", "<elead>2<", "&laquo;")
call HTMLmap("inoremap", "<elead>2>", "&raquo;")
call HTMLmap("inoremap", '<elead>"', "&uml;")
call HTMLmap("inoremap", "<elead>o/", "&oslash;")
call HTMLmap("inoremap", "<elead>sz", "&szlig;")
call HTMLmap("inoremap", "<elead>!", "&iexcl;")
call HTMLmap("inoremap", "<elead>?", "&iquest;")
call HTMLmap("inoremap", "<elead>dg", "&deg;")
call HTMLmap("inoremap", "<elead>0^", "&#x2070;")
call HTMLmap("inoremap", "<elead>1^", "&sup1;")
call HTMLmap("inoremap", "<elead>2^", "&sup2;")
call HTMLmap("inoremap", "<elead>3^", "&sup3;")
call HTMLmap("inoremap", "<elead>4^", "&#x2074;")
call HTMLmap("inoremap", "<elead>5^", "&#x2075;")
call HTMLmap("inoremap", "<elead>6^", "&#x2076;")
call HTMLmap("inoremap", "<elead>7^", "&#x2077;")
call HTMLmap("inoremap", "<elead>8^", "&#x2078;")
call HTMLmap("inoremap", "<elead>9^", "&#x2079;")
call HTMLmap("inoremap", "<elead>0v", "&#x2080;")
call HTMLmap("inoremap", "<elead>1v", "&#x2081;")
call HTMLmap("inoremap", "<elead>2v", "&#x2082;")
call HTMLmap("inoremap", "<elead>3v", "&#x2083;")
call HTMLmap("inoremap", "<elead>4v", "&#x2084;")
call HTMLmap("inoremap", "<elead>5v", "&#x2085;")
call HTMLmap("inoremap", "<elead>6v", "&#x2086;")
call HTMLmap("inoremap", "<elead>7v", "&#x2087;")
call HTMLmap("inoremap", "<elead>8v", "&#x2088;")
call HTMLmap("inoremap", "<elead>9v", "&#x2089;")
call HTMLmap("inoremap", "<elead>mi", "&micro;")
call HTMLmap("inoremap", "<elead>pa", "&para;")
call HTMLmap("inoremap", "<elead>se", "&sect;")
call HTMLmap("inoremap", "<elead>.", "&middot;")
call HTMLmap("inoremap", "<elead>*", "&bull;")
call HTMLmap("inoremap", "<elead>x", "&times;")
call HTMLmap("inoremap", "<elead>/", "&divide;")
call HTMLmap("inoremap", "<elead>+-", "&plusmn;")
call HTMLmap("inoremap", "<elead>n-", "&ndash;")  " Math symbol
call HTMLmap("inoremap", "<elead>2-", "&ndash;")  " ...
call HTMLmap("inoremap", "<elead>m-", "&mdash;")  " Sentence break
call HTMLmap("inoremap", "<elead>3-", "&mdash;")  " ...
call HTMLmap("inoremap", "<elead>--", "&mdash;")  " ...
call HTMLmap("inoremap", "<elead>3.", "&hellip;")
" Fractions:
call HTMLmap("inoremap", "<elead>14", "&frac14;")
call HTMLmap("inoremap", "<elead>12", "&frac12;")
call HTMLmap("inoremap", "<elead>34", "&frac34;")
call HTMLmap("inoremap", "<elead>13", "&frac13;")
call HTMLmap("inoremap", "<elead>23", "&frac23;")
call HTMLmap("inoremap", "<elead>15", "&frac15;")
call HTMLmap("inoremap", "<elead>25", "&frac25;")
call HTMLmap("inoremap", "<elead>35", "&frac35;")
call HTMLmap("inoremap", "<elead>45", "&frac45;")
call HTMLmap("inoremap", "<elead>16", "&frac16;")
call HTMLmap("inoremap", "<elead>56", "&frac56;")
call HTMLmap("inoremap", "<elead>18", "&frac18;")
call HTMLmap("inoremap", "<elead>38", "&frac38;")
call HTMLmap("inoremap", "<elead>58", "&frac58;")
call HTMLmap("inoremap", "<elead>78", "&frac78;") 
" Greek letters:
"   ... Capital:
call HTMLmap("inoremap", "<elead>Al", "&Alpha;")
call HTMLmap("inoremap", "<elead>Be", "&Beta;")
call HTMLmap("inoremap", "<elead>Ga", "&Gamma;")
call HTMLmap("inoremap", "<elead>De", "&Delta;")
call HTMLmap("inoremap", "<elead>Ep", "&Epsilon;")
call HTMLmap("inoremap", "<elead>Ze", "&Zeta;")
call HTMLmap("inoremap", "<elead>Et", "&Eta;")
call HTMLmap("inoremap", "<elead>Th", "&Theta;")
call HTMLmap("inoremap", "<elead>Io", "&Iota;")
call HTMLmap("inoremap", "<elead>Ka", "&Kappa;")
call HTMLmap("inoremap", "<elead>Lm", "&Lambda;")
call HTMLmap("inoremap", "<elead>Mu", "&Mu;")
call HTMLmap("inoremap", "<elead>Nu", "&Nu;")
call HTMLmap("inoremap", "<elead>Xi", "&Xi;")
call HTMLmap("inoremap", "<elead>Oc", "&Omicron;")
call HTMLmap("inoremap", "<elead>Pi", "&Pi;")
call HTMLmap("inoremap", "<elead>Rh", "&Rho;")
call HTMLmap("inoremap", "<elead>Si", "&Sigma;")
call HTMLmap("inoremap", "<elead>Ta", "&Tau;")
call HTMLmap("inoremap", "<elead>Up", "&Upsilon;")
call HTMLmap("inoremap", "<elead>Ph", "&Phi;")
call HTMLmap("inoremap", "<elead>Ch", "&Chi;")
call HTMLmap("inoremap", "<elead>Ps", "&Psi;")
"   ... Lowercase/small:
call HTMLmap("inoremap", "<elead>al", "&alpha;")
call HTMLmap("inoremap", "<elead>be", "&beta;")
call HTMLmap("inoremap", "<elead>ga", "&gamma;")
call HTMLmap("inoremap", "<elead>de", "&delta;")
call HTMLmap("inoremap", "<elead>ep", "&epsilon;")
call HTMLmap("inoremap", "<elead>ze", "&zeta;")
call HTMLmap("inoremap", "<elead>et", "&eta;")
call HTMLmap("inoremap", "<elead>th", "&theta;")
call HTMLmap("inoremap", "<elead>io", "&iota;")
call HTMLmap("inoremap", "<elead>ka", "&kappa;")
call HTMLmap("inoremap", "<elead>lm", "&lambda;")
call HTMLmap("inoremap", "<elead>mu", "&mu;")
call HTMLmap("inoremap", "<elead>nu", "&nu;")
call HTMLmap("inoremap", "<elead>xi", "&xi;")
call HTMLmap("inoremap", "<elead>oc", "&omicron;")
call HTMLmap("inoremap", "<elead>pi", "&pi;")
call HTMLmap("inoremap", "<elead>rh", "&rho;")
call HTMLmap("inoremap", "<elead>si", "&sigma;")
call HTMLmap("inoremap", "<elead>sf", "&sigmaf;")
call HTMLmap("inoremap", "<elead>ta", "&tau;")
call HTMLmap("inoremap", "<elead>up", "&upsilon;")
call HTMLmap("inoremap", "<elead>ph", "&phi;")
call HTMLmap("inoremap", "<elead>ch", "&chi;")
call HTMLmap("inoremap", "<elead>ps", "&psi;")
call HTMLmap("inoremap", "<elead>og", "&omega;")
call HTMLmap("inoremap", "<elead>ts", "&thetasym;")
call HTMLmap("inoremap", "<elead>uh", "&upsih;")
call HTMLmap("inoremap", "<elead>pv", "&piv;")
" single-line arrows:
call HTMLmap("inoremap", "<elead>la", "&larr;")
call HTMLmap("inoremap", "<elead>ua", "&uarr;")
call HTMLmap("inoremap", "<elead>ra", "&rarr;")
call HTMLmap("inoremap", "<elead>da", "&darr;")
call HTMLmap("inoremap", "<elead>ha", "&harr;")
"call HTMLmap("inoremap", "<elead>ca", "&crarr;")
" double-line arrows:
call HTMLmap("inoremap", "<elead>lA", "&lArr;")
call HTMLmap("inoremap", "<elead>uA", "&uArr;")
call HTMLmap("inoremap", "<elead>rA", "&rArr;")
call HTMLmap("inoremap", "<elead>dA", "&dArr;")
call HTMLmap("inoremap", "<elead>hA", "&hArr;")
" Roman numerals, upppercase:
call HTMLmap("inoremap", "<elead>R1",    "&#x2160;")
call HTMLmap("inoremap", "<elead>R2",    "&#x2161;")
call HTMLmap("inoremap", "<elead>R3",    "&#x2162;")
call HTMLmap("inoremap", "<elead>R4",    "&#x2163;")
call HTMLmap("inoremap", "<elead>R5",    "&#x2164;")
call HTMLmap("inoremap", "<elead>R6",    "&#x2165;")
call HTMLmap("inoremap", "<elead>R7",    "&#x2166;")
call HTMLmap("inoremap", "<elead>R8",    "&#x2167;")
call HTMLmap("inoremap", "<elead>R9",    "&#x2168;")
call HTMLmap("inoremap", "<elead>R10",   "&#x2169;")
call HTMLmap("inoremap", "<elead>R11",   "&#x216a;")
call HTMLmap("inoremap", "<elead>R12",   "&#x216b;")
call HTMLmap("inoremap", "<elead>R50",   "&#x216c;")
call HTMLmap("inoremap", "<elead>R100",  "&#x216d;")
call HTMLmap("inoremap", "<elead>R500",  "&#x216e;")
call HTMLmap("inoremap", "<elead>R1000", "&#x216f;")
" Roman numerals, lowercase:
call HTMLmap("inoremap", "<elead>r1",    "&#x2170;")
call HTMLmap("inoremap", "<elead>r2",    "&#x2171;")
call HTMLmap("inoremap", "<elead>r3",    "&#x2172;")
call HTMLmap("inoremap", "<elead>r4",    "&#x2173;")
call HTMLmap("inoremap", "<elead>r5",    "&#x2174;")
call HTMLmap("inoremap", "<elead>r6",    "&#x2175;")
call HTMLmap("inoremap", "<elead>r7",    "&#x2176;")
call HTMLmap("inoremap", "<elead>r8",    "&#x2177;")
call HTMLmap("inoremap", "<elead>r9",    "&#x2178;")
call HTMLmap("inoremap", "<elead>r10",   "&#x2179;")
call HTMLmap("inoremap", "<elead>r11",   "&#x217a;")
call HTMLmap("inoremap", "<elead>r12",   "&#x217b;")
call HTMLmap("inoremap", "<elead>r50",   "&#x217c;")
call HTMLmap("inoremap", "<elead>r100",  "&#x217d;")
call HTMLmap("inoremap", "<elead>r500",  "&#x217e;")
call HTMLmap("inoremap", "<elead>r1000", "&#x217f;")

" ----------------------------------------------------------------------------


" ---- Browser Remote Controls: ----------------------------------------- {{{1

runtime! browser_launcher.vim

if has('mac') || has('macunix') " {{{2

  " Run the default Mac browser:
  call HTMLmap("nnoremap", "<lead>db", ":call OpenInMacApp('default')<CR>")

  " Firefox: View current file, starting Firefox if it's not running:
  call HTMLmap("nnoremap", "<lead>ff", ":call OpenInMacApp('firefox',0)<CR>")
  " Firefox: Open a new window, and view the current file:
  call HTMLmap("nnoremap", "<lead>nff", ":call OpenInMacApp('firefox',1)<CR>")
  " Firefox: Open a new tab, and view the current file:
  call HTMLmap("nnoremap", "<lead>tff", ":call OpenInMacApp('firefox',2)<CR>")

  " Opera: View current file, starting Opera if it's not running:
  call HTMLmap("nnoremap", "<lead>oa", ":call OpenInMacApp('opera',0)<CR>")
  " Opera: View current file in a new window, starting Opera if it's not running:
  call HTMLmap("nnoremap", "<lead>noa", ":call OpenInMacApp('opera',1)<CR>")
  " Opera: Open a new tab, and view the current file:
  call HTMLmap("nnoremap", "<lead>toa", ":call OpenInMacApp('opera',2)<CR>")

  " Safari: View current file, starting Safari if it's not running:
  call HTMLmap("nnoremap", "<lead>sf", ":call OpenInMacApp('safari')<CR>")
  " Safari: Open a new window, and view the current file:
  call HTMLmap("nnoremap", "<lead>nsf", ":call OpenInMacApp('safari',1)<CR>")
  " Safari: Open a new tab, and view the current file:
  call HTMLmap("nnoremap", "<lead>tsf", ":call OpenInMacApp('safari',2)<CR>")

elseif has("unix") " {{{2
  call system("which xdg-open")
  if v:shell_error == 0
    " Run the default Unix browser:
    call HTMLmap("nnoremap", "<lead>db", ":call system('xdg-open ' . <SID>ShellEscape(expand('%:p')) . ' 2>&1 >/dev/null &')<CR>")
  endif
elseif has("win32") || has('win64') " {{{2
  " Run the default Windows browser:
  call HTMLmap("nnoremap", "<lead>db", ":call system('start RunDll32.exe shell32.dll,ShellExec_RunDLL ' . <SID>ShellEscape(expand('%:p')))<CR>")
endif " }}}2

if exists("*LaunchBrowser") " {{{2
  let s:browsers = LaunchBrowser()

  if s:browsers =~ 'f'
    " Firefox: View current file, starting Firefox if it's not running:
    call HTMLmap("nnoremap", "<lead>ff", ":call LaunchBrowser('f',0)<CR>")
    " Firefox: Open a new window, and view the current file:
    call HTMLmap("nnoremap", "<lead>nff", ":call LaunchBrowser('f',1)<CR>")
    " Firefox: Open a new tab, and view the current file:
    call HTMLmap("nnoremap", "<lead>tff", ":call LaunchBrowser('f',2)<CR>")
  endif
  if s:browsers =~ 'c'
    " Chrome: View current file, starting Chrome if it's not running:
    call HTMLmap("nnoremap", "<lead>gc", ":call LaunchBrowser('c',0)<CR>")
    " Chrome: Open a new window, and view the current file:
    call HTMLmap("nnoremap", "<lead>ngc", ":call LaunchBrowser('c',1)<CR>")
    " Chrome: Open a new tab, and view the current file:
    call HTMLmap("nnoremap", "<lead>tgc", ":call LaunchBrowser('c',2)<CR>")
  endif
  if s:browsers =~ 'o'
    " Opera: View current file, starting Opera if it's not running:
    call HTMLmap("nnoremap", "<lead>oa", ":call LaunchBrowser('o',0)<CR>")
    " Opera: View current file in a new window, starting Opera if it's not running:
    call HTMLmap("nnoremap", "<lead>noa", ":call LaunchBrowser('o',1)<CR>")
    " Opera: Open a new tab, and view the current file:
    call HTMLmap("nnoremap", "<lead>toa", ":call LaunchBrowser('o',2)<CR>")
  endif
  if s:browsers =~ 'l'
    " Lynx:  (This happens anyway if there's no DISPLAY environmental variable.)
    call HTMLmap("nnoremap","<lead>ly",":call LaunchBrowser('l',0)<CR>")
    " Lynx in an xterm:  (This happens regardless in the Vim GUI.)
    call HTMLmap("nnoremap", "<lead>nly", ":call LaunchBrowser('l',1)<CR>")
  endif
  if s:browsers =~ 'w'
    " w3m:
    call HTMLmap("nnoremap","<lead>w3",":call LaunchBrowser('w',0)<CR>")
    " w3m in an xterm:  (This happens regardless in the Vim GUI.)
    call HTMLmap("nnoremap", "<lead>nw3", ":call LaunchBrowser('w',1)<CR>")
  endif
endif " }}}2

" Attempt to run Microsoft Edge (doesn't seem to work for file:// URI's):
"call HTMLmap("nnoremap", "<lead>ed", ":call system('start \"microsoft-edge:file://' . <SID>ShellEscape(expand('%:p')) . '\"')<CR>")

" ----------------------------------------------------------------------------

endif " ! exists("b:did_html_mappings")


" ---- ToolBar Buttons: ------------------------------------------------- {{{1
if ! has("gui_running") && ! s:BoolVar('g:force_html_menu')
  augroup HTMLplugin
  au!
  execute 'autocmd GUIEnter * source ' . s:thisfile . ' | autocmd! HTMLplugin GUIEnter *'
  augroup END
elseif exists("g:did_html_menus")
  call s:MenuControl()
elseif ! s:BoolVar('g:no_html_menu')

command! -nargs=+ HTMLmenu call s:LeadMenu(<f-args>)
function! s:LeadMenu(type, level, name, item, ...)
  if a:0 == 1
    let pre = a:1
  else
    let pre = ''
  endif

  if a:level == '-'
    let level = ''
  else
    let level = a:level
  endif

  let name = escape(a:name, ' ')

  execute a:type . ' ' . level . ' ' . name . '<tab>' . g:html_map_leader . a:item
    \ . ' ' . pre . g:html_map_leader . a:item
endfunction

if ! s:BoolVar('g:no_html_toolbar') && has("toolbar")

  if ((has("win32") || has('win64')) && findfile('bitmaps/Browser.bmp', &rtp) == '')
      \ || findfile('bitmaps/Browser.xpm', &rtp) == ''
    let s:tmp = "Warning:\nYou need to install the Toolbar Bitmaps for the "
          \ . fnamemodify(s:thisfile, ':t') . " plugin. "
          \ . "See: http://christianrobinson.name/vim/HTML/#files\n"
          \ . 'Or see ":help g:no_html_toolbar".'
    if has('win32') || has('win64') || has('unix')
      let s:tmp = confirm(s:tmp, "&Dismiss\nView &Help\nGet &Bitmaps", 1, 'Warning')
    else
      let s:tmp = confirm(s:tmp, "&Dismiss\nView &Help", 1, 'Warning')
    endif

    if s:tmp == 2
      help g:no_html_toolbar
      " Go to the previous window or everything gets messy:
      wincmd p
    elseif s:tmp == 3
      if has('win32') || has('win64')
        execute '!start RunDll32.exe shell32.dll,ShellExec_RunDLL http://christianrobinson.name/vim/HTML/\#files'
      else
        call system("which xdg-open")
        if v:shell_error == 0
          " Run the default Unix browser:
          call system('xdg-open ' . s:ShellEscape('http://christianrobinson.name/vim/HTML/#files') . ' 2>&1 >/dev/null &')
        elseif exists('*LaunchBrowser')
          call LaunchBrowser('default', 2, 'http://christianrobinson.name/vim/HTML/#files')
        else
          HTMLERROR Can't launch browser -- OS not recognized?
        endif
      endif
    endif

    unlet s:tmp
  endif

  set guioptions+=T

  "tunmenu ToolBar
  silent! unmenu ToolBar
  silent! unmenu! ToolBar

  tmenu 1.10      ToolBar.Open      Open file
  amenu 1.10      ToolBar.Open      :browse e<CR>
  tmenu 1.20      ToolBar.Save      Save current file
  amenu 1.20      ToolBar.Save      :w<CR>
  tmenu 1.30      ToolBar.SaveAll   Save all files
  amenu 1.30      ToolBar.SaveAll   :wa<CR>

   menu 1.50      ToolBar.-sep1-    <nul>

  tmenu           1.60  ToolBar.Template   Insert Template
  HTMLmenu amenu  1.60  ToolBar.Template   html

   menu           1.65  ToolBar.-sep2-     <nul>

  tmenu           1.70  ToolBar.Paragraph  Create Paragraph
  HTMLmenu imenu  1.70  ToolBar.Paragraph  pp
  HTMLmenu vmenu  1.70  ToolBar.Paragraph  pp
  HTMLmenu nmenu  1.70  ToolBar.Paragraph  pp i
  tmenu           1.80  ToolBar.Break      Line Break
  HTMLmenu imenu  1.80  ToolBar.Break      br
  HTMLmenu vmenu  1.80  ToolBar.Break      br
  HTMLmenu nmenu  1.80  ToolBar.Break      br i

   menu           1.85  ToolBar.-sep3-     <nul>

  tmenu           1.90  ToolBar.Link       Create Hyperlink
  HTMLmenu imenu  1.90  ToolBar.Link       ah
  HTMLmenu vmenu  1.90  ToolBar.Link       ah
  HTMLmenu nmenu  1.90  ToolBar.Link       ah i
  tmenu           1.110 ToolBar.Image      Insert Image
  HTMLmenu imenu  1.110 ToolBar.Image      im
  HTMLmenu vmenu  1.110 ToolBar.Image      im
  HTMLmenu nmenu  1.110 ToolBar.Image      im i

   menu           1.115 ToolBar.-sep4-     <nul>

  tmenu           1.120 ToolBar.Hline      Create Horizontal Rule
  HTMLmenu imenu  1.120 ToolBar.Hline      hr
  HTMLmenu nmenu  1.120 ToolBar.Hline      hr i

   menu           1.125 ToolBar.-sep5-     <nul>

  tmenu           1.130 ToolBar.Table      Create Table
  HTMLmenu imenu  1.130 ToolBar.Table     tA <ESC>
  HTMLmenu nmenu  1.130 ToolBar.Table     tA

   menu           1.135 ToolBar.-sep6-     <nul>

  tmenu           1.140 ToolBar.Blist      Create Bullet List
  exe 'imenu      1.140 ToolBar.Blist'     g:html_map_leader . 'ul' . g:html_map_leader . 'li'
  exe 'vmenu      1.140 ToolBar.Blist'     g:html_map_leader . 'uli' . g:html_map_leader . 'li<ESC>'
  exe 'nmenu      1.140 ToolBar.Blist'     'i' . g:html_map_leader . 'ul' . g:html_map_leader . 'li'
  tmenu           1.150 ToolBar.Nlist      Create Numbered List
  exe 'imenu      1.150 ToolBar.Nlist'     g:html_map_leader . 'ol' . g:html_map_leader . 'li'
  exe 'vmenu      1.150 ToolBar.Nlist'     g:html_map_leader . 'oli' . g:html_map_leader . 'li<ESC>'
  exe 'nmenu      1.150 ToolBar.Nlist'     'i' . g:html_map_leader . 'ol' . g:html_map_leader . 'li'
  tmenu           1.160 ToolBar.Litem      Add List Item
  HTMLmenu imenu  1.160 ToolBar.Litem      li
  HTMLmenu nmenu  1.160 ToolBar.Litem      li i

   menu           1.165 ToolBar.-sep7-     <nul>

  tmenu           1.170 ToolBar.Bold       Bold
  HTMLmenu imenu  1.170 ToolBar.Bold       bo
  HTMLmenu vmenu  1.170 ToolBar.Bold       bo
  HTMLmenu nmenu  1.170 ToolBar.Bold       bo i
  tmenu           1.180 ToolBar.Italic     Italic
  HTMLmenu imenu  1.180 ToolBar.Italic     it
  HTMLmenu vmenu  1.180 ToolBar.Italic     it
  HTMLmenu nmenu  1.180 ToolBar.Italic     it i
  tmenu           1.190 ToolBar.Underline  Underline
  HTMLmenu imenu  1.190 ToolBar.Underline  un
  HTMLmenu vmenu  1.190 ToolBar.Underline  un
  HTMLmenu nmenu  1.190 ToolBar.Underline  un i

   menu           1.195 ToolBar.-sep8-    <nul>

  tmenu           1.200 ToolBar.Cut       Cut to clipboard
  vmenu           1.200 ToolBar.Cut       "*x
  tmenu           1.210 ToolBar.Copy      Copy to clipboard
  vmenu           1.210 ToolBar.Copy      "*y
  tmenu           1.220 ToolBar.Paste     Paste from Clipboard
  nmenu           1.220 ToolBar.Paste     i<C-R>*<Esc>
  vmenu           1.220 ToolBar.Paste     "-xi<C-R>*<Esc>
  menu!           1.220 ToolBar.Paste     <C-R>*

   menu           1.225 ToolBar.-sep9-    <nul>

  tmenu           1.230 ToolBar.Find      Find...
  tmenu           1.240 ToolBar.Replace   Find & Replace

  if has("win32") || has('win64') || has("win16") || has("gui_gtk") || has("gui_motif")
    amenu 1.250 ToolBar.Find    :promptfind<CR>
    vunmenu     ToolBar.Find
    vmenu       ToolBar.Find    y:promptfind <C-R>"<CR>
    amenu 1.260 ToolBar.Replace :promptrepl<CR>
    vunmenu     ToolBar.Replace
    vmenu       ToolBar.Replace y:promptrepl <C-R>"<CR>
  else
    amenu 1.250 ToolBar.Find    /
    amenu 1.260 ToolBar.Replace :%s/
    vunmenu     ToolBar.Replace
    vmenu       ToolBar.Replace :s/
  endif

   menu 1.500 ToolBar.-sep50- <nul>

  if maparg(g:html_map_leader . 'db', 'n') != ''
    tmenu          1.510 ToolBar.Browser Launch Default Browser on Current File
    HTMLmenu amenu 1.510 ToolBar.Browser db
  endif

  if exists("*LaunchBrowser")
    let s:browsers = LaunchBrowser()

    if s:browsers =~ 'f'
      tmenu           1.520 ToolBar.Firefox   Launch Firefox on Current File
      HTMLmenu amenu  1.520 ToolBar.Firefox   ff
    endif

    if s:browsers =~ 'c'
      tmenu           1.530 ToolBar.Chrome    Launch Chrome on Current File
      HTMLmenu amenu  1.530 ToolBar.Chrome    gc
    endif

    if s:browsers =~ 'o'
      tmenu           1.540 ToolBar.Opera     Launch Opera on Current File
      HTMLmenu amenu  1.540 ToolBar.Opera     oa
    endif

    if s:browsers =~ 'w'
      tmenu           1.550 ToolBar.w3m       Launch w3m on Current File
      HTMLmenu amenu  1.550 ToolBar.w3m       w3
    elseif s:browsers =~ 'l'
      tmenu           1.550 ToolBar.Lynx      Launch Lynx on Current File
      HTMLmenu amenu  1.550 ToolBar.Lynx      ly
    endif
  endif

   menu 1.998 ToolBar.-sep99- <nul>
  tmenu 1.999 ToolBar.Help    HTML Help
  amenu 1.999 ToolBar.Help    :help HTML<CR>

  let did_html_toolbar = 1
endif  " ! s:BoolVar('g:no_html_toolbar') && has("toolbar")
" ----------------------------------------------------------------------------


" ---- Menu Items: ------------------------------------------------------ {{{1

" Add to the PopUp menu:   {{{2
nnoremenu 1.91 PopUp.Select\ Ta&g vat
onoremenu 1.91 PopUp.Select\ Ta&g at
vnoremenu 1.91 PopUp.Select\ Ta&g <C-C>vat
inoremenu 1.91 PopUp.Select\ Ta&g <C-O>vat
cnoremenu 1.91 PopUp.Select\ Ta&g <C-C>vat

nnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g vit
onoremenu 1.92 PopUp.Select\ &Inner\ Ta&g it
vnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-C>vit
inoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-O>vit
cnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-C>vit
" }}}2

augroup HTMLmenu
au!
"autocmd BufLeave * call s:MenuControl()
autocmd BufEnter,WinEnter * call s:MenuControl() | call s:ToggleClipboard(2)
augroup END

amenu HTM&L.HTML\ Help<TAB>:help\ HTML\.txt :help HTML.txt<CR>
 menu HTML.-sep1- <nul>

amenu HTML.Co&ntrol.&Disable\ Mappings<tab>:HTML\ disable     :HTMLmappings disable<CR>
amenu HTML.Co&ntrol.&Enable\ Mappings<tab>:HTML\ enable       :HTMLmappings enable<CR>
amenu disable HTML.Control.Enable\ Mappings
 menu HTML.Control.-sep1- <nul>
amenu HTML.Co&ntrol.Switch\ to\ &HTML\ mode<tab>:HTML\ html   :HTMLmappings html<CR>
amenu HTML.Co&ntrol.Switch\ to\ &XHTML\ mode<tab>:HTML\ xhtml :HTMLmappings xhtml<CR>
 menu HTML.Control.-sep2- <nul>
amenu HTML.Co&ntrol.&Reload\ Mappings<tab>:HTML\ reload       :HTMLmappings reload<CR>

if s:BoolVar('b:do_xhtml_mappings')
  amenu disable HTML.Control.Switch\ to\ XHTML\ mode
else
  amenu disable HTML.Control.Switch\ to\ HTML\ mode
endif

if maparg(g:html_map_leader . 'db', 'n') != ''
  HTMLmenu amenu - HTML.&Preview.&Default\ Browser       db
endif
if maparg(g:html_map_leader . 'ff', 'n') != ''
   menu HTML.Preview.-sep1-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Firefox                ff
  HTMLmenu amenu - HTML.&Preview.Firefox\ (New\ Window)  nff
  HTMLmenu amenu - HTML.&Preview.Firefox\ (New\ Tab)     tff
endif
if maparg(g:html_map_leader . 'gc', 'n') != ''
   menu HTML.Preview.-sep2-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Chrome                 gc
  HTMLmenu amenu - HTML.&Preview.Chrome\ (New\ Window)   ngc
  HTMLmenu amenu - HTML.&Preview.Chrome\ (New\ Tab)      tgc
endif
if maparg(g:html_map_leader . 'oa', 'n') != ''
   menu HTML.Preview.-sep3-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Opera                  oa
  HTMLmenu amenu - HTML.&Preview.Opera\ (New\ Window)    noa
  HTMLmenu amenu - HTML.&Preview.Opera\ (New\ Tab)       toa
endif
if maparg(g:html_map_leader . 'sf', 'n') != ''
   menu HTML.Preview.-sep4-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Safari                 sf
  HTMLmenu amenu - HTML.&Preview.Safari\ (New\ Window)   nsf
  HTMLmenu amenu - HTML.&Preview.Safari\ (New\ Tab)      tsf
endif
if maparg(g:html_map_leader . 'ly', 'n') != ''
   menu HTML.Preview.-sep5-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Lynx                   ly
  HTMLmenu amenu - HTML.&Preview.Lynx\ (New\ Window\)    nly
endif
if maparg(g:html_map_leader . 'w3', 'n') != ''
   menu HTML.Preview.-sep6-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&w3m                    w3
  HTMLmenu amenu - HTML.&Preview.w3m\ (New\ Window\)     nw3
endif

 menu HTML.-sep4- <nul>

HTMLmenu amenu - HTML.Template html

 menu HTML.-sep5- <nul>

" Character Entities menu:   {{{2

"let b:save_encoding=&encoding
"let &encoding='latin1'
"scriptencoding latin1

command! -nargs=+ HTMLemenu call s:EntityMenu(<f-args>)
function! s:EntityMenu(name, item, ...)
  if a:0 >= 1 && a:1 != '-'
    if a:1 == '\-'
      let symb = ' (-)'
    else
      let symb = ' (' . a:1 . ')'
    endif
  else
    let symb = ''
  endif

  if a:0 >= 2
    let pre = a:2
  else
    let pre = ''
  endif

  let name = escape(a:name, ' ')

  execute 'imenu ' . name . escape(symb, ' &<.|') . '<tab>'
        \ . escape(g:html_map_entity_leader, '&\')
        \ . escape(a:item, '&<') . ' ' . pre
        \ . g:html_map_entity_leader . a:item
  execute 'nmenu ' . name . escape(symb, ' &<.|') . '<tab>'
        \ . escape(g:html_map_entity_leader, '&\')
        \ . escape(a:item, '&<') . ' ' . pre . 'i'
        \ . g:html_map_entity_leader . a:item . '<esc>'
endfunction


HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ to\ Entity                &
"HTMLmenu nmenu - HTML.Character\ &Entities.Convert\ to\ Entity                &l
HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ to\ %XX\ (URI\ Encode\)   %
"HTMLmenu nmenu - HTML.Character\ &Entities.Convert\ to\ %XX\ (URI\ Encode\)   %l
HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ from\ Entities/%XX        ^

 menu HTML.Character\ Entities.-sep0- <nul>
HTMLemenu HTML.Character\ Entities.Ampersand            &
HTMLemenu HTML.Character\ Entities.Greaterthan          >        >
HTMLemenu HTML.Character\ Entities.Lessthan             <        <
HTMLemenu HTML.Character\ Entities.Space                <space>  nonbreaking
 menu HTML.Character\ Entities.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Cent                 c\|      ¢
HTMLemenu HTML.Character\ Entities.Pound                #        £
HTMLemenu HTML.Character\ Entities.Euro                 E=       €
HTMLemenu HTML.Character\ Entities.Yen                  Y=       ¥
 menu HTML.Character\ Entities.-sep2- <nul>
HTMLemenu HTML.Character\ Entities.Copyright            cO       ©
HTMLemenu HTML.Character\ Entities.Registered           rO       ®
HTMLemenu HTML.Character\ Entities.Trademark            tm       TM
 menu HTML.Character\ Entities.-sep3- <nul>
HTMLemenu HTML.Character\ Entities.Inverted\ Exlamation !        ¡
HTMLemenu HTML.Character\ Entities.Inverted\ Question   ?        ¿
HTMLemenu HTML.Character\ Entities.Paragraph            pa       ¶
HTMLemenu HTML.Character\ Entities.Section              se       §
HTMLemenu HTML.Character\ Entities.Middle\ Dot          \.       ·
HTMLemenu HTML.Character\ Entities.Bullet               *        •
HTMLemenu HTML.Character\ Entities.En\ dash             n-       \-
HTMLemenu HTML.Character\ Entities.Em\ dash             m-       --
HTMLemenu HTML.Character\ Entities.Ellipsis             3\.      ...
 menu HTML.Character\ Entities.-sep5- <nul>
HTMLemenu HTML.Character\ Entities.Math.Multiply        x   ×
HTMLemenu HTML.Character\ Entities.Math.Divide          /   ÷
HTMLemenu HTML.Character\ Entities.Math.Degree          dg  °
HTMLemenu HTML.Character\ Entities.Math.Micro           mi  µ
HTMLemenu HTML.Character\ Entities.Math.Plus/Minus      +-  ±
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 1    R1    Ⅰ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 2    R2    Ⅱ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 3    R3    Ⅲ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 4    R4    Ⅳ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 5    R5    Ⅴ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 6    R6    Ⅵ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 7    R7    Ⅶ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 8    R8    Ⅷ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 9    R9    Ⅸ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 10   R10   Ⅹ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 11   R11   Ⅺ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 12   R12   Ⅻ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 50   R50   Ⅼ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 100  R100  Ⅽ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 500  R500  Ⅾ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 1000 R1000 Ⅿ
 menu HTML.Character\ Entities.Math.Roman\ Numerals.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 1    r1    ⅰ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 2    r2    ⅱ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 3    r3    ⅲ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 4    r4    ⅳ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 5    r5    ⅴ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 6    r6    ⅵ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 7    r7    ⅶ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 8    r8    ⅷ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 9    r9    ⅸ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 10   r10   ⅹ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 11   r11   ⅺ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 12   r12   ⅻ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 50   r50   ⅼ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 100  r100  ⅽ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 500  r500  ⅾ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 1000 r1000 ⅿ
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 0  0^  ⁰
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 1  1^  ¹
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 2  2^  ²
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 3  3^  ³
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 4  4^  ⁴
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 5  5^  ⁵
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 6  6^  ⁶
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 7  7^  ⁷
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 8  8^  ⁸
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 9  9^  ⁹
 menu HTML.Character\ Entities.Math.Super/Subscript.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 0    0v  ₀
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 1    1v  ₁
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 2    2v  ₂
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 3    3v  ₃
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 4    4v  ₄
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 5    5v  ₅
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 6    6v  ₆
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 7    7v  ₇
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 8    8v  ₈
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 9    9v  ₉
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Quarter    14  ¼
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Half       12  ½
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Quarters 34  ¾
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Third      13  ⅓
HTMLemenu HTML.Character\ Entities.Math.Fractions.Two\ Thirds     23  ⅔
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Fifth      15  ⅕
HTMLemenu HTML.Character\ Entities.Math.Fractions.Two\ Fifths     25  ⅖
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Fifths   35  ⅗
HTMLemenu HTML.Character\ Entities.Math.Fractions.Four\ Fiftsh    45  ⅘
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Sixth      16  ⅙
HTMLemenu HTML.Character\ Entities.Math.Fractions.Five\ Sixths    56  ⅚
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Eigth      18  ⅛
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Eigths   38  ⅜
HTMLemenu HTML.Character\ Entities.Math.Fractions.Five\ Eigths    58  ⅝
HTMLemenu HTML.Character\ Entities.Math.Fractions.Seven\ Eigths   78  ⅞
HTMLemenu HTML.Character\ Entities.&Graves.A-grave  A`  À
HTMLemenu HTML.Character\ Entities.&Graves.a-grave  a`  à
HTMLemenu HTML.Character\ Entities.&Graves.E-grave  E`  È
HTMLemenu HTML.Character\ Entities.&Graves.e-grave  e`  è
HTMLemenu HTML.Character\ Entities.&Graves.I-grave  I`  Ì
HTMLemenu HTML.Character\ Entities.&Graves.i-grave  i`  ì
HTMLemenu HTML.Character\ Entities.&Graves.O-grave  O`  Ò
HTMLemenu HTML.Character\ Entities.&Graves.o-grave  o`  ò
HTMLemenu HTML.Character\ Entities.&Graves.U-grave  U`  Ù
HTMLemenu HTML.Character\ Entities.&Graves.u-grave  u`  ù
HTMLemenu HTML.Character\ Entities.&Acutes.A-acute  A'  Á
HTMLemenu HTML.Character\ Entities.&Acutes.a-acute  a'  á
HTMLemenu HTML.Character\ Entities.&Acutes.E-acute  E'  É
HTMLemenu HTML.Character\ Entities.&Acutes.e-acute  e'  é
HTMLemenu HTML.Character\ Entities.&Acutes.I-acute  I'  Í
HTMLemenu HTML.Character\ Entities.&Acutes.i-acute  i'  í
HTMLemenu HTML.Character\ Entities.&Acutes.O-acute  O'  Ó
HTMLemenu HTML.Character\ Entities.&Acutes.o-acute  o'  ó
HTMLemenu HTML.Character\ Entities.&Acutes.U-acute  U'  Ú
HTMLemenu HTML.Character\ Entities.&Acutes.u-acute  u'  ú
HTMLemenu HTML.Character\ Entities.&Acutes.Y-acute  Y'  Ý
HTMLemenu HTML.Character\ Entities.&Acutes.y-acute  y'  ý
HTMLemenu HTML.Character\ Entities.&Tildes.A-tilde  A~  Ã
HTMLemenu HTML.Character\ Entities.&Tildes.a-tilde  a~  ã
HTMLemenu HTML.Character\ Entities.&Tildes.N-tilde  N~  Ñ
HTMLemenu HTML.Character\ Entities.&Tildes.n-tilde  n~  ñ
HTMLemenu HTML.Character\ Entities.&Tildes.O-tilde  O~  Õ
HTMLemenu HTML.Character\ Entities.&Tildes.o-tilde  o~  õ
HTMLemenu HTML.Character\ Entities.&Circumflexes.A-circumflex  A^  Â
HTMLemenu HTML.Character\ Entities.&Circumflexes.a-circumflex  a^  â
HTMLemenu HTML.Character\ Entities.&Circumflexes.E-circumflex  E^  Ê
HTMLemenu HTML.Character\ Entities.&Circumflexes.e-circumflex  e^  ê
HTMLemenu HTML.Character\ Entities.&Circumflexes.I-circumflex  I^  Î
HTMLemenu HTML.Character\ Entities.&Circumflexes.i-circumflex  i^  î
HTMLemenu HTML.Character\ Entities.&Circumflexes.O-circumflex  O^  Ô
HTMLemenu HTML.Character\ Entities.&Circumflexes.o-circumflex  o^  ô
HTMLemenu HTML.Character\ Entities.&Circumflexes.U-circumflex  U^  Û
HTMLemenu HTML.Character\ Entities.&Circumflexes.u-circumflex  u^  û
HTMLemenu HTML.Character\ Entities.&Umlauts.A-umlaut  A"  Ä
HTMLemenu HTML.Character\ Entities.&Umlauts.a-umlaut  a"  ä
HTMLemenu HTML.Character\ Entities.&Umlauts.E-umlaut  E"  Ë
HTMLemenu HTML.Character\ Entities.&Umlauts.e-umlaut  e"  ë
HTMLemenu HTML.Character\ Entities.&Umlauts.I-umlaut  I"  Ï
HTMLemenu HTML.Character\ Entities.&Umlauts.i-umlaut  i"  ï
HTMLemenu HTML.Character\ Entities.&Umlauts.O-umlaut  O"  Ö
HTMLemenu HTML.Character\ Entities.&Umlauts.o-umlaut  o"  ö
HTMLemenu HTML.Character\ Entities.&Umlauts.U-umlaut  U"  Ü
HTMLemenu HTML.Character\ Entities.&Umlauts.u-umlaut  u"  ü
HTMLemenu HTML.Character\ Entities.&Umlauts.y-umlaut  y"  ÿ
HTMLemenu HTML.Character\ Entities.&Umlauts.Umlaut    "   ¨
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Alpha    Al Α
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Beta     Be Β
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Gamma    Ga Γ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Delta    De Δ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Epsilon  Ep Ε
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Zeta     Ze Ζ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Eta      Et Η
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Theta    Th Θ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Iota     Io Ι
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Kappa    Ka Κ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Lambda   Lm Λ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Mu       Mu Μ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Nu       Nu Ν
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Xi       Xi Ξ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Omicron  Oc Ο
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Pi       Pi Π
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Rho      Rh Ρ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Sigma    Si Σ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Tau      Ta Τ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Upsilon  Up Υ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Phi      Ph Φ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Chi      Ch Χ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Psi      Ps Ψ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.alpha    al α
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.beta     be β
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.gamma    ga γ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.delta    de δ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.epsilon  ep ε
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.zeta     ze ζ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.eta      et η
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.theta    th θ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.iota     io ι
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.kappa    ka κ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.lambda   lm λ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.mu       mu μ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.nu       nu ν
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.xi       xi ξ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.omicron  oc ο
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.pi       pi π
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.rho      rh ρ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.sigma    si σ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.sigmaf   sf ς
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.tau      ta τ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.upsilon  up υ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.phi      ph φ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.chi      ch χ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.psi      ps ψ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.omega    og ω
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.thetasym ts ϑ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.upsih    uh ϒ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.piv      pv ϖ
HTMLemenu HTML.Character\ Entities.A&rrows.Left\ single\ arrow        la ←
HTMLemenu HTML.Character\ Entities.A&rrows.Right\ single\ arrow       ra →
HTMLemenu HTML.Character\ Entities.A&rrows.Up\ single\ arrow          ua ↑
HTMLemenu HTML.Character\ Entities.A&rrows.Down\ single\ arrow        da ↓
HTMLemenu HTML.Character\ Entities.A&rrows.Left-right\ single\ arrow  ha ↔
 menu HTML.Character\ Entities.Arrows.-sep1-                             <nul>
HTMLemenu HTML.Character\ Entities.A&rrows.Left\ double\ arrow        lA ⇐
HTMLemenu HTML.Character\ Entities.A&rrows.Right\ double\ arrow       rA ⇒
HTMLemenu HTML.Character\ Entities.A&rrows.Up\ double\ arrow          uA ⇑
HTMLemenu HTML.Character\ Entities.A&rrows.Down\ double\ arrow        dA ⇓
HTMLemenu HTML.Character\ Entities.A&rrows.Left-right\ double\ arrow  hA ⇔
HTMLemenu HTML.Character\ Entities.&Quotes.Quotation\ mark            '  "
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Single\ Quote        l' ‘
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Single\ Quote       r' ’
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Double\ Quote        l" “ 
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Double\ Quote       r" ”
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Angle\ Quote         2< «
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Angle\ Quote        2> »
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..A-ring      Ao Å
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..a-ring      ao å
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..AE-ligature AE Æ
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..ae-ligature ae æ
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..C-cedilla   C, Ç
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..c-cedilla   c, ç
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..O-slash     O/ Ø
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..o-slash     o/ ø

"let &encoding=b:save_encoding
"unlet b:save_encoding
"scriptencoding

" Colors menu:   {{{2

command! -nargs=+ HTMLcmenu call s:ColorsMenu(<f-args>)
let s:colors_sort = {
      \ 'A': 'A',   'B': 'B',   'C': 'C',
      \ 'D': 'D',   'E': 'E-G', 'F': 'E-G',
      \ 'G': 'E-G', 'H': 'H-K', 'I': 'H-K',
      \ 'J': 'H-K', 'K': 'H-K', 'L': 'L',
      \ 'M': 'M',   'N': 'N-O', 'O': 'N-O',
      \ 'P': 'P',   'Q': 'Q-R', 'R': 'Q-R',
      \ 'S': 'S',   'T': 'T-Z', 'U': 'T-Z',
      \ 'V': 'T-Z', 'W': 'T-Z', 'X': 'T-Z',
      \ 'Y': 'T-Z', 'Z': 'T-Z',
    \}
let s:color_list = {}
function! s:ColorsMenu(name, color)
  let c = a:name->strpart(0, 1)->toupper()
  let a:name = a:name->substitute('\C\([a-z]\)\([A-Z]\)', '\1\ \2', 'g')
  execute 'imenu HTML.&Colors.&' . s:colors_sort[c] . '.' . a:name->escape(' ')
        \ . '<tab>(' . a:color . ') ' . a:color
  execute 'nmenu HTML.&Colors.&' . s:colors_sort[c] . '.' . a:name->escape(' ')
        \ . '<tab>(' . a:color . ') i' . a:color . '<esc>'
  call s:color_list->extend({a:name : a:color})
endfunction

if (has('gui_running') || &t_Co >= 256)
  command! -nargs=? ColorSelect call s:ShowColors(<f-args>)
  command! -nargs=? CS call s:ShowColors(<f-args>)
  
  call HTMLmap("nnoremap", "<lead>3", ":ColorSelect<CR>")
  call HTMLmap("inoremap", "<lead>3", "<C-O>:ColorSelect<CR>")

  "amenu HTML.&Colors.Display\ All\ &&\ Select<TAB>:ColorSelect :ColorSelect<CR>
  HTMLmenu amenu - HTML.&Colors.Display\ All\ &&\ Select 3
  amenu HTML.Colors.-sep1- <nul>
endif

HTMLcmenu AliceBlue            #F0F8FF
HTMLcmenu AntiqueWhite         #FAEBD7
HTMLcmenu Aqua                 #00FFFF
HTMLcmenu Aquamarine           #7FFFD4
HTMLcmenu Azure                #F0FFFF

HTMLcmenu Beige                #F5F5DC
HTMLcmenu Bisque               #FFE4C4
HTMLcmenu Black                #000000
HTMLcmenu BlanchedAlmond       #FFEBCD
HTMLcmenu Blue                 #0000FF
HTMLcmenu BlueViolet           #8A2BE2
HTMLcmenu Brown                #A52A2A
HTMLcmenu Burlywood            #DEB887

HTMLcmenu CadetBlue            #5F9EA0
HTMLcmenu Chartreuse           #7FFF00
HTMLcmenu Chocolate            #D2691E
HTMLcmenu Coral                #FF7F50
HTMLcmenu CornflowerBlue       #6495ED
HTMLcmenu Cornsilk             #FFF8DC
HTMLcmenu Crimson              #DC143C
HTMLcmenu Cyan                 #00FFFF

HTMLcmenu DarkBlue             #00008B
HTMLcmenu DarkCyan             #008B8B
HTMLcmenu DarkGoldenrod        #B8860B
HTMLcmenu DarkGray             #A9A9A9
HTMLcmenu DarkGreen            #006400
HTMLcmenu DarkKhaki            #BDB76B
HTMLcmenu DarkMagenta          #8B008B
HTMLcmenu DarkOliveGreen       #556B2F
HTMLcmenu DarkOrange           #FF8C00
HTMLcmenu DarkOrchid           #9932CC
HTMLcmenu DarkRed              #8B0000
HTMLcmenu DarkSalmon           #E9967A
HTMLcmenu DarkSeagreen         #8FBC8F
HTMLcmenu DarkSlateBlue        #483D8B
HTMLcmenu DarkSlateGray        #2F4F4F
HTMLcmenu DarkTurquoise        #00CED1
HTMLcmenu DarkViolet           #9400D3
HTMLcmenu DeepPink             #FF1493
HTMLcmenu DeepSkyblue          #00BFFF
HTMLcmenu DimGray              #696969
HTMLcmenu DodgerBlue           #1E90FF

HTMLcmenu Firebrick            #B22222
HTMLcmenu FloralWhite          #FFFAF0
HTMLcmenu ForestGreen          #228B22
HTMLcmenu Fuchsia              #FF00FF
HTMLcmenu Gainsboro            #DCDCDC
HTMLcmenu GhostWhite           #F8F8FF
HTMLcmenu Gold                 #FFD700
HTMLcmenu Goldenrod            #DAA520
HTMLcmenu Gray                 #808080
HTMLcmenu Green                #008000
HTMLcmenu GreenYellow          #ADFF2F

HTMLcmenu Honeydew             #F0FFF0
HTMLcmenu HotPink              #FF69B4
HTMLcmenu IndianRed            #CD5C5C
HTMLcmenu Indigo               #4B0082
HTMLcmenu Ivory                #FFFFF0
HTMLcmenu Khaki                #F0E68C

HTMLcmenu Lavender             #E6E6FA
HTMLcmenu LavenderBlush        #FFF0F5
HTMLcmenu LawnGreen            #7CFC00
HTMLcmenu LemonChiffon         #FFFACD
HTMLcmenu LightBlue            #ADD8E6
HTMLcmenu LightCoral           #F08080
HTMLcmenu LightCyan            #E0FFFF
HTMLcmenu LightGoldenrodYellow #FAFAD2
HTMLcmenu LightGreen           #90EE90
HTMLcmenu LightGrey            #D3D3D3
HTMLcmenu LightPink            #FFB6C1
HTMLcmenu LightSalmon          #FFA07A
HTMLcmenu LightSeaGreen        #20B2AA
HTMLcmenu LightSkyBlue         #87CEFA
HTMLcmenu LightSlaTegray       #778899
HTMLcmenu LightSteelBlue       #B0C4DE
HTMLcmenu LightYellow          #FFFFE0
HTMLcmenu Lime                 #00FF00
HTMLcmenu LimeGreen            #32CD32
HTMLcmenu Linen                #FAF0E6

HTMLcmenu Magenta              #FF00FF
HTMLcmenu Maroon               #800000
HTMLcmenu MediumAquamarine     #66CDAA
HTMLcmenu MediumBlue           #0000CD
HTMLcmenu MediumOrchid         #BA55D3
HTMLcmenu MediumPurple         #9370DB
HTMLcmenu MediumSeaGreen       #3CB371
HTMLcmenu MediumSlateBlue      #7B68EE
HTMLcmenu MediumSpringGreen    #00FA9A
HTMLcmenu MediumTurquoise      #48D1CC
HTMLcmenu MediumVioletRed      #C71585
HTMLcmenu MidnightBlue         #191970
HTMLcmenu Mintcream            #F5FFFA
HTMLcmenu Mistyrose            #FFE4E1
HTMLcmenu Moccasin             #FFE4B5

HTMLcmenu NavajoWhite          #FFDEAD
HTMLcmenu Navy                 #000080
HTMLcmenu OldLace              #FDF5E6
HTMLcmenu Olive                #808000
HTMLcmenu OliveDrab            #6B8E23
HTMLcmenu Orange               #FFA500
HTMLcmenu OrangeRed            #FF4500
HTMLcmenu Orchid               #DA70D6

HTMLcmenu PaleGoldenrod        #EEE8AA
HTMLcmenu PaleGreen            #98FB98
HTMLcmenu PaleTurquoise        #AFEEEE
HTMLcmenu PaleVioletred        #DB7093
HTMLcmenu Papayawhip           #FFEFD5
HTMLcmenu Peachpuff            #FFDAB9
HTMLcmenu Peru                 #CD853F
HTMLcmenu Pink                 #FFC0CB
HTMLcmenu Plum                 #DDA0DD
HTMLcmenu PowderBlue           #B0E0E6
HTMLcmenu Purple               #800080

HTMLcmenu Red                  #FF0000
HTMLcmenu RosyBrown            #BC8F8F
HTMLcmenu RoyalBlue            #4169E1

HTMLcmenu SaddleBrown          #8B4513
HTMLcmenu Salmon               #FA8072
HTMLcmenu SandyBrown           #F4A460
HTMLcmenu SeaGreen             #2E8B57
HTMLcmenu Seashell             #FFF5EE
HTMLcmenu Sienna               #A0522D
HTMLcmenu Silver               #C0C0C0
HTMLcmenu SkyBlue              #87CEEB
HTMLcmenu SlateBlue            #6A5ACD
HTMLcmenu SlateGray            #708090
HTMLcmenu Snow                 #FFFAFA
HTMLcmenu SpringGreen          #00FF7F
HTMLcmenu SteelBlue            #4682B4

HTMLcmenu Tan                  #D2B48C
HTMLcmenu Teal                 #008080
HTMLcmenu Thistle              #D8BFD8
HTMLcmenu Tomato               #FF6347
HTMLcmenu Turquoise            #40E0D0
HTMLcmenu Violet               #EE82EE

" Font Styles menu:   {{{2

HTMLmenu imenu - HTML.Font\ &Styles.Bold      bo
HTMLmenu vmenu - HTML.Font\ &Styles.Bold      bo
HTMLmenu nmenu - HTML.Font\ &Styles.Bold      bo i
HTMLmenu imenu - HTML.Font\ &Styles.Strong    st
HTMLmenu vmenu - HTML.Font\ &Styles.Strong    st
HTMLmenu nmenu - HTML.Font\ &Styles.Strong    st i
HTMLmenu imenu - HTML.Font\ &Styles.Italics   it
HTMLmenu vmenu - HTML.Font\ &Styles.Italics   it
HTMLmenu nmenu - HTML.Font\ &Styles.Italics   it i
HTMLmenu imenu - HTML.Font\ &Styles.Emphasis  em
HTMLmenu vmenu - HTML.Font\ &Styles.Emphasis  em
HTMLmenu nmenu - HTML.Font\ &Styles.Emphasis  em i
HTMLmenu imenu - HTML.Font\ &Styles.Underline un
HTMLmenu vmenu - HTML.Font\ &Styles.Underline un
HTMLmenu nmenu - HTML.Font\ &Styles.Underline un i
HTMLmenu imenu - HTML.Font\ &Styles.Big       bi
HTMLmenu vmenu - HTML.Font\ &Styles.Big       bi
HTMLmenu nmenu - HTML.Font\ &Styles.Big       bi i
HTMLmenu imenu - HTML.Font\ &Styles.Small     sm
HTMLmenu vmenu - HTML.Font\ &Styles.Small     sm
HTMLmenu nmenu - HTML.Font\ &Styles.Small     sm i
 menu HTML.Font\ Styles.-sep1- <nul>
HTMLmenu imenu - HTML.Font\ &Styles.Font\ Size  fo
HTMLmenu vmenu - HTML.Font\ &Styles.Font\ Size  fo
HTMLmenu nmenu - HTML.Font\ &Styles.Font\ Size  fo i
HTMLmenu imenu - HTML.Font\ &Styles.Font\ Color fc
HTMLmenu vmenu - HTML.Font\ &Styles.Font\ Color fc
HTMLmenu nmenu - HTML.Font\ &Styles.Font\ Color fc i
 menu HTML.Font\ Styles.-sep2- <nul>
HTMLmenu imenu - HTML.Font\ &Styles.CITE           ci 
HTMLmenu vmenu - HTML.Font\ &Styles.CITE           ci 
HTMLmenu nmenu - HTML.Font\ &Styles.CITE           ci i
HTMLmenu imenu - HTML.Font\ &Styles.CODE           co 
HTMLmenu vmenu - HTML.Font\ &Styles.CODE           co 
HTMLmenu nmenu - HTML.Font\ &Styles.CODE           co i
HTMLmenu imenu - HTML.Font\ &Styles.Inserted\ Text in 
HTMLmenu vmenu - HTML.Font\ &Styles.Inserted\ Text in 
HTMLmenu nmenu - HTML.Font\ &Styles.Inserted\ Text in i
HTMLmenu imenu - HTML.Font\ &Styles.Deleted\ Text  de 
HTMLmenu vmenu - HTML.Font\ &Styles.Deleted\ Text  de 
HTMLmenu nmenu - HTML.Font\ &Styles.Deleted\ Text  de i
HTMLmenu imenu - HTML.Font\ &Styles.Emphasize      em 
HTMLmenu vmenu - HTML.Font\ &Styles.Emphasize      em 
HTMLmenu nmenu - HTML.Font\ &Styles.Emphasize      em i
HTMLmenu imenu - HTML.Font\ &Styles.Keyboard\ Text kb 
HTMLmenu vmenu - HTML.Font\ &Styles.Keyboard\ Text kb 
HTMLmenu nmenu - HTML.Font\ &Styles.Keyboard\ Text kb i
HTMLmenu imenu - HTML.Font\ &Styles.Sample\ Text   sa 
HTMLmenu vmenu - HTML.Font\ &Styles.Sample\ Text   sa 
HTMLmenu nmenu - HTML.Font\ &Styles.Sample\ Text   sa i
HTMLmenu imenu - HTML.Font\ &Styles.Strikethrough  sk 
HTMLmenu vmenu - HTML.Font\ &Styles.Strikethrough  sk 
HTMLmenu nmenu - HTML.Font\ &Styles.Strikethrough  sk i
HTMLmenu imenu - HTML.Font\ &Styles.STRONG         st 
HTMLmenu vmenu - HTML.Font\ &Styles.STRONG         st 
HTMLmenu nmenu - HTML.Font\ &Styles.STRONG         st i
HTMLmenu imenu - HTML.Font\ &Styles.Subscript      sb 
HTMLmenu vmenu - HTML.Font\ &Styles.Subscript      sb 
HTMLmenu nmenu - HTML.Font\ &Styles.Subscript      sb i
HTMLmenu imenu - HTML.Font\ &Styles.Superscript    sp 
HTMLmenu vmenu - HTML.Font\ &Styles.Superscript    sp 
HTMLmenu nmenu - HTML.Font\ &Styles.Superscript    sp i
HTMLmenu imenu - HTML.Font\ &Styles.Teletype\ Text tt 
HTMLmenu vmenu - HTML.Font\ &Styles.Teletype\ Text tt 
HTMLmenu nmenu - HTML.Font\ &Styles.Teletype\ Text tt i
HTMLmenu imenu - HTML.Font\ &Styles.Variable       va 
HTMLmenu vmenu - HTML.Font\ &Styles.Variable       va 
HTMLmenu nmenu - HTML.Font\ &Styles.Variable       va i


" Frames menu:   {{{2

HTMLmenu imenu - HTML.&Frames.FRAMESET fs
HTMLmenu vmenu - HTML.&Frames.FRAMESET fs
HTMLmenu nmenu - HTML.&Frames.FRAMESET fs i
HTMLmenu imenu - HTML.&Frames.FRAME    fr
HTMLmenu vmenu - HTML.&Frames.FRAME    fr
HTMLmenu nmenu - HTML.&Frames.FRAME    fr i
HTMLmenu imenu - HTML.&Frames.NOFRAMES nf
HTMLmenu vmenu - HTML.&Frames.NOFRAMES nf
HTMLmenu nmenu - HTML.&Frames.NOFRAMES nf i
HTMLmenu imenu - HTML.&Frames.IFRAME   if
HTMLmenu vmenu - HTML.&Frames.IFRAME   if
HTMLmenu nmenu - HTML.&Frames.IFRAME   if i


" Headings menu:   {{{2

HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 1 h1 
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 2 h2 
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 3 h3 
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 4 h4 
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 5 h5 
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 6 h6 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 1 h1 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 2 h2 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 3 h3 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 4 h4 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 5 h5 
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 6 h6 
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 1 h1 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 2 h2 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 3 h3 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 4 h4 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 5 h5 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 6 h6 i


" Lists menu:   {{{2

HTMLmenu imenu - HTML.&Lists.Ordered\ List    ol 
HTMLmenu vmenu - HTML.&Lists.Ordered\ List    ol 
HTMLmenu nmenu - HTML.&Lists.Ordered\ List    ol i
HTMLmenu imenu - HTML.&Lists.Unordered\ List  ul 
HTMLmenu vmenu - HTML.&Lists.Unordered\ List  ul 
HTMLmenu nmenu - HTML.&Lists.Unordered\ List  ul i
HTMLmenu imenu - HTML.&Lists.List\ Item       li 
HTMLmenu vmenu - HTML.&Lists.List\ Item       li 
HTMLmenu nmenu - HTML.&Lists.List\ Item       li i
 menu HTML.Lists.-sep1- <nul>
HTMLmenu imenu - HTML.&Lists.Definition\ List dl 
HTMLmenu vmenu - HTML.&Lists.Definition\ List dl 
HTMLmenu nmenu - HTML.&Lists.Definition\ List dl i
HTMLmenu imenu - HTML.&Lists.Definition\ Term dt 
HTMLmenu vmenu - HTML.&Lists.Definition\ Term dt
HTMLmenu nmenu - HTML.&Lists.Definition\ Term dt i
HTMLmenu imenu - HTML.&Lists.Definition\ Body dd 
HTMLmenu vmenu - HTML.&Lists.Definition\ Body dd
HTMLmenu nmenu - HTML.&Lists.Definition\ Body dd i


" Tables menu:   {{{2

HTMLmenu nmenu - HTML.&Tables.Interactive\ Table      tA 
HTMLmenu imenu - HTML.&Tables.TABLE                   ta 
HTMLmenu vmenu - HTML.&Tables.TABLE                   ta 
HTMLmenu nmenu - HTML.&Tables.TABLE                   ta i
HTMLmenu imenu - HTML.&Tables.Header\ Row             tH 
HTMLmenu vmenu - HTML.&Tables.Header\ Row             tH 
HTMLmenu nmenu - HTML.&Tables.Header\ Row             tH i
HTMLmenu imenu - HTML.&Tables.Row                     tr 
HTMLmenu vmenu - HTML.&Tables.Row                     tr 
HTMLmenu nmenu - HTML.&Tables.Row                     tr i
HTMLmenu imenu - HTML.&Tables.Footer\ Row             tf 
HTMLmenu vmenu - HTML.&Tables.Footer\ Row             tf 
HTMLmenu nmenu - HTML.&Tables.Footer\ Row             tf i
HTMLmenu imenu - HTML.&Tables.Column\ Header          th 
HTMLmenu vmenu - HTML.&Tables.Column\ Header          th 
HTMLmenu nmenu - HTML.&Tables.Column\ Header          th i
HTMLmenu imenu - HTML.&Tables.Data\ (Column\ Element) td 
HTMLmenu vmenu - HTML.&Tables.Data\ (Column\ Element) td 
HTMLmenu nmenu - HTML.&Tables.Data\ (Column\ Element) td i
HTMLmenu imenu - HTML.&Tables.CAPTION                 ca 
HTMLmenu vmenu - HTML.&Tables.CAPTION                 ca 
HTMLmenu nmenu - HTML.&Tables.CAPTION                 ca i


" Forms menu:   {{{2

HTMLmenu imenu - HTML.F&orms.FORM             fm
HTMLmenu vmenu - HTML.F&orms.FORM             fm
HTMLmenu nmenu - HTML.F&orms.FORM             fm i
HTMLmenu imenu - HTML.F&orms.BUTTON           bu
HTMLmenu vmenu - HTML.F&orms.BUTTON           bu
HTMLmenu nmenu - HTML.F&orms.BUTTON           bu i
HTMLmenu imenu - HTML.F&orms.CHECKBOX         ch
HTMLmenu vmenu - HTML.F&orms.CHECKBOX         ch
HTMLmenu nmenu - HTML.F&orms.CHECKBOX         ch i
HTMLmenu imenu - HTML.F&orms.RADIO            ra
HTMLmenu vmenu - HTML.F&orms.RADIO            ra
HTMLmenu nmenu - HTML.F&orms.RADIO            ra i
HTMLmenu imenu - HTML.F&orms.HIDDEN           hi
HTMLmenu vmenu - HTML.F&orms.HIDDEN           hi
HTMLmenu nmenu - HTML.F&orms.HIDDEN           hi i
HTMLmenu imenu - HTML.F&orms.EMAIL            @
HTMLmenu vmenu - HTML.F&orms.EMAIL            @
HTMLmenu nmenu - HTML.F&orms.EMAIL            @ i
HTMLmenu imenu - HTML.F&orms.NUMBER           nu
HTMLmenu vmenu - HTML.F&orms.NUMBER           nu
HTMLmenu nmenu - HTML.F&orms.NUMBER           nu i
HTMLmenu imenu - HTML.F&orms.PASSWORD         pa
HTMLmenu vmenu - HTML.F&orms.PASSWORD         pa
HTMLmenu nmenu - HTML.F&orms.PASSWORD         pa i
HTMLmenu imenu - HTML.F&orms.TEL              #
HTMLmenu vmenu - HTML.F&orms.TEL              #
HTMLmenu nmenu - HTML.F&orms.TEL              # i
HTMLmenu imenu - HTML.F&orms.URL              ur
HTMLmenu vmenu - HTML.F&orms.URL              ur
HTMLmenu nmenu - HTML.F&orms.URL              ur i
HTMLmenu imenu - HTML.F&orms.TEXT             te
HTMLmenu vmenu - HTML.F&orms.TEXT             te
HTMLmenu nmenu - HTML.F&orms.TEXT             te i
HTMLmenu imenu - HTML.F&orms.FILE             fi
HTMLmenu vmenu - HTML.F&orms.FILE             fi
HTMLmenu nmenu - HTML.F&orms.FILE             fi i
HTMLmenu imenu - HTML.F&orms.SELECT           se
HTMLmenu vmenu - HTML.F&orms.SELECT           se
HTMLmenu nmenu - HTML.F&orms.SELECT           se i
HTMLmenu imenu - HTML.F&orms.SELECT\ MULTIPLE ms 
HTMLmenu vmenu - HTML.F&orms.SELECT\ MULTIPLE ms 
HTMLmenu nmenu - HTML.F&orms.SELECT\ MULTIPLE ms i
HTMLmenu imenu - HTML.F&orms.OPTION           op
HTMLmenu vmenu - HTML.F&orms.OPTION           op
HTMLmenu nmenu - HTML.F&orms.OPTION           op i
HTMLmenu imenu - HTML.F&orms.OPTGROUP         og
HTMLmenu vmenu - HTML.F&orms.OPTGROUP         og
HTMLmenu nmenu - HTML.F&orms.OPTGROUP         og i
HTMLmenu imenu - HTML.F&orms.TEXTAREA         tx
HTMLmenu vmenu - HTML.F&orms.TEXTAREA         tx
HTMLmenu nmenu - HTML.F&orms.TEXTAREA         tx i
HTMLmenu imenu - HTML.F&orms.SUBMIT           su
HTMLmenu nmenu - HTML.F&orms.SUBMIT           su i
HTMLmenu imenu - HTML.F&orms.RESET            re
HTMLmenu nmenu - HTML.F&orms.RESET            re i
HTMLmenu imenu - HTML.F&orms.LABEL            la
HTMLmenu vmenu - HTML.F&orms.LABEL            la
HTMLmenu nmenu - HTML.F&orms.LABEL            la i

" }}}2

" HTML 5 Tags Menu: {{{2
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.AS&IDE                  as
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.AS&IDE                  as
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.AS&IDE                  as i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ summary ds
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ summary ds
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ summary ds i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&EMBED                  eb
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&EMBED                  eb
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&EMBED                  eb i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&HEADER                 hd
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&HEADER                 hd
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&HEADER                 hd i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&MAIN                   ma
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&MAIN                   ma
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&MAIN                   ma i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.MA&RK                   mk
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.MA&RK                   mk
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.MA&RK                   mk i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.METE&R                  mt
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.METE&R                  mt
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.METE&R                  mt i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&NAV                    na
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&NAV                    na
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&NAV                    na i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&SECTION                sc
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&SECTION                sc
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&SECTION                sc i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&TIME                   tm
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&TIME                   tm
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&TIME                   tm i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&WBR                    wb
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&WBR                    wb i
" }}}2

 menu HTML.-sep6- <nul>

HTMLmenu nmenu - HTML.Doctype\ (4\.01\ transitional) 4 
HTMLmenu nmenu - HTML.Doctype\ (4\.01\ strict)       s4 
HTMLmenu nmenu - HTML.Doctype\ (HTML\ 5)             5
HTMLmenu imenu - HTML.Content-Type                   ct 
HTMLmenu nmenu - HTML.Content-Type                   ct i

 menu HTML.-sep7- <nul>

HTMLmenu imenu - HTML.BODY             bd
HTMLmenu vmenu - HTML.BODY             bd
HTMLmenu nmenu - HTML.BODY             bd i
HTMLmenu imenu - HTML.BUTTON           bn
HTMLmenu vmenu - HTML.BUTTON           bn
HTMLmenu nmenu - HTML.BUTTON           bn i
HTMLmenu imenu - HTML.CENTER           ce
HTMLmenu vmenu - HTML.CENTER           ce
HTMLmenu nmenu - HTML.CENTER           ce i
HTMLmenu imenu - HTML.Comment          cm
HTMLmenu vmenu - HTML.Comment          cm
HTMLmenu nmenu - HTML.Comment          cm i
HTMLmenu imenu - HTML.HEAD             he
HTMLmenu vmenu - HTML.HEAD             he
HTMLmenu nmenu - HTML.HEAD             he i
HTMLmenu imenu - HTML.Horizontal\ Rule hr
HTMLmenu nmenu - HTML.Horizontal\ Rule hr i
HTMLmenu imenu - HTML.HTML             ht
HTMLmenu vmenu - HTML.HTML             ht
HTMLmenu nmenu - HTML.HTML             ht i
HTMLmenu imenu - HTML.Hyperlink        ah
HTMLmenu vmenu - HTML.Hyperlink        ah
HTMLmenu nmenu - HTML.Hyperlink        ah i
HTMLmenu imenu - HTML.Inline\ Image    im 
HTMLmenu vmenu - HTML.Inline\ Image    im 
HTMLmenu nmenu - HTML.Inline\ Image    im i
if exists("*MangleImageTag")
  HTMLmenu imenu - HTML.Update\ Image\ Size\ Attributes mi 
  HTMLmenu vmenu - HTML.Update\ Image\ Size\ Attributes mi <ESC>
  HTMLmenu nmenu - HTML.Update\ Image\ Size\ Attributes mi 
endif
HTMLmenu imenu - HTML.Line\ Break        br 
HTMLmenu nmenu - HTML.Line\ Break        br i
HTMLmenu imenu - HTML.Named\ Anchor      an 
HTMLmenu vmenu - HTML.Named\ Anchor      an 
HTMLmenu nmenu - HTML.Named\ Anchor      an i
HTMLmenu imenu - HTML.Paragraph          pp 
HTMLmenu vmenu - HTML.Paragraph          pp 
HTMLmenu nmenu - HTML.Paragraph          pp i
HTMLmenu imenu - HTML.Preformatted\ Text pr 
HTMLmenu vmenu - HTML.Preformatted\ Text pr 
HTMLmenu nmenu - HTML.Preformatted\ Text pr i
HTMLmenu imenu - HTML.TITLE              ti 
HTMLmenu vmenu - HTML.TITLE              ti 
HTMLmenu nmenu - HTML.TITLE              ti i

HTMLmenu imenu - HTML.&More\.\.\..ADDRESS                   ad 
HTMLmenu vmenu - HTML.&More\.\.\..ADDRESS                   ad 
HTMLmenu nmenu - HTML.&More\.\.\..ADDRESS                   ad i
HTMLmenu imenu - HTML.&More\.\.\..BASE\ HREF                bh 
HTMLmenu vmenu - HTML.&More\.\.\..BASE\ HREF                bh 
HTMLmenu nmenu - HTML.&More\.\.\..BASE\ HREF                bh i
HTMLmenu imenu - HTML.&More\.\.\..BASE\ TARGET              bt 
HTMLmenu vmenu - HTML.&More\.\.\..BASE\ TARGET              bt 
HTMLmenu nmenu - HTML.&More\.\.\..BASE\ TARGET              bt i
HTMLmenu imenu - HTML.&More\.\.\..BLOCKQUTE                 bl 
HTMLmenu vmenu - HTML.&More\.\.\..BLOCKQUTE                 bl 
HTMLmenu nmenu - HTML.&More\.\.\..BLOCKQUTE                 bl i
HTMLmenu imenu - HTML.&More\.\.\..Defining\ Instance        df 
HTMLmenu vmenu - HTML.&More\.\.\..Defining\ Instance        df 
HTMLmenu nmenu - HTML.&More\.\.\..Defining\ Instance        df i
HTMLmenu imenu - HTML.&More\.\.\..Document\ Division        dv 
HTMLmenu vmenu - HTML.&More\.\.\..Document\ Division        dv 
HTMLmenu nmenu - HTML.&More\.\.\..Document\ Division        dv i
HTMLmenu imenu - HTML.&More\.\.\..JavaScript                js
HTMLmenu nmenu - HTML.&More\.\.\..JavaScript                js i
HTMLmenu imenu - HTML.&More\.\.\..Sourced\ JavaScript       sj 
HTMLmenu nmenu - HTML.&More\.\.\..Sourced\ JavaScript       sj i
HTMLmenu imenu - HTML.&More\.\.\..LINK\ HREF                lk 
HTMLmenu vmenu - HTML.&More\.\.\..LINK\ HREF                lk 
HTMLmenu nmenu - HTML.&More\.\.\..LINK\ HREF                lk i
HTMLmenu imenu - HTML.&More\.\.\..META                      me 
HTMLmenu vmenu - HTML.&More\.\.\..META                      me 
HTMLmenu nmenu - HTML.&More\.\.\..META                      me i
HTMLmenu imenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh 
HTMLmenu vmenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh 
HTMLmenu nmenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh i
HTMLmenu imenu - HTML.&More\.\.\..NOSCRIPT                  nj 
HTMLmenu vmenu - HTML.&More\.\.\..NOSCRIPT                  nj 
HTMLmenu nmenu - HTML.&More\.\.\..NOSCRIPT                  nj i
HTMLmenu imenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob 
HTMLmenu vmenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob 
HTMLmenu nmenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob i
HTMLmenu imenu - HTML.&More\.\.\..Object\ Parameter         pm 
HTMLmenu vmenu - HTML.&More\.\.\..Object\ Parameter         pm 
HTMLmenu nmenu - HTML.&More\.\.\..Object\ Parameter         pm i
HTMLmenu imenu - HTML.&More\.\.\..Quoted\ Text              qu 
HTMLmenu vmenu - HTML.&More\.\.\..Quoted\ Text              qu 
HTMLmenu nmenu - HTML.&More\.\.\..Quoted\ Text              qu i
HTMLmenu imenu - HTML.&More\.\.\..SPAN                      sn 
HTMLmenu vmenu - HTML.&More\.\.\..SPAN                      sn 
HTMLmenu nmenu - HTML.&More\.\.\..SPAN                      sn i
HTMLmenu imenu - HTML.&More\.\.\..STYLE\ (Inline\ CSS\)     cs 
HTMLmenu vmenu - HTML.&More\.\.\..STYLE\ (Inline\ CSS\)     cs 
HTMLmenu nmenu - HTML.&More\.\.\..STYLE\ (Inline\ CSS\)     cs i
HTMLmenu imenu - HTML.&More\.\.\..Linked\ CSS               ls 
HTMLmenu vmenu - HTML.&More\.\.\..Linked\ CSS               ls 
HTMLmenu nmenu - HTML.&More\.\.\..Linked\ CSS               ls i

let g:did_html_menus = 1
endif
" ---------------------------------------------------------------------------


" ---- Clean Up: -------------------------------------------------------- {{{1

if exists('s:browsers')
  unlet s:browsers
endif

if exists(':HTMLmenu')
  delcommand HTMLmenu
  delfunction s:LeadMenu
endif

if exists(':HTMLemenu')
  delcommand HTMLemenu
  delfunction s:EntityMenu
endif

if exists(':HTMLcmenu')
  delcommand HTMLcmenu
  delfunction s:ColorsMenu
  unlet s:colors_sort
endif

let &cpoptions = s:savecpo
unlet s:savecpo

unlet s:doing_internal_html_mappings

" vim:ts=2:sw=2:expandtab:tw=78:fo=croq2j:comments=b\:\":
" vim:fdm=marker:fdc=4:cms=\ "\ %s:sw=0:
