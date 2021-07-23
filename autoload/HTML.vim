vim9script
scriptencoding utf8

if v:versionlong < 8023182
  finish
endif

# Various functions for the HTML.vim filetype plugin.
#
# Last Change: July 22, 2021
#
# Requirements:
#       Vim 9 or later
#
# Copyright (C) 2004-2020 Christian J. Robinson <heptite@gmail.com>
#
# This program is free software; you can  redistribute  it  and/or  modify  it
# under the terms of the GNU General Public License as published by  the  Free
# Software Foundation; either version 3 of the License, or  (at  your  option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but  WITHOUT
# ANY WARRANTY; without  even  the  implied  warranty  of  MERCHANTABILITY  or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General  Public  License  for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place  -  Suite  330,  Boston,  MA  02111-1307,  USA.   Or  you  can  go  to
# https://www.gnu.org/licenses/licenses.html#GPL

if exists(':HTMLWARN') != 2
  command! -nargs=+ HTMLWARN :echohl WarningMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLMESG :echohl Todo | echo <q-args> | echohl None
endif

# g:HTML#SetIfUnset()  {{{1
#
# Set a variable if it's not already set. Cannot be used for script-local
# variables.
#
# Arguments:
#  1       - String:  The variable name
#  2 ... N - String:  The default value to use
# Return Value:
#  0  - The variable already existed
#  1  - The variable didn't exist and was successfully set
#  -1 - An error occurred
def g:HTML#SetIfUnset(variable: string, ...args: list<any>): number
  var val: any
  var newvariable = variable

  if variable =~# '^l:'
    execute 'HTMLERROR Cannot set a local variable with ' .. expand('<sfile>')
    return -1
  elseif variable !~# '^[bgstvw]:'
    newvariable = 'g:' .. variable
  endif

  if args->len() == 0
    execute 'HTMLERROR E119: Not enough arguments for ' .. expand('<sfile>')
    return -1
  elseif type(args[0]) == type([]) || type(args[0]) == type({})
    val = args[0]
  else
    val = args->join(' ')
  endif

  if newvariable->s:IsSet()
    return 0
  endif

  if type(val) == type('')
    if val == '""' || val == "''"
      execute newvariable .. ' = ""'
    elseif val == '[]'
      execute newvariable .. ' = []'
    elseif val == '{}'
      execute newvariable .. ' = {}'
    else
      execute newvariable .. " = '" .. val->escape("'\\") .. "'"
    endif
  else
    # Unfortunately this is a suboptimal way to do this, but Vim9script
    # doesn't allow me to do it any other way:
    g:tmpvarval = val
    execute newvariable .. ' = g:tmpvarval'
    unlet g:tmpvarval
  endif

  return 1
enddef

# g:HTML#BoolVar()  {{{1
#
# Given a string, test to see if a variable by that string name exists, and if
# so, whether it's set to 1|true|yes / 0|false|no   (Actually, anything not
# listed here also returns as 1.)
#
# Arguments:
#  1 - String:  The name of the variable to test (not its value!)
# Return Value:
#  1/0
#
# Limitations:
#  This /will not/ work on function-local variable names.
def g:HTML#BoolVar(variable: string): bool
  var newvariable = variable

  if variable !~ '^[bgstvw]:'
    newvariable = "g:" .. variable
  endif

  if newvariable->s:IsSet()
    # Unfortunately this is a suboptimal way to do this, but Vim9script
    # doesn't allow me to do it any other way:
    execute 'g:tmpvarval = ' .. newvariable
    var varval = g:tmpvarval .. ''
    unlet g:tmpvarval
    return varval->s:Bool()
  else
    return false
  endif
enddef

# s:Bool() {{{1
#
# Helper to g:HTML#BoolVar() -- Test the string passed to it and
# return true/false based on that string.
#
# Arguments:
#  1 - String:  1|true|yes / 0|false|no
# Return Value:
#  1/0
def s:Bool(str: string): bool
  return str !~? '^no$\|^\(v:\)\?false$\|^0$\|^$'
enddef

# s:IsSet() {{{1
#
# Given a string, test to see if a variable by that string name exists.
#
# Arguments:
#  1 - String:  The variable name
# Return Value:
#  1/0
def s:IsSet(str: string): bool
  if str != ''
    return exists(str) != 0
  else
    return false
  endif
enddef

# g:HTML#FilesWithMatch()  {{{1
#
# Create a list of files that have contents matching a pattern.
#
# Arguments:
#  1 - List:    The files to search
#  2 - String:  The pattern to search for
#  2 - Integer: Optional, the number of lines to search before giving up 
# Return Value:
#  List:  Matching files
def g:HTML#FilesWithMatch(files: list<string>, pat: string, max: number = -1): list<string>
  var inc: number
  var matched: list<string>
  matched = []

  for file in files
    inc = 0
    for line in file->readfile()
      if line =~ pat
        matched->add(file->fnamemodify(':p'))
        break
      endif
      inc += 1
      if max > 0 && inc >= max
        break
      endif
    endfor
  endfor

  return matched
enddef

# g:HTML#EncodeString()  {{{1
#
# Encode the characters in a string to/from their HTML representations.
#
# Arguments:
#  1 - String:  The string to encode/decode.
#  2 - String:  Optional, whether to decode rather than encode the string:
#               - d/decode: Decode the %XX, &#...;, and &#x...; elements of
#                           the provided string
#               - %:        Encode as a %XX string
#               - x:        Encode as a &#x...; string
#               - omitted:  Encode as a &#...; string
#               - other:    No change to the string
# Return Value:
#  String:  The encoded string.
def g:HTML#EncodeString(str: string, decode: string = ''): string
  var out = str

  if decode == ''
    out = out->substitute('.', '\=printf("&#%d;",  submatch(0)->char2nr())', 'g')
  elseif decode == 'x'
    out = out->substitute('.', '\=printf("&#x%x;", submatch(0)->char2nr())', 'g')
  elseif decode == '%'
    out = out->substitute('[\x00-\x99]', '\=printf("%%%02X", submatch(0)->char2nr())', 'g')
  elseif decode =~? '^d\(ecode\)\=$'
    out = out->substitute('\(&#x\x\+;\|&#\d\+;\|%\x\x\)', '\=submatch(1)->g:HTML#DecodeSymbol()', 'g')
  endif

  return out
enddef

# g:HTML#DecodeSymbol()  {{{1
#
# Decode the HTML symbol string to its literal character counterpart
#
# Arguments:
#  1 - String:  The string to decode.
# Return Value:
#  Character:  The decoded character.
def g:HTML#DecodeSymbol(symbol: string): string
  var char: string

  if symbol =~ '&#\(x\x\+\);'
    char = symbol->strpart(2, symbol->strlen() - 3)->str2nr(8)->nr2char()
  elseif symbol =~ '&#\(\d\+\);'
    char = symbol->strpart(2, symbol->strlen() - 3)->str2nr()->nr2char()
  elseif symbol =~ '%\(\x\x\)'
    char = symbol->strpart(1, symbol->strlen() - 1)->str2nr(16)->nr2char()
  else
    char = symbol
  endif

  return char
enddef

# g:HTML#Map()  {{{1
#
# Define the HTML mappings with the appropriate case, plus some extra stuff.
#
# Arguments:
#  1 - String:  Which map command to run.
#  2 - String:  LHS of the map.
#  3 - String:  RHS of the map.
#  4 - Integer: Optional, applies only to visual maps:
#                -1: Don't add any extra special code to the mapping.
#                 0: Mapping enters insert mode.
#               Applies only when filetype indenting is on:
#                 1: re-selects the region, moves down a line, and re-indents.
#                 2: re-selects the region and re-indents.
#                 (Don't use these two arguments for maps that enter insert
#                 mode!)
const MODES = {  # {{{
      'n': 'normal',
      'v': 'visual',
      'o': 'operator-pending',
      'i': 'insert',
      'c': 'command-line',
      'l': 'langmap',
    }  # }}}

def g:HTML#Map(cmd: string, map: string, arg: string, extra: number = -999)
  if exists('g:html_map_leader') == 0 && map =~? '^<lead>'
    HTMLERROR g:html_map_leader is not set! No mapping defined.
    return
  endif

  if exists('g:html_map_entity_leader') == 0 && map =~? '^<elead>'
    HTMLERROR g:html_map_entity_leader is not set! No mapping defined.
    return
  endif

  var mode = cmd->strpart(0, 1)
  var newarg = arg
  var newmap = map->substitute('^<lead>\c', g:html_map_leader->escape('&~\'), '')
  newmap = newmap->substitute('^<elead>\c', g:html_map_entity_leader->escape('&~\'), '')

  if MODES->has_key(mode) && newmap->s:MapCheck(mode) >= 2
    return
  endif

  newarg = newarg->g:HTML#ConvertCase()

  if g:HTML#BoolVar('b:do_xhtml_mappings') == false
    newarg = newarg->substitute(' \?/>', '>', 'g')
  endif

  if mode == 'v'
    # If 'selection' is "exclusive" all the visual mode mappings need to
    # behave slightly differently:
    newarg = newarg->substitute("`>a\\C", "`>i<C-R>=g:HTML#VI()<CR>", 'g')

    # Note that <C-c>:-command is necessary instead of just <Cmd> because
    # <Cmd> doesn't update visual marks, which the mappings rely on:
    if extra < 0 && extra != -999
      execute cmd .. " <buffer> <silent> " .. newmap .. " " .. newarg
    elseif extra >= 1
      execute cmd .. " <buffer> <silent> " .. newmap .. " <C-c>:eval g:HTML#TO(v:false)<CR>gv" .. newarg
        .. ":eval g:HTML#TO(v:true)<CR>m':eval g:HTML#ReIndent(line(\"'<\"), line(\"'>\"), " .. extra .. ")<CR>``"
    elseif extra == 0
      execute cmd .. " <buffer> <silent> " .. newmap .. " <C-c>:eval g:HTML#TO(v:false)<CR>gv" .. newarg
        .. "<C-O>:eval g:HTML#TO(v:true)<CR>"
    else
      execute cmd .. " <buffer> <silent> " .. newmap .. " <C-c>:eval g:HTML#TO(v:false)<CR>gv" .. newarg
        .. ":eval g:HTML#TO(v:true)<CR>"
    endif
  else
    execute cmd .. " <buffer> <silent> " .. newmap .. " " .. newarg
  endif

  if MODES->has_key(mode)
    add(b:HTMLclearMappings, ':' .. mode .. "unmap <buffer> " .. newmap)
  else
    add(b:HTMLclearMappings, ":unmap <buffer> " .. newmap)
  endif

  # Save extra mappings so they can be restored if we need to later:
  s:ExtraMappingsAdd(':eval g:HTML#Map("' .. cmd .. '", "' .. map->escape('"\')
        .. '", "' .. arg->escape('"\') .. (extra != -999 ? ('", ' .. extra) : '"' ) .. ')')
enddef

# g:HTML#Mapo()  {{{1
#
# Define a normal mode map that takes an operator and assign it to its
# corresponding visual mode mapping.
#
# Arguments:
#  1 - String:  The mapping.
#  2 - Boolean: Whether to enter insert mode after the mapping has executed.
#               (A value greater than 1 tells the mapping not to move right one
#               character.)
def g:HTML#Mapo(map: string, insert: bool)
  if exists('g:html_map_leader') == 0 && map =~? '^<lead>'
    HTMLERROR g:html_map_leader is not set! No mapping defined.
    return
  endif

  var newmap = map->substitute("^<lead>", g:html_map_leader, '')

  if newmap->s:MapCheck('o') >= 2
    return
  endif

  execute 'nnoremap <buffer> <silent> ' .. newmap
    .. " :let b:htmltagaction='" .. newmap .. "'<CR>"
    .. ":let b:htmltaginsert=" .. insert .. "<CR>"
    .. ':set operatorfunc=g:HTML#WR<CR>g@'

  add(b:HTMLclearMappings, ":nunmap <buffer> " .. newmap)
  s:ExtraMappingsAdd(':eval g:HTML#Mapo("' .. map->escape('"\') .. '", ' .. insert .. ')')
enddef

# s:MapCheck()  {{{1
#
# Check to see if a mapping for a mode already exists.  If there is, and
# overriding hasn't been suppressed, print an error.
#
# Arguments:
#  1 - String:    The map sequence (LHS).
#  2 - Character: The mode for the mapping.
# Return Value:
#  0 - No mapping was found.
#  1 - A mapping was found, but overriding has /not/ been suppressed.
#  2 - A mapping was found and overriding has been suppressed.
#  3 - The mapping to be defined was suppressed by g:no_html_maps.
#
# (Note that suppression only works for the internal mappings.)
def s:MapCheck(map: string, mode: string): number
  if g:doing_internal_html_mappings &&
        ( (exists('g:no_html_maps') && map =~# g:no_html_maps) ||
          (exists('b:no_html_maps') && map =~# b:no_html_maps) )
    return 3
  elseif MODES->has_key(mode) && map->maparg(mode) != ''
    if g:HTML#BoolVar('g:no_html_map_override') && g:doing_internal_html_mappings
      return 2
    else
      execute "HTMLWARN WARNING: A mapping to \"" .. map .. "\" for " .. MODES[mode] .. " mode has been overridden for this buffer."
      return 1
    endif
  endif

  return 0
enddef

# g:HTML#SI()  {{{1
#
# 'Escape' special characters with a control-v so Vim doesn't handle them as
# special keys during insertion.  For use in <C-R>=... type calls in mappings.
#
# Arguments:
#  1 - String: The string to escape.
# Return Value:
#  String: The 'escaped' string.
#
# Limitations:
#  Null strings have to be left unescaped, due to a limitation in Vim itself.
#  (VimL represents newline characters as nulls...ouch.)
def g:HTML#SI(str: string): string
  return str->substitute('[^\x00\x20-\x7E]', '\="\x16" .. submatch(0)', 'g')
enddef

# g:HTML#WR()  {{{1
# Function set in 'operatorfunc' for mappings that take an operator:
def g:HTML#WR(type: string)
  var sel_save = &selection
  &selection = "inclusive"

  if type == 'line'
    execute "normal `[V`]" .. b:htmltagaction
  elseif type == 'block'
    execute "normal `[\<C-V>`]" .. b:htmltagaction
  else
    execute "normal `[v`]" .. b:htmltagaction
  endif

  &selection = sel_save

  if b:htmltaginsert
    if b:htmltaginsert < 2
      execute "normal \<Right>"
    endif
    silent startinsert
  endif
enddef

# s:ExtraMappingsAdd()  {{{1
#
# Add to the b:HTMLextraMappings variable if necessary.
#
# Arguments:
#  1 - String: The command necessary to re-define the mapping.
def s:ExtraMappingsAdd(arg: string)
  if ! g:doing_internal_html_mappings && ! doing_extra_html_mappings
    if ! exists('b:HTMLextraMappings')
      b:HTMLextraMappings = []
    endif
    add(b:HTMLextraMappings, arg)
  endif
enddef

# g:HTML#TO()  {{{1
#
# Used to make sure the 'showmatch', 'indentexpr', and 'formatoptions' options
# are off temporarily to prevent the visual mappings from causing a
# (visual)bell or inserting improperly.
#
# Arguments:
#  1 - Boolean: false - Turn options off.
#               true  - Turn options back on, if they were on before.
var savesm: bool
var saveinde: string
var savefo: string
var visualmode_save: string
def g:HTML#TO(which: bool)
  if which
    &l:sm = savesm
    &l:inde = saveinde
    &l:fo = savefo

    # Restore the last visual mode if it was changed:
    if visualmode_save != ''
      execute "normal gv" .. visualmode_save .. "\<C-C>"
      visualmode_save = ''
    endif
  else
    savesm = &l:sm | &l:sm = false
    saveinde = &l:inde | &l:inde = ''
    savefo = &l:fo | &l:fo = ''

    # A trick to make leading indent on the first line of visual-line
    # selections is handled properly (turn it into a character-wise
    # selection and exclude the leading indent):
    if visualmode() ==# 'V'
      visualmode_save = visualmode()
      execute "normal `<^v`>\<C-C>"
    endif
  endif
enddef

# g:HTML#TC()  {{{1
#
# Used to make sure the 'comments' option is off temporarily to prevent
# certain mappings from inserting unwanted comment leaders.
#
# Arguments:
#  1 - Boolean: false - Turn option off.
#               true  - Turn option back on, if they were on before.
var savecom: string
def g:HTML#TC(s: bool)
  if s
    &l:com = savecom
  else
    savecom = &l:com | &l:com = ''
  endif
enddef

# g:HTML#ToggleClipboard()  {{{1
#
# Used to turn off/on the inclusion of "html" in the 'clipboard' option when
# switching buffers.
#
# Arguments:
#  1 - Integer: 0 - Remove 'html' if it was removed before.
#               1 - Add 'html'.
#               2 - Auto detect which to do.
#
# (Note that savecb is set by this script's initialization.)
def g:HTML#ToggleClipboard(i: number)
  var newi = i

  if newi == 2
    if exists("b:did_html_mappings")
      newi = 1
    else
      newi = 0
    endif
  endif

  if newi == 0
    if exists('g:html_save_clipboard') != 0
      &clipboard = g:html_save_clipboard
    else
      HTMLERROR Somehow the html_save_clipboard global variable did not get set.
    endif
  else
    if &clipboard !~? 'html'
      g:html_save_clipboard = &clipboard
    endif
    silent! set clipboard+=html
  endif
enddef

# g:HTML#VI()  {{{1
#
# Used by g:HTML#Map() to enter insert mode in Visual mappings in the
# right place, depending on what 'selection' is set to.
#
# Arguments:
#   None
# Return Value:
#   The proper movement command based on the value of 'selection'.
def g:HTML#VI(): string
  if &selection == 'inclusive'
    return "\<right>"
  else
    return "\<C-O>`>"
  endif
enddef

# g:HTML#ConvertCase()  {{{1
#
# Convert special regions in a string to the appropriate case determined by
# b:html_tag_case.
#
# Arguments:
#  1 - String: The string with the regions to convert surrounded by [{...}].
# Return Value:
#  The converted string.
def g:HTML#ConvertCase(str: string): string
  var newstr = str

  if ! exists('b:html_tag_case')
    b:html_tag_case = g:html_tag_case
  endif

  if b:html_tag_case =~? '^u\(pper\(case\)\?\)\?'
    newstr = newstr->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g')
  elseif b:html_tag_case =~? '^l\(ower\(case\)\?\)\?'
    newstr = newstr->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g')
  else
    execute "HTMLWARN WARNING: b:html_tag_case = '" .. b:html_tag_case .. "' invalid, overriding to 'lowercase'."
    b:html_tag_case = 'lowercase'
    newstr = newstr->g:HTML#ConvertCase()
  endif

  return newstr
enddef

# g:HTML#ReIndent()  {{{1
#
# Re-indent a region.  (Usually called by g:HTML#Map.)
#  Nothing happens if filetype indenting isn't enabled or 'indentexpr' is
#  unset.
#
# Arguments:
#  1 - Integer: Start of region.
#  2 - Integer: End of region.
#  3 - Integer: 1: Add an extra line below the region to re-indent.
#               *: Don't add an extra line.
var filetype_output: string
def g:HTML#ReIndent(first: number, last: number, extraline: number)
  var firstline: number
  var lastline: number

  # To find out if filetype indenting is enabled:
  silent! redir =>filetype_output | silent! filetype | redir END

  if filetype_output =~ "indent:OFF" && &indentexpr == ''
    return
  endif

  # Make sure the range is in the proper order:
  if last >= first
    firstline = first
    lastline = last
  else
    lastline = first
    firstline = last
  endif

  # Make sure the full region to be re-indendted is included:
  if extraline == 1
    if firstline == lastline
      lastline = lastline + 2
    else
      lastline = lastline + 1
    endif
  endif

  execute ':' .. firstline .. ',' .. lastline .. 'norm =='
enddef

# s:ByteOffset()  {{{1
#
# Return the byte number of the current position.
#
# Arguments (optional):
#  Either:
#   1 - Mark: The mark name to convert to offset, preceded by a ' (single
#             quote character)
#  Or:
#   1 - Number: The line to get the byte offset from
#   2 - Number: The column of the specified line to get the byte offset from
# Return Value:
#  The byte offset, a negative value means the specified mark is not set.
def s:ByteOffset(lineormark: any = -1, column: number = -1): number
  if type(lineormark) == 1 && lineormark =~ "^'.$"
    return lineormark->line()->line2byte() + lineormark->col() - 1
  elseif type(lineormark) == 0 && lineormark < 0 && column < 0
    return line('.')->line2byte() + col('.') - 1
  elseif type(lineormark) == 0 && lineormark > 0 && column > 0
    return lineormark->line2byte() + column - 1
  else
    execute 'HTMLERROR Invalid argument(s) for ' .. expand('<sfile>')
    return -1
  endif
enddef

# g:HTML#NextInsertPoint()  {{{1
#
# Position the cursor at the next point in the file that needs data.
#
# Arguments:
#  1 - Character: Optional, the mode the function is being called from. 'n'
#                 for normal, 'i' for insert.  If 'i' is used the function
#                 enables an extra feature where if the cursor is on the start
#                 of a closing tag it places the cursor after the tag.
#                 Default is 'n'.
# Return Value:
#  None.
# Known Limitations:
#  It is impossible to cycle through all of the unfilled tags in a file; the
#  cursor will just jump back to the nearest unfilled tag if it is on the same
#  line as the cursor when the function is invoked.
def g:HTML#NextInsertPoint(mode: string = 'n')
  var byteoffset = s:ByteOffset()
  var done: bool

  # Tab in insert mode on the beginning of a closing tag jumps us to
  # after the tag:
  if mode == 'i'
    if line('.')->getline()->strpart(col('.') - 1, 2) == '</'
      normal! %
      done = true
    elseif line('.')->getline()->strpart(col('.') - 1) =~ '^ *-->'
      normal! f>
      done = true
    else
      done = false
    endif

    if done
      if col('.') == col('$') - 1
        startinsert!
      else
        normal! l
      endif

      return
    endif
  endif

  # Move to the end of the previous line, if possible, to allow the search()
  # to work as intended:
  normal! 0
  silent! execute "go " .. (s:ByteOffset() - 1)

  if '<\([^ <>]\+\)\_[^<>]*>\_s*<\/\1>\|<\_[^<>]*""\_[^<>]*>\|<!--\_s*-->'->search('wz') == 0
    # Nothing matched, so move the cursor back where it was:
    if byteoffset < 1
      go 1
    else
      execute 'go ' .. byteoffset
      if mode == 'i' && col('.') == col('$') - 1
        startinsert!
      endif
    endif
  else
    # There was a match, so position the cursor appropriately:
    '>\_s*<\|""\|<!--\_s*-->'->search('e')

    # ...and handle cursor positioning for comments or open+close tags
    # spanning multiple lines:
    if getline('.') =~ '<!-- \+-->'
      execute "normal! F\<space>"
    elseif getline('.') =~ '^ *-->' && getline(line('.') - 1) =~ '<!-- *$'
      normal! 0
      normal! t-
    elseif getline('.') =~ '^ *-->' && getline(line('.') - 1) =~ '^ *$'
      normal! k$
    elseif getline('.') =~ '^ *<\/[^<>]\+>' && getline(line('.') - 1) =~ '^ *$'
      normal! k$
    endif
  endif
enddef

# g:HTML#SmartTag()  {{{1
#
# Causes certain tags (such as bold, italic, underline) to be closed then
# opened rather than opened then closed where appropriate, if syntax
# highlighting is on.
#
# Arguments:
#  1 - String: The tag name.
#  2 - Character: The mode:
#                  'i' - Insert mode
#                  'v' - Visual mode
# Return Value:
#  The string to be executed to insert the tag.

# SMARTTAGS[tag][mode][open/close] = keystrokes  {{{
#  tag        - The literal tag, without the <>'s
#  mode       - i = insert, v = visual
#               (no "o", because o-mappings invoke visual mode)
#  open/close - c = When inside an equivalent tag, close then open it
#               o = When not inside an equivalent tag
#  keystrokes - The mapping keystrokes to execute
const SMARTTAGS = {
  'i': {
    'i': {
      'o': "<[{I></I}]>\<C-O>F<",
      'c': "<[{/I><I}]>\<C-O>F<",
    },
    'v': {
      'o': "`>a</[{I}]>\<C-O>`<<[{I}]>",
      'c': "`>a<[{I}]>\<C-O>`<</[{I}]>",
    }
  },

  'em': {
    'i': {
      'o': "<[{EM></EM}]>\<C-O>F<",
      'c': "<[{/EM><EM}]>\<C-O>F<",
    },
    'v': {
      'o': "`>a</[{EM}]>\<C-O>`<<[{EM}]>",
      'c': "`>a<[{EM}]>\<C-O>`<</[{EM}]>",
    }
  },

  'b': {
    'i': {
      'o': "<[{B></B}]>\<C-O>F<",
      'c': "<[{/B><B}]>\<C-O>F<",
    },
    'v': {
      'o': "`>a</[{B}]>\<C-O>`<<[{B}]>",
      'c': "`>a<[{B}]>\<C-O>`<</[{B}]>",
    }
  },

  'strong': {
    'i': {
      'o': "<[{STRONG></STRONG}]>\<C-O>F<",
      'c': "<[{/STRONG><STRONG}]>\<C-O>F<",
    },
    'v': {
      'o': "`>a</[{STRONG}]>\<C-O>`<<[{STRONG}]>",
      'c': "`>a<[{STRONG}]>\<C-O>`<</[{STRONG}]>",
    }
  },

  'u': {
    'i': {
      'o': "<[{U></U}]>\<C-O>F<",
      'c': "<[{/U><U}]>\<C-O>F<",
    },
    'v': {
      'o': "`>a</[{U}]>\<C-O>`<<[{U}]>",
      'c': "`>a<[{U}]>\<C-O>`<</[{U}]>",
    }
  },

  'comment': {
    'i': {
      'o': "<!--  -->\<C-O>F ",
      'c': " --><!-- \<C-O>F<",
    },
    'v': {
      'o': "`>a -->\<C-O>`<<!-- ",
      'c': "`>a<!-- \<C-O>`< -->",
    }
  }
} # }}}

def g:HTML#SmartTag(tag: string, mode: string): string
  var attr = synID(line('.'), col('.') - 1, 1)->synIDattr('name')
  var ret: string

  if ( tag == 'i' && attr =~? 'italic' )
        || ( tag == 'em' && attr =~? 'italic' )
        || ( tag == 'b' && attr =~? 'bold' )
        || ( tag == 'strong' && attr =~? 'bold' )
        || ( tag == 'u' && attr =~? 'underline' )
        || ( tag == 'comment' && attr =~? 'comment' )
    ret = SMARTTAGS[tag][mode]['c']->g:HTML#ConvertCase()
  else
    ret = SMARTTAGS[tag][mode]['o']->g:HTML#ConvertCase()
  endif

  if mode == 'v'
    # If 'selection' is "exclusive" all the visual mode mappings need to
    # behave slightly differently:
    ret = ret->substitute("`>a\\C", "`>i" .. g:HTML#VI(), 'g')
  endif

  return ret
enddef

# g:HTML#DetectCharset()  {{{1
#
# Detects the HTTP-EQUIV Content-Type charset based on Vim's current
# encoding/fileencoding.
#
# Arguments:
#  None
# Return Value:
#  The value for the Content-Type charset based on 'fileencoding' or
#  'encoding'.

# TODO: This table needs to be expanded:  {{{
const CHARSETS = {
  'latin1':    'iso-8859-1',
  'utf_8':     'UTF-8',
  'utf_16':    'UTF-16',
  'shift_jis': 'Shift_JIS',
  'euc_jp':    'EUC-JP',
  'cp950':     'Big5',
  'big5':      'Big5',
} # }}}

def g:HTML#DetectCharset(): string
  var enc: string

  if exists("g:html_charset")
    return g:html_charset
  endif

  if &fileencoding != ''
    enc = tolower(&fileencoding)
  else
    enc = tolower(&encoding)
  endif

  # The iso-8859-* encodings are valid for the Content-Type charset header:
  if enc =~? '^iso-8859-'
    return enc
  endif

  enc = enc->substitute('\W', '_', 'g')

  if CHARSETS[enc] != ''
    return CHARSETS[enc]
  endif

  return g:html_default_charset
enddef

# g:HTML#GenerateTable()  {{{1
#
# Interactively creates a table.
#
# Arguments:
#  None
# Return Value:
#  None
def g:HTML#GenerateTable()
  var charpos = getcharpos('.')
  var rows    = inputdialog("Number of rows: ")->str2nr()
  var columns = inputdialog("Number of columns: ")->str2nr()

  if (rows < 1 || columns < 1)
    HTMLERROR Rows and columns must be positive, non-zero integers.
    return
  endif

  var border = inputdialog("Border width of table [none]: ")->str2nr()

  if border
    execute g:HTML#ConvertCase("normal o<[{TABLE BORDER}]=" .. border .. ">\<ESC>")
  else
    execute g:HTML#ConvertCase("normal o<[{TABLE}]>\<ESC>")
  endif

  for r in rows->range()
    execute g:HTML#ConvertCase("normal o<[{TR}]>\<ESC>")

    for c in columns->range()
      execute g:HTML#ConvertCase("normal o<[{TD}]></[{TD}]>\<ESC>")
    endfor

    execute g:HTML#ConvertCase("normal o</[{TR}]>\<ESC>")
  endfor

  execute g:HTML#ConvertCase("normal o</[{TABLE}]>\<ESC>")

  setcharpos('.', charpos)

  normal jjj$F<
enddef

# s:ClearMappings() {{{1
#
# Iterate over all the commands to clear the mappings.  This used to be just
# one long single command but that had drawbacks, so now it's a List that must
# be looped over:
#
# Arguments:
#  None
# Return Value:
#  None
def s:ClearMappings()
  for mapping in b:HTMLclearMappings
    silent! execute mapping
  endfor
  b:HTMLclearMappings = []
  unlet b:did_html_mappings
enddef

# s:DoExtraMappings() {{{1
#
# Iterate over all the commands to define extra mappings (those that weren't
# defined by the plugin):
#
# Arguments:
#  None
# Return Value:
#  None
def s:DoExtraMappings()
  doing_extra_html_mappings = true
  for mapping in b:HTMLextraMappings
    silent! execute mapping
  endfor
  doing_extra_html_mappings = false
enddef

# g:HTML#MappingsControl()  {{{1
#
# Disable/enable all the mappings defined by
# g:HTML#Map()/g:HTML#Mapo().
#
# Arguments:
#  1 - String:  Whether to disable or enable the mappings:
#                d/disable/off:   Clear the mappings
#                e/enable/on:     Redefine the mappings
#                r/reload/reinit: Completely reload the script
#                h/html:          Reload the mapppings in HTML mode
#                x/xhtml:         Reload the mapppings in XHTML mode
# Return Value:
#  None
#
# Note:
#  This expects g:html_plugin_file to be set by the HTML plugin.
var doing_extra_html_mappings = false
var quiet_errors: bool
def g:HTML#MappingsControl(dowhat: string)
  if exists('b:did_html_mappings_init') == 0
    HTMLERROR The HTML mappings were not sourced for this buffer.
    return
  endif

  if exists('g:html_plugin_file') == 0
    HTMLERROR Somehow the HTML plugin reference global variable did not get set.
    return
  endif

  if b:did_html_mappings_init < 0
    unlet b:did_html_mappings_init
  endif

  if dowhat =~? '^\(d\(isable\)\=\|off\)$'
    if exists('b:did_html_mappings') == 1
      s:ClearMappings()
      if exists("g:did_html_menus") == 1
        g:HTML#MenuControl('disable')
      endif
    elseif quiet_errors
      HTMLERROR The HTML mappings are already disabled.
    endif
  elseif dowhat =~? '^\(e\(nable\)\=\|on\)$'
    if exists('b:did_html_mappings') == 1
      HTMLERROR The HTML mappings are already enabled.
    else
      execute "source " .. g:html_plugin_file
      if exists('b:HTMLextraMappings') == 1
        s:DoExtraMappings()
      endif
    endif
  elseif dowhat =~? '^\(r\(eload\|einit\)\=\)$'
    execute 'HTMLMESG Reloading: ' .. fnamemodify(g:html_plugin_file, ':t')
    quiet_errors = true
    g:HTML#MappingsControl('off')
    b:did_html_mappings_init = -1
    silent! unlet g:did_html_menus g:did_html_toolbar g:did_html_commands
    silent! unmenu HTML
    silent! unmenu! HTML
    g:HTML#MappingsControl('on')
    autocmd SafeState * ++once HTMLReloadFunctions
    quiet_errors = false
  elseif dowhat =~? '^h\(tml\)\=$'
    if exists('b:html_tag_case_save') == 1
      b:html_tag_case = b:html_tag_case_save
    endif
    b:do_xhtml_mappings = false
    g:HTML#MappingsControl('off')
    b:did_html_mappings_init = -1
    g:HTML#MappingsControl('on')
  elseif dowhat =~? '^x\(html\)\=$'
    b:do_xhtml_mappings = true
    g:HTML#MappingsControl('off')
    b:did_html_mappings_init = -1
    g:HTML#MappingsControl('on')
  else
    execute "HTMLERROR Invalid argument: " .. dowhat
  endif
enddef

# g:HTML#MenuControl()  {{{1
#
# Disable/enable the HTML menu and toolbar.
#
# Arguments:
#  1 - String:  Optional, Whether to disable or enable the menus:
#                empty: Detect which to do
#                "disable": Disable the menu and toolbar
#                "enable": Enable the menu and toolbar
# Return Value:
#  None
def g:HTML#MenuControl(which: string="detect")
  if which !~? '^disable$\|^enable$\|^detect$'
    echoerr "Invalid argument: " .. which
    return
  endif

  if which == 'disable' || exists("b:did_html_mappings") == 0
    amenu disable HTML
    amenu disable HTML.*
    if exists('g:did_html_toolbar') == 1
      amenu disable ToolBar.*
      amenu enable ToolBar.Open
      amenu enable ToolBar.Save
      amenu enable ToolBar.SaveAll
      amenu enable ToolBar.Undo
      amenu enable ToolBar.Redo
      amenu enable ToolBar.Cut
      amenu enable ToolBar.Copy
      amenu enable ToolBar.Paste
      amenu enable ToolBar.Replace
      amenu enable ToolBar.FindNext
      amenu enable ToolBar.FindPrev
    endif
    if exists('b:did_html_mappings_init') == 1 && exists('b:did_html_mappings') == 0
      amenu enable HTML
      amenu disable HTML.Control.*
      amenu enable HTML.Control
      amenu enable HTML.Control.Enable\ Mappings
      amenu enable HTML.Control.Reload\ Mappings
    endif
  elseif which == 'enable' || exists("b:did_html_mappings_init") == 1
    amenu enable HTML
    if exists("b:did_html_mappings") == 1
      amenu enable HTML.*
      amenu enable HTML.Control.*
      amenu disable HTML.Control.Enable\ Mappings

      if g:HTML#BoolVar('b:do_xhtml_mappings')
        amenu disable HTML.Control.Switch\ to\ XHTML\ mode
        amenu enable  HTML.Control.Switch\ to\ HTML\ mode
      else
        amenu enable  HTML.Control.Switch\ to\ XHTML\ mode
        amenu disable HTML.Control.Switch\ to\ HTML\ mode
      endif

      if exists('g:did_html_toolbar') == 1
        amenu enable ToolBar.*
      endif
    else
      amenu enable HTML.Control.Enable\ Mappings
    endif
  endif
enddef

# g:HTML#ShowColors()  {{{1
#
# Create a window to display the HTML colors, highlighted
#
# Arguments:
#  1 - String: Default is "i", how to insert the selection
# Return Value:
#  None
def g:HTML#ShowColors(str: string='')
  if exists('g:did_html_menus') == 0
    HTMLERROR The HTML menu was not created, and it is necessary for color parsing.
    return
  endif

  if exists('b:did_html_mappings_init') == 0
    HTMLERROR Not in an HTML buffer.
    return
  endif

  var curbuf = bufnr('%')
  var maxw = 0

  silent new [HTML\ Colors\ Display]
  setlocal buftype=nofile noswapfile bufhidden=wipe

  for key in g:html_color_list->keys()
    if key->strlen() > maxw
      maxw = key->strlen()
    endif
  endfor

  var col = 0
  var line = ''
  for key in g:html_color_list->keys()->sort()
    col += 1

    line ..= repeat(' ', maxw - key->strlen()) .. key .. ' = ' .. g:html_color_list[key]

    if col >= 2
      append('$', line)
      line = ''
      col = 0
    else
      line ..= '      '
    endif

    var key2 = key->substitute(' ', '', 'g')

    execute 'syntax match hc_' .. key2 .. ' /' .. g:html_color_list[key] .. '/'
    execute 'highlight hc_' .. key2 .. ' guibg=' .. g:html_color_list[key]
  endfor

  if line != ''
    append('$', line)
  endif

  append(0, [
        '+++ q = quit  <space> = page down   b = page up           +++',
        '+++ <tab> = Go to next color                              +++',
        '+++ <enter> or <double click> = Select color under cursor +++',
      ])
  go 1
  execute ':1,3center ' .. ((maxw + 13) * 2)
  norm }

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
  noremap <silent> <buffer> <tab> <Cmd>eval search('[A-Za-z][A-Za-z ]\+ = #\x\{6\}')<CR>
  inoremap <silent> <buffer> <tab> <Cmd>eval search('[A-Za-z][A-Za-z ]\+ = #\x\{6\}')<CR>

  var ins = ''
  if str != ''
    ins = ', "' .. str->escape('"') .. '"'
  endif

  execute 'noremap <silent> <buffer> <cr> <Cmd>eval <SID>ColorSelect(' .. curbuf .. ins .. ')<CR>'
  execute 'inoremap <silent> <buffer> <cr> <Cmd>eval <SID>ColorSelect(' .. curbuf .. ins .. ')<CR>'
  execute 'noremap <silent> <buffer> <2-leftmouse> <Cmd>eval <SID>ColorSelect(' .. curbuf .. ins .. ')<CR>'
  execute 'inoremap <silent> <buffer> <2-leftmouse> <Cmd>eval <SID>ColorSelect(' .. curbuf .. ins .. ')<CR>'

  stopinsert
enddef

# s:ColorSelect()  {{{1
# Arguments:
#  1 - Number: Buffer to insert into
#  2 - String: Optional, default "i", how to insert the color code
def s:ColorSelect(bufnr: number, which: string = 'i')
  var line  = getline('.')
  var col   = col('.')
  var color = line->substitute('.\{-\}\%<' .. (col + 1) .. 'c\([A-Za-z][A-Za-z ]\+ = #\x\{6\}\)\%>' .. col .. 'c.*', '\1', '')

  if color == line
    return
  endif

  var colora = color->split(' = ')

  close
  if bufnr->bufwinnr() == -1
    execute ':buffer ' .. bufnr
  else
    execute ':' .. bufnr->bufwinnr() .. 'wincmd w'
  endif

  execute 'normal ' .. which .. colora[1]
  stopinsert
  echo color
enddef

# g:HTML#Template()  {{{1
#
# Determine whether to insert the HTML template.
#
# Arguments:
#  None
# Return Value:
#  0 - The cursor is not on an insert point.
#  1 - The cursor is on an insert point.
def g:HTML#Template(): bool
  var ret = false
  var save_ruler = &ruler
  var save_showcmd = &showcmd
  set noruler noshowcmd

  if line('$') == 1 && getline(1) == ''
    ret = s:Template2()
  else
    var YesNoOverwrite = confirm("Non-empty file.\nInsert template anyway?", "&Yes\n&No\n&Overwrite", 2, "W")
    if YesNoOverwrite == 1
      ret = s:Template2()
    elseif YesNoOverwrite == 3
      execute "1,$delete"
      ret = s:Template2()
    endif
  endif
  &ruler = save_ruler
  &showcmd = save_showcmd
  return ret
enddef

# s:Template2()  {{{1
#
# Actually insert the HTML template.
#
# Arguments:
#  None
# Return Value:
#  0 - The cursor is not on an insert point.
#  1 - The cursor is on an insert point.
def s:Template2(): bool

  if g:html_authoremail != ''
    g:html_authoremail_encoded = g:html_authoremail->g:HTML#EncodeString()
  else
    g:html_authoremail_encoded = ''
  endif

  var template = ''

  if exists('b:html_template') && b:html_template != ''
    template = b:html_template
  elseif exists('g:html_template') && g:html_template != ''
    template = g:html_template
  endif

  if template != ''
    if template->expand()->filereadable()
      silent execute ":0read " .. template
    else
      execute "HTMLERROR Unable to insert template file: " .. template
      HTMLERROR "Either it doesn't exist or it isn't readable."
      return false
    endif
  else
    :0put =b:internal_html_template
  endif

  if getline('$') =~ '^\s*$'
    execute ":$delete"
  endif

  if getline(1) =~ '^\s*$'
    execute ":1delete"
  endif

  # Replace the various tokens with appropriate values:
  :silent! :%s/\C%authorname%/\=g:html_authorname/g
  :silent! :%s/\C%authoremail%/\=g:html_authoremail_encoded/g
  :silent! :%s/\C%bgcolor%/\=g:html_bgcolor/g
  :silent! :%s/\C%textcolor%/\=g:html_textcolor/g
  :silent! :%s/\C%linkcolor%/\=g:html_linkcolor/g
  :silent! :%s/\C%alinkcolor%/\=g:html_alinkcolor/g
  :silent! :%s/\C%vlinkcolor%/\=g:html_vlinkcolor/g
  :silent! :%s/\C%date%/\=strftime('%B %d, %Y')/g
  :silent! :%s/\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%/\=submatch(1)->substitute('\\%', '%%', 'g')->substitute('\\\@<!!', '%', 'g')->strftime()/g
  :silent! :%s/\C%time%/\=strftime('%r %Z')/g
  :silent! :%s/\C%time12%/\=strftime('%r %Z')/g
  :silent! :%s/\C%time24%/\=strftime('%T')/g
  :silent! :%s/\C%charset%/\=g:HTML#DetectCharset()/g
  :silent! :%s#\C%vimversion%#\=(v:version / 100) .. '.' .. (v:version % 100) .. '.' .. (v:versionlong % 10000)#g

  go 1

  g:HTML#NextInsertPoint('n')
  if getline('.')[col('.') - 2] .. getline('.')[col('.') - 1] == '><'
        || (getline('.') =~ '^\s*$' && line('.') != 1)
    return true
  else
    return false
  endif
enddef

# g:HTML#LeadMenu()  {{{1
#
# Generate HTML menu items
#
# Arguments:
#  1 - String: The menu type (amenu, imenu, omenu)
#  2 - String: The menu numeric level(s) ("-" for automatic)
#  3 - String: The menu item
#  4 - String: Optional, normal mode command to execute before running the
#              menu command
# Return Value:
#  None
def g:HTML#LeadMenu(type: string, level: string, name: string, item: string, pre: string = '')
  var newlevel: string

  if level == '-'
    newlevel = ''
  else
    newlevel = level
  endif

  var newname = name->escape(' ')

  execute type .. ' ' .. newlevel .. ' ' .. newname .. '<tab>' .. g:html_map_leader
      .. item .. ' ' .. pre .. g:html_map_leader .. item
enddef

# g:HTML#EntityMenu()  {{{1
#
# Generate HTML character entity menu items
#
# Arguments:
#  1 - String: The menu name
#  2 - String: The item
#  3 - String: The symbol it generates
# Return Value:
#  None
def g:HTML#EntityMenu(name: string, item: string, symb: string = '')
  var newsymb = ''

  if symb != '-'
    if symb == '\-'
      newsymb = ' (-)'
    else
      newsymb = ' (' .. symb .. ')'
    endif
  endif

  var newname = name->escape(' ')

  execute 'imenu ' .. newname .. newsymb->escape(' &<.|') .. '<tab>'
        .. g:html_map_entity_leader->escape('&\')
        .. item->escape('&<') .. ' '
        .. g:html_map_entity_leader .. item
  execute 'nmenu ' .. newname .. newsymb->escape(' &<.|') .. '<tab>'
        .. g:html_map_entity_leader->escape('&\')
        .. item->escape('&<') .. ' ' .. 'i'
        .. g:html_map_entity_leader .. item .. '<esc>'
  execute 'vmenu ' .. newname .. newsymb->escape(' &<.|') .. '<tab>'
        .. g:html_map_entity_leader->escape('&\')
        .. item->escape('&<') .. ' ' .. 's'
        .. g:html_map_entity_leader .. item .. '<esc>'
enddef

# g:HTML#ColorsMenu()  {{{1
#
# Generate HTML colors menu items
#
# Arguments:
#  1 - String: The color name
#  2 - String: The color hex code
# Return Value:
#  None
const colors_sort = {  # {{{
  'A': 'A',   'B': 'B',   'C': 'C',
  'D': 'D',   'E': 'E-G', 'F': 'E-G',
  'G': 'E-G', 'H': 'H-K', 'I': 'H-K',
  'J': 'H-K', 'K': 'H-K', 'L': 'L',
  'M': 'M',   'N': 'N-O', 'O': 'N-O',
  'P': 'P',   'Q': 'Q-R', 'R': 'Q-R',
  'S': 'S',   'T': 'T-Z', 'U': 'T-Z',
  'V': 'T-Z', 'W': 'T-Z', 'X': 'T-Z',
  'Y': 'T-Z', 'Z': 'T-Z',
}  # }}}

def g:HTML#ColorsMenu(name: string, color: string)
  var c = name->strpart(0, 1)->toupper()
  var newname = name->substitute('\C\([a-z]\)\([A-Z]\)', '\1\ \2', 'g')
  execute 'imenu HTML.&Colors.&' .. colors_sort[c] .. '.'
    .. newname->escape(' ') .. '<tab>(' .. color .. ') ' .. color
  execute 'nmenu HTML.&Colors.&' .. colors_sort[c] .. '.'
    .. newname->escape(' ') .. '<tab>(' .. color .. ') i' .. color .. '<esc>'
  g:html_color_list[name] = color
enddef

defcompile

if !exists('g:html_function_files') | g:html_function_files = [] | endif
add(g:html_function_files, expand('<sfile>:p'))->sort()->uniq()

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
