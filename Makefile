VIM       = $(shell zsh -c 'whence vim8 || whence vim')
TMPDIR   ?= /usr/tmp
bitmaps  := bitmaps
allxpm   := $(wildcard $(bitmaps)/*.xpm)
allbmp   := $(allxpm:.xpm=.bmp)
#docdir   := $(HOME)/.vim/doc
#faq      := $(HOME)/html/web_page/vim/HTML/faq.shtml
#textfaq  := $(faq:%shtml=%)txt
tmpdir   := $(shell mktemp -du $(TMPDIR)/make-tmp.XXXXXX)
savecwd  := $(shell pwd)
vim2html := $(shell find $(HOME)/share/vim -name vim2html.pl | tail -1)
vim2html := $(or $(vim2html),false)

#RCS_FILES_IN = $(wildcard RCS/*,v)
#RCS_FILES = $(RCS_FILES_IN:RCS/%,v=%)

PLUGIN_FILES = browser_launcher.vim browser_launcher_vim9.vim HTML.txt HTML.vim MangleImageTag.vim MangleImageTag_vim9.vim

.PHONY : default debug all force html.zip html.html bitmaps pixmaps changelog

default:
	@echo "Choose a specific target:"
	@echo "  HTML.zip"
	@echo "  bitmaps, pixmaps, or vim-html-pixmaps"
	@echo "  vim-html-pixmaps.zip"
	@echo "  montage, toolbar-icons, or toolbar-icons.png"
	@echo "  ChangeLog, ChangeLog.html"
	@echo "  HTML.html or html"
	@echo "  version"
#	@echo "  FAQ or faq"
	@echo ""
	@echo "  \"all\" will do all of the above."
	@echo "  \"debug\" will show some debugging info."
	@echo "  \"scp\" will rsync all the files to the webserver."
	@echo "        (This DOES NOT do \"make all\" first!"
	@echo "  \"install\" will put some, but not all of the files"
	@echo "            in the appropriate locations"

debug:
	@echo "\$$(VIM)        = $(VIM)"
	@echo "\$$(TMPDIR)     = $(TMPDIR)"
	@echo "\$${bitmaps}    = ${bitmaps}"
	@echo "\$$(allxpm)     = $(allxpm)"
	@echo "\$$(allbmp)     = $(allbmp)"
#	@echo "\$${docdir}     = ${docdir}"
#	@echo "\$${faq}        = ${faq}"
#	@echo "\$${textfaq}    = ${textfaq}"
	@echo "\$${tmpdir}     = ${tmpdir}"
	@echo "\$${savecwd}    = ${savecwd}"
	@echo "\$${vim2html}   = ${vim2html}"
#	@echo "\$$(RCS_FILES)  = $(RCS_FILES)"

all: ChangeLog.html HTML.html HTML.zip \
	bitmaps vim-html-pixmaps.zip toolbar-icons.png \
	version

# $(RCS_FILES):
# 	co $@

version: HTML.vim
	rm -f version
	fgrep 'Version: ' HTML.vim | awk '{ORS=""; print $$3}' > version
	chmod a+r version

zip html.zip: HTML.zip

#HTML.zip: $(RCS_FILES) $(allxpm) $(allbmp)
HTML.zip: $(PLUGIN_FILES) $(allxpm) $(allbmp)
	rm -f HTML.zip
	mkdir -p ${tmpdir}/bitmaps ${tmpdir}/ftplugin/html ${tmpdir}/doc
	cp ${bitmaps}/* ${tmpdir}/bitmaps
	cp HTML.vim ${tmpdir}/ftplugin/html
	cp browser_launcher.vim browser_launcher_vim9.vim ${tmpdir}
	cp MangleImageTag.vim MangleImageTag_vim9.vim ${tmpdir}
	cp HTML.txt ${tmpdir}/doc
	cd ${tmpdir}; zip -9mr ${savecwd}/HTML.zip *
	rmdir ${tmpdir}
	chmod a+r HTML.zip

html HTML html.html: HTML.html

HTML.html: HTML.txt tags
	rm -f HTML.html
	$(vim2html) tags HTML.txt
	perl -p -i -e 's#<link rel="stylesheet" href="([^"]+)" type="text/css">#open(F,$$1); join("", "<style type=\"text/css\">\n<!--\n", <F>, "-->\n</style>")#e;unlink $$1' HTML.html
	chmod a+r HTML.html

tags: HTML.txt
	vim -c "helptags ." -c "qa" > /dev/null 2> /dev/null

%.bmp: %.xpm
	convert $< -background '#c0c0c0' -flatten -colors 16 PPM:- | ppmtobmp > $@

bitmaps pixmaps vim-html-pixmaps: $(allxpm) $(allbmp)

montage toolbar-icons toolbar-icons.png: ${bitmaps}/*
	montage -geometry '50x30>' -tile 8x8 -borderwidth 2 \
		$(shell zsh -c 'for i in ${bitmaps}/*.xpm; \
		do; echo -label $${$${i%.xpm}##*/} $$i; done') \
		toolbar-icons.png
	chmod a+r toolbar-icons.png

vim-html-pixmaps.zip: $(allxpm) $(allbmp)
	rm -f vim-html-pixmaps.zip
	zip -9j vim-html-pixmaps.zip ${bitmaps}/*
	chmod a+r vim-html-pixmaps.zip

changelog: ChangeLog

#ChangeLog: $(RCS_FILES) ChangeLog-base
#	rm -f ChangeLog
#	rcs2log -R -u 'infynity	Christian J. Robinson	heptite at gmail dot com' \
#		-u 'Heptite	Christian J. Robinson	heptite at gmail dot com' \
#		| perl -ne 's/^\t/ /g; $$ate=0, print "\n" if $$ate && m/^\S/; if ($$eat) { $$eat = $$ate = 0; $$_ = "", $$ate=1 if m/^\s*$$/; } $$eat=1 if m/^ \* |^\s*$$/; print'\
#		> ChangeLog
#	cat ChangeLog-base >> ChangeLog
#	chmod a+r ChangeLog

ChangeLog: $(PLUGIN_FILES) ChangeLog-base
	rm -f ChangeLog
	git log --no-merges --format=%aD\ %an%n\ \*\ %B > ChangeLog
	cat ChangeLog-base >> ChangeLog
	chmod a+r ChangeLog


changelog.html: ChangeLog.html

ChangeLog.html: ChangeLog
	rm -f ChangeLog.html
	${VIM} -gf --noplugin -c 'if has("gui_running") | stop | endif' \
		-c 'highlight Normal guibg=white | highlight Constant guibg=white' \
		-c 'highlight link changelogError ignore' \
		-c 'autocmd FileType html syntax clear' \
		-c 'runtime syntax/2html.vim' \
		-c '%s/^<title>.*ChangeLog.html/<title>ChangeLog/' \
		-c '%s/^<style>$$/<meta name="viewport" content="width=device-width, initial-scale=1.0">\r<style>/' \
		-c 'w ChangeLog.html' -c 'qa!' ChangeLog
	chmod a+r ChangeLog.html


rsync scp:
	@echo "WARNING! This does NOT make sure the various files are updated, do \"make all\" first!"
	@echo
	rsync --verbose --archive --times --rsh=ssh --stats --progress \
		bitmaps browser_launcher.vim browser_launcher_vim9.vim \
		MangleImageTag.vim MangleImageTag_vim9.vim HTML.vim \
		HTML.txt HTML.html HTML.zip version ChangeLog ChangeLog.html \
		toolbar-icons.png vim-html-pixmaps.zip \
		pi@heptite.localnet:~/www/programming/vim/HTML/

install: HTML.vim HTML.txt browser_launcher.vim browser_launcher_vim9.vim MangleImageTag.vim MangleImageTag_vim9.vim
	cp -f HTML.vim ~/.vim/ftplugin/html/
	cp -f HTML.txt ~/.vim/doc/
	cp -f browser_launcher.vim ~/.vim/
	cp -f browser_launcher_vim9.vim ~/.vim/
	cp -f MangleImageTag.vim ~/.vim/
	cp -f MangleImageTag_vim9.vim ~/.vim/
	cp -f HTML.vim ~/Dropbox/vimfiles/ftplugin/html/
	cp -f HTML.txt ~/Dropbox/vimfiles/doc/
	cp -f browser_launcher.vim ~/Dropbox/vimfiles/
	cp -f browser_launcher_vim9.vim ~/Dropbox/vimfiles/
	cp -f MangleImageTag.vim ~/Dropbox/vimfiles/
	cp -f MangleImageTag_vim9.vim ~/Dropbox/vimfiles/
	vim -c 'helptags ~/.vim/doc' -c 'helptags ~/Dropbox/vimfiles/doc' -c 'qa' > /dev/null 2> /dev/null


#faq FAQ: $(textfaq)

#$(textfaq): $(faq)
#	w3m -T text/html -cols 79 -dump ${faq} | unix2dos > $(textfaq)
#	chmod a+r ${textfaq}

force:

# vim:ts=4:sw=4:fdm=indent:fdn=1:
