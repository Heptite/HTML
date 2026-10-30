# HTML/XHTML Editing Macros

Note that this plugin requires Vim 9.2.1240 or later; nightly builds are
available for Windows at:
<https://github.com/vim/vim-win32-installer/releases>

This plugin allows for the rapid development of HTML files primarily with the
use of macros. For example:

* In normal mode, type `;html` to insert a configurable template
* Use `<Tab>` to skip to unfilled parts of the template
* Use insert mode ;-mappings to insert tags. For example:
  * `;pp` inserts:  
    &lt;p&gt;  
    &lt;/p&gt;
  * `;im` inserts &lt;img src="" alt=""&gt; and correctly positions the cursor
  * `;br` inserts &lt;br&gt;
  * `&<` inserts &amp;lt;, `&>` inserts &amp;gt;, `&&` inserts &amp;amp;
  * and so on...
* `;db` in normal mode launches the default browser on the current buffer file
* Commands are included to disable and re-enable the mappings, so it is easier
  to edit JavaScript, PHP, etc.
* The map leaders (`;` and `&`) are configurable, along with many other
  configuration variables
* A menu―including a modified toolbar―is included to allow for reference to
  tags and their corresponding mappings

## Installation

Note: If you have an old installation of this plugin, you need to remove its
files first or they may prevent the packed version from loading.

### Vim Package Manager: vim-plug

If you are using [vim-plug](https://github.com/junegunn/vim-plug), just add it
to your vimrc. For example:

```
call plug#begin()
Plug 'Heptite/HTML'
call plug#end()
```

Then type `:PlugInstall` in Vim.

### Vim's Built-In Package Support

#### Unix/MacOS

In a terminal type this command:

```
git clone https://github.com/Heptite/HTML.git \
    ~/.vim/pack/cjr/start/HTML
```

#### Windows

Press `Windows+R`, type in "`cmd`" and press `Enter`.  In that window run this
command:

```
git clone https://github.com/Heptite/HTML.git ^
    %USERPROFILE%\vimfiles\pack\cjr\start\HTML
```

Or for PowerShell users:

```
git clone https://github.com/Heptite/HTML.git `
    $HOME\vimfiles\pack\cjr\start\HTML
```

After installing using git you can always update by going into the
`pack/cjr/start/HTML` directory and typing: `git pull`

## Official Website

<http://christianrobinson.name/HTML>

This includes extra documentation, alternate install methods, an FAQ, etc.

## License

Copyright © 1998 - 2026 Christian J. Robinson

Distributable under the terms of the GNU General Public License, version 3 or
later:  <https://www.gnu.org/licenses/licenses.html#GPL>
