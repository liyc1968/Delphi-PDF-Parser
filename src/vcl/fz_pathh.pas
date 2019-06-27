unit fz_pathh;

interface
uses  SysUtils,Math,digtypes,base_error;

function fz_bound_path(path:pfz_path_s; stroke:pfz_stroke_state_s;ctm: fz_matrix ) :fz_rect ;
function fz_new_path() :pfz_path_s;
procedure fz_closepath(path:pfz_path_s);
procedure fz_free_path(path:pfz_path_s);
procedure fz_moveto(path:pfz_path_s; x:single; y:single);
procedure fz_lineto(path:pfz_path_s; x:single; y:single);
procedure fz_curveto(path:pfz_path_s; 	 x1,  y1, x2, y2, x3, y3:single) ;
procedure fz_curvetov(path:pfz_path_s;  x2,  y2,  x3, y3:single) ;
procedure fz_curvetoy(path:pfz_path_s;  x1,  y1,  x3,  y3:single);
function fz_clone_path(old:pfz_path_s):pfz_path_s;
implementation
uses base_object_functions;
function fz_new_path() :pfz_path_s;
var
	path:pfz_path_s;
begin
	path := fz_malloc(sizeof(fz_path_s));
	path^.len := 0;
	path^.cap := 0;
	path^.items := nil;

	result:= path;
end;

function fz_clone_path(old:pfz_path_s):pfz_path_s;
var
	path:pfz_path_s;
begin
	path := fz_malloc(sizeof(fz_path_s));
	path^.len := old^.len;
	path^.cap := old^.len;
	path^.items := fz_calloc(path^.cap, sizeof(fz_path_item_S));
	//copymemory(path^.items, old^.items, sizeof(fz_path_item_S) * path^.len);
  move(old^.items^,path^.items^,  sizeof(fz_path_item_S) * path^.len);

	result:=path;
end;

procedure fz_free_path(path:pfz_path_s);
begin
	fz_free(path^.items);
	fz_free(path);
end;

procedure grow_path(path:pfz_path_s;n:integer);
begin
	if (path^.len + n < path^.cap)  then
		exit;
	while (path^.len + n > path^.cap)  do
		path^.cap := path^.cap + 36;
	path^.items := fz_realloc(path^.items, path^.cap, sizeof(fz_path_item_s));
end;

procedure fz_moveto(path:pfz_path_s; x:single; y:single);
begin
	grow_path(path, 3);
	fz_path_item_s_itmes(path^.items)[path^.len].k := FZ_MOVETO1;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := x;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := y;
  path^.len:=path^.len+1;
end;

procedure fz_lineto(path:pfz_path_s; x:single; y:single);
begin
	if (path^.len = 0) then
	begin
		fz_warn('lineto with no current point');
		exit;
	end;
	grow_path(path, 3);

	fz_path_item_s_itmes(path^.items)[path^.len].k := FZ_LINETO1;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := x;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := y;
  path^.len:=path^.len+1;
end;

procedure fz_curveto(path:pfz_path_s;
	 x1,  y1, x2, y2, x3, y3:single) ;
begin
	if (path^.len = 0) then
	begin
		fz_warn('curveto with no current point');
		//return;
    exit;
	end;
	grow_path(path, 7);
	fz_path_item_s_itmes(path^.items)[path^.len].k := FZ_CURVETO1;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := x1;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := y1;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := x2;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := y2;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := x3;
  path^.len:=path^.len+1;
	fz_path_item_s_itmes(path^.items)[path^.len].v := y3;
  path^.len:=path^.len+1;
end;

procedure fz_curvetov(path:pfz_path_s;  x2,  y2,  x3, y3:single) ;
var
	x1, y1:single;
begin
	if (path^.len = 0) then
	begin
		//fz_warn("curvetov with no current point");
		exit;
	end;
	x1 :=fz_path_item_s_itmes(path^.items)[path^.len-2].v;
	y1 := fz_path_item_s_itmes(path^.items)[path^.len-1].v;
	fz_curveto(path, x1, y1, x2, y2, x3, y3);
end;

procedure fz_curvetoy(path:pfz_path_s;  x1,  y1,  x3,  y3:single);
begin
	fz_curveto(path, x1, y1, x3, y3, x3, y3);
end;

procedure fz_closepath(path:pfz_path_s);
begin
	if (path^.len = 0) then
	begin
	 fz_warn('closepath with no current point');
   exit;

	end;
	grow_path(path, 1);
	fz_path_item_s_itmes(path^.items)[path^.len].k := FZ_CLOSE_PATH1;
  path^.len:=path^.len+1;
end;

function   bound_expand(r:fz_rect;p: fz_point_s ):fz_rect ;
begin
	if (p.x < r.x0) then r.x0 := p.x;
	if (p.y < r.y0) then r.y0 := p.y;
	if (p.x > r.x1) then r.x1 := p.x;
	if (p.y > r.y1) then r.y1 := p.y;
	result:=r;
end;

function fz_bound_path(path:pfz_path_s; stroke:pfz_stroke_state_s;ctm: fz_matrix ) :fz_rect ;
var
	 p:fz_point_s;
	 r:fz_rect;
	 i :integer;
   k: fz_path_item_kind_e;
    miterlength,linewidth,expand:single;

begin
  r:= fz_empty_rect;
  i:=0;
	if (path^.len<>0) then
	begin
		p.x := fz_path_item_s_itmes(path^.items)[1].v;
		p.y := fz_path_item_s_itmes(path^.items)[2].v;
		p := fz_transform_point(ctm, p);
    r.x1 := p.x;
		r.x0 := r.x1;
    r.y1 := p.y;
		r.y0 := r.y1;
	end;

	while (i < path^.len)   do
	begin
    k:=fz_path_item_s_itmes(path^.items)[i].k;
    i:=i+1;
		case k of
    FZ_CURVETO1:
      begin
			p.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			r := bound_expand(r, fz_transform_point(ctm, p));
			p.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			r := bound_expand(r, fz_transform_point(ctm, p));
			p.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			r := bound_expand(r, fz_transform_point(ctm, p));

      end;
		 FZ_MOVETO1:
     begin
       p.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			r := bound_expand(r, fz_transform_point(ctm, p));

     end;
     FZ_LINETO1 :
     begin
       p.x := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			p.y := fz_path_item_s_itmes(path^.items)[i].v;
      i:=i+1;
			r := bound_expand(r, fz_transform_point(ctm, p));

     end;


		FZ_CLOSE_PATH1:
      i:=i+1;
      
		end;

	end;

	if (stroke<>nil) then
	begin
		 miterlength := stroke^.miterlimit;
		 linewidth := stroke^.linewidth;
		 expand := MAX(miterlength, linewidth) * 0.5;
		r.x0 :=r.x0- expand;
		r.y0 :=r.y0- expand;
		r.x1 :=r.x1- expand;
		r.y1 :=r.y1- expand;
	end;

	result:=r;
end;

procedure fz_transform_path(path:pfz_path_s; ctm:fz_matrix );
var
	p:fz_point_s;
	 k, i:integer;
   k1: fz_path_item_kind_e;
begin
  k:=0;
  i:=0;
	while (i < path^.len) do
	begin

    k1:= fz_path_item_s_itmes(path^.items)[i].k;
    i:=i+1;

		case k1 of
		FZ_CURVETO1:
    begin
			for k := 0 to 3-1 do
			begin
				p.x := fz_path_item_s_itmes(path^.items)[i].v;
				p.y := fz_path_item_s_itmes(path^.items)[i+1].v;
				p := fz_transform_point(ctm, p);
				fz_path_item_s_itmes(path^.items)[i].v := p.x;
				fz_path_item_s_itmes(path^.items)[i+1].v := p.y;
				i:=i+ 2;
			end;
    end;
	 FZ_MOVETO1:
     begin
			p.x := fz_path_item_s_itmes(path^.items)[i].v;
			p.y := fz_path_item_s_itmes(path^.items)[i+1].v;
			p := fz_transform_point(ctm, p);
	  	fz_path_item_s_itmes(path^.items)[i].v := p.x;
			fz_path_item_s_itmes(path^.items)[i+1].v := p.y;
			i :=i+ 2;
		  end;
	  FZ_LINETO1:
      begin
			p.x := fz_path_item_s_itmes(path^.items)[i].v;
			p.y := fz_path_item_s_itmes(path^.items)[i+1].v;
			p := fz_transform_point(ctm, p);
	  	fz_path_item_s_itmes(path^.items)[i].v := p.x;
			fz_path_item_s_itmes(path^.items)[i+1].v := p.y;
			i :=i+ 2;
		  end;
		 FZ_CLOSE_PATH1:  continue;

		end;
	end;
end;



end.
