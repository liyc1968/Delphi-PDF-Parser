unit draw_meshss;

interface
uses
SysUtils,Math,digtypes,mylimits,base_error;
procedure fz_paint_shade(shade:pfz_shade_s; ctm: fz_matrix;dest: pfz_pixmap_s; bbox: fz_bbox);
implementation
 uses base_object_functions,fz_textx,fz_pixmapss,res_colorspace,draw_paints;

function clipx(val:single; ismax:integer; v1:psingle; v2:psingle; n:integer):integer;
var
	 t:single;
	 i,v1o,v2o:integer;
begin
   if ismax<>0 then
   begin
     if single_items(v1)[0] > val then
      v1o:=1
      else
      v1o:=0;
   end
   else
   begin
     if single_items(v1)[0] < val then
      v1o:=1
      else
      v1o:=0;
   end;

   if ismax<>0 then
   begin
     if single_items(v2)[0] > val then
      v2o:=1
      else
      v2o:=0;
   end
   else
   begin
     if single_items(v2)[0] < val then
      v2o:=1
      else
      v2o:=0;
   end;


	if (v1o + v2o = 0) then
  begin
		result:=INn;
    exit;
  end;
	if (v1o + v2o = 2) then
  begin
		result:= OUTt;
    exit;
  end;
	if (v2o<>0) then
	begin
		t := (val - single_items(v1)[0]) / (single_items(v2)[0] - single_items(v1)[0]);
		single_items(v2)[0] := val;
		single_items(v2)[1] := single_items(v1)[1] + t * (single_items(v2)[1] - single_items(v1)[1]);
		for i := 2 to n-1 do
			single_items(v2)[i] := single_items(v1)[i] + t * (single_items(v2)[i] - single_items(v1)[i]);
		result:= LEAVE;
    exit;
	end
	else
	begin
		t := (val - single_items(v2)[0]) / (single_items(v1)[0] - single_items(v2)[0]);
		single_items(v1)[0] := val;
		single_items(v1)[1] := single_items(v2)[1] + t * (single_items(v1)[1] - single_items(v2)[1]);
		for i := 2  to n-1 do
			single_items(v1)[i] := single_items(v2)[i] + t * (single_items(v1)[i] - single_items(v2)[i]);
		result:= ENTER;
    exit;
	end
end;

function  clipy( val:single; ismax:integer; v1:psingle; v2:psingle; n:integer):integer;
var
	 t:single;
	 i,v1o,v2o:integer;
begin
   if ismax<>0 then
   begin
     if single_items(v1)[1] > val then
      v1o:=1
      else
      v1o:=0;
   end
   else
   begin
     if single_items(v1)[1] < val then
      v1o:=1
      else
      v1o:=0;
   end;

   if ismax<>0 then
   begin
     if single_items(v2)[1] > val then
      v2o:=1
      else
      v2o:=0;
   end
   else
   begin
     if single_items(v2)[1] < val then
      v2o:=1
      else
      v2o:=0;
   end;
	if (v1o + v2o = 0) then
  begin
		result:= INn;
    exit;
  end;
	if (v1o + v2o = 2) then
  begin
		result:=OUTt;
    exit;
  end;
	if (v2o<>0) then
	begin
		t := (val - single_items(v1)[1]) / (single_items(v2)[1] - single_items(v1)[1]);
		single_items(v2)[0] := single_items(v1)[0] + t * (single_items(v2)[0] - single_items(v1)[0]);
		single_items(v2)[1] := val;
		for i := 2 to n-1 do
			single_items(v2)[i] := single_items(v1)[i] + t * (single_items(v2)[i] - single_items(v1)[i]);
		result:= LEAVE;
    exit;
	end
	else
	begin
		t := (val - single_items(v2)[1]) / (single_items(v1)[1] - single_items(v2)[1]);
		single_items(v1)[0] := single_items(v2)[0] + t * (single_items(v1)[0] - single_items(v2)[0]);
		single_items(v1)[1] := val;
		for i := 2 to n-1 do
			single_items(v1)[i] := single_items(v2)[i] + t * (single_items(v1)[i] - single_items(v2)[i]);
		result:= ENTER;
    exit;
	end;
end;

procedure copy_vert(dst:psingle;src:psingle; n:integer);
begin
	while (n<>0) do
  begin
     n:=n-1;
     dst^:=src^;
     inc(dst);
     inc(src);
  end;
end;

function  clip_poly(var src: sing2array;	 var dst: sing2array; len:integer; n:integer; val:single; isy:integer; ismax:integer):integer;
VAR
	cv1:ARRAY[0..MAXN-1] of single;
	cv2:ARRAY[0..MAXN-1] of single;
	 v1, v2, cp:integer;
	r:integer;
BEGIN
	v1 := len - 1;
	cp := 0;

	for v2 := 0 to len-1 do
	begin
		copy_vert(@cv1, @src[v1], n);
		copy_vert(@cv2, @src[v2], n);

		if (isy<>0) then
			r := clipy(val, ismax, @cv1, @cv2, n)
		else
			r := clipx(val, ismax, @cv1, @cv2, n);

		case r of
		INn:
      begin
			copy_vert(@dst[cp], @cv2, n);
      cp:=cp+1;
      end;
		LEAVE:
      begin
			copy_vert(@dst[cp], @cv2, n);
      cp:=cp+1;
      end;
		ENTER:
      begin
			copy_vert(@dst[cp], @cv1, n);
      cp:=cp+1;
			copy_vert(@dst[cp], @cv2, n);
      cp:=cp+1;
			end;
		end;
		v1 := v2;
	end;

  result:= cp;
end;

//* * gouraud shaded polygon scan conversion  */

procedure paint_scan(pix:pfz_pixmap_s; y, x1,  x2:integer; v1,v2:pinteger;n:integer);
var
	p:pbyte;
	 v:array[0..FZ_MAX_COLORS-1] of integer;
	dv:array[0..FZ_MAX_COLORS-1 ] of integer;
	w,k:integer;
	
begin
  w := x2 - x1;
  p := pointer(cardinal(pix^.samples) + ((y - pix^.y) * pix^.w + (x1 - pix^.x)) * pix^.n);
	assert(w >= 0);
	assert(y >= pix^.y);
	assert(y < pix^.y + pix^.h);
	assert(x1 >= pix^.x);
	assert(x2 <= pix^.x + pix^.w);

	if (w = 0) then
		exit;

	for k := 0 to  n-1 do
	begin
		v[k] := integer_items(v1)[k];
		dv[k] := trunc((integer_items(v2)[k] - integer_items(v1)[k]) / w);
	end;

	while (w<>0) do
	begin
		for k := 0 to n-1 do
		begin
			p^ := v[k] shr 16;
      inc(p);
      v[k]:= v[k]+dv[k]

		end;
    p^:=255;
    inc(p);
   w:=w-1;
	end;
end;

function find_next( var gel:integer2array_1;  len,  a:integer; s, e:pinteger; d:integer):integer;
var
b:integer;
begin

	while (true) do
	begin
		b := a + d;
		if (b = len) then
			b := 0;
		if (b = -1) then
			b := len - 1;

		if (gel[b][1] = gel[a][1]) then
		begin
			a := b;
			continue;
		end;

		if (gel[b][1] > gel[a][1])  then
		begin
			s^ := a;
			e^ := b;
			result:= 0;
      exit;
		end;

		result:= 1;
    exit;
	end;
end;



procedure load_edge( gel:integer2array_1;s, e:integer;  ael, del:pinteger; n:integer);
var
  swp, k, dy:integer;
begin
	if (gel[s][1] > gel[e][1])  then
	begin
		swp := s;
    s := e;
    e := swp;
	end;

	dy := gel[e][1] - gel[s][1];

	integer_items(ael)[0] := gel[s][0];
	integer_items(del)[0] := trunc((gel[e][0] - gel[s][0]) / dy);
	for k := 2 to n-1 do
	begin
		integer_items(ael)[k] := gel[s][k];
		integer_items(del)[k] :=trunc( (gel[e][k] - gel[s][k]) / dy);
	end;
end;

procedure step_edge(ael, del:pinteger;  n:integer);
var
	k:integer;
begin
	integer_items(ael)[0] :=integer_items(ael)[0]+ integer_items(del)[0];
	for k := 2 to n-1 do
		integer_items(ael)[k] :=integer_items(ael)[k]+ integer_items(del)[k];
end;

procedure fz_paint_triangle(pix:pfz_pixmap_s; av,bv, cv:psingle; n:integer; bbox: fz_bbox) ;

var
	poly:sing2array;
	temp:sing2array;
	 cx0 , cy0 ,cx1,cy1:single;


	 gel:integer2array_1;
	 ael:integer2array;
	 del:integer2array;
	 y, s0, s1, e0, e1:integer;
	 top, bot, len:integer;
   x0,x1:integer;
	i, k:integer;
begin
  cx0 := bbox.x0;
	cy0 := bbox.y0;
	 cx1 := bbox.x1;
	 cy1 := bbox.y1;
	copy_vert(@poly[0][0], av, n);
	copy_vert(@poly[1][0], bv, n);
	copy_vert(@poly[2][0], cv, n);

	len := clip_poly(poly, temp, 3, n, cx0, 0, 0);
	len := clip_poly(temp, poly, len, n, cx1, 0, 1);
	len := clip_poly(poly, temp, len, n, cy0, 1, 0);
	len := clip_poly(temp, poly, len, n, cy1, 1, 1);

	if (len < 3)  then
		exit;

	for i := 0 to len-1 do
	begin
    //outprintf( inttostr(i)+':'+inttostr(floor(poly[i][0])));
		gel[i][0] := floor(poly[i][0] + 0.5) * 65536; //* trunc and fix */
		gel[i][1] := floor(poly[i][1] + 0.5);	//* y is not fixpoint */
		for k := 2 to  n-1 do
			gel[i][k] := trunc(poly[i][k] * 65536);	//* fix with precision */
	end;
  bot := 0;
	top := bot;
	for i := 0 to len-1 do
	begin
		if (gel[i][1] < gel[top][1])  then
			top := i;
		if (gel[i][1] > gel[bot][1])  then
			bot := i;
	end;

	if (gel[bot][1] - gel[top][1] = 0) then
		exit;;

	y := gel[top][1];

	if (find_next(gel, len, top, @s0, @e0, 1))<>0  then
		exit;
	if (find_next(gel, len, top, @s1, @e1, -1))<>0 then
		exit;

	load_edge(gel, s0, e0, @ael[0], @del[0], n);
	load_edge(gel, s1, e1, @ael[1], @del[1], n);

	while (true) do
	begin
		x0 := ael[0][0] shr 16;
		x1 := ael[1][0] shr 16;

		if (ael[0][0] < ael[1][0]) then
			paint_scan(pix, y, x0, x1, pointer(cardinal(@ael[0][0])+2*sizeof(integer)), pointer(cardinal(@ael[1][0])+2*sizeof(integer)), n-2)
		else
			paint_scan(pix, y, x1, x0, pointer(cardinal(@ael[1][0])+2*sizeof(integer)), pointer(cardinal(@ael[0][0])+2*sizeof(integer)), n-2);

		step_edge(@ael[0][0], @del[0][0], n);
		step_edge(@ael[1][0], @del[1][0], n);
		y :=y+1;

		if (y >= gel[e0][1]) then
		begin
			if (find_next(gel, len, e0, @s0, @e0, 1)<>0)  then
				exit;
			load_edge(gel, s0, e0, @ael[0][0], @del[0][0], n);
		end;

		if (y >= gel[e1][1])then
		begin
			if (find_next(gel, len, e1, @s1, @e1, -1)<>0) then
				exit;
			load_edge(gel, s1, e1, @ael[1][0], @del[1][0], n);
	 end;
	end;
end;

procedure fz_paint_quad(pix:pfz_pixmap_s;
		p0:fz_point_s;  p1:fz_point_s; p2:fz_point_s; p3:fz_point_s;
		 c0, c1, c2, c3:single; n:integer; bbox: fz_bbox);
var
	 v:array[0..3,0..2] of single;
begin
	v[0][0] := p0.x;
	v[0][1] := p0.y;
	v[0][2] := c0;

	v[1][0] := p1.x;
	v[1][1] := p1.y;
	v[1][2] := c1;

	v[2][0] := p2.x;
	v[2][1] := p2.y;
	v[2][2] := c2;

	v[3][0] := p3.x;
	v[3][1] := p3.y;
	v[3][2] := c3;

	fz_paint_triangle(pix, @v[0], @v[2], @v[3], n, bbox);
	fz_paint_triangle(pix, @v[0], @v[3], @v[1], n, bbox);
end;

//*  * linear, radial and mesh painting  */



function fz_point_on_circle(p:fz_point_s; r, theta:single):fz_point_s;
begin
	p.x := p.x + cos(theta) * r;
	p.y := p.y + sin(theta) * r;

	result:= p;
end;
Function atan2(y : extended; x : extended): Extended;
Assembler;
asm
  fld [y]
  fld [x]
  fpatan
end;
procedure fz_paint_linear(shade:pfz_shade_s;ctm: fz_matrix; dest :pfz_pixmap_s ; bbox: fz_bbox);
var
	 p0, p1:fz_point_s;
  v0, v1, v2, v3:	fz_point_s;
	 e0, e1:fz_point_s;
	theta:single;
begin
	p0.x := single_items(shade^.mesh)[0];
	p0.y :=  single_items(shade^.mesh)[1];
	p0 := fz_transform_point(ctm, p0);

	p1.x :=  single_items(shade^.mesh)[3];
	p1.y :=  single_items(shade^.mesh)[4];
	p1 := fz_transform_point(ctm, p1);

	theta := atan2(p1.y - p0.y, p1.x - p0.x);
	theta := theta +M_PI * 0.5;

	v0 := fz_point_on_circle(p0, HUGENUM, theta);
	v1 := fz_point_on_circle(p1, HUGENUM, theta);
	v2 := fz_point_on_circle(p0, -HUGENUM, theta);
	v3 := fz_point_on_circle(p1, -HUGENUM, theta);

	fz_paint_quad(dest, v0, v1, v2, v3, 0, 255, 0, 255, 3, bbox);

	if (shade^.extend[0]<>0) then
	begin
		e0.x := v0.x - (p1.x - p0.x) * HUGENUM;
		e0.y := v0.y - (p1.y - p0.y) * HUGENUM;

		e1.x := v2.x - (p1.x - p0.x) * HUGENUM;
		e1.y := v2.y - (p1.y - p0.y) * HUGENUM;

		fz_paint_quad(dest, e0, e1, v0, v2, 0, 0, 0, 0, 3, bbox);
	end;

	if (shade^.extend[1]<>0) then
	begin
		e0.x := v1.x + (p1.x - p0.x) * HUGENUM;
		e0.y := v1.y + (p1.y - p0.y) * HUGENUM;

		e1.x := v3.x + (p1.x - p0.x) * HUGENUM;
		e1.y := v3.y + (p1.y - p0.y) * HUGENUM;

		fz_paint_quad(dest, e0, e1, v1, v3, 255, 255, 255, 255, 3, bbox);
	end;
end;

procedure fz_paint_annulus(ctm:fz_matrix ;
		 p0:fz_point_s;  r0:single; c0:single;
		 p1:fz_point; r1, c1:single;
		dest:pfz_pixmap_s; bbox:fz_bbox );
var
	 t0, t1, t2, t3, b0, b1, b2, b3:fz_point;
	 theta, step:single;
	 i:integer;
begin
	theta := atan2(p1.y - p0.y, p1.x - p0.x);
	step := M_PI * 2 / RADSEGS;

	for i := 0 to ((RADSEGS div 2)-1 ) do
	begin
  // outprintf('fz_paint_annulus:'+inttostr(ppppppppppp)+'::'+inttostr(i));

		t0 := fz_point_on_circle(p0, r0, theta + i * step);
		t1 := fz_point_on_circle(p0, r0, theta + i * step + step);
		t2 := fz_point_on_circle(p1, r1, theta + i * step);
		t3 := fz_point_on_circle(p1, r1, theta + i * step + step);
		b0 := fz_point_on_circle(p0, r0, theta - i * step);
		b1 := fz_point_on_circle(p0, r0, theta - i * step - step);
		b2 := fz_point_on_circle(p1, r1, theta - i * step);
		b3 := fz_point_on_circle(p1, r1, theta - i * step - step);

		t0 := fz_transform_point(ctm, t0);
		t1 := fz_transform_point(ctm, t1);
		t2 := fz_transform_point(ctm, t2);
		t3 := fz_transform_point(ctm, t3);
		b0 := fz_transform_point(ctm, b0);
		b1 := fz_transform_point(ctm, b1);
		b2 := fz_transform_point(ctm, b2);
		b3 := fz_transform_point(ctm, b3);

		fz_paint_quad(dest, t0, t1, t2, t3, c0, c0, c1, c1, 3, bbox);
		fz_paint_quad(dest, b0, b1, b2, b3, c0, c0, c1, c1, 3, bbox);
	end;
end;

procedure fz_paint_radial(shade:pfz_shade_s; ctm: fz_matrix ;dest: pfz_pixmap_s; bbox: fz_bbox);
var
	 p0, p1:fz_point_s;
	 r0, r1:single;
	 e:fz_point_s;
	 er, rs:single;
begin
	p0.x := single_items(shade^.mesh)[0];
	p0.y := single_items(shade^.mesh)[1];
	r0 := single_items(shade^.mesh)[2];

	p1.x := single_items(shade^.mesh)[3];
	p1.y := single_items(shade^.mesh)[4];
	r1 := single_items(shade^.mesh)[5];

	if (shade^.extend[0]<>0) then
	begin
		if (r0 < r1) then
			rs := r0 / (r0 - r1)
		else
			rs := -HUGENUM;

		e.x := p0.x + (p1.x - p0.x) * rs;
		e.y := p0.y + (p1.y - p0.y) * rs;
		er := r0 + (r1 - r0) * rs;

		fz_paint_annulus(ctm, e, er, 0, p0, r0, 0, dest, bbox);
	end;

	fz_paint_annulus(ctm, p0, r0, 0, p1, r1, 255, dest, bbox);

	if (shade^.extend[1]<>0) then
	begin
		if (r0 > r1) then
			rs := r1 / (r1 - r0)
		else
			rs := -HUGENUM;

		e.x := p1.x + (p0.x - p1.x) * rs;
		e.y := p1.y + (p0.y - p1.y) * rs;
		er := r1 + (r0 - r1) * rs;

		fz_paint_annulus(ctm, p1, r1, 255, e, er, 255, dest, bbox);
	end;
end;

procedure fz_paint_mesh(shade:pfz_shade_s; ctm: fz_matrix; dest:pfz_pixmap_s;bbox: fz_bbox);
var
	tri:array[0..2,0..MAXN-1] of single;
	p:fz_point_s;
	mesh:psingle;
	ntris:integer;
	 i, k:integer;
begin
	mesh := shade^.mesh;

	if (shade^.use_function<>0) then
		ntris := trunc(shade^.mesh_len / 9)
	else
		ntris := trunc(shade^.mesh_len / ((2 + shade^.colorspace^.n) * 3));

	while (ntris<>0) do
	begin
    ntris:=ntris-1;
		for k := 0 to 2 do
		begin
			p.x :=mesh^;
      inc(mesh);
			p.y := mesh^;
      inc(mesh);
			p := fz_transform_point(ctm, p);
			tri[k][0] := p.x;
			tri[k][1] := p.y;
			if (shade^.use_function<>0) then
      begin
				tri[k][2] := mesh^ * 255;
         inc(mesh);
      end
			else
			begin

				fz_convert_color(shade^.colorspace, mesh, dest^.colorspace, pointer(cardinal(@tri[k]) + 2));
				for i := 0 to dest^.colorspace^.n-1 do
					tri[k][i + 2] :=tri[k][i + 2] * 255;
          inc(mesh, shade^.colorspace^.n);

			end;
		end;
		fz_paint_triangle(dest, @tri[0], @tri[1], @tri[2], 2 + dest^.colorspace^.n, bbox);
	end;
end;

procedure fz_paint_shade(shade:pfz_shade_s; ctm: fz_matrix;dest: pfz_pixmap_s; bbox: fz_bbox);
var
	 clut:array[0..255,0..FZ_MAX_COLORS-1] of byte;
	 temp, conv:pfz_pixmap_s;
	color:array[0..FZ_MAX_COLORS-1] of single;
	 i, k:integer;
   s :pbyte;
	 d: pbyte;
	 len,v,a:integer;

begin
	ctm := fz_concat(shade^.matrix, ctm);

	if (shade^.use_function<>0) then
	begin
		for i := 0 to 255 do
		begin
			fz_convert_color(shade^.colorspace, @shade^.function1[i], dest^.colorspace, @color);
			for k := 0 to dest^.colorspace^.n-1 do
				clut[i][k] :=trunc( color[k] * 255);
			clut[i][k] := trunc(shade^.function1[i][shade^.colorspace^.n] * 255);
		end;
		conv := fz_new_pixmap_with_rect(dest^.colorspace, bbox);
		temp := fz_new_pixmap_with_rect(get_fz_device_gray(), bbox);
		fz_clear_pixmap(temp);
	end
	else
	begin
		temp := dest;
	end;

	case (shade^.type1) of
	FZ_LINEAR: fz_paint_linear(shade, ctm, temp, bbox);
	FZ_RADIAL: fz_paint_radial(shade, ctm, temp, bbox);
	FZ_MESH: fz_paint_mesh(shade, ctm, temp, bbox);
	end;

	if (shade^.use_function<>0) then
	begin
		s := temp^.samples;
		d := conv^.samples;
		len := temp^.w * temp^.h;
		while (len<>0) do
		begin
      len:=len-1;
			 v :=s^;
       inc(s);
			a := fz_mul255(s^, clut[v][conv^.n - 1]);
       inc(s);
			for k := 0 to conv^.n - 2 do
      begin
				d^ := fz_mul255(clut[v][k], a);
        inc(d);
      end;
      d^:=a;
      inc(d);
		
		end;
		fz_paint_pixmap(dest, conv, 255);
		fz_drop_pixmap(conv);
		fz_drop_pixmap(temp);
	end;
end;




 
end.
