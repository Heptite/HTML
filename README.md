# HTML/XHTML Editing Macros

Note that this plugin requires Vim 9 or later, or at least a very recently
patched Vim 8.2, available at: <https://tuxproject.de/projects/vim/>

This plugin allows the rapid development of HTML files primarily with the use
of macros. For example:

* In normal mode, type ;html to insert a configurable template
* Use &lt;Tab&gt; to skip to unfilled parts of the template
* Use insert mode ;-mappings to insert tags. For example:
    * ;pp inserts: &lt;p&gt;{newline}&lt;/p&gt;
    * ;im inserts &lt;img src="" alt=""&gt; and correctly positions the cursor
    * ;br inserts &lt;br&gt;
    * &amp;&lt; inserts &amp;lt;, &amp;&gt; inserts &amp;gt;, &amp;&amp; inserts &amp;amp;
    * and so on...
* Commands are included to disable and re-enable the mappings, so it is easier
  to edit JavScript, PHP, etc.
* The map leaders (; and &amp;) are configurable, along with many other
  configuration variables
* A menu―including a modified toolbar―is included to allow for reference to
  tags and their corresponding mappings

## Installation

Note: If you have an old installation of this plugin, you need to remove its
files first or they may prevent the packed version from loading.

Install using your favorite package manager, or use Vim's built-in package
support:

### Unix/MacOS

    mkdir -p ~/.vim/pack/cjr/start
    cd ~/.vim/pack/cjr/start
    git clone https://github.com/Heptite/HTML.git

### Windows

    Press Windows+R and type in "cmd"
    mkdir %USERPROFILE%\vimfiles\pack\cjr\start
    cd %USERPROFILE%\vimfiles\pack\cjr\start
    git clone https://github.com/Heptite/HTML.git

After installing using git you can always update by going into the
`pack/cjr/start/HTML` directory and typing: `git pull`

## Official Website

<http://christianrobinson.name/vim/HTML/>

This includes extra documentation, alternate install methods, an FAQ, etc.

## License

Copyright © 1998 - 2021 Christian J. Robinson

Distributable under the terms of the GNU General Public Licenve, version 3 or
later:  <https://www.gnu.org/licenses/licenses.html#GPL>
