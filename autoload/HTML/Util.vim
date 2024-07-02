vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  finish
endif

# Utility functions for the HTML macros filetype plugin.
#
# Last Change: July 01, 2024
#
# Requirements:
#       Vim 9.1.219 or later
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

import '../../import/HTML/Variables.vim'
import autoload 'HTML/BrowserLauncher.vim'
import autoload 'HTML/Messages.vim'

export enum SetIfUnsetR # {{{1
  error,
  exists,
  success
endenum

export enum ToggleClipboardA # {{{1
  remove,
  add,
  auto
endenum

# }}}1

export class HTMLUtil

  final HTMLMessagesO: Messages.HTMLMessages
  final HTMLVariablesO: Variables.HTMLVariables

  def new() # {{{
    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = Variables.HTMLVariables.new()
  enddef # }}}

  # About()  {{{1
  #
  # Purpose:
  #  Pop up an about window for the plugin.
  # Arguments:
  #  None
  # Return Value:
  #  None
  static def About(): void
    var message = "HTML/XHTML Editing Macros and Menus Plugin\n"
      .. $"Version: {Variables.HTMLVariables.VERSION}"
      .. $"\nWritten by: {Variables.HTMLVariables.AUTHOR}"
      .. $" <{Variables.HTMLVariables.EMAIL}>\n"
      .. "With thanks to Doug Renze for the original concept,\n"
      .. "Devin Weaver for the original mangleImageTag,\n"
      .. "Israel Chauca Fuentes for the MacOS version of the\n"
      .. "browser launcher code, and several others for their\n"
      .. "contributions.\n"
      .. $"{Variables.HTMLVariables.COPYRIGHT}\nURL: "
      .. $"{Variables.HTMLVariables.HOMEPAGE}"

    if message->confirm("&Visit Homepage\n&Dismiss", 2, 'Info') == 1
      BrowserLauncher.BrowserLauncher.new().Launch('default',
        BrowserLauncher.Behavior.default, Variables.HTMLVariables.HOMEPAGE)
    endif
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

    printf(this.HTMLMessagesO.E_BOOLTYPE, Messages.HTMLMessages.F(), value->typename())->this.HTMLMessagesO.Error()
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
  def BoolVar(v: string): bool
    var variable = v

    if variable !~ '^[bgstvw]:'
      variable = 'g:{variable}'
    endif

    if variable->this.IsSet()
      return variable->eval()->this.Bool()
    else
      return false
    endif
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
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOSOURCED)
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

      var color = Variables.HTMLVariables.COLOR_LIST[result - 1]

      if doname
        execute $'normal! {how} {color[0]->substitute("\\s", "", "g")}'
      elseif dorgb
        execute $'normal! {how} ' .. color[1]->this.ToRGB(false)
      elseif dorgbpercent
        execute $'normal! {how} ' .. color[1]->this.ToRGB(true)
      else
        execute $'normal! {how} {color[1]}'
      endif

      if mode == 'i'
        if col('.') == getline('.')->strlen()
          startinsert!
        else
          execute 'normal! l'
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
        if mousepos.screencol < (popup_getpos(id)['core_col'] - 1) ||
            mousepos.screenrow < (popup_getpos(id)['core_line']) ||
            mousepos.screencol > (popup_getpos(id)['core_col']
              + popup_getpos(id)['core_width'] - 1) ||
            mousepos.screenrow > (popup_getpos(id)['core_line']
              + popup_getpos(id)['core_height'] - 1)
          newkey = key
        else
          if key == "\<s-2-leftmouse>"
            dorgb = true
          elseif key == "\<c-2-leftmouse>"
            dorgbpercent = true
          elseif mousepos.screencol < (popup_getpos(id)['core_col']
              + popup_getpos(id)['core_width'] - 9)
            doname = true
          endif

          popup_close(id, popup_getpos(id)['firstline']
            + mousepos.winrow - 2)
          return true
        endif
      else
        newkey = key
      endif

      return popup_filter_menu(id, newkey)
    enddef  # }}}2

    maxw = Variables.HTMLVariables.COLOR_LIST->mapnew((_, value) => value[0]->strlen())
      ->sort('f')[-1]

    var colorwin = Variables.HTMLVariables.COLOR_LIST->mapnew(
        (_, value) => printf($'%{maxw}s = %s', (value[0] == '' ? value[1] : value[0]), value[1])
      )->popup_menu({
        callback: CCSelect, filter: CCKeyFilter,
        pos: 'topleft',     col: 'cursor',
        line: 1,            maxheight: &lines - 3,
        close: 'button',
      })

    Variables.HTMLVariables.COLOR_LIST->mapnew(
      (_, value) => {
        var csplit = value[1][1 : -1]->split('\x\x\zs')->mapnew((_, val) => val->str2nr(16))
        var contrast = (((csplit[0] > 0x80) || (csplit[1] > 0x80) || (csplit[2] > 0x80)) ? 0x000000 : 0xFFFFFF)
        var namenospace = (value[0] == '' ? value[1] : value[0]->substitute('\s', '', 'g'))
        win_execute(colorwin, $'syntax match hc_{namenospace} /{value[1]}$/')
        win_execute(colorwin, $'highlight hc_{namenospace} guibg={value[1]} guifg=#{printf("%06X", contrast)}')

        return
      })
  enddef

  # ConvertCase()  {{{1
  #
  # Purpose:
  #  Convert special regions in a string to the appropriate case determined by
  #  b:htmlplugin.tag_case.
  # Arguments:
  #  1 - String or list<string>: The string(s) with the regions to convert
  #      surrounded by [{...}].
  #  2 - Optional: The case to convert to, either "uppercase" or "lowercase".
  #      The default is to follow the configuration variable.
  # Return Value:
  #  The converted string(s), or 0 on error.
  def ConvertCase(s: any, c: string = 'config'): any
    var str: list<string>
    var newstr: list<string>
    var case: string

    if typename(s) == 'list<string>'
      str = s
    elseif type(s) == v:t_string
      str = [s]
    else
      printf(this.HTMLMessagesO.E_INVALIDTYPE, typename(str))->this.HTMLMessagesO.Error()
      return 0
    endif

    if c == 'config'
      this.SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)
      case = b:htmlplugin.tag_case
    else
      case = case
    endif

    if case =~? '^u\%(p\%(per\%(case\)\?\)\?\)\?'
      newstr = str->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\U\1', 'g'))
    elseif case =~? '^l\%(ow\%(er\%(case\)\?\)\?\)\?'
      newstr = str->mapnew((_, value): string => value->substitute('\[{\(.\{-}\)}\]', '\L\1', 'g'))
    else
      printf(this.HTMLMessagesO.W_INVALIDCASE, Messages.HTMLMessages.F(), case)->this.HTMLMessagesO.Warn()
      newstr = str->this.ConvertCase('lowercase')
    endif

    if type(s) == v:t_string
      return newstr[0]
    else
      return newstr
    endif
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

    if Variables.HTMLVariables.CHARSETS[enc] != ''
      return Variables.HTMLVariables.CHARSETS[enc]
    endif

    return g:htmlplugin.default_charset
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
    var matched: list<string> = []

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

  # FindAndRead()  {{{1
  #
  # Purpose:
  #  Find an include file and return it.
  # Arguments:
  #  1 - String:  File to find.
  #  2 - String:  Directories to search, comma separated.
  #  3 - Boolean: Whether to do token replacement on the file contents before
  #               returning it.
  #  4 - Boolean: Whether to return all the files found or just the first.
  # Return Value:
  #  String: The file's contents
  def FindAndRead(file: string, path: string, tokenize: bool = false, all: bool = false): list<string>
    var found: list<string> = file->findfile(path, -1)

    if len(found) <= 0
      printf(this.HTMLMessagesO.E_NOTFOUND, file)->this.HTMLMessagesO.Warn()
      return []
    endif

    var contents: list<string> = []

    for f in found
      if f->filereadable()
        contents->extend(f->readfile())
      else
        printf(this.HTMLMessagesO.E_NOREAD, Messages.HTMLMessages.F(), f)->this.HTMLMessagesO.Error()
      endif

      if ! all
        break
      endif
    endfor

    if tokenize
      return contents->this.TokenReplace(path)
    else
      return contents
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

  # ReadJsonFiles()  {{{1
  #
  #  Purpose:
  #   Find JSON files in the runtimepath, or specified path and return their
  #   contents as a Vim list
  #  Arguments:
  #   1 - String: The filename to find and read
  #  Return Value:
  #   List - The JSON data as a Vim list, empty if there was a problem
  def ReadJsonFiles(file: string, path: string = &runtimepath): list<any>
    return file->this.FindAndRead(path, false, true)->join("\n")->json_decode()
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
  #  SetIfUnsetR.exists   - The variable already existed
  #  SetIfUnsetR.success  - The variable didn't exist and was successfully set
  #  SetIfUnsetR.error    - An error occurred
  def SetIfUnset(v: string, ...args: list<any>): SetIfUnsetR
    var val: any
    var variable = v

    if variable =~# '^l:'
      printf(this.HTMLMessagesO.E_NOLOCALVAR, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return SetIfUnsetR.error
    elseif variable !~# '^[bgstvw]:'
      variable = $'g:{variable}'
    endif

    if args->len() == 0
      printf(this.HTMLMessagesO.E_NARGS, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return SetIfUnsetR.error
    elseif type(args[0]) == v:t_list || type(args[0]) == v:t_dict
        || type(args[0]) == v:t_number
      val = args[0]
    else
      val = args->join(' ')
    endif

    if variable->this.IsSet()
      return SetIfUnsetR.exists
    endif

    if type(val) == v:t_string
      if val == '""' || val == "''" || val == '[]' || val == '{}'
        execute $'{variable} = {val}'
      elseif val =~ '^-\?[[:digit:]]\+$'
        execute $'{variable} = {val->str2nr()}'
      elseif val =~ '^-\?[[:digit:].]\+$'
        execute $'{variable} = {val->str2float()}'
      else
        execute $'{variable} = ''{val->escape("''\\")}'''
      endif
    elseif type(val) == v:t_number || type(val) == v:t_float
      execute $'{variable} = {val}'
    else
      execute $'{variable} = {string(val)}'
    endif

    return SetIfUnsetR.success
  enddef

  # TokenReplace()  {{{1
  #
  # Purpose:
  #  Replace user tokens with appropriate text, based on configuration
  # Arguments:
  #  1 - String or List of strings: The text to do token replacement on
  # Return Value:
  #  String or List: The new text
  def TokenReplace(text: list<string>, path: string = ''): list<string>
    var newpath: string
    if path == ''
      newpath = expand('%:p:h')
    else
      newpath = split(expand('%:p:h') .. ',' .. path, ',')->uniq()->join(',')
    endif

    return text->mapnew(
      (_, str) =>
        str->substitute($'\C%\({join(keys(Variables.HTMLVariables.TEMPLATE_TOKENS), '\|')}\)%',
              '\=get(b:htmlplugin, Variables.HTMLVariables.TEMPLATE_TOKENS[submatch(1)], "")', 'g')
            ->substitute('\C%date%', '\=strftime("%B %d, %Y")', 'g')
            ->substitute('\C%date\s*\(\%(\\%\|[^%]\)\{-}\)\s*%',
              '\=submatch(1)->substitute(''\\%'', "%%", "g")->substitute(''\\\@<!!'', "%", "g")->strftime()', 'g')
            ->substitute('\C%time%', '\=strftime("%r %Z")', 'g')
            ->substitute('\C%time12%', '\=strftime("%r %Z")', 'g')
            ->substitute('\C%time24%', '\=strftime("%T")', 'g')
            ->substitute('\C%charset%', '\=this.DetectCharset()', 'g')
            ->substitute('\C%vimversion%', '\=(v:version / 100) .. "." .. (v:version % 100) .. "." .. (v:versionlong % 10000)', 'g')
            ->substitute('\C%htmlversion%', Variables.HTMLVariables.VERSION, 'g')
            ->substitute('\C%include\s\+\(.\{-1,}\)%',
              '\=this.FindAndRead(submatch(1), newpath, true, true)->join("%newline%")', 'g')
      )
  enddef

  # ToggleClipboard()  {{{1
  #
  # Used to turn off/on the inclusion of "html" in the 'clipboard' option when
  # switching buffers.
  #
  # Arguments:
  #  1 - ToggleClipboardA:
  #      remove - Remove 'html' if it was removed before.
  #      add    - Add 'html'.
  #      auto   - Auto detect which to do. (Default)
  #
  # (Note that g:htmlplugin.save_clipboard is set by this plugin's
  # initialization.)
  def ToggleClipboard(dowhat: ToggleClipboardA = ToggleClipboardA.auto): bool
    var newdowhat = dowhat

    if newdowhat == ToggleClipboardA.auto
      if this.BoolVar('b:htmlplugin.did_mappings')
        newdowhat = ToggleClipboardA.add
      else
        newdowhat = ToggleClipboardA.remove
      endif
    endif

    if newdowhat == ToggleClipboardA.remove
      if g:htmlplugin->has_key('save_clipboard')
        &clipboard = g:htmlplugin.save_clipboard
      else
        printf(this.HTMLMessagesO.E_NOCLIPBOARD, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
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

  # ToggleOptions()  {{{1
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
        if this.HTMLVariablesO.saveopts->has_key('formatoptions')
            && this.HTMLVariablesO.saveopts.formatoptions != ''
          &l:showmatch = this.HTMLVariablesO.saveopts.showmatch
          &l:indentexpr = this.HTMLVariablesO.saveopts.indentexpr
          &l:formatoptions = this.HTMLVariablesO.saveopts.formatoptions
        endif

        # Restore the last visual mode if it was changed:
        if this.HTMLVariablesO.saveopts->get('visualmode', '') != ''
          execute $'normal! gv{this.HTMLVariablesO.saveopts.visualmode}'
          this.HTMLVariablesO.saveopts->remove('visualmode')
        endif
      else
        if &l:formatoptions != ''
          this.HTMLVariablesO.saveopts.showmatch = &l:showmatch
          this.HTMLVariablesO.saveopts.indentexpr = &l:indentexpr
          this.HTMLVariablesO.saveopts.formatoptions = &l:formatoptions
        endif
        &l:showmatch = false
        &l:indentexpr = ''
        &l:formatoptions = ''

        # A trick to make leading indent on the first line of visual-line
        # selections is handled properly (turn it into a character-wise
        # selection and exclude the leading indent):
        if visualmode() ==# 'V'
          this.HTMLVariablesO.saveopts.visualmode = visualmode()
          execute "normal! \<c-\>\<c-n>`<^v`>"
        endif
      endif
    catch
      printf(this.HTMLMessagesO.E_OPTEXCEPTION, v:exception)->this.HTMLMessagesO.Error()
    endtry
  enddef

  # }}}1
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
      printf(this.HTMLMessagesO.E_COLOR, Messages.HTMLMessages.F(), color)->this.HTMLMessagesO.Error()
      return ''
    endif

    var rgb = color[1 : -1]->split('\x\{2}\zs')->mapnew((_, val) => str2nr(val, 16))

    if percent
      rgb = rgb->mapnew((_, val) => round(val / 256.0 * 100)->float2nr())
      return printf('rgb(%d%%, %d%%, %d%%)', rgb[0], rgb[1], rgb[2])
    endif

    return printf('rgb(%d, %d, %d)', rgb[0], rgb[1], rgb[2])
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
  #              - omitted or e/encode:  Encode as a &#...; string
  #              - other:    No change to the string
  # Return Value:
  #  String: The encoded string.
  def TranscodeString(str: string, code: string = 'encode'): string

    # CharToEntity()  {{{2
    #
    # Purpose:
    #  Convert a character to its corresponding character entity, or its numeric
    #  form if the entity doesn't exist in the lookup table.
    # Arguments:
    #  1 - Character: The character to encode
    # Return Value:
    #  String: The entity representing the character
    def CharToEntity(c: string): string
      var char: string

      if c->strchars(1) != 1
        printf(this.HTMLMessagesO.E_ONECHAR, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
        return c
      endif

      char = Variables.HTMLVariables.DictCharToEntities->get(c, printf('&#x%X;', c->char2nr()))

      return char
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

        if Variables.HTMLVariables.DictEntitiesToChar->has_key(entity)
          char = Variables.HTMLVariables.DictEntitiesToChar[entity]
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

    if code == '' || code =~? '^\%(e\%(ncode\)\=)\=$'
      return str->mapnew((_, char) => char->CharToEntity())
    elseif code ==? 'x'
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

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
