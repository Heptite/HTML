vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  finish
endif

# Various :-commands for the HTML macros filetype plugin.
#
# Last Change: May 14, 2024
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

if get(b:htmlplugin, 'did_commands', false) == true # {{{
  finish
endif


import autoload 'HTML/Util.vim'
import autoload 'HTML/Map.vim'
import autoload 'HTML/Glue.vim'

var HTMLUtilO = Util.HTMLUtil.new()
var HTMLMapO = Map.HTMLMap.new()
var HTMLGlueO = Glue.HTMLGlue.new()

command! -buffer -bar -nargs=1 HTMLplugin HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLPlugin HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLmappings HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLMappings HTMLGlueO.PluginControl(<f-args>)
if exists(':HTML') != 2
  command! -buffer -bar -nargs=1 HTML HTMLGlueO.PluginControl(<f-args>)
endif

command! -buffer -bar -nargs=? ColorChooser HTMLUtilO.ColorChooser(<f-args>)
if exists(':CC') != 2
  command! -buffer -bar -nargs=? CC HTMLUtilO.ColorChooser(<f-args>)
endif

command! -buffer -bar HTMLTemplate if HTMLMapO.Template() | startinsert | endif
command! -buffer -bar HTMLtemplate HTMLTemplate

b:htmlplugin.did_commands = true

# }}}

if get(g:htmlplugin, 'did_commands', false) == true # {{{
  finish
endif

command! -bar HTMLAbout Util.HTMLUtil.About()
command! -bar HTMLabout Util.HTMLUtil.About()

g:htmlplugin.did_commands = true

# }}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
