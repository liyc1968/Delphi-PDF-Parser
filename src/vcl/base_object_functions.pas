unit base_object_functions;

interface
uses
 SysUtils,Math,digtypes,QSort1,base_error,cUnicodeCodecs;

const
  Bit1 = 7;
	Bitx = 6;
	Bit2 = 5;
	Bit3 = 4;
	Bit4 = 3;
	Bit5 = 2;

	T1 =0; // ((1 shl (Bit1+1))-1) xor $FF; //, /* 0000 0000 */
	Tx =128; // ((1 shl (Bitx+1))-1) xor $FF; //, /* 1000 0000 */
	T2 =192; // ((1 shl (Bit2+1))-1) xor $FF;  //, /* 1100 0000 */
	T3 =224; // ((1 shl (Bit3+1))-1) xor $FF;  //, /* 1110 0000 */
	T4 =240; // ((1 shl (Bit4+1))-1) xor $FF; //, /* 1111 0000 */
	T5 =248; // ((1 shl (Bit5+1))-1) xor $FF; //, /* 1111 1000 */

	Rune1 =127; // (1 shl (Bit1+0*Bitx))-1; //, /* 0000 0000 0111 1111 */
	Rune2 =2047; // (1 shl (Bit2+1*Bitx))-1; //, /* 0000 0111 1111 1111 */
	Rune3 =65535; // (1 shl (Bit3+2*Bitx))-1; //, /* 1111 1111 1111 1111 */
	Rune4 =2097151; // (1 shl (Bit4+3*Bitx))-1; //, /* 0001 1111 1111 1111 1111 1111 */

	Maskx =63; // (1 shl Bitx)-1; //,	/* 0011 1111 */
	Testx =192; // Maskx ^ $FF; //,	/* 1100 0000 */

	Bad = Runeerror; //,
function strerror(i:integer):pchar;
PROCEDURE DDDD;
function atoi(const buf:pchar):integer;
function CLAMP(x,a,b:double):double;   overload;
function CLAMP(x,a,b:integer):integer; overload;
//function gettimeofday(Tv: PTimeVal):integer;

//* memory allocation */
function fz_malloc(size:integer):pointer;
function  fz_calloc(count,size:integer):pointer;
function  fz_realloc(p:pointer; count, size:integer):pointer;
procedure   fz_free(p:pointer);
function  fz_strdup(s:pchar):pchar;
//* runtime (hah!) test for endian-ness */
FUNCTION fz_is_big_endian():INTEGER;

//* safe string functions */
function fz_strsep(stringp:ppchar;const delim:pchar):pchar;
function  fz_strlcpy(dst:pchar;  const src:pchar;siz:integer):integer;
function  fz_strlcat(dst:pchar;  const src:pchar;n:integer):integer;
//* Range checking atof */
function fz_atof(s:pchar):single;

//* utf-8 encoding and decoding */
function chartorune(rune:pinteger;str:pchar):integer;
function runetochar(str:pchar;rune:pinteger):integer;
function runelen(c:integer):integer;

//* getopt */
function  fz_getopt( nargc:integer; nargv:pchar; ostr:pchar):integer;
function  fz_optind: integer;
function    fz_optarg:pchar;
 // * Generic hash-table with fixed-length keys.
function  fz_new_hash_table(initialsize, keylen:integer):Pfz_hash_table;
procedure fz_debug_hash(table:pfz_hash_table);
procedure fz_empty_hash(table:pfz_hash_table);
procedure fz_free_hash(table:pfz_hash_table);
function  fz_hash_find(table:pfz_hash_table; key:pointer):pointer;
procedure fz_hash_insert(table:pfz_hash_table; key:pointer; val:pointer);
procedure fz_hash_remove(table:pfz_hash_table; key:pointer);
function  fz_hash_len(table:pfz_hash_table):INTEGER;
function  fz_hash_get_key(table:pfz_hash_table; idx:INTEGER):POINTER;
function  fz_hash_get_val(table:pfz_hash_table; idx:INTEGER):POINTER;
//* * Math and geometry /* Multiply scaled two integers in the 0..255 range */
function  fz_concat(one:fz_matrix;two:fz_matrix):fz_matrix;
function fz_scale(sx, sy:single):fz_matrix;

function fz_mul255(a,b:integer):integer;
function fz_shear(sx,sy:single):fz_matrix;
function  fz_rotate(theta:single):fz_matrix;
function fz_translate(tx, ty:single):fz_matrix ;
function fz_invert_matrix(src:fz_matrix ):fz_matrix ;
function fz_is_rectilinear(m:fz_matrix):integer;
function fz_matrix_expansion(m:fz_matrix):single;
function fz_round_rect(r:fz_rect ):fz_bbox;
function fz_intersect_bbox(a,b:fz_bbox): fz_bbox;
function fz_intersect_rect(a,b:fz_rect): fz_rect;
function  fz_union_bbox(a,b:fz_bbox):fz_bbox;
function  fz_union_rect(a,b:fz_rect):fz_rect;
function  fz_transform_point(m:fz_matrix;p:fz_point):fz_point;
function  fz_transform_vector(m:fz_matrix;p:fz_point):fz_point;
function  fz_transform_rect(m:fz_matrix;r:fz_rect):fz_rect;
function  fz_transform_bbox(m:fz_matrix;b:fz_bbox):fz_bbox;
function fz_new_dict(initialcap:integer):pfz_obj_s;
procedure fz_free_array(obj:pfz_obj_s) ;
procedure fz_drop_obj(obj:pfz_obj_s);
procedure fz_free_dict(obj:pfz_obj_s) ;
function fz_new_name(str:pchar): pfz_obj_s;
function fz_new_array(initialcap:integer):pfz_obj_s;
function fz_new_int(i:integer) :pfz_obj_s;
procedure fz_array_push(obj:pfz_obj_s;item:pfz_obj_s) ;
function fz_is_array(obj:pfz_obj_s):boolean;
function fz_keep_obj(obj:pfz_obj_s) :pfz_obj_s;
function fz_new_indirect(num, gen:integer; xref:pointer) :pfz_obj_s ;
function fz_new_real(f:single):pfz_obj_s ;
function  fz_new_string(str:pchar; len:integer):pfz_obj_s ;
function  fz_new_bool(b:integer):pfz_obj_s ;
function fz_new_null():pfz_obj_s ;
procedure fz_dict_put(obj:pfz_obj_s;  key:pfz_obj_s; val:pfz_obj_s);
function fz_dict_get_key(obj:pfz_obj_s; i:integer):pfz_obj_s  ;
function fz_dict_get_val(obj:pfz_obj_s; i:integer):pfz_obj_s  ;
function fz_dict_gets(obj:pfz_obj_s; key:pchar) :pfz_obj_s;
procedure pdf_resize_xref(xref:ppdf_xref_s; newlen:integer);
function fz_to_int(obj:pfz_obj_s):integer;
function fz_to_name(obj:pfz_obj_s):pchar;
function fz_to_num(obj:pfz_obj_s) :integer;
function fz_array_get(obj:pfz_obj_s;i:integer):pfz_obj_s;
function fz_is_name(obj:pfz_obj_s):boolean;
function fz_is_int(obj:pfz_obj_s):boolean;
function fz_is_dict(obj:pfz_obj_s):boolean;
function fz_is_string(obj:pfz_obj_s):boolean;
function fz_to_str_len(obj:pfz_obj_s):integer;
function fz_to_str_buf(obj:pfz_obj_s) :pchar ;
function fz_to_gen(obj:pfz_obj_s):integer;
function fz_is_bool(obj:pfz_obj_s):boolean;
function fz_to_bool(obj:pfz_obj_s):integer;
function fz_array_len(obj:pfz_obj_s):integer;
function fz_is_indirect(obj:pfz_obj_s):boolean;
procedure fz_set_str_len(obj:pfz_obj_s; newlen:integer);
function fz_dict_len(obj:pfz_obj_s):integer;
function fz_dict_getsa(obj:pfz_obj_s; key:pchar; abbrev:pchar):pfz_obj_s;

//function fz_new_buffer( size:integer):pfz_buffer_s;
procedure fz_drop_buffer(buf:pfz_buffer_s);
function fz_keep_buffer(buf:pfz_buffer_s):pfz_buffer_s;
procedure fz_resize_buffer(buf:pfz_buffer_s;  size:integer) ;
procedure fz_grow_buffer(buf:pfz_buffer_s) ;
function fz_new_buffer( size:integer):pfz_buffer_s;
function fz_is_null(obj:pfz_obj_s):boolean;
function pdf_to_utf8(src:pfz_obj_s):pchar;
procedure fz_dict_puts(obj:pfz_obj_s; key:pchar; val:pfz_obj_s);
procedure fz_dict_dels(obj:pfz_obj_s; key:pchar);
function fz_resolve_indirect(obj:pfz_obj_s):pfz_obj_s;
 function memcmp(cs,ct:Pointer; count:Cardinal):Integer;
 function fz_objcmp(a:pfz_obj_s;b:pfz_obj_s):integer;
 function pdf_to_rect(array1:pfz_obj_s) :fz_rect ;
 function fz_is_empty_rect(r:fz_rect):boolean; overload;
 function fz_is_empty_rect(r:fz_bbox):boolean; overload;
 function fz_dict_get(obj:pfz_obj_s; key:pfz_obj_s):pfz_obj_s;
 function pdf_to_utf8_name(src:pfz_obj_s):pfz_obj_s;
 function pdf_to_matrix(array1:pfz_obj_s) :fz_matrix ;
 function pdf_resolve_indirect(ref:pfz_obj_s): pfz_obj_s;
 function fz_debug_dict_gets(obj:pfz_obj_s) :pfz_obj_s;
 function fz_is_infinite_rect(r:fz_bbox):boolean; overload;
 function fz_is_infinite_rect(r:fz_rect):boolean;overload;
 function FZ_EXPAND(A:integer):integer;
 function FZ_COMBINE(A,B:integer):integer;
 function FZ_COMBINE2(A,B,C,D:integer):integer;
 function FZ_BLEND(SRC, DST, AMOUNT:integer):integer;
 function strstr(a:pchar;b:pchar):pchar  ;
 function strchr(a:pchar;b:pchar):pchar  ;
 function fz_is_real(obj:pfz_obj_s):boolean;
 function fz_to_real(obj:pfz_obj_s):single;
 function fz_objkindstr(obj:pfz_obj_s):pchar;
 function getwidestr(mypchar:pchar):widestring;
 function  fz_is_infinite_bbox(b:fz_bbox):boolean; overload;
 function fz_is_empty_bbox(b:fz_bbox) :boolean;
 function fz_span_to_wchar( text:pfz_text_span_s; lineSep:pchar):widestring;
 function getwidestrs(s:string):widestring;
 procedure copymemory(s,c:pointer;lenn:integer);
 procedure zeromemory(p:pointer;lenn:integer);
 
 function fz_hash_get_Pval(table:pfz_hash_table; idx:INTEGER):POINTER;  //指针的指针


implementation
uses FZ_mystreams,mypdfstream;

//function _malloc(Size: Integer): Pointer; cdecl; external 'MSVCRT.DLL' name 'malloc';
{ Allocates memory block of size Size }

//function _realloc(P: Pointer; Size: Integer): Pointer; cdecl; external 'MSVCRT.DLL' name 'realloc';
{ Reallocates memory block allocated with _malloc to size Size and returns new pointer }

//procedure _free(P: pointer); cdecl; external 'MSVCRT.DLL' name 'free';
 
function strstr(a:pchar;b:pchar):pchar  ;
var
i:integer;
begin
  i:=pos(b,a);
  if i=0 then
  result:=nil
  else
  result:=pointer(cardinal(a)+i-1);
end;

function strchr(a:pchar;b:pchar):pchar  ;
var
i:integer;
begin
  i:=pos(b,a);
  if i=0 then
  result:=nil
  else
  result:=pointer(cardinal(a)+i);
end;
function FZ_EXPAND(A:integer):integer;
begin
 result:=(A+(A shr 7)) ;
end;

function FZ_COMBINE(A,B:integer):integer;
begin
 result:=((A*B) shr 8)
end;

function FZ_COMBINE2(A,B,C,D:integer):integer;
begin
 result:=(FZ_COMBINE((A), (B)) + FZ_COMBINE((C), (D)))  ;
end;

function FZ_BLEND(SRC, DST, AMOUNT:integer):integer;
begin
 result:=((((SRC)-(DST))*(AMOUNT) + ((DST) SHL 8)) SHR 8)
end;


function fz_resolve_indirect(obj:pfz_obj_s):pfz_obj_s;
begin

 result:=pdf_resolve_indirect(obj);

end;
FUNCTION fz_empty_rect:fz_rect;
BEGIN
    RESULT.x0:=0;
    RESULT.Y0:=0;
    RESULT.x1:=0;
    RESULT.Y1:=0;
END;

FUNCTION fz_empty_bbox:fz_bbox;
begin
  RESULT.x0:=0;
    RESULT.Y0:=0;
    RESULT.x1:=0;
    RESULT.Y1:=0;
end;
{
function gettimeofday(Tv: PTimeVal):integer;
VAR
	ft:FILETIME ;
	tmpres:INT64;
BEGIN
	if (tv<>NIL) THEN
	BEGIN
		GetSystemTimeAsFileTime(ft);
    tmpres:=0;
		tmpres:=ft.dwHighDateTime;
		tmpres:=tmpres SHL 32;
    tmpres:=tmpres+ft.dwLowDateTime;


		tmpres:=tmpres DIV 10; //*convert into microseconds*/
		//*converting file time to unix epoch*/
		tmpres:=tmpres-11644473600000000;
		tv^.tv_sec:= tmpres DIV 1000000;
		tv^.tv_usec:= tmpres DIV 1000000;
	END;

	RESULT:=0;
END;  }

function CLAMP(x,a,b:integer):integer; overload;
begin
 if x>b then
 begin
   if X>b then
   begin
     result:=b;
     exit;
   end;
 end;

 if x<a then
 result:=a
 else
 result:=x;
end;

function CLAMP(x,a,b:double):double; overload;
begin
 if x>b then
 begin
   if X>b then
   begin
     result:=b;
     exit;
   end;
 end;

 if x<a then
 result:=a
 else
 result:=x;
end;

function fz_malloc(size:integer):pointer;
var
p:pointer;
begin
 P:= AllocMem(size);
 //p:=_malloc(size);
 //zeromemory(p,size);
// getmem(P,SIZE);
 RESULT:=P;
end;

function  fz_calloc(count,size:integer):pointer;
VAR
p:pointer;
BEGIN
p:=nil;
result:=nil;
if (count = 0) or (size = 0) then
		exit;
if ((count<0) or (size<0) or (count>round(INT_MAX / size))) then
begin
  p:=nil;
   // fprintf(stderr, "fatal error: out of memory (integer overflow)\n");
   exit;
end;
//  p:=_Malloc(count * size);
 // zeromemory(p,count * size);
 P:= AllocMem(count * size);
 //P:= AllocMem(count * size);
 // GetMem(P,count * size);
	result:=p;

END;

function  fz_realloc( p:pointer; count, size:integer):pointer;

BEGIN

result:=nil;
if (count = 0) or (size = 0) then
BEGIN
    fz_free(P);
		exit;
END;
if ((count<0) or (size<0) or (count>round(INT_MAX / size))) then
begin
  fz_free(P);
   // fprintf(stderr, "fatal error: out of memory (integer overflow)\n");
   P:=NIL;
   exit;
end;
  // p:=_realloc(P,count * size);
   ReallocMem(P,count * size);
  //getmem(p,count * size);
  
	result:=p;
end;

procedure   fz_free(p:pointer);
BEGIN
  //Finalize(p);
 
  FREEMEM(P);
 //_free(p);
 //Dispose(P);
 p:=nil;
END;

function  fz_strdup(s:pchar):pchar;
VAR
LEN:INTEGER;
NS:PCHAR;
SS:STRING;
P:POINTER;
BEGIN


SS:=S;
LEN:=LENGTH(SS)+1;
//P:= AllocMem(LEN);
GETMEM(NS,LEN);
//COPYMEMORY(NS,S,LEN);
move(s^,ns^,len);
RESULT:=NS;
END;


FUNCTION fz_is_big_endian():INTEGER;

BEGIN
RESULT:=0 ;

END;

function fz_strsep(stringp:ppchar;const delim:pchar):pchar;
var
ret:pchar;

begin
//result:= StrPos(stringp,delim);     //AnsiStrPos 国际字符

  ret := stringp^;
	if (ret = nil) then
  begin
  result:=nil;
  end;
  stringp^:=StrPos(stringp^,delim);
  if  stringp^<>nil then
  begin
   pchar(stringp^)^:=#0;
    inc(stringp^);
  end;
//	if ((*stringp = strpbrk(*stringp, delim)) != NULL)
 //		*((*stringp)++) = '\0';
 //	return ret;
  result:=ret;

end;





function  fz_strlcpy(dst:pchar;  const src:pchar;siz:integer):integer;

begin
 // ZeroMemory(DST, SIZ);
  fillchar(DST^,siz,0);
  StrLCopy(dst,src,siz-1);
  result:=StrLen(dst);

end;
function  fz_strlcat(dst:pchar;  const src:pchar;n:integer):integer;
begin

   StrLCat(dst,src,N);
   result:= StrLen(dst);

end;

function fz_atof(s:pchar):single;
var
ss:string;
begin
ss:=s;
result:=strtofloatdef(ss,1.0);
end;

function chartorune(rune:pinteger;str:pchar):integer;
var
	 c, c1, c2, c3:integer;
	 l:longint;
   label bad1;
begin
 //	/*	 * one character sequence	 *	00000-0007F => T1	 */
	c := ord(str^);
	if(c < Tx) then
  begin
		rune^ := c;
		result:=1;
    exit;
	end;

	//* * two character sequence 	 *	0080-07FF => T2 Tx	 */

	c1 := ord((str+1)^) xor Tx;
	if(c1 and Testx)<>0 then
		goto bad1;
	if(c < T3)  then
  begin
		if(c < T2)  then
			goto bad1;
		l := ((c shl Bitx) or c1) and Rune2;
		if(l <= Rune1) then
			goto bad1;
		rune^ := l;
		result:=2;
    exit;
	end;

	//* 	 * three character sequence 	 *	0800-FFFF => T3 Tx Tx 	 */

	c2 := ord((str+2)^) xor Tx;
	if(c2 and Testx)<>0 then
		goto bad1;
	if(c < T4) then
  begin
		l := ((((c shl Bitx) or c1) shl Bitx) or c2) and Rune3;
		if(l <= Rune2) then
			goto bad1;
		rune^ := l;
		result:= 3;
    exit;
  end;

	{/*
	 * four character sequence (21-bit value)
	 *	10000-1FFFFF => T4 Tx Tx Tx
	 */   }
   if str+3=nil then
     goto bad1;
	c3 := ord((str+3)^) xor Tx;
	if (c3 and Testx)<>0 then
		goto bad1;
	if (c < T5) then
  begin
		l := ((((((c shl Bitx) or c1) shl Bitx) or c2) shl Bitx) or c3) and Rune4;
		if (l <= Rune3) then
			goto bad1;
		rune^ := l;
		result:= 4;
    exit;
	end;
{	/*
	 * Support for 5-byte or longer UTF-8 would go here, but
	 * since we don't have that, we'll just fall through to bad.
	 */

	/*
	 * bad decoding
	 */  }
bad1:
	rune^ := Bad;
	result:=1;
  exit;
end;



function runetochar(str:pchar; rune:pinteger):integer;
var
c:dword;
begin
{/* Runes are signed, so convert to unsigned for range check. */

	/*
	 * one character sequence
	 *	00000-0007F => 00-7F
	 */   }
	c := dword(rune^);
	if(c <= Rune1) then
  begin
		str^ := chr(c);
		result:= 1;
    exit;
	end;

	{/*
	 * two character sequence
	 *	0080-07FF => T2 Tx
	 */ }
	if(c <= Rune2) then
  begin
		str^ := chr(T2 or (c shr (1*Bitx)));

		(str+1)^ := chr(Tx or (c and Maskx));
  //  OutputDebugString(pchar(inttostr(ord((str+1)^))));
		result:= 2;
    exit;
	end;

 {	/*
	 * If the Rune is out of range, convert it to the error rune.
	 * Do this test here because the error rune encodes to three bytes.
	 * Doing it earlier would duplicate work, since an out of range
	 * Rune wouldn't have fit in one or two bytes.
	 */ }
	if (c > Runemax) then
		c := Runeerror;

	{/*
	 * three character sequence
	 *	0800-FFFF => T3 Tx Tx
	 */ }
	if (c <= Rune3) then
  begin

		str^ := chr(T3 or (c shr (2*Bitx)));

		(str+1)^ :=chr( Tx or ((c shr (1*Bitx)) and Maskx));

		(str+2)^ :=chr(Tx or (c and Maskx));

		result:= 3;
    exit;
  end;

 {	/*
	 * four character sequence (21-bit value)
	 *	10000-1FFFFF => T4 Tx Tx Tx
	 */ }
	str^ :=chr( T4 or (c shr (3*Bitx)));

	(str+1)^ :=chr( Tx or ((c shr (2*Bitx)) and Maskx));

	(str+2)^ :=chr( Tx or ((c shr (1*Bitx)) and Maskx));

	(str+3)^ :=chr( Tx or (c and Maskx));

	 result:= 4;
   exit;
end;
function runelen(c:integer):integer;
var
str:array[0..9] of char;
begin
	result:= runetochar(str, @c);
end;

function  fz_getopt( nargc:integer; nargv:pchar; ostr:pchar):integer;
begin
result:=1;
end;
function  fz_optind: integer;
begin
result:=1;
end;
function    fz_optarg:pchar;
begin
result:='1';
end;


function  fz_new_hash_table(initialsize, keylen:integer):Pfz_hash_table;
var
 table:pfz_hash_table;
begin
table := fz_malloc(sizeof(fz_hash_table));
table^.keylen:=  keylen;
table^.size := initialsize;
	table^.load := 0;
	table^.ents := fz_calloc(table^.size, sizeof(fz_hash_entry_s));
 //	memset(table^.ents, 0, sizeof(fz_hash_entry) * table^.size);        不需要 清空
 fillchar(table^.ents^, sizeof(fz_hash_entry_s) * table^.size,0);
 result:=table;
end;



procedure fz_empty_hash(table:pfz_hash_table);
begin
  table^.load := 0;
  //ZeroMemory(table^.ents, sizeof(fz_hash_entry_s) * table^.size);
  fillchar(table^.ents^, sizeof(fz_hash_entry_s) * table^.size,0);

end;

procedure fz_free_hash(table:pfz_hash_table);
begin
 fz_free(table^.ents);
 fz_free(table);
end;
{$OVERFLOWCHECKS OFF}
function hash(s:pbyte; len:integer):dword;
var
val:dword;
i:integer;
p:pbyte;
BEGIN
	val:= 0;
  p:=s;
	for i := 0 to len-1 do
	BEGIN
    val:=val+p^;
    val:=val+(val shL 10);
		val:=val xor (val shr 6);
    inc(p);
	END;
  val:=val+ (val shL 3);
  val:=val xor (val shr 11);
  val:=val+(val shl 15);
  result:=val;

END;
 {$OVERFLOWCHECKS ON}
function  fz_hash_find(table:pfz_hash_table; key:pointer):pointer;
var
ents,p:Pfz_hash_entry_s;
size,pos: dword;
PP:POINTER;
begin

  ents := table^.ents;
	size := table^.size;
	pos := hash(key, table^.keylen) mod size;

	while (true)  do
	begin
    p:=ents;
    inc(p,pos);
		if (p^.val=nil)   then
    begin
			result:=nil;
      exit;
    end;
    PP:=@(p^.key);
     if CompareMem( key, P, table^.keylen)=true then
     begin
	    result:=p^.val;
			exit;
     end;
		pos := (pos + 1) MOD size;
	end;

end;

procedure fz_resize_hash(table:pfz_hash_table; newsize:integer);
var
 oldents,p :Pfz_hash_entry_s;
 oldsize,oldload ,i:integer;
begin

 oldents:=table^.ents;
 p:=oldents;
 oldsize:=table^.size;
 oldload := table^.load;


	if (newsize < oldload * 8 div 10)  then
  begin

		fz_throw('assert: resize hash too small');
		EXIT;
	end;

	table^.ents := fz_calloc(newsize, sizeof(fz_hash_entry_s));
//  zeromemory(table^.ents, sizeof(fz_hash_entry_s) * newsize);
  fillchar(table^.ents^, sizeof(fz_hash_entry_s) * newsize,0);
 	//memset(table->ents, 0, sizeof(fz_hash_entry) * newsize);
	table^.size := newsize;
	table^.load := 0;

	for I:= 0 TO oldsize-1 do
	begin
    p:=oldents;
    inc(p,i);
		if (p^.val<>nil) then
		begin
			fz_hash_insert(table, @(p^.key), p^.val);
		end;
	end;

	fz_free(oldents);
end;


procedure fz_hash_insert(table:pfz_hash_table; key:pointer; val:pointer);
var
ents:Pfz_hash_entry_s;
size,pos: dword;
begin

  if (table^.load > table^.size * 8 div 10) then
	BEGIN
		fz_resize_hash(table, table^.size * 2);
	END;
  ents := table^.ents;
	size := table^.size;
	pos := hash(key, table^.keylen) mod size;

	while (true)  do
	begin
		if (fz_hash_entry_s_items(ents)[pos].val=nil)  then
		begin
		 //	copymemory(@fz_hash_entry_s_items(ents)[pos].key, key, table^.keylen);

      move(key^, (@fz_hash_entry_s_items(ents)[pos].key)^, table^.keylen);
			fz_hash_entry_s_items(ents)[pos].val := val;
			table^.load:=table^.load+1;
			exit;
		end;

		if (memcmp(key, @fz_hash_entry_s_items(ents)[pos].key, table^.keylen) = 0) then
			fz_warn('assert: overwrite hash slot');

		pos := (pos + 1) mod size;
	end;

end;

function  fz_hash_len(table:pfz_hash_table):INTEGER;
BEGIN
RESULT:=table^.size;
END;



procedure fz_hash_remove(table:pfz_hash_table_s; key:pointer);
var
ents:pfz_hash_entry_s;
size,pos,hole, look, code:cardinal;
begin
 // fz_debug_hash(table);
  ents := table^.ents;

  size := table^.size;
  pos := (hash(key, table^.keylen) mod size);
  while (true) do
	begin

		if (fz_hash_entry_s_items(ents)[pos].val=nil)   then
		begin
			fz_warn('assert: remove inexistant hash entry:%d',[pos]);
			exit;
		end;

		if (CompareMem(key, @(fz_hash_entry_s_items(ents)[pos].key), table^.keylen) =true) then
		begin
			fz_hash_entry_s_items(ents)[pos].val := nil;

			hole:= pos;
			look := (hole + 1) mod size;

			while (fz_hash_entry_s_items(ents)[look].val<>nil)  do
			begin

				code := (hash(@(fz_hash_entry_s_items(ents)[look].key), table^.keylen))  mod size;
				if (((code <= hole) and (hole < look)) or ((look < code) and (code <= hole)) or ((hole < look) and (look < code))) then
				begin

          fz_hash_entry_s_items(ents)[hole] := fz_hash_entry_s_items(ents)[look];
					fz_hash_entry_s_items(ents)[look].val := nil;
          hole := look;
				end;

				look := (look + 1) mod size;
			end;

			table^.load:=table^.load-1;

			exit;
		end;

		pos := (pos + 1) mod size;
	end;
end;

function  fz_hash_get_key(table:pfz_hash_table; idx:INTEGER):POINTER;
var
ents:Pfz_hash_entry_s;
BEGIN
 ENTS:=TABLE^.ents;
 INC(ENTS,IDX);
 RESULT:=@ents^.key;
END;

function fz_hash_get_val(table:pfz_hash_table; idx:INTEGER):POINTER;
var
ents:Pfz_hash_entry_s;
BEGIN
 ENTS:=TABLE^.ents;
 INC(ENTS,IDX);
  RESULT:=ents^.val;
END;

function fz_hash_get_Pval(table:pfz_hash_table; idx:INTEGER):POINTER;  //指针的指针
var
ents:Pfz_hash_entry_s;
BEGIN
 ENTS:=TABLE^.ents;
 INC(ENTS,IDX);
 ents^.val:=nil;
END;

procedure fz_debug_hash(table:pfz_hash_table_s) ;
const
MAX_KEY_LEN = 48;
var
	i, k:integer;
begin
	fz_warn('cache load %d / %d\n', [table^.load, table^.size]);

	for i := 0  to table^.size-1 do
	begin
		if (fz_hash_entry_s_items(table^.ents)[i].val=nil) then
		 fz_warn('table %d: empty\n', [i])
		else
		begin
			fz_warn('table %d: key=', [i]);
		 	for k := 0 to MAX_KEY_LEN-1 do
				fz_warn('%d', [fz_hash_entry_s_items(table^.ents)[i].key[k]]);
			fz_warn('val=$%s\n', [pchar(fz_hash_entry_s_items(table^.ents)[i].val)]);
		end;
	end;
end;


function fz_mul255(a,b:integer):integer;
var
x:integer;
begin
x:=a*b+128;
x:=x+(x shr 8);
x:=(x shr 8);
result:=x;
end;

function  fz_concat(one:fz_matrix;two:fz_matrix):fz_matrix;
var
dst:fz_matrix ;
begin
  dst.a := one.a * two.a + one.b * two.c;
	dst.b := one.a * two.b + one.b * two.d;
	dst.c := one.c * two.a + one.d * two.c;
	dst.d := one.c * two.b + one.d * two.d;
	dst.e := one.e * two.a + one.f * two.c + two.e;
	dst.f := one.e * two.b + one.f * two.d + two.f;
	result:=dst;
end;

function fz_scale(sx, sy:single):fz_matrix;
var
 m: fz_matrix;
begin
	m.a := sx;
  m.b := 0;
	m.c := 0;
  m.d := sy;
	m.e := 0;
  m.f := 0;
	result:=m;
end;

function fz_shear(sx,sy:single):fz_matrix;
var
 m: fz_matrix;
begin

	m.a := 1;
  m.b := sy;
	m.c := sx;
  m.d := 1;
	m.e := 0;
  m.f := 0;
	result:=m;
end;

function  fz_rotate(theta:single):fz_matrix;
var
  m: fz_matrix;
  s,c:single;
begin
while (theta < 0) do
		theta:=theta+ 360;
	while (theta >= 360) do
		theta :=theta - 360;

	if (abs(0 - theta) < FLT_EPSILON)  then
	begin
		s := 0;
		c := 1;
	end
	else if (abs(90.0 - theta) < FLT_EPSILON) then
	begin
		s := 1;
		c := 0;
	end
	else if (abs(180.0 - theta) < FLT_EPSILON)  then
	begin
		s := 0;
		c := -1;
	end
	else if (abs(270.0 - theta) < FLT_EPSILON)  then
	begin
		s := -1;
		c := 0;
	end
	else
	begin
		s := sin(theta * M_PI / 180);
		c := cos(theta * M_PI / 180);
	end;

	m.a := c;
  m.b := s;
	m.c := -s;
  m.d := c;
	m.e := 0;
  m.f := 0;
	result:=m;
  

end;
function fz_translate(tx, ty:single):fz_matrix ;
var
  m: fz_matrix;
begin
	m.a := 1;
  m.b := 0;
	m.c := 0;
  m.d := 1;
	m.e := tx;
  m.f := ty;
	result:= m;

end;

function fz_invert_matrix(src:fz_matrix ):fz_matrix ;
var
  dst: fz_matrix;
  rdet :single;
begin
	rdet := 1 / (src.a * src.d - src.b * src.c);
	dst.a := src.d * rdet;
	dst.b := -src.b * rdet;
	dst.c := -src.c * rdet;
	dst.d := src.a * rdet;
	dst.e := -src.e * dst.a - src.f * dst.c;
	dst.f := -src.e * dst.b - src.f * dst.d;
		result:=dst;

end;

function fz_is_rectilinear(m:fz_matrix):integer;
begin
  if  ((abs(m.b)< FLT_EPSILON) and  (abs(m.c)<  FLT_EPSILON)) or   ((abs(m.a) < FLT_EPSILON) and (abs(m.d) < FLT_EPSILON)) then
  result:=1
  else
  result:=0;
end;

function fz_matrix_expansion(m:fz_matrix):single;
begin
  result:=sqrt(abs(m.a * m.d - m.b * m.c));
end;

function fz_round_rect(r:fz_rect ):fz_bbox;
var
i:fz_bbox;
begin
	i.x0 := floor(r.x0 + 0.001); //* adjust by 0.001 to compensate for precision errors */
	i.y0 := floor(r.y0 + 0.001);
	i.x1 := ceil(r.x1 - 0.001);
	i.y1 := ceil(r.y1 - 0.001);
	result:=i;
end;

function fz_is_infinite_rect(r:fz_bbox):boolean; overload;
begin
   result:=false;
   if ((r).x0 > (r).x1)  then
   result:=true;
end;

function fz_is_infinite_rect(r:fz_rect):boolean;overload;
begin
   result:=false;
   if ((r).x0 > (r).x1)  then
   result:=true;
end;


function fz_is_empty_rect(r:fz_rect):boolean; overload;

begin
  result:=false;
  if ((r).x0 =(r).x1) then
   result:=true;

end;

function fz_is_empty_rect(r:fz_bbox):boolean; overload;

begin
  result:=false;
  if ((r).x0 =(r).x1) then
   result:=true;

end;
function  fz_is_infinite_bbox(b:fz_bbox):boolean; overload;
begin
  result:=false;
  if  ((b).x0 > (b).x1) then
    result:=true;
end;

function fz_intersect_bbox(a,b:fz_bbox): fz_bbox;
var
r: fz_bbox;
begin
	if (fz_is_infinite_rect(a)) then
  begin
   result:= b;
   exit;
  end;
	if (fz_is_infinite_rect(b)) then
  begin
   result:= a;
   exit;
  end;
	if (fz_is_empty_rect(a)) then
  begin
 //  result:= fz_empty_bbox;
  r.x0 := MAX(a.x0, b.x0);
	r.y0 := MAX(a.y0, b.y0);
	r.x1 := MIN(a.x1, b.x1);
	r.y1 := MIN(a.y1, b.y1);
  result:=r;
   exit;
  end;

	if (fz_is_empty_rect(b)) then

   begin
//   result:= fz_empty_bbox;
    r.x0 := MAX(a.x0, b.x0);
	r.y0 := MAX(a.y0, b.y0);
	r.x1 := MIN(a.x1, b.x1);
	r.y1 := MIN(a.y1, b.y1);
  result:=r;
   exit;
   exit;
  end;

	r.x0 := MAX(a.x0, b.x0);
	r.y0 := MAX(a.y0, b.y0);
	r.x1 := MIN(a.x1, b.x1);
	r.y1 := MIN(a.y1, b.y1);

  if  (r.x1 < r.x0) or (r.y1 < r.y0) then
  begin
   result:=fz_empty_bbox;

  end
  else
  result:=r;

end;
function fz_intersect_rect(a,b:fz_rect): fz_rect;
var
r: fz_rect;
begin

	if (fz_is_infinite_rect(a)) then
  begin
   result:=b;
   exit;
   end;
	if (fz_is_infinite_rect(b)) then
  begin
   result:=a;
   exit;
   end;
	if (fz_is_empty_rect(a)) then
  begin
    result:=fz_empty_rect;
    exit;
  end;
	if (fz_is_empty_rect(b)) then
  begin
    result:=fz_empty_rect;
    exit;
  end;
	r.x0 := MAX(a.x0, b.x0);
	r.y0 := MAX(a.y0, b.y0);
	r.x1 := MIN(a.x1, b.x1);
	r.y1 := MIN(a.y1, b.y1);
  if  (r.x1 < r.x0) or (r.y1 < r.y0) then
  result:= fz_empty_rect
  else
  result:=r;

end;
function  fz_union_bbox(a,b:fz_bbox):fz_bbox;
var
r:fz_bbox;
begin

	if (fz_is_infinite_rect(a)) then
  begin
    result:=a;
    exit;
  end;
	if (fz_is_infinite_rect(b)) then
  begin
    result:=b;
    exit;
  end;
	if (fz_is_empty_rect(a)) then
  begin
    result:=b;
    exit;
  end;
	if (fz_is_empty_rect(b)) then
  begin
    result:=a;
    exit;
  end;
	r.x0 := MIN(a.x0, b.x0);
	r.y0 := MIN(a.y0, b.y0);
	r.x1 := MAX(a.x1, b.x1);
	r.y1 := MAX(a.y1, b.y1);
	result:= r;

end;
function  fz_union_rect(a,b:fz_rect):fz_rect;
var
r:fz_rect;
begin
	if (fz_is_infinite_rect(a)) then
  begin
   result:= a;
   exit;
  end;
	if (fz_is_infinite_rect(b)) then
  begin
    result:=b;
    exit;
  end;
	if (fz_is_empty_rect(a)) then
  begin
    result:= b;
    exit;
  end;
	if (fz_is_empty_rect(b)) then
  begin
    result:= a;
    exit;
  end;

	r.x0 := MIN(a.x0, b.x0);
	r.y0 := MIN(a.y0, b.y0);
	r.x1 := MAX(a.x1, b.x1);
	r.y1 := MAX(a.y1, b.y1);
	result:=r;

end;
function  fz_transform_point(m:fz_matrix;p:fz_point):fz_point;
var
t: fz_point;
begin

	t.x := p.x * m.a + p.y * m.c + m.e;
	t.y := p.x * m.b + p.y * m.d + m.f;
	result:= t;

end;
function  fz_transform_vector(m:fz_matrix;p:fz_point):fz_point;
var
t: fz_point;
begin

	t.x := p.x * m.a + p.y * m.c;
	t.y := p.x * m.b + p.y * m.d;
	result:=t;
end;

function MIN4(x1,x2,x3,x4:single):single;
var
a1,a2:single;
begin
  a1:=min(x1,x2);
  a2:=min(x3,x4);
  result:=min(a1,a2);
end;

function MAX4(x1,x2,x3,x4:single):single;
var
a1,a2:single;
begin
  a1:=max(x1,x2);
  a2:=max(x3,x4);
  result:=max(a1,a2);
end;

function  fz_transform_rect(m:fz_matrix;r:fz_rect):fz_rect;
var
 s, t, u, v :fz_point;
begin


	if (fz_is_infinite_rect(r))  then
  begin
  result:=r;
  exit;
  end;
	s.x := r.x0;
  s.y := r.y0;
	t.x := r.x0; t.y := r.y1;
	u.x := r.x1; u.y := r.y1;
	v.x := r.x1; v.y := r.y0;
	s := fz_transform_point(m, s);
	t := fz_transform_point(m, t);
	u := fz_transform_point(m, u);
	v := fz_transform_point(m, v);
	r.x0 := MIN4(s.x, t.x, u.x, v.x);
	r.y0 := MIN4(s.y, t.y, u.y, v.y);
	r.x1 := MAX4(s.x, t.x, u.x, v.x);
	r.y1 := MAX4(s.y, t.y, u.y, v.y);
	result:=r;
end;
function  fz_transform_bbox(m:fz_matrix;b:fz_bbox):fz_bbox;
var
s, t, u, v:fz_point;
begin


	if (fz_is_infinite_bbox(b)) then
  begin
		result:=b;
    exit;
  end;

	s.x := b.x0; s.y := b.y0;
	t.x := b.x0; t.y := b.y1;
	u.x := b.x1; u.y := b.y1;
	v.x := b.x1; v.y := b.y0;
	s := fz_transform_point(m, s);
	t := fz_transform_point(m, t);
	u := fz_transform_point(m, u);
	v := fz_transform_point(m, v);
	b.x0 :=trunc( MIN4(s.x, t.x, u.x, v.x));
	b.y0 :=trunc( MIN4(s.y, t.y, u.y, v.y));
	b.x1 :=trunc( MAX4(s.x, t.x, u.x, v.x));
	b.y1 :=trunc( MAX4(s.y, t.y, u.y, v.y));
	result:=b;
end;


function fz_new_dict(initialcap:integer):pfz_obj_s;
var
  obj:pfz_obj_s;
  i:integer;

begin
	obj := fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_DICT;

	obj^.u.d.sorted := 1;
	obj^.u.d.len := 0;
  if  initialcap>1 then
      obj^.u.d.cap :=initialcap
      else
      obj^.u.d.cap :=10;



	obj^.u.d.items := fz_calloc(obj^.u.d.cap, sizeof(keyval_s));
	for i := 0 to obj^.u.d.cap-1 do
	begin
	 keyval_items(obj^.u.d.items)[i].k := nil;
	 keyval_items(obj^.u.d.items)[i].v := nil;
	end;
  result:=obj;

end;







function fz_array_get(obj:pfz_obj_s;i:integer):pfz_obj_s;
begin
	obj := fz_resolve_indirect(obj);

	if (not fz_is_array(obj)) then
  begin
		result:=nil;
    exit;
  end;
	if (i < 0) or (i >= obj^.u.a.len) then
  begin
		if not (fz_is_array(obj)) then
    begin
  		result:=nil;
     exit;
    end;
  end;
	result:=fz_obj_s_items(obj^.u.a.items)[i];
end;





function fz_new_array(initialcap:integer):pfz_obj_s;
 var
 obj:pfz_obj_s  ;
 i:integer;
begin

	obj := fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_ARRAY;

	obj^.u.a.len := 0;
  if  initialcap > 1 then
     obj^.u.a.cap:=initialcap
     else
     obj^.u.a.cap:=6;

	obj^.u.a.items := fz_calloc(obj^.u.a.cap, sizeof(pfz_obj_s));    //p?????
	for i := 0 to obj^.u.a.cap-1 do
  begin
	 fz_obj_s_items(obj^.u.a.items)[i] := nil;
   end;
	result:= obj;
end;


function fz_new_int(i:integer) :pfz_obj_s;
var
 obj:pfz_obj_s;
begin
	obj := fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_INT;
	obj^.u.i := i;
	result:= obj;
end;

procedure fz_array_push(obj:pfz_obj_s;item:pfz_obj_s) ;
var
i:integer;
begin
 	obj := fz_resolve_indirect(obj);

	if (not fz_is_array(obj)) then
  begin
	 	fz_warn('"assert: not an array (%s)', [fz_objkindstr(obj)]) ;
   exit;
  end
	else
	begin
		if (obj^.u.a.len + 1 > obj^.u.a.cap)  then
		begin

			obj^.u.a.cap := (obj^.u.a.cap * 3) div 2;
			obj^.u.a.items := fz_realloc(obj^.u.a.items, obj^.u.a.cap, sizeof(fz_obj_s));
			for i := obj^.u.a.len to obj^.u.a.cap do
				fz_obj_s_items(obj^.u.a.items)[i] := nil;
		end;
		fz_obj_s_items(obj^.u.a.items)[obj^.u.a.len] := fz_keep_obj(item);
		obj^.u.a.len:=obj^.u.a.len+1;
	end;
end;

function fz_is_bool(obj:pfz_obj_s):boolean;
begin
  result:=false;
  if obj=nil then
  exit;
	obj := fz_resolve_indirect(obj);
  if obj^.kind = FZ_BOOL then
  result:=true;

  
end; 
function fz_is_array(obj:pfz_obj_s):boolean;
begin
	obj := fz_resolve_indirect(obj);
    result:=false;
  if obj=nil then
  exit;
  if obj^.kind = FZ_ARRAY then
  result:=true;

	//return obj ? obj->kind == FZ_ARRAY : 0;
end;

function fz_is_dict(obj:pfz_obj_s):boolean;
begin
	obj := fz_resolve_indirect(obj);
   result:=false;
  if obj=nil then
  exit;
  if obj^.kind = FZ_DICT then
  result:=true ;


end;

function fz_to_bool(obj:pfz_obj_s):integer;
begin
	obj := fz_resolve_indirect(obj);
  result:=0;
	if (fz_is_bool(obj)) then
		result:=obj^.u.b;

end;

function fz_is_int(obj:pfz_obj_s):boolean;
begin
	obj := fz_resolve_indirect(obj);
    result:=false;
  if obj=nil then
  exit;
   if obj^.kind = FZ_INT then
  result:=true;

end;

function fz_is_real(obj:pfz_obj_s):boolean;
begin
 obj := fz_resolve_indirect(obj);
    result:=false;
  if obj=nil then
  exit;
   if obj^.kind = FZ_REAL then
  result:=true ;


end;

function fz_is_string(obj:pfz_obj_s):boolean;
begin
  obj := fz_resolve_indirect(obj);
    result:=false;
  if obj=nil then
  exit;
   if obj^.kind = FZ_STRING  then
  result:=true ;


end;

function fz_is_name(obj:pfz_obj_s):boolean;
begin
	obj := fz_resolve_indirect(obj);
      result:=false;
  if obj=nil then
  exit;
   if obj^.kind = FZ_NAME  then
  result:=true ;

end;


function fz_to_int(obj:pfz_obj_s):integer;
begin
result:=0;
obj := fz_resolve_indirect(obj);
   if obj=nil then
  exit;
	if (fz_is_int(obj)) then
		result:=obj^.u.i ;
  if (fz_is_real(obj)) then
		result:=TRUNC(obj^.u.f);

end;

function fz_to_real(obj:pfz_obj_s):single;
begin
obj := fz_resolve_indirect(obj);
result:=0;
	if (fz_is_real(obj)) then
		result:=obj^.u.f;
  if (fz_is_int(obj)) then
		result:=obj^.u.i;

end;


function fz_to_name(obj:pfz_obj_s):pchar;
begin
  result:='';
	obj := fz_resolve_indirect(obj);
	if (fz_is_name(obj)) then
		result:=@obj^.u.n;          //改过

end;

function fz_to_str_buf(obj:pfz_obj_s) :pchar ;

begin
  result:='';
	obj := fz_resolve_indirect(obj);
	if (fz_is_string(obj)) then
		result:= @obj^.u.s.buf;
   // outprintf( pchar(@obj^.u.s.buf));
end;

function fz_to_str_len(obj:pfz_obj_s):integer;
begin
  result:=0;
	obj := fz_resolve_indirect(obj);
	if (fz_is_string(obj)) then
		result:=obj^.u.s.len;

end;

//* for use by pdf_crypt_obj_imp to decrypt AES string in place */
procedure fz_set_str_len(obj:pfz_obj_s; newlen:integer);
begin
	obj := fz_resolve_indirect(obj);
	if (fz_is_string(obj)) then
		if (newlen < obj^.u.s.len) then
			obj^.u.s.len := newlen;
end;

function fz_is_indirect(obj:pfz_obj_s):boolean;
begin
 // obj := fz_resolve_indirect(obj);
       result:=false;
  if obj=nil then
  exit;
  if obj^.kind = FZ_INDIRECT   then
  result:=true
  else
  result:=false;
	
end;


function fz_to_num(obj:pfz_obj_s) :integer;
begin
  result:=0;
	if (fz_is_indirect(obj))  then
		result:= obj^.u.r.num;

end;

function fz_to_gen(obj:pfz_obj_s):integer;
begin
    result:=0;
	if (fz_is_indirect(obj)) then
		result:= obj^.u.r.gen;

end;

FUNCTION fz_get_indirect_xref(obj:pfz_obj_s):ppdf_xref_s ;
begin

  result:=nil;
	if (fz_is_indirect(obj)) then
		result:=obj^.u.r.xref;

end;

function fz_keep_obj(obj:pfz_obj_s) :pfz_obj_s ;
begin

	assert(obj <>nil);
	obj^.refs:=obj^.refs+1;
	result:=obj;
end;


function fz_new_indirect(num, gen:integer; xref:pointer) :pfz_obj_s ;
var
   obj:pfz_obj_s;
begin
	obj:= fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_INDIRECT;
	obj^.u.r.num := num;
	obj^.u.r.gen := gen;
	obj^.u.r.xref := xref;
	result:=obj;
end;


function fz_new_null():pfz_obj_s ;
var
   obj:pfz_obj_s;
begin
	obj:= fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_NULL;
	result:=obj;
end;

function  fz_new_bool(b:integer):pfz_obj_s ;
var
   obj:pfz_obj_s;
begin
	obj:= fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_BOOL;
	obj^.u.b := b;
	result:=obj;
end;



function fz_new_real(f:single):pfz_obj_s ;
var
   obj:pfz_obj_s;
begin
	obj:= fz_malloc(sizeof(fz_obj_s));
	obj^.refs := 1;
	obj^.kind := FZ_REAL;
	obj^.u.f := f;
	result:= obj;
end;

function  fz_new_string(str:pchar; len:integer):pfz_obj_s ;
var
   obj:pfz_obj_s;
   obj1:fz_obj_s;
   pp:cardinal;
begin


 pp:=cardinal(@(obj1.u.s.buf))-cardinal(@obj1);


	obj:= fz_malloc(pp + len + 1);
	obj^.refs := 1;
	obj^.kind := FZ_STRING;
	obj^.u.s.len := len;
  move(str^,obj^.u.s.buf,  len);
	obj^.u.s.buf[len] := #0;
	result:=obj;
end;

function fz_new_name(str:pchar) :pfz_obj_s ;
var
   obj:pfz_obj_s;
   obj1:fz_obj_s;
   pp:integer;
begin
  pp:= cardinal(@(obj1.u.n))-cardinal(@obj1);
	obj := fz_malloc(pp + strlen(str) + 1);
	obj^.refs := 1;
	obj^.kind := FZ_NAME;
	StrCopy(@obj^.u.n, str);
	result:= obj;
end;

//* dicts may only have names as keys! */

function keyvalcmp(ap:pointer; bp:pointer):integer;
var
aa,bb:Pkeyval_s;
begin
 //	const struct keyval *a = ap;
 //	const struct keyval *b = bp;
   aa:=Pkeyval_s(ap);
   bb:=Pkeyval_s( bp);

	result:= strcomp(fz_to_name(aa^.k), fz_to_name(bb^.k));
end;

function fz_dict_len(obj:pfz_obj_s):integer;
begin
	obj := fz_resolve_indirect(obj);
	if (fz_is_dict(obj)=false)  then
		result:=0
    else
	result:= obj^.u.d.len;
end;

function fz_copy_dict(obj:pfz_obj_s):pfz_obj_s ;
var
  oo:pfz_obj_s;
  i:integer;
begin

	if (fz_is_indirect(obj) or  fz_is_dict(obj)=false) then
  begin
		 fz_throw('assert: not a dict (%s)', [fz_objkindstr(obj)]);
    result:=nil;
    exit;
  end;

	oo := fz_new_dict(fz_dict_len(obj));
	for i := 0 to fz_dict_len(obj)-1 do
		fz_dict_put(oo, fz_dict_get_key(obj, i), fz_dict_get_val(obj, i));

	result:=oo;
end;



function fz_dict_get_key(obj:pfz_obj_s; i:integer):pfz_obj_s  ;

begin
	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj)) then
  begin
		result:=nil;
    exit;
  end;
	if (i < 0) or (i >= obj^.u.d.len) then
	begin
		result:=nil;
    exit;
  end;

	result:=keyval_items(obj^.u.d.items)[i].k;
end;

function fz_dict_get_val(obj:pfz_obj_s; i:integer):pfz_obj_s  ;
begin
	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj))  then
	begin
		result:=nil;
    exit;
  end;

	if (i < 0) or (i >= obj^.u.d.len)  then
	begin
		result:=nil;
    exit;
  end;
	result:= keyval_items(obj^.u.d.items)[i].v;
  
end;

function fz_dict_finds(obj:pfz_obj_s; key: pchar):integer;
var
l,r,m,c,i:integer;
begin
	if (obj^.u.d.sorted<>0) then
	begin
		l := 0;
		r := obj^.u.d.len - 1;
		while (l <= r)  do
		begin
			 m := (l + r) shr 1;
		  	c := -strcomp(fz_to_name(keyval_items(obj^.u.d.items)[m].k), key);
			if (c < 0) then
				r := m - 1
			else if (c > 0) then
				l := m + 1
			else
        begin
				result:=m;
        exit;
        end;
		end;
	end

	else
	begin
		for  i := 0 to obj^.u.d.len-1 do
			if (strcomp(fz_to_name(keyval_items(obj^.u.d.items)[i].k), key) = 0) then
      begin
				result:=i;
        exit;
      end;
	end;

	result:= -1;
end;

function fz_dict_gets(obj:pfz_obj_s; key:pchar) :pfz_obj_s;
var
i:integer;
begin

	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj)) then
     begin
				result:=nil;;
        exit;
      end;

	i := fz_dict_finds(obj, key);
	if (i >= 0) then
  begin
		result:=keyval_items(obj^.u.d.items)[i].v;
    exit;
  end;
	result:= nil;
end;

function fz_dict_get(obj:pfz_obj_s; key:pfz_obj_s):pfz_obj_s;
begin

	if (fz_is_name(key)) then
  begin
		result:= fz_dict_gets(obj, fz_to_name(key));
    exit;
  end;
	result:=nil;
end;

function fz_dict_getsa(obj:pfz_obj_s; key:pchar; abbrev:pchar):pfz_obj_s;
var
v:pfz_obj_s;
begin

	v := fz_dict_gets(obj, key);
	if (v<>nil ) then
  begin
		result:=v;
    exit;
  end;
	result:=fz_dict_gets(obj, abbrev);
end;

procedure fz_dict_put(obj:pfz_obj_s; key:pfz_obj_s; val:pfz_obj_s);
var
s:pchar;
i:integer;
begin

	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj)) then
	begin
	 	fz_warn('assert: not a dict (%s)', [fz_objkindstr(obj)]);
		exit;
	end;

	if (fz_is_name(key)) then
		s := fz_to_name(key)
	else
	begin
	 	fz_warn('assert: key is not a name (%s)', [fz_objkindstr(obj)]);
	 //	return;
    exit;
	end;

	if (val=nil) then
	begin
	 	fz_warn('assert: val does not exist for key (%s)', [s]);
	 //	return;
   exit;
	end;

	i := fz_dict_finds(obj, s);
	if (i >= 0) then
	begin
		fz_drop_obj(keyval_items(obj^.u.d.items)[i].v);
		keyval_items(obj^.u.d.items)[i].v := fz_keep_obj(val);
		//return;
    exit;
	end;

	if (obj^.u.d.len + 1 > obj^.u.d.cap) then
	begin
		obj^.u.d.cap := (obj^.u.d.cap * 3) div 2;
		obj^.u.d.items := fz_realloc(obj^.u.d.items, obj^.u.d.cap, sizeof(keyval_s));
		for i := obj^.u.d.len to obj^.u.d.cap-1 do
		begin
			keyval_items(obj^.u.d.items)[i].k := nil;
			keyval_items(obj^.u.d.items)[i].v := nil;
		end;
	end;

	//* borked! */
	if (obj^.u.d.len<>0) then
		if (strcomp(fz_to_name(keyval_items(obj^.u.d.items)[obj^.u.d.len - 1].k), s) > 0) then
			obj^.u.d.sorted := 0;

	keyval_items(obj^.u.d.items)[obj^.u.d.len].k := fz_keep_obj(key);
	keyval_items(obj^.u.d.items)[obj^.u.d.len].v := fz_keep_obj(val);
	obj^.u.d.len:=obj^.u.d.len+1;
end;

procedure fz_dict_puts(obj:pfz_obj_s; key:pchar; val:pfz_obj_s);
var
  keyobj:pfz_obj_s;
begin
	keyobj:= fz_new_name(key);
	fz_dict_put(obj, keyobj, val);
	fz_drop_obj(keyobj);
end;

procedure fz_dict_dels(obj:pfz_obj_s; key:pchar);
var
i:integer;
begin
	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj)) then
    	fz_warn('assert: not a dict (%s)', [fz_objkindstr(obj)])
	else
	begin
		i := fz_dict_finds(obj, key);
		if (i >= 0) then
		begin
			fz_drop_obj(keyval_items(obj^.u.d.items)[i].k);
			fz_drop_obj(keyval_items(obj^.u.d.items)[i].v);
			obj^.u.d.sorted := 0;
			keyval_items(obj^.u.d.items)[i] := keyval_items(obj^.u.d.items)[obj^.u.d.len-1];
			obj^.u.d.len:=obj^.u.d.len-1;
		end;
	end;
end;

procedure fz_dict_del(obj:pfz_obj_s; key:pfz_obj_s);
begin
	if (fz_is_name(key)) then
		fz_dict_dels(obj, fz_to_name(key))
	else
    begin
	   	fz_warn('assert: key is not a name (%s)', [fz_objkindstr(obj)]);
    end;
end;

procedure fz_sort_dict(obj:pfz_obj_s);
begin
	obj := fz_resolve_indirect(obj);
	if (not fz_is_dict(obj))  then
  begin
		exit;
  end;
	if (obj^.u.d.sorted=0) then
	begin
	 //	qsort(obj^.u.d.items, obj^.u.d.len, sizeof(keyval_s), keyvalcmp);
   QuickSort(obj^.u.d.items, word(obj^.u.d.len), word(sizeof(keyval_s)), @keyvalcmp);
		obj^.u.d.sorted := 1;
	end;
end;

procedure fz_free_array(obj:pfz_obj_s);
var
i:integer;
begin
	for i := 0 to obj^.u.a.len-1 do
  begin

		if (fz_obj_s_items(obj^.u.a.items)[i]<>nil) then
			fz_drop_obj(fz_obj_s_items(obj^.u.a.items)[i]);
  end;
	fz_free(obj^.u.a.items);
	fz_free(obj);
end;

procedure fz_free_dict(obj:pfz_obj_s);
var
	i:integer;
begin

	for i := 0 to obj^.u.d.len-1 do
  begin
    //if i=4 then
  //  OutputDebugString(pchar('fz_free_dict:'+inttostr(i)));
		if (keyval_items(obj^.u.d.items)[i].k<>nil) then
			fz_drop_obj(keyval_items(obj^.u.d.items)[i].k);
		if (keyval_items(obj^.u.d.items)[i].v<>nil) then
			fz_drop_obj(keyval_items(obj^.u.d.items)[i].v);
	end;

	fz_free(obj^.u.d.items);
	fz_free(obj);
end;

procedure fz_drop_obj(obj:pfz_obj_s);
begin
	assert(obj <>nil);
  obj^.refs:=obj^.refs-1;
	if (obj^.refs=0) then
	begin
		if (obj^.kind = FZ_ARRAY) then
			fz_free_array(obj)
		else if (obj^.kind = FZ_DICT)  then
			fz_free_dict(obj)
		else
			fz_free(obj);
	end;
end;

procedure pdf_resize_xref(xref:ppdf_xref_s; newlen:integer);
var
i:integer;
begin
	xref.table := fz_realloc(xref.table, newlen, sizeof(pdf_xref_entry_s));
	for i := xref.len to newlen-1 do
	begin
		table_items(xref.table)[i].type1 := 0;
		table_items(xref.table)[i].ofs := 0;
		table_items(xref.table)[i].gen := 0;
		table_items(xref.table)[i].stm_ofs := 0;
		table_items(xref.table)[i].obj := nil;
	end;
	xref.len := newlen;
end;

function fz_array_len(obj:pfz_obj_s):integer;
begin
	obj := fz_resolve_indirect(obj);
	if (not fz_is_array(obj))  then
   result:=0
   else
  	result:= obj^.u.a.len;
end;




function fz_new_buffer( size:integer):pfz_buffer_s;
var
 b:	pfz_buffer_s ;
begin
  if size<=1 then
  size:=16;

	b := fz_malloc(sizeof(fz_buffer_s));
	b^.refs := 1;
	b^.data := fz_malloc(size);
	b^.cap := size;
	b^.len := 0;
  result:=b;

end;


function fz_keep_buffer(buf:pfz_buffer_s):pfz_buffer_s;
begin
	buf^.refs:=buf^.refs+1;
	result:=buf;
end;

procedure fz_drop_buffer(buf:pfz_buffer_s);
begin
  buf^.refs:=buf^.refs-1;
  if (buf^.refs=0) then
  begin
		fz_free(buf^.data);
		fz_free(buf);
	end;
end;

procedure fz_resize_buffer(buf:pfz_buffer_s;  size:integer) ;
begin
	buf^.data := fz_realloc(buf^.data, size, 1);
	buf^.cap := size;
	if (buf^.len > buf^.cap) then
		buf^.len := buf^.cap;
end;

procedure fz_grow_buffer(buf:pfz_buffer_s) ;
begin
	fz_resize_buffer(buf, (buf^.cap * 3) div 2);
end;




function atoi(const buf:pchar):integer;
var
s:string;
p:pchar;
begin
p:=buf;
s:=string(p);
s:=trim(s);
result:=strtoint(s);
end;

PROCEDURE DDDD;
BEGIN
EXIT;
END;


function fz_is_null(obj:pfz_obj_s):boolean;
begin
  result:=false;
	obj := fz_resolve_indirect(obj);
  if obj=nil then
  exit;
  if obj<>nil then
      if obj^.kind= FZ_NULL then
      result:=true;

end;



//* Convert Unicode/PdfDocEncoding string into utf-8 */

function pdf_to_utf8(src:pfz_obj_s):pchar;
var
	srcptr:pbyte;
	dstptr, dst:pchar;
	srclen,dstlen, ucs,i:integer;
  pl:pchar;
begin
 // result:=fz_to_str_buf(src);
  //exit;
  pl:=fz_to_str_buf(src);
  srcptr:=pbyte(pl);
  srclen:=fz_to_str_len(src);
  dstlen:=0;
	if ((srclen > 2) and (byte_items(srcptr)[0]= 254) and (byte_items(srcptr)[1] = 255))  then
	begin
		i := 2;
    while i< srclen do
		begin
			ucs:= (byte_items(srcptr)[i] SHL 8) OR byte_items(srcptr)[i+1];
			dstlen:=dstlen+ runelen(ucs);
      i:=i+2;
		end;
    dst := fz_malloc(dstlen + 1);
		dstptr := dst;

		i := 2;
    while i< srclen do
		begin
     	ucs := (byte_items(srcptr)[i] shl 8) or byte_items(srcptr)[i+1];
			dstptr :=dstptr+ runetochar(dstptr, @ucs);
      i:=i+2;
		end;


	end

	else
	BEGIN
		for i := 0 to srclen-1 do
			dstlen:=dstlen+ runelen(pdf_doc_encoding[byte_items(srcptr)[i]]);
     dst := fz_malloc(dstlen + 1);
		dstptr :=dst;

		for i := 0 to srclen-1 do
		BEGIN
			ucs := pdf_doc_encoding[byte_items(srcptr)[i]];
			//dstptr += runetochar(dstptr, &ucs);
       dstptr:=dstptr+runetochar(dstptr, @ucs);
		END;
	END;

	dstptr^:= #0;
	result:=dst;
end;

//* Convert Unicode/PdfDocEncoding string into ucs-2 */

function pdf_to_ucs2(src:pfz_obj_s):pword;
var
  srcptr:pbyte;
  dstptr, dst:pword;
  srclen,i:integer;
begin
	srcptr := pbyte(fz_to_str_buf(src));
	srclen := fz_to_str_len(src);
	if ((srclen > 2) and (byte_items(srcptr)[0] = 254) and (byte_items(srcptr)[1] = 255)) then
	begin
    dst := fz_calloc((srclen - 2) div 2 + 1, sizeof(word));
		dstptr :=dst;
		for i := 2 to srclen-1 do
    begin
       if (i mod 2)<>0 then
       continue;

       dstptr^:= (byte_items(srcptr)[i] shl 8) or byte_items(srcptr)[i+1];
       inc(dstptr);
    end;
	end

	else
	begin
    dst := fz_calloc(srclen + 1, sizeof(word));
		dstptr :=dst;
		for i := 0 to srclen-1 do
    begin
     dstptr^:= pdf_doc_encoding[byte_items(srcptr)[i]];
      inc(dstptr);
    end;
	end;

	dstptr^:=0;
	result:= dst;
end;

//* Convert UCS-2 string into PdfDocEncoding for authentication */
function pdf_from_ucs2(src1:pword) :pchar;
var
 i, j, len:integer;
	docstr:pchar;
  src:array of word;
begin
  src:=@src1;
  len := 0;
	while (src[len]<>0) do
  begin
		len:=len+1;
  end;
	docstr := fz_malloc(len + 1);

	for i := 0  to len-1 do
	begin
		//* shortcut: check if the character has the same code point in both encodings */
		if ((0 < src[i]) and (src[i] < 256) and (pdf_doc_encoding[src[i]] = src[i])) then
    begin
			(docstr+i)^ := chr(src[i]);
			continue;
		end;

		//* search through pdf_docencoding for the character's code point */
		for j := 0 to 256-1 do
    begin
			if (pdf_doc_encoding[j] = src[i]) then
				break;
    end;
		(docstr+i)^ := chr(j);

		//* fail, if a character can't be encoded */
		if ((docstr+i)<>nil) then
		begin
			fz_free(docstr);
			result:= nil;
      exit;
		end;
	end;
	(docstr+len)^ :=#0; // '\0';

	result:=docstr;
end;


function pdf_to_utf8_name(src:pfz_obj_s):pfz_obj_s;
var
buf:pchar;
dst:pfz_obj_s;
begin
	buf := pdf_to_utf8(src);
	dst:= fz_new_name(buf);
	fz_free(buf);
	result:= dst;
end;

function fz_objcmp(a:pfz_obj_s;b:pfz_obj_s):integer;
var
i:integer;
begin

	if (a = b) then
	begin
    result:=0;
    exit;
  end;

	if (a<>nil) or (b<>nil ) then
	begin
    result:=1;
    exit;
  end;

	if (a^.kind <> b^.kind)  then
		begin
    result:=1;
    exit;
  end;

	case a^.kind of
	FZ_NULL:
		begin
    result:=0;
    exit;
    end;

	FZ_BOOL:
    begin
		result:= a^.u.b - b^.u.b;
    exit;
    end;
  FZ_INT:
     begin
		result:= a^.u.i - b^.u.i;
    exit;
    end;
	FZ_REAL:
    begin
		if (a^.u.f < b^.u.f) then
      begin
			result:= -1;
      exit;
      end;
		if (a^.u.f > b^.u.f) then
			begin
			result:=1;
      exit;
      end;
	  	result:=0;
      exit;
    end;
	FZ_STRING:
    begin
		if (a^.u.s.len < b^.u.s.len) then
		begin
      result:=1 ;
			if (memcmp(@a^.u.s.buf, @b^.u.s.buf, a^.u.s.len) <= 0)  then
				result:= -1;
			exit;
		end;
		if (a^.u.s.len > b^.u.s.len)  then
		begin
       result:= -1;
			if (memcmp(@a^.u.s.buf, @b^.u.s.buf, b^.u.s.len) >= 0) then
			result:=1;
			exit;
		end;
		result:=memcmp(@a^.u.s.buf, @b^.u.s.buf, a^.u.s.len);
    exit;
   end;
	FZ_NAME:
   begin
		result:= strcomp(a^.u.n, b^.u.n);
    exit;
   end;
	FZ_INDIRECT:
    begin
    result:=a^.u.r.num - b^.u.r.num;
		if (a^.u.r.num = b^.u.r.num)  then
			result:= a^.u.r.gen - b^.u.r.gen;
     exit;
    end;
	FZ_ARRAY:
    begin
		if (a^.u.a.len <> b^.u.a.len) then
    begin
			result:= a^.u.a.len - b^.u.a.len;
      exit;
    end;
		for i := 0  to a^.u.a.len-1  do
			if (fz_objcmp(fz_obj_s_items(a^.u.a.items)[i], fz_obj_s_items(b^.u.a.items)[i])<>0)  then
      begin
				result:= 1;
        exit;
      end;
		result:= 0;
    exit;
    end;
	FZ_DICT:
    begin
		if (a^.u.d.len <> b^.u.d.len) then
    begin
			result:= a^.u.d.len - b^.u.d.len;
      exit;
    end;
		for i:= 0 to a^.u.d.len-1 do
		begin
			if (fz_objcmp(keyval_items(a^.u.d.items)[i].k, keyval_items(b^.u.d.items)[i].k)<>0)  then
      begin
				result:= 1;
        exit;
      end;
			if (fz_objcmp(keyval_items(a^.u.d.items)[i].v, keyval_items(b^.u.d.items)[i].v)<>0) then
      begin
				result:= 1;
        exit;
      end;
		end;
		result:= 0;
    exit;

	end;
  end;
	result:=1;
end;

 function memcmp(cs,ct:Pointer; count:Cardinal):Integer;
var
  su1,su2:PByte;
begin
  su1 := cs;
  su2 := ct;
  while 0<count do
  begin
  Result:=su1^-su2^;
  if Result<>0 then
  Break;
  Dec(count);
  Inc(su1);
  Inc(su2);
  end;
end;


function pdf_to_rect(array1:pfz_obj_s) :fz_rect ;
var
 r:	fz_rect ;
 a,b,c,d:single;
begin
	a := fz_to_real(fz_array_get(array1, 0));
	b := fz_to_real(fz_array_get(array1, 1));
	c := fz_to_real(fz_array_get(array1, 2));
	d := fz_to_real(fz_array_get(array1, 3));
	r.x0 := MIN(a, c);
	r.y0 := MIN(b, d);
	r.x1 := MAX(a, c);
	r.y1 := MAX(b, d);
  result:=r;

end;


function pdf_to_matrix(array1:pfz_obj_s) :fz_matrix ;
var
	m:fz_matrix;
begin
	m.a := fz_to_real(fz_array_get(array1, 0));
	m.b := fz_to_real(fz_array_get(array1, 1));
	m.c := fz_to_real(fz_array_get(array1, 2));
	m.d := fz_to_real(fz_array_get(array1, 3));
	m.e := fz_to_real(fz_array_get(array1, 4));
	m.f := fz_to_real(fz_array_get(array1, 5));
	result:=m;
end;

function pdf_resolve_indirect(ref:pfz_obj_s): pfz_obj_s;
var
 xref :ppdf_xref_s;
 num,gen:integer;
 error:integer;

 obj:pfz_obj_s;
begin
  result:=ref;

	if (fz_is_indirect(ref)) then
	begin
		 xref:= fz_get_indirect_xref(ref);
		num := fz_to_num(ref);
		gen := fz_to_gen(ref);
		if (xref<>nil) then
		begin
			error := pdf_cache_object(xref, num, gen);
			if (error<0) then
			begin
			 //	fz_catch(error, "cannot load object (%d %d R) into cache", num, gen);
				result:=ref;
        exit;
			end;

    	if table_items(xref^.table)[num].obj<>nil then
      begin
        obj:=table_items(xref^.table)[num].obj;
        
				result:= obj; //table_items(xref^.table)[num].obj;
        exit;
      end;
		end;
	end;

end;

function fz_debug_dict_gets(obj:pfz_obj_s) :pfz_obj_s;
var
i:integer;
s:string;
v:pfz_obj_s;
begin
exit;
	obj := fz_resolve_indirect(obj);

	if (not fz_is_dict(obj)) then
     begin
				result:=nil;;
        exit;
      end;

  //s:=format('total sub dicts: len:=%d, cap:=%d /n',[ obj^.u.d.len,obj^.u.d.cap]);
 // OutputDebugString(pchar(s));

  for  i := 0 to obj^.u.d.len-1 do
  begin
      s:=fz_to_name(keyval_items(obj^.u.d.items)[i].k);
      s:=s+'/n';
      //OutputDebugString(pchar(s));
     v:=keyval_items(obj^.u.d.items)[i].v;
     s:=format(' refs:=%d, kind:=%d /n',[ v.refs,ord(v.kind)]);
      s:=s+'/n';
    //  OutputDebugString(pchar(s));
          
	end;

end;

function fz_objkindstr(obj:pfz_obj_s):pchar;
begin
	if (obj = nil) then
  BEGIN
		result:='<NULL>';    //不明白
    EXIT;
  END;
	case (obj^.kind) of
	FZ_NULL:
    begin
      result:= 'null';
      exit;
  end;
	FZ_BOOL:
  begin
    result:= 'boolean';
    exit;
  end;
	FZ_INT:
  begin
    result:= 'integer';
    exit;
  end;
	FZ_REAL:
  begin
    result:= 'real';
    exit;
  end;
	FZ_STRING:
  begin
    result:= 'string';
    exit;
  end;
	FZ_NAME:
  begin
    result:= 'name';
    exit;
  end;
	FZ_ARRAY:
  begin
    result:= 'array';
    exit;
  end;
	FZ_DICT:
  begin
    result:= 'dictionary';
    exit;
  end;
	FZ_INDIRECT:
  begin
    result:= 'reference';
    exit;
  end;
	end;
	result:='<unknown>';
end;

function strerror(i:integer):pchar;
begin
  result:='unkon error';
end;

function getwidestr(mypchar:pchar):widestring;
var
	wide:array[0..255] of widechar;
  dp:pwidechar;
	sp:pchar;
	rune:integer;
begin
  result:=UTF8StringToWideString(mypchar);
  exit;
	dp := wide;
	sp := mypchar;
	while ((sp<>nil)  and (cardinal(dp) < cardinal(@wide) + 255)) do
	begin
		inc(sp, chartorune(@rune, sp));
    dp^:=widechar(rune);
		inc(dp) ;
	end;
	dp^ := #0;
  result:=widestring(wide);
end;

function getwidestrs(s:string):widestring;

begin
  result:=UTF8StringToWideString(s);
  exit;

end;

function fz_is_empty_bbox(b:fz_bbox) :boolean;
begin
 result:=(b.x0 = b.x1);
end;
{
function StringToWideStringEx(const S: String; CodePage: Word): WideString;
var
  L: Integer;
begin
  L:= MultiByteToWideChar(CodePage, 0, PChar(S), -1, nil, 0);
  SetLength(Result, L-1);
  MultiByteToWideChar(CodePage, 0, PChar(S), -1, PWideChar(Result), L - 1);
end;

function WideStringToStringEx(const WS: WideString; CodePage: Word): String;
var
  L: Integer;
begin
  L := WideCharToMultiByte(CodePage, 0, PWideChar(WS), -1, nil, 0, nil, nil);
  SetLength(Result, L-1);
  WideCharToMultiByte(CodePage, 0, PWideChar(WS), -1, PChar(Result), L - 1, nil, nil);
end;
}

function fz_span_to_wchar( text:pfz_text_span_s; lineSep:pchar):widestring;
var
  lineSepLen,textLen:dword;
  content,dest:pwidechar;
  span:pfz_text_span_s;
  i,k:integer;
  sw:widestring;
begin 

    lineSepLen := strLen(lineSep);
    textLen := 0;
    span := text;
    while  span<>nil do
    begin
        textLen :=textLen+ span^.len + lineSepLen;
        span := span^.next ;
    end;
    getmem(content, (textLen + 1)*2);
  //  zeromemory(content,(textLen + 1)*2);
    fillchar(content^,(textLen + 1)*2,0);
    if (content=nil) then
    begin
        freemem(content);
        result:='';
        exit;
    end;
    dest := content;
    span := text;
    while span<>nil do // span = span->next) {
    begin

        for i := 0 to span^.len-1 do
        begin

            word_items(dest)[0]:= fz_text_char_s_items(span^.text)[i].c;

          if word_items(dest)[0] < 32 then
               word_items(dest)[0]:=ord('?');
             //   dest^ := '?';
            inc(dest);

        end;
        if (span^.eol=0) and (span^.next<>nil) then
        begin
            span := span^.next;
            continue;
        end;
        //k:=MultiByteToWideChar(CP_ACP, 0, lineSep, -1, dest, lineSepLen+1 );
       //  word_items(dest)[0]:=13 shl 8 +10;
         //copymemory(dest,lineSep,lineSepLen);
          word_items(dest)[0]:=13;
         inc(dest);
         word_items(dest)[0]:=10;
         inc(dest);
        //inc(dest,k div 2  );
        span := span^.next;
    end;
    sw:=widestring(content);
    freemem(content);
    result:=sw;
end;

procedure copymemory(s,c:pointer;lenn:integer);
begin
  move(c^,s^,lenn);
end;

procedure zeromemory(p:pointer;lenn:integer);
begin
 fillchar(p^,lenn,0);
end;

end.


