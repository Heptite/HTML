vim9script
scriptencoding utf8

if v:version < 900
  echoerr 'The HTML macros plugin no longer supports Vim versions prior to 9.0'
  sleep 3
  finish
endif

# ---- Author & Copyright: ---------------------------------------------- {{{1
#
# Author:           Christian J. Robinson <heptite(at)gmail(dot)com>
# URL:              https://christianrobinson.name/HTML/
# Last Change:      January 04, 2024
# Original Concept: Doug Renze
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
# ---- TODO: ------------------------------------------------------------ {{{1
#
# - Add a lot more character entities (see table in import/HTML.vim)
# - Add more HTML 5 tags?
#   https://www.w3.org/wiki/HTML/New_HTML5_Elements
#   https://www.w3.org/community/webed/wiki/HTML/New_HTML5_Elements
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

runtime commands/HTML/commands.vim

import '../../import/HTML/variables.vim' as HTMLvariables
import autoload 'HTML/functions.vim'
import autoload 'HTML/BrowserLauncher.vim'

if !functions.BoolVar('b:htmlplugin.did_mappings_init')
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
    authorname:             '',
    authoremail:            '',
    # Empty list means the HTML menu is its own toplevel:
    toplevel_menu:          [],
    # -1 means let Vim put the menu wherever it wants to by default:
    toplevel_menu_priority: -1,
    save_clipboard:         &clipboard,
  }, 'keep')
  # END configurable variables


  # Intitialize some necessary variables:  {{{2

  # Always set this, even if it was already set:
  if g:htmlplugin->has_key('file')
    unlockvar g:htmlplugin.file
  endif
  g:htmlplugin.file = expand('<sfile>:p')
  lockvar g:htmlplugin.file

  if type(g:htmlplugin.toplevel_menu) != v:t_list
    functions.Error('g:htmlplugin.toplevel_menu must be a list! Overriding.')
    sleep 3
    g:htmlplugin.toplevel_menu = []
  endif

  if !g:htmlplugin->has_key('toplevel_menu_escaped')
    g:htmlplugin.toplevel_menu_escaped =
      g:htmlplugin.toplevel_menu->add(HTMLvariables.MENU_NAME)->functions.MenuJoin()
    lockvar g:htmlplugin.toplevel_menu
    lockvar g:htmlplugin.toplevel_menu_escaped
  endif

  silent! setlocal clipboard+=html
  setlocal matchpairs+=<:>

  if g:htmlplugin.entity_map_leader ==# g:htmlplugin.map_leader
    functions.Error('"g:htmlplugin.entity_map_leader" and "g:htmlplugin.map_leader" have the same value!')
    functions.Error('Resetting both to their defaults (";" and "&" respectively).')
    sleep 3
    g:htmlplugin.map_leader = ';'
    g:htmlplugin.entity_map_leader = '&'
  endif


  # Detect whether to force uppper or lower case:  {{{2
  if &filetype ==? 'xhtml'
      || functions.BoolVar('g:htmlplugin.do_xhtml_mappings')
      || functions.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.do_xhtml_mappings = true
  else
    b:htmlplugin.do_xhtml_mappings = false

    if functions.BoolVar('g:htmlplugin.tag_case_autodetect')
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

  if functions.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.tag_case = 'lowercase'
  endif

  # Need to interpolate the value, which the command form of SetIfUnset doesn't
  # do:
  functions.SetIfUnset('b:htmlplugin.tag_case', g:htmlplugin.tag_case)

  # Template Creation: {{{2

  if functions.BoolVar('b:htmlplugin.do_xhtml_mappings')
    b:htmlplugin.internal_template = HTMLvariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"',
        ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
        '<html xmlns="http://www.w3.org/1999/xhtml">'
      ], 0)

    b:htmlplugin.internal_template =
      b:htmlplugin.internal_template->functions.ConvertCase()
  else
    b:htmlplugin.internal_template = HTMLvariables.INTERNAL_TEMPLATE->extendnew([
        '<!DOCTYPE html>',
        '<[{HTML}]>'
      ], 0)

    b:htmlplugin.internal_template =
      b:htmlplugin.internal_template->functions.ConvertCase()

    b:htmlplugin.internal_template =
      b:htmlplugin.internal_template->mapnew(
          (_, line) => {
            return line->substitute(' />', '>', 'g')
          }
        )
  endif

  # }}}2

endif # !functions.BoolVar('b:htmlplugin.did_mappings_init')

# ----------------------------------------------------------------------------

# ---- Miscellaneous Mappings: ------------------------------------------ {{{1

if !functions.BoolVar('b:htmlplugin.did_mappings')
b:htmlplugin.did_mappings = true

b:htmlplugin.clear_mappings = []

# Make it easy to use a ; (or whatever the map leader is) as normal:
functions.Map('inoremap', '<lead>' .. g:htmlplugin.map_leader, g:htmlplugin.map_leader, {extra: false})
functions.Map('vnoremap', '<lead>' .. g:htmlplugin.map_leader, g:htmlplugin.map_leader, {extra: false})
functions.Map('nnoremap', '<lead>' .. g:htmlplugin.map_leader, g:htmlplugin.map_leader)
# Make it easy to insert a & (or whatever the entity leader is):
functions.Map('inoremap', '<lead>' .. g:htmlplugin.entity_map_leader, g:htmlplugin.entity_map_leader, {extra: false})

if !functions.BoolVar('g:htmlplugin.no_tab_mapping')
  # Allow hard tabs to be used:
  functions.Map('inoremap', '<lead><tab>', '<tab>', {extra: false})
  functions.Map('nnoremap', '<lead><tab>', '<tab>')
  functions.Map('vnoremap', '<lead><tab>', '<tab>', {extra: false})
  # And shift-tabs too:
  functions.Map('inoremap', '<lead><s-tab>', '<s-tab>', {extra: false})
  functions.Map('nnoremap', '<lead><s-tab>', '<s-tab>')
  functions.Map('vnoremap', '<lead><s-tab>', '<s-tab>', {extra: false})

  # Tab takes us to a (hopefully) reasonable next insert point:
  functions.Map('inoremap', '<tab>', "<ScriptCmd>NextInsertPoint('i')<CR>", {extra: false})
  functions.Map('nnoremap', '<tab>', "<ScriptCmd>NextInsertPoint('n')<CR>")
  functions.Map('vnoremap', '<tab>', "<ScriptCmd>NextInsertPoint('n')<CR>", {extra: false})
  # ...And shift-tab goes backwards:
  functions.Map('inoremap', '<s-tab>', "<ScriptCmd>NextInsertPoint('i', 'b')<CR>", {extra: false})
  functions.Map('nnoremap', '<s-tab>', "<ScriptCmd>NextInsertPoint('n', 'b')<CR>")
  functions.Map('vnoremap', '<s-tab>', "<ScriptCmd>NextInsertPoint('n', 'b')<CR>", {extra: false})
else
  functions.Map('inoremap', '<lead><tab>', "<ScriptCmd>NextInsertPoint('i')<CR>", {extra: false})
  functions.Map('nnoremap', '<lead><tab>', "<ScriptCmd>NextInsertPoint('n')<CR>")
  functions.Map('vnoremap', '<lead><tab>', "<ScriptCmd>NextInsertPoint('n')<CR>", {extra: false})

  functions.Map('inoremap', '<lead><s-tab>', "<ScriptCmd>NextInsertPoint('i', 'b')<CR>")
  functions.Map('nnoremap', '<lead><s-tab>', "<ScriptCmd>NextInsertPoint('n', 'b')<CR>", {extra: false})
  functions.Map('vnoremap', '<lead><s-tab>', "<ScriptCmd>NextInsertPoint('n', 'b')<CR>", {extra: false})
endif

# ----------------------------------------------------------------------------

# ---- General Markup Tag Mappings: ------------------------------------- {{{1

# Can't conditionally set mappings in the tags.json file, so do this set of
# mappings here instead:

#       SGML Doctype Command
if functions.BoolVar('b:htmlplugin.do_xhtml_mappings')
  # Transitional XHTML (Looser):
  functions.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">'])<CR>")
  # Strict XHTML:
  functions.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"', ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">'])<CR>")
else
  # Transitional HTML (Looser):
  functions.Map('nnoremap', '<lead>4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"', ' \"http://www.w3.org/TR/html4/loose.dtd\">'])<CR>")
  # Strict HTML:
  functions.Map('nnoremap', '<lead>s4', "<ScriptCmd>append(0, ['<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"', ' \"http://www.w3.org/TR/html4/strict.dtd\">'])<CR>")
endif
functions.Map('imap', '<lead>4', '\<C-O>' .. g:htmlplugin.map_leader .. '4')
functions.Map('imap', '<lead>s4', '\<C-O>' .. g:htmlplugin.map_leader .. 's4')

