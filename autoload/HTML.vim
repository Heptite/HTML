vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8024023
  finish
endif

# Various functions for the HTML macros filetype plugin.
#
# Last Change: January 09, 2022
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 1998-2022 Christian J. Robinson <heptite(at)gmail(dot)com>
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

if ! exists('g:htmlplugin.did_commands') || ! g:htmlplugin.did_commands   # {{{1
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

import "../import/HTML.vim"

# Used in a bunch of places so some functions don't have to be globally
# exposed:
const self_sid = expand('<SID>')
#g:htmlplugin.functions_sid = self_sid

# Can't be imported because then it would have a prefix:
const off = 'off'
const on = 'on'
#const yes = 'yes'
#const no = 'no'

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
    .. "Version: " .. (HTML.VERSION) .. "\n" .. "Written by: "
    .. (HTML.AUTHOR) .. ' <' .. (HTML.EMAIL) .. ">\n"
    .. "With thanks to Doug Renze for the original concept,\n"
    .. "Devin Weaver for the original mangleImageTag,\n"
    .. "Israel Chauca Fuentes for the MacOS version of the browser\n"
    .. "launcher code, and several others for their contributions.\n"
    .. (HTML.COPYRIGHT) .. "\n" .. "URL: " .. (HTML.HOMEPAGE)

  if message->confirm("&Visit Homepage\n&Dismiss", 2, 'Info') == 1
    BrowserLauncher#Launch('default', 0, HTML.HOMEPAGE)
  endif
enddef

# HTML#SetIfUnset()  {{{1
#
# Purpose:
#  Set a variable if it's not already set. Cannot be used for script-local
#  variables.
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
    execute 'HTMLERROR ' .. ' Cannot set a local variable with '
      .. expand('<stack>')
    return -1
  elseif variable !~# '^[bgstvw]:'
    newvariable = 'g:' .. variable
  endif

  if args->len() == 0
    execute 'HTMLERROR E119: Not enough arguments for ' .. expand('<stack>')
    return -1
  elseif type(args[0]) == v:t_list || type(args[0]) == v:t_dict
      || type(args[0]) == v:t_number
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
# Purpose:
#  Helper to HTML#BoolVar() -- Test the string passed to it and
#  return true/false based on that string.
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

  execute 'HTMLERROR ' .. expand('<stack>')
    .. ' Unknown type for Bool(): ' .. value->typename()
  return false
enddef

# HTML#BoolVar()  {{{1
#
# Purpose:
#  Given a string, test to see if a variable by that string name exists, and
#  if so, whether it's set to 1|true|yes|on / 0|false|no|off|none|null
#  (Actually, anything not listed here also returns as true.)
# Arguments:
#  1 - String: The name of the variable to test (not its value!)
# Return Value:
#  Boolean - The value of the variable in boolean format
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
# Purpose:
#  Given a string, test to see if a variable by that string name exists.
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
# Purpose:
#  Create a list of files that have contents matching a pattern.
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
      ++inc
      if max > 0 && inc >= max
        break
      endif
    endfor
  endfor

  return matched
enddef

# HTML#TranscodeString()  {{{1
#
# Purpose:
#  Encode the characters in a string to/from their HTML representations.
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
def HTML#TranscodeString(str: string, code: string = ''): string

  # CharToEntity()  {{{2
  #
  # Purpose:
  #  Convert a character to its corresponding character entity, or its numeric
  #  form if the entity doesn't exist in the lookup table.
  # Arguments:
  #  1 - Character: The character to encode
  # Return Value:
  #  String: The entity representing the character
  def CharToEntity(char: string): string
    var newchar: string

    if char->strchars(1) > 1
      execute 'HTMLERROR ' .. expand('<stack>')
        .. ' Argument must be one character.'
      return char
    endif

    if HTML.DictCharToEntities->has_key(char)
      newchar = HTML.DictCharToEntities[char]
    else
      newchar = printf('&#x%X;', char->char2nr())
    endif

    return newchar
  enddef  # }}}2

  var out = str

  if code == ''
    out = out->split('\zs')->mapnew((_, char) => char->CharToEntity())->join('')
  elseif code == 'x'
    out = out->split('\zs')->mapnew((_, char) => printf("&#x%x;", char->char2nr()))->join('')
  elseif code == '%'
    out = out->substitute('[\x00-\x99]', '\=printf("%%%02X", submatch(0)->char2nr())', 'g')
  elseif code =~? '^d\%(ecode\)\=$'
    out = out->substitute('\(&[A-Za-z0-9]\+;\|&#x\x\+;\|&#\d\+;\|%\x\x\)', '\=submatch(1)->DecodeSymbol()', 'g')
  endif

  return out
enddef

# DecodeSymbol()  {{{1
#
# Purpose:
#  Decode the HTML entity or URI symbol string to its literal character
#  counterpart
# Arguments:
#  1 - String: The string to decode.
# Return Value:
#  Character: The decoded character.
def DecodeSymbol(symbol: string): string

  # EntityToChar()  {{{2
  #
  # Purpose:
  #  Convert character entities to its corresponing character.
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
  enddef  # }}}2

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
# Purpose:
#  Define the HTML mappings with the appropriate case, plus some extra stuff.
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

