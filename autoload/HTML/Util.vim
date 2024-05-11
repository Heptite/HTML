vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010219
  finish
endif

# Various functions for the HTML macros filetype plugin.
#
# Last Change: May 10, 2024
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

import '../../import/HTML/Variables.vim' as HTMLVariables
import autoload 'HTML/BrowserLauncher.vim'
import autoload 'HTML/Messages.vim'

export enum SetIfUnsetR # {{{1
  error,
  exists,
  success
endenum  # }}}1

export class HTMLUtil

  final HTMLMessagesO: Messages.HTMLMessages
  final HTMLVariablesO: HTMLVariables.HTMLVariables

  def new() # {{{
    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = HTMLVariables.HTMLVariables.new()
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
      .. $"Version: {HTMLVariables.HTMLVariables.VERSION}"
      .. $"\nWritten by: {HTMLVariables.HTMLVariables.AUTHOR}"
      .. $" <{HTMLVariables.HTMLVariables.EMAIL}>\n"
      .. "With thanks to Doug Renze for the original concept,\n"
      .. "Devin Weaver for the original mangleImageTag,\n"
      .. "Israel Chauca Fuentes for the MacOS version of the\n"
      .. "browser launcher code, and several others for their\n"
      .. "contributions.\n"
      .. $"{HTMLVariables.HTMLVariables.COPYRIGHT}\nURL: "
      .. $"{HTMLVariables.HTMLVariables.HOMEPAGE}"

    if message->confirm("&Visit Homepage\n&Dismiss", 2, 'Info') == 1
      BrowserLauncher.BrowserLauncher.new().Launch('default',
        BrowserLauncher.Behavior.default, HTMLVariables.HTMLVariables.HOMEPAGE)
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

    if HTMLVariables.HTMLVariables.CHARSETS[enc] != ''
      return HTMLVariables.HTMLVariables.CHARSETS[enc]
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
  #  1 - String: File to find
  #  2 - String: Directories to search, comma separated, last one is
  #              passed on in recursive calls
  # Return Value:
  #  String: The file's contents
  def FindAndRead(inc: string, path: string): list<string>
    var found: list<string> = findfile(inc, path, -1)

    if len(found) <= 0
      printf(this.HTMLMessagesO.E_NOTFOUND, inc)->this.HTMLMessagesO.Warn()
      return []
    endif
           
    return readfile(found[0])->this.TokenReplace(split(path, ':')[-1])
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
  #   Find JSON files in the runtimepath and return them as a Vim array
  #  Arguments:
  #   1 - String: The filename to find and read
  #  Return Value:
  #   List - The JSON data as a Vim array, empty if there was a problem
  def ReadJsonFiles(file: string): list<any>
    var json_files: list<string> = file->findfile(&runtimepath, -1)
    var json_data: list<any> = []

    if json_files->len() == 0
      printf(this.HTMLMessagesO.E_NOTFOUNDRTP, Messages.HTMLMessages.F(), file)->this.HTMLMessagesO.Error()
      return []
    endif

    for f in json_files
      if f->filereadable()
        json_data->extend(f->readfile()->join("\n")->json_decode())
      else
        printf(this.HTMLMessagesO.E_NOREAD, Messages.HTMLMessages.F(), f)->this.HTMLMessagesO.Error()
      endif
    endfor

    return json_data
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
  def TokenReplace(text: list<string>, directory: string = ''): list<string>
    return text->mapnew(
      (_, str) =>
          str->substitute($'\C%\({join(keys(HTMLVariables.HTMLVariables.TEMPLATE_TOKENS), '\|')}\)%',
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
    def CharToEntity(c: string): string
      var char: string

      if c->strchars(1) != 1
        printf(this.HTMLMessagesO.E_ONECHAR, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
        return c
      endif

      char = HTMLVariables.HTMLVariables.DictCharToEntities->get(c, printf('&#x%X;', c->char2nr()))

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

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=5:comments=b\:#:commentstring=\ #\ %s:
