vim9script
scriptencoding utf8

def Test_insert_mode_mappings(...which: list<string>)
	var mappings: dict<list<string>> = {
			';ah': ['<a href=""></a>'],
			';bo': ['<b></b>'],
			';st': ['<strong></strong>'],
			';it': ['<i></i>'],
			';em': ['<em></em>'],
			';un': ['<u></u>'],
			';bi': ['<span style="font-size: larger;"></span>'],
			';sm': ['<span style="font-size: smaller;"></span>'],
			';fo': ['<span style="font-size: ;"></span>'],
			';fc': ['<span style="color: ;"></span>'],
		}

	var do_which: list<string>

	if which == []
		do_which = keys(mappings)
	else
		do_which = which
	endif
	
	edit mappings.out
	set runtimepath+=..
	source ../ftplugin/html/HTML.vim

	for w: string in do_which
		:1,$delete
		execute 'normal i' .. w
		assert_equal(mappings[w], getline(1, '$'))
	endfor

	writefile(v:errors, 'Xresult')

	qall!
enddef

Test_insert_mode_mappings()
