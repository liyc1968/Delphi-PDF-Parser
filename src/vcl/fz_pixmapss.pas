unit fz_pixmapss;

interface
uses
SysUtils,classes,Math,digtypes,zlibh,base_error;

var
fz_memory_limit:INTEGER = 256 shl 20;
fz_memory_used:INTEGER = 0;
function fz_keep_pixmap(pix:pfz_pixmap_s) :pfz_pixmap_s;
function fz_new_pixmap(colorspace:pfz_colorspace_s; w:integer; h:integer):pfz_pixmap_s;
function fz_bound_pixmap(pix:pfz_pixmap_s) :fz_bbox;
function fz_new_pixmap_with_rect(colorspace:pfz_colorspace_s; r: fz_bbox) :pfz_pixmap_s;
procedure fz_clear_pixmap(pix:pfz_pixmap_s);
procedure fz_drop_pixmap(pix:pfz_pixmap_s);
procedure fz_copy_pixmap_rect(dest, src:pfz_pixmap_s; r:fz_bbox);
procedure fz_clear_pixmap_rect_with_color(dest:pfz_pixmap_s; value:integer;r: fz_bbox);
procedure fz_clear_pixmap_with_color(pix:pfz_pixmap_s;value:integer) ;
function fz_alpha_from_gray(gray:pfz_pixmap_s;luminosity:integer):pfz_pixmap_s ;
FUNCTION fz_new_pixmap_with_limit(colorspace:pfz_colorspace_s; w:integer;h:integer):pfz_pixmap_s;
procedure fz_premultiply_pixmap(pix:pfz_pixmap_s);
function fz_write_png(pixmap:pfz_pixmap_s; filename:pchar; savealpha:integer):integer;
function fz_write_pam(pixmap:pfz_pixmap_s; filename:pchar;savealpha:integer):integer;
implementation
uses base_object_functions,res_colorspace;

procedure copymemory(s,c:pointer;lenn:integer);
begin
  move(c^,s^,lenn);
end;

procedure zeromemory(p:pointer;lenn:integer);
begin
 fillchar(p^,lenn,0);
end;

function fz_new_pixmap_with_data(colorspace:pfz_colorspace_s;w:integer;h:integer; samples:pbyte):pfz_pixmap_s;
var
pix:pfz_pixmap_s;
begin
	pix := fz_malloc(sizeof(fz_pixmap_s));
	pix^.refs := 1;
	pix^.x := 0;
	pix^.y := 0;
	pix^.w := w;
	pix^.h := h;
	pix^.mask := nil;
	pix^.interpolate := 1;
	pix^.xres := 96;
	pix^.yres := 96;
	pix^.colorspace := nil;
	pix^.n := 1;

	if (colorspace<>nil) then
	begin
		pix^.colorspace := fz_keep_colorspace(colorspace);
		pix^.n := 1 + colorspace^.n;
	end;

	if (samples<>nil) then
	begin
		pix^.samples := samples;
		pix^.free_samples := 0;
	end
	else
	begin
		fz_memory_used :=fz_memory_used+ pix^.w * pix^.h * pix^.n;
		pix^.samples := fz_calloc(pix^.h, pix^.w * pix^.n);
		pix^.free_samples := 1;
	end;

	result:= pix;
end;

FUNCTION fz_new_pixmap_with_limit(colorspace:pfz_colorspace_s; w:integer;h:integer):pfz_pixmap_s;
var
n,size:integer;
begin
  if  colorspace<>nil then
     n:=colorspace^.n + 1
     else
     n:=1;

	size := w * h * n;
	if (fz_memory_used + size > fz_memory_limit)  then
	begin
		fz_warn('pixmap memory exceeds soft limit %dM + %dM > %dM'); //, [ 	fz_memory_used:=fz_memory_used/(1<<20);      size:= size/(1<<20);       fz_memory_limit:= fz_memory_limit/(1<<20);
		result:=nil;
    exit;
	end;
	result:=fz_new_pixmap_with_data(colorspace, w, h,nil);
end;

function fz_new_pixmap(colorspace:pfz_colorspace_s; w:integer; h:integer):pfz_pixmap_s;
begin
	result:=fz_new_pixmap_with_data(colorspace, w, h, nil);
end;

function fz_new_pixmap_with_rect(colorspace:pfz_colorspace_s; r: fz_bbox) :pfz_pixmap_s;
var
	pixmap:pfz_pixmap_s;
  begin
	pixmap := fz_new_pixmap(colorspace, r.x1 - r.x0, r.y1 - r.y0);
	pixmap^.x := r.x0;
	pixmap^.y := r.y0;
	result:= pixmap;
end;

function fz_new_pixmap_with_rect_and_data(colorspace:pfz_colorspace_s;  r:fz_bbox; samples:pbyte):pfz_pixmap_s;
var
pixmap: pfz_pixmap_s;
begin
	pixmap := fz_new_pixmap_with_data(colorspace, r.x1 - r.x0, r.y1 - r.y0, samples);
	pixmap^.x := r.x0;
	pixmap^.y := r.y0;
	result:=pixmap;
end;

function fz_keep_pixmap(pix:pfz_pixmap_s) :pfz_pixmap_s;
begin
	pix^.refs:=pix^.refs+1;
	result:= pix;
end;

procedure fz_drop_pixmap(pix:pfz_pixmap_s);
begin
  	if (pix=nil) then
    exit;
  pix^.refs:=pix^.refs-1;
	if (pix<>nil) and (pix^.refs = 0) then
	begin
		fz_memory_used:=fz_memory_used- pix^.w * pix^.h * pix^.n;
		if (pix^.mask<>nil) then
			fz_drop_pixmap(pix^.mask);
		if (pix^.colorspace<>nil) then
			fz_drop_colorspace(pix^.colorspace);
		if (@pix^.free_samples<>nil) then
			fz_free(pix^.samples);
		fz_free(pix);
	end;
end;


function fz_bound_pixmap(pix:pfz_pixmap_s) :fz_bbox;
var
 bbox:	fz_bbox;
begin
	bbox.x0 := pix^.x;
	bbox.y0 := pix^.y;
	bbox.x1 := pix^.x + pix^.w;
	bbox.y1 := pix^.y + pix^.h;
	result:= bbox;
end;

procedure fz_clear_pixmap(pix:pfz_pixmap_s);
begin
	fillchar(pix^.samples^, pix^.w * pix^.h * pix^.n, 0);
end;

procedure fz_clear_pixmap_with_color(pix:pfz_pixmap_s;value:integer) ;
var
  k, x, y:integer;
  s:pbyte;
begin
	if (value = 255) then
		fillchar(pix^.samples^, pix^.w * pix^.h * pix^.n, 255)
	else
	begin

		s := pix^.samples;
		for y := 0 to pix^.h-1-1 do
		begin
			for x := 0 to pix^.w-1-1 do
			begin
				for k := 0 to pix^.n - 1-1  do
        begin
					s^ := value;
          inc(s);
        end;
        s^:=255;
        inc(s);
			end;
		end;
	end;
end;

procedure fz_copy_pixmap_rect(dest, src:pfz_pixmap_s; r:fz_bbox);
var
	srcp:PBYTE;
	destp:pbyte;
	y, w, destspan, srcspan:integer;
begin
	r := fz_intersect_bbox(r, fz_bound_pixmap(dest));
	r := fz_intersect_bbox(r, fz_bound_pixmap(src));
	w := r.x1 - r.x0;
	y := r.y1 - r.y0;
	if (w <= 0) or (y <= 0) then
  exit;


	w:=w * src^.n;
	srcspan := src^.w * src^.n;
	srcp := pointer(cardinal(src^.samples) + srcspan * (r.y0 - src^.y) + src^.n * (r.x0 - src^.x));
	destspan := dest^.w * dest^.n;
	destp :=pointer(cardinal( dest^.samples) + destspan * (r.y0 - dest^.y) + dest^.n * (r.x0 - dest^.x));
	repeat
		copymemory(destp, srcp, w);
		srcp :=pointer(cardinal(srcp)+ srcspan);
		destp :=pointer(cardinal(destp)+ destspan);
	  y:=y-1;
	until (y<>0);
end;

procedure fz_clear_pixmap_rect_with_color(dest:pfz_pixmap_s; value:integer;r: fz_bbox);
var
	destp,s:pbyte;
	x, y, w, k, destspan:integer;
begin
	r := fz_intersect_bbox(r, fz_bound_pixmap(dest));
	w := r.x1 - r.x0;
	y := r.y1 - r.y0;
	if (w <= 0) or (y <= 0) then
		exit;

	destspan := dest^.w * dest^.n;
	destp := pointer(cardinal(dest^.samples) + destspan * (r.y0 - dest^.y) + dest^.n * (r.x0 - dest^.x));
	if (value = 255) then
		repeat

			fillchar(destp^, w * dest^.n, 255);
			destp :=pointer(cardinal(destp)+ destspan);
      y:=y-1;
	  until y<>0
	else
		repeat
			s := destp;
			for x := 0 to w-1 do
			begin
				for k := 0 to dest^.n - 1  do
        s^:=value;
        inc(s);

				s^:= 255;
        inc(s);
			end;
			destp :=pointer(cardinal(destp)+ destspan);
		y:=y-1 ;
	  until y<>0;
end;

procedure fz_premultiply_pixmap(pix:pfz_pixmap_s);
var
	s:pbyte;
	a:byte;
	 k, x, y:integer;
begin
  s := pix^.samples;
	for y := 0 to pix^.h-1 do
	begin
		for x:= 0 to pix^.w-1 do
		begin
			a := byte_items(s)[pix^.n - 1];
			for k := 0 to pix^.n - 1-1 do
				byte_items(s)[k] := fz_mul255(byte_items(s)[k], a);
      inc(s, pix^.n );
			
		end;
	end;
end;

function fz_alpha_from_gray(gray:pfz_pixmap_s;luminosity:integer):pfz_pixmap_s ;
var
 alpha:pfz_pixmap_s;
 sp, dp:pbyte;
	len:integer;
begin
	assert(gray^.n = 2);

	alpha := fz_new_pixmap_with_rect(nil, fz_bound_pixmap(gray));
	dp := alpha^.samples;
	sp := gray^.samples;
	if (luminosity=0) then
		inc(sp);

	len := gray^.w * gray^.h;
	while (len>0)  do
	begin
    inc(dp);
		dp^:=byte_items(sp)[0];
		inc(sp,2);
    len:=len-1;
	end;

	result:=alpha;
end;

procedure fz_invert_pixmap(pix:pfz_pixmap_s);
var
	s:pbyte ;
	k, x, y:integer;
begin
  s := pix^.samples;
	for y := 0 to pix^.h-1 do
	begin
		for x := 0 to pix^.w-1 do
		begin
			for k := 0 to pix^.n - 2 do
				byte_items(s)[k] := 255 - byte_items(s)[k];
      inc(s,pix^.n);
		end;
	end;
end;

procedure fz_gamma_pixmap(pix:pfz_pixmap_s;gamma:single) ;
var
	gamma_map:array[0..255] of byte;
	s :pbyte;
	k, x, y:integer;
begin
  s := pix^.samples;
	for k := 0 to 255 do
		gamma_map[k] := trunc(power(k / 255.0, gamma) * 255);

	for y := 0 to pix^.h-1 do
	begin
		for x := 0 to pix^.w-1 do
		begin
			for k := 0 to pix^.n - 1-1 do
				byte_items(s)[k] := gamma_map[byte_items(s)[k]];

      inc(s,pix^.n);
		end;
	end;
end;

//* * Write pixmap to PNM file (without alpha channel)  */

function putch(fp:tstream;p:pchar;n:integer):integer;
begin
  fp.WriteBuffer(p^,n);
  result:=1;
end;

function fz_write_pnm(pixmap:pfz_pixmap_s;filename:pchar) :integer;
var
	fp:tfilestream;
	p:pbyte;
	len,n:integer;
  s:string;
begin
	if ((pixmap^.n <> 1) and (pixmap^.n <> 2) and ( pixmap^.n <> 4)) then
  begin
		result:= fz_throw('pixmap must be grayscale or rgb to write as pnm');

    exit;
  end;
 fp:=tfilestream.Create(filename,fmCreate);
 //	fp := fopen(filename, "wb");
	if (fp=nil) then
  begin
		result:= fz_throw('cannot open file %s ', [filename]);
    exit;
  end;

	if (pixmap^.n = 1) or (pixmap^.n = 2) then
		//fprintf(fp, "P5\n");
    putch(fp,pchar('P5'+#10),3);
	if (pixmap^.n = 4) then
		//fprintf(fp, "P6\n");
    putch(fp,pchar('P6'+#10),3);
 //	fprintf(fp, "%d %d\n", pixmap->w, pixmap->h);
  s:=format('%d %d', [pixmap^.w, pixmap^.h]);
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);
 //	fprintf(fp, "255\n");

	len := pixmap^.w * pixmap^.h;
	p := pixmap^.samples;

	case  (pixmap^.n) of
	1:
  begin
		putch(fp,pchar(p),1);
	end;
	2:
  begin
		while (len>0) do
		begin
		 //	putc(p[0], fp);
      putch(fp,pchar(p),1);
			inc(p,2);
      len:=len-1;
		end;
	end;
	4:
		while (len>0)    do
		begin
      putch(fp,pchar(p),1);
      inc(p,1);
			 putch(fp,pchar(p),1);
      inc(p,1);
			 putch(fp,pchar(p),1);

			inc(p,2);
      len:=len-1;
	 end;
	end;

fp.free;
result:=1;
end;

//*  * Write pixmap to PAM file (with or without alpha channel)  */

function fz_write_pam(pixmap:pfz_pixmap_s; filename:pchar;savealpha:integer):integer;
var
	sp:pbyte;
	y, w, k:integer;
	fp:tfilestream;
   s:string;
	sn,dn:integer;
  n:integer;
begin
  sn := pixmap^.n;
	dn := pixmap^.n;
	if (savealpha=0) and (dn > 1) then
		dn:=dn-1;

	fp:=tfilestream.Create(filename,fmCreate);
	if (fp=nil) then
  begin
		result:= fz_throw('cannot open file "%s": %s', [filename, 'strerror(errno)']);

    exit;
  end;
  putch(fp,pchar('P7'+#10),3);
  s:=format( 'WIDTH %d',[ pixmap^.w]);
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);
  s:=format( 'HEIGHT %d',[ pixmap^.h]);
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);
  s:=format( 'DEPTH %d',[ dn]);
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);
  s:='MAXVAL 255';
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);


	if (pixmap^.colorspace) <>nil then
  begin
	 //	fprintf(fp, "# COLORSPACE %s\n", pixmap->colorspace->name);

    s:=format( '# COLORSPACE %s\',[pixmap^.colorspace^.name]);
    n:=length(s);
   putch(fp,pchar(s+#10),n+1);
  end;
	case dn of
	 1:
   begin
    //  fprintf(fp, 'TUPLTYPE GRAYSCALE\n');
      s:= 'UPLTYPE GRAYSCALE';
      n:=length(s);
      putch(fp,pchar(s+#10),n+1);
   end;
	 2: if (sn = 2)then
   begin
     //fprintf(fp, 'TUPLTYPE GRAYSCALE_ALPHA\n');
      s:= 'TUPLTYPE GRAYSCALE_ALPHA';
      n:=length(s);
      putch(fp,pchar(s+#10),n+1);
   end;
	 3: if (sn = 4) then
    begin
     //fprintf(fp, 'TUPLTYPE RGB\n');
     s:= 'TUPLTYPE RGB';
      n:=length(s);
      putch(fp,pchar(s+#10),n+1);
    end;
	 4: if (sn = 4) then
   begin
  //   fprintf(fp, 'TUPLTYPE RGB_ALPHA\n');
      s:= 'TUPLTYPE RGB_ALPHA';
      n:=length(s);
      putch(fp,pchar(s+#10),n+1);
  	end;
  end;

 //	fprintf(fp, 'ENDHDR\n');
  s:= 'ENDHDR';
  n:=length(s);
  putch(fp,pchar(s+#10),n+1);


	sp := pixmap^.samples;
	for y := 0 to pixmap^.h-1 do
	begin
		w := pixmap^.w;
		while (w>0) do
		begin
			for k := 0 to  dn-1 do
      begin
			//	putc(byte_items(sp)[k], fp);
        putch(fp,pchar(@(byte_items(sp)[k])),1);
      end;
			inc(sp,sn);
      w:=w-1;
		end;
	end;

	fp.free;

	RESULT:=1;
end;

//*  * Write pixmap to PNG file (with or without alpha channel)  */

//#include <zlib.h>

procedure big32(buf:pbyte; v:integer);
begin
	byte_items(buf)[0] := (v shr 24) and $ff;
	byte_items(buf)[1] := (v shr 16) and $ff;
	byte_items(buf)[2] := (v shr 8) and $ff;
	byte_items(buf)[3] := (v) and  $ff;
end;

procedure put32(v:integer; fp:tstream) ;
var
c:char;
begin
  c:=chr(v shr 24);
  putch(fp,@c,1);
  c:=chr(v shr 16);
  putch(fp,@c,1);
  c:=chr(v shr 8);
  putch(fp,@c,1);
  c:=chr(v);
  putch(fp,@c,1);

end;

procedure fwrite(tag:pchar;size:integer;count:inTEger; fp:tstream);
begin
  fp.WriteBuffer(tag^,count);
end;

procedure putchunk(tag:pchar;data:pbyte;size:integer; fp:tstream);
var
	sum:byte;
begin
	put32(size, fp);
	fwrite(tag, 1, 4, fp);
	fwrite(PCHAR(data), 1, size, fp);
	sum := crc32(0, NIL, 0);
	sum := crc32(sum, PBYTEf(tag), 4);
	sum := crc32(sum, PBYTEf(data), size);
	put32(sum, fp);
end;

function fz_write_png(pixmap:pfz_pixmap_s; filename:pchar; savealpha:integer):integer;
 const
    pngsig: array[0..7] of byte= ( 137, 80, 78, 71, 13, 10, 26, 10 );
var
  fp:tfilestream;
	head:array[0..12] of byte;
	udata, cdata, sp, dp:pbyte;
	 usize, csize:dword;
	y, x, k, sn, dn:integer;
	color:integer;
  err:integer;
begin
	if ((pixmap^.n <> 1) and (pixmap^.n <> 2) and (pixmap^.n <> 4)) then
  begin
		result:= fz_throw('pixmap must be grayscale or rgb to write as png');
    exit;
  end;

	sn := pixmap^.n;
	dn := pixmap^.n;
	if (savealpha=0) and (dn > 1) then
		dn:=dn-1;

	case dn of
	 1: color := 0;
	 2: color := 4;
	 3: color := 2;
	4: color := 6;
	end;

	usize := (pixmap^.w * dn + 1) * pixmap^.h;
	csize := compressBound(usize);
	udata := fz_malloc(usize);
	cdata := fz_malloc(csize);

	sp := pixmap^.samples;
	dp := udata;
	for y := 0 to pixmap^.h-1 do
	begin
	//	*dp++ = 1; //* sub prediction filter */
    dp^:=1;
    inc(dp);
		for x := 0 to pixmap^.w-1 do
		begin
			for k := 0 to dn-1 do
			begin
				if (x = 0) then
					byte_items(dp)[k] := byte_items(sp)[k]
				else
					byte_items(dp)[k] := byte_items(sp)[k] - byte_items(sp)[k-sn];
			end;
      inc(sp,sn);
      inc(dp,dn);
		end;
	end;

	err := compress(pbytef(cdata), csize, pbytef(udata), usize);
	if (err <> Z_OK) then
	begin
		fz_free(udata);
		fz_free(cdata);
		result:= fz_throw('cannot compress image data');
    exit;
	end;
  fp:=tfilestream.Create(filename,fmCreate);
	if (fp=nil) then
	begin
		fz_free(udata);
		fz_free(cdata);
	  result:= fz_throw('cannot open file %s: ', [filename]);
    exit;
	end;

	big32(pointer(cardinal(@head)+0), pixmap^.w);
	big32(pointer(cardinal(@head)+4), pixmap^.h);
	head[8] := 8; //* depth */
	head[9] := color;
	head[10] := 0; //* compression */
	head[11] := 0; //* filter */
	head[12] := 0; //* interlace */

	fwrite(@pngsig, 1, 8, fp);
	putchunk('IHDR', @head, 13, fp);
	putchunk('IDAT', cdata, csize, fp);
	putchunk('IEND', @head, 0, fp);
	fp.free;

	fz_free(udata);
	fz_free(cdata);
	result:=1;
  
end;

end.
