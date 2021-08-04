vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8023270
  echoerr 'The HTML macros plugin no longer supports Vim versions prior to 8.2.3236'
  sleep 3
  finish
endif

# ---- Author & Copyright: ---------------------------------------------- {{{1
#
# Author:      Christian J. Robinson <heptite@gmail.com>
# URL:         https://christianrobinson.name/HTML/
# Last Change: August 04, 2021
# Version:     1.1.1
# Original Concept: Doug Renze
#
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
# - Add a lot more character entities (see table in autoload/HTML.vim)
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

# ---- Commands: -------------------------------------------------------- {{{2

if ! exists('g:did_html_commands') || ! g:did_html_commands 
  g:did_html_commands = true

  command! -nargs=+ HTMLWARN {
      echohl WarningMsg
      echomsg <q-args>
      echohl None
    }
  command! -nargs=+ HTMLMESG {
      echohl Todo
      echo <q-args>
      echohl None
    }
  command! -nargs=+ HTMLERROR {
      echohl ErrorMsg
      echomsg <q-args>
      echohl None
    }
  command! -nargs=+ SetIfUnset HTML#SetIfUnset(<f-args>)
  command! -nargs=1 HTMLmappings HTML#MappingsControl(<f-args>)
  command! -nargs=1 HTMLMappings HTML#MappingsControl(<f-args>)
  if exists(':HTML') != 2
    command! -nargs=1 HTML HTML#MappingsControl(<f-args>)
  endif
  command! -nargs=? ColorSelect HTML#ShowColors(<f-args>)
  if exists(':CS') != 2
    command! -nargs=? CS HTML#ShowColors(<f-args>)
  endif
  command! HTMLReloadFunctions {
      if exists('g:html_function_files')
        for f in copy(g:html_function_files)
          execute 'HTMLMESG Reloading: ' .. fnamemodify(f, ':t')
          execute 'source ' .. f
        endfor
      else
        HTMLERROR Somehow the global variable describing the loaded function files is non-existent.
      endif
    }
endif

# ----------------------------------------------------------------------- }}}2

if ! exists('b:did_html_mappings_init')
  # This must be a number, not a boolean, because a -1 special case is used by
  # one of the functions:
  b:did_html_mappings_init = 1

  # Configuration variables:  {{{2
  # (These should be set in the user's vimrc or a filetype plugin, rather than
  # changed here.)
  SetIfUnset g:html_bgcolor           #FFFFFF
  SetIfUnset g:html_textcolor         #000000
  SetIfUnset g:html_linkcolor         #0000EE
  SetIfUnset g:html_alinkcolor        #FF0000
  SetIfUnset g:html_vlinkcolor        #990066
  SetIfUnset g:html_tag_case          lowercase
  SetIfUnset g:html_map_leader        ;
  SetIfUnset g:html_map_entity_leader &
  # SetIfUnset g:html_default_charset   iso-8859-1
  SetIfUnset g:html_default_charset   UTF-8
  # No way to know sensible defaults here so just make sure the
  # variables are set:
  SetIfUnset g:html_authorname        ''
  SetIfUnset g:html_authoremail       ''
  # END configurable variables

  # Intitialize some necessary variables:  {{{2
  SetIfUnset g:html_color_list {}
  SetIfUnset g:html_function_files []

  # Always set this, even if it was already set:
  g:html_plugin_file = expand('<sfile>:p')

  # Need to inerpolate the value, which the command form of SetIfUnset doesn't
  # do:
  HTML#SetIfUnset('g:html_save_clipboard', &clipboard)

  silent! setlocal clipboard+=html
  setlocal matchpairs+=<:>

  if g:html_map_entity_leader ==# g:html_map_leader
    HTMLERROR "g:html_map_entity_leader" and "g:html_map_leader" have the same value!
    HTMLERROR Resetting "g:html_map_entity_leader" to "&".
    sleep 3
    g:html_map_entity_leader = '&'
  endif

  if exists('b:html_tag_case')
    b:html_tag_case_save = b:html_tag_case
  endif

  # Detect whether to force uppper or lower case:  {{{2
  if &filetype ==? 'xhtml'
      || HTML#BoolVar('g:do_xhtml_mappings')
      || HTML#BoolVar('b:do_xhtml_mappings')
    b:do_xhtml_mappings = true
  else
    b:do_xhtml_mappings = false

    if HTML#BoolVar('g:html_tag_case_autodetect')
        && (line('$') != 1 || getline(1) != '')

      var found_upper = search('\C<\(\s*/\)\?\s*\u\+\_[^<>]*>', 'wn')
      var found_lower = search('\C<\(\s*/\)\?\s*\l\+\_[^<>]*>', 'wn')

      if found_upper != 0 && found_lower == 0
        b:html_tag_case = 'uppercase'
      elseif found_upper == 0 && found_lower != 0
        b:html_tag_case = 'lowercase'
      else
        # Found a combination of upper and lower case, so just use the user
        # preference:
        b:html_tag_case = g:html_tag_case
      endif
    endif
  endif

  if HTML#BoolVar('b:do_xhtml_mappings')
    b:html_tag_case = 'lowercase'
  endif

  # Need to inerpolate the value, which the command form of SetIfUnset doesn't
  # do:
  HTML#SetIfUnset('b:html_tag_case', g:html_tag_case)

  # Template Creation: {{{2

  var internal_html_template = [
    ' <[{HEAD}]>',
    '',
    '  <[{TITLE></TITLE}]>',
    '',
    '  <[{META HTTP-EQUIV}]="Content-Type" [{CONTENT}]="text/html; charset=%charset%" />',
    '  <[{META NAME}]="Generator" [{CONTENT}]="Vim %vimversion% (Vi IMproved editor; http://www.vim.org/)" />',
    '  <[{META NAME}]="Author" [{CONTENT}]="%authorname%" />',
    '  <[{META NAME}]="Copyright" [{CONTENT}]="Copyright (C) %date% %authorname%" />',
    '  <[{LINK REL}]="made" [{HREF}]="mailto:%authoremail%" />',
    '',
    '  <[{STYLE TYPE}]="text/css">',
    '   <!--',
    '   [{BODY}] {background: %bgcolor%; color: %textcolor%;}',
    '   [{A}]:link {color: %linkcolor%;}',
    '   [{A}]:visited {color: %vlinkcolor%;}',
    '   [{A}]:hover, [{A}]:active, [{A}]:focus {color: %alinkcolor%;}',
    '   -->',
    '  </[{STYLE}]>',
    '',
    ' </[{HEAD}]>',
    ' <[{BODY}]>',
    '',
    '  <[{H1 STYLE}]="text-align: center;"></[{H1}]>',
    '',
    '  <[{P}]>',
    '  </[{P}]>',
    '',
    '  <[{HR STYLE}]="width: 75%;" />',
    '',
    '  <[{P}]>',
    '  Last Modified: <[{I}]>%date%</[{I}]>',
    '  </[{P}]>',
    '',
    '  <[{ADDRESS}]>',
    '   <[{A HREF}]="mailto:%authoremail%">%authorname% &lt;%authoremail%&gt;</[{A}]>',
    '  </[{ADDRESS}]>',
    ' </[{BODY}]>',
    '</[{HTML}]>'
  ]

  if HTML#BoolVar('b:do_xhtml_mappings')
    internal_html_template->extend([
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"',
      ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
      '<html xmlns="http://www.w3.org/1999/xhtml">'
    ], 0)

    b:internal_html_template = internal_html_template->HTML#ConvertCase()->join("\n")
  else
    internal_html_template->extend([
      '<!DOCTYPE html>',
      '<[{HTML}]>'
    ], 0)

    b:internal_html_template = internal_html_template->HTML#ConvertCase()->join("\n")

    b:internal_html_template = b:internal_html_template->substitute(' />', '>', 'g')
  endif

  # }}}2

endif # ! exists('b:did_html_mappings_init')

# ----------------------------------------------------------------------------

# ---- Miscellaneous Mappings: ------------------------------------------ {{{1

g:doing_internal_html_mappings = true

if ! exists('b:did_html_mappings')
b:did_html_mappings = true

b:HTMLclearMappings = []

# Make it easy to use a ; (or whatever the map leader is) as normal:
HTML#Map('inoremap', '<lead>' .. g:html_map_leader, g:html_map_leader)
HTML#Map('vnoremap', '<lead>' .. g:html_map_leader, g:html_map_leader, {'extra': false})
HTML#Map('nnoremap', '<lead>' .. g:html_map_leader, g:html_map_leader)
# Make it easy to insert a & (or whatever the entity leader is):
HTML#Map('inoremap', '<lead>' .. g:html_map_entity_leader, g:html_map_entity_leader)

if ! HTML#BoolVar('g:no_html_tab_mapping')
  # Allow hard tabs to be used:
  HTML#Map('inoremap', '<lead><tab>', '<tab>')
  HTML#Map('nnoremap', '<lead><tab>', '<tab>')
  HTML#Map('vnoremap', '<lead><tab>', '<tab>', {'extra': false})
  # And shift-tabs too:
  HTML#Map('inoremap', '<lead><s-tab>', '<s-tab>')
  HTML#Map('nnoremap', '<lead><s-tab>', '<s-tab>')
  HTML#Map('vnoremap', '<lead><s-tab>', '<s-tab>', {'extra': false})

  # Tab takes us to a (hopefully) reasonable next insert point:
  HTML#Map('inoremap', '<tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('i')<CR>")
  HTML#Map('nnoremap', '<tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n')<CR>")
  HTML#Map('vnoremap', '<tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n')<CR>", {'extra': false})
  # ...And shift-tab goes backwards:
  HTML#Map('inoremap', '<s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('i', 'b')<CR>")
  HTML#Map('nnoremap', '<s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n', 'b')<CR>")
  HTML#Map('vnoremap', '<s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n', 'b')<CR>", {'extra': false})
else
  HTML#Map('inoremap', '<lead><tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('i')<CR>")
  HTML#Map('nnoremap', '<lead><tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n')<CR>")
  HTML#Map('vnoremap', '<lead><tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n')<CR>", {'extra': false})

  HTML#Map('inoremap', '<lead><s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('i', 'b')<CR>")
  HTML#Map('nnoremap', '<lead><s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n', 'b')<CR>")
  HTML#Map('vnoremap', '<lead><s-tab>', "<Cmd>vim9cmd HTML#NextInsertPoint('n', 'b')<CR>", {'extra': false})
endif

# Update an image tag's WIDTH & HEIGHT attributes:
HTML#Map('nnoremap', '<lead>mi', '<Cmd>vim9cmd MangleImageTag#Update()<CR>')
HTML#Map('inoremap', '<lead>mi', '<Cmd>vim9cmd MangleImageTag#Update()<CR>')
HTML#Map('vnoremap', '<lead>mi', '<C-c>:vim9cmd MangleImageTag#Update()<CR>', {'extra': false})

# Insert an HTML template:
HTML#Map('nnoremap', '<lead>html', '<Cmd>vim9cmd if HTML#Template() \| startinsert \| endif<CR>')

# Show a color selection buffer:
HTML#Map('nnoremap', '<lead>3', '<Cmd>ColorSelect<CR>')
HTML#Map('inoremap', '<lead>3', '<Cmd>ColorSelect<CR>')
HTML#Map('vnoremap', '<lead>3', '<C-c>:ColorSelect<CR>', {'extra': false})

# ----------------------------------------------------------------------------

# ---- General Markup Tag Mappings: ------------------------------------- {{{1

#       SGML Doctype Command
if HTML#BoolVar('b:do_xhtml_mappings')
  # Transitional XHTML (Looser):
  HTML#Map('nnoremap', '<lead>4', "<Cmd>vim9cmd append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"') \\\| vim9cmd append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">')<CR>")
  # Strict XHTML:
  HTML#Map('nnoremap', '<lead>s4', "<Cmd>vim9cmd append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"') \\\| vim9cmd append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">')<CR>")
else
  # Transitional HTML (Looser):
  HTML#Map('nnoremap', '<lead>4', "<Cmd>vim9cmd append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"') \\\| vim9cmd append(1, ' \"http://www.w3.org/TR/html4/loose.dtd\">')<CR>")
  # Strict HTML:
  HTML#Map('nnoremap', '<lead>s4', "<Cmd>vim9cmd append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"') \\\| vim9cmd append(1, ' \"http://www.w3.org/TR/html4/strict.dtd\">')<CR>")
endif
HTML#Map('imap', '<lead>4', '<C-O>' .. g:html_map_leader .. '4')
HTML#Map('imap', '<lead>s4', '<C-O>' .. g:html_map_leader .. 's4')

#       HTML5 Doctype Command           HTML 5
HTML#Map('nnoremap', '<lead>5', "<Cmd>vim9cmd append(0, '<!DOCTYPE html>')<CR>")
HTML#Map('imap', '<lead>5', '<C-O>' .. g:html_map_leader .. '5')

#       Content-Type META tag
HTML#Map('inoremap', '<lead>ct', '<[{META HTTP-EQUIV}]="Content-Type" [{CONTENT}]="text/html; charset=<C-R>=HTML#DetectCharset()<CR>" />')

#       Comment Tag
HTML#Map('inoremap', '<lead>cm', "<C-R>=HTML#SmartTag('comment', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>cm', "<C-c>:execute 'normal! ' .. HTML#SmartTag('comment', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>cm')

#       A HREF  Anchor Hyperlink        HTML 2.0
# HTML#Map('inoremap', '<lead>ah', '<[{A HREF=""></A}]><C-O>F"')
# HTML#Map('inoremap', '<lead>aH', '<[{A HREF="<C-R>*"></A}]><C-O>F<')
HTML#Map('inoremap', '<lead>ah', "<C-R>=HTML#SmartTag('a1', 'i')<CR>")
HTML#Map('inoremap', '<lead>aH', "<C-R>=HTML#SmartTag('a2', 'i')<CR>")
# Visual mappings:
# HTML#Map('vnoremap', '<lead>ah', '<ESC>`>a</[{A}]><C-O>`<<[{A HREF}]=""><C-O>F"', {'insert': true})
# HTML#Map('vnoremap', '<lead>aH', '<ESC>`>a"></[{A}]><C-O>`<<[{A HREF}]="<C-O>f<', {'insert': true})
HTML#Map('vnoremap', '<lead>ah', "<C-c>:execute 'normal! ' .. HTML#SmartTag('a1', 'v')<CR>", {'insert': true})
HTML#Map('vnoremap', '<lead>aH', "<C-c>:execute 'normal! ' .. HTML#SmartTag('a2', 'v')<CR>", {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>ah', true)
HTML#Mapo('<lead>aH', true)

#       A HREF  Anchor Hyperlink, with TARGET=""
# HTML#Map('inoremap', '<lead>at', '<[{A HREF="" TARGET=""></A}]><C-O>3F"')
# HTML#Map('inoremap', '<lead>aT', '<[{A HREF="<C-R>*" TARGET=""></A}]><C-O>F"')
HTML#Map('inoremap', '<lead>at', "<C-R>=HTML#SmartTag('a3', 'i')<CR>")
HTML#Map('inoremap', '<lead>aT', "<C-R>=HTML#SmartTag('a4', 'i')<CR>")
# Visual mappings:
# HTML#Map('vnoremap', '<lead>at', '<ESC>`>a</[{A}]><C-O>`<<[{A HREF="" TARGET}]=""><C-O>3F"', {'insert': true})
# HTML#Map('vnoremap', '<lead>aT', '<ESC>`>a" [{TARGET=""></A}]><C-O>`<<[{A HREF}]="<C-O>3f"', {'insert': true})
HTML#Map('vnoremap', '<lead>at', "<C-c>:execute 'normal! ' .. HTML#SmartTag('a3', 'v')<CR>", {'insert': true})
HTML#Map('vnoremap', '<lead>aT', "<C-c>:execute 'normal! ' .. HTML#SmartTag('a4', 'v')<CR>", {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>at', true)
HTML#Mapo('<lead>aT', true)

#       A NAME  Named Anchor            HTML 2.0
#       (note this is not HTML 5 compatible, use ID attributes instead)
# HTML#Map('inoremap', '<lead>an', '<[{A NAME=""></A}]><C-O>F"')
# HTML#Map('inoremap', '<lead>aN', '<[{A NAME="<C-R>*"></A}]><C-O>F<')
# Visual mappings:
# HTML#Map('vnoremap', '<lead>an', '<ESC>`>a</[{A}]><C-O>`<<[{A NAME}]=""><C-O>F"', {'insert': true})
# HTML#Map('vnoremap', '<lead>aN', '<ESC>`>a"></[{A}]><C-O>`<<[{A NAME}]="<C-O>f<', {'insert': true})
# Motion mappings:
# HTML#Mapo('<lead>an', {'reindent': 1})
# HTML#Mapo('<lead>aN', {'reindent': 1})

#       ABBR  Abbreviation              HTML 4.0
HTML#Map('inoremap', '<lead>ab', '<[{ABBR TITLE=""></ABBR}]><C-O>F"')
HTML#Map('inoremap', '<lead>aB', '<[{ABBR TITLE="<C-R>*"></ABBR}]><C-O>F<')
# Visual mappings:
HTML#Map('vnoremap', '<lead>ab', '<ESC>`>a</[{ABBR}]><C-O>`<<[{ABBR TITLE}]=""><C-O>F"', {'insert': true})
HTML#Map('vnoremap', '<lead>aB', '<ESC>`>a"></[{ABBR}]><C-O>`<<[{ABBR TITLE}]="<C-O>f<', {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>ab', true)
HTML#Mapo('<lead>aB', true)

#       ACRONYM                         HTML 4.0
#       (note this is not HTML 5 compatible, use ABBR instead)
# HTML#Map('inoremap', '<lead>ac', '<[{ACRONYM TITLE=""></ACRONYM}]><C-O>F"')
# HTML#Map('inoremap', '<lead>aC', '<[{ACRONYM TITLE="<C-R>*"></ACRONYM}]><C-O>F<')
# Visual mappings:
# HTML#Map('vnoremap', '<lead>ac', '<ESC>`>a</[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]=""><C-O>F"', {'insert': true})
# HTML#Map('vnoremap', '<lead>aC', '<ESC>`>a"></[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]="<C-O>f<', {'insert': true})
# Motion mappings:
# HTML#Mapo('<lead>ac', true)
# HTML#Mapo('<lead>aC', true)

#       ADDRESS                         HTML 2.0
HTML#Map('inoremap', '<lead>ad', '<[{ADDRESS></ADDRESS}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ad', '<ESC>`>a</[{ADDRESS}]><C-O>`<<[{ADDRESS}]><ESC>')
# Motion mapping:
HTML#Mapo('<lead>ad')

#       ARTICLE Self-contained content  HTML 5
HTML#Map('inoremap', '<lead>ar', '<[{ARTICLE}]><CR></[{ARTICLE}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ar', '<ESC>`>a<CR></[{ARTICLE}]><C-O>`<<[{ARTICLE}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ar')

#       ASIDE   Content aside from context HTML 5
HTML#Map('inoremap', '<lead>as', '<[{ASIDE}]><CR></[{ASIDE}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>as', '<ESC>`>a<CR></[{ASIDE}]><C-O>`<<[{ASIDE}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>as')

#       AUDIO  Audio with controls      HTML 5
HTML#Map('inoremap', '<lead>au', '<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR>Your browser does not support the audio tag.<CR></[{AUDIO}]><ESC>kk$3F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>au', '<ESC>`>a<CR></[{AUDIO}]><C-O>`<<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR><ESC>k$3F"li', {'reindent': 2, 'insert': true})
# Motion mapping:
HTML#Mapo('<lead>au')

#       B       Boldfaced Text          HTML 2.0
HTML#Map('inoremap', '<lead>bo', "<C-R>=HTML#SmartTag('b', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>bo', "<C-c>:execute 'normal! ' .. HTML#SmartTag('b', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>bo')

#       BASE                            HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>bh', '<[{BASE HREF}]="" /><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>bh', '<ESC>`>a" /><C-O>`<<[{BASE HREF}]="<ESC>')
# Motion mapping:
HTML#Mapo('<lead>bh')

#       BASE TARGET                     HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>bt', '<[{BASE TARGET}]="" /><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>bt', '<ESC>`>a" /><C-O>`<<[{BASE TARGET}]="<ESC>')
# Motion mapping:
HTML#Mapo('<lead>bt')

#       BIG                             HTML 3.0
#       (<BIG> is not HTML 5 compatible, so we use CSS instead)
# HTML#Map('inoremap', '<lead>bi', '<[{BIG></BIG}]><C-O>F<')
HTML#Map('inoremap', '<lead>bi', '<[{SPAN STYLE}]="font-size: larger;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# HTML#Map('vnoremap', '<lead>bi', '<ESC>`>a</[{BIG}]><C-O>`<<[{BIG}]><ESC>')
HTML#Map('vnoremap', '<lead>bi', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: larger;"><ESC>')
# Motion mapping:
HTML#Mapo('<lead>bi')

#       BLOCKQUOTE                      HTML 2.0
# HTML#Map('inoremap', '<lead>bl', '<[{BLOCKQUOTE}]><CR></[{BLOCKQUOTE}]><ESC>O')
HTML#Map('inoremap', '<lead>bl', "<C-R>=HTML#SmartTag('blockquote', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>bl', '<ESC>`>a<CR></[{BLOCKQUOTE}]><C-O>`<<[{BLOCKQUOTE}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>bl', "<C-c>:execute 'normal! ' .. HTML#SmartTag('blockquote', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>bl')

#       BODY                            HTML 2.0
HTML#Map('inoremap', '<lead>bd', '<[{BODY}]><CR></[{BODY}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>bd', '<ESC>`>a<CR></[{BODY}]><C-O>`<<[{BODY}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>bd')

#       BR      Line break              HTML 2.0
HTML#Map('inoremap', '<lead>br', '<[{BR}] />')

#       BUTTON  Generic Button
HTML#Map('inoremap', '<lead>bn', '<[{BUTTON TYPE}]="button"></[{BUTTON}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>bn', '<ESC>`>a</[{BUTTON}]><C-O>`<<[{BUTTON TYPE}]="button"><ESC>')
# Motion mapping:
HTML#Mapo('<lead>bn')

#       CANVAS                          HTML 5
HTML#Map('inoremap', '<lead>cv', '<[{CANVAS WIDTH="" HEIGHT=""></CANVAS}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>cv', '<ESC>`>a</[{CANVAS}]><C-O>`<<[{CANVAS WIDTH="" HEIGHT=""}]><C-O>3F"', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>cv', true)

#       CENTER                          NETSCAPE
#       (<CENTER> is not HTML 5 compatible, so we use CSS instead)
# HTML#Map('inoremap', '<lead>ce', '<[{CENTER></CENTER}]><C-O>F<')
HTML#Map('inoremap', '<lead>ce', '<[{DIV STYLE}]="text-align: center;"><CR></[{DIV}]><ESC>O')
# Visual mapping:
# HTML#Map('vnoremap', '<lead>ce', '<ESC>`>a</[{CENTER}]><C-O>`<<[{CENTER}]><ESC>')
HTML#Map('vnoremap', '<lead>ce', '<ESC>`>a<CR></[{DIV}]><C-O>`<<[{DIV STYLE}]="text-align: center;"><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ce')

#       CITE                            HTML 2.0
# HTML#Map('inoremap', '<lead>ci', '<[{CITE></CITE}]><C-O>F<')
HTML#Map('inoremap', '<lead>ci', "<C-R>=HTML#SmartTag('cite', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>ci', '<ESC>`>a</[{CITE}]><C-O>`<<[{CITE}]><ESC>')
HTML#Map('vnoremap', '<lead>ci', "<C-c>:execute 'normal! ' .. HTML#SmartTag('cite', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>ci')

#       CODE                            HTML 2.0
# HTML#Map('inoremap', '<lead>co', '<[{CODE></CODE}]><C-O>F<')
HTML#Map('inoremap', '<lead>co', "<C-R>=HTML#SmartTag('code', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>co', '<ESC>`>a</[{CODE}]><C-O>`<<[{CODE}]><ESC>')
HTML#Map('vnoremap', '<lead>co', "<C-c>:execute 'normal! ' .. HTML#SmartTag('code', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>co')

#       DEFINITION LIST COMPONENTS      HTML 5
#               DL      Description List
#               DT      Description Term
#               DD      Description Body
HTML#Map('inoremap', '<lead>dl', '<[{DL}]><CR></[{DL}]><ESC>O')
HTML#Map('inoremap', '<lead>dt', '<[{DT}]></[{DT}]><C-O>F<')
HTML#Map('inoremap', '<lead>dd', '<[{DD}]></[{DD}]><C-O>F<')
# Visual mappings:
HTML#Map('vnoremap', '<lead>dl', '<ESC>`>a<CR></[{DL}]><C-O>`<<[{DL}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>dt', '<ESC>`>a</[{DT}]><C-O>`<<[{DT}]><ESC>')
HTML#Map('vnoremap', '<lead>dd', '<ESC>`>a</[{DD}]><C-O>`<<[{DD}]><ESC>')
# Motion mappings:
HTML#Mapo('<lead>dl')
HTML#Mapo('<lead>dt')
HTML#Mapo('<lead>dd')

#       DEL     Deleted Text            HTML 3.0
# HTML#Map('inoremap', '<lead>de', '<lt>[{DEL></DEL}]><C-O>F<')
HTML#Map('inoremap', '<lead>de', "<C-R>=HTML#SmartTag('del', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>de', '<ESC>`>a</[{DEL}]><C-O>`<<lt>[{DEL}]><ESC>')
HTML#Map('vnoremap', '<lead>de', "<C-c>:execute 'normal! ' .. HTML#SmartTag('del', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>de')

#       DETAILS Expandable details      HTML 5
HTML#Map('inoremap', '<lead>ds', '<[{DETAILS}]><CR><[{SUMMARY}]></[{SUMMARY}]><CR><[{P}]><CR></[{P}]><CR></[{DETAILS}]><ESC>3k$F<i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ds', '<ESC>`>a<CR></[{DETAILS}]><C-O>`<<[{DETAILS}]><CR><[{SUMMARY></SUMMARY}]><CR><ESC>k$F<a', {'insert': true, 'reindent': 2})
# Motion mapping:
HTML#Mapo('<lead>ds', true)

#       DFN     Defining Instance       HTML 3.0
# HTML#Map('inoremap', '<lead>df', '<[{DFN></DFN}]><C-O>F<')
HTML#Map('inoremap', '<lead>df', "<C-R>=HTML#SmartTag('dfn', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>df', '<ESC>`>a</[{DFN}]><C-O>`<<[{DFN}]><ESC>')
HTML#Map('vnoremap', '<lead>df', "<C-c>:execute 'normal! ' .. HTML#SmartTag('dfn', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>df')

#       DIV     Document Division       HTML 3.0
HTML#Map('inoremap', '<lead>dv', '<[{DIV}]><CR></[{DIV}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>dv', '<ESC>`>a<CR></[{DIV}]><C-O>`<<[{DIV}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>dv')

#       SPAN    Delimit Arbitrary Text  HTML 4.0
#       with CLASS attribute:
HTML#Map('inoremap', '<lead>sn', '<[{SPAN CLASS=""></SPAN}]><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>sn', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN CLASS}]=""><ESC>F"i', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>sn', true)
#       with STYLE attribute:
HTML#Map('inoremap', '<lead>ss', '<[{SPAN STYLE=""></SPAN}]><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ss', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]=""><ESC>F"i', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>ss', true)

#       EM      Emphasize               HTML 2.0
HTML#Map('inoremap', '<lead>em', "<C-R>=HTML#SmartTag('em', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>em', "<C-c>:execute 'normal! ' .. HTML#SmartTag('em', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>em')

#       FONT                            NETSCAPE
#       (<FONT> is not HTML 5 compatible, so we use CSS instead)
# HTML#Map('inoremap', '<lead>fo', '<[{FONT SIZE=""></FONT}]><C-O>F"')
# HTML#Map('inoremap', '<lead>fc', '<[{FONT COLOR=""></FONT}]><C-O>F"')
HTML#Map('inoremap', '<lead>fo', '<[{SPAN STYLE}]="font-size: ;"></[{SPAN}]><C-O>F;')
HTML#Map('inoremap', '<lead>fc', '<[{SPAN STYLE}]="color: ;"></[{SPAN}]><C-O>F;')
# Visual mappings:
# HTML#Map('vnoremap', '<lead>fo', '<ESC>`>a</[{FONT}]><C-O>`<<[{FONT SIZE}]=""><C-O>F"', {'insert': true})
# HTML#Map('vnoremap', '<lead>fc', '<ESC>`>a</[{FONT}]><C-O>`<<[{FONT COLOR}]=""><C-O>F"', {'insert': true})
HTML#Map('vnoremap', '<lead>fo', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: ;"><C-O>F;', {'insert': true})
HTML#Map('vnoremap', '<lead>fc', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="color: ;"><C-O>F;', {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>fo', true)
HTML#Mapo('<lead>fc', true)

#       FIGURE                          HTML 5
HTML#Map('inoremap', '<lead>fg', '<[{FIGURE><CR></FIGURE}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>fg', '<ESC>`>a<CR></[{FIGURE}]><C-O>`<<[{FIGURE}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>fg')

#       Figure Caption                  HTML 5
HTML#Map('inoremap', '<lead>fp', '<[{FIGCAPTION></FIGCAPTION}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>fp', '<ESC>`>a</[{FIGCAPTION}]><C-O>`<<[{FIGCAPTION}]><ESC>')
# Motion mapping:
HTML#Mapo('<lead>fp')

#       FOOOTER                         HTML 5
HTML#Map('inoremap', '<lead>ft', '<[{FOOTER><CR></FOOTER}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ft', '<ESC>`>a<CR></[{FOOTER}]><C-O>`<<[{FOOTER}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ft')

#       HEADER                          HTML 5
HTML#Map('inoremap', '<lead>hd', '<[{HEADER><CR></HEADER}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>hd', '<ESC>`>a<CR></[{HEADER}]><C-O>`<<[{HEADER}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>hd')

#       HEADINGS, LEVELS 1-6            HTML 2.0
HTML#Map('inoremap', '<lead>h1', '<[{H1}]></[{H1}]><C-O>F<')
HTML#Map('inoremap', '<lead>h2', '<[{H2}]></[{H2}]><C-O>F<')
HTML#Map('inoremap', '<lead>h3', '<[{H3}]></[{H3}]><C-O>F<')
HTML#Map('inoremap', '<lead>h4', '<[{H4}]></[{H4}]><C-O>F<')
HTML#Map('inoremap', '<lead>h5', '<[{H5}]></[{H5}]><C-O>F<')
HTML#Map('inoremap', '<lead>h6', '<[{H6}]></[{H6}]><C-O>F<')
HTML#Map('inoremap', '<lead>H1', '<[{H1 STYLE}]="text-align: center;"></[{H1}]><C-O>F<')
HTML#Map('inoremap', '<lead>H2', '<[{H2 STYLE}]="text-align: center;"></[{H2}]><C-O>F<')
HTML#Map('inoremap', '<lead>H3', '<[{H3 STYLE}]="text-align: center;"></[{H3}]><C-O>F<')
HTML#Map('inoremap', '<lead>H4', '<[{H4 STYLE}]="text-align: center;"></[{H4}]><C-O>F<')
HTML#Map('inoremap', '<lead>H5', '<[{H5 STYLE}]="text-align: center;"></[{H5}]><C-O>F<')
HTML#Map('inoremap', '<lead>H6', '<[{H6 STYLE}]="text-align: center;"></[{H6}]><C-O>F<')
# Visual mappings:
HTML#Map('vnoremap', '<lead>h1', '<ESC>`>a</[{H1}]><C-O>`<<[{H1}]><ESC>')
HTML#Map('vnoremap', '<lead>h2', '<ESC>`>a</[{H2}]><C-O>`<<[{H2}]><ESC>')
HTML#Map('vnoremap', '<lead>h3', '<ESC>`>a</[{H3}]><C-O>`<<[{H3}]><ESC>')
HTML#Map('vnoremap', '<lead>h4', '<ESC>`>a</[{H4}]><C-O>`<<[{H4}]><ESC>')
HTML#Map('vnoremap', '<lead>h5', '<ESC>`>a</[{H5}]><C-O>`<<[{H5}]><ESC>')
HTML#Map('vnoremap', '<lead>h6', '<ESC>`>a</[{H6}]><C-O>`<<[{H6}]><ESC>')
HTML#Map('vnoremap', '<lead>H1', '<ESC>`>a</[{H1}]><C-O>`<<[{H1 STYLE}]="text-align: center;"><ESC>')
HTML#Map('vnoremap', '<lead>H2', '<ESC>`>a</[{H2}]><C-O>`<<[{H2 STYLE}]="text-align: center;"><ESC>')
HTML#Map('vnoremap', '<lead>H3', '<ESC>`>a</[{H3}]><C-O>`<<[{H3 STYLE}]="text-align: center;"><ESC>')
HTML#Map('vnoremap', '<lead>H4', '<ESC>`>a</[{H4}]><C-O>`<<[{H4 STYLE}]="text-align: center;"><ESC>')
HTML#Map('vnoremap', '<lead>H5', '<ESC>`>a</[{H5}]><C-O>`<<[{H5 STYLE}]="text-align: center;"><ESC>')
HTML#Map('vnoremap', '<lead>H6', '<ESC>`>a</[{H6}]><C-O>`<<[{H6 STYLE}]="text-align: center;"><ESC>')
# Motion mappings:
HTML#Mapo('<lead>h1')
HTML#Mapo('<lead>h2')
HTML#Mapo('<lead>h3')
HTML#Mapo('<lead>h4')
HTML#Mapo('<lead>h5')
HTML#Mapo('<lead>h6')
HTML#Mapo('<lead>H1')
HTML#Mapo('<lead>H2')
HTML#Mapo('<lead>H3')
HTML#Mapo('<lead>H4')
HTML#Mapo('<lead>H5')
HTML#Mapo('<lead>H6')

#       HGROUP  Group headings             HTML 5
HTML#Map('inoremap', '<lead>hg', '<[{HGROUP}]><CR></[{HGROUP}]><C-O>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>hg', '<ESC>`>a<CR></[{HGROUP}]><C-O>`<<[{HGROUP}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>hg')

#       HEAD                            HTML 2.0
HTML#Map('inoremap', '<lead>he', '<[{HEAD}]><CR></[{HEAD}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>he', '<ESC>`>a<CR></[{HEAD}]><C-O>`<<[{HEAD}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>he')

#       HR      Horizontal Rule         HTML 2.0
HTML#Map('inoremap', '<lead>hr', '<[{HR}] />')
HTML#Map('inoremap', '<lead>Hr', '<[{HR STYLE}]="width: 75%;" />')

#       HTML
if HTML#BoolVar('b:do_xhtml_mappings')
  HTML#Map('inoremap', '<lead>ht', '<html xmlns="http://www.w3.org/1999/xhtml"><CR></html><ESC>O')
  # Visual mapping:
  HTML#Map('vnoremap', '<lead>ht', '<ESC>`>a<CR></html><C-O>`<<html xmlns="http://www.w3.org/1999/xhtml"><CR><ESC>', {'reindent': 1})
else
  HTML#Map('inoremap', '<lead>ht', '<[{HTML}]><CR></[{HTML}]><ESC>O')
  # Visual mapping:
  HTML#Map('vnoremap', '<lead>ht', '<ESC>`>a<CR></[{HTML}]><C-O>`<<[{HTML}]><CR><ESC>', {'reindent': 1})
endif
# Motion mapping:
HTML#Mapo('<lead>ht')

#       I       Italicized Text         HTML 2.0
HTML#Map('inoremap', '<lead>it', "<C-R>=HTML#SmartTag('i', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>it', "<C-c>:execute 'normal! ' .. HTML#SmartTag('i', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>it')

#       IMG     Image                   HTML 2.0
HTML#Map('inoremap', '<lead>im', '<[{IMG SRC="" ALT}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>iM', '<[{IMG SRC="<C-R>*" ALT}]="" /><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>im', '<ESC>`>a" /><C-O>`<<[{IMG SRC="" ALT}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>iM', '<ESC>`>a" [{ALT}]="" /><C-O>`<<[{IMG SRC}]="<C-O>3f"', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>im', true)
HTML#Mapo('<lead>iM', true)

#       INS     Inserted Text           HTML 3.0
# HTML#Map('inoremap', '<lead>in', '<lt>[{INS></INS}]><C-O>F<')
HTML#Map('inoremap', '<lead>in', "<C-R>=HTML#SmartTag('ins', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>in', '<ESC>`>a</[{INS}]><C-O>`<<lt>[{INS}]><ESC>')
HTML#Map('vnoremap', '<lead>in', "<C-c>:execute 'normal! ' .. HTML#SmartTag('ins', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>in')

#       KBD     Keyboard Text           HTML 2.0
HTML#Map('inoremap', '<lead>kb', '<[{KBD></KBD}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>kb', '<ESC>`>a</[{KBD}]><C-O>`<<[{KBD}]><ESC>')
# Motion mapping:
HTML#Mapo('<lead>kb')

#       LI      List Item               HTML 2.0
HTML#Map('inoremap', '<lead>li', '<[{LI}]></[{LI}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>li', '<ESC>`>a</[{LI}]><C-O>`<<[{LI}]><ESC>')
# Motion mapping:
HTML#Mapo('<lead>li')

#       LINK                            HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>lk', '<[{LINK HREF}]="" /><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>lk', '<ESC>`>a" /><C-O>`<<[{LINK HREF}]="<ESC>')
# Motion mapping:
HTML#Mapo('<lead>lk')

#       MAIN                            HTML 5
HTML#Map('inoremap', '<lead>ma', '<[{MAIN><CR></MAIN}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ma', '<ESC>`>a<CR></[{MAIN}]><C-O>`<<[{MAIN}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ma')

#       METER                           HTML 5
HTML#Map('inoremap', '<lead>mt', '<[{METER VALUE="" MIN="" MAX=""></METER}]><C-O>5F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>mt', '<ESC>`>a</[{METER}]><C-O>`<<[{METER VALUE="" MIN="" MAX}]=""><C-O>5F"', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>mt', true)

#       MARK                            HTML 5
# HTML#Map('inoremap', '<lead>mk', '<[{MARK></MARK}]><C-O>F<')
HTML#Map('inoremap', '<lead>mk', "<C-R>=HTML#SmartTag('mark', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>mk', '<ESC>`>a</[{MARK}]><C-O>`<<[{MARK}]><ESC>')
HTML#Map('vnoremap', '<lead>mk', "<C-c>:execute 'normal! ' .. HTML#SmartTag('mark', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>mk')

#       META    Meta Information        HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>me', '<[{META NAME="" CONTENT}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>mE', '<[{META NAME="" CONTENT}]="<C-R>*" /><C-O>3F"')
# Visual mappings:
HTML#Map('vnoremap', '<lead>me', '<ESC>`>a" [{CONTENT}]="" /><C-O>`<<[{META NAME}]="<C-O>3f"', {'insert': true})
HTML#Map('vnoremap', '<lead>mE', '<ESC>`>a" /><C-O>`<<[{META NAME="" CONTENT}]="<C-O>2F"', {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>me', true)
HTML#Mapo('<lead>mE', true)

#       META    Meta http-equiv         HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>mh', '<[{META HTTP-EQUIV="" CONTENT}]="" /><C-O>3F"')
# Visual mappings:
HTML#Map('vnoremap', '<lead>mh', '<ESC>`>a" /><C-O>`<<[{META HTTP-EQUIV="" CONTENT}]="<C-O>2F"', {'insert': true})
# Motion mappings:
HTML#Mapo('<lead>mh', true)

#       NAV                             HTML 5
HTML#Map('inoremap', '<lead>na', '<[{NAV><CR></NAV}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>na', '<ESC>`>a<CR></[{NAV}]><C-O>`<<[{NAV}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>na', true)

#       OL      Ordered List            HTML 3.0
HTML#Map('inoremap', '<lead>ol', '<[{OL}]><CR></[{OL}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ol', '<ESC>`>a<CR></[{OL}]><C-O>`<<[{OL}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ol')

#       P       Paragraph               HTML 3.0
# HTML#Map('inoremap', '<lead>pp', '<[{P}]><CR></[{P}]><ESC>O')
HTML#Map('inoremap', '<lead>pp', "<C-R>=HTML#SmartTag('p', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>pp', '<ESC>`>a<CR></[{P}]><C-O>`<<[{P}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>pp', "<C-c>:execute 'normal! ' .. HTML#SmartTag('p', 'v')<CR>", {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>pp')
# A special mapping... If you're between <P> and </P> this will insert the
# close tag and then the open tag in insert mode (probably unnecessary now
# that the ;pp tag is smart):
HTML#Map('inoremap', '<lead>/p', '</[{P}]><CR><CR><[{P}]><CR>')

#       PRE     Preformatted Text       HTML 2.0
# HTML#Map('inoremap', '<lead>pr', '<[{PRE}]><CR></[{PRE}]><ESC>O')
HTML#Map('inoremap', '<lead>pr', "<C-R>=HTML#SmartTag('pre', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>pr', '<ESC>`>a<CR></[{PRE}]><C-O>`<<[{PRE}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>pr', "<C-c>:execute 'normal! ' .. HTML#SmartTag('pre', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>pr')

#       PROGRESS                        HTML 5
HTML#Map('inoremap', '<lead>pg', '<[{PROGRESS VALUE="" MAX=""></PROGRESS}]><C-O>3F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>pg', '<ESC>`>a" [{MAX=""></PROGRESS}]><C-O>`<<[{PROGRESS VALUE}]="<C-O>3f"', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>pg', true)

#       Q       Quote                   HTML 3.0
# HTML#Map('inoremap', '<lead>qu', '<[{Q></Q}]><C-O>F<')
HTML#Map('inoremap', '<lead>qu', "<C-R>=HTML#SmartTag('q', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>qu', '<ESC>`>a</[{Q}]><C-O>`<<[{Q}]><ESC>')
HTML#Map('vnoremap', '<lead>qu', "<C-c>:execute 'normal! ' .. HTML#SmartTag('q', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>qu')

#       STRIKE  Strikethrough           HTML 3.0
#       (note this is not HTML 5 compatible, use DEL instead)
# HTML#Map('inoremap', '<lead>sk', '<[{STRIKE></STRIKE}]><C-O>F<')
# Visual mapping:
# HTML#Map('vnoremap', '<lead>sk', '<ESC>`>a</[{STRIKE}]><C-O>`<<[{STRIKE}]><ESC>')
# Motion mapping:
# HTML#Mapo('<lead>sk')

#       SAMP    Sample Text             HTML 2.0
# HTML#Map('inoremap', '<lead>sa', '<[{SAMP></SAMP}]><C-O>F<')
HTML#Map('inoremap', '<lead>sa', "<C-R>=HTML#SmartTag('samp', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>sa', '<ESC>`>a</[{SAMP}]><C-O>`<<[{SAMP}]><ESC>')
HTML#Map('vnoremap', '<lead>sa', "<C-c>:execute 'normal! ' .. HTML#SmartTag('samp', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>sa')

#       SECTION                         HTML 5
HTML#Map('inoremap', '<lead>sc', '<[{SECTION><CR></SECTION}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>sc', '<ESC>`>a<CR></[{SECTION}]><C-O>`<<[{SECTION}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>sc', true)

#       SMALL   Small Text              HTML 3.0
#       (<SMALL> is not HTML 5 compatible, so we use CSS instead)
# HTML#Map('inoremap', '<lead>sm', '<[{SMALL></SMALL}]><C-O>F<')
HTML#Map('inoremap', '<lead>sm', '<[{SPAN STYLE}]="font-size: smaller;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# HTML#Map('vnoremap', '<lead>sm', '<ESC>`>a</[{SMALL}]><C-O>`<<[{SMALL}]><ESC>')
HTML#Map('vnoremap', '<lead>sm', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: smaller;"><ESC>')
# Motion mapping:
HTML#Mapo('<lead>sm')

#       STRONG  Bold Text               HTML 2.0
HTML#Map('inoremap', '<lead>st', "<C-R>=HTML#SmartTag('strong', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>st', "<C-c>:execute 'normal! ' .. HTML#SmartTag('strong', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>st')

#       STYLE                           HTML 4.0        HEADER
HTML#Map('inoremap', '<lead>cs', '<[{STYLE TYPE}]="text/css"><CR><!--<CR>--><CR></[{STYLE}]><ESC>kO')
# Visual mapping:
HTML#Map('vnoremap', '<lead>cs', '<ESC>`>a<CR> --><CR></[{STYLE}]><C-O>`<<[{STYLE TYPE}]="text/css"><CR><!--<CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>cs')

#       Linked CSS stylesheet
HTML#Map('inoremap', '<lead>ls', '<[{LINK REL}]="stylesheet" [{TYPE}]="text/css" [{HREF}]="" /><C-O>F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ls', '<ESC>`>a" /><C-O>`<<[{LINK REL}]="stylesheet" [{TYPE}]="text/css" [{HREF}]="<ESC>')
# Motion mapping:
HTML#Mapo('<lead>ls')

#       SUB     Subscript               HTML 3.0
# HTML#Map('inoremap', '<lead>sb', '<[{SUB></SUB}]><C-O>F<')
HTML#Map('inoremap', '<lead>sb', "<C-R>=HTML#SmartTag('sub', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>sb', '<ESC>`>a</[{SUB}]><C-O>`<<[{SUB}]><ESC>')
HTML#Map('vnoremap', '<lead>sb', "<C-c>:execute 'normal! ' .. HTML#SmartTag('sub', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>sb')

#       SUP     Superscript             HTML 3.0
# HTML#Map('inoremap', '<lead>sp', '<[{SUP></SUP}]><C-O>F<')
HTML#Map('inoremap', '<lead>sp', "<C-R>=HTML#SmartTag('sup', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>sp', '<ESC>`>a</[{SUP}]><C-O>`<<[{SUP}]><ESC>')
HTML#Map('vnoremap', '<lead>sp', "<C-c>:execute 'normal! ' .. HTML#SmartTag('sup', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>sp')

#       TITLE                           HTML 2.0        HEADER
HTML#Map('inoremap', '<lead>ti', '<[{TITLE></TITLE}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ti', '<ESC>`>a</[{TITLE}]><C-O>`<<[{TITLE}]><ESC>')
# Motion mapping:
HTML#Mapo('<lead>ti')

#       TIME    Human readable date/time HTML 5
HTML#Map('inoremap', '<lead>tm', '<[{TIME DATETIME=""></TIME}]><C-O>F<')
# Visual mapping:
HTML#Map('vnoremap', '<lead>tm', '<ESC>`>a</[{TIME}]><C-O>`<<[{TIME DATETIME=""}]><ESC>F"i', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>tm', true)

#       TT      Teletype Text (monospaced)      HTML 2.0
#       (<TT> is not HTML 5 compatible, so we use CSS instead)
# HTML#Map('inoremap', '<lead>tt', '<[{TT></TT}]><C-O>F<')
HTML#Map('inoremap', '<lead>tt', '<[{SPAN STYLE}]="font-family: monospace;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# HTML#Map('vnoremap', '<lead>tt', '<ESC>`>a</[{TT}]><C-O>`<<[{TT}]><ESC>')
HTML#Map('vnoremap', '<lead>tt', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-family: monospace;"><ESC>')
# Motion mapping:
HTML#Mapo('<lead>tt')

#       U       Underlined Text         HTML 2.0
HTML#Map('inoremap', '<lead>un', "<C-R>=HTML#SmartTag('u', 'i')<CR>")
# Visual mapping:
HTML#Map('vnoremap', '<lead>un', "<C-c>:execute 'normal! ' .. HTML#SmartTag('u', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>un')

#       UL      Unordered List          HTML 2.0
HTML#Map('inoremap', '<lead>ul', '<[{UL}]><CR></[{UL}]><ESC>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ul', '<ESC>`>a<CR></[{UL}]><C-O>`<<[{UL}]><CR><ESC>')
# Motion mapping:
HTML#Mapo('<lead>ul')

#       VAR     Variable                HTML 3.0
# HTML#Map('inoremap', '<lead>va', '<[{VAR></VAR}]><C-O>F<')
HTML#Map('inoremap', '<lead>va', "<C-R>=HTML#SmartTag('var', 'i')<CR>")
# Visual mapping:
# HTML#Map('vnoremap', '<lead>va', '<ESC>`>a</[{VAR}]><C-O>`<<[{VAR}]><ESC>')
HTML#Map('vnoremap', '<lead>va', "<C-c>:execute 'normal! ' .. HTML#SmartTag('var', 'v')<CR>")
# Motion mapping:
HTML#Mapo('<lead>va')

#       Embedded JavaScript
#HTML#Map('inoremap', '<lead>js', '<C-O>:vim9cmd HTML#TC(false)<CR><[{SCRIPT TYPE}]="text/javascript"><ESC>==o<!--<CR>// --><CR></[{SCRIPT}]><ESC>:vim9cmd HTML#TC(true)<CR>kko')
HTML#Map('inoremap', '<lead>js', "<C-R>=HTML#SmartTag('script', 'i')<CR>")
# Visual mapping:
#HTML#Map('vnoremap', '<lead>js', '<C-c>:vim9cmd HTML#TC(false)<CR>`>a<CR>// --><CR></[{SCRIPT}]><C-O>`<<[{SCRIPT TYPE}]="text/javascript"><CR><!--<CR><ESC>:vim9cmd HTML#TC(true)<CR>', {'reindent': 2})
HTML#Map('vnoremap', '<lead>js', "<C-c>:execute 'normal! ' .. HTML#SmartTag('script', 'v')<CR>", {'reindent': 3})
# Motion mapping:
HTML#Mapo('<lead>js')

#       Sourced JavaScript
HTML#Map('inoremap', '<lead>sj', '<[{SCRIPT SRC}]="" [{TYPE}]="text/javascript"></[{SCRIPT}]><C-O>3F"')
# Visual mapping:
HTML#Map('vnoremap', '<lead>sj', '<ESC>`>a" [{TYPE}]="text/javascript"></[{SCRIPT}]><C-O>`<<[{SCRIPT SRC}]="<C-O>`><C-O>f<', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>sj', true)

#       EMBED                           HTML 5
HTML#Map('inoremap', '<lead>eb', '<[{EMBED TYPE="" SRC="" WIDTH="" HEIGHT}]="" /><ESC>$5F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>eb', '<ESC>`>a" [{WIDTH="" HEIGHT}]="" /><C-O>`<<[{EMBED TYPE="" SRC}]="<C-O>2F"', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>eb', true)

#       NOSCRIPT
HTML#Map('inoremap', '<lead>ns', '<[{NOSCRIPT}]><CR></[{NOSCRIPT}]><C-O>O')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ns', '<ESC>`>a<CR></[{NOSCRIPT}]><C-O>`<<[{NOSCRIPT}]><CR><ESC>', {'reindent': 1})
# Motion mapping:
HTML#Mapo('<lead>ns')

#       OBJECT
HTML#Map('inoremap', '<lead>ob', '<[{OBJECT DATA="" WIDTH="" HEIGHT}]=""><CR></[{OBJECT}]><ESC>k$5F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>ob', '<ESC>`>a<CR></[{OBJECT}]><C-O>`<<[{OBJECT DATA="" WIDTH="" HEIGHT}]=""><CR><ESC>k$5F"i', {'reindent': 1, 'insert': true})
# Motion mapping:
HTML#Mapo('<lead>ob')

#       PARAM (Object Parameter)
HTML#Map('inoremap', '<lead>pm', '<[{PARAM NAME="" VALUE}]="" /><ESC>3F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>pm', '<ESC>`>a" [{VALUE}]="" /><C-O>`<<[{PARAM NAME}]="<ESC>3f"i', {'insert': true})
# Motion mapping:
HTML#Mapo('<lead>pm')

#       VIDEO  Video with controls      HTML 5
HTML#Map('inoremap', '<lead>vi', '<[{VIDEO WIDTH="" HEIGHT="" CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR>Your browser does not support the video tag.<CR></[{VIDEO}]><ESC>kkk$3F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>vi', '<ESC>`>a<CR></[{VIDEO}]><C-O>`<<[{VIDEO WIDTH="" HEIGHT="" CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR><ESC>kk$3F"i', {'reindent': 2, 'insert': true})
# Motion mapping:
HTML#Mapo('<lead>vi')

#       WBR     Possible line break     HTML 5
HTML#Map('inoremap', '<lead>wb', '<[{WBR}] />')


# Table stuff:
HTML#Map('inoremap', '<lead>ca', '<[{CAPTION></CAPTION}]><C-O>F<')
HTML#Map('inoremap', '<lead>ta', '<[{TABLE}]><CR></[{TABLE}]><ESC>O')
HTML#Map('inoremap', '<lead>tH', '<[{THEAD}]><CR></[{THEAD}]><ESC>O')
HTML#Map('inoremap', '<lead>tb', '<[{TBODY}]><CR></[{TBODY}]><ESC>O')
HTML#Map('inoremap', '<lead>tf', '<[{TFOOT}]><CR></[{TFOOT}]><ESC>O')
HTML#Map('inoremap', '<lead>tr', '<[{TR}]><CR></[{TR}]><ESC>O')
HTML#Map('inoremap', '<lead>td', '<[{TD></TD}]><C-O>F<')
HTML#Map('inoremap', '<lead>th', '<[{TH></TH}]><C-O>F<')
# Visual mappings:
HTML#Map('vnoremap', '<lead>ca', '<ESC>`>a<CR></[{CAPTION}]><C-O>`<<[{CAPTION}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>ta', '<ESC>`>a<CR></[{TABLE}]><C-O>`<<[{TABLE}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>tH', '<ESC>`>a<CR></[{THEAD}]><C-O>`<<[{THEAD}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>tb', '<ESC>`>a<CR></[{TBODY}]><C-O>`<<[{TBODY}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>tf', '<ESC>`>a<CR></[{TFOOT}]><C-O>`<<[{TFOOT}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>tr', '<ESC>`>a<CR></[{TR}]><C-O>`<<[{TR}]><CR><ESC>', {'reindent': 1})
HTML#Map('vnoremap', '<lead>td', '<ESC>`>a</[{TD}]><C-O>`<<[{TD}]><ESC>')
HTML#Map('vnoremap', '<lead>th', '<ESC>`>a</[{TH}]><C-O>`<<[{TH}]><ESC>')
# Motion mappings:
HTML#Mapo('<lead>ca')
HTML#Mapo('<lead>ta')
HTML#Mapo('<lead>tH')
HTML#Mapo('<lead>tb')
HTML#Mapo('<lead>tf')
HTML#Mapo('<lead>tr')
HTML#Mapo('<lead>td')
HTML#Mapo('<lead>th')

# Interactively generate a table:
HTML#Map('nnoremap', '<lead>tA', ':vim9cmd HTML#GenerateTable()<CR>')

# Frames stuff:
#       (note this is not HTML 5 compatible)
# HTML#Map('inoremap', '<lead>fs', '<[{FRAMESET ROWS="" COLS}]=""><CR></[{FRAMESET}]><ESC>k$3F"i')
# HTML#Map('inoremap', '<lead>fr', '<[{FRAME SRC}]="" /><C-O>F"')
# HTML#Map('inoremap', '<lead>nf', '<[{NOFRAMES}]><CR></[{NOFRAMES}]><ESC>O')
# Visual mappings:
# HTML#Map('vnoremap', '<lead>fs', '<ESC>`>a<CR></[{FRAMESET}]><C-O>`<<[{FRAMESET ROWS="" COLS}]=""><CR><ESC>k$3F"')
# HTML#Map('vnoremap', '<lead>fr', '<ESC>`>a" /><C-O>`<<[{FRAME SRC}]="<ESC>')
# HTML#Map('vnoremap', '<lead>nf', '<ESC>`>a<CR></[{NOFRAMES}]><C-O>`<<[{NOFRAMES}]><CR><ESC>', {'reindent': 1})
# Motion mappings:
# HTML#Mapo('<lead>fs')
# HTML#Mapo('<lead>fr')
# HTML#Mapo('<lead>nf')

#       IFRAME  Inline Frame            HTML 4.0
HTML#Map('inoremap', '<lead>if', '<[{IFRAME SRC="" WIDTH="" HEIGHT}]=""><CR></[{IFRAME}]><ESC>k$5F"i')
# Visual mapping:
HTML#Map('vnoremap', '<lead>if', '<ESC>`>a<CR></[{IFRAME}]><C-O>`<<[{IFRAME SRC="" WIDTH="" HEIGHT}]=""><CR><ESC>k$5F"i', {'reindent': 1, 'insert': true})
# Motion mapping:
HTML#Mapo('<lead>if')

# Forms stuff:
HTML#Map('inoremap', '<lead>fm', '<[{FORM ACTION}]=""><CR></[{FORM}]><ESC>k$F"i')
HTML#Map('inoremap', '<lead>fd', '<[{FIELDSET}]><CR><[{LEGEND></LEGEND}]><CR></[{FIELDSET}]><ESC>k$F<i')
HTML#Map('inoremap', '<lead>bu', '<[{INPUT TYPE="BUTTON" NAME="" VALUE}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>ch', '<[{INPUT TYPE="CHECKBOX" NAME="" VALUE}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>cl', '<[{INPUT TYPE="DATE" NAME}]="" /><C-O>F"')
HTML#Map('inoremap', '<lead>nt', '<[{INPUT TYPE="TIME" NAME}]="" /><C-O>F"')
HTML#Map('inoremap', '<lead>ra', '<[{INPUT TYPE="RADIO" NAME="" VALUE}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>rn', '<[{INPUT TYPE="RANGE" NAME="" MIN="" MAX}]="" /><C-O>5F"')
HTML#Map('inoremap', '<lead>hi', '<[{INPUT TYPE="HIDDEN" NAME="" VALUE}]="" /><C-O>3F"')
HTML#Map('inoremap', '<lead>pa', '<[{INPUT TYPE="PASSWORD" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
HTML#Map('inoremap', '<lead>te', '<[{INPUT TYPE="TEXT" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
HTML#Map('inoremap', '<lead>fi', '<[{INPUT TYPE="FILE" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
HTML#Map('inoremap', '<lead>@', '<[{INPUT TYPE="EMAIL" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
HTML#Map('inoremap', '<lead>#', '<[{INPUT TYPE="TEL" NAME="" VALUE="" SIZE}]="15" /><C-O>5F"')
HTML#Map('inoremap', '<lead>nu', '<[{INPUT TYPE="NUMBER" NAME="" VALUE="" STYLE}]="width: 5em;" /><C-O>5F"')
HTML#Map('inoremap', '<lead>ur', '<[{INPUT TYPE="URL" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
HTML#Map('inoremap', '<lead>se', '<[{SELECT NAME}]=""><CR></[{SELECT}]><ESC>O')
HTML#Map('inoremap', '<lead>ms', '<[{SELECT NAME="" MULTIPLE}]><CR></[{SELECT}]><ESC>O')
HTML#Map('inoremap', '<lead>op', '<[{OPTION></OPTION}]><C-O>F<')
HTML#Map('inoremap', '<lead>og', '<[{OPTGROUP LABEL}]=""><CR></[{OPTGROUP}]><ESC>k$F"i')
HTML#Map('inoremap', '<lead>ou', '<[{OUTPUT NAME}]=""></[{OUTPUT}]><C-O>F"')
HTML#Map('inoremap', '<lead>tx', '<[{TEXTAREA NAME="" ROWS="10" COLS}]="50"><CR></[{TEXTAREA}]><ESC>k$5F"i')
HTML#Map('inoremap', '<lead>su', '<[{INPUT TYPE="SUBMIT" VALUE}]="Submit" />')
HTML#Map('inoremap', '<lead>re', '<[{INPUT TYPE="RESET" VALUE}]="Reset" />')
HTML#Map('inoremap', '<lead>la', '<[{LABEL FOR=""></LABEL}]><C-O>F"')
HTML#Map('inoremap', '<lead>da', '<[{INPUT LIST}]=""><CR><[{DATALIST ID}]=""><CR></[{DATALIST}]><CR></[{INPUT}]><ESC>kkk$F"i')
# Visual mappings:
HTML#Map('vnoremap', '<lead>fm', '<ESC>`>a<CR></[{FORM}]><C-O>`<<[{FORM ACTION}]=""><CR><ESC>k$F"i', {'reindent': 1, 'insert': true})
HTML#Map('vnoremap', '<lead>fd', '<ESC>`>a<CR></[{FIELDSET}]><C-O>`<<[{FIELDSET}]><CR><[{LEGEND></LEGEND}]><CR><ESC>k$F<i', {'insert': true})
HTML#Map('vnoremap', '<lead>bu', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="BUTTON" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>ch', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="CHECKBOX" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>cl', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="DATE" NAME}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>nt', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="TIME" NAME}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>ra', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="RADIO" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>rn', '<ESC>`>a" [{MIN="" MAX}]="" /><C-O>`<<[{INPUT TYPE="RANGE" NAME}]="<C-O>3f"', {'insert': true})
HTML#Map('vnoremap', '<lead>hi', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="HIDDEN" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>pa', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="PASSWORD" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>te', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="TEXT" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>fi', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="FILE" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>@', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="EMAIL" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>#', '<ESC>`>a" [{SIZE}]="15" /><C-O>`<<[{INPUT TYPE="TEL" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>nu', '<ESC>`>a" [{STYLE}]="width: 5em;" /><C-O>`<<[{INPUT TYPE="NUMBER" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>ur', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="URL" NAME="" VALUE}]="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>se', '<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME}]=""><CR><ESC>k$F"i', {'reindent': 1, 'insert': true})
HTML#Map('vnoremap', '<lead>ms', '<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME="" MULTIPLE}]><CR><ESC>k$F"i', {'reindent': 1, 'insert': true})
HTML#Map('vnoremap', '<lead>op', '<ESC>`>a</[{OPTION}]><C-O>`<<[{OPTION}]><ESC>')
HTML#Map('vnoremap', '<lead>og', '<ESC>`>a<CR></[{OPTGROUP}]><C-O>`<<[{OPTGROUP LABEL}]=""><CR><ESC>k$F"i', {'reindent': 1, 'insert': true})
HTML#Map('vnoremap', '<lead>ou', '<ESC>`>a</[{OUTPUT}]><C-O>`<<[{OUTPUT NAME}]=""><C-O>F"', {'insert': true})
HTML#Map('vnoremap', '<lead>oU', '<ESC>`>a"></[{OUTPUT}]><C-O>`<<[{OUTPUT NAME}]="<C-O>f<', {'insert': true})
HTML#Map('vnoremap', '<lead>tx', '<ESC>`>a<CR></[{TEXTAREA}]><C-O>`<<[{TEXTAREA NAME="" ROWS="10" COLS}]="50"><CR><ESC>k$5F"i', {'reindent': 1, 'insert': true})
HTML#Map('vnoremap', '<lead>la', '<ESC>`>a</[{LABEL}]><C-O>`<<[{LABEL FOR}]=""><C-O>F"', {'insert': true})
HTML#Map('vnoremap', '<lead>lA', '<ESC>`>a"></[{LABEL}]><C-O>`<<[{LABEL FOR}]="<C-O>f<', {'insert': true})
HTML#Map('vnoremap', '<lead>da', 's<[{INPUT LIST}]="<C-R>""><CR><[{DATALIST ID}]="<C-R>""><CR></[{DATALIST}]><CR></[{INPUT}]><ESC>kO', {'reindent': 1, 'insert': true})
# Motion mappings:
HTML#Mapo('<lead>fm')
HTML#Mapo('<lead>fd', true)
HTML#Mapo('<lead>bu', true)
HTML#Mapo('<lead>ch', true)
HTML#Mapo('<lead>cl', true)
HTML#Mapo('<lead>nt', true)
HTML#Mapo('<lead>ra', true)
HTML#Mapo('<lead>rn', true)
HTML#Mapo('<lead>hi', true)
HTML#Mapo('<lead>pa', true)
HTML#Mapo('<lead>te', true)
HTML#Mapo('<lead>fi', true)
HTML#Mapo('<lead>@', true)
HTML#Mapo('<lead>#', true)
HTML#Mapo('<lead>nu', true)
HTML#Mapo('<lead>ur', true)
HTML#Mapo('<lead>se')
HTML#Mapo('<lead>ms')
HTML#Mapo('<lead>op')
HTML#Mapo('<lead>og')
HTML#Mapo('<lead>ou', true)
HTML#Mapo('<lead>oU', true)
HTML#Mapo('<lead>tx')
HTML#Mapo('<lead>la', true)
HTML#Mapo('<lead>lA', true)
HTML#Mapo('<lead>da', true)

# Server Side Include (SSI) directives:
HTML#Map('inoremap', '<lead>cf', '<!--#config timefmt="" --><C-O>F"')
HTML#Map('inoremap', '<lead>cz', '<!--#config sizefmt="" --><C-O>F"')
HTML#Map('inoremap', '<lead>ev', '<!--#echo var="" --><C-O>F"')
HTML#Map('inoremap', '<lead>iv', '<!--#include virtual="" --><C-O>F"')
HTML#Map('inoremap', '<lead>fv', '<!--#flastmod virtual="" --><C-O>F"')
HTML#Map('inoremap', '<lead>fz', '<!--#fsize virtual="" --><C-O>F"')
HTML#Map('inoremap', '<lead>ec', '<!--#exec cmd="" --><C-O>F"')
HTML#Map('inoremap', '<lead>sv', '<!--#set var="" value="" --><C-O>3F"')
HTML#Map('inoremap', '<lead>ie', '<!--#if expr="" --><CR><!--#else --><CR><!--#endif --><ESC>kk$F"i')
# Visual mappings:
HTML#Map('vnoremap', '<lead>cf', '<ESC>`>a" --><C-O>`<<!--#config timefmt="<ESC>')
HTML#Map('vnoremap', '<lead>cz', '<ESC>`>a" --><C-O>`<<!--#config sizefmt="<ESC>')
HTML#Map('vnoremap', '<lead>ev', '<ESC>`>a" --><C-O>`<<!--#echo var="<ESC>')
HTML#Map('vnoremap', '<lead>iv', '<ESC>`>a" --><C-O>`<<!--#include virtual="<ESC>')
HTML#Map('vnoremap', '<lead>fv', '<ESC>`>a" --><C-O>`<<!--#flastmod virtual="<ESC>')
HTML#Map('vnoremap', '<lead>fz', '<ESC>`>a" --><C-O>`<<!--#fsize virtual="<ESC>')
HTML#Map('vnoremap', '<lead>ec', '<ESC>`>a" --><C-O>`<<!--#exec cmd="<ESC>')
HTML#Map('vnoremap', '<lead>sv', '<ESC>`>a" --><C-O>`<<!--#set var="" value="<C-O>2F"', {'insert': true})
HTML#Map('vnoremap', '<lead>ie', '<ESC>`>a<CR><!--#else --><CR><!--#endif --><C-O>`<<!--#if expr="" --><CR><ESC>`<f"a', {'insert': true, 'reindent': 3})
# Motion mappings:
HTML#Mapo('<lead>cf')
HTML#Mapo('<lead>cz')
HTML#Mapo('<lead>ev')
HTML#Mapo('<lead>iv')
HTML#Mapo('<lead>fv')
HTML#Mapo('<lead>fz')
HTML#Mapo('<lead>ec')
HTML#Mapo('<lead>sv', true)
HTML#Mapo('<lead>ie', true)

# ----------------------------------------------------------------------------

# ---- Character Entities Mappings: ------------------------------------- {{{1

# Convert the character under the cursor or the highlighted string to its name
# entity or otherwise decimal HTML entities:
# (Note that this can be very slow due to syntax highlighting. Maybe find a
# different way to do it?)
HTML#Map('vnoremap', '<lead>&', "s<C-R>=HTML#EncodeString(@\")->HTML#SI()<CR><Esc>", {'extra': false})
HTML#Mapo('<lead>&')

# Convert the character under the cursor or the highlighted string to hex
# HTML entities:
HTML#Map('vnoremap', '<lead>*', "s<C-R>=HTML#EncodeString(@\", 'x')->HTML#SI()<CR><Esc>", {'extra': false})
HTML#Mapo('<lead>*')

# Convert the character under the cursor or the highlighted string to a %XX
# string:
HTML#Map('vnoremap', '<lead>%', "s<C-R>=HTML#EncodeString(@\", '%')->HTML#SI()<CR><Esc>", {'extra': false})
HTML#Mapo('<lead>%')

# Decode a &...;, &#...;, or %XX encoded string:
HTML#Map('vnoremap', '<lead>^', "s<C-R>=HTML#EncodeString(@\", 'd')->HTML#SI()<CR><Esc>", {'extra': false})
HTML#Mapo('<lead>^')

# TODO: Expand these mappings based on the table in autoload/HTML.vim

HTML#Map('inoremap', '<elead>&', '&amp;')
HTML#Map('inoremap', '<elead>cO', '&copy;')
HTML#Map('inoremap', '<elead>rO', '&reg;')
HTML#Map('inoremap', '<elead>tm', '&trade;')
HTML#Map('inoremap', "<elead>'", '&quot;')
HTML#Map('inoremap', "<elead>l'", '&lsquo;')
HTML#Map('inoremap', "<elead>r'", '&rsquo;')
HTML#Map('inoremap', '<elead>l"', '&ldquo;')
HTML#Map('inoremap', '<elead>r"', '&rdquo;')
HTML#Map('inoremap', '<elead><', '&lt;')
HTML#Map('inoremap', '<elead>>', '&gt;')
HTML#Map('inoremap', '<elead><space>', '&nbsp;')
HTML#Map('inoremap', '<lead><space>', '&nbsp;')
HTML#Map('inoremap', '<elead>#', '&pound;')
HTML#Map('inoremap', '<elead>E=', '&euro;')
HTML#Map('inoremap', '<elead>Y=', '&yen;')
HTML#Map('inoremap', '<elead>c\|', '&cent;')
HTML#Map('inoremap', '<elead>A`', '&Agrave;')
HTML#Map('inoremap', "<elead>A'", '&Aacute;')
HTML#Map('inoremap', '<elead>A^', '&Acirc;')
HTML#Map('inoremap', '<elead>A~', '&Atilde;')
HTML#Map('inoremap', '<elead>A"', '&Auml;')
HTML#Map('inoremap', '<elead>Ao', '&Aring;')
HTML#Map('inoremap', '<elead>AE', '&AElig;')
HTML#Map('inoremap', '<elead>C,', '&Ccedil;')
HTML#Map('inoremap', '<elead>E`', '&Egrave;')
HTML#Map('inoremap', "<elead>E'", '&Eacute;')
HTML#Map('inoremap', '<elead>E^', '&Ecirc;')
HTML#Map('inoremap', '<elead>E"', '&Euml;')
HTML#Map('inoremap', '<elead>I`', '&Igrave;')
HTML#Map('inoremap', "<elead>I'", '&Iacute;')
HTML#Map('inoremap', '<elead>I^', '&Icirc;')
HTML#Map('inoremap', '<elead>I"', '&Iuml;')
HTML#Map('inoremap', '<elead>N~', '&Ntilde;')
HTML#Map('inoremap', '<elead>O`', '&Ograve;')
HTML#Map('inoremap', "<elead>O'", '&Oacute;')
HTML#Map('inoremap', '<elead>O^', '&Ocirc;')
HTML#Map('inoremap', '<elead>O~', '&Otilde;')
HTML#Map('inoremap', '<elead>O"', '&Ouml;')
HTML#Map('inoremap', '<elead>O/', '&Oslash;')
HTML#Map('inoremap', '<elead>U`', '&Ugrave;')
HTML#Map('inoremap', "<elead>U'", '&Uacute;')
HTML#Map('inoremap', '<elead>U^', '&Ucirc;')
HTML#Map('inoremap', '<elead>U"', '&Uuml;')
HTML#Map('inoremap', "<elead>Y'", '&Yacute;')
HTML#Map('inoremap', '<elead>a`', '&agrave;')
HTML#Map('inoremap', "<elead>a'", '&aacute;')
HTML#Map('inoremap', '<elead>a^', '&acirc;')
HTML#Map('inoremap', '<elead>a~', '&atilde;')
HTML#Map('inoremap', '<elead>a"', '&auml;')
HTML#Map('inoremap', '<elead>ao', '&aring;')
HTML#Map('inoremap', '<elead>ae', '&aelig;')
HTML#Map('inoremap', '<elead>c,', '&ccedil;')
HTML#Map('inoremap', '<elead>e`', '&egrave;')
HTML#Map('inoremap', "<elead>e'", '&eacute;')
HTML#Map('inoremap', '<elead>e^', '&ecirc;')
HTML#Map('inoremap', '<elead>e"', '&euml;')
HTML#Map('inoremap', '<elead>i`', '&igrave;')
HTML#Map('inoremap', "<elead>i'", '&iacute;')
HTML#Map('inoremap', '<elead>i^', '&icirc;')
HTML#Map('inoremap', '<elead>i"', '&iuml;')
HTML#Map('inoremap', '<elead>n~', '&ntilde;')
HTML#Map('inoremap', '<elead>o`', '&ograve;')
HTML#Map('inoremap', "<elead>o'", '&oacute;')
HTML#Map('inoremap', '<elead>o^', '&ocirc;')
HTML#Map('inoremap', '<elead>o~', '&otilde;')
HTML#Map('inoremap', '<elead>o"', '&ouml;')
HTML#Map('inoremap', '<elead>u`', '&ugrave;')
HTML#Map('inoremap', "<elead>u'", '&uacute;')
HTML#Map('inoremap', '<elead>u^', '&ucirc;')
HTML#Map('inoremap', '<elead>u"', '&uuml;')
HTML#Map('inoremap', "<elead>y'", '&yacute;')
HTML#Map('inoremap', '<elead>y"', '&yuml;')
HTML#Map('inoremap', '<elead>2<', '&laquo;')
HTML#Map('inoremap', '<elead>2>', '&raquo;')
HTML#Map('inoremap', '<elead>"', '&uml;')
HTML#Map('inoremap', '<elead>o/', '&oslash;')
HTML#Map('inoremap', '<elead>sz', '&szlig;')
HTML#Map('inoremap', '<elead>!', '&iexcl;')
HTML#Map('inoremap', '<elead>?', '&iquest;')
HTML#Map('inoremap', '<elead>dg', '&deg;')
HTML#Map('inoremap', '<elead>0^', '&#x2070;')
HTML#Map('inoremap', '<elead>1^', '&sup1;')
HTML#Map('inoremap', '<elead>2^', '&sup2;')
HTML#Map('inoremap', '<elead>3^', '&sup3;')
HTML#Map('inoremap', '<elead>4^', '&#x2074;')
HTML#Map('inoremap', '<elead>5^', '&#x2075;')
HTML#Map('inoremap', '<elead>6^', '&#x2076;')
HTML#Map('inoremap', '<elead>7^', '&#x2077;')
HTML#Map('inoremap', '<elead>8^', '&#x2078;')
HTML#Map('inoremap', '<elead>9^', '&#x2079;')
HTML#Map('inoremap', '<elead>0v', '&#x2080;')
HTML#Map('inoremap', '<elead>1v', '&#x2081;')
HTML#Map('inoremap', '<elead>2v', '&#x2082;')
HTML#Map('inoremap', '<elead>3v', '&#x2083;')
HTML#Map('inoremap', '<elead>4v', '&#x2084;')
HTML#Map('inoremap', '<elead>5v', '&#x2085;')
HTML#Map('inoremap', '<elead>6v', '&#x2086;')
HTML#Map('inoremap', '<elead>7v', '&#x2087;')
HTML#Map('inoremap', '<elead>8v', '&#x2088;')
HTML#Map('inoremap', '<elead>9v', '&#x2089;')
HTML#Map('inoremap', '<elead>mi', '&micro;')
HTML#Map('inoremap', '<elead>pa', '&para;')
HTML#Map('inoremap', '<elead>se', '&sect;')
HTML#Map('inoremap', '<elead>.', '&middot;')
HTML#Map('inoremap', '<elead>*', '&bull;')
HTML#Map('inoremap', '<elead>x', '&times;')
HTML#Map('inoremap', '<elead>/', '&divide;')
HTML#Map('inoremap', '<elead>+-', '&plusmn;')
HTML#Map('inoremap', '<elead>n-', '&ndash;')  # Math symbol
HTML#Map('inoremap', '<elead>2-', '&ndash;')  # ...
HTML#Map('inoremap', '<elead>m-', '&mdash;')  # Sentence break
HTML#Map('inoremap', '<elead>3-', '&mdash;')  # ...
HTML#Map('inoremap', '<elead>--', '&mdash;')  # ...
HTML#Map('inoremap', '<elead>3.', '&hellip;')
# Fractions:
HTML#Map('inoremap', '<elead>14', '&frac14;')
HTML#Map('inoremap', '<elead>12', '&frac12;')
HTML#Map('inoremap', '<elead>34', '&frac34;')
HTML#Map('inoremap', '<elead>13', '&frac13;')
HTML#Map('inoremap', '<elead>23', '&frac23;')
HTML#Map('inoremap', '<elead>15', '&frac15;')
HTML#Map('inoremap', '<elead>25', '&frac25;')
HTML#Map('inoremap', '<elead>35', '&frac35;')
HTML#Map('inoremap', '<elead>45', '&frac45;')
HTML#Map('inoremap', '<elead>16', '&frac16;')
HTML#Map('inoremap', '<elead>56', '&frac56;')
HTML#Map('inoremap', '<elead>18', '&frac18;')
HTML#Map('inoremap', '<elead>38', '&frac38;')
HTML#Map('inoremap', '<elead>58', '&frac58;')
HTML#Map('inoremap', '<elead>78', '&frac78;')
# Greek letters:
#   ... Capital:
HTML#Map('inoremap', '<elead>Al', '&Alpha;')
HTML#Map('inoremap', '<elead>Be', '&Beta;')
HTML#Map('inoremap', '<elead>Ga', '&Gamma;')
HTML#Map('inoremap', '<elead>De', '&Delta;')
HTML#Map('inoremap', '<elead>Ep', '&Epsilon;')
HTML#Map('inoremap', '<elead>Ze', '&Zeta;')
HTML#Map('inoremap', '<elead>Et', '&Eta;')
HTML#Map('inoremap', '<elead>Th', '&Theta;')
HTML#Map('inoremap', '<elead>Io', '&Iota;')
HTML#Map('inoremap', '<elead>Ka', '&Kappa;')
HTML#Map('inoremap', '<elead>Lm', '&Lambda;')
HTML#Map('inoremap', '<elead>Mu', '&Mu;')
HTML#Map('inoremap', '<elead>Nu', '&Nu;')
HTML#Map('inoremap', '<elead>Xi', '&Xi;')
HTML#Map('inoremap', '<elead>Oc', '&Omicron;')
HTML#Map('inoremap', '<elead>Pi', '&Pi;')
HTML#Map('inoremap', '<elead>Rh', '&Rho;')
HTML#Map('inoremap', '<elead>Si', '&Sigma;')
HTML#Map('inoremap', '<elead>Ta', '&Tau;')
HTML#Map('inoremap', '<elead>Up', '&Upsilon;')
HTML#Map('inoremap', '<elead>Ph', '&Phi;')
HTML#Map('inoremap', '<elead>Ch', '&Chi;')
HTML#Map('inoremap', '<elead>Ps', '&Psi;')
#   ... Lowercase/small:
HTML#Map('inoremap', '<elead>al', '&alpha;')
HTML#Map('inoremap', '<elead>be', '&beta;')
HTML#Map('inoremap', '<elead>ga', '&gamma;')
HTML#Map('inoremap', '<elead>de', '&delta;')
HTML#Map('inoremap', '<elead>ep', '&epsilon;')
HTML#Map('inoremap', '<elead>ze', '&zeta;')
HTML#Map('inoremap', '<elead>et', '&eta;')
HTML#Map('inoremap', '<elead>th', '&theta;')
HTML#Map('inoremap', '<elead>io', '&iota;')
HTML#Map('inoremap', '<elead>ka', '&kappa;')
HTML#Map('inoremap', '<elead>lm', '&lambda;')
HTML#Map('inoremap', '<elead>mu', '&mu;')
HTML#Map('inoremap', '<elead>nu', '&nu;')
HTML#Map('inoremap', '<elead>xi', '&xi;')
HTML#Map('inoremap', '<elead>oc', '&omicron;')
HTML#Map('inoremap', '<elead>pi', '&pi;')
HTML#Map('inoremap', '<elead>rh', '&rho;')
HTML#Map('inoremap', '<elead>si', '&sigma;')
HTML#Map('inoremap', '<elead>sf', '&sigmaf;')
HTML#Map('inoremap', '<elead>ta', '&tau;')
HTML#Map('inoremap', '<elead>up', '&upsilon;')
HTML#Map('inoremap', '<elead>ph', '&phi;')
HTML#Map('inoremap', '<elead>ch', '&chi;')
HTML#Map('inoremap', '<elead>ps', '&psi;')
HTML#Map('inoremap', '<elead>og', '&omega;')
HTML#Map('inoremap', '<elead>ts', '&thetasym;')
HTML#Map('inoremap', '<elead>uh', '&upsih;')
HTML#Map('inoremap', '<elead>pv', '&piv;')
# single-line arrows:
HTML#Map('inoremap', '<elead>la', '&larr;')
HTML#Map('inoremap', '<elead>ua', '&uarr;')
HTML#Map('inoremap', '<elead>ra', '&rarr;')
HTML#Map('inoremap', '<elead>da', '&darr;')
HTML#Map('inoremap', '<elead>ha', '&harr;')
# HTML#Map('inoremap', '<elead>ca', '&crarr;')
# double-line arrows:
HTML#Map('inoremap', '<elead>lA', '&lArr;')
HTML#Map('inoremap', '<elead>uA', '&uArr;')
HTML#Map('inoremap', '<elead>rA', '&rArr;')
HTML#Map('inoremap', '<elead>dA', '&dArr;')
HTML#Map('inoremap', '<elead>hA', '&hArr;')
# Roman numerals, upppercase:
HTML#Map('inoremap', '<elead>R1',    '&#x2160;')
HTML#Map('inoremap', '<elead>R2',    '&#x2161;')
HTML#Map('inoremap', '<elead>R3',    '&#x2162;')
HTML#Map('inoremap', '<elead>R4',    '&#x2163;')
HTML#Map('inoremap', '<elead>R5',    '&#x2164;')
HTML#Map('inoremap', '<elead>R6',    '&#x2165;')
HTML#Map('inoremap', '<elead>R7',    '&#x2166;')
HTML#Map('inoremap', '<elead>R8',    '&#x2167;')
HTML#Map('inoremap', '<elead>R9',    '&#x2168;')
HTML#Map('inoremap', '<elead>R10',   '&#x2169;')
HTML#Map('inoremap', '<elead>R11',   '&#x216a;')
HTML#Map('inoremap', '<elead>R12',   '&#x216b;')
HTML#Map('inoremap', '<elead>R50',   '&#x216c;')
HTML#Map('inoremap', '<elead>R100',  '&#x216d;')
HTML#Map('inoremap', '<elead>R500',  '&#x216e;')
HTML#Map('inoremap', '<elead>R1000', '&#x216f;')
# Roman numerals, lowercase:
HTML#Map('inoremap', '<elead>r1',    '&#x2170;')
HTML#Map('inoremap', '<elead>r2',    '&#x2171;')
HTML#Map('inoremap', '<elead>r3',    '&#x2172;')
HTML#Map('inoremap', '<elead>r4',    '&#x2173;')
HTML#Map('inoremap', '<elead>r5',    '&#x2174;')
HTML#Map('inoremap', '<elead>r6',    '&#x2175;')
HTML#Map('inoremap', '<elead>r7',    '&#x2176;')
HTML#Map('inoremap', '<elead>r8',    '&#x2177;')
HTML#Map('inoremap', '<elead>r9',    '&#x2178;')
HTML#Map('inoremap', '<elead>r10',   '&#x2179;')
HTML#Map('inoremap', '<elead>r11',   '&#x217a;')
HTML#Map('inoremap', '<elead>r12',   '&#x217b;')
HTML#Map('inoremap', '<elead>r50',   '&#x217c;')
HTML#Map('inoremap', '<elead>r100',  '&#x217d;')
HTML#Map('inoremap', '<elead>r500',  '&#x217e;')
HTML#Map('inoremap', '<elead>r1000', '&#x217f;')

# ----------------------------------------------------------------------------

# ---- Browser Remote Controls: ----------------------------------------- {{{1

var BrowserLauncherExists: bool
# try/catch because the function won't autoload if it's not installed:
try
  BrowserLauncherExists = BrowserLauncher#Exists() != []
catch /^Vim\%((\a\+)\)\=:E117:.\+BrowserLauncher#Exists/
  BrowserLauncherExists = false
endtry

if BrowserLauncherExists
  if BrowserLauncher#Exists('default')
    # Run the default browser:
    HTML#Map(
      'nnoremap',
      '<lead>db',
      ":vim9cmd BrowserLauncher#Launch('default')<CR>"
    )
  endif

  if BrowserLauncher#Exists('firefox')
    # Firefox: View current file, starting Firefox if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>ff',
      ":vim9cmd BrowserLauncher#Launch('firefox', 0)<CR>"
    )
    # Firefox: Open a new window, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>nff',
      ":vim9cmd BrowserLauncher#Launch('firefox', 1)<CR>"
    )
    # Firefox: Open a new tab, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>tff',
      ":vim9cmd BrowserLauncher#Launch('firefox', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('chrome')
    # Chrome: View current file, starting Chrome if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>gc',
      ":vim9cmd BrowserLauncher#Launch('chrome', 0)<CR>"
    )
    # Chrome: Open a new window, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>ngc',
      ":vim9cmd BrowserLauncher#Launch('chrome', 1)<CR>"
    )
    # Chrome: Open a new tab, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>tgc',
      ":vim9cmd BrowserLauncher#Launch('chrome', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('edge')
    # Edge: View current file, starting Microsoft Edge if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>ed',
      ":vim9cmd BrowserLauncher#Launch('edge', 0)<CR>"
    )
    # Edge: Open a new window, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>ned',
      ":vim9cmd BrowserLauncher#Launch('edge', 1)<CR>"
    )
    # Edge: Open a new tab, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>ted',
      ":vim9cmd BrowserLauncher#Launch('edge', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('opera')
    # Opera: View current file, starting Opera if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>oa',
      ":vim9cmd BrowserLauncher#Launch('opera', 0)<CR>"
    )
    # Opera: View current file in a new window, starting Opera if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>noa',
      ":vim9cmd BrowserLauncher#Launch('opera', 1)<CR>"
    )
    # Opera: Open a new tab, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>toa',
      ":vim9cmd BrowserLauncher#Launch('opera', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('safari')
    # Safari: View current file, starting Safari if it's not running:
    HTML#Map(
      'nnoremap',
      '<lead>sf',
      ":vim9cmd BrowserLauncher#Launch('safari', 0)<CR>"
    )
    # Safari: Open a new window, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>nsf',
      ":vim9cmd BrowserLauncher#Launch('safari', 1)<CR>"
      )
    # Safari: Open a new tab, and view the current file:
    HTML#Map(
      'nnoremap',
      '<lead>tsf',
      ":vim9cmd BrowserLauncher#Launch('safari', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('lynx')
    # Lynx:  (This may happen anyway if there's no GUI available.)
    HTML#Map(
      'nnoremap',
      '<lead>ly',
      ":vim9cmd BrowserLauncher#Launch('lynx', 0)<CR>"
    )
    # Lynx in an xterm:  (This always happens in the Vim GUI.)
    HTML#Map(
      'nnoremap',
      '<lead>nly',
      ":vim9cmd BrowserLauncher#Launch('lynx', 1)<CR>"
    )
    # Lynx in a new Vim window, using :terminal:
    HTML#Map(
      'nnoremap',
      '<lead>tly',
      ":vim9cmd BrowserLauncher#Launch('lynx', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('w3m')
    # w3m:  (This may happen anyway if there's no GUI available.)
    HTML#Map(
      'nnoremap',
      '<lead>w3',
      ":vim9cmd BrowserLauncher#Launch('w3m', 0)<CR>"
    )
    # w3m in an xterm:  (This always happens in the Vim GUI.)
    HTML#Map(
      'nnoremap',
      '<lead>nw3',
      ":vim9cmd BrowserLauncher#Launch('w3m', 1)<CR>"
    )
    # w3m in a new Vim window, using :terminal:
    HTML#Map(
      'nnoremap',
      '<lead>tw3',
      ":vim9cmd BrowserLauncher#Launch('w3m', 2)<CR>"
    )
  endif

  if BrowserLauncher#Exists('links')
    # Links:  (This may happen anyway if there's no GUI available.)
    HTML#Map(
      'nnoremap',
      '<lead>ln',
      ":vim9cmd BrowserLauncher#Launch('links', 0)<CR>"
    )
    # Lynx in an xterm:  (This always happens in the Vim GUI.)
    HTML#Map(
      'nnoremap',
      '<lead>nln',
      ":vim9cmd BrowserLauncher#Launch('links', 1)<CR>"
    )
    # Lynx in a new Vim window, using :terminal:
    HTML#Map(
      'nnoremap',
      '<lead>tln',
      ":vim9cmd BrowserLauncher#Launch('links', 2)<CR>"
    )
  endif
endif

# ----------------------------------------------------------------------------

endif # ! exists('b:did_html_mappings')

# ---- ToolBar Buttons: ------------------------------------------------- {{{1
if ! has('gui_running') && ! HTML#BoolVar('g:force_html_menu')
  augroup HTMLplugin
  au!
  execute 'autocmd GUIEnter * ++once source ' .. g:html_plugin_file
  augroup END
elseif exists('g:did_html_menus')
  HTML#MenuControl()
elseif ! HTML#BoolVar('g:no_html_menu')

# Solve a race condition:
if ! exists('g:did_install_default_menus')
  source $VIMRUNTIME/menu.vim
endif