def HTML#Map(cmd: string, map: string, arg: string, opts: dict<any> = {}, internal: bool = false): bool
  if !exists('g:htmlplugin.map_leader') && map =~? '^<lead>'
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' g:htmlplugin.map_leader is not set! No mapping defined.'
    return false
  endif

  if !exists('g:htmlplugin.entity_map_leader') && map =~? '^<elead>'
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' g:htmlplugin.entity_map_leader is not set! No mapping defined.'
    return false
  endif

  if map == '' || map ==? "<lead>" || map ==? "<elead>"
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' must have a non-empty lhs. No mapping defined.'
    return false
  endif

  if arg == ''
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' must have a non-empty rhs. No mapping defined.'
    return false
  endif

  if cmd =~# '^no' || cmd =~# '^map$'
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' must have one of the modes explicitly stated. No mapping defined.'
    return false
  endif

  var mode = cmd->strpart(0, 1)
  var newarg = arg
  var newmap = map->substitute('^<lead>\c', g:htmlplugin.map_leader->escape('&~\'), '')
  newmap = newmap->substitute('^<elead>\c', g:htmlplugin.entity_map_leader->escape('&~\'), '')

  if HTML.MODES->has_key(mode) && newmap->MapCheck(mode, internal) >= 2
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
    newarg = newarg->substitute('`>a\C', '`>i<C-R>=' .. self_sid .. 'VI()<CR>', 'g')

    # Note that <C-c>:-command is necessary instead of just <Cmd> because
    # <Cmd> doesn't update visual marks, which the mappings rely on:
    if opts->has_key('extra') && ! opts['extra']
      execute cmd .. ' <buffer> <silent> ' .. newmap .. " " .. newarg
    elseif opts->has_key('insert') && opts['insert'] && opts->has_key('reindent')
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. self_sid .. 'TO(false)<CR><C-O>gv' .. newarg
        .. "<C-O>:vim9cmd " .. self_sid
        .. "TO(true)<CR><C-O>m'<C-O>:vim9cmd " .. self_sid .. "ReIndent(line(\"'<\"), line(\"'>\"), "
        .. opts['reindent'] .. ')<CR><C-O>``'
    elseif opts->has_key('insert') && opts['insert']
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. self_sid .. 'TO(false)<CR>gv' .. newarg
        .. '<C-O>:vim9cmd ' .. self_sid .. 'TO(true)<CR>'
    elseif opts->has_key('reindent')
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. self_sid .. 'TO(false)<CR>gv' .. newarg
        .. ":vim9cmd " .. self_sid
        .. "TO(true)<CR>m':vim9cmd " .. self_sid .. "ReIndent(line(\"'<\"), line(\"'>\"), "
        .. opts['reindent'] .. ')<CR>``'
    else
      execute cmd .. ' <buffer> <silent> ' .. newmap
        .. ' <C-c>:vim9cmd ' .. self_sid .. 'TO(false)<CR>gv' .. newarg
        .. ':vim9cmd ' .. self_sid .. 'TO(true)<CR>'
    endif
  else
    execute cmd .. ' <buffer> <silent> ' .. newmap .. " " .. newarg
  endif

  if HTML.MODES->has_key(mode)
    add(b:htmlplugin.clear_mappings, ':' .. mode .. 'unmap <buffer> ' .. newmap)
  else
    add(b:htmlplugin.clear_mappings, ':unmap <buffer> ' .. newmap)
  endif

  # Save extra mappings so they can be restored if we need to later:
  newmap->maparg(mode, false, true)->ExtraMappingsListAdd(mode, internal)

  return true
enddef

# HTML#Mapo()  {{{1
#
# Purpose:
#  Define a normal mode map that takes an operator and assign it to its
#  corresponding visual mode mapping.
# Arguments:
#  1 - String: The mapping.
#  2 - Boolean: Optional, Whether to enter insert mode after the mapping has
#                          executed. Default false.
# Return Value:
#  Boolean: Whether a mapping was defined
def HTML#Mapo(map: string, insert: bool = false, internal: bool = false): bool
  if !exists('g:htmlplugin.map_leader') && map =~? '^<lead>'
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' g:htmlplugin.map_leader is not set! No mapping defined.'
    return false
  endif

  if map == '' || map ==? "<lead>"
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' must have a non-empty lhs. No mapping defined.'
    return false
  endif

  var newmap = map->substitute('^<lead>', g:htmlplugin.map_leader, '')

  if newmap->MapCheck('o', internal) >= 2
    # MapCheck() will echo the necessary message, so just return here
    return false
  endif

  execute 'nnoremap <buffer> <silent> ' .. newmap
    .. " :vim9cmd b:htmlplugin.tagaction = '" .. newmap .. "'<CR>"
    .. ':vim9cmd b:htmlplugin.taginsert = ' .. insert .. "<CR>"
    .. ':vim9cmd &operatorfunc = "' .. self_sid .. 'WR"<CR>g@'

  add(b:htmlplugin.clear_mappings, ':nunmap <buffer> ' .. newmap)
  newmap->maparg('n', false, true)->ExtraMappingsListAdd('n', internal)

  return true
enddef

# MapCheck()  {{{1
#
# Purpose:
#  Check to see if a mapping for a mode already exists.  If there is, and
#  overriding hasn't been suppressed, print an error.
# Arguments:
#  1 - String:    The map sequence (LHS).
#  2 - Character: The mode for the mapping.
#  3 - Boolean:   Whether an "internal" map is being defined
# Return Value:
#  0 - No mapping was found.
#  1 - A mapping was found, but overriding has /not/ been suppressed.
#  2 - A mapping was found and overriding has been suppressed.
#  3 - The mapping to be defined was suppressed by g:htmlplugin.no_maps.
#
# (Note that suppression only works for the internal mappings.)
def MapCheck(map: string, mode: string, internal: bool = false): number
  if (b:htmlplugin.doing_internal_mappings || internal) &&
        ( (exists('g:htmlplugin.no_maps')
            && g:htmlplugin.no_maps->match('^\C\V' .. map .. '\$') >= 0) ||
          (exists('b:htmlplugin.no_maps')
            && b:htmlplugin.no_maps->match('^\C\V' .. map .. '\$') >= 0) )
    return 3
  elseif HTML.MODES->has_key(mode) && map->maparg(mode) != ''
    if HTML#BoolVar('g:htmlplugin.no_map_override')
        && (b:htmlplugin.doing_internal_mappings || internal)
      return 2
    else
      execute 'HTMLWARN WARNING: A mapping of "' .. map .. '" for '
        .. HTML.MODES[mode] .. ' mode has been overridden for buffer: '
        .. expand('%')
      return 1
    endif
  endif

  return 0
enddef

# HTML#SI()  {{{1
#
# Purpose:
#  'Escape' special characters with a control-v so Vim doesn't handle them as
#  special keys during insertion.  For use in <C-R>=... type calls in
#  mappings.
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
#
# Function set in 'operatorfunc' for mappings that take an operator:
#
# Purpose:
#  Execute the actual mapping after properly visually selecting the region
#  indicated by the movement or text object the user typed.
# Arguments:
#  1 - String: The type of movement (visual mode) to be used
# Return value:
#  None
def WR(type: string)
  HTML.saveopts['selection'] = &selection
  &selection = 'inclusive'

  if type == 'line'
    execute 'normal `[V`]' .. b:htmlplugin.tagaction
  elseif type == 'block'
    execute "normal `[\<C-V>`]" .. b:htmlplugin.tagaction
  else
    execute 'normal `[v`]' .. b:htmlplugin.tagaction
  endif

  &selection = HTML.saveopts['selection']

  if b:htmlplugin.taginsert
    normal! l
    silent startinsert
  endif
enddef

# ExtraMappingsListAdd()  {{{1
#
# Purpose:
#  Add to the b:htmlplugin.extra_mappings list variable if necessary.
# Arguments:
#  1 - String: The command necessary to re-define the mapping.
#  1 - String: The mode necessary to re-define the mapping.
# Return Value:
#  Boolean: Whether a mapping was added to the extra mappings list
def ExtraMappingsListAdd(arg: dict<any>, mode: string, internal: bool = false): bool
  if ! (b:htmlplugin.doing_internal_mappings || internal)
    HTML#SetIfUnset('b:htmlplugin.extra_mappings', '[]')
    b:htmlplugin.extra_mappings->add([arg, mode])
    return true
  endif
  return false
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
    if HTML.saveopts->has_key('formatoptions')
        && HTML.saveopts['formatoptions'] != ''
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

# TC()  {{{1
#
# Used to make sure the 'comments' option is off temporarily to prevent
# certain mappings from inserting unwanted comment leaders.
#
# Arguments:
#  1 - Boolean: false - Clear option
#               true  - Restore option
def TC(s: bool)
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
# (Note that g:htmlplugin.save_clipboard is set by this plugin's
# initialization.)
def HTML#ToggleClipboard(dowhat: number = 2): bool
  var newdowhat = dowhat

  if newdowhat == 2
    if HTML#BoolVar('b:htmlplugin.did_mappings')
      newdowhat = 1
    else
      newdowhat = 0
    endif
  endif

  if newdowhat == 0
    if exists('g:htmlplugin.save_clipboard')
      &clipboard = g:htmlplugin.save_clipboard
    else
      execute 'HTMLERROR ' .. expand('<stack>')
        .. ' Somehow the htmlplugin.save_clipboard global variable did not get set.'
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
# Purpose:
#  Used by HTML#Map() to enter insert mode in Visual mappings in the right
#  place, depending on what 'selection' is set to.
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
# Purpose:
#  Convert special regions in a string to the appropriate case determined by
#  b:htmlplugin.tag_case.
# Arguments:
#  1 - String or List<String>: The string(s) with the regions to convert
#      surrounded by [{...}].
#  2 - Optional: The case to convert to, either "uppercase" or "lowercase".
#      The default is to follow the configuration variable.
# Return Value:
#  The converted string(s).
def HTML#ConvertCase(str: any, case: string = 'config'): any
  var newstr: list<string>
  var newnewstr: list<string>
  var newcase: string
  if type(str) == v:t_list
    newstr = str
  else
    newstr = [str]
  endif
  if case == 'config'
    newcase = b:htmlplugin.tag_case
  else
    newcase = case
  endif

  HTML#SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

  if newcase =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
    newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g'))
  elseif newcase =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
    newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g'))
  else
    execute 'HTMLWARN ' .. expand('<stack>') .. ' Specified case is invalid: "'
      .. newcase .. '". Overriding to "lowercase".'
    newstr = newstr->HTML#ConvertCase('lowercase')
  endif

  if type(str) == v:t_list
    return newnewstr
  else
    return newnewstr[0]
  endif
enddef

# ReIndent()  {{{1
#
# Purpose:
#  Re-indent a region.  (Usually called by HTML#Map.)
#  Nothing happens if filetype indenting isn't enabled and 'indentexpr' is
#  unset.
# Arguments:
#  1 - Integer: Start of region.
#  2 - Integer: End of region.
#  3 - Integer: Optional, Add N extra lines below the region to re-indent.
#  4 - Integer: Optional, Add N extra lines above the region to re-indent.
#               (Two extra options because the start/end can be reversed so
#               adding to those in the function call can have wrong results.)
# Return Value:
#  Boolean - True if lines were reindented, false otherwise.
def ReIndent(first: number, last: number, extralines: number = 0, prelines: number = 0): bool

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
    ++lastline
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
# Purpose:
#  Position the cursor at the next point in the file that needs data.
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

# SmartTag()  {{{1
#
# Purpose:
#  Causes certain tags (such as bold, italic, underline) to be closed then
#  opened rather than opened then closed where appropriate, if syntax
#  highlighting is on.
# Arguments:
#  1 - String: The tag name.
#  2 - Character: The mode:
#                  'i' - Insert mode
#                  'v' - Visual mode
# Return Value:
#  The string to be executed to insert the tag.

def SmartTag(tag: string, mode: string): string
  var newmode = mode->strpart(0, 1)->tolower()
  var newtag = tag->tolower()
  var which: string
  var ret: string
  var line: number
  var column: number

  if ! HTML.smarttags->has_key(newtag)
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' Unknown smart tag: ' .. newtag
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

# HTML#GenerateTable()  {{{1
#
# Purpose:
#  Interactively creates a table.
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
    lines->add('<[{TABLE STYLE}]="border: solid ' .. g:htmlplugin.textcolor .. ' ' .. newborder .. 'px; padding: 3px;">')
  else
    lines->add('<[{TABLE}]>')
  endif

  if newthead
    lines->add('<[{THEAD}]>')
    lines->add('<[{TR}]>')
    for c in newcolumns->range()
      if newborder > 0
        lines->add('<[{TH STYLE}]="border: solid ' .. g:htmlplugin.textcolor .. ' '  .. newborder .. 'px; padding: 3px;"></[{TH}]>')
      else
        lines->add('<[{TH></TH}]>')
      endif
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
      if newborder > 0
        lines->add('<[{TD STYLE}]="border: solid ' .. g:htmlplugin.textcolor .. ' '  .. newborder .. 'px; padding: 3px;"></[{TD}]>')
      else
        lines->add('<[{TD></TD}]>')
      endif
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
      if newborder > 0
        lines->add('<[{TD STYLE}]="border: solid ' .. g:htmlplugin.textcolor .. ' '  .. newborder .. 'px; padding: 3px;"></[{TD}]>')
      else
        lines->add('<[{TD></TD}]>')
      endif
    endfor
    lines->add('</[{TR}]>')
    lines->add('</[{TFOOT}]>')
  endif

  lines->add("</[{TABLE}]>")

  lines = lines->HTML#ConvertCase()

  lines->append('.')

  execute ':' .. (line('.') + 1) .. ',' .. (line('.') + lines->len())
    .. 'normal! =='

  setcharpos('.', charpos)

  if getline('.') =~ '^\s*$'
    delete
  endif

  HTML#NextInsertPoint()

  return true
enddef

# HTML#PluginControl()  {{{1
#
# Purpose:
#  Disable/enable all the mappings defined by HTML#Map()/HTML#Mapo().
# Arguments:
#  1 - String: Whether to disable or enable the mappings:
#               d/disable/off:   Clear the mappings
#               e/enable/on:     Redefine the mappings
#               r/reload/reinit: Completely reload the script
#               h/html:          Reload the mapppings in HTML mode
#               x/xhtml:         Reload the mapppings in XHTML mode
# Return Value:
#  Boolean: False for an error, true otherwise
# Known Limitations:
#  This expects g:htmlplugin.file to be set by the HTML plugin.
var quiet_errors: bool
def HTML#PluginControl(dowhat: string): bool

  # DoExtraMappings()  {{{2
  #
  # Purpose:
  #  Iterate over all the commands to define extra mappings (those that
  #  weren't defined by the plugin):
  # Arguments:
  #  None
  # Return Value:
  #  Boolean: Whether there were extra mappings to define
  def DoExtraMappings(): bool
    if !exists('b:htmlplugin.extra_mappings')
      return false
    endif
    b:htmlplugin.extra_mappings->mapnew((_, mapping) => mapset(mapping[1], false, mapping[0]))
    return true
  enddef  # }}}2

  # ClearMappings() {{{2
  #
  # Purpose:
  #  Iterate over all the commands to clear the mappings.  (This used to be
  #  just one long single command but that had drawbacks, so now it's a List
  #  that must be looped over.)
  # Arguments:
  #  None
  # Return Value:
  #  None
  def ClearMappings(): void
    b:htmlplugin.clear_mappings->mapnew(
      (_, mapping) => {
        silent! execute mapping
        return
      }
    )
    b:htmlplugin.clear_mappings = []
    unlet b:htmlplugin.did_mappings
  enddef  # }}}2

  if !HTML#BoolVar('b:htmlplugin.did_mappings_init')
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
    if HTML#BoolVar('b:htmlplugin.did_mappings')
      ClearMappings()
      if HTML#BoolVar('g:htmlplugin.did_menus')
        HTML#MenuControl('disable')
      endif
    elseif !quiet_errors
      HTMLERROR The HTML mappings are already disabled.
      return false
    endif
  elseif dowhat =~? '^\%(e\%(nable\)\?\|on\|true\|1\)$'
    if HTML#BoolVar('b:htmlplugin.did_mappings')
      HTMLERROR The HTML mappings are already enabled.
    else
      execute 'source ' .. g:htmlplugin.file
      HTML#ReadEntities(false, true)
      HTML#ReadTags(false, true)
      if exists('b:htmlplugin.extra_mappings') == 1
        DoExtraMappings()
      endif
    endif
  elseif dowhat =~? '^\%(r\%(eload\|einit\)\?\)$'
    execute 'HTMLMESG Reloading: ' .. fnamemodify(g:htmlplugin.file, ':t')
    quiet_errors = true
    HTML#PluginControl(off)
    b:htmlplugin.did_mappings_init = -1
    silent! unlet g:htmlplugin.did_menus g:htmlplugin.did_toolbar
    silent! unlet g:htmlplugin.did_commands
    execute 'silent! unmenu ' .. g:htmlplugin.toplevel_menu_escaped
    execute 'silent! unmenu! ' .. g:htmlplugin.toplevel_menu_escaped
    HTML#PluginControl(on)
    autocmd SafeState * ++once HTMLReloadFunctions
    quiet_errors = false
  elseif dowhat =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
    if b:htmlplugin.do_xhtml_mappings
      HTMLERROR Can't switch to uppercase while editing XHTML.
      return false
    endif
    if !HTML#BoolVar('b:htmlplugin.did_mappings')
      HTMLERROR The HTML mappings are disabled, changing case is not possible.
      return false
    endif
    if b:htmlplugin.tag_case =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
      return false
    endif
    HTML#PluginControl(off)
    b:htmlplugin.tag_case = 'uppercase'
    HTML#PluginControl(on)
  elseif dowhat =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
    if !HTML#BoolVar('b:htmlplugin.did_mappings')
      HTMLERROR The HTML mappings are disabled, changing case is not possible.
      return false
    endif
    if b:htmlplugin.tag_case =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
      return false
    endif
    HTML#PluginControl(off)
    b:htmlplugin.tag_case = 'lowercase'
    HTML#PluginControl(on)
  elseif dowhat =~? '^h\%(tml\)\?$'
    if exists('b:htmlplugin.tag_case_save')
      b:htmlplugin.tag_case = b:htmlplugin.tag_case_save
    endif
    b:htmlplugin.do_xhtml_mappings = false
    HTML#PluginControl(off)
    b:htmlplugin.did_mappings_init = -1
    HTML#PluginControl(on)
  elseif dowhat =~? '^x\%(html\)\?$'
    b:htmlplugin.do_xhtml_mappings = true
    HTML#PluginControl(off)
    b:htmlplugin.did_mappings_init = -1
    HTML#PluginControl(on)
  else
    execute 'HTMLERROR ' .. expand('<stack>')
      .. ' Invalid argument: ' .. dowhat
    return false
  endif

  return true
enddef

# HTML#MenuControl()  {{{1
#
# Purpose:
#  Disable/enable the HTML menu and toolbar.
# Arguments:
#  1 - String: Optional, Whether to disable or enable the menus:
#                empty: Detect which to do
#                "disable": Disable the menu and toolbar
#                "enable": Enable the menu and toolbar
# Return Value:
#  Boolean: False if an error occurred, true otherwise
def HTML#MenuControl(which: string = 'detect'): bool
  if which !~? '^disable$\|^enable$\|^detect$'
    exe 'HTMLERROR ' .. expand('<stack>') .. ' Invalid argument: ' .. which
    return false
  endif

  if which == 'disable' || !HTML#BoolVar('b:htmlplugin.did_mappings')
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
    if HTML#BoolVar('b:htmlplugin.did_mappings_init')
        && !HTML#BoolVar('b:htmlplugin.did_mappings')
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.*'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.Enable\ Mappings'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.Reload\ Mappings'
    endif
  elseif which == 'enable' || HTML#BoolVar('b:htmlplugin.did_mappings_init')
    execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
    if HTML#BoolVar('b:htmlplugin.did_mappings')
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.*'
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.*'
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.Enable\ Mappings'

      if HTML#BoolVar('b:htmlplugin.do_xhtml_mappings')
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ XHTML\ mode'
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ HTML\ mode'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ uppercase'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ lowercase'
      else
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ XHTML\ mode'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Control.Switch\ to\ HTML\ mode'

        if b:htmlplugin.tag_case =~? '^u\%(pper\%(case\)\?\)\?'
          execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
            .. '.Control.Switch\ to\ uppercase'
        else
          execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
            .. '.Control.Switch\ to\ lowercase'
        endif
      endif

      if HTML#BoolVar('g:htmlplugin.did_toolbar')
        amenu enable ToolBar.*
      endif
    else
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        .. '.Control.Enable\ Mappings'
    endif
  endif

  return true
enddef

# ToRGB()  {{{1
#
# Purpose:
#  Convert a #NNNNNN hex color to rgb() format
# Arguments:
#  1 - String: The #NNNNNN hex color code to convert
#  2 - Boolean: Whether to conver to percentage or not
# Return Value:
#  String: The converted color
def ToRGB(color: string, percent: bool = false): string
  if color !~ '^#\x\{6}$'
    execute 'HTMLERROR ' .. expand('<stack>') ..
      ' Color must be a six-digit hexadecimal value prefixed by a #'
    return ''
  endif

  var rgb = color[1 : -1]->split('\x\{2}\zs')->mapnew((_, val) => str2nr(val, 16))

  if percent
    rgb = rgb->mapnew((_, val) => round(val / 256.0 * 100)->float2nr())
    return printf('rgb(%d%%, %d%%, %d%%)', rgb[0], rgb[1], rgb[2])
  endif

  return printf('rgb(%d, %d, %d)', rgb[0], rgb[1], rgb[2])
enddef

# HTML#ColorChooser()  {{{1
#
# Purpose:
#  Use the popup feature of Vim to display HTML colors for selection
# Arguments:
#  1 - String: Default is "i", how to insert the chosen color
# Return Value:
#  None
def HTML#ColorChooser(how: string = 'i'): void
  if !HTML#BoolVar('b:htmlplugin.did_mappings_init')
    HTMLERROR Not in an HTML buffer.
    return
  endif

  var maxw = 0
  var doname = false
  var dorgb = false
  var dorgbpercent = false
  var mode = mode()

  def CCSelect(id: number, result: number)  # {{{2
    if result < 0
      return
    endif

    var color = HTML.COLOR_LIST[result - 1]

    if doname
      execute 'normal! ' .. how .. color[2]
    elseif dorgb
      execute 'normal! ' .. how .. color[3]
    elseif dorgbpercent
      execute 'normal! ' .. how .. color[1]->ToRGB(true)
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
    elseif key ==# 'r'
      dorgb = true
      newkey = "\<cr>"
    elseif key ==# 'R'
      dorgbpercent = true
      newkey = "\<cr>"
    elseif key == "\<s-cr>"
      doname = true
      newkey = "\<cr>"
    elseif key ==? 'q'
      call popup_close(id, -2)
      return true
    elseif key == "\<2-leftmouse>" || key == "\<s-2-leftmouse>" || key == "\<c-2-leftmouse>"
      if getmousepos()['screencol'] < (popup_getpos(id)['core_col'] - 1) ||
          getmousepos()['screenrow'] < (popup_getpos(id)['core_line']) ||
          getmousepos()['screencol'] > (popup_getpos(id)['core_col']
            + popup_getpos(id)['core_width'] - 1) ||
          getmousepos()['screenrow'] > (popup_getpos(id)['core_line']
            + popup_getpos(id)['core_height'] - 1)
        newkey = key
      else
        if key == "\<s-2-leftmouse>"
          dorgb = true
        elseif key == "\<c-2-leftmouse>"
          dorgbpercent = true
        elseif getmousepos()['screencol'] < (popup_getpos(id)['core_col']
            + popup_getpos(id)['core_width'] - 9)
          doname = true
        endif

        call popup_close(id, popup_getpos(id)['firstline']
          + getmousepos()['winrow'] - 2)
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
        var csplit = value[1][1 : -1]->split('\x\x\zs')->mapnew((_, val) => val->str2nr(16))
        var contrast = (((csplit[0] > 0x80) || (csplit[1] > 0x80) || (csplit[2] > 0x80)) ?
          0x000000 : 0xFFFFFF)
        win_execute(colorwin, 'syntax match hc_' .. value[2] .. ' /'
          .. value[1] .. '/')
        win_execute(colorwin, 'highlight hc_' .. value[2] .. ' guibg='
          .. value[1] .. ' guifg=#' .. printf('%06X', contrast))

        return
      }
    )
enddef

# HTML#Template()  {{{1
#
# Purpose:
#  Determine whether to insert the HTML template.
# Arguments:
#  None
# Return Value:
#  Boolean - Whether the cursor is not on an insert point.
def HTML#Template(): bool

  # InsertTemplate()  {{{2
  #
  # Purpose:
  #  Actually insert the HTML template.
  # Arguments:
  #  None
  # Return Value:
  #  Boolean - Whether the cursor is not on an insert point.
  def InsertTemplate(): bool

    # TokenReplace()  {{{3
    #
    # Purpose:
    #  Replace user tokens with appropriate text, based on configuration
    # Arguments:
    #  1 - String or List of strings: The text to do token replacement on
    # Return Value:
    #  String or List: The new text
    def TokenReplace(text: list<string>): list<string>
      var newtext: list<string>

      newtext = text->mapnew(
        (_, str) => {
            var newstr = str
            newstr = newstr->substitute('\C%authorname%', '\=g:htmlplugin.authorname', 'g')
            newstr = newstr->substitute('\C%authoremail%', '\=g:htmlplugin.authoremail_encoded', 'g')
            newstr = newstr->substitute('\C%bgcolor%', '\=g:htmlplugin.bgcolor', 'g')
            newstr = newstr->substitute('\C%textcolor%', '\=g:htmlplugin.textcolor', 'g')
            newstr = newstr->substitute('\C%linkcolor%', '\=g:htmlplugin.linkcolor', 'g')
            newstr = newstr->substitute('\C%alinkcolor%', '\=g:htmlplugin.alinkcolor', 'g')
            newstr = newstr->substitute('\C%vlinkcolor%', '\=g:htmlplugin.vlinkcolor', 'g')
            newstr = newstr->substitute('\C%date%', '\=strftime("%B %d, %Y")', 'g')
            newstr = newstr->substitute('\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%', '\=submatch(1)->substitute(''\\%'', "%%", "g")->substitute(''\\\@<!!'', "%", "g")->strftime()', 'g')
            newstr = newstr->substitute('\C%time%', '\=strftime("%r %Z")', 'g')
            newstr = newstr->substitute('\C%time12%', '\=strftime("%r %Z")', 'g')
            newstr = newstr->substitute('\C%time24%', '\=strftime("%T")', 'g')
            newstr = newstr->substitute('\C%charset%', '\=DetectCharset()', 'g')
            newstr = newstr->substitute('\C%vimversion%', '\=(v:version / 100) .. "." .. (v:version % 100) .. "." .. (v:versionlong % 10000)', 'g')
            return newstr
          }
        )

      return newtext
    enddef  # }}}3

    if g:htmlplugin.authoremail != ''
      g:htmlplugin.authoremail_encoded = g:htmlplugin.authoremail->HTML#TranscodeString()
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
        template->readfile()->TokenReplace()->append(0)
      else
        execute 'HTMLERROR Unable to insert template file: ' .. template
        HTMLERROR "Either it doesn't exist or it isn't readable."
        return false
      endif
    else
      b:htmlplugin.internal_template->TokenReplace()->append(0)
    endif

    if getline('$') =~ '^\s*$'
      :$delete
    endif

    cursor(1, 1)

    redraw

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

# DetectCharset()  {{{1
#
# Purpose:
#  Detects the HTTP-EQUIV Content-Type charset based on Vim's current
#  encoding/fileencoding.
# Arguments:
#  1 - String: Optional, the charset to try to match with the internal
#              table
# Return Value:
#  The value for the Content-Type charset based on 'fileencoding' or
#  'encoding'.
def DetectCharset(charset: string = ''): string
  var enc: string

  if exists('b:htmlplugin.charset')
    return b:htmlplugin.charset
  elseif exists('g:htmlplugin.charset')
    return g:htmlplugin.charset
  endif

  if charset != ''
    enc = charset
  elseif &fileencoding == ''
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

# HTML#MenuJoin()  {{{1
#
# Purpose:
#  Simple function to join menu name array into a valid menu name, escaped
# Arguments:
#  1 - List: The menu name
# Return Value:
#  The menu name joined into a single string, escaped
def HTML#MenuJoin(menuname: list<string>): string
  return menuname->mapnew((key, value) => value->escape(' .'))->join('.')
enddef

# MenuPriorityPrefix()  {{{1
#
# Purpose:
#  Allow a specified menu priority to be properly prefixed with periods so it
#  matches the user configuration of the toplevel menu.
# Arguments:
#  None
# Return Value:
#  String - the number of periods necessary to properly specify the prefix
def MenuPriorityPrefix(menu: string): string
  if menu == 'ToolBar' || menu == 'PopUp'
    return ''
  else
    return repeat('.', len(g:htmlplugin.toplevel_menu) - 1)
  endif
enddef

# HTML#Menu()  {{{1
#
# Purpose:
#  Generate plain HTML menu items without any extra magic
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
  var nameescaped: string
  var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
  var priorityprefix = MenuPriorityPrefix(name[0])

  if name[0] == 'ToolBar' || name[0] == 'PopUp'
    newname = name
  else
    newname = name->extendnew(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  if level ==? 'auto'
    if g:htmlplugin.toplevel_menu_priority > 0
        && name[0] != 'ToolBar' && name[0] != 'PopUp'
      newlevel = priorityprefix .. g:htmlplugin.toplevel_menu_priority
    else
      newlevel = ''
    endif
  elseif level == '-' || level == ''
    newlevel = ''
  else
    newlevel = priorityprefix .. level
  endif

  execute type .. ' ' .. newlevel .. ' ' .. nameescaped .. ' ' .. item
enddef

# HTML#LeadMenu()  {{{1
#
# Purpose:
#  Generate HTML menu items
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
  var nameescaped: string
  var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
  var priorityprefix = MenuPriorityPrefix(name[0])

  if name[0] == 'ToolBar'
    newname = name
  else
    newname = name->extendnew(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  if level == '-' || level == ''
    newlevel = ''
  else
    newlevel = priorityprefix .. level
  endif

  execute type .. ' ' .. newlevel .. ' ' .. nameescaped .. '<tab>'
    .. leaderescaped .. item .. ' ' .. pre .. g:htmlplugin.map_leader .. item
enddef

# HTML#EntityMenu()  {{{1
#
# Purpose:
#  Generate HTML character entity menu items
# Arguments:
#  1 - List: The menu name, split into submenu heirarchy as a list
#  2 - String: The item
#  3 - String: The symbol it generates
# Return Value:
#  None
def HTML#EntityMenu(name: list<string>, item: string, symb: string = ''): void
  var newname = name->extendnew(['Character Entities'], 0)
  var nameescaped: string

  if g:htmlplugin.toplevel_menu != []
    newname = newname->extendnew(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  var newsymb = symb
  var leaderescaped = g:htmlplugin.entity_map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
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
    .. g:htmlplugin.entity_map_leader .. item
  execute 'nmenu ' .. nameescaped .. newsymb .. '<tab>'
    .. leaderescaped .. itemescaped .. ' ' .. 'i'
    .. g:htmlplugin.entity_map_leader .. item .. '<esc>'
  execute 'vmenu ' .. nameescaped .. newsymb .. '<tab>'
    .. leaderescaped .. itemescaped .. ' ' .. 's'
    .. g:htmlplugin.entity_map_leader .. item .. '<esc>'
enddef

# HTML#ColorsMenu()  {{{1
#
# Purpose:
#  Generate HTML colors menu items
# Arguments:
#  1 - String: The color name
#  2 - String: The color hex code
#  3 - String: Optional, the color name without spaces
#  4 - String: Optional, The rgb() code of the color
#  5 - String: Optional, The rgb() code in percentages
# Return Value:
#  None
def HTML#ColorsMenu(name: string, color: string, namens: string = '', rgb: string = '', rgbpercent: string = ''): void
  var c = name->strpart(0, 1)->toupper()
  var newname: list<string>
  var newnamens: string
  var nameescaped: string
  var newrgb: string
  var newrgbpercent: string

  if HTML.COLORS_SORT->has_key(c)
    newname = [name]->extendnew(['&Colors', '&' .. HTML.COLORS_SORT[c]], 0)
  else
    newname = [name]->extendnew(['&Colors', 'Web Safe Palette'], 0)
  endif

  if g:htmlplugin.toplevel_menu != []
    newname = newname->extendnew(g:htmlplugin.toplevel_menu, 0)
  endif

  nameescaped = newname->HTML#MenuJoin()

  if namens == ''
    newnamens = namens->substitute('\s', '', 'g')
  else
    newnamens = namens
  endif

  if rgb == ''
    newrgb = color->ToRGB()
  else
    newrgb = rgb
  endif

  if rgbpercent == ''
    newrgbpercent = color->ToRGB(true)
  else
    newrgbpercent = rgbpercent
  endif

  if newnamens == color
    execute 'inoremenu ' .. nameescaped
      .. '.Insert\ &Hexadecimal ' .. color
    execute 'nnoremenu ' .. nameescaped
      .. '.Insert\ &Hexadecimal i' .. color .. '<esc>'
    execute 'vnoremenu ' .. nameescaped
      .. '.Insert\ &Hexadecimal s' .. color .. '<esc>'

    execute 'inoremenu ' .. nameescaped
      .. '.Insert\ &RGB ' .. newrgb
    execute 'nnoremenu ' .. nameescaped
      .. '.Insert\ &RGB i' .. newrgb .. '<esc>'
    execute 'vnoremenu ' .. nameescaped
      .. '.Insert\ &RGB s' .. newrgb .. '<esc>'

    execute 'inoremenu ' .. nameescaped
      .. '.Insert\ RGB\ &Percent ' .. newrgbpercent
    execute 'nnoremenu ' .. nameescaped
      .. '.Insert\ RGB\ &Percent i' .. newrgbpercent .. '<esc>'
    execute 'vnoremenu ' .. nameescaped
      .. '.Insert\ RGB\ &Percent s' .. newrgbpercent .. '<esc>'
  else
    execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Name ' .. newnamens
    execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Name i' .. newnamens .. '<esc>'
    execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Name s' .. newnamens .. '<esc>'

    execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Hexadecimal ' .. color
    execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Hexadecimal i' .. color .. '<esc>'
    execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &Hexadecimal s' .. color .. '<esc>'

    execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &RGB ' .. newrgb
    execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &RGB i' .. newrgb .. '<esc>'
    execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ &RGB s' .. newrgb .. '<esc>'

    execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ RGB\ &Percent ' .. newrgbpercent
    execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ RGB\ &Percent i' .. newrgbpercent .. '<esc>'
    execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
      .. ').Insert\ RGB\ &Percent s' .. newrgbpercent .. '<esc>'
  endif
enddef

# HTML#ReadTags()  {{{1
#
#  Purpose:
#   Read in the HTML tags JSON file and define both the mappings and menu at
#   the same time, unless otherwise specified.
#  Arguments:
#   1 - Boolean: Optional, whether to define the menus
#   2 - String:  Optional, what json file to read
#  Return Value:
#   Boolean - Whether the json file was successfully read in without error
def HTML#ReadTags(domenu: bool = true, internal: bool = false, file: string = HTML.TAGS_FILE): bool
  var maplhs: string
  var menulhs: string
  var jsonfile = file->findfile(&runtimepath)
  var rval = true

  if jsonfile == ''
    execute 'HTMLERROR ' .. expand('<stack>') .. ' ' .. file
      .. ' is not found in the runtimepath. No tag mappings or menus have been defined.'
    return false
  elseif ! jsonfile->filereadable()
    execute 'HTMLERROR ' .. expand('<stack>') .. ' ' .. jsonfile
      .. ' is not readable. No tag mappings or menus have been defined.'
    return false
  endif

  for json in jsonfile->readfile()->join(' ')->json_decode()
    try
      if json->has_key('menu') && json.menu[2]->has_key('n')
          && json.menu[2].n[0] ==? '<nop>' && domenu
        HTML#Menu('menu', json.menu[0], json.menu[1], '<nop>')
        continue
      endif

      if json->has_key('lhs')
        maplhs = '<lead>' .. json.lhs
        menulhs = json.lhs
      else
        maplhs = ""
        menulhs = ""
      endif

      if json->has_key('smarttag')
        # Translate <SID> and \<...> strings to their corresponding actual
        # value:
        var smarttag = json.smarttag->string()->substitute('\c<SID>',
          self_sid, 'g')->substitute('\c\\<[a-z0-9_-]\+>',
            '\=eval(''"'' .. submatch(0) .. ''"'')', 'g')

        HTML.smarttags->extend(smarttag->eval())
      endif

      if json->has_key('maps')
        var did_mappings = 0

        if json.maps->has_key('i')
            && maparg((maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs)->substitute('^<lead>\c',
              g:htmlplugin.map_leader->escape('&~\'), ''), 'i') == ''
          if HTML#Map('inoremap',
              (maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs),
              json.maps.i[1],
              v:none,
              internal)
            ++did_mappings
          endif
        endif

        if json.maps->has_key('v')
            && maparg((maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs)->substitute('^<lead>\c',
              g:htmlplugin.map_leader->escape('&~\'), ''), 'v') == ''
          if HTML#Map('vnoremap',
              (maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs),
              json.maps.v[1],
              json.maps.v[2],
              internal)
            ++did_mappings
          endif
        endif

        if json.maps->has_key('n')
            && maparg((maplhs == '' ? '<lead>' .. json.maps.n[0] : maplhs)->substitute('^<lead>\c',
              g:htmlplugin.map_leader->escape('&~\'), ''), 'n') == ''
          if HTML#Map('nnoremap',
              (maplhs == '' ? '<lead>' .. json.maps.n[0] : maplhs),
              json.maps.n[1],
              v:none,
              internal)
            ++did_mappings
          endif
        endif

        if json.maps->has_key('o')
            && maparg((maplhs == '' ? '<lead>' .. json.maps.o[0] : maplhs)->substitute('^<lead>\c',
              g:htmlplugin.map_leader->escape('&~\'), ''), 'o') == ''
          if HTML#Mapo(
              (maplhs == '' ? '<lead>' .. json.maps.o[0] : maplhs),
              json.maps.o[1],
              internal)
            ++did_mappings
          endif
        endif

        # If it was indicated that mappings would be defined but none were
        # actually defined, don't set the menu items for this mapping either:
        if did_mappings == 0
          continue
        endif
      endif

      if domenu && json->has_key('menu')
        if json.menu[2]->has_key('i')
          HTML#LeadMenu('imenu',
            json.menu[0],
            json.menu[1],
            (menulhs == '' ? json.menu[2].i[0] : menulhs),
            json.menu[2].i[1])
        endif

        if json.menu[2]->has_key('v')
          HTML#LeadMenu('vmenu',
            json.menu[0],
            json.menu[1],
            (menulhs == '' ? json.menu[2].v[0] : menulhs),
            json.menu[2].v[1])
        endif

        if json.menu[2]->has_key('n')
          HTML#LeadMenu('nmenu',
            json.menu[0],
            json.menu[1],
            (menulhs == '' ? json.menu[2].n[0] : menulhs),
            json.menu[2].n[1])
        endif

        if json.menu[2]->has_key('a')
          HTML#LeadMenu(
            'amenu',
            json.menu[0],
            json.menu[1],
            (menulhs == '' ? json.menu[2].a[0] : menulhs),
            json.menu[2].a[1])
        endif
      endif
    catch /.*/
      execute 'HTMLERROR ' .. v:exception
      execute 'HTMLERROR Potentially malformed json in ' .. file
        .. ', section: ' .. json->string()
      rval = false
    endtry
  endfor

  return rval
enddef

# HTML#ReadEntities()  {{{1
#
#  Purpose:
#   Read in the HTML entities JSON file and define both the mappings and menu
#   at the same time, unless otherwise specified.
#  Arguments:
#   1 - Boolean: Optional, whether to define the menus
#   2 - Boolean: Optional, whether we're doing "internal" mappings
#   3 - String:  Optional, what json file to read
#  Return Value:
#   Boolean - Whether the json file was successfully read in without error
def HTML#ReadEntities(domenu: bool = true, internal: bool = false, file: string = HTML.ENTITIES_FILE): bool
  var jsonfile = file->findfile(&runtimepath)
  var rval = true

  if jsonfile == ''
    execute 'HTMLERROR ' .. expand('<stack>') .. ' ' .. file
      .. ' is not found in the runtimepath. No entity mappings or menus have been defined.'
    return false
  elseif ! jsonfile->filereadable()
    execute 'HTMLERROR ' .. expand('<stack>') .. ' ' .. jsonfile
      .. ' is not readable. No entity mappings or menus have been defined.'
    return false
  endif

  for json in jsonfile->readfile()->join(' ')->json_decode()
    if json->len() != 4 || json[2]->type() != v:t_list
      execute 'HTMLERROR ' .. expand('<stack>') .. ' Malformed json in ' .. file .. ', section: '
        .. json->string()
      rval = false
      continue
    endif
    if json[3] ==? '<nop>'
      if domenu
        HTML#Menu('menu', '-', json[2]->extendnew(['Character &Entities'], 0), '<nop>')
      endif
    else
      if maparg(g:htmlplugin.entity_map_leader .. json[0], 'i') != '' ||
        !HTML#Map('inoremap', '<elead>' .. json[0], json[1], v:none, internal)
        # Failed to map? No menu item should be defined either:
        continue
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
g:htmlplugin.function_files->add(expand('<sfile>:p'))->sort()->uniq()

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=5:comments=b\:#:commentstring=\ #\ %s:
