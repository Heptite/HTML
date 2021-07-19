VIM       = $(shell zsh -c 'whence vim9 || whence vim')
TMPDIR   ?= /usr/tmp
bitmaps  := cjr/start/HTML/bitmaps
allxpm   := $(wildcard $(bitmaps)/*.xpm)
allbmp   := $(allxpm:.xpm=.bmp)
#faq      := $(HOME)/www/programming/vim/HTML/faq.shtml
#textfaq  := $(faq:%shtml=%)txt
tmpdir   := $(shell mktemp -du $(TMPDIR)/make-tmp.XXXXXX)
savecwd  := $(shell pwd)
vim2html := $(shell find $(HOME)/share/vim -name vim2html.pl | tail -1)
vim2html := $(or $(vim2html),false)

PLUGIN_FILES = cjr/start/HTML/doc/HTML.txt cjr/start/HTML/ftplugin/html/HTML.vim cjr/start/HTML/autoload/BrowserLauncher.vim cjr/start/HTML/autoload/MangleImageTag.vim cjr/start/HTML/autoload/HTML.vim

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
	@echo "\$$(VIM)           = $(VIM)"
	@echo "\$$(TMPDIR)        = $(TMPDIR)"
	@echo "\$${bitmaps}       = ${bitmaps}"
	@echo "\$$(allxpm)        = $(allxpm)"
	@echo "\$$(allbmp)        = $(allbmp)"
#	@echo "\$${faq}           = ${faq}"
#	@echo "\$${textfaq}       = ${textfaq}"
	@echo "\$${tmpdir}        = ${tmpdir}"
	@echo "\$${savecwd}       = ${savecwd}"
	@echo "\$${vim2html}      = ${vim2html}"
	@echo "\$$(PLUGIN_FILES)  = $(PLUGIN_FILES)"

all: ChangeLog ChangeLog.html HTML.html HTML.zip bitmaps vim-html-pixmaps.zip toolbar-icons.png version

version: cjr/start/HTML/ftplugin/html/HTML.vim
	rm -f version
	fgrep 'Version: ' cjr/start/HTML/ftplugin/html/HTML.vim | awk '{ORS=""; print $$3}' > version
	chmod a+r version

zip html.zip: HTML.zip

HTML.zip: $(PLUGIN_FILES) $(allxpm) $(allbmp) tags
	rm -f HTML.zip
	mkdir -p ${tmpdir}/pack/cjr/start/HTML/bitmaps ${tmpdir}/pack/cjr/start/HTML/ftplugin/html \
		${tmpdir}/pack/cjr/start/HTML/doc ${tmpdir}/pack/cjr/start/HTML/autoload
	cp ${bitmaps}/* ${tmpdir}/pack/cjr/start/HTML/bitmaps/
	cp cjr/start/HTML/ftplugin/html/HTML.vim ${tmpdir}/pack/cjr/start/HTML/ftplugin/html/
	cp cjr/start/HTML/autoload/BrowserLauncher.vim cjr/start/HTML/autoload/MangleImageTag.vim \
		cjr/start/HTML/autoload/HTML.vim ${tmpdir}/pack/cjr/start/HTML/autoload/
	cp cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/tags cjr/start/HTML/doc/gpl-3.0.html \
		cjr/start/HTML/doc/gpl-3.0.txt ${tmpdir}/pack/cjr/start/HTML/doc/
	chmod -R a+rX ${tmpdir}
	cd ${tmpdir}; zip -9mr ${savecwd}/HTML.zip *
	rmdir ${tmpdir}
	chmod a+r HTML.zip

html HTML html.html: HTML.html

HTML.html: cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/tags
	rm -f HTML.html
	$(vim2html) cjr/start/HTML/doc/tags cjr/start/HTML/doc/HTML.txt
	perl -p -i -e 's#<link rel="stylesheet" href="([^"]+)" type="text/css">#open(F,$$1); join("", "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n<style type=\"text/css\">\n<!--\n", <F>, "-->\n</style>")#e && unlink $$1' HTML.html
	chmod a+r HTML.html

tags: cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/gpl-3.0.txt
	vim -c "helptags cjr/start/HTML/doc/" -c "qa" > /dev/null 2> /dev/null
	chmod a+r cjr/start/HTML/doc/tags

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
		cjr/start/HTML/bitmaps BrowserLauncher.vim MangleImageTag.vim HTML.vim \
		HTML.vim HTML.txt HTML.html HTML.zip version ChangeLog ChangeLog.html \
		toolbar-icons.png vim-html-pixmaps.zip \
		pi@heptite.localnet:~/www/programming/vim/HTML/

install: cjr/start/HTML/ftplugin/html/HTML.vim cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/tags cjr/start/HTML/autoload/BrowserLauncher.vim cjr/start/HTML/autoload/MangleImageTag.vim cjr/start/HTML/autoload/HTML.vim
	cp -f cjr/start/HTML/ftplugin/html/HTML.vim ~/.vim/pack/cjr/start/HTML/ftplugin/html/
	cp -f cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/tags ~/.vim/pack/cjr/start/HTML/doc/
	cp -f cjr/start/HTML/autoload/BrowserLauncher.vim cjr/start/HTML/autoload/MangleImageTag.vim \
		cjr/start/HTML/autoload/HTML.vim ~/.vim/pack/cjr/start/HTML/autoload/
	cp -f cjr/start/HTML/ftplugin/html/HTML.vim ~/Dropbox/vimfiles/pack/cjr/start/HTML/ftplugin/html/
	cp -f cjr/start/HTML/doc/HTML.txt cjr/start/HTML/doc/tags ~/Dropbox/vimfiles/pack/cjr/start/HTML/doc/
	cp -f cjr/start/HTML/autoload/BrowserLauncher.vim cjr/start/HTML/autoload/MangleImageTag.vim \
		cjr/start/HTML/autoload/HTML.vim ~/Dropbox/vimfiles/pack/cjr/start/HTML/autoload/


#faq FAQ: $(textfaq)

#$(textfaq): $(faq)
#	w3m -T text/html -cols 79 -dump ${faq} | unix2dos > $(textfaq)
#	chmod a+r ${textfaq}

force:

# vim:ts=4:sw=0:fdm=indent:fdn=1:fdc=2:
