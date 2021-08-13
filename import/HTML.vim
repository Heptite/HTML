vim9script

# Various constants and variables for the HTML macros filetype plugin.
#
# Last Change: August 12, 2021
#
# Requirements:
#       Vim 9 or later
#
# Copyright © 2004-2021 Christian J. Robinson <heptite@gmail.com>
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

export const AUTHOR = 'Christian J. Robinson'
export const HOMEPAGE = 'https://christianrobinson.name/HTML/'
export const COPYRIGHT = 'Copyright © 1998-2021 under the terms of the GPL3'

export const VERSION = '1.1.7'

# Used by some of the functions to save then restore some options:
export var saveopts: dict<any>

export const MENU_NAME = 'HTM&L'

export const TAGS_FILE = 'json/htmltags.json'
export const ENTITIES_FILE = 'json/htmlentities.json'

export const INTERNAL_HTML_TEMPLATE = [  # {{{
    ' <[{HEAD}]>',
    '',
    '  <[{TITLE></TITLE}]>',
    '',
    '  <[{META HTTP-EQUIV}]="Content-Type" [{CONTENT}]="text/html; charset=%charset%" />',
    '  <[{META NAME}]="Generator" [{CONTENT}]="Vim %vimversion% (Vi IMproved editor; http://www.vim.org/)" />',
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

# https://dev.w3.org/html5/html-author/charref
export const DictEntitiesToChar = {  # {{{
  '&Tab;': "\x9", '&NewLine;': "\xA", '&excl;': "\x21",
  '&quot;': "\x22", '&num;': "\x23", '&dollar;': "\x24",
  '&percnt;': "\x25", '&amp;': "\x26", '&apos;': "\x27",
  '&lpar;': "\x28", '&rpar;': "\x29", '&ast;': "\x2A",
  '&plus;': "\x2B", '&comma;': "\x2C", '&period;': "\x2E",
  '&sol;': "\x2F", '&colon;': "\x3A", '&semi;': "\x3B",
  '&lt;': "\x3C", '&equals;': "\x3D", '&gt;': "\x3E",
  '&quest;': "\x3F", '&commat;': "\x40", '&lsqb;': "\x5B",
  '&bsol;': "\x5C", '&rsqb;': "\x5D", '&Hat;': "\x5E",
  '&lowbar;': "\x5F", '&grave;': "\x60", '&lcub;': "\x7B",
  '&verbar;': "\x7C", '&rcub;': "\x7D", '&nbsp;': "\xA0",
  '&iexcl;': "\xA1", '&cent;': "\xA2", '&pound;': "\xA3",
  '&curren;': "\xA4", '&yen;': "\xA5", '&brvbar;': "\xA6",
  '&sect;': "\xA7", '&uml;': "\xA8", '&copy;': "\xA9",
  '&ordf;': "\xAA", '&laquo;': "\xAB", '&not;': "\xAC",
  '&shy;': "\xAD", '&reg;': "\xAE", '&macr;': "\xAF",
  '&deg;': "\xB0", '&plusmn;': "\xB1", '&sup2;': "\xB2",
  '&sup3;': "\xB3", '&acute;': "\xB4", '&micro;': "\xB5",
  '&para;': "\xB6", '&middot;': "\xB7", '&cedil;': "\xB8",
  '&sup1;': "\xB9", '&ordm;': "\xBA", '&raquo;': "\xBB",
  '&frac14;': "\xBC", '&frac12;': "\xBD", '&frac34;': "\xBE",
  '&iquest;': "\xBF", '&Agrave;': "\xC0", '&Aacute;': "\xC1",
  '&Acirc;': "\xC2", '&Atilde;': "\xC3", '&Auml;': "\xC4",
  '&Aring;': "\xC5", '&AElig;': "\xC6", '&Ccedil;': "\xC7",
  '&Egrave;': "\xC8", '&Eacute;': "\xC9", '&Ecirc;': "\xCA",
  '&Euml;': "\xCB", '&Igrave;': "\xCC", '&Iacute;': "\xCD",
  '&Icirc;': "\xCE", '&Iuml;': "\xCF", '&ETH;': "\xD0",
  '&Ntilde;': "\xD1", '&Ograve;': "\xD2", '&Oacute;': "\xD3",
  '&Ocirc;': "\xD4", '&Otilde;': "\xD5", '&Ouml;': "\xD6",
  '&times;': "\xD7", '&Oslash;': "\xD8", '&Ugrave;': "\xD9",
  '&Uacute;': "\xDA", '&Ucirc;': "\xDB", '&Uuml;': "\xDC",
  '&Yacute;': "\xDD", '&THORN;': "\xDE", '&szlig;': "\xDF",
  '&agrave;': "\xE0", '&aacute;': "\xE1", '&acirc;': "\xE2",
  '&atilde;': "\xE3", '&auml;': "\xE4", '&aring;': "\xE5",
  '&aelig;': "\xE6", '&ccedil;': "\xE7", '&egrave;': "\xE8",
  '&eacute;': "\xE9", '&ecirc;': "\xEA", '&euml;': "\xEB",
  '&igrave;': "\xEC", '&iacute;': "\xED", '&icirc;': "\xEE",
  '&iuml;': "\xEF", '&eth;': "\xF0", '&ntilde;': "\xF1",
  '&ograve;': "\xF2", '&oacute;': "\xF3", '&ocirc;': "\xF4",
  '&otilde;': "\xF5", '&ouml;': "\xF6", '&divide;': "\xF7",
  '&oslash;': "\xF8", '&ugrave;': "\xF9", '&uacute;': "\xFA",
  '&ucirc;': "\xFB", '&uuml;': "\xFC", '&yacute;': "\xFD",
  '&thorn;': "\xFE", '&yuml;': "\xFF", '&Amacr;': "\U100",
  '&amacr;': "\U101", '&Abreve;': "\U102", '&abreve;': "\U103",
  '&Aogon;': "\U104", '&aogon;': "\U105", '&Cacute;': "\U106",
  '&cacute;': "\U107", '&Ccirc;': "\U108", '&ccirc;': "\U109",
  '&Cdot;': "\U10A", '&cdot;': "\U10B", '&Ccaron;': "\U10C",
  '&ccaron;': "\U10D", '&Dcaron;': "\U10E", '&dcaron;': "\U10F",
  '&Dstrok;': "\U110", '&dstrok;': "\U111", '&Emacr;': "\U112",
  '&emacr;': "\U113", '&Edot;': "\U116", '&edot;': "\U117",
  '&Eogon;': "\U118", '&eogon;': "\U119", '&Ecaron;': "\U11A",
  '&ecaron;': "\U11B", '&Gcirc;': "\U11C", '&gcirc;': "\U11D",
  '&Gbreve;': "\U11E", '&gbreve;': "\U11F", '&Gdot;': "\U120",
  '&gdot;': "\U121", '&Gcedil;': "\U122", '&Hcirc;': "\U124",
  '&hcirc;': "\U125", '&Hstrok;': "\U126", '&hstrok;': "\U127",
  '&Itilde;': "\U128", '&itilde;': "\U129", '&Imacr;': "\U12A",
  '&imacr;': "\U12B", '&Iogon;': "\U12E", '&iogon;': "\U12F",
  '&Idot;': "\U130", '&imath;': "\U131", '&IJlig;': "\U132",
  '&ijlig;': "\U133", '&Jcirc;': "\U134", '&jcirc;': "\U135",
  '&Kcedil;': "\U136", '&kcedil;': "\U137", '&kgreen;': "\U138",
  '&Lacute;': "\U139", '&lacute;': "\U13A", '&Lcedil;': "\U13B",
  '&lcedil;': "\U13C", '&Lcaron;': "\U13D", '&lcaron;': "\U13E",
  '&Lmidot;': "\U13F", '&lmidot;': "\U140", '&Lstrok;': "\U141",
  '&lstrok;': "\U142", '&Nacute;': "\U143", '&nacute;': "\U144",
  '&Ncedil;': "\U145", '&ncedil;': "\U146", '&Ncaron;': "\U147",
  '&ncaron;': "\U148", '&napos;': "\U149", '&ENG;': "\U14A",
  '&eng;': "\U14B", '&Omacr;': "\U14C", '&omacr;': "\U14D",
  '&Odblac;': "\U150", '&odblac;': "\U151", '&OElig;': "\U152",
  '&oelig;': "\U153", '&Racute;': "\U154", '&racute;': "\U155",
  '&Rcedil;': "\U156", '&rcedil;': "\U157", '&Rcaron;': "\U158",
  '&rcaron;': "\U159", '&Sacute;': "\U15A", '&sacute;': "\U15B",
  '&Scirc;': "\U15C", '&scirc;': "\U15D", '&Scedil;': "\U15E",
  '&scedil;': "\U15F", '&Scaron;': "\U160", '&scaron;': "\U161",
  '&Tcedil;': "\U162", '&tcedil;': "\U163", '&Tcaron;': "\U164",
  '&tcaron;': "\U165", '&Tstrok;': "\U166", '&tstrok;': "\U167",
  '&Utilde;': "\U168", '&utilde;': "\U169", '&Umacr;': "\U16A",
  '&umacr;': "\U16B", '&Ubreve;': "\U16C", '&ubreve;': "\U16D",
  '&Uring;': "\U16E", '&uring;': "\U16F", '&Udblac;': "\U170",
  '&udblac;': "\U171", '&Uogon;': "\U172", '&uogon;': "\U173",
  '&Wcirc;': "\U174", '&wcirc;': "\U175", '&Ycirc;': "\U176",
  '&ycirc;': "\U177", '&Yuml;': "\U178", '&Zacute;': "\U179",
  '&zacute;': "\U17A", '&Zdot;': "\U17B", '&zdot;': "\U17C",
  '&Zcaron;': "\U17D", '&zcaron;': "\U17E", '&fnof;': "\U192",
  '&imped;': "\U1B5", '&gacute;': "\U1F5", '&jmath;': "\U237",
  '&circ;': "\U2C6", '&caron;': "\U2C7", '&breve;': "\U2D8",
  '&dot;': "\U2D9", '&ring;': "\U2DA", '&ogon;': "\U2DB",
  '&tilde;': "\U2DC", '&dblac;': "\U2DD", '&DownBreve;': "\U311",
  '&UnderBar;': "\U332", '&Alpha;': "\U391", '&Beta;': "\U392",
  '&Gamma;': "\U393", '&Delta;': "\U394", '&Epsilon;': "\U395",
  '&Zeta;': "\U396", '&Eta;': "\U397", '&Theta;': "\U398",
  '&Iota;': "\U399", '&Kappa;': "\U39A", '&Lambda;': "\U39B",
  '&Mu;': "\U39C", '&Nu;': "\U39D", '&Xi;': "\U39E",
  '&Omicron;': "\U39F", '&Pi;': "\U3A0", '&Rho;': "\U3A1",
  '&Sigma;': "\U3A3", '&Tau;': "\U3A4", '&Upsilon;': "\U3A5",
  '&Phi;': "\U3A6", '&Chi;': "\U3A7", '&Psi;': "\U3A8",
  '&Omega;': "\U3A9", '&alpha;': "\U3B1", '&beta;': "\U3B2",
  '&gamma;': "\U3B3", '&delta;': "\U3B4", '&epsiv;': "\U3B5",
  '&zeta;': "\U3B6", '&eta;': "\U3B7", '&theta;': "\U3B8",
  '&iota;': "\U3B9", '&kappa;': "\U3BA", '&lambda;': "\U3BB",
  '&mu;': "\U3BC", '&nu;': "\U3BD", '&xi;': "\U3BE",
  '&omicron;': "\U3BF", '&pi;': "\U3C0", '&rho;': "\U3C1",
  '&sigmav;': "\U3C2", '&sigma;': "\U3C3", '&tau;': "\U3C4",
  '&upsi;': "\U3C5", '&phi;': "\U3C6", '&chi;': "\U3C7",
  '&psi;': "\U3C8", '&omega;': "\U3C9", '&thetav;': "\U3D1",
  '&Upsi;': "\U3D2", '&straightphi;': "\U3D5", '&piv;': "\U3D6",
  '&Gammad;': "\U3DC", '&gammad;': "\U3DD", '&kappav;': "\U3F0",
  '&rhov;': "\U3F1", '&epsi;': "\U3F5", '&bepsi;': "\U3F6",
  '&IOcy;': "\U401", '&DJcy;': "\U402", '&GJcy;': "\U403",
  '&Jukcy;': "\U404", '&DScy;': "\U405", '&Iukcy;': "\U406",
  '&YIcy;': "\U407", '&Jsercy;': "\U408", '&LJcy;': "\U409",
  '&NJcy;': "\U40A", '&TSHcy;': "\U40B", '&KJcy;': "\U40C",
  '&Ubrcy;': "\U40E", '&DZcy;': "\U40F", '&Acy;': "\U410",
  '&Bcy;': "\U411", '&Vcy;': "\U412", '&Gcy;': "\U413",
  '&Dcy;': "\U414", '&IEcy;': "\U415", '&ZHcy;': "\U416",
  '&Zcy;': "\U417", '&Icy;': "\U418", '&Jcy;': "\U419",
  '&Kcy;': "\U41A", '&Lcy;': "\U41B", '&Mcy;': "\U41C",
  '&Ncy;': "\U41D", '&Ocy;': "\U41E", '&Pcy;': "\U41F",
  '&Rcy;': "\U420", '&Scy;': "\U421", '&Tcy;': "\U422",
  '&Ucy;': "\U423", '&Fcy;': "\U424", '&KHcy;': "\U425",
  '&TScy;': "\U426", '&CHcy;': "\U427", '&SHcy;': "\U428",
  '&SHCHcy;': "\U429", '&HARDcy;': "\U42A", '&Ycy;': "\U42B",
  '&SOFTcy;': "\U42C", '&Ecy;': "\U42D", '&YUcy;': "\U42E",
  '&YAcy;': "\U42F", '&acy;': "\U430", '&bcy;': "\U431",
  '&vcy;': "\U432", '&gcy;': "\U433", '&dcy;': "\U434",
  '&iecy;': "\U435", '&zhcy;': "\U436", '&zcy;': "\U437",
  '&icy;': "\U438", '&jcy;': "\U439", '&kcy;': "\U43A",
  '&lcy;': "\U43B", '&mcy;': "\U43C", '&ncy;': "\U43D",
  '&ocy;': "\U43E", '&pcy;': "\U43F", '&rcy;': "\U440",
  '&scy;': "\U441", '&tcy;': "\U442", '&ucy;': "\U443",
  '&fcy;': "\U444", '&khcy;': "\U445", '&tscy;': "\U446",
  '&chcy;': "\U447", '&shcy;': "\U448", '&shchcy;': "\U449",
  '&hardcy;': "\U44A", '&ycy;': "\U44B", '&softcy;': "\U44C",
  '&ecy;': "\U44D", '&yucy;': "\U44E", '&yacy;': "\U44F",
  '&iocy;': "\U451", '&djcy;': "\U452", '&gjcy;': "\U453",
  '&jukcy;': "\U454", '&dscy;': "\U455", '&iukcy;': "\U456",
  '&yicy;': "\U457", '&jsercy;': "\U458", '&ljcy;': "\U459",
  '&njcy;': "\U45A", '&tshcy;': "\U45B", '&kjcy;': "\U45C",
  '&ubrcy;': "\U45E", '&dzcy;': "\U45F", '&ensp;': "\U2002",
  '&emsp;': "\U2003", '&emsp13;': "\U2004", '&emsp14;': "\U2005",
  '&numsp;': "\U2007", '&puncsp;': "\U2008", '&thinsp;': "\U2009",
  '&hairsp;': "\U200A", '&ZeroWidthSpace;': "\U200B", '&zwnj;': "\U200C",
  '&zwj;': "\U200D", '&lrm;': "\U200E", '&rlm;': "\U200F",
  '&hyphen;': "\U2010", '&ndash;': "\U2013", '&mdash;': "\U2014",
  '&horbar;': "\U2015", '&Verbar;': "\U2016", '&lsquo;': "\U2018",
  '&rsquo;': "\U2019", '&lsquor;': "\U201A", '&ldquo;': "\U201C",
  '&rdquo;': "\U201D", '&ldquor;': "\U201E", '&dagger;': "\U2020",
  '&Dagger;': "\U2021", '&bull;': "\U2022", '&nldr;': "\U2025",
  '&hellip;': "\U2026", '&permil;': "\U2030", '&pertenk;': "\U2031",
  '&prime;': "\U2032", '&Prime;': "\U2033", '&tprime;': "\U2034",
  '&bprime;': "\U2035", '&lsaquo;': "\U2039", '&rsaquo;': "\U203A",
  '&oline;': "\U203E", '&caret;': "\U2041", '&hybull;': "\U2043",
  '&frasl;': "\U2044", '&bsemi;': "\U204F", '&qprime;': "\U2057",
  '&MediumSpace;': "\U205F", '&NoBreak;': "\U2060", '&ApplyFunction;': "\U2061",
  '&InvisibleTimes;': "\U2062", '&InvisibleComma;': "\U2063", '&euro;': "\U20AC",
  '&tdot;': "\U20DB", '&DotDot;': "\U20DC", '&Copf;': "\U2102",
  '&incare;': "\U2105", '&gscr;': "\U210A", '&hamilt;': "\U210B",
  '&Hfr;': "\U210C", '&quaternions;': "\U210D", '&planckh;': "\U210E",
  '&planck;': "\U210F", '&Iscr;': "\U2110", '&image;': "\U2111",
  '&Lscr;': "\U2112", '&ell;': "\U2113", '&Nopf;': "\U2115",
  '&numero;': "\U2116", '&copysr;': "\U2117", '&weierp;': "\U2118",
  '&Popf;': "\U2119", '&rationals;': "\U211A", '&Rscr;': "\U211B",
  '&real;': "\U211C", '&reals;': "\U211D", '&rx;': "\U211E",
  '&trade;': "\U2122", '&integers;': "\U2124", '&ohm;': "\U2126",
  '&mho;': "\U2127", '&Zfr;': "\U2128", '&iiota;': "\U2129",
  '&angst;': "\U212B", '&bernou;': "\U212C", '&Cfr;': "\U212D",
  '&escr;': "\U212F", '&Escr;': "\U2130", '&Fscr;': "\U2131",
  '&phmmat;': "\U2133", '&order;': "\U2134", '&alefsym;': "\U2135",
  '&beth;': "\U2136", '&gimel;': "\U2137", '&daleth;': "\U2138",
  '&CapitalDifferentialD;': "\U2145", '&DifferentialD;': "\U2146", '&ExponentialE;': "\U2147",
  '&ImaginaryI;': "\U2148", '&frac13;': "\U2153", '&frac23;': "\U2154",
  '&frac15;': "\U2155", '&frac25;': "\U2156", '&frac35;': "\U2157",
  '&frac45;': "\U2158", '&frac16;': "\U2159", '&frac56;': "\U215A",
  '&frac18;': "\U215B", '&frac38;': "\U215C", '&frac58;': "\U215D",
  '&frac78;': "\U215E", '&larr;': "\U2190", '&uarr;': "\U2191",
  '&rarr;': "\U2192", '&darr;': "\U2193", '&harr;': "\U2194",
  '&varr;': "\U2195", '&nwarr;': "\U2196", '&nearr;': "\U2197",
  '&searr;': "\U2198", '&swarr;': "\U2199", '&nlarr;': "\U219A",
  '&nrarr;': "\U219B", '&rarrw;': "\U219D", '&Larr;': "\U219E",
  '&Uarr;': "\U219F", '&Rarr;': "\U21A0", '&Darr;': "\U21A1",
  '&larrtl;': "\U21A2", '&rarrtl;': "\U21A3", '&LeftTeeArrow;': "\U21A4",
  '&UpTeeArrow;': "\U21A5", '&map;': "\U21A6", '&DownTeeArrow;': "\U21A7",
  '&larrhk;': "\U21A9", '&rarrhk;': "\U21AA", '&larrlp;': "\U21AB",
  '&rarrlp;': "\U21AC", '&harrw;': "\U21AD", '&nharr;': "\U21AE",
  '&lsh;': "\U21B0", '&rsh;': "\U21B1", '&ldsh;': "\U21B2",
  '&rdsh;': "\U21B3", '&crarr;': "\U21B5", '&cularr;': "\U21B6",
  '&curarr;': "\U21B7", '&olarr;': "\U21BA", '&orarr;': "\U21BB",
  '&lharu;': "\U21BC", '&lhard;': "\U21BD", '&uharr;': "\U21BE",
  '&uharl;': "\U21BF", '&rharu;': "\U21C0", '&rhard;': "\U21C1",
  '&dharr;': "\U21C2", '&dharl;': "\U21C3", '&rlarr;': "\U21C4",
  '&udarr;': "\U21C5", '&lrarr;': "\U21C6", '&llarr;': "\U21C7",
  '&uuarr;': "\U21C8", '&rrarr;': "\U21C9", '&ddarr;': "\U21CA",
  '&lrhar;': "\U21CB", '&rlhar;': "\U21CC", '&nlArr;': "\U21CD",
  '&nhArr;': "\U21CE", '&nrArr;': "\U21CF", '&lArr;': "\U21D0",
  '&uArr;': "\U21D1", '&rArr;': "\U21D2", '&dArr;': "\U21D3",
  '&hArr;': "\U21D4", '&vArr;': "\U21D5", '&nwArr;': "\U21D6",
  '&neArr;': "\U21D7", '&seArr;': "\U21D8", '&swArr;': "\U21D9",
  '&lAarr;': "\U21DA", '&rAarr;': "\U21DB", '&zigrarr;': "\U21DD",
  '&larrb;': "\U21E4", '&rarrb;': "\U21E5", '&duarr;': "\U21F5",
  '&loarr;': "\U21FD", '&roarr;': "\U21FE", '&hoarr;': "\U21FF",
  '&forall;': "\U2200", '&comp;': "\U2201", '&part;': "\U2202",
  '&exist;': "\U2203", '&nexist;': "\U2204", '&empty;': "\U2205",
  '&nabla;': "\U2207", '&isin;': "\U2208", '&notin;': "\U2209",
  '&niv;': "\U220B", '&notni;': "\U220C", '&prod;': "\U220F",
  '&coprod;': "\U2210", '&sum;': "\U2211", '&minus;': "\U2212",
  '&mnplus;': "\U2213", '&plusdo;': "\U2214", '&setmn;': "\U2216",
  '&lowast;': "\U2217", '&compfn;': "\U2218", '&radic;': "\U221A",
  '&prop;': "\U221D", '&infin;': "\U221E", '&angrt;': "\U221F",
  '&ang;': "\U2220", '&angmsd;': "\U2221", '&angsph;': "\U2222",
  '&mid;': "\U2223", '&nmid;': "\U2224", '&par;': "\U2225",
  '&npar;': "\U2226", '&and;': "\U2227", '&or;': "\U2228",
  '&cap;': "\U2229", '&cup;': "\U222A", '&int;': "\U222B",
  '&Int;': "\U222C", '&tint;': "\U222D", '&conint;': "\U222E",
  '&Conint;': "\U222F", '&Cconint;': "\U2230", '&cwint;': "\U2231",
  '&cwconint;': "\U2232", '&awconint;': "\U2233", '&there4;': "\U2234",
  '&becaus;': "\U2235", '&ratio;': "\U2236", '&Colon;': "\U2237",
  '&minusd;': "\U2238", '&mDDot;': "\U223A", '&homtht;': "\U223B",
  '&sim;': "\U223C", '&bsim;': "\U223D", '&ac;': "\U223E",
  '&acd;': "\U223F", '&wreath;': "\U2240", '&nsim;': "\U2241",
  '&esim;': "\U2242", '&sime;': "\U2243", '&nsime;': "\U2244",
  '&cong;': "\U2245", '&simne;': "\U2246", '&ncong;': "\U2247",
  '&asymp;': "\U2248", '&nap;': "\U2249", '&ape;': "\U224A",
  '&apid;': "\U224B", '&bcong;': "\U224C", '&asympeq;': "\U224D",
  '&bump;': "\U224E", '&bumpe;': "\U224F", '&esdot;': "\U2250",
  '&eDot;': "\U2251", '&efDot;': "\U2252", '&erDot;': "\U2253",
  '&colone;': "\U2254", '&ecolon;': "\U2255", '&ecir;': "\U2256",
  '&cire;': "\U2257", '&wedgeq;': "\U2259", '&veeeq;': "\U225A",
  '&trie;': "\U225C", '&equest;': "\U225F", '&ne;': "\U2260",
  '&equiv;': "\U2261", '&nequiv;': "\U2262", '&le;': "\U2264",
  '&ge;': "\U2265", '&lE;': "\U2266", '&gE;': "\U2267",
  '&lnE;': "\U2268", '&gnE;': "\U2269", '&Lt;': "\U226A",
  '&Gt;': "\U226B", '&twixt;': "\U226C", '&NotCupCap;': "\U226D",
  '&nlt;': "\U226E", '&ngt;': "\U226F", '&nle;': "\U2270",
  '&nge;': "\U2271", '&lsim;': "\U2272", '&gsim;': "\U2273",
  '&nlsim;': "\U2274", '&ngsim;': "\U2275", '&lg;': "\U2276",
  '&gl;': "\U2277", '&ntlg;': "\U2278", '&ntgl;': "\U2279",
  '&pr;': "\U227A", '&sc;': "\U227B", '&prcue;': "\U227C",
  '&sccue;': "\U227D", '&prsim;': "\U227E", '&scsim;': "\U227F",
  '&npr;': "\U2280", '&nsc;': "\U2281", '&sub;': "\U2282",
  '&sup;': "\U2283", '&nsub;': "\U2284", '&nsup;': "\U2285",
  '&sube;': "\U2286", '&supe;': "\U2287", '&nsube;': "\U2288",
  '&nsupe;': "\U2289", '&subne;': "\U228A", '&supne;': "\U228B",
  '&cupdot;': "\U228D", '&uplus;': "\U228E", '&sqsub;': "\U228F",
  '&sqsup;': "\U2290", '&sqsube;': "\U2291", '&sqsupe;': "\U2292",
  '&sqcap;': "\U2293", '&sqcup;': "\U2294", '&oplus;': "\U2295",
  '&ominus;': "\U2296", '&otimes;': "\U2297", '&osol;': "\U2298",
  '&odot;': "\U2299", '&ocir;': "\U229A", '&oast;': "\U229B",
  '&odash;': "\U229D", '&plusb;': "\U229E", '&minusb;': "\U229F",
  '&timesb;': "\U22A0", '&sdotb;': "\U22A1", '&vdash;': "\U22A2",
  '&dashv;': "\U22A3", '&top;': "\U22A4", '&bottom;': "\U22A5",
  '&models;': "\U22A7", '&vDash;': "\U22A8", '&Vdash;': "\U22A9",
  '&Vvdash;': "\U22AA", '&VDash;': "\U22AB", '&nvdash;': "\U22AC",
  '&nvDash;': "\U22AD", '&nVdash;': "\U22AE", '&nVDash;': "\U22AF",
  '&prurel;': "\U22B0", '&vltri;': "\U22B2", '&vrtri;': "\U22B3",
  '&ltrie;': "\U22B4", '&rtrie;': "\U22B5", '&origof;': "\U22B6",
  '&imof;': "\U22B7", '&mumap;': "\U22B8", '&hercon;': "\U22B9",
  '&intcal;': "\U22BA", '&veebar;': "\U22BB", '&barvee;': "\U22BD",
  '&angrtvb;': "\U22BE", '&lrtri;': "\U22BF", '&xwedge;': "\U22C0",
  '&xvee;': "\U22C1", '&xcap;': "\U22C2", '&xcup;': "\U22C3",
  '&diam;': "\U22C4", '&sdot;': "\U22C5", '&sstarf;': "\U22C6",
  '&divonx;': "\U22C7", '&bowtie;': "\U22C8", '&ltimes;': "\U22C9",
  '&rtimes;': "\U22CA", '&lthree;': "\U22CB", '&rthree;': "\U22CC",
  '&bsime;': "\U22CD", '&cuvee;': "\U22CE", '&cuwed;': "\U22CF",
  '&Sub;': "\U22D0", '&Sup;': "\U22D1", '&Cap;': "\U22D2",
  '&Cup;': "\U22D3", '&fork;': "\U22D4", '&epar;': "\U22D5",
  '&ltdot;': "\U22D6", '&gtdot;': "\U22D7", '&Ll;': "\U22D8",
  '&Gg;': "\U22D9", '&leg;': "\U22DA", '&gel;': "\U22DB",
  '&cuepr;': "\U22DE", '&cuesc;': "\U22DF", '&nprcue;': "\U22E0",
  '&nsccue;': "\U22E1", '&nsqsube;': "\U22E2", '&nsqsupe;': "\U22E3",
  '&lnsim;': "\U22E6", '&gnsim;': "\U22E7", '&prnsim;': "\U22E8",
  '&scnsim;': "\U22E9", '&nltri;': "\U22EA", '&nrtri;': "\U22EB",
  '&nltrie;': "\U22EC", '&nrtrie;': "\U22ED", '&vellip;': "\U22EE",
  '&ctdot;': "\U22EF", '&utdot;': "\U22F0", '&dtdot;': "\U22F1",
  '&disin;': "\U22F2", '&isinsv;': "\U22F3", '&isins;': "\U22F4",
  '&isindot;': "\U22F5", '&notinvc;': "\U22F6", '&notinvb;': "\U22F7",
  '&isinE;': "\U22F9", '&nisd;': "\U22FA", '&xnis;': "\U22FB",
  '&nis;': "\U22FC", '&notnivc;': "\U22FD", '&notnivb;': "\U22FE",
  '&barwed;': "\U2305", '&Barwed;': "\U2306", '&lceil;': "\U2308",
  '&rceil;': "\U2309", '&lfloor;': "\U230A", '&rfloor;': "\U230B",
  '&drcrop;': "\U230C", '&dlcrop;': "\U230D", '&urcrop;': "\U230E",
  '&ulcrop;': "\U230F", '&bnot;': "\U2310", '&profline;': "\U2312",
  '&profsurf;': "\U2313", '&telrec;': "\U2315", '&target;': "\U2316",
  '&ulcorn;': "\U231C", '&urcorn;': "\U231D", '&dlcorn;': "\U231E",
  '&drcorn;': "\U231F", '&frown;': "\U2322", '&smile;': "\U2323",
  '&cylcty;': "\U232D", '&profalar;': "\U232E", '&topbot;': "\U2336",
  '&ovbar;': "\U233D", '&solbar;': "\U233F", '&angzarr;': "\U237C",
  '&lmoust;': "\U23B0", '&rmoust;': "\U23B1", '&tbrk;': "\U23B4",
  '&bbrk;': "\U23B5", '&bbrktbrk;': "\U23B6", '&OverParenthesis;': "\U23DC",
  '&UnderParenthesis;': "\U23DD", '&OverBrace;': "\U23DE", '&UnderBrace;': "\U23DF",
  '&trpezium;': "\U23E2", '&elinters;': "\U23E7", '&blank;': "\U2423",
  '&oS;': "\U24C8", '&boxh;': "\U2500", '&boxv;': "\U2502",
  '&boxdr;': "\U250C", '&boxdl;': "\U2510", '&boxur;': "\U2514",
  '&boxul;': "\U2518", '&boxvr;': "\U251C", '&boxvl;': "\U2524",
  '&boxhd;': "\U252C", '&boxhu;': "\U2534", '&boxvh;': "\U253C",
  '&boxH;': "\U2550", '&boxV;': "\U2551", '&boxdR;': "\U2552",
  '&boxDr;': "\U2553", '&boxDR;': "\U2554", '&boxdL;': "\U2555",
  '&boxDl;': "\U2556", '&boxDL;': "\U2557", '&boxuR;': "\U2558",
  '&boxUr;': "\U2559", '&boxUR;': "\U255A", '&boxuL;': "\U255B",
  '&boxUl;': "\U255C", '&boxUL;': "\U255D", '&boxvR;': "\U255E",
  '&boxVr;': "\U255F", '&boxVR;': "\U2560", '&boxvL;': "\U2561",
  '&boxVl;': "\U2562", '&boxVL;': "\U2563", '&boxHd;': "\U2564",
  '&boxhD;': "\U2565", '&boxHD;': "\U2566", '&boxHu;': "\U2567",
  '&boxhU;': "\U2568", '&boxHU;': "\U2569", '&boxvH;': "\U256A",
  '&boxVh;': "\U256B", '&boxVH;': "\U256C", '&uhblk;': "\U2580",
  '&lhblk;': "\U2584", '&block;': "\U2588", '&blk14;': "\U2591",
  '&blk12;': "\U2592", '&blk34;': "\U2593", '&squ;': "\U25A1",
  '&squf;': "\U25AA", '&EmptyVerySmallSquare;': "\U25AB", '&rect;': "\U25AD",
  '&marker;': "\U25AE", '&fltns;': "\U25B1", '&xutri;': "\U25B3",
  '&utrif;': "\U25B4", '&utri;': "\U25B5", '&rtrif;': "\U25B8",
  '&rtri;': "\U25B9", '&xdtri;': "\U25BD", '&dtrif;': "\U25BE",
  '&dtri;': "\U25BF", '&ltrif;': "\U25C2", '&ltri;': "\U25C3",
  '&loz;': "\U25CA", '&cir;': "\U25CB", '&tridot;': "\U25EC",
  '&xcirc;': "\U25EF", '&ultri;': "\U25F8", '&urtri;': "\U25F9",
  '&lltri;': "\U25FA", '&EmptySmallSquare;': "\U25FB", '&FilledSmallSquare;': "\U25FC",
  '&starf;': "\U2605", '&star;': "\U2606", '&phone;': "\U260E",
  '&female;': "\U2640", '&male;': "\U2642", '&spades;': "\U2660",
  '&clubs;': "\U2663", '&hearts;': "\U2665", '&diams;': "\U2666",
  '&sung;': "\U266A", '&flat;': "\U266D", '&natur;': "\U266E",
  '&sharp;': "\U266F", '&check;': "\U2713", '&cross;': "\U2717",
  '&malt;': "\U2720", '&sext;': "\U2736", '&VerticalSeparator;': "\U2758",
  '&lbbrk;': "\U2772", '&rbbrk;': "\U2773", '&lobrk;': "\U27E6",
  '&robrk;': "\U27E7", '&lang;': "\U27E8", '&rang;': "\U27E9",
  '&Lang;': "\U27EA", '&Rang;': "\U27EB", '&loang;': "\U27EC",
  '&roang;': "\U27ED", '&xlarr;': "\U27F5", '&xrarr;': "\U27F6",
  '&xharr;': "\U27F7", '&xlArr;': "\U27F8", '&xrArr;': "\U27F9",
  '&xhArr;': "\U27FA", '&xmap;': "\U27FC", '&dzigrarr;': "\U27FF",
  '&nvlArr;': "\U2902", '&nvrArr;': "\U2903", '&nvHarr;': "\U2904",
  '&Map;': "\U2905", '&lbarr;': "\U290C", '&rbarr;': "\U290D",
  '&lBarr;': "\U290E", '&rBarr;': "\U290F", '&RBarr;': "\U2910",
  '&DDotrahd;': "\U2911", '&UpArrowBar;': "\U2912", '&DownArrowBar;': "\U2913",
  '&Rarrtl;': "\U2916", '&latail;': "\U2919", '&ratail;': "\U291A",
  '&lAtail;': "\U291B", '&rAtail;': "\U291C", '&larrfs;': "\U291D",
  '&rarrfs;': "\U291E", '&larrbfs;': "\U291F", '&rarrbfs;': "\U2920",
  '&nwarhk;': "\U2923", '&nearhk;': "\U2924", '&searhk;': "\U2925",
  '&swarhk;': "\U2926", '&nwnear;': "\U2927", '&nesear;': "\U2928",
  '&seswar;': "\U2929", '&swnwar;': "\U292A", '&rarrc;': "\U2933",
  '&cudarrr;': "\U2935", '&ldca;': "\U2936", '&rdca;': "\U2937",
  '&cudarrl;': "\U2938", '&larrpl;': "\U2939", '&curarrm;': "\U293C",
  '&cularrp;': "\U293D", '&rarrpl;': "\U2945", '&harrcir;': "\U2948",
  '&Uarrocir;': "\U2949", '&lurdshar;': "\U294A", '&ldrushar;': "\U294B",
  '&LeftRightVector;': "\U294E", '&RightUpDownVector;': "\U294F", '&DownLeftRightVector;': "\U2950",
  '&LeftUpDownVector;': "\U2951", '&LeftVectorBar;': "\U2952", '&RightVectorBar;': "\U2953",
  '&RightUpVectorBar;': "\U2954", '&RightDownVectorBar;': "\U2955", '&DownLeftVectorBar;': "\U2956",
  '&DownRightVectorBar;': "\U2957", '&LeftUpVectorBar;': "\U2958", '&LeftDownVectorBar;': "\U2959",
  '&LeftTeeVector;': "\U295A", '&RightTeeVector;': "\U295B", '&RightUpTeeVector;': "\U295C",
  '&RightDownTeeVector;': "\U295D", '&DownLeftTeeVector;': "\U295E", '&DownRightTeeVector;': "\U295F",
  '&LeftUpTeeVector;': "\U2960", '&LeftDownTeeVector;': "\U2961", '&lHar;': "\U2962",
  '&uHar;': "\U2963", '&rHar;': "\U2964", '&dHar;': "\U2965",
  '&luruhar;': "\U2966", '&ldrdhar;': "\U2967", '&ruluhar;': "\U2968",
  '&rdldhar;': "\U2969", '&lharul;': "\U296A", '&llhard;': "\U296B",
  '&rharul;': "\U296C", '&lrhard;': "\U296D", '&udhar;': "\U296E",
  '&duhar;': "\U296F", '&RoundImplies;': "\U2970", '&erarr;': "\U2971",
  '&simrarr;': "\U2972", '&larrsim;': "\U2973", '&rarrsim;': "\U2974",
  '&rarrap;': "\U2975", '&ltlarr;': "\U2976", '&gtrarr;': "\U2978",
  '&subrarr;': "\U2979", '&suplarr;': "\U297B", '&lfisht;': "\U297C",
  '&rfisht;': "\U297D", '&ufisht;': "\U297E", '&dfisht;': "\U297F",
  '&lopar;': "\U2985", '&ropar;': "\U2986", '&lbrke;': "\U298B",
  '&rbrke;': "\U298C", '&lbrkslu;': "\U298D", '&rbrksld;': "\U298E",
  '&lbrksld;': "\U298F", '&rbrkslu;': "\U2990", '&langd;': "\U2991",
  '&rangd;': "\U2992", '&lparlt;': "\U2993", '&rpargt;': "\U2994",
  '&gtlPar;': "\U2995", '&ltrPar;': "\U2996", '&vzigzag;': "\U299A",
  '&vangrt;': "\U299C", '&angrtvbd;': "\U299D", '&ange;': "\U29A4",
  '&range;': "\U29A5", '&dwangle;': "\U29A6", '&uwangle;': "\U29A7",
  '&angmsdaa;': "\U29A8", '&angmsdab;': "\U29A9", '&angmsdac;': "\U29AA",
  '&angmsdad;': "\U29AB", '&angmsdae;': "\U29AC", '&angmsdaf;': "\U29AD",
  '&angmsdag;': "\U29AE", '&angmsdah;': "\U29AF", '&bemptyv;': "\U29B0",
  '&demptyv;': "\U29B1", '&cemptyv;': "\U29B2", '&raemptyv;': "\U29B3",
  '&laemptyv;': "\U29B4", '&ohbar;': "\U29B5", '&omid;': "\U29B6",
  '&opar;': "\U29B7", '&operp;': "\U29B9", '&olcross;': "\U29BB",
  '&odsold;': "\U29BC", '&olcir;': "\U29BE", '&ofcir;': "\U29BF",
  '&olt;': "\U29C0", '&ogt;': "\U29C1", '&cirscir;': "\U29C2",
  '&cirE;': "\U29C3", '&solb;': "\U29C4", '&bsolb;': "\U29C5",
  '&boxbox;': "\U29C9", '&trisb;': "\U29CD", '&rtriltri;': "\U29CE",
  '&LeftTriangleBar;': "\U29CF", '&RightTriangleBar;': "\U29D0", '&race;': "\U29DA",
  '&iinfin;': "\U29DC", '&infintie;': "\U29DD", '&nvinfin;': "\U29DE",
  '&eparsl;': "\U29E3", '&smeparsl;': "\U29E4", '&eqvparsl;': "\U29E5",
  '&lozf;': "\U29EB", '&RuleDelayed;': "\U29F4", '&dsol;': "\U29F6",
  '&xodot;': "\U2A00", '&xoplus;': "\U2A01", '&xotime;': "\U2A02",
  '&xuplus;': "\U2A04", '&xsqcup;': "\U2A06", '&qint;': "\U2A0C",
  '&fpartint;': "\U2A0D", '&cirfnint;': "\U2A10", '&awint;': "\U2A11",
  '&rppolint;': "\U2A12", '&scpolint;': "\U2A13", '&npolint;': "\U2A14",
  '&pointint;': "\U2A15", '&quatint;': "\U2A16", '&intlarhk;': "\U2A17",
  '&pluscir;': "\U2A22", '&plusacir;': "\U2A23", '&simplus;': "\U2A24",
  '&plusdu;': "\U2A25", '&plussim;': "\U2A26", '&plustwo;': "\U2A27",
  '&mcomma;': "\U2A29", '&minusdu;': "\U2A2A", '&loplus;': "\U2A2D",
  '&roplus;': "\U2A2E", '&Cross;': "\U2A2F", '&timesd;': "\U2A30",
  '&timesbar;': "\U2A31", '&smashp;': "\U2A33", '&lotimes;': "\U2A34",
  '&rotimes;': "\U2A35", '&otimesas;': "\U2A36", '&Otimes;': "\U2A37",
  '&odiv;': "\U2A38", '&triplus;': "\U2A39", '&triminus;': "\U2A3A",
  '&tritime;': "\U2A3B", '&iprod;': "\U2A3C", '&amalg;': "\U2A3F",
  '&capdot;': "\U2A40", '&ncup;': "\U2A42", '&ncap;': "\U2A43",
  '&capand;': "\U2A44", '&cupor;': "\U2A45", '&cupcap;': "\U2A46",
  '&capcup;': "\U2A47", '&cupbrcap;': "\U2A48", '&capbrcup;': "\U2A49",
  '&cupcup;': "\U2A4A", '&capcap;': "\U2A4B", '&ccups;': "\U2A4C",
  '&ccaps;': "\U2A4D", '&ccupssm;': "\U2A50", '&And;': "\U2A53",
  '&Or;': "\U2A54", '&andand;': "\U2A55", '&oror;': "\U2A56",
  '&orslope;': "\U2A57", '&andslope;': "\U2A58", '&andv;': "\U2A5A",
  '&orv;': "\U2A5B", '&andd;': "\U2A5C", '&ord;': "\U2A5D",
  '&wedbar;': "\U2A5F", '&sdote;': "\U2A66", '&simdot;': "\U2A6A",
  '&congdot;': "\U2A6D", '&easter;': "\U2A6E", '&apacir;': "\U2A6F",
  '&apE;': "\U2A70", '&eplus;': "\U2A71", '&pluse;': "\U2A72",
  '&Esim;': "\U2A73", '&Colone;': "\U2A74", '&Equal;': "\U2A75",
  '&eDDot;': "\U2A77", '&equivDD;': "\U2A78", '&ltcir;': "\U2A79",
  '&gtcir;': "\U2A7A", '&ltquest;': "\U2A7B", '&gtquest;': "\U2A7C",
  '&les;': "\U2A7D", '&ges;': "\U2A7E", '&lesdot;': "\U2A7F",
  '&gesdot;': "\U2A80", '&lesdoto;': "\U2A81", '&gesdoto;': "\U2A82",
  '&lesdotor;': "\U2A83", '&gesdotol;': "\U2A84", '&lap;': "\U2A85",
  '&gap;': "\U2A86", '&lne;': "\U2A87", '&gne;': "\U2A88",
  '&lnap;': "\U2A89", '&gnap;': "\U2A8A", '&lEg;': "\U2A8B",
  '&gEl;': "\U2A8C", '&lsime;': "\U2A8D", '&gsime;': "\U2A8E",
  '&lsimg;': "\U2A8F", '&gsiml;': "\U2A90", '&lgE;': "\U2A91",
  '&glE;': "\U2A92", '&lesges;': "\U2A93", '&gesles;': "\U2A94",
  '&els;': "\U2A95", '&egs;': "\U2A96", '&elsdot;': "\U2A97",
  '&egsdot;': "\U2A98", '&el;': "\U2A99", '&eg;': "\U2A9A",
  '&siml;': "\U2A9D", '&simg;': "\U2A9E", '&simlE;': "\U2A9F",
  '&simgE;': "\U2AA0", '&LessLess;': "\U2AA1", '&GreaterGreater;': "\U2AA2",
  '&glj;': "\U2AA4", '&gla;': "\U2AA5", '&ltcc;': "\U2AA6",
  '&gtcc;': "\U2AA7", '&lescc;': "\U2AA8", '&gescc;': "\U2AA9",
  '&smt;': "\U2AAA", '&lat;': "\U2AAB", '&smte;': "\U2AAC",
  '&late;': "\U2AAD", '&bumpE;': "\U2AAE", '&pre;': "\U2AAF",
  '&sce;': "\U2AB0", '&prE;': "\U2AB3", '&scE;': "\U2AB4",
  '&prnE;': "\U2AB5", '&scnE;': "\U2AB6", '&prap;': "\U2AB7",
  '&scap;': "\U2AB8", '&prnap;': "\U2AB9", '&scnap;': "\U2ABA",
  '&Pr;': "\U2ABB", '&Sc;': "\U2ABC", '&subdot;': "\U2ABD",
  '&supdot;': "\U2ABE", '&subplus;': "\U2ABF", '&supplus;': "\U2AC0",
  '&submult;': "\U2AC1", '&supmult;': "\U2AC2", '&subedot;': "\U2AC3",
  '&supedot;': "\U2AC4", '&subE;': "\U2AC5", '&supE;': "\U2AC6",
  '&subsim;': "\U2AC7", '&supsim;': "\U2AC8", '&subnE;': "\U2ACB",
  '&supnE;': "\U2ACC", '&csub;': "\U2ACF", '&csup;': "\U2AD0",
  '&csube;': "\U2AD1", '&csupe;': "\U2AD2", '&subsup;': "\U2AD3",
  '&supsub;': "\U2AD4", '&subsub;': "\U2AD5", '&supsup;': "\U2AD6",
  '&suphsub;': "\U2AD7", '&supdsub;': "\U2AD8", '&forkv;': "\U2AD9",
  '&topfork;': "\U2ADA", '&mlcp;': "\U2ADB", '&Dashv;': "\U2AE4",
  '&Vdashl;': "\U2AE6", '&Barv;': "\U2AE7", '&vBar;': "\U2AE8",
  '&vBarv;': "\U2AE9", '&Vbar;': "\U2AEB", '&Not;': "\U2AEC",
  '&bNot;': "\U2AED", '&rnmid;': "\U2AEE", '&cirmid;': "\U2AEF",
  '&midcir;': "\U2AF0", '&topcir;': "\U2AF1", '&nhpar;': "\U2AF2",
  '&parsim;': "\U2AF3", '&parsl;': "\U2AFD", '&fflig;': "\UFB00",
  '&filig;': "\UFB01", '&fllig;': "\UFB02", '&ffilig;': "\UFB03",
  '&ffllig;': "\UFB04", '&Ascr;': "\U1D49C", '&Cscr;': "\U1D49E",
  '&Dscr;': "\U1D49F", '&Gscr;': "\U1D4A2", '&Jscr;': "\U1D4A5",
  '&Kscr;': "\U1D4A6", '&Nscr;': "\U1D4A9", '&Oscr;': "\U1D4AA",
  '&Pscr;': "\U1D4AB", '&Qscr;': "\U1D4AC", '&Sscr;': "\U1D4AE",
  '&Tscr;': "\U1D4AF", '&Uscr;': "\U1D4B0", '&Vscr;': "\U1D4B1",
  '&Wscr;': "\U1D4B2", '&Xscr;': "\U1D4B3", '&Yscr;': "\U1D4B4",
  '&Zscr;': "\U1D4B5", '&ascr;': "\U1D4B6", '&bscr;': "\U1D4B7",
  '&cscr;': "\U1D4B8", '&dscr;': "\U1D4B9", '&fscr;': "\U1D4BB",
  '&hscr;': "\U1D4BD", '&iscr;': "\U1D4BE", '&jscr;': "\U1D4BF",
  '&kscr;': "\U1D4C0", '&lscr;': "\U1D4C1", '&mscr;': "\U1D4C2",
  '&nscr;': "\U1D4C3", '&pscr;': "\U1D4C5", '&qscr;': "\U1D4C6",
  '&rscr;': "\U1D4C7", '&sscr;': "\U1D4C8", '&tscr;': "\U1D4C9",
  '&uscr;': "\U1D4CA", '&vscr;': "\U1D4CB", '&wscr;': "\U1D4CC",
  '&xscr;': "\U1D4CD", '&yscr;': "\U1D4CE", '&zscr;': "\U1D4CF",
  '&Afr;': "\U1D504", '&Bfr;': "\U1D505", '&Dfr;': "\U1D507",
  '&Efr;': "\U1D508", '&Ffr;': "\U1D509", '&Gfr;': "\U1D50A",
  '&Jfr;': "\U1D50D", '&Kfr;': "\U1D50E", '&Lfr;': "\U1D50F",
  '&Mfr;': "\U1D510", '&Nfr;': "\U1D511", '&Ofr;': "\U1D512",
  '&Pfr;': "\U1D513", '&Qfr;': "\U1D514", '&Sfr;': "\U1D516",
  '&Tfr;': "\U1D517", '&Ufr;': "\U1D518", '&Vfr;': "\U1D519",
  '&Wfr;': "\U1D51A", '&Xfr;': "\U1D51B", '&Yfr;': "\U1D51C",
  '&afr;': "\U1D51E", '&bfr;': "\U1D51F", '&cfr;': "\U1D520",
  '&dfr;': "\U1D521", '&efr;': "\U1D522", '&ffr;': "\U1D523",
  '&gfr;': "\U1D524", '&hfr;': "\U1D525", '&ifr;': "\U1D526",
  '&jfr;': "\U1D527", '&kfr;': "\U1D528", '&lfr;': "\U1D529",
  '&mfr;': "\U1D52A", '&nfr;': "\U1D52B", '&ofr;': "\U1D52C",
  '&pfr;': "\U1D52D", '&qfr;': "\U1D52E", '&rfr;': "\U1D52F",
  '&sfr;': "\U1D530", '&tfr;': "\U1D531", '&ufr;': "\U1D532",
  '&vfr;': "\U1D533", '&wfr;': "\U1D534", '&xfr;': "\U1D535",
  '&yfr;': "\U1D536", '&zfr;': "\U1D537", '&Aopf;': "\U1D538",
  '&Bopf;': "\U1D539", '&Dopf;': "\U1D53B", '&Eopf;': "\U1D53C",
  '&Fopf;': "\U1D53D", '&Gopf;': "\U1D53E", '&Iopf;': "\U1D540",
  '&Jopf;': "\U1D541", '&Kopf;': "\U1D542", '&Lopf;': "\U1D543",
  '&Mopf;': "\U1D544", '&Oopf;': "\U1D546", '&Sopf;': "\U1D54A",
  '&Topf;': "\U1D54B", '&Uopf;': "\U1D54C", '&Vopf;': "\U1D54D",
  '&Wopf;': "\U1D54E", '&Xopf;': "\U1D54F", '&Yopf;': "\U1D550",
  '&aopf;': "\U1D552", '&bopf;': "\U1D553", '&copf;': "\U1D554",
  '&dopf;': "\U1D555", '&eopf;': "\U1D556", '&fopf;': "\U1D557",
  '&gopf;': "\U1D558", '&hopf;': "\U1D559", '&iopf;': "\U1D55A",
  '&jopf;': "\U1D55B", '&kopf;': "\U1D55C", '&lopf;': "\U1D55D",
  '&mopf;': "\U1D55E", '&nopf;': "\U1D55F", '&oopf;': "\U1D560",
  '&popf;': "\U1D561", '&qopf;': "\U1D562", '&ropf;': "\U1D563",
  '&sopf;': "\U1D564", '&topf;': "\U1D565", '&uopf;': "\U1D566",
  '&vopf;': "\U1D567", '&wopf;': "\U1D568", '&xopf;': "\U1D569",
  '&yopf;': "\U1D56A", '&zopf;': "\U1D56B"
}  # }}}
export var DictCharToEntities: dict<string>  # {{{
DictEntitiesToChar->mapnew(
  (key, value) => {
    DictCharToEntities[value] = key
    return
  }
)
lockvar DictCharToEntities  # }}}

export const MODES = {  # {{{
  n: 'normal',
  v: 'visual',
  o: 'operator-pending',
  i: 'insert',
  c: 'command-line',
  l: 'langmap',
}  # }}}

# SMARTTAGS[tag][mode][open/close/insert] = value
#  tag        - The literal tag, lowercase and without the <>'s
#               Numbers at the end of the literal tag name are stripped,
#               allowing for multiple mappings of the same tag but with
#               different effects
#  mode       - i = insert, v = visual
#               (no "o", because o-mappings invoke visual mode)
#  open/close - c = When inside an equivalent tag, close then open it
#               o = When not inside an equivalent tag
#  keystrokes - The mapping keystrokes to execute
#  insert     - Behave slightly differently in visual mappings if this is set
#               to true
export const SMARTTAGS = {  # {{{
  a1: {
    i: {
      o: "<[{A HREF=\"\"></A}]>\<C-O>F\"",
      c: "<[{/A><A HREF=\"\"}]>\<C-O>F\"",
    },
    v: {
      o: "`>a</[{A}]>\<C-O>`<<[{A HREF=\"\"}]>\<C-O>F\"",
      c: "`>a<[{A HREF=\"\"}]>\<C-O>`<</[{A}]>\<C-O>2f\"",
      insert: true
    }
  },

  a2: {
    i: {
      o: "<[{A HREF=\"\<C-R>*\"></A}]>\<C-O>F<",
      c: "<[{/A><A HREF=\"\<C-R>*\"}]>",
    },
    v: {
      o: "`>a\"></[{A}]>\<C-O>`<<[{A HREF}]=\"\<C-O>f<",
      c: "`>a\">\<C-O>`<</[{A><A HREF}]=\"\<C-O>f<",
      insert: true
    }
  },

  a3: {
    i: {
      o: "<[{A HREF=\"\" TARGET=\"\"></A}]>\<C-O>3F\"",
      c: "<[{/A><A HREF=\"\" TARGET=\"\"}]>\<C-O>3F\"",
    },
    v: {
      o: "`>a</[{A}]>\<C-O>`<<[{A HREF=\"\" TARGET=\"\"}]>\<C-O>3F\"",
      c: "`>a<[{A HREF=\"\" TARGET=\"\"}]>\<C-O>`<</[{A}]>\<C-O>2f\"",
      insert: true
    }
  },

  a4: {
    i: {
      o: "<[{A HREF=\"\<C-R>*\" TARGET=\"\"></A}]>\<C-O>F\"",
      c: "<[{/A><A HREF=\"\<C-R>*\" TARGET=\"\"}]>\<C-O>F\"",
    },
    v: {
      o: "`>a\" [{TARGET=\"\"></A}]>\<C-O>`<<[{A HREF}]=\"\<C-O>3f\"",
      c: "`>a\" [{TARGET=\"\"}]>\<C-O>`<</[{A><A HREF}]=\"\<C-O>3f\"",
      insert: true
    }
  },

  b: {
    i: {
      o: "<[{B></B}]>\<C-O>F<",
      c: "<[{/B><B}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{B}]>\<C-O>`<<[{B}]>",
      c: "`>a<[{B}]>\<C-O>`<</[{B}]>",
    }
  },

  blockquote: {
    i: {
      o: "<[{BLOCKQUOTE}]>\<CR></[{BLOCKQUOTE}]>\<Esc>O",
      c: "</[{BLOCKQUOTE}]>\<CR>\<CR><[{BLOCKQUOTE}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{BLOCKQUOTE}]>\<C-O>`<<[{BLOCKQUOTE}]>\<CR>",
      c: "`>a\<CR><[{BLOCKQUOTE}]>\<C-O>`<</[{BLOCKQUOTE}]>\<CR>",
    }
  },

  cite: {
    i: {
      o: "<[{CITE></CITE}]>\<C-O>F<",
      c: "<[{/CITE><CITE}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{CITE}]>\<C-O>`<<[{CITE}]>",
      c: "`>a<[{CITE}]>\<C-O>`<</[{CITE}]>",
    }
  },

  code: {
    i: {
      o: "<[{CODE></CODE}]>\<C-O>F<",
      c: "<[{/CODE><CODE}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{CODE}]>\<C-O>`<<[{CODE}]>",
      c: "`>a<[{CODE}]>\<C-O>`<</[{CODE}]>",
    }
  },

  comment: {
    i: {
      o: "<!--  -->\<C-O>F ",
      c: " --><!-- \<C-O>F<",
    },
    v: {
      o: "`>a -->\<C-O>`<<!-- ",
      c: "`>a<!-- \<C-O>`< -->",
    }
  },

  del: {
    i: {
      o: "<[{DEL></DEL}]>\<C-O>F<",
      c: "<[{/DEL><DEL}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{DEL}]>\<C-O>`<<[{DEL}]>",
      c: "`>a<[{DEL}]>\<C-O>`<</[{DEL}]>",
    }
  },

  dfn: {
    i: {
      o: "<[{DFN></DFN}]>\<C-O>F<",
      c: "<[{/DFN><DFN}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{DFN}]>\<C-O>`<<[{DFN}]>",
      c: "`>a<[{DFN}]>\<C-O>`<</[{DFN}]>",
    }
  },

  # Not actually used, since <div> can nest:
  div: {
    i: {
      o: "<[{DIV}]>\<CR></[{DIV}]>\<Esc>O",
      c: "</[{DIV}]>\<CR>\<CR><[{DIV}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{DIV}]>\<C-O>`<<[{DIV}]>\<CR>",
      c: "`>a\<CR><[{DIV}]>\<C-O>`<</[{DIV}]>\<CR>",
    }
  },

  em: {
    i: {
      o: "<[{EM></EM}]>\<C-O>F<",
      c: "<[{/EM><EM}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{EM}]>\<C-O>`<<[{EM}]>",
      c: "`>a<[{EM}]>\<C-O>`<</[{EM}]>",
    }
  },

  i: {
    i: {
      o: "<[{I></I}]>\<C-O>F<",
      c: "<[{/I><I}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{I}]>\<C-O>`<<[{I}]>",
      c: "`>a<[{I}]>\<C-O>`<</[{I}]>",
    }
  },

  ins: {
    i: {
      o: "<[{INS></INS}]>\<C-O>F<",
      c: "<[{/INS><INS}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{INS}]>\<C-O>`<<[{INS}]>",
      c: "`>a<[{INS}]>\<C-O>`<</[{INS}]>",
    }
  },

  kbd: {
    i: {
      o: "<[{KBD></KBD}]>\<C-O>F<",
      c: "<[{/KBD><KBD}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{KBD}]>\<C-O>`<<[{KBD}]>",
      c: "`>a<[{KBD}]>\<C-O>`<</[{KBD}]>",
    }
  },

  script: {
    i: {
      o: "\<C-O>:vim9cmd HTML#TC(false)\<CR>i<[{SCRIPT TYPE}]=\"text/javascript\">\<ESC>==o<!--\<CR>// -->\<CR></[{SCRIPT}]>\<ESC>:vim9cmd HTML#TC(true)\<CR>kko",
      c: "\<C-O>:vim9cmd HTML#TC(false)\<CR>i// -->\<CR></[{SCRIPT}]>\<CR><[{SCRIPT TYPE}]=\"text/javascript\">\<CR><!--\<CR>\<C-O>:vim9cmd HTML#TC(true)\<CR>",
    },
    v: {
      o: ":vim9cmd HTML#TC(false)\<CR>`>a\<CR>// -->\<CR></[{SCRIPT}]>\<C-O>`<<[{SCRIPT TYPE}]=\"text/javascript\">\<CR><!--\<CR>\<ESC>:vim9cmd HTML#TC(true)\<CR>",
      c: ":vim9cmd HTML#TC(false)\<CR>`>a\<CR><[{SCRIPT TYPE}]=\"text/javascript\">\<CR><!--\<C-O>`<// -->\<CR></[{SCRIPT}]>\<CR>\<ESC>:vim9cmd HTML#TC(true)\<CR>",
    }
  },

  # Not actually used, since <li> can nest:
  li: {
    i: {
      o: "<[{LI></LI}]>\<C-O>F<",
      c: "<[{/LI><LI}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{LI}]>\<C-O>`<<[{LI}]>",
      c: "`>a<[{LI}]>\<C-O>`<</[{LI}]>",
    }
  },

  mark: {
    i: {
      o: "<[{MARK></MARK}]>\<C-O>F<",
      c: "<[{/MARK><MARK}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{MARK}]>\<C-O>`<<[{MARK}]>",
      c: "`>a<[{MARK}]>\<C-O>`<</[{MARK}]>",
    }
  },

  # Not actually used, since <ol> can nest:
  ol: {
    i: {
      o: "<[{OL}]>\<CR></[{OL}]>\<Esc>O",
      c: "</[{OL}]>\<CR>\<CR><[{OL}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{OL}]>\<C-O>`<<[{OL}]>\<CR>",
      c: "`>a\<CR><[{OL}]>\<C-O>`<</[{OL}]>\<CR>",
    }
  },

  p: {
    i: {
      o: "<[{P}]>\<CR></[{P}]>\<Esc>O",
      c: "</[{P}]>\<CR>\<CR><[{P}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{P}]>\<C-O>`<<[{P}]>\<CR>",
      c: "`>a\<CR><[{P}]>\<C-O>`<</[{P}]>\<CR>",
    }
  },

  pre: {
    i: {
      o: "<[{PRE}]>\<CR></[{PRE}]>\<Esc>O",
      c: "</[{PRE}]>\<CR>\<CR><[{PRE}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{PRE}]>\<C-O>`<<[{PRE}]>\<CR>",
      c: "`>a\<CR><[{PRE}]>\<C-O>`<</[{PRE}]>\<CR>",
    }
  },

  q: {
    i: {
      o: "<[{Q></Q}]>\<C-O>F<",
      c: "<[{/Q><Q}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{Q}]>\<C-O>`<<[{Q}]>",
      c: "`>a<[{Q}]>\<C-O>`<</[{Q}]>",
    }
  },

  samp: {
    i: {
      o: "<[{SAMP></SAMP}]>\<C-O>F<",
      c: "<[{/SAMP><SAMP}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{SAMP}]>\<C-O>`<<[{SAMP}]>",
      c: "`>a<[{SAMP}]>\<C-O>`<</[{SAMP}]>",
    }
  },

  # Not actually used, since <span> can nest:
  span: {
    i: {
      o: "<[{SPAN CLASS=\"\"></SPAN}]>\<C-O>F<",
      c: "<[{/SPAN><SPAN CLASS=\"\"}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{SPAN}]>\<C-O>`<<[{SPAN CLASS=\"\"}]>",
      c: "`>a<[{SPAN CLASS=\"\"}]>\<C-O>`<</[{SPAN}]>",
    }
  },

  strong: {
    i: {
      o: "<[{STRONG></STRONG}]>\<C-O>F<",
      c: "<[{/STRONG><STRONG}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{STRONG}]>\<C-O>`<<[{STRONG}]>",
      c: "`>a<[{STRONG}]>\<C-O>`<</[{STRONG}]>",
    }
  },

  sub: {
    i: {
      o: "<[{SUB></SUB}]>\<C-O>F<",
      c: "<[{/SUB><SUB}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{SUB}]>\<C-O>`<<[{SUB}]>",
      c: "`>a<[{SUB}]>\<C-O>`<</[{SUB}]>",
    }
  },

  sup: {
    i: {
      o: "<[{SUP></SUP}]>\<C-O>F<",
      c: "<[{/SUP><SUP}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{SUP}]>\<C-O>`<<[{SUP}]>",
      c: "`>a<[{SUP}]>\<C-O>`<</[{SUP}]>",
    }
  },

  u: {
    i: {
      o: "<[{U></U}]>\<C-O>F<",
      c: "<[{/U><U}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{U}]>\<C-O>`<<[{U}]>",
      c: "`>a<[{U}]>\<C-O>`<</[{U}]>",
    }
  },

  # Not actually used, since <ul> can nest:
  ul: {
    i: {
      o: "<[{UL}]>\<CR></[{UL}]>\<Esc>O",
      c: "</[{UL}]>\<CR>\<CR><[{UL}]>\<CR>",
    },
    v: {
      o: "`>a\<CR></[{UL}]>\<C-O>`<<[{UL}]>\<CR>",
      c: "`>a\<CR><[{UL}]>\<C-O>`<</[{UL}]>\<CR>",
    }
  },

  var: {
    i: {
      o: "<[{VAR></VAR}]>\<C-O>F<",
      c: "<[{/VAR><VAR}]>\<C-O>F<",
    },
    v: {
      o: "`>a</[{VAR}]>\<C-O>`<<[{VAR}]>",
      c: "`>a<[{VAR}]>\<C-O>`<</[{VAR}]>",
    }
  },
}  # }}}

# TODO: This table needs to be expanded:
export const CHARSETS = {  # {{{
  latin1:    'ISO-8859-1',
  utf_8:     'UTF-8',
  ucs_2:     'UTF-8',
  ucs_2le:   'UTF-8',
  utf_16:    'UTF-8',
  utf_16le:  'UTF-8',
  ucs_4:     'UTF-8',
  ucs_4le:   'UTF-8',
  shift_jis: 'Shift_JIS',
  sjis:      'Shift_JIS',
  cp932:     'Shift_JIS',
  euc_jp:    'EUC-JP',
  cp950:     'Big5',
  big5:      'Big5',
  koi8_r:    'KOI8-R',
  koi8_u:    'KOI8-U',
  macroman:  'macintosh',
  cp866:     'IBM866',
  cp1250:    'windows-1250',
  cp1251:    'windows-1251',
  cp1253:    'windows-1253',
  cp1254:    'windows-1254',
  cp1255:    'windows-1255',
  cp1256:    'windows-1256',
  cp1257:    'windows-1257',
  cp1258:    'windows-1258',
  euc_kr:    'EUC-KR',
  cp936:     'GBK',
  euc_cn:    'GB2312',
}  # }}}

export const COLORS_SORT = {  # {{{
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

export const COLOR_LIST = [  # {{{
    ['Alice Blue',              '#F0F8FF', 'AliceBlue',           ],
    ['Antique White',           '#FAEBD7', 'AntiqueWhite',        ],
    ['Aqua',                    '#00FFFF', 'Aqua',                ],
    ['Aquamarine',              '#7FFFD4', 'Aquamarine',          ],
    ['Azure',                   '#F0FFFF', 'Azure',               ],

    ['Beige',                   '#F5F5DC', 'Beige',               ],
    ['Bisque',                  '#FFE4C4', 'Bisque',              ],
    ['Black',                   '#000000', 'Black',               ],
    ['Blanched Almond',         '#FFEBCD', 'BlanchedAlmond',      ],
    ['Blue',                    '#0000FF', 'Blue',                ],
    ['Blue Violet',             '#8A2BE2', 'BlueViolet',          ],
    ['Brown',                   '#A52A2A', 'Brown',               ],
    ['Burly Wood',              '#DEB887', 'BurlyWood',           ],

    ['Cadet Blue',              '#5F9EA0', 'CadetBlue',           ],
    ['Chartreuse',              '#7FFF00', 'Chartreuse',          ],
    ['Chocolate',               '#D2691E', 'Chocolate',           ],
    ['Coral',                   '#FF7F50', 'Coral',               ],
    ['Cornflower Blue',         '#6495ED', 'CornflowerBlue',      ],
    ['Cornsilk',                '#FFF8DC', 'Cornsilk',            ],
    ['Crimson',                 '#DC143C', 'Crimson',             ],
    ['Cyan',                    '#00FFFF', 'Cyan',                ],

    ['Dark Blue',               '#00008B', 'DarkBlue',            ],
    ['Dark Cyan',               '#008B8B', 'DarkCyan',            ],
    ['Dark Golden Rod',         '#B8860B', 'DarkGoldenRod',       ],
    ['Dark Gray',               '#A9A9A9', 'DarkGray',            ],
    ['Dark Green',              '#006400', 'DarkGreen',           ],
    ['Dark Grey',               '#A9A9A9', 'DarkGrey',            ],
    ['Dark Khaki',              '#BDB76B', 'DarkKhaki',           ],
    ['Dark Magenta',            '#8B008B', 'DarkMagenta',         ],
    ['Dark Olive Green',        '#556B2F', 'DarkOliveGreen',      ],
    ['Dark Orange',             '#FF8C00', 'DarkOrange',          ],
    ['Dark Orchid',             '#9932CC', 'DarkOrchid',          ],
    ['Dark Red',                '#8B0000', 'DarkRed',             ],
    ['Dark Salmon',             '#E9967A', 'DarkSalmon',          ],
    ['Dark Sea Green',          '#8FBC8F', 'DarkSeaGreen',        ],
    ['Dark Slate Blue',         '#483D8B', 'DarkSlateBlue',       ],
    ['Dark Slate Gray',         '#2F4F4F', 'DarkSlateGray',       ],
    ['Dark Slate Grey',         '#2F4F4F', 'DarkSlateGrey',       ],
    ['Dark Turquoise',          '#00CED1', 'DarkTurquoise',       ],
    ['Dark Violet',             '#9400D3', 'DarkViolet',          ],
    ['Deep Pink',               '#FF1493', 'DeepPink',            ],
    ['Deep Sky Blue',           '#00BFFF', 'DeepSkyBlue',         ],
    ['Dim Gray',                '#696969', 'DimGray',             ],
    ['Dim Grey',                '#696969', 'DimGrey',             ],
    ['Dodger Blue',             '#1E90FF', 'DodgerBlue',          ],

    ['Fire Brick',              '#B22222', 'FireBrick',           ],
    ['Floral White',            '#FFFAF0', 'FloralWhite',         ],
    ['Forest Green',            '#228B22', 'ForestGreen',         ],
    ['Fuchsia',                 '#FF00FF', 'Fuchsia',             ],

    ['Gainsboro',               '#DCDCDC', 'Gainsboro',           ],
    ['Ghost White',             '#F8F8FF', 'GhostWhite',          ],
    ['Gold',                    '#FFD700', 'Gold',                ],
    ['Golden Rod',              '#DAA520', 'GoldenRod',           ],
    ['Gray',                    '#808080', 'Gray',                ],
    ['Green',                   '#008000', 'Green',               ],
    ['Green Yellow',            '#ADFF2F', 'GreenYellow',         ],
    ['Grey',                    '#808080', 'Grey',                ],

    ['Honey Dew',               '#F0FFF0', 'HoneyDew',            ],
    ['Hot Pink',                '#FF69B4', 'HotPink',             ],
                                                                  
    ['Indian Red',              '#CD5C5C', 'IndianRed',           ],
    ['Indigo',                  '#4B0082', 'Indigo',              ],
    ['Ivory',                   '#FFFFF0', 'Ivory',               ],

    ['Khaki',                   '#F0E68C', 'Khaki',               ],

    ['Lavender',                '#E6E6FA', 'Lavender',            ],
    ['Lavender Blush',          '#FFF0F5', 'LavenderBlush',       ],
    ['Lawn Green',              '#7CFC00', 'LawnGreen',           ],
    ['Lemon Chiffon',           '#FFFACD', 'LemonChiffon',        ],
    ['Light Blue',              '#ADD8E6', 'LightBlue',           ],
    ['Light Coral',             '#F08080', 'LightCoral',          ],
    ['Light Cyan',              '#E0FFFF', 'LightCyan',           ],
    ['Light Golden Rod Yellow', '#FAFAD2', 'LightGoldenRodYellow',],
    ['Light Gray',              '#D3D3D3', 'LightGray',           ],
    ['Light Green',             '#90EE90', 'LightGreen',          ],
    ['Light Grey',              '#D3D3D3', 'LightGrey',           ],
    ['Light Pink',              '#FFB6C1', 'LightPink',           ],
    ['Light Salmon',            '#FFA07A', 'LightSalmon',         ],
    ['Light Sea Green',         '#20B2AA', 'LightSeaGreen',       ],
    ['Light Sky Blue',          '#87CEFA', 'LightSkyBlue',        ],
    ['Light Slate Gray',        '#778899', 'LightSlateGray',      ],
    ['Light Slate Grey',        '#778899', 'LightSlateGrey',      ],
    ['Light Steel Blue',        '#B0C4DE', 'LightSteelBlue',      ],
    ['Light Yellow',            '#FFFFE0', 'LightYellow',         ],
    ['Lime',                    '#00FF00', 'Lime',                ],
    ['Lime Green',              '#32CD32', 'LimeGreen',           ],
    ['Linen',                   '#FAF0E6', 'Linen',               ],

    ['Magenta',                 '#FF00FF', 'Magenta',             ],
    ['Maroon',                  '#800000', 'Maroon',              ],
    ['Medium Aqua Marine',      '#66CDAA', 'MediumAquaMarine',    ],
    ['Medium Blue',             '#0000CD', 'MediumBlue',          ],
    ['Medium Orchid',           '#BA55D3', 'MediumOrchid',        ],
    ['Medium Purple',           '#9370DB', 'MediumPurple',        ],
    ['Medium Sea Green',        '#3CB371', 'MediumSeaGreen',      ],
    ['Medium Slate Blue',       '#7B68EE', 'MediumSlateBlue',     ],
    ['Medium Spring Green',     '#00FA9A', 'MediumSpringGreen',   ],
    ['Medium Turquoise',        '#48D1CC', 'MediumTurquoise',     ],
    ['Medium Violet Red',       '#C71585', 'MediumVioletRed',     ],
    ['Midnight Blue',           '#191970', 'MidnightBlue',        ],
    ['Mint Cream',              '#F5FFFA', 'MintCream',           ],
    ['Misty Rose',              '#FFE4E1', 'MistyRose',           ],
    ['Moccasin',                '#FFE4B5', 'Moccasin',            ],

    ['Navajo White',            '#FFDEAD', 'NavajoWhite',         ],
    ['Navy',                    '#000080', 'Navy',                ],

    ['Old Lace',                '#FDF5E6', 'OldLace',             ],
    ['Olive',                   '#808000', 'Olive',               ],
    ['Olive Drab',              '#6B8E23', 'OliveDrab',           ],
    ['Orange',                  '#FFA500', 'Orange',              ],
    ['Orange Red',              '#FF4500', 'OrangeRed',           ],
    ['Orchid',                  '#DA70D6', 'Orchid',              ],

    ['Pale Golden Rod',         '#EEE8AA', 'PaleGoldenRod',       ],
    ['Pale Green',              '#98FB98', 'PaleGreen',           ],
    ['Pale Turquoise',          '#AFEEEE', 'PaleTurquoise',       ],
    ['Pale Violet Red',         '#DB7093', 'PaleVioletRed',       ],
    ['Papaya Whip',             '#FFEFD5', 'PapayaWhip',          ],
    ['Peach Puff',              '#FFDAB9', 'PeachPuff',           ],
    ['Peru',                    '#CD853F', 'Peru',                ],
    ['Pink',                    '#FFC0CB', 'Pink',                ],
    ['Plum',                    '#DDA0DD', 'Plum',                ],
    ['Powder Blue',             '#B0E0E6', 'PowderBlue',          ],
    ['Purple',                  '#800080', 'Purple',              ],

    ['Rebecca Purple',          '#663399', 'RebeccaPurple',       ],
    ['Red',                     '#FF0000', 'Red',                 ],
    ['Rosy Brown',              '#BC8F8F', 'RosyBrown',           ],
    ['Royal Blue',              '#4169E1', 'RoyalBlue',           ],

    ['Saddle Brown',            '#8B4513', 'SaddleBrown',         ],
    ['Salmon',                  '#FA8072', 'Salmon',              ],
    ['Sandy Brown',             '#F4A460', 'SandyBrown',          ],
    ['Sea Green',               '#2E8B57', 'SeaGreen',            ],
    ['Sea Shell',               '#FFF5EE', 'SeaShell',            ],
    ['Sienna',                  '#A0522D', 'Sienna',              ],
    ['Silver',                  '#C0C0C0', 'Silver',              ],
    ['Sky Blue',                '#87CEEB', 'SkyBlue',             ],
    ['Slate Blue',              '#6A5ACD', 'SlateBlue',           ],
    ['Slate Gray',              '#708090', 'SlateGray',           ],
    ['Slate Grey',              '#708090', 'SlateGrey',           ],
    ['Snow',                    '#FFFAFA', 'Snow',                ],
    ['Spring Green',            '#00FF7F', 'SpringGreen',         ],
    ['Steel Blue',              '#4682B4', 'SteelBlue',           ],

    ['Tan',                     '#D2B48C', 'Tan',                 ],
    ['Teal',                    '#008080', 'Teal',                ],
    ['Thistle',                 '#D8BFD8', 'Thistle',             ],
    ['Tomato',                  '#FF6347', 'Tomato',              ],
    ['Turquoise',               '#40E0D0', 'Turquoise',           ],

    ['Violet',                  '#EE82EE', 'Violet',              ],

    ['Wheat',                   '#F5DEB3', 'Wheat',               ],
    ['White',                   '#FFFFFF', 'White',               ],
    ['White Smoke',             '#F5F5F5', 'WhiteSmoke',          ],

    ['Yellow',                  '#FFFF00', 'Yellow',              ],
    ['Yellow Green',            '#9ACD32', 'YellowGreen',         ],
  ]   # }}}

# vim:tabstop=2:shiftwidth=0:expandtab:textwidth=78:formatoptions=croq2j:
# vim:foldmethod=marker:foldcolumn=3:comments=b\:#:commentstring=\ #\ %s:
