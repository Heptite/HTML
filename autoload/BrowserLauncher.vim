vim9script
scriptencoding utf8

if v:versionlong < 8023182
  finish
endif

# --------------------------------------------------------------------------
#
# Vim script to launch/control browsers
#
# Last Change: July 19, 2021
#
# Currently supported browsers:
# Unix:
#  - Firefox  (remote [new window / new tab] / launch)
#    (This will fall back to Iceweasel for Debian installs.)
#  - Chrome   (remote [new window / new tab] / launch)
#    (This will fall back to Chromium if it's installed and Chrome isn't.)
#  - Opera    (remote [new window / new tab] / launch)
#  - Lynx     (Under the current TTY if not running the GUI, or a new xterm
#              window if DISPLAY is set.)
#  - w3m      (Under the current TTY if not running the GUI, or a new xterm
#              window if DISPLAY is set.)
#  - Default
#
# MacOS:
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Safari   (remote [new window / new tab] / launch)
#  - Default
#
# Windows and Cygwin:
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Chrome   (remote [new window / new tab] / launch)
#  - Edge     (remote [new window / new tab] / launch)
#  - Plus lynx & w3m on Cygwin if they can be found.
#  - Default
#
# TODO:
#
#  - Support more browsers, especially on MacOS
#    Note: Various browsers use the same HTML rendering engine as Firefox
#    or Chrome, so supporting them isn't as important.
#
#  - Defaulting to Lynx/w3m if the the GUI isn't available on Unix may be
#    undesirable.
#
# BUGS:
#  * On Unix, since the commands to start the browsers are run in the
#    backgorund when possible there's no way to actually get v:shell_error,
#    so execution errors aren't actually seen.
#
#  * On Windows (and Cygwin) there's no reliable way to detect which
#    browsers are installed so the most common install locations are checked.
#
# Requirements:
#       Vim 9 or later
#
# Copyright (C) 2004-2020 Christian J. Robinson <heptite@gmail.com>
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


# Not ideal to do this at the beginning of the script instead of the end, but
# this script could finish before it reaches the end:
if !exists('g:html_function_files') | g:html_function_files = [] | endif
add(g:html_function_files, expand('<sfile>:p'))->sort()->uniq()


if exists(':HTMLWARN') != 2
  command! -nargs=+ HTMLWARN :echohl WarningMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLMESG :echohl Todo | echo <q-args> | echohl None
endif

# Allow auto-scoping to work properly for Vim 9,
# initialize these variables here:
var Browsers: dict<list<any>>
var TextmodeBrowsers = ['lynx', 'w3m']

