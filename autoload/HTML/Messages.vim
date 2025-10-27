vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9011157
  finish
endif

# Messaging functions for the HTML macros filetype plugin.
#
# Last Change: October 27, 2025
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



# Must be done outside of any class:
bindtextdomain('CJRHTML', fnamemodify(expand('<script>'), ':p:h') .. '../../lang/')

export class HTMLMessages

  # Error and warning messages:  {{{1

  # Must be defined early for use in other errors:
  const E_NOMAP        = gettext("No mapping defined.", 'CJRHTML')

  const E_BLANK        = gettext("No image specified in SRC.", 'CJRHTML')
  const E_BOOLTYPE     = gettext("%s Unknown type for Bool(): %s", 'CJRHTML')
  const E_COLOR        = gettext("%s Color \"%s\" is invalid. Colors must be a six-digit hexadecimal value prefixed by a \"#\".", 'CJRHTML')
  const E_COMMAND      = gettext("Command failed: %s", 'CJRHTML')
  const E_DISABLED     = gettext("The HTML mappings are already disabled.", 'CJRHTML')
  const E_DISPLAY      = gettext("$DISPLAY is not set and no textmode browsers were found, no browser launched.", 'CJRHTML')
  const E_EMPTYLHS     = gettext($"%s must have a non-empty lhs. {E_NOMAP}", 'CJRHTML')
  const E_EMPTYRHS     = gettext($"%s must have a non-empty rhs. {E_NOMAP}", 'CJRHTML')
  const E_ENABLED      = gettext("The HTML mappings are already enabled.", 'CJRHTML')
  const E_FINAL        = gettext("Something went wrong, we should never get here...", 'CJRHTML')
  const E_GIF          = gettext("Malformed GIF file.", 'CJRHTML')
  const E_INDENTEXCEPT = gettext("%s while reindenting.", 'CJRHTML')
  const E_INVALIDARG   = gettext("%s Invalid argument: %s", 'CJRHTML')
  const E_INVALIDTYPE  = gettext("Invalid argument type: %s", 'CJRHTML')
  const E_JPG          = gettext("Malformed JPEG file.", 'CJRHTML')
  const E_JSON         = gettext("%s Potentially malformed json in %s, section: %s", 'CJRHTML')
  const E_LAUNCH       = gettext("Unable to launch %s.", 'CJRHTML')
  const E_MAPEXCEPT    = gettext("%s while executing mapping: %s", 'CJRHTML')
  const E_NARGS        = gettext("E119: Not enough arguments for %s", 'CJRHTML')
  const E_NOAPP        = gettext("%s not found.", 'CJRHTML')
  const E_NOCLIPBOARD  = gettext("%s Somehow the htmlplugin.save_clipboard global variable did not get set.", 'CJRHTML')
  const E_NOEMAPLEAD   = gettext($"%s g:htmlplugin.entity_map_leader is not set! {E_NOMAP}", 'CJRHTML')
  const E_NOENTITY     = gettext("No entity mappings or menus have been defined.", 'CJRHTML')
  const E_NOFILE       = gettext("No file is associated with the current buffer and no URL was specified.", 'CJRHTML')
  const E_NOFULL       = gettext($"%s must use a full map command. {E_NOMAP}", 'CJRHTML')
  const E_NOIMAGE      = gettext("Can not find image file (or it is not readable): %s", 'CJRHTML')
  const E_NOIMG        = gettext("The cursor is not on an IMG tag.", 'CJRHTML')
  const E_NOIMGREAD    = gettext("Can not read file: %s", 'CJRHTML')
  const E_NOLOCALVAR   = gettext("Cannot set a local variable with %s", 'CJRHTML')
  const E_NOMAPLEAD    = gettext($"%s g:htmlplugin.map_leader is not set! {E_NOMAP}", 'CJRHTML')
  const E_NOMODE       = gettext($"%s must have one of the modes explicitly stated. {E_NOMAP}", 'CJRHTML')
  const E_NOREAD       = gettext("%s %s is not readable.", 'CJRHTML')
  const E_NOSMART      = gettext("%s Unknown smart tag: %s", 'CJRHTML')
  const E_NOSOURCED    = gettext("The HTML macros plugin was not sourced for this buffer.", 'CJRHTML')
  const E_NOSRC        = gettext("Image SRC not specified in the tag.", 'CJRHTML')
  const E_NOTAG        = gettext("No tag mappings or menus have been defined.", 'CJRHTML')
  const E_NOTFOUND     = gettext("File \"%s\" was not found.", 'CJRHTML')
  const E_NOTFOUNDRTP  = gettext("%s %s is not found in the runtimepath.", 'CJRHTML')
  const E_ONECHAR      = gettext("%s First argument must be one character.", 'CJRHTML')
  const E_OPTEXCEPTION = gettext("%s while toggling options.", 'CJRHTML')
  const E_PNG          = gettext("Malformed PNG file.", 'CJRHTML')
  const E_TEMPLATE     = gettext("Unable to insert template file: %s Either it doesn't exist or it isn't readable.", 'CJRHTML')
  const E_TERM         = gettext(":terminal is not compiled into this version of GVim. Can't launch %s.", 'CJRHTML')
  const E_TIFF         = gettext("Malformed TIFF file.", 'CJRHTML')
  const E_TIFFENDIAN   = gettext($"{E_TIFF} Endian identifier not found.", 'CJRHTML')
  const E_TIFFID       = gettext($"{E_TIFF} Identifier not found.", 'CJRHTML')
  const E_UNKNOWN      = gettext("Unknown browser ID: %s", 'CJRHTML')
  const E_UNSUPPORTED  = gettext("Image type not supported: %s", 'CJRHTML')
  const E_WEBP         = gettext("Malformed WEBP file.", 'CJRHTML')
  const E_XTERM        = gettext("XTerm not found, and :terminal is not compiled into this version of GVim. Can't launch %s.", 'CJRHTML')
  const E_ZEROROWSCOLS = gettext("Rows and columns must be positive, non-zero integers.", 'CJRHTML')

  const W_MAPOVERRIDE  = gettext("WARNING: A mapping of %s for %s mode has been overridden for buffer number %d: %s", 'CJRHTML')
  const W_CAUGHTERR    = gettext("Caught error \"%s\", continuing.", 'CJRHTML')
  const W_INVALIDCASE  = gettext("%s Specified case is invalid: %s. Overriding to \"lowercase\".", 'CJRHTML')
  const W_NOMENU       = gettext("No menu item was defined for \"%s\".", 'CJRHTML')
  const W_UNSAVED      = gettext("Warning: The current buffer has unsaved modifications.", 'CJRHTML')
  const W_NOMAPDEFINED = gettext('No mapping(s) were defined for "%s".%s', 'CJRHTML')
  const W_SKIPPEDMENU  = gettext(' Skipping menu item.', 'CJRHTML')
  # }}}1

  def Warn(message: any): void  # {{{1
    echohl WarningMsg
    this._DoEcho(message, 'w')
    echohl None
  enddef

  def Message(message: any): void  # {{{1
    echohl Todo
    this._DoEcho(message, 'm')
    echohl None
  enddef

  def Error(message: any): void  # {{{1
    echohl ErrorMsg
    this._DoEcho(message, 'e')
    echohl None
  enddef

  def _DoEcho(message: any, type: string): void # {{{1
    var m: list<string>
    if type(message) == v:t_string
      m = [message]
    elseif typename(message) == 'list<string>'
      m = message
    else
      echoerr printf(this.E_INVALIDTYPE, typename(message))
      return
    endif

    for s in m
      if exists_compiled(':echowindow') == 2 && type !~? '^e'
        echowindow s
      else
        echomsg s
      endif
    endfor
  enddef

  static def F(): string # {{{1
    return split(expand('<stack>'), '\.\.')[-2]->substitute('\[\d\+\]$', '', '')
  enddef

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
