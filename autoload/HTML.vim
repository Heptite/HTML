vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8023316
  finish
endif

# Various functions for the HTML macros filetype plugin.
#
# Last Change: August 15, 2021
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 1998-2021 Christian J. Robinson <heptite@gmail.com>
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

if exists(':HTMLWARN') != 2  # {{{1
  command! -nargs=+ HTMLWARN {
      echohl WarningMsg
      echomsg <q-args>
      echohl None
    }
  command! -nargs=+ HTMLMESG {
      echohl Todo
      echo <q-args>
      echohl None
    }
  command! -nargs=+ HTMLERROR {
      echohl ErrorMsg
      echomsg <q-args>
      echohl None
    }
endif  # }}}1

import * as HTML from "../import/HTML.vim"

# Can't be imported because then it would have a prefix:
const off = 'off'
const on = 'on'

# Used in a bunch of places so some functions don't have to be globally
# exposed:
const _this = expand('<SID>')

# HTML#About()  {{{1
#
# Purpose:
#  Self-explanatory
# Arguments:
#  None
# Return Value:
#  None
def HTML#About(): void
  var message = "HTML/XHTML Editing Macros and Menus Plugin\n"
    .. "Version: " .. (HTML.VERSION) .. "\n"
    .. "Written by: " .. (HTML.AUTHOR) .. "\n"
    .. (HTML.COPYRIGHT) .. "\n"
    .. "URL: " .. (HTML.HOMEPAGE)

  if message->confirm("&Visit Homepage\n&Dismiss", 2, 'Info') == 1
    BrowserLauncher#Launch('default', 0, HTML.HOMEPAGE)
  endif
enddef

# HTML#SetIfUnset()  {{{1
#
# Set a variable if it's not already set. Cannot be used for script-local
# variables.
#
# Arguments:
#  1       - String: The variable name
#  2 ... N - String: The default value to use
# Return Value:
#  0  - The variable already existed
#  1  - The variable didn't exist and was successfully set
#  -1 - An error occurred
def HTML#SetIfUnset(variable: string, ...args: list<any>): number
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
  elseif type(args[0]) == v:t_list || type(args[0]) == v:t_dict || type(args[0]) == v:t_number
    val = args[0]
  else
    val = args->join(' ')
  endif

  if newvariable->IsSet()
    return 0
  endif

  if type(val) == v:t_string
    if val == '""' || val == "''"
      execute newvariable .. ' = ""'
    elseif val == '[]'
      execute newvariable .. ' = []'
    elseif val == '{}'
      execute newvariable .. ' = {}'
    elseif val =~ '^-\?[[:digit:]]\+$'
      execute newvariable .. ' = ' val->str2nr()
    elseif val =~ '^-\?[[:digit:].]\+$'
      execute newvariable .. ' = ' val->str2float()
    else
      execute newvariable .. " = '" .. val->escape("'\\") .. "'"
    endif
  elseif type(val) == v:t_number || type(val) == v:t_float
    execute newvariable .. ' = ' .. val
  else
    execute newvariable .. ' = ' .. string(val)
  endif

  return 1
enddef


# Bool()  {{{1
#
# Helper to HTML#BoolVar() -- Test the string passed to it and
# return true/false based on that string.
#
# Arguments:
#  1 - String: 1|true|yes|y|on / 0|false|no|n|off|none|null
# Return Value:
#  Boolean
def Bool(value: any): bool
  var regexp = '^no\?$\|^off$\|^\%(v:\)\?\%(false\|none\|null\)$\|^0\%(\.0\)\?$\|^$'
  if value->type() == v:t_string
    return value !~? regexp
  elseif value->type() == v:t_bool || value->type() == v:t_none
      || value->type() == v:t_number || value->type() == v:t_float
    return value->string() !~? regexp
  elseif value->type() == v:t_list
    return value != []
  elseif value->type() == v:t_dict
    return value != {}
  endif

  execute 'HTMLERROR Unknown type for Bool(): ' .. value->typename()
  return false
enddef

# HTML#BoolVar()  {{{1
#
# Given a string, test to see if a variable by that string name exists, and if
# so, whether it's set to 1|true|yes|on / 0|false|no|off|none|null
# (Actually, anything not listed here also returns as true.)
#
# Arguments:
#  1 - String: The name of the variable to test (not its value!)
# Return Value:
#  Boolean
#
# Limitations:
#  This /will not/ work on function-local variable names.
def HTML#BoolVar(variable: string): bool
  var newvariable = variable

  if variable !~ '^[bgstvw]:'
    newvariable = 'g:' .. variable
  endif

  if newvariable->IsSet()
    return newvariable->eval()->Bool()
  else
    return false
  endif
enddef

# IsSet() {{{1
#
# Given a string, test to see if a variable by that string name exists.
#
# Arguments:
#  1 - String: The variable name
# Return Value:
#  Boolean: Whether the variable exists
def IsSet(str: string): bool
  if str != ''
    return exists(str) != 0
  else
    return false
  endif
enddef

# HTML#FilesWithMatch()  {{{1
#
# Create a list of files that have contents matching a pattern.
#
# Arguments:
#  1 - List:    The files to search
#  2 - String:  The pattern to search for
#  2 - Integer: Optional, the number of lines to search before giving up 
# Return Value:
#  List: Matching files
def HTML#FilesWithMatch(files: list<string>, pat: string, max: number = -1): list<string>
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

# CharToEntity()  {{{1
#
# Convert a character to its corresponding character entity, or its numeric
# form if the entity doesn't exist in the lookup table.
#
# Arguments:
#  1 - Character: The character to encode
# Return Value:
#  String: The entity representing the character
def CharToEntity(char: string): string
  var newchar: string
  
  if char->strchars(1) > 1
    execute 'HTMLERROR Argument must be one character.'
    return char
  endif

  if HTML.DictCharToEntities->has_key(char)
    newchar = HTML.DictCharToEntities[char]
  else
    newchar = printf('&#x%X;', char->char2nr())
  endif

  return newchar
enddef

# EntityToChar()  {{{1
#
# Convert character entities to its corresponing character.
#
# Arguments:
#  1 - String: The entity to decode
# Return Value:
#  String: The decoded character
def EntityToChar(entity: string): string
  var char: string

  if HTML.DictEntitiesToChar->has_key(entity)
    char = HTML.DictEntitiesToChar[entity]
  elseif entity =~ '^&#\%(x\x\+\);$'
    char = entity->strpart(3, entity->strlen() - 4)->str2nr(16)->nr2char()
  elseif entity =~ '^&#\%(\d\+\);$'
    char = entity->strpart(2, entity->strlen() - 3)->str2nr()->nr2char()
  else
    char = entity
  endif

  return char
enddef