if ! HTML#BoolVar('g:no_html_toolbar') && has('toolbar')

  if findfile('bitmaps/Browser.bmp', &runtimepath) == ''
    var bitmapmessage = "Warning:\nYou need to install the Toolbar Bitmaps for the "
      .. g:html_plugin_file->fnamemodify(':t') .. " plugin.\n"
      .. "See: http://christianrobinson.name/HTML/#files\n"
      .. 'Or see ":help g:no_html_toolbar".'
    var bitmapmessagereturn = bitmapmessage->confirm("&Dismiss\nView &Help\nGet &Bitmaps", 1, 'Warning')

    if bitmapmessagereturn == 2
      help g:no_html_toolbar
      # Go to the previous window or everything gets messy:
      wincmd p
    elseif bitmapmessagereturn == 3
      BrowserLauncher#Launch('default', 0, 'http://christianrobinson.name/HTML/#files')
    endif
  endif

  set guioptions+=T

  # Save some menu stuff from the global menu.vim so we can reuse them later:
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

  # For some reason, the tmenu commands must come before the other menu
  # commands for that menu item, or GTK versions of gVim don't show the
  # icons properly.

  tmenu               1.10  ToolBar.Open         Open File
  execute 'anoremenu  1.10  ToolBar.Open ' ..    save_toolbar['open']
  tmenu               1.20  ToolBar.Save         Save Current File
  execute 'anoremenu  1.20  ToolBar.Save ' ..    save_toolbar['save']
  tmenu               1.30  ToolBar.SaveAll      Save All Files
  execute 'anoremenu  1.30  ToolBar.SaveAll ' .. save_toolbar['saveall']

   menu               1.50  ToolBar.-sep1-       <Nop>

  tmenu               1.60  ToolBar.Template     Insert Template
  HTML#LeadMenu('amenu', '1.60', 'ToolBar.Template', 'html')

   menu               1.65  ToolBar.-sep2-       <Nop>

  tmenu               1.70  ToolBar.Paragraph    Create Paragraph
  HTML#LeadMenu('imenu', '1.70', 'ToolBar.Paragraph', 'pp')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Paragraph', 'pp')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Paragraph', 'pp i')
  tmenu               1.80  ToolBar.Break        Line Break
  HTML#LeadMenu('imenu', '1.80', 'ToolBar.Break', 'br')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Break', 'br')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Break', 'br i')

   menu               1.85  ToolBar.-sep3-       <Nop>

  tmenu               1.90  ToolBar.Link         Create Hyperlink
  HTML#LeadMenu('imenu', '1.90', 'ToolBar.Link', 'ah')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Link', 'ah')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Link', 'ah i')
  tmenu               1.100 ToolBar.Image        Insert Image
  HTML#LeadMenu('imenu', '1.100', 'ToolBar.Image', 'im')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Image', 'im')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Image', 'im i')

   menu               1.105 ToolBar.-sep4-       <Nop>

  tmenu               1.110 ToolBar.Hline        Create Horizontal Rule
  HTML#LeadMenu('imenu', '1.110', 'ToolBar.Hline', 'hr')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Hline', 'hr i')

   menu               1.115 ToolBar.-sep5-       <Nop>

  tmenu               1.120 ToolBar.Table        Create Table
  HTML#LeadMenu('imenu', '1.120', 'ToolBar.Table', 'tA <ESC>')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Table', 'tA')

   menu               1.125 ToolBar.-sep6-       <Nop>

  tmenu               1.130 ToolBar.Blist        Create Bullet List
  execute 'inoremenu  1.130 ToolBar.Blist'       g:html_map_leader .. 'ul' .. g:html_map_leader .. 'li'
  execute 'vnoremenu        ToolBar.Blist'       g:html_map_leader .. 'uli' .. g:html_map_leader .. 'li<ESC>'
  execute 'nnoremenu        ToolBar.Blist'       'i' .. g:html_map_leader .. 'ul' .. g:html_map_leader .. 'li'
  tmenu               1.140 ToolBar.Nlist        Create Numbered List
  execute 'inoremenu  1.140 ToolBar.Nlist'       g:html_map_leader .. 'ol' .. g:html_map_leader .. 'li'
  execute 'vnoremenu        ToolBar.Nlist'       g:html_map_leader .. 'oli' .. g:html_map_leader .. 'li<ESC>'
  execute 'nnoremenu        ToolBar.Nlist'       'i' .. g:html_map_leader .. 'ol' .. g:html_map_leader .. 'li'
  tmenu               1.150 ToolBar.Litem        Add List Item
  HTML#LeadMenu('imenu', '1.150', 'ToolBar.Litem', 'li')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Litem', 'li i')

   menu               1.155 ToolBar.-sep7-       <Nop>

  tmenu               1.160 ToolBar.Bold         Bold
  HTML#LeadMenu('imenu', '1.160', 'ToolBar.Bold', 'bo')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Bold', 'bo')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Bold', 'bo i')
  tmenu               1.170 ToolBar.Italic       Italic
  HTML#LeadMenu('imenu', '1.170', 'ToolBar.Italic', 'it')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Italic', 'it')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Italic', 'it i')
  tmenu               1.180 ToolBar.Underline    Underline
  HTML#LeadMenu('imenu', '1.180', 'ToolBar.Underline', 'un')
  HTML#LeadMenu('vmenu', '-', 'ToolBar.Underline', 'un')
  HTML#LeadMenu('nmenu', '-', 'ToolBar.Underline', 'un i')

   menu               1.185 ToolBar.-sep8-       <Nop>

  tmenu               1.190 ToolBar.Undo         Undo
  anoremenu           1.190 ToolBar.Undo         u
  tmenu               1.200 ToolBar.Redo         Redo
  anoremenu           1.200 ToolBar.Redo         <C-R>


   menu               1.205 ToolBar.-sep9-       <Nop>

  tmenu               1.210 ToolBar.Cut          Cut to Clipboard
  execute 'vnoremenu  1.210 ToolBar.Cut ' ..     save_toolbar['cut_v']
  tmenu               1.220 ToolBar.Copy         Copy to Clipboard
  execute 'vnoremenu  1.220 ToolBar.Copy ' ..    save_toolbar['copy_v']
  tmenu               1.230 ToolBar.Paste        Paste from Clipboard
  execute 'nnoremenu  1.230 ToolBar.Paste ' ..   save_toolbar['paste_n']
  execute 'cnoremenu        ToolBar.Paste ' ..   save_toolbar['paste_c']
  execute 'inoremenu        ToolBar.Paste ' ..   save_toolbar['paste_i']
  execute 'vnoremenu        ToolBar.Paste ' ..   save_toolbar['paste_v']

   menu               1.235 ToolBar.-sep10-      <Nop>

  if !has('gui_athena')
    tmenu              1.240 ToolBar.Replace      Find / Replace
    execute 'anoremenu 1.240 ToolBar.Replace ' .. save_toolbar['replace']
    vunmenu                  ToolBar.Replace
    execute 'vnoremenu       ToolBar.Replace ' .. save_toolbar['replace_v']
    tmenu 1.250              ToolBar.FindNext     Find Next
    anoremenu 1.250          ToolBar.FindNext     n
    tmenu 1.260              ToolBar.FindPrev     Find Previous
    anoremenu 1.260          ToolBar.FindPrev     N
  endif

   menu 1.500 ToolBar.-sep50- <Nop>

  if maparg(g:html_map_leader .. 'db', 'n') != ''
    tmenu          1.510 ToolBar.Browser Launch the Default Browser on the Current File
    HTML#LeadMenu('amenu', '1.510', 'ToolBar.Browser', 'db')
  endif

  if maparg(g:html_map_leader .. 'ff', 'n') != ''
    tmenu           1.520 ToolBar.Firefox   Launch Firefox on the Current File
    HTML#LeadMenu('amenu', '1.520', 'ToolBar.Firefox', 'ff')
  endif

  if maparg(g:html_map_leader .. 'gc', 'n') != ''
    tmenu           1.530 ToolBar.Chrome    Launch Chrome on the Current File
    HTML#LeadMenu('amenu', '1.530', 'ToolBar.Chrome', 'gc')
  endif

  if maparg(g:html_map_leader .. 'ed', 'n') != ''
    tmenu           1.540 ToolBar.Edge      Launch Edge on the Current File
    HTML#LeadMenu('amenu', '1.540', 'ToolBar.Edge', 'ed')
  endif

  if maparg(g:html_map_leader .. 'oa', 'n') != ''
    tmenu           1.550 ToolBar.Opera     Launch Opera on the Current File
    HTML#LeadMenu('amenu', '1.550', 'ToolBar.Opera', 'oa')
  endif

  if maparg(g:html_map_leader .. 'sf', 'n') != ''
    tmenu           1.560 ToolBar.Safari    Launch Safari on the Current File
    HTML#LeadMenu('amenu', '1.560', 'ToolBar.Safari', 'sf')
  endif

  if maparg(g:html_map_leader .. 'w3', 'n') != ''
    tmenu           1.570 ToolBar.w3m       Launch w3m on the Current File
    HTML#LeadMenu('amenu', '1.570', 'ToolBar.w3m', 'w3')
  endif

  if maparg(g:html_map_leader .. 'ly', 'n') != ''
    tmenu           1.580 ToolBar.Lynx      Launch Lynx on the Current File
    HTML#LeadMenu('amenu', '1.580', 'ToolBar.Lynx', 'ly')
  endif

  if maparg(g:html_map_leader .. 'ln', 'n') != ''
    tmenu           1.580 ToolBar.Links     Launch Links on the Current File
    HTML#LeadMenu('amenu', '1.580', 'ToolBar.Links', 'ln')
  endif

   menu     1.998 ToolBar.-sep99- <Nop>
  tmenu     1.999 ToolBar.Help    HTML Help
  anoremenu 1.999 ToolBar.Help    :help HTML<CR>

  g:did_html_toolbar = true
endif  # ! HTML#BoolVar('g:no_html_toolbar') && has('toolbar')
# ----------------------------------------------------------------------------

# ---- Menu Items: ------------------------------------------------------ {{{1

# Add to the PopUp menu:   {{{2
nnoremenu 1.91 PopUp.Select\ Ta&g vat
onoremenu      PopUp.Select\ Ta&g at
vnoremenu      PopUp.Select\ Ta&g <C-c>vat
inoremenu      PopUp.Select\ Ta&g <C-O>vat
cnoremenu      PopUp.Select\ Ta&g <C-c>vat

nnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g vit
onoremenu      PopUp.Select\ &Inner\ Ta&g it
vnoremenu      PopUp.Select\ &Inner\ Ta&g <C-c>vit
inoremenu      PopUp.Select\ &Inner\ Ta&g <C-O>vit
cnoremenu      PopUp.Select\ &Inner\ Ta&g <C-c>vit
# }}}2

augroup HTMLmenu
au!
  autocmd BufEnter,WinEnter * {
    HTML#MenuControl()
    HTML#ToggleClipboard(2)
  }
augroup END

amenu HTM&L.HTML\ Help<TAB>:help\ HTML\.txt :help HTML.txt<CR>
 menu HTML.-sep1- <Nop>

amenu HTML.Co&ntrol.&Disable\ Mappings<tab>:HTML\ disable     :HTMLmappings disable<CR>
amenu HTML.Co&ntrol.&Enable\ Mappings<tab>:HTML\ enable       :HTMLmappings enable<CR>
amenu disable HTML.Control.Enable\ Mappings
 menu HTML.Control.-sep1- <Nop>
amenu HTML.Co&ntrol.Switch\ to\ &HTML\ mode<tab>:HTML\ html   :HTMLmappings html<CR>
amenu HTML.Co&ntrol.Switch\ to\ &XHTML\ mode<tab>:HTML\ xhtml :HTMLmappings xhtml<CR>
 menu HTML.Control.-sep2- <Nop>
amenu HTML.Co&ntrol.&Reload\ Mappings<tab>:HTML\ reload       :HTMLmappings reload<CR>

if HTML#BoolVar('b:do_xhtml_mappings')
  amenu disable HTML.Control.Switch\ to\ XHTML\ mode
else
  amenu disable HTML.Control.Switch\ to\ HTML\ mode
endif

if maparg(g:html_map_leader .. 'db', 'n') != ''
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Default Browser', 'db')
endif
if maparg(g:html_map_leader .. 'ff', 'n') != ''
  menu HTML.Preview.-sep1- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Firefox', 'ff')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Firefox (New Window)', 'nff')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Firefox (New Tab)', 'tff')
endif
if maparg(g:html_map_leader .. 'gc', 'n') != ''
  menu HTML.Preview.-sep2- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Chrome', 'gc')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Chrome (New Window)', 'ngc')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Chrome (New Tab)', 'tgc')
endif
if maparg(g:html_map_leader .. 'ed', 'n') != ''
  menu HTML.Preview.-sep3- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Edge', 'ed')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Edge (New Window)', 'ned')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Edge (New Tab)', 'ted')
endif
if maparg(g:html_map_leader .. 'oa', 'n') != ''
  menu HTML.Preview.-sep4- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Opera', 'oa')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Opera (New Window)', 'noa')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Opera (New Tab)', 'toa')
endif
if maparg(g:html_map_leader .. 'sf', 'n') != ''
  menu HTML.Preview.-sep5- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Safari', 'sf')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Safari (New Window)', 'nsf')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Safari (New Tab)', 'tsf')
endif
if maparg(g:html_map_leader .. 'ly', 'n') != ''
  menu HTML.Preview.-sep6- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&Lynx', 'ly')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Lynx (New Window)', 'nly')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Lynx (:terminal)', 'tly')
endif
if maparg(g:html_map_leader .. 'w3', 'n') != ''
  menu HTML.Preview.-sep7- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.&w3m', 'w3')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.w3m (New Window)', 'nw3')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.w3m (:terminal)', 'tw3')
endif
if maparg(g:html_map_leader .. 'ln', 'n') != ''
  menu HTML.Preview.-sep8- <nop>
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Li&nks', 'ln')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Links (New Window)', 'nln')
  HTML#LeadMenu('amenu', '-', 'HTML.&Preview.Links (:terminal)', 'tln')
endif

menu HTML.-sep4- <Nop>

HTML#LeadMenu('amenu', '-', 'HTML.Template', 'html')

menu HTML.-sep5- <Nop>

# Character Entities menu:   {{{2

HTML#LeadMenu('vmenu', '-', 'HTML.Character &Entities.Convert to Entity', '&')
HTML#LeadMenu('vmenu', '-', 'HTML.Character &Entities.Convert to %XX (URI Encode)', '%')
HTML#LeadMenu('vmenu', '-', 'HTML.Character &Entities.Convert from Entities/%XX', '^')

menu HTML.Character\ Entities.-sep0- <Nop>
HTML#EntityMenu('HTML.Character Entities.Ampersand', '&', '-')
HTML#EntityMenu('HTML.Character Entities.Greaterthan', '>', '>')
HTML#EntityMenu('HTML.Character Entities.Lessthan', '<', '<')
HTML#EntityMenu('HTML.Character Entities.Space', '<space>', 'nonbreaking')
menu HTML.Character\ Entities.-sep1- <Nop>
HTML#EntityMenu('HTML.Character Entities.Cent', 'c\|', '\xA2')
HTML#EntityMenu('HTML.Character Entities.Pound', '#', '\xA3')
HTML#EntityMenu('HTML.Character Entities.Euro', 'E=', '\u20AC')
HTML#EntityMenu('HTML.Character Entities.Yen', 'Y=', '\xA5')
menu HTML.Character\ Entities.-sep2- <Nop>
HTML#EntityMenu('HTML.Character Entities.Copyright', 'cO', '\xA9')
HTML#EntityMenu('HTML.Character Entities.Registered', 'rO', '\xAE')
HTML#EntityMenu('HTML.Character Entities.Trademark', 'tm', '\u2122')
menu HTML.Character\ Entities.-sep3- <Nop>
HTML#EntityMenu('HTML.Character Entities.Inverted Exlamation', '!', '\xA1')
HTML#EntityMenu('HTML.Character Entities.Inverted Question', '?', '\xBF')
HTML#EntityMenu('HTML.Character Entities.Paragraph', 'pa', '\xB6')
HTML#EntityMenu('HTML.Character Entities.Section', 'se', '\xA7')
HTML#EntityMenu('HTML.Character Entities.Middle Dot', '\.', '\xB7')
HTML#EntityMenu('HTML.Character Entities.Bullet', '*', '\u2022')
HTML#EntityMenu('HTML.Character Entities.En dash', 'n-', '\u2013')
HTML#EntityMenu('HTML.Character Entities.Em dash', 'm-', '\u2014')
HTML#EntityMenu('HTML.Character Entities.Ellipsis', '3\.', '\u2026')
menu HTML.Character\ Entities.-sep5- <Nop>
HTML#EntityMenu('HTML.Character Entities.Math.Multiply', 'x', '\xD7')
HTML#EntityMenu('HTML.Character Entities.Math.Divide', '/', '\xF7')
HTML#EntityMenu('HTML.Character Entities.Math.Degree', 'dg', '\xB0')
HTML#EntityMenu('HTML.Character Entities.Math.Micro', 'mi', '\xB5')
HTML#EntityMenu('HTML.Character Entities.Math.Plus/Minus', '+-', '\xB1')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 1', 'R1', '\u2160')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 2', 'R2', '\u2161')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 3', 'R3', '\u2162')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 4', 'R4', '\u2163')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 5', 'R5', '\u2164')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 6', 'R6', '\u2165')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 7', 'R7', '\u2166')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 8', 'R8', '\u2167')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 9', 'R9', '\u2168')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 10', 'R10', '\u2169')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 11', 'R11', '\u216A')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 12', 'R12', '\u216B')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 50', 'R50', '\u216C')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 100', 'R100', '\u216D')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 500', 'R500', '\u216E')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Uppercase 1000', 'R1000', '\u216F')
menu HTML.Character\ Entities.Math.Roman\ Numerals.-sep1- <Nop>
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 1', 'r1', '\u2170')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 2', 'r2', '\u2171')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 3', 'r3', '\u2172')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 4', 'r4', '\u2173')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 5', 'r5', '\u2174')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 6', 'r6', '\u2175')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 7', 'r7', '\u2176')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 8', 'r8', '\u2177')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 9', 'r9', '\u2178')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 10', 'r10', '\u2179')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 11', 'r11', '\u217A')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 12', 'r12', '\u217B')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 50', 'r50', '\u217C')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 100', 'r100', '\u217D')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 500', 'r500', '\u217E')
HTML#EntityMenu('HTML.Character Entities.Math.Roman Numerals.Lowercase 1000', 'r1000', '\u217F')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 0', '0^', '\u2070')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 1', '1^', '\xB9')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 2', '2^', '\xB2')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 3', '3^', '\xB3')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 4', '4^', '\u2074')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 5', '5^', '\u2075')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 6', '6^', '\u2076')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 7', '7^', '\u2077')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 8', '8^', '\u2078')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Superscript 9', '9^', '\u2079')
menu HTML.Character\ Entities.Math.Super/Subscript.-sep1- <Nop>
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 0', '0v', '\u2080')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 1', '1v', '\u2081')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 2', '2v', '\u2082')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 3', '3v', '\u2083')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 4', '4v', '\u2084')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 5', '5v', '\u2085')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 6', '6v', '\u2086')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 7', '7v', '\u2087')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 8', '8v', '\u2088')
HTML#EntityMenu('HTML.Character Entities.Math.Super/Subscript.Subscript 9', '9v', '\u2089')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Quarter', '14', '\xBC')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Half', '12', '\xBD')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Three Quarters', '34', '\xBE')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Third', '13', '\u2153')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Two Thirds', '23', '\u2154')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Fifth', '15', '\u2155')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Two Fifths', '25', '\u2156')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Three Fifths', '35', '\u2157')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Four Fiftsh', '45', '\u2158')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Sixth', '16', '\u2159')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Five Sixths', '56', '\u215A')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.One Eigth', '18', '\u215B')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Three Eigths', '38', '\u215C')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Five Eigths', '58', '\u215D')
HTML#EntityMenu('HTML.Character Entities.Math.Fractions.Seven Eigths', '78', '\u215E')
HTML#EntityMenu('HTML.Character Entities.&Graves.A-grave', 'A`', '\xC0')
HTML#EntityMenu('HTML.Character Entities.&Graves.a-grave', 'a`', '\xE0')
HTML#EntityMenu('HTML.Character Entities.&Graves.E-grave', 'E`', '\xC8')
HTML#EntityMenu('HTML.Character Entities.&Graves.e-grave', 'e`', '\xE8')
HTML#EntityMenu('HTML.Character Entities.&Graves.I-grave', 'I`', '\xCC')
HTML#EntityMenu('HTML.Character Entities.&Graves.i-grave', 'i`', '\xEC')
HTML#EntityMenu('HTML.Character Entities.&Graves.O-grave', 'O`', '\xD2')
HTML#EntityMenu('HTML.Character Entities.&Graves.o-grave', 'o`', '\xF2')
HTML#EntityMenu('HTML.Character Entities.&Graves.U-grave', 'U`', '\xD9')
HTML#EntityMenu('HTML.Character Entities.&Graves.u-grave', 'u`', '\xF9')
HTML#EntityMenu('HTML.Character Entities.&Acutes.A-acute', "A'", '\xC1')
HTML#EntityMenu('HTML.Character Entities.&Acutes.a-acute', "a'", '\xE1')
HTML#EntityMenu('HTML.Character Entities.&Acutes.E-acute', "E'", '\xC9')
HTML#EntityMenu('HTML.Character Entities.&Acutes.e-acute', "e'", '\xE9')
HTML#EntityMenu('HTML.Character Entities.&Acutes.I-acute', "I'", '\xCD')
HTML#EntityMenu('HTML.Character Entities.&Acutes.i-acute', "i'", '\xED')
HTML#EntityMenu('HTML.Character Entities.&Acutes.O-acute', "O'", '\xD3')
HTML#EntityMenu('HTML.Character Entities.&Acutes.o-acute', "o'", '\xF3')
HTML#EntityMenu('HTML.Character Entities.&Acutes.U-acute', "U'", '\xDA')
HTML#EntityMenu('HTML.Character Entities.&Acutes.u-acute', "u'", '\xFA')
HTML#EntityMenu('HTML.Character Entities.&Acutes.Y-acute', "Y'", '\xDD')
HTML#EntityMenu('HTML.Character Entities.&Acutes.y-acute', "y'", '\xFD')
HTML#EntityMenu('HTML.Character Entities.&Tildes.A-tilde', 'A~', '\xC3')
HTML#EntityMenu('HTML.Character Entities.&Tildes.a-tilde', 'a~', '\xE3')
HTML#EntityMenu('HTML.Character Entities.&Tildes.N-tilde', 'N~', '\xD1')
HTML#EntityMenu('HTML.Character Entities.&Tildes.n-tilde', 'n~', '\xF1')
HTML#EntityMenu('HTML.Character Entities.&Tildes.O-tilde', 'O~', '\xD5')
HTML#EntityMenu('HTML.Character Entities.&Tildes.o-tilde', 'o~', '\xF5')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.A-circumflex', 'A^', '\xC2')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.a-circumflex', 'a^', '\xE2')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.E-circumflex', 'E^', '\xCA')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.e-circumflex', 'e^', '\xEA')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.I-circumflex', 'I^', '\xCE')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.i-circumflex', 'i^', '\xEE')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.O-circumflex', 'O^', '\xD4')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.o-circumflex', 'o^', '\xF4')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.U-circumflex', 'U^', '\xDB')
HTML#EntityMenu('HTML.Character Entities.&Circumflexes.u-circumflex', 'u^', '\xFB')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.A-umlaut', 'A"', '\xC4')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.a-umlaut', 'a"', '\xE4')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.E-umlaut', 'E"', '\xCB')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.e-umlaut', 'e"', '\xEB')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.I-umlaut', 'I"', '\xCF')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.i-umlaut', 'i"', '\xEF')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.O-umlaut', 'O"', '\xD6')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.o-umlaut', 'o"', '\xF6')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.U-umlaut', 'U"', '\xDC')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.u-umlaut', 'u"', '\xFC')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.y-umlaut', 'y"', '\xFF')
HTML#EntityMenu('HTML.Character Entities.&Umlauts.Umlaut', '"', '\xA8')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Alpha', 'Al', '\u391')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Beta', 'Be', '\u392')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Gamma', 'Ga', '\u393')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Delta', 'De', '\u394')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Epsilon', 'Ep', '\u395')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Zeta', 'Ze', '\u396')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Eta', 'Et', '\u397')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Theta', 'Th', '\u398')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Iota', 'Io', '\u399')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Kappa', 'Ka', '\u39A')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Lambda', 'Lm', '\u39B')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Mu', 'Mu', '\u39C')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Nu', 'Nu', '\u39D')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Xi', 'Xi', '\u39E')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Omicron', 'Oc', '\u39F')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Pi', 'Pi', '\u3A0')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Rho', 'Rh', '\u3A1')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Sigma', 'Si', '\u3A3')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Tau', 'Ta', '\u3A4')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Upsilon', 'Up', '\u3A5')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Phi', 'Ph', '\u3A6')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Chi', 'Ch', '\u3A7')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Uppercase.Psi', 'Ps', '\u3A8')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.alpha', 'al', '\u3B1')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.beta', 'be', '\u3B2')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.gamma', 'ga', '\u3B3')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.delta', 'de', '\u3B4')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.epsilon', 'ep', '\u3B5')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.zeta', 'ze', '\u3B6')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.eta', 'et', '\u3B7')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.theta', 'th', '\u3B8')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.iota', 'io', '\u3B9')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.kappa', 'ka', '\u3BA')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.lambda', 'lm', '\u3BB')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.mu', 'mu', '\u3BC')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.nu', 'nu', '\u3BD')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.xi', 'xi', '\u3BE')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.omicron', 'oc', '\u3BF')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.pi', 'pi', '\u3C0')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.rho', 'rh', '\u3C1')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.sigma', 'si', '\u3C3')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.sigmaf', 'sf', '\u3C2')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.tau', 'ta', '\u3C4')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.upsilon', 'up', '\u3C5')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.phi', 'ph', '\u3C6')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.chi', 'ch', '\u3C7')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.psi', 'ps', '\u3C8')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.omega', 'og', '\u3C9')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.thetasym', 'ts', '\u3D1')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.upsih', 'uh', '\u3D2')
HTML#EntityMenu('HTML.Character Entities.Greek &Letters.&Lowercase.piv', 'pv', '\u3D6')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Left single arrow', 'la', '\u2190')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Right single arrow', 'ra', '\u2192')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Up single arrow', 'ua', '\u2191')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Down single arrow', 'da', '\u2193')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Left-right single arrow', 'ha', '\u2194')
menu HTML.Character\ Entities.Arrows.-sep1- <Nop>
HTML#EntityMenu('HTML.Character Entities.A&rrows.Left double arrow', 'lA', '\u21D0')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Right double arrow', 'rA', '\u21D2')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Up double arrow', 'uA', '\u21D1')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Down double arrow', 'dA', '\u21D3')
HTML#EntityMenu('HTML.Character Entities.A&rrows.Left-right double arrow', 'hA', '\u21D4')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Quotation mark', "'", 'x22')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Left Single Quote', "l'", '\u2018')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Right Single Quote', "r'", '\u2019')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Left Double Quote', 'l"', '\u201C')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Right Double Quote', 'r"', '\u201D')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Left Angle Quote', '2<', '\xAB')
HTML#EntityMenu('HTML.Character Entities.&Quotes.Right Angle Quote', '2>', '\xBB')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..A-ring', 'Ao', '\xC5')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..a-ring', 'ao', '\xE5')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..AE-ligature', 'AE', '\xC6')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..ae-ligature', 'ae', '\xE6')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..C-cedilla', 'C,', '\xC7')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..c-cedilla', 'c,', '\xE7')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..O-slash', 'O/', '\xD8')
HTML#EntityMenu('HTML.Character Entities.       &etc\.\.\..o-slash', 'o/', '\xF8')

# Colors menu:   {{{2

HTML#LeadMenu('amenu', '-', 'HTML.&Colors.Display All && Select', '3')
amenu HTML.Colors.-sep1- <Nop>

HTML#ColorsMenu('Alice Blue', '#F0F8FF')
HTML#ColorsMenu('Antique White', '#FAEBD7')
HTML#ColorsMenu('Aqua', '#00FFFF')
HTML#ColorsMenu('Aquamarine', '#7FFFD4')
HTML#ColorsMenu('Azure', '#F0FFFF')

HTML#ColorsMenu('Beige', '#F5F5DC')
HTML#ColorsMenu('Bisque', '#FFE4C4')
HTML#ColorsMenu('Black', '#000000')
HTML#ColorsMenu('Blanched Almond', '#FFEBCD')
HTML#ColorsMenu('Blue', '#0000FF')
HTML#ColorsMenu('Blue Violet', '#8A2BE2')
HTML#ColorsMenu('Brown', '#A52A2A')
HTML#ColorsMenu('Burlywood', '#DEB887')

HTML#ColorsMenu('Cadet Blue', '#5F9EA0')
HTML#ColorsMenu('Chartreuse', '#7FFF00')
HTML#ColorsMenu('Chocolate', '#D2691E')
HTML#ColorsMenu('Coral', '#FF7F50')
HTML#ColorsMenu('Cornflower Blue', '#6495ED')
HTML#ColorsMenu('Cornsilk', '#FFF8DC')
HTML#ColorsMenu('Crimson', '#DC143C')
HTML#ColorsMenu('Cyan', '#00FFFF')

HTML#ColorsMenu('Dark Blue', '#00008B')
HTML#ColorsMenu('Dark Cyan', '#008B8B')
HTML#ColorsMenu('Dark Goldenrod', '#B8860B')
HTML#ColorsMenu('Dark Gray', '#A9A9A9')
HTML#ColorsMenu('Dark Green', '#006400')
HTML#ColorsMenu('Dark Khaki', '#BDB76B')
HTML#ColorsMenu('Dark Magenta', '#8B008B')
HTML#ColorsMenu('Dark Olive Green', '#556B2F')
HTML#ColorsMenu('Dark Orange', '#FF8C00')
HTML#ColorsMenu('Dark Orchid', '#9932CC')
HTML#ColorsMenu('Dark Red', '#8B0000')
HTML#ColorsMenu('Dark Salmon', '#E9967A')
HTML#ColorsMenu('Dark Seagreen', '#8FBC8F')
HTML#ColorsMenu('Dark Slate Blue', '#483D8B')
HTML#ColorsMenu('Dark Slate Gray', '#2F4F4F')
HTML#ColorsMenu('Dark Turquoise', '#00CED1')
HTML#ColorsMenu('Dark Violet', '#9400D3')
HTML#ColorsMenu('Deep Pink', '#FF1493')
HTML#ColorsMenu('Deep Skyblue', '#00BFFF')
HTML#ColorsMenu('Dim Gray', '#696969')
HTML#ColorsMenu('Dodger Blue', '#1E90FF')

HTML#ColorsMenu('Firebrick', '#B22222')
HTML#ColorsMenu('Floral White', '#FFFAF0')
HTML#ColorsMenu('Forest Green', '#228B22')
HTML#ColorsMenu('Fuchsia', '#FF00FF')
HTML#ColorsMenu('Gainsboro', '#DCDCDC')
HTML#ColorsMenu('Ghost White', '#F8F8FF')
HTML#ColorsMenu('Gold', '#FFD700')
HTML#ColorsMenu('Goldenrod', '#DAA520')
HTML#ColorsMenu('Gray', '#808080')
HTML#ColorsMenu('Green', '#008000')
HTML#ColorsMenu('Green Yellow', '#ADFF2F')

HTML#ColorsMenu('Honeydew', '#F0FFF0')
HTML#ColorsMenu('Hot Pink', '#FF69B4')
HTML#ColorsMenu('Indian Red', '#CD5C5C')
HTML#ColorsMenu('Indigo', '#4B0082')
HTML#ColorsMenu('Ivory', '#FFFFF0')
HTML#ColorsMenu('Khaki', '#F0E68C')

HTML#ColorsMenu('Lavender', '#E6E6FA')
HTML#ColorsMenu('Lavender Blush', '#FFF0F5')
HTML#ColorsMenu('Lawn Green', '#7CFC00')
HTML#ColorsMenu('Lemon Chiffon', '#FFFACD')
HTML#ColorsMenu('Light Blue', '#ADD8E6')
HTML#ColorsMenu('Light Coral', '#F08080')
HTML#ColorsMenu('Light Cyan', '#E0FFFF')
HTML#ColorsMenu('Light Goldenrod Yellow', '#FAFAD2')
HTML#ColorsMenu('Light Green', '#90EE90')
HTML#ColorsMenu('Light Grey', '#D3D3D3')
HTML#ColorsMenu('Light Pink', '#FFB6C1')
HTML#ColorsMenu('Light Salmon', '#FFA07A')
HTML#ColorsMenu('Light Sea Green', '#20B2AA')
HTML#ColorsMenu('Light Sky Blue', '#87CEFA')
HTML#ColorsMenu('Light Slate Gray', '#778899')
HTML#ColorsMenu('Light Steel Blue', '#B0C4DE')
HTML#ColorsMenu('Light Yellow', '#FFFFE0')
HTML#ColorsMenu('Lime', '#00FF00')
HTML#ColorsMenu('Lime Green', '#32CD32')
HTML#ColorsMenu('Linen', '#FAF0E6')

HTML#ColorsMenu('Magenta', '#FF00FF')
HTML#ColorsMenu('Maroon', '#800000')
HTML#ColorsMenu('Medium Aquamarine', '#66CDAA')
HTML#ColorsMenu('Medium Blue', '#0000CD')
HTML#ColorsMenu('Medium Orchid', '#BA55D3')
HTML#ColorsMenu('Medium Purple', '#9370DB')
HTML#ColorsMenu('Medium Sea Green', '#3CB371')
HTML#ColorsMenu('Medium Slate Blue', '#7B68EE')
HTML#ColorsMenu('Medium Spring Green', '#00FA9A')
HTML#ColorsMenu('Medium Turquoise', '#48D1CC')
HTML#ColorsMenu('Medium Violet Red', '#C71585')
HTML#ColorsMenu('Midnight Blue', '#191970')
HTML#ColorsMenu('Mintcream', '#F5FFFA')
HTML#ColorsMenu('Mistyrose', '#FFE4E1')
HTML#ColorsMenu('Moccasin', '#FFE4B5')

HTML#ColorsMenu('Navajo White', '#FFDEAD')
HTML#ColorsMenu('Navy', '#000080')
HTML#ColorsMenu('Old Lace', '#FDF5E6')
HTML#ColorsMenu('Olive', '#808000')
HTML#ColorsMenu('Olive Drab', '#6B8E23')
HTML#ColorsMenu('Orange', '#FFA500')
HTML#ColorsMenu('Orange Red', '#FF4500')
HTML#ColorsMenu('Orchid', '#DA70D6')

HTML#ColorsMenu('Pale Goldenrod', '#EEE8AA')
HTML#ColorsMenu('Pale Green', '#98FB98')
HTML#ColorsMenu('Pale Turquoise', '#AFEEEE')
HTML#ColorsMenu('Pale Violetred', '#DB7093')
HTML#ColorsMenu('Papayawhip', '#FFEFD5')
HTML#ColorsMenu('Peachpuff', '#FFDAB9')
HTML#ColorsMenu('Peru', '#CD853F')
HTML#ColorsMenu('Pink', '#FFC0CB')
HTML#ColorsMenu('Plum', '#DDA0DD')
HTML#ColorsMenu('Powder Blue', '#B0E0E6')
HTML#ColorsMenu('Purple', '#800080')

HTML#ColorsMenu('Red', '#FF0000')
HTML#ColorsMenu('Rosy Brown', '#BC8F8F')
HTML#ColorsMenu('Royal Blue', '#4169E1')

HTML#ColorsMenu('Saddle Brown', '#8B4513')
HTML#ColorsMenu('Salmon', '#FA8072')
HTML#ColorsMenu('Sandy Brown', '#F4A460')
HTML#ColorsMenu('Sea Green', '#2E8B57')
HTML#ColorsMenu('Seashell', '#FFF5EE')
HTML#ColorsMenu('Sienna', '#A0522D')
HTML#ColorsMenu('Silver', '#C0C0C0')
HTML#ColorsMenu('Sky Blue', '#87CEEB')
HTML#ColorsMenu('Slate Blue', '#6A5ACD')
HTML#ColorsMenu('Slate Gray', '#708090')
HTML#ColorsMenu('Snow', '#FFFAFA')
HTML#ColorsMenu('Spring Green', '#00FF7F')
HTML#ColorsMenu('Steel Blue', '#4682B4')

HTML#ColorsMenu('Tan', '#D2B48C')
HTML#ColorsMenu('Teal', '#008080')
HTML#ColorsMenu('Thistle', '#D8BFD8')
HTML#ColorsMenu('Tomato', '#FF6347')
HTML#ColorsMenu('Turquoise', '#40E0D0')
HTML#ColorsMenu('Violet', '#EE82EE')

# Font Styles menu:   {{{2

HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Bold', 'bo')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Bold', 'bo')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Bold', 'bo', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Strong', 'st')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Strong', 'st')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Strong', 'st', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Italics', 'it')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Italics', 'it')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Italics', 'it', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Emphasis', 'em')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Emphasis', 'em')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Emphasis', 'em', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Underline', 'un')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Underline', 'un')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Underline', 'un', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Big', 'bi')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Big', 'bi')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Big', 'bi', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Small', 'sm')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Small', 'sm')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Small', 'sm', 'i')
menu HTML.Font\ Styles.-sep1- <Nop>
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Font Size', 'fo')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Font Size', 'fo')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Font Size', 'fo', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Font Color', 'fc')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Font Color', 'fc')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Font Color', 'fc', 'i')
menu HTML.Font\ Styles.-sep2- <Nop>
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.CITE', 'ci')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.CITE', 'ci')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.CITE', 'ci', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.CODE', 'co')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.CODE', 'co')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.CODE', 'co', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Inserted Text', 'in')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Inserted Text', 'in')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Inserted Text', 'in', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Deleted Text', 'de')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Deleted Text', 'de')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Deleted Text', 'de', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Emphasize', 'em')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Emphasize', 'em')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Emphasize', 'em', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Keyboard Text', 'kb')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Keyboard Text', 'kb')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Keyboard Text', 'kb', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Sample Text', 'sa')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Sample Text', 'sa')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Sample Text', 'sa', 'i')
# HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Strikethrough', 'sk')
# HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Strikethrough', 'sk')
# HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Strikethrough', 'sk', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.STRONG', 'st')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.STRONG', 'st')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.STRONG', 'st', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Subscript', 'sb')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Subscript', 'sb')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Subscript', 'sb', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Superscript', 'sp')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Superscript', 'sp')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Superscript', 'sp', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Teletype Text', 'tt')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Teletype Text', 'tt')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Teletype Text', 'tt', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Font &Styles.Variable', 'va')
HTML#LeadMenu('vmenu', '-', 'HTML.Font &Styles.Variable', 'va')
HTML#LeadMenu('nmenu', '-', 'HTML.Font &Styles.Variable', 'va', 'i')


# Frames menu:   {{{2

# HTML#LeadMenu('imenu', '-', 'HTML.&Frames.FRAMESET', 'fs')
# HTML#LeadMenu('vmenu', '-', 'HTML.&Frames.FRAMESET', 'fs')
# HTML#LeadMenu('nmenu', '-', 'HTML.&Frames.FRAMESET', 'fs', 'i')
# HTML#LeadMenu('imenu', '-', 'HTML.&Frames.FRAME', 'fr')
# HTML#LeadMenu('vmenu', '-', 'HTML.&Frames.FRAME', 'fr')
# HTML#LeadMenu('nmenu', '-', 'HTML.&Frames.FRAME', 'fr', 'i')
# HTML#LeadMenu('imenu', '-', 'HTML.&Frames.NOFRAMES', 'nf')
# HTML#LeadMenu('vmenu', '-', 'HTML.&Frames.NOFRAMES', 'nf')
# HTML#LeadMenu('nmenu', '-', 'HTML.&Frames.NOFRAMES', 'nf', 'i')
#
# IFRAME menu item has been moved


# Headings menu:   {{{2

HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 1', 'h1')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 2', 'h2')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 3', 'h3')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 4', 'h4')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 5', 'h5')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Level 6', 'h6')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 1', 'h1')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 2', 'h2')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 3', 'h3')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 4', 'h4')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 5', 'h5')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Level 6', 'h6')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 1', 'h1', 'i')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 2', 'h2', 'i')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 3', 'h3', 'i')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 4', 'h4', 'i')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 5', 'h5', 'i')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Level 6', 'h6', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Headings.Heading Grouping', 'hg')
HTML#LeadMenu('vmenu', '-', 'HTML.&Headings.Heading Grouping', 'hg')
HTML#LeadMenu('nmenu', '-', 'HTML.&Headings.Heading Grouping', 'hg', 'i')


# Lists menu:   {{{2

HTML#LeadMenu('imenu', '-', 'HTML.&Lists.Ordered List', 'ol')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.Ordered List', 'ol')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.Ordered List', 'ol', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Lists.Unordered List', 'ul')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.Unordered List', 'ul')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.Unordered List', 'ul', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Lists.List Item', 'li')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.List Item', 'li')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.List Item', 'li', 'i')
menu HTML.Lists.-sep1- <Nop>
HTML#LeadMenu('imenu', '-', 'HTML.&Lists.Definition List', 'dl')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.Definition List', 'dl')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.Definition List', 'dl', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Lists.Definition Term', 'dt')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.Definition Term', 'dt')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.Definition Term', 'dt', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Lists.Definition Body', 'dd')
HTML#LeadMenu('vmenu', '-', 'HTML.&Lists.Definition Body', 'dd')
HTML#LeadMenu('nmenu', '-', 'HTML.&Lists.Definition Body', 'dd', 'i')


# Tables menu:   {{{2

HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Interactive Table', 'tA')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.TABLE', 'ta')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.TABLE', 'ta')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.TABLE', 'ta', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.Header Row', 'tH')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.Header Row', 'tH')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Header Row', 'tH', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.Row', 'tr')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.Row', 'tr')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Row', 'tr', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.Footer Row', 'tf')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.Footer Row', 'tf')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Footer Row', 'tf i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.Column Header', 'th')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.Column Header', 'th')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Column Header', 'th', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.Data (Column Element)', 'td')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.Data (Column Element)', 'td')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.Data (Column Element)', 'td', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&Tables.CAPTION', 'ca')
HTML#LeadMenu('vmenu', '-', 'HTML.&Tables.CAPTION', 'ca')
HTML#LeadMenu('nmenu', '-', 'HTML.&Tables.CAPTION', 'ca', 'i')


# Forms menu:   {{{2

HTML#LeadMenu('imenu', '-', 'HTML.F&orms.FORM', 'fm')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.FORM', 'fm')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.FORM', 'fm', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.FIELDSET', 'fd')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.FIELDSET', 'fd')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.FIELDSET', 'fd', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.BUTTON', 'bu')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.BUTTON', 'bu')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.BUTTON', 'bu', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.CHECKBOX', 'ch')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.CHECKBOX', 'ch')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.CHECKBOX', 'ch', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.DATALIST', 'da')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.DATALIST', 'da')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.DATALIST', 'da', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.DATE', 'cl')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.DATE', 'cl')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.DATE', 'cl', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.RADIO', 'ra')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.RADIO', 'ra')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.RADIO', 'ra', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.RANGE', 'rn')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.RANGE', 'rn')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.RANGE', 'rn', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.HIDDEN', 'hi')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.HIDDEN', 'hi')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.HIDDEN', 'hi', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.EMAIL', '@')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.EMAIL', '@')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.EMAIL', '@', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.NUMBER', 'nu')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.NUMBER', 'nu')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.NUMBER', 'nu', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.OPTION', 'op')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.OPTION', 'op')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.OPTION', 'op', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.OPTGROUP', 'og')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.OPTGROUP', 'og')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.OPTGROUP', 'og', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.PASSWORD', 'pa')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.PASSWORD', 'pa')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.PASSWORD', 'pa', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.TIME', 'nt')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.TIME', 'nt')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.TIME', 'nt', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.TEL', '#')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.TEL', '#')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.TEL', '#', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.TEXT', 'te')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.TEXT', 'te')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.TEXT', 'te', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.FILE', 'fi')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.FILE', 'fi')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.FILE', 'fi', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.SELECT', 'se')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.SELECT', 'se')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.SELECT', 'se', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.SELECT MULTIPLE', 'ms')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.SELECT MULTIPLE', 'ms')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.SELECT MULTIPLE', 'ms', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.TEXTAREA', 'tx')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.TEXTAREA', 'tx')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.TEXTAREA', 'tx', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.URL', 'ur')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.URL', 'ur')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.URL', 'ur', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.SUBMIT', 'su')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.SUBMIT', 'su', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.RESET', 're')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.RESET', 're', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.F&orms.LABEL', 'la')
HTML#LeadMenu('vmenu', '-', 'HTML.F&orms.LABEL', 'la')
HTML#LeadMenu('nmenu', '-', 'HTML.F&orms.LABEL', 'la', 'i')


# HTML 5 Tags Menu: {{{2

HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&ARTICLE', 'ar')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&ARTICLE', 'ar')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&ARTICLE', 'ar', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.AS&IDE', 'as')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.AS&IDE', 'as')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.AS&IDE', 'as', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.A&udio with controls', 'au')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.A&udio with controls', 'au')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.A&udio with controls', 'au i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&Video with controls', 'vi')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&Video with controls', 'vi')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&Video with controls', 'vi', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&CANVAS', 'cv')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&CANVAS', 'cv')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&CANVAS', 'cv', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&DETAILS with SUMMARY', 'ds')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&DETAILS with SUMMARY', 'ds')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&DETAILS with SUMMARY', 'ds', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&EMBED', 'eb')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&EMBED', 'eb')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&EMBED', 'eb', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&FIGURE', 'fg')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&FIGURE', 'fg')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&FIGURE', 'fg', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.F&igure Caption', 'fp')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.F&igure Caption', 'fp')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.F&igure Caption', 'fp', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&FOOTER', 'ft')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&FOOTER', 'ft')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&FOOTER', 'ft', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&HEADER', 'hd')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&HEADER', 'hd')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&HEADER', 'hd', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&MAIN', 'ma')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&MAIN', 'ma')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&MAIN', 'ma', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.MA&RK', 'mk')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.MA&RK', 'mk')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.MA&RK', 'mk', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.METE&R', 'mt')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.METE&R', 'mt')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.METE&R', 'mt', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&NAV', 'na')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&NAV', 'na')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&NAV', 'na', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&PROGRESS', 'pg')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&PROGRESS', 'pg')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&PROGRESS', 'pg', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&SECTION', 'sc')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&SECTION', 'sc')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&SECTION', 'sc', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&TIME', 'tm')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML &5 Tags.&TIME', 'tm')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&TIME', 'tm', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML &5 Tags.&WBR', 'wb')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML &5 Tags.&WBR', 'wb', 'i')


# SSI directives: {{{2

HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.&config timefmt', 'cf')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.&config timefmt', 'cf')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.&config timefmt', 'cf', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.config sizefmt', 'cz')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.config sizefmt', 'cz')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.config sizefmt', 'cz', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.&echo var', 'ev')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.&echo var', 'ev')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.&echo var', 'ev', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.&include virtual', 'iv')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.&include virtual', 'iv')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.&include virtual', 'iv', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.&flastmod virtual', 'fv')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.&flastmod virtual', 'fv')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.&flastmod virtual', 'fv', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.fsi&ze virtual', 'fz')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.fsi&ze virtual', 'fz')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.fsi&ze virtual', 'fz', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.e&xec cmd', 'ec')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.e&xec cmd', 'ec')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.e&xec cmd', 'ec', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.&set var', 'sv')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.&set var', 'sv')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.&set var', 'sv', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.SSI Directi&ves.if then e&lse', 'ie')
HTML#LeadMenu('vmenu', '-', 'HTML.SSI Directi&ves.if then e&lse', 'ie')
HTML#LeadMenu('nmenu', '-', 'HTML.SSI Directi&ves.if then e&lse', 'ie', 'i')

# }}}2

menu HTML.-sep6- <Nop>

HTML#LeadMenu('nmenu', '-', 'HTML.Doctype (4\.01 transitional)', '4')
HTML#LeadMenu('nmenu', '-', 'HTML.Doctype (4\.01 strict)', 's4')
HTML#LeadMenu('nmenu', '-', 'HTML.Doctype (HTML 5)', '5')
HTML#LeadMenu('imenu', '-', 'HTML.Content-Type', 'ct')
HTML#LeadMenu('nmenu', '-', 'HTML.Content-Type', 'ct', 'i')

menu HTML.-sep7- <Nop>

HTML#LeadMenu('imenu', '-', 'HTML.BODY', 'bd')
HTML#LeadMenu('vmenu', '-', 'HTML.BODY', 'bd')
HTML#LeadMenu('nmenu', '-', 'HTML.BODY', 'bd', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.BUTTON', 'bn')
HTML#LeadMenu('vmenu', '-', 'HTML.BUTTON', 'bn')
HTML#LeadMenu('nmenu', '-', 'HTML.BUTTON', 'bn', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.CENTER', 'ce')
HTML#LeadMenu('vmenu', '-', 'HTML.CENTER', 'ce')
HTML#LeadMenu('nmenu', '-', 'HTML.CENTER', 'ce', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HEAD', 'he')
HTML#LeadMenu('vmenu', '-', 'HTML.HEAD', 'he')
HTML#LeadMenu('nmenu', '-', 'HTML.HEAD', 'he', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Horizontal Rule', 'hr')
HTML#LeadMenu('nmenu', '-', 'HTML.Horizontal Rule', 'hr', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.HTML', 'ht')
HTML#LeadMenu('vmenu', '-', 'HTML.HTML', 'ht')
HTML#LeadMenu('nmenu', '-', 'HTML.HTML', 'ht', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Hyperlink', 'ah')
HTML#LeadMenu('vmenu', '-', 'HTML.Hyperlink', 'ah')
HTML#LeadMenu('nmenu', '-', 'HTML.Hyperlink', 'ah', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Inline Image', 'im')
HTML#LeadMenu('vmenu', '-', 'HTML.Inline Image', 'im')
HTML#LeadMenu('nmenu', '-', 'HTML.Inline Image', 'im', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Update Image Size Attributes', 'mi')
HTML#LeadMenu('vmenu', '-', 'HTML.Update Image Size Attributes', 'mi')
HTML#LeadMenu('nmenu', '-', 'HTML.Update Image Size Attributes', 'mi')
HTML#LeadMenu('imenu', '-', 'HTML.Line Break', 'br')
HTML#LeadMenu('nmenu', '-', 'HTML.Line Break', 'br', 'i')
# HTML#LeadMenu('imenu', '-', 'HTML.Named Anchor', 'an')
# HTML#LeadMenu('vmenu', '-', 'HTML.Named Anchor', 'an')
# HTML#LeadMenu('nmenu', '-', 'HTML.Named Anchor', 'an', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Paragraph', 'pp')
HTML#LeadMenu('vmenu', '-', 'HTML.Paragraph', 'pp')
HTML#LeadMenu('nmenu', '-', 'HTML.Paragraph', 'pp', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.Preformatted Text', 'pr')
HTML#LeadMenu('vmenu', '-', 'HTML.Preformatted Text', 'pr')
HTML#LeadMenu('nmenu', '-', 'HTML.Preformatted Text', 'pr', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.TITLE', 'ti')
HTML#LeadMenu('vmenu', '-', 'HTML.TITLE', 'ti')
HTML#LeadMenu('nmenu', '-', 'HTML.TITLE', 'ti', 'i')

HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..ADDRESS', 'ad')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..ADDRESS', 'ad')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..ADDRESS', 'ad', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..BASE HREF', 'bh')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..BASE HREF', 'bh')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..BASE HREF', 'bh', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..BASE TARGET', 'bt')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..BASE TARGET', 'bt')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..BASE TARGET', 'bt', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..BLOCKQUTE', 'bl')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..BLOCKQUTE', 'bl')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..BLOCKQUTE', 'bl', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Comment', 'cm')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Comment', 'cm')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Comment', 'cm', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Defining Instance', 'df')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Defining Instance', 'df')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Defining Instance', 'df', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Document Division', 'dv')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Document Division', 'dv')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Document Division', 'dv', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Inline Frame', 'if')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Inline Frame', 'if')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Inline Frame', 'if', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..JavaScript', 'js')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..JavaScript', 'js', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Sourced JavaScript', 'sj')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Sourced JavaScript', 'sj', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..LINK HREF', 'lk')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..LINK HREF', 'lk')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..LINK HREF', 'lk', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..META', 'me')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..META', 'me')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..META', 'me', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..META HTTP-EQUIV', 'mh')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..META HTTP-EQUIV', 'mh')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..META HTTP-EQUIV', 'mh', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..NOSCRIPT', 'nj')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..NOSCRIPT', 'nj')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..NOSCRIPT', 'nj', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Generic Embedded Object', 'ob')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Generic Embedded Object', 'ob')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Generic Embedded Object', 'ob', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Object Parameter', 'pm')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Object Parameter', 'pm')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Object Parameter', 'pm', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Quoted Text', 'qu')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Quoted Text', 'qu')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Quoted Text', 'qu', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..SPAN', 'sn')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..SPAN', 'sn')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..SPAN', 'sn', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..STYLE (Internal CSS)', 'cs')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..STYLE (Internal CSS)', 'cs')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..STYLE (Internal CSS)', 'cs', 'i')
HTML#LeadMenu('imenu', '-', 'HTML.&More\.\.\..Linked CSS', 'ls')
HTML#LeadMenu('vmenu', '-', 'HTML.&More\.\.\..Linked CSS', 'ls')
HTML#LeadMenu('nmenu', '-', 'HTML.&More\.\.\..Linked CSS', 'ls', 'i')

g:did_html_menus = true
endif
# ---------------------------------------------------------------------------

# ---- Finalize and Clean Up: ------------------------------------------- {{{1

g:doing_internal_html_mappings = false

# Try to reduce support requests from users: {{{
if ! exists('g:did_html_plugin_warning_check')
  g:did_html_plugin_warning_check = true
  var pluginfiles: list<string>
  pluginfiles = 'ftplugin/html/HTML.vim'->findfile(&runtimepath, -1)
  if pluginfiles->len() > 1
    var pluginfilesmatched: list<string>
    pluginfilesmatched = pluginfiles->HTML#FilesWithMatch('https\?://christianrobinson.name/\(programming/\)\?vim/HTML/', 20)
    if pluginfilesmatched->len() > 1
      var pluginmessage = "Multiple versions of the HTML.vim filetype plugin are installed.\n"
        .. "Locations:\n   " .. pluginfilesmatched->join("\n   ")
        .. "\nIt is necessary that you remove old versions!"
        .. "\n(Don't forget about browser_launcher.vim and MangleImageTag.vim)"
      pluginmessage->confirm('&Dismiss', 1, 'Warning')
    endif
  endif
endif
# }}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=4:comments=b\:#:commentstring=\ #\ %s:
