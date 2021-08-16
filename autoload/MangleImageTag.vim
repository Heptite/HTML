vim9script
scriptencoding utf8

if v:version < 802 || v:versionlong < 8023316
  finish
endif

# MangleImageTag#Update() - updates an <IMG>'s WIDTH and HEIGHT tags.
#
# Last Change: August 14, 2021
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 2004-2021 Christian J. Robinson <heptite@gmail.com>
#
# Based on "mangleImageTag" by Devin Weaver <ktohg@tritarget.com>
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

if exists(':HTMLERROR') != 2  # {{{1
  command! -nargs=+ HTMLERROR {
      echohl ErrorMsg
      echomsg <q-args>
      echohl None
    }
endif  # }}}1

def MangleImageTag#Update(): bool  # {{{1
  var start_linenr: number
  var end_linenr: number
  var col: number
  var line: string

  # Find out if we're inside an <img ...> tag, and get its first line, etc.:
  [start_linenr, col] = searchpairpos('<', '', '>', 'bnW')
  end_linenr = start_linenr
  line = getline(start_linenr)

  if line !~? '<img'
    HTMLERROR The cursor is not on an IMG tag.
    return false
  endif

  # Get the rest of the tag if we have a partial tag:
  while line =~? '<img\_[^>]*$'
    end_linenr += 1
    line = line .. "\n" .. getline(end_linenr)
  endwhile

  # Make sure we modify the right tag if more than one is on the line:
  var tagstart: number
  if line[col] == '<'
    tagstart = col
  else
    var tmp = line->strpart(0, col)
    tagstart = tmp->strridx('<')
  endif
  var savestart = line->strpart(0, tagstart)
  var tag = line->strpart(tagstart)
  var tagend = tag->stridx('>') + 1
  var saveend = tag->strpart(tagend)
  tag = tag->strpart(0, tagend)

  if tag[0] != '<' || col > strlen(savestart .. tag) - 1
    HTMLERROR The cursor is not on an IMG tag.
    return false
  endif

  var case: bool
  var src: string
  if tag =~? 'src=\(".\{-}"\|''.\{-}''\)'
    src = tag->substitute('.\{-}src=\(["'']\)\(.\{-}\)\1.*', '\2', '')
    if tag =~# 'src'
      case = false
    else
      case = true
    endif
  else
    HTMLERROR Image SRC not specified in the tag.
    return false
  endif

  if ! src->filereadable()
    if filereadable(expand('%:p:h') .. '/' .. src)
      src = expand('%:p:h') .. '/' .. src
    else
      execute 'HTMLERROR Can not find image file (or it is not readable): ' .. src
      return false
    endif
  endif

  var size = ImageSize(src)
  if size->len() != 2
    return false
  endif

  if tag =~? 'height=\("\d\+"\|''\d\+''\|\d\+\)'
    tag = tag->substitute(
      '\c\(height=\)\(["'']\=\)\d\+\2',
      '\1\2' .. size[1] .. '\2', '')
  else
    tag = tag->substitute(
      '\csrc=\(["'']\).\{-}\1',
      '\0 ' .. (case ? 'HEIGHT' : 'height') .. '="' .. size[1] .. '"', '')
  endif

  if tag =~? 'width=\("\d\+"\|''\d\+''\|\d\+\)'
    tag = tag->substitute(
      '\c\(width=\)\(["'']\=\)\d\+\2',
      '\1\2' .. size[0] .. '\2', '')
  else
    tag = tag->substitute(
      '\csrc=\(["'']\).\{-}\1',
      '\0 ' .. (case ? 'WIDTH' : 'width') .. '="' .. size[0] .. '"', '')
  endif

  line = savestart .. tag .. saveend

  line->split("\n")->setline(start_linenr)

  return true
enddef

def ImageSize(image: string): list<number>  # {{{1
  var ext = image->fnamemodify(':e')
  var size: list<number>

  if ext !~? '^png$\|^gif$\|^jpe\?g$'
    execute 'HTMLERROR Image type not supported: ' .. tolower(ext)
    return []
  endif

  if filereadable(image) == 1
    var buf: list<number>
    var i = 0

    # Note that the 1024 here is not bytes, but lines,
    # whereas below the 1024 IS bytes:
    for line in image->readfile('b', 1024)
      var string = line->split('\zs')
      for c in string
        var char = c->char2nr()
        buf->add((char == 10 ? 0 : char))

        # Keep the script from being too slow, but could cause a JPG
        # (and GIF/PNG?) to return as "malformed":
        i += 1
        if i > 1024 * 8
          break
        endif
      endfor
      buf->add(10)
    endfor

    if ext ==? 'png'
      size = buf->SizePng()
    elseif ext ==? 'gif'
      size = buf->SizeGif()
    elseif ext ==? 'jpg' || ext ==? 'jpeg'
      size = buf->SizeJpg()
    endif
  else
    execute 'HTMLERROR Can not read file: ' .. image
    return []
  endif

  return size
enddef

def SizeGif(lines: list<number>): list<number>  # {{{1
  var i = 0
  var len = lines->len()

  while i <= len
    if lines[i : i + 9]->join(' ') =~ '^71 73 70\%( \d\+\)\{7}'
      var width = lines[i + 6 : i + 7]->reverse()->Vec()
      var height = lines[i + 8 : i + 9]->reverse()->Vec()

      return [width, height]
    endif

    i += 1
  endwhile

  HTMLERROR Malformed GIF file.

  return []
enddef

def SizeJpg(lines: list<number>): list<number>  # {{{1
  var i = 0
  var len = lines->len()

  while i <= len
    if lines[i : i + 8]->join(' ') =~ '^255 192\%( \d\+\)\{7}'
      var height = lines[i + 5 : i + 6]->Vec()
      var width = lines[i + 7 : i + 8]->Vec()

      return [width, height]
    endif
    i += 1
  endwhile

  HTMLERROR Malformed JPEG file.

  return []
enddef

def SizePng(lines: list<number>): list<number>  # {{{1
  var i = 0
  var len = lines->len()

  while i <= len
    if lines[i : i + 11]->join(' ') =~ '^73 72 68 82\%( \d\+\)\{8}'
      var width = lines[i + 4 : i + 7]->Vec()
      var height = lines[i + 8 : i + 11]->Vec()

      return [width, height]
    endif
    i += 1
  endwhile

  HTMLERROR Malformed PNG file.

  return []
enddef

def Vec(numbers: list<number>): number  # {{{1
  var n = 0
  numbers->mapnew(
    (_, i) => {
      n = n * 256 + i
      return
    }
  )
  return n
enddef

defcompile

if !exists('g:htmlplugin.function_files') | g:htmlplugin.function_files = [] | endif
add(g:htmlplugin.function_files, expand('<sfile>:p'))->sort()->uniq()

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
