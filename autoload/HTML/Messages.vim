vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010219
  finish
endif

# Messaging functions for the HTML macros filetype plugin.
#
# Last Change: June 01, 2024
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

export class HTMLMessages

  # Error and warning messages:  {{{1
  const E_NOFILE       = 'No file is associated with the current buffer and no URL was specified.'
  const E_NOAPP        = '%s not found.'
  const E_UNKNOWN      = 'Unknown browser ID: %s'
  const E_DISPLAY      = '$DISPLAY is not set and no textmode browsers were found, no browser launched.'
  const E_XTERM        = "XTerm not found, and :terminal is not compiled into this version of GVim. Can't launch %s."
  const E_TERM         = ":terminal is not compiled into this version of GVim. Can't launch %s."
  const E_LAUNCH       = 'Unable to launch %s.'
  const E_COMMAND      = 'Command failed: %s'
  const E_FINAL        = 'Something went wrong, we should never get here...'
  const E_NOMAP        = 'No mapping defined.'
  const E_NOMAPLEAD    = $'%s g:htmlplugin.map_leader is not set! {E_NOMAP}'
  const E_NOEMAPLEAD   = $'%s g:htmlplugin.entity_map_leader is not set! {E_NOMAP}'
  const E_EMPTYLHS     = $'%s must have a non-empty lhs. {E_NOMAP}'
  const E_EMPTYRHS     = $'%s must have a non-empty rhs. {E_NOMAP}'
  const E_NOMODE       = $'%s must have one of the modes explicitly stated. {E_NOMAP}'
  const E_NOFULL       = $'%s must use a full map command. {E_NOMAP}'
  const E_NOLOCALVAR   = 'Cannot set a local variable with %s'
  const E_NARGS        = 'E119: Not enough arguments for %s'
  const E_NOSOURCED    = 'The HTML macros plugin was not sourced for this buffer.'
  const E_DISABLED     = 'The HTML mappings are already disabled.'
  const E_ENABLED      = 'The HTML mappings are already enabled.'
  const E_INVALIDARG   = '%s Invalid argument: %s'
  const E_INVALIDTYPE  = 'Invalid argument type: %s'
  const E_JSON         = '%s Potentially malformed json in %s, section: %s'
  const E_NOTFOUNDRTP  = '%s %s is not found in the runtimepath.'
  const E_NOTFOUND     = 'File "%s" was not found.'
  const E_NOREAD       = '%s %s is not readable.'
  const E_NOTAG        = 'No tag mappings or menus have been defined.'
  const E_NOENTITY     = 'No entity mappings or menus have been defined.'
  const E_ONECHAR      = '%s First argument must be one character.'
  const E_BOOLTYPE     = '%s Unknown type for Bool(): %s'
  const E_NOCLIPBOARD  = '%s Somehow the htmlplugin.save_clipboard global variable did not get set.'
  const E_NOSMART      = '%s Unknown smart tag: %s'
  const E_OPTEXCEPTION = '%s while toggling options.'
  const E_INDENTEXCEPT = '%s while reindenting.'
  const E_MAPEXCEPT    = '%s while executing mapping: %s'
  const E_ZEROROWSCOLS = 'Rows and columns must be positive, non-zero integers.'
  const E_COLOR        = '%s Color "%s" is invalid. Colors must be a six-digit hexadecimal value prefixed by a "#".'
  const E_TEMPLATE     = 'Unable to insert template file: %s Either it doesn''t exist or it isn''t readable.'
  const E_NOIMG        = 'The cursor is not on an IMG tag.'
  const E_NOSRC        = 'Image SRC not specified in the tag.'
  const E_BLANK        = 'No image specified in SRC.'
  const E_NOIMAGE      = 'Can not find image file (or it is not readable): %s'
  const E_UNSUPPORTED  = 'Image type not supported: %s'
  const E_NOIMGREAD    = 'Can not read file: %s'
  const E_GIF          = 'Malformed GIF file.'
  const E_JPG          = 'Malformed JPEG file.'
  const E_PNG          = 'Malformed PNG file.'
  const E_TIFF         = 'Malformed TIFF file.'
  const E_TIFFENDIAN   = $'{E_TIFF} Endian identifier not found.'
  const E_TIFFID       = $'{E_TIFF} Identifier not found.'
  const E_WEBP         = 'Malformed WEBP file.'

  const W_MAPOVERRIDE  = 'WARNING: A mapping of %s for %s mode has been overridden for buffer number %d: %s'
  const W_CAUGHTERR    = 'Caught error "%s", continuing.'
  const W_INVALIDCASE  = '%s Specified case is invalid: %s. Overriding to "lowercase".'
  const W_NOMENU       = 'No menu item was defined for "%s".'
  const W_UNSAVED      = 'Warning: The current buffer has unsaved modifications.'
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
      if exists(':echowindow') == 2 && type !~? '^e'
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
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
