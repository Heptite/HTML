VIM      ?= $(shell zsh -c 'whence vim9 || whence vim')
VIM      := $(or $(VIM),false)
TMPDIR   ?= /tmp
bitmaps  := bitmaps
allxpm   := $(wildcard $(bitmaps)/*.xpm)
allbmp   := $(allxpm:.xpm=.bmp)
alldoc   := $(wildcard doc/*.txt)
alllang  := $(wildcard lang/*)
#pihome   := pi@christianrobinson.name:~
faq      := $(HOME)/www/website/src/assets/programming/faq.html
textfaq  := $(faq:%html=%)txt
tmpdir   := $(shell mktemp -du $(TMPDIR)/make-tmp.XXXXXX)
savecwd  := $(shell pwd)
vim2html := $(shell find $(HOME)/share/vim -name vim2html.pl | tail -1)
vim2html := $(or $(vim2html),false)

PLUGIN_FILES = ftplugin/html/HTML.vim autoload/HTML/BrowserLauncher.vim autoload/HTML/MangleImageTag.vim autoload/HTML/Messages.vim autoload/HTML/Glue.vim autoload/HTML/Menu.vim autoload/HTML/Map.vim autoload/HTML/Util.vim commands/HTML/Commands.vim import/HTML/Variables.vim json/HTML/entities.json json/HTML/tags.json json/HTML/entitytable.json

.PHONY : default debug all force html.zip html.html bitmaps pixmaps changelog push

define _helptext
cat <<'EOF'
Choose a specific target:
  HTML.zip
  bitmaps, pixmaps, or vim-html-pixmaps
  vim-html-pixmaps.zip
  montage, toolbar-icons, or toolbar-icons.png
  ChangeLog, ChangeLog.html
  tags
  HTML.html or html
  version
  FAQ or faq

  "all" will do all of the above.
  "debug" will show some debugging info.
  "scp" will rsync all the files to the webserver.
  "push" will commit the changes and push them to git.
  "install" will put some, but not all of the files
            in the appropriate locations on the local
            machine, for testing.
  "test" will test (some of) the plugin's functionality
EOF
endef
export HELPTEXT = $(value _helptext)

default:
	@eval "$$HELPTEXT"

debug:
	@echo "\$$(VIM)           = $(VIM)"
	@echo "\$$(TMPDIR)        = $(TMPDIR)"
	@echo "\$${bitmaps}       = ${bitmaps}"
	@echo "\$$(allxpm)        = $(allxpm)"
	@echo "\$$(allbmp)        = $(allbmp)"
	@echo "\$${faq}           = ${faq}"
	@echo "\$${textfaq}       = ${textfaq}"
	@echo "\$${tmpdir}        = ${tmpdir}"
	@echo "\$${savecwd}       = ${savecwd}"
	@echo "\$${vim2html}      = ${vim2html}"
	@echo "\$$(PLUGIN_FILES)  = $(PLUGIN_FILES)"
	@echo "\$$(alldoc)        = $(alldoc)"
	@echo "\$$(alllang)       = $(alllang)"

all: ChangeLog ChangeLog.html HTML.html HTML.zip bitmaps vim-html-pixmaps.zip toolbar-icons.png version

push: pushed

pushed: $(PLUGIN_FILES) $(allxpm) $(allbmp) $(alldoc) $(alllang) ChangeLog README.md version
	-git add .
	-git commit
	-git push
	touch pushed

version: import/HTML/Variables.vim
	rm -f version
	fgrep -m 1 'const VERSION' import/HTML/Variables.vim | awk -F "'" '{ORS=""; print $$2}' > version
	chmod a+r version

zip html.zip: HTML.zip

HTML.zip: $(PLUGIN_FILES) $(allxpm) $(allbmp) $(alldoc) $(alllang) doc/tags
	rm -f HTML.zip
	mkdir -p ${tmpdir}/pack/cjr/start/HTML/bitmaps \
		${tmpdir}/pack/cjr/start/HTML/ftplugin/html \
		${tmpdir}/pack/cjr/start/HTML/doc \
		${tmpdir}/pack/cjr/start/HTML/lang \
		${tmpdir}/pack/cjr/start/HTML/autoload/HTML \
		${tmpdir}/pack/cjr/start/HTML/commands/HTML \
		${tmpdir}/pack/cjr/start/HTML/import/HTML \
		${tmpdir}/pack/cjr/start/HTML/json/HTML
	cp ${bitmaps}/* ${tmpdir}/pack/cjr/start/HTML/bitmaps/
	cp ftplugin/html/*.vim ${tmpdir}/pack/cjr/start/HTML/ftplugin/html/
	cp import/HTML/*.vim ${tmpdir}/pack/cjr/start/HTML/import/HTML/
	cp commands/HTML/*.vim ${tmpdir}/pack/cjr/start/HTML/commands/HTML/
	cp json/HTML/*.json ${tmpdir}/pack/cjr/start/HTML/json/HTML/
	cp autoload/HTML/*.vim ${tmpdir}/pack/cjr/start/HTML/autoload/HTML/
	cp doc/tags doc/gpl-3.0.html ${alldoc} ${tmpdir}/pack/cjr/start/HTML/doc/
	cp ${alllang} ${tmpdir}/pack/cjr/start/HTML/lang/
	chmod -R a+rX ${tmpdir}
	cd ${tmpdir}; zip -9mr ${savecwd}/HTML.zip *
	rmdir ${tmpdir}
	chmod a+r HTML.zip

html HTML html.html: HTML.html

HTML.html: $(alldoc) doc/tags
	rm -f HTML.html
	$(vim2html) doc/tags doc/HTML.txt
	perl -p -i -e 's#<link rel="stylesheet" href="([^"]+)" type="text/css">#open(F,$$1); join("", "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n<style type=\"text/css\">\n<!--\n", <F>, "-->\n</style>")#e && unlink $$1; s#\|(<a href.+?</a>)\|#$$1#g' HTML.html
	chmod a+r HTML.html

tags: doc/tags

doc/tags: $(alldoc)
	vim -c "helptags doc/" -c "qa" > /dev/null 2> /dev/null
	chmod a+r doc/tags

%.bmp: %.xpm
	convert $< -background '#c0c0c0' -flatten -colors 16 PPM:- | ppmtobmp > $@

bitmaps pixmaps vim-html-pixmaps: $(allxpm) $(allbmp)

montage toolbar-icons: toolbar-icons.png

toolbar-icons.png: ${bitmaps}/*
	montage -geometry '50x30>' -tile 8x4 -borderwidth 2 \
		$(shell zsh -c 'for i in ${bitmaps}/*.xpm; \
		do; echo -label $${$${i%.xpm}##*/} $$i; done') \
		toolbar-icons.png
	chmod a+r toolbar-icons.png

vim-html-pixmaps.zip: $(allxpm) $(allbmp)
	rm -f vim-html-pixmaps.zip
	zip -9j vim-html-pixmaps.zip ${bitmaps}/*
	chmod a+r vim-html-pixmaps.zip

changelog: ChangeLog

ChangeLog: ChangeLog-base
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

#rsync scp: all
#	for d in ${pihome}/www/assets/programming/ ${pihome}/christian_j_robinson/src/assets/programming/; do \
#	rsync --verbose --archive --no-group --no-owner --times --rsh=ssh --stats --progress --exclude '.*.swp' \
#		doc HTML.html HTML.zip version ChangeLog ChangeLog.html toolbar-icons.png \
#		vim-html-pixmaps.zip $$d; done

rsync scp:
	@echo "Use 'make copy' instead, then use git to sync the website."

copy: all
	rsync --verbose --archive --no-group --no-owner --times --rsh=ssh --stats --progress --exclude '.*.swp' \
		doc HTML.html HTML.zip version ChangeLog ChangeLog.html \
		toolbar-icons.png ~/www/website/src/assets/programming/

install: installed

installed: $(PLUGIN_FILES) $(alldoc) $(alllang) $(allxpm) $(allbmp) doc/tags
	mkdir -p ~/.vim/pack/cjr/start/HTML/ftplugin/html/ \
		~/.vim/pack/cjr/start/HTML/doc/ \
		~/.vim/pack/cjr/start/HTML/lang \
		~/.vim/pack/cjr/start/HTML/import/HTML/ \
		~/.vim/pack/cjr/start/HTML/commands/HTML/ \
		~/.vim/pack/cjr/start/HTML/json/HTML/ \
		~/.vim/pack/cjr/start/HTML/autoload/HTML/ \
		~/.vim/pack/cjr/start/HTML/bitmaps/
	cp -f ftplugin/html/*.vim ~/.vim/pack/cjr/start/HTML/ftplugin/html/
	cp -f import/HTML/Variables.vim ~/.vim/pack/cjr/start/HTML/import/HTML/
	cp -f commands/HTML/Commands.vim ~/.vim/pack/cjr/start/HTML/commands/HTML/
	cp -f json/HTML/*.json ~/.vim/pack/cjr/start/HTML/json/HTML/
	cp -f autoload/HTML/*.vim ~/.vim/pack/cjr/start/HTML/autoload/HTML/
	cp -f doc/tags doc/gpl-3.0.html ${alldoc} ~/.vim/pack/cjr/start/HTML/doc/
	cp -f ${alllang} ~/.vim/pack/cjr/start/HTML/lang/
	cp -f bitmaps/* ~/.vim/pack/cjr/start/HTML/bitmaps/
	touch installed

faq FAQ: $(textfaq)

$(textfaq): $(faq)
	w3m -T text/html -cols 79 -O latin1 -dump ${faq} | unix2dos > $(textfaq)
	chmod a+r ${textfaq}

test tests: test_maps test_methods

test_methods: force
	@sh -c "cd test; \
		echo -n TESTING METHODS...; \
		vim -u ./test_methods.vim -U NONE --noplugin > /dev/null 2>&1 ; \
		if test -f ./Xresult; \
		then \
			mv ./Xresult test_methods_results.log; \
			echo FAILURE: \`wc -l test_methods_results.log | cut -f1 -d' '\` INCORRET -- SEE test/test_methods_results.log FOR DETAILS; \
			exit 1; \
		else \
			echo PASSED; \
		fi"

test_maps: force
	@sh -c "cd test; \
		echo -n TESTING MAPPINGS...; \
		vim -u ./test_maps.vim -U NONE --noplugin > /dev/null 2>&1 ; \
		if test -f ./Xresult; \
		then \
			mv ./Xresult test_maps_results.log; \
			echo FAILURE: \`wc -l ./test_maps_results.log | cut -f1 -d' '\` INCORRET -- SEE test/test_maps_results.log FOR DETAILS; \
			exit 1; \
		else \
			echo PASSED; \
		fi"

force:

#.IGNORE: test_methods test_maps

# vim:tabstop=4:shiftwidth=0:foldmethod=expr:foldcolumn=2:number:
