unit draw_unpackss;

interface
 uses SysUtils,Math,digtypes ;

  
var
get1_tab_1:array[0..255,0..7] of byte;
get1_tab_1p:array[0..255,0..15] of byte;
get1_tab_255:array[0..255,0..7] of byte;
get1_tab_255p:array[0..255,0..15] of byte;

procedure
fz_unpack_tile(dst:pfz_pixmap_s; src:pbyte; n, depth, stride, scale:integer);
procedure fz_decode_indexed_tile(pix:pfz_pixmap_s; decode:psingle; maxval:integer);
procedure fz_decode_tile(pix:pfz_pixmap_s; decode:psingle);

implementation
 uses base_object_functions;
function get1(buf:pbyte;x:integer):integer;
begin
 result:=((byte_items(buf)[x shr 3] shr ( 7 - (x and 7) ) ) and 1 );
end;
function get2(buf:pbyte;x:integer):integer;
begin
   result:=((byte_items(buf)[x shr 2] shr ( ( 3 - (x and 3) ) shl 1 ) ) and 3 );
end;


function get4(buf:pbyte;x:integer):integer;
begin
   result:=((byte_items(buf)[x shr 1] shr ( ( 1 - (x and 1) ) shl 2 ) ) and 15 ) ;
end;

function get8(buf:pbyte;x:integer):integer;
begin
   result:=(byte_items(buf)[x]);
end;

function get16(buf:pbyte;x:integer):integer;
begin
   result:=(byte_items(buf)[x shl 1]);
end;

procedure init_get1_tables();
const
{$J+}
   once:integer = 0;
{$J-}
var
 i,k,x:integer;
  bits:array[0..0] of byte;

begin
	//* TODO: mutex lock here */

	if (once<>0) then
		exit;

	for i := 0 to 256-1 do
	begin
		bits[0] := i;
		for k := 0 to 8-1 do
		begin
			x := get1(@bits, k);
			get1_tab_1[i][k] := x;
			get1_tab_1p[i][k * 2] := x;
			get1_tab_1p[i][k * 2 + 1] := 255;
			get1_tab_255[i][k] := x * 255;
			get1_tab_255p[i][k * 2] := x * 255;
			get1_tab_255p[i][k * 2 + 1] := 255;
		end;
	end;

	once := 1;
end;

procedure
fz_unpack_tile(dst:pfz_pixmap_s; src:pbyte; n, depth, stride, scale:integer);
var
	 pad, x, y, k:integer;
	 w,w3:integer;
   sp,dp:pbyte;
   len,b:integer;
begin
  w := dst^.w;
	pad := 0;
	if (dst^.n > n) then
		pad := 255;

	if (depth = 1) then
		init_get1_tables();

	if (scale = 0) then
	begin
		case depth of
		1: scale := 255;
		2: scale := 85;
		4: scale := 17;
		end;
	end;

	for y := 0 to dst^.h-1 do
	begin
		sp := pointer(cardinal(src) + y * stride);
		dp := pointer(cardinal(dst^.samples) + y * (dst^.w * dst^.n));

		//* Specialized loops */

		if ((n = 1) and (depth = 1) and (scale = 1) and (pad=0) ) then
		begin
			w3 := w shr 3;
			for x := 0 to w3-1 do
			begin
				copymemory(dp, @get1_tab_1[sp^], 8);
        inc(sp);
				inc(dp, 8);
			end;
			x := x shl 3;
			if (x < w)  then
				copymemory(dp, @get1_tab_1[sp^], w - x);
		end

		else if ((n = 1) and (depth = 1) and (scale = 255) and (pad=0)) then
		begin
			w3 := w shr 3;
			for x := 0 to w3-1 do
			begin
				copymemory(dp, @get1_tab_255[sp^], 8);
        inc(sp);
				inc(dp,8);
			end;
			x := x shl 3;
			if (x < w) then
				copymemory(dp, @get1_tab_255[sp^], w - x);
		end

		else if ((n = 1) and (depth = 1) and (scale = 1) and ( pad<>0)) then
		begin
		  w3 := w shr 3;
			for x := 0 to w3-1 do
			begin
				copymemory(dp, @get1_tab_1p[sp^], 16);
        inc(sp);
				inc(dp, 16);
			end;
			x := x shl 3;
			if (x < w) then
				copymemory(dp, @get1_tab_1p[sp^], (w - x) shl 1);
		end

		else if ((n = 1) and (depth = 1) and  (scale = 255) and   (pad<>0)) then
		begin
			w3 := w shr 3;
			for x := 0 to w3-1 do
			begin
				copymemory(dp, @get1_tab_255p[sp^], 16);
        inc(sp);
				inc(dp, 16);
			end;
			x := x shl 3;
			if (x < w)  then
				copymemory(dp, @get1_tab_255p[sp^], (w - x) shl 1);
		end

		else if (depth = 8) and (pad=0) then
		begin
			len := w * n;
			while (len<>0) do
      begin
        len:=len-1;
        dp^:=sp^;
           if dp^<>0 then
           dddd;
        inc(dp);
        inc(sp);

      end;
		end

		else if (depth = 8) and  (pad<>0) then
		begin
			for x := 0 to w-1 do
			begin
				for k := 0 to n-1 do
        begin
           dp^:=sp^;

           inc(sp);
           inc(dp);
        end;
        dp^:=255;
				inc(dp);
			end;
		end

		else
		begin
			b := 0;
			for x := 0 to w-1 do
			begin
				for k := 0 to n-1 do
				begin
					case (depth) of
					1:
          begin
            dp^:= get1(sp, b) * scale;
            inc(dp);
          end;
					2:
          begin
            dp^ := get2(sp, b) * scale;
            inc(dp);
          end;
					4:
           begin
             dp^ := get4(sp, b) * scale;
             inc(dp);
           end;
					8:
           begin
             dp^ := get8(sp, b);
             inc(dp);
           end;
					16:
           begin
              dp^ := get16(sp, b);
              inc(dp);
           end;
					end;
					b:=b+1;
				end;
				if (pad<>0) then
        begin

          dp^:=255;
          inc(dp);
        end;
			end;
		end;
	end;
end;

//* Apply decode array */

procedure fz_decode_indexed_tile(pix:pfz_pixmap_s; decode:psingle; maxval:integer);
var
	add:array[0..FZ_MAX_COLORS-1] of integer;
	mul:array[0..FZ_MAX_COLORS-1] of integer;
	p:pbyte;
	len, n ,needed,k:integer;
  min1,max1,mm:integer;
begin
  p := pix^.samples;
  len := pix^.w * pix^.h;
  n := pix^.n - 1;
	needed := 0;
	for k := 0 to n-1 do
	begin
		min1 := trunc(single_items(decode)[k * 2] * 256);
		max1 := trunc(single_items(decode)[k * 2 + 1] * 256);
		add[k] := min1;
		mul[k] := (max1 - min1) div maxval;
    if (min1 <> 0) or (max1 <> maxval * 256) then
    mm:=1
    else
    mm:=0;
		needed:=needed or mm ;
	end;

	if (needed=0) then
		exit;

	while (len<>0) do
	begin
  len:=len-1;
		for k := 0 to n-1 do
			byte_items(p)[k] := (add[k] + (((byte_items(p)[k] shl 8) * mul[k]) shr 8)) shr 8;
		inc(p, n + 1);
	end;
end;

procedure fz_decode_tile(pix:pfz_pixmap_s; decode:psingle);
var
	add:array[0..FZ_MAX_COLORS-1] of integer;
	mul:array[0..FZ_MAX_COLORS-1] of integer;
	p:pbyte;
	 len,n, needed, k:integer;
   min1,max1,mm:integer;
begin

  p := pix^.samples;
  len := pix^.w * pix^.h;
  n := MAX(1, pix^.n - 1);
	needed := 0;
	for k := 0 to n-1 do
	begin
		min1 := trunc(single_items(decode)[k * 2] * 255);
		max1 := trunc(single_items(decode)[k * 2 + 1] * 255);
		add[k] := min1;
		mul[k] := max1 - min1;
     if (min1 <> 0) or (max1 <> 255) then
     mm:=1
     else
     mm:=0;
		needed :=needed or mm;
	end;

	if (needed=0) then
		exit;

	while (len<>0) do
	begin
    len:=len-1;
		for k := 0 to n-1 do
			byte_items(p)[k] := add[k] + fz_mul255(byte_items(p)[k], mul[k]);
		inc(p, pix^.n);
  end;
end;



end.
