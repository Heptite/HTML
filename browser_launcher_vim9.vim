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
#
#  * This code is messy and needs to be rethought.

command! -nargs=+ BRCWARN :echohl WarningMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCMESG :echohl Todo | echo <q-args> | echohl None

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
      exec 'BRCERROR ' .. app .. " not found"
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
          exec 'BRCERROR ' .. as_msg
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
          exec 'BRCERROR ' .. as_msg

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
          exec 'BRCERROR ' .. as_msg

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
      exe 'BRCMESG Opening ' .. app->substitute('^.', '\U&', '') .. '...'
      command = "open -a " .. app .. " " .. shellescape(file)
    endif

    call system(command .. " 2>&1 >/dev/null")
  enddef # }}}

  finish

elseif has('unix') && ! has('win32unix') # {{{1

  var s:Browsers = dict<string>
  # Set this manually, since the first in the list is the default:
  var s:BrowsersExist = 'fcolw'
  s:Browsers['f'] = [['firefox', 'iceweasel'],               '']
  s:Browsers['c'] = [['google-chrome', 'chromium-browser'],  '']
  s:Browsers['o'] = ['opera',                                '']
  s:Browsers['l'] = ['lynx',                                 '']
  s:Browsers['w'] = ['w3m',                                  '']

  var temp1: string
  var temp2: string
  var temp3: string

  for temp1 in keys(s:Browsers)
    for temp2 in (type(s:Browsers[temp1][0]) == type([]) ? s:Browsers[temp1][0] : [s:Browsers[temp1][0]])
      var temp3 = system("which " .. temp2)
      if v:shell_error == 0
        break
      endif
    endfor

    if v:shell_error == 0
      s:Browsers[s:temp1][0] = temp2
      s:Browsers[s:temp1][1] = temp3->substitute("\n$", '', '')
    else
      s:BrowsersExist = s:BrowsersExist->substitute(temp1, '', 'g')
    endif
  endfor

elseif has('win32') || has('win64') || has('win32unix')  # {{{1

  # No reliably scriptable way to detect installed browsers, so just add
  # support for a few and let the Windows system complain if a browser
  # doesn't exist:
  var s:Browsers: dict<string>
  var s:BrowsersExist = 'fcoe'
  s:Browsers['f'] = ['firefox', '']
  s:Browsers['c'] = ['chrome',  '']
  s:Browsers['o'] = ['opera',   '']
  s:Browsers['e'] = ['msedge',  '']

  if has('win32unix')
    var temp: string
    temp = system("which lynx")
    if v:shell_error == 0
      s:BrowsersExist ..= 'l'
      s:Browsers['l'] = ['lynx', temp->substitute("\n$", '', '')]
    endif
    temp = system("which w3m")
    if v:shell_error == 0
      s:BrowsersExist ..= 'w'
      s:Browsers['w'] = ['w3m', temp->substitute("\n$", '', '')]
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
#  "0" - Failure (No browser was launched/controlled.)
#  "1" - Success
#
#  (Due to Vim9's typing, these are STRING values, and must be treated as
#  such!)
#
#  A special case of no arguments returns a character list of what browsers
#  were found.
def g:LaunchBrowser(browser: string = '', new: number = 0, url: string = ''): string

  if browser == '' && new == 0 && url == ''
    return s:BrowsersExist
  endif

  var which = browser
  var command = ''

  # If we're on Cygwin, translate the file path to a Windows native path
  # for later use, otherwise just add the file:// prefix:
  var file = 'file://' ..
      (has('win32unix') ?
         system('cygpath -w ' .. expand('%:p')->shellescape())->substitute("\n$", '', '') :
         expand('%:p'))

  if url != ''
    file = url
  endif

  if which ==? 'default' || which == ''
    which = s:BrowsersExist->strpart(0, 1)
  endif

  if s:BrowsersExist !~? which
    if exists('s:Browsers["' .. which .. '"]')
      exe 'BRCERROR '
            .. (s:Browsers[which][0]->type() == type([]) ? s:Browsers[which][0][0] : s:Browsers[which][0])
            .. ' not found'
    else
      exe 'BRCERROR Unknown browser ID: ' .. which
    endif

    return "0"
  endif

  if has('unix') && ! has('win32unix') && strlen($DISPLAY) == 0
    if exists('s:Browsers["l"]')
      which = 'l'
    elseif exists('s:Browsers["w"]')
      which = 'w'
    else
      BRCERROR $DISPLAY is not set and Lynx and w3m are not found, no browser launched.
      return "0"
    endif
  endif

  if (which ==? 'l') # {{{
    BRCMESG Launching lynx...

    if (has("gui_running") || new > 0) && strlen($DISPLAY) > 0
      command = 'xterm -T Lynx -e ' .. s:Browsers['l'][1] .. ' ' .. shellescape(file) .. ' &'
    else
      sleep 1
      execute "!" .. s:Browsers['l'][1] .. " " .. shellescape(file)

      if v:shell_error
        BRCERROR Unable to launch lynx.
        return "0"
      endif
    endif
  endif # }}}

  if (which ==? 'w') # {{{
    BRCMESG Launching w3m...

    if (has("gui_running") || new > 0) && strlen($DISPLAY) > 0
      command = 'xterm -T w3m -e w3m ' .. shellescape(file) .. ' &'
    else
      sleep 1
      execute "!w3m " .. shellescape(file)

      if v:shell_error
        BRCERROR Unable to launch w3m.
        return "0"
      endif
    endif
  endif # }}}

  if (which ==? 'o') # {{{
    if new == 2
      BRCMESG Opening new Opera tab...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    elseif new > 0
      BRCMESG Opening new Opera window...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file) .. ' --new-window'
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " --new-window &\""
      endif
    else
      BRCMESG Sending remote command to Opera...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    endif
  endif # }}}

  if (which ==? 'c') # {{{
    if new == 2
      BRCMESG Opening new Chrome tab...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    elseif new > 0
      BRCMESG Opening new Chrome window...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file) .. ' --new-window'
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " --new-window &\""
      endif
    else
      BRCMESG Sending remote command to Chrome...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    endif
  endif # }}}

  if (which ==? 'e') # {{{
    if new == 2
      BRCMESG Opening new Edge tab...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    elseif new > 0
      BRCMESG Opening new Edge window...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file) .. ' --new-window'
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " --new-window &\""
      endif
    else
      BRCMESG Sending remote command to Edge...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    endif
  endif # }}}

  if (which ==? 'f') # {{{
    if new == 2
      BRCMESG Opening new Firefox tab...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' --new-tab ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " --new-tab " .. shellescape(file) .. " &\""
      endif
    elseif new > 0
      BRCMESG Opening new Firefox window...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' --new-window ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " --new-window " .. shellescape(file) .. " &\""
      endif
    else
      BRCMESG Sending remote command to Firefox...
      if has('win32') || has('win64') || has('win32unix')
        command = 'start ' .. s:Browsers[which][0] .. ' ' .. shellescape(file)
      else
        command = "sh -c \"trap '' HUP; " .. s:Browsers[which][1] .. " " .. shellescape(file) .. " &\""
      endif
    endif
  endif # }}}

  if command != ''

    if has('win32unix')
      # Change "start" to "cygstart":
      command = 'cyg' .. command
    endif

    call system(command)

    if v:shell_error
      exe 'BRCERROR Command failed: ' .. command
      return "0"
    endif

    return "1"
  endif

  BRCERROR Something went wrong, we should not ever get here...
  return "0"
enddef # }}}1

# vim: set ts=2 sw=0 et ai nu tw=75 fo=croq2 fdm=marker fdc=4 cms=\ #\ %s:
