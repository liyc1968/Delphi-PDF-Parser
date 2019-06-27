unit digtypes;

interface
uses 
SysUtils,
Math,mylimits,freetype;
//zlibh j jvcl的组件
   const
INT_MAX=2147483647  ;
 M_PI= 3.14159265358979323846;
 M_SQRT2=1.41421356237309504880;
 FLT_EPSILON=1.192092896e-07;
 FZ_MAX_COLORS = 32;
  MAXV =7;
  MAXN = 2 + FZ_MAX_COLORS ;
AES_DECRYPT= 0;
AES_ENCRYPT= 1;
	FZ_IGNORE_IMAGE = 1;
	FZ_IGNORE_SHADE = 2;
	FZ_CHARPROC_MASK = 1;
	FZ_CHARPROC_COLOR = 2;
 MAX_FONT_SIZE =1000;
 MAX_GLYPH_SIZE= 256;
 MAX_CACHE_SIZE =(1024*1024);
  HUGENUM= 32000; // /* how far to extend axial/radial shadings */
 RADSEGS= 32; // /* how many segments to generate for radial meshes */
EEOF=-1;
MAX_KEY_LEN = 48;
	UTFmax = 4; //, /* maximum bytes per rune */
	Runesync = $80; //* cannot represent part of a UTF sequence (<) */
	Runeself = $80; //, /* rune and UTF sequences are the same (<) */
	Runeerror = $FFFD; //, /* decoding error in UTF */
	Runemax = $10FFFF; //, /* maximum rune value */
  USHRT_MAX=$ffff;


  PDF_FD_FIXED_PITCH = 1 shl 0;
	PDF_FD_SERIF = 1 shl 1;
	PDF_FD_SYMBOLIC = 1 shl 2;
	PDF_FD_SCRIPT = 1 shl 3;
	PDF_FD_NONSYMBOLIC = 1 shl 5;
	PDF_FD_ITALIC = 1 shl 6;
	PDF_FD_ALL_CAP = 1 shl 16;
	PDF_FD_SMALL_CAP = 1 shl 17;
	PDF_FD_FORCE_BOLD = 1 shl 18;
  
  PDF_ROS_CNS=0;
  PDF_ROS_GB=1;
  PDF_ROS_JAPAN=2;
  PDF_ROS_KOREA=3;
	MAXM = FZ_MAX_COLORS;
  fz_okay=0;
type fz_error=integer;
type pdf_font_kind=
( UNKNOWN, TYPE1, TRUETYPE );

type fz_objkind_e=(FZ_NULL,
	FZ_BOOL,
	FZ_INT,
	FZ_REAL,
	FZ_STRING,
	FZ_NAME,
	FZ_ARRAY,
	FZ_DICT,
	FZ_INDIRECT);
fz_objkind=fz_objkind_e;


type fz_pdfcolor_e =
(
	SAMPLE = 0,
	EXPONENTIAL = 2,
	STITCHING = 3,
	POSTSCRIPT = 4
);

type
PostScript_kind1_e=( PS_BOOL, PS_INT, PS_REAL, PS_OPERATOR, PS_BLOCK );

PostScript_kind2_e=(
	PS_OP_ABS, PS_OP_ADD, PS_OP_AND, PS_OP_ATAN, PS_OP_BITSHIFT,
	PS_OP_CEILING, PS_OP_COPY, PS_OP_COS, PS_OP_CVI, PS_OP_CVR,
	PS_OP_DIV, PS_OP_DUP, PS_OP_EQ, PS_OP_EXCH, PS_OP_EXP,
	PS_OP_FALSE, PS_OP_FLOOR, PS_OP_GE, PS_OP_GT, PS_OP_IDIV,
	PS_OP_INDEX, PS_OP_LE, PS_OP_LN, PS_OP_LOG, PS_OP_LT, PS_OP_MOD,
	PS_OP_MUL, PS_OP_NE, PS_OP_NEG, PS_OP_NOT, PS_OP_OR, PS_OP_POP,
	PS_OP_ROLL, PS_OP_ROUND, PS_OP_SIN, PS_OP_SQRT, PS_OP_SUB,
	PS_OP_TRUE, PS_OP_TRUNCATE, PS_OP_XOR, PS_OP_IF, PS_OP_IFELSE,
	PS_OP_RETURN
);
type
dword=longword;
pdword=plongword;
type
pfz_stream_s=^fz_stream_s;
read1=function(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
close1=procedure(stm:pfz_stream_s);
seek1=procedure(stm:pfz_stream_s;offset:integer;whence:integer);
drop_func_s=procedure(v:pointer);

paintfn1=procedure(bdp, sp:pbyte;  sw, sh, u,  v,  fa,  fb, w,  n,  alpha:integer; color,hp:pbyte);

fz_stream_s=record
	refs:integer;
	error:integer;
	eof:integer;
	pos:integer;
	avail:integer;
	bits:integer;
	bp, rp, wp, ep:pbyte;
	state:pointer;
   read:read1;
   close:close1;
   seek:seek1;
	 buf:array[0..4095] of byte;
end;

type pdf_crypt_e=(
	PDF_CRYPT_NONE,
	PDF_CRYPT_RC4,
	PDF_CRYPT_AESV2,
	PDF_CRYPT_AESV3,
	PDF_CRYPT_UNKNOWN);

type
pfz_obj_s=^fz_obj_s;
 ppdf_xref_s=^ pdf_xref_s;
 pppdf_xref_s=^ ppdf_xref_s;
 Pkeyval_s=^keyval_s;
 ppdf_xref_entry_s=^pdf_xref_entry_s;
 ppdf_crypt_filter_s=^pdf_crypt_filter_s;
 ppdf_crypt_s=^pdf_crypt_s;
 pppdf_crypt_s=^ppdf_crypt_s;
 pfz_hash_entry_s=^fz_hash_entry_s;
 pfz_hash_table_s=^fz_hash_table_s;
 PPfz_obj_S=^Pfz_obj_S;
 ppdf_item_s=^pdf_item_s;
 ppdf_store_s=^pdf_store_s;
keyval_s=record
 k:pfz_obj_S ;
 v:pfz_obj_S ;

end;




fzz_ogj_s1=record
 len:word;
 buf: array[0..0] of char;
end;


fzz_ogj_s2=record
 len:integer;
 cap:integer;
 items:ppfz_obj_s;
end;


fzz_ogj_s3=record
sorted:byte ;
 len:integer;
 cap:integer;
 items: pkeyval_s;
end;

fzz_ogj_s4=record
num:integer;
gen:integer;
xref:ppdf_xref_s;
end;

fzz_ogj_u=record
b:integer;
i:integer;
f:single;
case   Integer   of
1: (s:fzz_ogj_s1;);
2: (n: array[0..0] of char;);
3: (a:fzz_ogj_s2;);
4:  (d:fzz_ogj_s3;);
5:( r: fzz_ogj_s4;);
end;

fz_obj_s=record
	refs:integer;
	kind:fz_objkind ;
	u:fzz_ogj_u;
  end;

pdf_xref_entry_s=record

	ofs:integer;	//* file offset / objstm object number */
	gen:integer;	//* generation / objstm index */
	stm_ofs:integer;	//* on-disk stream */
	obj:pfz_obj_s;	//* stored/cached object */
	type1:integer;	//* 0=unset (f)ree i(n)use (o)bjstm */
end;


pdf_crypt_filter_s=record

  method:pdf_crypt_e;
 length:integer;
end;

pdf_crypt_s=record
	id: pfz_obj_s;

	v:integer;
	length:integer ;
	cf: pfz_obj_s;
	stmf:pdf_crypt_filter_s;
	strf:pdf_crypt_filter_s;
  r:integer;
	 o :array[0..47] of byte;
   u :array[0..47] of byte;
   oe:array[0..31] of byte;
   ue:array[0..31] of byte;
	 p:integer;
	 encrypt_metadata:integer ;
   key:array[0..31] of byte;
end;

 pdf_xref_s=record
	myfile:pfz_stream_s;
	version:integer;
  startxref:integer;
	file_size:integer;
  crypt:ppdf_crypt_s;
  trailer:pfz_obj_s;
	len:integer;
  table:ppdf_xref_entry_s;
	page_len:integer;
	page_cap:integer;
  page_objs:ppfz_obj_s;
  page_refs :ppfz_obj_s;
  store:ppdf_store_s;
  scratch:array[0..65535] of char;
end;

 fz_hash_entry_s=record
	key:array[0..MAX_KEY_LEN-1] of byte;
	val:pointer;
end;


fz_hash_table_s=record
	 keylen:integer;
	 size:integer;
	 load:integer;
	 ents:pfz_hash_entry_s;
end;




pdf_item_s=record
	drop_func:drop_func_s;
	key:pfz_obj_s;
	val:pointer;
	age:integer;
	next:ppdf_item_s;
end;
prefkey_s=^refkey_s;
refkey_s=record
	drop_func:pointer;
	num:integer;
	gen:integer;
end;

pdf_store_s=record
	hash:pfz_hash_table_s;	//* hash for num/gen keys */
	root:ppdf_item_s;		//* linked list for everything else */
end;

type pdf_kind_e=(PDF_TOK_ERROR, PDF_TOK_EOF,
	PDF_TOK_OPEN_ARRAY, PDF_TOK_CLOSE_ARRAY,
	PDF_TOK_OPEN_DICT, PDF_TOK_CLOSE_DICT,
	PDF_TOK_OPEN_BRACE, PDF_TOK_CLOSE_BRACE,
	PDF_TOK_NAME, PDF_TOK_INT, PDF_TOK_REAL, PDF_TOK_STRING, PDF_TOK_KEYWORD,
	PDF_TOK_R, PDF_TOK_TRUE, PDF_TOK_FALSE, PDF_TOK_NULL,
	PDF_TOK_OBJ, PDF_TOK_ENDOBJ,
	PDF_TOK_STREAM, PDF_TOK_ENDSTREAM,
	PDF_TOK_XREF, PDF_TOK_TRAILER, PDF_TOK_STARTXREF,
	PDF_NUM_TOKENS,
  TOK_USECMAP=PDF_NUM_TOKENS,
  TOK_BEGIN_CODESPACE_RANGE,     //后加的
	TOK_END_CODESPACE_RANGE,
	TOK_BEGIN_BF_CHAR,
	TOK_END_BF_CHAR,
	TOK_BEGIN_BF_RANGE,
	TOK_END_BF_RANGE,
	TOK_BEGIN_CID_CHAR,
	TOK_END_CID_CHAR,
	TOK_BEGIN_CID_RANGE,
	TOK_END_CID_RANGE,
	TOK_END_CMAP);

 TYPE
 Ppdf_kind_e=^pdf_kind_e;

type pdf_link_kind_e=(

	PDF_LINK_GOTO = 0,
	PDF_LINK_URI,
	PDF_LINK_LAUNCH,
	PDF_LINK_NAMED,
	PDF_LINK_ACTION);
type edge_kind_e =( INSIDE, OUTSIDE, LEAVE, ENTER );

type shade_kind_e =(
	FZ_LINEAR,
	FZ_RADIAL,
	FZ_MESH
);

type

pdffillkind_e=
(	PDF_FILL,
	PDF_STROKE
);

type
fillkind_e=(
	PDF_MAT_NONE,
	PDF_MAT_COLOR,
	PDF_MAT_PATTERN,
	PDF_MAT_SHADE
);

CAMP_kind_e=(PDF_CMAP_SINGLE, PDF_CMAP_RANGE, PDF_CMAP_TABLE, PDF_CMAP_MULTI );


 type
PTimeVal = ^TTimeVal;
  TTimeVal = packed record
    tv_sec: Longint;
    tv_usec: Longint;
  end;
type
ppfz_colorspace_s=^pfz_colorspace_s;
pfz_colorspace_s=^fz_colorspace_s;
to_rgb1=procedure(cs:pfz_colorspace_s; src:psingle; rgb:psingle);
from_rgb1=procedure(cs:pfz_colorspace_s; rgb:psingle;dst:psingle);
free_data1=procedure(cs:pfz_colorspace_s);
fz_colorspace_s=record
	refs:integer;
	name:array[0..16] of char;
	 n:integer;
	to_rgb:to_rgb1;     //void (*to_rgb)(fz_colorspace *, float *src, float *rgb);
	from_rgb: from_rgb1; //void (*from_rgb)(fz_colorspace *, float *rgb, float *dst);
	free_data:free_data1; //void (*free_data)(fz_colorspace *);
	data:pointer;
end;

 type
 pfz_matrix_s=^fz_matrix_s;
 fz_matrix_s= record
 a:single;
 b:single;
 c:single;
 d:single;
 e:single;
 f:single;
 end;
type
 fz_matrix=fz_matrix_s;
 pfz_matrix=pfz_matrix_s;
type
 pfz_point_s=^fz_point_s;
 fz_point_s= record
x:single;
y:single;
end;







type
 pfz_point=pfz_point_s;
 fz_point=fz_point_s;

type
 pfz_rect_s=^fz_rect_s;
 fz_rect_s  = record
  x0:single;
  y0:single;
  x1:single;
  y1:single;
end;
 type
 pfz_rect=pfz_rect_s;
 fz_rect=fz_rect_s;
type
pfz_bbox_s=^fz_bbox_s;
fz_bbox_s=record
    x0:integer;
  y0:integer;
  x1:integer;
  y1:integer;
end;
type
  pfz_bbox=pfz_bbox_s;
  fz_bbox=fz_bbox_s;


type
pfz_md5_s=^fz_md5_s;
fz_md5_s=record
	state:array[0..3] of longword;
	count:array[0..1] of longword;
	buffer:array[0..63] of byte;
end;
type
pfz_md5=pfz_md5_s;
fz_md5=fz_md5_s;
type
pfz_sha256_s=^fz_sha256_s;
fz_sha256_t=record
  case integer of
    1: (u8:array[0..63] of byte;);
	  2: (u32:array[0..15] of dword;);
end;
fz_sha256_s=record
	state:array[0..7] of dword;
	count:array[0..1] of dword;
	buffer:fz_sha256_t;
end;


type
pfz_aes_s=^fz_aes_s;
fz_aes_s=record
	nr:integer; //* number of rounds */
	rk:plongword; //* AES round keys */
	buf:array[0..67]of longword; //* unaligned data */
end;

type pfz_arc4_s=^fz_arc4_s ;
fz_arc4_s=record
	x:byte;
	y:byte;
	state:array[0..255] of byte;
end;


type
ppfz_buffer_s=^pfz_buffer_s;
pfz_buffer_s=^fz_buffer_s;
fz_buffer_s=record
	refs:integer;
	data: pbyte;
	cap:integer;
  len:integer;
end;

type
ppdf_outline_s=^pdf_outline_s;

ppdf_link_s=^pdf_link_s;
pppdf_link_s=^ppdf_link_s;
pdf_link_s=record
	kind:pdf_link_kind_e;
	rect:fz_rect;
	dest:pfz_obj_s;
	next:ppdf_link_s;
end;
pdf_outline_s=record
	title:pchar;
	link:ppdf_link_s;
	count:integer;
	child:ppdf_outline_s;
	next:ppdf_outline_s;
end;

type

ppdf_annot_s=^pdf_annot_s;
pppdf_annot_s=^ppdf_annot_s;
pppdf_xobject_s=^ppdf_xobject_s;
ppdf_xobject_s=^pdf_xobject_s;
pdf_xobject_s=record
	refs:integer ;
  matrix:fz_matrix;
	bbox:fz_rect ;
	isolated:integer ;
	knockout:integer ;
	transparency:integer;
	colorspace:pfz_colorspace_s;
	resources:pfz_obj_s;
	contents:pfz_buffer_s;
end;

pdf_annot_s=record
  obj:pfz_obj_s;
	rect:fz_rect ;
	ap:ppdf_xobject_s;
  matrix:fz_matrix;
  next	:ppdf_annot_s;
end;

type
pinfo_s=^info_s;
info_s=record
 resources:pfz_obj_s;
 mediabox:pfz_obj_s;
 cropbox:pfz_obj_s;
 rotate:pfz_obj_s;
end;
//* Null filter copies a specified amount of data */

type
 pnull_filter_s=^null_filter_s;
 null_filter_s=record
	chain:pfz_stream_s;
	remain:integer;
end;

type
pfz_ahxd_s=^fz_ahxd_s;
fz_ahxd_s=record
	chain:pfz_stream_s;
	 eod:integer;
end;




type
pppdf_page_s=^ppdf_page_s;
ppdf_page_s=^pdf_page_s;
pdf_page_s=record
	 mediabox:fz_rect;
	 rotate:integer;
	transparency:integer;
	resources:pfz_obj_s;
	contents:pfz_buffer_s;
	links:ppdf_link_s;
	annots:ppdf_annot_s;
end;
 Pfz_hash_table=pfz_hash_table_s;
fz_hash_table=fz_hash_table_s;
type keyval_items=array of  keyval_s;
type fz_obj_s_items=array of  pfz_obj_s;
type fz_buffer_s_items=array of pfz_buffer_s;
type table_items=array of pdf_xref_entry_s;
type byte_items=array of byte;
type word_items=array of word;
type integer_items=array of integer;
type single_items=array of single;
type PPfz_stream_s=^Pfz_stream_s;
//type sing2array=array of array of single; //二维数组
type sing2array=array[0..MAXV-1,0..MAXN-1] of single  ;
//type integer2array=array of array of integer; //二维数组
type integer2array=array[0..1,0..MAXN-1]of integer ;
type integer2array_1=array[0..MAXV-1,0..MAXN-1] of integer  ;
type smallint_items=array of smallint;
type FT_CharMap_items=array of FT_CharMap;
type arraypchar=array of pchar;
type parraypchar=^arraypchar;
type longword_items=array of longword;
const
    pdf_doc_encoding: array[0..255] of word =(
	$0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
	$0000, $0009, $000A, $0000, $0000, $000D, $0000, $0000,
	$0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000,
	$02d8, $02c7, $02c6, $02d9, $02dd, $02db, $02da, $02dc,
	$0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027,
	$0028, $0029, $002a, $002b, $002c, $002d, $002e, $002f,
	$0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037,
	$0038, $0039, $003a, $003b, $003c, $003d, $003e, $003f,
	$0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047,
	$0048, $0049, $004a, $004b, $004c, $004d, $004e, $004f,
	$0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057,
	$0058, $0059, $005a, $005b, $005c, $005d, $005e, $005f,
	$0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067,
	$0068, $0069, $006a, $006b, $006c, $006d, $006e, $006f,
	$0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077,
	$0078, $0079, $007a, $007b, $007c, $007d, $007e, $0000,
	$2022, $2020, $2021, $2026, $2014, $2013, $0192, $2044,
	$2039, $203a, $2212, $2030, $201e, $201c, $201d, $2018,
	$2019, $201a, $2122, $fb01, $fb02, $0141, $0152, $0160,
	$0178, $017d, $0131, $0142, $0153, $0161, $017e, $0000,
	$20ac, $00a1, $00a2, $00a3, $00a4, $00a5, $00a6, $00a7,
	$00a8, $00a9, $00aa, $00ab, $00ac, $0000, $00ae, $00af,
	$00b0, $00b1, $00b2, $00b3, $00b4, $00b5, $00b6, $00b7,
	$00b8, $00b9, $00ba, $00bb, $00bc, $00bd, $00be, $00bf,
	$00c0, $00c1, $00c2, $00c3, $00c4, $00c5, $00c6, $00c7,
	$00c8, $00c9, $00ca, $00cb, $00cc, $00cd, $00ce, $00cf,
	$00d0, $00d1, $00d2, $00d3, $00d4, $00d5, $00d6, $00d7,
	$00d8, $00d9, $00da, $00db, $00dc, $00dd, $00de, $00df,
	$00e0, $00e1, $00e2, $00e3, $00e4, $00e5, $00e6, $00e7,
	$00e8, $00e9, $00ea, $00eb, $00ec, $00ed, $00ee, $00ef,
	$00f0, $00f1, $00f2, $00f3, $00f4, $00f5, $00f6, $00f7,
	$00f8, $00f9, $00fa, $00fb, $00fc, $00fd, $00fe, $00ff
);

//* Rectangles and bounding boxes */
const

    fz_blendmode_names:array   [0..15]   of   string=(
	'Normal',
	'Multiply',
	'Screen',
	'Overlay',
	'Darken',
	'Lighten',
	'ColorDodge',
	'ColorBurn',
	'HardLight',
	'SoftLight',
	'Difference',
	'Exclusion',
	'Hue',
	'Saturation',
	'Color',
	'Luminosity'
);


const  fz_infinite_rect:fz_rect = ( X0:1; y0:1; x1:-1;y1: -1 );
const fz_empty_rect:fz_rect = ( X0:0; y0:0; x1:0;y1: 0 );
const  fz_unit_rect:fz_rect= ( X0:0; y0:0; x1:1;y1: 1 );

const  fz_infinite_bbox:fz_bbox =( X0:1; y0:1; x1:-1;y1: -1 );
const  fz_empty_bbox:fz_bbox =( X0:0; y0:0; x1:0;y1: 0 );
const  fz_unit_bbox:fz_bbox = ( X0:0; y0:0; x1:1;y1: 1 );
const fz_identity:fz_matrix  = (a: 1; b:0; c:0; d:1;e: 0;f: 0);




type
ft_error=record
 err:integer;
 str:pchar;
end;


pfz_pixmap_s=^fz_pixmap_s;
ppfz_pixmap_s=^pfz_pixmap_s;
fz_pixmap_s=record
	refs:integer;
	 x, y, w, h, n:integer;
	mask:pfz_pixmap_s; //* explicit soft/image mask */
	interpolate:integer;
	xres, yres:integer;
	colorspace:pfz_colorspace_s;
	samples:pbyte;
	free_samples:integer;
end;

type
pfz_edge_s=^fz_edge_s;
pfz_gel_s=^fz_gel_s;
ppfz_edge_s=^pfz_edge_s;
fz_edge_s=record
	 x, e, h, y:integer;
	 adj_up, adj_down:integer;
	 xmove:integer;
	 xdir, ydir:integer; //* -1 or +1 */
end;

fz_gel_s=record
	 clip:fz_bbox;
	 bbox:fz_bbox;
	 cap, len:integer;
   edges:pfz_edge_s;
   acap, alen:integer;
	 active:ppfz_edge_s;
end;

type
fz_gel_s_items=array of fz_gel_s;
pfz_gel_s_items=array of pfz_gel_s;
fz_edge_s_items=array of fz_edge_s;
pfz_edge_s_items=array of pfz_edge_s;

type fz_path_item_kind_e=
(
	FZ_MOVETO1,
	FZ_LINETO1,
	FZ_CURVETO1,
	FZ_CLOSE_PATH1
);
type
 pfz_path_item_s=^fz_path_item_s;
 pfz_path_s=^fz_path_s;
 pfz_stroke_state_s=^fz_stroke_state_s;
 fz_path_item_s=record
 case integer of
	1: (k: fz_path_item_kind_e;);
	2: (v:single;);
end;

fz_path_s=record
	len, cap:integer;
	items:pfz_path_item_s;
end;

fz_stroke_state_s=record
	start_cap:Integer; // FT_Stroker_LineCap;
  dash_cap:Integer;
  end_cap:integer;
	linejoin:Integer; //FT_Stroker_LineJoin;
	linewidth:single;
	 miterlimit:single;
	dash_phase:single;
	dash_len:integer;
	dash_list:array [0..31] of single;
end;
ppfz_shade_s=^pfz_shade_s;
pfz_shade_s=^fz_shade_s;
fz_shade_s=record
	 refs:integer;

	 bbox:fz_rect;		//* can be fz_infinite_rect */
	colorspace:pfz_colorspace_s;

	matrix:fz_matrix ;	//* matrix from pattern dict */
	use_background:integer;	//* background color for fills but not 'sh' */
	background:array[0..FZ_MAX_COLORS-1]OF single;

	 use_function:integer;
	 function1:ARRAY[0..255,0..FZ_MAX_COLORS ] OF SINGLE;

	 type1:shade_kind_e; //* linear, radial, mesh */
	extend:array[0..1] of integer;

	 mesh_len:integer;
	mesh_cap:integer;
	mesh:psingle; //* [x y 0], [x y r], [x y t] or [x y c1 ... cn] */
end;

type
pfz_text_item_s=^fz_text_item_s;
pfz_font_s=^fz_font_s;
ppfz_font_s=^pfz_font_s;
pfz_text_s=^fz_text_s;
free_user1=procedure(v:pointer);

fill_path1=procedure(v:pointer;path1:pfz_path_s; even_odd:integer;matrix: fz_matrix;colorspace: pfz_colorspace_s; color:psingle; alpha:single);
stroke_path1=procedure(v:pointer; path1:pfz_path_s; stroke_state:pfz_stroke_state_s;matrix: fz_matrix; colorspace:pfz_colorspace_s; color:psingle; alpha:single);
clip_path1=procedure(v:pointer; path1:pfz_path_s; rect:pfz_rect_s; even_odd:integer;matrix: fz_matrix);
clip_stroke_path1=procedure(v:pointer; path1:pfz_path_s; rect:pfz_rect_s; stroke_state:pfz_stroke_state_s;matrix: fz_matrix);

fill_text1=procedure(v:pointer;  text:pfz_text_s;matrix: fz_matrix; colorspace:pfz_colorspace_s;color:psingle;alpha:single);
stroke_text1=procedure(v:pointer;  text:pfz_text_s; state:pfz_stroke_state_s;matrix: fz_matrix; colorspace:pfz_colorspace_s;color:psingle; alpha:single);
clip_text1=procedure(v:pointer;  text:pfz_text_s;matrix: fz_matrix; accumulate:integer);
clip_stroke_text1=procedure(v:pointer;  text:pfz_text_s;state:pfz_stroke_state_s;matrix: fz_matrix);
ignore_text1=procedure(v:pointer;  text:pfz_text_s;matrix: fz_matrix);

fill_shade1=procedure(v:pointer;shd: pfz_shade_s; ctm:fz_matrix ; alpha:single);
fill_image1=procedure(v:pointer;img: pfz_pixmap_s; ctm:fz_matrix ; alpha:single);
fill_image_mask1=procedure(v:pointer;img: pfz_pixmap_s;ctm: fz_matrix; colorspace:pfz_colorspace_s; color:psingle; alpha:single);
clip_image_mask1=procedure(v:pointer;img: pfz_pixmap_s; rect:pfz_rect;ctm :fz_matrix );

pop_clip1=procedure(v:pointer);
begin_mask1=procedure(v:pointer;rect:fz_rect; luminosity:integer;colorspace:pfz_colorspace_s; bc:psingle);
end_mask1=procedure(v:pointer);
begin_group1=procedure(v:pointer;rect: fz_rect;  isolated:integer; knockout:integer; blendmode:integer; alpha:single);
 end_group1=procedure(v:pointer);
begin_tile1=procedure(v:pointer;area: fz_rect ; view: fz_rect; xstep:single;  ystep:single;ctm: fz_matrix);
end_tile1=procedure(v:pointer);

pfz_device_s=^fz_device_s;
fz_device_s=record
	hints:integer;
	flags:integer;

	user:pointer;
	free_user:free_user1;
  fill_path:fill_path1;
  stroke_path:stroke_path1;
  clip_path:clip_path1;
   clip_stroke_path:clip_stroke_path1;
   fill_text:fill_text1;
   stroke_text:stroke_text1;
   clip_text:clip_text1;
   clip_stroke_text:clip_stroke_text1;
   ignore_text:ignore_text1;
    fill_shade:fill_shade1;
   fill_image:fill_image1;
   fill_image_mask:fill_image_mask1;
    clip_image_mask:clip_image_mask1;
   pop_clip:pop_clip1;
   begin_mask:begin_mask1;
   end_mask:end_mask1;
   begin_group:begin_group1;
   end_group:end_group1;
   begin_tile:begin_tile1;
   end_tile:end_tile1;

end;



t3run1=function(xref:pointer; resources:pfz_obj_s; contents:pfz_buffer_s;   dev :pfz_device_s; ctm:fz_matrix):integer;
fz_text_item_s=record
	x, y:single;
  gid:integer; //* -1 for one gid to many ucs mappings */
	ucs:integer; //* -1 for one ucs to many gid mappings */
end;

fz_font_s=record
	refs:integer;
	name:array[0..31] of char;
  ft_face:FT_Face; // /* has an FT_Face if used */
	ft_substitute:integer; //* ... substitute metrics */
	ft_bold:integer; //* ... synthesize bold */
	ft_italic:integer; //* ... synthesize italic */
	ft_hint:integer; //* ... force hinting for DynaLab fonts */

	//* origin of font data */
	ft_file:pchar;
	ft_data:pbyte;
	ft_size:integer;

	t3matrix:fz_matrix_s;
	t3resources:pfz_obj_s;
	t3procs:^pfz_buffer_s; //* has 256 entries if used */
	t3widths:psingle ; //* has 256 entries if used */
	t3xref:pointer; //* a pdf_xref for the callback */
	t3run:t3run1; // (*t3run)(void *xref, fz_obj *resources, fz_buffer *contents,  		struct fz_device_s *dev, fz_matrix ctm);

	bbox:fz_rect ;

	//* substitute metrics */
	width_count:integer;
	width_table:pinteger;
end;

fz_text_s=record
	font:pfz_font_s;
  trm:	fz_matrix;
	wmode:integer;
	len, cap:integer;
	items:pfz_text_item_s;
end;

pfz_glyph_cache_s=^fz_glyph_cache_s;
pfz_glyph_key_s=^fz_glyph_key_s;
fz_glyph_cache_s=record
	hash:pfz_hash_table_s;
	total:integer;
end;

fz_glyph_key_s=record
	font:pfz_font_s;
	a, b:integer;
	c, d:integer;
	 gid:byte;
	 e, f:byte;
end;




type
fz_path_item_s_itmes=array of fz_path_item_s;

const
	FZ_DRAWDEV_FLAGS_TYPE3 = 1;
  STACK_SIZE= 96;
type
pfz_draw_device_s=^fz_draw_device_s;

stack1=record
	 scissor:	fz_bbox ;
	 dest:	pfz_pixmap_s;
		mask: pfz_pixmap_s;
		shape:pfz_pixmap_s;
		 blendmode:integer;
		 luminosity:integer;
	  alpha:single;
		ctm:fz_matrix ;
		 xstep, ystep:single;
		area:fz_rect ;
end;

fz_draw_device_s=record
	cache:pfz_glyph_cache_s;
	gel:pfz_gel_s;
  dest:pfz_pixmap_s;
  shape:pfz_pixmap_s;
	scissor:fz_bbox ;
	flags:integer;
	top:integer;
	blendmode:integer;
  stack:array[0..STACK_SIZE-1] of stack1;
end;
psctx_s=^sctx_s;
sctx_s=record
	gel:pfz_gel_s;
	ctm:pfz_matrix_s;
	flatness:single;

  linejoin:integer;
	linewidth:single;
  miterlimit:single;
	 beg:array[0..1] of fz_point_s;
	 seg:array[0..1] of fz_point_s;
	sn, bn:integer;
	dot:integer;

	dash_list:psingle;
	dash_phase:single;
	dash_len:integer;
	 toggle, cap:integer;
	offset:integer;
	 phase:single;
	 cur:fz_point_s;
end;
type
fz_text_items=array of fz_text_item_s;
type

 pfz_scale_filter_s=^fz_scale_filter_s;
 fn1=function( cs:pfz_scale_filter_s; f:single):single;
 pfz_weights_s=^fz_weights_s;
 fz_scale_filter_s=record
	width:integer;
	fn:fn1; // (*fn)(fz_scale_filter *, float);
end;
fz_weights_s=record
	count:integer;
	max_len:integer;
	n:integer;
	flip:integer;
	new_line:integer;
	index:array[0..0] of integer;
end;


ppdf_range_s=^pdf_range_s;
ppdf_cmap_s=^pdf_cmap_s;
pppdf_cmap_s=^ppdf_cmap_s;
pdf_range_s=record
	low:word;
	(* Next, we pack 2 fields into the same unsigned short. Top 14 bits
	 * are the extent, bottom 2 bits are flags: single, range, table,
	 * multi *)
	extent_flags:word;
	offset:word;	//* range-delta or table-index */
end;

kopdok_s=record
		n:word;
		 low:word;
		 high:word;
end;

pdf_cmap_s=record
	refs:integer;
	cmap_name:array[0..31] of char;

	usecmap_name:array[0..31] of char;
	usecmap:ppdf_cmap_s;

	wmode:integer;

	codespace_len:integer;
	codespace:array[0..39] of kopdok_s;

	rlen, rcap:integer;
	ranges:ppdf_range_s;

	tlen, tcap:integer;
	table:pword;
end;


ppdf_hmtx_s=^pdf_hmtx_s;
ppdf_vmtx_s=^pdf_vmtx_s;
ppdf_font_desc_s=^pdf_font_desc_s;
pppdf_font_desc_s=^ppdf_font_desc_s;
pdf_hmtx_s=record
	lo:	Word;
	hi:	Word;
	w:integer;	//* type3 fonts can be big! */
end;

pdf_vmtx_s=record
	 lo:	Word;
	 hi:	Word;
	x: SmallInt;
	y :SmallInt;
	w :SmallInt;
END;

pdf_font_desc_s=record
	refs:integer;

  font:pfz_font_s;

	//* FontDescriptor */
	flags:integer;
	italic_angle:single;
	ascent:single;
	descent:single;
	cap_height:single;
	x_height:single;
	missing_width:single;

	//* Encoding (CMap) */
	encoding:ppdf_cmap_s;
	to_ttf_cmap:ppdf_cmap_s;
	cid_to_gid_len:integer;
	cid_to_gid:pword;

	//* ToUnicode */
	to_unicode:ppdf_cmap_s;
	cid_to_ucs_len:integer;
	cid_to_ucs:pword;

	//* Metrics (given in the PDF file) */
	wmode:integer;

	hmtx_len, hmtx_cap:integer;
	 dhmtx:pdf_hmtx_s;
	hmtx:ppdf_hmtx_s;

	vmtx_len, vmtx_cap:integer;
	dvmtx:pdf_vmtx_s;
	vmtx:ppdf_vmtx_s;

	is_embedded:integer;
end;
pppdf_pattern_s=^ppdf_pattern_s;
ppdf_pattern_s=^pdf_pattern_s;
pdf_pattern_s=record
	refs:integer;
	ismask:integer;
	xstep:single;
	ystep:single;
	matrix:fz_matrix ;
	bbox:fz_rect ;
	resources:pfz_obj_s;
	contents:pfz_buffer_s;
end;

ppdf_material_s=^pdf_material_s;
pdf_material_s=record
	kind:fillkind_e;
	colorspace:pfz_colorspace_s;
	pattern:ppdf_pattern_s;
	shade:pfz_shade_s;
	alpha:single;
	v:array[0..31] of single
end;

ppdf_gstate_s=^pdf_gstate_s;
pdf_gstate_s=record
	 ctm:fz_matrix;
	 clip_depth:integer;

	//* path stroking */
    stroke_state:	fz_stroke_state_s;

	//* materials */
	 stroke:pdf_material_s;
	 fill:pdf_material_s;

	//* text state */
	char_space:single;
	word_space:single;
	scale:single;
	leading:single;
	font:ppdf_font_desc_s;
	size:single;
	render:integer;
	rise:single;

	//* transparency */
	blendmode:integer;
	softmask:ppdf_xobject_s;
	softmask_ctm:fz_matrix;
	softmask_bc:array[0..FZ_MAX_COLORS-1] of single;
	luminosity:integer;
end;
ppdf_csi_s=^pdf_csi_s;
pppdf_csi_s=^ppdf_csi_s;
pdf_csi_s=record
	dev:pfz_device_s;
	xref:ppdf_xref_s;

	//* usage mode for optional content groups */
	target:pchar; //* "View", "Print", "Export" */

	//* interpreter stack */
	obj:pfz_obj_s;
	name:array[0..255] of char;
	string1:array[0..255] of byte;
	string_len:integer;
  stack:array[0..31] of single;
	top:integer;

	xbalance:integer;
	in_text:integer;
    in_hidden_ocg:integer; //* SumatraPDF: support inline OCGs */
	//* path object state */
	path:pfz_path_s;
  //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692391 */
	 clip:integer; //* 0: none, 1: winding, 2: even-odd */
	//* text object state */
	text:pfz_text_s;
	tlm:fz_matrix;
	tm:fz_matrix;
	text_mode:integer;
	accumulate:integer;

	//* graphics state */
	top_ctm:fz_matrix;
	gstate:array[0..63] of pdf_gstate_s;
  gcap:integer;
	gtop:integer;
end;
pdf_range_s_items=array of pdf_range_s;
pdf_vmtx_s_items=array of pdf_vmtx_s;
pdf_hmtx_s_items=array of pdf_hmtx_s;

const base_font_names :array[0..13,0..6] of pchar=
(
	( 'Courier', 'CourierNew', 'CourierNewPSMT', nil,nil,nil,nil),
	( 'Courier-Bold', 'CourierNew,Bold', 'Courier,Bold',		'CourierNewPS-BoldMT', 'CourierNew-Bold', nil,nil),
	( 'Courier-Oblique', 'CourierNew,Italic', 'Courier,Italic', 		'CourierNewPS-ItalicMT', 'CourierNew-Italic', nil,nil),
	( 'Courier-BoldOblique', 'CourierNew,BoldItalic', 'Courier,BoldItalic',	'CourierNewPS-BoldItalicMT', 'CourierNew-BoldItalic', nil,nil ),
	( 'Helvetica', 'ArialMT', 'Arial', nil,nil,nil,nil ),
	( 'Helvetica-Bold', 'Arial-BoldMT', 'Arial,Bold', 'Arial-Bold', 	'Helvetica,Bold', nil,nil ),
	( 'Helvetica-Oblique', 'Arial-ItalicMT', 'Arial,Italic', 'Arial-Italic', 	'Helvetica,Italic', 'Helvetica-Italic', nil ),
	( 'Helvetica-BoldOblique', 'Arial-BoldItalicMT', 	'Arial,BoldItalic', 'Arial-BoldItalic',		'Helvetica,BoldItalic', 'Helvetica-BoldItalic', nil ),
	( 'Times-Roman', 'TimesNewRomanPSMT', 'TimesNewRoman',	'TimesNewRomanPS', nil,nil,nil ),
	( 'Times-Bold', 'TimesNewRomanPS-BoldMT', 'TimesNewRoman,Bold',	'TimesNewRomanPS-Bold', 'TimesNewRoman-Bold', nil,nil ),
	( 'Times-Italic', 'TimesNewRomanPS-ItalicMT', 'TimesNewRoman,Italic',  'TimesNewRomanPS-Italic', 'TimesNewRoman-Italic', nil ,nil),
	( 'Times-BoldItalic', 'TimesNewRomanPS-BoldItalicMT',	'TimesNewRoman,BoldItalic', 'TimesNewRomanPS-BoldItalic',		'TimesNewRoman-BoldItalic', nil,nil ),
	( 'Symbol', nil,nil,nil,nil,nil,nil ),
	( 'ZapfDingbats', nil,nil,nil,nil,nil,nil )
);

const
  _notdef=nil;

const  pdf_standard:array[0..255] of pchar = ( _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	'space', 'exclam', 'quotedbl', 'numbersign', 'dollar', 'percent',
	'ampersand', 'quoteright', 'parenleft', 'parenright', 'asterisk',
	'plus', 'comma', 'hyphen', 'period', 'slash', 'zero', 'one', 'two',
	'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'colon',
	'semicolon', 'less', 'equal', 'greater', 'question', 'at', 'A',
	'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
	'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
	'bracketleft', 'backslash', 'bracketright', 'asciicircum', 'underscore',
	'quoteleft', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
	'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
	'y', 'z', 'braceleft', 'bar', 'braceright', 'asciitilde', _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, 'exclamdown', 'cent', 'sterling',
	'fraction', 'yen', 'florin', 'section', 'currency', 'quotesingle',
	'quotedblleft', 'guillemotleft', 'guilsinglleft', 'guilsinglright',
	'fi', 'fl', _notdef, 'endash', 'dagger', 'daggerdbl', 'periodcentered',
	_notdef, 'paragraph', 'bullet', 'quotesinglbase', 'quotedblbase',
	'quotedblright', 'guillemotright', 'ellipsis', 'perthousand',
	_notdef, 'questiondown', _notdef, 'grave', 'acute', 'circumflex',
	'tilde', 'macron', 'breve', 'dotaccent', 'dieresis', _notdef,
	'ring', 'cedilla', _notdef, 'hungarumlaut', 'ogonek', 'caron',
	'emdash', _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, 'AE',
	_notdef, 'ordfeminine', _notdef, _notdef, _notdef, _notdef,
	'Lslash', 'Oslash', 'OE', 'ordmasculine', _notdef, _notdef,
	_notdef, _notdef, _notdef, 'ae', _notdef, _notdef,
	_notdef, 'dotlessi', _notdef, _notdef, 'lslash', 'oslash',
	'oe', 'germandbls', _notdef, _notdef, _notdef, _notdef
);

const pdf_mac_roman:array[0..255] of pchar = ( _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	'space', 'exclam', 'quotedbl', 'numbersign', 'dollar', 'percent',
	'ampersand', 'quotesingle', 'parenleft', 'parenright', 'asterisk',
	'plus', 'comma', 'hyphen', 'period', 'slash', 'zero', 'one', 'two',
	'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'colon',
	'semicolon', 'less', 'equal', 'greater', 'question', 'at', 'A',
	'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
	'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
	'bracketleft', 'backslash', 'bracketright', 'asciicircum', 'underscore',
	'grave', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
	'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
	'y', 'z', 'braceleft', 'bar', 'braceright', 'asciitilde', _notdef,
	'Adieresis', 'Aring', 'Ccedilla', 'Eacute', 'Ntilde', 'Odieresis',
	'Udieresis', 'aacute', 'agrave', 'acircumflex', 'adieresis', 'atilde',
	'aring', 'ccedilla', 'eacute', 'egrave', 'ecircumflex', 'edieresis',
	'iacute', 'igrave', 'icircumflex', 'idieresis', 'ntilde', 'oacute',
	'ograve', 'ocircumflex', 'odieresis', 'otilde', 'uacute', 'ugrave',
	'ucircumflex', 'udieresis', 'dagger', 'degree', 'cent', 'sterling',
	'section', 'bullet', 'paragraph', 'germandbls', 'registered',
	'copyright', 'trademark', 'acute', 'dieresis', _notdef, 'AE',
	'Oslash', _notdef, 'plusminus', _notdef, _notdef, 'yen', 'mu',
	_notdef, _notdef, _notdef, _notdef, _notdef, 'ordfeminine',
	'ordmasculine', _notdef, 'ae', 'oslash', 'questiondown', 'exclamdown',
	'logicalnot', _notdef, 'florin', _notdef, _notdef, 'guillemotleft',
	'guillemotright', 'ellipsis', 'space', 'Agrave', 'Atilde', 'Otilde',
	'OE', 'oe', 'endash', 'emdash', 'quotedblleft', 'quotedblright',
	'quoteleft', 'quoteright', 'divide', _notdef, 'ydieresis',
	'Ydieresis', 'fraction', 'currency', 'guilsinglleft', 'guilsinglright',
	'fi', 'fl', 'daggerdbl', 'periodcentered', 'quotesinglbase',
	'quotedblbase', 'perthousand', 'Acircumflex', 'Ecircumflex', 'Aacute',
	'Edieresis', 'Egrave', 'Iacute', 'Icircumflex', 'Idieresis', 'Igrave',
	'Oacute', 'Ocircumflex', _notdef, 'Ograve', 'Uacute', 'Ucircumflex',
	'Ugrave', 'dotlessi', 'circumflex', 'tilde', 'macron', 'breve',
	'dotaccent', 'ring', 'cedilla', 'hungarumlaut', 'ogonek', 'caron'
);

const pdf_mac_expert:array[0..255] of pchar= ( _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	'space', 'exclamsmall', 'Hungarumlautsmall', 'centoldstyle',
	'dollaroldstyle', 'dollarsuperior', 'ampersandsmall', 'Acutesmall',
	'parenleftsuperior', 'parenrightsuperior', 'twodotenleader',
	'onedotenleader', 'comma', 'hyphen', 'period', 'fraction',
	'zerooldstyle', 'oneoldstyle', 'twooldstyle', 'threeoldstyle',
	'fouroldstyle', 'fiveoldstyle', 'sixoldstyle', 'sevenoldstyle',
	'eightoldstyle', 'nineoldstyle', 'colon', 'semicolon', _notdef,
	'threequartersemdash', _notdef, 'questionsmall', _notdef,
	_notdef, _notdef, _notdef, 'Ethsmall', _notdef, _notdef,
	'onequarter', 'onehalf', 'threequarters', 'oneeighth', 'threeeighths',
	'fiveeighths', 'seveneighths', 'onethird', 'twothirds', _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, 'ff', 'fi',
	'fl', 'ffi', 'ffl', 'parenleftinferior', _notdef, 'parenrightinferior',
	'Circumflexsmall', 'hypheninferior', 'Gravesmall', 'Asmall', 'Bsmall',
	'Csmall', 'Dsmall', 'Esmall', 'Fsmall', 'Gsmall', 'Hsmall', 'Ismall',
	'Jsmall', 'Ksmall', 'Lsmall', 'Msmall', 'Nsmall', 'Osmall', 'Psmall',
	'Qsmall', 'Rsmall', 'Ssmall', 'Tsmall', 'Usmall', 'Vsmall', 'Wsmall',
	'Xsmall', 'Ysmall', 'Zsmall', 'colonmonetary', 'onefitted', 'rupiah',
	'Tildesmall', _notdef, _notdef, 'asuperior', 'centsuperior',
	_notdef, _notdef, _notdef, _notdef, 'Aacutesmall',
	'Agravesmall', 'Acircumflexsmall', 'Adieresissmall', 'Atildesmall',
	'Aringsmall', 'Ccedillasmall', 'Eacutesmall', 'Egravesmall',
	'Ecircumflexsmall', 'Edieresissmall', 'Iacutesmall', 'Igravesmall',
	'Icircumflexsmall', 'Idieresissmall', 'Ntildesmall', 'Oacutesmall',
	'Ogravesmall', 'Ocircumflexsmall', 'Odieresissmall', 'Otildesmall',
	'Uacutesmall', 'Ugravesmall', 'Ucircumflexsmall', 'Udieresissmall',
	_notdef, 'eightsuperior', 'fourinferior', 'threeinferior',
	'sixinferior', 'eightinferior', 'seveninferior', 'Scaronsmall',
	_notdef, 'centinferior', 'twoinferior', _notdef, 'Dieresissmall',
	_notdef, 'Caronsmall', 'osuperior', 'fiveinferior', _notdef,
	'commainferior', 'periodinferior', 'Yacutesmall', _notdef,
	'dollarinferior', _notdef, _notdef, 'Thornsmall', _notdef,
	'nineinferior', 'zeroinferior', 'Zcaronsmall', 'AEsmall', 'Oslashsmall',
	'questiondownsmall', 'oneinferior', 'Lslashsmall', _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, 'Cedillasmall',
	_notdef, _notdef, _notdef, _notdef, _notdef, 'OEsmall',
	'figuredash', 'hyphensuperior', _notdef, _notdef, _notdef,
	_notdef, 'exclamdownsmall', _notdef, 'Ydieresissmall', _notdef,
	'onesuperior', 'twosuperior', 'threesuperior', 'foursuperior',
	'fivesuperior', 'sixsuperior', 'sevensuperior', 'ninesuperior',
	'zerosuperior', _notdef, 'esuperior', 'rsuperior', 'tsuperior',
	_notdef, _notdef, 'isuperior', 'ssuperior', 'dsuperior',
	_notdef, _notdef, _notdef, _notdef, _notdef, 'lsuperior',
	'Ogoneksmall', 'Brevesmall', 'Macronsmall', 'bsuperior', 'nsuperior',
	'msuperior', 'commasuperior', 'periodsuperior', 'Dotaccentsmall',
	'Ringsmall', _notdef, _notdef, _notdef, _notdef );

const pdf_win_ansi:array[0..255] of pchar = ( _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, _notdef,
	_notdef, _notdef, _notdef, _notdef, _notdef, 'space',
	'exclam', 'quotedbl', 'numbersign', 'dollar', 'percent', 'ampersand',
	'quotesingle', 'parenleft', 'parenright', 'asterisk', 'plus',
	'comma', 'hyphen', 'period', 'slash', 'zero', 'one', 'two', 'three',
	'four', 'five', 'six', 'seven', 'eight', 'nine', 'colon', 'semicolon',
	'less', 'equal', 'greater', 'question', 'at', 'A', 'B', 'C', 'D',
	'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q',
	'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'bracketleft',
	'backslash', 'bracketright', 'asciicircum', 'underscore', 'grave',
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
	'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
	'braceleft', 'bar', 'braceright', 'asciitilde', 'bullet', 'Euro',
	'bullet', 'quotesinglbase', 'florin', 'quotedblbase', 'ellipsis',
	'dagger', 'daggerdbl', 'circumflex', 'perthousand', 'Scaron',
	'guilsinglleft', 'OE', 'bullet', 'Zcaron', 'bullet', 'bullet',
	'quoteleft', 'quoteright', 'quotedblleft', 'quotedblright', 'bullet',
	'endash', 'emdash', 'tilde', 'trademark', 'scaron', 'guilsinglright',
	'oe', 'bullet', 'zcaron', 'Ydieresis', 'space', 'exclamdown', 'cent',
	'sterling', 'currency', 'yen', 'brokenbar', 'section', 'dieresis',
	'copyright', 'ordfeminine', 'guillemotleft', 'logicalnot', 'hyphen',
	'registered', 'macron', 'degree', 'plusminus', 'twosuperior',
	'threesuperior', 'acute', 'mu', 'paragraph', 'periodcentered',
	'cedilla', 'onesuperior', 'ordmasculine', 'guillemotright',
	'onequarter', 'onehalf', 'threequarters', 'questiondown', 'Agrave',
	'Aacute', 'Acircumflex', 'Atilde', 'Adieresis', 'Aring', 'AE',
	'Ccedilla', 'Egrave', 'Eacute', 'Ecircumflex', 'Edieresis', 'Igrave',
	'Iacute', 'Icircumflex', 'Idieresis', 'Eth', 'Ntilde', 'Ograve',
	'Oacute', 'Ocircumflex', 'Otilde', 'Odieresis', 'multiply', 'Oslash',
	'Ugrave', 'Uacute', 'Ucircumflex', 'Udieresis', 'Yacute', 'Thorn',
	'germandbls', 'agrave', 'aacute', 'acircumflex', 'atilde', 'adieresis',
	'aring', 'ae', 'ccedilla', 'egrave', 'eacute', 'ecircumflex',
	'edieresis', 'igrave', 'iacute', 'icircumflex', 'idieresis', 'eth',
	'ntilde', 'ograve', 'oacute', 'ocircumflex', 'otilde', 'odieresis',
	'divide', 'oslash', 'ugrave', 'uacute', 'ucircumflex', 'udieresis',
	'yacute', 'thorn', 'ydieresis'
);

type
array256=array[0..256-1] of pchar;
parray256=^array256;
CONST  cp936fonts:array[0..10] of Pchar=(
			'\xCB\xCE\xCC\xE5', 'SimSun,Regular',
			'\xBA\xDA\xCC\xE5', 'SimHei,Regular',
			'\xBF\xAC\xCC\xE5_GB2312', 'SimKai,Regular',
			'\xB7\xC2\xCB\xCE_GB2312', 'SimFang,Regular',
			'\xC1\xA5\xCA\xE9', 'SimLi,Regular',
			nil );


type
ppsobj_s=^psobj_s;
psobj1_s=record
  case   Integer   of
   1:( b:integer);				//* boolean (stack only) */
	 2:(	i:integer);				//* integer (stack and code) */
	 3:(	f:single);			//* real (stack and code) */
	 4:(	op:integer);			//* operator (code only) */
		5:(block:integer);
end;

psobj_s=record
	type1:integer;
	u: psobj1_s;
end;
pppdf_function_s=^ppdf_function_s;
ppdf_function_s=^pdf_function_s;
pdf_function1_s=record
 bps:word;
 size:array[0..MAXM-1] of integer;
 encode:array[0..MAXM-1,0..1] of single;
 decode:array[0..MAXN-1,0..1] of single;
 samples:psingle;
end;

pdf_function2_s=record
 n:single;
 c0:array[0..MAXN-1] of single;
 c1:array[0..MAXN-1] of single;
end;

pdf_function3_s=record
 k:integer;
 funcs:pppdf_function_s;  //* k */
 bounds:psingle; //* k - 1 */
 encode:psingle; //* k * 2 */
end;
pdf_function4_s=record
code:ppsobj_s;
cap:integer;
end;
pdf_function_aa_s=record
case integer of
1:(sa:pdf_function1_s);
2:(e:pdf_function2_s);
3:(st:pdf_function3_s );
4: (p:pdf_function4_s);
end;

 pdf_function_s=record
  refs:integer;
	type1:integer;				//* 0=sample 2=exponential 3=stitching 4=postscript */
	m:integer;					//* number of input values */
	n:integer;					//* number of output values */
	domain:array[0..MAXM-1,0..1] of single;	//* even index : min value, odd index : max value */
	range:array[0..MAXM-1,0..1] of single;	//* even index : min value, odd index : max value */
	has_range:integer;
  u:pdf_function_aa_s;
end;

pps_stack_s=^ps_stack_s;
ps_stack_s=record
	stack:array[0..99] of psobj_s;
	sp:integer;
end;
pindexed_s=^indexed_s;
indexed_s=record
	base:pfz_colorspace_s;
	high:integer;
	lookup:pbyte;
end;

type
psobj_s_items=array of psobj_s;
ppdf_function_s_items=array of ppdf_function_s;

fz_point_s_items=array of fz_point_s;


type
pfz_text_char_s=^fz_text_char_s;
fz_text_char_s=record
	c:integer;
	bbox:fz_bbox;
end;
ppfz_text_span_s=^pfz_text_span_s;
pfz_text_span_s=^fz_text_span_s;
fz_text_span_s=record
	font:pfz_font_s;
	size:single;
	wmode:integer;
	len, cap:integer;
	text:pfz_text_char_s;
	next:pfz_text_span_s;
	eol:integer;
end;

type
  fz_text_char_s_items=array of fz_text_char_s;
  pparray256=^parray256;
type
 pfz_text_device_s=^fz_text_device_s;
 fz_text_device_s=record
	point:fz_point_s;
	head:pfz_text_span_s;
	span:pfz_text_span_s;
end;

type
fz_hash_entry_s_items=array of fz_hash_entry_s;


type
   pfz_bitmap_s=^fz_bitmap_s;
   fz_bitmap_s=record
	 refs:integer;
	 w, h, stride, n:integer;
	 samples:pbyte;
end;
var
ppppppppppp:integer;

implementation

end.
