vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8023182
  echoerr 'HTML.vim no longer supports Vim versions prior to 8.2.3182'
  sleep 3
  finish
endif

# ---- Author & Copyright: ---------------------------------------------- {{{1
#
# Author:      Christian J. Robinson <heptite@gmail.com>
# URL:         https://christianrobinson.name/vim/HTML/
# Last Change: July 20, 2021
# Version:     1.0.12
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
# - Add more HTML 5 tags:
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

if ! exists("g:did_html_commands") || ! g:did_html_commands 
  g:did_html_commands = true

  # Define commands before any functions are loaded, or there will be errors:
  command! -nargs=+ HTMLWARN echohl WarningMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLERROR echohl ErrorMsg | echomsg <q-args> | echohl None
  command! -nargs=+ HTMLMESG echohl Todo | echo <q-args> | echohl None
  command! -nargs=+ SetIfUnset g:HTML#SetIfUnset(<f-args>)
  command! -nargs=1 HTMLmappings g:HTML#MappingsControl(<f-args>)
  command! -nargs=1 HTMLMappings g:HTML#MappingsControl(<f-args>)
  if exists(":HTML") != 2
    command! -nargs=1 HTML g:HTML#MappingsControl(<f-args>)
  endif
  command! -nargs=? ColorSelect g:HTML#ShowColors(<f-args>)
  if exists(":CS") != 2
    command! -nargs=? CS g:HTML#ShowColors(<f-args>)
  endif
  command! -nargs=+ HTMLmenu g:HTML#LeadMenu(<f-args>)
  command! -nargs=+ HTMLemenu g:HTML#EntityMenu(<f-args>)
  command! -nargs=+ HTMLcmenu g:HTML#ColorsMenu(<f-args>)
  command! HTMLReloadFunctions if exists('g:html_function_files')
    |   for f in copy(g:html_function_files)
    |     exe 'HTMLMESG Reloading: ' .. fnamemodify(f, ':t')
    |     exe 'source ' .. f
    |   endfor
    | else
    |   HTMLERROR Somehow the global variable describing the sourced function files is non-existent.
    | endif
endif

# ----------------------------------------------------------------------- }}}2

if ! exists('b:did_html_mappings_init')
  # This must be a number, not a boolean, because a -1 special case is used by
  # one of the functions:
  b:did_html_mappings_init = 1

  # User configurable variables:
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
  # END user configurable variables

  SetIfUnset g:html_color_list {}
  SetIfUnset g:html_function_files []

  # Always set this, even if it was already set:
  g:html_plugin_file = expand('<sfile>:p')

  # Need to inerpolate the value, which the command form of SetIfUnset doesn't
  # do:
  g:HTML#SetIfUnset('g:html_save_clipboard', &clipboard)

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
  if &filetype ==? "xhtml"
        || g:HTML#BoolVar('g:do_xhtml_mappings')
        || g:HTML#BoolVar('b:do_xhtml_mappings')
    b:do_xhtml_mappings = true
  else
    b:do_xhtml_mappings = false

    if g:HTML#BoolVar('g:html_tag_case_autodetect')
          && (line('$') != 1 || getline(1) != '')

      var found_upper = search('\C<\(\s*/\)\?\s*\u\+\_[^<>]*>', 'wn')
      var found_lower = search('\C<\(\s*/\)\?\s*\l\+\_[^<>]*>', 'wn')

      if found_upper != 0 && found_lower != 0
        b:html_tag_case = 'uppercase'
      elseif found_upper == 0 && found_lower > 0
        b:html_tag_case = 'lowercase'
      endif
    endif
  endif

  if g:HTML#BoolVar('b:do_xhtml_mappings')
    b:html_tag_case = 'lowercase'
  endif

  g:HTML#SetIfUnset('b:html_tag_case', g:html_tag_case)

  # Template Creation: {{{2

  var internal_html_template = " <[{HEAD}]>\n\n"
    .. "  <[{TITLE></TITLE}]>\n\n"
    .. "  <[{META HTTP-EQUIV}]=\"Content-Type\" [{CONTENT}]=\"text/html; charset=%charset%\" />\n"
    .. "  <[{META NAME}]=\"Generator\" [{CONTENT}]=\"Vim %vimversion% (Vi IMproved editor; http://www.vim.org/)\" />\n"
    .. "  <[{META NAME}]=\"Author\" [{CONTENT}]=\"%authorname%\" />\n"
    .. "  <[{META NAME}]=\"Copyright\" [{CONTENT}]=\"Copyright (C) %date% %authorname%\" />\n"
    .. "  <[{LINK REL}]=\"made\" [{HREF}]=\"mailto:%authoremail%\" />\n\n"
    .. "  <[{STYLE TYPE}]=\"text/css\">\n"
    .. "   <!--\n"
    .. "   [{BODY}] {background: %bgcolor%; color: %textcolor%;}\n"
    .. "   [{A}]:link {color: %linkcolor%;}\n"
    .. "   [{A}]:visited {color: %vlinkcolor%;}\n"
    .. "   [{A}]:hover, [{A}]:active, [{A}]:focus {color: %alinkcolor%;}\n"
    .. "   -->\n"
    .. "  </[{STYLE}]>\n\n"
    .. " </[{HEAD}]>\n"
    .. " <[{BODY}]>\n\n"
    .. "  <[{H1 STYLE}]=\"text-align: center;\"></[{H1}]>\n\n"
    .. "  <[{P}]>\n"
    .. "  </[{P}]>\n\n"
    .. "  <[{HR STYLE}]=\"width: 75%;\" />\n\n"
    .. "  <[{P}]>\n"
    .. "  Last Modified: <[{I}]>%date%</[{I}]>\n"
    .. "  </[{P}]>\n\n"
    .. "  <[{ADDRESS}]>\n"
    .. "   <[{A HREF}]=\"mailto:%authoremail%\">%authorname% &lt;%authoremail%&gt;</[{A}]>\n"
    .. "  </[{ADDRESS}]>\n"
    .. " </[{BODY}]>\n"
    .. "</[{HTML}]>"

  if g:HTML#BoolVar('b:do_xhtml_mappings')
    b:internal_html_template = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n"
          .. " \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
          .. "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
          .. internal_html_template
  else
    b:internal_html_template = "<!DOCTYPE html>\n"
          .. "<[{HTML}]>\n"
          .. internal_html_template
    b:internal_html_template = b:internal_html_template->substitute(' />', '>', 'g')
  endif

  b:internal_html_template = b:internal_html_template->g:HTML#ConvertCase()

  # }}}2

endif # ! exists('b:did_html_mappings_init')

# ----------------------------------------------------------------------------

# ---- Miscellaneous Mappings: ------------------------------------------ {{{1

g:doing_internal_html_mappings = true

if ! exists("b:did_html_mappings")
b:did_html_mappings = true

b:HTMLclearMappings = []

# Make it easy to use a ; (or whatever the map leader is) as normal:
g:HTML#Map('inoremap', '<lead>' .. g:html_map_leader, g:html_map_leader)
g:HTML#Map('vnoremap', '<lead>' .. g:html_map_leader, g:html_map_leader, -1)
g:HTML#Map('nnoremap', '<lead>' .. g:html_map_leader, g:html_map_leader)
# Make it easy to insert a & (or whatever the entity leader is):
g:HTML#Map('inoremap', '<lead>' .. g:html_map_entity_leader, g:html_map_entity_leader)

if ! g:HTML#BoolVar('g:no_html_tab_mapping')
  # Allow hard tabs to be inserted:
  g:HTML#Map('inoremap', '<lead><tab>', '<tab>')
  g:HTML#Map('nnoremap', '<lead><tab>', '<tab>')

  # Tab takes us to a (hopefully) reasonable next insert point:
  g:HTML#Map('inoremap', '<tab>', "<Cmd>eval g:HTML#NextInsertPoint('i')<CR>")
  g:HTML#Map('nnoremap', '<tab>', "<Cmd>eval g:HTML#NextInsertPoint('n')<CR>")
  g:HTML#Map('vnoremap', '<tab>', "<Cmd>eval g:HTML#NextInsertPoint('n')<CR>", -1)
else
  g:HTML#Map('inoremap', '<lead><tab>', "<Cmd>eval g:HTML#NextInsertPoint('i')<CR>")
  g:HTML#Map('nnoremap', '<lead><tab>', "<Cmd>eval g:HTML#NextInsertPoint('n')<CR>")
  g:HTML#Map('vnoremap', '<lead><tab>', "<Cmd>eval g:HTML#NextInsertPoint('n')<CR>", -1)
endif

# Update an image tag's WIDTH & HEIGHT attributes:
g:HTML#Map('nnoremap', '<lead>mi', '<Cmd>eval MangleImageTag#Mangle()<CR>')
g:HTML#Map('inoremap', '<lead>mi', '<Cmd>eval MangleImageTag#Mangle()<CR>')
g:HTML#Map('vnoremap', '<lead>mi', '<ESC>:eval MangleImageTag#Mangle()<CR>')

# Insert an HTML template:
g:HTML#Map('nnoremap', '<lead>html', '<Cmd>if g:HTML#Template() \| startinsert \| endif<CR>')

# Show a color selection buffer:
g:HTML#Map('nnoremap', '<lead>3', "<Cmd>ColorSelect<CR>")
g:HTML#Map('inoremap', '<lead>3', "<Cmd>ColorSelect<CR>")
g:HTML#Map('vnoremap', '<lead>3', "<ESC>:ColorSelect<CR>")

# ----------------------------------------------------------------------------

# ---- General Markup Tag Mappings: ------------------------------------- {{{1

#       SGML Doctype Command
if ! g:HTML#BoolVar('b:do_xhtml_mappings')
  # Transitional HTML (Looser):
  g:HTML#Map('nnoremap', '<lead>4', "<Cmd>eval append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"') \\\| eval append(1, ' \"http://www.w3.org/TR/html4/loose.dtd\">')<CR>")
  # Strict HTML:
  g:HTML#Map('nnoremap', '<lead>s4', "<Cmd>eval append(0, '<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"') \\\| eval append(1, ' \"http://www.w3.org/TR/html4/strict.dtd\">')<CR>")
else
  # Transitional XHTML (Looser):
  g:HTML#Map('nnoremap', '<lead>4', "<Cmd>eval append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"') \\\| eval append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">')<CR>")
  # Strict XHTML:
  g:HTML#Map('nnoremap', '<lead>s4', "<Cmd>eval append(0, '<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"') \\\| eval append(1, ' \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">')<CR>")
endif
g:HTML#Map("imap", '<lead>4', "<C-O>" .. g:html_map_leader .. "4")
g:HTML#Map("imap", '<lead>s4', "<C-O>" .. g:html_map_leader .. "s4")

#       HTML5 Doctype Command           HTML 5
g:HTML#Map('nnoremap', '<lead>5', "<Cmd>eval append(0, '<!DOCTYPE html>')<CR>")
g:HTML#Map("imap", '<lead>5', "<C-O>" .. g:html_map_leader .. "5")

#       Content-Type META tag
g:HTML#Map('inoremap', '<lead>ct', '<[{META HTTP-EQUIV}]="Content-Type" [{CONTENT}]="text/html; charset=<C-R>=g:HTML#DetectCharset()<CR>" />')

#       Comment Tag
g:HTML#Map('inoremap', '<lead>cm', "<C-R>=g:HTML#SmartTag('comment', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>cm', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('comment', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>cm', 0)

#       A HREF  Anchor Hyperlink        HTML 2.0
g:HTML#Map('inoremap', '<lead>ah', '<[{A HREF=""></A}]><C-O>F"')
g:HTML#Map('inoremap', '<lead>aH', '<[{A HREF="<C-R>*"></A}]><C-O>F<')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>ah', '<ESC>`>a</[{A}]><C-O>`<<[{A HREF}]=""><C-O>F"', 0)
g:HTML#Map('vnoremap', '<lead>aH', '<ESC>`>a"></[{A}]><C-O>`<<[{A HREF}]="<C-O>f<', 0)
# Motion mappings:
g:HTML#Mapo('<lead>ah', 1)
g:HTML#Mapo('<lead>aH', 1)

#       A HREF  Anchor Hyperlink, with TARGET=""
g:HTML#Map('inoremap', '<lead>at', '<[{A HREF="" TARGET=""></A}]><C-O>3F"')
g:HTML#Map('inoremap', '<lead>aT', '<[{A HREF="<C-R>*" TARGET=""></A}]><C-O>F"')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>at', '<ESC>`>a</[{A}]><C-O>`<<[{A HREF="" TARGET}]=""><C-O>3F"', 0)
g:HTML#Map('vnoremap', '<lead>aT', '<ESC>`>a" [{TARGET=""></A}]><C-O>`<<[{A HREF}]="<C-O>3f"', 0)
# Motion mappings:
g:HTML#Mapo('<lead>at', 1)
g:HTML#Mapo('<lead>aT', 1)

#       A NAME  Named Anchor            HTML 2.0
#       (note this is not HTML 5 compatible, use ID attributes instead)
# g:HTML#Map('inoremap', '<lead>an', '<[{A NAME=""></A}]><C-O>F"')
# g:HTML#Map('inoremap', '<lead>aN', '<[{A NAME="<C-R>*"></A}]><C-O>F<')
# Visual mappings:
# g:HTML#Map('vnoremap', '<lead>an', '<ESC>`>a</[{A}]><C-O>`<<[{A NAME}]=""><C-O>F"', 0)
# g:HTML#Map('vnoremap', '<lead>aN', '<ESC>`>a"></[{A}]><C-O>`<<[{A NAME}]="<C-O>f<', 0)
# Motion mappings:
# g:HTML#Mapo('<lead>an', 1)
# g:HTML#Mapo('<lead>aN', 1)

#       ABBR  Abbreviation              HTML 4.0
g:HTML#Map('inoremap', '<lead>ab', '<[{ABBR TITLE=""></ABBR}]><C-O>F"')
g:HTML#Map('inoremap', '<lead>aB', '<[{ABBR TITLE="<C-R>*"></ABBR}]><C-O>F<')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>ab', '<ESC>`>a</[{ABBR}]><C-O>`<<[{ABBR TITLE}]=""><C-O>F"', 0)
g:HTML#Map('vnoremap', '<lead>aB', '<ESC>`>a"></[{ABBR}]><C-O>`<<[{ABBR TITLE}]="<C-O>f<', 0)
# Motion mappings:
g:HTML#Mapo('<lead>ab', 1)
g:HTML#Mapo('<lead>aB', 1)

#       ACRONYM                         HTML 4.0
#       (note this is not HTML 5 compatible, use ABBR instead)
# g:HTML#Map('inoremap', '<lead>ac', '<[{ACRONYM TITLE=""></ACRONYM}]><C-O>F"')
# g:HTML#Map('inoremap', '<lead>aC', '<[{ACRONYM TITLE="<C-R>*"></ACRONYM}]><C-O>F<')
# Visual mappings:
# g:HTML#Map('vnoremap', '<lead>ac', '<ESC>`>a</[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]=""><C-O>F"', 0)
# g:HTML#Map('vnoremap', '<lead>aC', '<ESC>`>a"></[{ACRONYM}]><C-O>`<<[{ACRONYM TITLE}]="<C-O>f<', 0)
# Motion mappings:
# g:HTML#Mapo('<lead>ac', 1)
# g:HTML#Mapo('<lead>aC', 1)

#       ADDRESS                         HTML 2.0
g:HTML#Map('inoremap', '<lead>ad', '<[{ADDRESS></ADDRESS}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ad', '<ESC>`>a</[{ADDRESS}]><C-O>`<<[{ADDRESS}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>ad', 0)

#       ARTICLE Self-contained content  HTML 5
g:HTML#Map('inoremap', '<lead>ar', '<[{ARTICLE}]><CR></[{ARTICLE}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ar', '<ESC>`>a<CR></[{ARTICLE}]><C-O>`<<[{ARTICLE}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>ar', 0)

#       ASIDE   Content aside from context HTML 5
g:HTML#Map('inoremap', '<lead>as', '<[{ASIDE}]><CR></[{ASIDE}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>as', '<ESC>`>a<CR></[{ASIDE}]><C-O>`<<[{ASIDE}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>as', 0)

#       AUDIO  Audio with controls      HTML 5
g:HTML#Map('inoremap', '<lead>au', '<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR>Your browser does not support the audio tag.<CR></[{AUDIO}]><ESC>kk$3F"i')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>au', '<ESC>`>a<CR></[{AUDIO}]><C-O>`<<[{AUDIO CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR><ESC>k$3F"l', 1)
# Motion mapping:
g:HTML#Mapo('<lead>au', 0)

#       B       Boldfaced Text          HTML 2.0
g:HTML#Map('inoremap', '<lead>bo', "<C-R>=g:HTML#SmartTag('b', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bo', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('b', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>bo', 0)

#       BASE                            HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>bh', '<[{BASE HREF}]="" /><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bh', '<ESC>`>a" /><C-O>`<<[{BASE HREF}]="<ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>bh', 0)

#       BASE TARGET                     HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>bt', '<[{BASE TARGET}]="" /><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bt', '<ESC>`>a" /><C-O>`<<[{BASE TARGET}]="<ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>bt', 0)

#       BIG                             HTML 3.0
#       (<BIG> is not HTML 5 compatible, so we use CSS instead)
# g:HTML#Map('inoremap', '<lead>bi', '<[{BIG></BIG}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>bi', '<[{SPAN STYLE}]="font-size: larger;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# g:HTML#Map('vnoremap', '<lead>bi', '<ESC>`>a</[{BIG}]><C-O>`<<[{BIG}]><ESC>')
g:HTML#Map('vnoremap', '<lead>bi', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: larger;"><ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>bi', 0)

#       BLOCKQUOTE                      HTML 2.0
g:HTML#Map('inoremap', '<lead>bl', '<[{BLOCKQUOTE}]><CR></[{BLOCKQUOTE}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bl', '<ESC>`>a<CR></[{BLOCKQUOTE}]><C-O>`<<[{BLOCKQUOTE}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>bl', 0)

#       BODY                            HTML 2.0
g:HTML#Map('inoremap', '<lead>bd', '<[{BODY}]><CR></[{BODY}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bd', '<ESC>`>a<CR></[{BODY}]><C-O>`<<[{BODY}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>bd', 0)

#       BR      Line break              HTML 2.0
g:HTML#Map('inoremap', '<lead>br', '<[{BR}] />')

#       BUTTON  Generic Button
g:HTML#Map('inoremap', '<lead>bn', '<[{BUTTON TYPE}]="button"></[{BUTTON}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>bn', '<ESC>`>a</[{BUTTON}]><C-O>`<<[{BUTTON TYPE}]="button"><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>bn', 0)

#       CANVAS                          HTML 5
g:HTML#Map('inoremap', '<lead>cv', '<[{CANVAS WIDTH="" HEIGHT=""></CANVAS}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>cv', '<ESC>`>a</[{CANVAS}]><C-O>`<<[{CANVAS WIDTH="" HEIGHT=""}]><C-O>3F"', 0)
# Motion mapping:
g:HTML#Mapo('<lead>cv', 1)

#       CENTER                          NETSCAPE
#       (<CENTER> is not HTML 5 compatible, so we use CSS instead)
# g:HTML#Map('inoremap', '<lead>ce', '<[{CENTER></CENTER}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>ce', '<[{DIV STYLE}]="text-align: center;"></[{DIV}]><C-O>F<')
# Visual mapping:
# g:HTML#Map('vnoremap', '<lead>ce', '<ESC>`>a</[{CENTER}]><C-O>`<<[{CENTER}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>ce', '<ESC>`>a</[{DIV}]><C-O>`<<[{DIV STYLE}]="text-align: center;"><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>ce', 0)

#       CITE                            HTML 2.0
g:HTML#Map('inoremap', '<lead>ci', '<[{CITE></CITE}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ci', '<ESC>`>a</[{CITE}]><C-O>`<<[{CITE}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>ci', 0)

#       CODE                            HTML 2.0
g:HTML#Map('inoremap', '<lead>co', '<[{CODE></CODE}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>co', '<ESC>`>a</[{CODE}]><C-O>`<<[{CODE}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>co', 0)

#       DEFINITION LIST COMPONENTS      HTML 5
#               DL      Description List
#               DT      Description Term
#               DD      Description Body
g:HTML#Map('inoremap', '<lead>dl', '<[{DL}]><CR></[{DL}]><ESC>O')
g:HTML#Map('inoremap', '<lead>dt', '<[{DT}]></[{DT}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>dd', '<[{DD}]></[{DD}]><C-O>F<')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>dl', '<ESC>`>a<CR></[{DL}]><C-O>`<<[{DL}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>dt', '<ESC>`>a</[{DT}]><C-O>`<<[{DT}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>dd', '<ESC>`>a</[{DD}]><C-O>`<<[{DD}]><ESC>', 2)
# Motion mappings:
g:HTML#Mapo('<lead>dl', 0)
g:HTML#Mapo('<lead>dt', 0)
g:HTML#Mapo('<lead>dd', 0)

#       DEL     Deleted Text            HTML 3.0
g:HTML#Map('inoremap', '<lead>de', '<lt>[{DEL></DEL}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>de', '<ESC>`>a</[{DEL}]><C-O>`<<lt>[{DEL}]><ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>de', 0)

#       DETAILS Expandable details      HTML 5
g:HTML#Map('inoremap', '<lead>ds', '<[{DETAILS}]><CR><[{SUMMARY}]></[{SUMMARY}]><CR><[{P}]><CR></[{P}]><CR></[{DETAILS}]><ESC>3k$F<i')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ds', '<ESC>`>a<CR></[{DETAILS}]><C-O>`<<[{DETAILS}]><CR><[{SUMMARY></SUMMARY}]><CR><ESC>k$F<i', 0)
# Motion mapping:
g:HTML#Mapo('<lead>ds', 1)

#       DFN     Defining Instance       HTML 3.0
g:HTML#Map('inoremap', '<lead>df', '<[{DFN></DFN}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>df', '<ESC>`>a</[{DFN}]><C-O>`<<[{DFN}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>df', 0)

#       DIV     Document Division       HTML 3.0
g:HTML#Map('inoremap', '<lead>dv', '<[{DIV}]><CR></[{DIV}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>dv', '<ESC>`>a<CR></[{DIV}]><C-O>`<<[{DIV}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>dv', 0)

#       SPAN    Delimit Arbitrary Text  HTML 4.0
#       with CLASS attribute:
g:HTML#Map('inoremap', '<lead>sn', '<[{SPAN CLASS=""></SPAN}]><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>sn', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN CLASS}]=""><ESC>F"i', 0)
# Motion mapping:
g:HTML#Mapo('<lead>sn', 1)
#       with STYLE attribute:
g:HTML#Map('inoremap', '<lead>ss', '<[{SPAN STYLE=""></SPAN}]><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ss', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]=""><ESC>F"i', 0)
# Motion mapping:
g:HTML#Mapo('<lead>ss', 1)

#       EM      Emphasize               HTML 2.0
g:HTML#Map('inoremap', '<lead>em', "<C-R>=g:HTML#SmartTag('em', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>em', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('em', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>em', 0)

#       FONT                            NETSCAPE
#       (<FONT> is not HTML 5 compatible, so we use CSS instead)
# g:HTML#Map('inoremap', '<lead>fo', '<[{FONT SIZE=""></FONT}]><C-O>F"')
# g:HTML#Map('inoremap', '<lead>fc', '<[{FONT COLOR=""></FONT}]><C-O>F"')
g:HTML#Map('inoremap', '<lead>fo', '<[{SPAN STYLE}]="font-size: ;"></[{SPAN}]><C-O>F;')
g:HTML#Map('inoremap', '<lead>fc', '<[{SPAN STYLE}]="color: ;"></[{SPAN}]><C-O>F;')
# Visual mappings:
# g:HTML#Map('vnoremap', '<lead>fo', '<ESC>`>a</[{FONT}]><C-O>`<<[{FONT SIZE}]=""><C-O>F"', 0)
# g:HTML#Map('vnoremap', '<lead>fc', '<ESC>`>a</[{FONT}]><C-O>`<<[{FONT COLOR}]=""><C-O>F"', 0)
g:HTML#Map('vnoremap', '<lead>fo', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: ;"><C-O>F;', 0)
g:HTML#Map('vnoremap', '<lead>fc', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="color: ;"><C-O>F;', 0)
# Motion mappings:
g:HTML#Mapo('<lead>fo', 1)
g:HTML#Mapo('<lead>fc', 1)

#       FIGURE                          HTML 5
g:HTML#Map('inoremap', '<lead>fg', '<[{FIGURE><CR></FIGURE}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>fg', '<ESC>`>a<CR></[{FIGURE}]><C-O>`<<[{FIGURE}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>fg', 0)

#       Figure Caption                  HTML 5
g:HTML#Map('inoremap', '<lead>fp', '<[{FIGCAPTION></FIGCAPTION}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>fp', '<ESC>`>a</[{FIGCAPTION}]><C-O>`<<[{FIGCAPTION}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>fp', 0)

#       FOOOTER                         HTML 5
g:HTML#Map('inoremap', '<lead>ft', '<[{FOOTER><CR></FOOTER}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ft', '<ESC>`>a<CR></[{FOOTER}]><C-O>`<<[{FOOTER}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>ft', 0)

#       HEADER                          HTML 5
g:HTML#Map('inoremap', '<lead>hd', '<[{HEADER><CR></HEADER}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>hd', '<ESC>`>a<CR></[{HEADER}]><C-O>`<<[{HEADER}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>hd', 0)

#       HEADINGS, LEVELS 1-6            HTML 2.0
g:HTML#Map('inoremap', '<lead>h1', '<[{H1}]></[{H1}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>h2', '<[{H2}]></[{H2}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>h3', '<[{H3}]></[{H3}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>h4', '<[{H4}]></[{H4}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>h5', '<[{H5}]></[{H5}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>h6', '<[{H6}]></[{H6}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H1', '<[{H1 STYLE}]="text-align: center;"></[{H1}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H2', '<[{H2 STYLE}]="text-align: center;"></[{H2}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H3', '<[{H3 STYLE}]="text-align: center;"></[{H3}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H4', '<[{H4 STYLE}]="text-align: center;"></[{H4}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H5', '<[{H5 STYLE}]="text-align: center;"></[{H5}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>H6', '<[{H6 STYLE}]="text-align: center;"></[{H6}]><C-O>F<')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>h1', '<ESC>`>a</[{H1}]><C-O>`<<[{H1}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>h2', '<ESC>`>a</[{H2}]><C-O>`<<[{H2}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>h3', '<ESC>`>a</[{H3}]><C-O>`<<[{H3}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>h4', '<ESC>`>a</[{H4}]><C-O>`<<[{H4}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>h5', '<ESC>`>a</[{H5}]><C-O>`<<[{H5}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>h6', '<ESC>`>a</[{H6}]><C-O>`<<[{H6}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H1', '<ESC>`>a</[{H1}]><C-O>`<<[{H1 STYLE}]="text-align: center;"><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H2', '<ESC>`>a</[{H2}]><C-O>`<<[{H2 STYLE}]="text-align: center;"><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H3', '<ESC>`>a</[{H3}]><C-O>`<<[{H3 STYLE}]="text-align: center;"><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H4', '<ESC>`>a</[{H4}]><C-O>`<<[{H4 STYLE}]="text-align: center;"><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H5', '<ESC>`>a</[{H5}]><C-O>`<<[{H5 STYLE}]="text-align: center;"><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>H6', '<ESC>`>a</[{H6}]><C-O>`<<[{H6 STYLE}]="text-align: center;"><ESC>', 2)
# Motion mappings:
g:HTML#Mapo('<lead>h1', 0)
g:HTML#Mapo('<lead>h2', 0)
g:HTML#Mapo('<lead>h3', 0)
g:HTML#Mapo('<lead>h4', 0)
g:HTML#Mapo('<lead>h5', 0)
g:HTML#Mapo('<lead>h6', 0)
g:HTML#Mapo('<lead>H1', 0)
g:HTML#Mapo('<lead>H2', 0)
g:HTML#Mapo('<lead>H3', 0)
g:HTML#Mapo('<lead>H4', 0)
g:HTML#Mapo('<lead>H5', 0)
g:HTML#Mapo('<lead>H6', 0)

#       HGROUP  Group headings             HTML 5
g:HTML#Map('inoremap', '<lead>hg', '<[{HGROUP}]><CR></[{HGROUP}]><C-O>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>hg', '<ESC>`>a<CR></[{HGROUP}]><C-O>`<<[{HGROUP}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>hg', 0)

#       HEAD                            HTML 2.0
g:HTML#Map('inoremap', '<lead>he', '<[{HEAD}]><CR></[{HEAD}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>he', '<ESC>`>a<CR></[{HEAD}]><C-O>`<<[{HEAD}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>he', 0)

#       HR      Horizontal Rule         HTML 2.0
g:HTML#Map('inoremap', '<lead>hr', '<[{HR}] />')
g:HTML#Map('inoremap', '<lead>Hr', '<[{HR STYLE}]="width: 75%;" />')

#       HTML
if ! g:HTML#BoolVar('b:do_xhtml_mappings')
  g:HTML#Map('inoremap', '<lead>ht', '<[{HTML}]><CR></[{HTML}]><ESC>O')
  # Visual mapping:
  g:HTML#Map('vnoremap', '<lead>ht', '<ESC>`>a<CR></[{HTML}]><C-O>`<<[{HTML}]><CR><ESC>', 1)
else
  g:HTML#Map('inoremap', '<lead>ht', '<html xmlns="http://www.w3.org/1999/xhtml"><CR></html><ESC>O')
  # Visual mapping:
  g:HTML#Map('vnoremap', '<lead>ht', '<ESC>`>a<CR></html><C-O>`<<html xmlns="http://www.w3.org/1999/xhtml"><CR><ESC>', 1)
endif
# Motion mapping:
g:HTML#Mapo('<lead>ht', 0)

#       I       Italicized Text         HTML 2.0
g:HTML#Map('inoremap', '<lead>it', "<C-R>=g:HTML#SmartTag('i', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>it', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('i', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>it', 0)

#       IMG     Image                   HTML 2.0
g:HTML#Map('inoremap', '<lead>im', '<[{IMG SRC="" ALT}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>iM', '<[{IMG SRC="<C-R>*" ALT}]="" /><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>im', '<ESC>`>a" /><C-O>`<<[{IMG SRC="" ALT}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>iM', '<ESC>`>a" [{ALT}]="" /><C-O>`<<[{IMG SRC}]="<C-O>3f"', 0)
# Motion mapping:
g:HTML#Mapo('<lead>im', 1)
g:HTML#Mapo('<lead>iM', 1)

#       INS     Inserted Text           HTML 3.0
g:HTML#Map('inoremap', '<lead>in', '<lt>[{INS></INS}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>in', '<ESC>`>a</[{INS}]><C-O>`<<lt>[{INS}]><ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>in', 0)

#       KBD     Keyboard Text           HTML 2.0
g:HTML#Map('inoremap', '<lead>kb', '<[{KBD></KBD}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>kb', '<ESC>`>a</[{KBD}]><C-O>`<<[{KBD}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>kb', 0)

#       LI      List Item               HTML 2.0
g:HTML#Map('inoremap', '<lead>li', '<[{LI}]></[{LI}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>li', '<ESC>`>a</[{LI}]><C-O>`<<[{LI}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>li', 0)

#       LINK                            HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>lk', '<[{LINK HREF}]="" /><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>lk', '<ESC>`>a" /><C-O>`<<[{LINK HREF}]="<ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>lk', 0)

#       MAIN                            HTML 5
g:HTML#Map('inoremap', '<lead>ma', '<[{MAIN><CR></MAIN}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ma', '<ESC>`>a<CR></[{MAIN}]><C-O>`<<[{MAIN}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>ma', 0)

#       METER                           HTML 5
g:HTML#Map('inoremap', '<lead>mt', '<[{METER VALUE="" MIN="" MAX=""></METER}]><C-O>5F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>mt', '<ESC>`>a</[{METER}]><C-O>`<<[{METER VALUE="" MIN="" MAX}]=""><C-O>5F"', 0)
# Motion mapping:
g:HTML#Mapo('<lead>mt', 1)

#       MARK                            HTML 5
g:HTML#Map('inoremap', '<lead>mk', '<[{MARK></MARK}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>mk', '<ESC>`>a</[{MARK}]><C-O>`<<[{MARK}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>mk', 0)

#       META    Meta Information        HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>me', '<[{META NAME="" CONTENT}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>mE', '<[{META NAME="" CONTENT}]="<C-R>*" /><C-O>3F"')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>me', '<ESC>`>a" [{CONTENT}]="" /><C-O>`<<[{META NAME}]="<C-O>3f"', 0)
g:HTML#Map('vnoremap', '<lead>mE', '<ESC>`>a" /><C-O>`<<[{META NAME="" CONTENT}]="<C-O>2F"', 0)
# Motion mappings:
g:HTML#Mapo('<lead>me', 1)
g:HTML#Mapo('<lead>mE', 1)

#       META    Meta http-equiv         HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>mh', '<[{META HTTP-EQUIV="" CONTENT}]="" /><C-O>3F"')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>mh', '<ESC>`>a" /><C-O>`<<[{META HTTP-EQUIV="" CONTENT}]="<C-O>2F"', 0)
# Motion mappings:
g:HTML#Mapo('<lead>mh', 1)

#       NAV                             HTML 5
g:HTML#Map('inoremap', '<lead>na', '<[{NAV><CR></NAV}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>na', '<ESC>`>a<CR></[{NAV}]><C-O>`<<[{NAV}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>na', 1)

#       OL      Ordered List            HTML 3.0
g:HTML#Map('inoremap', '<lead>ol', '<[{OL}]><CR></[{OL}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ol', '<ESC>`>a<CR></[{OL}]><C-O>`<<[{OL}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>ol', 0)

#       P       Paragraph               HTML 3.0
g:HTML#Map('inoremap', '<lead>pp', '<[{P}]><CR></[{P}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>pp', '<ESC>`>a<CR></[{P}]><C-O>`<<[{P}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>pp', 0)
# A special mapping... If you're between <P> and </P> this will insert the
# close tag and then the open tag in insert mode:
g:HTML#Map('inoremap', '<lead>/p', '</[{P}]><CR><CR><[{P}]><CR>')

#       PRE     Preformatted Text       HTML 2.0
g:HTML#Map('inoremap', '<lead>pr', '<[{PRE}]><CR></[{PRE}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>pr', '<ESC>`>a<CR></[{PRE}]><C-O>`<<[{PRE}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>pr', 0)

#       PROGRESS                        HTML 5
g:HTML#Map('inoremap', '<lead>pg', '<[{PROGRESS VALUE="" MAX=""></PROGRESS}]><C-O>3F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>pg', '<ESC>`>a" [{MAX=""></PROGRESS}]><C-O>`<<[{PROGRESS VALUE}]="<C-O>3f"', 0)
# Motion mapping:
g:HTML#Mapo('<lead>pg', 1)

#       Q       Quote                   HTML 3.0
g:HTML#Map('inoremap', '<lead>qu', '<[{Q></Q}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>qu', '<ESC>`>a</[{Q}]><C-O>`<<[{Q}]><ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>qu', 0)

#       STRIKE  Strikethrough           HTML 3.0
#       (note this is not HTML 5 compatible, use DEL instead)
# g:HTML#Map('inoremap', '<lead>sk', '<[{STRIKE></STRIKE}]><C-O>F<')
# Visual mapping:
# g:HTML#Map('vnoremap', '<lead>sk', '<ESC>`>a</[{STRIKE}]><C-O>`<<[{STRIKE}]><ESC>', 2)
# Motion mapping:
# g:HTML#Mapo('<lead>sk', 0)

#       SAMP    Sample Text             HTML 2.0
g:HTML#Map('inoremap', '<lead>sa', '<[{SAMP></SAMP}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>sa', '<ESC>`>a</[{SAMP}]><C-O>`<<[{SAMP}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>sa', 0)

#       SECTION                         HTML 5
g:HTML#Map('inoremap', '<lead>sc', '<[{SECTION><CR></SECTION}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>sc', '<ESC>`>a<CR></[{SECTION}]><C-O>`<<[{SECTION}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>sc', 1)

#       SMALL   Small Text              HTML 3.0
#       (<SMALL> is not HTML 5 compatible, so we use CSS instead)
# g:HTML#Map('inoremap', '<lead>sm', '<[{SMALL></SMALL}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>sm', '<[{SPAN STYLE}]="font-size: smaller;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# g:HTML#Map('vnoremap', '<lead>sm', '<ESC>`>a</[{SMALL}]><C-O>`<<[{SMALL}]><ESC>')
g:HTML#Map('vnoremap', '<lead>sm', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-size: smaller;"><ESC>')
# Motion mapping:
g:HTML#Mapo('<lead>sm', 0)

#       STRONG  Bold Text               HTML 2.0
g:HTML#Map('inoremap', '<lead>st', "<C-R>=g:HTML#SmartTag('strong', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>st', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('strong', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>st', 0)

#       STYLE                           HTML 4.0        HEADER
g:HTML#Map('inoremap', '<lead>cs', '<[{STYLE TYPE}]="text/css"><CR><!--<CR>--><CR></[{STYLE}]><ESC>kO')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>cs', '<ESC>`>a<CR> --><CR></[{STYLE}]><C-O>`<<[{STYLE TYPE}]="text/css"><CR><!--<CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>cs', 0)

#       Linked CSS stylesheet
g:HTML#Map('inoremap', '<lead>ls', '<[{LINK REL}]="stylesheet" [{TYPE}]="text/css" [{HREF}]="" /><C-O>F"')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ls', '<ESC>`>a" /><C-O>`<<[{LINK REL}]="stylesheet" [{TYPE}]="text/css" [{HREF}]="<ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>ls', 0)

#       SUB     Subscript               HTML 3.0
g:HTML#Map('inoremap', '<lead>sb', '<[{SUB></SUB}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>sb', '<ESC>`>a</[{SUB}]><C-O>`<<[{SUB}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>sb', 0)

#       SUP     Superscript             HTML 3.0
g:HTML#Map('inoremap', '<lead>sp', '<[{SUP></SUP}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>sp', '<ESC>`>a</[{SUP}]><C-O>`<<[{SUP}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>sp', 0)

#       TITLE                           HTML 2.0        HEADER
g:HTML#Map('inoremap', '<lead>ti', '<[{TITLE></TITLE}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ti', '<ESC>`>a</[{TITLE}]><C-O>`<<[{TITLE}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>ti', 0)

#       TIME    Human readable date/time HTML 5
g:HTML#Map('inoremap', '<lead>tm', '<[{TIME DATETIME=""></TIME}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>tm', '<ESC>`>a</[{TIME}]><C-O>`<<[{TIME DATETIME=""}]><ESC>F"i', 0)
# Motion mapping:
g:HTML#Mapo('<lead>tm', 1)

#       TT      Teletype Text (monospaced)      HTML 2.0
#       (<TT> is not HTML 5 compatible, so we use CSS instead)
# g:HTML#Map('inoremap', '<lead>tt', '<[{TT></TT}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>tt', '<[{SPAN STYLE}]="font-family: monospace;"></[{SPAN}]><C-O>F<')
# Visual mapping:
# g:HTML#Map('vnoremap', '<lead>tt', '<ESC>`>a</[{TT}]><C-O>`<<[{TT}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>tt', '<ESC>`>a</[{SPAN}]><C-O>`<<[{SPAN STYLE}]="font-family: monospace;"><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>tt', 0)

#       U       Underlined Text         HTML 2.0
g:HTML#Map('inoremap', '<lead>un', "<C-R>=g:HTML#SmartTag('u', 'i')<CR>")
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>un', "<C-C>:execute \"normal \" .. g:HTML#SmartTag('u', 'v')<CR>", 2)
# Motion mapping:
g:HTML#Mapo('<lead>un', 0)

#       UL      Unordered List          HTML 2.0
g:HTML#Map('inoremap', '<lead>ul', '<[{UL}]><CR></[{UL}]><ESC>O')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>ul', '<ESC>`>a<CR></[{UL}]><C-O>`<<[{UL}]><CR><ESC>', 1)
# Motion mapping:
g:HTML#Mapo('<lead>ul', 0)

#       VAR     Variable                HTML 3.0
g:HTML#Map('inoremap', '<lead>va', '<[{VAR></VAR}]><C-O>F<')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>va', '<ESC>`>a</[{VAR}]><C-O>`<<[{VAR}]><ESC>', 2)
# Motion mapping:
g:HTML#Mapo('<lead>va', 0)

#       Embedded JavaScript
g:HTML#Map('inoremap', '<lead>js', '<C-O>:eval g:HTML#TC(v:false)<CR><[{SCRIPT TYPE}]="text/javascript"><CR><!--<CR>// --><CR></[{SCRIPT}]><ESC>:eval g:HTML#TC(v:true)<CR>kko')

#       Sourced JavaScript
g:HTML#Map('inoremap', '<lead>sj', '<[{SCRIPT SRC}]="" [{TYPE}]="text/javascript"></[{SCRIPT}]><C-O>3F"')

#       EMBED                           HTML 5
g:HTML#Map('inoremap', '<lead>eb', '<[{EMBED SRC="" WIDTH="" HEIGHT}]="" /><ESC>$5F"i')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>eb', '<ESC>`>a" [{WIDTH="" HEIGHT}]="" /><C-O>`<<[{EMBED SRC}]="<ESC>$3F"i', 0)
# Motion mapping:
g:HTML#Mapo('<lead>eb', 1)

#       NOSCRIPT
g:HTML#Map('inoremap', '<lead>ns', '<[{NOSCRIPT}]><CR></[{NOSCRIPT}]><C-O>O')
g:HTML#Map('vnoremap', '<lead>ns', '<ESC>`>a<CR></[{NOSCRIPT}]><C-O>`<<[{NOSCRIPT}]><CR><ESC>', 1)
g:HTML#Mapo('<lead>ns', 0)

#       OBJECT
g:HTML#Map('inoremap', '<lead>ob', '<[{OBJECT DATA="" WIDTH="" HEIGHT}]=""><CR></[{OBJECT}]><ESC>k$5F"i')
g:HTML#Map('vnoremap', '<lead>ob', '<ESC>`>a<CR></[{OBJECT}]><C-O>`<<[{OBJECT DATA="" WIDTH="" HEIGHT}]=""><CR><ESC>k$5F"', 1)
g:HTML#Mapo('<lead>ob', 0)

#       PARAM (Object Parameter)
g:HTML#Map('inoremap', '<lead>pm', '<[{PARAM NAME="" VALUE}]="" /><ESC>3F"i')
g:HTML#Map('vnoremap', '<lead>pm', '<ESC>`>a" [{VALUE}]="" /><C-O>`<<[{PARAM NAME}]="<ESC>3f"i', 0)
g:HTML#Mapo('<lead>pm', 0)

#       VIDEO  Video with controls      HTML 5
g:HTML#Map('inoremap', '<lead>vi', '<[{VIDEO WIDTH="" HEIGHT="" CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR>Your browser does not support the video tag.<CR></[{VIDEO}]><ESC>kkk$3F"i')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>vi', '<ESC>`>a<CR></[{VIDEO}]><C-O>`<<[{VIDEO WIDTH="" HEIGHT="" CONTROLS}]><CR><[{SOURCE SRC="" TYPE}]=""><CR><ESC>kk$3F"', 1)
# Motion mapping:
g:HTML#Mapo('<lead>vi', 0)

#       WBR     Possible line break     HTML 5
g:HTML#Map('inoremap', '<lead>wb', '<[{WBR}] />')


# Table stuff:
g:HTML#Map('inoremap', '<lead>ca', '<[{CAPTION></CAPTION}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>ta', '<[{TABLE}]><CR></[{TABLE}]><ESC>O')
g:HTML#Map('inoremap', '<lead>tH', '<[{THEAD}]><CR></[{THEAD}]><ESC>O')
g:HTML#Map('inoremap', '<lead>tb', '<[{TBODY}]><CR></[{TBODY}]><ESC>O')
g:HTML#Map('inoremap', '<lead>tf', '<[{TFOOT}]><CR></[{TFOOT}]><ESC>O')
g:HTML#Map('inoremap', '<lead>tr', '<[{TR}]><CR></[{TR}]><ESC>O')
g:HTML#Map('inoremap', '<lead>td', '<[{TD></TD}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>th', '<[{TH></TH}]><C-O>F<')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>ca', '<ESC>`>a<CR></[{CAPTION}]><C-O>`<<[{CAPTION}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>ta', '<ESC>`>a<CR></[{TABLE}]><C-O>`<<[{TABLE}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>tH', '<ESC>`>a<CR></[{THEAD}]><C-O>`<<[{THEAD}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>tb', '<ESC>`>a<CR></[{TBODY}]><C-O>`<<[{TBODY}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>tf', '<ESC>`>a<CR></[{TFOOT}]><C-O>`<<[{TFOOT}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>tr', '<ESC>`>a<CR></[{TR}]><C-O>`<<[{TR}]><CR><ESC>', 1)
g:HTML#Map('vnoremap', '<lead>td', '<ESC>`>a</[{TD}]><C-O>`<<[{TD}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>th', '<ESC>`>a</[{TH}]><C-O>`<<[{TH}]><ESC>', 2)
# Motion mappings:
g:HTML#Mapo('<lead>ca', 0)
g:HTML#Mapo('<lead>ta', 0)
g:HTML#Mapo('<lead>tH', 0)
g:HTML#Mapo('<lead>tb', 0)
g:HTML#Mapo('<lead>tf', 0)
g:HTML#Mapo('<lead>tr', 0)
g:HTML#Mapo('<lead>td', 0)
g:HTML#Mapo('<lead>th', 0)

# Interactively generate a table of Rows x Columns:
g:HTML#Map('nnoremap', '<lead>tA', ':eval g:HTML#GenerateTable()<CR>')

# Frames stuff:
#       (note this is not HTML 5 compatible)
# g:HTML#Map('inoremap', '<lead>fs', '<[{FRAMESET ROWS="" COLS}]=""><CR></[{FRAMESET}]><ESC>k$3F"i')
# g:HTML#Map('inoremap', '<lead>fr', '<[{FRAME SRC}]="" /><C-O>F"')
# g:HTML#Map('inoremap', '<lead>nf', '<[{NOFRAMES}]><CR></[{NOFRAMES}]><ESC>O')
# Visual mappings:
# g:HTML#Map('vnoremap', '<lead>fs', '<ESC>`>a<CR></[{FRAMESET}]><C-O>`<<[{FRAMESET ROWS="" COLS}]=""><CR><ESC>k$3F"', 1)
# g:HTML#Map('vnoremap', '<lead>fr', '<ESC>`>a" /><C-O>`<<[{FRAME SRC}]="<ESC>')
# g:HTML#Map('vnoremap', '<lead>nf', '<ESC>`>a<CR></[{NOFRAMES}]><C-O>`<<[{NOFRAMES}]><CR><ESC>', 1)
# Motion mappings:
# g:HTML#Mapo('<lead>fs', 0)
# g:HTML#Mapo('<lead>fr', 0)
# g:HTML#Mapo('<lead>nf', 0)

#       IFRAME  Inline Frame            HTML 4.0
g:HTML#Map('inoremap', '<lead>if', '<[{IFRAME SRC="" WIDTH="" HEIGHT}]=""><CR></[{IFRAME}]><ESC>k$5F"i')
# Visual mapping:
g:HTML#Map('vnoremap', '<lead>if', '<ESC>`>a<CR></[{IFRAME}]><C-O>`<<[{IFRAME SRC="" WIDTH="" HEIGHT}]=""><CR><ESC>k$5F"', 1)
# Motion mapping:
g:HTML#Mapo('<lead>if', 0)

# Forms stuff:
g:HTML#Map('inoremap', '<lead>fm', '<[{FORM ACTION}]=""><CR></[{FORM}]><ESC>k$F"i')
g:HTML#Map('inoremap', '<lead>fd', '<[{FIELDSET}]><CR><[{LEGEND></LEGEND}]><CR></[{FIELDSET}]><ESC>k$F<i')
g:HTML#Map('inoremap', '<lead>bu', '<[{INPUT TYPE="BUTTON" NAME="" VALUE}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>ch', '<[{INPUT TYPE="CHECKBOX" NAME="" VALUE}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>cl', '<[{INPUT TYPE="DATE" NAME}]="" /><C-O>F"')
g:HTML#Map('inoremap', '<lead>nt', '<[{INPUT TYPE="TIME" NAME}]="" /><C-O>F"')
g:HTML#Map('inoremap', '<lead>ra', '<[{INPUT TYPE="RADIO" NAME="" VALUE}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>rn', '<[{INPUT TYPE="RANGE" NAME="" MIN="" MAX}]="" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>hi', '<[{INPUT TYPE="HIDDEN" NAME="" VALUE}]="" /><C-O>3F"')
g:HTML#Map('inoremap', '<lead>pa', '<[{INPUT TYPE="PASSWORD" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>te', '<[{INPUT TYPE="TEXT" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>fi', '<[{INPUT TYPE="FILE" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>@', '<[{INPUT TYPE="EMAIL" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>#', '<[{INPUT TYPE="TEL" NAME="" VALUE="" SIZE}]="15" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>nu', '<[{INPUT TYPE="NUMBER" NAME="" VALUE="" STYLE}]="width: 5em;" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>ur', '<[{INPUT TYPE="URL" NAME="" VALUE="" SIZE}]="20" /><C-O>5F"')
g:HTML#Map('inoremap', '<lead>se', '<[{SELECT NAME}]=""><CR></[{SELECT}]><ESC>O')
g:HTML#Map('inoremap', '<lead>ms', '<[{SELECT NAME="" MULTIPLE}]><CR></[{SELECT}]><ESC>O')
g:HTML#Map('inoremap', '<lead>op', '<[{OPTION></OPTION}]><C-O>F<')
g:HTML#Map('inoremap', '<lead>og', '<[{OPTGROUP LABEL}]=""><CR></[{OPTGROUP}]><ESC>k$F"i')
g:HTML#Map('inoremap', '<lead>ou', '<[{OUTPUT NAME}]=""></[{OUTPUT}]><C-O>F"')
g:HTML#Map('inoremap', '<lead>tx', '<[{TEXTAREA NAME="" ROWS="10" COLS}]="50"><CR></[{TEXTAREA}]><ESC>k$5F"i')
g:HTML#Map('inoremap', '<lead>su', '<[{INPUT TYPE="SUBMIT" VALUE}]="Submit" />')
g:HTML#Map('inoremap', '<lead>re', '<[{INPUT TYPE="RESET" VALUE}]="Reset" />')
g:HTML#Map('inoremap', '<lead>la', '<[{LABEL FOR=""></LABEL}]><C-O>F"')
g:HTML#Map('inoremap', '<lead>da', '<[{INPUT LIST}]=""><CR><[{DATALIST ID}]=""><CR></[{DATALIST}]><CR></[{INPUT}]><ESC>kkk$F"i')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>fm', '<ESC>`>a<CR></[{FORM}]><C-O>`<<[{FORM ACTION}]=""><CR><ESC>k$F"', 1)
g:HTML#Map('vnoremap', '<lead>fd', '<ESC>`>a<CR></[{FIELDSET}]><C-O>`<<[{FIELDSET}]><CR><[{LEGEND></LEGEND}]><CR><ESC>k$F<i', 0)
g:HTML#Map('vnoremap', '<lead>bu', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="BUTTON" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>ch', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="CHECKBOX" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>cl', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="DATE" NAME}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>nt', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="TIME" NAME}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>ra', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="RADIO" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>rn', '<ESC>`>a" [{MIN="" MAX}]="" /><C-O>`<<[{INPUT TYPE="RANGE" NAME}]="<C-O>3f"', 0)
g:HTML#Map('vnoremap', '<lead>hi', '<ESC>`>a" /><C-O>`<<[{INPUT TYPE="HIDDEN" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>pa', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="PASSWORD" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>te', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="TEXT" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>fi', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="FILE" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>@', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="EMAIL" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>#', '<ESC>`>a" [{SIZE}]="15" /><C-O>`<<[{INPUT TYPE="TEL" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>nu', '<ESC>`>a" [{STYLE}]="width: 5em;" /><C-O>`<<[{INPUT TYPE="NUMBER" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>ur', '<ESC>`>a" [{SIZE}]="20" /><C-O>`<<[{INPUT TYPE="URL" NAME="" VALUE}]="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>se', '<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME}]=""><CR><ESC>k$F"', 1)
g:HTML#Map('vnoremap', '<lead>ms', '<ESC>`>a<CR></[{SELECT}]><C-O>`<<[{SELECT NAME="" MULTIPLE}]><CR><ESC>k$F"', 1)
g:HTML#Map('vnoremap', '<lead>op', '<ESC>`>a</[{OPTION}]><C-O>`<<[{OPTION}]><ESC>', 2)
g:HTML#Map('vnoremap', '<lead>og', '<ESC>`>a<CR></[{OPTGROUP}]><C-O>`<<[{OPTGROUP LABEL}]=""><CR><ESC>k$F"', 1)
g:HTML#Map('vnoremap', '<lead>ou', '<ESC>`>a</[{OUTPUT}]><C-O>`<<[{OUTPUT NAME}]=""><C-O>F"', 0)
g:HTML#Map('vnoremap', '<lead>oU', '<ESC>`>a"></[{OUTPUT}]><C-O>`<<[{OUTPUT NAME}]="<C-O>f<', 0)
g:HTML#Map('vnoremap', '<lead>tx', '<ESC>`>a<CR></[{TEXTAREA}]><C-O>`<<[{TEXTAREA NAME="" ROWS="10" COLS}]="50"><CR><ESC>k$5F"', 1)
g:HTML#Map('vnoremap', '<lead>la', '<ESC>`>a</[{LABEL}]><C-O>`<<[{LABEL FOR}]=""><C-O>F"', 0)
g:HTML#Map('vnoremap', '<lead>lA', '<ESC>`>a"></[{LABEL}]><C-O>`<<[{LABEL FOR}]="<C-O>f<', 0)
g:HTML#Map('vnoremap', '<lead>da', 's<[{INPUT LIST}]="<C-R>""><CR><[{DATALIST ID}]="<C-R>""><CR></[{DATALIST}]><CR></[{INPUT}]><ESC>kO', 0)
# Motion mappings:
g:HTML#Mapo('<lead>fm', 0)
g:HTML#Mapo('<lead>fd', 1)
g:HTML#Mapo('<lead>bu', 1)
g:HTML#Mapo('<lead>ch', 1)
g:HTML#Mapo('<lead>cl', 1)
g:HTML#Mapo('<lead>nt', 1)
g:HTML#Mapo('<lead>ra', 1)
g:HTML#Mapo('<lead>rn', 1)
g:HTML#Mapo('<lead>hi', 1)
g:HTML#Mapo('<lead>pa', 1)
g:HTML#Mapo('<lead>te', 1)
g:HTML#Mapo('<lead>fi', 1)
g:HTML#Mapo('<lead>@', 1)
g:HTML#Mapo('<lead>#', 1)
g:HTML#Mapo('<lead>nu', 1)
g:HTML#Mapo('<lead>ur', 1)
g:HTML#Mapo('<lead>se', 0)
g:HTML#Mapo('<lead>ms', 0)
g:HTML#Mapo('<lead>op', 0)
g:HTML#Mapo('<lead>og', 0)
g:HTML#Mapo('<lead>ou', 1)
g:HTML#Mapo('<lead>oU', 1)
g:HTML#Mapo('<lead>tx', 0)
g:HTML#Mapo('<lead>la', 1)
g:HTML#Mapo('<lead>lA', 1)
g:HTML#Mapo('<lead>da', 1)

# Server Side Include (SSI) directives:
g:HTML#Map('inoremap', '<lead>cf', '<!--#config timefmt="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>cz', '<!--#config sizefmt="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>ev', '<!--#echo var="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>iv', '<!--#include virtual="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>fv', '<!--#flastmod virtual="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>fz', '<!--#fsize virtual="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>ec', '<!--#exec cmd="" --><C-O>F"')
g:HTML#Map('inoremap', '<lead>sv', '<!--#set var="" value="" --><C-O>3F"')
g:HTML#Map('inoremap', '<lead>ie', '<!--#if expr="" --><CR><!--#else --><CR><!--#endif --><ESC>kk$F"i')
# Visual mappings:
g:HTML#Map('vnoremap', '<lead>cf', '<ESC>`>a" --><C-O>`<<!--#config timefmt="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>cz', '<ESC>`>a" --><C-O>`<<!--#config sizefmt="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>ev', '<ESC>`>a" --><C-O>`<<!--#echo var="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>iv', '<ESC>`>a" --><C-O>`<<!--#include virtual="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>fv', '<ESC>`>a" --><C-O>`<<!--#flastmod virtual="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>fz', '<ESC>`>a" --><C-O>`<<!--#fsize virtual="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>ec', '<ESC>`>a" --><C-O>`<<!--#exec cmd="<ESC>', 2)
g:HTML#Map('vnoremap', '<lead>sv', '<ESC>`>a" --><C-O>`<<!--#set var="" value="<C-O>2F"', 0)
g:HTML#Map('vnoremap', '<lead>ie', '<ESC>`>a<CR><!--#else --><CR><!--#endif --><C-O>`<<!--#if expr="" --><CR><ESC>kf"a', 0)
# Motion mappings:
g:HTML#Mapo('<lead>cf', 0)
g:HTML#Mapo('<lead>cz', 0)
g:HTML#Mapo('<lead>ev', 0)
g:HTML#Mapo('<lead>iv', 0)
g:HTML#Mapo('<lead>fv', 0)
g:HTML#Mapo('<lead>fz', 0)
g:HTML#Mapo('<lead>ec', 0)
g:HTML#Mapo('<lead>sv', 1)
g:HTML#Mapo('<lead>ie', 1)

# ----------------------------------------------------------------------------

# ---- Special Character (Character Entities) Mappings: ----------------- {{{1

# Convert the character under the cursor or the highlighted string to decimal
# HTML entities:
g:HTML#Map('vnoremap', '<lead>&', "s<C-R>=g:HTML#SI(g:HTML#EncodeString(@\"))<CR><Esc>")
g:HTML#Mapo('<lead>&', 0)

# Convert the character under the cursor or the highlighted string to hex
# HTML entities:
g:HTML#Map('vnoremap', '<lead>*', "s<C-R>=g:HTML#SI(g:HTML#EncodeString(@\", 'x'))<CR><Esc>")
g:HTML#Mapo('<lead>*', 0)

# Convert the character under the cursor or the highlighted string to a %XX
# string:
g:HTML#Map('vnoremap', '<lead>%', "s<C-R>=g:HTML#SI(g:HTML#EncodeString(@\", '%'))<CR><Esc>")
g:HTML#Mapo('<lead>%', 0)

# Decode a &#...; or %XX encoded string:
g:HTML#Map('vnoremap', '<lead>^', "s<C-R>=g:HTML#SI(g:HTML#EncodeString(@\", 'd'))<CR><Esc>")
g:HTML#Mapo('<lead>^', 0)

g:HTML#Map('inoremap', '<elead>&', '&amp;')
g:HTML#Map('inoremap', '<elead>cO', '&copy;')
g:HTML#Map('inoremap', '<elead>rO', '&reg;')
g:HTML#Map('inoremap', '<elead>tm', '&trade;')
g:HTML#Map('inoremap', "<elead>'", '&quot;')
g:HTML#Map('inoremap', "<elead>l'", '&lsquo;')
g:HTML#Map('inoremap', "<elead>r'", '&rsquo;')
g:HTML#Map('inoremap', '<elead>l"', '&ldquo;')
g:HTML#Map('inoremap', '<elead>r"', '&rdquo;')
g:HTML#Map('inoremap', '<elead><', '&lt;')
g:HTML#Map('inoremap', '<elead>>', '&gt;')
g:HTML#Map('inoremap', '<elead><space>', '&nbsp;')
g:HTML#Map('inoremap', '<lead><space>', '&nbsp;')
g:HTML#Map('inoremap', '<elead>#', '&pound;')
g:HTML#Map('inoremap', '<elead>E=', '&euro;')
g:HTML#Map('inoremap', '<elead>Y=', '&yen;')
g:HTML#Map('inoremap', '<elead>c\|', '&cent;')
g:HTML#Map('inoremap', '<elead>A`', '&Agrave;')
g:HTML#Map('inoremap', "<elead>A'", '&Aacute;')
g:HTML#Map('inoremap', '<elead>A^', '&Acirc;')
g:HTML#Map('inoremap', '<elead>A~', '&Atilde;')
g:HTML#Map('inoremap', '<elead>A"', '&Auml;')
g:HTML#Map('inoremap', '<elead>Ao', '&Aring;')
g:HTML#Map('inoremap', '<elead>AE', '&AElig;')
g:HTML#Map('inoremap', '<elead>C,', '&Ccedil;')
g:HTML#Map('inoremap', '<elead>E`', '&Egrave;')
g:HTML#Map('inoremap', "<elead>E'", '&Eacute;')
g:HTML#Map('inoremap', '<elead>E^', '&Ecirc;')
g:HTML#Map('inoremap', '<elead>E"', '&Euml;')
g:HTML#Map('inoremap', '<elead>I`', '&Igrave;')
g:HTML#Map('inoremap', "<elead>I'", '&Iacute;')
g:HTML#Map('inoremap', '<elead>I^', '&Icirc;')
g:HTML#Map('inoremap', '<elead>I"', '&Iuml;')
g:HTML#Map('inoremap', '<elead>N~', '&Ntilde;')
g:HTML#Map('inoremap', '<elead>O`', '&Ograve;')
g:HTML#Map('inoremap', "<elead>O'", '&Oacute;')
g:HTML#Map('inoremap', '<elead>O^', '&Ocirc;')
g:HTML#Map('inoremap', '<elead>O~', '&Otilde;')
g:HTML#Map('inoremap', '<elead>O"', '&Ouml;')
g:HTML#Map('inoremap', '<elead>O/', '&Oslash;')
g:HTML#Map('inoremap', '<elead>U`', '&Ugrave;')
g:HTML#Map('inoremap', "<elead>U'", '&Uacute;')
g:HTML#Map('inoremap', '<elead>U^', '&Ucirc;')
g:HTML#Map('inoremap', '<elead>U"', '&Uuml;')
g:HTML#Map('inoremap', "<elead>Y'", '&Yacute;')
g:HTML#Map('inoremap', '<elead>a`', '&agrave;')
g:HTML#Map('inoremap', "<elead>a'", '&aacute;')
g:HTML#Map('inoremap', '<elead>a^', '&acirc;')
g:HTML#Map('inoremap', '<elead>a~', '&atilde;')
g:HTML#Map('inoremap', '<elead>a"', '&auml;')
g:HTML#Map('inoremap', '<elead>ao', '&aring;')
g:HTML#Map('inoremap', '<elead>ae', '&aelig;')
g:HTML#Map('inoremap', '<elead>c,', '&ccedil;')
g:HTML#Map('inoremap', '<elead>e`', '&egrave;')
g:HTML#Map('inoremap', "<elead>e'", '&eacute;')
g:HTML#Map('inoremap', '<elead>e^', '&ecirc;')
g:HTML#Map('inoremap', '<elead>e"', '&euml;')
g:HTML#Map('inoremap', '<elead>i`', '&igrave;')
g:HTML#Map('inoremap', "<elead>i'", '&iacute;')
g:HTML#Map('inoremap', '<elead>i^', '&icirc;')
g:HTML#Map('inoremap', '<elead>i"', '&iuml;')
g:HTML#Map('inoremap', '<elead>n~', '&ntilde;')
g:HTML#Map('inoremap', '<elead>o`', '&ograve;')
g:HTML#Map('inoremap', "<elead>o'", '&oacute;')
g:HTML#Map('inoremap', '<elead>o^', '&ocirc;')
g:HTML#Map('inoremap', '<elead>o~', '&otilde;')
g:HTML#Map('inoremap', '<elead>o"', '&ouml;')
g:HTML#Map('inoremap', '<elead>u`', '&ugrave;')
g:HTML#Map('inoremap', "<elead>u'", '&uacute;')
g:HTML#Map('inoremap', '<elead>u^', '&ucirc;')
g:HTML#Map('inoremap', '<elead>u"', '&uuml;')
g:HTML#Map('inoremap', "<elead>y'", '&yacute;')
g:HTML#Map('inoremap', '<elead>y"', '&yuml;')
g:HTML#Map('inoremap', '<elead>2<', '&laquo;')
g:HTML#Map('inoremap', '<elead>2>', '&raquo;')
g:HTML#Map('inoremap', '<elead>"', '&uml;')
g:HTML#Map('inoremap', '<elead>o/', '&oslash;')
g:HTML#Map('inoremap', '<elead>sz', '&szlig;')
g:HTML#Map('inoremap', '<elead>!', '&iexcl;')
g:HTML#Map('inoremap', '<elead>?', '&iquest;')
g:HTML#Map('inoremap', '<elead>dg', '&deg;')
g:HTML#Map('inoremap', '<elead>0^', '&#x2070;')
g:HTML#Map('inoremap', '<elead>1^', '&sup1;')
g:HTML#Map('inoremap', '<elead>2^', '&sup2;')
g:HTML#Map('inoremap', '<elead>3^', '&sup3;')
g:HTML#Map('inoremap', '<elead>4^', '&#x2074;')
g:HTML#Map('inoremap', '<elead>5^', '&#x2075;')
g:HTML#Map('inoremap', '<elead>6^', '&#x2076;')
g:HTML#Map('inoremap', '<elead>7^', '&#x2077;')
g:HTML#Map('inoremap', '<elead>8^', '&#x2078;')
g:HTML#Map('inoremap', '<elead>9^', '&#x2079;')
g:HTML#Map('inoremap', '<elead>0v', '&#x2080;')
g:HTML#Map('inoremap', '<elead>1v', '&#x2081;')
g:HTML#Map('inoremap', '<elead>2v', '&#x2082;')
g:HTML#Map('inoremap', '<elead>3v', '&#x2083;')
g:HTML#Map('inoremap', '<elead>4v', '&#x2084;')
g:HTML#Map('inoremap', '<elead>5v', '&#x2085;')
g:HTML#Map('inoremap', '<elead>6v', '&#x2086;')
g:HTML#Map('inoremap', '<elead>7v', '&#x2087;')
g:HTML#Map('inoremap', '<elead>8v', '&#x2088;')
g:HTML#Map('inoremap', '<elead>9v', '&#x2089;')
g:HTML#Map('inoremap', '<elead>mi', '&micro;')
g:HTML#Map('inoremap', '<elead>pa', '&para;')
g:HTML#Map('inoremap', '<elead>se', '&sect;')
g:HTML#Map('inoremap', '<elead>.', '&middot;')
g:HTML#Map('inoremap', '<elead>*', '&bull;')
g:HTML#Map('inoremap', '<elead>x', '&times;')
g:HTML#Map('inoremap', '<elead>/', '&divide;')
g:HTML#Map('inoremap', '<elead>+-', '&plusmn;')
g:HTML#Map('inoremap', '<elead>n-', '&ndash;')  # Math symbol
g:HTML#Map('inoremap', '<elead>2-', '&ndash;')  # ...
g:HTML#Map('inoremap', '<elead>m-', '&mdash;')  # Sentence break
g:HTML#Map('inoremap', '<elead>3-', '&mdash;')  # ...
g:HTML#Map('inoremap', '<elead>--', '&mdash;')  # ...
g:HTML#Map('inoremap', '<elead>3.', '&hellip;')
# Fractions:
g:HTML#Map('inoremap', '<elead>14', '&frac14;')
g:HTML#Map('inoremap', '<elead>12', '&frac12;')
g:HTML#Map('inoremap', '<elead>34', '&frac34;')
g:HTML#Map('inoremap', '<elead>13', '&frac13;')
g:HTML#Map('inoremap', '<elead>23', '&frac23;')
g:HTML#Map('inoremap', '<elead>15', '&frac15;')
g:HTML#Map('inoremap', '<elead>25', '&frac25;')
g:HTML#Map('inoremap', '<elead>35', '&frac35;')
g:HTML#Map('inoremap', '<elead>45', '&frac45;')
g:HTML#Map('inoremap', '<elead>16', '&frac16;')
g:HTML#Map('inoremap', '<elead>56', '&frac56;')
g:HTML#Map('inoremap', '<elead>18', '&frac18;')
g:HTML#Map('inoremap', '<elead>38', '&frac38;')
g:HTML#Map('inoremap', '<elead>58', '&frac58;')
g:HTML#Map('inoremap', '<elead>78', '&frac78;')
# Greek letters:
#   ... Capital:
g:HTML#Map('inoremap', '<elead>Al', '&Alpha;')
g:HTML#Map('inoremap', '<elead>Be', '&Beta;')
g:HTML#Map('inoremap', '<elead>Ga', '&Gamma;')
g:HTML#Map('inoremap', '<elead>De', '&Delta;')
g:HTML#Map('inoremap', '<elead>Ep', '&Epsilon;')
g:HTML#Map('inoremap', '<elead>Ze', '&Zeta;')
g:HTML#Map('inoremap', '<elead>Et', '&Eta;')
g:HTML#Map('inoremap', '<elead>Th', '&Theta;')
g:HTML#Map('inoremap', '<elead>Io', '&Iota;')
g:HTML#Map('inoremap', '<elead>Ka', '&Kappa;')
g:HTML#Map('inoremap', '<elead>Lm', '&Lambda;')
g:HTML#Map('inoremap', '<elead>Mu', '&Mu;')
g:HTML#Map('inoremap', '<elead>Nu', '&Nu;')
g:HTML#Map('inoremap', '<elead>Xi', '&Xi;')
g:HTML#Map('inoremap', '<elead>Oc', '&Omicron;')
g:HTML#Map('inoremap', '<elead>Pi', '&Pi;')
g:HTML#Map('inoremap', '<elead>Rh', '&Rho;')
g:HTML#Map('inoremap', '<elead>Si', '&Sigma;')
g:HTML#Map('inoremap', '<elead>Ta', '&Tau;')
g:HTML#Map('inoremap', '<elead>Up', '&Upsilon;')
g:HTML#Map('inoremap', '<elead>Ph', '&Phi;')
g:HTML#Map('inoremap', '<elead>Ch', '&Chi;')
g:HTML#Map('inoremap', '<elead>Ps', '&Psi;')
#   ... Lowercase/small:
g:HTML#Map('inoremap', '<elead>al', '&alpha;')
g:HTML#Map('inoremap', '<elead>be', '&beta;')
g:HTML#Map('inoremap', '<elead>ga', '&gamma;')
g:HTML#Map('inoremap', '<elead>de', '&delta;')
g:HTML#Map('inoremap', '<elead>ep', '&epsilon;')
g:HTML#Map('inoremap', '<elead>ze', '&zeta;')
g:HTML#Map('inoremap', '<elead>et', '&eta;')
g:HTML#Map('inoremap', '<elead>th', '&theta;')
g:HTML#Map('inoremap', '<elead>io', '&iota;')
g:HTML#Map('inoremap', '<elead>ka', '&kappa;')
g:HTML#Map('inoremap', '<elead>lm', '&lambda;')
g:HTML#Map('inoremap', '<elead>mu', '&mu;')
g:HTML#Map('inoremap', '<elead>nu', '&nu;')
g:HTML#Map('inoremap', '<elead>xi', '&xi;')
g:HTML#Map('inoremap', '<elead>oc', '&omicron;')
g:HTML#Map('inoremap', '<elead>pi', '&pi;')
g:HTML#Map('inoremap', '<elead>rh', '&rho;')
g:HTML#Map('inoremap', '<elead>si', '&sigma;')
g:HTML#Map('inoremap', '<elead>sf', '&sigmaf;')
g:HTML#Map('inoremap', '<elead>ta', '&tau;')
g:HTML#Map('inoremap', '<elead>up', '&upsilon;')
g:HTML#Map('inoremap', '<elead>ph', '&phi;')
g:HTML#Map('inoremap', '<elead>ch', '&chi;')
g:HTML#Map('inoremap', '<elead>ps', '&psi;')
g:HTML#Map('inoremap', '<elead>og', '&omega;')
g:HTML#Map('inoremap', '<elead>ts', '&thetasym;')
g:HTML#Map('inoremap', '<elead>uh', '&upsih;')
g:HTML#Map('inoremap', '<elead>pv', '&piv;')
# single-line arrows:
g:HTML#Map('inoremap', '<elead>la', '&larr;')
g:HTML#Map('inoremap', '<elead>ua', '&uarr;')
g:HTML#Map('inoremap', '<elead>ra', '&rarr;')
g:HTML#Map('inoremap', '<elead>da', '&darr;')
g:HTML#Map('inoremap', '<elead>ha', '&harr;')
# g:HTML#Map('inoremap', '<elead>ca', '&crarr;')
# double-line arrows:
g:HTML#Map('inoremap', '<elead>lA', '&lArr;')
g:HTML#Map('inoremap', '<elead>uA', '&uArr;')
g:HTML#Map('inoremap', '<elead>rA', '&rArr;')
g:HTML#Map('inoremap', '<elead>dA', '&dArr;')
g:HTML#Map('inoremap', '<elead>hA', '&hArr;')
# Roman numerals, upppercase:
g:HTML#Map('inoremap', '<elead>R1',    '&#x2160;')
g:HTML#Map('inoremap', '<elead>R2',    '&#x2161;')
g:HTML#Map('inoremap', '<elead>R3',    '&#x2162;')
g:HTML#Map('inoremap', '<elead>R4',    '&#x2163;')
g:HTML#Map('inoremap', '<elead>R5',    '&#x2164;')
g:HTML#Map('inoremap', '<elead>R6',    '&#x2165;')
g:HTML#Map('inoremap', '<elead>R7',    '&#x2166;')
g:HTML#Map('inoremap', '<elead>R8',    '&#x2167;')
g:HTML#Map('inoremap', '<elead>R9',    '&#x2168;')
g:HTML#Map('inoremap', '<elead>R10',   '&#x2169;')
g:HTML#Map('inoremap', '<elead>R11',   '&#x216a;')
g:HTML#Map('inoremap', '<elead>R12',   '&#x216b;')
g:HTML#Map('inoremap', '<elead>R50',   '&#x216c;')
g:HTML#Map('inoremap', '<elead>R100',  '&#x216d;')
g:HTML#Map('inoremap', '<elead>R500',  '&#x216e;')
g:HTML#Map('inoremap', '<elead>R1000', '&#x216f;')
# Roman numerals, lowercase:
g:HTML#Map('inoremap', '<elead>r1',    '&#x2170;')
g:HTML#Map('inoremap', '<elead>r2',    '&#x2171;')
g:HTML#Map('inoremap', '<elead>r3',    '&#x2172;')
g:HTML#Map('inoremap', '<elead>r4',    '&#x2173;')
g:HTML#Map('inoremap', '<elead>r5',    '&#x2174;')
g:HTML#Map('inoremap', '<elead>r6',    '&#x2175;')
g:HTML#Map('inoremap', '<elead>r7',    '&#x2176;')
g:HTML#Map('inoremap', '<elead>r8',    '&#x2177;')
g:HTML#Map('inoremap', '<elead>r9',    '&#x2178;')
g:HTML#Map('inoremap', '<elead>r10',   '&#x2179;')
g:HTML#Map('inoremap', '<elead>r11',   '&#x217a;')
g:HTML#Map('inoremap', '<elead>r12',   '&#x217b;')
g:HTML#Map('inoremap', '<elead>r50',   '&#x217c;')
g:HTML#Map('inoremap', '<elead>r100',  '&#x217d;')
g:HTML#Map('inoremap', '<elead>r500',  '&#x217e;')
g:HTML#Map('inoremap', '<elead>r1000', '&#x217f;')

# ----------------------------------------------------------------------------

# ---- Browser Remote Controls: ----------------------------------------- {{{1

if has('mac') || has('macunix') # {{{2

  # try/catch because the function file may not autoload if it's not
  # installed:
  var openinmacappexists: bool
  try
    openinmacappexists = BrowserLauncher#OpenInMacApp('test')
  catch /^Vim\%((\a\+)\)\=:E117:.\+BrowserLauncher#OpenInMacApp/
    # Do nothing, just discard the error
  endtry

  if openinmacappexists
    # Run the default Mac browser:
    g:HTML#Map(
      'nnoremap',
      '<lead>db',
      ":eval BrowserLauncher#OpenInMacApp('default')<CR>"
    )

    # Firefox: View current file, starting Firefox if it's not running:
    g:HTML#Map(
      'nnoremap',
      '<lead>ff',
      ":eval BrowserLauncher#OpenInMacApp('firefox', 0)<CR>"
    )
    # Firefox: Open a new window, and view the current file:
    g:HTML#Map(
      'nnoremap',
      '<lead>nff',
      ":eval BrowserLauncher#OpenInMacApp('firefox', 1)<CR>"
    )
    # Firefox: Open a new tab, and view the current file:
    g:HTML#Map(
      'nnoremap',
      '<lead>tff',
      ":eval BrowserLauncher#OpenInMacApp('firefox', 2)<CR>"
    )

    # Opera: View current file, starting Opera if it's not running:
    g:HTML#Map(
      'nnoremap',
      '<lead>oa',
      ":eval BrowserLauncher#OpenInMacApp('opera', 0)<CR>"
    )
    # Opera: View current file in a new window, starting Opera if it's not running:
    g:HTML#Map(
      'nnoremap',
      '<lead>noa',
      ":eval BrowserLauncher#OpenInMacApp('opera', 1)<CR>"
    )
    # Opera: Open a new tab, and view the current file:
    g:HTML#Map(
      'nnoremap',
      '<lead>toa',
      ":eval BrowserLauncher#OpenInMacApp('opera', 2)<CR>"
    )

    # Safari: View current file, starting Safari if it's not running:
    g:HTML#Map(
      'nnoremap',
      '<lead>sf',
      ":eval BrowserLauncher#OpenInMacApp('safari', 0)<CR>"
    )
    # Safari: Open a new window, and view the current file:
    g:HTML#Map(
      'nnoremap',
      '<lead>nsf',
      ":eval BrowserLauncher#OpenInMacApp('safari', 1)<CR>"
      )
    # Safari: Open a new tab, and view the current file:
    g:HTML#Map(
      'nnoremap',
      '<lead>tsf',
      ":eval BrowserLauncher#OpenInMacApp('safari', 2)<CR>"
    )
  endif

else # {{{2

  # try/catch because the function file may not autoload if it's not
  # installed:
  var browserlauncherexists: bool
  try
    browserlauncherexists = BrowserLauncher#Exists() != []
  catch /^Vim\%((\a\+)\)\=:E117:.\+BrowserLauncher#Exists/
    # Do nothing, just discard the error
  endtry

  if browserlauncherexists
    if BrowserLauncher#Exists('default')
      # Run the default browser:
      g:HTML#Map(
        'nnoremap',
        '<lead>db',
        ":eval BrowserLauncher#Launch('default')<CR>"
      )
    endif
    if BrowserLauncher#Exists('firefox')
      # Firefox: View current file, starting Firefox if it's not running:
      g:HTML#Map(
        'nnoremap',
        '<lead>ff',
        ":eval BrowserLauncher#Launch('firefox', 0)<CR>"
      )
      # Firefox: Open a new window, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>nff',
        ":eval BrowserLauncher#Launch('firefox', 1)<CR>"
      )
      # Firefox: Open a new tab, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>tff',
        ":eval BrowserLauncher#Launch('firefox', 2)<CR>"
      )
    endif
    if BrowserLauncher#Exists('chrome')
      # Chrome: View current file, starting Chrome if it's not running:
      g:HTML#Map(
        'nnoremap',
        '<lead>gc',
        ":eval BrowserLauncher#Launch('chrome', 0)<CR>"
      )
      # Chrome: Open a new window, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>ngc',
        ":eval BrowserLauncher#Launch('chrome', 1)<CR>"
      )
      # Chrome: Open a new tab, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>tgc',
        ":eval BrowserLauncher#Launch('chrome', 2)<CR>"
      )
    endif
    if BrowserLauncher#Exists('edge')
      # Edge: View current file, starting Microsoft Edge if it's not running:
      g:HTML#Map(
        'nnoremap',
        '<lead>ed',
        ":eval BrowserLauncher#Launch('edge', 0)<CR>"
      )
      # Edge: Open a new window, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>ned',
        ":eval BrowserLauncher#Launch('edge', 1)<CR>"
      )
      # Edge: Open a new tab, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>ted',
        ":eval BrowserLauncher#Launch('edge', 2)<CR>"
      )
    endif
    if BrowserLauncher#Exists('opera')
      # Opera: View current file, starting Opera if it's not running:
      g:HTML#Map(
        'nnoremap',
        '<lead>oa',
        ":eval BrowserLauncher#Launch('opera', 0)<CR>"
      )
      # Opera: View current file in a new window, starting Opera if it's not running:
      g:HTML#Map(
        'nnoremap',
        '<lead>noa',
        ":eval BrowserLauncher#Launch('opera', 1)<CR>"
      )
      # Opera: Open a new tab, and view the current file:
      g:HTML#Map(
        'nnoremap',
        '<lead>toa',
        ":eval BrowserLauncher#Launch('opera', 2)<CR>"
      )
    endif
    if BrowserLauncher#Exists('lynx')
      # Lynx:  (This may happen anyway if there's no GUI available.)
      g:HTML#Map(
        'nnoremap',
        '<lead>ly',
        ":eval BrowserLauncher#Launch('lynx', 0)<CR>"
      )
      # Lynx in an xterm:  (This always happens in the Vim GUI.)
      g:HTML#Map(
        'nnoremap',
        '<lead>nly',
        ":eval BrowserLauncher#Launch('lynx', 1)<CR>"
      )
      # Lynx in a new Vim window, using :terminal:
      g:HTML#Map(
        'nnoremap',
        '<lead>tly',
        ":eval BrowserLauncher#Launch('lynx', 2)<CR>"
      )
    endif
    if BrowserLauncher#Exists('w3m')
      # w3m:  (This may happen anyway if there's no GUI available.)
      g:HTML#Map(
        'nnoremap',
        '<lead>w3',
        ":eval BrowserLauncher#Launch('w3m', 0)<CR>"
      )
      # w3m in an xterm:  (This always happens in the Vim GUI.)
      g:HTML#Map(
        'nnoremap',
        '<lead>nw3',
        ":eval BrowserLauncher#Launch('w3m', 1)<CR>"
      )
      # w3m in a new Vim window, using :terminal:
      g:HTML#Map(
        'nnoremap',
        '<lead>tw3',
        ":eval BrowserLauncher#Launch('w3m', 2)<CR>"
      )
    endif
  endif

endif # }}}2

# ----------------------------------------------------------------------------

endif # ! exists("b:did_html_mappings")

# ---- ToolBar Buttons: ------------------------------------------------- {{{1
if ! has("gui_running") && ! g:HTML#BoolVar('g:force_html_menu')
  augroup HTMLplugin
  au!
  execute 'autocmd GUIEnter * ++once source ' .. g:html_plugin_file
  augroup END
elseif exists("g:did_html_menus")
  g:HTML#MenuControl()
elseif ! g:HTML#BoolVar('g:no_html_menu')

# Solve a race condition:
if ! exists('g:did_install_default_menus')
  source $VIMRUNTIME/menu.vim
endif

if ! g:HTML#BoolVar('g:no_html_toolbar') && has('toolbar')

  if ((has("win32") || has('win64'))
    && findfile('bitmaps/Browser.bmp', &rtp) == '')
      || findfile('bitmaps/Browser.xpm', &rtp) == ''
    var tmp = "Warning:\nYou need to install the Toolbar Bitmaps for the "
          .. g:html_plugin_file->fnamemodify(':t') .. " plugin. "
          .. "See: http://christianrobinson.name/vim/HTML/#files\n"
          .. 'Or see ":help g:no_html_toolbar".'
    var tmpret: number
    if has('win32') || has('win64') || has('unix')
      tmpret = tmp->confirm("&Dismiss\nView &Help\nGet &Bitmaps", 1, 'Warning')
    else
      tmpret = tmp->confirm("&Dismiss\nView &Help", 1, 'Warning')
    endif

    if tmpret == 2
      help g:no_html_toolbar
      # Go to the previous window or everything gets messy:
      wincmd p
    elseif tmpret == 3
      BrowserLauncher#Launch('default', 0, 'http://christianrobinson.name/vim/HTML/\#files')
    endif

  endif

  set guioptions+=T

  silent! unmenu ToolBar
  silent! unmenu! ToolBar

  amenu 1.10      ToolBar.Open      :browse confirm e<CR>
  tmenu           ToolBar.Open      Open file
  amenu 1.20      ToolBar.Save      :if expand("%") == ""<Bar>browse confirm w<Bar>else<Bar>confirm w<Bar>endif<CR>
  tmenu           ToolBar.Save      Save current file
  amenu 1.30      ToolBar.SaveAll   :browse confirm wa<CR>
  tmenu           ToolBar.SaveAll   Save all files

   menu 1.50      ToolBar.-sep1-    <nul>

  HTMLmenu amenu  1.60  ToolBar.Template   html
  tmenu                 ToolBar.Template   Insert Template

   menu           1.65  ToolBar.-sep2-     <nul>

  HTMLmenu imenu  1.70  ToolBar.Paragraph  pp
  HTMLmenu vmenu  1.70  ToolBar.Paragraph  pp
  HTMLmenu nmenu  1.70  ToolBar.Paragraph  pp i
  tmenu                 ToolBar.Paragraph  Create Paragraph
  HTMLmenu imenu  1.80  ToolBar.Break      br
  HTMLmenu vmenu  1.80  ToolBar.Break      br
  HTMLmenu nmenu  1.80  ToolBar.Break      br i
  tmenu                 ToolBar.Break      Line Break

   menu           1.85  ToolBar.-sep3-     <nul>

  HTMLmenu imenu  1.90  ToolBar.Link       ah
  HTMLmenu vmenu  1.90  ToolBar.Link       ah
  HTMLmenu nmenu  1.90  ToolBar.Link       ah i
  tmenu                 ToolBar.Link       Create Hyperlink
  HTMLmenu imenu  1.110 ToolBar.Image      im
  HTMLmenu vmenu  1.110 ToolBar.Image      im
  HTMLmenu nmenu  1.110 ToolBar.Image      im i
  tmenu                 ToolBar.Image      Insert Image

   menu           1.115 ToolBar.-sep4-     <nul>

  HTMLmenu imenu  1.120 ToolBar.Hline      hr
  HTMLmenu nmenu  1.120 ToolBar.Hline      hr i
  tmenu                 ToolBar.Hline      Create Horizontal Rule

   menu           1.125 ToolBar.-sep5-     <nul>

  HTMLmenu imenu  1.130 ToolBar.Table     tA <ESC>
  HTMLmenu nmenu  1.130 ToolBar.Table     tA
  tmenu                 ToolBar.Table      Create Table

   menu           1.135 ToolBar.-sep6-     <nul>

  exe 'imenu      1.140 ToolBar.Blist'     g:html_map_leader .. 'ul' .. g:html_map_leader .. 'li'
  exe 'vmenu      1.140 ToolBar.Blist'     g:html_map_leader .. 'uli' .. g:html_map_leader .. 'li<ESC>'
  exe 'nmenu      1.140 ToolBar.Blist'     'i' .. g:html_map_leader .. 'ul' .. g:html_map_leader .. 'li'
  tmenu                 ToolBar.Blist      Create Bullet List
  exe 'imenu      1.150 ToolBar.Nlist'     g:html_map_leader .. 'ol' .. g:html_map_leader .. 'li'
  exe 'vmenu      1.150 ToolBar.Nlist'     g:html_map_leader .. 'oli' .. g:html_map_leader .. 'li<ESC>'
  exe 'nmenu      1.150 ToolBar.Nlist'     'i' .. g:html_map_leader .. 'ol' .. g:html_map_leader .. 'li'
  tmenu                 ToolBar.Nlist      Create Numbered List
  HTMLmenu imenu  1.160 ToolBar.Litem      li
  HTMLmenu nmenu  1.160 ToolBar.Litem      li i
  tmenu                 ToolBar.Litem      Add List Item

   menu           1.165 ToolBar.-sep7-     <nul>

  HTMLmenu imenu  1.170 ToolBar.Bold       bo
  HTMLmenu vmenu  1.170 ToolBar.Bold       bo
  HTMLmenu nmenu  1.170 ToolBar.Bold       bo i
  tmenu                 ToolBar.Bold       Bold
  HTMLmenu imenu  1.180 ToolBar.Italic     it
  HTMLmenu vmenu  1.180 ToolBar.Italic     it
  HTMLmenu nmenu  1.180 ToolBar.Italic     it i
  tmenu                 ToolBar.Italic     Italic
  HTMLmenu imenu  1.190 ToolBar.Underline  un
  HTMLmenu vmenu  1.190 ToolBar.Underline  un
  HTMLmenu nmenu  1.190 ToolBar.Underline  un i
  tmenu                 ToolBar.Underline  Underline


   menu	          1.195 ToolBar.-sep8-     <Nop>

  anoremenu       1.200 ToolBar.Undo       u
  tmenu                 ToolBar.Undo       Undo
  anoremenu       1.210 ToolBar.Redo       <C-R>
  tmenu                 ToolBar.Redo       Redo


   menu           1.215 ToolBar.-sep9-    <nul>

  vmenu           1.210 ToolBar.Cut       "+x
  tmenu                 ToolBar.Cut       Cut to clipboard
  vmenu           1.220 ToolBar.Copy      "+y
  tmenu                 ToolBar.Copy      Copy to clipboard
  nmenu           1.230 ToolBar.Paste     "+gP
  cmenu           1.230 ToolBar.Paste     <C-R>+
  imenu           1.230 ToolBar.Paste     <C-R>+
  vmenu           1.230 ToolBar.Paste     "-xi<C-R>+<Esc>
  tmenu                 ToolBar.Paste     Paste from Clipboard

   menu           1.235 ToolBar.-sep10-    <nul>


  if !has("gui_athena")
    amenu 1.260 ToolBar.Find    :promptfind<CR>
    vunmenu     ToolBar.Find
    vmenu       ToolBar.Find    y:promptfind <C-R>"<CR>
    tmenu       ToolBar.Find    Find...
    amenu 1.270 ToolBar.Replace :promptrepl<CR>
    vunmenu     ToolBar.Replace
    vmenu       ToolBar.Replace y:promptrepl <C-R>"<CR>
    tmenu       ToolBar.Replace Find & Replace
  # else
  #   amenu 1.260 ToolBar.Find    /
  #   amenu 1.270 ToolBar.Replace :%s/
  #   tmenu       ToolBar.Find      Find...
  #   vunmenu     ToolBar.Replace
  #   vmenu       ToolBar.Replace :s/
  #   tmenu       ToolBar.Replace   Find & Replace
  endif

   menu 1.500 ToolBar.-sep50- <nul>

  if maparg(g:html_map_leader .. 'db', 'n') != ''
    HTMLmenu amenu 1.510 ToolBar.Browser db
    tmenu                ToolBar.Browser Launch the Default Browser on the Current File
  endif

  if maparg(g:html_map_leader .. 'ff', 'n') != ''
    HTMLmenu amenu  1.520 ToolBar.Firefox   ff
    tmenu                 ToolBar.Firefox   Launch Firefox on the Current File
  endif

  if maparg(g:html_map_leader .. 'gc', 'n') != ''
    HTMLmenu amenu  1.530 ToolBar.Chrome    gc
    tmenu                 ToolBar.Chrome    Launch Chrome on the Current File
  endif

  if maparg(g:html_map_leader .. 'ed', 'n') != ''
    HTMLmenu amenu  1.540 ToolBar.Edge      ed
    tmenu                 ToolBar.Edge      Launch Edge on the Current File
  endif

  if maparg(g:html_map_leader .. 'oa', 'n') != ''
    HTMLmenu amenu  1.550 ToolBar.Opera     oa
    tmenu                 ToolBar.Opera     Launch Opera on the Current File
  endif

  if maparg(g:html_map_leader .. 'sf', 'n') != ''
    HTMLmenu amenu  1.560 ToolBar.Safari    sf
    tmenu                 ToolBar.Safari    Launch Safari on the Current File
  endif

  if maparg(g:html_map_leader .. 'w3', 'n') != ''
    HTMLmenu amenu  1.570 ToolBar.w3m       w3
    tmenu                 ToolBar.w3m       Launch w3m on the Current File
  endif

  if maparg(g:html_map_leader .. 'ly', 'n') != ''
    HTMLmenu amenu  1.570 ToolBar.Lynx      ly
    tmenu                 ToolBar.Lynx      Launch Lynx on the Current File
  endif

   menu 1.998 ToolBar.-sep99- <nul>
  amenu 1.999 ToolBar.Help    :help HTML<CR>
  tmenu       ToolBar.Help    HTML Help

  g:did_html_toolbar = true
endif  # ! g:HTML#BoolVar('g:no_html_toolbar') && has("toolbar")
# ----------------------------------------------------------------------------

# ---- Menu Items: ------------------------------------------------------ {{{1

# Add to the PopUp menu:   {{{2
nnoremenu 1.91 PopUp.Select\ Ta&g vat
onoremenu 1.91 PopUp.Select\ Ta&g at
vnoremenu 1.91 PopUp.Select\ Ta&g <C-C>vat
inoremenu 1.91 PopUp.Select\ Ta&g <C-O>vat
cnoremenu 1.91 PopUp.Select\ Ta&g <C-C>vat

nnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g vit
onoremenu 1.92 PopUp.Select\ &Inner\ Ta&g it
vnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-C>vit
inoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-O>vit
cnoremenu 1.92 PopUp.Select\ &Inner\ Ta&g <C-C>vit
# }}}2

augroup HTMLmenu
au!
  autocmd BufEnter,WinEnter * g:HTML#MenuControl() | g:HTML#ToggleClipboard(2)
augroup END

amenu HTM&L.HTML\ Help<TAB>:help\ HTML\.txt :help HTML.txt<CR>
 menu HTML.-sep1- <nul>

amenu HTML.Co&ntrol.&Disable\ Mappings<tab>:HTML\ disable     :HTMLmappings disable<CR>
amenu HTML.Co&ntrol.&Enable\ Mappings<tab>:HTML\ enable       :HTMLmappings enable<CR>
amenu disable HTML.Control.Enable\ Mappings
 menu HTML.Control.-sep1- <nul>
amenu HTML.Co&ntrol.Switch\ to\ &HTML\ mode<tab>:HTML\ html   :HTMLmappings html<CR>
amenu HTML.Co&ntrol.Switch\ to\ &XHTML\ mode<tab>:HTML\ xhtml :HTMLmappings xhtml<CR>
 menu HTML.Control.-sep2- <nul>
amenu HTML.Co&ntrol.&Reload\ Mappings<tab>:HTML\ reload       :HTMLmappings reload<CR>

if g:HTML#BoolVar('b:do_xhtml_mappings')
  amenu disable HTML.Control.Switch\ to\ XHTML\ mode
else
  amenu disable HTML.Control.Switch\ to\ HTML\ mode
endif

if maparg(g:html_map_leader .. 'db', 'n') != ''
  HTMLmenu amenu - HTML.&Preview.&Default\ Browser       db
endif
if maparg(g:html_map_leader .. 'ff', 'n') != ''
   menu HTML.Preview.-sep1-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Firefox                ff
  HTMLmenu amenu - HTML.&Preview.Firefox\ (New\ Window)  nff
  HTMLmenu amenu - HTML.&Preview.Firefox\ (New\ Tab)     tff
endif
if maparg(g:html_map_leader .. 'gc', 'n') != ''
   menu HTML.Preview.-sep2-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Chrome                 gc
  HTMLmenu amenu - HTML.&Preview.Chrome\ (New\ Window)   ngc
  HTMLmenu amenu - HTML.&Preview.Chrome\ (New\ Tab)      tgc
endif
if maparg(g:html_map_leader .. 'ed', 'n') != ''
   menu HTML.Preview.-sep2-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Edge                   ed
  HTMLmenu amenu - HTML.&Preview.Edge\ (New\ Window)     ned
  HTMLmenu amenu - HTML.&Preview.Edge\ (New\ Tab)        ted
endif
if maparg(g:html_map_leader .. 'oa', 'n') != ''
   menu HTML.Preview.-sep3-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Opera                  oa
  HTMLmenu amenu - HTML.&Preview.Opera\ (New\ Window)    noa
  HTMLmenu amenu - HTML.&Preview.Opera\ (New\ Tab)       toa
endif
if maparg(g:html_map_leader .. 'sf', 'n') != ''
   menu HTML.Preview.-sep4-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Safari                 sf
  HTMLmenu amenu - HTML.&Preview.Safari\ (New\ Window)   nsf
  HTMLmenu amenu - HTML.&Preview.Safari\ (New\ Tab)      tsf
endif
if maparg(g:html_map_leader .. 'ly', 'n') != ''
   menu HTML.Preview.-sep5-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&Lynx                   ly
  HTMLmenu amenu - HTML.&Preview.Lynx\ (New\ Window\)    nly
endif
if maparg(g:html_map_leader .. 'w3', 'n') != ''
   menu HTML.Preview.-sep6-                              <nop>
  HTMLmenu amenu - HTML.&Preview.&w3m                    w3
  HTMLmenu amenu - HTML.&Preview.w3m\ (New\ Window\)     nw3
endif

 menu HTML.-sep4- <nul>

HTMLmenu amenu - HTML.Template html

 menu HTML.-sep5- <nul>

# Character Entities menu:   {{{2

HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ to\ Entity                &
# HTMLmenu nmenu - HTML.Character\ &Entities.Convert\ to\ Entity                &l
HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ to\ %XX\ (URI\ Encode\)   %
# HTMLmenu nmenu - HTML.Character\ &Entities.Convert\ to\ %XX\ (URI\ Encode\)   %l
HTMLmenu vmenu - HTML.Character\ &Entities.Convert\ from\ Entities/%XX        ^

 menu HTML.Character\ Entities.-sep0- <nul>
HTMLemenu HTML.Character\ Entities.Ampersand            &
HTMLemenu HTML.Character\ Entities.Greaterthan          >        >
HTMLemenu HTML.Character\ Entities.Lessthan             <        <
HTMLemenu HTML.Character\ Entities.Space                <space>  nonbreaking
 menu HTML.Character\ Entities.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Cent                 c\|      ¢
HTMLemenu HTML.Character\ Entities.Pound                #        £
HTMLemenu HTML.Character\ Entities.Euro                 E=       €
HTMLemenu HTML.Character\ Entities.Yen                  Y=       ¥
 menu HTML.Character\ Entities.-sep2- <nul>
HTMLemenu HTML.Character\ Entities.Copyright            cO       ©
HTMLemenu HTML.Character\ Entities.Registered           rO       ®
HTMLemenu HTML.Character\ Entities.Trademark            tm       TM
 menu HTML.Character\ Entities.-sep3- <nul>
HTMLemenu HTML.Character\ Entities.Inverted\ Exlamation !        ¡
HTMLemenu HTML.Character\ Entities.Inverted\ Question   ?        ¿
HTMLemenu HTML.Character\ Entities.Paragraph            pa       ¶
HTMLemenu HTML.Character\ Entities.Section              se       §
HTMLemenu HTML.Character\ Entities.Middle\ Dot          \.       ·
HTMLemenu HTML.Character\ Entities.Bullet               *        •
HTMLemenu HTML.Character\ Entities.En\ dash             n-       \-
HTMLemenu HTML.Character\ Entities.Em\ dash             m-       --
HTMLemenu HTML.Character\ Entities.Ellipsis             3\.      ...
 menu HTML.Character\ Entities.-sep5- <nul>
HTMLemenu HTML.Character\ Entities.Math.Multiply        x   ×
HTMLemenu HTML.Character\ Entities.Math.Divide          /   ÷
HTMLemenu HTML.Character\ Entities.Math.Degree          dg  °
HTMLemenu HTML.Character\ Entities.Math.Micro           mi  µ
HTMLemenu HTML.Character\ Entities.Math.Plus/Minus      +-  ±
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 1    R1    Ⅰ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 2    R2    Ⅱ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 3    R3    Ⅲ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 4    R4    Ⅳ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 5    R5    Ⅴ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 6    R6    Ⅵ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 7    R7    Ⅶ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 8    R8    Ⅷ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 9    R9    Ⅸ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 10   R10   Ⅹ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 11   R11   Ⅺ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 12   R12   Ⅻ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 50   R50   Ⅼ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 100  R100  Ⅽ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 500  R500  Ⅾ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Uppercase\ 1000 R1000 Ⅿ
 menu HTML.Character\ Entities.Math.Roman\ Numerals.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 1    r1    ⅰ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 2    r2    ⅱ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 3    r3    ⅲ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 4    r4    ⅳ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 5    r5    ⅴ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 6    r6    ⅵ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 7    r7    ⅶ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 8    r8    ⅷ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 9    r9    ⅸ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 10   r10   ⅹ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 11   r11   ⅺ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 12   r12   ⅻ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 50   r50   ⅼ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 100  r100  ⅽ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 500  r500  ⅾ
HTMLemenu HTML.Character\ Entities.Math.Roman\ Numerals.Lowercase\ 1000 r1000 ⅿ
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 0  0^  ⁰
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 1  1^  ¹
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 2  2^  ²
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 3  3^  ³
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 4  4^  ⁴
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 5  5^  ⁵
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 6  6^  ⁶
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 7  7^  ⁷
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 8  8^  ⁸
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Superscript\ 9  9^  ⁹
 menu HTML.Character\ Entities.Math.Super/Subscript.-sep1- <nul>
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 0    0v  ₀
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 1    1v  ₁
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 2    2v  ₂
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 3    3v  ₃
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 4    4v  ₄
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 5    5v  ₅
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 6    6v  ₆
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 7    7v  ₇
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 8    8v  ₈
HTMLemenu HTML.Character\ Entities.Math.Super/Subscript.Subscript\ 9    9v  ₉
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Quarter    14  ¼
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Half       12  ½
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Quarters 34  ¾
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Third      13  ⅓
HTMLemenu HTML.Character\ Entities.Math.Fractions.Two\ Thirds     23  ⅔
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Fifth      15  ⅕
HTMLemenu HTML.Character\ Entities.Math.Fractions.Two\ Fifths     25  ⅖
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Fifths   35  ⅗
HTMLemenu HTML.Character\ Entities.Math.Fractions.Four\ Fiftsh    45  ⅘
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Sixth      16  ⅙
HTMLemenu HTML.Character\ Entities.Math.Fractions.Five\ Sixths    56  ⅚
HTMLemenu HTML.Character\ Entities.Math.Fractions.One\ Eigth      18  ⅛
HTMLemenu HTML.Character\ Entities.Math.Fractions.Three\ Eigths   38  ⅜
HTMLemenu HTML.Character\ Entities.Math.Fractions.Five\ Eigths    58  ⅝
HTMLemenu HTML.Character\ Entities.Math.Fractions.Seven\ Eigths   78  ⅞
HTMLemenu HTML.Character\ Entities.&Graves.A-grave  A`  À
HTMLemenu HTML.Character\ Entities.&Graves.a-grave  a`  à
HTMLemenu HTML.Character\ Entities.&Graves.E-grave  E`  È
HTMLemenu HTML.Character\ Entities.&Graves.e-grave  e`  è
HTMLemenu HTML.Character\ Entities.&Graves.I-grave  I`  Ì
HTMLemenu HTML.Character\ Entities.&Graves.i-grave  i`  ì
HTMLemenu HTML.Character\ Entities.&Graves.O-grave  O`  Ò
HTMLemenu HTML.Character\ Entities.&Graves.o-grave  o`  ò
HTMLemenu HTML.Character\ Entities.&Graves.U-grave  U`  Ù
HTMLemenu HTML.Character\ Entities.&Graves.u-grave  u`  ù
HTMLemenu HTML.Character\ Entities.&Acutes.A-acute  A'  Á
HTMLemenu HTML.Character\ Entities.&Acutes.a-acute  a'  á
HTMLemenu HTML.Character\ Entities.&Acutes.E-acute  E'  É
HTMLemenu HTML.Character\ Entities.&Acutes.e-acute  e'  é
HTMLemenu HTML.Character\ Entities.&Acutes.I-acute  I'  Í
HTMLemenu HTML.Character\ Entities.&Acutes.i-acute  i'  í
HTMLemenu HTML.Character\ Entities.&Acutes.O-acute  O'  Ó
HTMLemenu HTML.Character\ Entities.&Acutes.o-acute  o'  ó
HTMLemenu HTML.Character\ Entities.&Acutes.U-acute  U'  Ú
HTMLemenu HTML.Character\ Entities.&Acutes.u-acute  u'  ú
HTMLemenu HTML.Character\ Entities.&Acutes.Y-acute  Y'  Ý
HTMLemenu HTML.Character\ Entities.&Acutes.y-acute  y'  ý
HTMLemenu HTML.Character\ Entities.&Tildes.A-tilde  A~  Ã
HTMLemenu HTML.Character\ Entities.&Tildes.a-tilde  a~  ã
HTMLemenu HTML.Character\ Entities.&Tildes.N-tilde  N~  Ñ
HTMLemenu HTML.Character\ Entities.&Tildes.n-tilde  n~  ñ
HTMLemenu HTML.Character\ Entities.&Tildes.O-tilde  O~  Õ
HTMLemenu HTML.Character\ Entities.&Tildes.o-tilde  o~  õ
HTMLemenu HTML.Character\ Entities.&Circumflexes.A-circumflex  A^  Â
HTMLemenu HTML.Character\ Entities.&Circumflexes.a-circumflex  a^  â
HTMLemenu HTML.Character\ Entities.&Circumflexes.E-circumflex  E^  Ê
HTMLemenu HTML.Character\ Entities.&Circumflexes.e-circumflex  e^  ê
HTMLemenu HTML.Character\ Entities.&Circumflexes.I-circumflex  I^  Î
HTMLemenu HTML.Character\ Entities.&Circumflexes.i-circumflex  i^  î
HTMLemenu HTML.Character\ Entities.&Circumflexes.O-circumflex  O^  Ô
HTMLemenu HTML.Character\ Entities.&Circumflexes.o-circumflex  o^  ô
HTMLemenu HTML.Character\ Entities.&Circumflexes.U-circumflex  U^  Û
HTMLemenu HTML.Character\ Entities.&Circumflexes.u-circumflex  u^  û
HTMLemenu HTML.Character\ Entities.&Umlauts.A-umlaut  A"  Ä
HTMLemenu HTML.Character\ Entities.&Umlauts.a-umlaut  a"  ä
HTMLemenu HTML.Character\ Entities.&Umlauts.E-umlaut  E"  Ë
HTMLemenu HTML.Character\ Entities.&Umlauts.e-umlaut  e"  ë
HTMLemenu HTML.Character\ Entities.&Umlauts.I-umlaut  I"  Ï
HTMLemenu HTML.Character\ Entities.&Umlauts.i-umlaut  i"  ï
HTMLemenu HTML.Character\ Entities.&Umlauts.O-umlaut  O"  Ö
HTMLemenu HTML.Character\ Entities.&Umlauts.o-umlaut  o"  ö
HTMLemenu HTML.Character\ Entities.&Umlauts.U-umlaut  U"  Ü
HTMLemenu HTML.Character\ Entities.&Umlauts.u-umlaut  u"  ü
HTMLemenu HTML.Character\ Entities.&Umlauts.y-umlaut  y"  ÿ
HTMLemenu HTML.Character\ Entities.&Umlauts.Umlaut    "   ¨
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Alpha    Al Α
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Beta     Be Β
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Gamma    Ga Γ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Delta    De Δ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Epsilon  Ep Ε
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Zeta     Ze Ζ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Eta      Et Η
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Theta    Th Θ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Iota     Io Ι
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Kappa    Ka Κ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Lambda   Lm Λ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Mu       Mu Μ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Nu       Nu Ν
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Xi       Xi Ξ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Omicron  Oc Ο
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Pi       Pi Π
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Rho      Rh Ρ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Sigma    Si Σ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Tau      Ta Τ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Upsilon  Up Υ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Phi      Ph Φ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Chi      Ch Χ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Uppercase.Psi      Ps Ψ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.alpha    al α
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.beta     be β
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.gamma    ga γ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.delta    de δ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.epsilon  ep ε
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.zeta     ze ζ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.eta      et η
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.theta    th θ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.iota     io ι
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.kappa    ka κ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.lambda   lm λ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.mu       mu μ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.nu       nu ν
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.xi       xi ξ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.omicron  oc ο
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.pi       pi π
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.rho      rh ρ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.sigma    si σ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.sigmaf   sf ς
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.tau      ta τ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.upsilon  up υ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.phi      ph φ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.chi      ch χ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.psi      ps ψ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.omega    og ω
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.thetasym ts ϑ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.upsih    uh ϒ
HTMLemenu HTML.Character\ Entities.Greek\ &Letters.&Lowercase.piv      pv ϖ
HTMLemenu HTML.Character\ Entities.A&rrows.Left\ single\ arrow        la ←
HTMLemenu HTML.Character\ Entities.A&rrows.Right\ single\ arrow       ra →
HTMLemenu HTML.Character\ Entities.A&rrows.Up\ single\ arrow          ua ↑
HTMLemenu HTML.Character\ Entities.A&rrows.Down\ single\ arrow        da ↓
HTMLemenu HTML.Character\ Entities.A&rrows.Left-right\ single\ arrow  ha ↔
 menu HTML.Character\ Entities.Arrows.-sep1-                             <nul>
