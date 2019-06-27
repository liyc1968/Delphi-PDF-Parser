unit ohhcrypt_arc4;

interface
uses digtypes,  SysUtils,Math;

procedure fz_arc4_init(arc4:pfz_arc4_s; const key :pbyte; keylen:longword);
procedure fz_arc4_encrypt(arc4:pfz_arc4_s; var dest: array of byte; const src:array of byte; len:integer);

implementation

procedure fz_arc4_init(arc4:pfz_arc4_s; const key :pbyte; keylen:longword);
var
t, u:longword;
keyindex:longword;
stateindex:longword;
state:pbyte;
counter:integer;
begin
  state := @arc4^.state;

	arc4^.x := 0;
	arc4^.y := 0;

	for counter := 0 to 256-1 do
	begin
		byte_items(state)[counter] := counter;
	end;

	keyindex := 0;
	stateindex := 0;

	for counter := 0 to  256-1 do
	begin
		t := byte_items(state)[counter];
		stateindex := (stateindex + byte_items(key)[keyindex] + t) and $ff;
		u := byte_items(state)[stateindex];

		byte_items(state)[stateindex] := t;
		byte_items(state)[counter] := u;
    keyindex:=keyindex+1;
		if (keyindex >= keylen) then
		begin
			keyindex := 0;
		end

	end;
end;

function fz_arc4_next(arc4:pfz_arc4_s):byte;
var
x,y,sx,sy:longword;
state:pbyte;
begin

  state := @arc4^.state;

	x := (arc4^.x + 1) and $ff;
	sx := byte_items(state)[x];
	y := (sx + arc4^.y) and $ff;
	sy := byte_items(state)[y];

	arc4^.x := x;
	arc4^.y := y;

	byte_items(state)[y] := sx;
	byte_items(state)[x] := sy;

	result:=byte_items(state)[(sx + sy) and $ff];
end;


procedure fz_arc4_encrypt(arc4:pfz_arc4_s; var dest: array of byte; const src: array of byte; len:integer);
var
i:integer;
x:byte;
begin
 // if len<=0 then
 // exit;
	for i := 0 to len-1 do
	begin

		x := fz_arc4_next(arc4);
		dest[i] := src[i] xor x;
	end;
end;

end.
