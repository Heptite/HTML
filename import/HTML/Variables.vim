vim9script
scriptencoding utf8

if v:version < 901 || v:versionlong < 9011157
  finish
endif

# Various constants and variables for the HTML macros filetype plugin.
#
# Last Change: March 07, 2025
#
# Requirements:
#       Vim 9.1.1157 or later
#
# Copyright © 1998-2025 Christian J. Robinson <heptite(at)gmail(dot)com>
#
# This program is free software; you can  redistribute  it  and/or  modify  it
# under the terms of the GNU General Public License as published by  the  Free
# Software Foundation; either version 3 of the License, or  (at  your  option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but  WITHOUT
# ANY WARRANTY; without  even  the  implied  warranty  of  MERCHANTABILITY  or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General  Public  License  for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place  -  Suite  330,  Boston,  MA  02111-1307,  USA.   Or  you  can  go  to
# https://www.gnu.org/licenses/licenses.html#GPL

import autoload '../../autoload/HTML/Messages.vim'

export class HTMLVariables

  static var HTMLMessagesO: Messages.HTMLMessages

  def new() # {{{
    if HTMLMessagesO == null_object
      HTMLMessagesO = Messages.HTMLMessages.new()
    endif

    if empty(DictCharToEntities) == 1
      var json_files: list<string> = ENTITY_TABLE_FILE->findfile(&runtimepath, -1)

      if json_files->len() == 0
        printf(HTMLMessagesO.E_NOTFOUND, ENTITY_TABLE_FILE)->HTMLMessagesO.Error()
        return
      endif

      for f: string in json_files
        if f->filereadable()
          var entities: dict<dict<any>> = f->readfile()->join("\n")->json_decode()
          for key: string in entities->keys()
            DictEntitiesToChar[key] = entities[key].characters
            DictCharToEntities[entities[key].characters] = key
          endfor
        else
          printf(HTMLMessagesO.E_NOREAD, Messages.HTMLMessages.F(), f)->HTMLMessagesO.Error()
        endif
      endfor
    endif
  enddef # }}}

  static const AUTHOR: string    = 'Christian J. Robinson'
  static const EMAIL: string     = 'heptite+html' .. "\x40" .. 'gmail' .. "\x2E"  .. 'com'
  static const HOMEPAGE: string  = 'https://christianrobinson.name/HTML/'
  static const COPYRIGHT: string = 'Copyright © 1998-2025 under the terms of the GPL3'

  static const VERSION: string   = '1.5.0'

  var saveopts: dict<any> = {}

  static const MENU_NAME: string = 'HTM&L'

  static const TAGS_FILE: string         = 'json/HTML/tags.json'
  static const ENTITIES_FILE: string     = 'json/HTML/entities.json'
  # https://dev.w3.org/html5/html-author/charref
  static const ENTITY_TABLE_FILE: string = 'json/HTML/entitytable.json'

  static const TEMPLATE_TOKENS: dict<string> = { # {{{
    authorname:  'author_name',
    authoremail: 'author_email_encoded',
    authorurl:   'author_url',
    bgcolor:     'bgcolor',
    textcolor:   'textcolor',
    linkcolor:   'linkcolor',
    alinkcolor:  'alinkcolor',
    vlinkcolor:  'vlinkcolor',
  } # }}}

  static const INTERNAL_TEMPLATE: list<string> = [  # {{{
    # Don't insert the start of the <html> tag here, since logic in the main
    # plugin file adds it depending on the filetype.
    ' <[{HEAD}]>',
    '',
    '  <[{TITLE></TITLE}]>',
    '',
    '  <[{META HTTP-EQUIV}]="Content-Type" [{CONTENT}]="text/html; charset=%charset%" />',
    '  <[{META NAME}]="Generator" [{CONTENT}]="Vim %vimversion% (Vi IMproved editor; http://www.vim.org/) with HTML Editing Macros '
      .. $'%htmlversion% ({HTMLVariables.HOMEPAGE})" />',
    '  <[{META NAME}]="Author" [{CONTENT}]="%authorname%" />',
    '  <[{META NAME}]="Copyright" [{CONTENT}]="Copyright (C) %date% %authorname%" />',
    '  <[{LINK REL}]="made" [{HREF}]="mailto:%authoremail%" />',
    '',
    '  <[{STYLE TYPE}]="text/css">',
    '   <!--',
    '   [{BODY}] {background: %bgcolor%; color: %textcolor%;}',
    '   [{A}]:link {color: %linkcolor%;}',
    '   [{A}]:visited {color: %vlinkcolor%;}',
    '   [{A}]:hover, [{A}]:active, [{A}]:focus {color: %alinkcolor%;}',
    '   -->',
    '  </[{STYLE}]>',
    '',
    ' </[{HEAD}]>',
    ' <[{BODY}]>',
    '',
    '  <[{H1 STYLE}]="text-align: center;"></[{H1}]>',
    '',
    '  <[{P}]>',
    '  </[{P}]>',
    '',
    '  <[{HR STYLE}]="width: 75%;" />',
    '',
    '  <[{P}]>',
    '  Last Modified: <[{I}]>%date%</[{I}]>',
    '  </[{P}]>',
    '',
    '  <[{ADDRESS}]>',
    '   <[{A HREF}]="mailto:%authoremail%">%authorname% &lt;%authoremail%&gt;</[{A}]>',
    '  </[{ADDRESS}]>',
    ' </[{BODY}]>',
    '</[{HTML}]>'
  ]  # }}}

  static var DictEntitiesToChar: dict<string> = {}
  static var DictCharToEntities: dict<string> = {}

  static const MODES: dict<string> = {  # {{{
    n: 'normal',
    v: 'visual',
    o: 'operator-pending',
    i: 'insert',
    c: 'command-line',
    l: 'langmap',
  }  # }}}

  # TODO: This table needs to be expanded:
  static const CHARSETS: dict<string> = {  # {{{
    latin1:    'ISO-8859-1',  koi8_u:    'KOI8-U',
    utf_8:     'UTF-8',       macroman:  'macintosh',
    ucs_2:     'UTF-8',       cp866:     'IBM866',
    ucs_2le:   'UTF-8',       cp1250:    'windows-1250',
    utf_16:    'UTF-8',       cp1251:    'windows-1251',
    utf_16le:  'UTF-8',       cp1253:    'windows-1253',
    ucs_4:     'UTF-8',       cp1254:    'windows-1254',
    ucs_4le:   'UTF-8',       cp1255:    'windows-1255',
    shift_jis: 'Shift_JIS',   cp1256:    'windows-1256',
    sjis:      'Shift_JIS',   cp1257:    'windows-1257',
    cp932:     'Shift_JIS',   cp1258:    'windows-1258',
    euc_jp:    'EUC-JP',      euc_kr:    'EUC-KR',
    cp950:     'Big5',        cp936:     'GBK',
    big5:      'Big5',        euc_cn:    'GB2312',
    koi8_r:    'KOI8-R',
  }  # }}}

  static const COLORS_SORT: dict<string> = {  # {{{
    A: 'A',   B: 'B',   C: 'C',
    D: 'D',   E: 'E-G', F: 'E-G',
    G: 'E-G', H: 'H-K', I: 'H-K',
    J: 'H-K', K: 'H-K', L: 'L',
    M: 'M',   N: 'N-O', O: 'N-O',
    P: 'P',   Q: 'Q-R', R: 'Q-R',
    S: 'S',   T: 'T-Z', U: 'T-Z',
    V: 'T-Z', W: 'T-Z', X: 'T-Z',
    Y: 'T-Z', Z: 'T-Z',
  }  # }}}

  static const COLOR_LIST: list<list<string>> = [  # {{{
    # Standard color names:
    ['Alice Blue',              '#F0F8FF'],
    ['Antique White',           '#FAEBD7'],
    ['Aqua',                    '#00FFFF'],
    ['Aquamarine',              '#7FFFD4'],
    ['Azure',                   '#F0FFFF'],

    ['Beige',                   '#F5F5DC'],
    ['Bisque',                  '#FFE4C4'],
    ['Black',                   '#000000'],
    ['Blanched Almond',         '#FFEBCD'],
    ['Blue',                    '#0000FF'],
    ['Blue Violet',             '#8A2BE2'],
    ['Brown',                   '#A52A2A'],
    ['Burly Wood',              '#DEB887'],

    ['Cadet Blue',              '#5F9EA0'],
    ['Chartreuse',              '#7FFF00'],
    ['Chocolate',               '#D2691E'],
    ['Coral',                   '#FF7F50'],
    ['Cornflower Blue',         '#6495ED'],
    ['Cornsilk',                '#FFF8DC'],
    ['Crimson',                 '#DC143C'],
    ['Cyan',                    '#00FFFF'],

    ['Dark Blue',               '#00008B'],
    ['Dark Cyan',               '#008B8B'],
    ['Dark Golden Rod',         '#B8860B'],
    ['Dark Gray',               '#A9A9A9'],
    ['Dark Green',              '#006400'],
    ['Dark Grey',               '#A9A9A9'],
    ['Dark Khaki',              '#BDB76B'],
    ['Dark Magenta',            '#8B008B'],
    ['Dark Olive Green',        '#556B2F'],
    ['Dark Orange',             '#FF8C00'],
    ['Dark Orchid',             '#9932CC'],
    ['Dark Red',                '#8B0000'],
    ['Dark Salmon',             '#E9967A'],
    ['Dark Sea Green',          '#8FBC8F'],
    ['Dark Slate Blue',         '#483D8B'],
    ['Dark Slate Gray',         '#2F4F4F'],
    ['Dark Slate Grey',         '#2F4F4F'],
    ['Dark Turquoise',          '#00CED1'],
    ['Dark Violet',             '#9400D3'],
    ['Deep Pink',               '#FF1493'],
    ['Deep Sky Blue',           '#00BFFF'],
    ['Dim Gray',                '#696969'],
    ['Dim Grey',                '#696969'],
    ['Dodger Blue',             '#1E90FF'],

    ['Fire Brick',              '#B22222'],
    ['Floral White',            '#FFFAF0'],
    ['Forest Green',            '#228B22'],
    ['Fuchsia',                 '#FF00FF'],

    ['Gainsboro',               '#DCDCDC'],
    ['Ghost White',             '#F8F8FF'],
    ['Gold',                    '#FFD700'],
    ['Golden Rod',              '#DAA520'],
    ['Gray',                    '#808080'],
    ['Green',                   '#008000'],
    ['Green Yellow',            '#ADFF2F'],
    ['Grey',                    '#808080'],

    ['Honey Dew',               '#F0FFF0'],
    ['Hot Pink',                '#FF69B4'],

    ['Indian Red',              '#CD5C5C'],
    ['Indigo',                  '#4B0082'],
    ['Ivory',                   '#FFFFF0'],

    ['Khaki',                   '#F0E68C'],

    ['Lavender',                '#E6E6FA'],
    ['Lavender Blush',          '#FFF0F5'],
    ['Lawn Green',              '#7CFC00'],
    ['Lemon Chiffon',           '#FFFACD'],
    ['Light Blue',              '#ADD8E6'],
    ['Light Coral',             '#F08080'],
    ['Light Cyan',              '#E0FFFF'],
    ['Light Golden Rod Yellow', '#FAFAD2'],
    ['Light Gray',              '#D3D3D3'],
    ['Light Green',             '#90EE90'],
    ['Light Grey',              '#D3D3D3'],
    ['Light Pink',              '#FFB6C1'],
    ['Light Salmon',            '#FFA07A'],
    ['Light Sea Green',         '#20B2AA'],
    ['Light Sky Blue',          '#87CEFA'],
    ['Light Slate Gray',        '#778899'],
    ['Light Slate Grey',        '#778899'],
    ['Light Steel Blue',        '#B0C4DE'],
    ['Light Yellow',            '#FFFFE0'],
    ['Lime',                    '#00FF00'],
    ['Lime Green',              '#32CD32'],
    ['Linen',                   '#FAF0E6'],

    ['Magenta',                 '#FF00FF'],
    ['Maroon',                  '#800000'],
    ['Medium Aqua Marine',      '#66CDAA'],
    ['Medium Blue',             '#0000CD'],
    ['Medium Orchid',           '#BA55D3'],
    ['Medium Purple',           '#9370DB'],
    ['Medium Sea Green',        '#3CB371'],
    ['Medium Slate Blue',       '#7B68EE'],
    ['Medium Spring Green',     '#00FA9A'],
    ['Medium Turquoise',        '#48D1CC'],
    ['Medium Violet Red',       '#C71585'],
    ['Midnight Blue',           '#191970'],
    ['Mint Cream',              '#F5FFFA'],
    ['Misty Rose',              '#FFE4E1'],
    ['Moccasin',                '#FFE4B5'],

    ['Navajo White',            '#FFDEAD'],
    ['Navy',                    '#000080'],

    ['Old Lace',                '#FDF5E6'],
    ['Olive',                   '#808000'],
    ['Olive Drab',              '#6B8E23'],
    ['Orange',                  '#FFA500'],
    ['Orange Red',              '#FF4500'],
    ['Orchid',                  '#DA70D6'],

    ['Pale Golden Rod',         '#EEE8AA'],
    ['Pale Green',              '#98FB98'],
    ['Pale Turquoise',          '#AFEEEE'],
    ['Pale Violet Red',         '#DB7093'],
    ['Papaya Whip',             '#FFEFD5'],
    ['Peach Puff',              '#FFDAB9'],
    ['Peru',                    '#CD853F'],
    ['Pink',                    '#FFC0CB'],
    ['Plum',                    '#DDA0DD'],
    ['Powder Blue',             '#B0E0E6'],
    ['Purple',                  '#800080'],

    ['Rebecca Purple',          '#663399'],
    ['Red',                     '#FF0000'],
    ['Rosy Brown',              '#BC8F8F'],
    ['Royal Blue',              '#4169E1'],

    ['Saddle Brown',            '#8B4513'],
    ['Salmon',                  '#FA8072'],
    ['Sandy Brown',             '#F4A460'],
    ['Sea Green',               '#2E8B57'],
    ['Sea Shell',               '#FFF5EE'],
    ['Sienna',                  '#A0522D'],
    ['Silver',                  '#C0C0C0'],
    ['Sky Blue',                '#87CEEB'],
    ['Slate Blue',              '#6A5ACD'],
    ['Slate Gray',              '#708090'],
    ['Slate Grey',              '#708090'],
    ['Snow',                    '#FFFAFA'],
    ['Spring Green',            '#00FF7F'],
    ['Steel Blue',              '#4682B4'],

    ['Tan',                     '#D2B48C'],
    ['Teal',                    '#008080'],
    ['Thistle',                 '#D8BFD8'],
    ['Tomato',                  '#FF6347'],
    ['Turquoise',               '#40E0D0'],

    ['Violet',                  '#EE82EE'],

    ['Wheat',                   '#F5DEB3'],
    ['White',                   '#FFFFFF'],
    ['White Smoke',             '#F5F5F5'],

    ['Yellow',                  '#FFFF00'],
    ['Yellow Green',            '#9ACD32'],

    # Web safe palette:
    ['', '#CCFF00'],
    ['', '#CCFF33'],
    ['', '#CCFF66'],
    ['', '#CCFF99'],
    ['', '#CCFFCC'],
    ['', '#CCFFFF'],
    ['', '#FFFFFF'],
    ['', '#FFFFCC'],
    ['', '#FFFF99'],
    ['', '#FFFF66'],
    ['', '#FFFF33'],
    ['', '#FFFF00'],
    ['', '#CCCC00'],
    ['', '#CCCC33'],
    ['', '#CCCC66'],
    ['', '#CCCC99'],
    ['', '#CCCCCC'],
    ['', '#CCCCFF'],
    ['', '#FFCCFF'],
    ['', '#FFCCCC'],
    ['', '#FFCC99'],
    ['', '#FFCC66'],
    ['', '#FFCC33'],
    ['', '#FFCC00'],
    ['', '#CC9900'],
    ['', '#CC9933'],
    ['', '#CC9966'],
    ['', '#CC9999'],
    ['', '#CC99CC'],
    ['', '#CC99FF'],
    ['', '#FF99FF'],
    ['', '#FF99CC'],
    ['', '#FF9999'],
    ['', '#FF9966'],
    ['', '#FF9933'],
    ['', '#FF9900'],
    ['', '#CC6600'],
    ['', '#CC6633'],
    ['', '#CC6666'],
    ['', '#CC6699'],
    ['', '#CC66CC'],
    ['', '#CC66FF'],
    ['', '#FF66FF'],
    ['', '#FF66CC'],
    ['', '#FF6699'],
    ['', '#FF6666'],
    ['', '#FF6633'],
    ['', '#FF6600'],
    ['', '#CC3300'],
    ['', '#CC3333'],
    ['', '#CC3366'],
    ['', '#CC3399'],
    ['', '#CC33CC'],
    ['', '#CC33FF'],
    ['', '#FF33FF'],
    ['', '#FF33CC'],
    ['', '#FF3399'],
    ['', '#FF3366'],
    ['', '#FF3333'],
    ['', '#FF3300'],
    ['', '#CC0000'],
    ['', '#CC0033'],
    ['', '#CC0066'],
    ['', '#CC0099'],
    ['', '#CC00CC'],
    ['', '#CC00FF'],
    ['', '#FF00FF'],
    ['', '#FF00CC'],
    ['', '#FF0099'],
    ['', '#FF0066'],
    ['', '#FF0033'],
    ['', '#FF0000'],
    ['', '#660000'],
    ['', '#660033'],
    ['', '#660066'],
    ['', '#660099'],
    ['', '#6600CC'],
    ['', '#6600FF'],
    ['', '#9900FF'],
    ['', '#9900CC'],
    ['', '#990099'],
    ['', '#990066'],
    ['', '#990033'],
    ['', '#990000'],
    ['', '#663300'],
    ['', '#663333'],
    ['', '#663366'],
    ['', '#663399'],
    ['', '#6633CC'],
    ['', '#6633FF'],
    ['', '#9933FF'],
    ['', '#9933CC'],
    ['', '#993399'],
    ['', '#993366'],
    ['', '#993333'],
    ['', '#993300'],
    ['', '#666600'],
    ['', '#666633'],
    ['', '#666666'],
    ['', '#666699'],
    ['', '#6666CC'],
    ['', '#6666FF'],
    ['', '#9966FF'],
    ['', '#9966CC'],
    ['', '#996699'],
    ['', '#996666'],
    ['', '#996633'],
    ['', '#996600'],
    ['', '#669900'],
    ['', '#669933'],
    ['', '#669966'],
    ['', '#669999'],
    ['', '#6699CC'],
    ['', '#6699FF'],
    ['', '#9999FF'],
    ['', '#9999CC'],
    ['', '#999999'],
    ['', '#999966'],
    ['', '#999933'],
    ['', '#999900'],
    ['', '#66CC00'],
    ['', '#66CC33'],
    ['', '#66CC66'],
    ['', '#66CC99'],
    ['', '#66CCCC'],
    ['', '#66CCFF'],
    ['', '#99CCFF'],
    ['', '#99CCCC'],
    ['', '#99CC99'],
    ['', '#99CC66'],
    ['', '#99CC33'],
    ['', '#99CC00'],
    ['', '#66FF00'],
    ['', '#66FF33'],
    ['', '#66FF66'],
    ['', '#66FF99'],
    ['', '#66FFCC'],
    ['', '#66FFFF'],
    ['', '#99FFFF'],
    ['', '#99FFCC'],
    ['', '#99FF99'],
    ['', '#99FF66'],
    ['', '#99FF33'],
    ['', '#99FF00'],
    ['', '#00FF00'],
    ['', '#00FF33'],
    ['', '#00FF66'],
    ['', '#00FF99'],
    ['', '#00FFCC'],
    ['', '#00FFFF'],
    ['', '#33FFFF'],
    ['', '#33FFCC'],
    ['', '#33FF99'],
    ['', '#33FF66'],
    ['', '#33FF33'],
    ['', '#33FF00'],
    ['', '#00CC00'],
    ['', '#00CC33'],
    ['', '#00CC66'],
    ['', '#00CC99'],
    ['', '#00CCCC'],
    ['', '#00CCFF'],
    ['', '#33CCFF'],
    ['', '#33CCCC'],
    ['', '#33CC99'],
    ['', '#33CC66'],
    ['', '#33CC33'],
    ['', '#33CC00'],
    ['', '#009900'],
    ['', '#009933'],
    ['', '#009966'],
    ['', '#009999'],
    ['', '#0099CC'],
    ['', '#0099FF'],
    ['', '#3399FF'],
    ['', '#3399CC'],
    ['', '#339999'],
    ['', '#339966'],
    ['', '#339933'],
    ['', '#339900'],
    ['', '#006600'],
    ['', '#006633'],
    ['', '#006666'],
    ['', '#006699'],
    ['', '#0066CC'],
    ['', '#0066FF'],
    ['', '#3366FF'],
    ['', '#3366CC'],
    ['', '#336699'],
    ['', '#336666'],
    ['', '#336633'],
    ['', '#336600'],
    ['', '#003300'],
    ['', '#003333'],
    ['', '#003366'],
    ['', '#003399'],
    ['', '#0033CC'],
    ['', '#0033FF'],
    ['', '#3333FF'],
    ['', '#3333CC'],
    ['', '#333399'],
    ['', '#333366'],
    ['', '#333333'],
    ['', '#333300'],
    ['', '#000000'],
    ['', '#000033'],
    ['', '#000066'],
    ['', '#000099'],
    ['', '#0000CC'],
    ['', '#0000FF'],
    ['', '#3300FF'],
    ['', '#3300CC'],
    ['', '#330099'],
    ['', '#330066'],
    ['', '#330033'],
    ['', '#330000'],
  ]   # }}}

endclass

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
