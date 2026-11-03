vim9script noclear
scriptencoding utf8

if v:versionlong < 9021240
  finish
endif

# Various :-commands for the HTML macros filetype plugin.                 {{{1
#
# Last Change: November 03, 2026
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
# https://www.gnu.org/licenses/licenses.html#GPL                          }}}1

if get(b:htmlplugin, 'did_commands', false) # {{{1
  finish
endif

import autoload '../../autoload/HTML/Glue.vim'

var HTMLGlueO: Glue.HTMLGlue = Glue.HTMLGlue.new()

def HTMLpluginComplete(A: string, C: string, P: number): list<string>
  return [
    'disable', 'off',   'false',    'enable',     'on',
    'true',    'about', 'template', 'browserlog', 'colorchooser'
  ]->filter((idx, val) => val =~? $'^{A}')
enddef

command! -buffer -bar -nargs=1 -complete=customlist,HTMLpluginComplete
      \ HTMLplugin HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 -complete=customlist,HTMLpluginComplete
      \ HTMLPlugin HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 -complete=customlist,HTMLpluginComplete
      \ HTMLmappings HTMLGlueO.PluginControl(<f-args>)
command! -buffer -bar -nargs=1 -complete=customlist,HTMLpluginComplete
      \ HTMLMappings HTMLGlueO.PluginControl(<f-args>)
if exists(':HTML') != 2
  command! -buffer -bar -nargs=1 -complete=customlist,HTMLpluginComplete
        \ HTML HTMLGlueO.PluginControl(<f-args>)
endif

command! -buffer -bar -nargs=? ColorChooser HTMLPlugin colorchooser
if exists(':CC') != 2
  command! -buffer -bar -nargs=? CC HTMLPlugin colorchooser
endif

command! -buffer -bar HTMLTemplate   HTMLPlugin template
command! -buffer -bar HTMLtemplate   HTMLPlugin template
command! -buffer -bar BrowserLog     HTMLPlugin browserlog
command! -buffer -bar ShowBrowserLog HTMLPlugin browserlog
command! -buffer -bar HTMLBrowserLog HTMLPlugin browserlog

b:htmlplugin.did_commands = true


if get(g:htmlplugin, 'did_commands', false) # {{{1
  finish
endif

command! -bar HTMLAbout HTMLPlugin about
command! -bar HTMLabout HTMLPlugin about

g:htmlplugin.did_commands = true

# }}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