#       HTML5 Doctype Command           HTML 5
functions.Map('nnoremap', '<lead>5', "<ScriptCmd>append(0, '<!DOCTYPE html>')<CR>")
functions.Map('imap', '<lead>5', '\<C-O>' .. g:htmlplugin.map_leader .. '5')


#       HTML
if functions.BoolVar('b:htmlplugin.do_xhtml_mappings')
  functions.Map('inoremap', '<lead>ht', '<html xmlns="http://www.w3.org/1999/xhtml"><CR></html>\<ESC>O')
  # Visual mapping:
  functions.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></html>\<C-O>`<<html xmlns="http://www.w3.org/1999/xhtml">\<CR>\<ESC>', {reindent: 1})
else
  functions.Map('inoremap', '<lead>ht', '<[{HTML}]>\<CR></[{HTML}]>\<ESC>O')
  # Visual mapping:
  functions.Map('vnoremap', '<lead>ht', '\<ESC>`>a\<CR></[{HTML}]>\<C-O>`<<[{HTML}]>\<CR>\<ESC>', {reindent: 1})
endif
# Motion mapping:
functions.Mapo('<lead>ht')

# ----------------------------------------------------------------------------

# ---- Browser Remote Controls: ----------------------------------------- {{{1

if BrowserLauncher.Exists('default')
  # Run the default browser:
  functions.Map(
    'nnoremap',
    '<lead>db',
    "<ScriptCmd>BrowserLauncher.Launch('default')<CR>"
  )
endif

if BrowserLauncher.Exists('brave')
  # Chrome: View current file, starting Chrome if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>bv',
    "<ScriptCmd>BrowserLauncher.Launch('brave', 0)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>nbv',
    "<ScriptCmd>BrowserLauncher.Launch('brave', 1)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>tbv',
    "<ScriptCmd>BrowserLauncher.Launch('brave', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('chrome')
  # Chrome: View current file, starting Chrome if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>gc',
    "<ScriptCmd>BrowserLauncher.Launch('chrome', 0)<CR>"
  )
  # Chrome: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>ngc',
    "<ScriptCmd>BrowserLauncher.Launch('chrome', 1)<CR>"
  )
  # Chrome: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>tgc',
    "<ScriptCmd>BrowserLauncher.Launch('chrome', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('edge')
  # Edge: View current file, starting Microsoft Edge if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>ed',
    "<ScriptCmd>BrowserLauncher.Launch('edge', 0)<CR>"
  )
  # Edge: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>ned',
    "<ScriptCmd>BrowserLauncher.Launch('edge', 1)<CR>"
  )
  # Edge: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>ted',
    "<ScriptCmd>BrowserLauncher.Launch('edge', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('firefox')
  # Firefox: View current file, starting Firefox if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>ff',
    "<ScriptCmd>BrowserLauncher.Launch('firefox', 0)<CR>"
  )
  # Firefox: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>nff',
    "<ScriptCmd>BrowserLauncher.Launch('firefox', 1)<CR>"
  )
  # Firefox: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>tff',
    "<ScriptCmd>BrowserLauncher.Launch('firefox', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('opera')
  # Opera: View current file, starting Opera if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>oa',
    "<ScriptCmd>BrowserLauncher.Launch('opera', 0)<CR>"
  )
  # Opera: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>noa',
    "<ScriptCmd>BrowserLauncher.Launch('opera', 1)<CR>"
  )
  # Opera: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>toa',
    "<ScriptCmd>BrowserLauncher.Launch('opera', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('safari')
  # Safari: View current file, starting Safari if it's not running:
  functions.Map(
    'nnoremap',
    '<lead>sf',
    "<ScriptCmd>BrowserLauncher.Launch('safari', 0)<CR>"
  )
  # Safari: Open a new window, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>nsf',
    "<ScriptCmd>BrowserLauncher.Launch('safari', 1)<CR>"
    )
  # Safari: Open a new tab, and view the current file:
  functions.Map(
    'nnoremap',
    '<lead>tsf',
    "<ScriptCmd>BrowserLauncher.Launch('safari', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('lynx')
  # Lynx:  (This may happen anyway if there's no GUI available.)
  functions.Map(
    'nnoremap',
    '<lead>ly',
    "<ScriptCmd>BrowserLauncher.Launch('lynx', 0)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  functions.Map(
    'nnoremap',
    '<lead>nly',
    "<ScriptCmd>BrowserLauncher.Launch('lynx', 1)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  functions.Map(
    'nnoremap',
    '<lead>tly',
    "<ScriptCmd>BrowserLauncher.Launch('lynx', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('w3m')
  # w3m:  (This may happen anyway if there's no GUI available.)
  functions.Map(
    'nnoremap',
    '<lead>w3',
    "<ScriptCmd>BrowserLauncher.Launch('w3m', 0)<CR>"
  )
  # w3m in an xterm:  (This always happens in the Vim GUI.)
  functions.Map(
    'nnoremap',
    '<lead>nw3',
    "<ScriptCmd>BrowserLauncher.Launch('w3m', 1)<CR>"
  )
  # w3m in a new Vim window, using ":terminal":
  functions.Map(
    'nnoremap',
    '<lead>tw3',
    "<ScriptCmd>BrowserLauncher.Launch('w3m', 2)<CR>"
  )
endif

if BrowserLauncher.Exists('links')
  # Links:  (This may happen anyway if there's no GUI available.)
  functions.Map(
    'nnoremap',
    '<lead>ln',
    "<ScriptCmd>BrowserLauncher.Launch('links', 0)<CR>"
  )
  # Lynx in an xterm:  (This always happens in the Vim GUI.)
  functions.Map(
    'nnoremap',
    '<lead>nln',
    "<ScriptCmd>BrowserLauncher.Launch('links', 1)<CR>"
  )
  # Lynx in a new Vim window, using ":terminal":
  functions.Map(
    'nnoremap',
    '<lead>tln',
    "<ScriptCmd>BrowserLauncher.Launch('links', 2)<CR>"
  )
endif

# ----------------------------------------------------------------------------

endif # !functions.BoolVar('b:htmlplugin.did_mappings')

# ---- ToolBar Buttons and Menu Items: ---------------------------------- {{{1

if functions.BoolVar('g:htmlplugin.did_menus')
  functions.MenuControl()
  if !functions.BoolVar('b:htmlplugin.did_json')
    # Already did the menus but the tags and entities mappings need to be
    # defined for this new buffer:
    b:htmlplugin.did_json = true
    functions.ReadTags(false, true)
    functions.ReadEntities(false, true)
  endif
elseif functions.BoolVar('g:htmlplugin.no_menu')
  # No menus were requested, so just define the tags and entities mappings:
  if !functions.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    functions.ReadTags(false, true)
    functions.ReadEntities(false, true)
  endif
else

  # Solve a race condition:
  if ! exists('g:did_install_default_menus')
    source $VIMRUNTIME/menu.vim
  endif

  if !functions.BoolVar('g:htmlplugin.no_toolbar') && has('toolbar')

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
    save_toolbar['open']      = menu_info('ToolBar.Open')['rhs']->escape('|')
    save_toolbar['save']      = menu_info('ToolBar.Save')['rhs']->escape('|')
    save_toolbar['saveall']   = menu_info('ToolBar.SaveAll')['rhs']->escape('|')
    save_toolbar['replace']   = menu_info('ToolBar.Replace')['rhs']->escape('|')
    save_toolbar['replace_v'] = menu_info('ToolBar.Replace', 'v')['rhs']->escape('|')
    save_toolbar['cut_v']     = menu_info('ToolBar.Cut', 'v')['rhs']->escape('|')
    save_toolbar['copy_v']    = menu_info('ToolBar.Copy', 'v')['rhs']->escape('|')
    save_toolbar['paste_n']   = menu_info('ToolBar.Paste', 'n')['rhs']->escape('|')
    save_toolbar['paste_c']   = menu_info('ToolBar.Paste', 'c')['rhs']->escape('|')
    save_toolbar['paste_i']   = menu_info('ToolBar.Paste', 'i')['rhs']->escape('|')
    save_toolbar['paste_v']   = menu_info('ToolBar.Paste', 'v')['rhs']->escape('|')

    silent! unmenu ToolBar
    silent! unmenu! ToolBar

    # Create the ToolBar:   {{{2

    # For some reason, the tmenu commands must come before the other menu
    # commands for that menu item, or GTK versions of gVim don't show the
    # icons properly.

    functions.Menu('tmenu',     '1.10',  ['ToolBar', 'Open'],      'Open File')
    functions.Menu('anoremenu', '1.10',  ['ToolBar', 'Open'],      save_toolbar['open'])
    functions.Menu('tmenu',     '1.20',  ['ToolBar', 'Save'],      'Save Current File')
    functions.Menu('anoremenu', '1.20',  ['ToolBar', 'Save'],      save_toolbar['save'])
    functions.Menu('tmenu',     '1.30',  ['ToolBar', 'SaveAll'],   'Save All Files')
    functions.Menu('anoremenu', '1.30',  ['ToolBar', 'SaveAll'],   save_toolbar['saveall'])

    functions.Menu('menu',      '1.50',  ['ToolBar', '-sep1-'],    '<Nop>')

    functions.Menu('tmenu',     '1.60',  ['ToolBar', 'Template'],  'Insert Template')
    functions.LeadMenu('amenu', '1.60',  ['ToolBar', 'Template'],  'html')

    functions.Menu('menu',      '1.65',  ['ToolBar', '-sep2-'],    '<Nop>')

    functions.Menu('tmenu',     '1.70',  ['ToolBar', 'Paragraph'], 'Create Paragraph')
    functions.LeadMenu('imenu', '1.70',  ['ToolBar', 'Paragraph'], 'pp')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Paragraph'], 'pp')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Paragraph'], 'pp', 'i')
    functions.Menu('tmenu',     '1.80',  ['ToolBar', 'Break'],     'Line Break')
    functions.LeadMenu('imenu', '1.80',  ['ToolBar', 'Break'],     'br')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Break'],     'br')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Break'],     'br', 'i')

    functions.Menu('menu',      '1.85',  ['ToolBar', '-sep3-'],    '<Nop>')

    functions.Menu('tmenu',     '1.90',  ['ToolBar', 'Link'],      'Create Hyperlink')
    functions.LeadMenu('imenu', '1.90',  ['ToolBar', 'Link'],      'ah')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Link'],      'ah')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Link'],      'ah', 'i')
    functions.Menu('tmenu',     '1.100', ['ToolBar', 'Image'],     'Insert Image')
    functions.LeadMenu('imenu', '1.100', ['ToolBar', 'Image'],     'im')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Image'],     'im')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Image'],     'im', 'i')

    functions.Menu('menu',      '1.105', ['ToolBar', '-sep4-'],    '<Nop>')

    functions.Menu('tmenu',     '1.110', ['ToolBar', 'Hline'],     'Create Horizontal Rule')
    functions.LeadMenu('imenu', '1.110', ['ToolBar', 'Hline'],     'hr')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Hline'],     'hr', 'i')

    functions.Menu('menu',      '1.115', ['ToolBar', '-sep5-'],    '<Nop>')

    functions.Menu('tmenu',     '1.120', ['ToolBar', 'Table'],     'Create Table')
    functions.LeadMenu('imenu', '1.120', ['ToolBar', 'Table'],     'tA <ESC>')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Table'],     'tA')

    functions.Menu('menu',      '1.125', ['ToolBar', '-sep6-'],    '<Nop>')

    functions.Menu('tmenu',     '1.130', ['ToolBar', 'Blist'],     'Create Bullet List')
    functions.Menu('imenu',     '1.130', ['ToolBar', 'Blist'],
      g:htmlplugin.map_leader .. 'ul' .. g:htmlplugin.map_leader .. 'li')
    functions.Menu('vmenu',     '-',     ['ToolBar', 'Blist'], 
      g:htmlplugin.map_leader .. 'uli' .. g:htmlplugin.map_leader .. 'li<ESC>')
    functions.Menu('nmenu',     '-',     ['ToolBar', 'Blist'], 
      'i' .. g:htmlplugin.map_leader .. 'ul' .. g:htmlplugin.map_leader .. 'li')
    functions.Menu('tmenu',     '1.140', ['ToolBar', 'Nlist'],     'Create Numbered List')
    functions.Menu('imenu',     '1.140', ['ToolBar', 'Nlist'], 
      g:htmlplugin.map_leader .. 'ol' .. g:htmlplugin.map_leader .. 'li')
    functions.Menu('vmenu',     '-',     ['ToolBar', 'Nlist'], 
      g:htmlplugin.map_leader .. 'oli' .. g:htmlplugin.map_leader .. 'li<ESC>')
    functions.Menu('nmenu',     '-',     ['ToolBar', 'Nlist'], 
      'i' .. g:htmlplugin.map_leader .. 'ol' .. g:htmlplugin.map_leader .. 'li')
    functions.Menu('tmenu',     '1.150', ['ToolBar', 'Litem'],     'Add List Item')
    functions.LeadMenu('imenu', '1.150', ['ToolBar', 'Litem'],     'li')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Litem'],     'li', 'i')

    functions.Menu('menu',      '1.155', ['ToolBar', '-sep7-'],    '<Nop>')

    functions.Menu('tmenu',     '1.160', ['ToolBar', 'Bold'],      'Bold')
    functions.LeadMenu('imenu', '1.160', ['ToolBar', 'Bold'],      'bo')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Bold'],      'bo')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Bold'],      'bo', 'i')
    functions.Menu('tmenu',     '1.170', ['ToolBar', 'Italic'],    'Italic')
    functions.LeadMenu('imenu', '1.170', ['ToolBar', 'Italic'],    'it')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Italic'],    'it')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Italic'],    'it', 'i')
    functions.Menu('tmenu',     '1.180', ['ToolBar', 'Underline'], 'Underline')
    functions.LeadMenu('imenu', '1.180', ['ToolBar', 'Underline'], 'un')
    functions.LeadMenu('vmenu', '-',     ['ToolBar', 'Underline'], 'un')
    functions.LeadMenu('nmenu', '-',     ['ToolBar', 'Underline'], 'un', 'i')

    functions.Menu('menu',      '1.185', ['ToolBar', '-sep8-'],    '<Nop>')

    functions.Menu('tmenu',     '1.190', ['ToolBar', 'Undo'],      'Undo')
    functions.Menu('anoremenu', '1.190', ['ToolBar', 'Undo'],      'u')
    functions.Menu('tmenu',     '1.200', ['ToolBar', 'Redo'],      'Redo')
    functions.Menu('anoremenu', '1.200', ['ToolBar', 'Redo'],      '<C-R>')

    functions.Menu('menu',      '1.205', ['ToolBar', '-sep9-'],    '<Nop>')

    functions.Menu('tmenu',     '1.210', ['ToolBar', 'Cut'],       'Cut to Clipboard')
    functions.Menu('vnoremenu', '1.210', ['ToolBar', 'Cut'],       save_toolbar['cut_v'])
    functions.Menu('tmenu',     '1.220', ['ToolBar', 'Copy'],      'Copy to Clipboard')
    functions.Menu('vnoremenu', '1.220', ['ToolBar', 'Copy'],      save_toolbar['copy_v'])
    functions.Menu('tmenu',     '1.230', ['ToolBar', 'Paste'],     'Paste from Clipboard')
    functions.Menu('nnoremenu', '1.230', ['ToolBar', 'Paste'],     save_toolbar['paste_n'])
    functions.Menu('cnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar['paste_c'])
    functions.Menu('inoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar['paste_i'])
    functions.Menu('vnoremenu', '-',     ['ToolBar', 'Paste'],     save_toolbar['paste_v'])

    functions.Menu('menu',      '1.235', ['ToolBar', '-sep10-'],   '<Nop>')

    if !has('gui_athena')
      functions.Menu('tmenu',       '1.240', ['ToolBar', 'Replace'],  'Find / Replace')
      functions.Menu('anoremenu',   '1.240', ['ToolBar', 'Replace'],  save_toolbar['replace'])
      vunmenu ToolBar.Replace
      functions.Menu('vnoremenu',   '-',     ['ToolBar', 'Replace'],  save_toolbar['replace_v'])
      functions.Menu('tmenu',       '1.250', ['ToolBar', 'FindNext'], 'Find Next')
      functions.Menu('anoremenu',   '1.250', ['ToolBar', 'FindNext'], 'n')
      functions.Menu('tmenu',       '1.260', ['ToolBar', 'FindPrev'], 'Find Previous')
      functions.Menu('anoremenu',   '1.260', ['ToolBar', 'FindPrev'], 'N')
    endif

    functions.Menu('menu', '1.500', ['ToolBar', '-sep50-'], '<Nop>')

    if maparg(g:htmlplugin.map_leader .. 'db', 'n') != ''
      functions.Menu('tmenu', '1.510', ['ToolBar', 'Browser'],
        'Launch the Default Browser on the Current File')
      functions.LeadMenu('amenu', '1.510', ['ToolBar', 'Browser'], 'db')
    endif

    if maparg(g:htmlplugin.map_leader .. 'bv', 'n') != ''
      functions.Menu('tmenu', '1.520', ['ToolBar', 'Brave'],
        'Launch Brave on the Current File')
      functions.LeadMenu('amenu', '1.520', ['ToolBar', 'Brave'], 'bv')
    endif

    if maparg(g:htmlplugin.map_leader .. 'gc', 'n') != ''
      functions.Menu('tmenu', '1.530', ['ToolBar', 'Chrome'],
        'Launch Chrome on the Current File')
      functions.LeadMenu('amenu', '1.530', ['ToolBar', 'Chrome'], 'gc')
    endif

    if maparg(g:htmlplugin.map_leader .. 'ed', 'n') != ''
      functions.Menu('tmenu', '1.540', ['ToolBar', 'Edge'],
        'Launch Edge on the Current File')
      functions.LeadMenu('amenu', '1.540', ['ToolBar', 'Edge'], 'ed')
    endif

    if maparg(g:htmlplugin.map_leader .. 'ff', 'n') != ''
      functions.Menu('tmenu', '1.550', ['ToolBar', 'Firefox'],
        'Launch Firefox on the Current File')
      functions.LeadMenu('amenu', '1.550', ['ToolBar', 'Firefox'], 'ff')
    endif

    if maparg(g:htmlplugin.map_leader .. 'oa', 'n') != ''
      functions.Menu('tmenu', '1.560', ['ToolBar', 'Opera'],
        'Launch Opera on the Current File')
      functions.LeadMenu('amenu', '1.560', ['ToolBar', 'Opera'], 'oa')
    endif

    if maparg(g:htmlplugin.map_leader .. 'sf', 'n') != ''
      functions.Menu('tmenu', '1.570', ['ToolBar', 'Safari'],
        'Launch Safari on the Current File')
      functions.LeadMenu('amenu', '1.570', ['ToolBar', 'Safari'], 'sf')
    endif

    if maparg(g:htmlplugin.map_leader .. 'w3', 'n') != ''
      functions.Menu('tmenu', '1.580', ['ToolBar', 'w3m'],
        'Launch w3m on the Current File')
      functions.LeadMenu('amenu', '1.580', ['ToolBar', 'w3m'], 'w3')
    endif

    if maparg(g:htmlplugin.map_leader .. 'ly', 'n') != ''
      functions.Menu('tmenu', '1.590', ['ToolBar', 'Lynx'],
        'Launch Lynx on the Current File')
      functions.LeadMenu('amenu', '1.590', ['ToolBar', 'Lynx'], 'ly')
    endif

    if maparg(g:htmlplugin.map_leader .. 'ln', 'n') != ''
      functions.Menu('tmenu', '1.600', ['ToolBar', 'Links'],
        'Launch Links on the Current File')
      functions.LeadMenu('amenu', '1.600', ['ToolBar', 'Links'], 'ln')
    endif

    functions.Menu('menu',      '1.997', ['ToolBar', '-sep99-'], '<Nop>')
    functions.Menu('tmenu',     '1.998', ['ToolBar', 'HTMLHelp'], 'HTML Plugin Help')
    functions.Menu('anoremenu', '1.998', ['ToolBar', 'HTMLHelp'], ':help HTML.txt<CR>')

    functions.Menu('tmenu',     '1.999', ['ToolBar', 'Help'], 'Help')
    functions.Menu('anoremenu', '1.999', ['ToolBar', 'Help'], ':help<CR>')

    # }}}2

    g:htmlplugin.did_toolbar = true
  endif  # !functions.BoolVar('g:htmlplugin.no_toolbar') && has('toolbar')

  # Add to the PopUp menu:   {{{2
  functions.Menu('nnoremenu', '1.91', ['PopUp', 'Select Ta&g'],        'vat')
  functions.Menu('onoremenu', '-',    ['PopUp', 'Select Ta&g'],        'at')
  functions.Menu('vnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')
  functions.Menu('inoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-O>vat')
  functions.Menu('cnoremenu', '-',    ['PopUp', 'Select Ta&g'],        '<C-c>vat')

  functions.Menu('nnoremenu', '1.92', ['PopUp', 'Select &Inner Ta&g'], 'vit')
  functions.Menu('onoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], 'it')
  functions.Menu('vnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  functions.Menu('inoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-O>vit')
  functions.Menu('cnoremenu', '-',    ['PopUp', 'Select &Inner Ta&g'], '<C-c>vit')
  # }}}2

  augroup HTMLmenu
    au!
    autocmd BufEnter,WinEnter * {
        functions.MenuControl()
        functions.ToggleClipboard()
      }
  augroup END

  # Create the "HTML" menu:   {{{2

  # Very first non-ToolBar, non-PopUp menu gets "auto" for its priority to place
  # the HTML menu according to user configuration:
  functions.Menu('amenu', 'auto', ['&Disable Mappings<tab>:HTML disable'],
    ':HTMLmappings disable<CR>')
  functions.Menu('amenu', '-',    ['&Enable Mappings<tab>:HTML enable'],
    ':HTMLmappings enable<CR>')

  execute 'amenu disable ' .. g:htmlplugin.toplevel_menu_escaped
    .. '.Enable\ Mappings'

  functions.Menu('menu',  '.9999', ['-sep999-'], '<Nop>')

  functions.Menu('amenu', '.9999', ['Help', 'HTML Plugin Help<TAB>:help HTML.txt'],
    ':help HTML.txt<CR>')
  functions.Menu('amenu', '.9999', ['Help', 'About the HTML Plugin<TAB>:HTMLAbout'],
    ':HTMLAbout<CR>')

  if maparg(g:htmlplugin.map_leader .. 'db', 'n') != ''
    functions.LeadMenu('amenu', '-', ['&Preview', '&Default Browser'], 'db')
  endif
  if maparg(g:htmlplugin.map_leader .. 'bv', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep1-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Brave'], 'bv')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Window)'], 'nbv')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Brave (New Tab)'], 'tbv')
  endif
  if maparg(g:htmlplugin.map_leader .. 'gc', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep3-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Chrome'], 'gc')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Window)'], 'ngc')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Chrome (New Tab)'], 'tgc')
  endif
  if maparg(g:htmlplugin.map_leader .. 'ed', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep4-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Edge'], 'ed')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Window)'], 'ned')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Edge (New Tab)'], 'ted')
  endif
  if maparg(g:htmlplugin.map_leader .. 'ff', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep2-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Firefox'], 'ff')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Window)'], 'nff')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Firefox (New Tab)'], 'tff')
  endif
  if maparg(g:htmlplugin.map_leader .. 'oa', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep5-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Opera'], 'oa')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Window)'], 'noa')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Opera (New Tab)'], 'toa')
  endif
  if maparg(g:htmlplugin.map_leader .. 'sf', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep6-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Safari'], 'sf')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Window)'], 'nsf')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Safari (New Tab)'], 'tsf')
  endif
  if maparg(g:htmlplugin.map_leader .. 'ly', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep7-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&Lynx'], 'ly')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Lynx (New Window)'], 'nly')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Lynx (:terminal)'], 'tly')
  endif
  if maparg(g:htmlplugin.map_leader .. 'w3', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep8-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', '&w3m'], 'w3')
    functions.LeadMenu('amenu', '-', ['&Preview', 'w3m (New Window)'], 'nw3')
    functions.LeadMenu('amenu', '-', ['&Preview', 'w3m (:terminal)'], 'tw3')
  endif
  if maparg(g:htmlplugin.map_leader .. 'ln', 'n') != ''
    functions.Menu('menu', '-', ['Preview', '-sep9-'], '<nop>')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Li&nks'], 'ln')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Links (New Window)'], 'nln')
    functions.LeadMenu('amenu', '-', ['&Preview', 'Links (:terminal)'], 'tln')
  endif

  # Bring in the tags and entities menus and mappings at the same time. (If we
  # got here they weren't brought in above.):
  if !functions.BoolVar('b:htmlplugin.did_json')
    b:htmlplugin.did_json = true
    functions.ReadTags(true, true)
    functions.ReadEntities(true, true)
  endif

  # Create the rest of the colors menu:
  HTMLvariables.COLOR_LIST->mapnew((_, value) => functions.ColorsMenu(value[0], value[1], value[2], value[3]))

  # }}}2

  g:htmlplugin.did_menus = true

endif
# ---------------------------------------------------------------------------

# ---- Finalize and Clean Up: ------------------------------------------- {{{1

# Try to reduce support requests from users:  {{{
if !functions.BoolVar('g:htmlplugin.did_old_variable_check') &&
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

if !functions.BoolVar('g:htmlplugin.did_plugin_warning_check')
  g:htmlplugin.did_plugin_warning_check = true
  var files = 'ftplugin/html/HTML.vim'->findfile(&runtimepath, -1)
  if files->len() > 1
    var filesmatched = files->functions.FilesWithMatch('https\?://christianrobinson.name/\%(\%(programming/\)\?vim/\)\?HTML/', 20)
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
