vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010219
  finish
endif

# Mapping functions for the HTML macros filetype plugin.
#
# Last Change: June 09, 2024
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
import autoload 'HTML/Messages.vim'
import autoload 'HTML/Util.vim'

export enum MapCheckR # {{{1
  notfound,
  override,
  nooverride,
  suppressed
endenum

# }}}1

export class HTMLMap extends Util.HTMLUtil
  
  var _mode: string
  var _lhs: string
  var _rhs: string
  var _options: dict<any>

  def new() # {{{1
    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = HTMLVariables.HTMLVariables.new()
  enddef

  def newMap(this._mode, this._lhs, this._rhs, this._options) # {{{1
    if strlen(this._mode) != 1 && this._mode !~# '^[iv]$'
      echoerr $'Mode is invalid: {this._mode}'
    endif

    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = HTMLVariables.HTMLVariables.new()
  enddef

  def newOpMap(this._lhs, this._options) # {{{1
    this._mode = 'n'
    this._rhs = this._lhs

    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = HTMLVariables.HTMLVariables.new()
  enddef # }}}1

  # CreateExtraMappings()  {{{1
  #
  # Purpose:
  #  Define mappings that are stored in a list, as opposed to stored in a JSON
  #  file.
  # Arguments:
  #  1 - List of strings: The mappings to define.
  # Return Value:
  #  Boolean: Whether there were mappings to define.
  def CreateExtraMappings(mappings: list<list<any>>): bool
    if len(mappings) == 0
      return false
    endif
    mappings->mapnew((_, mapping) => mapset(mapping[1], false, mapping[0]))
    return true
  enddef

  # DoMap()  {{{1
  #
  # Purpose:
  #  Execute or return the "right hand side" of a mapping, while preventing an
  #  error to cause it to abort.
  # Arguments:
  #  None, as DoMap() should be invoked via a mapping object that contains the
  #  information needed.
  # Return Value:
  #  String: Either an empty string (for visual mappings) or the key sequence
  #           to run (for insert mode mappings). This oddity is because the
  #           two modes need to be handled differently.
  #def DoMap(mode: string, map: string): string
  def DoMap(): string
    var evalstr: string

    var mode = this._mode
    var lhs = this._lhs
    var rhs = this._rhs
       ->substitute('\c\\<[a-z0-9_-]\+>', '\=eval(''"'' .. submatch(0) .. ''"'')', 'g')
       ->this.ConvertCase()
    var opts = this._options

    if opts->get('expr', false)
      evalstr = eval(rhs)
    else
      evalstr = rhs
    endif

    if mode->strlen() != 1
      printf(this.HTMLMessagesO.E_ONECHAR, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return ''
    endif

    if mode ==# 'n' && lhs ==# rhs
      b:htmlplugin.operator_action = rhs->escape('&~\')
      b:htmlplugin.operator_insert = opts.insert
      &operatorfunc = 'function(b:htmlplugin.HTMLMapO.OpWrap)'
      return 'g@'
    elseif mode ==# 'i' || mode ==# 'n'
      return evalstr
    elseif mode ==# 'v'
      this.ToggleOptions(false)

      try
        execute $'silent normal! {evalstr}'
      catch
        printf(this.HTMLMessagesO.E_MAPEXCEPT, v:exception, lhs)->this.HTMLMessagesO.Error()
      endtry

      this.ToggleOptions(true)

      if opts->has_key('reindent') && opts.reindent >= 0
        #normal! m'
        var curpos = getcharpos('.')[1 : -1]
        #keepjumps ReIndent(line('v'), line('.'), opts.reindent)
        keepjumps this.ReIndent(line("'<"), line("'>"), opts.reindent)
        #normal! ``
        setcharpos('.', curpos)
      endif

      if opts->get('insert', false)
        execute "normal! \<c-\>\<c-n>l"
        startinsert
      endif
    else
      printf(this.HTMLMessagesO.E_INVALIDARG, Messages.HTMLMessages.F(), mode)->this.HTMLMessagesO.Error()
    endif

    return ''
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
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_ZEROROWSCOLS)
      return false
    endif

    if border < 0
      newborder = inputdialog('Border width of table [none]: ', '', '0')->str2nr()
    else
      newborder = border
    endif

    if rows < 0 && columns < 0 && border < 0
      newthead = 'Insert a table header?'->confirm("&Yes\n&No", 2, 'Question') == 1
      newtfoot = 'Insert a table footer?'->confirm("&Yes\n&No", 2, 'Question') == 1
    endif

    if newborder > 0
      lines->add($'<[{{TABLE STYLE}}]="border: solid {g:htmlplugin.textcolor} {newborder}px; padding: 3px;">')
    else
      lines->add('<[{TABLE}]>')
    endif

    if newthead
      lines->add('<[{THEAD}]>')
      lines->add('<[{TR}]>')
      for c in newcolumns->range()
        if newborder > 0
          lines->add($'<[{{TH STYLE}}]="border: solid {g:htmlplugin.textcolor} {newborder}px; padding: 3px;"></[{{TH}}]>')
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
          lines->add($'<[{{TD STYLE}}]="border: solid {g:htmlplugin.textcolor} {newborder}px; padding: 3px;"></[{{TD}}]>')
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
          lines->add($'<[{{TD STYLE}}]="border: solid {g:htmlplugin.textcolor} {newborder}px; padding: 3px;"></[{{TD}}]>')
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

    execute $':{(line('.') + 1)},{(line('.') + lines->len())}normal! =='

    setcharpos('.', charpos)

    if getline('.') =~ '^\s*$'
      delete
    endif

    this.NextInsertPoint()

    return true
  enddef

  # Map()  {{{1
  #
  # Purpose:
  #  Create a wrapper for a mapping.
  # Arguments:
  #  1 - String: Which map command to run.
  #  2 - String: LHS of the map.
  #  3 - String: RHS of the map--empty if it's a normal map designed to
  #                trigger a visual mapping via a motion/operator.
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
      printf(this.HTMLMessagesO.E_NOMAPLEAD, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif

    if !g:htmlplugin->has_key('entity_map_leader') && map =~? '^<elead>'
      printf(this.HTMLMessagesO.E_NOEMAPLEAD, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif

    if map == '' || map ==? '<lead>' || map ==? '<elead>'
      printf(this.HTMLMessagesO.E_EMPTYLHS, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif

    if arg == '' && map =~# '^\(nmap\|nnoremap\)$'
      printf(this.HTMLMessagesO.E_EMPTYRHS, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif
    
    if cmd->strlen() <= 2
      printf(this.HTMLMessagesO.E_NOFULL, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif

    if cmd =~# '^no' || cmd =~# '^map$'
      printf(this.HTMLMessagesO.E_NOMODE, Messages.HTMLMessages.F())->this.HTMLMessagesO.Error()
      return false
    endif

    if !b:htmlplugin->has_key('maps')
      b:htmlplugin.maps = {'n': {}, 'v': {}, 'i': {}}
    endif

    var mode = cmd->strpart(0, 1)
    var newarg = arg
    var newmap = map->substitute('^<lead>\c', g:htmlplugin.map_leader->escape('&~\'), '')
      ->substitute('^<elead>\c', g:htmlplugin.entity_map_leader->escape('&~\'), '')
    var newmap_escaped = newmap->substitute('<', '<lt>', 'g')->escape('"')

    var mapchecked: MapCheckR = newmap->this.MapCheck(mode, internal)
    if HTMLVariables.HTMLVariables.MODES->has_key(mode) &&
        (mapchecked == MapCheckR.nooverride || mapchecked == MapCheckR.suppressed)
      # MapCheck() will echo the necessary message, so just return here
      return false
    endif

    if ! this.BoolVar('b:htmlplugin.do_xhtml_mappings')
      newarg = newarg->substitute(' \?/>', '>', 'g')
    endif


    var tmpmode: string = ''
    var tmplhs: string = ''
    var tmprhs: string = ''
    var tmpopts: dict<any> = {}

    if mode ==# 'n' && newarg == ''
      tmpmode = 'n'
      tmplhs = newmap
      tmprhs = newmap
      tmpopts = opts
      execute $'{cmd} <buffer> <silent> <expr> {newmap} b:htmlplugin.maps.n["{newmap_escaped}"].DoMap()'
    elseif mode ==# 'v'
      # If 'selection' is "exclusive" all the visual mode mappings need to
      # behave slightly differently:
      newarg = newarg->substitute('`>a\C', '`>i\\<C-R>='
        .. 'b:htmlplugin.HTMLMapO.VisualInsertPos()\\<CR>', 'g')

      if !opts->has_key('extra') || opts.extra
        tmpmode = 'v'
        tmplhs = newmap
        tmprhs = newarg

        if opts->has_key('expr')
          tmpopts.expr = opts.expr
        endif
      endif

      if opts->has_key('extra') && ! opts.extra
        execute $'{cmd} <buffer> <silent> {newmap} {newarg}'
      else
        execute $'{cmd} <buffer> <silent> {newmap} <ScriptCmd>b:htmlplugin.maps.v["{newmap_escaped}"].DoMap()<CR>'

        if opts->get('insert', false) && opts->has_key('reindent')
          tmpopts.reindent = opts.reindent
          tmpopts.insert = opts.insert
        elseif opts->get('insert', false)
          tmpopts.insert = opts.insert
        elseif opts->has_key('reindent')
          tmpopts.reindent = opts.reindent
        endif
      endif
    elseif mode ==# 'i'
      if opts->has_key('extra') && ! opts.extra
        execute $'{cmd} <buffer> <silent> {newmap} {newarg}'
      else
        tmpmode = 'i'
        tmplhs = newmap
        tmprhs = newarg
        if opts->has_key('expr')
          tmpopts.expr = opts.expr
        endif
        execute $'{cmd} <buffer> <silent> <expr> {newmap} b:htmlplugin.maps.i["{newmap_escaped}"].DoMap()'
      endif
    else
      execute $'{cmd} <buffer> <silent> {newmap} {newarg}'
    endif

    if HTMLVariables.HTMLVariables.MODES->has_key(mode)
      b:htmlplugin.clear_mappings->add($':{mode}unmap <buffer> {newmap}')
    else
      b:htmlplugin.clear_mappings->add($':unmap <buffer> {newmap}')
      b:htmlplugin.clear_mappings->add($':unmap! <buffer> {newmap}')
    endif

    if tmpmode != '' && tmplhs != '' && tmprhs != ''
      b:htmlplugin.maps[tmpmode][tmplhs] =
        HTMLMap.newMap(tmpmode, tmplhs, tmprhs, tmpopts)
    endif

    # Save extra (non-plugin) mappings so they can be restored if we need to later:
    newmap->maparg(mode, false, true)->this.MappingsListAdd(mode, internal)

    return true
  enddef

  # MapCheck()  {{{1
  #
  # Purpose:
  #  Check to see if a mapping for a mode already exists, or if a specific
  #  mapping has been suppressed.  Errors and warnings are issued depending on
  #  whether overriding is enabled or not.
  # Arguments:
  #  1 - String:    The map sequence (LHS).
  #  2 - Character: The mode for the mapping.
  #  3 - Boolean:   Whether an "internal" map is being defined
  # Return Value:
  #  MapCheckR.notfound   - No mapping was found.
  #  MapCheckR.override   - A mapping was found, but overriding has /not/ been
  #                         suppressed.
  #  MapCheckR.nooverride - A mapping was found and overriding has been suppressed.
  #  MapCheckR.suppressed - The mapping to be defined was suppressed by
  #                         g:htmlplugin.no_maps or b:htmlplugin.no_maps.
  def MapCheck(map: string, mode: string, internal: bool = false): MapCheckR
    if internal &&
          ( (g:htmlplugin->has_key('no_maps')
              && g:htmlplugin.no_maps->match($'^\C\V{map}\$') >= 0) ||
            (b:htmlplugin->has_key('no_maps')
              && b:htmlplugin.no_maps->match($'^\C\V{map}\$') >= 0) )
      return MapCheckR.suppressed
    elseif HTMLVariables.HTMLVariables.MODES->has_key(mode) && map->maparg(mode) != ''
      if this.BoolVar('g:htmlplugin.no_map_override') && internal
        return MapCheckR.nooverride
      else
        printf(this.HTMLMessagesO.W_MAPOVERRIDE, map, HTMLVariables.HTMLVariables.MODES[mode], bufnr('%'), expand('%'))->this.HTMLMessagesO.Warn()
        return MapCheckR.override
      endif
    endif

    return MapCheckR.notfound
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

  # OpWrap()  {{{1
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
  def OpWrap(type: string)
    this.HTMLVariablesO.saveopts.selection = &selection
    &selection = 'inclusive'

    try
      # Do not use ":normal!" here because we _want_ mappings to be triggered:
      if type == 'line'
        execute $'normal `[V`]{b:htmlplugin.operator_action}'
      elseif type == 'block'
        execute $"normal `[\<C-V>`]{b:htmlplugin.operator_action}"
      else
        execute $'normal `[v`]{b:htmlplugin.operator_action}'
      endif
    catch
      printf(this.HTMLMessagesO.W_CAUGHTERR, v:exception)->this.HTMLMessagesO.Warn()
    finally
      &selection = this.HTMLVariablesO.saveopts.selection
    endtry

    if b:htmlplugin.operator_insert
      execute "normal! \<c-\>\<c-n>l"
      startinsert
    endif
  enddef

  # ReIndent()  {{{1
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

    def GetFiletypeInfo(): dict<string>  # {{{2
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
    enddef  # }}}2

    var firstline: number
    var lastline: number

    if !(this.Bool(GetFiletypeInfo()['indent'])) && &indentexpr == ''
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

    var range = firstline == lastline ? firstline : $'{firstline},{lastline}'
    var charpos = getcharpos('.')

    try
      execute $'keepjumps :{range}normal! =='
    catch
      printf(this.HTMLMessagesO.E_INDENTEXCEPT, v:exception)->this.HTMLMessagesO.Error()
    finally
      setcharpos('.', charpos)
    endtry

    return true
  enddef

  # SmartTag()  {{{1
  #
  # Purpose:
  #  Causes certain tags (such as bold, italic, underline) to be closed then
  #  opened rather than opened then closed where appropriate.
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
      printf(this.HTMLMessagesO.E_NOSMART, Messages.HTMLMessages.F(), newtag)->this.HTMLMessagesO.Error()
      return ''
    endif

    if newtag == 'comment'
      [line, column] = searchpairpos('<!--', '', '-->', 'ncW')
    else
      var realtag = tag->substitute('\d\+$', '', '')
      [line, column] = searchpairpos($'\c<{realtag}\>[^>]*>', '', $'\c<\/{realtag}>', 'ncW')
    endif

    which = (line == 0 && column == 0 ? 'o' : 'c')

    ret = b:htmlplugin.smarttags[newtag][newmode][which]->this.ConvertCase()

    if newmode ==# 'v'
      # If 'selection' is "exclusive" all the visual mode mappings need to
      # behave slightly differently:
      ret = ret->substitute('`>a\C', $'`>i{this.VisualInsertPos()}', 'g')
    endif

    return ret
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
    var ret = false

    if line('$') == 1 && getline(1) == ''
      ret = this.TemplateInsert(file)
    else
      var YesNoOverwrite = "Non-empty file.\nInsert template anyway?"->confirm("&Yes\n&No\n&Overwrite", 2, 'Question')
      if YesNoOverwrite == 1
        ret = this.TemplateInsert(file)
      elseif YesNoOverwrite == 3
        execute ':%delete'
        ret = this.TemplateInsert(file)
      endif
    endif

    return ret
  enddef

  # TemplateInsert()  {{{1
  #
  # Purpose:
  #  Actually insert the HTML template.
  # Arguments:
  #  1 - String (optional): The file being processed, defaults to the
  #                         configured files.
  # Return Value:
  #  Boolean - Whether the cursor is not on an insert point.
  def TemplateInsert(f: string = ''): bool
    if g:htmlplugin.author_email != ''
      g:htmlplugin.author_email_encoded = g:htmlplugin.author_email->this.TranscodeString()
    else
      g:htmlplugin.author_email_encoded = ''
    endif
    if b:htmlplugin.author_email != ''
      b:htmlplugin.author_email_encoded = b:htmlplugin.author_email->this.TranscodeString()
    else
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
        printf(this.HTMLMessagesO.E_TEMPLATE, template)->this.HTMLMessagesO.Error()
        return false
      endif
    else
      b:htmlplugin.internal_template->this.TokenReplace()->append(0)
    endif

    # Special case, can't be done in TokenReplace():
    silent! :%s/%newline%/\r/g

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

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
