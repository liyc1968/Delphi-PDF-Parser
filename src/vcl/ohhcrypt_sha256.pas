unit ohhcrypt_sha256;

interface
uses digtypes, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  Math;

procedure fz_sha256_init(context:pfz_sha256_s);
procedure fz_sha256_update(context:pfz_sha256_s;  input:pbyte; inlen:dword);
procedure fz_sha256_final(context:pfz_sha256_s; var digest:array of byte);

implementation

function  isbigendian():boolean;
{j+}
const  one:integer = 1;
{j-}
begin

	result:= one = 0;
end;

procedure copymemory(s,c:pointer;lenn:integer);
begin
  move(c^,s^,lenn);
end;

procedure zeromemory(p:pointer;lenn:integer);
begin
 fillchar(p^,lenn,0);
end;

function bswap32(num:dword):dword;
BEGIN
	if (not isbigendian()) then
	begin
		result:=	( (((num) shl 24)) or (((num) shl 8) and $00FF0000) or (((num) shr 8) and $0000FF00)  or (((num) shr 24)) );
    exit;
	end;
	result:= num;
end;

//* At least on x86, GCC is able to optimize this to a rotate instruction. */
function rotr_32(num, amount:dword):dword;
begin
  result:=((num) shr (amount)) or ((num) shl (32 - (amount)));
end;


(*
#define blk0(i) (W[i] = data[i])
#define blk2(i) (W[i & 15] += s1(W[(i - 2) & 15]) + W[(i - 7) & 15] \
		+ s0(W[(i - 15) & 15]))

#define Ch(x, y, z) (z ^ (x & (y ^ z)))
#define Maj(x, y, z) ((x & y) | (z & (x | y)))

#define a(i) T[(0 - i) & 7]
#define b(i) T[(1 - i) & 7]
#define c(i) T[(2 - i) & 7]
#define d(i) T[(3 - i) & 7]
#define e(i) T[(4 - i) & 7]
#define f(i) T[(5 - i) & 7]
#define g(i) T[(6 - i) & 7]
#define h(i) T[(7 - i) & 7]

#define R(i) \
	h(i) += S1(e(i)) + Ch(e(i), f(i), g(i)) + SHA256_K[i + j] \
		+ (j ? blk2(i) : blk0(i)); \
	d(i) += h(i); \
	h(i) += S0(a(i)) + Maj(a(i), b(i), c(i))

#define S0(x) (rotr_32(x, 2) ^ rotr_32(x, 13) ^ rotr_32(x, 22))
#define S1(x) (rotr_32(x, 6) ^ rotr_32(x, 11) ^ rotr_32(x, 25))
#define s0(x) (rotr_32(x, 7) ^ rotr_32(x, 18) ^ (x >> 3))
#define s1(x) (rotr_32(x, 17) ^ rotr_32(x, 19) ^ (x >> 10))
*)
const  SHA256_K:array[0..63] of dword = (
	$428A2F98, $71374491, $B5C0FBCF, $E9B5DBA5,
	$3956C25B, $59F111F1, $923F82A4, $AB1C5ED5,
	$D807AA98, $12835B01, $243185BE, $550C7DC3,
	$72BE5D74, $80DEB1FE, $9BDC06A7, $C19BF174,
	$E49B69C1, $EFBE4786, $0FC19DC6, $240CA1CC,
	$2DE92C6F, $4A7484AA, $5CB0A9DC, $76F988DA,
	$983E5152, $A831C66D, $B00327C8, $BF597FC7,
	$C6E00BF3, $D5A79147, $06CA6351, $14292967,
	$27B70A85, $2E1B2138, $4D2C6DFC, $53380D13,
	$650A7354, $766A0ABB, $81C2C92E, $92722C85,
	$A2BFE8A1, $A81A664B, $C24B8B70, $C76C51A3,
	$D192E819, $D6990624, $F40E3585, $106AA070,
	$19A4C116, $1E376C08, $2748774C, $34B0BCB5,
	$391C0CB3, $4ED8AA4A, $5B9CCA4F, $682E6FF3,
	$748F82EE, $78A5636F, $84C87814, $8CC70208,
	$90BEFFFA, $A4506CEB, $BEF9A3F7, $C67178F2
);

function Ch(x, y, z:dword):dword;
begin
 result:=(z or (x and (y xor z))) ;
end;

function Ch256(x, y, z: LongWord): LongWord; 
begin 
  Result := (x and y) xor ((not x) and z); 
end;
 
function Maj(x, y, z: Int64): Int64; 
begin 
  Result := (x and y) xor (x and z) xor (y and z); 
end; 

function ror(x: LongWord; y: Byte): LongWord; assembler;
asm
  mov   cl,dl
  ror   eax,cl
end;

function rol(x: LongWord; y: Byte): LongWord; assembler;
asm
  mov   cl,dl
  rol   eax,cl
end;

function ror64(x: Int64; y: Byte): Int64;
begin
  Result := (x shr y) or (x shl (64 - y));
end;

function Endian(X: LongWord): LongWord; assembler;
asm
  bswap eax
end;


function S0(x:dword):dword;
begin
 result:=(rotr_32(x, 2) xor rotr_32(x, 13) xor rotr_32(x, 22)) ;
end;
function S1(x:dword):dword;
begin
  result:=(rotr_32(x, 6) xor rotr_32(x, 11) xor rotr_32(x, 25)) ;
end;

function Maj1(x, y, z:dword):dword;
begin
result:= ((x and y) or (z and (x xor y)));
end;


function Maj256(x, y, z: LongWord): LongWord; 
begin 
  Result := (x and y) xor (x and z) xor (y and z); 
end;

function E0256(x: LongWord): LongWord; 
begin 
  Result := ror(x, 2) xor ror(x, 13) xor ror(x, 22);
end; 
 
function E1256(x: LongWord): LongWord; 
begin 
  Result := ror(x, 6) xor ror(x, 11) xor ror(x, 25); 
end; 
 
function F0256(x: LongWord): LongWord; 
begin 
  Result := ror(x, 7) xor ror(x, 18) xor (x shr 3); 
end; 
 
function F1256(x: LongWord): LongWord; 
begin 
  Result := ror(x, 17) xor ror(x, 19) xor (x shr 10); 
end;


procedure
transform(var state:array of dword; const data_xe:array of dword);
var 
  S: array[0..7] of LongWord; 
  W: array[0..63] of LongWord; 
  t1, t2: LongWord;
  i: LongWord; 
begin 
  Move(state, S, SizeOf(S));
  for i := 0 to 15 do 
    W[i] := Endian(PLongWord(LongWord(@state) + i * 4)^);
  for i := 16 to 63 do
    W[i] := F1256(W[i - 2]) + W[i - 7] + F0256(W[i - 15]) + W[i - 16];
  for i := 0 to 63 do
  begin 
    t1 := S[7] + E1256(S[4]) + Ch256(S[4], S[5], S[6]) + SHA256_K[i] + W[i];
    t2 := E0256(S[0]) + Maj256(S[0], S[1], S[2]);
    S[7] := S[6];
    S[6] := S[5]; 
    S[5] := S[4]; 
    S[4] := S[3] + t1;
    S[3] := S[2]; 
    S[2] := S[1]; 
    S[1] := S[0]; 
    S[0] := t1 + t2; 
  end; 
  for i := 0 to 7 do 
    state[i] := state[i] + S[i];


end;

procedure
transform1(var state:array of dword; const data_xe:array of dword);
var
	data:array[0..15] of dword;
  W:array[0..15] of dword;
	T:array[0..7] of dword;
	j:dword;
  i:integer;
  ai,bi,ci,di,ei,fi,gi,v1,v2,v3,v4:dword;
  bb:dword;
begin
	//* ensure big-endian integers */
	for j := 0 to 15 do
		data[j] := bswap32(data_xe[j]);

	//* Copy state[] to working vars. */
	copymemory(@T, @state, sizeof(T));

	//* 64 operations, partially loop unrolled */
  j:=0;
	while j < 64-1 do
  begin

  for i:=0 to 15 do
  begin
  ei:=T[(4 - i) and 7];
  fi:=  T[(5 - i) and 7];
  gi:= T[(6 - i) and 7];
  if j<>0 then
  begin
   W[i and 15] :=W[i and 15]+ s1(W[(i - 2) and 15]) + W[(i - 7) and 15] + s0(W[(i - 15) and 15]);
   bb:=W[i and 15];
  end
   ELSE
   begin
   W[i] := data[i];
   bb:=W[i];
  end;
   v1:=s1(ei);
   v2:=Ch(ei, fi, gi);
   v3:=SHA256_K[i + j];
   T[(0 - i) and 7] :=T[(0 - i) and 7]+ v1 + v2 + v3 + bb;
   T[(3 - i) and 7] :=T[(3 - i) and 7]+ T[(0 - i) and 7];
   ai:= T[(0 - i) and 7];
   bi:= T[(1 - i) and 7];
   ci:=  T[(2 - i) and 7] ;
   T[(0 - i) and 7] :=T[(0 - i) and 7]+ S0(ai) + Maj(ai, bi, ci);

  end;

	 {	R( 0); R( 1); R( 2); R( 3);
		R( 4); R( 5); R( 6); R( 7);
		R( 8); R( 9); R(10); R(11);
		R(12); R(13); R(14); R(15); }
    j:=j+16;
	end;

	//* Add the working vars back into state[]. */

	state[0] :=state[0] + T[(0) and 7];
	state[1] :=state[1]+ T[(1) and 7];
	state[2] :=state[2]+ T[(2) and 7];
	state[3] :=state[3]+ T[(3) and 7];
	state[4] :=state[4]+ T[(4) and 7];
	state[5] :=state[5]+ T[(5) and 7];
	state[6] :=state[6]+ T[(6) and 7];
	state[7] :=state[7]+ T[(7) and 7];
end;

procedure fz_sha256_init(context:pfz_sha256_s);
begin
  context^.count[1] := 0;
	context^.count[0] := context^.count[1];

	context^.state[0] := $6A09E667;
	context^.state[1] := $BB67AE85;
	context^.state[2] := $3C6EF372;
	context^.state[3] := $A54FF53A;
	context^.state[4] := $510E527F;
	context^.state[5] := $9B05688C;
	context^.state[6] := $1F83D9AB;
	context^.state[7] := $5BE0CD19;
end;

procedure fz_sha256_update(context:pfz_sha256_s; input:pbyte; inlen:dword);

var
		 copy_size,copy_start:dword;
begin
	(* Copy the input data into a properly aligned temporary buffer.
	 * This way we can be called with arbitrarily sized buffers
	 * (no need to be multiple of 64 bytes), and the code works also
	 * on architectures that don't allow unaligned memory access. *)
	while (inlen > 0) do
	begin
		copy_start := context^.count[0] and $3F;
		copy_size := 64 - copy_start;
		if (copy_size > inlen) then
			copy_size := inlen;

		copymemory(pointer(cardinal(@context^.buffer.u8) + copy_start*sizeof(dword)), input, copy_size);     //可能不对

		inc(input, copy_size);
		inlen :=inlen - copy_size;
		context^.count[0] :=context^.count[0]+ copy_size;
		//* carry overflow from low to high */
		if (context^.count[0] < copy_size) then
			context^.count[1]:=context^.count[1]+1;

		if ((context^.count[0] and $3F) = 0) then
			transform(context^.state, context^.buffer.u32);
	end;
end;

procedure fz_sha256_final(context:pfz_sha256_s; var digest:array of byte);
var
	(* Add padding as described in RFC 3174 (it describes SHA-1 but
	 * the same padding style is used for SHA-256 too). *)
j:dword;
begin
	j := context^.count[0] and $3F;
	context^.buffer.u8[j] := $80;
  j:=j+1;

	while (j <> 56) do
	begin
		if (j = 64) then
		begin
			transform(context^.state, context^.buffer.u32);
			j := 0;
		end;
		context^.buffer.u8[j] := $00;
    j:=j+1;
	end;

	//* Convert the message size from bytes to bits. */
	context^.count[1] := (context^.count[1] shl 3) + (context^.count[0] shr 29);
	context^.count[0] := context^.count[0] shl 3;

	context^.buffer.u32[14] := bswap32(context^.count[1]);
	context^.buffer.u32[15] := bswap32(context^.count[0]);
	transform(context^.state, context^.buffer.u32);

	for j := 0 to 7 do
		digest[j] := bswap32(context^.state[j]);
	fillchar(context^,  sizeof(fz_sha256_s),0);
end;

end.




