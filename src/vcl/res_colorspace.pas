unit res_colorspace;

interface
uses  Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,Math,digtypes,base_object_functions,FZ_mystreams,fz_pixmapss,base_error;

const
FZ_MAX_COLORS=32;

function get_fz_device_gray(): Pfz_colorspace_s;
function fz_keep_colorspace(cs:pfz_colorspace_s):pfz_colorspace_s;
procedure fz_drop_colorspace(cs:pfz_colorspace_s);
procedure fz_convert_color(ss:pfz_colorspace_s; sv:psingle; ds:pfz_colorspace_s; dv:psingle);
procedure fz_convert_pixmap(sp:pfz_pixmap_s; dp:pfz_pixmap_s);
function get_fz_device_rgb(): Pfz_colorspace_s;
function get_fz_device_bgr(): Pfz_colorspace_s;
function get_fz_device_cmyk(): Pfz_colorspace_s;
function fz_new_colorspace(name:pchar;n:integer):pfz_colorspace_s;

implementation


function fz_new_colorspace(name:pchar;n:integer):pfz_colorspace_s;
var
cs:pfz_colorspace_s;
begin
	 cs := fz_malloc(sizeof(fz_colorspace_s));
	cs^.refs := 1;
	fz_strlcpy(@cs^.name, name, sizeof(cs^.name));
	cs^.n := n;
	cs^.to_rgb := nil;
	cs^.from_rgb := nil;
	cs^.free_data := nil;
	cs^.data := nil;
	result:=cs;
end;

function fz_keep_colorspace(cs:pfz_colorspace_s):pfz_colorspace_s;
begin
	if (cs^.refs < 0) then
  begin
		result:= cs;
    exit;
  end;
	cs^.refs:=cs^.refs+1;
	result:= cs;
end;

procedure fz_drop_colorspace(cs:pfz_colorspace_s);
begin
  if cs=nil then
  exit;
	if (cs<>nil) and (cs^.refs < 0) then
  exit;
  cs^.refs:=cs^.refs-1;
	if (cs<>nil) and (cs^.refs=0) then
	begin
		if (@cs^.free_data<>nil) and (cs^.data<>nil) then
			cs^.free_data(cs);
		fz_free(cs);
	end;
end;

//* Device colorspace definitions */

procedure gray_to_rgb(cs:pfz_colorspace_s;gray:psingle; rgb:psingle);
begin
	single_items(rgb)[0] := single_items(gray)[0];
	single_items(rgb)[1] := single_items(gray)[0];
	single_items(rgb)[2] := single_items(gray)[0];
end;

procedure rgb_to_gray(cs:pfz_colorspace_s; rgb:psingle; gray:psingle);
var
r,g,b:single;
begin
	 r := single_items(rgb)[0];
	 g := single_items(rgb)[1];
	 b := single_items(rgb)[2];
	single_items(gray)[0] := r * 0.3 + g * 0.59 + b * 0.11;
end;

procedure rgb_to_rgb(cs:pfz_colorspace_s; rgb:psingle; xyz:psingle) ;
begin
	single_items(xyz)[0] := single_items(rgb)[0];
	single_items(xyz)[1] := single_items(rgb)[1];
  single_items(xyz)[2] := single_items(rgb)[2];
end;

procedure bgr_to_rgb(cs:pfz_colorspace_s; bgr:psingle; rgb:psingle) ;
begin
	single_items(rgb)[0] := single_items(bgr)[2];
	single_items(rgb)[1] := single_items(bgr)[1];
	single_items(rgb)[2] := single_items(bgr)[0];
end;

procedure rgb_to_bgr(cs:pfz_colorspace_s; rgb:psingle; bgr:psingle);
begin
	single_items(bgr)[0] := single_items(rgb)[2];
	single_items(bgr)[1] := single_items(rgb)[1];
	single_items(bgr)[2] := single_items(rgb)[0];
end;

procedure cmyk_to_rgb(cs:pfz_colorspace_s; cmyk:psingle; rgb:psingle);
var
  c,m,y,k:single;
  c1,m1,y1,k1:single;

	 r, g, b, x:single;
begin
  c := single_items(cmyk)[0];
  m := single_items(cmyk)[1];
  y := single_items(cmyk)[2];
  k := single_items(cmyk)[3];
  c1 := 1 - c;
  m1 := 1 - m;
  y1 := 1 - y;
  k1 := 1 - k;

	//* this is a matrix multiplication, unrolled for performance */
	x := c1 * m1 * y1 * k1;	//* 0 0 0 0 */
  b:=x;
  g:=b;
  r:=g;
	
	x := c1 * m1 * y1 * k;	//* 0 0 0 1 */
	r :=r+ 0.1373 * x;
	g :=g+ 0.1216 * x;
	b :=b+ 0.1255 * x;
	x := c1 * m1 * y * k1;	//* 0 0 1 0 */
	r :=r+ x;
	g :=g+ 0.9490 * x;
	x := c1 * m1 * y * k;	//* 0 0 1 1 */
	r :=r+ 0.1098 * x;
	g :=g+ 0.1020 * x;
	x := c1 * m * y1 * k1;	//* 0 1 0 0 */
	r :=r+ 0.9255 * x;
	b :=b+ 0.5490 * x;
	x := c1 * m * y1 * k;	//* 0 1 0 1 */
	r :=r+ 0.1412 * x;
	x := c1 * m * y * k1;	//* 0 1 1 0 */
	r :=r+ 0.9294 * x;
	g :=g+ 0.1098 * x;
	b :=b+ 0.1412 * x;
	x := c1 * m * y * k;	//* 0 1 1 1 */
	r :=r+ 0.1333 * x;
	x :=x+ c * m1 * y1 * k1;	//* 1 0 0 0 */
	g :=g+ 0.6784 * x;
	b :=b+ 0.9373 * x;
	x := c * m1 * y1 * k;	//* 1 0 0 1 */
	g :=g+ 0.0588 * x;
	b :=b+ 0.1412 * x;
	x := c * m1 * y * k1;	//* 1 0 1 0 */
	g :=g+ 0.6510 * x;
	b :=b+ 0.3137 * x;
	x := c * m1 * y * k;	//* 1 0 1 1 */
	g :=g+ 0.0745 * x;
	x := c * m * y1 * k1; //* 1 1 0 0 */
	r :=r+ 0.1804 * x;
	g :=g+ 0.1922 * x;
	b :=b+ 0.5725 * x;
	x := c * m * y1 * k;	//* 1 1 0 1 */
	b :=b+ 0.0078 * x;
	x := c * m * y * k1;	//* 1 1 1 0 */
	r :=r+ 0.2118 * x;
	g :=g+ 0.2119 * x;
	b :=b+ 0.2235 * x;

	single_items(rgb)[0] := CLAMP(r, 0, 1);
	single_items(rgb)[1] := CLAMP(g, 0, 1);
	single_items(rgb)[2] := CLAMP(b, 0, 1);

end;

procedure rgb_to_cmyk(s:pfz_colorspace_s; rgb:psingle; cmyk:psingle);
var
	 c, m, y, k:single;
begin
	c := 1 - single_items(rgb)[0];
	m := 1 - single_items(rgb)[1];
	y := 1 - single_items(rgb)[2];
	k := MIN(c, MIN(m, y));
	single_items(cmyk)[0] := c - k;
	single_items(cmyk)[1] := m - k;
	single_items(cmyk)[2] := y - k;
	single_items(cmyk)[3] := k;
end;

const
    k_device_gray:fz_colorspace_s=(REFS:-1; NAME:'DeviceGray';N: 1;to_rgb:gray_to_rgb;from_rgb:rgb_to_gray ;free_data:NIL;data:NIL);
    fz_device_gray:Pfz_colorspace_s=@k_device_gray;
    k_device_rgb:fz_colorspace_s=(REFS:-1; NAME:'DeviceRGB';N: 3;to_rgb:rgb_to_rgb;from_rgb:rgb_to_rgb ;free_data:NIL;data:NIL);
    fz_device_rgb:Pfz_colorspace_s=@k_device_rgb;

    k_device_bgr:fz_colorspace_s=(REFS:-1; NAME:'DeviceRGB';N: 3;to_rgb:bgr_to_rgb;from_rgb:rgb_to_bgr ;free_data:NIL;data:NIL);
    fz_device_bgr:Pfz_colorspace_s=@k_device_bgr;

    k_device_cmyk:fz_colorspace_s=(REFS:-1; NAME:'DeviceCMYK';N: 4;to_rgb:cmyk_to_rgb;from_rgb:rgb_to_cmyk ;free_data:NIL;data:NIL);
    fz_device_cmyk:Pfz_colorspace_s=@k_device_cmyk;

    //static fz_colorspace k_device_gray = { -1, "DeviceGray", 1, gray_to_rgb, rgb_to_gray };
//static fz_colorspace k_device_rgb = { -1, "DeviceRGB", 3, rgb_to_rgb, rgb_to_rgb };
//static fz_colorspace k_device_bgr = { -1, "DeviceRGB", 3, bgr_to_rgb, rgb_to_bgr };
//static fz_colorspace k_device_cmyk = { -1, "DeviceCMYK", 4, cmyk_to_rgb, rgb_to_cmyk };

//fz_colorspace *fz_device_gray = &k_device_gray;
//fz_colorspace *fz_device_rgb = &k_device_rgb;
//fz_colorspace *fz_device_bgr = &k_device_bgr;
//fz_colorspace *fz_device_cmyk = &k_device_cmyk;
function get_fz_device_gray(): Pfz_colorspace_s;
begin
  result:=fz_device_gray;
end;

function get_fz_device_bgr(): Pfz_colorspace_s;
begin
  result:=fz_device_bgr;
end;

function get_fz_device_rgb(): Pfz_colorspace_s;
begin
  result:=fz_device_rgb;
end;

function get_fz_device_cmyk(): Pfz_colorspace_s;
begin
  result:=fz_device_cmyk;
end;


function fz_find_device_colorspace(name:pchar): pfz_colorspace_s;

begin
	if (strcomp(name, 'DeviceGray')=0) then
  begin
    result:=fz_device_gray;
    exit;
  end;
	if (strcomp(name, 'DeviceRGB')=0) then
  begin
   result:=fz_device_rgb;
	 //	return fz_device_rgb;
   exit;
  end;
	if (strcomp(name, 'DeviceRGB')=0) then
  begin

		result:=fz_device_bgr;
	 //	return fz_device_rgb;
   exit;

	//	return fz_device_bgr;
  end;
	if (strcomp(name, 'DeviceCMYK')=0) then
  begin
   	result:=fz_device_cmyk;
	   exit;


	//	return fz_device_cmyk;
  end;
	fz_warn('unknown device colorspace: %s', [name]);

	result:=nil;
end ;

//* Fast pixmap color conversions */

procedure fast_gray_to_rgb(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
	while (n<>0)  do
	begin
		byte_items(d)[0] := byte_items(s)[0];
		byte_items(d)[1] := byte_items(s)[0];
		byte_items(d)[2] := byte_items(s)[0];
		byte_items(d)[3] := byte_items(s)[1];
		inc(s,2);
		inc(d,4);
    n:=n-1;
	end;
end;

procedure fast_gray_to_cmyk(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin
		byte_items(d)[0] := 0;
		byte_items(d)[1] := 0;
		byte_items(d)[2] := 0;
		byte_items(d)[3] := byte_items(s)[0];
		byte_items(d)[4] :=  byte_items(s)[1];
		inc(s,2);
		inc(d,5);
    n:=n-1;
	end;
end;

procedure fast_rgb_to_gray(src:pfz_pixmap_s; dst:pfz_pixmap_s) ;
var
	s:pbyte;
	d:pbyte;
	n:integer;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin

		byte_items(d)[0] := ((byte_items(s)[0]+1) * 77 + (byte_items(s)[1]+1) * 150 + (byte_items(s)[2]+1) * 28) shr 8;
		byte_items(d)[1] :=byte_items(s)[3];
		inc(s,4);
		inc(d,2);
    n:=n-1;
	end;
end;

procedure fast_bgr_to_gray(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin
		byte_items(d)[0] := ((byte_items(s)[0]+1) * 28 + (byte_items(s)[1]+1) * 150 + (byte_items(s)[2]+1) * 77) shr 8;
		byte_items(d)[1] := byte_items(s)[3];
		inc(s,4);
		inc(d,2);
    n:=n-1;
  end;
end;

procedure fast_rgb_to_cmyk(src:pfz_pixmap_s; dst:pfz_pixmap_s) ;
var
	s:pbyte;
	d:pbyte;
	n:integer;
  c,m,y,k:byte;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin
		c := 255 - byte_items(s)[0];
		m := 255 - byte_items(s)[1];
		y := 255 - byte_items(s)[2];
		k := MIN(c, MIN(m, y));
		byte_items(d)[0] := c - k;
		byte_items(d)[1] := m - k;
		byte_items(d)[2] := y - k;
		byte_items(d)[3] := k;
		byte_items(d)[4] := byte_items(s)[3];
		inc(s,4);
		inc(d,5);
    n:=n-1;
	end;
end;

procedure fast_bgr_to_cmyk(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
  c,m,y,k:byte;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin
		c := 255 - byte_items(s)[2];
		m := 255 - byte_items(s)[1];
		y := 255 - byte_items(s)[0];
		k := MIN(c, MIN(m, y));
		byte_items(d)[0] := c - k;
		byte_items(d)[1] := m - k;
		byte_items(d)[2] := y - k;
		byte_items(d)[3] := k;
		byte_items(d)[4] := byte_items(s)[3];
		inc(s,4);
		inc(d,5);
	end;
end;

procedure fast_cmyk_to_gray(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
  c,m,y:byte;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
  while (n<>0)  do
	begin
		c := fz_mul255(byte_items(s)[0], 77);
		m := fz_mul255(byte_items(s)[1], 150);
		y := fz_mul255(byte_items(s)[2], 28);
		byte_items(d)[0] := 255 - MIN(c + m + y + byte_items(s)[3], 255);
		byte_items(d)[1] := byte_items(s)[4];
		inc(s,5);
		inc(d,2);
    n:=n-1;
	end;
end;

procedure fast_cmyk_to_rgb(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
  cmyk :array[0..3] of single;
  rgb:array[0..2] of single;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
	while (n<>0) do
	begin
		cmyk[0] := byte_items(s)[0] / 255.0;
		cmyk[1] := byte_items(s)[1] / 255.0;
		cmyk[2] := byte_items(s)[2] / 255.0;
		cmyk[3] := byte_items(s)[3] / 255.0;
		cmyk_to_rgb(nil, @cmyk, @rgb);
		byte_items(d)[0] := trunc(rgb[0] * 255);
		byte_items(d)[1] := trunc(rgb[1] * 255);
		byte_items(d)[2] := trunc(rgb[2] * 255);
		byte_items(d)[3] := byte_items(s)[4];
		inc(s,5);
		inc(d,4);
    n:=n-1;
	end;
end;

procedure fast_cmyk_to_bgr(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;
  cmyk :array[0..3] of single;
  rgb:array[0..2] of single;
begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
	while (n<>0) do
	begin
		cmyk[0] := byte_items(s)[0] / 255.0;
		cmyk[1] := byte_items(s)[1] / 255.0;
		cmyk[2] := byte_items(s)[2] / 255.0;
		cmyk[3] := byte_items(s)[3] / 255.0;
		cmyk_to_rgb(nil, @cmyk, @rgb);
		byte_items(d)[0] := trunc(rgb[2] * 255);
		byte_items(d)[1] := trunc(rgb[1] * 255);
		byte_items(d)[2] := trunc(rgb[0] * 255);
		byte_items(d)[3] := byte_items(s)[4];
		inc(s,5);
		inc(d,4);
    n:=n-1;
	end;
end;

procedure fast_rgb_to_bgr(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	s:pbyte;
	d:pbyte;
	n:integer;

begin
  s := src^.samples;
  d := dst^.samples;
  n := src^.w * src^.h;
	while (n<>0) do
	begin
		byte_items(d)[0] := byte_items(s)[2];
		byte_items(d)[1] := byte_items(s)[1];
		byte_items(d)[2] := byte_items(s)[0];
		byte_items(d)[3] := byte_items(s)[3];
		inc(s,4);
		inc(d,4);
    n:=n-1;
	end;
end;

procedure fz_std_conv_pixmap(src:pfz_pixmap_s; dst:pfz_pixmap_s);
var
	srcv:array[0..FZ_MAX_COLORS-1] of single;
	dstv:array[0..FZ_MAX_COLORS-1] of single;
	srcn, dstn:integer;
	 y, x, k, i:integer;
   ss,ds: pfz_colorspace_s;
   s,d:pbyte;
   lookup:array[0..FZ_MAX_COLORS * 256-1] of byte ;
    lookup1:pfz_hash_table_s;
		color:pbyte;
begin
	ss := src^.colorspace;
	ds := dst^.colorspace;

	s := src^.samples;
	d := dst^.samples;

	assert((src^.w = dst^.w) and (src^.h = dst^.h));
	assert((src^.n = ss^.n + 1));
	assert(dst^.n = ds^.n + 1);

	srcn := ss^.n;
	dstn := ds^.n;

	//* Special case for Lab colorspace (scaling of components to float) */
	if (strcomp(ss^.name, 'Lab')=0) and (srcn = 3) then
	begin
		for y := 0 to src^.h-1 do
		begin
			for x := 0 to src^.w-1 do
			begin
				srcv[0] := s^ / 255.0 * 100;
        inc(s);
				srcv[1] := s^ - 128;
        inc(s);
				srcv[2] := s^ - 128;
         inc(s);
				fz_convert_color(ss, @srcv, ds, @dstv);

				for k := 0 to dstn-1 do
        begin

          d^:=trunc(dstv[k] * 255);
          inc(d);
        end;
			  d^:=s^;
        inc(d);
        inc(s);
			end;
		end;
	end

	//* Brute-force for small images */
	else if (src^.w * src^.h < 256) then
	begin
		for y := 0 to src^.h-1 do
		begin
			for x := 0 to src^.w-1 do
			begin
				for k := 0 to srcn-1 do
        begin
					srcv[k] := s^ / 255.0;
          inc(s);
        end;
				fz_convert_color(ss, @srcv, ds, @dstv);

				for k := 0 to dstn-1 do
        begin
           d^:= trunc(dstv[k] * 255);
					 inc(d);
        end;
         d^:=s^;
         inc(d);
         inc(s);

			end;
		end;
	end

	//* 1-d lookup table for separation and similar colorspaces */
	else if (srcn = 1) then
	begin
		for i := 0 to 256-1 do
		begin
			srcv[0] := i / 255.0;
			fz_convert_color(ss, @srcv, ds, @dstv);
			for k := 0 to dstn-1 do
				lookup[i * dstn + k] := trunc(dstv[k] * 255);
		end;

		for y := 0 to src^.h-1 do
		begin
			for x := 0 to src^.w-1 do
			begin
				i := s^;
        inc(s);
				for k := 0 to dstn-1 do
        begin
					d^ := lookup[i * dstn + k];
          inc(d);
        end;
        d^:=s^;
        inc(d);
        inc(s);

			end;
		end;
	end

	//* Memoize colors using a hash table for the general case */
	else
	begin
		//fz_hash_table *lookup1;
	 //	unsigned char *color;

		lookup1 := fz_new_hash_table(509, srcn);

		for y := 0 to src^.h-1 do
		begin
			for  x := 0 to src^.w-1 do
			begin
				color := fz_hash_find(lookup1, s);
				if (color<>nil) then
				begin
				 //	copymemory(d, color, dstn);
          move(color^, d^, dstn);
          inc(s,srcn);
					inc(d, dstn);
          d^:=s^;
          inc(d);
          inc(s);
				end
				else
				begin
					for k := 0 to srcn-1 do
          begin
						srcv[k] := s^ / 255.0;
            inc(s);
          end;
					fz_convert_color(ss, @srcv, ds, @dstv);
					for k := 0 to dstn-1 do
          begin
            d^:=trunc(dstv[k] * 255);
						inc(d);
          end;

					fz_hash_insert(lookup1, pointer(cardinal(s) - srcn), pointer(cardinal(d) - dstn));
          d^:=s^;
          inc(d);
          inc(s);

				end;
			end;
		end;

		fz_free_hash(lookup1);
	end;
end;

procedure fz_convert_pixmap(sp:pfz_pixmap_s; dp:pfz_pixmap_s);
var
  ss,ds: pfz_colorspace_s;
begin
	ss:= sp^.colorspace;
	ds := dp^.colorspace;

	assert((ss<>nil) and (ds<>nil));

	if (sp^.mask<>nil) then
		dp^.mask := fz_keep_pixmap(sp^.mask);
	dp^.interpolate := sp^.interpolate;

	if (ss = fz_device_gray) then
	begin
		if (ds = fz_device_rgb) then fast_gray_to_rgb(sp, dp)
		else if (ds = fz_device_bgr) then fast_gray_to_rgb(sp, dp) //* bgr == rgb here */
		else if (ds = fz_device_cmyk) then fast_gray_to_cmyk(sp, dp)
		else fz_std_conv_pixmap(sp, dp);
	end

	else if (ss = fz_device_rgb) then
	begin
		if (ds = fz_device_gray) then fast_rgb_to_gray(sp, dp)
		else if (ds = fz_device_bgr) then fast_rgb_to_bgr(sp, dp)
		else if (ds = fz_device_cmyk) then fast_rgb_to_cmyk(sp, dp)
		else fz_std_conv_pixmap(sp, dp);
	end

	else if (ss = fz_device_bgr) then
	begin
		if (ds = fz_device_gray) then fast_bgr_to_gray(sp, dp)
		else if (ds = fz_device_rgb) then fast_rgb_to_bgr(sp, dp) //* bgr = rgb here */
		else if (ds = fz_device_cmyk) then fast_bgr_to_cmyk(sp, dp)
		else fz_std_conv_pixmap(sp, dp);
	end

	else if (ss = fz_device_cmyk) then
	begin
		if (ds = fz_device_gray) then fast_cmyk_to_gray(sp, dp)
		else if (ds = fz_device_bgr) then fast_cmyk_to_bgr(sp, dp)
		else if (ds = fz_device_rgb) then fast_cmyk_to_rgb(sp, dp)
		else fz_std_conv_pixmap(sp, dp);
	end

	else fz_std_conv_pixmap(sp, dp);
end;

//* Convert a single color */

procedure fz_std_conv_color( srcs:pfz_colorspace_s;srcv:psingle; dsts:pfz_colorspace_s;dstv:psingle);
var
	 rgb:array[0..2] of single;
	  i:integer;
begin
  if (srcs <> dsts) then
  begin
		assert((@srcs^.to_rgb<>nil) and (@dsts^.from_rgb<>nil));
		srcs^.to_rgb(srcs, srcv, @rgb);
		dsts^.from_rgb(dsts, @rgb, dstv);
		for i := 0 to dsts^.n-1 do
			single_items(dstv)[i] := CLAMP(single_items(dstv)[i], 0, 1);
  end
	else
	begin
		for i := 0 to srcs^.n-1 do
			single_items(dstv)[i] := single_items(srcv)[i];
	end;
end;

procedure fz_convert_color(ss:pfz_colorspace_s; sv:psingle; ds:pfz_colorspace_s; dv:psingle);
var
c,m,y,k:single;
rgb:array[0..2] of single;
begin
	if (ss = fz_device_gray) then
	begin
		if ((ds = fz_device_rgb) or (ds = fz_device_bgr)) then
		begin
			single_items(dv)[0] := single_items(sv)[0];
			single_items(dv)[1] := single_items(sv)[0];
			single_items(dv)[2] := single_items(sv)[0];
		end
		else if (ds = fz_device_cmyk) then
		begin
			single_items(dv)[0] := 0;
			single_items(dv)[1] := 0;
			single_items(dv)[2] := 0;
			single_items(dv)[3] := single_items(sv)[0];
		end
		else
			fz_std_conv_color(ss, sv, ds, dv);
	end

	else if (ss = fz_device_rgb) then
	begin
		if (ds = fz_device_gray) then
		begin
			single_items(dv)[0] := single_items(sv)[0] * 0.3 + single_items(sv)[1] * 0.59 + single_items(sv)[2] * 0.11;
		end
		else if (ds = fz_device_bgr) then
		begin
			single_items(dv)[0] := single_items(sv)[2];
			single_items(dv)[1] := single_items(sv)[1];
			single_items(dv)[2] := single_items(sv)[0];
		end
		else if (ds = fz_device_cmyk) then
		begin
			c := 1 - single_items(sv)[0];
			m := 1 - single_items(sv)[1];
			y := 1 - single_items(sv)[2];
			k := MIN(c, MIN(m, y));
			single_items(dv)[0] := c - k;
			single_items(dv)[1] := m - k;
			single_items(dv)[2] := y - k;
			single_items(dv)[3] := k;
		end
		else
			fz_std_conv_color(ss, sv, ds, dv);
	end

	else if (ss = fz_device_bgr) then
	begin
		if (ds = fz_device_gray) then
		begin
			single_items(dv)[0] := single_items(sv)[0] * 0.11 + single_items(sv)[1] * 0.59 + single_items(sv)[2] * 0.3;
		end
		else if (ds = fz_device_bgr) then
		begin
			single_items(dv)[0] := single_items(sv)[2];
			single_items(dv)[1] := single_items(sv)[1];
			single_items(dv)[2] := single_items(sv)[0];
		end
		else if (ds = fz_device_cmyk) then
		begin
			 c := 1 - single_items(sv)[2];
			 m := 1 - single_items(sv)[1];
			 y := 1 - single_items(sv)[0];
			 k := MIN(c, MIN(m, y));
			single_items(dv)[0] := c - k;
			single_items(dv)[1] := m - k;
			single_items(dv)[2] := y - k;
			single_items(dv)[3] := k;
		end
		else
			fz_std_conv_color(ss, sv, ds, dv);
	end

	else if (ss = fz_device_cmyk) then
	begin
		if (ds = fz_device_gray) then
		begin
			c := single_items(sv)[0] * 0.3;
			m := single_items(sv)[1] * 0.59;
			y := single_items(sv)[2] * 0.11;
			single_items(dv)[0] := 1 - MIN(c + m + y + single_items(sv)[3], 1);
		end
		else if (ds = fz_device_rgb) then
		begin

			cmyk_to_rgb(nil, sv, dv);

		end
		else if (ds = fz_device_bgr) then
		begin


			cmyk_to_rgb(NIL, sv, @rgb);
			single_items(dv)[0] := rgb[2];
			single_items(dv)[1] := rgb[1];
			single_items(dv)[2] := rgb[0];

		end
		else
			fz_std_conv_color(ss, sv, ds, dv);
	end

	else
		fz_std_conv_color(ss, sv, ds, dv);
end;


end.
