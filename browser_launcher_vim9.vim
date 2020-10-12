vim9script

# --------------------------------------------------------------------------
#
# Vim script to launch/control browsers
#
# Copyright ????-2020 Christian J. Robinson <heptite@gmail.com>
#
# Distributable under the terms of the GNU GPL.
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
#  - Plus lynx & w3m on Cygwin if they can be found.
#
# TODO:
#
#  - Support more browsers, especially on MacOS
#    Note: Various browsers such as Galeon, Nautilus, Phoenix, &c use the
#    same HTML rendering engine as Firefox, so supporting them isn't as
#    important. Others use the same engine as Chrome/Chromium (Opera?).
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
#    browsers are installed so a few are defined automatically.

# if v:version < 900
#   finish
# endif

command! -nargs=+ BRCWARN :echohl WarningMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCMESG :echohl Todo | echo <q-args> | echohl None

# Allow auto-scoping to work properly for Vim 9,
# initialize these variables here:
var Browsers: dict<list<any>>
var BrowsersExist: string

if has('mac') || has('macunix')  # {{{1
  if exists("*g:OpenInMacApp")
    finish
  endif

  # The following code is provided by Israel Chauca Fuentes
  # <israelvarios()fastmail!fm>:

  def s:MacAppExists(app: string): bool # {{{
    silent! call system("/usr/bin/osascript -e 'get id of application \"" ..
        app .. "\"' 2>&1 >/dev/null")
    if v:shell_error
      return 0
    endif
    return 1
  enddef # }}}

  def s:UseAppleScript(): string # {{{
    return system("/usr/bin/osascript -e " ..
       "'tell application \"System Events\" to set UI_enabled " ..
       "to UI elements enabled' 2>/dev/null") ==? "true\n" ? 1 : 0
  enddef # }}}

  def g:OpenInMacApp(app: string, new: number = 0): bool # {{{
    if (! s:MacAppExists(app) && app !=? 'default')
      execute 'BRCERROR ' .. app .. " not found"
      return 0
    endif

    var file = expand('%:p')

    # Can we open new tabs and windows?
    var use_AS = s:UseAppleScript()

    # Why we can't open new tabs and windows:
    var as_msg = "This feature utilizes the built-in Graphic User " ..
        "Interface Scripting architecture of Mac OS X which is " ..
        "currently disabled. You can activate GUI Scripting by " ..
        "selecting the checkbox \"Enable access for assistive " ..
        "devices\" in the Universal Access preference pane."

    var torn: string
    var script: string
    var command: string

    if (app ==? 'safari') # {{{
      if new != 0 && use_AS
        if new == 2
          torn = 't'
          BRCMESG Opening file in new Safari tab...
        else
          torn = 'n'
          BRCMESG Opening file in new Safari window...
        endif
        script = '-e "tell application \"safari\"" ' ..
                 '-e "activate" ' ..
                 '-e "tell application \"System Events\"" ' ..
                 '-e "tell process \"safari\"" ' ..
                 '-e "keystroke \"' .. torn .. '\" using {command down}" ' ..
                 '-e "end tell" ' ..
                 '-e "end tell" ' ..
                 '-e "delay 0.3" ' ..
                 '-e "tell window 1" ' ..
                 '-e ' .. shellescape("set (URL of last tab) to \"" .. file .. "\"") .. ' ' ..
                 '-e "end tell" ' ..
                 '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know what's going on:
          execute 'BRCERROR ' .. as_msg
        endif
        BRCMESG Opening file in Safari...
        command = "/usr/bin/open -a safari " .. shellescape(file)
      endif
    endif "}}}

    if (app ==? 'firefox') # {{{
      if new != 0 && use_AS
        if new == 2

          torn = 't'
          BRCMESG Opening file in new Firefox tab...
        else

          torn = 'n'
          BRCMESG Opening file in new Firefox window...
        endif
        script = '-e "tell application \"firefox\"" ' ..
                 '-e "activate" ' ..
                 '-e "tell application \"System Events\"" ' ..
                 '-e "tell process \"firefox\"" ' ..
                 '-e "keystroke \"' .. torn .. '\" using {command down}" ' ..
                 '-e "delay 0.8" ' ..
                 '-e "keystroke \"l\" using {command down}" ' ..
                 '-e "keystroke \"a\" using {command down}" ' ..
                 '-e ' .. shellescape("keystroke \"" .. file .. "\" & return") .. " " ..
                 '-e "end tell" ' ..
                 '-e "end tell" ' ..
                 '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know wath's going on:
          execute 'BRCERROR ' .. as_msg

        endif
        BRCMESG Opening file in Firefox...
        command = "/usr/bin/open -a firefox " .. shellescape(file)
      endif
    endif # }}}

    if (app ==? 'opera') # {{{
      if new != 0 && use_AS
        if new == 2

          torn = 't'
          BRCMESG Opening file in new Opera tab...
        else

          torn = 'n'
          BRCMESG Opening file in new Opera window...
        endif
        script = '-e "tell application \"Opera\"" ' ..
                 '-e "activate" ' ..
                 '-e "tell application \"System Events\"" ' ..
                 '-e "tell process \"opera\"" ' ..
                 '-e "keystroke \"' .. torn .. '\" using {command down}" ' ..
                 '-e "end tell" ' ..
                 '-e "end tell" ' ..
                 '-e "delay 0.5" ' ..
                 '-e ' .. shellescape("set URL of front document to \"" .. file .. "\"") .. " " ..
                 '-e "end tell" '

        command = "/usr/bin/osascript " .. script

      else
        if new != 0
          # Let the user know what's going on:
          execute 'BRCERROR ' .. as_msg

        endif
        BRCMESG Opening file in Opera...
        command = "/usr/bin/open -a opera " .. shellescape(file)
      endif
    endif # }}}

    if (app ==? 'default')
      BRCMESG Opening file in default browser...
      command = "/usr/bin/open " .. shellescape(file)
    endif

    if (command == '')
      execute 'BRCMESG Opening ' .. app->substitute('^.', '\U&', '') .. '...'
      command = "open -a " .. app .. " " .. shellescape(file)
    endif

    call system(command .. " 2>&1 >/dev/null")
  enddef # }}}

  finish

elseif has('unix') && ! has('win32unix') # {{{1

  # Set this manually, since the first in the list is the default:
  BrowsersExist = 'fcolw'
  Browsers['f'] = [['firefox', 'iceweasel'],               '', '', '--new-tab', '--new-window']
  Browsers['c'] = [['google-chrome', 'chromium-browser'],  '', '', '',          '--new-window']
  Browsers['o'] = ['opera',                                '', '', '',          '--new-window']
  Browsers['l'] = ['lynx',                                 '', '', '',          '']
  Browsers['w'] = ['w3m',                                  '', '', '',          '']

  var temp1: string
  var temp2: string
  var temp3: string

  for temp1 in keys(Browsers)
    for temp2 in (type(Browsers[temp1][0]) == type([]) ? Browsers[temp1][0] : [Browsers[temp1][0]])
      temp3 = system("which " .. temp2)
      if v:shell_error == 0
        break
      endif
    endfor

    if v:shell_error == 0
      Browsers[s:temp1][0] = temp2
      Browsers[s:temp1][1] = temp3->substitute("\n$", '', '')
    else
      BrowsersExist = BrowsersExist->substitute(temp1, '', 'g')
    endif
  endfor

elseif has('win32') || has('win64') || has('win32unix')  # {{{1

  # No reliably scriptable way to detect installed browsers, so just add
  # support for a few and let the Windows system complain if a browser
  # doesn't exist:
  BrowsersExist = 'fcoe'
  Browsers['f'] = ['firefox', '', '', '--new-tab', '--new-window']
  Browsers['c'] = ['chrome',  '', '', '',          '--new-window']
  Browsers['o'] = ['opera',   '', '', '',          '--new-window']
  Browsers['e'] = ['msedge',  '', '', '',          '--new-window']

  if has('win32unix')
    var temp: string
    temp = system("which lynx")
    if v:shell_error == 0
      BrowsersExist ..= 'l'
      Browsers['l'] = ['lynx', temp->substitute("\n$", '', ''), '', '', '']
    endif
    temp = system("which w3m")
    if v:shell_error == 0
      BrowsersExist ..= 'w'
      Browsers['w'] = ['w3m', temp->substitute("\n$", '', ''), '', '', '']
    endif
  endif

else # {{{1

  BRCWARN Your OS is not recognized, browser controls will not work.

  finish

endif # }}}1

if exists("*g:LaunchBrowser")
  finish
endif

