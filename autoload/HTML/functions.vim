vim9script
scriptencoding utf8

if v:version < 901
  finish
endif

# Various functions for the HTML macros filetype plugin.
#
# Last Change: March 17, 2024
#
# Requirements:
#       Vim 9.1 or later
#
# Copyright © 1998-2024 Christian J. Robinson <heptite(at)gmail(dot)com>
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

import '../../import/HTML/variables.vim' as HTMLVariables
import autoload 'HTML/BrowserLauncher.vim'

export class HTMLFunctions

  # Error and warning messages:  {{{1
  static const E_NOMAP        = ' No mapping defined.'
  static const E_NOMAPLEAD    = '%s g:htmlplugin.map_leader is not set!' .. HTMLFunctions.E_NOMAP
  static const E_NOEMAPLEAD   = '%s g:htmlplugin.entity_map_leader is not set!' .. HTMLFunctions.E_NOMAP
  static const E_EMPTYLHS     = '%s must have a non-empty lhs.' .. HTMLFunctions.E_NOMAP
  static const E_EMPTYRHS     = '%s must have a non-empty rhs.' .. HTMLFunctions.E_NOMAP
  static const E_NOMODE       = '%s must have one of the modes explicitly stated.' .. HTMLFunctions.E_NOMAP
  static const E_NOLOCALVAR   = 'Cannot set a local variable with %s'
  static const E_NARGS        = 'E119: Not enough arguments for %s'
  static const E_NOSRC        = 'The HTML macros plugin was not sourced for this buffer.'
  static const E_DISABLED     = 'The HTML mappings are already disabled.'
  static const E_ENABLED      = 'The HTML mappings are already enabled.'
  static const E_INVALIDARG   = '%s Invalid argument: %s'
  static const E_JSON         = '%s Potentially malformed json in %s, section: %s'
  static const E_NOTFOUNDRTP  = '%s %s is not found in the runtimepath.'
  static const E_NOTFOUND     = 'File "%s" was not found.'
  static const E_NOREAD       = '%s %s is not readable.'
  static const E_NOTAG        = 'No tag mappings or menus have been defined.'
  static const E_NOENTITY     = 'No entity mappings or menus have been defined.'
  static const E_ONECHAR      = '%s First argument must be one character.'
  static const E_BOOLTYPE     = '%s Unknown type for Bool(): %s'
  static const E_NOCLIPBOARD  = '%s Somehow the htmlplugin.save_clipboard global variable did not get set.'
  static const E_NOSMART      = '%s Unknown smart tag: %s'
  static const E_OPTEXCEPTION = '%s while toggling options.'
  static const E_INDENTEXCEPT = '%s while reindenting.'
  static const E_MAPEXCEPT    = '%s while executing mapping: %s'
  static const E_NOTPOSSIBLE  = 'Should not get here, something went wrong.'
  static const E_ZEROROWSCOLS = 'Rows and columns must be positive, non-zero integers.'
  static const E_COLOR        = '%s Color "%s" is invalid. Colors must be a six-digit hexadecimal value prefixed by a "#".'
  static const E_TEMPLATE     = 'Unable to insert template file: %s Either it doesn''t exist or it isn''t readable.'

  static const W_MAPOVERRIDE  = 'WARNING: A mapping of %s for %s mode has been overridden for buffer number %d: %s'
  static const W_CAUGHTERR    = 'Caught error "%s", continuing.'
  static const W_INVALIDCASE  = '%s Specified case is invalid: %s. Overriding to "lowercase".'
  static const W_NOMENU       = 'No menu item was defined for "%s".'
  # }}}1

  static def Warn(message: string): void  # {{{1
    echohl WarningMsg
    if exists(':echowindow') == 2
      echowindow message
    else
      echo message
    endif
    echohl None
  enddef

  static def Message(message: string): void  # {{{1
    echohl Todo
    if exists(':echowindow') == 2
      echowindow message
    else
      echo message
    endif
    echohl None
  enddef

  static def Error(message: string): void  # {{{1
    echohl ErrorMsg
    echomsg message
    echohl None
  enddef

  # About()  {{{1
  #
  # Purpose:
  #  Self-explanatory
  # Arguments:
  #  None
  # Return Value:
  #  None
  static def About(): void
    var message = "HTML/XHTML Editing Macros and Menus Plugin\n"
      .. "Version: " .. (HTMLVariables.HTMLVariables.VERSION)
      .. "\n" .. "Written by: " .. (HTMLVariables.HTMLVariables.AUTHOR)
      .. ' <' .. (HTMLVariables.HTMLVariables.EMAIL) .. ">\n"
      .. "With thanks to Doug Renze for the original concept,\n"
      .. "Devin Weaver for the original mangleImageTag,\n"
      .. "Israel Chauca Fuentes for the MacOS version of the browser\n"
      .. "launcher code, and several others for their contributions.\n"
      .. (HTMLVariables.HTMLVariables.COPYRIGHT) .. "\n" .. "URL: "
      .. (HTMLVariables.HTMLVariables.HOMEPAGE)

    if message->confirm("&Visit Homepage\n&Dismiss", 2, 'Info') == 1
      var BrowserLauncherObject = BrowserLauncher.BrowserLauncher.new()
      BrowserLauncherObject.Launch('default', 0, HTMLVariables.HTMLVariables.HOMEPAGE)
    endif
  enddef

  # SetIfUnset()  {{{1
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
  def SetIfUnset(variable: string, ...args: list<any>): number
    var val: any
    var newvariable = variable

    if variable =~# '^l:'
      printf(E_NOLOCALVAR, F())->Error()
      return -1
    elseif variable !~# '^[bgstvw]:'
      newvariable = 'g:' .. variable
    endif

    if args->len() == 0
      printf(E_NARGS, F())->Error()
      return -1
    elseif type(args[0]) == v:t_list || type(args[0]) == v:t_dict
        || type(args[0]) == v:t_number
      val = args[0]
    else
      val = args->join(' ')
    endif

    if newvariable->this.IsSet()
      return 0
    endif

    if type(val) == v:t_string
      if val == '""' || val == "''" || val == '[]' || val == '{}'
        execute newvariable .. ' = ' .. val
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
  #  Helper to BoolVar() -- Test the string passed to it and
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

    printf(E_BOOLTYPE, F(), value->typename())->Error()
    return false
  enddef

  # BoolVar()  {{{1
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
  def BoolVar(variable: string): bool
    var newvariable = variable

    if variable !~ '^[bgstvw]:'
      newvariable = 'g:' .. variable
    endif

    if newvariable->this.IsSet()
      return newvariable->eval()->this.Bool()
    else
      return false
    endif
  enddef

  # IsSet()  {{{1
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

  # FilesWithMatch()  {{{1
  #
  # Purpose:
  #  Create a list of files that have contents matching a pattern.
  # Arguments:
  #  1 - List:    The files to search
  #  2 - String:  The pattern to search for
  #  2 - Integer: Optional, the number of lines to search before giving up
  # Return Value:
  #  List: Matching files
  static def FilesWithMatch(files: list<string>, pat: string, max: number = -1): list<string>
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

  # TranscodeString()  {{{1
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
  def TranscodeString(str: string, code: string = ''): string

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

      if char->strchars(1) != 1
        printf(HTMLFunctions.E_ONECHAR, HTMLFunctions.F())->HTMLFunctions.Error()
        return char
      endif

      newchar = HTMLVariables.HTMLVariables.DictCharToEntities->get(char, printf('&#x%X;', char->char2nr()))

      return newchar
    enddef  # }}}2

    # DecodeSymbol()  {{{2
    #
    # Purpose:
    #  Decode the HTML entity or URI symbol string to its literal character
    #  counterpart
    # Arguments:
    #  1 - String: The string to decode.
    # Return Value:
    #  Character: The decoded character.
    def DecodeSymbol(symbol: string): string

      # EntityToChar()  {{{3
      #
      # Purpose:
      #  Convert character entities to its corresponing character.
      # Arguments:
      #  1 - String: The entity to decode
      # Return Value:
      #  String: The decoded character
      def EntityToChar(entity: string): string
        var char: string

        if HTMLVariables.HTMLVariables.DictEntitiesToChar->has_key(entity)
          char = HTMLVariables.HTMLVariables.DictEntitiesToChar[entity]
        elseif entity =~ '^&#\%(x\x\+\);$'
          char = entity->strpart(3, entity->strlen() - 4)->str2nr(16)->nr2char()
        elseif entity =~ '^&#\%(\d\+\);$'
          char = entity->strpart(2, entity->strlen() - 3)->str2nr()->nr2char()
        else
          char = entity
        endif

        return char
      enddef  # }}}3

      var char: string

      if symbol =~ '^&#\%(x\x\+\);$\|^&#\%(\d\+\);$\|^&\%([A-Za-z0-9]\+\);$'
        char = EntityToChar(symbol)
      elseif symbol =~ '^%\%(\x\x\)$'
        char = symbol->strpart(1, symbol->strlen() - 1)->str2nr(16)->nr2char()
      else
        char = symbol
      endif

      return char
    enddef  # }}}2

    if code == ''
      return str->mapnew((_, char) => char->CharToEntity())
    elseif code == 'x'
      return str->mapnew((_, char) => printf("&#x%x;", char->char2nr()))
    elseif code == '%'
      return str->substitute('[\x00-\x99]', '\=printf("%%%02X", submatch(0)->char2nr())', 'g')
    elseif code =~? '^d\%(ecode\)\=$'
      return str->split('\(&[A-Za-z0-9]\+;\|&#x\x\+;\|&#\d\+;\|%\x\x\)\zs')
          ->mapnew((_, s) => s->DecodeSymbol())
          ->join('')
    endif

    return ''
  enddef

  # Map()  {{{1
  #
  # Purpose:
  #  Define the HTML mappings with the appropriate case, plus some extra stuff.
  # Arguments:
  #  1 - String: Which map command to run.
  #  2 - String: LHS of the map.
  #  3 - String: RHS of the map.
  #  4 - Dictionary: Optional:
  #                {'extra': bool}
  #                 Whether to suppress extra code on the mapping
  #                {'expr': bool}
  #                 Whether to execute the rhs as an expression
  #                {'insert': bool} (ony for visual maps)
  #                 Whether mapping enters insert mode
  #                {'reindent': number} (ony for visual maps)
  #                 Re-selects the region, moves down "number" lines, and
  #                 re-indents (applies only when filetype indenting is on)
  # Return Value:
  #  Boolean: Whether a mapping was defined
  def Map(cmd: string, map: string, arg: string, opts: dict<any> = {}, internal: bool = false): bool
    if !g:htmlplugin->has_key('map_leader') && map =~? '^<lead>'
      printf(E_NOMAPLEAD, F())->Error()
      return false
    endif

    if !g:htmlplugin->has_key('entity_map_leader') && map =~? '^<elead>'
      printf(E_NOEMAPLEAD, F())->Error()
      return false
    endif

    if map == '' || map ==? '<lead>' || map ==? '<elead>'
      printf(E_EMPTYLHS, F())->Error()
      return false
    endif

    if arg == ''
      printf(E_EMPTYRHS, F())->Error()
      return false
    endif

    if cmd =~# '^no' || cmd =~# '^map$'
      printf(E_NOMODE, F())->Error()
      return false
    endif

    if !b:htmlplugin->has_key('maps')
      b:htmlplugin.maps = {'v': {}, 'i': {}}
    endif

    var mode = cmd->strpart(0, 1)
    var newarg = arg
    var newmap = map->substitute('^<lead>\c', g:htmlplugin.map_leader->escape('&~\'), '')
      ->substitute('^<elead>\c', g:htmlplugin.entity_map_leader->escape('&~\'), '')
    var newmap_escaped = newmap->substitute('<', '<lt>', 'g')

    if HTMLVariables.HTMLVariables.MODES->has_key(mode) && newmap->this.MapCheck(mode, internal) >= 2
      # this.MapCheck() will echo the necessary message, so just return here
      return false
    endif

    newarg = newarg->this.ConvertCase()

    if ! this.BoolVar('b:htmlplugin.do_xhtml_mappings')
      newarg = newarg->substitute(' \?/>', '>', 'g')
    endif

    if mode == 'v'
      # If 'selection' is "exclusive" all the visual mode mappings need to
      # behave slightly differently:
      newarg = newarg->substitute('`>a\C', '`>i\\<C-R>='
        .. 'b:htmlplugin.HTMLFunctionsObject.VisualInsertPos()\\<CR>', 'g')

      if !opts->has_key('extra') || opts.extra
        b:htmlplugin.maps['v'][newmap] = [newarg, {}]

        if opts->has_key('expr')
          b:htmlplugin.maps['v'][newmap][1]['expr'] = opts.expr
        endif
      endif

      if opts->has_key('extra') && ! opts.extra
        execute cmd .. ' <buffer> <silent> ' .. newmap .. ' ' .. newarg
      elseif opts->get('insert', false) && opts->has_key('reindent')
        execute cmd .. ' <buffer> <silent> ' .. newmap
          .. ' <ScriptCmd>b:htmlplugin.HTMLFunctionsObject.DoMap("v", "' .. newmap_escaped .. '")<CR>'

        b:htmlplugin.maps['v'][newmap][1]['reindent'] = opts.reindent
        b:htmlplugin.maps['v'][newmap][1]['insert'] = opts.insert
      elseif opts->get('insert', false)
        execute cmd .. ' <buffer> <silent> ' .. newmap
          .. ' <ScriptCmd>b:htmlplugin.HTMLFunctionsObject.DoMap("v", "' .. newmap_escaped .. '")<CR>'

        b:htmlplugin.maps['v'][newmap][1]['insert'] = opts.insert
      elseif opts->has_key('reindent')
        execute cmd .. ' <buffer> <silent> ' .. newmap
          .. ' <ScriptCmd>b:htmlplugin.HTMLFunctionsObject.DoMap("v", "' .. newmap_escaped .. '")<CR>'

        b:htmlplugin.maps['v'][newmap][1]['reindent'] = opts.reindent
      else
        execute cmd .. ' <buffer> <silent> ' .. newmap
          .. ' <ScriptCmd>b:htmlplugin.HTMLFunctionsObject.DoMap("v", "' .. newmap_escaped .. '")<CR>'
      endif
    elseif mode == 'i'
      if opts->has_key('extra') && ! opts.extra
        execute cmd .. ' <buffer> <silent> ' .. newmap .. ' ' .. newarg
      else
        b:htmlplugin.maps['i'][newmap] = [newarg, {}]
        if opts->has_key('expr')
          b:htmlplugin.maps['i'][newmap][1]['expr'] = opts.expr
        endif
        execute cmd .. ' <buffer> <silent> <expr> ' .. newmap
          .. ' b:htmlplugin.HTMLFunctionsObject.DoMap("i", "' .. newmap_escaped .. '")'
      endif
    else
      execute cmd .. ' <buffer> <silent> ' .. newmap .. ' ' .. newarg
    endif

    if HTMLVariables.HTMLVariables.MODES->has_key(mode)
      b:htmlplugin.clear_mappings->add(':' .. mode .. 'unmap <buffer> ' .. newmap)
    else
      b:htmlplugin.clear_mappings->add(':unmap <buffer> ' .. newmap)
      b:htmlplugin.clear_mappings->add(':unmap! <buffer> ' .. newmap)
    endif

    # Save extra (nonplugin) mappings so they can be restored if we need to later:
    newmap->maparg(mode, false, true)->this.MappingsListAdd(mode, internal)

    return true
  enddef

  # Mapo()  {{{1
  #
  # Purpose:
  #  Define a normal mode map that takes an operator and assign it to its
  #  corresponding visual mode mapping.
  # Arguments:
  #  1 - String: The mapping.
  #  2 - Boolean: Optional, Whether to enter insert mode after the mapping has
  #                          executed. Default false.
  #  3 - Boolean: Optional, Whether the map is internal to the plugin.  Default
  #                          false.
  # Return Value:
  #  Boolean: Whether a mapping was defined
  def Mapo(map: string, insert: bool = false, internal: bool = false): bool
    if !g:htmlplugin->has_key('map_leader') && map =~? '^<lead>'
      printf(E_NOMAPLEAD, F())->Error()
      return false
    endif

    if map == '' || map ==? "<lead>"
      printf(E_EMPTYLHS, F())->Error()
      return false
    endif

    var newmap = map->substitute('^<lead>', g:htmlplugin.map_leader, '')

    if newmap->this.MapCheck('o', internal) >= 2
      # this.MapCheck() will echo the necessary message, so just return here
      return false
    endif

    execute 'nnoremap <buffer> <silent> ' .. newmap
      .. " <ScriptCmd>b:htmlplugin.tagaction = '" .. newmap .. "'<CR>"
      .. '<ScriptCmd>b:htmlplugin.taginsert = ' .. insert .. "<CR>"
      .. '<ScriptCmd>&operatorfunc = "function(b:htmlplugin.HTMLFunctionsObject.HTMLOpWrap)"<CR>g@'

    b:htmlplugin.clear_mappings->add(':nunmap <buffer> ' .. newmap)
    newmap->maparg('n', false, true)->this.MappingsListAdd('n', internal)

    return true
  enddef

  # DoMap()  {{{1
  #
  # Purpose:
  #  Execute or return the "right hand side" of a mapping, while preventing an
  #  error to cause it to abort.
  # Arguments:
  #  1 - String: The mode, either 'v' or 'i'
  #  2 - String: The mapping name (lhs) of the mapping to call, stored in
  #              b:htmlplugin.maps
  # Return Value:
  #  String: Either an empty string (for visual mappings) or the key sequence to
  #  run (for insert mode mappings).
  def DoMap(mode: string, map: string): string

    # ToggleOptions()  {{{2
    #
    # Used to make sure the 'showmatch', 'indentexpr', and 'formatoptions' options
    # are off temporarily to prevent the visual mappings from causing a
    # (visual)bell or inserting improperly.
    #
    # Arguments:
    #  1 - Boolean: false - Turn options off.
    #               true  - Turn options back on, if they were on before.
    def ToggleOptions(which: bool)
      try
        if which
          if HTMLVariables.HTMLVariables.saveopts->has_key('formatoptions')
              && HTMLVariables.HTMLVariables.saveopts['formatoptions'] != ''
            &l:showmatch = HTMLVariables.HTMLVariables.saveopts['showmatch']
            &l:indentexpr = HTMLVariables.HTMLVariables.saveopts['indentexpr']
            &l:formatoptions = HTMLVariables.HTMLVariables.saveopts['formatoptions']
          endif

          # Restore the last visual mode if it was changed:
          if HTMLVariables.HTMLVariables.saveopts->get('visualmode', '') != ''
            execute 'normal! gv' .. HTMLVariables.HTMLVariables.saveopts['visualmode']
            HTMLVariables.HTMLVariables.saveopts->remove('visualmode')
          endif
        else
          if &l:formatoptions != ''
            HTMLVariables.HTMLVariables.saveopts['showmatch'] = &l:showmatch
            HTMLVariables.HTMLVariables.saveopts['indentexpr'] = &l:indentexpr
            HTMLVariables.HTMLVariables.saveopts['formatoptions'] = &l:formatoptions
          endif
          &l:showmatch = false
          &l:indentexpr = ''
          &l:formatoptions = ''

          # A trick to make leading indent on the first line of visual-line
          # selections is handled properly (turn it into a character-wise
          # selection and exclude the leading indent):
          if visualmode() ==# 'V'
            HTMLVariables.HTMLVariables.saveopts['visualmode'] = visualmode()
            execute "normal! \<c-\>\<c-n>`<^v`>"
          endif
        endif
      catch
        printf(HTMLFunctions.E_OPTEXCEPTION, v:exception)->HTMLFunctions.Error()
      endtry
    enddef

    # ReIndent()  {{{2
    #
    # Purpose:
    #  Re-indent a region.  (Usually called by Map().)
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

      def GetFiletypeInfo(): dict<string>  # {{{3
        var ftout: dict<string>
        execute('filetype')
          ->trim()
          ->strpart(9)
          ->split('  ')
          ->mapnew(
            (_, val) => {
              var newval = val->split(':')
              ftout[newval[0]] = newval[1]
            }
          )
        return ftout
      enddef  # }}}3

      var firstline: number
      var lastline: number

      #if !GetFiletypeInfo()['indent']->this.Bool() && &indentexpr == ''
      if !(GetFiletypeInfo()['indent'] ==? 'ON') && &indentexpr == ''
        return false
      endif

      # Make sure the range is in the proper order before adding
      # prelines/extralines:
      if last >= first
        firstline = first
        lastline = last
      else
        firstline = last
        lastline = first
      endif

      firstline -= prelines
      lastline += extralines

      if firstline < 1
        firstline = 1
      endif
      if lastline > line('$')
        lastline = line('$')
      endif

      var range = firstline == lastline ? firstline : firstline .. ',' .. lastline
      var position = [line('.'), col('.')]

      try
        execute ':' .. range .. 'normal! =='
      catch
        printf(HTMLFunctions.E_INDENTEXCEPT, v:exception)->HTMLFunctions.Error()
      finally
        cursor(position)
      endtry

      return true
    enddef  # }}}2

    var evalstr: string
    var rhs: string
    var opts: dict<any>

    rhs = b:htmlplugin.maps[mode][map][0]
    rhs = rhs->substitute('\c\\<[a-z0-9_-]\+>',
      '\=eval(''"'' .. submatch(0) .. ''"'')', 'g')

    opts = b:htmlplugin.maps[mode][map][1]

    if opts->get('expr', false)
      evalstr = eval(rhs)
    else
      evalstr = rhs
    endif

    if mode->strlen() != 1
      printf(HTMLFunctions.E_ONECHAR, HTMLFunctions.F())->HTMLFunctions.Error()
      return ''
    endif

    if mode == 'i'
      return evalstr
    elseif mode == 'v'
      ToggleOptions(false)
      try
        execute 'normal! ' .. evalstr
      catch
        printf(HTMLFunctions.E_MAPEXCEPT, v:exception, map)->HTMLFunctions.Error()
      endtry
      ToggleOptions(true)

      if opts->has_key('reindent') && opts.reindent >= 0
        normal m'
        #ReIndent(line('v'), line('.'), opts.reindent)
        ReIndent(line("'<"), line("'>"), opts.reindent)
        normal ``
      endif

      if opts->get('insert', false)
        exe "normal! \<c-\>\<c-n>l"
        startinsert
      endif
    else
      HTMLFunctions.Error(HTMLFunctions.E_NOTPOSSIBLE)
    endif

    return ''
  enddef

  # CreateExtraMappings()  {{{1
  #
  # Purpose:
  #  Define mappings that are stored in a list
  # Arguments:
  #  1 - List of mappings: The mappings to define
  # Return Value:
  #  Boolean: Whether there were mappings to define
  def CreateExtraMappings(mappings: list<list<any>>): bool
    if len(mappings) == 0
      return false
    endif
    mappings->mapnew((_, mapping) => mapset(mapping[1], false, mapping[0]))
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
  def MapCheck(map: string, mode: string, internal: bool = false): number
    if internal &&
          ( (g:htmlplugin->has_key('no_maps')
              && g:htmlplugin.no_maps->match('^\C\V' .. map .. '\$') >= 0) ||
            (b:htmlplugin->has_key('no_maps')
              && b:htmlplugin.no_maps->match('^\C\V' .. map .. '\$') >= 0) )
      return 3
    elseif HTMLVariables.HTMLVariables.MODES->has_key(mode) && map->maparg(mode) != ''
      if this.BoolVar('g:htmlplugin.no_map_override') && internal
        return 2
      else
        printf(W_MAPOVERRIDE, map, HTMLVariables.HTMLVariables.MODES[mode], bufnr('%'), expand('%'))->Warn()
        return 1
      endif
    endif

    return 0
  enddef

  # HTMLOpWrap()  {{{1
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
  def HTMLOpWrap(type: string)
    HTMLVariables.HTMLVariables.saveopts['selection'] = &selection
    &selection = 'inclusive'

    try
      if type == 'line'
        execute 'normal `[V`]' .. b:htmlplugin.tagaction
      elseif type == 'block'
        execute "normal `[\<C-V>`]" .. b:htmlplugin.tagaction
      else
        execute 'normal `[v`]' .. b:htmlplugin.tagaction
      endif
    catch
      printf(W_CAUGHTERR, v:exception)->Warn()
    finally
      &selection = HTMLVariables.HTMLVariables.saveopts['selection']
    endtry

    if b:htmlplugin.taginsert
      exe "normal! \<c-\>\<c-n>l"
      startinsert
    endif
  enddef

  # MappingsListAdd()  {{{1
  #
  # Purpose:
  #  Add to the b:htmlplugin.mappings list variable if necessary.
  # Arguments:
  #  1 - String: The command necessary to re-define the mapping.
  #  1 - String: The mode necessary to re-define the mapping.
  # Return Value:
  #  Boolean: Whether a mapping was added to the mappings list
  def MappingsListAdd(arg: dict<any>, mode: string, internal: bool = false): bool
    if ! (internal)
      this.SetIfUnset('b:htmlplugin.mappings', '[]')
      b:htmlplugin.mappings->add([arg, mode])
      return true
    endif
    return false
  enddef

  # ToggleComments()  {{{1
  #
  # Used to make sure the 'comments' option is off temporarily to prevent
  # certain mappings from inserting unwanted comment leaders.
  #
  # Arguments:
  #  1 - Boolean: false - Clear option
  #               true  - Restore option
  #def ToggleComments(s: bool)
  #  if s
  #    if HTMLVariables.HTMLVariables.saveopts->has_key('comments') && HTMLVariables.HTMLVariables.saveopts['comments'] != ''
  #      &l:comments = HTMLVariables.HTMLVariables.saveopts['comments']
  #    endif
  #  else
  #    if &l:comments != ''
  #      HTMLVariables.HTMLVariables.saveopts['comments'] = &l:comments
  #      &l:comments = ''
  #    endif
  #  endif
  #enddef

  # ToggleClipboard()  {{{1
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
  def ToggleClipboard(dowhat: number = 2): bool
    var newdowhat = dowhat

    if newdowhat == 2
      if this.BoolVar('b:htmlplugin.did_mappings')
        newdowhat = 1
      else
        newdowhat = 0
      endif
    endif

    if newdowhat == 0
      if g:htmlplugin->has_key('save_clipboard')
        &clipboard = g:htmlplugin.save_clipboard
      else
        printf(E_NOCLIPBOARD, F())->Error()
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

  # VisualInsertPos()  {{{1
  #
  # Purpose:
  #  Used by Map() to enter insert mode in Visual mappings in the right
  #  place, depending on what 'selection' is set to.
  # Arguments:
  #   None
  # Return Value:
  #   The proper movement command based on the value of 'selection'.
  def VisualInsertPos(): string
    if &selection == 'inclusive'
      return "\<right>"
    else
      return "\<C-O>`>"
    endif
  enddef

  # ConvertCase()  {{{1
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
  def ConvertCase(str: any, case: string = 'config'): any
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

    this.SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

    if newcase =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
      newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g'))
    elseif newcase =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
      newnewstr = newstr->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g'))
    else
      printf(W_INVALIDCASE, F(), newcase)->Warn()
      newstr = newstr->this.ConvertCase('lowercase')
    endif

    if type(str) == v:t_list
      return newnewstr
    else
      return newnewstr[0]
    endif
  enddef

  # NextInsertPoint()  {{{1
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
  def NextInsertPoint(mode: string = 'n', direction: string = 'f'): bool
    var done: bool
    var line = line('.')->getline()

    # Tab in insert mode on the beginning of a closing tag jumps us to
    # after the tag:
    if mode =~? '^i' && direction =~? '^f'
      if line->strpart(col('.') - 1, 2) == '</'
        normal! %
        done = true
      elseif line->strpart(col('.') - 1) =~ '^ *-->'
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

    if ! b:htmlplugin.smarttags->has_key(newtag)
      printf(E_NOSMART, F(), newtag)->Error()
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

    ret = b:htmlplugin.smarttags[newtag][newmode][which]->this.ConvertCase()

    if newmode == 'v'
      # If 'selection' is "exclusive" all the visual mode mappings need to
      # behave slightly differently:
      ret = ret->substitute('`>a\C', '`>i' .. this.VisualInsertPos(), 'g')
    endif

    return ret
  enddef

  # GenerateTable()  {{{1
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
  def GenerateTable(rows: number = -1, columns: number = -1, border: number = -1, thead: bool = false, tfoot: bool = false): bool
    var charpos = getcharpos('.')
    var rowsstring: string
    var columnsstring: string
    var newrows: number
    var newcolumns: number
    var newborder: number
    var newthead = thead
    var newtfoot = tfoot
    var lines: list<string>

    if rows < 0
      rowsstring = inputdialog('Number of rows: ', '', 'cancel')
      if rowsstring == 'cancel'
        return false
      endif
      newrows = rowsstring->str2nr()
    else
      newrows = rows
    endif

    if columns < 0
      columnsstring = inputdialog('Number of columns: ', '', 'cancel')
      if columnsstring == 'cancel'
        return false
      endif
      newcolumns = columnsstring->str2nr()
    else
      newcolumns = columns
    endif

    if newrows < 1 || newcolumns < 1
      Error(E_ZEROROWSCOLS)
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

    lines = lines->this.ConvertCase()

    lines->append('.')

    execute ':' .. (line('.') + 1) .. ',' .. (line('.') + lines->len())
      .. 'normal! =='

    setcharpos('.', charpos)

    if getline('.') =~ '^\s*$'
      delete
    endif

    this.NextInsertPoint()

    return true
  enddef

  # PluginControl()  {{{1
  #
  # Purpose:
  #  Disable/enable all the mappings defined by
  #  Map()/Mapo().
  # Arguments:
  #  1 - String: Whether to disable or enable the mappings:
  #               d/disable/off:   Clear the mappings
  #               e/enable/on:     Redefine the mappings
  # Return Value:
  #  Boolean: False for an error, true otherwise
  def PluginControl(dowhat: string): bool

    # ClearMappings()  {{{2
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
      unlet b:htmlplugin.did_json
    enddef  # }}}2

    if !this.BoolVar('b:htmlplugin.did_mappings_init')
      Error(E_NOSRC)
      return false
    endif

    if dowhat =~? '^\%(d\%(isable\)\?\|off\|false\|0\)$'
      if this.BoolVar('b:htmlplugin.did_mappings')
        ClearMappings()
        if this.BoolVar('g:htmlplugin.did_menus')
          this.MenuControl('disable')
        endif
      else
        Error(E_DISABLED)
        return false
      endif
    elseif dowhat =~? '^\%(e\%(nable\)\?\|on\|true\|1\)$'
      if this.BoolVar('b:htmlplugin.did_mappings')
        Error(E_ENABLED)
      else
        this.ReadEntities(false, true)
        this.ReadTags(false, true)
        if b:htmlplugin->has_key('mappings')
          this.CreateExtraMappings(b:htmlplugin.mappings)
        endif
        b:htmlplugin.did_mappings = true
        this.MenuControl('enable')
      endif
    else
      printf(E_INVALIDARG, F(), dowhat)->Error()
      return false
    endif

    return true
  enddef

  # MenuControl()  {{{1
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
  def MenuControl(which: string = 'detect'): bool
    if which !~? '^disable$\|^enable$\|^detect$'
      printf(E_INVALIDARG, F(), which)->Error()
      return false
    endif

    if which == 'disable' || !this.BoolVar('b:htmlplugin.did_mappings')
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
      execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped .. '.*'
      if g:htmlplugin->has_key('did_toolbar')
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
      if this.BoolVar('b:htmlplugin.did_mappings_init')
          && !this.BoolVar('b:htmlplugin.did_mappings')
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Enable\ Mappings'
      endif
    elseif which == 'enable' || this.BoolVar('b:htmlplugin.did_mappings_init')
      execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
      if this.BoolVar('b:htmlplugin.did_mappings')
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped .. '.*'
        execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Enable\ Mappings'
        if this.BoolVar('g:htmlplugin.did_toolbar')
          amenu enable ToolBar.*
        endif
      else
        execute 'amenu enable ' .. g:htmlplugin.toplevel_menu_escaped
          .. '.Enable\ Mappings'
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
  #  2 - Boolean: Whether to convert to percentage or not
  # Return Value:
  #  String: The converted color
  def ToRGB(color: string, percent: bool = false): string
    if color !~ '^#\x\{6}$'
      printf(E_COLOR, F(), color)->Error()
      return ''
    endif

    var rgb = color[1 : -1]->split('\x\{2}\zs')->mapnew((_, val) => str2nr(val, 16))

    if percent
      rgb = rgb->mapnew((_, val) => round(val / 256.0 * 100)->float2nr())
      return printf('rgb(%d%%, %d%%, %d%%)', rgb[0], rgb[1], rgb[2])
    endif

    return printf('rgb(%d, %d, %d)', rgb[0], rgb[1], rgb[2])
  enddef

  # ColorChooser()  {{{1
  #
  # Purpose:
  #  Use the popup feature of Vim to display HTML colors for selection
  # Arguments:
  #  1 - String: Default is "i", how to insert the chosen color
  # Return Value:
  #  None
  def ColorChooser(how: string = 'i'): void
    if !this.BoolVar('b:htmlplugin.did_mappings_init')
      Error(E_NOSRC)
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

      var color = HTMLVariables.HTMLVariables.COLOR_LIST[result - 1]

      if doname
        execute 'normal! ' .. how .. color[2]
      elseif dorgb
        execute 'normal! ' .. how .. color[1]->this.ToRGB()
      elseif dorgbpercent
        execute 'normal! ' .. how .. color[1]->this.ToRGB(true)
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
        popup_close(id, -2)
        return true
      elseif key == "\<2-leftmouse>" || key == "\<s-2-leftmouse>" || key == "\<c-2-leftmouse>"
        var mousepos = getmousepos()
        if mousepos['screencol'] < (popup_getpos(id)['core_col'] - 1) ||
            mousepos['screenrow'] < (popup_getpos(id)['core_line']) ||
            mousepos['screencol'] > (popup_getpos(id)['core_col']
              + popup_getpos(id)['core_width'] - 1) ||
            mousepos['screenrow'] > (popup_getpos(id)['core_line']
              + popup_getpos(id)['core_height'] - 1)
          newkey = key
        else
          if key == "\<s-2-leftmouse>"
            dorgb = true
          elseif key == "\<c-2-leftmouse>"
            dorgbpercent = true
          elseif mousepos['screencol'] < (popup_getpos(id)['core_col']
              + popup_getpos(id)['core_width'] - 9)
            doname = true
          endif

          popup_close(id, popup_getpos(id)['firstline']
            + mousepos['winrow'] - 2)
          return true
        endif
      else
        newkey = key
      endif

      return popup_filter_menu(id, newkey)
    enddef  # }}}2

    maxw = HTMLVariables.HTMLVariables.COLOR_LIST->mapnew((_, value) => value[0]->strlen())
      ->sort('f')[-1]

    var colorwin = HTMLVariables.HTMLVariables.COLOR_LIST->mapnew(
        (_, value) => printf('%' .. maxw .. 's = %s', (value[0] == '' ? value[1] : value[0]), value[1])
      )->popup_menu({
        callback: CCSelect, filter: CCKeyFilter,
        pos: 'topleft',     col: 'cursor',
        line: 1,            maxheight: &lines - 3,
        close: 'button',
      })

    HTMLVariables.HTMLVariables.COLOR_LIST->mapnew(
      (_, value) => {
        var csplit = value[1][1 : -1]->split('\x\x\zs')->mapnew((_, val) => val->str2nr(16))
        var contrast = (((csplit[0] > 0x80) || (csplit[1] > 0x80) || (csplit[2] > 0x80)) ?
          0x000000 : 0xFFFFFF)
        var namens = (value[0] == '' ? value[1] : value[0]->substitute('\s', '', 'g'))
        win_execute(colorwin, 'syntax match hc_' .. namens .. ' /'
          .. value[1] .. '$/')
        win_execute(colorwin, 'highlight hc_' .. namens .. ' guibg='
          .. value[1] .. ' guifg=#' .. printf('%06X', contrast))

        return
      })
  enddef

  # TokenReplace()  {{{1
  #
  # Purpose:
  #  Replace user tokens with appropriate text, based on configuration
  # Arguments:
  #  1 - String or List of strings: The text to do token replacement on
  # Return Value:
  #  String or List: The new text
  def TokenReplace(text: list<string>, directory: string = ''): list<string>
    return text->mapnew(
      (_, str) =>
          str->substitute('\C%\(' .. join(keys(HTMLVariables.HTMLVariables.TEMPLATE_TOKENS), '\|') .. '\)%',
                '\=get(b:htmlplugin, HTMLVariables.HTMLVariables.TEMPLATE_TOKENS[submatch(1)], "")', 'g')
              ->substitute('\C%date%', '\=strftime("%B %d, %Y")', 'g')
              ->substitute('\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%',
                '\=submatch(1)->substitute(''\\%'', "%%", "g")->substitute(''\\\@<!!'', "%", "g")->strftime()', 'g')
              ->substitute('\C%time%', '\=strftime("%r %Z")', 'g')
              ->substitute('\C%time12%', '\=strftime("%r %Z")', 'g')
              ->substitute('\C%time24%', '\=strftime("%T")', 'g')
              ->substitute('\C%charset%', '\=this.DetectCharset()', 'g')
              ->substitute('\C%vimversion%', '\=(v:version / 100) .. "." .. (v:version % 100) .. "." .. (v:versionlong % 10000)', 'g')
              ->substitute('\C%htmlversion%', HTMLVariables.HTMLVariables.VERSION, 'g')
              ->substitute('\C%include\s\+\(.\{-1,}\)%',
                '\=this.FindAndRead(submatch(1), expand("%:p:h") .. (directory != "" ? "," .. directory : ""))->join("%newline%")', 'g')
      )
  enddef

  # FindAndRead() {{{1
  #
  # Purpose:
  #  Find an include file and return it.
  # Arguments:
  #  1 - String: File to find
  #  2 - String: Directories to search, comma separated, last one is
  #              passed on in recursive calls
  # Return Value:
  #  String: The file's contents
  def FindAndRead(inc: string, path: string): list<string>
    var found: list<string> = findfile(inc, path, -1)

    if len(found) <= 0
      printf(HTMLFunctions.E_NOTFOUND, inc)->HTMLFunctions.Warn()
      return []
    endif
           
    return readfile(found[0])->this.TokenReplace(split(path, ':')[-1])
  enddef

  # Template()  {{{1
  #
  # Purpose:
  #  Determine whether to insert the HTML template.
  # Arguments:
  #  None
  # Return Value:
  #  Boolean - Whether the cursor is not on an insert point.
  def Template(file: string = ''): bool

    # InsertTemplate()  {{{2
    #
    # Purpose:
    #  Actually insert the HTML template.
    # Arguments:
    #  None
    # Return Value:
    #  Boolean - Whether the cursor is not on an insert point.
    def InsertTemplate(f: string = ''): bool

      if g:htmlplugin.author_email != ''
        g:htmlplugin.author_email_encoded = g:htmlplugin.author_email->this.TranscodeString()
        b:htmlplugin.author_email_encoded = b:htmlplugin.author_email->this.TranscodeString()
      else
        g:htmlplugin.author_email_encoded = ''
        b:htmlplugin.author_email_encoded = ''
      endif

      var template: string

      if f != ''
        template = f
      elseif b:htmlplugin->get('template', '') != ''
        template = b:htmlplugin.template
      elseif g:htmlplugin->get('template', '') != ''
        template = g:htmlplugin.template
      endif

      if template != ''
        if template->expand()->filereadable()
          template->readfile()->this.TokenReplace(fnamemodify(template, ':p:h'))->append(0)
        else
          printf(HTMLFunctions.E_TEMPLATE, template)->HTMLFunctions.Error()
          return false
        endif
      else
        b:htmlplugin.internal_template->this.TokenReplace()->append(0)
      endif

      # Special case, can't be done in TokenReplace():
      execute(':%s/%newline%/\r/g', 'silent!')

      if getline('$') =~ '^\s*$'
        :$delete
      endif

      cursor(1, 1)

      redraw

      this.NextInsertPoint('n')
      if getline('.')[col('.') - 2 : col('.') - 1] == '><'
          || (getline('.') =~ '^\s*$' && line('.') != 1)
        return true
      else
        return false
      endif
    enddef  # }}}2

    var ret = false
    HTMLVariables.HTMLVariables.saveopts['ruler'] = &ruler
    HTMLVariables.HTMLVariables.saveopts['showcmd'] = &showcmd
    set noruler noshowcmd

    if line('$') == 1 && getline(1) == ''
      ret = InsertTemplate(file)
    else
      var YesNoOverwrite = confirm("Non-empty file.\nInsert template anyway?", "&Yes\n&No\n&Overwrite", 2, 'Question')
      if YesNoOverwrite == 1
        ret = InsertTemplate(file)
      elseif YesNoOverwrite == 3
        execute ':%delete'
        ret = InsertTemplate(file)
      endif
    endif

    &ruler = HTMLVariables.HTMLVariables.saveopts['ruler']
    &showcmd = HTMLVariables.HTMLVariables.saveopts['showcmd']

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

    if b:htmlplugin->has_key('charset')
      return b:htmlplugin.charset
    elseif g:htmlplugin->has_key('charset')
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

    if HTMLVariables.HTMLVariables.CHARSETS[enc] != ''
      return HTMLVariables.HTMLVariables.CHARSETS[enc]
    endif

    return g:htmlplugin.default_charset
  enddef

  # MenuJoin()  {{{1
  #
  # Purpose:
  #  Simple function to join menu name array into a valid menu name, escaped
  # Arguments:
  #  1 - List: The menu name
  # Return Value:
  #  The menu name joined into a single string, escaped
  def MenuJoin(menuname: list<string>): string
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

  # Menu()  {{{1
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
  def Menu(type: string, level: string, name: list<string>, item: string): void
    var newlevel: string
    var newname: list<string>
    var nameescaped: string
    var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
    var priorityprefix = this.MenuPriorityPrefix(name[0])

    if name[0] == 'ToolBar' || name[0] == 'PopUp'
      newname = name
    else
      newname = name->extendnew(g:htmlplugin.toplevel_menu, 0)
    endif

    nameescaped = newname->this.MenuJoin()

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

  # LeadMenu()  {{{1
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
  def LeadMenu(type: string, level: string, name: list<string>, item: string, pre: string = ''): void
    var newlevel: string
    var newname: list<string>
    var nameescaped: string
    var leaderescaped = g:htmlplugin.map_leader->escape('&<.|')->substitute('\\&', '\&\&', 'g')
    var priorityprefix = this.MenuPriorityPrefix(name[0])

    if name[0] == 'ToolBar'
      newname = name
    else
      newname = name->extendnew(g:htmlplugin.toplevel_menu, 0)
    endif

    nameescaped = newname->this.MenuJoin()

    if level == '-' || level == ''
      newlevel = ''
    else
      newlevel = priorityprefix .. level
    endif

    execute type .. ' ' .. newlevel .. ' ' .. nameescaped .. '<tab>'
      .. leaderescaped .. item .. ' ' .. pre .. g:htmlplugin.map_leader .. item
  enddef

  # EntityMenu()  {{{1
  #
  # Purpose:
  #  Generate HTML character entity menu items
  # Arguments:
  #  1 - List: The menu name, split into submenu heirarchy as a list
  #  2 - String: The item
  #  3 - String: The symbol it generates
  # Return Value:
  #  None
  def EntityMenu(name: list<string>, item: string, symb: string = ''): void
    var newname = name->extendnew(['Character Entities'], 0)
    var nameescaped: string

    if g:htmlplugin.toplevel_menu != []
      newname = newname->extendnew(g:htmlplugin.toplevel_menu, 0)
    endif

    nameescaped = newname->this.MenuJoin()

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

  # ColorsMenu()  {{{1
  #
  # Purpose:
  #  Generate HTML colors menu items
  # Arguments:
  #  1 - String: The color name
  #  2 - String: The color hex code
  # Return Value:
  #  None
  def ColorsMenu(name: string, color: string): void
    var c = name->strpart(0, 1)->toupper()
    var newname: list<string>
    var namens: string
    var nameescaped: string
    var rgb: string
    var rgbpercent: string

    if HTMLVariables.HTMLVariables.COLORS_SORT->has_key(c)
      newname = [name]->extendnew(['&Colors', '&' .. HTMLVariables.HTMLVariables.COLORS_SORT[c]], 0)
    else
      if name == ''
        newname = [color]->extendnew(['&Colors', 'Web Safe Palette'], 0)
      else
        newname = [name]->extendnew(['&Colors', 'Web Safe Palette'], 0)
      endif
    endif

    if g:htmlplugin.toplevel_menu != []
      newname = newname->extendnew(g:htmlplugin.toplevel_menu, 0)
    endif

    nameescaped = newname->this.MenuJoin()

    namens = (name == '' ? color : name->substitute('\s', '', 'g'))
    rgb = color->this.ToRGB()
    rgbpercent = color->this.ToRGB(true)

    if namens == color
      execute 'inoremenu ' .. nameescaped
        .. '.Insert\ &Hexadecimal ' .. color
      execute 'nnoremenu ' .. nameescaped
        .. '.Insert\ &Hexadecimal i' .. color .. '<esc>'
      execute 'vnoremenu ' .. nameescaped
        .. '.Insert\ &Hexadecimal s' .. color .. '<esc>'

      execute 'inoremenu ' .. nameescaped
        .. '.Insert\ &RGB ' .. rgb
      execute 'nnoremenu ' .. nameescaped
        .. '.Insert\ &RGB i' .. rgb .. '<esc>'
      execute 'vnoremenu ' .. nameescaped
        .. '.Insert\ &RGB s' .. rgb .. '<esc>'

      execute 'inoremenu ' .. nameescaped
        .. '.Insert\ RGB\ &Percent ' .. rgbpercent
      execute 'nnoremenu ' .. nameescaped
        .. '.Insert\ RGB\ &Percent i' .. rgbpercent .. '<esc>'
      execute 'vnoremenu ' .. nameescaped
        .. '.Insert\ RGB\ &Percent s' .. rgbpercent .. '<esc>'
    else
      execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Name ' .. namens
      execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Name i' .. namens .. '<esc>'
      execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Name s' .. namens .. '<esc>'

      execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Hexadecimal ' .. color
      execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Hexadecimal i' .. color .. '<esc>'
      execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &Hexadecimal s' .. color .. '<esc>'

      execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &RGB ' .. rgb
      execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &RGB i' .. rgb .. '<esc>'
      execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ &RGB s' .. rgb .. '<esc>'

      execute 'inoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ RGB\ &Percent ' .. rgbpercent
      execute 'nnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ RGB\ &Percent i' .. rgbpercent .. '<esc>'
      execute 'vnoremenu ' .. nameescaped .. '<tab>(' .. color
        .. ').Insert\ RGB\ &Percent s' .. rgbpercent .. '<esc>'
    endif
  enddef

  # ReadJsonFile()  {{{1
  #
  #  Purpose:
  #   Find JSON files in the runtimepath and return them as a Vim array
  #  Arguments:
  #   1 - String: The filename to find and read
  #  Return Value:
  #   List - The JSON data as a Vim array, empty if there was a problem
  def ReadJsonFile(file: string): list<any>
    var json_files: list<string> = file->findfile(&runtimepath, -1)
    var json_data: list<any> = []

    if json_files->len() == 0
      printf(E_NOTFOUNDRTP, F(), file)->Error()
      return []
    endif

    for f in json_files
      if f->filereadable()
        json_data->extend(f->readfile()->join("\n")->json_decode())
      else
        printf(E_NOREAD, F(), f)->Error()
      endif
    endfor

    return json_data
  enddef

  # ReadTags()  {{{1
  #
  #  Purpose:
  #   Read in the HTML tags JSON file and define both the mappings and menu at
  #   the same time, unless otherwise specified.
  #  Arguments:
  #   1 - Boolean: Optional, whether to define the menus
  #   2 - Boolean: Optional, whether tags being read are internal to the plugin
  #   3 - String:  Optional, what json file to read
  #  Return Value:
  #   Boolean - Whether the json file was successfully read in without error
  def ReadTags(domenu: bool = true, internal: bool = false, file: string = HTMLVariables.HTMLVariables.TAGS_FILE): bool
    var maplhs: string
    var menulhs: string
    var rval = true
    var json_data = this.ReadJsonFile(file)

    if json_data == []
      printf(E_NOTAG)
      return false
    endif

    # b:htmlplugin.smarttags[tag][mode][open/close/insert] = value
    #  tag        - The literal tag, lowercase and without the <>'s
    #               Numbers at the end of the literal tag name are stripped,
    #               allowing for multiple mappings of the same tag but with
    #               different effects
    #  mode       - i = insert, v = visual
    #               (no "o", because o-mappings invoke visual mode)
    #  open&close - c = When inside an equivalent tag, close then open it
    #               o = When not inside (outside) of an equivalent tag
    #  insert     - Only for the visual mappings; behave slightly
    #               differently in visual mappings if this is set to true
    #  value      - The keystrokes to execute
    if !b:htmlplugin->has_key('smarttags')
      b:htmlplugin.smarttags = {}
    endif

    for json in json_data
        if json->has_key('menu') && json.menu[2]->has_key('n')
            && json.menu[2].n[0] ==? '<nop>' && domenu
          this.Menu('menu', json.menu[0], json.menu[1], '<nop>')
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
          # Translate \<...> strings to their corresponding actual value:
          var smarttag = json.smarttag->string()->substitute('\c\\<[a-z0-9_-]\+>',
              '\=eval(''"'' .. submatch(0) .. ''"'')', 'g')

          b:htmlplugin.smarttags->extend(smarttag->eval())
        endif

        if json->has_key('maps')
          var did_mappings = 0

          if json.maps->has_key('i')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'i') == ''
            if this.Map('inoremap',
                (maplhs == '' ? '<lead>' .. json.maps.i[0] : maplhs),
                json.maps.i[1],
                len(json.maps.i) >= 3 ? json.maps.i[2] : {},
                internal)
              ++did_mappings
            endif
          endif

          if json.maps->has_key('v')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'v') == ''
            if this.Map('vnoremap',
                (maplhs == '' ? '<lead>' .. json.maps.v[0] : maplhs),
                json.maps.v[1],
                len(json.maps.v) >= 3 ? json.maps.v[2] : {},
                internal)
              ++did_mappings
            endif
          endif

          if json.maps->has_key('n')
              && maparg((maplhs == '' ? '<lead>' .. json.maps.n[0] : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'n') == ''
            if this.Map('nnoremap',
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
            if this.Mapo(
                (maplhs == '' ? '<lead>' .. json.maps.o[0] : maplhs),
                json.maps.o[1],
                internal)
              ++did_mappings
            endif
          endif

          # If it was indicated that mappings would be defined but none were
          # actually defined, don't set the menu items for this mapping either:
          if did_mappings == 0
            if maplhs != ''
              Warn('No mapping(s) were defined for "' .. maplhs .. '".'
                .. (json->has_key('menu') ? '' : ' Skipping menu item.'))
            endif
            continue
          endif
        endif

        if domenu && json->has_key('menu')
          var did_menus = 0

          if json.menu[2]->has_key('i')
            this.LeadMenu('imenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].i[0] : menulhs),
              json.menu[2].i[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('v')
            this.LeadMenu('vmenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].v[0] : menulhs),
              json.menu[2].v[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('n')
            this.LeadMenu('nmenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].n[0] : menulhs),
              json.menu[2].n[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('a')
            this.LeadMenu(
              'amenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].a[0] : menulhs),
              json.menu[2].a[1])
            ++did_menus
          endif

          if did_menus == 0
              printf(W_NOMENU, json.menu[1][-1])->Warn()
          endif
        endif
    endfor

    return rval
  enddef

  # ReadEntities()  {{{1
  #
  #  Purpose:
  #   Read in the HTML entities JSON file and define both the mappings and menu
  #   at the same time, unless otherwise specified.
  #  Arguments:
  #   1 - Boolean: Optional, whether to define the menus
  #   2 - Boolean: Optional, whether entities being read are internal to the plugin
  #   3 - String:  Optional, what json file to read
  #  Return Value:
  #   Boolean - Whether the json file was successfully read in without error
  def ReadEntities(domenu: bool = true, internal: bool = false, file: string = HTMLVariables.HTMLVariables.ENTITIES_FILE): bool
    var rval = true
    var json_data = this.ReadJsonFile(file)

    if json_data == []
      printf(E_NOENTITY)
      return false
    endif

    for json in json_data
      if json->len() != 4 || json[2]->type() != v:t_list
        printf(E_JSON, F(), file, json->string())->Error()
        rval = false
        continue
      endif
      if json[3] ==? '<nop>'
        if domenu
          this.Menu('menu', '-', json[2]->extendnew(['Character &Entities'], 0), '<nop>')
        endif
      else
        if maparg(g:htmlplugin.entity_map_leader .. json[0], 'i') != '' ||
          !this.Map('inoremap', '<elead>' .. json[0], json[1], {extra: false}, internal)
          # Failed to map? No menu item should be defined either:
          continue
        endif
        if domenu
          this.EntityMenu(json[2], json[0], json[3])
        endif
      endif
    endfor

    return rval
  enddef


  # F()  {{{1
  #
  #  Purpose:
  #   Get the function name from the stack in the context of the caller of F().
  #  Arguments:
  #   None
  #  Return Value:
  #   String: The function name
  static def F(): string
    return split(expand('<stack>'), '\.\.')[-2]->substitute('\[\d\+\]$', '', '')
  enddef

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=5:comments=b\:#:commentstring=\ #\ %s:
