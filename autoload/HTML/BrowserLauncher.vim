vim9script
scriptencoding utf8

if v:versionlong < 9021240
  finish
endif

# --------------------------------------------------------------------------
#
# Methods to launch/control browsers
#
# Last Change: October 28, 2026
#
# Currently supported browsers:
# Unix:
#  - Brave    (remote [new window / new tab] / launch)
#  - Chrome   (remote [new window / new tab] / launch)
#    (This will fall back to Chromium if it's installed and Chrome isn't.)
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - lynx     (Current TTY / :terminal / new xterm)
#  - w3m      (Current TTY / :terminal / new xterm)
#  - links    (Current TTY / :terminal / new xterm)
#  - links2   (Current TTY / :terminal / new xterm)
#  - elinks   (Current TTY / :terminal / new xterm)
#  - OS Default (using xdg-open)
#
# MacOS:
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Safari   (remote [new window / new tab] / launch)
#  - OS Default
#
# Windows, Cygwin, and WSL2:
#  - Brave    (remote [new window / new tab] / launch)
#  - Chrome   (remote [new window / new tab] / launch)
#  - Edge     (remote [new window / new tab] / launch)
#  - Firefox  (remote [new window / new tab] / launch)
#  - Opera    (remote [new window / new tab] / launch)
#  - Plus lynx, w3m, links, links2, and elinks text-mode browsers if under
#    Cygwin or WSL2
#  - OS Default
#
# TODO:
#
#  - Support more browsers, especially on MacOS
#    Note: Various browsers use the same HTML rendering engine as Firefox
#    or Chrome, so supporting them isn't as important.
#
#  - Defaulting to lynx/w3m/elinks if the the GUI isn't available on Unix may
#    be undesirable.
#
#  - Make a way to invoke browsers installed under WSL2 if they're there,
#    instead of just the "native" Windows binaries.
#
# BUGS:
#
# Requirements:
#
#  - Vim 9.2.1240 or later with job_start()/channel support
#  - At least one supported browser must be installed
#  - xdg-open should be installed for Unix for default browser behavior
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

import autoload './Messages.vim'
import autoload './Util.vim'

export enum Behavior # {{{1
  default,
  newwindow,
  newtab
endenum # }}}1

export type BrowserList = dict<dict<string>>

export class BrowserLauncher

  static var _Browsers: BrowserList = {}
  static var _TextModeBrowsers: BrowserList = { # {{{
    lynx:   {realname: 'lynx',   path: '', tab: '', window: ''},
    w3m:    {realname: 'w3m',    path: '', tab: '', window: ''},
    links:  {realname: 'links',  path: '', tab: '', window: ''},
    links2: {realname: 'links2', path: '', tab: '', window: ''},
    elinks: {realname: 'elinks', path: '', tab: '', window: ''}
  } # }}}
  static const _UnixBrowsers: BrowserList = { # {{{
    firefox: {
      realname: 'firefox',   path:   '',
      tab:      '--new-tab', window: '--new-window'
    },
    brave: {
      realname: ['brave-browser', 'brave'], path:   '',
      tab:      '',                         window: '--new-window'
    },
    chrome: {
      realname: ['google-chrome', 'chrome', 'chromium-browser', 'chromium'],
      path:     '',
      tab:      '', window: '--new-window'
    },
    opera: {
      realname: 'opera', path:   '',
      tab:      '',      window: '--new-window'
    },
    default: {
      realname: 'xdg-open', path:   '',
      tab:      '',         window: ''
    }
  } # }}}
  static const _WindowsBrowsers: BrowserList = { # {{{
    brave: {
      realname: 'Brave',     path:   'brave.exe',
      tab:      '',          window: '--new-window'
    },
    firefox: {
      realname: 'Firefox',   path:   'firefox.exe',
      tab:      '--new-tab', window: '--new-window'
    },
    chrome: {
      realname: 'Chrome',    path:   'chrome.exe',
      tab:      '',          window: '--new-window'
    },
    opera: {
      realname: 'Opera',     path:   'opera.exe',
      tab:      '',          window: '--new-window'
    },
    edge: {
      realname: 'Edge',      path:   'msedge.exe',
      tab:      '',          window: '--new-window'
    }
  } # }}}
  static var _MacBrowsersExist: list<string> = ['default']
  static var HTMLMessagesO: Messages.HTMLMessages
  static var HTMLUtilO: Util.HTMLUtil
  static var _BrowserLog: list<string> = []

  def new()  # {{{
    var temppath: string
    var browserstmp: dict<dict<any>>

    if HTMLMessagesO == null_object
      HTMLMessagesO = Messages.HTMLMessages.new()
      HTMLUtilO = Util.HTMLUtil.new()
    endif

    if HTMLUtilO.Has('mac') || _Browsers != {}
      return
    elseif (! (HTMLUtilO.Has('WSL2') || has('win32unix') == 1)) && has('unix') == 1
      _Browsers->extend(this._FindUnixBrowsers())
      _TextModeBrowsers = this._FindTextModeBrowsers()
      _Browsers->extend(_TextModeBrowsers)
    elseif HTMLUtilO.Has('WSL2') || HTMLUtilO.Has('win')
      _Browsers->extend(this._FindWindowsBrowsers())
      if HTMLUtilO.Has('WSL2') || has('win32unix') == 1
        _TextModeBrowsers = this._FindTextModeBrowsers()
        _Browsers->extend(_TextModeBrowsers)
      endif
    else
      HTMLMessagesO.Warn('Your OS is not recognized--browser controls will not work.')
    endif
  enddef  # }}}

  def BrowserExists(browser: string = ''): any  # {{{1
    if HTMLUtilO.Has('mac')
      return this._MacBrowserExists(browser)
    else
      return this._UnixWindowsBrowserExists(browser)
    endif
  enddef

  def Launch(browser: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool  # {{{1
    if HTMLUtilO.Has('mac')
      return this._MacLaunch(browser, new, url)
    else
      return this._UnixWindowsLaunch(browser, new, url)
    endif
  enddef  # }}}1

  # _RegistrySearch() {{{1
  #
  # Find the executable location of a browser installed on Windows by
  # searching the registry, returning a path to the executable if found, or an
  # empty string if not found.
  #
  # Args:
  #  1 - The name of the browser to search for (as it appears in the registry)
  #  2 - The name of the executable to search for (e.g., "firefox.exe")
  # Return value:
  #  The path to the executable of the browser, or an empty string if not
  #  found
  def _RegistrySearch(name: string, exe: string): string
    var output: list<string>

    # First look in the User's personal installs:
    output = systemlist(['reg.exe', 'query', 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', '/s', '/f', name, '/d'])
    output += systemlist(['reg.exe', 'query', 'HKCU\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall', '/s', '/f', name, '/d'])
    # Then look in the system-wide installs:
    output += systemlist(['reg.exe', 'query', 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', '/s', '/f', name, '/d'])
    output += systemlist(['reg.exe', 'query', 'HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall', '/s', '/f', name, '/d'])

    for line: string in output
      if line =~# '^\s*InstallLocation\>'
        var path: string = substitute(trim(line), '^InstallLocation\s\+REG_SZ\s\+', '', '')
        if has('win32unix') == 1
          path = trim(system(['cygpath', path]))
          path = findfile(exe, escape(path, ' ') .. '/**')
        elseif HTMLUtilO.Has('WSL2')
          path = trim(system(['wslpath', path]))
          path = findfile(exe, escape(path, ' ') .. '/**')
        else
          path = findfile(exe, escape(path, ' ') .. '\**')
        endif
        if executable(path)
          return path
        endif
      endif
    endfor

    return ''
  enddef

  def _FindTextModeBrowsers(browserlist: BrowserList = _TextModeBrowsers): BrowserList  # {{{1
    var browsers: BrowserList

    for browser: string in browserlist->keys()
        var temp: string = browserlist[browser]['realname']->exepath()
        if temp != ''
          browsers[browser] = browserlist[browser]
          browsers[browser]['path'] = temp
        endif
    endfor

    return browsers
  enddef

  def _FindUnixBrowsers(browsers: BrowserList = _UnixBrowsers): BrowserList  # {{{1
    var browserstmp: BrowserList = deepcopy(browsers)
    var temppath: string

    for tempkey: string in browserstmp->keys()
      for tempname in (
          type(browserstmp[tempkey]['realname']) == v:t_list
            ?
          browserstmp[tempkey]['realname']
            :
          [browserstmp[tempkey]['realname']]
      )
        temppath = tempname->exepath()
        if temppath != ''
          browserstmp[tempkey]['realname'] = tempname
          browserstmp[tempkey]['path']     = temppath
          break
        endif
      endfor

      if temppath == ''
        browserstmp->remove(tempkey)
      endif
    endfor

    return browserstmp
  enddef

  def _FindWindowsBrowsers(browsers: BrowserList = _WindowsBrowsers): BrowserList  # {{{1
    var browserstmp: BrowserList = deepcopy(browsers)
    var temppath: string

    for tempkey: string in browserstmp->keys()
      temppath = this._RegistrySearch(browserstmp[tempkey]['realname'], browserstmp[tempkey]['path'])
      if temppath != ''
        browserstmp[tempkey]['realname'] = fnamemodify(browserstmp[tempkey]['path'], ':r')
        browserstmp[tempkey]['path'] = temppath
      else
        browserstmp->remove(tempkey)
      endif
    endfor

    browserstmp.default = {realname: '', path: '', tab: '', window: ''}

    return browserstmp
  enddef  # }}}1

  def _UseAppleScript(): bool # {{{1
    return system([
      '/usr/bin/osascript', '-e',
      'tell application "System Events" to set UI_enabled '
      .. 'to UI elements enabled'
    ])->trim() ==? 'true' ? true : false
  enddef

  def _MacBrowserExists(app: string = ''): any # {{{1
    if app == ''
      return _MacBrowsersExist
    endif

    if match(_MacBrowsersExist, $'^\c\V{app}\$')
      return true
    else
      system(['/usr/bin/osascript', '-e', 'get id of application "' .. app->escape('"''\') .. '"'])
      if v:shell_error
        return false
      endif

      _MacBrowsersExist->add(app->tolower())->sort()->uniq()
      return true
    endif
  enddef

  def _MacLaunch(app: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool  # {{{1
    var file: string
    var torn: string
    var script: list<string>
    var command: list<string>
    var use_AS: bool
    var as_msg: list<string>

    if (!this._MacBrowserExists(app) && app !=? 'default')
      printf(HTMLMessagesO.E_NOAPP, app)->HTMLMessagesO.Error()
      return false
    endif

    if url != ''
      file = url
    elseif expand('%') == ''
      HTMLMessagesO.Error(HTMLMessagesO.E_NOFILE)
      return false
    else
      if &modified
        HTMLMessagesO.Warn(HTMLMessagesO.W_UNSAVED)
      endif
      file = expand('%:p')
    endif

    # Can we open new tabs and windows?
    use_AS = this._UseAppleScript()

    # Why we can't open new tabs and windows:
    as_msg =<< trim END
      The feature that allows the opening of new browser windows
      and tabs utilizes the built-in Graphic User Interface Scripting
      architecture of Mac OS X which is currently disabled. You can
      activate GUI Scripting by selecting the checkbox "Enable
      access for assistive devices" in the Universal Access
      preference pane."
    END

    if (app ==? 'safari') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab
          torn = 't'
          HTMLMessagesO.Message('Opening file in new Safari tab...')
        else
          torn = 'n'
          HTMLMessagesO.Message('Opening file in new Safari window...')
        endif

        script = [
          '-e', 'tell application "safari"',
          '-e', 'activate',
          '-e', 'tell application "System Events"',
          '-e', 'tell process "safari"',
          '-e', $'keystroke "{torn}" using {{command down}}',
          '-e', 'end tell',
          '-e', 'end tell',
          '-e', 'delay 0.3',
          '-e', 'tell window 1',
          '-e', $'set (URL of last tab) to "{file}"',
          '-e', 'end tell',
          '-e', 'end tell'
        ]

        command = ['/usr/bin/osascript'] + script

      else
        if new != Behavior.default
          # Let the user know what's going on:
          as_msg->join("\n")->confirm('&Dismiss', 1, 'Error')
        endif

        HTMLMessagesO.Message('Opening file in Safari...')
        command = ['/usr/bin/open', '-a', 'safari', file]
      endif
    endif # }}}

    if (app ==? 'firefox') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab

          torn = 't'
          HTMLMessagesO.Message('Opening file in new Firefox tab...')
        else

          torn = 'n'
          HTMLMessagesO.Message('Opening file in new Firefox window...')
        endif
        script = [
          '-e', 'tell application "firefox"',
          '-e', 'activate',
          '-e', 'tell application "System Events"',
          '-e', 'tell process "firefox"',
          '-e', $'keystroke "{torn}" using {{command down}}',
          '-e', 'delay 0.8',
          '-e', 'keystroke "l" using {command down}',
          '-e', 'keystroke "a" using {command down}',
          '-e', $'keystroke "{file}" & return',
          '-e', 'end tell',
          '-e', 'end tell',
          '-e', 'end tell'
        ]

        command = ['/usr/bin/osascript'] + script

      else
        if new != Behavior.default
          # Let the user know wath's going on:
          as_msg->join("\n")->confirm('&Dismiss', 1, 'Error')
        endif

        HTMLMessagesO.Message('Opening file in Firefox...')
        command = ['/usr/bin/open', '-a', 'firefox', file]
      endif
    endif # }}}

    if (app ==? 'opera') # {{{
      if new != Behavior.default && use_AS
        if new == Behavior.newtab

          torn = 't'
          HTMLMessagesO.Message('Opening file in new Opera tab...')
        else

          torn = 'n'
          HTMLMessagesO.Message('Opening file in new Opera window...')
        endif
        script = [
          '-e', 'tell application \"Opera\"',
          '-e', 'activate',
          '-e', 'tell application "System Events"',
          '-e', 'tell process "opera"',
          '-e', $'keystroke "{torn}" using {{command down}}"',
          '-e', 'end tell',
          '-e', 'end tell',
          '-e', 'delay 0.5',
          '-e', $'set URL of front document to "{file}"',
          '-e', 'end tell',
        ] 

        command = ['/usr/bin/osascript'] + script

      else
        if new != Behavior.default
          # Let the user know what's going on:
          as_msg->join("\n")->confirm('&Dismiss', 1, 'Error')
        endif

        HTMLMessagesO.Message('Opening file in Opera...')
        command = ['/usr/bin/open', '-a', 'opera', file]
      endif
    endif # }}}

    if (app ==? 'default')
      HTMLMessagesO.Message('Opening file in default browser...')
      command = ['/usr/bin/open', file]
    endif

    if (command == [])
      HTMLMessagesO.Message($'Opening {HTMLUtilO.Cap(app)}...')
      command = ['/usr/bin/open', '-a', app, file]
    endif

    system(command)
    return v:shell_error == 0 ? true : false
  enddef # }}}

  # _UnixWindowsBrowserExists() {{{1
  #
  # Usage:
  #  UnixWindowsBrowserExists([browser])
  # Return value:
  #  With an argument: True or False - Whether the browser was found (exists)
  #  Without an argument: list - The names of the browsers that were found
  def _UnixWindowsBrowserExists(browser: string = ''): any
    if browser == ''
      #return _Browsers->keys()->sort()
      return _Browsers->mapnew(
        (name: string, info: dict<string>) => ({
          path: info.path,
          realname: info.realname
        })
      )
    endif

    # Oddly, has_key() returns numbers and not a bool value, so convert it:
    return _Browsers->has_key(browser) == 1 ? true : false
  enddef

  # _UnixWindowsLaunch() {{{1
  #
  # Usage:
  #  UnixWindowsLaunch({...}, [{0/1/2}], [url])
  #    The first argument is which browser to launch, by name (not executable).
  #    Use BrowserExists() to see which ones are available.
  #
  #    The optional second argument is whether to launch a new window:
  #      Behavior.default   - (default -- in modern brosers this tends to
  #                           open a new tab)
  #      Behavior.newwindow - (some modern browsers don't actually provide
  #                           a way to do this)
  #      Behavior.newtab    - (or new window if the browser doesn't provide a
  #                           way to open a new tab)
  #
  #    The optional third argument is an URL to go to instead of loading the
  #    current file.
  #
  # Return value:
  #  false - Failure (No browser was launched/controlled.)
  #  true  - Success (A browser was launched/controlled.)
  def _UnixWindowsLaunch(browser: string = 'default', new: Behavior = Behavior.default, url: string = ''): bool
    var which:   string       = browser
    var donew:   Behavior     = new
    var command: list<string> = []
    var file:    string

    if !this._UnixWindowsBrowserExists(which)
      printf(HTMLMessagesO.E_UNKNOWN, which)->HTMLMessagesO.Error()
      return false
    endif

    if which == 'default'
      donew = Behavior.default
    endif

    if url != ''
      file = url
    elseif expand('%') != ''
      if &modified
        HTMLMessagesO.Warn(HTMLMessagesO.W_UNSAVED)
      endif

      # If we're on Cygwin or WSL2 and not using a text mode browser,
      # translate the file path to a Windows native path for later use,
      # otherwise just add the file:// prefix:
      if has('win32unix') == 1 && match(_TextModeBrowsers->keys(), $'^\c\V{which}\$') < 0
        file = 'file://' .. system(['cygpath', '-w', expand('%:p')])->trim()
      elseif HTMLUtilO.Has('WSL2')
          && match(_TextModeBrowsers->keys(), $'^\c\V{which}\$') < 0
        file = 'file://' .. system(['wslpath', '-w', expand('%:p')])->trim()
      else
        file = 'file://' .. expand('%:p')
      endif
    else
      HTMLMessagesO.Error(HTMLMessagesO.E_NOFILE)
      return false
    endif

    if has('unix') == 1 && $DISPLAY == ''
        && match(_TextModeBrowsers->keys(), $'^\c\V{which}\$') < 0
        && has('win32unix') == 0
      if _TextModeBrowsers->keys() == []
        HTMLMessagesO.Error(HTMLMessagesO.E_DISPLAY)
        return false
      else
        which = _TextModeBrowsers->keys()->sort('i')[0]
      endif
    endif

    # Have to handle the textmode browsers different than the GUI browsers:
    if match(_TextModeBrowsers->keys(), $'^\c\V{which}\$') >= 0
      var xterm: string

      HTMLMessagesO.Message('Launching ' .. _Browsers[which]['realname'] .. '...')

      if executable('/etc/alternatives/x-terminal-emulator')
        xterm = '/etc/alternatives/x-terminal-emulator'
      else
        xterm = exepath('xterm')
      endif

      if has('gui_running') == 1 || donew != Behavior.default
        if $DISPLAY != '' && xterm != '' && donew == Behavior.newwindow
          command = [xterm, '-e', _Browsers[which]['path'], file]
        elseif exists_compiled(':terminal') == 2
          execute 'terminal ++close ' .. _Browsers[which]['path'] .. ' ' .. file
          return true
        else
          if donew == Behavior.newwindow
            HTMLMessagesO.Error(printf(HTMLMessagesO.E_XTERM, _Browsers[which]['realname']))
          else
            HTMLMessagesO.Error(printf(HTMLMessagesO.E_TERM, _Browsers[which]['realname']))
          endif

          return false
        endif
      else
        execute '!' .. _Browsers[which]['path'] .. ' ' .. file->shellescape()

        if v:shell_error
          printf(HTMLMessagesO.E_LAUNCH, _Browsers[which]['realname'])->HTMLMessagesO.Error()
          return false
        endif

        return true
      endif
    endif

    # If we haven't already defined a command, we are going to use a GUI
    # browser:
    if command == []

      if donew == Behavior.newtab
        HTMLMessagesO.Message($'Opening new {HTMLUtilO.Cap(_Browsers[which]['realname'])} tab...')
        command = [
          _Browsers[which]['path'],
          file,
          _Browsers[which]['tab']
        ]
      elseif donew == Behavior.newwindow
        HTMLMessagesO.Message($'Opening new {HTMLUtilO.Cap(_Browsers[which]['realname'])} window...')
        command = [
          _Browsers[which]['path'],
          file,
          _Browsers[which]['window']
        ]
      else
        if which == 'default'
          HTMLMessagesO.Message('Invoking system default browser...')
        else
          HTMLMessagesO.Message($'Invoking {HTMLUtilO.Cap(_Browsers[which]['realname'])}...')
        endif

        command = [
          _Browsers[which]['path'],
          file
        ]
      endif
    endif

    if command != []
      if command[0] == ''
        if HTMLUtilO.Has('WSL2') || HTMLUtilO.Has('win')
          map(command, (_, val) => substitute(val, '^file://', '', ''))
          command = ['rundll32.exe', 'shell32.dll,ShellExec_RunDLL'] + command[1 : -1]
        else
          HTMLMessagesO.Error(HTMLMessagesO.E_NOCOMMAND)
          return false
        endif
      endif

      # Strip out useless command arguments:
      command->filter((_, v: string) => !empty(v))

      if has('unix') == 1
        command = ['nohup'] + command
      endif

      var job_id: job = job_start(command, {
        drop: 'auto',
        stoponexit: '',
        exit_cb: (_, exitstatus: number) => {
          if exitstatus > 0
            b:htmlplugin.HTMLMessagesO.Error($'Job exited abmormally: {exitstatus}')
          endif
        },
        callback: this._AddLogItem
      })

      if job_status(job_id) == 'fail'
        printf(HTMLMessagesO.E_COMMAND, command)->HTMLMessagesO.Error()
        return false
      endif

      return true
    endif

    HTMLMessagesO.E_FINAL->HTMLMessagesO.Error()
    return false
  enddef  # }}}1

  def _AddLogItem(channel: channel, msg: string): void  # {{{1
    _BrowserLog->add($'[{strftime("%c")}] channel {channel->ch_info()['id']}: {msg}')
  enddef
      
  def ShowBrowserLog(): void  # {{{1
    if _BrowserLog == []
      HTMLMessagesO.Message('No browser output to show.')
      return
    endif

    var logbuf: number = bufnr('\[BrowserLauncherLog\]')
    if logbuf == -1
      new [BrowserLauncherLog]
      setlocal buftype=nofile bufhidden=hide noswapfile filetype=log
    else
      var winid: number = bufwinnr(logbuf)
      if winid != -1
        execute $':{winid}wincmd w'
      else
        execute $'sbuffer {logbuf}'
      endif
      setlocal modifiable
    endif

    execute ':%d'
    append(0, _BrowserLog)
    setlocal nomodifiable
  enddef # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
