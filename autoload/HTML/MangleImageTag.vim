vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9010509
  finish
endif

# MangleImageTag.Update() - updates an <IMG>'s WIDTH and HEIGHT attributes.
#
# Last Change: June 20, 2024
#
# Requirements:
#   Vim 9.1.219 or later
# Assumptions:
#   The filename extension is correct for the image type
#
# Copyright © 1998-2024 Christian J. Robinson <heptite(at)gmail(dot)com>
#
# Based on "mangleImageTag" by Devin Weaver <ktohg(at)tritarget(dot)com>
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

import autoload 'HTML/Messages.vim'

export class MangleImageTag

  var HTMLMessagesO: Messages.HTMLMessages

  def new()
    this.HTMLMessagesO = Messages.HTMLMessages.new()
  enddef

  def Update(): bool  # {{{1
    var start_linenr: number
    var end_linenr: number
    var col: number
    var line: string

    # Find out if we're inside an <img ...> tag, and get its first line, etc.:
    [start_linenr, col] = searchpairpos('<', '', '>', 'bnW')
    end_linenr = start_linenr
    line = getline(start_linenr)

    if line !~? '<img'
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOIMG)
      return false
    endif

    # Get the rest of the tag if we have a partial tag:
    while line =~? '<img\_[^>]*$'
      ++end_linenr
      line = $"{line}\n{getline(end_linenr)}"
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
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOIMG)
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
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_NOSRC)
      return false
    endif

    if src == ''
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_BLANK)
      return false
    elseif !src->filereadable()
      if filereadable($"{expand('%:p:h')}/{src}")
        src = $"{expand('%:p:h')}/{src}"
      else
        printf(this.HTMLMessagesO.E_NOIMAGE, src)->this.HTMLMessagesO.Error()
        return false
      endif
    endif

    var size = this.ImageSize(src)
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
    var ext = image->fnamemodify(':e')->tolower()
    var size: list<number>
    var buf: list<number>

    if ['png', 'gif', 'jpg', 'jpeg', 'tif', 'tiff', 'webp']->match(ext) < 0
      printf(this.HTMLMessagesO.E_UNSUPPORTED, ext)->this.HTMLMessagesO.Error()
      return []
    elseif !image->filereadable()
      printf(this.HTMLMessagesO.E_NOIMGREAD, image)->this.HTMLMessagesO.Error()
      return []
    endif

    # Read the image and convert it to a list of numbers:
    buf = image->readblob()->blob2list()

    if ext == 'png'
      size = buf->this.SizePng()
    elseif ext == 'gif'
      size = buf->this.SizeGif()
    elseif ext == 'jpg' || ext == 'jpeg'
      size = buf->this.SizeJpeg()
    elseif ext == 'tif' || ext == 'tiff'
      size = buf->this.SizeTiff()
    elseif ext == 'webp'
      size = buf->this.SizeWebP()
    endif

    return size
  enddef

  def SizeGif(buf: list<number>): list<number>  # {{{1
    var i = 0
    var len = buf->len()

    while i < len
      if buf[i : i + 9]->join(' ') =~ '^71 73 70\%( \d\+\)\{7}'
        var width = buf[i + 6 : i + 7]->reverse()->this.Vec()
        var height = buf[i + 8 : i + 9]->reverse()->this.Vec()

        return [width, height]
      endif

      ++i
    endwhile

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_GIF)

    return []
  enddef

  def SizeJpeg(buf: list<number>): list<number>  # {{{1
    var i = 0
    var len = buf->len()

    while i < len
      if buf[i : i + 8]->join(' ') =~ '^255 192\%( \d\+\)\{7}'
        var height = buf[i + 5 : i + 6]->this.Vec()
        var width = buf[i + 7 : i + 8]->this.Vec()

        return [width, height]
      endif

      ++i
    endwhile

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_JPG)

    return []
  enddef

  def SizePng(buf: list<number>): list<number>  # {{{1
    var i = 0
    var len = buf->len()

    while i < len
      if buf[i : i + 11]->join(' ') =~ '^73 72 68 82\%( \d\+\)\{8}'
        var width = buf[i + 4 : i + 7]->this.Vec()
        var height = buf[i + 8 : i + 11]->this.Vec()

        return [width, height]
      endif

      ++i
    endwhile

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_PNG)

    return []
  enddef

  def SizeTiff(buf: list<number>): list<number>  # {{{1
    var i: number
    var j: number
    var len = buf->len()
    var width = -1
    var height = -1
    var bigendian: bool
    var type: number

    if buf[0 : 1]->join(' ') == '73 73'
      #echomsg "TIFF is Little Endian"
      bigendian = false
    elseif buf[0 : 1]->join(' ') == '77 77'
      #echomsg "TIFF is Big Endian"
      bigendian = true
    else
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_TIFFENDIAN)
      return []
    endif

    if (bigendian ? buf[2 : 3]->this.Vec() : buf[2 : 3]->reverse()->this.Vec()) != 42
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_TIFFID)
      return []
    endif

    i = bigendian ? buf[4 : 7]->this.Vec() : buf[4 : 7]->reverse()->this.Vec()
    j = bigendian ? buf[i : i + 1]->this.Vec() : buf[i : i + 1]->reverse()->this.Vec()
    i += 2

    while i < len
      type = bigendian ? buf[i : i + 1]->this.Vec() : buf[i : i + 1]->reverse()->this.Vec()

      if type == 0x100
        width = bigendian ? buf[i + 8 : i + 11]->this.Vec() : buf[i + 8 : i + 11]->reverse()->this.Vec()
      elseif type == 0x101
        height = bigendian ? buf[i + 8 : i + 11]->this.Vec() : buf[i + 8 : i + 11]->reverse()->this.Vec()
      endif

      if width > 0 && height > 0
        return [width, height]
      endif

      i += 12

      if j == 0
        i = bigendian ? buf[i + 4 : i + 7]->this.Vec() : buf[i + 4 : i + 7]->reverse()->this.Vec()
        j = bigendian ? buf[i : i + 1]->this.Vec() : buf[i : i + 1]->reverse()->this.Vec()
        i += 2
      else
        --j
      endif
    endwhile

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_TIFF)

    return []
  enddef

  def SizeWebP(buf: list<number>): list<number>  # {{{1
    var i = 0
    var len = buf->len()

    if buf[0 : 11]->join(' ') !~ '^82 73 70 70\%( \d\+\)\{4} 87 69 66 80'
      this.HTMLMessagesO.Error(this.HTMLMessagesO.E_WEBP)
      return []
    endif

    i += 12

    while i < len
      if buf[i : i + 3]->join(' ') =~ '^86 80 56 \d\+'
        i += 14
        var width = and(buf[i : i + 1]->reverse()->this.Vec(), 0x3fff)
        var height = and(buf[i + 2 : i + 3]->reverse()->this.Vec(), 0x3fff)

        return [width, height]
      endif

      ++i
    endwhile

    this.HTMLMessagesO.Error(this.HTMLMessagesO.E_WEBP)

    return []
  enddef

  def Vec(numbers: list<number>): number  # {{{1
    var n = 0
    numbers->mapnew(
      (_, i): void => {
        n = n * 256 + i
      }
    )
    return n
  enddef

  # }}}1

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=2:comments=b\:#:commentstring=\ #\ %s:
