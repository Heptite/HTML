vim9script
scriptencoding utf8

if v:version < 900
  finish
endif

# Various :-commands for the HTML macros filetype plugin.
#
# Last Change: July 17, 2022
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 1998-2022 Christian J. Robinson <heptite(at)gmail(dot)com>
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

if b:htmlplugin->has_key('did_commands') && b:htmlplugin.did_commands == true
  finish
endif

import autoload 'HTML/functions.vim'

command! -buffer -bar -nargs=1 HTMLplugin functions.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLPlugin functions.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLmappings functions.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 HTMLMappings functions.PluginControl(<f-args>)
if exists(':HTML') != 2
  command! -buffer -bar -nargs=1 HTML functions.PluginControl(<f-args>)
endif

command! -buffer -bar -nargs=? ColorChooser functions.ColorChooser(<f-args>)
if exists(':CC') != 2
  command! -buffer -bar -nargs=? CC functions.ColorChooser(<f-args>)
endif

command! -buffer -bar HTMLTemplate if functions.Template() | startinsert | endif
command! -buffer -bar HTMLtemplate HTMLTemplate

b:htmlplugin.did_commands = true


if g:htmlplugin->has_key('did_commands') && g:htmlplugin.did_commands == true
  finish
endif

command! -bar HTMLAbout functions.About()
command! -bar HTMLabout functions.About()

command! -nargs=+ SetIfUnset functions.SetIfUnset(<f-args>)

g:htmlplugin.did_commands = true

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
