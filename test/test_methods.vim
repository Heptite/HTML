vim9script
scriptencoding utf8

import "../autoload/HTML/Util.vim"

def Test_util_methods(...which: list<string>)
	var util: Util.HTMLUtil = Util.HTMLUtil.new()

	assert_true(util.Bool("yes"), 'Bool("yes")')
	assert_false(util.Bool("no"), 'Bool("no")')
	g:tmp = 'yes'
	assert_true(util.BoolVar("g:tmp"), 'g:tmp = "yes"; BoolVar("g:tmp")')
	g:tmp = 'no'
	assert_false(util.BoolVar("g:tmp"), 'g:tmp = "no"; BoolVar("g:tmp")')
	assert_equal('Lorem Ipsum Dolor Met', util.Cap("Lorem ipsum dolor met"),
		'Cap("Lorem ipsum dolor met")')
	assert_equal('abcdefg ABCDEFG', util.ConvertCase("[{ABCDEFG}] ABCDEFG", "lowercase"),
		'ConvertCase("[{ABCDEFG}] ABCDEFG", "lowercase")')
	assert_equal('ABCDEFG abcdefg', util.ConvertCase("[{abcdefg}] abcdefg", "uppercase"),
		'ConvertCase("[{abcdefg}] abcdefg", "uppercase")')
	assert_equal('UTF-8', util.DetectCharset("utf-8"), 'DetectCharset("utf-8")')
	assert_equal('ISO-8859-1', util.DetectCharset("latin1"), 'DetectCharset("latin1")')
	assert_equal([getcwd() .. '/test_maps.vim', getcwd() .. '/test_methods.vim'],
		Util.HTMLUtil.FilesWithMatch(["test_maps.vim", "test_methods.vim"], "mappings"),
		'Util.HTMLUtil.FilesWithMatch(["test_maps.vim", "test_methods.vim"], "mappings")')
	assert_equal(['one', 'two', 'three', 'four'], util.FindAndRead("example.txt", ".", false, false),
		'FindAndRead("textfile", ".", false, false)')
	assert_true(util.Has("eval"), 'Has("eval")')
	assert_true(util.IsSet("g:tmp"), 'IsSet("g:tmp")')
	assert_equal(['one', 'two', 'three', 'four'], util.ReadJsonFiles("example.json", "."),
		'ReadJsonFiles("example.json", ".")')

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
	endif
enddef

set runtimepath+=..

source ../ftplugin/html/HTML.vim

delete('./Xresult')

Test_util_methods()

qall!
