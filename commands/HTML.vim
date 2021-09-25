vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8023438
  finish
endif

# Various :-commands for the HTML macros filetype plugin.
#
# Last Change: September 14, 2021
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 1998-2021 Christian J. Robinson <heptite(at)gmail(dot)com>
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

if exists('b:htmlplugin.did_commands') && b:htmlplugin.did_commands == true
  finish
endif

command! -buffer -nargs=1 HTMLplugin HTML#PluginControl(<f-args>)
command! -buffer -nargs=1 HTMLPlugin HTML#PluginControl(<f-args>)
command! -buffer -nargs=1 HTMLmappings HTML#PluginControl(<f-args>)
command! -buffer -nargs=1 HTMLMappings HTML#PluginControl(<f-args>)
if exists(':HTML') != 2
  command! -buffer -nargs=1 HTML HTML#PluginControl(<f-args>)
endif

command! -buffer -nargs=? ColorChooser HTML#ColorChooser(<f-args>)
if exists(':CC') != 2
  command! -buffer -nargs=? CC HTML#ColorChooser(<f-args>)
endif

command! -buffer HTMLTemplate if HTML#Template() | startinsert | endif
command! -buffer HTMLtemplate HTMLTemplate

command! -buffer HTMLReloadFunctions {
    if exists('g:htmlplugin.function_files')
      for f in copy(g:htmlplugin.function_files)
        execute 'HTMLMESG Reloading: ' .. fnamemodify(f, ':t')
        execute 'source ' .. f
      endfor
    else
      HTMLERROR Somehow the global variable describing the loaded function files is non-existent.
    endif
  }

b:htmlplugin.did_commands = true


if exists('g:htmlplugin.did_commands') && g:htmlplugin.did_commands == true
  finish
endif

command! -nargs=+ HTMLWARN {
    echohl WarningMsg
    echomsg <q-args>
    echohl None
  }

command! -nargs=+ HTMLMESG {
    echohl Todo
    echo <q-args>
    echohl None
  }

command! -nargs=+ HTMLERROR {
    echohl ErrorMsg
    echomsg <q-args>
    echohl None
  }

command! HTMLAbout HTML#About()
command! HTMLabout HTML#About()

command! -nargs=+ SetIfUnset HTML#SetIfUnset(<f-args>)

g:htmlplugin.did_commands = true

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
