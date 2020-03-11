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
" $Id: browser_launcher.vim,v 1.27 2020/02/02 21:41:17 Heptite Exp $
"--------------------------------------------------------------------------

if v:version < 702
	finish
endif

command! -nargs=+ BRCWARN :echohl WarningMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCERROR :echohl ErrorMsg | echomsg <q-args> | echohl None
command! -nargs=+ BRCMESG :echohl Todo | echo <q-args> | echohl None

function! s:ShellEscape(str) " {{{
	if exists('*shellescape')
		return shellescape(a:str)
	else
		return "'" . substitute(a:str, "'", "'\\\\''", 'g') . "'"
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
			let new = a:1
		else
			let new = 0
		endif

		let file = expand('%:p')

		" Can we open new tabs and windows?
		let use_AS = s:UseAppleScript()

		" Why we can't open new tabs and windows:
		let as_msg = "This feature utilizes the built-in Graphic User " .
				\ "Interface Scripting architecture of Mac OS X which is " .
				\ "currently disabled. You can activate GUI Scripting by " .
				\ "selecting the checkbox \"Enable access for assistive " .
				\ "devices\" in the Universal Access preference pane."

		if (a:app ==? 'safari') " {{{
			if new != 0 && use_AS
				if new == 2
					let torn = 't'
					BRCMESG Opening file in new Safari tab...
				else
					let torn = 'n'
					BRCMESG Opening file in new Safari window...
				endif
				let script = '-e "tell application \"safari\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"safari\"" ' .
				\ '-e "keystroke \"' . torn . '\" using {command down}" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "delay 0.3" ' .
				\ '-e "tell window 1" ' .
				\ '-e ' . s:ShellEscape("set (URL of last tab) to \"" . file . "\"") . ' ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" '

				let command = "/usr/bin/osascript " . script

			else
				if new != 0
					" Let the user know what's going on:
					exec 'BRCERROR ' . as_msg
				endif
				BRCMESG Opening file in Safari...
				let command = "/usr/bin/open -a safari " . s:ShellEscape(file)
			endif
		endif "}}}

		if (a:app ==? 'firefox') " {{{
			if new != 0 && use_AS
				if new == 2

					let torn = 't'
					BRCMESG Opening file in new Firefox tab...
				else

					let torn = 'n'
					BRCMESG Opening file in new Firefox window...
				endif
				let script = '-e "tell application \"firefox\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"firefox\"" ' .
				\ '-e "keystroke \"' . torn . '\" using {command down}" ' .
				\ '-e "delay 0.8" ' .
				\ '-e "keystroke \"l\" using {command down}" ' .
				\ '-e "keystroke \"a\" using {command down}" ' .
				\ '-e ' . s:ShellEscape("keystroke \"" . file . "\" & return") . " " .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" '

				let command = "/usr/bin/osascript " . script

			else
				if new != 0
					" Let the user know wath's going on:
					exec 'BRCERROR ' . as_msg

				endif
				BRCMESG Opening file in Firefox...
				let command = "/usr/bin/open -a firefox " . s:ShellEscape(file)
			endif
		endif " }}}

		if (a:app ==? 'opera') " {{{
			if new != 0 && use_AS
				if new == 2

					let torn = 't'
					BRCMESG Opening file in new Opera tab...
				else

					let torn = 'n'
					BRCMESG Opening file in new Opera window...
				endif
				let script = '-e "tell application \"Opera\"" ' .
				\ '-e "activate" ' .
				\ '-e "tell application \"System Events\"" ' .
				\ '-e "tell process \"opera\"" ' .
				\ '-e "keystroke \"' . torn . '\" using {command down}" ' .
				\ '-e "end tell" ' .
				\ '-e "end tell" ' .
				\ '-e "delay 0.5" ' .
				\ '-e ' . s:ShellEscape("set URL of front document to \"" . file . "\"") . " " .
				\ '-e "end tell" '

				let command = "/usr/bin/osascript " . script

			else
				if new != 0
					" Let the user know what's going on:
					exec 'BRCERROR ' . as_msg

				endif
				BRCMESG Opening file in Opera...
				let command = "/usr/bin/open -a opera " . s:ShellEscape(file)
			endif
		endif " }}}

		if (a:app ==? 'default')

			BRCMESG Opening file in default browser...
			let command = "/usr/bin/open " . s:ShellEscape(file)
		endif

		if (! exists('command'))

			exe 'BRCMESG Opening ' . substitute(a:app, '^.', '\U&', '') . '...'
			let command = "open -a " . a:app . " " . s:ShellEscape(file)
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
			let s:Browsers[s:temp1][1] = substitute(s:temp3, "\n$", '', '')
		else
			let s:BrowsersExist = substitute(s:BrowsersExist, s:temp1, '', 'g')
		endif
	endfor

	"for [key, value] in items(s:Browsers)
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

	let err = 0

	if a:0 == 0
		return s:BrowsersExist
	elseif a:0 >= 2
		let which = a:1
		let new = a:2
	else
		let err = 1
	endif

	" If we're on Cygwin, translate the file path to a Windows native path
	" for later use, otherwise just add the file:// prefix:
	let file = 'file://' .
			\(has('win32unix') ?
				\ substitute(system('cygpath -w ' . s:ShellEscape(expand('%:p'))), "\n$", '', '') :
				\ expand('%:p')
			\)

	if a:0 == 3
		let file = a:3
	elseif a:0 > 3
		let err = 1
	endif

	if err
		exe 'BRCERROR E119: Wrong number of arguments for function: '
					\ . substitute(expand('<sfile>'), '^function ', '', '')
		return 0
	endif

	if which ==? 'default'
		let which = strpart(s:BrowsersExist, 0, 1)
	endif

	if s:BrowsersExist !~? which
		if exists('s:Browsers[which]')
			exe 'BRCERROR '
						\ . (type(s:Browsers[which][0]) == type([]) ? s:Browsers[which][0][0] : s:Browsers[which][0])
						\ . ' not found'
		else
			exe 'BRCERROR Unknown browser ID: ' . which
		endif

		return 0
	endif

	if has('unix') && (! strlen($DISPLAY) || which ==? 'l') " {{{
		BRCMESG Launching lynx...

		if (has("gui_running") || new) && strlen($DISPLAY)
			let command='xterm -T Lynx -e lynx ' . s:ShellEscape(file) . ' &'
		else
			sleep 1
			execute "!lynx " . s:ShellEscape(file)

			if v:shell_error
				BRCERROR Unable to launch lynx.
				return 0
			endif
		endif
	endif " }}}

	if has('unix') && (which ==? 'w') " {{{
		BRCMESG Launching w3m...

		if (has("gui_running") || new) && strlen($DISPLAY)
			let command='xterm -T w3m -e w3m ' . s:ShellEscape(file) . ' &'
		else
			sleep 1
			execute "!w3m " . s:ShellEscape(file)

			if v:shell_error
				BRCERROR Unable to launch w3m.
				return 0
			endif
		endif
	endif " }}}

	if (which ==? 'o') " {{{
		if new == 2
			BRCMESG Opening new Opera tab...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " &\""
			endif
		elseif new
			BRCMESG Opening new Opera window...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file) . ' --new-window'
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " --new-window &\""
			endif
		else
			BRCMESG Sending remote command to Opera...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " &\""
			endif
		endif
	endif " }}}

	if (which ==? 'c') " {{{
		if new == 2
			BRCMESG Opening new Chrome tab...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " &\""
			endif
		elseif new
			BRCMESG Opening new Chrome window...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file) . ' --new-window'
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " --new-window &\""
			endif
		else
			BRCMESG Sending remote command to Chrome...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " &\""
			endif
		endif
	endif " }}}

	if (which ==? 'f') " {{{
		if new == 2
			BRCMESG Opening new Firefox tab...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' --new-tab ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " --new-tab " . s:ShellEscape(file) . " &\""
			endif
		elseif new
			BRCMESG Opening new Firefox window...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' --new-window ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " --new-window " . s:ShellEscape(file) . " &\""
			endif
		else
			BRCMESG Sending remote command to Firefox...
			if has('win32') || has('win64') || has('win32unix')
				let command='start ' . s:Browsers[which][0] . ' ' . <SID>ShellEscape(file)
			else
				let command="sh -c \"trap '' HUP; " . s:Browsers[which][1] . " " . s:ShellEscape(file) . " &\""
			endif
		endif
	endif " }}}

	if exists('l:command')

		if has('win32unix')
			" Change "start" to "cygstart":
			let command='cyg' . command
		endif

		"echomsg command
		call system(command)

		"if has('unix') && v:shell_error
		if v:shell_error
			exe 'BRCERROR Command failed: ' . command
			return 0
		endif

		return 1
	endif

	BRCERROR Something went wrong, we should not ever get here...
	return 0
endfunction " }}}1

" vim: set ts=2 sw=2 ai nu tw=75 fo=croq2 fdm=marker fdc=4:
