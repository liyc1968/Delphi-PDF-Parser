unit res_shades;

interface
uses  SysUtils,Math,digtypes;
  
function fz_bound_shade(shade:pfz_shade_s; ctm:fz_matrix ):fz_rect ;
function fz_keep_shade(shade:pfz_shade_s):pfz_shade_s;
procedure fz_drop_shade(shade:pfz_shade_s) ;
implementation
uses base_object_functions,res_colorspace;

function fz_keep_shade(shade:pfz_shade_s):pfz_shade_s;
begin
	shade^.refs:=shade^.refs+1;
	result:=shade;
end;

procedure fz_drop_shade(shade:pfz_shade_s) ;
begin
  if shade=nil then
  exit;
   shade^.refs:=shade^.refs-1;
	if (shade<>nil) and (shade^.refs = 0) then
	begin
		if (shade^.colorspace<>nil) then
			fz_drop_colorspace(shade^.colorspace);
		fz_free(shade^.mesh);
		fz_free(shade);
	end;
end;


function fz_bound_shade(shade:pfz_shade_s; ctm:fz_matrix ):fz_rect ;
var
	v:psingle;
	 r:fz_rect;
	 p:fz_point_s;
	i, ncomp, nvert:integer;
begin
	ctm := fz_concat(shade^.matrix, ctm);
   if shade^.use_function<>0 then
      ncomp := 3
   else
    	ncomp :=  2 + shade^.colorspace^.n;

	nvert := trunc(shade^.mesh_len / ncomp);
	v := shade^.mesh;

	if (shade^.type1 = FZ_LINEAR) then
  begin
		result:= fz_infinite_rect;
    exit;
  end;
	if (shade^.type1 = FZ_RADIAL)  then
  begin
		result:= fz_infinite_rect;
    exit;
  end;

	if (nvert = 0) then
  begin
		result:=fz_empty_rect;
    exit;
  end;

	p.x := single_items(v)[0];
	p.y := single_items(v)[1];
	v :=pointer(cardinal(v)+ ncomp);
	p := fz_transform_point(ctm, p);
  r.x1 := p.x;
	r.x0 := r.x1;
  r.y1 := p.y;
	r.y0 := r.y1;

	for i := 1 to nvert-1 do
	begin
		p.x := single_items(v)[0];
		p.y := single_items(v)[1];
		p := fz_transform_point(ctm, p);
		v :=pointer(cardinal(v)+ ncomp);
		if (p.x < r.x0) then r.x0 := p.x;
		if (p.y < r.y0) then r.y0 := p.y;
		if (p.x > r.x1) then r.x1 := p.x;
		if (p.y > r.y1) then r.y1 := p.y;
	end;

	result:= r;
end;




end.
