

unit draw_paints;
{*

The functions in this file implement various flavours of Porter-Duff blending.

We take the following as definitions:

	Cx = Color (from plane x)
	ax = Alpha (from plane x)
	cx = Cx.ax = Premultiplied color (from plane x)

The general PorterDuff blending equation is:

	Blend Z = X op Y	cz = Fx.cx + Fy. cy	where Fx and Fy depend on op

The two operations we use in this file are: '(X in Y) over Z' and
'S over Z'. The definitions of the 'over' and 'in' operations are as
follows:

	For S over Z,	Fs = 1, Fz = 1-as
	For X in Y,	Fx = ay, Fy = 0

We have 2 choices; we can either work with premultiplied data, or non
premultiplied data. Our

First the premultiplied case:

	Let S = (X in Y)
	Let R = (X in Y) over Z = S over Z

	cs	= cx.Fx + cy.Fy	(where Fx = ay, Fy = 0)
		= cx.ay
	as	= ax.Fx + ay.Fy
		= ax.ay

	cr	= cs.Fs + cz.Fz	(where Fs = 1, Fz = 1-as)
		= cs + cz.(1-as)
		= cx.ay + cz.(1-ax.ay)
	ar	= as.Fs + az.Fz
		= as + az.(1-as)
		= ax.ay + az.(1-ax.ay)

This has various nice properties, like not needing any divisions, and
being symmetric in color and alpha, so this is what we use. Because we
went through the pain of deriving the non premultiplied forms, we list
them here too, though they are not used.

Non Pre-multiplied case:

	Cs.as	= Fx.Cx.ax + Fy.Cy.ay	(where Fx = ay, Fy = 0)
		= Cx.ay.ax
	Cs	= (Cx.ay.ax)/(ay.ax)
		= Cx
	Cr.ar	= Fs.Cs.as + Fz.Cz.az	(where Fs = 1, Fz = 1-as)
		= Cs.as	+ (1-as).Cz.az
		= Cx.ax.ay + Cz.az.(1-ax.ay)
	Cr	= (Cx.ax.ay + Cz.az.(1-ax.ay))/(ax.ay + az.(1-ax-ay))

Much more complex, it seems. However, if we could restrict ourselves to
the case where we were always plotting onto an opaque background (i.e.
az = 1), then:

	Cr	= Cx.(ax.ay) + Cz.(1-ax.ay)
		= (Cx-Cz)*(1-ax.ay) + Cz	(a single MLA operation)
	ar	= 1

Sadly, this is not true in the general case, so we abandon this effort
and stick to using the premultiplied form.

*}

interface
uses digtypes;
procedure fz_paint_span_with_color( dp,  mp:pbyte;  n, w:integer;color:pbyte);
procedure fz_paint_span( dp, sp:pbyte; n, w, alpha:integer);
procedure fz_paint_solid_alpha( dp:pbyte; w:integer;alpha:integer);
procedure fz_paint_solid_color(dp:pbyte; n,w :integer; color:pbyte);
procedure fz_paint_pixmap_with_rect(dst:pfz_pixmap_s;  src:pfz_pixmap_s;  alpha:integer; bbox: fz_bbox) ;
procedure fz_paint_pixmap(dst:pfz_pixmap_s;  src:pfz_pixmap_s;  alpha:integer);
procedure fz_paint_pixmap_with_mask(dst:pfz_pixmap_s;  src:pfz_pixmap_s; msk:pfz_pixmap_s);
implementation
uses base_object_functions,fz_pixmapss;
procedure fz_paint_solid_alpha( dp:pbyte; w:integer;alpha:integer);
var
 t:integer;
begin
	t := FZ_EXPAND(255 - alpha);

	while (w>0) do
	begin
		dp^:= alpha + FZ_COMBINE(dp^, t);
		inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_solid_color(dp:pbyte; n,w :integer; color:pbyte);
var
n1,sa,k,ma:integer;
begin
	n1 := n - 1;
	sa := FZ_EXPAND(byte_items(color)[n1]);

	while (w>0)  do
	begin
		ma := FZ_COMBINE(FZ_EXPAND(255), sa);
		for k := 0  to n1-1 do
			byte_items(dp)[k] := FZ_BLEND(byte_items(color)[k], byte_items(dp)[k], ma);
		byte_items(dp)[k] := FZ_BLEND(255, byte_items(dp)[k], ma);
		inc(dp,n);
    w:=w-1;
	end;
end;

//* Blend a non-premultiplied color in mask over destination */

procedure fz_paint_span_with_color_2( dp, mp:pbyte; w:integer;color:pbyte);
var
 sa,g,ma:integer;

begin
	sa := FZ_EXPAND(byte_items(color)[1]);
	g := color^;
	while (w>0) do
	begin
		ma := mp^;
    inc(mp);
		ma := FZ_COMBINE(FZ_EXPAND(ma), sa);
			byte_items(dp)[0] := FZ_BLEND(g, 	byte_items(dp)[0], ma);
			byte_items(dp)[1] := FZ_BLEND(255, 	byte_items(dp)[1], ma);
		inc(dp,2);
    w:=w-1;
	end;
end;

procedure fz_paint_span_with_color_4( dp,  mp:pbyte;  w:integer;color:pbyte);
var
	sa,r,g,b,ma:integer;

begin
  sa := FZ_EXPAND(byte_items(color)[3]);
  r := byte_items(color)[0];
  g := byte_items(color)[1];
  b := byte_items(color)[2];

	while (w>0) do
	begin
	   ma := mp^;
     inc(mp);
		ma := FZ_COMBINE(FZ_EXPAND(ma), sa);
		byte_items(dp)[0] := FZ_BLEND(r, byte_items(dp)[0], ma);
		byte_items(dp)[1] := FZ_BLEND(g, byte_items(dp)[1], ma);
		byte_items(dp)[2] := FZ_BLEND(b, byte_items(dp)[2], ma);
		byte_items(dp)[3] := FZ_BLEND(255, byte_items(dp)[3], ma);
		inc(dp,4);
    w:=w-1;
	end;
end;

procedure fz_paint_span_with_color_N(dp,mp:pbyte; n,  w:integer;color:pbyte);
var
	n1,sa,k,ma:integer;

begin
   n1 := n - 1;
  sa := FZ_EXPAND(byte_items(color)[n1]);
	while (w>0) do
	begin
		ma := mp^;
    inc(mp);
		ma := FZ_COMBINE(FZ_EXPAND(ma), sa);
		for k := 0 to n1-1 do
			byte_items(dp)[k] := FZ_BLEND(byte_items(color)[k], byte_items(dp)[k], ma);
		byte_items(dp)[k]:= FZ_BLEND(255, byte_items(dp)[k], ma);
    inc(dp,n);

    w:=w-1;
	end;
end;

procedure fz_paint_span_with_color( dp,  mp:pbyte;  n, w:integer;color:pbyte);
begin
	case (n) of

	2: fz_paint_span_with_color_2(dp, mp, w, color);
	4: fz_paint_span_with_color_4(dp, mp, w, color);
	else  fz_paint_span_with_color_N(dp, mp, n, w, color);
  end;
end;

//* Blend source in mask over destination */

procedure fz_paint_span_with_mask_2( dp,  sp,  mp:pbyte; w:integer) ;
var
    masa, ma:integer;
begin
	while (w>0) do
	begin
		ma := mp^;
    inc(mp);
		ma := FZ_EXPAND(ma);
		masa := FZ_COMBINE(byte_items(sp)[1], ma);
		masa := 255 - masa;
		masa := FZ_EXPAND(masa);
		dp^:= FZ_COMBINE2(sp^, ma, dp^, masa);
    inc(sp);
    inc(dp);
  	dp^:= FZ_COMBINE2(sp^, ma, dp^, masa);
		inc(sp);
    inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_span_with_mask_4( dp, sp, mp:pbyte; w:integer);
var
masa, ma:integer;
begin
 while (w>0) do
 begin
    ma := mp^;
    inc(mp);
		ma := FZ_EXPAND(ma);
		masa := FZ_COMBINE(byte_items(sp)[3], ma);
		masa := 255 - masa;
		masa := FZ_EXPAND(masa);
		dp^ := FZ_COMBINE2(sp^, ma, dp^, masa);
    inc(sp);
    inc(dp);

		dp^ := FZ_COMBINE2(sp^, ma, dp^, masa);
		inc(sp);
    inc(dp);
		dp^ := FZ_COMBINE2(sp^, ma, dp^, masa);
		inc(sp);
    inc(dp);
		dp^ := FZ_COMBINE2(sp^, ma, dp^, masa);
		inc(sp);
    inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_span_with_mask_N( dp, sp,  mp:pbyte; n,  w:integer);
var
 k,masa,ma:integer;
begin
	while (w>0) do
	begin
		k := n;
  	 ma := mp^;
    inc(mp);
		ma := FZ_EXPAND(ma);
		masa := FZ_COMBINE(byte_items(sp)[n-1], ma);
		masa := 255-masa;
		masa := FZ_EXPAND(masa);
		while (k>0) do
		begin
			dp^ := FZ_COMBINE2(sp^, ma, dp^, masa);
			inc(sp);
      inc(dp);
      k:=k-1;
		end;
    w:=w-1;
	end;
end;

procedure fz_paint_span_with_mask( dp,  sp,  mp:pbyte; n,w:integer);
begin
	case n of
	2: fz_paint_span_with_mask_2(dp, sp, mp, w);
	4: fz_paint_span_with_mask_4(dp, sp, mp, w);
	else fz_paint_span_with_mask_N(dp, sp, mp, n, w);
	end;
end;

//* Blend source in constant alpha over destination */

procedure fz_paint_span_2_with_alpha( dp,  sp:pbyte; w, alpha:integer);
var
  masa:integer;
begin
	alpha := FZ_EXPAND(alpha);
	while (w>0) do
	begin
		 masa := FZ_COMBINE(byte_items(sp)[1], alpha);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
      w:=w-1;
	end;
end;

procedure fz_paint_span_4_with_alpha( dp,  sp:pbyte; w, alpha:integer);
var
  masa:integer;
begin
	alpha := FZ_EXPAND(alpha);
	while (w>0) do
	begin
		 masa := FZ_COMBINE(byte_items(sp)[3], alpha);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
		dp^ := FZ_BLEND(sp^, dp^, masa);
		inc(sp);
      inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_span_N_with_alpha(dp,  sp:pbyte;  n,  w,  alpha:integer);
var
  masa,k:integer;
begin
	alpha := FZ_EXPAND(alpha);
	while (w>0) do
	begin
		masa := FZ_COMBINE(byte_items(sp)[n-1], alpha);
		k := n;
		while (k>0) do
		begin
			dp^:= FZ_BLEND(sp^, dp^, masa);
      inc(sp);
      inc(dp);

      k:=k-1;
		end;
    w:=w-1;
	end;
end;

//* Blend source over destination */

procedure fz_paint_span_1( dp,  sp:pbyte; w:integer);
var
t:integer;
begin
	while (w>0) do
	begin
		t := FZ_EXPAND(255 - byte_items(sp)[0]);
		dp^ := sp^ + FZ_COMBINE(dp^, t);
    inc(sp);
    inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_span_2( dp,  sp:pbyte; w:integer);
var
t:integer;
begin
	while (w>0) do
	begin
		t := FZ_EXPAND(255 - byte_items(sp)[1]);
    dp^:=sp^+ FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
		dp^:=sp^+ FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
    w:=w-1;
  end;
end;

procedure fz_paint_span_4( dp,  sp:pbyte; w:integer);
var
t:integer;
begin
	while (w>0) do
	begin
		 t := FZ_EXPAND(255 - byte_items(sp)[3]);
		dp^ := sp^ + FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
		dp^ := sp^ + FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
		dp^ := sp^ + FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
		dp^ := sp^ + FZ_COMBINE(dp^, t);
		inc(sp);
    inc(dp);
    w:=w-1;
	end;
end;

procedure fz_paint_span_N( dp, sp:pbyte; n, w:integer);
var
t,k:integer;
begin
	while (w>0) do
	begin
		 k := n;
		 t := FZ_EXPAND(255 - byte_items(sp)[n-1]);
		while (k>0) do
		begin
			dp^ := sp^ + FZ_COMBINE(dp^, t);
		  inc(sp);
      inc(dp);
      k:=k-1;
		end;
    w:=w-1;
	end;
end;

procedure fz_paint_span( dp, sp:pbyte; n, w, alpha:integer);
begin
	if (alpha = 255) then
	begin
		case (n) of
		 1: fz_paint_span_1(dp, sp, w);
		 2: fz_paint_span_2(dp, sp, w);
		 4: fz_paint_span_4(dp, sp, w);
		 else fz_paint_span_N(dp, sp, n, w);
	  end;
	end
	else if (alpha > 0)  then
	begin
		case (n) of
		 2: fz_paint_span_2_with_alpha(dp, sp, w, alpha);
		 4: fz_paint_span_4_with_alpha(dp, sp, w, alpha);
		 else fz_paint_span_N_with_alpha(dp, sp, n, w, alpha); 
		end;
	end;
end;

//*  * Pixmap blending functions  */

procedure fz_paint_pixmap_with_rect(dst:pfz_pixmap_s;  src:pfz_pixmap_s;  alpha:integer; bbox: fz_bbox) ;
var
	sp, dp:pbyte;
	 x, y, w, h, n:integer;
begin
	assert(dst^.n = src^.n);

	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(dst));
	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(src));

	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;
	if ((w or h) = 0)  then
		exit;

	n := src^.n;
	sp := pointer(cardinal(src^.samples) + ((y - src^.y) * src^.w + (x - src^.x)) * src^.n);
	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * dst^.n);

	while (h>0) do
	begin
		fz_paint_span(dp, sp, n, w, alpha);
    inc(sp,src^.w * n);
    inc(dp,dst^.w * n);
    h:=h-1;
	end;
end;

procedure fz_paint_pixmap(dst:pfz_pixmap_s;  src:pfz_pixmap_s;  alpha:integer);
var
	sp, dp:pbyte;
	bbox:fz_bbox ;
	 x, y, w, h, n:integer;
begin
	assert(dst^.n = src^.n);

	bbox := fz_bound_pixmap(dst);
	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(src));

	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;
	if ((w or h) = 0)  then
		exit;

	n := src^.n;
	sp := pointer(cardinal(src^.samples) + ((y - src^.y) * src^.w + (x - src^.x)) * src^.n);
	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * dst^.n);

	while (h>0) do
	begin
		fz_paint_span(dp, sp, n, w, alpha);
    inc(sp, src^.w * n);
    inc(dp,  dst^.w * n);

    h:=h-1;
	end;
end;

procedure fz_paint_pixmap_with_mask(dst:pfz_pixmap_s;  src:pfz_pixmap_s; msk:pfz_pixmap_s);
var
	sp, dp, mp:pbyte;
	bbox:fz_bbox ;
	 x, y, w, h, n:integer;
begin
	assert(dst^.n = src^.n);
	assert(msk^.n = 1);

	bbox := fz_bound_pixmap(dst);
	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(src));
	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(msk));

	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;
	if ((w or h) = 0) then
		exit;

	n := src^.n;
	sp := pointer(cardinal(src^.samples) + ((y - src^.y) * src^.w + (x - src^.x)) * src^.n);
	mp := pointer(cardinal(msk^.samples) + ((y - msk^.y) * msk^.w + (x - msk^.x)) * msk^.n);
	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * dst^.n);

	while (h>0) do
	begin
		fz_paint_span_with_mask(dp, sp, mp, n, w);
    inc(sp,src^.w * n);
    inc(dp, dst^.w * n);
    inc(mp, msk^.w);

    h:=h-1;
	end;
end;


end.
