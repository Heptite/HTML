vim9script
scriptencoding utf8

def Test_insert_mode_mappings(...which: list<string>)
	var mappings: dict<list<string>> = {
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
			';@':  ['<input type="email" name="" value="" size="20">'],
			';nu': ['<input type="number" name="" value="" style="width: 5em;">'],
			';op': ['<option></option>'],
			';og': ['<optgroup label="">', '</optgroup>'],
			';ou': ['<output name=""></output>'],
			';pa': ['<input type="password" name="" value="" size="20">'],
			';nt': ['<input type="time" name="">'],
			';#':  ['<input type="tel" name="" value="" size="15">'],
			';te': ['<input type="text" name="" value="" size="20">'],
			';fi': ['<input type="file" name="" value="" size="20">'],
			';se': ['<select name="">', '', '</select>'],
			';ms': ['<select name="" multiple>', '', '</select>'],
			';tx': ['<textarea name="" rows="10" cols="50">', '</textarea>'],
			';ur': ['<input type="url" name="" value="" size="20">'],
			';su': ['<input type="submit" value="Submit">'],
			';re': ['<input type="reset" value="Reset">'],
			';la': ['<label for=""></label>'],
			';bd': ['<body>', '', '</body>'],
			';bn': ['<button type="button"></button>'],
			';ce': ['<div style="text-align: center;">', '', '</div>'],
			';he': ['<head>', '', '</head>'],
			';hr': ['<hr>'],
			';Hr': ['<hr style="width: 75%;">'],
			';ht': ['<html>', '', '</html>'],
			';ah': ['<a href=""></a>'],
			';at': ['<a href="" target=""></a>'],
			';im': ['<img src="" alt="">'],
			';br': ['<br>'],
			';pp': ['<p>', '', '</p>'],
			';/p': ['</p>', '', '<p>', ''],
			';pr': ['<pre>', '', '</pre>'],
			';ti': ['<title></title>'],
			';h1': ['<h1></h1>'],
			';h2': ['<h2></h2>'],
			';h3': ['<h3></h3>'],
			';h4': ['<h4></h4>'],
			';h5': ['<h5></h5>'],
			';h6': ['<h6></h6>'],
			';hg': ['<hgroup>', '', '</hgroup>'],
			';ar': ['<article>', '', '</article>'],
			';as': ['<aside>', '', '</aside>'],
			';au': ['<audio controls>', '<source src="" type="">', 'Your browser does not support the audio tag.', '</audio>'],
			';vi': ['<video width="" height="" controls>', '<source src="" type="">', 'Your browser does not support the video tag.', '</video>'],
			';cv': ['<canvas width="" height=""></canvas>'],
			';ds': ['<details>', '<summary></summary>', '<p>', '</p>', '</details>'],
			';eb': ['<embed type="" src="" width="" height="">'],
			';fg': ['<figure>', '', '</figure>'],
			';fp': ['<figcaption></figcaption>'],
			';ft': ['<footer>', '', '</footer>'],
			';hd': ['<header>', '', '</header>'],
			';ma': ['<main>', '', '</main>'],
			';mk': ['<mark></mark>'],
			';mt': ['<meter value="" min="" max=""></meter>'],
			';na': ['<nav>', '', '</nav>'],
			';pg': ['<progress value="" max=""></progress>'],
			';sc': ['<section>', '', '</section>'],
			';tm': ['<time datetime=""></time>'],
			';wb': ['<wbr>'],
			';ol': ['<ol>', '', '</ol>'],
			';ul': ['<ul>', '', '</ul>'],
			';dl': ['<dl>', '', '</dl>'],
			';li': ['<li></li>'],
			';dt': ['<dt></dt>'],
			';ab': ['<abbr title=""></abbr>'],
			';ad': ['<address></address>'],
			';bh': ['<base href="">'],
			';bt': ['<base target="">'],
			';bl': ['<blockquote>', '', '</blockquote>'],
			';cm': ['<!--  -->'],
			';df': ['<dfn></dfn>'],
			';dv': ['<div>', '', '</div>'],
			';if': ['<iframe src="" width="" height="">', '</iframe>'],
			';js': ['<script type="application/javascript">', '', '</script>'],
			';jm': ['<script type="module">', '', '</script>'],
			';sj': ['<script src="" type="application/javascript"></script>'],
			';mo': ['<script src="" type="module"></script>'],
			';lk': ['<link href="">'],
			';me': ['<meta name="" content="">'],
			';mh': ['<meta http-equiv="" content="">'],
			';ob': ['<object data="" width="" height="">', '</object>'],
			';pm': ['<param name="" value="">'],
			';qu': ['<q></q>'],
			';sn': ['<span class=""></span>'],
			';ss': ['<span style=""></span>'],
			';cs': ['<style type="text/css">', '<!--', '', '-->', '</style>'],
			';ls': ['<link rel="stylesheet" type="text/css" href="">'],
			';cf': ['<!--#config timefmt="" -->'],
			';cz': ['<!--#config sizefmt="" -->'],
			';ev': ['<!--#echo var="" -->'],
			';iv': ['<!--#include virtual="" -->'],
			';fz': ['<!--#fsize virtual="" -->'],
			';ec': ['<!--#exec cmd="" -->'],
			';sv': ['<!--#set var="" value="" -->'],
			';ie': ['<!--#if expr="" -->', '<!--#else -->', '<!--#endif -->'],
			';ta': ['<table>', '', '</table>'],
			';tH': ['<thead>', '', '</thead>'],
			';tb': ['<tbody>', '', '</tbody>'],
			';tr': ['<tr>', '', '</tr>'],
			';tf': ['<tfoot>', '', '</tfoot>'],
			';th': ['<th></th>'],
			';td': ['<td></td>'],
			';ca': ['<caption></caption>'],
			';ct': ['<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'],
			';4':  ['<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"', ' "http://www.w3.org/TR/html4/loose.dtd">', ''],
			';s4': ['<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"', ' "http://www.w3.org/TR/html4/strict.dtd">', ''],
			';5':  ['<!DOCTYPE html>', ''],
		}

	var do_which: list<string>

	if which == []
		do_which = keys(mappings)
	else
		do_which = which
	endif
	
	edit! insert_mappings.out

	source ../ftplugin/html/HTML.vim

	for w: string in do_which
		:%delete
		assert_nobeep('normal i' .. w)
		assert_equal(mappings[w], getline(1, '$'), $'Mapping: {w}')
	endfor

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
	endif
enddef

def Test_normal_mode_mappings(...which: list<string>)
	var mappings: dict<list<string>> = {
			';bo': ['<b>test text</b>'],
			';st': ['<strong>test text</strong>'],
			';it': ['<i>test text</i>'],
			';em': ['<em>test text</em>'],
			';un': ['<u>test text</u>'],
			';bi': ['<span style="font-size: larger;">test text</span>'],
			';sm': ['<span style="font-size: smaller;">test text</span>'],
			';fo': ['<span style="font-size: ;">test text</span>'],
			';fc': ['<span style="color: ;">test text</span>'],
			';ci': ['<cite>test text</cite>'],
			';co': ['<code>test text</code>'],
			';in': ['<ins>test text</ins>'],
			';de': ['<del>test text</del>'],
			';kb': ['<kbd>test text</kbd>'],
			';sa': ['<samp>test text</samp>'],
			';sb': ['<sub>test text</sub>'],
			';sp': ['<sup>test text</sup>'],
			';tt': ['<span style="font-family: monospace;">test text</span>'],
			';va': ['<var>test text</var>'],
			';fm': ['<form action="">', 'test text', '</form>'],
			';fd': ['<fieldset>', '<legend></legend>', 'test text', '</fieldset>'],
			';bu': ['<input type="button" name="" value="test text">'],
			';ch': ['<input type="checkbox" name="" value="test text">'],
			';da': ['<input list="test text">', '<datalist id="test text">', '', '</datalist>', '</input>'],
			';cl': ['<input type="date" name="test text">'],
			';ra': ['<input type="radio" name="" value="test text">'],
			';rn': ['<input type="range" name="test text" min="" max="">'],
			';hi': ['<input type="hidden" name="" value="test text">'],
			';@':  ['<input type="email" name="" value="test text" size="20">'],
			';nu': ['<input type="number" name="" value="test text" style="width: 5em;">'],
			';op': ['<option>test text</option>'],
			';og': ['<optgroup label="">', 'test text', '</optgroup>'],
			';ou': ['<output name="">test text</output>'],
			';pa': ['<input type="password" name="" value="test text" size="20">'],
			';nt': ['<input type="time" name="test text">'],
			';#':  ['<input type="tel" name="" value="test text" size="15">'],
			';te': ['<input type="text" name="" value="test text" size="20">'],
			';fi': ['<input type="file" name="" value="test text" size="20">'],
			';se': ['<select name="">', 'test text', '</select>'],
			';ms': ['<select name="" multiple>', 'test text', '</select>'],
			';tx': ['<textarea name="" rows="10" cols="50">', 'test text', '</textarea>'],
			';ur': ['<input type="url" name="" value="test text" size="20">'],
			';la': ['<label for="">test text</label>'],
			';bd': ['<body>', 'test text', '</body>'],
			';bn': ['<button type="button">test text</button>'],
			';ce': ['<div style="text-align: center;">', 'test text', '</div>'],
			';he': ['<head>', 'test text', '</head>'],
			';ht': ['<html>', 'test text', '</html>'],
			';ah': ['<a href="">test text</a>'],
			';at': ['<a href="" target="">test text</a>'],
			';im': ['<img src="" alt="test text">'],
			';pp': ['<p>', 'test text', '</p>'],
			';pr': ['<pre>', 'test text', '</pre>'],
			';ti': ['<title>test text</title>'],
			';h1': ['<h1>test text</h1>'],
			';h2': ['<h2>test text</h2>'],
			';h3': ['<h3>test text</h3>'],
			';h4': ['<h4>test text</h4>'],
			';h5': ['<h5>test text</h5>'],
			';h6': ['<h6>test text</h6>'],
			';hg': ['<hgroup>', 'test text', '</hgroup>'],
			';ar': ['<article>', 'test text', '</article>'],
			';as': ['<aside>', 'test text', '</aside>'],
			';au': ['<audio controls>', '<source src="" type="">', 'test text', '</audio>'],
			';vi': ['<video width="" height="" controls>', '<source src="" type="">', 'test text', '</video>'],
			';cv': ['<canvas width="" height="">test text</canvas>'],
			';ds': ['<details>', '<summary></summary>', 'test text', '</details>'],
			';eb': ['<embed type="" src="test text" width="" height="">'],
			';fg': ['<figure>', 'test text', '</figure>'],
			';fp': ['<figcaption>test text</figcaption>'],
			';ft': ['<footer>', 'test text', '</footer>'],
			';hd': ['<header>', 'test text', '</header>'],
			';ma': ['<main>', 'test text', '</main>'],
			';mk': ['<mark>test text</mark>'],
			';mt': ['<meter value="" min="" max="">test text</meter>'],
			';na': ['<nav>', 'test text', '</nav>'],
			';pg': ['<progress value="test text" max=""></progress>'],
			';sc': ['<section>', 'test text', '</section>'],
			';tm': ['<time datetime="">test text</time>'],
			';ol': ['<ol>', 'test text', '</ol>'],
			';ul': ['<ul>', 'test text', '</ul>'],
			';dl': ['<dl>', 'test text', '</dl>'],
			';li': ['<li>test text</li>'],
			';dt': ['<dt>test text</dt>'],
			';ab': ['<abbr title="">test text</abbr>'],
			';ad': ['<address>test text</address>'],
			';bh': ['<base href="test text">'],
			';bt': ['<base target="test text">'],
			';bl': ['<blockquote>', 'test text', '</blockquote>'],
			';cm': ['<!-- test text -->'],
			';df': ['<dfn>test text</dfn>'],
			';dv': ['<div>', 'test text', '</div>'],
			';if': ['<iframe src="" width="" height="">', 'test text', '</iframe>'],
			';js': ['<script type="application/javascript">', 'test text', '</script>'],
			';jm': ['<script type="module">', 'test text', '</script>'],
			';sj': ['<script src="test text" type="application/javascript"></script>'],
			';mo': ['<script src="test text" type="module"></script>'],
			';lk': ['<link href="test text">'],
			';me': ['<meta name="test text" content="">'],
			';mh': ['<meta http-equiv="" content="test text">'],
			';ob': ['<object data="" width="" height="">', 'test text', '</object>'],
			';pm': ['<param name="test text" value="">'],
			';qu': ['<q>test text</q>'],
			';sn': ['<span class="">test text</span>'],
			';ss': ['<span style="">test text</span>'],
			';cs': ['<style type="text/css">', '<!--', 'test text', ' -->', '</style>'],
			';ls': ['<link rel="stylesheet" type="text/css" href="test text">'],
			';cf': ['<!--#config timefmt="test text" -->'],
			';cz': ['<!--#config sizefmt="test text" -->'],
			';ev': ['<!--#echo var="test text" -->'],
			';iv': ['<!--#include virtual="test text" -->'],
			';fz': ['<!--#fsize virtual="test text" -->'],
			';ec': ['<!--#exec cmd="test text" -->'],
			';sv': ['<!--#set var="" value="test text" -->'],
			';ie': ['<!--#if expr="" -->', 'test text', '<!--#else -->', '<!--#endif -->'],
			';ta': ['<table>', 'test text', '</table>'],
			';tH': ['<thead>', 'test text', '</thead>'],
			';tb': ['<tbody>', 'test text', '</tbody>'],
			';tr': ['<tr>', 'test text', '</tr>'],
			';tf': ['<tfoot>', 'test text', '</tfoot>'],
			';th': ['<th>test text</th>'],
			';td': ['<td>test text</td>'],
			';ca': ['<caption>', 'test text', '</caption>'],
		}

	var do_which: list<string>

	if which == []
		do_which = keys(mappings)
	else
		do_which = which
	endif
	
	edit! normal_visual_mappings.out

	source ../ftplugin/html/HTML.vim

	for w: string in do_which
		:%delete
		assert_nobeep("normal itest text\<esc>" .. w .. 'ip')
		assert_equal(mappings[w], getline(1, '$'), $'Mapping: {w}')
	endfor

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
	endif
enddef

# TODO: Fix this, currently doesn't work (feedkeys() + confirm() don't like
#       each other):
def Test_interactive_mappings(...which: list<string>)
	var mappings: dict<list<any>> = {
			';tA': ["2\<cr>2\<cr>2\<cr>yy", ['<table style="border: solid #000000 2px; padding: 3px;">', '<thead>', '<tr>', '<th style="border: solid #000000 2px; padding: 3px;"></th>', '<th style="border: solid #000000 2px; padding: 3px;"></th>', '</tr>', '</thead>', '<tbody>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '</tbody>', '<tfoot>', '<tr>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '<td style="border: solid #000000 2px; padding: 3px;"></td>', '</tr>', '</tfoot>', '</table>']],
		}

	var do_which: list<string>

	if which == []
		do_which = keys(mappings)
	else
		do_which = which
	endif
	
	edit! interactive_mappings.out

	source ../ftplugin/html/HTML.vim

	for w: string in do_which
		:%delete
		feedkeys(w .. mappings[w][0], 'xt')
		assert_equal(mappings[w][1], getline(1, '$'), $'Mapping: {w}')
	endfor

	if v:errors != []
		writefile(v:errors, 'Xresult', 'a')
	endif
enddef


set runtimepath+=..

delete('./Xresult')
delete('./.mappings.out.swp')

Test_insert_mode_mappings()
# No need for a visual mode test on mappings because the normal mode mappings
# run a visual selection:
Test_normal_mode_mappings()
# See TODO above
#Test_interactive_mappings()

qall!
