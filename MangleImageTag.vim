" MangleImageTag() - updates an <IMG>'s width and height tags.
"
" Requirements:
"       VIM 8 or later
"
" Copyright (C) 2004-2020 Christian J. Robinson <heptite@gmail.com>
"
" Based on "mangleImageTag" by Devin Weaver <ktohg@tritarget.com>
"
" This program is free software; you can  redistribute  it  and/or  modify  it
" under the terms of the GNU General Public License as published by  the  Free
" Software Foundation; either version 2 of the License, or  (at  your  option)
" any later version.
"
" This program is distributed in the hope that it will be useful, but  WITHOUT
" ANY WARRANTY; without  even  the  implied  warranty  of  MERCHANTABILITY  or
" FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General  Public  License  for
" more details.
"
" You should have received a copy of the GNU General Public License along with
" this program; if not, write to the Free Software Foundation, Inc., 59 Temple
" Place - Suite 330, Boston, MA 02111-1307, USA.

if v:version < 800 || exists("*MangleImageTag")
	finish
endif

function! MangleImageTag() "{{{1
	let l:start_linenr = line('.')
	let l:end_linenr = l:start_linenr
	let l:col = col('.') - 1
	let l:line = getline(l:start_linenr)

	if l:line !~? '<img'
		echohl ErrorMsg
		echomsg "The current line does not contain an image tag (see :help ;mi)."
		echohl None

		return
	endif

	" Get the rest of the tag if we have a partial tag:
	while l:line =~? '<img\_[^>]*$'
		let l:end_linenr = l:end_linenr + 1
		let l:line = l:line . "\n" . getline(l:end_linenr)
	endwhile

	" Make sure we modify the right tag if more than one is on the line:
	if l:line[col] != '<'
		let l:tmp = l:line->strpart(0, l:col)
		let l:tagstart = l:tmp->strridx('<')
	else
		let l:tagstart = l:col
	endif
	let l:savestart = l:line->strpart(0, l:tagstart)
	let l:tag = l:line->strpart(l:tagstart)
	let l:tagend = l:tag->stridx('>') + 1
	let l:saveend = l:tag->strpart(l:tagend)
	let l:tag = l:tag->strpart(0, l:tagend)

	if l:tag[0] != '<' || l:col > strlen(l:savestart . l:tag) - 1
		echohl ErrorMsg
		echomsg "Cursor isn't on an IMG tag."
		echohl None

		return
	endif

	if l:tag =~? "src=\\(\".\\{-}\"\\|'.\\{-}\'\\)"
		let l:src = l:tag->substitute(".\\{-}src=\\([\"']\\)\\(.\\{-}\\)\\1.*", '\2', '')
		if l:tag =~# 'src'
			let l:case = 0
		else
			let l:case = 1
		endif
	else
		echohl ErrorMsg
		echomsg "Image src not specified in the tag."
		echohl None

		return
	endif

	if ! filereadable(l:src)
		if filereadable(expand("%:p:h") . '/' . l:src)
			let l:src = expand("%:p:h") . '/' . l:src
		else
			echohl ErrorMsg
			echomsg "Can't find image file: " . l:src
			echohl None

			return
		endif
	endif

	let l:size = s:ImageSize(l:src)
	if len(l:size) != 2
		return
	endif

	if tag =~? "height=\\(\"\\d\\+\"\\|'\\d\\+\'\\|\\d\\+\\)"
		let l:tag = l:tag->substitute(
			\ "\\c\\(height=\\)\\([\"']\\=\\)\\(\\d\\+\\)\\(\\2\\)",
			\ '\1\2' . l:size[1] . '\4', '')
	else
		let l:tag = l:tag->substitute(
			\ "\\csrc=\\([\"']\\)\\(.\\{-}\\|.\\{-}\\)\\1",
			\ '\0 ' . (l:case ? 'HEIGHT' : 'height') . '="' . l:size[1] . '"', '')
	endif

	if l:tag =~? "width=\\(\"\\d\\+\"\\|'\\d\\+\'\\|\\d\\+\\)"
		let l:tag = l:tag->substitute(
			\ "\\c\\(width=\\)\\([\"']\\=\\)\\(\\d\\+\\)\\(\\2\\)",
			\ '\1\2' . l:size[0] . '\4', '')
	else
		let l:tag = l:tag->substitute(
			\ "\\csrc=\\([\"']\\)\\(.\\{-}\\|.\\{-}\\)\\1",
			\ '\0 ' . (l:case ? 'WIDTH' : 'width') . '="' . l:size[0] . '"', '')
	endif

	let l:line = l:savestart . l:tag . l:saveend

	let saveautoindent=&autoindent
	let &l:autoindent=0

	call split(l:line, "\n")->setline(l:start_linenr)

	let &l:autoindent=saveautoindent
endfunction

function! s:ImageSize(image) "{{{1
	let l:ext = fnamemodify(a:image, ':e')

	if l:ext !~? 'png\|gif\|jpe\?g'
		echohl ErrorMsg
		echomsg "Image type not recognized: " . tolower(l:ext)
		echohl None

		return
	endif

	if filereadable(a:image)
		let l:ldsave=&lazyredraw
		set lazyredraw

		let l:buf=readfile(a:image, 'b', 1024)
		let l:buf2=[]

		let l:i=0
		for l:l in l:buf
			let l:string = split(l:l, '\zs')
			for l:c in l:string
				let l:char = char2nr(l:c)
				eval l:buf2->add((l:char == 10 ? '0' : l:char))

				" Keep the script from being too slow, but could cause a JPG
				" (and GIF/PNG?) to return as "malformed":
				let l:i+=1
				if l:i > 1024 * 4
					break
				endif
			endfor
			eval l:buf2->add('10')
		endfor

		if l:ext ==? 'png'
			let l:size = l:buf2->s:SizePng()
		elseif l:ext ==? 'gif'
			let l:size = l:buf2->s:SizeGif()
		elseif l:ext ==? 'jpg' || ext ==? 'jpeg'
			let l:size = l:buf2->s:SizeJpg()
		endif
	else
		echohl ErrorMsg
		echomsg "Can't read file: " . a:image
		echohl None

		return
	endif

	return l:size
endfunction

function! s:SizeGif(lines) "{{{1
	let l:i = 0
	let l:len = len(a:lines)

	while l:i <= l:len
		if join(a:lines[l:i : l:i+9], ' ') =~ '^71 73 70\( \d\+\)\{7}'
			let l:width = a:lines[l:i+6 : l:i+7]->reverse()->s:Vec()
			let l:height = a:lines[l:i+8 : l:i+9]->reverse()->s:Vec()

			return [l:width, l:height]
		endif

		let l:i += 1
	endwhile

	echohl ErrorMsg
	echomsg "Malformed GIF file."
	echohl None

	return
endfunction

function! s:SizeJpg(lines) "{{{1
	let l:i=0
	let l:len=len(a:lines)

	while l:i <= len
		if join(a:lines[l:i : l:i+8], ' ') =~ '^255 192\( \d\+\)\{7}'
			let l:height = s:Vec(a:lines[l:i+5 : l:i+6])
			let l:width = s:Vec(a:lines[l:i+7 : l:i+8])

			return [l:width, l:height]
		endif
		let l:i += 1
	endwhile

	echohl ErrorMsg
	echomsg "Malformed JPEG file."
	echohl None

	return
endfunction

function! s:SizePng(lines) "{{{1
	let l:i=0
	let l:len=len(a:lines)

	while l:i <= len
		if join(a:lines[l:i : l:i+11], ' ') =~ '^73 72 68 82\( \d\+\)\{8}'
			let l:width = s:Vec(a:lines[l:i+4 : l:i+7])
			let l:height = s:Vec(a:lines[l:i+8 : l:i+11])

			return [l:width, l:height]
		endif
		let l:i += 1
	endwhile

	echohl ErrorMsg
	echomsg "Malformed PNG file."
	echohl None

	return
endfunction

function! s:Vec(nums) "{{{1
	let l:n = 0
	for l:i in a:nums
		let l:n = l:n * 256 + l:i
	endfor
	return l:n
endfunction

" vim:ts=4:sw=4:
" vim600:fdm=marker:fdc=2:cms=\ \"%s:
