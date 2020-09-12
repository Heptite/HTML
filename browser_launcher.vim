"--------------------------------------------------------------------------
"
" Vim script to launch/control browsers
"
" Copyright ????-2020 Christian J. Robinson <heptite@gmail.com>
"
" Distributable under the terms of the GNU GPL.
"
" Currently supported browsers:
" Unix:
"  - Firefox  (remote [new window / new tab] / launch)
"    (This will fall back to Iceweasel for Debian installs.)
"  - Chrome   (remote [new window / new tab] / launch)
"    (This will fall back to Chromium if it's installed and Chrome isn't.)
"  - Opera    (remote [new window / new tab] / launch)
"  - Lynx     (Under the current TTY if not running the GUI, or a new xterm
"              window if DISPLAY is set.)
"  - w3m      (Under the current TTY if not running the GUI, or a new xterm
"              window if DISPLAY is set.)
" MacOS:
"  - Firefox  (remote [new window / new tab] / launch)
"  - Opera    (remote [new window / new tab] / launch)
"  - Safari   (remote [new window / new tab] / launch)
"  - Default
"
" Windows and Cygwin:
"  - Firefox  (remote [new window / new tab] / launch)
"  - Opera    (remote [new window / new tab] / launch)
"  - Chrome   (remote [new window / new tab] / launch)
"
" TODO:
"
"  - Support more browsers, especially on MacOS
"    Note: Various browsers such as Galeon, Nautilus, Phoenix, &c use the
"    same HTML rendering engine as Firefox, so supporting them isn't as
"    important. Others use the same engine as Chrome/Chromium (Opera?).
"
"  - Defaulting to Lynx if the the GUI isn't available on Unix may be
"    undesirable.
"
" BUGS:
"  * On Unix, since the commands to start the browsers are run in the
"    backgorund when possible there's no way to actually get v:shell_error,
"    so execution errors aren't actually seen.
"
"  * On Windows (and Cygwin) there's no reliable way to detect which
"    browsers are installed so a few are defined automatically.
"
"  * This code is messy and needs to be rethought.
"
"--------------------------------------------------------------------------
" $Id: browser_launcher.vim,v 1.28 2020/09/12 03:00:48 Heptite Exp $
"--------------------------------------------------------------------------

if v:version < 8
	finish
endif

command! -nargs=+ BRCWARN :echohl WarningMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCMESG :echohl Todo | echo <q-args> | echohl None

function! s:ShellEscape(str) " {{{
	if exists('*shellescape')
		return shellescape(a:str)
	else
		return "'" . a:str->substitute("'", "'\\\\''", 'g') . "'"
	endif
endfunction " }}}


if has('mac') || has('macunix')  " {{{1
	if exists("*OpenInMacApp")
		finish
	endif

	" The following code is provided by Israel Chauca Fuentes
	" <israelvarios()fastmail!fm>:

	function! s:MacAppExists(app) " {{{
		 silent! call system("/usr/bin/osascript -e 'get id of application \"" .
				\ a:app . "\"' 2>&1 >/dev/null")
		if v:shell_error
			return 0
		endif
		return 1
	endfunction " }}}

	function! s:UseAppleScript() " {{{
		return system("/usr/bin/osascript -e " .
			 \ "'tell application \"System Events\" to set UI_enabled " .
			 \ "to UI elements enabled' 2>/dev/null") ==? "true\n" ? 1 : 0
	endfunction " }}}

	function! OpenInMacApp(app, ...) " {{{
		if (! s:MacAppExists(a:app) && a:app !=? 'default')
			exec 'BRCERROR ' . a:app . " not found"
			return 0
		endif

		if a:0 >= 1 && a:0 <= 2
			let l:new = a:1
		else
			let l:new = 0
		endif

		let l:file = expand('%:p')

		" Can we open new tabs and windows?
		let l:use_AS = s:UseAppleScript()

		" Why we can't open new tabs and windows:
		let l:as_msg = "This feature utilizes the built-in Graphic User " .
				\ "Interface Scripting architecture of Mac OS X which is " .
				\ "currently disabled. You can activate GUI Scripting by " .
				\ "selecting the checkbox \"Enable access for assistive " .
				\ "devices\" in the Universal Access preference pane."

		if (a:app ==? 'safari') " {{{
			if l:new != 0 && l:use_AS
				if l:new == 2
					let l:torn = 't'
					BRCMESG Opening file in new Safari tab...
				else
					let l:torn = 'n'
					BRCMESG Opening file in new Safari window...
				endif
				let l:script = '-e "tell application \"safari\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"safari\"" ' .
				\ '-e "keystroke \"' . torn . '\" using {command down}" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "delay 0.3" ' .
				\ '-e "tell window 1" ' .
				\ '-e ' . s:ShellEscape("set (URL of last tab) to \"" . l:file . "\"") . ' ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" '

				let l:command = "/usr/bin/osascript " . script

			else
				if l:new != 0
					" Let the user know what's going on:
					exec 'BRCERROR ' . l:as_msg
				endif
				BRCMESG Opening file in Safari...
				let l:command = "/usr/bin/open -a safari " . s:ShellEscape(l:file)
			endif
		endif "}}}

		if (a:app ==? 'firefox') " {{{
			if l:new != 0 && l:use_AS
				if l:new == 2

					let l:torn = 't'
					BRCMESG Opening file in new Firefox tab...
				else

					let l:torn = 'n'
					BRCMESG Opening file in new Firefox window...
				endif
				let l:script = '-e "tell application \"firefox\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"firefox\"" ' .
				\ '-e "keystroke \"' . l:torn . '\" using {command down}" ' .
				\ '-e "delay 0.8" ' .
				\ '-e "keystroke \"l\" using {command down}" ' .
				\ '-e "keystroke \"a\" using {command down}" ' .
				\ '-e ' . s:ShellEscape("keystroke \"" . l:file . "\" & return") . " " .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" '

				let l:command = "/usr/bin/osascript " . script

			else
				if l:new != 0
					" Let the user know wath's going on:
					exec 'BRCERROR ' . l:as_msg

				endif
				BRCMESG Opening file in Firefox...
				let l:command = "/usr/bin/open -a firefox " . s:ShellEscape(l:file)
			endif
		endif " }}}

		if (a:app ==? 'opera') " {{{
			if l:new != 0 && l:use_AS
				if l:new == 2

					let l:torn = 't'
					BRCMESG Opening file in new Opera tab...
				else

					let l:torn = 'n'
					BRCMESG Opening file in new Opera window...
				endif
				let l:script = '-e "tell application \"Opera\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"opera\"" ' .
				\ '-e "keystroke \"' . l:torn . '\" using {command down}" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "delay 0.5" ' .
				\ '-e ' . s:ShellEscape("set URL of front document to \"" . l:file . "\"") . " " .
				\ '-e "end tell" '

				let l:command = "/usr/bin/osascript " . l:script

			else
				if l:new != 0
					" Let the user know what's going on:
					exec 'BRCERROR ' . l:as_msg

				endif
				BRCMESG Opening file in Opera...
				let l:command = "/usr/bin/open -a opera " . s:ShellEscape(l:file)
			endif
		endif " }}}

		if (a:app ==? 'default')

			BRCMESG Opening file in default browser...
			let l:command = "/usr/bin/open " . s:ShellEscape(l:file)
		endif

		if (! exists('command'))

			exe 'BRCMESG Opening ' . a:app->substitute('^.', '\U&', '') . '...'
			let l:command = "open -a " . a:app . " " . s:ShellEscape(l:file)
		endif

		call system(command . " 2>&1 >/dev/null")
	endfunction " }}}

	finish

elseif has('unix') && ! has('win32unix') " {{{1

	let s:Browsers = {}
	" Set this manually, since the first in the list is the default:
	let s:BrowsersExist = 'fcolw'
	let s:Browsers['f'] = [['firefox', 'iceweasel'],               '']
	let s:Browsers['c'] = [['google-chrome', 'chromium-browser'],  '']
	let s:Browsers['o'] = ['opera',                                '']
	let s:Browsers['l'] = ['lynx',                                 '']
	let s:Browsers['w'] = ['w3m',                                  '']

	for s:temp1 in keys(s:Browsers)
		for s:temp2 in (type(s:Browsers[s:temp1][0]) == type([]) ? s:Browsers[s:temp1][0] : [s:Browsers[s:temp1][0]])
			let s:temp3 = system("which " . s:temp2)
			if v:shell_error == 0
				break
			endif
		endfor

		if v:shell_error == 0
			let s:Browsers[s:temp1][0] = s:temp2
			let s:Browsers[s:temp1][1] = s:temp3->substitute("\n$", '', '')
		else
			let s:BrowsersExist = s:BrowsersExist->substitute(s:temp1, '', 'g')
		endif
	endfor

	"for [key, value] in s:Browsers->items()
	"	echomsg key . ': ' . join(value, ', ')
	"endfor

	unlet s:temp1 s:temp2 s:temp3

elseif has('win32') || has('win64') || has('win32unix')  " {{{1

	" No reliably scriptable way to detect installed browsers, so just add
	" support for a few and let the Windows system complain if a browser
	" doesn't exist:
	let s:Browsers = {}
	let s:BrowsersExist = 'fco'
	let s:Browsers['f'] = ['firefox', '']
	let s:Browsers['c'] = ['chrome',  '']
	let s:Browsers['o'] = ['opera',   '']
	
else " {{{1

	BRCWARN Your OS is not recognized, browser controls will not work.

	finish

endif " }}}1

if exists("*LaunchBrowser")
	finish
endif

" LaunchBrowser() {{{1
"
" Usage:
"  :call LaunchBrowser({[fcolw] | default}, {[012]}, [url])
"    The first argument is which browser to launch:
"      f - Firefox
"      c - Chrome
"      o - Opera
"      l - Lynx
"      w - w3m
"
"      default - This launches the first browser that was actually found.
"                (This isn't actually used, and may go away in the future.)
"
"    The second argument is whether to launch a new window:
"      0 - No
"      1 - Yes
"      2 - New Tab (or new window if the browser doesn't provide a way to
"                   open a new tab)
"
"    The optional third argument is an URL to go to instead of loading the
"    current file.
"
" Return value:
"  0 - Failure (No browser was launched/controlled.)
"  1 - Success
"
" A special case of no arguments returns a character list of what browsers
" were found.
function! LaunchBrowser(...)

	let l:err = 0

	if a:0 == 0
		return s:BrowsersExist
	elseif a:0 >= 2
		let l:which = a:1
		let l:new = a:2
	else
		let l:err = 1
	endif

	" If we're on Cygwin, translate the file path to a Windows native path
	" for later use, otherwise just add the file:// prefix:
	let l:file = 'file://' .
			\(has('win32unix') ?
				\ system('cygpath -w ' . expand('%:p')->s:ShellEscape())->substitute("\n$", '', '') :
				\ expand('%:p')
			\)

	if a:0 == 3
		let l:file = a:3
	elseif a:0 > 3
		let l:err = 1
	endif

	if l:err
		exe 'BRCERROR E119: Wrong number of arguments for function: '
					\ . expand('<sfile>')->substitute('^function ', '', '')
		return 0
	endif

	if l:which ==? 'default'
		let l:which = s:BrowsersExist->strpart(0, 1)
	endif

	if s:BrowsersExist !~? l:which
		if exists('s:Browsers[l:which]')
			exe 'BRCERROR '
						\ . (s:Browsers[l:which][0]->type() == type([]) ? s:Browsers[l:which][0][0] : s:Browsers[l:which][0])
						\ . ' not found'
		else
			exe 'BRCERROR Unknown browser ID: ' . l:which
		endif

		return 0
	endif

	if has('unix') && (! strlen($DISPLAY) || l:which ==? 'l') " {{{
		BRCMESG Launching lynx...

		if (has("gui_running") || l:new) && strlen($DISPLAY)
			let l:command='xterm -T Lynx -e lynx ' . s:ShellEscape(l:file) . ' &'
		else
			sleep 1
			execute "!lynx " . s:ShellEscape(l:file)

			if v:shell_error
				BRCERROR Unable to launch lynx.
				return 0
			endif
		endif
	endif " }}}

	if has('unix') && (l:which ==? 'w') " {{{
		BRCMESG Launching w3m...

		if (has("gui_running") || l:new) && strlen($DISPLAY)
			let l:command='xterm -T w3m -e w3m ' . s:ShellEscape(l:file) . ' &'
		else
			sleep 1
			execute "!w3m " . s:ShellEscape(l:file)

			if v:shell_error
				BRCERROR Unable to launch w3m.
				return 0
			endif
		endif
	endif " }}}

	if (l:which ==? 'o') " {{{
		if l:new == 2
			BRCMESG Opening new Opera tab...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " &\""
			endif
		elseif l:new
			BRCMESG Opening new Opera window...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file) . ' --new-window'
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " --new-window &\""
			endif
		else
			BRCMESG Sending remote command to Opera...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " &\""
			endif
		endif
	endif " }}}

	if (l:which ==? 'c') " {{{
		if l:new == 2
			BRCMESG Opening new Chrome tab...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " &\""
			endif
		elseif l:new
			BRCMESG Opening new Chrome window...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file) . ' --new-window'
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " --new-window &\""
			endif
		else
			BRCMESG Sending remote command to Chrome...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " &\""
			endif
		endif
	endif " }}}

	if (l:which ==? 'f') " {{{
		if l:new == 2
			BRCMESG Opening new Firefox tab...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' --new-tab ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " --new-tab " . s:ShellEscape(l:file) . " &\""
			endif
		elseif l:new
			BRCMESG Opening new Firefox window...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' --new-window ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " --new-window " . s:ShellEscape(l:file) . " &\""
			endif
		else
			BRCMESG Sending remote command to Firefox...
			if has('win32') || has('win64') || has('win32unix')
				let l:command='start ' . s:Browsers[l:which][0] . ' ' . <SID>ShellEscape(l:file)
			else
				let l:command="sh -c \"trap '' HUP; " . s:Browsers[l:which][1] . " " . s:ShellEscape(l:file) . " &\""
			endif
		endif
	endif " }}}

	if exists('l:command')

		if has('win32unix')
			" Change "start" to "cygstart":
			let l:command='cyg' . l:command
		endif

		"echomsg l:command
		call system(l:command)

		"if has('unix') && v:shell_error
		if v:shell_error
			exe 'BRCERROR Command failed: ' . l:command
			return 0
		endif

		return 1
	endif

	BRCERROR Something went wrong, we should not ever get here...
	return 0
endfunction " }}}1

" vim: set ts=2 sw=2 ai nu tw=75 fo=croq2 fdm=marker fdc=4:
