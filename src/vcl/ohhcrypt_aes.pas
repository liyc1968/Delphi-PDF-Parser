unit ohhcrypt_aes;


interface

uses
  SysUtils,digtypes;
procedure aes_setkey_dec( ctx:pfz_aes_s; const key:pbyte; keysize:integer );
PROCEDURE aes_crypt_cbc( ctx:pfz_aes_s; mode:integer; length:integer; var iv:array of byte;input:pbyte;	output:pbyte);

implementation

var
FSb:array[0..255] of byte;
FT0:array[0..255] of longword;
FT1:array[0..255] of longword;
FT2:array[0..255] of longword;
FT3:array[0..255] of longword;


RSb:array[0..255] of byte;
RT0:array[0..255] of longword;
RT1:array[0..255] of longword;
RT2:array[0..255] of longword;
RT3:array[0..255] of longword;

//* * Round constants */
RCON:array[0..9] of longword;

aes_init_done:byte = 0;

procedure copymemory(s,c:pointer;lenn:integer);
begin
  move(c^,s^,lenn);
end;

procedure zeromemory(p:pointer;lenn:integer);
begin
 fillchar(p^,lenn,0);
end;

function GET_ULONG_LE(var n:longword; b:pbyte; i:longword):longword;
begin
	n:= ( byte_items(b)[i] ) or (  byte_items(b)[i + 1] shl 8 ) or (  byte_items(b)[i + 2] shl 16 )	or ( byte_items(b)[i + 3] shl 24 );
  exit;
end;

procedure PUT_ULONG_LE(n:longword;b:pbyte;i:longword);
begin
	 byte_items(b)[i ] :=  n;
	 byte_items(b)[i + 1] := n shr 8 ;
	 byte_items(b)[i + 2] := n shr 16 ;
	 byte_items(b)[i + 3] := n shr 24 ;
end;

function ROTL8(x:longword):longword;
begin
 result:= ( ( x shl 8 ) and $FFFFFFFF ) or ( x shr 24 ) ;
end;

function XTIME(x:longword):longword;
var
aa:longword;
begin
 if  ( x and $80 )<>0 then
      aa:=$1B
      else
      aa:=$00;
 result:=  ( x shl 1 ) xor ( aa )    ;
end;

function  MUL(x,y:longword;pow,log: array of integer):longword;
begin
  if  (x<>0) and (y<>0) then
      result:=pow[(log[x]+log[y]) mod 255]
      else
      result:=0;
end;


procedure aes_gen_tables(  );
var
	i, x, y, z:integer;
	pow:array[0..255] of integer;
	log:array[0..255] of integer;
begin
	//	 * compute pow and log tables over GF(2^8)	 */
  x:=1;
	for i := 0 to 255 do
	begin
		pow[i] := x;
		log[x] := i;
		x := ( x xor XTIME( x ) ) and $FF;
	end;

	(*
	 * calculate the round constants
	 *)
  x:=1;
	for i := 0 to 9 do
	begin
		RCON[i] :=  x;
		x := XTIME( x ) and $FF;
	end;

	(*
	 * generate the forward and reverse S-boxes
	 *)
	FSb[$00] := $63;
	RSb[$63] := $00;

	for i := 1 to 255 do
	begin
		x := pow[255 - log[i]];

		y := x;
    y := ( (y shl 1) or (y shr 7) ) and $FF;
		x :=x xor y;
    y := ( (y shl 1) or (y shr 7) ) and $FF;
		x :=x xor y;
    y := ( (y shl 1) or (y shr 7) ) and $FF;
		x :=x xor y;
    y := ( (y shl 1) or (y shr 7) ) and $FF;
		x :=x xor y xor $63;

		FSb[i] :=  x;
		RSb[x]:=  i;
	end;

(*
	 * generate the forward and reverse tables
	 *)
	for i := 0 to 255 do
	begin
		x := FSb[i];
		y := XTIME( x ) and $FF;
		z := ( y xor x ) and $FF;

		FT0[i] := (  y ) xor (  x shl	8 ) xor (  x shl 16 ) xor 	( z shl 24 );

		FT1[i] := ROTL8( FT0[i] );
		FT2[i] := ROTL8( FT1[i] );
		FT3[i] := ROTL8( FT2[i] );

		x := RSb[i];

		RT0[i] := ( MUL( $0E, x,pow,log ) ) xor (  MUL( $09, x ,pow,log) shl 8 ) xor 	(  MUL( $0D, x,pow,log ) shl 16 ) xor 		(  MUL( $0B, x,pow,log ) shl 24 );

		RT1[i] := ROTL8( RT0[i] );
		RT2[i] := ROTL8( RT1[i] );
		RT3[i] := ROTL8( RT2[i] );
	end;
end;

procedure aes_setkey_enc( ctx:pfz_aes_s; const key:pbyte; keysize:integer );
var
	i:integer;
	RK:plongword;
begin
	if( aes_init_done = 0 ) then
	begin
		aes_gen_tables();
		aes_init_done := 1;
	end;


	case keysize of
   128: ctx^.nr := 10;
	 192: ctx^.nr := 12;
	 256: ctx^.nr := 14;
	 else  exit;
	end;
  RK := @ctx^.buf;
  ctx^.rk := RK;


	for  i := 0 to ((keysize shr 5)-1) do
	begin
		GET_ULONG_LE( longword_items(RK)[i], key, i shl 2 );
	end;

	case ctx^.nr of
	10:
    begin
		for i := 0 to 9 do
		begin
			longword_items(RK)[4] := longword_items(RK)[0] xor RCON[i] xor
				( FSb[ ( longword_items(RK)[3] shr 8 ) and $FF ] ) xor
				( FSb[ ( longword_items(RK)[3] shr 16 ) and $FF ] shl 8 ) xor
				( FSb[ ( longword_items(RK)[3] shr 24 ) and $FF ] shl 16 )  xor
				( FSb[ ( longword_items(RK)[3] ) and $FF ] shl 24 );

			longword_items(RK)[5] := longword_items(RK)[1] xor longword_items(RK)[4];
			longword_items(RK)[6] := longword_items(RK)[2] xor longword_items(RK)[5];
			longword_items(RK)[7] := longword_items(RK)[3] xor longword_items(RK)[6];
      inc(rk,4);
		end;
	 end;

	12:
    begin
		for i := 0 to 7 do
		begin
			longword_items(RK)[6] := longword_items(RK)[0] xor RCON[i] xor
				( FSb[ ( longword_items(RK)[5] shr 8 ) and $FF ] ) xor
				( FSb[ ( longword_items(RK)[5] shr 16 ) and $FF ] shl 8 ) xor
				( FSb[ ( longword_items(RK)[5] shr 24 ) and $FF ] shl 16 ) xor
				( FSb[ ( longword_items(RK)[5] ) and $FF ] shl 24 );

			longword_items(RK)[7] := longword_items(RK)[1] xor longword_items(RK)[6];
			longword_items(RK)[8] := longword_items(RK)[2] xor longword_items(RK)[7];
			longword_items(RK)[9] := longword_items(RK)[3] xor longword_items(RK)[8];
			longword_items(RK)[10] := longword_items(RK)[4] xor longword_items(RK)[9];
			longword_items(RK)[11] := longword_items(RK)[5] xor longword_items(RK)[10];
      inc(rk,6);
		end;
		end;

	14:
    begin
		for i := 0 to 6 do
		begin
			longword_items(RK)[8] := longword_items(RK)[0] xor RCON[i] xor
				( FSb[ ( longword_items(RK)[7] shr 8 ) and $FF ] ) xor
				( FSb[ ( longword_items(RK)[7] shr 16 ) and $FF ] shl 8 ) xor
				( FSb[ ( longword_items(RK)[7] shr 24 ) and $FF ] shl 16 ) xor
				( FSb[ ( longword_items(RK)[7] ) and $FF ] shl 24 );

			longword_items(RK)[9] := longword_items(RK)[1] xor longword_items(RK)[8];
			longword_items(RK)[10] := longword_items(RK)[2] xor longword_items(RK)[9];
			longword_items(RK)[11] := longword_items(RK)[3] xor longword_items(RK)[10];

			longword_items(RK)[12] := longword_items(RK)[4] xor
				( FSb[ ( longword_items(RK)[11] ) and $FF ] ) xor
				( FSb[ ( longword_items(RK)[11] shr 8 ) and $FF ] shl 8 ) xor
				( FSb[ ( longword_items(RK)[11] shr 16 ) and $FF ] shl 16 ) xor
				( FSb[ ( longword_items(RK)[11] shr 24 ) and $FF ] shl 24 );

			longword_items(RK)[13] := longword_items(RK)[5] xor longword_items(RK)[12];
			longword_items(RK)[14] := longword_items(RK)[6] xor longword_items(RK)[13];
			longword_items(RK)[15]:= longword_items(RK)[7] xor longword_items(RK)[14];
      inc(rk,8);

		end;
    end;
	  else
     exit;
    end;
end;

procedure aes_setkey_dec( ctx:pfz_aes_s; const key:pbyte; keysize:integer );
var
	i, j:integer;
	cty:fz_aes_s;
	RK:plongword;
	SK:plongword;
begin
case keysize of
   128: ctx^.nr := 10;
	 192: ctx^.nr := 12;
	 256: ctx^.nr := 14;
	 else  exit;
	end;
  RK := @ctx^.buf;
  ctx^.rk := RK;


	aes_setkey_enc( @cty, key, keysize );
	SK := cty.rk;
  inc(sk, + cty.nr * 4);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  INC(SK,-8);
	for i := ctx^.nr - 1 downto 1 do
	begin
		for j := 0 to 3 do
		begin
			  RK^ := RT0[ FSb[ ( SK^ ) and $FF ] ] xor
				RT1[ FSb[ ( SK^ shr 8 ) and $FF ] ] xor
				RT2[ FSb[ ( SK^ shr 16 ) and $FF ] ] xor
				RT3[ FSb[ ( SK^ shr 24 ) and $FF ] ];
        inc(RK);
        inc(SK);
		end;
    inc(SK, - 8);
	end;

	RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);
  RK^:=SK^;
  inc(RK);
  INC(SK);

	fillchar( cty, sizeof( fz_aes_s ), 0 );
end;
type pplongword=^plongword;
procedure AES_FROUND(var X0:longword; var X1:longword; var X2:longword; var X3:longword;Y0,Y1,Y2,Y3:longword;RK1:pplongword);
var
  RK:plongword;
begin
  RK:=RK1^;
  X0 := RK^ xor FT0[ ( Y0 ) and $FF ] xor 	FT1[ ( Y1 shr 8 ) and $FF ] xor	FT2[ ( Y2 shr 16 ) and $FF ] xor	FT3[ ( Y3 shr 24 ) and $FF ];
  inc(RK);
  X1 := RK^ xor FT0[ ( Y1 ) and $FF ] xor	FT1[ ( Y2 shr 8 ) and $FF ] xor	FT2[ ( Y3 shr 16 ) and $FF ] xor	FT3[ ( Y0 shr 24 ) and $FF ];
  inc(RK);
  X2 := RK^ xor FT0[ ( Y2 ) and $FF ] xor	FT1[ ( Y3 shr 8 ) and $FF ] xor	FT2[ ( Y0 shr 16 ) and $FF ] xor	FT3[ ( Y1 shr 24 ) and $FF ];
  inc(RK);
  X3 := RK^ xor FT0[ ( Y3 ) and $FF ] xor	FT1[ ( Y0 shr 8 ) and $FF ] xor	FT2[ ( Y1 shr 16 ) and $FF ] xor	FT3[ ( Y2 shr 24 ) and $FF ];
  inc(RK);
end;

procedure AES_RROUND(var X0:longword; var X1:longword; var X2:longword; var X3:longword;Y0,Y1,Y2,Y3:longword;RK1:pplongword);
var
  RK:plongword;
begin
  RK:=RK1^;

	X0 := RK^ xor RT0[ ( Y0 ) and $FF ] xor		RT1[ ( Y3 shr 8 ) and $FF ] xor		RT2[ ( Y2 shr 16 ) and $FF ] xor			RT3[ ( Y1 shr 24 ) and $FF ];
	inc(RK);
	X1 := RK^ xor RT0[ ( Y1 ) and $FF ] xor	  RT1[ ( Y0 shr 8 ) and $FF ] xor		RT2[ ( Y3 shr 16 ) and $FF ] xor			RT3[ ( Y2 shr 24 ) and $FF ];
	inc(RK);
	X2 := RK^ xor RT0[ ( Y2 ) and $FF ] xor		RT1[ ( Y1 shr 8 ) and $FF ] xor		RT2[ ( Y0 shr 16 ) and $FF ] xor			RT3[ ( Y3 shr 24 ) and $FF ];
	inc(RK);					
	X3 := RK^ xor RT0[ ( Y3 ) and $FF ] xor		RT1[ ( Y2 shr 8 ) and $FF ] xor		RT2[ ( Y1 shr 16 ) and $FF ] xor			RT3[ ( Y0 shr 24 ) and $FF ];
  inc(RK);
  RK1^:=rk;
end;


procedure aes_crypt_ecb( ctx:pfz_aes_s; mode:integer; const input:pbyte;	output:pbyte);
var
	i:integer;
	 X0, X1, X2, X3, Y0, Y1, Y2, Y3:longword;
  RK:plongword;
begin

	RK := ctx^.rk;

	GET_ULONG_LE( X0, input, 0 );
  X0 :=X0 xor RK^;
  inc(RK);
	GET_ULONG_LE( X1, input, 4 );
  X1 :=X1 XOR RK^;
  inc(RK);
	GET_ULONG_LE( X2, input, 8 );
  X2 :=X2 XOR RK^;
  inc(RK);

	GET_ULONG_LE( X3, input, 12 );
  X3 :=X3 XOR RK^;
  inc(RK);

	if( mode = AES_DECRYPT ) THEN
	BEGIN
		for i := (ctx^.nr shr 1) - 1 downto 1 do
		begin

  	 	AES_RROUND( Y0, Y1, Y2, Y3, X0, X1, X2, X3 ,@rk);
		  AES_RROUND( X0, X1, X2, X3, Y0, Y1, Y2, Y3,@rk );
		end;

		AES_RROUND( Y0, Y1, Y2, Y3, X0, X1, X2, X3,@rk );

		X0 := RK^ xor ( RSb[ ( Y0 ) and $FF ] ) xor  ( RSb[ ( Y3 shr 8 ) and $FF ] shl 8 ) xor ( RSb[ ( Y2 shr 16 ) and $FF ] shl 16 ) xor 	( RSb[ ( Y1 shr 24 ) and $FF ] shl 24 );
    inc(RK);
		X1 := RK^ xor ( RSb[ ( Y1 ) and $FF ] ) xor  ( RSb[ ( Y0 shr 8 ) and $FF ] shl 8 ) xor  ( RSb[ ( Y3 shr 16 ) and $FF ] shl 16 ) xor 	( RSb[ ( Y2 shr 24 ) and $FF ] shl 24 );
    inc(RK);
		X2 := RK^ xor ( RSb[ ( Y2 ) and $FF ] ) xor  ( RSb[ ( Y1 shr 8 ) and $FF ] shl 8 ) xor ( RSb[ ( Y0 shr 16 ) and $FF ] shl 16 ) xor 	( RSb[ ( Y3 shr 24 ) and $FF ] shl 24 );
    inc(RK);
		X3 := RK^ xor ( RSb[ ( Y3 ) and $FF ] ) xor  ( RSb[ ( Y2 shr 8 ) and $FF ] shl 8 ) xor	( RSb[ ( Y1 shr 16 ) and $FF ] shl 16 ) xor 	( RSb[ ( Y0 shr 24 ) and $FF ] shl 24 );
    inc(RK);
  END
	else //* AES_ENCRYPT */
	BEGIN
		for i := (ctx^.nr shr 1) - 1 downto 1 do
		begin
			AES_FROUND( Y0, Y1, Y2, Y3, X0, X1, X2, X3,@RK );
			AES_FROUND( X0, X1, X2, X3, Y0, Y1, Y2, Y3,@RK  );
		end;

		AES_FROUND( Y0, Y1, Y2, Y3, X0, X1, X2, X3,@RK  );

		X0 := RK^ xor ( FSb[ ( Y0 ) and $FF ] ) xor  	( FSb[ ( Y1 shr 8 ) and $FF ] shl 8 ) xor 	( FSb[ ( Y2 shr 16 ) and $FF ] shl 16 ) xor 	( FSb[ ( Y3 shr 24 ) and $FF ] shl 24 );
    inc(RK);
		X1 := RK^ xor ( FSb[ ( Y1 ) and $FF ] ) xor  	( FSb[ ( Y2 shr 8 ) and $FF ] shl 8 ) xor 	( FSb[ ( Y3 shr 16 ) and $FF ] shl 16 ) xor 	( FSb[ ( Y0 shr 24 ) and $FF ] shl 24 );
    inc(RK);
		X2 := RK^ xor ( FSb[ ( Y2 ) and $FF ] ) xor   ( FSb[ ( Y3 shr 8 ) and $FF ] shl 8 ) xor 	( FSb[ ( Y0 shr 16 ) and $FF ] shl 16 ) xor 	( FSb[ ( Y1 shr 24 ) and $FF ] shl 24 );
    inc(RK);
    X3 := RK^ xor ( FSb[ ( Y3 ) and $FF ] ) xor  	( FSb[ ( Y0 shr 8 ) and $FF ] shl 8 ) xor 	( FSb[ ( Y1 shr 16 ) and $FF ] shl 16 ) xor 	( FSb[ ( Y2 shr 24 ) and $FF ] shl 24 );
    inc(RK);
	END;

	PUT_ULONG_LE( X0, output, 0 );
	PUT_ULONG_LE( X1, output, 4 );
	PUT_ULONG_LE( X2, output, 8 );
	PUT_ULONG_LE( X3, output, 12 );
end;


PROCEDURE aes_crypt_cbc( ctx:pfz_aes_s; mode:integer; length:integer; var iv:array of byte;input:pbyte;	output:pbyte);
var
	i:integer;
	temp:array[0..15] of byte;
begin


	if( mode = AES_DECRYPT ) then
	begin
		while( length > 0 ) do
		begin
			copymemory( @temp, input, 16 );
			aes_crypt_ecb( ctx, mode, input, output );

			for i := 0 to 15 do
				byte_items(output)[i] := ( byte_items(output)[i] xor iv[i] );

				copymemory( @iv, @temp, 16 );

			inc(input, 16);
			inc(output,16);
			length :=length- 16;
		end;
	end
	else
	begin
		while( length > 0 )   do
		begin
			for i := 0 to 15 do
				byte_items(output)[i] := ( byte_items(input)[i] xor iv[i] );

			aes_crypt_ecb( ctx, mode, output, output );
			copymemory( @iv, output, 16 );

			inc(input, 16);
			inc(output,16);
			length :=length- 16;
		end;
	end;
end;











end.



