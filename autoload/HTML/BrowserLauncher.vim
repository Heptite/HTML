vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  finish
endif

# --------------------------------------------------------------------------
#
# Vim script to launch/control browsers
#
# Last Change: July 29, 2024
#
# Currently supported browsers:
# Unix:
#  - Brave    (remote [new window / new tab] / launch)
#  - Chrome   (remote [new window / new tab] / launch)
#    (This will fall back to Chromium if it's installed and Chrome isn't.)
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Lynx     (Under the current TTY if not running the GUI, or a new xterm
#              window if DISPLAY is set.)
#  - w3m      (Under the current TTY if not running the GUI, or a new xterm
#              window if DISPLAY is set.)
#  - links    (Under the current TTY if not running the GUI, or a new xterm
#              window if DISPLAY is set.)
#  - Default
#
# MacOS:
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Safari   (remote [new window / new tab] / launch)
#  - Default
#
# Windows, Cygwin, and WSL2:
#  - Brave    (remote [new window / new tab] / launch)
#  - Chrome   (remote [new window / new tab] / launch)
#  - Edge     (remote [new window / new tab] / launch)
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Plus lynx, w3m, and links on Cygwin if they can be found.
#  - Default
#
# TODO:
#
#  - Support more browsers, especially on MacOS
#    Note: Various browsers use the same HTML rendering engine as Firefox
#    or Chrome, so supporting them isn't as important.
#
#  - Defaulting to Lynx/w3m/Links if the the GUI isn't available on Unix may
#    be undesirable.
#
# BUGS:
#  * On Unix, since the commands to start the browsers are run in the
#    backgorund when possible there's no way to actually get v:shell_error,
#    so execution errors aren't actually seen.
#
#  * On Windows (and Cygwin) there's no reliable way to detect which
#    browsers are installed so only the most common install locations are
#    checked.
#
# Requirements:
#  * Vim 9.1.509 or later
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

import autoload 'HTML/Messages.vim'

export enum Behavior
  default,
  newwindow,
  newtab
endenum

export class BrowserLauncher

  var Browsers: dict<list<any>>
  var TextModeBrowsers: dict<list<any>> = {lynx: [], w3m: [], links: []}
  var MacBrowsersExist = ['default']
  var HTMLMessagesO: Messages.HTMLMessages

  def new() # {{{
    this.HTMLMessagesO = Messages.HTMLMessages.new()

    if (has('mac') == 1) || (has('macunix') == 1)
      return
    elseif filereadable('/proc/version') && readfile('/proc/version')[0] =~# 'WSL2'
      # These applications _could_ be installed elsewhere, but there's no reliable
      # way to find them if they are, so just assume they would be in a standard
      # location:
      if filereadable('/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe')
        this.Browsers.brave = ['brave', '/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe', '', '', '--new-window']
      elseif filereadable('/mnt/c/Program Files (x86)/BraveSoftware/Brave-Browser/Application/brave.exe')
        this.Browsers.brave = ['brave', '/mnt/c/Program Files (x86)/BraveSoftware/Brave-Browser/Application/brave.exe', '', '', '--new-window']
      endif
      if filereadable('/mnt/c/Program Files/Mozilla Firefox/firefox.exe')
        this.Browsers.firefox = ['firefox', '/mnt/c/Program Files/Mozilla Firefox/firefox.exe', '', '--new-tab', '--new-window']
      elseif filereadable('/mnt/c/Program Files (x86)/Mozilla Firefox/firefox.exe')
        this.Browsers.firefox = ['firefox', '/mnt/c/Program Files (x86)/Mozilla Firefox/firefox.exe', '', '--new-tab', '--new-window']
      endif
      if filereadable('/mnt/c/Program Files/Google/Chrome/Application/chrome.exe')
        this.Browsers.chrome = ['chrome', '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe', '', '', '--new-window']
      elseif filereadable('/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe')
        this.Browsers.chrome = ['chrome', '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe', '', '', '--new-window']
      endif
      if filereadable('/mnt/c/Program Files/Opera/launcher.exe')
        this.Browsers.opera = ['opera', '/mnt/c/Program Files/Opera/launcher.exe', '', '', '--new-window']
      elseif filereadable('/mnt/c/Program Files (x86)/Opera/launcher.exe')
        this.Browsers.opera = ['opera', '/mnt/c/Program Files (x86)/Opera/launcher.exe', '', '', '--new-window']
      endif
      if filereadable('/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe')
        this.Browsers.edge = ['msedge', '/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe', '', '', '--new-window']
      elseif filereadable('/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        this.Browsers.edge = ['msedge', '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '', '', '--new-window']
      endif

      this.TextModeBrowsers = this.FindTextModeBrowsers()
      this.Browsers->extend(this.TextModeBrowsers)
    elseif (has('unix') == 1) && (has('win32unix') == 0)

      this.Browsers.firefox = ['firefox',
        '', '', '--new-tab', '--new-window']
      this.Browsers.brave   = [['brave-browser', 'brave'],
        '', '', '',          '--new-window']
      this.Browsers.chrome  = [['google-chrome', 'chrome', 'chromium-browser', 'chromium'],
        '', '', '',          '--new-window']
      this.Browsers.opera   = ['opera',
        '', '', '',          '--new-window']
      this.Browsers.default = ['xdg-open',
        '', '', '',          '']

      var temppath: string
      for tempkey in this.Browsers->keys()
        for tempname in (type(this.Browsers[tempkey][0]) == v:t_list ? this.Browsers[tempkey][0] : [this.Browsers[tempkey][0]])
          temppath = system($'which {tempname}')->trim()
          if v:shell_error == 0
            this.Browsers[tempkey][0] = tempname
            this.Browsers[tempkey][1] = temppath
            break
          endif
        endfor

        if v:shell_error != 0
          this.Browsers->remove(tempkey)
        endif
      endfor

      this.TextModeBrowsers = this.FindTextModeBrowsers()
      this.Browsers->extend(this.TextModeBrowsers)

    elseif (has('win32') == 1) || (has('win64') == 1) || (has('win32unix') == 1)

      # These applications _could_ be installed elsewhere, but there's no reliable
      # way to find them if they are, so just assume they would be in a standard
      # location:
      if filereadable('C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe')
          || filereadable('C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe')
        this.Browsers.brave = ['brave', '', '', '', '--new-window']
      endif
      if filereadable('C:\Program Files\Mozilla Firefox\firefox.exe')
          || filereadable('C:\Program Files (x86)\Mozilla Firefox\firefox.exe')
        this.Browsers.firefox = ['firefox', '', '', '--new-tab', '--new-window']
      endif
      if filereadable('C:\Program Files\Google\Chrome\Application\chrome.exe')
          || filereadable('C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')
        this.Browsers.chrome = ['chrome', '', '', '', '--new-window']
      endif
      if filereadable('C:\Program Files\Opera\launcher.exe')
          || filereadable('C:\Program Files (x86)\Opera\launcher.exe')
        this.Browsers.opera = ['opera', '', '', '', '--new-window']
      endif
      if filereadable('C:\Program Files\Microsoft\Edge\Application\msedge.exe')
          || filereadable('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')
        this.Browsers.edge = ['msedge', '', '', '', '--new-window']
      endif

      # Odd quoting needed for "start":
      this.Browsers.default = ['"RunDll32.exe shell32.dll,ShellExec_RunDLL"', '', '', '', '']

      if has('win32unix') == 1
        this.TextModeBrowsers = this.FindTextModeBrowsers()
        this.Browsers->extend(this.TextModeBrowsers)

        # Different quoting required for "cygstart":
        this.Browsers.default = ['RunDll32.exe shell32.dll,ShellExec_RunDLL', '', '', '', '']
      endif

    else

      this.HTMLMessagesO.Warn('Your OS is not recognized, browser controls will not work.')

      this.Browsers = {}

    endif
  enddef # }}}

  def Exists(browser: string = ''): any  # {{{1
    if has('mac') == 1 || has('macunix') == 1
      return this.MacExists(browser)
    else
      return this.UnixWindowsExists(browser)
    endif
  enddef

  def Launch(browser: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool  # {{{1
    if (has('mac') == 1) || (has('macunix') == 1)
      return this.MacLaunch(browser, new, url)
    else
      return this.UnixWindowsLaunch(browser, new, url)
    endif
  enddef  # }}}1

  # FindTextModeBrowsers() {{{1
  #
  # Remove browsers from TextModeBrowsers that aren't found, and add to
  # Browsers dictionary of textmode browsers that are found.
  #
  # Args:
  #  The list of browsers to search for
  # Return value:
  #  A list of browsers that were found, in lisdt<list<string>> format
  def FindTextModeBrowsers(browserlist: dict<list<any>> = this.TextModeBrowsers): dict<list<any>>
    var browsers: dict<list<any>>

    browsers = browserlist->mapnew(
      (textbrowser, _) => {
        var temp: string = system($'which {textbrowser}')->trim()

        if v:shell_error == 0
          return [textbrowser, temp, '', '', '']
        else
          return []
        endif
      }
    )

    browsers->filter((_, tmp) => tmp != [])

    return browsers
  enddef # }}}1

  def UseAppleScript(): bool # {{{1
    return system('/usr/bin/osascript -e '
      .. "'tell application \"System Events\" to set UI_enabled "
      .. "to UI elements enabled' 2>/dev/null")->trim() ==? 'true' ? true : false
  enddef

  def MacExists(app: string = ''): any # {{{1
    if app == ''
      return this.MacBrowsersExist
    endif

    if match(this.MacBrowsersExist, '^\c\V' .. app .. '\$')
      return true
    else
      system("/usr/bin/osascript -e 'get id of application \"" .. app->escape("\"'\\") .. "\"'")
      if v:shell_error
        return false
      endif

      this.MacBrowsersExist->add(app->tolower())->sort()->uniq()
      return true
    endif
  enddef

  def MacLaunch(app: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool # {{{1
    var file: string
    var torn: string
    var script: string
    var command: string
    var use_AS: bool
    var as_msg: string

    if (!this.MacExists(app) && app !=? 'default')
      printf(this.HTMLMessagesO.E_NOAPP, app)->this.HTMLMessagesO.Error()
      return false
    endif

    if url != ''
      file = url
    elseif expand('%') == ''
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOFILE)
      return false
    else
      if &modified
        this.HTMLMessagesO.Warn(this.HTMLMessagesO.W_UNSAVED)
      endif
      file = expand('%:p')
    endif

    # Can we open new tabs and windows?
    use_AS = this.UseAppleScript()

    # Why we can't open new tabs and windows:
    as_msg = "The feature that allows the opening of new browser windows\n"
      .. "and tabs utilizes the built-in Graphic User Interface Scripting\n"
      .. "architecture of Mac OS X which is currently disabled. You can\n"
      .. "activate GUI Scripting by selecting the checkbox \"Enable\n"
      .. "access for assistive devices\" in the Universal Access\n"
      .. "preference pane."

    if (app ==? 'safari') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab
          torn = 't'
          this.HTMLMessagesO.Message('Opening file in new Safari tab...')
        else
          torn = 'n'
          this.HTMLMessagesO.Message('Opening file in new Safari window...')
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

        command = '/usr/bin/osascript ' .. script

      else
        if new != Behavior.default
          # Let the user know what's going on:
          as_msg->confirm('&Dismiss', 1, 'Error')
        endif

        this.HTMLMessagesO.Message('Opening file in Safari...')
        command = '/usr/bin/open -a safari ' .. file->shellescape()
      endif
    endif "}}}

    if (app ==? 'firefox') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab

          torn = 't'
          this.HTMLMessagesO.Message('Opening file in new Firefox tab...')
        else

          torn = 'n'
          this.HTMLMessagesO.Message('Opening file in new Firefox window...')
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

        command = '/usr/bin/osascript ' .. script

      else
        if new != Behavior.default
          # Let the user know wath's going on:
          as_msg->confirm('&Dismiss', 1, 'Error')

        endif
        this.HTMLMessagesO.Message('Opening file in Firefox...')
        command = '/usr/bin/open -a firefox ' .. file->shellescape()
      endif
    endif # }}}

    if (app ==? 'opera') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab

          torn = 't'
          this.HTMLMessagesO.Message('Opening file in new Opera tab...')
        else

          torn = 'n'
          this.HTMLMessagesO.Message('Opening file in new Opera window...')
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

        command = '/usr/bin/osascript ' .. script

      else
        if new != Behavior.default
          # Let the user know what's going on:
          as_msg->confirm('&Dismiss', 1, 'Error')

        endif
        this.HTMLMessagesO.Message('Opening file in Opera...')
        command = '/usr/bin/open -a opera ' .. file->shellescape()
      endif
    endif # }}}

    if (app ==? 'default')
      this.HTMLMessagesO.Message('Opening file in default browser...')
      command = '/usr/bin/open ' .. file->shellescape()
    endif

    if (command == '')
      this.HTMLMessagesO.Message('Opening ' .. app->substitute('^.', '\U&', '') .. '...')
      command = '/usr/bin/open -a ' .. app .. ' ' .. file->shellescape()
    endif

    system(command)
  enddef # }}}

  # UnixWindowsExists() {{{1
  #
  # Usage:
  #  UnixWindowsExists([browser])
  # Return value:
  #  With an argument: True or False - Whether the browser was found (exists)
  #  Without an argument: list - The names of the browsers that were found
  def UnixWindowsExists(browser: string = ''): any
    if browser == ''
      return this.Browsers->keys()->sort()
    else
      return this.Browsers->has_key(browser) ? true : false
    endif
  enddef

  # UnixWindowsLaunch() {{{1
  #
  # Usage:
  #  UnixWindowsLaunch({...}, [{0/1/2}], [url])
  #    The first argument is which browser to launch, by name (not executable).
  #    Use BrowserLauncher#Exists() to see which ones are available.
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
  #  true  - Success (A browser was launched/controlled.)
  def UnixWindowsLaunch(browser: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool
    # Cap() {{{2
    #
    # Capitalize the first letter of every word in a string
    #
    # Args:
    #  1 - String: The words
    # Return value:
    #  String: The words capitalized
    def Cap(arg: string): string
      return arg->substitute('\<.', '\U&', 'g')
    enddef # }}}2

    var which = browser
    var donew = new
    var command: string
    var output: string
    var file: string

    if !this.UnixWindowsExists(which)
      printf(this.HTMLMessagesO.E_UNKNOWN, which)->this.HTMLMessagesO.Error()
      return false
    endif

    if which == 'default'
      donew = Behavior.default
    endif

    if url != ''
      file = url
    elseif expand('%') != ''
      if &modified
        this.HTMLMessagesO.Warn(this.HTMLMessagesO.W_UNSAVED)
      endif

      # If we're on Cygwin or WSL2 and not using a text mode browser,
      # translate the file path to a Windows native path for later use,
      # otherwise just add the file:// prefix:
      if has('win32unix') == 1 && match(this.TextModeBrowsers->keys(), '^\c\V' .. which .. '\$') < 0
        file = 'file://' .. system('cygpath -w ' .. expand('%:p')->shellescape())->trim()
      elseif filereadable('/proc/version') && readfile('/proc/version')[0] =~# 'WSL2'
          && match(this.TextModeBrowsers->keys(), '^\c\V' .. which .. '\$') < 0
        # No double slash here, please:
        file = 'file:/' .. system('wslpath -w ' .. expand('%:p')->shellescape())->trim()
      else
        file = 'file://' .. expand('%:p')
      endif
    else
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOFILE)
      return false
    endif

    if has('unix') == 1 && $DISPLAY == ''
        && match(this.TextModeBrowsers->keys(), '^\c\V' .. which .. '\$') < 0
        && has('win32unix') == 0
      if this.TextModeBrowsers->keys() == []
        this.HTMLMessagesO.Error(this.HTMLMessagesO.E_DISPLAY)
        return false
      else
        which = this.TextModeBrowsers->keys()[0]
      endif
    endif

    # Have to handle the textmode browsers different than the GUI browsers:
    if match(this.TextModeBrowsers->keys(), '^\c\V' .. which .. '\$') >= 0
      this.HTMLMessagesO.Message('Launching ' .. this.Browsers[which][0] .. '...')

      var xterm = system('which xterm')->trim()
      if v:shell_error != 0
        xterm = ''
      endif

      if has('gui_running') == 1 || donew != Behavior.default
        if $DISPLAY != '' && xterm != '' && donew == Behavior.newwindow
          command = xterm .. ' -T ' .. this.Browsers[which][0] .. ' -e '
            .. this.Browsers[which][1] .. ' ' .. file->shellescape() .. ' &'
        elseif exists_compiled(':terminal') == 2
          execute 'terminal ++close ' .. this.Browsers[which][1] .. ' ' .. file
          return true
        else
          if donew == Behavior.newwindow
            this.HTMLMessagesO.Error(printf(this.HTMLMessagesO.E_XTERM, this.Browsers[which][0]))
          else
            this.HTMLMessagesO.Error(printf(this.HTMLMessagesO.E_TERM, this.Browsers[which][0]))
          endif

          return false
        endif
      else
        sleep 1
        execute '!' .. this.Browsers[which][1] .. ' ' .. file->shellescape()

        if v:shell_error
          printf(this.HTMLMessagesO.E_LAUNCH, this.Browsers[which][0])->this.HTMLMessagesO.Error()
          return false
        endif

        return true
      endif
    endif

    # If we haven't already defined a command, we are going to use a GUI
    # browser:
    if command == ''

      if donew == Behavior.newtab
        this.HTMLMessagesO.Message('Opening new ' .. this.Browsers[which][0]->Cap()
          .. ' tab...')
        if (has('win32') == 1) || (has('win64') == 1) || (has('win32unix') == 1)
          command = 'start ' .. this.Browsers[which][0] .. ' ' .. file->shellescape()
            .. ' ' .. this.Browsers[which][3]
        else
          command = "sh -c \"trap '' HUP; " .. this.Browsers[which][1] .. " "
            .. file->shellescape() .. ' ' .. this.Browsers[which][3]  .. ' &"'
        endif
      elseif donew != Behavior.default
        this.HTMLMessagesO.Message('Opening new ' .. this.Browsers[which][0]->Cap()
          .. ' window...')
        if (has('win32') == 1) || (has('win64') == 1) || (has('win32unix') == 1)
          command = 'start ' .. this.Browsers[which][0] .. ' ' .. file->shellescape()
            .. ' ' .. this.Browsers[which][4]
        else
          command = "sh -c \"trap '' HUP; " .. this.Browsers[which][1] .. ' '
            .. file->shellescape() .. ' ' .. this.Browsers[which][4]  .. ' &"'
        endif
      else
        if which == 'default'
          this.HTMLMessagesO.Message('Invoking system default browser...')
        else
          this.HTMLMessagesO.Message('Invoking ' .. this.Browsers[which][0]->Cap() .. '...')
        endif

        if (has('win32') == 1) || (has('win64') == 1) || (has('win32unix') == 1)
          command = 'start ' .. this.Browsers[which][0] .. ' ' .. file->shellescape()
            .. ' ' .. this.Browsers[which][2]
        else
          command = $'sh -c "trap '''' HUP; {this.Browsers[which][1]->shellescape()} {file->shellescape()} {this.Browsers[which][2]} &"'
        endif
      endif
    endif

    if command != ''

      if has('win32unix') == 1
        command = command->substitute('^start', 'cygstart', '')
        if which == 'default'
          command = command->substitute('file://', '', '')
        endif
      endif

      output = system(command)

      if v:shell_error
        printf(this.HTMLMessagesO.E_COMMAND, command)->this.HTMLMessagesO.Error()
        this.HTMLMessagesO.Error(output)
        return false
      endif

      return true
    endif

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_FINAL)
    return false
  enddef

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