if has('mac') || has('macunix')  # {{{1
  # The following code is provided by Israel Chauca Fuentes
  # <israelvarios()fastmail!fm>:

  def s:MacAppExists(app: string): bool # {{{
    silent! call system("/usr/bin/osascript -e 'get id of application \""
      .. app .. "\"' 2>&1 >/dev/null")
    if v:shell_error
      return 0
    endif
    return 1
  enddef # }}}

  def s:UseAppleScript(): string # {{{
    return system("/usr/bin/osascript -e "
      .. "'tell application \"System Events\" to set UI_enabled "
      .. "to UI elements enabled' 2>/dev/null") ==? "true\n" ? 1 : 0
  enddef # }}}

  def g:BrowserLauncher#OpenInMacApp(app: string, new: number = 0): bool # {{{
    if app == 'test' && new == 0
      return true
    endif

    if (! s:MacAppExists(app) && app !=? 'default')
      execute 'HTMLERROR ' .. app .. ' not found'
      return 0
    endif

    var file = expand('%:p')

    # Can we open new tabs and windows?
    var use_AS = s:UseAppleScript()

    # Why we can't open new tabs and windows:
    var as_msg = 'This feature utilizes the built-in Graphic User '
      .. 'Interface Scripting architecture of Mac OS X which is '
      .. 'currently disabled. You can activate GUI Scripting by '
      .. 'selecting the checkbox "Enable access for assistive '
      .. 'devices" in the Universal Access preference pane.'

    var torn: string
    var script: string
    var command: string

    if (app ==? 'safari') # {{{
      if new != 0 && use_AS
        if new == 2
          torn = 't'
          HTMLMESG Opening file in new Safari tab...
        else
          torn = 'n'
          HTMLMESG Opening file in new Safari window...
        endif
        script = '-e "tell application \"safari\"" '
                 .. '-e "activate" '
                 .. '-e "tell application \"System Events\"" '
                 .. '-e "tell process \"safari\"" '
                 .. '-e "keystroke \"' .. torn .. '\" using {command down}" '
                 .. '-e "end tell" '
                 .. '-e "end tell" '
                 .. '-e "delay 0.3" '
                 .. '-e "tell window 1" '
                 .. '-e ' .. shellescape("set (URL of last tab) to \"" .. file .. "\"") .. ' '
                 .. '-e "end tell" '
                 .. '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know what's going on:
          execute 'HTMLERROR ' .. as_msg
        endif
        HTMLMESG Opening file in Safari...
        command = "/usr/bin/open -a safari " .. shellescape(file)
      endif
    endif "}}}

    if (app ==? 'firefox') # {{{
      if new != 0 && use_AS
        if new == 2

          torn = 't'
          HTMLMESG Opening file in new Firefox tab...
        else

          torn = 'n'
          HTMLMESG Opening file in new Firefox window...
        endif
        script = '-e "tell application \"firefox\"" '
                 .. '-e "activate" '
                 .. '-e "tell application \"System Events\"" '
                 .. '-e "tell process \"firefox\"" '
                 .. '-e "keystroke \"' .. torn .. '\" using {command down}" '
                 .. '-e "delay 0.8" '
                 .. '-e "keystroke \"l\" using {command down}" '
                 .. '-e "keystroke \"a\" using {command down}" '
                 .. '-e ' .. shellescape("keystroke \"" .. file .. "\" & return") .. " "
                 .. '-e "end tell" '
                 .. '-e "end tell" '
                 ..  '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know wath's going on:
          execute 'HTMLERROR ' .. as_msg

        endif
        HTMLMESG Opening file in Firefox...
        command = "/usr/bin/open -a firefox " .. shellescape(file)
      endif
    endif # }}}

    if (app ==? 'opera') # {{{
      if new != 0 && use_AS
        if new == 2

          torn = 't'
          HTMLMESG Opening file in new Opera tab...
        else

          torn = 'n'
          HTMLMESG Opening file in new Opera window...
        endif
        script = '-e "tell application \"Opera\"" '
                 .. '-e "activate" '
                 .. '-e "tell application \"System Events\"" '
                 .. '-e "tell process \"opera\"" '
                 .. '-e "keystroke \"' .. torn .. '\" using {command down}" '
                 .. '-e "end tell" '
                 .. '-e "end tell" '
                 .. '-e "delay 0.5" '
                 .. '-e ' .. shellescape("set URL of front document to \"" .. file .. "\"") .. " "
                 .. '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know what's going on:
          execute 'HTMLERROR ' .. as_msg

        endif
        HTMLMESG Opening file in Opera...
        command = "/usr/bin/open -a opera " .. shellescape(file)
      endif
    endif # }}}

    if (app ==? 'default')
      HTMLMESG Opening file in default browser...
      command = "/usr/bin/open " .. shellescape(file)
    endif

    if (command == '')
      execute 'HTMLMESG Opening ' .. app->substitute('^.', '\U&', '') .. '...'
      command = "open -a " .. app .. " " .. shellescape(file)
    endif

    system(command .. " 2>&1 >/dev/null")
  enddef # }}}

  defcompile

  finish

elseif has('unix') && ! has('win32unix') # {{{1

  # Set this manually, since the first in the list is the default:
  Browsers['firefox'] = [['firefox', 'iceweasel'], 
    '', '', '--new-tab', '--new-window']
  Browsers['chrome']  = [['google-chrome', 'chrome', 'chromium-browser', 'chromium'],
    '', '', '',          '--new-window']
  Browsers['opera']   = ['opera',
    '', '', '',          '--new-window']
  Browsers['lynx']    = ['lynx',
    '', '', '',          '']
  Browsers['w3m']     = ['w3m',
    '', '', '',          '']
  Browsers['default'] = ['xdg-open',
    '', '', '',          '']

  var temppath: string

  for tempkey in keys(Browsers)
    for tempname in (type(Browsers[tempkey][0]) == type([]) ? Browsers[tempkey][0] : [Browsers[tempkey][0]])
      temppath = system('which ' .. tempname)->substitute("\n$", '', '')
      if v:shell_error == 0
        Browsers[tempkey][0] = tempname
        Browsers[tempkey][1] = temppath
        break
      endif
    endfor

    if v:shell_error != 0
      remove(Browsers, tempkey)
    endif
  endfor

elseif has('win32') || has('win64') || has('win32unix')  # {{{1

  # These applications _could_ be installed elsewhere, but there's no reliable
  # way to find them if they are, so just assume they would be in a standard
  # location:
  if filereadable('C:\Program Files\Mozilla Firefox\firefox.exe')
    || filereadable('C:\Program Files (x86)\Mozilla Firefox\firefox.exe')
    Browsers['firefox'] = ['firefox', '', '', '--new-tab', '--new-window']
  endif
  if filereadable('C:\Program Files\Google\Chrome\Application\chrome.exe')
    || filereadable('C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')
    Browsers['chrome'] = ['chrome', '', '', '', '--new-window']
  endif
  if filereadable('C:\Program Files\Opera\launcher.exe')
    || filereadable('C:\Program Files (x86)\Opera\launcher.exe')
    Browsers['opera'] = ['opera', '', '', '', '--new-window']
  endif
  if filereadable('C:\Program Files\Microsoft\Edge\Application\msedge.exe')
    || filereadable('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')
    Browsers['edge'] = ['msedge', '', '', '', '--new-window']
  endif

  Browsers['default'] = ['"RunDll32.exe shell32.dll,ShellExec_RunDLL"', '', '', '', '']

  if has('win32unix')
    var temp: string
    temp = system('which lynx')->substitute("\n$", '', '')
    if v:shell_error == 0
      Browsers['lynx'] = ['lynx', temp, '', '', '']
    endif
    temp = system('which w3m')->substitute("\n$", '', '')
    if v:shell_error == 0
      Browsers['w3m'] = ['w3m', temp, '', '', '']
    endif

    Browsers['default'] = ['RunDll32.exe shell32.dll,ShellExec_RunDLL', '', '', '', '']
  endif

else # OS not recognized, can't do any browser control: {{{1

  HTMLWARN Your OS is not recognized, browser controls will not work.

  Browsers = {}

endif # }}}1

# g:BrowserLauncher#Exists() {{{1
#
# Usage:
#  :echo BrowserLauncher#Exists([browser])
# Return value:
#  With an argument: True or False - Whether the browser was found (exists)
#  Without an argument: list - The names of the browsers that were found
def g:BrowserLauncher#Exists(browser: string = ''): any
  if browser == ''
    return keys(Browsers)
  else
    return exists('Browsers["' .. browser->escape('"\\') .. '"]') ? true : false
  endif
enddef

