unit draw_affiness;

interface
uses
SysUtils, Math,digtypes,base_error;


procedure fz_paint_image(dst:pfz_pixmap_s; scissor:fz_bbox ; shape:pfz_pixmap_s; img:pfz_pixmap_s; ctm: fz_matrix; alpha:integer);
procedure
fz_paint_image_with_color(dst:pfz_pixmap_s; scissor:fz_bbox ; shape:pfz_pixmap_s; img:pfz_pixmap_s; ctm: fz_matrix; color:pbyte);

implementation
uses base_object_functions,fz_textx,fz_pixmapss;


function roundup( x:single):single;
begin
  if x<0 then
    result:=floor(X)
    else
    result:=ceil(x);

end;
{$OVERFLOWCHECKS OFF}
function lerp( a,  b,  t:integer):integer;
begin
  //IF B-A>=0 THEN
	//result:= a + (((b - a) * t) shr 16)
  //ELSE
  //result:= a + NOT ((NOT ((b - a) * t)) shr 16)
  result:= a + (((b - a) * t) div 65536) ;

end;
{$OVERFLOWCHECKS ON}
function bilerp( a, b, c,  d,  u,  v:integer):integer;
begin
	result:= lerp(lerp(a, b, u), lerp(c, d, u), v);
end;

function sample_nearest(s:pbyte;  w,  h,  n,  u,  v:integer):pbyte;
begin
	if (u < 0) then u := 0;
	if (v < 0) then v := 0;
	if (u >= w) then u := w - 1;
	if (v >= h) then v := h - 1;
	result:= pointer(cardinal(s) + (v * w + u) * n);
end;

//* Blend premultiplied source image in constant alpha over destination */

procedure
fz_paint_affine_alpha_N_lerp(dp, sp:pbyte;  sw, sh, u,  v,  fa,  fb,  w,  n,  alpha:integer; hp:pbyte);
var
	 k, n1,hi,vi,ui,uf,vf,xa,t,x:integer;

   a,b,c,d:pbyte;

begin
  n1 := n-1;
	while (w<>0) do
	begin
    w:=w-1;
	  ui := u shr 16;
	  vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and  (vi < sh)) then
		begin
			uf := u and $ffff;
			vf := v and $ffff;
			a := sample_nearest(sp, sw, sh, n, ui, vi);
			b := sample_nearest(sp, sw, sh, n, ui+1, vi);
			c := sample_nearest(sp, sw, sh, n, ui, vi+1);
			d := sample_nearest(sp, sw, sh, n, ui+1, vi+1);
			xa := bilerp(byte_items(a)[n1], byte_items(b)[n1], byte_items(c)[n1], byte_items(d)[n1], uf, vf);

			xa := fz_mul255(xa, alpha);
			t := 255 - xa;
			for k := 0  to n1-1 do
			begin
				 x := bilerp(byte_items(a)[k], byte_items(b)[k], byte_items(c)[k], byte_items(d)[k], uf, vf);
				byte_items(dp)[k] := fz_mul255(x, alpha) + fz_mul255(byte_items(dp)[k], t);
			end;
			byte_items(dp)[n1] := xa + fz_mul255(byte_items(dp)[n1], t);
			if (hp<>nil) then
				byte_items(hp)[0] := xa + fz_mul255(byte_items(hp)[n1], t);
		end;
    inc(dp,n);

		if (hp<>nil) then
			inc(hp);;
		u :=u + fa;
		v :=v + fb;
	end;
end;

//* Special case code for gray -> rgb */
procedure
fz_paint_affine_alpha_g2rgb_lerp(dp, sp:pbyte;  sw,  sh,  u,  v,  fa,  fb,  w,  alpha:integer;hp:pbyte);
var
  ui,vi,x,y,t,uf,vf:integer;
  a,b,c,d:pbyte;
