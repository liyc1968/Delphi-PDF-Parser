unit draw_edge;

interface
uses
digtypes,math,base_error,SysUtils;

const BBOX_MIN= -(1 shl 20);
 BBOX_MAX =(1 shl 20);

var
fz_aa_hscale :integer= 17;
fz_aa_vscale :integer= 15;
fz_aa_scale :integer= 256;
fz_aa_level :integer= 8;
procedure fz_scan_convert(gel:pfz_gel_s;  eofill:integer;clip: fz_bbox; dst	:pfz_pixmap_s; color:pbyte) ;
function fz_bound_gel(gel:pfz_gel_s) :fz_bbox;
procedure fz_sort_gel(gel:pfz_gel_s);
function fz_get_aa_level():integer;
procedure fz_reset_gel(gel:pfz_gel_s; clip:fz_bbox );
procedure fz_insert_gel(gel:pfz_gel_s;  fx0,  fy0,  fx1,  fy1:single);
function fz_is_rect_gel(gel:pfz_gel_s):integer;
procedure fz_free_gel(gel:pfz_gel_s);
function fz_new_gel():pfz_gel_s;
implementation
uses base_object_functions,draw_paints;
function AA_SCALE(x:integer):integer;
begin
 result:=((x * fz_aa_scale) shr  8);
end;
//* divide and floor towards -inf */
function fz_idiv( a,  b:integer):integer;
begin
  if a<0 then
  result:=trunc((a - b + 1) / b)
  else
  result:=trunc(a / b);
end;


function fz_get_aa_level():integer;
begin
 result:=fz_aa_level;
end;

procedure fz_set_aa_level(level:integer);
begin

	if (level > 6)  then
	begin
		fz_aa_hscale := 17;
		fz_aa_vscale := 15;
		fz_aa_level := 8;
	end
	else if (level > 4)  then
	begin
		fz_aa_hscale := 8;
		fz_aa_vscale := 8;
		fz_aa_level := 6;
	end
	else if (level > 2) then
	begin
		fz_aa_hscale := 5;
		fz_aa_vscale := 3;
		fz_aa_level := 4;
	end
	else if (level > 0) then
	begin
		fz_aa_hscale := 2;
		fz_aa_vscale := 2;
		fz_aa_level := 2;
	end
	else
	begin
		fz_aa_hscale := 1;
		fz_aa_vscale := 1;
		fz_aa_level := 0;
	end;
	fz_aa_scale := $FF00 // (fz_aa_hscale * fz_aa_vscale);
end;

{*
 * Global Edge List -- list of straight path segments for scan conversion
 *
 * Stepping along the edges is with bresenham's line algorithm.
 *
 * See Mike Abrash -- Graphics Programming Black Book (notably chapter 40)
 */ }




function fz_new_gel():pfz_gel_s;
var
	gel:pfz_gel_s;
begin
	gel := fz_malloc(sizeof(fz_gel_s));
	gel^.cap := 512;
	gel^.len := 0;
	gel^.edges := fz_calloc(gel^.cap, sizeof(fz_edge_s));
  gel^.clip.y0 := BBOX_MAX;
	gel^.clip.x0 := gel^.clip.y0;
  gel^.clip.y1 := BBOX_MIN;
	gel^.clip.x1 := gel^.clip.y1;
  gel^.bbox.y0 := BBOX_MAX;
	gel^.bbox.x0 := gel^.bbox.y0;
  gel^.bbox.y1 := BBOX_MIN;
	gel^.bbox.x1 := gel^.bbox.y1;

	gel^.acap := 64;
	gel^.alen := 0;
	gel^.active := fz_calloc(gel^.acap, sizeof(pfz_edge_s));

	result:= gel;
end;

procedure fz_reset_gel(gel:pfz_gel_s; clip:fz_bbox );
begin
	if (fz_is_infinite_rect(clip)) then
	begin
    gel^.clip.y0 := BBOX_MAX;
		gel^.clip.x0 := gel^.clip.y0;
    gel^.clip.y1 := BBOX_MIN;
		gel^.clip.x1 := gel^.clip.y1;
	end
	else 
  begin
		gel^.clip.x0 := clip.x0 * fz_aa_hscale;
		gel^.clip.x1 := clip.x1 * fz_aa_hscale;
		gel^.clip.y0 := clip.y0 * fz_aa_vscale;
		gel^.clip.y1 := clip.y1 * fz_aa_vscale;
	end;
  gel^.bbox.y0 := BBOX_MAX;
	gel^.bbox.x0 := gel^.bbox.y0;
  gel^.bbox.y1 := BBOX_MIN;
	gel^.bbox.x1 := gel^.bbox.y1;

	gel^.len := 0;
end;

procedure fz_free_gel(gel:pfz_gel_s);
begin
	fz_free(gel^.active);
	fz_free(gel^.edges);
	fz_free(gel);
end;


function fz_bound_gel(gel:pfz_gel_s) :fz_bbox;
var
	 bbox:fz_bbox;
begin
	if (gel^.len = 0) then
  begin
		result:=fz_empty_bbox;
    exit;
  end;
	bbox.x0 := fz_idiv(gel^.bbox.x0, fz_aa_hscale);
	bbox.y0 := fz_idiv(gel^.bbox.y0, fz_aa_vscale);
	bbox.x1 := fz_idiv(gel^.bbox.x1, fz_aa_hscale) + 1;
	bbox.y1 := fz_idiv(gel^.bbox.y1, fz_aa_vscale) + 1;
	result:= bbox;
end;



//function  clip_lerp_y(v,m,x0,y0,x1,y1,t) clip_lerp_x(v,m,y0,x0,y1,x1,t):single

function clip_lerp_x( val, m, x0,  y0, x1, y1:integer; outp:pinteger):edge_kind_e;
var
v0out,v1out:INTEGER;

begin
  if m<>0 then
  BEGIN
    IF x0 > val THEN
     v0out:=1
    ELSE
     v0out:=0;
  END
  ELSE
  BEGIN
    IF x0 < val THEN
     v0out:=1
    ELSE
     v0out:=0;
  END;

  if m<>0 then
  BEGIN
    IF x1 > val THEN
     v1out:=1
    ELSE
     v1out:=0;
  END
  ELSE
  BEGIN
    IF x1 < val THEN
     v1out:=1
    ELSE
     v1out:=0;
  END;


	if (v0out + v1out = 0) THEN
  BEGIN
		RESULT:= INSIDE;
    EXIT;
  END;

	if (v0out + v1out = 2) THEN
   BEGIN
		RESULT:= OUTSIDE;
    EXIT;
   END;

	if (v1out<>0) THEN
	BEGIN
		outp^:= trunc(y0 + (y1 - y0) * (val - x0) / (x1 - x0));
		RESULT:= LEAVE;
    exit;
	END
	else
	begin
		outp^:=trunc( y1 + (y0 - y1) * (val - x1) / (x0 - x1));
		RESULT:= ENTER;
    exit;
	end;
end;

function  clip_lerp_y(val, m, x0,  y0, x1, y1:integer; outp:pinteger):edge_kind_e;
BEGIN
RESULT:=clip_lerp_x(val,m,y0,x0,y1,x1,outp);
END;

procedure fz_insert_gel_raw(gel:pfz_gel_s;  x0, y0, x1, y1:integer);
var
	 edge:pfz_edge_s;
	dx, dy:integer;
	winding:integer;
	width:integer;
	tmp:integer;
 begin
	if (y0 = y1) then
		exit;

	if (y0 > y1) then
  begin
		winding := -1;
		tmp := x0; x0 := x1; x1 := tmp;
		tmp := y0; y0 := y1; y1 := tmp;
	end
	else
		winding := 1;

	if (x0 < gel^.bbox.x0) then gel^.bbox.x0 := x0;
	if (x0 > gel^.bbox.x1) then gel^.bbox.x1 := x0;
	if (x1 < gel^.bbox.x0) then gel^.bbox.x0 := x1;
	if (x1 > gel^.bbox.x1) then gel^.bbox.x1 := x1;

	if (y0 < gel^.bbox.y0) then gel^.bbox.y0 := y0;
	if (y1 > gel^.bbox.y1) then gel^.bbox.y1 := y1;

	if (gel^.len + 1 = gel^.cap) then
  begin
		gel^.cap := gel^.cap + 512;
		gel^.edges := fz_realloc(gel^.edges, gel^.cap, sizeof(fz_edge_s));
	end;

	edge := @fz_edge_s_items(gel^.edges)[gel^.len];
  gel^.len:=gel^.len+1;
	dy := y1 - y0;
	dx := x1 - x0;
	width := ABS(dx);
  if  dx > 0 then
   edge^.xdir:=1
   else
   edge^.xdir:=-1;

	edge^.ydir := winding;
	edge^.x := x0;
	edge^.y := y0;
	edge^.h := dy;
	edge^.adj_down := dy;

	//* initial error term going l^.r and r^.l */
	if (dx >= 0) then
		edge^.e := 0
	else
		edge^.e := -dy + 1;

 //	/* y-major edge */
	if (dy >= width) then
  begin
		edge^.xmove := 0;
		edge^.adj_up := width;
	end

	//* x-major edge */
	else
  begin
		edge^.xmove := trunc((width / dy) * edge^.xdir);
		edge^.adj_up := width mod dy;
	end;
end;

procedure fz_insert_gel(gel:pfz_gel_s;  fx0,  fy0,  fx1,  fy1:single);
var
	x0, y0, x1, y1:integer;
	  v:integer;
    d:edge_kind_e;
begin
	fx0 := floor(fx0 * fz_aa_hscale);
	fx1 := floor(fx1 * fz_aa_hscale);
	fy0 := floor(fy0 * fz_aa_vscale);
	fy1 := floor(fy1 * fz_aa_vscale);

	x0 := trunc(CLAMP(fx0, BBOX_MIN, BBOX_MAX));
	y0 := trunc(CLAMP(fy0, BBOX_MIN, BBOX_MAX));
	x1 := trunc(CLAMP(fx1, BBOX_MIN, BBOX_MAX));
	y1 := trunc(CLAMP(fy1, BBOX_MIN, BBOX_MAX));

	d := clip_lerp_y(gel^.clip.y0, 0, x0, y0, x1, y1, @v);   //d := clip_lerp_y(gel^.clip.y0, 0, x0, y0, x1, y1, @v);
	if (d = OUTSIDE) then exit;
	if (d = LEAVE) then
  begin
    y1 := gel^.clip.y0;
    x1 := v;
  end;
	if (d = ENTER) then
  begin
   y0 := gel^.clip.y0;
   x0 := v;
  end;

	d := clip_lerp_y(gel^.clip.y1, 1, x0, y0, x1, y1, @v);
	if (d = OUTSIDE) then exit;;
	if (d = LEAVE) then
  begin
    y1 := gel^.clip.y1;
    x1 := v;
  end;
	if (d = ENTER)then
  begin
    y0 := gel^.clip.y1;
    x0 := v;
  end;

	d := clip_lerp_x(gel^.clip.x0, 0, x0, y0, x1, y1, @v);
	if (d = OUTSIDE) then
  begin
    x1 := gel^.clip.x0;
		x0 := x1;
	end;
	if (d = LEAVE) then
  begin
		fz_insert_gel_raw(gel, gel^.clip.x0, v, gel^.clip.x0, y1);
		x1 := gel^.clip.x0;
		y1 := v;
	end;
	if (d = ENTER) then
  begin
		fz_insert_gel_raw(gel, gel^.clip.x0, y0, gel^.clip.x0, v);
		x0 := gel^.clip.x0;
		y0 := v;
	end;

	d := clip_lerp_x(gel^.clip.x1, 1, x0, y0, x1, y1, @v);
	if (d = OUTSIDE) then
  begin
    x1 := gel^.clip.x1;
		x0 := x1;
	end;
	if (d = LEAVE) then
  begin
		fz_insert_gel_raw(gel, gel^.clip.x1, v, gel^.clip.x1, y1);
		x1 := gel^.clip.x1;
		y1 := v;
	end;
	if (d = ENTER) then
  begin
		fz_insert_gel_raw(gel, gel^.clip.x1, y0, gel^.clip.x1, v);
		x0 := gel^.clip.x1;
		y0 := v;
	end;
//  outprintf('gel:'+'x0:'+inttostr(x0)+' '+ 'y0:'+inttostr(y0)+ ' '+ 'x1:'+inttostr(x1)+' '+ 'y1:'+inttostr(y1) );
	fz_insert_gel_raw(gel, x0, y0, x1, y1);
end;

procedure fz_sort_gel(gel:pfz_gel_s);
var
	a:pfz_edge_s; // *a = gel^.edges;
	n:integer;

	h, i, k:integer;
	t:fz_edge_s ;
begin
  a := gel^.edges;
  n := gel^.len;
	h := 1;
	if (n < 14) then
  begin
		h := 1;
	end
	else
  begin
		while (h < n) do
			h := 3 * h + 1;
		h:=trunc(h / 3);
		h:=trunc(h / 3);
	end;

	while (h > 0) do
	begin
		for i := 0 to n-1 do
    begin
      t := fz_edge_s_items(a)[i];
			k := i - h;
		 //	/* TODO: sort on y major, x minor */
			while (k >= 0) and (fz_edge_s_items(a)[k].y > t.y) do
      begin
				fz_edge_s_items(a)[k + h] := fz_edge_s_items(a)[k];
				k:=k - h;
			end;
			fz_edge_s_items(a)[k + h] := t;
		end;

		h:=trunc(h / 3);
	end;
end;

function fz_is_rect_gel(gel:pfz_gel_s):integer;
var
  a,b:pfz_edge_s;
begin
	//* a rectangular path is converted into two vertical edges of identical height */
	if (gel^.len = 2) then
	begin
		// a := pointer(cardinal(gel^.edges) + 0);
	//	 b :=  pointer(cardinal(gel^.edges) + 1);;
     a := gel^.edges;
		 b :=  gel^.edges;
     inc(b);

     if  ((a^.y = b^.y) and ( a^.h = b^.h) and
			(a^.xmove = 0) and (a^.adj_up = 0) and
			(b^.xmove = 0) and ( b^.adj_up = 0)) then
      begin
		   result:=1   ;
       exit;
      end;
	end;
	result:=0;
end;

//*  * Active Edge List -- keep track of active edges while sweeping  */

procedure sort_active( a:ppfz_edge_s; n:integer);
var
	 h, i, k:integer;
	 t:pfz_edge_s;
begin
	h := 1;
	if (n < 14) then
  begin
		h := 1;
	end
	else
  begin
		while (h < n) do
			h := 3 * h + 1;
		h :=trunc(h/ 3);
		h :=trunc(h/ 3);
	end;

	while (h > 0) do
	begin
		for i := 0 to n-1 do
    begin
			t := pfz_edge_s_items(a)[i];
			k := i - h;
			while (k >= 0) and (pfz_edge_s_items(a)[k]^.x > t^.x) do
      begin
				pfz_edge_s_items(a)[k + h] := pfz_edge_s_items(a)[k];
        k:=k-h;
 			end;
			pfz_edge_s_items(a)[k + h] := t;
		end;

		h :=trunc(h/ 3);
	end;
end;

procedure insert_active(gel:pfz_gel_s;  y:integer; e:pinteger);
var
newactive:ppfz_edge_s;
newcap:integer;
begin
	//* insert edges that start here */
	while (e^ < gel^.len) and (fz_edge_s_items(gel^.edges)[e^].y = y) do
  begin
		if (gel^.alen + 1 = gel^.acap) then
    begin
			newcap := gel^.acap + 64;
			newactive := fz_realloc(gel^.active, newcap, sizeof(pfz_edge_s));
			gel^.active := newactive;
			gel^.acap := newcap;
		end;
		pfz_edge_s_items(gel^.active)[gel^.alen] :=pointer(cardinal(@fz_edge_s_items(gel^.edges)[e^]));
    gel^.alen:=gel^.alen+1;
    e^:=e^+1;
	end;

	//* shell-sort the edges by increasing x */
	sort_active(gel^.active, gel^.alen);
end;

procedure advance_active(gel:pfz_gel_s);
var
	edge:pfz_edge_s;
	i:integer;
begin
  i:=0;
	while (i < gel^.alen) do
	begin
		edge := pfz_edge_s_items(gel^.active)[i];

		edge^.h :=edge^.h-1;

		//* terminator! */
		if (edge^.h = 0) then
    begin
      gel^.alen:=gel^.alen-1;
			pfz_edge_s_items(gel^.active)[i] :=pfz_edge_s_items(gel^.active)[gel^.alen];
		end

		else
    begin
			edge^.x :=edge^.x+ edge^.xmove;
			edge^.e :=edge^.e+ edge^.adj_up;
			if (edge^.e > 0) then
      begin
				edge^.x :=edge^.x+ edge^.xdir;
				edge^.e :=edge^.e-edge^.adj_down;
	  	end;
			i:=i+1;
		end;
	end;
end;

//*  * Anti-aliased scan conversion.  */

procedure add_span_aa(list:pinteger;  x0, x1, xofs:integer) ;
var
	x0pix, x0sub:integer;
	x1pix, x1sub:integer;
begin
	if (x0 = x1) then
		exit;

 //	/* x between 0 and width of bbox */
	x0 :=x0-xofs;
	x1:= x1-xofs;

	x0pix := trunc(x0 / fz_aa_hscale);
	x0sub := x0 mod fz_aa_hscale;
	x1pix := trunc(x1 / fz_aa_hscale);
	x1sub := x1 mod fz_aa_hscale;

	if (x0pix = x1pix) then
	begin
		integer_items(list)[x0pix]:=integer_items(list)[x0pix]+x1sub - x0sub;
		integer_items(list)[x0pix+1] :=integer_items(list)[x0pix+1]+ x0sub - x1sub;
	end

	else
	begin
		integer_items(list)[x0pix] :=integer_items(list)[x0pix]+ fz_aa_hscale - x0sub;
		integer_items(list)[x0pix+1] :=integer_items(list)[x0pix+1]+ x0sub;
		integer_items(list)[x1pix] :=integer_items(list)[x1pix]+ x1sub - fz_aa_hscale;
		integer_items(list)[x1pix+1] :=integer_items(list)[x1pix+1] -x1sub;
	end;
end;

procedure non_zero_winding_aa(gel:Pfz_gel_S; list:PINTEGER; xofs:integer);
var
	winding,x,i:integer;
begin
  winding := 0;
	x := 0;

	for i := 0 to gel^.alen-1 do
	begin
		if (winding=0) and (winding + pfz_edge_s_items(gel^.active)[i]^.ydir<>0) then
			x := pfz_edge_s_items(gel^.active)[i]^.x;
		if (winding<>0) and (winding + pfz_edge_s_items(gel^.active)[i]^.ydir=0) then
			add_span_aa(list, x, pfz_edge_s_items(gel^.active)[i]^.x, xofs);
		winding :=winding+ pfz_edge_s_items(gel^.active)[i]^.ydir;
 end;
end;

procedure even_odd_aa(gel:Pfz_gel_S; list:pinteger; xofs:integer) ;
var
	even, x, i:integer;
begin
  even := 0;
  x := 0;

	for i := 0 to gel^.alen-1 do
	begin
		if (even=0) then
			x := pfz_edge_s_items(gel^.active)[i]^.x
		else
			add_span_aa(list, x, pfz_edge_s_items(gel^.active)[i]^.x, xofs);
    if even=1 then
    even:=0
    else
    even:=1;

	end;
end;

procedure undelta_aa(outP:PBYTE; inp:pinteger;n:integer);
var
d:integer;
begin
	d := 0;

	while (n>0) do
	begin
    d:=d+inp^;
    inc(inp);
    outp^:=AA_SCALE(d);
	  inc(outp);
    n:=n-1;
	end;
end;

procedure blit_aa(dst:pfz_pixmap_s; x:integer; y:integer; mp:pbyte; w:integer; color:pbyte);
var
	dp:pbyte;
begin
	dp := pointer(cardinal(dst^.samples) + ( (y - dst^.y) * dst^.w + (x - dst^.x) ) * dst^.n);
	if (color<>nil) then
		fz_paint_span_with_color(dp, mp, dst^.n, w, color)
	else
		fz_paint_span(dp, mp, 1, w, 255);
end;

procedure fz_scan_convert_aa(gel:pfz_gel_s; eofill:integer;clip: fz_bbox ;	dst:pfz_pixmap_s; color:pbyte);
var
	alphas:pbyte;
  deltas:pinteger;
	y, e:integer;
	yd, yc:integer;
  xmin,xmax,xofs, skipx,clipn:integer;

begin

	xmin := fz_idiv(gel^.bbox.x0, fz_aa_hscale);
	xmax := fz_idiv(gel^.bbox.x1, fz_aa_hscale) + 1;

	xofs := xmin * fz_aa_hscale;

	skipx := clip.x0 - xmin;
	clipn := clip.x1 - clip.x0;

	if (gel^.len = 0) then
  exit;

	assert(clip.x0 >= xmin);
	assert(clip.x1 <= xmax);

	alphas := fz_malloc(xmax - xmin + 1);
	deltas := fz_malloc((xmax - xmin + 1) * sizeof(integer));
	fillchar(deltas^, (xmax - xmin + 1) * sizeof(integer), 0);

	e := 0;
	y := fz_edge_s_items(gel^.edges)[0].y;
	yc := fz_idiv(y, fz_aa_vscale);
	yd := yc;

	while (gel^.alen > 0) or (e < gel^.len) do
	begin
		yc := fz_idiv(y, fz_aa_vscale);
		if (yc <> yd) then
		begin
			if (yd >= clip.y0) and (yd < clip.y1) then
			begin
				undelta_aa(alphas, deltas, skipx + clipn);
				blit_aa(dst, xmin + skipx, yd, pointer(cardinal(alphas)+ skipx), clipn, color);
				fillchar(deltas^, (skipx + clipn) * sizeof(integer), 0);
			end;
		end;
		yd := yc;

		insert_active(gel, y, @e);

		if (yd >= clip.y0) and (yd < clip.y1) then
		begin
			if (eofill<>0) then
				even_odd_aa(gel, deltas, xofs)
			else
				non_zero_winding_aa(gel, deltas, xofs);
	 end;

		advance_active(gel);

		if (gel^.alen > 0)  then
			y:=y+1
		else if (e < gel^.len)then
			y := fz_edge_s_items(gel^.edges)[e].y;
	end;

	if (yd >= clip.y0) and (yd < clip.y1) then
	begin
		undelta_aa(alphas, deltas, skipx + clipn);
		blit_aa(dst, xmin + skipx, yd, pointer(cardinal(alphas) + skipx), clipn, color);
	end;

	fz_free(deltas);
	fz_free(alphas);
end;

//* * Sharp (not anti-aliased) scan conversion  */

procedure blit_sharp(x0, x1, y:integer;	 clip:fz_bbox; dst:pfz_pixmap_s; color:pbyte) ;
var
	dp:pbyte;
begin
	x0 := CLAMP(x0, dst^.x, dst^.x + dst^.w);
	x1 := CLAMP(x1, dst^.x, dst^.x + dst^.w);
	if (x0 < x1) then
	begin
		dp := pointer(cardinal(dst^.samples) + ( (y - dst^.y) * dst^.w + (x0 - dst^.x) ) * dst^.n);
		if (color<>nil) then
			fz_paint_solid_color(dp, dst^.n, x1 - x0, color)
		else
			fz_paint_solid_alpha(dp, x1 - x0, 255);
	end;
end;

procedure non_zero_winding_sharp(gel:pfz_gel_s; y:integer;clip:	fz_bbox ;dst: pfz_pixmap_s; color:pbyte);
var
	winding, x,i:integer;
begin
  winding := 0;
   x := 0;
	for i := 0 to gel^.alen-1 do
	begin
		if (winding=0) and  ((winding + pfz_edge_s_items(gel^.active)[i]^.ydir)<>0) then
			x :=pfz_edge_s_items(gel^.active)[i]^.x ;
		if (winding<>0) and ((winding + pfz_edge_s_items(gel^.active)[i]^.ydir)=0) then
			blit_sharp(x, pfz_edge_s_items(gel^.active)[i]^.x, y, clip, dst, color);
		winding:= winding+pfz_edge_s_items(gel^.active)[i]^.ydir;
	end;
end;

procedure even_odd_sharp(gel:pfz_gel_s;  y:integer;clip:	fz_bbox;dst:pfz_pixmap_s;color:pbyte) ;
var
even,x,i:integer;
begin
  even := 0;
	x := 0;
	for i := 0 to gel^.alen-1 do
	begin
		if (even=0) then
			x := pfz_edge_s_items(gel^.active)[i]^.x
		else
			blit_sharp(x, pfz_edge_s_items(gel^.active)[i]^.x, y, clip, dst, color);
		if even=1 then
    even:=0
    else
    even:=1;
	end;
end;

procedure  fz_scan_convert_sharp(gel:pfz_gel_s; eofill:integer; clip:fz_bbox;  dst:pfz_pixmap_s;color:pbyte);
var
e,y:integer;
begin
	e := 0;
	y := fz_edge_s_items(gel^.edges)[0].y;

	while (gel^.alen > 0) or (e < gel^.len) do
	begin
		insert_active(gel, y, @e);

		if (y >= clip.y0) and (y < clip.y1) then
		begin
			if (eofill<>0) then
				even_odd_sharp(gel, y, clip, dst, color)
			else
				non_zero_winding_sharp(gel, y, clip, dst, color);
		end;

		advance_active(gel);

		if (gel^.alen > 0) then
      y:=y+1

		else if (e < gel^.len)  then
			y := fz_edge_s_items(gel^.edges)[e].y;
	end;
end;

procedure fz_scan_convert(gel:pfz_gel_s;  eofill:integer;clip: fz_bbox; dst	:pfz_pixmap_s; color:pbyte) ;
begin
	if (fz_aa_level > 0)  then
		fz_scan_convert_aa(gel, eofill, clip, dst, color)
	else
		fz_scan_convert_sharp(gel, eofill, clip, dst, color);
end;


end.
