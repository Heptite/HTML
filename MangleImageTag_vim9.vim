vim9script

# MangleImageTag() - updates an <IMG>'s width and height tags.
#
# Requirements:
#       Vim 9 or later
#
# Copyright (C) 2004-2020 Christian J. Robinson <heptite@gmail.com>
#
# Based on "mangleImageTag" by Devin Weaver <ktohg@tritarget.com>
#
# This program is free software; you can  redistribute  it  and/or  modify  it
# under the terms of the GNU General Public License as published by  the  Free
# Software Foundation; either version 2 of the License, or  (at  your  option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but  WITHOUT
# ANY WARRANTY; without  even  the  implied  warranty  of  MERCHANTABILITY  or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General  Public  License  for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA.

if exists("*g:MangleImageTag") # || v:version < 900
    finish
endif

def g:MangleImageTag() # {{{1
    var start_linenr = line('.')
    var end_linenr = start_linenr
    var col = col('.') - 1
    var line = getline(start_linenr)

    if line !~? '<img'
        echohl ErrorMsg
        echomsg "The current line does not contain an image tag (see :help ;mi)."
        echohl None

        return
    endif

    # Get the rest of the tag if we have a partial tag:
    while line =~? '<img\_[^>]*$'
        end_linenr = end_linenr + 1
        line = line .. "\n" .. getline(end_linenr)
    endwhile

    # Make sure we modify the right tag if more than one is on the line:
    var tagstart: number
    if line[col] != '<'
        var tmp = line->strpart(0, col)
        tagstart = tmp->strridx('<')
    else
        tagstart = col
    endif
    var savestart = line->strpart(0, tagstart)
    var tag = line->strpart(tagstart)
    var tagend = tag->stridx('>') + 1
    var saveend = tag->strpart(tagend)
    tag = tag->strpart(0, tagend)

    if tag[0] != '<' || col > strlen(savestart .. tag) - 1
        echohl ErrorMsg
        echomsg "Cursor isn't on an IMG tag."
        echohl None

        return
    endif

    var case: bool
    var src: string
    if tag =~? "src=\\(\".\\{-}\"\\|'.\\{-}\'\\)"
        src = tag->substitute(".\\{-}src=\\([\"']\\)\\(.\\{-}\\)\\1.*", '\2', '')
        if tag =~# 'src'
            case = false
        else
            case = true
        endif
    else
        echohl ErrorMsg
        echomsg "Image src not specified in the tag."
        echohl None

        return
    endif

    if ! src->filereadable()
        if filereadable(expand("%:p:h") .. '/' .. src)
            src = expand("%:p:h") .. '/' .. src
        else
            echohl ErrorMsg
            echomsg "Can't find image file: " .. src
            echohl None

            return
        endif
    endif

    var size = s:ImageSize(src)
    if len(size) != 2
        return
    endif

    if tag =~? "height=\\(\"\\d\\+\"\\|'\\d\\+\'\\|\\d\\+\\)"
        tag = tag->substitute(
            "\\c\\(height=\\)\\([\"']\\=\\)\\(\\d\\+\\)\\(\\2\\)",
            '\1\2' .. size[1] .. '\4', '')
    else
        tag = tag->substitute(
            "\\csrc=\\([\"']\\)\\(.\\{-}\\|.\\{-}\\)\\1",
            '\0 ' .. (case ? 'HEIGHT' : 'height') .. '="' .. size[1] .. '"', '')
    endif

    if tag =~? "width=\\(\"\\d\\+\"\\|'\\d\\+\'\\|\\d\\+\\)"
        tag = tag->substitute(
            "\\c\\(width=\\)\\([\"']\\=\\)\\(\\d\\+\\)\\(\\2\\)",
            '\1\2' .. size[0] .. '\4', '')
    else
        tag = tag->substitute(
            "\\csrc=\\([\"']\\)\\(.\\{-}\\|.\\{-}\\)\\1",
            '\0 ' .. (case ? 'WIDTH' : 'width') .. '="' .. size[0] .. '"', '')
    endif

    line = savestart .. tag .. saveend

    var saveautoindent = &autoindent
    &autoindent = 0

    call line->split("\n")->setline(start_linenr)

    &autoindent = saveautoindent
enddef

def s:ImageSize(image: string): list<number> # {{{1
    var ext = fnamemodify(image, ':e')
    var size: list<number>

    if ext !~? 'png\|gif\|jpe\?g'
        echohl ErrorMsg
        echomsg "Image type not recognized: " .. tolower(ext)
        echohl None

        return []
    endif

    if filereadable(image) == 1
        var buf = readfile(image, 'b', 1024)
        var buf2: list<number>

        var i = 0
        for l in buf
            var string = split(l, '\zs')
            for c in string
                var char = char2nr(c)
                eval buf2->add((char == 10 ? 0 : char))

                # Keep the script from being too slow, but could cause a JPG
                # (and GIF/PNG?) to return as "malformed":
                i += 1
                if i > 1024 * 8
                    break
                endif
            endfor
            eval buf2->add(10)
        endfor

        if ext ==? 'png'
            size = buf2->s:SizePng()
        elseif ext ==? 'gif'
            size = buf2->s:SizeGif()
        elseif ext ==? 'jpg' || ext ==? 'jpeg'
            size = buf2->s:SizeJpg()
        endif
    else
        echohl ErrorMsg
        echomsg "Can't read file: " .. image
        echohl None

        return []
    endif

    return size
enddef

def s:SizeGif(lines: list<number>): list<number> # {{{1
    var i = 0
    var len = len(lines)

    while i <= len
        if join(lines[i : i + 9], ' ') =~ '^71 73 70\( \d\+\)\{7}'
            var width = lines[i + 6 : i + 7]->reverse()->s:Vec()
            var height = lines[i + 8 : i + 9]->reverse()->s:Vec()

            return [width, height]
        endif

        i += 1
    endwhile

    echohl ErrorMsg
    echomsg "Malformed GIF file."
    echohl None

    return []
enddef

def s:SizeJpg(lines: list<number>): list<number> # {{{1
    var i = 0
    var len = len(lines)

    while i <= len
        if join(lines[i : i + 8], ' ') =~ '^255 192\( \d\+\)\{7}'
            var height = s:Vec(lines[i + 5 : i + 6])
            var width = s:Vec(lines[i + 7 : i + 8])

            return [width, height]
        endif
        i += 1
    endwhile

    echohl ErrorMsg
    echomsg "Malformed JPEG file."
    echohl None

    return []
enddef

def s:SizePng(lines: list<number>): list<number> # {{{1
    var i = 0
    var len = len(lines)

    while i <= len
        if join(lines[i : i + 11], ' ') =~ '^73 72 68 82\( \d\+\)\{8}'
            var width = s:Vec(lines[i + 4 : i + 7])
            var height = s:Vec(lines[i + 8 : i + 11])

            return [width, height]
        endif
        i += 1
    endwhile

    echohl ErrorMsg
    echomsg "Malformed PNG file."
    echohl None

    return []
enddef

def s:Vec(nums: list<number>): number # {{{1
    var n = 0
    for i in nums
        n = n * 256 + i
    endfor
    return n
enddef

# vim:ts=4:sw=0:et:fdm=marker:fdc=2:cms=\ #\ %s:
