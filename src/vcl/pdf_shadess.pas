unit pdf_shadess;

interface
uses
 SysUtils,Math,digtypes,digcommtype,BASE_ERROR;
const
HUGENUM= 32000;  //* how far to extend axial/radial shadings */
FUNSEGS= 32; //* size of sampled mesh for function-based shadings */
RADSEGS= 32; //* how many segments to generate for radial meshes */
SUBDIV= 3;  //* how many levels to subdivide patches */

type
pvertex_s=^vertex_s;
vertex_s=record
	 x, y:single;
	 c:array[0..FZ_MAX_COLORS-1] of single;
end;

ppdf_tensor_patch_s=^pdf_tensor_patch_s;
pdf_tensor_patch_s=record
	pole:array[0..3,0..3] of fz_point_s;
  color:array[0..3,0..FZ_MAX_COLORS-1] of single;
end;

pmesh_params_s=^mesh_params_s;
mesh_params_s=record
	vprow:integer;
	bpflag:integer;
	bpcoord:integer;
	bpcomp:integer;
	x0, x1:single;
	y0, y1:single;
	c0:array[0..FZ_MAX_COLORS-1] of single;
	c1:array[0..FZ_MAX_COLORS-1] of single;
end;
vertex_s_items=array of vertex_s;


function pdf_load_shading(shadep:ppfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
implementation
uses base_object_functions,pdf_functionss,FZ_mystreams,res_shades,pdf_color_spcasess,mypdfstream,fz_pdf_store;

procedure pdf_grow_mesh(shade:pfz_shade_s;  amount:integer);
begin
	if (shade^.mesh_len + amount < shade^.mesh_cap) then
		exit;

	if (shade^.mesh_cap = 0) then
		shade^.mesh_cap := 1024;

	while (shade^.mesh_len + amount > shade^.mesh_cap) do
		shade^.mesh_cap := (shade^.mesh_cap * 3) div 2;

	shade^.mesh := fz_realloc(shade^.mesh, shade^.mesh_cap, sizeof(single));
end;

procedure pdf_add_vertex(shade:pfz_shade_s;  v:pvertex_s);
var
ncomp,i:integer;
begin
  if  shade^.use_function<>0 then
	ncomp :=  1
  else
   ncomp :=shade^.colorspace^.n;

	pdf_grow_mesh(shade, 2 + ncomp);
	single_items(shade^.mesh)[shade^.mesh_len] := v^.x;
   shade^.mesh_len:=shade^.mesh_len+1;
	single_items(shade^.mesh)[shade^.mesh_len] := v^.y;
  shade^.mesh_len:=shade^.mesh_len+1;
	for i := 0 to ncomp-1 do
  begin
	single_items(shade^.mesh)[shade^.mesh_len] := v^.c[i];
    shade^.mesh_len:=shade^.mesh_len+1;
  end;
end;

procedure pdf_add_triangle(shade:pfz_shade_s;	v0,v1,v2:pvertex_s);
begin
	pdf_add_vertex(shade, v0);
	pdf_add_vertex(shade, v1);
	pdf_add_vertex(shade, v2);
end;

procedure pdf_add_quad(shade:pfz_shade_s;v0,v1,v2,v3:pvertex_s);
begin
	pdf_add_triangle(shade, v0, v1, v3);
	pdf_add_triangle(shade, v1, v3, v2);
end;

//* Subdivide and tesselate tensor-patches */





procedure
triangulate_patch( p :pdf_tensor_patch_s; shade:pfz_shade_s) ;
var
   v0, v1, v2, v3:vertex_s;
begin
	v0.x := p.pole[0][0].x;
	v0.y := p.pole[0][0].y;
	//copymemory(@v0.c, @p.color[0], sizeof(v0.c));
  move((@p.color[0])^,(@v0.c)^,  sizeof(v0.c));

	v1.x := p.pole[0][3].x;
	v1.y := p.pole[0][3].y;
 //	copymemory(@v1.c, @p.color[1], sizeof(v1.c));
  move((@p.color[1])^,(@v1.c)^,  sizeof(v1.c));

	v2.x := p.pole[3][3].x;
	v2.y := p.pole[3][3].y;
 //	copymemory(@v2.c, @p.color[2], sizeof(v2.c));
  move((@p.color[2])^,(@v2.c)^,  sizeof(v2.c));
	v3.x := p.pole[3][0].x;
	v3.y := p.pole[3][0].y;
	//copymemory(@v3.c, @p.color[3], sizeof(v3.c));
  move((@p.color[3])^,(@v3.c)^,  sizeof(v3.c));
	pdf_add_quad(shade, @v0, @v1, @v2, @v3);
end;

procedure midcolor(c, c1, c2:psingle);
var
	i:integer;
begin
	for i := 0 to FZ_MAX_COLORS-1 do
		single_items(c)[i] := (single_items(c1)[i] + single_items(c2)[i]) * 0.5;
end;

procedure split_curve(pole:pfz_point_s; q0:pfz_point_s; q1:pfz_point_s; polestep:integer);
var
	(*
	split bezier curve given by control points pole[0]..pole[3]
	using de casteljau algo at midpoint and build two new
	bezier curves q0[0]..q0[3] and q1[0]..q1[3]. all indices
	should be multiplies by polestep == 1 for vertical bezier
	curves in patch and == 4 for horizontal bezier curves due
	to C's multi-dimensional matrix memory layout.
	*)
 x12,y12:single;
begin

	x12 := (fz_point_s_items(pole)[1 * polestep].x + fz_point_s_items(pole)[2 * polestep].x) * 0.5;
	y12 := (fz_point_s_items(pole)[1 * polestep].y + fz_point_s_items(pole)[2 * polestep].y) * 0.5;

fz_point_s_items(q0)[1 * polestep].x := (fz_point_s_items(pole)[0 * polestep].x + fz_point_s_items(pole)[1 * polestep].x) * 0.5;
	fz_point_s_items(q0)[1 * polestep].y := (fz_point_s_items(pole)[0 * polestep].y + fz_point_s_items(pole)[1 * polestep].y) * 0.5;
	fz_point_s_items(q1)[2 * polestep].x := (fz_point_s_items(pole)[2 * polestep].x + fz_point_s_items(pole)[3 * polestep].x) * 0.5;
	fz_point_s_items(q1)[2 * polestep].y := (fz_point_s_items(pole)[2 * polestep].y + fz_point_s_items(pole)[3 * polestep].y) * 0.5;

	fz_point_s_items(q0)[2 * polestep].x := (fz_point_s_items(q0)[1 * polestep].x + x12) * 0.5;
	fz_point_s_items(q0)[2 * polestep].y := (fz_point_s_items(q0)[1 * polestep].y + y12) * 0.5;
	fz_point_s_items(q1)[1 * polestep].x := (x12 + fz_point_s_items(q1)[2 * polestep].x) * 0.5;
	fz_point_s_items(q1)[1 * polestep].y := (y12 + fz_point_s_items(q1)[2 * polestep].y) * 0.5;

	fz_point_s_items(q0)[3 * polestep].x := (fz_point_s_items(q0)[2 * polestep].x + fz_point_s_items(q1)[1 * polestep].x) * 0.5;
	fz_point_s_items(q0)[3 * polestep].y := (fz_point_s_items(q0)[2 * polestep].y + fz_point_s_items(q1)[1 * polestep].y) * 0.5;
	fz_point_s_items(q1)[0 * polestep].x := (fz_point_s_items(q0)[2 * polestep].x + fz_point_s_items(q1)[1 * polestep].x) * 0.5;
	fz_point_s_items(q1)[0 * polestep].y := (fz_point_s_items(q0)[2 * polestep].y + fz_point_s_items(q1)[1 * polestep].y) * 0.5;

	fz_point_s_items(q0)[0 * polestep].x := fz_point_s_items(pole)[0 * polestep].x;
	fz_point_s_items(q0)[0 * polestep].y := fz_point_s_items(pole)[0 * polestep].y;
	fz_point_s_items(q1)[3 * polestep].x := fz_point_s_items(pole)[3 * polestep].x;
	fz_point_s_items(q1)[3 * polestep].y := fz_point_s_items(pole)[3 * polestep].y;
end;

procedure 
split_stripe(p:ppdf_tensor_patch_s; s0:ppdf_tensor_patch_s; s1:ppdf_tensor_patch_s);
begin
	(*
	split all horizontal bezier curves in patch,
	creating two new patches with half the width.
	*)
	split_curve(@p^.pole[0][0], @s0^.pole[0][0], @s1^.pole[0][0], 4);
	split_curve(@p^.pole[0][1], @s0^.pole[0][1], @s1^.pole[0][1], 4);
	split_curve(@p^.pole[0][2], @s0^.pole[0][2], @s1^.pole[0][2], 4);
	split_curve(@p^.pole[0][3], @s0^.pole[0][3], @s1^.pole[0][3], 4);

	//* interpolate the colors for the two new patches. */
	//copymemory(@s0^.color[0], @p^.color[0], sizeof(s0^.color[0]));
  move((@p^.color[0])^,(@s0^.color[0])^,  sizeof(s0^.color[0]));
	//copymemory(@s0^.color[1], @p^.color[1], sizeof(s0^.color[1]));
  move((@p^.color[1])^,(@s0^.color[1])^,  sizeof(s0^.color[1]));

	midcolor(@s0^.color[2], @p^.color[1], @p^.color[2]);
	midcolor(@s0^.color[3], @p^.color[0], @p^.color[3]);

	//copymemory(@s1^.color[0], @s0^.color[3], sizeof(s1^.color[0]));
  move(( @s0^.color[3])^,(@s1^.color[0])^, sizeof(s1^.color[0]));
	//copymemory(@s1^.color[1], @s0^.color[2], sizeof(s1^.color[1]));
  move((@s0^.color[2])^,(@s1^.color[1])^,  sizeof(s1^.color[1]));
	//copymemory(@s1^.color[2], @p^.color[2], sizeof(s1^.color[2]));
  move((@p^.color[2])^,(@s1^.color[2])^,  sizeof(s1^.color[2]));
 //	copymemory(@s1^.color[3], @p^.color[3], sizeof(s1^.color[3]));
  move((@p^.color[3])^,(@s1^.color[3])^,  sizeof(s1^.color[3]));
end;

procedure draw_stripe(p:ppdf_tensor_patch_s; shade:pfz_shade_s; depth:integer);
var
	 s0, s1:pdf_tensor_patch_s;
begin
	//* split patch into two half-height patches */
	split_stripe(p, @s0, @s1);

	depth:=depth-1;
	if (depth = 0) then
	begin
		//* if no more subdividing, draw two new patches... */
		triangulate_patch(s0, shade);
		triangulate_patch(s1, shade);
	end
	else
	begin
		//* ...otherwise, continue subdividing. */
		draw_stripe(@s0, shade, depth);
		draw_stripe(@s1, shade, depth);
	end;
end;

procedure split_patch(p:ppdf_tensor_patch_s; s0:ppdf_tensor_patch_s; s1:ppdf_tensor_patch_s);
begin
	(*
	split all vertical bezier curves in patch,
	creating two new patches with half the height.
	*)
	split_curve(@p^.pole[0], @s0^.pole[0], @s1^.pole[0], 1);
	split_curve(@p^.pole[1], @s0^.pole[1], @s1^.pole[1], 1);
	split_curve(@p^.pole[2], @s0^.pole[2], @s1^.pole[2], 1);
	split_curve(@p^.pole[3], @s0^.pole[3], @s1^.pole[3], 1);

	//* interpolate the colors for the two new patches. */
 //	copymemory(@s0^.color[0], @p^.color[0], sizeof(s0^.color[0]));
  move((@p^.color[0])^, (@s0^.color[0])^, sizeof(s0^.color[0]));
	midcolor(@s0^.color[1], @p^.color[0], @p^.color[1]);
	midcolor(@s0^.color[2], @p^.color[2], @p^.color[3]);
 //	copymemory(@s0^.color[3], @p^.color[3], sizeof(s0^.color[3]));
  move( (@p^.color[3])^,(@s0^.color[3])^, sizeof(s0^.color[3]));
 //	copymemory(@s1^.color[0],@s0^.color[1], sizeof(s1^.color[0]));
  move((@s0^.color[1])^,(@s1^.color[0])^, sizeof(s1^.color[0]));
	//copymemory(@s1^.color[1], @p^.color[1], sizeof(s1^.color[1]));
  move((@p^.color[1])^,(@s1^.color[1])^,  sizeof(s1^.color[1]));
	//copymemory(@s1^.color[2], @p^.color[2], sizeof(s1^.color[2]));
  move((@p^.color[2])^,(@s1^.color[2])^,  sizeof(s1^.color[2]));
	//copymemory(@s1^.color[3], @s0^.color[2], sizeof(s1^.color[3]));
  move((@s0^.color[2])^,(@s1^.color[3])^,  sizeof(s1^.color[3]));
end;

procedure draw_patch(shade:pfz_shade_s; p:ppdf_tensor_patch_s; depth, origdepth:integer);
var
	s0, s1:pdf_tensor_patch_s;
begin
	//* split patch into two half-width patches */
	split_patch(p, @s0, @s1);

	depth:=depth-1;
	if (depth = 0) then
	begin
		//* if no more subdividing, draw two new patches... */
		draw_stripe(@s0, shade, origdepth);
		draw_stripe(@s1, shade, origdepth);
	end
	else
	begin
		//* ...otherwise, continue subdividing. */
		draw_patch(shade, @s0, depth, origdepth);
		draw_patch(shade, @s1, depth, origdepth);
	end
end;

function pdf_compute_tensor_interior(
	a, b, c, d,e, f, g, h:fz_point_s)  :fz_point_s;
var
	pt:fz_point_s;
begin
	//* see equations at page 330 in pdf 1.7 */

	pt.x := -4 * a.x;
	pt.x :=pt.x + 6 * (b.x + c.x);
	pt.x :=pt.x + -2 * (d.x + e.x);
	pt.x :=pt.x + 3 * (f.x + g.x);
	pt.x :=pt.x  -1 * h.x;
	pt.x :=pt.x / 9;

	pt.y := -4 * a.y;
	pt.y :=pt.y + 6 * (b.y + c.y);
	pt.y :=pt.y + -2 * (d.y + e.y);
	pt.y :=pt.y + 3 * (f.y + g.y);
	pt.y :=pt.y  -1 * h.y;
	pt.y :=pt.y / 9;

	result:= pt;
end;

procedure 
pdf_make_tensor_patch(p:ppdf_tensor_patch_s; type1:integer; pt:pfz_point_s);
begin
	if (type1 = 6) then
	begin
		//* see control point stream order at page 325 in pdf 1.7 */

		p^.pole[0][0] := fz_point_s_items(pt)[0];
		p^.pole[0][1] := fz_point_s_items(pt)[1];
		p^.pole[0][2] := fz_point_s_items(pt)[2];
		p^.pole[0][3] := fz_point_s_items(pt)[3];
		p^.pole[1][3] := fz_point_s_items(pt)[4];
		p^.pole[2][3] := fz_point_s_items(pt)[5];
		p^.pole[3][3] := fz_point_s_items(pt)[6];
		p^.pole[3][2] := fz_point_s_items(pt)[7];
		p^.pole[3][1] := fz_point_s_items(pt)[8];
		p^.pole[3][0] := fz_point_s_items(pt)[9];
		p^.pole[2][0] := fz_point_s_items(pt)[10];
		p^.pole[1][0] := fz_point_s_items(pt)[11];

		//* see equations at page 330 in pdf 1.7 */

		p^.pole[1][1] := pdf_compute_tensor_interior(
			p^.pole[0][0], p^.pole[0][1], p^.pole[1][0], p^.pole[0][3],
			p^.pole[3][0], p^.pole[3][1], p^.pole[1][3], p^.pole[3][3]);

		p^.pole[1][2] := pdf_compute_tensor_interior(
			p^.pole[0][3], p^.pole[0][2], p^.pole[1][3], p^.pole[0][0],
			p^.pole[3][3], p^.pole[3][2], p^.pole[1][0], p^.pole[3][0]);

		p^.pole[2][1] := pdf_compute_tensor_interior(
			p^.pole[3][0], p^.pole[3][1], p^.pole[2][0], p^.pole[3][3],
			p^.pole[0][0], p^.pole[0][1], p^.pole[2][3], p^.pole[0][3]);

		p^.pole[2][2] := pdf_compute_tensor_interior(
			p^.pole[3][3], p^.pole[3][2], p^.pole[2][3], p^.pole[3][0],
			p^.pole[0][3], p^.pole[0][2], p^.pole[2][0], p^.pole[0][0]);
	end
	else if (type1 = 7) then
	begin
		//* see control point stream order at page 330 in pdf 1.7 */

		p^.pole[0][0] := fz_point_s_items(pt)[0];
		p^.pole[0][1] := fz_point_s_items(pt)[1];
		p^.pole[0][2] := fz_point_s_items(pt)[2];
		p^.pole[0][3] := fz_point_s_items(pt)[3];
		p^.pole[1][3] := fz_point_s_items(pt)[4];
		p^.pole[2][3] := fz_point_s_items(pt)[5];
		p^.pole[3][3] := fz_point_s_items(pt)[6];
		p^.pole[3][2] := fz_point_s_items(pt)[7];
		p^.pole[3][1] := fz_point_s_items(pt)[8];
		p^.pole[3][0] := fz_point_s_items(pt)[9];
		p^.pole[2][0] := fz_point_s_items(pt)[10];
		p^.pole[1][0] := fz_point_s_items(pt)[11];
		p^.pole[1][1] := fz_point_s_items(pt)[12];
		p^.pole[1][2] := fz_point_s_items(pt)[13];
		p^.pole[2][2] := fz_point_s_items(pt)[14];
		p^.pole[2][1] := fz_point_s_items(pt)[15];
	end;
end;

//* Sample various functions into lookup tables */

procedure pdf_sample_composite_shade_function(shade:pfz_shade_s; func:ppdf_function_s; t0, t1:single);
var
	i:integer;
	t:single;
begin
	for i := 0 to 256-1 do
	begin
		t := t0 + (i / 255.0) * (t1 - t0);
		pdf_eval_function(func, @t, 1, @shade^.function1[i], shade^.colorspace^.n);
		shade^.function1[i][shade^.colorspace^.n] := 1;
	end;
end;

procedure pdf_sample_component_shade_function(shade:pfz_shade_s; funcs:integer; func:pppdf_function_s; t0, t1:single);
var
	 i, k:integer;
	 t:single;
begin
	for i := 0 to 256-1 do
	begin
		t:= t0 + (i / 255.0) * (t1 - t0);
		for k := 0  to funcs-1  do
			pdf_eval_function(ppdf_function_s_items(func)[k], @t, 1, @shade^.function1[i][k], 1);
		shade^.function1[i][k] := 1;
	end;
end;

procedure pdf_sample_shade_function(shade:pfz_shade_s; funcs:integer; func:pppdf_function_s; t0, t1:single);
begin
	shade^.use_function := 1;
	if (funcs = 1) then
		pdf_sample_composite_shade_function(shade, ppdf_function_s_items(func)[0], t0, t1)
	else
		pdf_sample_component_shade_function(shade, funcs, func, t0, t1);
end;

//* Type 1-3 -- Function-based, axial and radial shadings */

procedure
pdf_load_function_based_shading(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s; func:ppdf_function_s);
var
	obj:pfz_obj_s;
	x0, y0, x1, y1:single;
	matrix:fz_matrix;
  v:array[0..3] of vertex_s;
	xx, yy:integer;
	x, y:single;
	xn, yn:single;
	i:integer;
  pt:fz_point_s;
  fv:array[0..1] of single;
begin
  y0 := 0;
	x0 := y0;
  y1 := 1;
	x1 := y1;
	obj := fz_dict_gets(dict, 'Domain');
	if (fz_array_len(obj) = 4) then
	begin
		x0 := fz_to_real(fz_array_get(obj, 0));
		x1 := fz_to_real(fz_array_get(obj, 1));
		y0 := fz_to_real(fz_array_get(obj, 2));
		y1 := fz_to_real(fz_array_get(obj, 3));
	end;

	matrix := fz_identity;
	obj := fz_dict_gets(dict, 'Matrix');
	if (fz_array_len(obj) = 6) then
		matrix := pdf_to_matrix(obj);

	for yy := 0 to FUNSEGS-1 do
	begin
		y := y0 + (y1 - y0) * yy / FUNSEGS;
		yn := y0 + (y1 - y0) * (yy + 1) / FUNSEGS;

		for xx := 0 to FUNSEGS-1 do
		begin
			x := x0 + (x1 - x0) * xx / FUNSEGS;
			xn := x0 + (x1 - x0) * (xx + 1) / FUNSEGS;

			v[0].x := x;
      v[0].y := y;
			v[1].x := xn;
      v[1].y := y;
			v[2].x := xn;
      v[2].y := yn;
			v[3].x := x;
      v[3].y := yn;

			for i := 0 to 3 do
			begin


				fv[0] := v[i].x;
				fv[1] := v[i].y;
				pdf_eval_function(func, @fv, 2, @v[i].c, shade^.colorspace^.n);

				pt.x := v[i].x;
				pt.y := v[i].y;
				pt := fz_transform_point(matrix, pt);
				v[i].x := pt.x;
				v[i].y := pt.y;
			end;

			pdf_add_quad(shade, @v[0], @v[1], @v[2], @v[3]);
		end;
	end;
end;

procedure 
pdf_load_axial_shading(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s; funcs:integer; func:pppdf_function_s);
var
	obj:pfz_obj_s;
	d0, d1:single;
	e0, e1:integer;
	x0, y0, x1, y1:single;
	p1, p2:vertex_s;
 begin
	obj := fz_dict_gets(dict, 'Coords');
	x0 := fz_to_real(fz_array_get(obj, 0));
	y0 := fz_to_real(fz_array_get(obj, 1));
	x1 := fz_to_real(fz_array_get(obj, 2));
	y1 := fz_to_real(fz_array_get(obj, 3));

	d0 := 0;
	d1 := 1;
	obj := fz_dict_gets(dict, 'Domain');
	if (fz_array_len(obj) = 2) then
	begin
		d0 := fz_to_real(fz_array_get(obj, 0));
		d1 := fz_to_real(fz_array_get(obj, 1));
	end;
  e1 := 0 ;
	e0 := e1;
	obj := fz_dict_gets(dict, 'Extend');
	if (fz_array_len(obj) = 2) then
	begin
		e0 := fz_to_bool(fz_array_get(obj, 0));
		e1 := fz_to_bool(fz_array_get(obj, 1));
	end;

	pdf_sample_shade_function(shade, funcs, func, d0, d1);

	shade^.type1 := FZ_LINEAR;

	shade^.extend[0] := e0;
	shade^.extend[1] := e1;

	p1.x := x0;
	p1.y := y0;
	p1.c[0] := 0;
	pdf_add_vertex(shade, @p1);

	p2.x := x1;
	p2.y := y1;
	p2.c[0] := 0;
	pdf_add_vertex(shade, @p2);
end;

procedure 
pdf_load_radial_shading(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s; funcs:integer; func:pppdf_function_s);
var
  obj:pfz_obj_s;
	d0, d1:single;
	e0, e1:integer;
	x0, y0, x1, y1,r0,r1:single;
	p1, p2:vertex_s;


begin
	obj := fz_dict_gets(dict, 'Coords');
	x0 := fz_to_real(fz_array_get(obj, 0));
	y0 := fz_to_real(fz_array_get(obj, 1));
	r0 := fz_to_real(fz_array_get(obj, 2));
	x1 := fz_to_real(fz_array_get(obj, 3));
	y1 := fz_to_real(fz_array_get(obj, 4));
	r1 := fz_to_real(fz_array_get(obj, 5));

	d0 := 0;
	d1 := 1;
	obj := fz_dict_gets(dict, 'Domain');
	if (fz_array_len(obj) = 2) then
	begin
		d0 := fz_to_real(fz_array_get(obj, 0));
		d1 := fz_to_real(fz_array_get(obj, 1));
	end;
  e1 := 0;
	e0 := e1 ;
	obj := fz_dict_gets(dict, 'Extend');
	if (fz_array_len(obj) = 2) then
	begin
		e0 := fz_to_bool(fz_array_get(obj, 0));
		e1 := fz_to_bool(fz_array_get(obj, 1));
	end;

	pdf_sample_shade_function(shade, funcs, func, d0, d1);

	shade^.type1 := FZ_RADIAL;

	shade^.extend[0] := e0;
	shade^.extend[1] := e1;

	p1.x := x0;
	p1.y := y0;
	p1.c[0] := r0;
	pdf_add_vertex(shade, @p1);

	p2.x := x1;
	p2.y := y1;
	p2.c[0] := r1;
	pdf_add_vertex(shade, @p2);
end;

//* Type 4-7 -- Triangle and patch mesh shadings */

function  read_sample(stream:pfz_stream_s; bits:integer; min1,  max1:single):single;
var
bitscale:single;
begin
	//* we use pow(2,x) because (1<<x) would overflow the math on 32-bit samples */
	bitscale := 1 / (power(2, bits) - 1);
	result:= min1 + fz_read_bits(stream, bits) * (max1 - min1) * bitscale;
end;



procedure 
pdf_load_mesh_params(xref:ppdf_xref_s; dict:pfz_obj_s; p:pmesh_params_s);
var
	obj:pfz_obj_s;
	 i, n:integer;
begin
  p^.y0 := 0;
	p^.x0 := p^.y0 ;
  p^.y1 := 1;
	p^.x1 := p^.y1;
	for i := 0 to FZ_MAX_COLORS-1 do
	begin
		p^.c0[i] := 0;
		p^.c1[i] := 1;
	end;

	p^.vprow := fz_to_int(fz_dict_gets(dict, 'VerticesPerRow'));
	p^.bpflag := fz_to_int(fz_dict_gets(dict, 'BitsPerFlag'));
	p^.bpcoord := fz_to_int(fz_dict_gets(dict, 'BitsPerCoordinate'));
	p^.bpcomp := fz_to_int(fz_dict_gets(dict, 'BitsPerComponent'));

	obj := fz_dict_gets(dict, 'Decode');
	if (fz_array_len(obj) >= 6)   then
	begin
		n := (fz_array_len(obj) - 4) div 2;
		p^.x0 := fz_to_real(fz_array_get(obj, 0));
		p^.x1 := fz_to_real(fz_array_get(obj, 1));
		p^.y0 := fz_to_real(fz_array_get(obj, 2));
		p^.y1 := fz_to_real(fz_array_get(obj, 3));
		for i := 0 to n-1 do
		begin
			p^.c0[i] := fz_to_real(fz_array_get(obj, 4 + i * 2));
			p^.c1[i] := fz_to_real(fz_array_get(obj, 5 + i * 2));
		end;
	end;

	if (p^.vprow < 2) then
		p^.vprow := 2;

	if ((p^.bpflag <> 2) and  (p^.bpflag <> 4) and (p^.bpflag <> 8)) then
		p^.bpflag := 8;

	if ((p^.bpcoord <> 1) and (p^.bpcoord <> 2) and (p^.bpcoord <> 4) and
		(p^.bpcoord <> 8) and (p^.bpcoord <> 12) and (p^.bpcoord <> 16) and
		(p^.bpcoord <> 24) and (p^.bpcoord <> 32)) then
		p^.bpcoord := 8;

	if ((p^.bpcomp <> 1) and (p^.bpcomp <> 2) and (p^.bpcomp <> 4) and
		(p^.bpcomp <> 8) and (p^.bpcomp <> 12) and (p^.bpcomp <> 16)) then
		p^.bpcomp := 8;
end;

procedure 
pdf_load_type4_shade(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s;
	 funcs:integer; func:pppdf_function_s; stream:pfz_stream_s);
var
	p:mesh_params_s;
	va, vb, vc, vd:vertex_s;
	ncomp,flag,i:integer;
begin
	pdf_load_mesh_params(xref, dict, @p);

	if (funcs > 0) then
	begin
		ncomp := 1;
		pdf_sample_shade_function(shade, funcs, func, p.c0[0], p.c1[0]);
	end
	else
		ncomp := shade^.colorspace^.n;

	while (not fz_is_eof_bits(stream))  do
	begin
		flag := fz_read_bits(stream, p.bpflag);
		vd.x := read_sample(stream, p.bpcoord, p.x0, p.x1);
		vd.y := read_sample(stream, p.bpcoord, p.y0, p.y1);
		for i := 0 to ncomp-1 do
			vd.c[i] := read_sample(stream, p.bpcomp, p.c0[i], p.c1[i]);

		case (flag) of
		0: //* start new triangle */
      begin
			va := vd;

			fz_read_bits(stream, p.bpflag);
			vb.x := read_sample(stream, p.bpcoord, p.x0, p.x1);
			vb.y := read_sample(stream, p.bpcoord, p.y0, p.y1);
			for i := 0 to ncomp-1 do
				vb.c[i] := read_sample(stream, p.bpcomp, p.c0[i], p.c1[i]);

			fz_read_bits(stream, p.bpflag);
			vc.x := read_sample(stream, p.bpcoord, p.x0, p.x1);
			vc.y := read_sample(stream, p.bpcoord, p.y0, p.y1);
			for i := 0 to ncomp-1 do
				vc.c[i] := read_sample(stream, p.bpcomp, p.c0[i], p.c1[i]);

			pdf_add_triangle(shade, @va, @vb, @vc);
			end;

		1: //* Vb, Vc, Vd */
      begin
			va := vb;
			vb := vc;
			vc := vd;
			pdf_add_triangle(shade, @va, @vb, @vc);
			end;

		2: //* Va, Vc, Vd */
      begin
			vb := vc;
			vc := vd;
			pdf_add_triangle(shade, @va, @vb, @vc);
			end;
		end;
	end;
end;

procedure 
pdf_load_type5_shade(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s;
	funcs:integer; func:pppdf_function_s; stream:pfz_stream_s);
var
	 p:mesh_params_s;
	buf, ref:pvertex_s;
	first:integer;
	ncomp:integer;
	i, k:integer;
begin
	pdf_load_mesh_params(xref, dict, @p);

	if (funcs > 0)    then
	begin
		ncomp := 1;
		pdf_sample_shade_function(shade, funcs, func, p.c0[0], p.c1[0]);
	end
	else
		ncomp := shade^.colorspace^.n;

	ref := fz_calloc(p.vprow, sizeof(vertex_s));
	buf := fz_calloc(p.vprow, sizeof(vertex_s));
	first := 1;

	while (not fz_is_eof_bits(stream)) do
	begin
		for i := 0 to p.vprow-1 do
		begin
			vertex_s_items(buf)[i].x := read_sample(stream, p.bpcoord, p.x0, p.x1);
			vertex_s_items(buf)[i].y := read_sample(stream, p.bpcoord, p.y0, p.y1);
			for k := 0 to ncomp-1 do
				vertex_s_items(buf)[i].c[k] := read_sample(stream, p.bpcomp, p.c0[k], p.c1[k]);
		end;

		if (first<>0) then
			for i := 0 to p.vprow - 1-1 do
				pdf_add_quad(shade,
					@vertex_s_items(ref)[i], @vertex_s_items(ref)[i+1], @vertex_s_items(buf)[i+1], @vertex_s_items(buf)[i]);

		//copymemory(ref, buf, p.vprow * sizeof(vertex_s));
    move(buf^,ref^,  p.vprow * sizeof(vertex_s));
		first := 0;
	end;

	freemem(ref);
	freemem(buf);
end;

//* Type 6 & 7 -- Patch mesh shadings */

procedure 
pdf_load_type6_shade(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s;
	funcs:integer; func:pppdf_function_s; stream:pfz_stream_s);
var
	p: mesh_params_s;
	 haspatch, hasprevpatch:integer;
	prevc:array[0..3,0..FZ_MAX_COLORS-1] of single;
	prevp:array[0..11] of fz_point_s;
	ncomp:integer;
	i, k:integer;
  c:array[0..3,0..FZ_MAX_COLORS-1] of single;
		v:array[0..11] of fz_point_s;
	  startcolor:integer;
	  startpt:integer;
	  flag:integer;
   patch:pdf_tensor_patch_s;
begin
	pdf_load_mesh_params(xref, dict, @p);

	if (funcs > 0) then
	begin
		ncomp := 1;
		pdf_sample_shade_function(shade, funcs, func, p.c0[0], p.c1[0]);
	end
	else
		ncomp := shade^.colorspace^.n;

	hasprevpatch := 0;

	while (not fz_is_eof_bits(stream)) do
	begin


		flag := fz_read_bits(stream, p.bpflag);

		if (flag = 0) then
		begin
			startpt := 0;
			startcolor := 0;
	  end
		else
		begin
			startpt := 4;
			startcolor := 2;
		end;

		for i := startpt  to 11 do
		begin
			v[i].x := read_sample(stream, p.bpcoord, p.x0, p.x1);
			v[i].y := read_sample(stream, p.bpcoord, p.y0, p.y1);
		end;

		for i := startcolor to 3 do
		begin
			for k := 0 to ncomp-1 do
				c[i][k] := read_sample(stream, p.bpcomp, p.c0[k], p.c1[k]);
		end;

		haspatch := 0;

		if (flag =  0) then
		begin
			haspatch := 1;
		end
		else if (flag = 1) and (hasprevpatch<>0) then
		begin
			v[0] := prevp[3];
			v[1] := prevp[4];
			v[2] := prevp[5];
			v[3] := prevp[6];
			//copymemory(@c[0], @prevc[1], ncomp * sizeof(single));
      move(  (@prevc[1])^,(@c[0])^, ncomp * sizeof(single));
			//copymemory(@c[1], @prevc[2], ncomp * sizeof(single));
      move( (@prevc[2])^,(@c[1])^, ncomp * sizeof(single));

			haspatch := 1;
		end
		else if (flag = 2) and (hasprevpatch<>0) then
		begin
			v[0] := prevp[6];
			v[1] := prevp[7];
			v[2] := prevp[8];
			v[3] := prevp[9];
			//copymemory(@c[0], @prevc[2], ncomp * sizeof(single));
      move((@prevc[2])^,(@c[0])^,  ncomp * sizeof(single));
		 //	copymemory(@c[1], @prevc[3], ncomp * sizeof(single));
     move((@prevc[3])^,(@c[1])^,  ncomp * sizeof(single));

			haspatch := 1;
		end
		else if (flag = 3) and  (hasprevpatch<>0) then
		begin
			v[0] := prevp[ 9];
			v[1] := prevp[10];
			v[2] := prevp[11];
			v[3] := prevp[ 0];
		 //	copymemory(@c[0], @prevc[3], ncomp * sizeof(single));
      move((@prevc[3])^,(@c[0])^,  ncomp * sizeof(single));
		//	copymemory(@c[1], @prevc[0], ncomp * sizeof(single));
      move((@prevc[0])^,(@c[1])^,  ncomp * sizeof(single));
			haspatch := 1;
		end;

		if (haspatch<>0) then
		begin


			pdf_make_tensor_patch(@patch, 6, @v);

			for i := 0 to 3 do
			 //	copymemory(@patch.color[i], @c[i], ncomp * sizeof(single));
       	move((@c[i])^,(@patch.color[i])^,  ncomp * sizeof(single));

			draw_patch(shade, @patch, SUBDIV, SUBDIV);

			for i := 0 to 11 do
				prevp[i] := v[i];

			for i := 0 to 3 do
			 //	copymemory(@prevc[i], @c[i], ncomp * sizeof(single));
       move((@c[i])^,(@prevc[i])^,  ncomp * sizeof(single));

			hasprevpatch := 1;
		end;
	end;
end;

procedure 
pdf_load_type7_shade(shade:pfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s;
	funcs:integer; func:pppdf_function_s; stream:pfz_stream_s);
var
	p:mesh_params_s;
	haspatch, hasprevpatch:integer;
	prevc:array[0..3,0..FZ_MAX_COLORS-1] of single;
	prevp:array[0..15] of fz_point_s;
	ncomp:integer;
	i, k:integer;
  c:array[0..3,0..FZ_MAX_COLORS-1] of single;
	v:array[0..15] of fz_point_s;
	startcolor:integer;
	startpt:integer;
	flag:integer;
  patch:pdf_tensor_patch_s;
begin
	pdf_load_mesh_params(xref, dict, @p);

	if (funcs > 0) then
	begin
		ncomp := 1;
		pdf_sample_shade_function(shade, funcs, func, p.c0[0], p.c1[0]);
	end
	else
		ncomp := shade^.colorspace^.n;

	hasprevpatch := 0;

	while (not fz_is_eof_bits(stream)) do
	begin


		flag := fz_read_bits(stream, p.bpflag);

		if (flag = 0) then
		begin
			startpt := 0;
			startcolor := 0;
		end
		else
		begin
			startpt := 4;
			startcolor := 2;
		end;

		for i := startpt to 15 do
		begin
			v[i].x := read_sample(stream, p.bpcoord, p.x0, p.x1);
			v[i].y := read_sample(stream, p.bpcoord, p.y0, p.y1);
		end;

		for i := startcolor to 3 do
		begin
			for k := 0 to ncomp-1 do
				c[i][k] := read_sample(stream, p.bpcomp, p.c0[k], p.c1[k]);
		end;

		haspatch := 0;

		if (flag = 0) then
		begin
			haspatch := 1;
		end
		else if (flag = 1) and (hasprevpatch<>0) then
		begin
			v[0] := prevp[3];
			v[1] := prevp[4];
			v[2] := prevp[5];
			v[3] := prevp[6];
			//copymemory(@c[0], @prevc[1], ncomp * sizeof(single));
      move((@prevc[1])^,(@c[0])^,  ncomp * sizeof(single));
		 //	copymemory(@c[1], @prevc[2], ncomp * sizeof(single));
     move((@prevc[2])^,(@c[1])^,  ncomp * sizeof(single));

			haspatch := 1;
		end
		else if (flag = 2) and (hasprevpatch<>0) then
		begin
			v[0] := prevp[6];
			v[1] := prevp[7];
			v[2] := prevp[8];
			v[3] := prevp[9];
			//copymemory(@c[0], @prevc[2], ncomp * sizeof(single));
      	move((@prevc[2])^,(@c[0])^,  ncomp * sizeof(single));
			//copymemory(@c[1], @prevc[3], ncomp * sizeof(single));
      	move(( @prevc[3])^,(@c[1])^, ncomp * sizeof(single));

			haspatch := 1;
		end
		else if (flag = 3) and (hasprevpatch<>0) then
		begin
			v[0] := prevp[ 9];
			v[1] := prevp[10];
			v[2] := prevp[11];
			v[3] := prevp[ 0];
			//copymemory(@c[0], @prevc[3], ncomp * sizeof(single));
      move((@prevc[3])^, (@c[0])^, ncomp * sizeof(single));
		 //	copymemory(@c[1], @prevc[0], ncomp * sizeof(single));
      move((@prevc[0])^,(@c[1])^,  ncomp * sizeof(single));
			haspatch := 1;
		end;

		if (haspatch<>0) then
		begin


			pdf_make_tensor_patch(@patch, 7, @v);

			for i := 0 to 3 do
				//copymemory(@patch.color[i], @c[i], ncomp * sizeof(single));
        move((@c[i])^, (@patch.color[i])^, ncomp * sizeof(single));

			draw_patch(shade, @patch, SUBDIV, SUBDIV);

			for i := 0 to 15 do
				prevp[i] := v[i];

			for i := 0 to 3 do
				//copymemory(@prevc[i], @c[i], FZ_MAX_COLORS * sizeof(single));
        move( (@c[i])^,(@prevc[i])^, FZ_MAX_COLORS * sizeof(single));
			hasprevpatch := 1;
		end;
	end;
end;

//* Load all of the shading dictionary parameters, then switch on the shading type. */

function
pdf_load_shading_dict(shadep:ppfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s; transform:fz_matrix_s):integer;
var
	error:integer;
	shade:pfz_shade_s;
 	func:array[0..FZ_MAX_COLORS-1] of ppdf_function_s; // = { NULL };
	stream:pfz_stream_s;
	obj:pfz_obj_s;
	funcs:integer;
	type1:integer;
	i:integer;
  label cleanup;
begin
  for i:=0 to FZ_MAX_COLORS-1 do
      func[i]:=nil;

  stream:=nil;

	shade := fz_malloc(sizeof(fz_shade_s));
	shade^.refs := 1;
	shade^.type1 := FZ_MESH;
	shade^.use_background := 0;
	shade^.use_function := 0;
	shade^.matrix := transform;
	shade^.bbox := fz_infinite_rect;
	shade^.extend[0] := 0;
	shade^.extend[1] := 0;

	shade^.mesh_len := 0;
	shade^.mesh_cap := 0;
	shade^.mesh := nil;

	shade^.colorspace := nil;

	funcs := 0;

	obj := fz_dict_gets(dict, 'ShadingType');
	type1 := fz_to_int(obj);

	obj := fz_dict_gets(dict, 'ColorSpace');
	if (obj=nil) then
	begin
		fz_drop_shade(shade);
	//	return fz_throw("shading colorspace is missing");
    result:=fz_throw('shading colorspace is missing');
    exit;
	end;
	error := pdf_load_colorspace(@shade^.colorspace, xref, obj);
	if (error<0)  then
	begin
		fz_drop_shade(shade);
		//return fz_rethrow(error, "cannot load colorspace (%d %d R)", fz_to_num(obj), fz_to_gen(obj));
    result:=fz_rethrow(error, 'cannot load colorspace (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
    exit;
	end;

	obj := fz_dict_gets(dict, 'Background');
	if (obj<>nil) then
	begin
		shade^.use_background := 1;
		for i := 0 to shade^.colorspace^.n-1 do
			shade^.background[i] := fz_to_real(fz_array_get(obj, i));
	end;

	obj := fz_dict_gets(dict, 'BBox');
	if (fz_is_array(obj)) then
	begin
		shade^.bbox := pdf_to_rect(obj);
	end;

	obj := fz_dict_gets(dict, 'Function');
	if (fz_is_dict(obj)) then
	begin
		funcs := 1;

		error := pdf_load_function(@func[0], xref, obj);
		if (error<0)  then
		begin
			error := fz_rethrow(error, 'cannot load shading function (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
      //error:=-1;
			goto cleanup;
		end;
	end
	else if (fz_is_array(obj)) then
	begin
		funcs := fz_array_len(obj);
		if (funcs <> 1) and (funcs <> shade^.colorspace^.n) then
		begin
			error := fz_throw('incorrect number of shading functions');
      //error:=-1;
			goto cleanup;
		end;

		for i := 0 to funcs-1 do
		begin
			error := pdf_load_function(@func[i], xref, fz_array_get(obj, i));
			if (error<0)  then
			begin
				error := fz_rethrow(error, 'cannot load shading function (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
       // result:=-1;
				goto cleanup;
			end;
		end;
	end;

	if (type1 >= 4) and (type1 <= 7) then
	begin
		error := pdf_open_stream(@stream, xref, fz_to_num(dict), fz_to_gen(dict));
		if (error<0)  then
		begin
			error := fz_rethrow(error, 'cannot open shading stream (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
     // result:=-1;
			goto cleanup;
		end;
	end;

	case (type1) of
	1: pdf_load_function_based_shading(shade, xref, dict, func[0]);
	2: pdf_load_axial_shading(shade, xref, dict, funcs, @func);
	3: pdf_load_radial_shading(shade, xref, dict, funcs, @func);
	4: pdf_load_type4_shade(shade, xref, dict, funcs, @func, stream);
	5: pdf_load_type5_shade(shade, xref, dict, funcs, @func, stream);
	6: pdf_load_type6_shade(shade, xref, dict, funcs, @func, stream);
	7: pdf_load_type7_shade(shade, xref, dict, funcs, @func, stream);
	else
   begin
	 result:= fz_throw('unknown shading type: %d', [type1]);
		goto cleanup;
   end;
	end;

	if (stream<>nil) then
		fz_close(stream);
	for i := 0 to funcs-1 do
		if (func[i]<>nil) then
			pdf_drop_function(func[i]);

	shadep^ := shade;
  result:=1;
  exit;
	//return fz_okay;

cleanup:
	if (stream<>nil) then
		fz_close(stream);
	for i := 0 to funcs-1 do
  begin
		if (func[i]<>nil) then
			pdf_drop_function(func[i]);
    end;
	fz_drop_shade(shade);

	result:= fz_rethrow(error, 'cannot load shading type %d (%d %d R)', [type1, fz_to_num(dict), fz_to_gen(dict)]);
  //result:=-1;
  exit;
end;

function pdf_load_shading(shadep:ppfz_shade_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	mat:fz_matrix_s;
	obj:pfz_obj_s;
begin
	shadep^ := pdf_find_item(xref^.store, @fz_drop_shade, dict);
  if (shadep^<>nil) then
	begin
		fz_keep_shade(shadep^);
		//return fz_okay;
    result:=1;
    exit;
	end;

	//* Type 2 pattern dictionary */
	if (fz_dict_gets(dict, 'PatternType')<>nil) then
	begin
		obj := fz_dict_gets(dict, 'Matrix');
		if (obj<>nil) then
			mat := pdf_to_matrix(obj)
		else
			mat := fz_identity;

		obj := fz_dict_gets(dict, 'ExtGState');
		if (obj<>nil) then
		begin
			if (fz_dict_gets(obj, 'CA')<>nil) or  (fz_dict_gets(obj, 'ca')<>nil) then
			begin
				fz_warn('shading with alpha not supported');

			end;
		end;

		obj := fz_dict_gets(dict, 'Shading');
		if (obj=nil) then
    begin
			result:= fz_throw('syntaxerror: missing shading dictionary');

      exit;
    end;

		error := pdf_load_shading_dict(shadep, xref, obj, mat);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load shading dictionary (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);

      exit;
    end;
	end

	//* Naked shading dictionary */
	else
	begin
		error := pdf_load_shading_dict(shadep, xref, dict, fz_identity);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load shading dictionary (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
      exit;
    end;
	end;

	pdf_store_item(xref^.store, @fz_keep_shade, @fz_drop_shade, dict, shadep^);
  result:=1;
//	return fz_okay;
end;


end.
