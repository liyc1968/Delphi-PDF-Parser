unit draw_pathss;

interface
uses  SysUtils, Math,mylimits,digtypes,base_error;
procedure  fz_flatten_dash_path(gel:pfz_gel_s; path:Pfz_path_s; stroke:pfz_stroke_state_s; ctm: fz_matrix ; flatness:single; linewidth:single);
procedure fz_flatten_stroke_path(gel:Pfz_gel_s; path:pfz_path_s;  stroke:pfz_stroke_state_s;ctm: fz_matrix; flatness:single; linewidth:single);
procedure fz_flatten_fill_path(gel:pfz_gel_s; path:pfz_path_s; ctm: fz_matrix; flatness:single);
implementation
uses fz_pixmapss,base_object_functions,draw_paints,draw_blendss,draw_edge,digcommtype;


procedure line(gel:pfz_gel_s; ctm:pfz_matrix_s;  x0,  y0,  x1,  y1:single);
var
 tx0,ty0,tx1,ty1:single;
begin
	tx0 := ctm^.a * x0 + ctm^.c * y0 + ctm^.e;
	ty0 := ctm^.b * x0 + ctm^.d * y0 + ctm^.f;
	tx1 := ctm^.a * x1 + ctm^.c * y1 + ctm^.e;
	ty1 := ctm^.b * x1 + ctm^.d * y1 + ctm^.f;
	fz_insert_gel(gel, tx0, ty0, tx1, ty1);
end;

procedure
bezier(gel:pfz_gel_s; ctm:pfz_matrix_s;  flatness, xa, ya, xb, yb, xc,  yc, xd,  yd:single;  depth:integer);
var
	 dmax:single;
	 xab, yab:single;
	 xbc, ybc:single;
	 xcd, ycd:single;
	 xabc, yabc:single;
	 xbcd, ybcd:single;
	 xabcd, yabcd:single;
begin
	//* termination check */
	dmax := ABS(xa - xb);
	dmax := MAX(dmax, ABS(ya - yb));
	dmax := MAX(dmax, ABS(xd - xc));
	dmax := MAX(dmax, ABS(yd - yc));
	if (dmax < flatness) or (depth >= MAX_DEPTH) then
	begin
		line(gel, ctm, xa, ya, xd, yd);
		exit;
	end;

	xab := xa + xb;
	yab := ya + yb;
	xbc := xb + xc;
	ybc := yb + yc;
	xcd := xc + xd;
	ycd := yc + yd;

	xabc := xab + xbc;
	yabc := yab + ybc;
	xbcd := xbc + xcd;
	ybcd := ybc + ycd;

	xabcd := xabc + xbcd;
	yabcd := yabc + ybcd;

	xab :=xab* 0.5;
  yab :=yab* 0.5;
	xbc :=xbc* 0.5;
  ybc :=ybc* 0.5;
	xcd :=xcd* 0.5;
  ycd :=ycd* 0.5;
  xabc :=xabc* 0.25;
  yabc :=yabc* 0.25;
	xbcd :=xbcd* 0.25;
  ybcd :=ybcd* 0.25;
  xabcd :=xabcd* 0.125;
  yabcd :=yabcd* 0.125;

	bezier(gel, ctm, flatness, xa, ya, xab, yab, xabc, yabc, xabcd, yabcd, depth + 1);
	bezier(gel, ctm, flatness, xabcd, yabcd, xbcd, ybcd, xcd, ycd, xd, yd, depth + 1);
end;

procedure fz_flatten_fill_path(gel:pfz_gel_s; path:pfz_path_s; ctm: fz_matrix; flatness:single);
var
	x1, y1, x2, y2, x3, y3:single;
  cx,cy,bx,by:single;
	i:integer;
  k:fz_path_item_kind_e;
begin
  cx := 0;
	cy := 0;
	bx := 0;
	by := 0;
	i := 0;

	while (i < path^.len)  do
	begin
    k:= fz_path_item_s_itmes(path^.items)[i].k;
    i:=i+1;

		case k of
    FZ_MOVETO1:
      begin
			//* implicit closepath before moveto */
			if ((i<>0) and ((cx <> bx) or (cy <> by))) then
				line(gel, @ctm, cx, cy, bx, by);
			x1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			y1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
      bx := x1;
			cx := bx;
      by := y1;
			cy := by;
      end;

		FZ_LINETO1:
      begin
			x1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			y1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			line(gel, @ctm, cx, cy, x1, y1);
			cx := x1;
			cy := y1;
			end;

		FZ_CURVETO1:
      begin
			x1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			y1 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			x2 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			y2 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			x3 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			y3 := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			bezier(gel, @ctm, flatness, cx, cy, x1, y1, x2, y2, x3, y3, 0);
			cx := x3;
			cy := y3;
			end;

		FZ_CLOSE_PATH1:
      begin
			line(gel, @ctm, cx, cy, bx, by);
			cx := bx;
			cy := by;
			end;
		end;
	end;

	if (i<>0) and ((cx <> bx) or (cy <> by))   then
		line(gel, @ctm, cx, cy, bx, by);
end;



procedure fz_add_line(s:psctx_s; x0, y0, x1, y1:single);
var

tx0,tx1,ty0,ty1:single;
begin
	tx0 := s^.ctm^.a * x0 + s^.ctm^.c * y0 + s^.ctm^.e;
	ty0 := s^.ctm^.b * x0 + s^.ctm^.d * y0 + s^.ctm^.f;
	tx1 := s^.ctm^.a * x1 + s^.ctm^.c * y1 + s^.ctm^.e;
	ty1 := s^.ctm^.b * x1 + s^.ctm^.d * y1 + s^.ctm^.f;
	fz_insert_gel(s^.gel, tx0, ty0, tx1, ty1);
end;

procedure fz_add_arc(s:psctx_s;xc,yc,x0,y0,x1,y1:single);
var
	 th0, th1, r:single;
	 theta:single;
	 ox, oy, nx, ny:single;
	 n, i:integer;
begin
	r := abs(s^.linewidth);
	theta := 2 * M_SQRT2 * sqrt(s^.flatness / r);
	th0 := atan2(y0, x0);
	th1 := atan2(y1, x1);

	if (r > 0)  then
	begin
		if (th0 < th1) then
			th0 :=th0+ M_PI * 2;
		n := ceil((th0 - th1) / theta);
	end
	else
	begin
		if (th1 < th0) then
			th1 :=th1 + M_PI * 2;
		n := ceil((th1 - th0) / theta);
	end;

	ox := x0;
	oy := y0;
	for i := 1 to n-1 do
	begin
		theta := th0 + (th1 - th0) * i / n;
		nx := cos(theta) * r;
		ny := sin(theta) * r;
		fz_add_line(s, xc + ox, yc + oy, xc + nx, yc + ny);
		ox := nx;
		oy := ny;
	end;

	fz_add_line(s, xc + ox, yc + oy, xc + x1, yc + y1);
end;

procedure
fz_add_line_stroke(s:psctx_s;  a,  b:fz_point_s);
var
dx,dy,scale,dlx,dly:single;
begin
	dx := b.x - a.x;
	dy := b.y - a.y;
	scale := s^.linewidth / sqrt(dx * dx + dy * dy);
	dlx := dy * scale;
	dly := -dx * scale;
	fz_add_line(s, a.x - dlx, a.y - dly, b.x - dlx, b.y - dly);
	fz_add_line(s, b.x + dlx, b.y + dly, a.x + dlx, a.y + dly);
end;

procedure
fz_add_line_join(s:psctx_s;a :fz_point_s ; b:fz_point_s; c:fz_point_s);
var
	 miterlimit,linewidth:single;

	 linejoin:integer;
	 dx0, dy0:single;
	 dx1, dy1:single;
	 dlx0, dly0:single;
	 dlx1, dly1:single;
	 dmx, dmy:single;
	 dmr2:single;
	 scale:single;
	 cross:single;
begin

  miterlimit := s^.miterlimit;
	linewidth := s^.linewidth;
	linejoin := s^.linejoin;

	dx0 := b.x - a.x;
	dy0 := b.y - a.y;

	dx1 := c.x - b.x;
	dy1 := c.y - b.y;

	if (dx0 * dx0 + dy0 * dy0 < FLT_EPSILON) then
		linejoin := BEVEL;
	if (dx1 * dx1 + dy1 * dy1 < FLT_EPSILON)  then
		linejoin:= BEVEL;

	scale := linewidth / sqrt(dx0 * dx0 + dy0 * dy0);
	dlx0 := dy0 * scale;
	dly0 := -dx0 * scale;

	scale := linewidth / sqrt(dx1 * dx1 + dy1 * dy1);
	dlx1 := dy1 * scale;
	dly1 := -dx1 * scale;

	cross := dx1 * dy0 - dx0 * dy1;

	dmx := (dlx0 + dlx1) * 0.5;
	dmy := (dly0 + dly1) * 0.5;
	dmr2 := dmx * dmx + dmy * dmy;

	if (cross * cross < FLT_EPSILON) and (dx0 * dx1 + dy0 * dy1 >= 0) then
		linejoin := BEVEL;

	if (linejoin = MITER) then
		if (dmr2 * miterlimit * miterlimit < linewidth * linewidth) then
			linejoin := BEVEL;

	if (linejoin = BEVEL) then
	begin
		fz_add_line(s, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
		fz_add_line(s, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
	end;

	if (linejoin = MITER) then
	begin
		scale := linewidth * linewidth / dmr2;
		dmx :=dmx * scale;
		dmy :=dmy * scale;

		if (cross < 0) then
		begin
			fz_add_line(s, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
			fz_add_line(s, b.x + dlx1, b.y + dly1, b.x + dmx, b.y + dmy);
			fz_add_line(s, b.x + dmx, b.y + dmy, b.x + dlx0, b.y + dly0);
		end
		else
		begin
			fz_add_line(s, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
			fz_add_line(s, b.x - dlx0, b.y - dly0, b.x - dmx, b.y - dmy);
			fz_add_line(s, b.x - dmx, b.y - dmy, b.x - dlx1, b.y - dly1);
		end;
	end;

	if (linejoin = ROUND) then
	begin
		if (cross < 0) then
		begin
			fz_add_line(s, b.x - dlx0, b.y - dly0, b.x - dlx1, b.y - dly1);
			fz_add_arc(s, b.x, b.y, dlx1, dly1, dlx0, dly0);
		end
		else
		begin
			fz_add_line(s, b.x + dlx1, b.y + dly1, b.x + dlx0, b.y + dly0);
			fz_add_arc(s, b.x, b.y, -dlx0, -dly0, -dlx1, -dly1);
		end;
	end;
end;

procedure
fz_add_line_cap(s:psctx_s;a: fz_point_s; b: fz_point_s; linecap:integer);
var
	flatness,linewidth,dx , dy ,scale ,dlx ,dly:single;
  theta,cth,sth,nx,ny:single;
  mx,my:single;
  ox,oy:single;
  i,n:integer;
begin
  flatness := s^.flatness;
	linewidth := s^.linewidth;

  dx := b.x - a.x;
	dy := b.y - a.y;

	scale := linewidth / sqrt(dx * dx + dy * dy);
	dlx := dy * scale;
	dly := -dx * scale;
	if (linecap = BUTT) then
		fz_add_line(s, b.x - dlx, b.y - dly, b.x + dlx, b.y + dly);

	if (linecap = ROUND) then
	begin
		n := ceil(M_PI / (2.0 * M_SQRT2 * sqrt(flatness / linewidth)));
		ox := b.x - dlx;
		oy := b.y - dly;
		for i := 1 to n-1 do
		begin
			theta := M_PI * i / n;
			cth := cos(theta);
			sth := sin(theta);
			nx := b.x - dlx * cth - dly * sth;
			ny := b.y - dly * cth + dlx * sth;
			fz_add_line(s, ox, oy, nx, ny);
			ox := nx;
			oy := ny;
		end;
		fz_add_line(s, ox, oy, b.x + dlx, b.y + dly);
	end;

	if (linecap = SQUARE) then
	begin
		fz_add_line(s, b.x - dlx, b.y - dly,
			b.x - dlx - dly, b.y - dly + dlx);
		fz_add_line(s, b.x - dlx - dly, b.y - dly + dlx,
			b.x + dlx - dly, b.y + dly + dlx);
		fz_add_line(s, b.x + dlx - dly, b.y + dly + dlx,
			b.x + dlx, b.y + dly);
	end;

	if (linecap = TRIANGLE) then
	begin
		 mx := -dly;
		 my := dlx;
		fz_add_line(s, b.x - dlx, b.y - dly, b.x + mx, b.y + my);
		fz_add_line(s, b.x + mx, b.y + my, b.x + dlx, b.y + dly);
	end;
end;

procedure fz_add_line_dot(s:psctx_s;  a:fz_point_s);
var
	 flatness,	linewidth:single;
	n:integer;
	ox,oy:single;
	i:integer;
  theta,cth,sth,nx,ny:single;
begin
  flatness := s^.flatness;
	linewidth := s^.linewidth;
	n := ceil(M_PI / (M_SQRT2 * sqrt(flatness / linewidth)));
	ox := a.x - linewidth;
	oy := a.y;

	for i := 1 to n-1 do
	begin
		theta := M_PI * 2 * i / n;
		cth := cos(theta);
		sth := sin(theta);
		nx := a.x - cth * linewidth;
		ny := a.y + sth * linewidth;
		fz_add_line(s, ox, oy, nx, ny);
		ox := nx;
		oy := ny;
	end;

	fz_add_line(s, ox, oy, a.x - linewidth, a.y);
end;

procedure 
fz_stroke_flush(s:psctx_s; start_cap:integer;end_cap:integer);
begin
	if (s^.sn = 2) then
	begin
		fz_add_line_cap(s, s^.beg[1], s^.beg[0], start_cap);
		fz_add_line_cap(s, s^.seg[0], s^.seg[1], end_cap);
	end
	else if (s^.dot<>0) then
	begin
		fz_add_line_dot(s, s^.beg[0]);
	end;
end;

procedure
fz_stroke_moveto(s:psctx_s;cur: fz_point_s);
begin
	s^.seg[0] := cur;
	s^.beg[0] := cur;
	s^.sn := 1;
	s^.bn := 1;
	s^.dot := 0;
end;

procedure
fz_stroke_lineto(s:psctx_s;cur: fz_point_s);
var
dx,dy:single;
begin
	dx := cur.x - s^.seg[s^.sn-1].x;
	dy := cur.y - s^.seg[s^.sn-1].y;

	if (dx * dx + dy * dy < FLT_EPSILON) then
	begin
		if (s^.cap = ROUND) or (s^.dash_list<>nil)  then
			s^.dot := 1;
		exit;
	end;

	fz_add_line_stroke(s, s^.seg[s^.sn-1], cur);

	if (s^.sn = 2) then
	begin
		fz_add_line_join(s, s^.seg[0], s^.seg[1], cur);
		s^.seg[0] := s^.seg[1];
		s^.seg[1] := cur;
	end;

	if (s^.sn = 1) then
  begin
		s^.seg[s^.sn] := cur;
    s^.sn:=s^.sn+1;
  end;
	if (s^.bn = 1)then
  begin
		s^.beg[s^.bn] := cur;
    s^.bn:=s^.bn+1;
  end;
end;

procedure
fz_stroke_closepath(s:psctx_s)  ;
begin
	if (s^.sn = 2) then
	begin
		fz_stroke_lineto(s, s^.beg[0]);
		if (s^.seg[1].x = s^.beg[0].x) and (s^.seg[1].y = s^.beg[0].y)  then
			fz_add_line_join(s, s^.seg[0], s^.beg[0], s^.beg[1])
		else
			fz_add_line_join(s, s^.seg[1], s^.beg[0], s^.beg[1]);
	end
	else if (s^.dot<>0) then
	begin
		fz_add_line_dot(s, s^.beg[0]);
	end;

	s^.seg[0] := s^.beg[0];
	s^.bn := 1;
	s^.sn := 1;
	s^.dot := 0;
end;

procedure fz_stroke_bezier(s:psctx_s;
	 xa,  ya, xb, yb, xc,  yc, xd,  yd:single;  depth:integer);
var
	 dmax:single;
	 xab, yab:single;
	 xbc, ybc:single;
	 xcd, ycd:single;
	 xabc, yabc:single;
	 xbcd, ybcd:single;
	 xabcd, yabcd:single;
   p: fz_point_s;
begin
	//* termination check */
	dmax := ABS(xa - xb);
	dmax := MAX(dmax, ABS(ya - yb));
	dmax := MAX(dmax, ABS(xd - xc));
	dmax := MAX(dmax, ABS(yd - yc));
	if (dmax < s^.flatness) or (depth >= MAX_DEPTH) then
	begin
		p.x := xd;
		p.y := yd;
		fz_stroke_lineto(s, p);
		exit;
	end;

	xab := xa + xb;
	yab := ya + yb;
	xbc := xb + xc;
	ybc := yb + yc;
	xcd := xc + xd;
	ycd := yc + yd;

	xabc := xab + xbc;
	yabc := yab + ybc;
	xbcd := xbc + xcd;
	ybcd := ybc + ycd;

	xabcd := xabc + xbcd;
	yabcd := yabc + ybcd;

	xab :=xab * 0.5;
  yab :=yab * 0.5;
	xbc :=xbc* 0.5;
  ybc :=ybc * 0.5;
	xcd :=xcd *0.5;
  ycd :=ycd * 0.5;

	xabc :=xabc * 0.25;
  yabc :=yabc * 0.25;
	xbcd :=xbcd *0.25;
  ybcd :=ybcd * 0.25;

	xabcd :=xabcd *0.125;
  yabcd :=yabcd* 0.125;

	fz_stroke_bezier(s, xa, ya, xab, yab, xabc, yabc, xabcd, yabcd, depth + 1);
	fz_stroke_bezier(s, xabcd, yabcd, xbcd, ybcd, xcd, ycd, xd, yd, depth + 1);
end;

procedure fz_flatten_stroke_path(gel:Pfz_gel_s; path:pfz_path_s;  stroke:pfz_stroke_state_s;ctm: fz_matrix; flatness:single; linewidth:single);
var
	s:sctx_s;
	 p0, p1, p2, p3:fz_point_s;
	 i:integer;
   k:fz_path_item_kind_e;
begin
	s.gel := gel;
	s.ctm := @ctm;
	s.flatness := flatness;

	s.linejoin := stroke^.linejoin;
	s.linewidth := linewidth * 0.5; //* hairlines use a different value from the path value */
	s.miterlimit := stroke^.miterlimit;
	s.sn := 0;
	s.bn := 0;
	s.dot := 0;

	s.dash_list := nil;
	s.dash_phase := 0;
	s.dash_len := 0;
	s.toggle := 0;
	s.offset := 0;
	s.phase := 0;

	s.cap := stroke^.start_cap;

	i:= 0;

	if (path^.len > 0) and (fz_path_item_s_itmes(path^.items)[0].k <> FZ_MOVETO1) then
	begin
		fz_warn('assert: path must begin with moveto');
		exit;
	end;
  p0.y := 0;
	p0.x := p0.y;

	while (i < path^.len) do
	begin
     k:= fz_path_item_s_itmes(path^.items)[i].k;
     i:=i+1;
		case k of
		FZ_MOVETO1:
    begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_stroke_flush(@s, stroke^.start_cap, stroke^.end_cap);
			fz_stroke_moveto(@s, p1);
			p0 := p1;
		end;

		FZ_LINETO1:
    begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_stroke_lineto(@s, p1);
			p0 := p1;
		end;

		FZ_CURVETO1:
    begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p2.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p2.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p3.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p3.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_stroke_bezier(@s, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, 0);
			p0 := p3;
		end;

		FZ_CLOSE_PATH1:
    begin
			fz_stroke_closepath(@s);
		end;
		end;
	end;

	fz_stroke_flush(@s, stroke^.start_cap, stroke^.end_cap);
end;

procedure
fz_dash_moveto(s:psctx_s; a:fz_point_s;  start_cap:integer; end_cap:integer);
begin
	s^.toggle := 1;
	s^.offset := 0;
	s^.phase := s^.dash_phase;

	while (s^.phase >= single_items(s^.dash_list)[s^.offset]) do
	begin
    if s^.toggle=0 then
      s^.toggle :=1
      else
      s^.toggle :=0;

		s^.phase :=s^.phase - single_items(s^.dash_list)[s^.offset];
		s^.offset:=s^.offset+1;
		if (s^.offset = s^.dash_len) then
			s^.offset := 0;
	end;

	s^.cur := a;

	if (s^.toggle<>0 ) then
	begin
		fz_stroke_flush(s, s^.cap, end_cap);
		s^.cap := start_cap;
		fz_stroke_moveto(s, a);
	end;
end;

procedure 
fz_dash_lineto(s:psctx_s; b:fz_point_s; dash_cap:integer) ;
var
	 dx, dy:single;
	 total, used, ratio:single;
	 a,m:fz_point_s;

begin
	a := s^.cur;
	dx := b.x - a.x;
	dy := b.y - a.y;
	total := sqrt(dx * dx + dy * dy);
	used := 0;

	while (total - used >single_items(s^.dash_list)[s^.offset] - s^.phase) do
	begin

    used:=used+single_items(s^.dash_list)[s^.offset] - s^.phase;
		ratio := used / total;
		m.x := a.x + ratio * dx;
		m.y := a.y + ratio * dy;

		if (s^.toggle<>0) then
		begin
			fz_stroke_lineto(s, m);
		end
		else
		begin
			fz_stroke_flush(s, s^.cap, dash_cap);
			s^.cap := dash_cap;
			fz_stroke_moveto(s, m);
		end;
     if s^.toggle=0 then
      s^.toggle :=1
      else
      s^.toggle :=0;
		
		s^.phase := 0;
		s^.offset:=	s^.offset+1;
		if (s^.offset = s^.dash_len) then
			s^.offset := 0;
	end;

	s^.phase :=s^.phase + total - used;

	s^.cur := b;

	if (s^.toggle<>0) then
	begin
		fz_stroke_lineto(s, b);
	end;
end;

procedure fz_dash_bezier(s:psctx_s;
	 xa,  ya, xb,  yb, xc,  yc, xd, yd:single; depth,dash_cap:integer);
var
	dmax:single;
	xab, yab:single;
	xbc, ybc:single;
	xcd, ycd:single;
	xabc, yabc:single;
	xbcd, ybcd:single;
	xabcd, yabcd:single;
  p:fz_point_s;
begin
	//* termination check */
	dmax := ABS(xa - xb);
	dmax := MAX(dmax, ABS(ya - yb));
	dmax := MAX(dmax, ABS(xd - xc));
	dmax := MAX(dmax, ABS(yd - yc));
	if (dmax < s^.flatness) or (depth >= MAX_DEPTH) then
	begin

		p.x := xd;
		p.y := yd;
		fz_dash_lineto(s, p, dash_cap);
		exit;
  end;

	xab := xa + xb;
	yab := ya + yb;
	xbc := xb + xc;
	ybc := yb + yc;
	xcd := xc + xd;
	ycd := yc + yd;

	xabc := xab + xbc;
	yabc := yab + ybc;
	xbcd := xbc + xcd;
	ybcd := ybc + ycd;

	xabcd := xabc + xbcd;
	yabcd := yabc + ybcd;

	xab :=xab * 0.5;
  yab :=yab * 0.5;
	xbc :=xbc * 0.5;
  ybc :=ybc * 0.5;
	xcd :=xcd * 0.5;
  ycd :=ycd * 0.5;

	xabc :=xabc * 0.25;
  yabc :=yabc * 0.25;
	xbcd :=xbcd * 0.25;
  ybcd :=ybcd * 0.25;

	xabcd :=xabcd * 0.125;
  xabcd :=xabcd * 0.125;

	fz_dash_bezier(s, xa, ya, xab, yab, xabc, yabc, xabcd, yabcd, depth + 1, dash_cap);
	fz_dash_bezier(s, xabcd, yabcd, xbcd, ybcd, xcd, ycd, xd, yd, depth + 1, dash_cap);
end;

procedure  fz_flatten_dash_path(gel:pfz_gel_s; path:Pfz_path_s; stroke:pfz_stroke_state_s; ctm: fz_matrix ; flatness:single; linewidth:single);
var
  s:sctx_s;

	 p0, p1, p2, p3, beg:fz_point_s;
	 phase_len:single;
	 i:integer;
   k:fz_path_item_kind_e;
begin
	s.gel := gel;
	s.ctm := @ctm;
	s.flatness := flatness;

	s.linejoin := stroke^.linejoin;
	s.linewidth := linewidth * 0.5;
	s.miterlimit := stroke^.miterlimit;
	s.sn := 0;
	s.bn := 0;
	s.dot := 0;

	s.dash_list := @stroke^.dash_list;
	s.dash_phase := stroke^.dash_phase;
	s.dash_len := stroke^.dash_len;
	s.toggle := 0;
	s.offset := 0;
	s.phase := 0;

	s.cap := stroke^.start_cap;

	if (path^.len > 0) and (fz_path_item_s_itmes(path^.items)[0].k <> FZ_MOVETO1) then
	begin
		fz_warn('assert: path must begin with moveto');
    exit;

	end;

	phase_len := 0;
	for i := 0 to stroke^.dash_len-1 do
		phase_len :=phase_len+ stroke^.dash_list[i];
	if (phase_len < 0.01) or (phase_len < stroke^.linewidth * 0.5) then
	begin
		fz_flatten_stroke_path(gel, path, stroke, ctm, flatness, linewidth);
		exit;
	end;
  p0.y := 0;
	p0.x := p0.y;
	i := 0;

	while (i < path^.len)   do
	begin
   k:=fz_path_item_s_itmes(path^.items)[i].k;
   i:=i+1;
		case k of
		FZ_MOVETO1:
      begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_dash_moveto(@s, p1, stroke^.start_cap, stroke^.end_cap);
      p0 := p1;
			beg := p0;
			end;

		FZ_LINETO1:
      begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_dash_lineto(@s, p1, stroke^.dash_cap);
			p0 := p1;
			end;

		FZ_CURVETO1:
      begin
			p1.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p1.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p2.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p2.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p3.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p3.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			fz_dash_bezier(@s, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, 0, stroke^.dash_cap);
			p0 := p3;
			end;

		FZ_CLOSE_PATH1:
      begin
			fz_dash_lineto(@s, beg, stroke^.dash_cap);
      p1 := beg;
			p0 := p1;
			end;
		end;
	end;

	fz_stroke_flush(@s, s.cap, stroke^.end_cap);
end;


end.