# g:BrowserLauncher#Launch() {{{1
#
# Usage:
#  :call BrowserLauncher#Launch({...}, [{0/1/2}], [url])
#    The first argument is which browser to launch, by name (not executable).
#    Use g:BrowserLauncher#Exists() to see which ones are available.
#
#    The optional second argument is whether to launch a new window:
#      0 - No (default -- in modern brosers this tends to open a new tab)
#      1 - Yes (some modern browsers don't actually provide a way to do this)
#      2 - New Tab (or new window if the browser doesn't provide a way to
#                   open a new tab)
#
#    The optional third argument is an URL to go to instead of loading the
#    current file.
#
# Return value:
#  false - Failure (No browser was launched/controlled.)
#  true  - Success (The specified browser was launched/controlled.)
def g:BrowserLauncher#Launch(browser: string, new: number = 0, url: string = ''): bool
  var which = browser
  var donew = new
  var command: string
  var file: string

  if !g:BrowserLauncher#Exists(which)
    execute 'HTMLERROR Unknown browser ID: ' .. which
    return false
  endif

  if which == 'default'
    donew = 0
  endif

  if url != ''
    file = url
  elseif expand('%') != ''
    # If we're on Cygwin and not using lynx or w3m, translate the file path
    # to a Windows native path for later use, otherwise just add the file://
    # prefix:
    file = 'file://'
      .. (has('win32unix') && TextmodeBrowsers->match('^\c\V' .. which .. '\$') < 0 ?
        system('cygpath -w ' .. expand('%:p')->shellescape())->trim() : expand('%:p'))
  else
    HTMLERROR No file is loaded in the current buffer and no URL was specified.
    return false
  endif

  if has('unix') == 1 && $DISPLAY == '' && has('win32unix') == 0
    if TextmodeBrowsers->match('^lynx$') >= 0
      which = 'lynx'
    elseif TextmodeBrowsers->match('^w3m$') >= 0
      which = 'w3m'
    else
      HTMLERROR $DISPLAY is not set and Lynx or w3m are not found, no browser launched.
      return false
    endif
  endif

  if TextmodeBrowsers->match('^\c\V' .. which .. '\$') >= 0 
    execute "HTMLMESG Launching " .. Browsers[which][0] .. "..."

    var xterm = system('which xterm')->trim()
    if v:shell_error != 0
      xterm = ''
    endif

    # The logic here is a bit convoluted
    if has("gui_running") || donew > 0
      if $DISPLAY != '' && xterm != '' && donew == 1
        command = xterm .. ' -T ' .. Browsers[which][0] .. ' -e '
          .. Browsers[which][1] .. ' ' .. shellescape(file) .. ' &'
      elseif exists(':terminal') == 2
        execute 'terminal ++close ' .. Browsers[which][1] .. ' ' .. file
        return true
      else
        if donew == 1
          execute "HTMLERROR XTerm not found, and :terminal is not compiled into this version of GVim. Can't launch "
            ..  Browsers[which][0] .. '.'
        else
          execute ":terminal is not compiled into this version of GVim. Can't launch "
            ..  Browsers[which][0] .. '.'
        endif

        return false
      endif
    else
      sleep 1
      execute "!" .. Browsers[which][1] .. " " .. shellescape(file)

      if v:shell_error
        execute "HTMLERROR Unable to launch " .. Browsers[which][0] .. "."
        return false
      endif

      return true
    endif
  endif

  if command == ''
    if donew == 2
      execute 'HTMLMESG Opening new ' .. Browsers[which][0]->s:Cap() .. ' tab...'
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file)
          .. ' ' .. Browsers[which][3] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. " "
          .. shellescape(file) .. ' ' .. Browsers[which][3]  .. ' &"'
      endif
    elseif donew > 0
      execute 'HTMLMESG Opening new ' .. Browsers[which][0]->s:Cap() .. ' window...'
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file)
          .. ' ' .. Browsers[which][4] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. ' '
          .. shellescape(file) .. ' ' .. Browsers[which][4]  .. ' &"'
      endif
    else
      if which == 'default'
        execute 'HTMLMESG Invoking system default browser...'
      else
        execute 'HTMLMESG Invoking ' .. Browsers[which][0]->s:Cap() .. "..."
      endif

      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file)
          .. ' ' .. Browsers[which][2] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. " "
          .. shellescape(file) .. ' ' .. Browsers[which][2]  .. ' &"'
      endif
    endif
  endif

  if command != ''

    if has('win32unix')
      command = command->substitute('^start', 'cygstart', '')
      if which == 'default'
        command = command->substitute('file://', '', '')
      endif
    endif

    system(command)

    if v:shell_error
      execute 'HTMLERROR Command failed: ' .. command
      return false
    endif

    return true
  endif

  HTMLERROR Something went wrong, we should never get here...
  return false
enddef

# s:Cap() {{{1
#
# Capitalize the first letter of every word in a string
#
# Args:
#  1 - String: The words
# Return value:
#  String: The words capitalized
def s:Cap(arg: string): string
  return arg->substitute('\<.', '\U&', 'g')
enddef # }}}1

defcompile

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