# LaunchBrowser() {{{1
#
# Usage:
#  :call LaunchBrowser([{.../default}], [{0/1/2}], [url])
#    The first argument is which browser to launch, by letter, see the
#    dictionary defined above to see which ones are available, or:
#      default - This launches the first browser that was actually found.
#                (This isn't actually used, and may go away in the future.)
#
#    The second argument is whether to launch a new window:
#      0 - No
#      1 - Yes
#      2 - New Tab (or new window if the browser doesn't provide a way to
#                   open a new tab)
#
#    The optional third argument is an URL to go to instead of loading the
#    current file.
#
# Return value:
#  false - Failure (No browser was launched/controlled.)
#  true  - Success
#
#  A special case of no arguments returns a character list of what browsers
#  were found.
def g:LaunchBrowser(browser: string = '', new: number = 0, url: string = ''): any

  if browser == '' && new == 0 && url == ''
    return BrowsersExist
  endif

  var which = browser
  var command = ''

  if which ==? 'default' || which == ''
    which = BrowsersExist->strpart(0, 1)
  endif

  # If we're on Cygwin and not using lynx or w3m, translate the file path
  # to a Windows native path for later use, otherwise just add the file://
  # prefix:
  var file = 'file://' ..
      (has('win32unix') && which !~ '\c[lw]' ?
         system('cygpath -w ' .. expand('%:p')->shellescape())->substitute("\n$", '', '') :
         expand('%:p'))

  if url != ''
    file = url
  endif

  if BrowsersExist !~ which
    if exists('Browsers["' .. which .. '"]')
      execute 'BRCERROR '
            .. (Browsers[which][0]->type() == type([]) ? Browsers[which][0][0] : Browsers[which][0])
            .. ' not found'
    else
      execute 'BRCERROR Unknown browser ID: ' .. which
    endif

    return false
  endif

  if has('unix') == 1 && strlen($DISPLAY) == 0 && has('win32unix') == 0
    if exists('Browsers["l"]')
      which = 'l'
    elseif exists('Browsers["w"]')
      which = 'w'
    else
      BRCERROR $DISPLAY is not set and Lynx and w3m are not found, no browser launched.
      return false
    endif
  endif

  if which =~ '\c[lw]'
    execute "BRCMESG Launching " .. Browsers['l'][0] .. "..."

    if (has("gui_running") || new > 0) && strlen($DISPLAY) > 0
      command = 'xterm -T ' .. Browsers['l'][0] .. ' -e ' ..
        Browsers['l'][1] .. ' ' .. shellescape(file) .. ' &'
    else
      sleep 1
      execute "!" .. Browsers['l'][1] .. " " .. shellescape(file)

      if v:shell_error
        execute "BRCERROR Unable to launch " .. Browsers['l'][0] .. "."
        return false
      endif

      return true
    endif
  endif

  if command == ''
    if new == 2
      execute "BRCMESG Opening new " .. Browsers[which][0]->s:Cap() .. " tab..."
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file) ..
          ' ' .. Browsers[which][3] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. " " ..
          shellescape(file) .. ' ' .. Browsers[which][3]  .. " &\""
      endif
    elseif new > 0
      execute "BRCMESG Opening new " .. Browsers[which][0]->s:Cap() .. " window..."
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file) ..
          ' ' .. Browsers[which][4] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. " " ..
          shellescape(file) .. ' ' .. Browsers[which][4]  .. " &\""
      endif
    else
      execute "BRCMESG Sending remote command to " .. Browsers[which][0]->s:Cap() .. "..."
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. Browsers[which][0] .. ' ' .. shellescape(file) ..
          ' ' .. Browsers[which][2] 
      else
        command = "sh -c \"trap '' HUP; " .. Browsers[which][1] .. " " ..
          shellescape(file) .. ' ' .. Browsers[which][2]  .. " &\""
      endif
    endif
  endif

  if command != ''

    if has('win32unix')
      command = command->substitute('^start', 'cygstart', '')
    endif

    call system(command)

    if v:shell_error
      execute 'BRCERROR Command failed: ' .. command
      return false
    endif

    return true
  endif

  BRCERROR Something went wrong, we should not ever get here...
  return false
enddef # }}}1

def s:Cap(arg: string): string
  return arg->substitute('\<.', '\U&', 'g')
enddef

# vim: set ts=2 sw=0 et ai nu tw=75 fo=croq2 fdm=marker fdc=4 cms=\ #\ %s: