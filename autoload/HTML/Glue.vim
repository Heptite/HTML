vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9011157
  finish
endif

# Glue functions for the HTML macros filetype plugin.
#
# Last Change: March 06, 2025
#
# Requirements:
#       Vim 9.1.1157 or later
#
# Copyright © 1998-2025 Christian J. Robinson <heptite(at)gmail(dot)com>
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
import autoload './Map.vim'
import autoload './Menu.vim'
import autoload './Messages.vim'
import autoload './Util.vim'

export class HTMLGlue extends Util.HTMLUtil

  static var HTMLMapO: Map.HTMLMap
  static var HTMLMenuO: Menu.HTMLMenu
  static var HTMLMessagesO: Messages.HTMLMessages

  def new() # {{{1
    # Even though this is done in the ftplugin file, this file can be imported
    # alone, so do it here as well:
    if !exists('g:htmlplugin')
      g:htmlplugin = {}
    endif
    if !exists('b:htmlplugin')
      b:htmlplugin = {}
    endif

    if HTMLMapO == null_object
      HTMLMapO = Map.HTMLMap.new()
      HTMLMenuO = Menu.HTMLMenu.new()
      HTMLMessagesO = Messages.HTMLMessages.new()
    endif
  enddef # }}}1

  # PluginControl()  {{{1
  #
  # Purpose:
  #  Disable/enable all the mappings defined by
  #  Map().
  # Arguments:
  #  1 - String: Whether to disable or enable the mappings:
  #               d/disable/off:   Clear the mappings
  #               e/enable/on:     Redefine the mappings
  # Return Value:
  #  Boolean: False for an error, true otherwise
  def PluginControl(dowhat: string): bool
    if !this.BoolVar('b:htmlplugin.did_mappings_init')
      HTMLMessagesO.Error(HTMLMessagesO.E_NOSOURCED)
      return false
    endif

    if dowhat =~? '^\%(d\%(isable\)\?\|off\|false\|0\)$'
      if this.BoolVar('b:htmlplugin.did_mappings')
        b:htmlplugin.clear_mappings->mapnew(
          (_, mapping) => {
            silent! execute mapping
            return
          }
        )
        b:htmlplugin.clear_mappings = []
        unlet b:htmlplugin.did_mappings
        unlet b:htmlplugin.did_json

        if this.BoolVar('g:htmlplugin.did_menus')
          HTMLMenuO.MenuControl(Menu.MenuControlA.disable)
        endif
      else
        HTMLMessagesO.Error(HTMLMessagesO.E_DISABLED)
        return false
      endif
    elseif dowhat =~? '^\%(e\%(nable\)\?\|on\|true\|1\)$'
      if this.BoolVar('b:htmlplugin.did_mappings')
        HTMLMessagesO.Error(HTMLMessagesO.E_ENABLED)
      else
        this.ReadEntities(false, true)
        this.ReadTags(false, true)
        if b:htmlplugin->has_key('mappings')
          HTMLMapO.CreateExtraMappings(b:htmlplugin.mappings)
        endif
        b:htmlplugin.did_mappings = true
        HTMLMenuO.MenuControl(Menu.MenuControlA.enable)
      endif
    elseif dowhat =~? '^about$'
      Util.HTMLUtil.About()
    elseif dowhat =~? '^template$'
      if HTMLMapO.Template()
        startinsert
      endif
    else
      printf(HTMLMessagesO.E_INVALIDARG, Messages.HTMLMessages.F(), dowhat)->HTMLMessagesO.Error()
      return false
    endif

    return true
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
  def ReadEntities(domenu: bool = true, internal: bool = false, file: string = Variables.HTMLVariables.ENTITIES_FILE): bool
    var rval = true
    var json_data = this.ReadJsonFiles(file)

    if json_data == []
      printf(HTMLMessagesO.E_NOENTITY)
      return false
    endif

    for json in json_data
      if json->len() != 4 || json[2]->type() != v:t_list
        printf(HTMLMessagesO.E_JSON, Messages.HTMLMessages.F(), file, json->string())->HTMLMessagesO.Error()
        rval = false
        continue
      endif
      if json[3] ==? '<nop>'
        if domenu
          HTMLMenuO.Menu('menu', '-', json[2]->extendnew(['Character &Entities'], 0), '<nop>')
        endif
      else
        if maparg(g:htmlplugin.entity_map_leader .. json[0], 'i') != '' ||
            !HTMLMapO.Map('inoremap', $'<elead>{json[0]}', json[1], {extra: false}, internal)
          # Failed to map? No menu item should be defined either:
          continue
        endif
        if domenu
          HTMLMenuO.EntityMenu(json[2], json[0], json[3])
        endif
      endif
    endfor

    return rval
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
  def ReadTags(domenu: bool = true, internal: bool = false, file: string = Variables.HTMLVariables.TAGS_FILE): bool
    var maplhs: string
    var menulhs: string
    var rval = true
    var json_data = this.ReadJsonFiles(file)

    if json_data == []
      printf(HTMLMessagesO.E_NOTAG)
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
          HTMLMenuO.Menu('menu', json.menu[0], json.menu[1], '<nop>')
          continue
        endif

        if json->has_key('lhs')
          maplhs = $'<lead>{json.lhs}'
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
              && maparg((maplhs == '' ? $'<lead>{json.maps.i[0]}' : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'i') == ''
            if HTMLMapO.Map('inoremap',
                (maplhs == '' ? $'<lead>{json.maps.i[0]}' : maplhs),
                json.maps.i[1],
                len(json.maps.i) >= 3 ? json.maps.i[2] : {},
                internal)
              ++did_mappings
            endif
          endif

          if json.maps->has_key('v')
              && maparg((maplhs == '' ? $'<lead>{json.maps.v[0]}' : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'v') == ''
            if HTMLMapO.Map('vnoremap',
                (maplhs == '' ? $'<lead>{json.maps.v[0]}' : maplhs),
                json.maps.v[1],
                len(json.maps.v) >= 3 ? json.maps.v[2] : {},
                internal)
              ++did_mappings
            endif
          endif

          if json.maps->has_key('n')
              && maparg((maplhs == '' ? $'<lead>{json.maps.n[0]}' : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'n') == ''
            if HTMLMapO.Map('nnoremap',
                (maplhs == '' ? $'<lead>{json.maps.n[0]}' : maplhs),
                json.maps.n[1],
                v:none,
                internal)
              ++did_mappings
            endif
          endif

          if json.maps->has_key('o')
              && maparg((maplhs == '' ? $'<lead>{json.maps.o[0]}' : maplhs)->substitute('^<lead>\c',
                g:htmlplugin.map_leader->escape('&~\'), ''), 'o') == ''
            if HTMLMapO.Map('nnoremap',
                (maplhs == '' ? $'<lead>{json.maps.o[0]}' : maplhs),
                '',
                json.maps.o[1],
                internal)
              ++did_mappings
            endif
          endif

          # If it was indicated that mappings would be defined but none were
          # actually defined, don't set the menu items for this mapping either:
          if did_mappings == 0
            if maplhs != ''
              HTMLMessagesO.Warn($'No mapping(s) were defined for "{maplhs}".'
                .. (domenu && json->has_key('menu') ? '' : ' Skipping menu item.'))
            endif
            continue
          endif
        endif

        if domenu && json->has_key('menu')
          var did_menus = 0

          if json.menu[2]->has_key('i')
            HTMLMenuO.LeadMenu('imenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].i[0] : menulhs),
              json.menu[2].i[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('v')
            HTMLMenuO.LeadMenu('vmenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].v[0] : menulhs),
              json.menu[2].v[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('n')
            HTMLMenuO.LeadMenu('nmenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].n[0] : menulhs),
              json.menu[2].n[1])
            ++did_menus
          endif

          if json.menu[2]->has_key('a')
            HTMLMenuO.LeadMenu(
              'amenu',
              json.menu[0],
              json.menu[1],
              (menulhs == '' ? json.menu[2].a[0] : menulhs),
              json.menu[2].a[1])
            ++did_menus
          endif

          if did_menus == 0
            printf(HTMLMessagesO.W_NOMENU, json.menu[1][-1])->HTMLMessagesO.Warn()
          endif
        endif
    endfor

    return rval
  enddef


  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
