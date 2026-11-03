vim9script
scriptencoding utf8

if v:versionlong < 9021240
  finish
endif

# Messaging functions for the HTML macros filetype plugin.
#
# Last Change: November 02, 2026
#
# Requirements:
#       Vim 9.2 or later
#
# Copyright © 1998-2026 Christian J. Robinson <heptite+html(at)proton(dot)me>
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
  public static const E_NOMAP        = gettext("No mapping defined.", 'CJRHTML')

  public static const E_BLANK        = gettext("No image specified in SRC.", 'CJRHTML')
  public static const E_BOOLTYPE     = gettext("%s Unknown type for Bool(): %s", 'CJRHTML')
  public static const E_COLOR        = gettext("%s Color \"%s\" is invalid. Colors must be a six-digit hexadecimal value prefixed by a \"#\".", 'CJRHTML')
  public static const E_COMMAND      = gettext("Command failed: %s", 'CJRHTML')
  public static const E_DISABLED     = gettext("The HTML mappings are already disabled.", 'CJRHTML')
  public static const E_DISPLAY      = gettext("$DISPLAY is not set and no textmode browsers were found, no browser launched.", 'CJRHTML')
  public static const E_EMPTYLHS     = gettext($"%s must have a non-empty lhs. {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_EMPTYRHS     = gettext($"%s must have a non-empty rhs. {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_ENABLED      = gettext("The HTML mappings are already enabled.", 'CJRHTML')
  public static const E_FINAL        = gettext("Something went wrong, we should never get here...", 'CJRHTML')
  public static const E_GIF          = gettext("Malformed GIF file.", 'CJRHTML')
  public static const E_INDENTEXCEPT = gettext("%s while reindenting.", 'CJRHTML')
  public static const E_INVALIDARG   = gettext("%s Invalid argument: %s", 'CJRHTML')
  public static const E_INVALIDTYPE  = gettext("Invalid argument type: %s", 'CJRHTML')
  public static const E_JPG          = gettext("Malformed JPEG file.", 'CJRHTML')
  public static const E_JSON         = gettext("%s Potentially malformed json in %s, section: %s", 'CJRHTML')
  public static const E_LAUNCH       = gettext("Unable to launch %s.", 'CJRHTML')
  public static const E_MAPEXCEPT    = gettext("%s while executing mapping: %s", 'CJRHTML')
  public static const E_NARGS        = gettext("E119: Not enough arguments for %s", 'CJRHTML')
  public static const E_NOAPP        = gettext("%s not found.", 'CJRHTML')
  public static const E_NOCLIPBOARD  = gettext("%s Somehow the htmlplugin.save_clipboard global variable did not get set.", 'CJRHTML')
  public static const E_NOCOMMAND: string    = gettext("No command found.", 'CJRHTML')
  public static const E_NOEMAPLEAD   = gettext($"%s g:htmlplugin.entity_map_leader is not set! {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_NOENTITY     = gettext("No entity mappings or menus have been defined.", 'CJRHTML')
  public static const E_NOFILE       = gettext("No file is associated with the current buffer and no URL was specified.", 'CJRHTML')
  public static const E_NOFULL       = gettext($"%s must use a full map command. {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_NOIMAGE      = gettext("Can not find image file (or it is not readable): %s", 'CJRHTML')
  public static const E_NOIMG        = gettext("The cursor is not on an IMG tag.", 'CJRHTML')
  public static const E_NOIMGREAD    = gettext("Can not read file: %s", 'CJRHTML')
  public static const E_NOLOCALVAR   = gettext("Cannot set a local variable with %s", 'CJRHTML')
  public static const E_NOMAPLEAD    = gettext($"%s g:htmlplugin.map_leader is not set! {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_NOMODE       = gettext($"%s must have one of the modes explicitly stated. {HTMLMessages.E_NOMAP}", 'CJRHTML')
  public static const E_NOREAD       = gettext("%s %s is not readable.", 'CJRHTML')
  public static const E_NOSMART      = gettext("%s Unknown smart tag: %s", 'CJRHTML')
  public static const E_NOSOURCED    = gettext("The HTML macros plugin was not sourced for this buffer.", 'CJRHTML')
  public static const E_NOSRC        = gettext("Image SRC not specified in the tag.", 'CJRHTML')
  public static const E_NOTAG        = gettext("No tag mappings or menus have been defined.", 'CJRHTML')
  public static const E_NOTFOUND     = gettext("File \"%s\" was not found.", 'CJRHTML')
  public static const E_NOTFOUNDRTP  = gettext("%s %s is not found in the runtimepath.", 'CJRHTML')
  public static const E_ONECHAR      = gettext("%s First argument must be one character.", 'CJRHTML')
  public static const E_OPTEXCEPTION = gettext("%s while toggling options.", 'CJRHTML')
  public static const E_PNG          = gettext("Malformed PNG file.", 'CJRHTML')
  public static const E_TEMPLATE     = gettext("Unable to insert template file: %s Either it doesn't exist or it isn't readable.", 'CJRHTML')
  public static const E_TERM         = gettext(":terminal is not compiled into this version of GVim. Can't launch %s.", 'CJRHTML')
  public static const E_TIFF         = gettext("Malformed TIFF file.", 'CJRHTML')
  public static const E_TIFFENDIAN   = gettext($"{HTMLMessages.E_TIFF} Endian identifier not found.", 'CJRHTML')
  public static const E_TIFFID       = gettext($"{HTMLMessages.E_TIFF} Identifier not found.", 'CJRHTML')
  public static const E_UNKNOWN      = gettext("Unknown browser ID: %s", 'CJRHTML')
  public static const E_UNSUPPORTED  = gettext("Image type not supported: %s", 'CJRHTML')
  public static const E_WEBP         = gettext("Malformed WEBP file.", 'CJRHTML')
  public static const E_XTERM        = gettext("XTerm not found, and :terminal is not compiled into this version of GVim. Can't launch %s.", 'CJRHTML')
  public static const E_ZEROROWSCOLS = gettext("Rows and columns must be positive, non-zero integers.", 'CJRHTML')

  public static const W_MAPOVERRIDE  = gettext("WARNING: A mapping of %s for %s mode has been overridden for buffer %d: %s", 'CJRHTML')
  public static const W_CAUGHTERR    = gettext("Caught error \"%s\", continuing.", 'CJRHTML')
  public static const W_INVALIDCASE  = gettext("%s Specified case is invalid: %s. Overriding to \"lowercase\".", 'CJRHTML')
  public static const W_NOMENU       = gettext("No menu item was defined for \"%s\".", 'CJRHTML')
  public static const W_UNSAVED      = gettext("Warning: The current buffer has unsaved modifications.", 'CJRHTML')
  public static const W_NOMAPDEFINED = gettext('No mapping(s) were defined for "%s".%s', 'CJRHTML')
  public static const W_NOMAPLHS     = gettext('Found a mapping with no lhs in file "%s", skipping.', 'CJRHTML')
  public static const W_SKIPPEDMENU  = gettext(' Skipping menu item.', 'CJRHTML')
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
      #echoerr printf(E_INVALIDTYPE, typename(message))
      #return
      throw printf(E_INVALIDTYPE, typename(message))
    endif

    for s: string in m
      if type !~? '^e'
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
