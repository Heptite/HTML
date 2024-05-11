vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010219
  echoerr 'The HTML macros plugin no longer supports Vim versions prior to 9.1.219'
  sleep 3
  finish
endif

# ---- Author & Copyright: ---------------------------------------------- {{{1
#
# Author:           Christian J. Robinson <heptite(at)gmail(dot)com>
# URL:              https://christianrobinson.name/HTML/
# Last Change:      May 08, 2024
# Original Concept: Doug Renze
# Requirements:     Vim 9.1.219 or later
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

import '../../import/HTML/Variables.vim' as HTMLVariables
import autoload 'HTML/Functions.vim'
import autoload 'HTML/BrowserLauncher.vim'
import autoload 'HTML/MangleImageTag.vim'

# Create functions object ...
var HTMLFunctionsO = Functions.HTMLFunctions.new()
# ...and save it where it can be used by the mappings:
b:htmlplugin.HTMLFunctionsO = HTMLFunctionsO
# ...
var BrowserLauncherO = BrowserLauncher.BrowserLauncher.new()
b:htmlplugin.BrowserLauncherO = BrowserLauncherO
# ...
var MangleImageTagO = MangleImageTag.MangleImageTag.new()
b:htmlplugin.MangleImageTagO = MangleImageTagO
# ...
var HTMLVariablesO = HTMLVariables.HTMLVariables.new()
#b:HTMLVariablesO = HTMLVariablesO

if !HTMLFunctionsO.BoolVar('b:htmlplugin.did_mappings_init')
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
    Functions.HTMLFunctions.Error('g:htmlplugin.toplevel_menu must be a list! Overriding to default.')
    sleep 3
    g:htmlplugin.toplevel_menu = []
  endif

  if !g:htmlplugin->has_key('toplevel_menu_escaped')
    g:htmlplugin.toplevel_menu_escaped =
      HTMLFunctionsO.MenuJoin(g:htmlplugin.toplevel_menu->add(HTMLVariables.HTMLVariables.MENU_NAME))
    lockvar g:htmlplugin.toplevel_menu
    lockvar g:htmlplugin.toplevel_menu_escaped
  endif

  silent! setlocal clipboard+=html
  setlocal matchpairs+=<:>

  if g:htmlplugin.entity_map_leader ==# g:htmlplugin.map_leader
    Functions.HTMLFunctions.Error('"g:htmlplugin.entity_map_leader" and "g:htmlplugin.map_leader" have the same value!')
    Functions.HTMLFunctions.Error('Resetting both to their defaults (";" and "&" respectively).')
    sleep 3
    g:htmlplugin.map_leader = ';'
    g:htmlplugin.entity_map_leader = '&'
  endif


  # Detect whether to force uppper or lower case:  {{{2
  if &filetype ==? 'xhtml'
      || HTMLFunctionsO.BoolVar('g:htmlplugin.do_xhtml_mappings')
      || HTMLFunctionsO.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.do_xhtml_mappings = true
  else
    b:htmlplugin.do_xhtml_mappings = false

    if HTMLFunctionsO.BoolVar('g:htmlplugin.tag_case_autodetect')
        && (line('$') != 1 || getline(1) != '')

      var found_upper = search('\C<\(\s*/\)\?\s*\u\+\_[^<>]*>', 'wn')
      var found_lower = search('\C<\(\s*/\)\?\s*\l\+\_[^<>]*>', 'wn')

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

  if HTMLFunctionsO.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.tag_case = 'lowercase'
  endif

  HTMLFunctionsO.SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

  # Template Creation: {{{2

  if HTMLFunctionsO.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.internal_template = HTMLVariables.HTMLVariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"',
        ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
        '<html xmlns="http://www.w3.org/1999/xhtml">'
      ], 0)

    b:htmlplugin.internal_template =
      HTMLFunctionsO.ConvertCase(b:htmlplugin.internal_template)
  else
    b:htmlplugin.internal_template = HTMLVariables.HTMLVariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html>',
        '<[{HTML}]>'
      ], 0)

    b:htmlplugin.internal_template =
      HTMLFunctionsO.ConvertCase(b:htmlplugin.internal_template)

    b:htmlplugin.internal_template =
      b:htmlplugin.internal_template->mapnew(
          (_, line) => {
            return line->substitute(' />', '>', 'g')
          }
        )
  endif

  # }}}2

endif # !HTMLFunctionsO.BoolVar('b:htmlplugin.did_mappings_init')

# ----------------------------------------------------------------------------

# ---- Miscellaneous Mappings: ------------------------------------------ {{{1

if !HTMLFunctionsO.BoolVar('b:htmlplugin.did_mappings')
b:htmlplugin.did_mappings = true

b:htmlplugin.clear_mappings = []

# Make it easy to use a ; (or whatever the map leader is) as normal:
HTMLFunctionsO.Map('inoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader, {extra: false})
HTMLFunctionsO.Map('vnoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader, {extra: false})
HTMLFunctionsO.Map('nnoremap', $'<lead>{g:htmlplugin.map_leader}', g:htmlplugin.map_leader)
# Make it easy to insert a & (or whatever the entity leader is):
HTMLFunctionsO.Map('inoremap', $'<lead>{g:htmlplugin.entity_map_leader}', g:htmlplugin.entity_map_leader, {extra: false})

if !HTMLFunctionsO.BoolVar('g:htmlplugin.no_tab_mapping')
  # Allow hard tabs to be used:
  HTMLFunctionsO.Map('inoremap', '<lead><tab>', '<tab>', {extra: false})
  HTMLFunctionsO.Map('nnoremap', '<lead><tab>', '<tab>')
  HTMLFunctionsO.Map('vnoremap', '<lead><tab>', '<tab>', {extra: false})
  # And shift-tabs too:
  HTMLFunctionsO.Map('inoremap', '<lead><s-tab>', '<s-tab>', {extra: false})
  HTMLFunctionsO.Map('nnoremap', '<lead><s-tab>', '<s-tab>')
  HTMLFunctionsO.Map('vnoremap', '<lead><s-tab>', '<s-tab>', {extra: false})

  # Tab takes us to a (hopefully) reasonable next insert point:
  HTMLFunctionsO.Map('inoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('i')<CR>", {extra: false})
  HTMLFunctionsO.Map('nnoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n')<CR>")
  HTMLFunctionsO.Map('vnoremap', '<tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n')<CR>", {extra: false})
  # ...And shift-tab goes backwards:
  HTMLFunctionsO.Map('inoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('i', 'b')<CR>", {extra: false})
  HTMLFunctionsO.Map('nnoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n', 'b')<CR>")
  HTMLFunctionsO.Map('vnoremap', '<s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n', 'b')<CR>", {extra: false})
else
  HTMLFunctionsO.Map('inoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('i')<CR>", {extra: false})
  HTMLFunctionsO.Map('nnoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n')<CR>")
  HTMLFunctionsO.Map('vnoremap', '<lead><tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n')<CR>", {extra: false})

  HTMLFunctionsO.Map('inoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('i', 'b')<CR>")
  HTMLFunctionsO.Map('nnoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n', 'b')<CR>", {extra: false})
  HTMLFunctionsO.Map('vnoremap', '<lead><s-tab>', "<ScriptCmd>b:htmlplugin.HTMLFunctionsO.NextInsertPoint('n', 'b')<CR>", {extra: false})
endif

# ----------------------------------------------------------------------------

# ---- General Markup Tag Mappings: ------------------------------------- {{{1

# Can't conditionally set mappings in the tags.json file, so do this set of
# mappings here instead:

#       SGML Doctype Command
if HTMLFunctionsO.BoolVar('b:htmlplugin.do_xhtml_mappings')
  # Transitional XHTML (Looser):
  HTMLFunctionsO.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">'])<CR>")
  # Strict XHTML:
  HTMLFunctionsO.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">'])<CR>")
else
  # Transitional HTML (Looser):
  HTMLFunctionsO.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"', ' \"http://www.w3.org/TR/html4/loose.dtd\">'])<CR>")
  # Strict HTML:
  HTMLFunctionsO.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"', ' \"http://www.w3.org/TR/html4/strict.dtd\">'])<CR>")
endif
HTMLFunctionsO.Map('imap', '<lead>4', $'\<C-O>{g:htmlplugin.map_leader}4')
HTMLFunctionsO.Map('imap', '<lead>s4', $'\<C-O>{g:htmlplugin.map_leader}s4')

#       HTML5 Doctype Command           HTML 5
HTMLFunctionsO.Map('nnoremap', '<lead>5', "<ScriptCmd>append(0, '<!DOCTYPE html>')<CR>")
HTMLFunctionsO.Map('imap', '<lead>5', $'\<C-O>{g:htmlplugin.map_leader}5')


#       HTML
if HTMLFunctionsO.BoolVar('b:htmlplugin.do_xhtml_mappings')
  HTMLFunctionsO.Map('inoremap', '<lead>ht', '<html xmlns="http://www.w3.org/1999/xhtml"><CR></html>\<ESC>O')
  # Visual mapping:
  HTMLFunctionsO.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></html>\<C-O>`<<html xmlns="http://www.w3.org/1999/xhtml">\<CR>\<ESC>', {reindent: 1})
else
  HTMLFunctionsO.Map('inoremap', '<lead>ht', '<[{HTML}]>\<CR></[{HTML}]>\<ESC>O')
  # Visual mapping:
  HTMLFunctionsO.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></[{HTML}]>\<C-O>`<<[{HTML}]>\<CR>\<ESC>', {reindent: 1})
endif
# Motion mapping:
HTMLFunctionsO.Mapo('<lead>ht')

# ----------------------------------------------------------------------------

# ---- Browser Remote Controls: ----------------------------------------- {{{1

if BrowserLauncherO.Exists('default') # {{{2
  # Run the default browser:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>db',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('default')<CR>"
  )
endif

if BrowserLauncherO.Exists('brave') # {{{2
  # Chrome: View current file, starting Chrome if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>bv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', BrowserLauncher.Behavior.default)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nbv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tbv',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('brave', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('chrome') # {{{2
  # Chrome: View current file, starting Chrome if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>gc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', BrowserLauncher.Behavior.default)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ngc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tgc',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('chrome', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('edge') # {{{2
  # Edge: View current file, starting Microsoft Edge if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ed',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', BrowserLauncher.Behavior.default)<CR>"
  )
  # Edge: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ned',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Edge: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ted',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('edge', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('firefox') # {{{2
  # Firefox: View current file, starting Firefox if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', BrowserLauncher.Behavior.default)<CR>"
  )
  # Firefox: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Firefox: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tff',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('firefox', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('opera') # {{{2
  # Opera: View current file, starting Opera if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>oa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', BrowserLauncher.Behavior.default)<CR>"
  )
  # Opera: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>noa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Opera: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>toa',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('opera', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('safari') # {{{2
  # Safari: View current file, starting Safari if it's not running:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>sf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', BrowserLauncher.Behavior.default)<CR>"
  )
  # Safari: Open a new window, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nsf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', BrowserLauncher.Behavior.newwindow)<CR>"
    )
  # Safari: Open a new tab, and view the current file:
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tsf',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('safari', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('lynx') # {{{2
  # Lynx:  (This may happen anyway if there's no GUI available.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', BrowserLauncher.Behavior.default)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tly',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('lynx', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('w3m') # {{{2
  # w3m:  (This may happen anyway if there's no GUI available.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>w3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', BrowserLauncher.Behavior.default)<CR>"
  )
  # w3m in an xterm:  (This always happens in the Vim GUI.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nw3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # w3m in a new Vim window, using ":terminal":
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tw3',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('w3m', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif

if BrowserLauncherO.Exists('links') # {{{2
  # Links:  (This may happen anyway if there's no GUI available.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>ln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', BrowserLauncher.Behavior.default)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>nln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', BrowserLauncher.Behavior.newwindow)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  HTMLFunctionsO.Map(
    'nnoremap',
    '<lead>tln',
    "<ScriptCmd>b:htmlplugin.BrowserLauncherO.Launch('links', BrowserLauncher.Behavior.newtab)<CR>"
  )
endif # }}}2

# ----------------------------------------------------------------------------

endif # !HTMLFunctionsO.BoolVar('b:htmlplugin.did_mappings')

# ---- ToolBar Buttons and Menu Items: ---------------------------------- {{{1

if HTMLFunctionsO.BoolVar('g:htmlplugin.did_menus')
  HTMLFunctionsO.MenuControl()
  if !HTMLFunctionsO.BoolVar('b:htmlplugin.did_json')
    # Already did the menus but the tags and entities mappings need to be
    # defined for this new buffer:
    b:htmlplugin.did_json = true
    HTMLFunctionsO.ReadTags(false, true)
    HTMLFunctionsO.ReadEntities(false, true)
  endif
elseif HTMLFunctionsO.BoolVar('g:htmlplugin.no_menu')
  # No menus were requested, so just define the tags and entities mappings:
  if !HTMLFunctionsO.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    HTMLFunctionsO.ReadTags(false, true)
    HTMLFunctionsO.ReadEntities(false, true)
  endif
