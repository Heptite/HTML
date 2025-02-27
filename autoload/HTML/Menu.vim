vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  finish
endif

# Menu functions for the HTML macros filetype plugin.
#
# Last Change: February 27, 2025
#
# Requirements:
#       Vim 9.1.509 or later
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
import autoload './Messages.vim'
import autoload './Util.vim'

export enum MenuControlA # {{{1
    disable,
    enable,
    detect
endenum # }}}1

export class HTMLMenu extends Util.HTMLUtil

  def new() # {{{
    this.HTMLMessagesO = Messages.HTMLMessages.new()
    this.HTMLVariablesO = Variables.HTMLVariables.new()
  enddef # }}}

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
    var namenospace: string
    var nameescaped: string
    var rgb: string
    var rgbpercent: string

    if Variables.HTMLVariables.COLORS_SORT->has_key(c)
      newname = [name]->extendnew(['&Colors', '&' .. Variables.HTMLVariables.COLORS_SORT[c]], 0)
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

    namenospace = (name == '' ? color : name->substitute('\s', '', 'g'))
    rgb = color->this.ToRGB(false)
    rgbpercent = color->this.ToRGB(true)

    if namenospace == color
      execute $'inoremenu {nameescaped}.Insert\ &Hexadecimal {color}'
      execute $'nnoremenu {nameescaped}.Insert\ &Hexadecimal i{color}<esc>'
      execute $'vnoremenu {nameescaped}.Insert\ &Hexadecimal s{color}<esc>'

      execute $'inoremenu {nameescaped}.Insert\ &RGB {rgb}'
      execute $'nnoremenu {nameescaped}.Insert\ &RGB i{rgb}<esc>'
      execute $'vnoremenu {nameescaped}.Insert\ &RGB s{rgb}<esc>'

      execute $'inoremenu {nameescaped}.Insert\ RGB\ &Percent {rgbpercent}'
      execute $'nnoremenu {nameescaped}.Insert\ RGB\ &Percent i{rgbpercent}<esc>'
      execute $'vnoremenu {nameescaped}.Insert\ RGB\ &Percent s{rgbpercent}<esc>'
    else
      execute $'inoremenu {nameescaped}<tab>({color}).Insert\ &Name {namenospace}'
      execute $'nnoremenu {nameescaped}<tab>({color}).Insert\ &Name i{namenospace}<esc>'
      execute $'vnoremenu {nameescaped}<tab>({color}).Insert\ &Name s{namenospace}<esc>'

      execute $'inoremenu {nameescaped}<tab>({color}).Insert\ &Hexadecimal {color}'
      execute $'nnoremenu {nameescaped}<tab>({color}).Insert\ &Hexadecimal i{color}<esc>'
      execute $'vnoremenu {nameescaped}<tab>({color}).Insert\ &Hexadecimal s{color}<esc>'

      execute $'inoremenu {nameescaped}<tab>({color}).Insert\ &RGB {rgb}'
      execute $'nnoremenu {nameescaped}<tab>({color}).Insert\ &RGB i{rgb}<esc>'
      execute $'vnoremenu {nameescaped}<tab>({color}).Insert\ &RGB s{rgb}<esc>'

      execute $'inoremenu {nameescaped}<tab>({color}).Insert\ RGB\ &Percent {rgbpercent}'
      execute $'nnoremenu {nameescaped}<tab>({color}).Insert\ RGB\ &Percent i{rgbpercent}<esc>'
      execute $'vnoremenu {nameescaped}<tab>({color}).Insert\ RGB\ &Percent s{rgbpercent}<esc>'
    endif
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
      # Makes it so UTF8 characters don't have to be hardcoded in JSON files:
      if newsymb =~# '^\\[xuU]\x\+$'
        newsymb = newsymb->substitute('^\\[xuU]', '', '')->str2nr(16)->nr2char(1)
      endif

      newsymb = $'\ ({newsymb->escape(" &<.|")})'
      newsymb = newsymb->substitute('\\&', '\&\&', 'g')
    endif

    execute $'imenu {nameescaped}{newsymb}<tab>{leaderescaped}{itemescaped} {g:htmlplugin.entity_map_leader}{item}'
    execute $'nmenu {nameescaped}{newsymb}<tab>{leaderescaped}{itemescaped} i{g:htmlplugin.entity_map_leader}{item}<esc>'
    execute $'vmenu {nameescaped}{newsymb}<tab>{leaderescaped}{itemescaped} s{g:htmlplugin.entity_map_leader}{item}<esc>'
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

    execute $'{type} {newlevel} {nameescaped}<tab>{leaderescaped}{item} {pre}{g:htmlplugin.map_leader}{item}'
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

    execute $'{type} {newlevel} {nameescaped} {item}'
  enddef

  # MenuControl()  {{{1
  #
  # Purpose:
  #  Disable/enable the HTML menu and toolbar.
  # Arguments:
  #  1 - String: Optional, Whether to disable or enable the menus:
  #                empty/"detect": Detect which to do
  #                "disable": Disable the menu and toolbar
  #                "enable": Enable the menu and toolbar
  # Return Value:
  #  Boolean: False if an error occurred, true otherwise
  def MenuControl(which: MenuControlA = MenuControlA.detect): bool
    if which == MenuControlA.disable || !this.BoolVar('b:htmlplugin.did_mappings')
      execute $'amenu disable {g:htmlplugin.toplevel_menu_escaped}'
      execute $'amenu disable {g:htmlplugin.toplevel_menu_escaped}.*'
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
        execute $'amenu enable {g:htmlplugin.toplevel_menu_escaped}'
        execute $'amenu enable {g:htmlplugin.toplevel_menu_escaped}.Enable\ Mappings'
      endif
    elseif which == MenuControlA.enable || this.BoolVar('b:htmlplugin.did_mappings_init')
      execute $'amenu enable {g:htmlplugin.toplevel_menu_escaped}'
      if this.BoolVar('b:htmlplugin.did_mappings')
        execute $'amenu enable {g:htmlplugin.toplevel_menu_escaped}.*'
        execute $'amenu disable {g:htmlplugin.toplevel_menu_escaped}.Enable\ Mappings'
        if this.BoolVar('g:htmlplugin.did_toolbar')
          amenu enable ToolBar.*
        endif
      else
        execute $'amenu enable {g:htmlplugin.toplevel_menu_escaped}.Enable\ Mappings'
      endif
    endif

    return true
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

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
