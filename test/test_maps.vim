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
			';ci': ['<cite></cite>'],
			';co': ['<code></code>'],
			';in': ['<ins></ins>'],
			';de': ['<del></del>'],
			';kb': ['<kbd></kbd>'],
			';sa': ['<samp></samp>'],
			';sb': ['<sub></sub>'],
			';sp': ['<sup></sup>'],
			';tt': ['<span style="font-family: monospace;"></span>'],
			';va': ['<var></var>'],
			';fm': ['<form action="">', '</form>'],
			';fd': ['<fieldset>', '<legend></legend>', '</fieldset>'],
			';bu': ['<input type="button" name="" value="">'],
			';ch': ['<input type="checkbox" name="" value="">'],
			';da': ['<input list="">', '<datalist id="">', '</datalist>', '</input>'],
			';cl': ['<input type="date" name="">'],
			';ra': ['<input type="radio" name="" value="">'],
			';rn': ['<input type="range" name="" min="" max="">'],
			';hi': ['<input type="hidden" name="" value="">'],
			';@': ['<input type="email" name="" value="" size="20">'],
			';nu': ['<input type="number" name="" value="" style="width: 5em;">'],
			';op': ['<option></option>'],
			';og': ['<optgroup label="">', '</optgroup>'],
			';ou': ['<output name=""></output>'],
			';pa': ['<input type="password" name="" value="" size="20">'],
			';nt': ['<input type="time" name="">'],
			';#': ['<input type="tel" name="" value="" size="15">'],
			';te': ['<input type="text" name="" value="" size="20">'],
			';fi': ['<input type="file" name="" value="" size="20">'],
			';se': ['<select name="">', '', '</select>'],
			';ms': ['<select name="" multiple>', '', '</select>'],
			';tx': ['<textarea name="" rows="10" cols="50">', '</textarea>'],
			';ur': ['<input type="url" name="" value="" size="20">'],
			';su': ['<input type="submit" value="Submit">'],
			';re': ['<input type="reset" value="Reset">'],
			';la': ['<label for=""></label>'],
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
		assert_equal(mappings[w], getline(1, '$'), $'Mapping: {w}')
	endfor

	writefile(v:errors, 'Xresult')

	qall!
enddef

Test_insert_mode_mappings()
