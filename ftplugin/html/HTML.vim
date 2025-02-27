vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  echoerr 'The HTML macros plugin no longer supports Vim versions prior to 9.1.509'
  sleep 3
  finish
endif

# ---- Author & Copyright: ---------------------------------------------- {{{1
#
# Author:           Christian J. Robinson <heptite(at)gmail(dot)com>
# URL:              https://christianrobinson.name/HTML/
# Last Change:      February 27, 2025
# Original Concept: Doug Renze
# Requirements:     Vim 9.1.509 or later
#
# The original Copyright goes to Doug Renze, although nearly all of his
# efforts have been modified in this implementation.  My changes and additions
# are Copyrighted by me, on the dates marked in the ChangeLog.
#
# (Doug Renze has authorized me to place the original "code" under the GPL.)
#
# ----------------------------------------------------------------------------
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
#
# ---- Original Author's Notes: ----------------------------------------------
#
# HTML Macros
#        I wrote these HTML macros for my personal use.  They're
#        freely-distributable and freely-modifiable.
#
#        If you do make any major additions or changes, or even just
#        have a suggestion for improvement, feel free to let me
#        know.  I'd appreciate any suggestions.
#
#        Credit must go to Eric Tilton, Carl Steadman and Tyler
#        Jones for their excellent book "Web Weaving" which was
#        my primary source.
#
#        Doug Renze
#
# ---- Assumptions: ----------------------------------------------------- {{{1
#
# This plugin makes a number of assumptions under the umbrella of assuming the
# user's Vim binary was compiled with a standard level of features, sometimes
# called the "Normal" version. However, this has not been fully tested by the
# author because he operates with the "Huge" version that includes nearly all
# compile-time features available to Vim.
#
# ---- TODO: ------------------------------------------------------------ {{{1
#
# - Add a lot more character entity mappings (see table in
#   import/HTML/Variables.vim)
# - Add more HTML 5 tags?
#   https://www.w3.org/wiki/HTML/New_HTML5_Elements
#   https://www.geeksforgeeks.org/html5-new-tags/
# - Find a way to make "gv"--after executing a visual mapping--re-select the
#   right text.  (Currently my extra code that wraps around the visual
#   mappings can tweak the selected area significantly.)
#   + This should probably exclude the newly created tag text, so things like
#     visual selection ;ta, then gv and ;tr, then gv and ;td work.
#
# ----------------------------------------------------------------------- }}}1

# ---- Initialization: -------------------------------------------------- {{{1

# Do this here instead of below, because it's referenced early:
if !exists('g:htmlplugin')
  g:htmlplugin = {}
endif
if !exists('b:htmlplugin')
  b:htmlplugin = {}
endif

runtime commands/HTML/Commands.vim

import '../../import/HTML/Variables.vim'
import autoload '../../autoload/HTML/Glue.vim'
import autoload '../../autoload/HTML/BrowserLauncher.vim'
import autoload '../../autoload/HTML/MangleImageTag.vim'
import autoload '../../autoload/HTML/Map.vim'
import autoload '../../autoload/HTML/Menu.vim'
import autoload '../../autoload/HTML/Util.vim'
import autoload '../../autoload/HTML/Messages.vim'

# Create Glue object ...
var HTMLGlueO: Glue.HTMLGlue = Glue.HTMLGlue.new()
# ...and save it where it can be used by the mappings:
#b:htmlplugin.HTMLGlueO = HTMLGlueO
# ...and do the same with the rest:
var BrowserLauncherO: BrowserLauncher.BrowserLauncher =
  BrowserLauncher.BrowserLauncher.new()
b:htmlplugin.BrowserLauncherO = BrowserLauncherO
# ...
var MangleImageTagO: MangleImageTag.MangleImageTag =
  MangleImageTag.MangleImageTag.new()
b:htmlplugin.MangleImageTagO = MangleImageTagO
# ...
var HTMLMapO: Map.HTMLMap = Map.HTMLMap.new()
b:htmlplugin.HTMLMapO = HTMLMapO
# ...
var HTMLMenuO: Menu.HTMLMenu = Menu.HTMLMenu.new()
#b:htmlplugin.HTMLMenuO = HTMLMenuO
# ...
var HTMLMessagesO: Messages.HTMLMessages =
  Messages.HTMLMessages.new()
#b:htmlplugin.HTMLMessagesO = HTMLMessagesO
# ...
var HTMLVariablesO: Variables.HTMLVariables =
  Variables.HTMLVariables.new()
#b:htmlplugin.HTMLVariablesO = HTMLVariablesO
# ...
var HTMLUtilO: Util.HTMLUtil = Util.HTMLUtil.new()
b:htmlplugin.HTMLUtilO = HTMLUtilO

# Enable some features by default:
HTMLUtilO.SetIfUnset('g:htmlplugin.map_override', v:true)
HTMLUtilO.SetIfUnset('g:htmlplugin.menu', v:true)
HTMLUtilO.SetIfUnset('g:htmlplugin.tab_mapping', v:true)
HTMLUtilO.SetIfUnset('g:htmlplugin.toolbar', v:true)

if !HTMLUtilO.BoolVar('b:htmlplugin.did_mappings_init')
  b:htmlplugin.did_mappings_init = true

  # Configuration variables:  {{{2
  # (These should be set in the user's vimrc or a filetype plugin, rather than
  # changed here.)
  g:htmlplugin->extend({
    bgcolor:                '#FFFFFF',
    textcolor:              '#000000',
    linkcolor:              '#0000EE',
    alinkcolor:             '#FF0000',
    vlinkcolor:             '#990066',
    tag_case:               'lowercase',
    map_leader:             ';',
    entity_map_leader:      '&',
    default_charset:        'UTF-8',
    # No way to know sensible defaults here so just make sure the
    # variables are set:
    author_name:             '',
    author_email:            '',
    author_url:              '',
    # Empty list means the HTML menu is its own toplevel:
    toplevel_menu:          [],
    # -1 means let Vim put the menu wherever it wants to by default:
    toplevel_menu_priority: -1,
    save_clipboard:         &clipboard,
  }, 'keep')

  # Buffer-local versions of some config variables (others are set below):
  b:htmlplugin->extend({
    author_name:  g:htmlplugin.author_name,
    author_email: g:htmlplugin.author_email,
    author_url:   g:htmlplugin.author_url,
    bgcolor:      g:htmlplugin.bgcolor,
    textcolor:    g:htmlplugin.textcolor,
    linkcolor:    g:htmlplugin.linkcolor,
    alinkcolor:   g:htmlplugin.alinkcolor,
    vlinkcolor:   g:htmlplugin.vlinkcolor
  }, 'keep')
  # END configurable variables


  # Intitialize some necessary variables:  {{{2

  if type(g:htmlplugin.toplevel_menu) != v:t_list
    Messages.HTMLMessages.Error('g:htmlplugin.toplevel_menu must be a list! Overriding to default.')
    sleep 3
    g:htmlplugin.toplevel_menu = []
  endif

  if !g:htmlplugin->has_key('toplevel_menu_escaped')
    g:htmlplugin.toplevel_menu_escaped =
      HTMLMenuO.MenuJoin(g:htmlplugin.toplevel_menu->add(Variables.HTMLVariables.MENU_NAME))
    lockvar g:htmlplugin.toplevel_menu
    lockvar g:htmlplugin.toplevel_menu_escaped
  endif

  silent! setlocal clipboard+=html
  setlocal matchpairs+=<:>

  if g:htmlplugin.entity_map_leader ==# g:htmlplugin.map_leader
    Messages.HTMLmessages.Error('"g:htmlplugin.entity_map_leader" and "g:htmlplugin.map_leader" have the same value!')
    Messages.HTMLmessages.Error('Resetting both to their defaults (";" and "&" respectively).')
    sleep 3
    g:htmlplugin.map_leader = ';'
    g:htmlplugin.entity_map_leader = '&'
  endif


  # Detect whether to force uppper or lower case:  {{{2
  if &filetype ==? 'xhtml'
      || HTMLUtilO.BoolVar('g:htmlplugin.xhtml_mappings')
      || HTMLUtilO.BoolVar('b:htmlplugin.xhtml_mappings')
    b:htmlplugin.xhtml_mappings = true
  else
    b:htmlplugin.xhtml_mappings = false

    if HTMLUtilO.BoolVar('g:htmlplugin.tag_case_autodetect')
        && (line('$') != 1 || getline(1) != '')

      var found_upper: number = search('\C<\(\s*/\)\?\s*\u\+\_[^<>]*>', 'wn')
      var found_lower: number = search('\C<\(\s*/\)\?\s*\l\+\_[^<>]*>', 'wn')

      if found_upper != 0 && found_lower == 0
        b:htmlplugin.tag_case = 'uppercase'
      elseif found_upper == 0 && found_lower != 0
        b:htmlplugin.tag_case = 'lowercase'
      else
        # Found a combination of upper and lower case, so just use the user
        # preference:
        b:htmlplugin.tag_case = g:htmlplugin.tag_case
      endif
    endif
  endif

  if HTMLUtilO.BoolVar('b:htmlplugin.xhtml_mappings')
    b:htmlplugin.tag_case = 'lowercase'
  endif

  HTMLUtilO.SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

  # Template creation: {{{2

  if HTMLUtilO.BoolVar('b:htmlplugin.xhtml_mappings')
    b:htmlplugin.internal_template = Variables.HTMLVariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"',
        ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
        '<html xmlns="http://www.w3.org/1999/xhtml">'
      ], 0)

    b:htmlplugin.internal_template =
      HTMLUtilO.ConvertCase(b:htmlplugin.internal_template)
  else
    b:htmlplugin.internal_template = Variables.HTMLVariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html>',
        '<[{HTML}]>'
      ], 0)

    b:htmlplugin.internal_template =
      HTMLUtilO.ConvertCase(b:htmlplugin.internal_template)

    b:htmlplugin.internal_template =
      b:htmlplugin.internal_template->mapnew(
          (_, line) => {
            return line->substitute(' />', '>', 'g')
          }
        )
  endif

  # }}}2

endif # !HTMLUtilO.BoolVar('b:htmlplugin.did_mappings_init')

# ----------------------------------------------------------------------------

if !HTMLUtilO.BoolVar('b:htmlplugin.did_mappings')
b:htmlplugin.did_mappings = true

# ---- Miscellaneous Mappings: ------------------------------------------ {{{1

b:htmlplugin.clear_mappings = []

# Make it easy to use a ; (or whatever the map leader is) as normal:
HTMLMapO.Map('inoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader, {extra: false})
HTMLMapO.Map('vnoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader, {extra: false})
HTMLMapO.Map('nnoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader)
# Make it easy to insert a & (or whatever the entity leader is):
HTMLMapO.Map('inoremap', $'<lead>{g:htmlplugin.entity_map_leader}', g:htmlplugin.entity_map_leader, {extra: false})

if HTMLUtilO.BoolVar('g:htmlplugin.tab_mapping')
  # Allow hard tabs to be used:
  HTMLMapO.Map('inoremap', '<lead><tab>', '<tab>', {extra: false})
  HTMLMapO.Map('nnoremap', '<lead><tab>', '<tab>')
  HTMLMapO.Map('vnoremap', '<lead><tab>', '<tab>', {extra: false})
  # And shift-tabs too:
  HTMLMapO.Map('inoremap', '<lead><s-tab>', '<s-tab>', {extra: false})
  HTMLMapO.Map('nnoremap', '<lead><s-tab>', '<s-tab>')
  HTMLMapO.Map('vnoremap', '<lead><s-tab>', '<s-tab>', {extra: false})

  # Tab takes us to a (hopefully) reasonable next insert point:
  HTMLMapO.Map('inoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('i')<CR>", {extra: false})
  HTMLMapO.Map('nnoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n')<CR>")
  HTMLMapO.Map('vnoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n')<CR>", {extra: false})
  # ...And shift-tab goes backwards:
  HTMLMapO.Map('inoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('i', 'b')<CR>", {extra: false})
  HTMLMapO.Map('nnoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n', 'b')<CR>")
  HTMLMapO.Map('vnoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n', 'b')<CR>", {extra: false})
else
  HTMLMapO.Map('inoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('i')<CR>", {extra: false})
  HTMLMapO.Map('nnoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n')<CR>")
  HTMLMapO.Map('vnoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n')<CR>", {extra: false})

  HTMLMapO.Map('inoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('i', 'b')<CR>")
  HTMLMapO.Map('nnoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n', 'b')<CR>", {extra: false})
  HTMLMapO.Map('vnoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLMapO.NextInsertPoint('n', 'b')<CR>", {extra: false})
endif

# ----------------------------------------------------------------------------

# ---- General Markup Tag Mappings: ------------------------------------- {{{1

# Can't conditionally set mappings in the tags.json file, so do this set of
# mappings here instead:

#       SGML Doctype Command
if HTMLUtilO.BoolVar('b:htmlplugin.xhtml_mappings')
  # Transitional XHTML (Looser):
  HTMLMapO.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">'])<CR>")
  # Strict XHTML:
  HTMLMapO.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">'])<CR>")
else
  # Transitional HTML (Looser):
  HTMLMapO.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"', ' \"http://www.w3.org/TR/html4/loose.dtd\">'])<CR>")
  # Strict HTML:
  HTMLMapO.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"', ' \"http://www.w3.org/TR/html4/strict.dtd\">'])<CR>")
endif
HTMLMapO.Map('imap', '<lead>4', $'\<C-O>{g:htmlplugin.map_leader}4')
HTMLMapO.Map('imap', '<lead>s4', $'\<C-O>{g:htmlplugin.map_leader}s4')

#       HTML5 Doctype Command           HTML 5
HTMLMapO.Map('nnoremap', '<lead>5', "<ScriptCmd>append(0, '<!DOCTYPE html>')<CR>")
HTMLMapO.Map('imap', '<lead>5', $'\<C-O>{g:htmlplugin.map_leader}5')


#       HTML
if HTMLUtilO.BoolVar('b:htmlplugin.xhtml_mappings')
  HTMLMapO.Map('inoremap', '<lead>ht', '<html xmlns="http://www.w3.org/1999/xhtml"><CR></html>\<ESC>O')
  # Visual mapping:
  HTMLMapO.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></html>\<C-O>`<<html xmlns="http://www.w3.org/1999/xhtml">\<CR>\<ESC>', {reindent: 1})
else
  HTMLMapO.Map('inoremap', '<lead>ht', '<[{HTML}]>\<CR></[{HTML}]>\<ESC>O')
  # Visual mapping:
  HTMLMapO.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></[{HTML}]>\<C-O>`<<[{HTML}]>\<CR>\<ESC>', {reindent: 1})
endif
# Motion mapping:
HTMLMapO.Map('nnoremap', '<lead>ht', '')

# ----------------------------------------------------------------------------

# ---- Browser Remote Controls: ----------------------------------------- {{{1

# Can't access an imported enum from mappings, so kluge it:
b:htmlplugin.BrowserBehavior = {
  default: BrowserLauncher.Behavior.default,
  newwindow: BrowserLauncher.Behavior.newwindow,
  newtab: BrowserLauncher.Behavior.newtab
}

if BrowserLauncherO.BrowserExists('default') # {{{2
  # Run the default browser:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>db',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('default')<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('brave') # {{{2
  # Chrome: View current file, starting Chrome if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>bv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nbv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tbv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('chrome') # {{{2
  # Chrome: View current file, starting Chrome if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>gc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ngc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tgc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('edge') # {{{2
  # Edge: View current file, starting Microsoft Edge if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ed',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Edge: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ned',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Edge: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ted',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('firefox') # {{{2
  # Firefox: View current file, starting Firefox if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Firefox: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Firefox: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('opera') # {{{2
  # Opera: View current file, starting Opera if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>oa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Opera: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>noa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Opera: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>toa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('safari') # {{{2
  # Safari: View current file, starting Safari if it's not running:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>sf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Safari: Open a new window, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nsf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
    )
  # Safari: Open a new tab, and view the current file:
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tsf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('lynx') # {{{2
  # Lynx:  (This may happen anyway if there's no GUI available.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('w3m') # {{{2
  # w3m:  (This may happen anyway if there's no GUI available.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>w3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # w3m in an xterm:  (This always happens in the Vim GUI.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nw3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # w3m in a new Vim window, using ":terminal":
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tw3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.BrowserExists('links') # {{{2
  # Links:  (This may happen anyway if there's no GUI available.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>ln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', b:htmlplugin.BrowserBehavior.default)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  HTMLMapO.Map(
    'nnoremap',
    '<lead>nln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', b:htmlplugin.BrowserBehavior.newwindow)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  HTMLMapO.Map(
    'nnoremap',
    '<lead>tln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', b:htmlplugin.BrowserBehavior.newtab)<CR>"
  )
endif # }}}2

# ----------------------------------------------------------------------------

endif # !HTMLUtilO.BoolVar('b:htmlplugin.did_mappings')

# ---- ToolBar Buttons and Menu Items: ---------------------------------- {{{1

if HTMLUtilO.BoolVar('g:htmlplugin.did_menus')
  HTMLMenuO.MenuControl()
  if !HTMLUtilO.BoolVar('b:htmlplugin.did_json')
    # Already did the menus but the tags and entities mappings need to be
    # defined for this new buffer:
    b:htmlplugin.did_json = true
    HTMLGlueO.ReadTags(false, true)
    HTMLGlueO.ReadEntities(false, true)
  endif
elseif !HTMLUtilO.BoolVar('g:htmlplugin.menu')
  # No menus were requested, so just define the tags and entities mappings:
  if !HTMLUtilO.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    HTMLGlueO.ReadTags(false, true)
    HTMLGlueO.ReadEntities(false, true)
  endif
else

  # Solve a race condition:
  if ! exists('g:did_install_default_menus')
    source $VIMRUNTIME/menu.vim
  endif

  if HTMLUtilO.BoolVar('g:htmlplugin.toolbar') && has('toolbar')

    # In the context of running ":gui" after starting the non-GUI, unfortunately
    # there's no way to make this work if the user has 'guioptions' set in their
    # gvimrc, and it removes the 'T'.
    if has('gui_running')
      set guioptions+=T
    else
      augroup HTMLplugin
        autocmd GUIEnter * set guioptions+=T
      augroup END
    endif

    # Save some menu stuff from the global menu.vim so we can reuse them
    # later--this makes sure updates from menu.vim make it into this codebase:
    var save_toolbar: dict<string>
    save_toolbar.open      = menu_info('ToolBar.Open').rhs->escape('|')
    save_toolbar.save      = menu_info('ToolBar.Save').rhs->escape('|')
    save_toolbar.saveall   = menu_info('ToolBar.SaveAll').rhs->escape('|')
    save_toolbar.replace   = menu_info('ToolBar.Replace').rhs->escape('|')
    save_toolbar.replace_v = menu_info('ToolBar.Replace', 'v').rhs->escape('|')
    save_toolbar.cut_v     = menu_info('ToolBar.Cut', 'v').rhs->escape('|')
    save_toolbar.copy_v    = menu_info('ToolBar.Copy', 'v').rhs->escape('|')
    save_toolbar.paste_n   = menu_info('ToolBar.Paste', 'n').rhs->escape('|')
    save_toolbar.paste_c   = menu_info('ToolBar.Paste', 'c').rhs->escape('|')
    save_toolbar.paste_i   = menu_info('ToolBar.Paste', 'i').rhs->escape('|')
    save_toolbar.paste_v   = menu_info('ToolBar.Paste', 'v').rhs->escape('|')

    silent! unmenu ToolBar
    silent! unmenu! ToolBar

    # Create the ToolBar:   {{{2

    # For some reason, the tmenu commands must come before the other menu
    # commands for that menu item, or GTK versions of gVim don't show the
    # icons properly.

    HTMLMenuO.Menu('tmenu',     '1.10',  ['ToolBar', 'Open'],      'Open File')
    HTMLMenuO.Menu('anoremenu', '1.10',  ['ToolBar', 'Open'],      save_toolbar.open)
    HTMLMenuO.Menu('tmenu',     '1.20',  ['ToolBar', 'Save'],      'Save Current File')
    HTMLMenuO.Menu('anoremenu', '1.20',  ['ToolBar', 'Save'],      save_toolbar.save)
    HTMLMenuO.Menu('tmenu',     '1.30',  ['ToolBar', 'SaveAll'],   'Save All Files')
    HTMLMenuO.Menu('anoremenu', '1.30',  ['ToolBar', 'SaveAll'],   save_toolbar.saveall)

    HTMLMenuO.Menu('menu',      '1.50',  ['ToolBar', '-sep1-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.60',  ['ToolBar', 'Template'],  'Insert Template')
    HTMLMenuO.LeadMenu('amenu', '1.60',  ['ToolBar', 'Template'],  'html')

    HTMLMenuO.Menu('menu',      '1.65',  ['ToolBar', '-sep2-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.70',  ['ToolBar', 'Paragraph'], 'Create Paragraph')
    HTMLMenuO.LeadMenu('imenu', '1.70',  ['ToolBar', 'Paragraph'], 'pp')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Paragraph'], 'pp')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Paragraph'], 'pp', 'i')
    HTMLMenuO.Menu('tmenu',     '1.80',  ['ToolBar', 'Break'],     'Line Break')
    HTMLMenuO.LeadMenu('imenu', '1.80',  ['ToolBar', 'Break'],     'br')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Break'],     'br')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Break'],     'br', 'i')

    HTMLMenuO.Menu('menu',      '1.85',  ['ToolBar', '-sep3-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.90',  ['ToolBar', 'Link'],      'Create Hyperlink')
    HTMLMenuO.LeadMenu('imenu', '1.90',  ['ToolBar', 'Link'],      'ah')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Link'],      'ah')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Link'],      'ah', 'i')
    HTMLMenuO.Menu('tmenu',     '1.100', ['ToolBar', 'Image'],     'Insert Image')
    HTMLMenuO.LeadMenu('imenu', '1.100', ['ToolBar', 'Image'],     'im')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Image'],     'im')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Image'],     'im', 'i')

    HTMLMenuO.Menu('menu',      '1.105', ['ToolBar', '-sep4-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.110', ['ToolBar', 'Hline'],     'Create Horizontal Rule')
    HTMLMenuO.LeadMenu('imenu', '1.110', ['ToolBar', 'Hline'],     'hr')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Hline'],     'hr', 'i')

    HTMLMenuO.Menu('menu',      '1.115', ['ToolBar', '-sep5-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.120', ['ToolBar', 'Table'],     'Create Table')
    HTMLMenuO.LeadMenu('imenu', '1.120', ['ToolBar', 'Table'],     'tA <ESC>')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Table'],     'tA')

    HTMLMenuO.Menu('menu',      '1.125', ['ToolBar', '-sep6-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.130', ['ToolBar', 'Blist'],     'Create Bullet List')
    HTMLMenuO.Menu('imenu',     '1.130', ['ToolBar', 'Blist'],
      $'{g:htmlplugin.map_leader}ul{g:htmlplugin.map_leader}li')
    HTMLMenuO.Menu('vmenu',     '-',     ['ToolBar', 'Blist'],
      $'{g:htmlplugin.map_leader}uli{g:htmlplugin.map_leader}li<ESC>')
    HTMLMenuO.Menu('nmenu',     '-',     ['ToolBar', 'Blist'],
      $'i{g:htmlplugin.map_leader}ul{g:htmlplugin.map_leader}li')
    HTMLMenuO.Menu('tmenu',     '1.140', ['ToolBar', 'Nlist'],     'Create Numbered List')
    HTMLMenuO.Menu('imenu',     '1.140', ['ToolBar', 'Nlist'],
      $'{g:htmlplugin.map_leader}ol{g:htmlplugin.map_leader}li')
    HTMLMenuO.Menu('vmenu',     '-',     ['ToolBar', 'Nlist'],
      $'{g:htmlplugin.map_leader}oli{g:htmlplugin.map_leader}li<ESC>')
    HTMLMenuO.Menu('nmenu',     '-',     ['ToolBar', 'Nlist'],
      $'i{g:htmlplugin.map_leader}ol{g:htmlplugin.map_leader}li')
    HTMLMenuO.Menu('tmenu',     '1.150', ['ToolBar', 'Litem'],     'Add List Item')
    HTMLMenuO.LeadMenu('imenu', '1.150', ['ToolBar', 'Litem'],     'li')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Litem'],     'li', 'i')

    HTMLMenuO.Menu('menu',      '1.155', ['ToolBar', '-sep7-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.160', ['ToolBar', 'Bold'],      'Bold')
    HTMLMenuO.LeadMenu('imenu', '1.160', ['ToolBar', 'Bold'],      'bo')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Bold'],      'bo')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Bold'],      'bo', 'i')
    HTMLMenuO.Menu('tmenu',     '1.170', ['ToolBar', 'Italic'],    'Italic')
    HTMLMenuO.LeadMenu('imenu', '1.170', ['ToolBar', 'Italic'],    'it')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Italic'],    'it')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Italic'],    'it', 'i')
    HTMLMenuO.Menu('tmenu',     '1.180', ['ToolBar', 'Underline'], 'Underline')
    HTMLMenuO.LeadMenu('imenu', '1.180', ['ToolBar', 'Underline'], 'un')
    HTMLMenuO.LeadMenu('vmenu', '-',     ['ToolBar', 'Underline'], 'un')
    HTMLMenuO.LeadMenu('nmenu', '-',     ['ToolBar', 'Underline'], 'un', 'i')

    HTMLMenuO.Menu('menu',      '1.185', ['ToolBar', '-sep8-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.190', ['ToolBar', 'Undo'],      'Undo')
    HTMLMenuO.Menu('anoremenu', '1.190', ['ToolBar', 'Undo'],      'u')
    HTMLMenuO.Menu('tmenu',     '1.200', ['ToolBar', 'Redo'],      'Redo')
    HTMLMenuO.Menu('anoremenu', '1.200', ['ToolBar', 'Redo'],      '<C-R>')

    HTMLMenuO.Menu('menu',      '1.205', ['ToolBar', '-sep9-'],    '<Nop>')

    HTMLMenuO.Menu('tmenu',     '1.210', ['ToolBar', 'Cut'],       'Cut to Clipboard')
    HTMLMenuO.Menu('vnoremenu', '1.210', ['ToolBar', 'Cut'],       save_toolbar.cut_v)
    HTMLMenuO.Menu('tmenu',     '1.220', ['ToolBar', 'Copy'],      'Copy to Clipboard')
    HTMLMenuO.Menu('vnoremenu', '1.220', ['ToolBar', 'Copy'],      save_toolbar.copy_v)
    HTMLMenuO.Menu('tmenu',     '1.230', ['ToolBar', 'Paste'],     'Paste from Clipboard')
    HTMLMenuO.Menu('nnoremenu', '1.230', ['ToolBar', 'Paste'],     save_toolbar.paste_n)
    HTMLMenuO.Menu('cnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_c)
    HTMLMenuO.Menu('inoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_i)
    HTMLMenuO.Menu('vnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_v)

    HTMLMenuO.Menu('menu',      '1.235', ['ToolBar', '-sep10-'],   '<Nop>')

    if !has('gui_athena')
      HTMLMenuO.Menu('tmenu',       '1.240', ['ToolBar', 'Replace'],  'Find / Replace')
      HTMLMenuO.Menu('anoremenu',   '1.240', ['ToolBar', 'Replace'],  save_toolbar.replace)
      vunmenu ToolBar.Replace
      HTMLMenuO.Menu('vnoremenu',   '-',     ['ToolBar', 'Replace'],  save_toolbar.replace_v)
      HTMLMenuO.Menu('tmenu',       '1.250', ['ToolBar', 'FindNext'], 'Find Next')
      HTMLMenuO.Menu('anoremenu',   '1.250', ['ToolBar', 'FindNext'], 'n')
      HTMLMenuO.Menu('tmenu',       '1.260', ['ToolBar', 'FindPrev'], 'Find Previous')
      HTMLMenuO.Menu('anoremenu',   '1.260', ['ToolBar', 'FindPrev'], 'N')
    endif

    HTMLMenuO.Menu('menu', '1.500', ['ToolBar', '-sep50-'], '<Nop>')

    if maparg($'{g:htmlplugin.map_leader}db', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.510', ['ToolBar', 'Browser'],
        'Launch the Default Browser on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.510', ['ToolBar', 'Browser'], 'db')
    endif

    if maparg($'{g:htmlplugin.map_leader}bv', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.520', ['ToolBar', 'Brave'],
        'Launch Brave on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.520', ['ToolBar', 'Brave'], 'bv')
    endif

    if maparg($'{g:htmlplugin.map_leader}gc', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.530', ['ToolBar', 'Chrome'],
        'Launch Chrome on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.530', ['ToolBar', 'Chrome'], 'gc')
    endif

    if maparg($'{g:htmlplugin.map_leader}ed', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.540', ['ToolBar', 'Edge'],
        'Launch Edge on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.540', ['ToolBar', 'Edge'], 'ed')
    endif

    if maparg($'{g:htmlplugin.map_leader}ff', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.550', ['ToolBar', 'Firefox'],
        'Launch Firefox on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.550', ['ToolBar', 'Firefox'], 'ff')
    endif

    if maparg($'{g:htmlplugin.map_leader}oa', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.560', ['ToolBar', 'Opera'],
        'Launch Opera on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.560', ['ToolBar', 'Opera'], 'oa')
    endif

    if maparg($'{g:htmlplugin.map_leader}sf', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.570', ['ToolBar', 'Safari'],
        'Launch Safari on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.570', ['ToolBar', 'Safari'], 'sf')
    endif

    if maparg($'{g:htmlplugin.map_leader}w3', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.580', ['ToolBar', 'w3m'],
        'Launch w3m on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.580', ['ToolBar', 'w3m'], 'w3')
    endif

    if maparg($'{g:htmlplugin.map_leader}ly', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.590', ['ToolBar', 'Lynx'],
        'Launch Lynx on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.590', ['ToolBar', 'Lynx'], 'ly')
    endif

    if maparg($'{g:htmlplugin.map_leader}ln', 'n') != ''
      HTMLMenuO.Menu('tmenu', '1.600', ['ToolBar', 'Links'],
        'Launch Links on the Current File')
      HTMLMenuO.LeadMenu('amenu', '1.600', ['ToolBar', 'Links'], 'ln')
    endif

    HTMLMenuO.Menu('menu',      '1.997', ['ToolBar', '-sep99-'], '<Nop>')
    HTMLMenuO.Menu('tmenu',     '1.998', ['ToolBar', 'HTMLHelp'], 'HTML Plugin Help')
    HTMLMenuO.Menu('anoremenu', '1.998', ['ToolBar', 'HTMLHelp'], ':help HTML.txt<CR>')

    HTMLMenuO.Menu('tmenu',     '1.999', ['ToolBar', 'Help'], 'Help')
    HTMLMenuO.Menu('anoremenu', '1.999', ['ToolBar', 'Help'], ':help<CR>')

    # }}}2

    g:htmlplugin.did_toolbar = true
  endif  # !HTMLUtilO.BoolVar('g:htmlplugin.toolbar') && has('toolbar')

  # Add to the PopUp menu:   {{{2
  HTMLMenuO.Menu('nnoremenu', '1.91', ['PopUp', 'Select Ta&g'],        'vat')
  HTMLMenuO.Menu('onoremenu', '-',    ['PopUp', 'Select Ta&g'],        'at')
  HTMLMenuO.Menu('vnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')
  HTMLMenuO.Menu('inoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-O>vat')
  HTMLMenuO.Menu('cnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')

  HTMLMenuO.Menu('nnoremenu', '1.92', ['PopUp', 'Select &Inner Ta&g'], 'vit')
  HTMLMenuO.Menu('onoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], 'it')
  HTMLMenuO.Menu('vnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  HTMLMenuO.Menu('inoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-O>vit')
  HTMLMenuO.Menu('cnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  # }}}2

  augroup HTMLmenu
    au!
    autocmd BufEnter,WinEnter * {
        HTMLMenuO.MenuControl()
        HTMLMenuO.ToggleClipboard()
      }
  augroup END

  # Create the "HTML" menu:   {{{2

  # Very first non-ToolBar, non-PopUp menu gets "auto" for its priority to place
  # the HTML menu according to user configuration:
  HTMLMenuO.Menu('amenu', 'auto', ['&Disable Mappings<tab>:HTML disable'],
    ':HTMLmappings disable<CR>')
  HTMLMenuO.Menu('amenu', '-',    ['&Enable Mappings<tab>:HTML enable'],
    ':HTMLmappings enable<CR>')

  execute $'amenu disable {g:htmlplugin.toplevel_menu_escaped}.Enable\ Mappings'

  HTMLMenuO.Menu('menu',  '.9999', ['-sep999-'], '<Nop>')

  HTMLMenuO.Menu('amenu', '.9999', ['Help', 'HTML Plugin Help<TAB>:help HTML.txt'],
    ':help HTML.txt<CR>')
  HTMLMenuO.Menu('amenu', '.9999', ['Help', 'About the HTML Plugin<TAB>:HTMLAbout'],
    ':HTMLAbout<CR>')

  if maparg($'{g:htmlplugin.map_leader}db', 'n') != ''
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Default Browser'], 'db')
  endif
  if maparg($'{g:htmlplugin.map_leader}bv', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep1-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Brave'], 'bv')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Window)'], 'nbv')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Tab)'], 'tbv')
  endif
  if maparg($'{g:htmlplugin.map_leader}gc', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep3-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Chrome'], 'gc')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Window)'], 'ngc')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Tab)'], 'tgc')
  endif
  if maparg($'{g:htmlplugin.map_leader}ed', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep4-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Edge'], 'ed')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Window)'], 'ned')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Tab)'], 'ted')
  endif
  if maparg($'{g:htmlplugin.map_leader}ff', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep2-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Firefox'], 'ff')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Window)'], 'nff')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Tab)'], 'tff')
  endif
  if maparg($'{g:htmlplugin.map_leader}oa', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep5-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Opera'], 'oa')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Window)'], 'noa')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Tab)'], 'toa')
  endif
  if maparg($'{g:htmlplugin.map_leader}sf', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep6-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Safari'], 'sf')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Window)'], 'nsf')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Tab)'], 'tsf')
  endif
  if maparg($'{g:htmlplugin.map_leader}ly', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep7-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&Lynx'], 'ly')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Lynx (New Window)'], 'nly')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Lynx (:terminal)'], 'tly')
  endif
  if maparg($'{g:htmlplugin.map_leader}w3', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep8-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', '&w3m'], 'w3')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'w3m (New Window)'], 'nw3')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'w3m (:terminal)'], 'tw3')
  endif
  if maparg($'{g:htmlplugin.map_leader}ln', 'n') != ''
    HTMLMenuO.Menu('menu', '-', ['Preview', '-sep9-'], '<nop>')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Li&nks'], 'ln')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Links (New Window)'], 'nln')
    HTMLMenuO.LeadMenu('amenu', '-', ['&Preview', 'Links (:terminal)'], 'tln')
  endif

  # Bring in the tags and entities menus and mappings at the same time. (If we
  # got here they weren't brought in above.):
  if !HTMLUtilO.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    HTMLGlueO.ReadTags(true, true)
    HTMLGlueO.ReadEntities(true, true)
  endif

  # Create the rest of the colors menu:
  Variables.HTMLVariables.COLOR_LIST->mapnew((_, value) => HTMLMenuO.ColorsMenu(value[0], value[1]))

  # }}}2

  g:htmlplugin.did_menus = true

endif
# ---------------------------------------------------------------------------

# ---- Finalize and Clean Up: ------------------------------------------- {{{1

# Try to reduce support requests from users:

if !HTMLUtilO.BoolVar('g:htmlplugin.did_old_variable_check') &&  # {{{
    (exists('g:html_author_name') || exists('g:html_author_email')
    || exists('g:html_bgcolor') || exists('g:html_textcolor')
    || exists('g:html_alinkcolor') || exists('g:html_vlinkcolor')
    || exists('g:html_tag_case') || exists('g:html_map_leader')
    || exists('g:html_map_entity_leader') || exists('g:html_default_charset')
    || exists('g:html_template') || exists('g:no_html_map_override')
    || exists('g:no_html_maps') || exists('g:no_html_menu')
    || exists('g:no_html_toolbar') || exists('g:no_html_tab_mapping'))
  g:htmlplugin.did_old_variable_check = true
  var message = "You have set one or more of the old HTML plugin configuration variables.\n"
  .. "These variables are no longer used in favor of a new dictionary variable.\n\n"
  .. "Please refer to \":help html-variables\"."
  if message->confirm("&Help\n&Dismiss", 2, 'Warning') == 1
    help html-variables
    # Go to the previous window or everything gets messy:
    wincmd p
  endif
endif  # }}}

if !HTMLUtilO.BoolVar('g:htmlplugin.did_plugin_warning_check')  # {{{
  g:htmlplugin.did_plugin_warning_check = true
  var files = 'ftplugin/html/HTML.vim'->findfile(&runtimepath, -1)
  if files->len() > 1
    var filesmatched = files->Util.HTMLUtil.FilesWithMatch('https\?://christianrobinson.name/\%(\%(programming/\)\?vim/\)\?HTML/', 20)
    if filesmatched->len() > 1
      var message = "Multiple versions of the HTML plugin are installed.\n"
        .. "Locations:\n   " .. filesmatched->map((_, value) => value->fnamemodify(':~'))->join("\n   ")
        .. "\nIt is necessary that you remove old versions!\n"
        .. "(Don't forget about browser_launcher.vim/BrowserLauncher.vim and MangleImageTag.vim)"
      message->confirm('&Dismiss', 1, 'Warning')
    endif
  endif
endif  #}}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
