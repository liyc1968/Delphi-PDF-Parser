unit ohhcrypt_md5;

interface
uses digtypes, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  Math;
procedure fz_md5_init(context:pfz_md5_s);
procedure fz_md5_update(context:pfz_md5_s; const input:pbyte; const inlen:longword);
procedure fz_md5_final(context:pfz_md5_s; digest:pbyte) ;

implementation


const

	S11 = 7; S12 = 12; S13 = 17; S14 = 22;
	S21 = 5; S22 = 9; S23 = 14; S24 = 20;
	S31 = 4; S32 = 11; S33 = 16; S34 = 23;
	S41 = 6; S42 = 10; S43 = 15; S44 = 21;




CONST padding:array[0..63] of byte =
(
	$80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
);

(*//* F, G, H and I are basic MD5 functions */
#define F(x, y, z) (((x) & (y)) | ((~x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & (~z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | (~z)))
                                              *)
procedure copymemory(s,c:pointer;lenn:integer);
begin
  move(c^,s^,lenn);
end;

procedure zeromemory(p:pointer;lenn:integer);
begin
 fillchar(p^,lenn,0);
end;

function F(x, y, z:longword):longword;
begin
  result:=((x and y) or ((not x) and z));
end;

function G(x, y, z:longword):longword;
begin
  result:=(x and z) or (y and (not z));
end;

function H(x, y, z:longword):longword;
begin
  result:=(x xor y xor (z));
end;

function I(x, y, z:longword):longword;
begin
   result:=y xor (x or (not z));
end;


//* ROTATE rotates x left n bits */

function ROTATE(a, b: longword): longword;
begin
  Result:= (a shl b) or (a shr (32-b));
end;

(* FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4.
 * Rotation is separate from addition to prevent recomputation.
 *)

{$OVERFLOWCHECKS OFF}
procedure FF(var a:longword; b, c, d, x:longword; s:byte; ac:longword);
begin
	a :=a+ F (b, c, d) + x +ac;
	a := ROTATE (a, s);
	a :=a+ b;
end;
procedure GG(var a:longword; b, c, d, x:longword; s:byte; ac:longword);
begin
	a :=a+ G (b, c, d) + x + ac;
	a := ROTATE (a, s);
	a :=a+ (b);
end;
procedure HH(var a:longword; b, c, d, x:longword; s:byte; ac:longword);
begin
	a :=a+ H (b, c, d) + x + ac;
	a := ROTATE (a, s);
	a :=a+ b;
end;

procedure II(var a:longword; b, c, d, x:longword; s:byte; ac:longword);
begin
	a:=a+ I (b, c, d) + x + ac;
	a:= ROTATE (a, s);
	a:=a+ (b); 
end;
{$OVERFLOWCHECKS ON}
procedure encode(output:pbyte; const input:plongword; const len:longword);
var
	 i, j:longword;
begin
  j:=0;
  i:=0;
	while j < len do
	begin
		byte_items(output)[j] := (longword_items(input)[i] and $ff);
		byte_items(output)[j+1] := ((longword_items(input)[i] shr 8) and $ff);
		byte_items(output)[j+2] := ((longword_items(input)[i] shr 16) and $ff);
		byte_items(output)[j+3] := ((longword_items(input)[i] shr 24) and $ff);
    j:=j+4;
    i:=i+1;
	end;
end;

procedure decode(output:plongword; const input:pbyte; const len:longword);
var
	i, j:longword;
begin
  i:=0;
  j:=0;
	while j < len do 
	begin
		longword_items(output)[i] := (byte_items(input)[j]) or ((byte_items(input)[j+1]) shl 8) or ((byte_items(input)[j+2]) shl 16) or ((byte_items(input)[j+3]) shl 24);
    i:=i+1;
    j:=j+4;
	end;
end;
{$OVERFLOWCHECKS OFF}
procedure transform( state:plongword; const block:array of byte); //unsigned int state[4], const unsigned char block[64]
var
  a,b,c,d:longword;
  x:array[0..15] of longword;
begin
	a := longword_items(state)[0];
	b := longword_items(state)[1];
	c := longword_items(state)[2];
	d := longword_items(state)[3];
	decode(@x, @block, 64);

	/// Round 1 */
	FF (a, b, c, d, x[ 0], S11, $d76aa478); // 1 */
	FF (d, a, b, c, x[ 1], S12, $e8c7b756); // 2 */
	FF (c, d, a, b, x[ 2], S13, $242070db); // 3 */
	FF (b, c, d, a, x[ 3], S14, $c1bdceee); // 4 */
	FF (a, b, c, d, x[ 4], S11, $f57c0faf); // 5 */
	FF (d, a, b, c, x[ 5], S12, $4787c62a); // 6 */
	FF (c, d, a, b, x[ 6], S13, $a8304613); // 7 */
	FF (b, c, d, a, x[ 7], S14, $fd469501); // 8 */
	FF (a, b, c, d, x[ 8], S11, $698098d8); // 9 */
	FF (d, a, b, c, x[ 9], S12, $8b44f7af); // 10 */
	FF (c, d, a, b, x[10], S13, $ffff5bb1); // 11 */
	FF (b, c, d, a, x[11], S14, $895cd7be); // 12 */
	FF (a, b, c, d, x[12], S11, $6b901122); // 13 */
	FF (d, a, b, c, x[13], S12, $fd987193); // 14 */
	FF (c, d, a, b, x[14], S13, $a679438e); // 15 */
	FF (b, c, d, a, x[15], S14, $49b40821); // 16 */

	// Round 2 */
	GG (a, b, c, d, x[ 1], S21, $f61e2562); // 17 */
	GG (d, a, b, c, x[ 6], S22, $c040b340); // 18 */
	GG (c, d, a, b, x[11], S23, $265e5a51); // 19 */
	GG (b, c, d, a, x[ 0], S24, $e9b6c7aa); // 20 */
	GG (a, b, c, d, x[ 5], S21, $d62f105d); // 21 */
	GG (d, a, b, c, x[10], S22, $02441453); // 22 */
	GG (c, d, a, b, x[15], S23, $d8a1e681); // 23 */
	GG (b, c, d, a, x[ 4], S24, $e7d3fbc8); // 24 */
	GG (a, b, c, d, x[ 9], S21, $21e1cde6); // 25 */
	GG (d, a, b, c, x[14], S22, $c33707d6); // 26 */
	GG (c, d, a, b, x[ 3], S23, $f4d50d87); // 27 */
	GG (b, c, d, a, x[ 8], S24, $455a14ed); // 28 */
	GG (a, b, c, d, x[13], S21, $a9e3e905); // 29 */
	GG (d, a, b, c, x[ 2], S22, $fcefa3f8); // 30 */
	GG (c, d, a, b, x[ 7], S23, $676f02d9); // 31 */
	GG (b, c, d, a, x[12], S24, $8d2a4c8a); // 32 */

	// Round 3 */
	HH (a, b, c, d, x[ 5], S31, $fffa3942); // 33 */
	HH (d, a, b, c, x[ 8], S32, $8771f681); // 34 */
	HH (c, d, a, b, x[11], S33, $6d9d6122); // 35 */
	HH (b, c, d, a, x[14], S34, $fde5380c); // 36 */
	HH (a, b, c, d, x[ 1], S31, $a4beea44); // 37 */
	HH (d, a, b, c, x[ 4], S32, $4bdecfa9); // 38 */
	HH (c, d, a, b, x[ 7], S33, $f6bb4b60); // 39 */
	HH (b, c, d, a, x[10], S34, $bebfbc70); // 40 */
	HH (a, b, c, d, x[13], S31, $289b7ec6); // 41 */
	HH (d, a, b, c, x[ 0], S32, $eaa127fa); // 42 */
	HH (c, d, a, b, x[ 3], S33, $d4ef3085); // 43 */
	HH (b, c, d, a, x[ 6], S34, $04881d05); // 44 */
	HH (a, b, c, d, x[ 9], S31, $d9d4d039); // 45 */
	HH (d, a, b, c, x[12], S32, $e6db99e5); // 46 */
	HH (c, d, a, b, x[15], S33, $1fa27cf8); // 47 */
	HH (b, c, d, a, x[ 2], S34, $c4ac5665); // 48 */

	// Round 4 */
	II (a, b, c, d, x[ 0], S41, $f4292244); // 49 */
	II (d, a, b, c, x[ 7], S42, $432aff97); // 50 */
	II (c, d, a, b, x[14], S43, $ab9423a7); // 51 */
	II (b, c, d, a, x[ 5], S44, $fc93a039); // 52 */
	II (a, b, c, d, x[12], S41, $655b59c3); // 53 */
	II (d, a, b, c, x[ 3], S42, $8f0ccc92); // 54 */
	II (c, d, a, b, x[10], S43, $ffeff47d); // 55 */
	II (b, c, d, a, x[ 1], S44, $85845dd1); // 56 */
	II (a, b, c, d, x[ 8], S41, $6fa87e4f); // 57 */
	II (d, a, b, c, x[15], S42, $fe2ce6e0); // 58 */
	II (c, d, a, b, x[ 6], S43, $a3014314); // 59 */
	II (b, c, d, a, x[13], S44, $4e0811a1); // 60 */
	II (a, b, c, d, x[ 4], S41, $f7537e82); // 61 */
	II (d, a, b, c, x[11], S42, $bd3af235); // 62 */
	II (c, d, a, b, x[ 2], S43, $2ad7d2bb); // 63 */
	II (b, c, d, a, x[ 9], S44, $eb86d391); // 64 */

  longword_items(state)[0] :=longword_items(state)[0]+ a;
	longword_items(state)[1] :=longword_items(state)[1]+ b;
	longword_items(state)[2] :=longword_items(state)[2]+ c;
	longword_items(state)[3] :=longword_items(state)[3]+ d;

	//* Zeroize sensitive information */
	fillchar(x,sizeof (x), 0 );
end;
{$OVERFLOWCHECKS ON}
//* MD5 initialization. Begins an MD5 operation, writing a new context. */
procedure fz_md5_init(context:pfz_md5_s);
begin
  context^.count[1] := 0;
	context^.count[0] := context^.count[1];

	//* Load magic initialization constants */
	context^.state[0] := $67452301;
	context^.state[1] := $efcdab89;
	context^.state[2] := $98badcfe;
	context^.state[3] := $10325476;
end;

(* MD5 block update operation. Continues an MD5 message-digest operation,
 * processing another message block, and updating the context.
 *)
procedure fz_md5_update(context:pfz_md5_s; const input:pbyte; const inlen:longword);
var
 i, index, partlen:longword;
begin
	//* Compute number of bytes mod 64 */
	index := ((context^.count[0] shr 3) and $3F);

	//* Update number of bits */
	context^.count[0] :=context^.count[0] +  (inlen shl 3);
	if context^.count[0] <  (inlen shl 3) then
		context^.count[1]:=context^.count[1]+1;
	context^.count[1] :=context^.count[1]+ ( inlen shr 29) ;

	partlen := 64 - index;

	//* Transform as many times as possible. */
	if (inlen >= partlen) then
	begin
		copymemory(pointer( cardinal(@context^.buffer) + index), input, partlen);
		transform(@context^.state, context^.buffer);
    i:=partlen;
		while i + 63 < inlen do
    begin
			transform(@context^.state, byte_items(pointer(cardinal(input) + i)));
      i:=i+64;
    end;
		index := 0;
	end
	else
	begin
		i := 0;
	end;

	//* Buffer remaining input */
	copymemory(pointer(cardinal(@context^.buffer) + index), pointer(cardinal(input) + i), inlen - i);
end;

(* MD5 finalization. Ends an MD5 message-digest operation, writing the
 * the message digest and zeroizing the context.
 *)
procedure fz_md5_final(context:pfz_md5_s; digest:pbyte) ;       // unsigned char digest[16]
var
	 bits:array[0..7] of byte;
	 index, padlen:longword;
begin
	//* Save number of bits */
	encode(@bits, @context^.count, 8);

	//* Pad out to 56 mod 64 */
	index := ((context^.count[0] shr 3) and $3f);
  if index < 56 then
  	padlen :=  56 - index
  else
    padlen :=120 - index;

	fz_md5_update(context, @padding, padlen);

	//* Append length (before padding) */
	fz_md5_update(context, @bits, 8);

	//* Store state in digest */
	encode(digest, @context^.state, 16);

	//* Zeroize sensitive information */
	fillchar(context^,  sizeof(fz_md5_s),0);
end;


end.