# HTML#EncodeString()  {{{1
#
# Encode the characters in a string to/from their HTML representations.
#
# Arguments:
#  1 - String: The string to encode/decode.
#  2 - String: Optional, whether to decode rather than encode the string:
#              - d/decode: Decode the %XX, &#...;, and &#x...; elements of
#                          the provided string
#              - %:        Encode as a %XX string
#              - x:        Encode as a &#x...; string
#              - omitted:  Encode as a &#...; string
#              - other:    No change to the string
# Return Value:
#  String: The encoded string.
def HTML#EncodeString(str: string, code: string = ''): string
  var out = str

  if code == ''
    out = out->split('\zs')->mapnew((_, char) => char->CharToEntity())->join('')
  elseif code == 'x'
    out = out->split('\zs')->mapnew((_, char) => printf("&#x%x;", char->char2nr()))->join('')
  elseif code == '%'
    out = out->substitute('[\x00-\x99]', '\=printf("%%%02X", submatch(0)->char2nr())', 'g')
  elseif code =~? '^d\%(ecode\)\=$'
    out = out->substitute('\(&[A-Za-z0-9]\+;\|&#x\x\+;\|&#\d\+;\|%\x\x\)', '\=submatch(1)->HTML#DecodeSymbol()', 'g')
  endif

  return out
enddef

# HTML#DecodeSymbol()  {{{1
#
# Decode the HTML entity or URI symbol string to its literal character
# counterpart
#
# Arguments:
#  1 - String: The string to decode.
# Return Value:
#  Character: The decoded character.
def HTML#DecodeSymbol(symbol: string): string
  var char: string

  if symbol =~ '^&#\%(x\x\+\);$\|^&#\%(\d\+\);$\|^&\%([A-Za-z0-9]\+\);$'
    char = EntityToChar(symbol)
  elseif symbol =~ '^%\%(\x\x\)$'
    char = symbol->strpart(1, symbol->strlen() - 1)->str2nr(16)->nr2char()
  else
    char = symbol
  endif

  return char
enddef

# HTML#Map()  {{{1
#
# Define the HTML mappings with the appropriate case, plus some extra stuff.
#
# Arguments:
#  1 - String: Which map command to run.
#  2 - String: LHS of the map.
#  3 - String: RHS of the map.
#  4 - Dictionary: Optional, applies only to visual maps:
#                {'extra': bool}
#                 Whether to suppress extra code on the mapping
#                {'insert': bool}
#                 Whether mapping enters insert mode
#                {'reindent': number}
#                 Re-selects the region, moves down "number" lines, and
#                 re-indents (applies only when filetype indenting is on)
# Return Value:
#  Boolean: Whether a mapping was defined

def HTML#Map(cmd: string, map: string, arg: string, opts: dict<any> = {}): bool
  if exists('g:htmlplugin.map_leader') == 0 && map =~? '^<lead>'
    HTMLERROR g:htmlplugin.map_leader is not set! No mapping defined.
    return false
  endif

  if exists('g:htmlplugin.map_entity_leader') == 0 && map =~? '^<elead>'
    HTMLERROR g:htmlplugin.map_entity_leader is not set! No mapping defined.
    return false
  endif

  if map == ''
    HTMLERROR lhs must be non-empty! No mapping defined.
    return false
  endif

  if arg == ''
    HTMLERROR rhs must be non-empty! No mapping defined.
    return false
  endif

  if cmd =~# '^no' || cmd =~# '^map$'
    execute 'HTMLERROR ' .. expand('<sfile>') .. ' must have one of the modes explicitly stated. No mapping defined.'
    return false
  endif

  var mode = cmd->strpart(0, 1)
  var newarg = arg
  var newmap = map->substitute('^<lead>\c', g:htmlplugin.map_leader->escape('&~\'), '')
  newmap = newmap->substitute('^<elead>\c', g:htmlplugin.map_entity_leader->escape('&~\'), '')

  if HTML.MODES->has_key(mode) && newmap->MapCheck(mode) >= 2
    # MapCheck() will echo the necessary message, so just return here
    return false
  endif

  newarg = newarg->HTML#ConvertCase()

  if ! HTML#BoolVar('b:htmlplugin.do_xhtml_mappings')
    newarg = newarg->substitute(' \?/>', '>', 'g')
  endif

  if mode == 'v'
    # If 'selection' is "exclusive" all the visual mode mappings need to
    # behave slightly differently:
    newarg = newarg->substitute('`>a\C', '`>i<C-R>=' .. _this .. 'VI()<CR>', 'g')

    # Note that <C-c>:-command is necessary instead of just <Cmd> because
    # <Cmd> doesn't update visual marks, which the mappings rely on:
    if opts->has_key('extra') && ! opts['extra']
      execute cmd .. ' <buffer> <silent> ' .. newmap .. " " .. newarg
    elseif opts->has_key('insert') && opts['insert'] && opts->has_key('reindent')
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. _this .. 'TO(false)<CR><C-O>gv' .. newarg
        .. "<C-O>:vim9cmd " .. _this
        .. "TO(true)<CR><C-O>m'<C-O>:vim9cmd HTML#ReIndent(line(\"'<\"), line(\"'>\"), "
        .. opts['reindent'] .. ')<CR><C-O>``'
    elseif opts->has_key('insert') && opts['insert']
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. _this .. 'TO(false)<CR>gv' .. newarg
        .. '<C-O>:vim9cmd ' .. _this .. 'TO(true)<CR>'
    elseif opts->has_key('reindent')
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. _this .. 'TO(false)<CR>gv' .. newarg
        .. ":vim9cmd " .. _this
        .. "TO(true)<CR>m':vim9cmd HTML#ReIndent(line(\"'<\"), line(\"'>\"), "
        .. opts['reindent'] .. ')<CR>``'
    else
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. _this .. 'TO(false)<CR>gv' .. newarg
        .. ':vim9cmd ' .. _this .. 'TO(true)<CR>'
    endif
  else
    execute cmd .. ' <buffer> <silent> ' .. newmap .. " " .. newarg
  endif

  if HTML.MODES->has_key(mode)
    add(b:HTMLclearMappings, ':' .. mode .. 'unmap <buffer> ' .. newmap)
  else
    add(b:HTMLclearMappings, ':unmap <buffer> ' .. newmap)
  endif

  # Save extra mappings so they can be restored if we need to later:
  ExtraMappingsAdd(':vim9cmd HTML#Map("' .. cmd .. '", "' .. map->escape('"\')
    .. '", "' .. arg->escape('"\') .. '"'
    .. (opts != {} ? ', ' .. string(opts) : '') .. ')')

  return true
enddef

# HTML#Mapo()  {{{1
#
# Define a normal mode map that takes an operator and assign it to its
# corresponding visual mode mapping.
#
# Arguments:
#  1 - String: The mapping.
#  2 - Boolean: Optional - Whether to enter insert mode after the mapping has
#                          executed. Default false.
# Return Value:
#  Boolean: Whether a mapping was defined
def HTML#Mapo(map: string, insert: bool = false): bool
  if exists('g:htmlplugin.map_leader') == 0 && map =~? '^<lead>'
    HTMLERROR g:htmlplugin.map_leader is not set! No mapping defined.
    return false
  endif

  if map == ''
    HTMLERROR lhs must be non-empty! No mapping defined.
    return false
  endif

  var newmap = map->substitute('^<lead>', g:htmlplugin.map_leader, '')

  if newmap->MapCheck('o') >= 2
    return false
  endif

  execute 'nnoremap <buffer> <silent> ' .. newmap
    .. " :vim9cmd b:htmltagaction = '" .. newmap .. "'<CR>"
    .. ':vim9cmd b:htmltaginsert = ' .. insert .. "<CR>"
    .. ':vim9cmd &operatorfunc = "' .. _this .. 'WR"<CR>g@'

  add(b:HTMLclearMappings, ':nunmap <buffer> ' .. newmap)
  ExtraMappingsAdd(':vim9cmd HTML#Mapo("' .. map->escape('"\')
    .. '", ' .. insert .. ')')

  return true
enddef

# MapCheck()  {{{1
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
#  3 - The mapping to be defined was suppressed by g:htmlplugin.no_maps.
#
# (Note that suppression only works for the internal mappings.)
def MapCheck(map: string, mode: string): number
  if g:htmlplugin.doing_internal_mappings &&
        ( (exists('g:htmlplugin.no_maps') && map =~# g:htmlplugin.no_maps) ||
          (exists('b:htmlplugin.no_maps') && map =~# b:htmlplugin.no_maps) )
    return 3
  elseif HTML.MODES->has_key(mode) && map->maparg(mode) != ''
    if HTML#BoolVar('g:htmlplugin.no_map_override') && g:htmlplugin.doing_internal_mappings
      return 2
    else
      execute 'HTMLWARN WARNING: A mapping to "' .. map .. '" for ' .. HTML.MODES[mode] .. ' mode has been overridden for this buffer.'
      return 1
    endif
  endif

  return 0
enddef

# HTML#SI()  {{{1
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
def HTML#SI(str: string): string
  return str->substitute('[^\x00\x20-\x7E]', '\="\x16" .. submatch(0)', 'g')
enddef

# WR()  {{{1
# Function set in 'operatorfunc' for mappings that take an operator:
def WR(type: string)
  HTML.saveopts['selection'] = &selection
  &selection = 'inclusive'

  if type == 'line'
    execute 'normal `[V`]' .. b:htmltagaction
  elseif type == 'block'
    execute "normal `[\<C-V>`]" .. b:htmltagaction
  else
    execute 'normal `[v`]' .. b:htmltagaction
  endif

  &selection = HTML.saveopts['selection']

  if b:htmltaginsert
    normal! l
    silent startinsert
  endif
enddef

# ExtraMappingsAdd()  {{{1
#
# Add to the b:htmlplugin.extra_mappings variable if necessary.
#
# Arguments:
#  1 - String: The command necessary to re-define the mapping.
def ExtraMappingsAdd(arg: string)
  if ! g:htmlplugin.doing_internal_mappings && ! doing_extra_html_mappings
    HTML#SetIfUnset('b:htmlplugin.extra_mappings', '[]')
    add(b:htmlplugin.extra_mappings, arg)
  endif
enddef

# TO()  {{{1
#
# Used to make sure the 'showmatch', 'indentexpr', and 'formatoptions' options
# are off temporarily to prevent the visual mappings from causing a
# (visual)bell or inserting improperly.
#
# Arguments:
#  1 - Boolean: false - Turn options off.
#               true  - Turn options back on, if they were on before.
def TO(which: bool)
  if which
    if HTML.saveopts->has_key('formatoptions') && HTML.saveopts['formatoptions'] != ''
      &l:showmatch = HTML.saveopts['showmatch']
      &l:indentexpr = HTML.saveopts['indentexpr']
      &l:formatoptions = HTML.saveopts['formatoptions']
    endif

    # Restore the last visual mode if it was changed:
    if HTML.saveopts->has_key('visualmode') && HTML.saveopts['visualmode'] != ''
      execute 'normal! gv' .. HTML.saveopts['visualmode'] .. "\<C-c>"
      HTML.saveopts->remove('visualmode')
    endif
  else
    if &l:formatoptions != ''
      HTML.saveopts['showmatch'] = &l:showmatch
      HTML.saveopts['indentexpr'] = &l:indentexpr
      HTML.saveopts['formatoptions'] = &l:formatoptions
    endif
    &l:showmatch = false
    &l:indentexpr = ''
    &l:formatoptions = ''

    # A trick to make leading indent on the first line of visual-line
    # selections is handled properly (turn it into a character-wise
    # selection and exclude the leading indent):
    if visualmode() ==# 'V'
      HTML.saveopts['visualmode'] = visualmode()
      execute "normal! `<^v`>\<C-c>"
    endif
  endif
enddef

# HTML#TC()  {{{1
#
# Used to make sure the 'comments' option is off temporarily to prevent
# certain mappings from inserting unwanted comment leaders.
#
# Arguments:
#  1 - Boolean: false - Clear option
#               true  - Restore option
def HTML#TC(s: bool)
  if s
    if HTML.saveopts->has_key('comments') && HTML.saveopts['comments'] != ''
      &l:comments = HTML.saveopts['comments']
    endif
  else
    if &l:comments != ''
      HTML.saveopts['comments'] = &l:comments
      &l:comments = ''
    endif
  endif
enddef

# HTML#ToggleClipboard()  {{{1
#
# Used to turn off/on the inclusion of "html" in the 'clipboard' option when
# switching buffers.
#
# Arguments:
#  1 - Integer: 0 - Remove 'html' if it was removed before.
#               1 - Add 'html'.
#               2 - Auto detect which to do. (Default)
#
# (Note that g:htmlplugin.save_clipboard is set by this plugin's initialization.)
def HTML#ToggleClipboard(dowhat: number = 2): bool
  var newdowhat = dowhat

  if newdowhat == 2
    if exists('b:htmlplugin.did_mappings')
      newdowhat = 1
    else
      newdowhat = 0
    endif
  endif

  if newdowhat == 0
    if exists('g:htmlplugin.save_clipboard') != 0
      &clipboard = g:htmlplugin.save_clipboard
    else
      HTMLERROR Somehow the htmlplugin.save_clipboard global variable did not get set.
      return false
    endif
  else
    if &clipboard !~? 'html'
      g:htmlplugin.save_clipboard = &clipboard
    endif
    silent! set clipboard+=html
  endif

  return true
enddef

# VI()  {{{1
#
# Used by HTML#Map() to enter insert mode in Visual mappings in the
# right place, depending on what 'selection' is set to.
#
# Arguments:
#   None
# Return Value:
#   The proper movement command based on the value of 'selection'.
def VI(): string
  if &selection == 'inclusive'
    return "\<right>"
  else
    return "\<C-O>`>"
  endif
enddef

# HTML#ConvertCase()  {{{1
#
# Convert special regions in a string to the appropriate case determined by
# b:htmlplugin.tag_case.
#
# Arguments:
#  1 - String or List<String>: The string(s) with the regions to convert
#      surrounded by [{...}].
# Return Value:
#  The converted string(s).
def HTML#ConvertCase(str: any): any
  var newstr: list<string>
  var newnewstr: list<string>
  if type(str) == v:t_list
    newstr = str
  else
    newstr = [str]
  endif

  HTML#SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

  if b:htmlplugin.tag_case =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
    newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g'))
  elseif b:htmlplugin.tag_case =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
    newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g'))
  else
    execute 'HTMLWARN WARNING: b:htmlplugin.tag_case = "' .. b:htmlplugin.tag_case .. '" invalid, overriding to "lowercase".'
    b:htmlplugin.tag_case = 'lowercase'
    newstr = newstr->HTML#ConvertCase()
  endif

  if type(str) == v:t_list
    return newnewstr
  else
    return newnewstr[0]
  endif
enddef

# HTML#ReIndent()  {{{1
#
# Re-indent a region.  (Usually called by HTML#Map.)
#  Nothing happens if filetype indenting isn't enabled and 'indentexpr' is
#  unset.
#
# Arguments:
#  1 - Integer: Start of region.
#  2 - Integer: End of region.
#  3 - Integer: Optional - Add N extra lines below the region to re-indent.
#  4 - Integer: Optional - Add N extra lines above the region to re-indent.
#               (Two extra options because the start/end can be reversed so
#               adding to those in the function call can have wrong results.)
# Return Value:
#  Boolean - True if lines were reindented, false otherwise.
def HTML#ReIndent(first: number, last: number, extralines: number = 0, prelines: number = 0): bool

  def GetFiletypeInfo(): dict<string>  # {{{2
    var filetypeoutput: dict<string>
    execute('filetype')->trim()->strpart(9)->split('  ')->mapnew(
      (_, val) => {
        var newval = val->split(':')
        filetypeoutput[newval[0]] = newval[1]
      }
    )
    return filetypeoutput
  enddef  # }}}2

  var firstline: number
  var lastline: number

  if !GetFiletypeInfo()['indent']->Bool() && &indentexpr == ''
    return false
  endif

  # Make sure the range is in the proper order (although this may not be
  # necesssary for modern versions of Vim?):
  if last >= first
    firstline = first
    lastline = last
  else
    firstline = last
    lastline = first
  endif

  # Behavior of visual mappings can be unpredictable without this:
  if firstline == lastline
    lastline += 1
  endif

  firstline -= prelines
  lastline += extralines

  if firstline < 1
    firstline = 1
  endif
  if lastline > line('$')
    lastline = line('$')
  endif

  execute ':' .. firstline .. ',' .. lastline .. 'normal! =='

  return true
enddef

# HTML#NextInsertPoint()  {{{1
#
# Position the cursor at the next point in the file that needs data.
#
# Arguments:
#  1 - Character: Optional, the mode the function is being called from. 'n'
#                 for normal, 'i' for insert.  If 'i' is used the function
#                 enables an extra feature where if the cursor is on the start
#                 of a closing tag it places the cursor after the tag.
#                 Default is 'n'.
#  2 - Character: Optional, the direction to search in, 'f' for forward and
#                 'b' for backward.  Default, of course, is forward.
# Return Value:
#  True if the cursor was repositioned, false otherwise.
# Known Limitations:
#  Sometimes this will skip an insert point on the same line if there are
#  multiple matches.
def HTML#NextInsertPoint(mode: string = 'n', direction: string = 'f'): bool
  var done: bool

  # Tab in insert mode on the beginning of a closing tag jumps us to
  # after the tag:
  if mode =~? '^i' && direction =~? '^f'
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

      return true
    endif
  endif

  # This regexp looks like someone ran their fingers along the keyboard
  # randomly, but it does work and even correctly positions the cursor:
  return '<\_[^<>]\{-}\(["'']\)\zs\1\_[^<>]*>\|<\([^ <>]\+\)\_[^<>]*>\_s\{-}\zs\n\?\s\{-}<\/\2>\|<!--\_s\{-}\zs\_s\?-->'->search('w' .. (direction =~? '^b' ? 'b' : '')) > 0
enddef

# HTML#SmartTag()  {{{1
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

def HTML#SmartTag(tag: string, mode: string): string
  var newmode = mode->strpart(0, 1)->tolower()
  var newtag = tag->tolower()
  var which: string
  var ret: string
  var line: number
  var column: number

  if ! HTML.smarttags->has_key(newtag)
    execute 'HTMLERROR Unknown smart tag: ' .. newtag
    return ''
  endif

  if newtag == 'comment'
    [line, column] = searchpairpos('<!--', '', '-->', 'ncW')
  else
    var realtag = tag->substitute('\d\+$', '', '')
    [line, column] = searchpairpos('\c<' .. realtag
      .. '\>[^>]*>', '', '\c<\/' .. realtag .. '>', 'ncW')
  endif

  which = (line == 0 && column == 0 ? 'o' : 'c')

  ret = HTML.smarttags[newtag][newmode][which]->HTML#ConvertCase()

  if newmode == 'v'
    # If 'selection' is "exclusive" all the visual mode mappings need to
    # behave slightly differently:
    ret = ret->substitute('`>a\C', '`>i' .. VI(), 'g')

    if HTML.smarttags[newtag][newmode]->has_key('insert')
        && HTML.smarttags[newtag][newmode]['insert'] 
      ret ..= "\<right>"
      silent startinsert
    endif
  endif

  return ret
enddef

# HTML#DetectCharset()  {{{1
#
# Detects the HTTP-EQUIV Content-Type charset based on Vim's current
# encoding/fileencoding.
#
# Arguments:
#  None
# Return Value:
#  The value for the Content-Type charset based on 'fileencoding' or
#  'encoding'.
def HTML#DetectCharset(): string
  var enc: string

  if exists('b:htmlplugin.charset')
    return b:htmlplugin.charset
  elseif exists('g:htmlplugin.charset')
    return g:htmlplugin.charset
  endif

  if &fileencoding == ''
    enc = tolower(&encoding)
  else
    enc = tolower(&fileencoding)
  endif

  # The iso-8859-* encodings are valid for the Content-Type charset header:
  if enc =~? '^iso-8859-'
    return toupper(enc)
  endif

  enc = enc->substitute('\W', '_', 'g')

  if HTML.CHARSETS[enc] != ''
    return HTML.CHARSETS[enc]
  endif

  return g:htmlplugin.default_charset
enddef

# HTML#GenerateTable()  {{{1
#
# Interactively creates a table.
#
# Arguments:
#  The arguments are optional, but if they are provided the funtion runs
#  non-interactively.
#
#  Argument:      Behavior:
#  {rows}         Number: Number of rows to insert
#  {columns}      Number: Number of columns to insert
#  {border-width} Number: Width of the border in pixels (not HTML5
#                 compatible; leave at 0 and use CSS)
#  {thead}        Boolean: Whether to insert a table header
#  {tfoot}        Boolean: Whether to insert a table footer
#  
#  If a table header or table footer is inserted, a table body tag will also
#  be inserted.  Note that the header and footer is exclusive of the row
#  count.
# Return Value:
#  Boolean: Whether a table was generated
def HTML#GenerateTable(rows: number = -1, columns: number = -1, border: number = -1, thead: bool = false, tfoot: bool = false): bool
  var charpos = getcharpos('.')
  var newrows: number
  var newcolumns: number
  var newborder: number
  var newthead = thead
  var newtfoot = tfoot
  var lines: list<string>

  if rows < 0
    newrows = inputdialog('Number of rows: ')->str2nr()
  else
    newrows = rows
  endif
  if columns < 0
    newcolumns = inputdialog('Number of columns: ')->str2nr()
  else
    newcolumns = columns
  endif

  if newrows < 1 || newcolumns < 1
    HTMLERROR Rows and columns must be positive, non-zero integers.
    return false
  endif

  if border < 0
    newborder = inputdialog('Border width of table [none]: ', '', '0')->str2nr()
  else
    newborder = border
  endif

  if rows < 0 && columns < 0 && border < 0
    newthead = confirm('Insert a table header?', "&Yes\n&No", 2, 'Question') == 1
    newtfoot = confirm('Insert a table footer?', "&Yes\n&No", 2, 'Question') == 1
  endif

  if newborder > 0
    lines->add('<[{TABLE BORDER}]="' .. border .. '">')
  else
    lines->add('<[{TABLE}]>')
  endif

  if newthead
    lines->add('<[{THEAD}]>')
    lines->add('<[{TR}]>')
    for c in newcolumns->range()
      lines->add('<[{TH></TH}]>')
    endfor
    lines->add('</[{TR}]>')
    lines->add('</[{THEAD}]>')
  endif

  if newthead || newtfoot
    lines->add('<[{TBODY}]>')
  endif

  for r in newrows->range()
    lines->add('<[{TR}]>')

    for c in newcolumns->range()
      lines->add('<[{TD></TD}]>')
    endfor

    lines->add('</[{TR}]>')
  endfor

  if newthead || newtfoot
    lines->add('</[{TBODY}]>')
  endif

  if newtfoot
    lines->add('<[{TFOOT}]>')
    lines->add('<[{TR}]>')
    for c in newcolumns->range()
      lines->add('<[{TD></TD}]>')
    endfor
    lines->add('</[{TR}]>')
    lines->add('</[{TFOOT}]>')
  endif

  lines->add("</[{TABLE}]>")

  lines = lines->HTML#ConvertCase()

  lines->append('.')

  execute ':' .. (line('.') + 1) .. ',' .. (line('.') + lines->len()) .. 'normal! =='

  setcharpos('.', charpos)

  if getline('.') =~ '^\s*$'
    delete
  endif

  HTML#NextInsertPoint()

  return true
enddef

# HTML#MappingsControl()  {{{1
#
# Disable/enable all the mappings defined by
# HTML#Map()/HTML#Mapo().
#
# Arguments:
#  1 - String: Whether to disable or enable the mappings:
#               d/disable/off:   Clear the mappings
#               e/enable/on:     Redefine the mappings
#               r/reload/reinit: Completely reload the script
#               h/html:          Reload the mapppings in HTML mode
#               x/xhtml:         Reload the mapppings in XHTML mode
# Return Value:
#  Boolean: False for an error, true otherwise
#
# Note:
#  This expects g:htmlplugin.file to be set by the HTML plugin.
var doing_extra_html_mappings = false
var quiet_errors: bool
def HTML#MappingsControl(dowhat: string): bool

  # DoExtraMappings()  {{{2
  #
  # Iterate over all the commands to define extra mappings (those that weren't
  # defined by the plugin):
  #
  # Arguments:
  #  None
  # Return Value:
  #  None
  def DoExtraMappings(): void
    doing_extra_html_mappings = true
    b:htmlplugin.extra_mappings->mapnew(
      (_, mapping) => {
        silent! execute mapping
        return
      }
    )
    doing_extra_html_mappings = false
  enddef

  # ClearMappings() {{{2
  #
  # Iterate over all the commands to clear the mappings.  This used to be just
  # one long single command but that had drawbacks, so now it's a List that must
  # be looped over:
  #
  # Arguments:
  #  None
  # Return Value:
  #  None
  def ClearMappings(): void
    b:HTMLclearMappings->mapnew(
      (_, mapping) => {
        silent! execute mapping
        return
      }
    )
    b:HTMLclearMappings = []
    unlet b:htmlplugin.did_mappings
  enddef  # }}}2

  if exists('b:htmlplugin.did_mappings_init') == 0
    HTMLERROR The HTML macros plugin was not sourced for this buffer.
    return false
  endif

  if exists('g:htmlplugin.file') == 0
    HTMLERROR Somehow the HTML plugin reference global variable did not get set.
    return false
  endif

  if b:htmlplugin.did_mappings_init < 0
    unlet b:htmlplugin.did_mappings_init
  endif

  if dowhat =~? '^\%(d\%(isable\)\?\|off\|false\|0\)$'
    if exists('b:htmlplugin.did_mappings') == 1
      ClearMappings()
      if exists('g:htmlplugin.did_menus') == 1
        HTML#MenuControl('disable')
      endif
    elseif !quiet_errors
      HTMLERROR The HTML mappings are already disabled.
      return false
    endif
  elseif dowhat =~? '^\%(e\%(nable\)\?\|on\|true\|1\)$'
    if exists('b:htmlplugin.did_mappings') == 1
      HTMLERROR The HTML mappings are already enabled.
    else
      execute 'source ' .. g:htmlplugin.file
      HTML#ReadEntities(false)
      HTML#ReadTags(false)
      if exists('b:htmlplugin.extra_mappings') == 1
        DoExtraMappings()
      endif
    endif
  elseif dowhat =~? '^\%(r\%(eload\|einit\)\?\)$'
    execute 'HTMLMESG Reloading: ' .. fnamemodify(g:htmlplugin.file, ':t')
    quiet_errors = true
    HTML#MappingsControl(off)
    b:htmlplugin.did_mappings_init = -1
    silent! unlet g:htmlplugin.did_menus g:htmlplugin.did_toolbar g:htmlplugin.did_commands
    execute 'silent! unmenu ' .. g:htmlplugin.toplevel_menu_escaped
    execute 'silent! unmenu! ' .. g:htmlplugin.toplevel_menu_escaped
    HTML#MappingsControl(on)
    autocmd SafeState * ++once HTMLReloadFunctions
    quiet_errors = false
  elseif dowhat =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
    if b:htmlplugin.do_xhtml_mappings
      HTMLERROR Can't switch to uppercase while editing XHTML.
      return false
    endif
    if exists('b:htmlplugin.did_mappings') != 1
      HTMLERROR The HTML mappings are disabled, changing case is not possible.
      return false
    endif
    if b:htmlplugin.tag_case =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
      return false
    endif
    HTML#MappingsControl(off)
    b:htmlplugin.tag_case = 'uppercase'
    HTML#MappingsControl(on)
  elseif dowhat =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
    if exists('b:htmlplugin.did_mappings') != 1
      HTMLERROR The HTML mappings are disabled, changing case is not possible.
      return false
    endif
    if b:htmlplugin.tag_case =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
      return false
    endif
    HTML#MappingsControl(off)
    b:htmlplugin.tag_case = 'lowercase'
    HTML#MappingsControl(on)
  elseif dowhat =~? '^h\%(tml\)\?$'
    if exists('b:htmlplugin.tag_case_save') == 1
      b:htmlplugin.tag_case = b:htmlplugin.tag_case_save
    endif
    b:htmlplugin.do_xhtml_mappings = false
    HTML#MappingsControl(off)
    b:htmlplugin.did_mappings_init = -1
    HTML#MappingsControl(on)
  elseif dowhat =~? '^x\%(html\)\?$'
    b:htmlplugin.do_xhtml_mappings = true
    HTML#MappingsControl(off)
    b:htmlplugin.did_mappings_init = -1
    HTML#MappingsControl(on)
  else
    execute 'HTMLERROR Invalid argument: ' .. dowhat
    return false
  endif

  return true
enddef

# HTML#MenuControl()  {{{1
#
# Disable/enable the HTML menu and toolbar.
#
# Arguments:
#  1 - String: Optional, Whether to disable or enable the menus:
#                empty: Detect which to do
#                "disable": Disable the menu and toolbar
#                "enable": Enable the menu and toolbar
# Return Value:
#  Boolean: False if an error occurred, true otherwise
def HTML#MenuControl(which: string = 'detect'): bool
  if which !~? '^disable$\|^enable$\|^detect$'
    exe 'HTMLERROR Invalid argument: ' .. which
    return false
  endif

  if which == 'disable' || exists('b:htmlplugin.did_mappings') == 0
    execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
    execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.*'
    if exists('g:htmlplugin.did_toolbar') == 1
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
      amenu enable ToolBar.Help
    endif
    if exists('b:htmlplugin.did_mappings_init') == 1 && exists('b:htmlplugin.did_mappings') == 0
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.*'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Enable\ Mappings'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Reload\ Mappings'
    endif
  elseif which == 'enable' || exists('b:htmlplugin.did_mappings_init') == 1
    execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
    if exists('b:htmlplugin.did_mappings') == 1
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.*'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.*'
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Enable\ Mappings'

      if HTML#BoolVar('b:htmlplugin.do_xhtml_mappings')
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ XHTML\ mode'
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ HTML\ mode'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ uppercase'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ lowercase'
      else
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ XHTML\ mode'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ HTML\ mode'

        if b:htmlplugin.tag_case =~? '^u\%(pper\%(case\)\?\)\?'
          execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ uppercase'
        else
          execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Switch\ to\ lowercase'
        endif
      endif

      if exists('g:htmlplugin.did_toolbar') == 1
        amenu enable ToolBar.*
      endif
    else
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.Control.Enable\ Mappings'
    endif
  endif

  return true
enddef

# ToRGB()  {{{1
def ToRGB(color: string): string
  if color !~ '^#\x\{6}$'
    execute 'HTMLERROR Color must be a six-digit hexadecimal value prefixed by a #'
    return ''
  endif
  var rgb = color[1 : -1]->split('\x\{2}\zs')->mapnew((_, val) => str2nr(val, 16))
  return printf('rgb(%d, %d, %d)', rgb[0], rgb[1], rgb[2])
enddef

# HTML#ColorChooser()  {{{1
# 
# Use the popup feature of Vim to display HTML colors for selection
#
# Arguments:
#
#  1 - String: Default is "i", how to insert the chosen color
# Return Value:
#  None
def HTML#ColorChooser(how: string = 'i'): void
  if exists('b:htmlplugin.did_mappings_init') == 0
    HTMLERROR Not in an HTML buffer.
    return
  endif
  
  var maxw = 0
  var doname = false
  var dorgb = false
  var mode = mode()

  def CCSelect(id: number, result: number)  # {{{2
    if result < 0
      return
    endif

    var color = HTML.COLOR_LIST[result - 1]

    if doname
      execute 'normal! ' .. how .. color[2]
    elseif dorgb
      execute 'normal! ' .. how .. color[1]->ToRGB()
    else
      execute 'normal! ' .. how .. color[1]
    endif

    if mode == 'i'
      if col('.') == getline('.')->strlen()
        startinsert!
      else
        execute "normal! l"
      endif
    else
      stopinsert
    endif
  enddef

  def CCKeyFilter(id: number, key: string): bool  # {{{2
    var newkey = key
    if key == "\<tab>" || key ==? 'n' || key ==? 'f'
      newkey = 'j'
    elseif key == "\<s-tab>" || key ==? 'p' || key ==? 'b'
      newkey = 'k'
    elseif key ==? 'r'
      dorgb = true
      newkey = "\<cr>"
    elseif key == "\<s-cr>"
      doname = true
      newkey = "\<cr>"
    elseif key ==? 'q'
      call popup_close(id, -2)
      return true
    elseif key == "\<2-leftmouse>" || key == "\<s-2-leftmouse>"
      if getmousepos()['screencol'] < (popup_getpos(id)['core_col'] - 1) ||
          getmousepos()['screenrow'] < (popup_getpos(id)['core_line']) ||
          getmousepos()['screencol'] > (popup_getpos(id)['core_col'] + popup_getpos(id)['core_width'] - 1) ||
          getmousepos()['screenrow'] > (popup_getpos(id)['core_line'] + popup_getpos(id)['core_height'] - 1)
        newkey = key
      else
        if key == "\<s-2-leftmouse>"
          dorgb = true
        elseif getmousepos()['screencol'] < (popup_getpos(id)['core_col'] + popup_getpos(id)['core_width'] - 9)
          doname = true
        endif

        call popup_close(id, popup_getpos(id)['firstline'] + getmousepos()['winrow'] - 2)
        return true
      endif
    endif

	  return popup_filter_menu(id, newkey)
  enddef  # }}}2
  
  HTML.COLOR_LIST->mapnew(
    (_, value) => {
      if (value[0]->strlen()) > maxw
        maxw = value[0]->strlen()
      endif
      return
    }
  )

  var colorwin = HTML.COLOR_LIST->mapnew(
      (_, value) => printf('%' .. maxw .. 's = %s', value[0], value[1])
    )->popup_menu({
      callback: CCSelect, filter: CCKeyFilter, 
      pos: 'topleft',     col: 'cursor', 
      line: 1,            maxheight: &lines - 3, 
      close: 'button',
    })

  HTML.COLOR_LIST->mapnew(
    (_, value) => {
      win_execute(colorwin, 'syntax match hc_' .. value[2] .. ' /' .. value[1] .. '/')
      win_execute(colorwin, 'highlight hc_' .. value[2] .. ' guibg=' .. value[1])

      return
    }
  )
enddef

# HTML#Template()  {{{1
#
# Determine whether to insert the HTML template.
#
# Arguments:
#  None
# Return Value:
#  Boolean - Whether the cursor is not on an insert point.
def HTML#Template(): bool

  # InsertTemplate()  {{{2
  #
  # Actually insert the HTML template.
  #
  # Arguments:
  #  None
  # Return Value:
  #  Boolean - Whether the cursor is not on an insert point.
  def InsertTemplate(): bool
    if g:htmlplugin.authoremail != ''
      g:htmlplugin.authoremail_encoded = g:htmlplugin.authoremail->HTML#EncodeString()
    else
      g:htmlplugin.authoremail_encoded = ''
    endif

    var template = ''

    if exists('b:htmlplugin.template') && b:htmlplugin.template != ''
      template = b:htmlplugin.template
    elseif exists('g:htmlplugin.template') && g:htmlplugin.template != ''
      template = g:htmlplugin.template
    endif

    if template != ''
      if template->expand()->filereadable()
        silent execute ':0read ' .. template
      else
        execute 'HTMLERROR Unable to insert template file: ' .. template
        HTMLERROR 'Either it doesn't exist or it isn't readable.'
        return false
      endif
    else
      :0put =b:htmlplugin.internal_template
    endif

    if getline('$') =~ '^\s*$'
      execute ':$delete'
    endif

    if getline(1) =~ '^\s*$'
      execute ':1delete'
    endif

    # Replace the various tokens with appropriate values:
    :silent! :%s/\C%authorname%/\=g:htmlplugin.authorname/g
    :silent! :%s/\C%authoremail%/\=g:htmlplugin.authoremail_encoded/g
    :silent! :%s/\C%bgcolor%/\=g:htmlplugin.bgcolor/g
    :silent! :%s/\C%textcolor%/\=g:htmlplugin.textcolor/g
    :silent! :%s/\C%linkcolor%/\=g:htmlplugin.linkcolor/g
    :silent! :%s/\C%alinkcolor%/\=g:htmlplugin.alinkcolor/g
    :silent! :%s/\C%vlinkcolor%/\=g:htmlplugin.vlinkcolor/g
    :silent! :%s/\C%date%/\=strftime('%B %d, %Y')/g
    :silent! :%s/\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%/\=submatch(1)->substitute('\\%', '%%', 'g')->substitute('\\\@<!!', '%', 'g')->strftime()/g
    :silent! :%s/\C%time%/\=strftime('%r %Z')/g
    :silent! :%s/\C%time12%/\=strftime('%r %Z')/g
    :silent! :%s/\C%time24%/\=strftime('%T')/g
    :silent! :%s/\C%charset%/\=HTML#DetectCharset()/g
    :silent! :%s#\C%vimversion%#\=(v:version / 100) .. '.' .. (v:version % 100) .. '.' .. (v:versionlong % 10000)#g

    go 1

    HTML#NextInsertPoint('n')
    if getline('.')[col('.') - 2 : col('.') - 1] == '><'
        || (getline('.') =~ '^\s*$' && line('.') != 1)
      return true
    else
      return false
    endif
  enddef  # }}}2

  var ret = false
  HTML.saveopts['ruler'] = &ruler
  HTML.saveopts['showcmd'] = &showcmd
  set noruler noshowcmd

  if line('$') == 1 && getline(1) == ''
    ret = InsertTemplate()
  else
    var YesNoOverwrite = confirm("Non-empty file.\nInsert template anyway?", "&Yes\n&No\n&Overwrite", 2, 'Question')
    if YesNoOverwrite == 1
      ret = InsertTemplate()
    elseif YesNoOverwrite == 3
      execute '%delete'
      ret = InsertTemplate()
    endif
  endif

  &ruler = HTML.saveopts['ruler']
  &showcmd = HTML.saveopts['showcmd']

  return ret
enddef

# HTML#MenuJoin()  {{{1
#
# Simple function to join menu name array into a valid menu name, escaped
#
# Arguments:
#  1 - List: The menu name
# Return Value:
#  The menu name joined into a single string, escaped
def HTML#MenuJoin(menuname: list<string>): string
  return menuname->mapnew((key, value) => value->escape(' .'))->join('.')
enddef

# MenuPriorityPrefix()  {{{1
#
# Allow a specified menu priority to be properly prefixed with periods so it
# matches the user configuration of the toplevel menu.
#
# Arguments:
#  None
# Return Value:
#  String - the number of periods necessary to properly specify the prefix
def MenuPriorityPrefix(): string
  return repeat('.', len(g:htmlplugin.toplevel_menu) - 1)
enddef

# HTML#Menu()  {{{1
#
# Generate plain HTML menu items without any extra magic
#
# Arguments:
#  1 - String: The menu type (amenu, imenu, omenu)
#  2 - String: The menu numeric level(s) ("-" for automatic)
#  3 - List:   The menu name, split into submenu heirarchy as a list
#  4 - String: The keystrokes to run (usually going to be a mapping to call)
# Return Value:
#  None
def HTML#Menu(type: string, level: string, name: list<string>, item: string): void
  var newlevel: string
  var newname: list<string>
  var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
  var nameescaped: string

  if name[0] == 'ToolBar' || name[0] == 'PopUp'
    newname = name
  else
    newname = name->extend(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  if level ==? 'auto'
    if g:htmlplugin.toplevel_menu_priority > 0
        && name[0] != 'ToolBar' && name[0] != 'PopUp'
      newlevel = MenuPriorityPrefix() .. g:htmlplugin.toplevel_menu_priority
    else
      newlevel = ''
    endif
  elseif level == '-' || level == ''
    newlevel = ''
  else
    newlevel = MenuPriorityPrefix() .. level
  endif

  execute type .. ' ' .. newlevel .. ' ' .. nameescaped .. ' ' .. item
enddef

# HTML#LeadMenu()  {{{1
#
# Generate HTML menu items
#
# Arguments:
#  1 - String: The menu type (amenu, imenu, omenu)
#  2 - String: The menu numeric level(s) ("-" for automatic)
#  3 - List:   The menu name, split into submenu heirarchy as a list
#  4 - String: Optional, normal mode command to execute before running the
#              menu command
# Return Value:
#  None
def HTML#LeadMenu(type: string, level: string, name: list<string>, item: string, pre: string = ''): void
  var newlevel: string
  var newname: list<string>
  var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
  var nameescaped: string

  if name[0] == 'ToolBar'
    newname = name
  else
    newname = name->extend(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  if level == '-' || level == ''
    newlevel = ''
  else
    newlevel = MenuPriorityPrefix() .. level
  endif

  execute type .. ' ' .. newlevel .. ' ' .. nameescaped .. '<tab>'
    .. leaderescaped .. item .. ' ' .. pre .. g:htmlplugin.map_leader .. item
enddef

# HTML#EntityMenu()  {{{1
#
# Generate HTML character entity menu items
#
# Arguments:
#  1 - List: The menu name, split into submenu heirarchy as a list
#  2 - String: The item
#  3 - String: The symbol it generates
# Return Value:
#  None
def HTML#EntityMenu(name: list<string>, item: string, symb: string = ''): void
  var newname = name->extend(['Character Entities'], 0)
  var nameescaped: string

  if g:htmlplugin.toplevel_menu != []
    newname = newname->extend(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  var newsymb = symb
  var leaderescaped = g:htmlplugin.map_entity_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
  var itemescaped = item->escape('&<.|')->substitute('\\&', '\&\&', 'g')

  if newsymb != ''
    # Makes it so UTF8 characters don't have to be hardcoded:
    if newsymb =~# '^\\[xuU]\x\+$'
      newsymb = newsymb->substitute('^\\[xuU]', '', '')->str2nr(16)->nr2char(1)
    endif

    newsymb = '\ (' .. newsymb->escape(' &<.|') .. ')'
    newsymb = newsymb->substitute('\\&', '\&\&', 'g')
  endif

  execute 'imenu ' .. nameescaped .. newsymb .. '<tab>'
    .. leaderescaped .. itemescaped .. ' '
    .. g:htmlplugin.map_entity_leader .. item
  execute 'nmenu ' .. nameescaped .. newsymb .. '<tab>'
    .. leaderescaped .. itemescaped .. ' ' .. 'i'
    .. g:htmlplugin.map_entity_leader .. item .. '<esc>'
  execute 'vmenu ' .. nameescaped .. newsymb .. '<tab>'
    .. leaderescaped .. itemescaped .. ' ' .. 's'
    .. g:htmlplugin.map_entity_leader .. item .. '<esc>'
enddef

# HTML#ColorsMenu()  {{{1
#
# Generate HTML colors menu items
#
# Arguments:
#  1 - String: The color name
#  2 - String: The color hex code
# Return Value:
#  None
def HTML#ColorsMenu(name: string, color: string, namens: string): void
  var c = name->strpart(0, 1)->toupper()
  var newname = [name]->extend(['&Colors', '&' .. HTML.COLORS_SORT[c]], 0)
  var nameescaped: string
  var rgb: string

  if g:htmlplugin.toplevel_menu != []
    newname = newname->extend(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  rgb = color->ToRGB()

  execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Name ' .. namens
  execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Name i' .. namens .. '<esc>'
  execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Name s' .. namens .. '<esc>'
  execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Hexadecimal ' .. color
  execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Hexadecimal i' .. color .. '<esc>'
  execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &Hexadecimal s' .. color .. '<esc>'
  execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &RGB ' .. rgb
  execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &RGB i' .. rgb .. '<esc>'
  execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color .. ').Insert\ &RGB s' .. rgb .. '<esc>'
enddef

# HTML#ReadTags()  {{{1
#  Purpose:
#   Read in the HTML tags JSON file and define both the mappings and menu at
#   the same time, unless otherwise specified.
#
#  Arguments:
#   1 - Boolean: Optional, whether to define the menus
#   2 - String:  Optional, what json file to read
#  Return Value:
#   Boolean - Whether the json file was successfully read in without error
def HTML#ReadTags(domenu: bool = true, file: string = HTML.TAGS_FILE): bool
  var maplhs: string
  var menulhs: string
  var jsonfile = file->findfile(&runtimepath)
  var rval = true

  if jsonfile == ''
    execute 'HTMLERROR ' .. file .. ' is not found in the runtimepath. No entity mappings or menus have been defined.'
    return false
  elseif ! jsonfile->filereadable()
    execute 'HTMLERROR ' .. jsonfile .. ' is not readable. No entity mappings or menus have been defined.'
    return false
  endif

  for json in jsonfile->readfile()->join(' ')->json_decode()
    try
      if json->has_key('menus') && json.menus->has_key('n') && json.menus.n[2] ==? '<nop>'
        if domenu
          HTML#Menu('menu', json.menus.n[0], json.menus.n[1], '<nop>')
        endif
      else
        if json->has_key('lhs')
          maplhs = '<lead>' .. json.lhs
          menulhs = json.lhs
        else
          maplhs = ""
          menulhs = ""
        endif

        if json->has_key('smarttag')
          # Translate \<...> strings to their corresponding actual character:
          var smarttag = json.smarttag->string()->substitute('\\<[^>]\+>', '\=eval(''"'' .. submatch(0) .. ''"'')', 'g')

          HTML.smarttags->extend(smarttag->eval())
        endif

        if json->has_key('maps')
          if json.maps->has_key('i')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'i') == ''
            HTML#Map('inoremap',
              (maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs),
              json.maps.i[1]
            )
          endif

          if json.maps->has_key('v')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'v') == ''
            HTML#Map('vnoremap',
              (maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs),
              json.maps.v[1],
              json.maps.v[2]
            )
          endif

          if json.maps->has_key('n')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.n[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'n') == ''
            HTML#Map('nnoremap',
              (maplhs == '' ? '<lead>' .. json.maps.n[0] : maplhs),
              json.maps.n[1]
            )
          endif

          if json.maps->has_key('o')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.o[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'o') == ''
            HTML#Mapo(
              (maplhs == '' ? '<lead>' .. json.maps.o[0] : maplhs),
              json.maps.o[1]
            )
          endif
        endif

        if domenu && json->has_key('menus')
          if json.menus->has_key('i')
            HTML#LeadMenu('imenu',
              json.menus.i[0],
              json.menus.i[1],
              (menulhs == '' ? json.menus.i[2] : menulhs),
              json.menus.i[3]
            )
          endif

          if json.menus->has_key('v')
            HTML#LeadMenu('vmenu',
              json.menus.v[0],
              json.menus.v[1],
              (menulhs == '' ? json.menus.v[2] : menulhs),
              json.menus.v[3]
            )
          endif

          if json.menus->has_key('n')
            HTML#LeadMenu('nmenu',
              json.menus.n[0],
              json.menus.n[1],
              (menulhs == '' ? json.menus.n[2] : menulhs),
              json.menus.n[3]
            )
          endif

          if json.menus->has_key('a')
            HTML#LeadMenu(
              'amenu',
              json.menus.a[0],
              json.menus.a[1],
              (menulhs == '' ? json.menus.a[2] : menulhs),
              json.menus.a[3]
            )
          endif
        endif
      endif
    catch /.*/
      execute 'HTMLERROR ' .. v:exception
      execute 'HTMLERROR Potentially malformed json in ' .. file .. ', section: ' .. json->string()
      rval = false
    endtry
  endfor

  return rval
enddef

# HTML#ReadEntities()  {{{1
#  Purpose:
#   Read in the HTML entities JSON file and define both the mappings and menu
#   at the same time, unless otherwise specified.
#
#  Arguments:
#   1 - Boolean: Optional, whether to define the menus
#   2 - String:  Optional, what json file to read
#  Return Value:
#   Boolean - Whether the json file was successfully read in without error
def HTML#ReadEntities(domenu: bool = true, file: string = HTML.ENTITIES_FILE): bool
  var jsonfile = file->findfile(&runtimepath)
  var rval = true

  if jsonfile == ''
    execute 'HTMLERROR ' .. file .. ' is not found in the runtimepath. No entity mappings or menus have been defined.'
    return false
  elseif ! jsonfile->filereadable()
    execute 'HTMLERROR ' .. jsonfile .. ' is not readable. No entity mappings or menus have been defined.'
    return false
  endif

  for json in jsonfile->readfile()->join(' ')->json_decode()
    if json->len() != 4 || json[2]->type() != v:t_list
      execute 'HTMLERROR Malformed json in ' .. file .. ', section: ' .. json->string()
      rval = false
      continue
    endif
    if json[3] ==? '<nop>'
      if domenu
        HTML#Menu('menu', '-', json[2]->extend(['Character &Entities'], 0), '<nop>')
      endif
    else
      if maparg(g:htmlplugin.map_entity_leader .. json[0], 'i') == ''
        HTML#Map('inoremap', '<elead>' .. json[0], json[1])
      endif
      if domenu
        HTML#EntityMenu(json[2], json[0], json[3])
      endif
    endif
  endfor

  return rval
enddef

defcompile

if !exists('g:htmlplugin.function_files') | g:htmlplugin.function_files = [] | endif
add(g:htmlplugin.function_files, expand('<sfile>:p'))->sort()->uniq()

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