HTMLemenu HTML.Character\ Entities.A&rrows.Left\ double\ arrow        lA ⇐
HTMLemenu HTML.Character\ Entities.A&rrows.Right\ double\ arrow       rA ⇒
HTMLemenu HTML.Character\ Entities.A&rrows.Up\ double\ arrow          uA ⇑
HTMLemenu HTML.Character\ Entities.A&rrows.Down\ double\ arrow        dA ⇓
HTMLemenu HTML.Character\ Entities.A&rrows.Left-right\ double\ arrow  hA ⇔
HTMLemenu HTML.Character\ Entities.&Quotes.Quotation\ mark            '  "
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Single\ Quote        l' ‘
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Single\ Quote       r' ’
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Double\ Quote        l" “
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Double\ Quote       r" ”
HTMLemenu HTML.Character\ Entities.&Quotes.Left\ Angle\ Quote         2< «
HTMLemenu HTML.Character\ Entities.&Quotes.Right\ Angle\ Quote        2> »
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..A-ring      Ao Å
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..a-ring      ao å
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..AE-ligature AE Æ
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..ae-ligature ae æ
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..C-cedilla   C, Ç
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..c-cedilla   c, ç
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..O-slash     O/ Ø
HTMLemenu HTML.Character\ Entities.\ \ \ \ \ \ \ &etc\.\.\..o-slash     o/ ø

# Colors menu:   {{{2

HTMLmenu amenu - HTML.&Colors.Display\ All\ &&\ Select 3
amenu HTML.Colors.-sep1- <nul>

HTMLcmenu AliceBlue            #F0F8FF
HTMLcmenu AntiqueWhite         #FAEBD7
HTMLcmenu Aqua                 #00FFFF
HTMLcmenu Aquamarine           #7FFFD4
HTMLcmenu Azure                #F0FFFF

HTMLcmenu Beige                #F5F5DC
HTMLcmenu Bisque               #FFE4C4
HTMLcmenu Black                #000000
HTMLcmenu BlanchedAlmond       #FFEBCD
HTMLcmenu Blue                 #0000FF
HTMLcmenu BlueViolet           #8A2BE2
HTMLcmenu Brown                #A52A2A
HTMLcmenu Burlywood            #DEB887

HTMLcmenu CadetBlue            #5F9EA0
HTMLcmenu Chartreuse           #7FFF00
HTMLcmenu Chocolate            #D2691E
HTMLcmenu Coral                #FF7F50
HTMLcmenu CornflowerBlue       #6495ED
HTMLcmenu Cornsilk             #FFF8DC
HTMLcmenu Crimson              #DC143C
HTMLcmenu Cyan                 #00FFFF

HTMLcmenu DarkBlue             #00008B
HTMLcmenu DarkCyan             #008B8B
HTMLcmenu DarkGoldenrod        #B8860B
HTMLcmenu DarkGray             #A9A9A9
HTMLcmenu DarkGreen            #006400
HTMLcmenu DarkKhaki            #BDB76B
HTMLcmenu DarkMagenta          #8B008B
HTMLcmenu DarkOliveGreen       #556B2F
HTMLcmenu DarkOrange           #FF8C00
HTMLcmenu DarkOrchid           #9932CC
HTMLcmenu DarkRed              #8B0000
HTMLcmenu DarkSalmon           #E9967A
HTMLcmenu DarkSeagreen         #8FBC8F
HTMLcmenu DarkSlateBlue        #483D8B
HTMLcmenu DarkSlateGray        #2F4F4F
HTMLcmenu DarkTurquoise        #00CED1
HTMLcmenu DarkViolet           #9400D3
HTMLcmenu DeepPink             #FF1493
HTMLcmenu DeepSkyblue          #00BFFF
HTMLcmenu DimGray              #696969
HTMLcmenu DodgerBlue           #1E90FF

HTMLcmenu Firebrick            #B22222
HTMLcmenu FloralWhite          #FFFAF0
HTMLcmenu ForestGreen          #228B22
HTMLcmenu Fuchsia              #FF00FF
HTMLcmenu Gainsboro            #DCDCDC
HTMLcmenu GhostWhite           #F8F8FF
HTMLcmenu Gold                 #FFD700
HTMLcmenu Goldenrod            #DAA520
HTMLcmenu Gray                 #808080
HTMLcmenu Green                #008000
HTMLcmenu GreenYellow          #ADFF2F

HTMLcmenu Honeydew             #F0FFF0
HTMLcmenu HotPink              #FF69B4
HTMLcmenu IndianRed            #CD5C5C
HTMLcmenu Indigo               #4B0082
HTMLcmenu Ivory                #FFFFF0
HTMLcmenu Khaki                #F0E68C

HTMLcmenu Lavender             #E6E6FA
HTMLcmenu LavenderBlush        #FFF0F5
HTMLcmenu LawnGreen            #7CFC00
HTMLcmenu LemonChiffon         #FFFACD
HTMLcmenu LightBlue            #ADD8E6
HTMLcmenu LightCoral           #F08080
HTMLcmenu LightCyan            #E0FFFF
HTMLcmenu LightGoldenrodYellow #FAFAD2
HTMLcmenu LightGreen           #90EE90
HTMLcmenu LightGrey            #D3D3D3
HTMLcmenu LightPink            #FFB6C1
HTMLcmenu LightSalmon          #FFA07A
HTMLcmenu LightSeaGreen        #20B2AA
HTMLcmenu LightSkyBlue         #87CEFA
HTMLcmenu LightSlateGray       #778899
HTMLcmenu LightSteelBlue       #B0C4DE
HTMLcmenu LightYellow          #FFFFE0
HTMLcmenu Lime                 #00FF00
HTMLcmenu LimeGreen            #32CD32
HTMLcmenu Linen                #FAF0E6

HTMLcmenu Magenta              #FF00FF
HTMLcmenu Maroon               #800000
HTMLcmenu MediumAquamarine     #66CDAA
HTMLcmenu MediumBlue           #0000CD
HTMLcmenu MediumOrchid         #BA55D3
HTMLcmenu MediumPurple         #9370DB
HTMLcmenu MediumSeaGreen       #3CB371
HTMLcmenu MediumSlateBlue      #7B68EE
HTMLcmenu MediumSpringGreen    #00FA9A
HTMLcmenu MediumTurquoise      #48D1CC
HTMLcmenu MediumVioletRed      #C71585
HTMLcmenu MidnightBlue         #191970
HTMLcmenu Mintcream            #F5FFFA
HTMLcmenu Mistyrose            #FFE4E1
HTMLcmenu Moccasin             #FFE4B5

HTMLcmenu NavajoWhite          #FFDEAD
HTMLcmenu Navy                 #000080
HTMLcmenu OldLace              #FDF5E6
HTMLcmenu Olive                #808000
HTMLcmenu OliveDrab            #6B8E23
HTMLcmenu Orange               #FFA500
HTMLcmenu OrangeRed            #FF4500
HTMLcmenu Orchid               #DA70D6

HTMLcmenu PaleGoldenrod        #EEE8AA
HTMLcmenu PaleGreen            #98FB98
HTMLcmenu PaleTurquoise        #AFEEEE
HTMLcmenu PaleVioletred        #DB7093
HTMLcmenu Papayawhip           #FFEFD5
HTMLcmenu Peachpuff            #FFDAB9
HTMLcmenu Peru                 #CD853F
HTMLcmenu Pink                 #FFC0CB
HTMLcmenu Plum                 #DDA0DD
HTMLcmenu PowderBlue           #B0E0E6
HTMLcmenu Purple               #800080

HTMLcmenu Red                  #FF0000
HTMLcmenu RosyBrown            #BC8F8F
HTMLcmenu RoyalBlue            #4169E1

HTMLcmenu SaddleBrown          #8B4513
HTMLcmenu Salmon               #FA8072
HTMLcmenu SandyBrown           #F4A460
HTMLcmenu SeaGreen             #2E8B57
HTMLcmenu Seashell             #FFF5EE
HTMLcmenu Sienna               #A0522D
HTMLcmenu Silver               #C0C0C0
HTMLcmenu SkyBlue              #87CEEB
HTMLcmenu SlateBlue            #6A5ACD
HTMLcmenu SlateGray            #708090
HTMLcmenu Snow                 #FFFAFA
HTMLcmenu SpringGreen          #00FF7F
HTMLcmenu SteelBlue            #4682B4

HTMLcmenu Tan                  #D2B48C
HTMLcmenu Teal                 #008080
HTMLcmenu Thistle              #D8BFD8
HTMLcmenu Tomato               #FF6347
HTMLcmenu Turquoise            #40E0D0
HTMLcmenu Violet               #EE82EE

# Font Styles menu:   {{{2

HTMLmenu imenu - HTML.Font\ &Styles.Bold      bo
HTMLmenu vmenu - HTML.Font\ &Styles.Bold      bo
HTMLmenu nmenu - HTML.Font\ &Styles.Bold      bo i
HTMLmenu imenu - HTML.Font\ &Styles.Strong    st
HTMLmenu vmenu - HTML.Font\ &Styles.Strong    st
HTMLmenu nmenu - HTML.Font\ &Styles.Strong    st i
HTMLmenu imenu - HTML.Font\ &Styles.Italics   it
HTMLmenu vmenu - HTML.Font\ &Styles.Italics   it
HTMLmenu nmenu - HTML.Font\ &Styles.Italics   it i
HTMLmenu imenu - HTML.Font\ &Styles.Emphasis  em
HTMLmenu vmenu - HTML.Font\ &Styles.Emphasis  em
HTMLmenu nmenu - HTML.Font\ &Styles.Emphasis  em i
HTMLmenu imenu - HTML.Font\ &Styles.Underline un
HTMLmenu vmenu - HTML.Font\ &Styles.Underline un
HTMLmenu nmenu - HTML.Font\ &Styles.Underline un i
HTMLmenu imenu - HTML.Font\ &Styles.Big       bi
HTMLmenu vmenu - HTML.Font\ &Styles.Big       bi
HTMLmenu nmenu - HTML.Font\ &Styles.Big       bi i
HTMLmenu imenu - HTML.Font\ &Styles.Small     sm
HTMLmenu vmenu - HTML.Font\ &Styles.Small     sm
HTMLmenu nmenu - HTML.Font\ &Styles.Small     sm i
 menu HTML.Font\ Styles.-sep1- <nul>
HTMLmenu imenu - HTML.Font\ &Styles.Font\ Size  fo
HTMLmenu vmenu - HTML.Font\ &Styles.Font\ Size  fo
HTMLmenu nmenu - HTML.Font\ &Styles.Font\ Size  fo i
HTMLmenu imenu - HTML.Font\ &Styles.Font\ Color fc
HTMLmenu vmenu - HTML.Font\ &Styles.Font\ Color fc
HTMLmenu nmenu - HTML.Font\ &Styles.Font\ Color fc i
 menu HTML.Font\ Styles.-sep2- <nul>
HTMLmenu imenu - HTML.Font\ &Styles.CITE           ci
HTMLmenu vmenu - HTML.Font\ &Styles.CITE           ci
HTMLmenu nmenu - HTML.Font\ &Styles.CITE           ci i
HTMLmenu imenu - HTML.Font\ &Styles.CODE           co
HTMLmenu vmenu - HTML.Font\ &Styles.CODE           co
HTMLmenu nmenu - HTML.Font\ &Styles.CODE           co i
HTMLmenu imenu - HTML.Font\ &Styles.Inserted\ Text in
HTMLmenu vmenu - HTML.Font\ &Styles.Inserted\ Text in
HTMLmenu nmenu - HTML.Font\ &Styles.Inserted\ Text in i
HTMLmenu imenu - HTML.Font\ &Styles.Deleted\ Text  de
HTMLmenu vmenu - HTML.Font\ &Styles.Deleted\ Text  de
HTMLmenu nmenu - HTML.Font\ &Styles.Deleted\ Text  de i
HTMLmenu imenu - HTML.Font\ &Styles.Emphasize      em
HTMLmenu vmenu - HTML.Font\ &Styles.Emphasize      em
HTMLmenu nmenu - HTML.Font\ &Styles.Emphasize      em i
HTMLmenu imenu - HTML.Font\ &Styles.Keyboard\ Text kb
HTMLmenu vmenu - HTML.Font\ &Styles.Keyboard\ Text kb
HTMLmenu nmenu - HTML.Font\ &Styles.Keyboard\ Text kb i
HTMLmenu imenu - HTML.Font\ &Styles.Sample\ Text   sa
HTMLmenu vmenu - HTML.Font\ &Styles.Sample\ Text   sa
HTMLmenu nmenu - HTML.Font\ &Styles.Sample\ Text   sa i
# HTMLmenu imenu - HTML.Font\ &Styles.Strikethrough  sk
# HTMLmenu vmenu - HTML.Font\ &Styles.Strikethrough  sk
# HTMLmenu nmenu - HTML.Font\ &Styles.Strikethrough  sk i
HTMLmenu imenu - HTML.Font\ &Styles.STRONG         st
HTMLmenu vmenu - HTML.Font\ &Styles.STRONG         st
HTMLmenu nmenu - HTML.Font\ &Styles.STRONG         st i
HTMLmenu imenu - HTML.Font\ &Styles.Subscript      sb
HTMLmenu vmenu - HTML.Font\ &Styles.Subscript      sb
HTMLmenu nmenu - HTML.Font\ &Styles.Subscript      sb i
HTMLmenu imenu - HTML.Font\ &Styles.Superscript    sp
HTMLmenu vmenu - HTML.Font\ &Styles.Superscript    sp
HTMLmenu nmenu - HTML.Font\ &Styles.Superscript    sp i
HTMLmenu imenu - HTML.Font\ &Styles.Teletype\ Text tt
HTMLmenu vmenu - HTML.Font\ &Styles.Teletype\ Text tt
HTMLmenu nmenu - HTML.Font\ &Styles.Teletype\ Text tt i
HTMLmenu imenu - HTML.Font\ &Styles.Variable       va
HTMLmenu vmenu - HTML.Font\ &Styles.Variable       va
HTMLmenu nmenu - HTML.Font\ &Styles.Variable       va i


# Frames menu:   {{{2

# HTMLmenu imenu - HTML.&Frames.FRAMESET fs
# HTMLmenu vmenu - HTML.&Frames.FRAMESET fs
# HTMLmenu nmenu - HTML.&Frames.FRAMESET fs i
# HTMLmenu imenu - HTML.&Frames.FRAME    fr
# HTMLmenu vmenu - HTML.&Frames.FRAME    fr
# HTMLmenu nmenu - HTML.&Frames.FRAME    fr i
# HTMLmenu imenu - HTML.&Frames.NOFRAMES nf
# HTMLmenu vmenu - HTML.&Frames.NOFRAMES nf
# HTMLmenu nmenu - HTML.&Frames.NOFRAMES nf i
#
# IFRAME menu item has been moved


# Headings menu:   {{{2

HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 1 h1
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 2 h2
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 3 h3
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 4 h4
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 5 h5
HTMLmenu imenu - HTML.&Headings.Heading\ Level\ 6 h6
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 1 h1
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 2 h2
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 3 h3
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 4 h4
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 5 h5
HTMLmenu vmenu - HTML.&Headings.Heading\ Level\ 6 h6
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 1 h1 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 2 h2 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 3 h3 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 4 h4 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 5 h5 i
HTMLmenu nmenu - HTML.&Headings.Heading\ Level\ 6 h6 i
HTMLmenu imenu - HTML.&Headings.Heading\ Grouping hg
HTMLmenu vmenu - HTML.&Headings.Heading\ Grouping hg
HTMLmenu nmenu - HTML.&Headings.Heading\ Grouping hg i


# Lists menu:   {{{2

HTMLmenu imenu - HTML.&Lists.Ordered\ List    ol
HTMLmenu vmenu - HTML.&Lists.Ordered\ List    ol
HTMLmenu nmenu - HTML.&Lists.Ordered\ List    ol i
HTMLmenu imenu - HTML.&Lists.Unordered\ List  ul
HTMLmenu vmenu - HTML.&Lists.Unordered\ List  ul
HTMLmenu nmenu - HTML.&Lists.Unordered\ List  ul i
HTMLmenu imenu - HTML.&Lists.List\ Item       li
HTMLmenu vmenu - HTML.&Lists.List\ Item       li
HTMLmenu nmenu - HTML.&Lists.List\ Item       li i
 menu HTML.Lists.-sep1- <nul>
HTMLmenu imenu - HTML.&Lists.Definition\ List dl
HTMLmenu vmenu - HTML.&Lists.Definition\ List dl
HTMLmenu nmenu - HTML.&Lists.Definition\ List dl i
HTMLmenu imenu - HTML.&Lists.Definition\ Term dt
HTMLmenu vmenu - HTML.&Lists.Definition\ Term dt
HTMLmenu nmenu - HTML.&Lists.Definition\ Term dt i
HTMLmenu imenu - HTML.&Lists.Definition\ Body dd
HTMLmenu vmenu - HTML.&Lists.Definition\ Body dd
HTMLmenu nmenu - HTML.&Lists.Definition\ Body dd i


# Tables menu:   {{{2

HTMLmenu nmenu - HTML.&Tables.Interactive\ Table      tA
HTMLmenu imenu - HTML.&Tables.TABLE                   ta
HTMLmenu vmenu - HTML.&Tables.TABLE                   ta
HTMLmenu nmenu - HTML.&Tables.TABLE                   ta i
HTMLmenu imenu - HTML.&Tables.Header\ Row             tH
HTMLmenu vmenu - HTML.&Tables.Header\ Row             tH
HTMLmenu nmenu - HTML.&Tables.Header\ Row             tH i
HTMLmenu imenu - HTML.&Tables.Row                     tr
HTMLmenu vmenu - HTML.&Tables.Row                     tr
HTMLmenu nmenu - HTML.&Tables.Row                     tr i
HTMLmenu imenu - HTML.&Tables.Footer\ Row             tf
HTMLmenu vmenu - HTML.&Tables.Footer\ Row             tf
HTMLmenu nmenu - HTML.&Tables.Footer\ Row             tf i
HTMLmenu imenu - HTML.&Tables.Column\ Header          th
HTMLmenu vmenu - HTML.&Tables.Column\ Header          th
HTMLmenu nmenu - HTML.&Tables.Column\ Header          th i
HTMLmenu imenu - HTML.&Tables.Data\ (Column\ Element) td
HTMLmenu vmenu - HTML.&Tables.Data\ (Column\ Element) td
HTMLmenu nmenu - HTML.&Tables.Data\ (Column\ Element) td i
HTMLmenu imenu - HTML.&Tables.CAPTION                 ca
HTMLmenu vmenu - HTML.&Tables.CAPTION                 ca
HTMLmenu nmenu - HTML.&Tables.CAPTION                 ca i


# Forms menu:   {{{2

HTMLmenu imenu - HTML.F&orms.FORM             fm
HTMLmenu vmenu - HTML.F&orms.FORM             fm
HTMLmenu nmenu - HTML.F&orms.FORM             fm i
HTMLmenu imenu - HTML.F&orms.FIELDSET         fd
HTMLmenu vmenu - HTML.F&orms.FIELDSET         fd
HTMLmenu nmenu - HTML.F&orms.FIELDSET         fd i
HTMLmenu imenu - HTML.F&orms.BUTTON           bu
HTMLmenu vmenu - HTML.F&orms.BUTTON           bu
HTMLmenu nmenu - HTML.F&orms.BUTTON           bu i
HTMLmenu imenu - HTML.F&orms.CHECKBOX         ch
HTMLmenu vmenu - HTML.F&orms.CHECKBOX         ch
HTMLmenu nmenu - HTML.F&orms.CHECKBOX         ch i
HTMLmenu imenu - HTML.F&orms.DATALIST         da
HTMLmenu vmenu - HTML.F&orms.DATALIST         da
HTMLmenu nmenu - HTML.F&orms.DATALIST         da i
HTMLmenu imenu - HTML.F&orms.DATE             cl
HTMLmenu vmenu - HTML.F&orms.DATE             cl
HTMLmenu nmenu - HTML.F&orms.DATE             cl i
HTMLmenu imenu - HTML.F&orms.RADIO            ra
HTMLmenu vmenu - HTML.F&orms.RADIO            ra
HTMLmenu nmenu - HTML.F&orms.RADIO            ra i
HTMLmenu imenu - HTML.F&orms.RANGE            rn
HTMLmenu vmenu - HTML.F&orms.RANGE            rn
HTMLmenu nmenu - HTML.F&orms.RANGE            rn i
HTMLmenu imenu - HTML.F&orms.HIDDEN           hi
HTMLmenu vmenu - HTML.F&orms.HIDDEN           hi
HTMLmenu nmenu - HTML.F&orms.HIDDEN           hi i
HTMLmenu imenu - HTML.F&orms.EMAIL            @
HTMLmenu vmenu - HTML.F&orms.EMAIL            @
HTMLmenu nmenu - HTML.F&orms.EMAIL            @ i
HTMLmenu imenu - HTML.F&orms.NUMBER           nu
HTMLmenu vmenu - HTML.F&orms.NUMBER           nu
HTMLmenu nmenu - HTML.F&orms.NUMBER           nu i
HTMLmenu imenu - HTML.F&orms.OPTION           op
HTMLmenu vmenu - HTML.F&orms.OPTION           op
HTMLmenu nmenu - HTML.F&orms.OPTION           op i
HTMLmenu imenu - HTML.F&orms.OPTGROUP         og
HTMLmenu vmenu - HTML.F&orms.OPTGROUP         og
HTMLmenu nmenu - HTML.F&orms.OPTGROUP         og i
HTMLmenu imenu - HTML.F&orms.PASSWORD         pa
HTMLmenu vmenu - HTML.F&orms.PASSWORD         pa
HTMLmenu nmenu - HTML.F&orms.PASSWORD         pa i
HTMLmenu imenu - HTML.F&orms.TIME             nt
HTMLmenu vmenu - HTML.F&orms.TIME             nt
HTMLmenu nmenu - HTML.F&orms.TIME             nt i
HTMLmenu imenu - HTML.F&orms.TEL              #
HTMLmenu vmenu - HTML.F&orms.TEL              #
HTMLmenu nmenu - HTML.F&orms.TEL              # i
HTMLmenu imenu - HTML.F&orms.TEXT             te
HTMLmenu vmenu - HTML.F&orms.TEXT             te
HTMLmenu nmenu - HTML.F&orms.TEXT             te i
HTMLmenu imenu - HTML.F&orms.FILE             fi
HTMLmenu vmenu - HTML.F&orms.FILE             fi
HTMLmenu nmenu - HTML.F&orms.FILE             fi i
HTMLmenu imenu - HTML.F&orms.SELECT           se
HTMLmenu vmenu - HTML.F&orms.SELECT           se
HTMLmenu nmenu - HTML.F&orms.SELECT           se i
HTMLmenu imenu - HTML.F&orms.SELECT\ MULTIPLE ms
HTMLmenu vmenu - HTML.F&orms.SELECT\ MULTIPLE ms
HTMLmenu nmenu - HTML.F&orms.SELECT\ MULTIPLE ms i
HTMLmenu imenu - HTML.F&orms.TEXTAREA         tx
HTMLmenu vmenu - HTML.F&orms.TEXTAREA         tx
HTMLmenu nmenu - HTML.F&orms.TEXTAREA         tx i
HTMLmenu imenu - HTML.F&orms.URL              ur
HTMLmenu vmenu - HTML.F&orms.URL              ur
HTMLmenu nmenu - HTML.F&orms.URL              ur i
HTMLmenu imenu - HTML.F&orms.SUBMIT           su
HTMLmenu nmenu - HTML.F&orms.SUBMIT           su i
HTMLmenu imenu - HTML.F&orms.RESET            re
HTMLmenu nmenu - HTML.F&orms.RESET            re i
HTMLmenu imenu - HTML.F&orms.LABEL            la
HTMLmenu vmenu - HTML.F&orms.LABEL            la
HTMLmenu nmenu - HTML.F&orms.LABEL            la i


# HTML 5 Tags Menu: {{{2

HTMLmenu imenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&ARTICLE                ar i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.AS&IDE                  as
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.AS&IDE                  as
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.AS&IDE                  as i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.A&udio\ with\ controls  au i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&Video\ with\ controls  vi i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&CANVAS                 cv i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ SUMMARY ds
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ SUMMARY ds
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&DETAILS\ with\ SUMMARY ds i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&EMBED                  eb
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&EMBED                  eb
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&EMBED                  eb i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&FIGURE                 fg i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.F&igure\ Caption        fp i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&FOOTER                 ft i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&HEADER                 hd
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&HEADER                 hd
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&HEADER                 hd i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&MAIN                   ma
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&MAIN                   ma
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&MAIN                   ma i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.MA&RK                   mk
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.MA&RK                   mk
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.MA&RK                   mk i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.METE&R                  mt
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.METE&R                  mt
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.METE&R                  mt i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&NAV                    na
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&NAV                    na
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&NAV                    na i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&PROGRESS               pg i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&SECTION                sc
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&SECTION                sc
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&SECTION                sc i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&TIME                   tm
HTMLmenu vmenu - HTML.HTML\ &5\ Tags.&TIME                   tm
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&TIME                   tm i
HTMLmenu imenu - HTML.HTML\ &5\ Tags.&WBR                    wb
HTMLmenu nmenu - HTML.HTML\ &5\ Tags.&WBR                    wb i


# SSI directives: {{{2

HTMLmenu imenu - HTML.SSI\ Directi&ves.&config\ timefmt      cf
HTMLmenu vmenu - HTML.SSI\ Directi&ves.&config\ timefmt      cf
HTMLmenu nmenu - HTML.SSI\ Directi&ves.&config\ timefmt      cf i
HTMLmenu imenu - HTML.SSI\ Directi&ves.config\ sizefmt       cz
HTMLmenu vmenu - HTML.SSI\ Directi&ves.config\ sizefmt       cz
HTMLmenu nmenu - HTML.SSI\ Directi&ves.config\ sizefmt       cz i
HTMLmenu imenu - HTML.SSI\ Directi&ves.&echo\ var            ev
HTMLmenu vmenu - HTML.SSI\ Directi&ves.&echo\ var            ev
HTMLmenu nmenu - HTML.SSI\ Directi&ves.&echo\ var            ev i
HTMLmenu imenu - HTML.SSI\ Directi&ves.&include\ virtual     iv
HTMLmenu vmenu - HTML.SSI\ Directi&ves.&include\ virtual     iv
HTMLmenu nmenu - HTML.SSI\ Directi&ves.&include\ virtual     iv i
HTMLmenu imenu - HTML.SSI\ Directi&ves.&flastmod\ virtual    fv
HTMLmenu vmenu - HTML.SSI\ Directi&ves.&flastmod\ virtual    fv
HTMLmenu nmenu - HTML.SSI\ Directi&ves.&flastmod\ virtual    fv i
HTMLmenu imenu - HTML.SSI\ Directi&ves.fsi&ze\ virtual       fz
HTMLmenu vmenu - HTML.SSI\ Directi&ves.fsi&ze\ virtual       fz
HTMLmenu nmenu - HTML.SSI\ Directi&ves.fsi&ze\ virtual       fz i
HTMLmenu imenu - HTML.SSI\ Directi&ves.e&xec\ cmd            ec
HTMLmenu vmenu - HTML.SSI\ Directi&ves.e&xec\ cmd            ec
HTMLmenu nmenu - HTML.SSI\ Directi&ves.e&xec\ cmd            ec i
HTMLmenu imenu - HTML.SSI\ Directi&ves.&set\ var             sv
HTMLmenu vmenu - HTML.SSI\ Directi&ves.&set\ var             sv
HTMLmenu nmenu - HTML.SSI\ Directi&ves.&set\ var             sv i
HTMLmenu imenu - HTML.SSI\ Directi&ves.if\ e&lse             ie
HTMLmenu vmenu - HTML.SSI\ Directi&ves.if\ e&lse             ie
HTMLmenu nmenu - HTML.SSI\ Directi&ves.if\ e&lse             ie i

# }}}2

 menu HTML.-sep6- <nul>

HTMLmenu nmenu - HTML.Doctype\ (4\.01\ transitional) 4
HTMLmenu nmenu - HTML.Doctype\ (4\.01\ strict)       s4
HTMLmenu nmenu - HTML.Doctype\ (HTML\ 5)             5
HTMLmenu imenu - HTML.Content-Type                   ct
HTMLmenu nmenu - HTML.Content-Type                   ct i

 menu HTML.-sep7- <nul>

HTMLmenu imenu - HTML.BODY               bd
HTMLmenu vmenu - HTML.BODY               bd
HTMLmenu nmenu - HTML.BODY               bd i
HTMLmenu imenu - HTML.BUTTON             bn
HTMLmenu vmenu - HTML.BUTTON             bn
HTMLmenu nmenu - HTML.BUTTON             bn i
HTMLmenu imenu - HTML.CENTER             ce
HTMLmenu vmenu - HTML.CENTER             ce
HTMLmenu nmenu - HTML.CENTER             ce i
HTMLmenu imenu - HTML.HEAD               he
HTMLmenu vmenu - HTML.HEAD               he
HTMLmenu nmenu - HTML.HEAD               he i
HTMLmenu imenu - HTML.Horizontal\ Rule   hr
HTMLmenu nmenu - HTML.Horizontal\ Rule   hr i
HTMLmenu imenu - HTML.HTML               ht
HTMLmenu vmenu - HTML.HTML               ht
HTMLmenu nmenu - HTML.HTML               ht i
HTMLmenu imenu - HTML.Hyperlink          ah
HTMLmenu vmenu - HTML.Hyperlink          ah
HTMLmenu nmenu - HTML.Hyperlink          ah i
HTMLmenu imenu - HTML.Inline\ Image      im
HTMLmenu vmenu - HTML.Inline\ Image      im
HTMLmenu nmenu - HTML.Inline\ Image      im i
HTMLmenu imenu - HTML.Update\ Image\ Size\ Attributes mi
HTMLmenu vmenu - HTML.Update\ Image\ Size\ Attributes mi
HTMLmenu nmenu - HTML.Update\ Image\ Size\ Attributes mi
HTMLmenu imenu - HTML.Line\ Break        br
HTMLmenu nmenu - HTML.Line\ Break        br i
# HTMLmenu imenu - HTML.Named\ Anchor      an
# HTMLmenu vmenu - HTML.Named\ Anchor      an
# HTMLmenu nmenu - HTML.Named\ Anchor      an i
HTMLmenu imenu - HTML.Paragraph          pp
HTMLmenu vmenu - HTML.Paragraph          pp
HTMLmenu nmenu - HTML.Paragraph          pp i
HTMLmenu imenu - HTML.Preformatted\ Text pr
HTMLmenu vmenu - HTML.Preformatted\ Text pr
HTMLmenu nmenu - HTML.Preformatted\ Text pr i
HTMLmenu imenu - HTML.TITLE              ti
HTMLmenu vmenu - HTML.TITLE              ti
HTMLmenu nmenu - HTML.TITLE              ti i

HTMLmenu imenu - HTML.&More\.\.\..ADDRESS                   ad
HTMLmenu vmenu - HTML.&More\.\.\..ADDRESS                   ad
HTMLmenu nmenu - HTML.&More\.\.\..ADDRESS                   ad i
HTMLmenu imenu - HTML.&More\.\.\..BASE\ HREF                bh
HTMLmenu vmenu - HTML.&More\.\.\..BASE\ HREF                bh
HTMLmenu nmenu - HTML.&More\.\.\..BASE\ HREF                bh i
HTMLmenu imenu - HTML.&More\.\.\..BASE\ TARGET              bt
HTMLmenu vmenu - HTML.&More\.\.\..BASE\ TARGET              bt
HTMLmenu nmenu - HTML.&More\.\.\..BASE\ TARGET              bt i
HTMLmenu imenu - HTML.&More\.\.\..BLOCKQUTE                 bl
HTMLmenu vmenu - HTML.&More\.\.\..BLOCKQUTE                 bl
HTMLmenu nmenu - HTML.&More\.\.\..BLOCKQUTE                 bl i
HTMLmenu imenu - HTML.&More\.\.\..Comment                   cm
HTMLmenu vmenu - HTML.&More\.\.\..Comment                   cm
HTMLmenu nmenu - HTML.&More\.\.\..Comment                   cm i
HTMLmenu imenu - HTML.&More\.\.\..Defining\ Instance        df
HTMLmenu vmenu - HTML.&More\.\.\..Defining\ Instance        df
HTMLmenu nmenu - HTML.&More\.\.\..Defining\ Instance        df i
HTMLmenu imenu - HTML.&More\.\.\..Document\ Division        dv
HTMLmenu vmenu - HTML.&More\.\.\..Document\ Division        dv
HTMLmenu nmenu - HTML.&More\.\.\..Document\ Division        dv i
HTMLmenu imenu - HTML.&More\.\.\..Inline\ Frame             if
HTMLmenu vmenu - HTML.&More\.\.\..Inline\ Frame             if
HTMLmenu nmenu - HTML.&More\.\.\..Inline\ Frame             if i
HTMLmenu imenu - HTML.&More\.\.\..JavaScript                js
HTMLmenu nmenu - HTML.&More\.\.\..JavaScript                js i
HTMLmenu imenu - HTML.&More\.\.\..Sourced\ JavaScript       sj
HTMLmenu nmenu - HTML.&More\.\.\..Sourced\ JavaScript       sj i
HTMLmenu imenu - HTML.&More\.\.\..LINK\ HREF                lk
HTMLmenu vmenu - HTML.&More\.\.\..LINK\ HREF                lk
HTMLmenu nmenu - HTML.&More\.\.\..LINK\ HREF                lk i
HTMLmenu imenu - HTML.&More\.\.\..META                      me
HTMLmenu vmenu - HTML.&More\.\.\..META                      me
HTMLmenu nmenu - HTML.&More\.\.\..META                      me i
HTMLmenu imenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh
HTMLmenu vmenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh
HTMLmenu nmenu - HTML.&More\.\.\..META\ HTTP-EQUIV          mh i
HTMLmenu imenu - HTML.&More\.\.\..NOSCRIPT                  nj
HTMLmenu vmenu - HTML.&More\.\.\..NOSCRIPT                  nj
HTMLmenu nmenu - HTML.&More\.\.\..NOSCRIPT                  nj i
HTMLmenu imenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob
HTMLmenu vmenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob
HTMLmenu nmenu - HTML.&More\.\.\..Generic\ Embedded\ Object ob i
HTMLmenu imenu - HTML.&More\.\.\..Object\ Parameter         pm
HTMLmenu vmenu - HTML.&More\.\.\..Object\ Parameter         pm
HTMLmenu nmenu - HTML.&More\.\.\..Object\ Parameter         pm i
HTMLmenu imenu - HTML.&More\.\.\..Quoted\ Text              qu
HTMLmenu vmenu - HTML.&More\.\.\..Quoted\ Text              qu
HTMLmenu nmenu - HTML.&More\.\.\..Quoted\ Text              qu i
HTMLmenu imenu - HTML.&More\.\.\..SPAN                      sn
HTMLmenu vmenu - HTML.&More\.\.\..SPAN                      sn
HTMLmenu nmenu - HTML.&More\.\.\..SPAN                      sn i
HTMLmenu imenu - HTML.&More\.\.\..STYLE\ (Internal\ CSS\)   cs
HTMLmenu vmenu - HTML.&More\.\.\..STYLE\ (Internal\ CSS\)   cs
HTMLmenu nmenu - HTML.&More\.\.\..STYLE\ (Internal\ CSS\)   cs i
HTMLmenu imenu - HTML.&More\.\.\..Linked\ CSS               ls
HTMLmenu vmenu - HTML.&More\.\.\..Linked\ CSS               ls
HTMLmenu nmenu - HTML.&More\.\.\..Linked\ CSS               ls i

g:did_html_menus = true
endif
# ---------------------------------------------------------------------------

# ---- Finalize and Clean Up: ------------------------------------------- {{{1

g:doing_internal_html_mappings = false

# Try to reduce support requests from users: {{{
if ! exists('g:did_html_plugin_warning_check')
  g:did_html_plugin_warning_check = true
  var pluginfiles: list<string>
  pluginfiles = 'ftplugin/html/HTML.vim'->findfile(&rtp, -1)
  if pluginfiles->len() > 1
    var pluginfilesmatched: list<string>
    pluginfilesmatched = pluginfiles->g:HTML#FilesWithMatch('https\?://christianrobinson.name/\(programming/\)\?vim/HTML/', 20)
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