begin
	while (w<>0) do
	begin
     w:=w-1;
		 ui := u shr 16;
		 vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh)) then
		begin
			uf := u and $ffff;
			vf := v and $ffff;
			a := sample_nearest(sp, sw, sh, 2, ui, vi);
			b := sample_nearest(sp, sw, sh, 2, ui+1, vi);
			c := sample_nearest(sp, sw, sh, 2, ui, vi+1);
			d := sample_nearest(sp, sw, sh, 2, ui+1, vi+1);
			y := bilerp(byte_items(a)[1], byte_items(b)[1], byte_items(c)[1], byte_items(d)[1], uf, vf);
			x := bilerp(byte_items(a)[0], byte_items(b)[0], byte_items(c)[0], byte_items(d)[0], uf, vf);
			x := fz_mul255(x, alpha);
			y := fz_mul255(y, alpha);
			t := 255 - y;
			byte_items(dp)[0] := x + fz_mul255(byte_items(dp)[0], t);
			byte_items(dp)[1] := x + fz_mul255(byte_items(dp)[1], t);
			byte_items(dp)[2] := x + fz_mul255(byte_items(dp)[2], t);
			byte_items(dp)[3] := y + fz_mul255(byte_items(dp)[3], t);
			if (hp<>nil)  then
				byte_items(hp)[0] := y + fz_mul255(byte_items(hp)[0], t);
		end;
    inc(dp,4);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_alpha_N_near(dp, sp:pbyte;  sw,  sh,  u,  v,  fa,  fb, w,  n,  alpha:integer; hp:pbyte);
var
	 k,	 n1, ui, vi,a,t:integer;
   sample:pbyte;
begin
  n1:=n-1;
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh))  then
		begin
			sample := pointer(cardinal(sp) + ((vi * sw + ui) * n));
			a := fz_mul255(byte_items(sample)[n-1], alpha);
			t := 255 - a;
			for k := 0 to n1-1 do
				byte_items(dp)[k] := fz_mul255(byte_items(sample)[k], alpha) + fz_mul255(byte_items(dp)[k], t);
			byte_items(dp)[n1] := a + fz_mul255(byte_items(dp)[n1], t);
			if (hp<>nil) then
				byte_items(hp)[0] := a + fz_mul255(byte_items(hp)[n1], t);
		end;
    inc(dp,n);

		if (hp<>nil) then
			inc(hp,1);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_alpha_g2rgb_near(dp, sp:pbyte; sw,  sh,  u, v,  fa,  fb,  w,  alpha:integer; hp:pbyte);
var
   ui,vi,x,a,t:integer;
   sample:pbyte;
begin

	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh) ) then
		begin
			sample := pointer(cardinal(sp) + ((vi * sw + ui) * 2));
			x := fz_mul255(byte_items(sample)[0], alpha);
			a := fz_mul255(byte_items(sample)[1], alpha);
			t := 255 - a;
			byte_items(dp)[0] := x + fz_mul255(byte_items(dp)[0], t);
			byte_items(dp)[1] := x + fz_mul255(byte_items(dp)[1], t);
			byte_items(dp)[2] := x + fz_mul255(byte_items(dp)[2], t);
			byte_items(dp)[3] := a + fz_mul255(byte_items(dp)[3], t);
			if (hp<>nil) then
				byte_items(hp)[0] := a + fz_mul255(byte_items(hp)[0], t);
		end;
		inc(dp,4);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

//* Blend premultiplied source image over destination */

procedure fz_paint_affine_N_lerp(dp, sp:pbyte;  sw,  sh, u, v, fa, fb,  w,  n:integer; hp:pbyte);
var
	 k,n1,ui,vi,uf,vf,y,t,x:integer;
   a,b,c,d:pbyte;
begin
  n1:=n-1;
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and ( vi >= 0) and ( vi < sh)) then
		begin
			uf := u and $ffff;
			vf := v and $ffff;
			a := sample_nearest(sp, sw, sh, n, ui, vi);
			b := sample_nearest(sp, sw, sh, n, ui+1, vi);
			c := sample_nearest(sp, sw, sh, n, ui, vi+1);
			d := sample_nearest(sp, sw, sh, n, ui+1, vi+1);
			y := bilerp(byte_items(a)[n1], byte_items(b)[n1], byte_items(c)[n1], byte_items(d)[n1], uf, vf);
			t := 255 - y;
			for k := 0 to n1-1 do
			begin
				x := bilerp(byte_items(a)[k], byte_items(b)[k], byte_items(c)[k], byte_items(d)[k], uf, vf);
				byte_items(dp)[k] := x + fz_mul255(byte_items(dp)[k], t);
			end;
			byte_items(dp)[n1] := y + fz_mul255(byte_items(dp)[n1], t);
			if (hp<>nil) then
				byte_items(hp)[0] := y + fz_mul255(byte_items(hp)[0], t);
		end;
		inc(dp,n);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure fz_paint_affine_solid_g2rgb_lerp(dp, sp:pbyte; sw, sh, u, v, fa, fb, w:integer; hp:pbyte);
var
ui,vi,uf,vf,y,t,x:integer;
a,b,c,d:pbyte;
begin
	while (w<>0)  do
	begin
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh)) then
		begin
			uf := u and $ffff;
			vf := v and $ffff;
			a := sample_nearest(sp, sw, sh, 2, ui, vi);
			b := sample_nearest(sp, sw, sh, 2, ui+1, vi);
			c := sample_nearest(sp, sw, sh, 2, ui, vi+1);
			d := sample_nearest(sp, sw, sh, 2, ui+1, vi+1);
			y := bilerp(byte_items(a)[1], byte_items(b)[1], byte_items(c)[1], byte_items(d)[1], uf, vf);
			t := 255 - y;
			x := bilerp(byte_items(a)[0], byte_items(b)[0], byte_items(c)[0], byte_items(d)[0], uf, vf);
			byte_items(dp)[0] := x + fz_mul255(byte_items(dp)[0], t);
			byte_items(dp)[1] := x + fz_mul255(byte_items(dp)[1], t);
			byte_items(dp)[2] := x + fz_mul255(byte_items(dp)[2], t);
			byte_items(dp)[3] := y + fz_mul255(byte_items(dp)[3], t);
			if (hp<>nil) then
				byte_items(hp)[0] := y + fz_mul255(byte_items(hp)[0], t);
		end;
		inc(dp,4);
		if (hp<>nil) then
			inc(hp);
    //outprintf(inttostr(u));
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_N_near(dp, sp:pbyte;  sw, sh,  u,  v, fa, fb,  w, n:integer; hp:pbyte);
var
	 k,n1,ui,vi,a,t:integer;
  sample:pbyte;
begin


  n1 := n-1;
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh)) then
		begin
			sample :=pointer( cardinal(sp) + ((vi * sw + ui) * n));
			a := byte_items(sample)[n1];
		 	t := 255 - a;

			for k := 0 to n1-1 do
				byte_items(dp)[k] := byte_items(sample)[k] + fz_mul255(byte_items(dp)[k], t);
			byte_items(dp)[n1] := a + fz_mul255(byte_items(dp)[n1], t);
			if (hp<>nil) then
				byte_items(hp)[0] := a + fz_mul255(byte_items(hp)[0], t);
		end;
		inc(dp,n);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_solid_g2rgb_near(dp, sp:pbyte;   sw, sh, u, v, fa, fb, w:integer; hp:pbyte);
var
ui,vi,a,x,t:integer;
 sample:pbyte;
begin
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh)) then
		begin
			sample := pointer( cardinal(sp) + ((vi * sw + ui) * 2));
			x := byte_items(sample)[0];
			a := byte_items(sample)[1];
			t := 255 - a;
			byte_items(dp)[0] := x + fz_mul255(byte_items(dp)[0], t);
			byte_items(dp)[1] := x + fz_mul255(byte_items(dp)[1], t);
			byte_items(dp)[2] := x + fz_mul255(byte_items(dp)[2], t);
			byte_items(dp)[3] := a + fz_mul255(byte_items(dp)[3], t);
			if (hp<>nil ) then
				byte_items(hp)[0] := a + fz_mul255(byte_items(hp)[0], t);
		end ;
		inc(dp,4);
		if (hp<>nil ) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

//* Blend non-premultiplied color in source image mask over destination */

procedure
fz_paint_affine_color_N_lerp(dp, sp:pbyte;  sw, sh, u, v, fa, fb, w,  n:integer; color,hp:pbyte);
var
	 n1, sa,k,ui,vi,uf,vf:integer;
   ma,masa:integer;
	a,b,c,d:pbyte;
begin
	n1 := n - 1;
	sa := byte_items(color)[n1];
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh) ) then
		begin
			uf := u and $ffff;
			vf := v and $ffff;
			a := sample_nearest(sp, sw, sh, 1, ui, vi);
			b := sample_nearest(sp, sw, sh, 1, ui+1, vi);
			c := sample_nearest(sp, sw, sh, 1, ui, vi+1);
			d := sample_nearest(sp, sw, sh, 1, ui+1, vi+1);
			ma := bilerp(byte_items(a)[0], byte_items(b)[0], byte_items(c)[0], byte_items(d)[0], uf, vf);
			masa := FZ_COMBINE(FZ_EXPAND(ma), sa);
			for k := 0 to n1-1 do
				byte_items(dp)[k] := FZ_BLEND(byte_items(color)[k], byte_items(dp)[k], masa);
			byte_items(dp)[n1] := FZ_BLEND(255, byte_items(dp)[n1], masa);
			if (hp<>nil) then
				byte_items(hp)[0] := FZ_BLEND(255, byte_items(hp)[0], masa);
		end;
		inc(dp,n);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_color_N_near(dp, sp:pbyte; sw, sh, u, v,  fa,  fb,  w, n:integer; color, hp:pbyte);
var
n1, sa,k,ui,vi:integer;
   ma,masa:integer;

begin
  	n1 := n - 1;
	sa := byte_items(color)[n1];
	while (w<>0) do
	begin
    w:=w-1;
		ui := u shr 16;
		vi := v shr 16;
		if ((ui >= 0) and (ui < sw) and (vi >= 0) and (vi < sh)) then
		begin
			ma := byte_items(sp)[vi * sw + ui];
			masa := FZ_COMBINE(FZ_EXPAND(ma), sa);
			for k := 0 to n1-1 do
				byte_items(dp)[k] := FZ_BLEND(byte_items(color)[k], byte_items(dp)[k], masa);
			byte_items(dp)[n1] := FZ_BLEND(255, byte_items(dp)[n1], masa);
			if (hp<>nil) then
				byte_items(hp)[n1] := FZ_BLEND(255, byte_items(hp)[n1], masa);
		end;
		inc(dp,n);
		if (hp<>nil) then
			inc(hp);
		u :=u + fa;
		v :=v + fb;
	end;
end;

procedure
fz_paint_affine_lerp(dp, sp:pbyte; sw, sh, u, v, fa, fb,w, n, alpha:integer; color, hp:pbyte);
begin
	if (alpha = 255) then
	begin
		case n of

		1: fz_paint_affine_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 1, hp);
		2: fz_paint_affine_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 2, hp);
		4: fz_paint_affine_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 4, hp);
		else fz_paint_affine_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, n, hp);
		end;
	end
	else if (alpha > 0) then
	begin
		case n of
		1: fz_paint_affine_alpha_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 1, alpha, hp);
		2: fz_paint_affine_alpha_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 2, alpha, hp);
		4: fz_paint_affine_alpha_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 4, alpha, hp);
		else fz_paint_affine_alpha_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, n, alpha, hp); 
		end;
	end;
end;

procedure
fz_paint_affine_g2rgb_lerp(dp, sp:pbyte;  sw,  sh,  u,  v, fa, fb, w,  n, alpha:integer; color, hp:pbyte);
begin
	if (alpha = 255) then
	begin
		fz_paint_affine_solid_g2rgb_lerp(dp, sp, sw, sh, u, v, fa, fb, w, hp);
	end
	else if (alpha > 0) then
	begin
		fz_paint_affine_alpha_g2rgb_lerp(dp, sp, sw, sh, u, v, fa, fb, w, alpha, hp);
	end;
end;

procedure
fz_paint_affine_near(dp, sp:pbyte; sw, sh, u, v,  fa, fb, w, n, alpha:integer;color, hp:pbyte);
begin
	if (alpha = 255) then
	begin
		case (n) of
		1: fz_paint_affine_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 1, hp);
		2: fz_paint_affine_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 2, hp);
		4: fz_paint_affine_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 4, hp);
		else fz_paint_affine_N_near(dp, sp, sw, sh, u, v, fa, fb, w, n, hp);
		end;
	end
	else if (alpha > 0)  then
	begin
		case (n) of
		1: fz_paint_affine_alpha_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 1, alpha, hp);
		2: fz_paint_affine_alpha_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 2, alpha, hp);
		4: fz_paint_affine_alpha_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 4, alpha, hp);
		else fz_paint_affine_alpha_N_near(dp, sp, sw, sh, u, v, fa, fb, w, n, alpha, hp);
		end;
	end;
end;

procedure
fz_paint_affine_g2rgb_near(dp, sp:pbyte;  sw, sh, u, v, fa, fb, w,  n, alpha:integer; color, hp:pbyte);
begin
	if (alpha = 255) then
	begin
		fz_paint_affine_solid_g2rgb_near(dp, sp, sw, sh, u, v, fa, fb, w, hp);
	end
	else if (alpha > 0) then
	begin
		fz_paint_affine_alpha_g2rgb_near(dp, sp, sw, sh, u, v, fa, fb, w, alpha, hp);
	end;
end;

procedure
fz_paint_affine_color_lerp(dp, sp:pbyte; sw, sh, u, v, fa, fb, w, n,  alpha:integer;color, hp:pbyte);
begin
	case (n) of
	2: fz_paint_affine_color_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 2, color, hp);
	4: fz_paint_affine_color_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, 4, color, hp);
	else fz_paint_affine_color_N_lerp(dp, sp, sw, sh, u, v, fa, fb, w, n, color, hp); 
	end;
end;

procedure
fz_paint_affine_color_near(dp, sp:pbyte; sw, sh, u, v, fa, fb, w, n,  alpha:integer;color, hp:pbyte);
begin
	case (n) of
	2: fz_paint_affine_color_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 2, color, hp);
	4: fz_paint_affine_color_N_near(dp, sp, sw, sh, u, v, fa, fb, w, 4, color, hp);
	else  fz_paint_affine_color_N_near(dp, sp, sw, sh, u, v, fa, fb, w, n, color, hp);
	end;
end;

//* Draw an image with an affine transform on destination */

procedure
fz_paint_image_imp( dst:pfz_pixmap_s;scissor: fz_bbox ; shape: pfz_pixmap_s ;img :pfz_pixmap_s; ctm: fz_matrix; color:pbyte; alpha:integer);
var
	dp, sp, hp:pbyte;
	 u, v, fa, fb, fc, fd:integer;
	 x, y, w, h,tt:integer;
	 sw, sh, n, hw:integer;
	inv:fz_matrix ;
	bbox:fz_bbox ;
	dolerp:integer;
  paintfn:paintfn1;

begin

	//* grid fit the image */
	if (fz_is_rectilinear(ctm)<>0) then
	begin
		ctm.a := roundUP(ctm.a);
		ctm.b := roundUP(ctm.b);
		ctm.c := roundUP(ctm.c);
		ctm.d := roundUP(ctm.d);
		ctm.e := FLOOR(ctm.e);
		ctm.f := FLOOR(ctm.f);
	end;

	//* turn on interpolation for upscaled and non-rectilinear transforms */
	dolerp := 0;
	if (fz_is_rectilinear(ctm)=0) then
		dolerp := 1;
	if (sqrt(ctm.a * ctm.a + ctm.b * ctm.b) > img^.w) then
		dolerp := 1;
	if (sqrt(ctm.c * ctm.c + ctm.d * ctm.d) > img^.h)  then
		dolerp := 1;

	//* except when we shouldn't, at large magnifications */
	if (img^.interpolate=0) then
	begin
		if (sqrt(ctm.a * ctm.a + ctm.b * ctm.b) > img^.w * 2)  then
			dolerp := 0;
		if (sqrt(ctm.c * ctm.c + ctm.d * ctm.d) > img^.h * 2) then
			dolerp := 0;
	end;

	bbox := fz_round_rect(fz_transform_rect(ctm, fz_unit_rect));
	bbox := fz_intersect_bbox(bbox, scissor);
	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;

	//* map from screen space (x,y) to image space (u,v) */
	inv := fz_scale(1.0 / img^.w, -1.0 / img^.h);
	inv := fz_concat(inv, fz_translate(0, 1));
	inv := fz_concat(inv, ctm);
	inv := fz_invert_matrix(inv);

	fa := trunc(inv.a * 65536);
	fb := trunc(inv.b * 65536);
	fc := trunc(inv.c * 65536);
	fd := trunc(inv.d * 65536);

	//* Calculate initial texture positions. Do a half step to start. */
	u := (fa * x) + (fc * y) + trunc(inv.e * 65536) + ((fa + fc) DIV 2);
	v := (fb * x) + (fd * y) + trunc(inv.f * 65536)+ ((fb + fd) DIV 2);


	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * dst^.n);
	n := dst^.n;
	sp := img^.samples;
	sw := img^.w;
	sh := img^.h;
	if (shape<>nil) then
	begin
		hw := shape^.w;
		hp := pointer(cardinal(shape^.samples) + ((y - shape^.y) * hw) + x - dst^.x);
	end
	else
	begin
		hw := 0;
		hp := nil;
	end;

	//* TODO: if (fb == 0 && fa == 1) call fz_paint_span */

	if (dst^.n = 4) and (img^.n = 2) then
	begin
		assert(color = nil);
		if (dolerp<>0)  then
			paintfn := fz_paint_affine_g2rgb_lerp
		else
			paintfn := fz_paint_affine_g2rgb_near;
	end
	else
	begin
		if (dolerp<>0) then
		begin
			if (color<>nil) then
				paintfn := fz_paint_affine_color_lerp
			else
				paintfn := fz_paint_affine_lerp;
		end
		else
		begin
			if (color<>nil) then
				paintfn := fz_paint_affine_color_near
			else
				paintfn := fz_paint_affine_near;
		end;
	end;

	while (h<>0) do
	begin
    h:=h-1;
		paintfn(dp, sp, sw, sh, u, v, fa, fb, w, n, alpha, color, hp);
		inc(dp, dst^.w * n);
    if hp<>nil then
		inc(hp, hw);
		u :=u + fc;
		v :=v + fd;
	end;
end;

procedure
fz_paint_image_with_color(dst:pfz_pixmap_s; scissor:fz_bbox ; shape:pfz_pixmap_s; img:pfz_pixmap_s; ctm: fz_matrix; color:pbyte);
begin
	assert(img^.n = 1);
	fz_paint_image_imp(dst, scissor, shape, img, ctm, color, 255);
end;

procedure
fz_paint_image(dst:pfz_pixmap_s; scissor:fz_bbox ; shape:pfz_pixmap_s; img:pfz_pixmap_s; ctm: fz_matrix; alpha:integer);
begin
	assert((dst^.n = img^.n) or ((dst^.n = 4) and (img^.n = 2)));
	fz_paint_image_imp(dst, scissor, shape, img, ctm, nil, alpha);
end;


end.
