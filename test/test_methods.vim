vim9script
scriptencoding utf8

import "../autoload/HTML/Util.vim"
import "../autoload/HTML/Map.vim"
import "../autoload/HTML/Messages.vim"
import "../autoload/HTML/Glue.vim"
import "../import/HTML/Variables.vim"

def Test_util_methods()
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
	assert_false(util.Has("nonexistent"), 'Has("nonexistent")')
	assert_true(util.IsSet("g:tmp"), 'IsSet("g:tmp")')
	assert_equal(['one', 'two', 'three', 'four'], util.ReadJsonFiles("example.json", "."),
		'ReadJsonFiles("example.json", ".")')
	assert_equal(Util.SetIfUnsetR.exists, util.SetIfUnset("g:tmp", "foo bar baz"),
		'SetIfUnset("g:tmp", "foo bar baz")')
	assert_equal(Util.SetIfUnsetR.success, util.SetIfUnset("g:tmp2", "foo bar baz"),
		'SetIfUnset("g:tmp", "foo bar baz")')
	assert_equal([Variables.HTMLVariables.VERSION], util.TokenReplace(["%htmlversion%"]),
		'TokenReplace(["%htmlversion%"])')
	assert_equal('rgb(18, 52, 86)', util.ToRGB("#123456"), 'ToRGB("#123456")')
	assert_equal('rgb(7%, 20%, 34%)', util.ToRGB("#123456", true), 'ToRGB("#123456", true)')
	assert_equal('&#x7E;&excl;&commat;&num;&dollar;&percnt;&Hat;&AMP;&ast;&lpar;&rpar;&UnderBar;&plus;',
		util.TranscodeString("~!@#$%^&*()_+"), 'TranscodeString("~!@#$%^&*()_+")')

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
		v:errors = []
	endif
enddef

def Test_map_methods()
	var mapo: Map.HTMLMap = Map.HTMLMap.new()

	assert_true(mapo.GenerateTable(2, 2, 2, true, true), 'GenerateTable(2, 2, 2, true, true)')
	assert_equal(['<table style="border: solid #000000 2px; padding: 3px;">', '<thead>', '<tr>', '<th style="border: solid #000000 2px; padding: 3px;"></th>', '<th style="border: solid #000000 2px; padding: 3px;"></th>', '</tr>', '</thead>', '<tbody>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '</tbody>', '<tfoot>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '</tfoot>', '</table>'],
		getline(1, '$'), 'Output of: GenerateTable(2, 2, 2, true, true)')
	assert_equal(Map.MapCheckR.override, mapo.MapCheck(";ah", "i", true), 'MapCheck(";ah", "i", true)')
	g:htmlplugin.map_override = false
	assert_equal(Map.MapCheckR.nooverride, mapo.MapCheck(";ah", "i", true), 'g:htmlplugin.map_override = false; MapCheck(";ah", "i", true)')
	b:htmlplugin.no_maps = [";ah"]
	assert_equal(Map.MapCheckR.suppressed, mapo.MapCheck(";ah", "i", true), 'b:htmlplugin.no_maps = [";ah"]; MapCheck(";ah", "i", true)')
	assert_false(mapo.MappingsListAdd({";ah": "foobar"}, "i", true), 'MappingsListAdd({";ah": "foobar"}, "i", true)')
	assert_true(mapo.MappingsListAdd({";ah": "foobar"}, "i", false), 'MappingsListAdd({";ah": "foobar"}, "i", false)')
	:%delete
	assert_false(mapo.NextInsertPoint(), "NextInsertPoint()")
	setline(1, ['<html>', '<head>', '<title></title>', '</head>', '</html>'])
	cursor(0, 0)
	assert_true(mapo.NextInsertPoint(), "NextInsertPoint() cursor should reposition")
	normal iLorem Ipsum
	assert_false(mapo.NextInsertPoint(), "NextInsertPoint() cursor should NOT reposition")
	:%delete
	assert_equal("<b></b>\<C-O>F<", mapo.SmartTag("b", "i"), 'SmartTag("b", "i")')
	&selection = 'exclusive'
	assert_equal("\<C-O>`>", mapo.VisualInsertPos(), "'selection' = exclusive; VisualInsertPos()")
	&selection = 'inclusive'
	assert_equal("\<right>", mapo.VisualInsertPos(), "'selection' = inclusive; VisualInsertPos()")

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
		v:errors = []
	endif
enddef

def Test_messages_methods()
	var mapo: Map.HTMLMap = Map.HTMLMap.new()

	assert_match('function <SNR>\d\+_Test_messages_methods', Messages.HTMLMessages.F(), 'Messages.HTMLMessages.F()')

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
		v:errors = []
	endif
enddef

def Test_glue_methods()
	var glue: Glue.HTMLGlue = Glue.HTMLGlue.new()

	assert_true(glue.PluginControl('disable'), 'PluginControl("disable")')
	assert_false(glue.PluginControl('disable'), 'PluginControl("disable")')
	assert_false(glue.PluginControl('foobar'), 'PluginControl("foobar")')
	assert_true(glue.PluginControl('enable'), 'PluginControl("enable")')

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
		v:errors = []
	endif
enddef

set runtimepath+=..

delete('.swp')
delete('./Xresult')

source ../ftplugin/html/HTML.vim

# Test glue methods first because we do some hinky stuff later on that would
# make the tests fail (should probably fix that):
Test_glue_methods()
Test_util_methods()
Test_map_methods()
Test_messages_methods()

qall!