else

  # Solve a race condition:
  if ! exists('g:did_install_default_menus')
    source $VIMRUNTIME/menu.vim
  endif

  if !HTMLFunctionsO.BoolVar('g:htmlplugin.no_toolbar') && has('toolbar')

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

    HTMLFunctionsO.Menu('tmenu',     '1.10',  ['ToolBar', 'Open'],      'Open File')
    HTMLFunctionsO.Menu('anoremenu', '1.10',  ['ToolBar', 'Open'],      save_toolbar.open)
    HTMLFunctionsO.Menu('tmenu',     '1.20',  ['ToolBar', 'Save'],      'Save Current File')
    HTMLFunctionsO.Menu('anoremenu', '1.20',  ['ToolBar', 'Save'],      save_toolbar.save)
    HTMLFunctionsO.Menu('tmenu',     '1.30',  ['ToolBar', 'SaveAll'],   'Save All Files')
    HTMLFunctionsO.Menu('anoremenu', '1.30',  ['ToolBar', 'SaveAll'],   save_toolbar.saveall)

    HTMLFunctionsO.Menu('menu',      '1.50',  ['ToolBar', '-sep1-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.60',  ['ToolBar', 'Template'],  'Insert Template')
    HTMLFunctionsO.LeadMenu('amenu', '1.60',  ['ToolBar', 'Template'],  'html')

    HTMLFunctionsO.Menu('menu',      '1.65',  ['ToolBar', '-sep2-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.70',  ['ToolBar', 'Paragraph'], 'Create Paragraph')
    HTMLFunctionsO.LeadMenu('imenu', '1.70',  ['ToolBar', 'Paragraph'], 'pp')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Paragraph'], 'pp')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Paragraph'], 'pp', 'i')
    HTMLFunctionsO.Menu('tmenu',     '1.80',  ['ToolBar', 'Break'],     'Line Break')
    HTMLFunctionsO.LeadMenu('imenu', '1.80',  ['ToolBar', 'Break'],     'br')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Break'],     'br')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Break'],     'br', 'i')

    HTMLFunctionsO.Menu('menu',      '1.85',  ['ToolBar', '-sep3-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.90',  ['ToolBar', 'Link'],      'Create Hyperlink')
    HTMLFunctionsO.LeadMenu('imenu', '1.90',  ['ToolBar', 'Link'],      'ah')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Link'],      'ah')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Link'],      'ah', 'i')
    HTMLFunctionsO.Menu('tmenu',     '1.100', ['ToolBar', 'Image'],     'Insert Image')
    HTMLFunctionsO.LeadMenu('imenu', '1.100', ['ToolBar', 'Image'],     'im')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Image'],     'im')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Image'],     'im', 'i')

    HTMLFunctionsO.Menu('menu',      '1.105', ['ToolBar', '-sep4-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.110', ['ToolBar', 'Hline'],     'Create Horizontal Rule')
    HTMLFunctionsO.LeadMenu('imenu', '1.110', ['ToolBar', 'Hline'],     'hr')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Hline'],     'hr', 'i')

    HTMLFunctionsO.Menu('menu',      '1.115', ['ToolBar', '-sep5-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.120', ['ToolBar', 'Table'],     'Create Table')
    HTMLFunctionsO.LeadMenu('imenu', '1.120', ['ToolBar', 'Table'],     'tA <ESC>')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Table'],     'tA')

    HTMLFunctionsO.Menu('menu',      '1.125', ['ToolBar', '-sep6-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.130', ['ToolBar', 'Blist'],     'Create Bullet List')
    HTMLFunctionsO.Menu('imenu',     '1.130', ['ToolBar', 'Blist'],
      $'{g:htmlplugin.map_leader}ul{g:htmlplugin.map_leader}li')
    HTMLFunctionsO.Menu('vmenu',     '-',     ['ToolBar', 'Blist'], 
      $'{g:htmlplugin.map_leader}uli{g:htmlplugin.map_leader}li<ESC>')
    HTMLFunctionsO.Menu('nmenu',     '-',     ['ToolBar', 'Blist'], 
      $'i{g:htmlplugin.map_leader}ul{g:htmlplugin.map_leader}li')
    HTMLFunctionsO.Menu('tmenu',     '1.140', ['ToolBar', 'Nlist'],     'Create Numbered List')
    HTMLFunctionsO.Menu('imenu',     '1.140', ['ToolBar', 'Nlist'], 
      $'{g:htmlplugin.map_leader}ol{g:htmlplugin.map_leader}li')
    HTMLFunctionsO.Menu('vmenu',     '-',     ['ToolBar', 'Nlist'], 
      $'{g:htmlplugin.map_leader}oli{g:htmlplugin.map_leader}li<ESC>')
    HTMLFunctionsO.Menu('nmenu',     '-',     ['ToolBar', 'Nlist'], 
      $'i{g:htmlplugin.map_leader}ol{g:htmlplugin.map_leader}li')
    HTMLFunctionsO.Menu('tmenu',     '1.150', ['ToolBar', 'Litem'],     'Add List Item')
    HTMLFunctionsO.LeadMenu('imenu', '1.150', ['ToolBar', 'Litem'],     'li')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Litem'],     'li', 'i')

    HTMLFunctionsO.Menu('menu',      '1.155', ['ToolBar', '-sep7-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.160', ['ToolBar', 'Bold'],      'Bold')
    HTMLFunctionsO.LeadMenu('imenu', '1.160', ['ToolBar', 'Bold'],      'bo')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Bold'],      'bo')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Bold'],      'bo', 'i')
    HTMLFunctionsO.Menu('tmenu',     '1.170', ['ToolBar', 'Italic'],    'Italic')
    HTMLFunctionsO.LeadMenu('imenu', '1.170', ['ToolBar', 'Italic'],    'it')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Italic'],    'it')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Italic'],    'it', 'i')
    HTMLFunctionsO.Menu('tmenu',     '1.180', ['ToolBar', 'Underline'], 'Underline')
    HTMLFunctionsO.LeadMenu('imenu', '1.180', ['ToolBar', 'Underline'], 'un')
    HTMLFunctionsO.LeadMenu('vmenu', '-',     ['ToolBar', 'Underline'], 'un')
    HTMLFunctionsO.LeadMenu('nmenu', '-',     ['ToolBar', 'Underline'], 'un', 'i')

    HTMLFunctionsO.Menu('menu',      '1.185', ['ToolBar', '-sep8-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.190', ['ToolBar', 'Undo'],      'Undo')
    HTMLFunctionsO.Menu('anoremenu', '1.190', ['ToolBar', 'Undo'],      'u')
    HTMLFunctionsO.Menu('tmenu',     '1.200', ['ToolBar', 'Redo'],      'Redo')
    HTMLFunctionsO.Menu('anoremenu', '1.200', ['ToolBar', 'Redo'],      '<C-R>')

    HTMLFunctionsO.Menu('menu',      '1.205', ['ToolBar', '-sep9-'],    '<Nop>')

    HTMLFunctionsO.Menu('tmenu',     '1.210', ['ToolBar', 'Cut'],       'Cut to Clipboard')
    HTMLFunctionsO.Menu('vnoremenu', '1.210', ['ToolBar', 'Cut'],       save_toolbar.cut_v)
    HTMLFunctionsO.Menu('tmenu',     '1.220', ['ToolBar', 'Copy'],      'Copy to Clipboard')
    HTMLFunctionsO.Menu('vnoremenu', '1.220', ['ToolBar', 'Copy'],      save_toolbar.copy_v)
    HTMLFunctionsO.Menu('tmenu',     '1.230', ['ToolBar', 'Paste'],     'Paste from Clipboard')
    HTMLFunctionsO.Menu('nnoremenu', '1.230', ['ToolBar', 'Paste'],     save_toolbar.paste_n)
    HTMLFunctionsO.Menu('cnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_c)
    HTMLFunctionsO.Menu('inoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_i)
    HTMLFunctionsO.Menu('vnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar.paste_v)

    HTMLFunctionsO.Menu('menu',      '1.235', ['ToolBar', '-sep10-'],   '<Nop>')

    if !has('gui_athena')
      HTMLFunctionsO.Menu('tmenu',       '1.240', ['ToolBar', 'Replace'],  'Find / Replace')
      HTMLFunctionsO.Menu('anoremenu',   '1.240', ['ToolBar', 'Replace'],  save_toolbar.replace)
      vunmenu ToolBar.Replace
      HTMLFunctionsO.Menu('vnoremenu',   '-',     ['ToolBar', 'Replace'],  save_toolbar.replace_v)
      HTMLFunctionsO.Menu('tmenu',       '1.250', ['ToolBar', 'FindNext'], 'Find Next')
      HTMLFunctionsO.Menu('anoremenu',   '1.250', ['ToolBar', 'FindNext'], 'n')
      HTMLFunctionsO.Menu('tmenu',       '1.260', ['ToolBar', 'FindPrev'], 'Find Previous')
      HTMLFunctionsO.Menu('anoremenu',   '1.260', ['ToolBar', 'FindPrev'], 'N')
    endif

    HTMLFunctionsO.Menu('menu', '1.500', ['ToolBar', '-sep50-'], '<Nop>')

    if maparg($'{g:htmlplugin.map_leader}db', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.510', ['ToolBar', 'Browser'],
        'Launch the Default Browser on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.510', ['ToolBar', 'Browser'], 'db')
    endif

    if maparg($'{g:htmlplugin.map_leader}bv', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.520', ['ToolBar', 'Brave'],
        'Launch Brave on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.520', ['ToolBar', 'Brave'], 'bv')
    endif

    if maparg($'{g:htmlplugin.map_leader}gc', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.530', ['ToolBar', 'Chrome'],
        'Launch Chrome on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.530', ['ToolBar', 'Chrome'], 'gc')
    endif

    if maparg($'{g:htmlplugin.map_leader}ed', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.540', ['ToolBar', 'Edge'],
        'Launch Edge on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.540', ['ToolBar', 'Edge'], 'ed')
    endif

    if maparg($'{g:htmlplugin.map_leader}ff', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.550', ['ToolBar', 'Firefox'],
        'Launch Firefox on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.550', ['ToolBar', 'Firefox'], 'ff')
    endif

    if maparg($'{g:htmlplugin.map_leader}oa', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.560', ['ToolBar', 'Opera'],
        'Launch Opera on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.560', ['ToolBar', 'Opera'], 'oa')
    endif

    if maparg($'{g:htmlplugin.map_leader}sf', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.570', ['ToolBar', 'Safari'],
        'Launch Safari on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.570', ['ToolBar', 'Safari'], 'sf')
    endif

    if maparg($'{g:htmlplugin.map_leader}w3', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.580', ['ToolBar', 'w3m'],
        'Launch w3m on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.580', ['ToolBar', 'w3m'], 'w3')
    endif

    if maparg($'{g:htmlplugin.map_leader}ly', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.590', ['ToolBar', 'Lynx'],
        'Launch Lynx on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.590', ['ToolBar', 'Lynx'], 'ly')
    endif

    if maparg($'{g:htmlplugin.map_leader}ln', 'n') != ''
      HTMLFunctionsO.Menu('tmenu', '1.600', ['ToolBar', 'Links'],
        'Launch Links on the Current File')
      HTMLFunctionsO.LeadMenu('amenu', '1.600', ['ToolBar', 'Links'], 'ln')
    endif

    HTMLFunctionsO.Menu('menu',      '1.997', ['ToolBar', '-sep99-'], '<Nop>')
    HTMLFunctionsO.Menu('tmenu',     '1.998', ['ToolBar', 'HTMLHelp'], 'HTML Plugin Help')
    HTMLFunctionsO.Menu('anoremenu', '1.998', ['ToolBar', 'HTMLHelp'], ':help HTML.txt<CR>')

    HTMLFunctionsO.Menu('tmenu',     '1.999', ['ToolBar', 'Help'], 'Help')
    HTMLFunctionsO.Menu('anoremenu', '1.999', ['ToolBar', 'Help'], ':help<CR>')

    # }}}2

    g:htmlplugin.did_toolbar = true
  endif  # !HTMLFunctionsO.BoolVar('g:htmlplugin.no_toolbar') && has('toolbar')

  # Add to the PopUp menu:   {{{2
  HTMLFunctionsO.Menu('nnoremenu', '1.91', ['PopUp', 'Select Ta&g'],        'vat')
  HTMLFunctionsO.Menu('onoremenu', '-',    ['PopUp', 'Select Ta&g'],        'at')
  HTMLFunctionsO.Menu('vnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')
  HTMLFunctionsO.Menu('inoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-O>vat')
  HTMLFunctionsO.Menu('cnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')

  HTMLFunctionsO.Menu('nnoremenu', '1.92', ['PopUp', 'Select &Inner Ta&g'], 'vit')
  HTMLFunctionsO.Menu('onoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], 'it')
  HTMLFunctionsO.Menu('vnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  HTMLFunctionsO.Menu('inoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-O>vit')
  HTMLFunctionsO.Menu('cnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  # }}}2

  augroup HTMLmenu
    au!
    autocmd BufEnter,WinEnter * {
        HTMLFunctionsO.MenuControl()
        HTMLFunctionsO.ToggleClipboard()
      }
  augroup END

  # Create the "HTML" menu:   {{{2

  # Very first non-ToolBar, non-PopUp menu gets "auto" for its priority to place
  # the HTML menu according to user configuration:
  HTMLFunctionsO.Menu('amenu', 'auto', ['&Disable Mappings<tab>:HTML disable'],
    ':HTMLmappings disable<CR>')
  HTMLFunctionsO.Menu('amenu', '-',    ['&Enable Mappings<tab>:HTML enable'],
    ':HTMLmappings enable<CR>')

  execute $'amenu disable {g:htmlplugin.toplevel_menu_escaped}.Enable\ Mappings'

  HTMLFunctionsO.Menu('menu',  '.9999', ['-sep999-'], '<Nop>')

  HTMLFunctionsO.Menu('amenu', '.9999', ['Help', 'HTML Plugin Help<TAB>:help HTML.txt'],
    ':help HTML.txt<CR>')
  HTMLFunctionsO.Menu('amenu', '.9999', ['Help', 'About the HTML Plugin<TAB>:HTMLAbout'],
    ':HTMLAbout<CR>')

  if maparg($'{g:htmlplugin.map_leader}db', 'n') != ''
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Default Browser'], 'db')
  endif
  if maparg($'{g:htmlplugin.map_leader}bv', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep1-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Brave'], 'bv')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Window)'], 'nbv')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Tab)'], 'tbv')
  endif
  if maparg($'{g:htmlplugin.map_leader}gc', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep3-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Chrome'], 'gc')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Window)'], 'ngc')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Tab)'], 'tgc')
  endif
  if maparg($'{g:htmlplugin.map_leader}ed', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep4-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Edge'], 'ed')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Window)'], 'ned')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Tab)'], 'ted')
  endif
  if maparg($'{g:htmlplugin.map_leader}ff', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep2-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Firefox'], 'ff')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Window)'], 'nff')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Tab)'], 'tff')
  endif
  if maparg($'{g:htmlplugin.map_leader}oa', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep5-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Opera'], 'oa')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Window)'], 'noa')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Tab)'], 'toa')
  endif
  if maparg($'{g:htmlplugin.map_leader}sf', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep6-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Safari'], 'sf')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Window)'], 'nsf')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Tab)'], 'tsf')
  endif
  if maparg($'{g:htmlplugin.map_leader}ly', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep7-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&Lynx'], 'ly')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Lynx (New Window)'], 'nly')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Lynx (:terminal)'], 'tly')
  endif
  if maparg($'{g:htmlplugin.map_leader}w3', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep8-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', '&w3m'], 'w3')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'w3m (New Window)'], 'nw3')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'w3m (:terminal)'], 'tw3')
  endif
  if maparg($'{g:htmlplugin.map_leader}ln', 'n') != ''
    HTMLFunctionsO.Menu('menu', '-', ['Preview', '-sep9-'], '<nop>')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Li&nks'], 'ln')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Links (New Window)'], 'nln')
    HTMLFunctionsO.LeadMenu('amenu', '-', ['&Preview', 'Links (:terminal)'], 'tln')
  endif

  # Bring in the tags and entities menus and mappings at the same time. (If we
  # got here they weren't brought in above.):
  if !HTMLFunctionsO.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    HTMLFunctionsO.ReadTags(true, true)
    HTMLFunctionsO.ReadEntities(true, true)
  endif

  # Create the rest of the colors menu:
  HTMLVariables.HTMLVariables.COLOR_LIST->mapnew((_, value) => HTMLFunctionsO.ColorsMenu(value[0], value[1]))

  # }}}2

  g:htmlplugin.did_menus = true

endif
# ---------------------------------------------------------------------------

# ---- Finalize and Clean Up: ------------------------------------------- {{{1

# Try to reduce support requests from users:  {{{
if !HTMLFunctionsO.BoolVar('g:htmlplugin.did_old_variable_check') &&
    (exists('g:html_author_name') || exists('g:html_author_email')
    || exists('g:html_bgcolor') || exists('g:html_textcolor')
    || exists('g:html_alinkcolor') || exists('g:html_vlinkcolor')
    || exists('g:html_tag_case') || exists('g:html_map_leader')
    || exists('g:html_map_entity_leader') || exists('g:html_default_charset')
    || exists('g:html_template') || exists('g:no_html_map_override')
    || exists('g:no_html_maps') || exists('g:no_html_menu')
    || exists('g:no_html_toolbar') || exists('g:no_html_tab_mapping'))
  g:htmlplugin.did_old_variable_check = true
  var message = "You have set one of the old HTML plugin configuration variables.\n"
  .. "These variables are no longer used in favor of a new dictionary variable.\n\n"
  .. "Please refer to \":help html-variables\"."
  if message->confirm("&Help\n&Dismiss", 2, 'Warning') == 1
    help html-variables
    # Go to the previous window or everything gets messy:
    wincmd p
  endif
endif

if !HTMLFunctionsO.BoolVar('g:htmlplugin.did_plugin_warning_check')
  g:htmlplugin.did_plugin_warning_check = true
  var files = 'ftplugin/html/HTML.vim'->findfile(&runtimepath, -1)
  if files->len() > 1
    var filesmatched = files->Functions.HTMLFunctions.FilesWithMatch('https\?://christianrobinson.name/\%(\%(programming/\)\?vim/\)\?HTML/', 20)
    if filesmatched->len() > 1
      var message = "Multiple versions of the HTML plugin are installed.\n"
        .. "Locations:\n   " .. filesmatched->map((_, value) => value->fnamemodify(':~'))->join("\n   ")
        .. "\nIt is necessary that you remove old versions!\n"
        .. "(Don't forget about browser_launcher.vim/BrowserLauncher.vim and MangleImageTag.vim)"
      message->confirm('&Dismiss', 1, 'Warning')
    endif
  endif
endif
# }}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
