unit draw_devicess;

interface
uses SysUtils,Math,mylimits,digtypes,draw_glyphss,base_error;


function fz_new_draw_device_type3(cache:pfz_glyph_cache_s; dest:pfz_pixmap_s):pfz_device_s;
function fz_new_draw_device(cache:pfz_glyph_cache_s; dest:pfz_pixmap_s):pfz_device_s;

implementation
uses fz_pixmapss,base_object_functions,draw_paints,draw_blendss,draw_edge,draw_pathss,res_colorspace,
draw_affiness,fz_textx,res_shades,draw_meshss,draw_scaless,fz_dev_null;

procedure fz_knockout_begin(user:pointer);
var
	dev:pfz_draw_device_s;
	bbox:fz_bbox ;
	dest, shape,prev:pfz_pixmap_s;
	isolated,i:integer;
begin
  dev := user;
  isolated := dev^.blendmode and FZ_BLEND_ISOLATED;
	if ((dev^.blendmode and FZ_BLEND_KNOCKOUT) = 0) then
		exit;

	if (dev^.top = STACK_SIZE) then
	begin
	 fz_warn('assert: too many buffers on stack');
	 exit;
	end;

	bbox := fz_bound_pixmap(dev^.dest);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	dest := fz_new_pixmap_with_rect(dev^.dest^.colorspace, bbox);

	if (isolated<>0) then
	begin
		fz_clear_pixmap(dest);
	end
	else
	begin

		i  := dev^.top;
		repeat
      i:=i-1;
			prev := dev^.stack[i].dest;
		until (prev <> nil);
		fz_copy_pixmap_rect(dest, prev, bbox);
	end;

	if (dev^.blendmode = 0) and (isolated<>0) then
	begin
		//* We can render direct to any existing shape plane. If there
		 //* isn't one, we don't need to make one. */
		shape := dev^.shape;
	end
	else
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end;
	dev^.stack[dev^.top].blendmode := dev^.blendmode;
	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
	dev^.top:=dev^.top+1;

	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;
	dev^.blendmode :=dev^.blendmode and (not FZ_BLEND_MODEMASK);
end;

procedure fz_knockout_end(user:pointer);
var
	dev:pfz_draw_device_s;
	group,	shape:pfz_pixmap_s;
	 blendmode:integer;
	isolated:integer;
begin
  dev := user;
  group := dev^.dest;
  shape := dev^.shape;
	if ((dev^.blendmode and FZ_BLEND_KNOCKOUT) = 0) then
		exit;

	if (dev^.top = STACK_SIZE) then
	begin
	 	fz_warn('assert: too many buffers on stack');
		exit;
	end;

	if (dev^.top > 0) then
	begin
		dev^.top:=dev^.top-1;
		blendmode := dev^.blendmode and FZ_BLEND_MODEMASK;
		isolated := dev^.blendmode and FZ_BLEND_ISOLATED;
		dev^.blendmode := dev^.stack[dev^.top].blendmode;
		dev^.shape := dev^.stack[dev^.top].shape;
		dev^.dest := dev^.stack[dev^.top].dest;
		dev^.scissor := dev^.stack[dev^.top].scissor;


		if ((blendmode = 0) and (shape =nil)) then
			fz_paint_pixmap(dev^.dest, group, 255)
		else
			fz_blend_pixmap(dev^.dest, group, 255, blendmode, isolated, shape);

		fz_drop_pixmap(group);
		if (shape <> dev^.shape) then
		begin
			if (dev^.shape<>nil) then
			begin
				fz_paint_pixmap(dev^.shape, shape, 255);
			end;
			fz_drop_pixmap(shape);
	 end;

	end;
end;

procedure fz_draw_fill_path(user:pointer;  path:pfz_path_s; even_odd:integer;ctm: fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	dev:pfz_draw_device_s;
	model :pfz_colorspace_s;
	expansion:single;
	 flatness:single;
	colorbv:array[0..FZ_MAX_COLORS ] of byte;
	colorfv:array[0..FZ_MAX_COLORS-1] of single;
	 bbox:fz_bbox;
	i:integer;
begin
  dev := user;
	model := dev^.dest^.colorspace;
	expansion := fz_matrix_expansion(ctm);
	flatness := 0.3/ expansion;
	fz_reset_gel(dev^.gel, dev^.scissor);
	fz_flatten_fill_path(dev^.gel, path, ctm, flatness);
	fz_sort_gel(dev^.gel);

	bbox := fz_bound_gel(dev^.gel);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);

	if (fz_is_empty_rect(bbox)) then
		exit;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	fz_convert_color(colorspace, color, model, @colorfv);
	for i := 0 to model^.n-1 do
		colorbv[i] := trunc(colorfv[i] * 255);
	colorbv[i] := trunc(alpha * 255);

	fz_scan_convert(dev^.gel, even_odd, bbox, dev^.dest, @colorbv);
	if (dev^.shape<>nil) then
	begin
		fz_reset_gel(dev^.gel, dev^.scissor);
		fz_flatten_fill_path(dev^.gel, path, ctm, flatness);
		fz_sort_gel(dev^.gel);

		colorbv[0] :=trunc(alpha * 255);
		fz_scan_convert(dev^.gel, even_odd, bbox, dev^.shape, @colorbv);
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

procedure
fz_draw_stroke_path(user:pointer; path:pfz_path_s; stroke:pfz_stroke_state_s;ctm: fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	dev:pfz_draw_device_s;
  	model:pfz_colorspace_s;
	 expansion:single;
	flatness,	linewidth:single;
	colorbv:array[0..FZ_MAX_COLORS ] of byte;
	colorfv:array[0..FZ_MAX_COLORS-1] of single;
	 bbox:fz_bbox;
	 i:integer;
begin
  dev := user;
	model := dev^.dest^.colorspace;
	expansion := fz_matrix_expansion(ctm);
	flatness := 0.3 / expansion;
	linewidth := stroke^.linewidth;
	if (linewidth * expansion < 0.1) then
		linewidth := 1 / expansion;

	fz_reset_gel(dev^.gel, dev^.scissor);
	if (stroke^.dash_len > 0) then
		fz_flatten_dash_path(dev^.gel, path, stroke, ctm, flatness, linewidth)
	else
		fz_flatten_stroke_path(dev^.gel, path, stroke, ctm, flatness, linewidth);
	fz_sort_gel(dev^.gel);

	bbox := fz_bound_gel(dev^.gel);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);

	if (fz_is_empty_rect(bbox)) then
		exit;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0  then
		fz_knockout_begin(dev);

	fz_convert_color(colorspace, color, model, @colorfv);
	for i := 0 to model^.n-1 do
		colorbv[i] := trunc(colorfv[i] * 255);
   	colorbv[i] := trunc(alpha * 255);

	fz_scan_convert(dev^.gel, 0, bbox, dev^.dest, @colorbv);
	if (dev^.shape<>nil) then
	begin
		fz_reset_gel(dev^.gel, dev^.scissor);
		if (stroke^.dash_len > 0) then
			fz_flatten_dash_path(dev^.gel, path, stroke, ctm, flatness, linewidth)
		else
			fz_flatten_stroke_path(dev^.gel, path, stroke, ctm, flatness, linewidth);
		fz_sort_gel(dev^.gel);

		colorbv[0] := 255;
		fz_scan_convert(dev^.gel, 0, bbox, dev^.shape, @colorbv);
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

procedure fz_draw_clip_path(user:pointer; path:pfz_path_s; rect:pfz_rect_s;  even_odd:integer; ctm: fz_matrix);
var
  	dev:pfz_draw_device_s;
  	model:pfz_colorspace_s;
	 expansion:single;
	flatness:single;

	 mask, dest, shape:pfz_pixmap_s;
	 bbox:fz_bbox;
begin
  dev := user;
  model := dev^.dest^.colorspace;
  expansion := fz_matrix_expansion(ctm);
  flatness := 0.3 / expansion;
	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
	  exit;
	end;

	fz_reset_gel(dev^.gel, dev^.scissor);
	fz_flatten_fill_path(dev^.gel, path, ctm, flatness);
	fz_sort_gel(dev^.gel);

	bbox := fz_bound_gel(dev^.gel);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	if (rect<>nil) then
		bbox := fz_intersect_bbox(bbox, fz_round_rect(rect^));

	if (fz_is_empty_rect(bbox)) or (fz_is_rect_gel(dev^.gel)<>0) then
	begin
		dev^.stack[dev^.top].scissor := dev^.scissor;
		dev^.stack[dev^.top].mask := nil;
		dev^.stack[dev^.top].dest := nil;
		dev^.stack[dev^.top].shape := dev^.shape;
		dev^.stack[dev^.top].blendmode := dev^.blendmode;
		dev^.scissor := bbox;

		dev^.top:=dev^.top+1;
		exit;
	end;

	mask := fz_new_pixmap_with_rect(nil, bbox);
	fz_clear_pixmap(mask);
	dest := fz_new_pixmap_with_rect(model, bbox);
	//* FIXME: See note #1 */
	fz_clear_pixmap(dest);
	if (dev^.shape<>nil) then
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end
	else
		shape := nil;

	fz_scan_convert(dev^.gel, even_odd, bbox, mask, nil);

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].mask := mask;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
	//* FIXME: See note #1 */
	dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;
	dev^.top:=dev^.top+1;
end;

procedure fz_draw_clip_stroke_path(user:pointer; path:pfz_path_s; rect:pfz_rect_s; stroke:pfz_stroke_state_s; ctm: fz_matrix);
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
	 expansion:single;
	 flatness:single;
	linewidth:single;
	 mask, dest, shape:pfz_pixmap_s;
	bbox:fz_bbox ;
begin
  dev := user;
	model := dev^.dest^.colorspace;
	expansion := fz_matrix_expansion(ctm);
	flatness := 0.3 / expansion;
	linewidth := stroke^.linewidth;

	if (dev^.top = STACK_SIZE) then
	begin
	 	fz_warn('assert: too many buffers on stack');
		exit;
	end;

	if (linewidth * expansion < 0.1) then
		linewidth:= 1 / expansion;

	fz_reset_gel(dev^.gel, dev^.scissor);
	if (stroke^.dash_len > 0)  then
		fz_flatten_dash_path(dev^.gel, path, stroke, ctm, flatness, linewidth)
	else
		fz_flatten_stroke_path(dev^.gel, path, stroke, ctm, flatness, linewidth);
	fz_sort_gel(dev^.gel);

	bbox := fz_bound_gel(dev^.gel);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	if (rect<>nil) then
		bbox := fz_intersect_bbox(bbox, fz_round_rect(rect^));

	mask := fz_new_pixmap_with_rect(nil, bbox);
	fz_clear_pixmap(mask);
	dest := fz_new_pixmap_with_rect(model, bbox);
	//* FIXME: See note #1 */
	fz_clear_pixmap(dest);
	if (dev^.shape<>nil) then
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end
	else
		shape := nil;

	if (not fz_is_empty_rect(bbox)) then
		fz_scan_convert(dev^.gel, 0, bbox, mask, nil);

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].mask := mask;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
	//* FIXME: See note #1 */
	dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;

	dev^.top:=dev^.top+1;
end;

procedure draw_glyph(colorbv:pbyte; dst:pfz_pixmap_s; msk:pfz_pixmap_s; 	xorig:integer; yorig:integer; scissor: fz_bbox );
var
	dp, mp:pbyte;
	bbox:fz_bbox ;
	 x, y, w, h:integer;
begin
	bbox := fz_bound_pixmap(msk);
	bbox.x0 :=bbox.x0 + xorig;
	bbox.y0 :=bbox.y0 +yorig;
	bbox.x1 :=bbox.x1 +xorig;
	bbox.y1 :=bbox.y1 + yorig;

	bbox := fz_intersect_bbox(bbox, scissor); //* scissor < dst */
	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;

	mp := pointer(cardinal(msk^.samples) + ((y - msk^.y - yorig) * msk^.w + (x - msk^.x - xorig)));
	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * dst^.n);

	assert(msk^.n = 1);

	while (h>0) do
	begin
    h:=h-1;
		if (dst^.colorspace<>nil) then
			fz_paint_span_with_color(dp, mp, dst^.n, w, colorbv)
		else
			fz_paint_span(dp, mp, 1, w, 255);
		inc(dp, dst^.w * dst^.n);
		inc(mp,msk^.w);
	end;
end;
function QUANT(x,a:single):single;
begin
 result:=((trunc((x * a))) / (a))
end;
procedure fz_draw_fill_text(user:pointer;  text:pfz_text_s; ctm: fz_matrix;	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
	colorbv:array[0..FZ_MAX_COLORS ] of byte;
	shapebv:byte;
	 colorfv:array[0..FZ_MAX_COLORS-1] of single;
	 tm, trm:fz_matrix;
	glyph:pfz_pixmap_s;
	 i, x, y, gid:integer;
   ctm1:fz_matrix_s ;
begin
  dev := user;
  model := dev^.dest^.colorspace;
	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	fz_convert_color(colorspace, color, model, @colorfv);
	for i := 0 to model^.n-1 do
		colorbv[i] := trunc(colorfv[i] * 255);
	colorbv[i] := trunc(alpha * 255);
	shapebv := 255;

	tm := text^.trm;

	for i := 0 to text^.len-1 do
	begin
		gid := fz_text_items(text^.items)[i].gid;
		if (gid < 0) then
			continue;

		tm.e := fz_text_items(text^.items)[i].x;
		tm.f := fz_text_items(text^.items)[i].y;
		trm := fz_concat(tm, ctm);
		x := floor(trm.e);
		y := floor(trm.f);
		trm.e := QUANT(trm.e - floor(trm.e), HSUBPIX);
			trm.f := QUANT(trm.f - floor(trm.f), VSUBPIX);

		glyph := fz_render_glyph(dev^.cache, text^.font, gid, trm, model);
		if (glyph<>nil) then
		begin
			if (glyph^.n = 1) then
			begin
				draw_glyph(@colorbv, dev^.dest, glyph, x, y, dev^.scissor);
				if (dev^.shape<>nil) then
					draw_glyph(@shapebv, dev^.shape, glyph, x, y, dev^.scissor);
			end
			else
			begin
			 //	ctm1 :=fz_matrix(glyph^.w, 0.0, 0.0, -glyph^.h, x + glyph^.x, y + glyph^.y + glyph^.h);
        ctm1.a:=glyph^.w;
        ctm1.b:=0;
        ctm1.c:=0;
        ctm1.d:=-glyph^.h;
        ctm1.e:=x + glyph^.x;
        ctm1.f:=y + glyph^.y + glyph^.h;

				fz_paint_image(dev^.dest, dev^.scissor, dev^.shape, glyph, ctm1, trunc(alpha * 255));
			end;
			fz_drop_pixmap(glyph);
		end;
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)>0 then
		fz_knockout_end(dev);
end;

procedure fz_draw_stroke_text(user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s; ctm: fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	 dev:pfz_draw_device_s;
	 model:pfz_colorspace_s;
	 colorbv:array[0..FZ_MAX_COLORS ] of byte;
	 colorfv:array[0..FZ_MAX_COLORS-1] of single;
	 tm, trm:fz_matrix;
   glyph:pfz_pixmap_s;
	 i, x, y, gid:integer;
begin
   dev := user;
   model := dev^.dest^.colorspace;
	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	fz_convert_color(colorspace, color, model, @colorfv);
	for i := 0 to model^.n-1 do
		colorbv[i] := trunc(colorfv[i] * 255);
	colorbv[i] := trunc(alpha * 255);

	tm := text^.trm;

	for i := 0 to text^.len-1 do
	begin
		gid := fz_text_items(text^.items)[i].gid;
		if (gid < 0) then
			continue;

		tm.e := fz_text_items(text^.items)[i].x;
		tm.f := fz_text_items(text^.items)[i].y;
		trm := fz_concat(tm, ctm);
		x := floor(trm.e);
		y := floor(trm.f);
		trm.e := QUANT(trm.e - floor(trm.e), HSUBPIX);
		trm.f := QUANT(trm.f - floor(trm.f), VSUBPIX);

		glyph := fz_render_stroked_glyph(dev^.cache, text^.font, gid, trm, ctm, stroke);
		if (glyph<>nil) then
		begin
			draw_glyph(@colorbv, dev^.dest, glyph, x, y, dev^.scissor);
			if (dev^.shape<>nil) then
				draw_glyph(@colorbv, dev^.shape, glyph, x, y, dev^.scissor);
			fz_drop_pixmap(glyph);
		end;
	end ;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

procedure fz_draw_clip_text(user:pointer;  text:pfz_text_s;ctm: fz_matrix;  accumulate:integer);
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
	bbox:fz_bbox ;
	mask, dest, shape:pfz_pixmap_s;
	tm, trm:fz_matrix;
	glyph:pfz_pixmap_s;
	i, x, y, gid:integer;
begin
	//* If accumulate == 0 then this text object is guaranteed complete */
	//* If accumulate == 1 then this text object is the first (or only) in a sequence */
	//* If accumulate == 2 then this text object is a continuation */
  dev := user;
	model := dev^.dest^.colorspace;
	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
    exit;
		//return;
	end ;

	if (accumulate = 0) then
	begin
		//* make the mask the exact size needed */
		bbox := fz_round_rect(fz_bound_text(text, ctm));
		bbox := fz_intersect_bbox(bbox, dev^.scissor);
	end
	else
	begin
		//* be conservative about the size of the mask needed */
		bbox := dev^.scissor;
	end;

	if (accumulate = 0) or (accumulate = 1) then
	begin
		mask := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(mask);
		dest := fz_new_pixmap_with_rect(model, bbox);
		//* FIXME: See note #1 */
		fz_clear_pixmap(dest);
		if (dev^.shape<>nil) then
		begin
			shape := fz_new_pixmap_with_rect(nil, bbox);
			fz_clear_pixmap(shape);
		end
		else
			shape := nil;

		dev^.stack[dev^.top].scissor := dev^.scissor;
		dev^.stack[dev^.top].mask := mask;
		dev^.stack[dev^.top].dest := dev^.dest;
		dev^.stack[dev^.top].shape := dev^.shape;
		//* FIXME: See note #1 */
		dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
		dev^.scissor := bbox;
		dev^.dest := dest;
		dev^.shape := shape;
		dev^.top:=dev^.top+1;
	end
	else
	begin
		mask := dev^.stack[dev^.top-1].mask;
	end;

	if (not fz_is_empty_rect(bbox)) then
	begin
		tm := text^.trm;

		for i := 0 to text^.len-1 do
		begin
			gid := fz_text_items(text^.items)[i].gid;
			if (gid < 0)  then
				continue;

			tm.e := fz_text_items(text^.items)[i].x;
			tm.f := fz_text_items(text^.items)[i].y;
			trm := fz_concat(tm, ctm);
			x := floor(trm.e);
			y := floor(trm.f);
			trm.e := QUANT(trm.e - floor(trm.e), HSUBPIX);
			trm.f := QUANT(trm.f - floor(trm.f), VSUBPIX);

			glyph := fz_render_glyph(dev^.cache, text^.font, gid, trm, model);
			if (glyph<>nil) then
			begin
				draw_glyph(nil, mask, glyph, x, y, bbox);
				if (dev^.shape<>nil) then
					draw_glyph(nil, dev^.shape, glyph, x, y, bbox);
				fz_drop_pixmap(glyph);
			end;
		end;
	end;
end;

procedure
fz_draw_clip_stroke_text(user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s; ctm: fz_matrix);
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
	bbox:fz_bbox ;
	mask, dest, shape:pfz_pixmap_s;
	tm, trm:fz_matrix;
	glyph:pfz_pixmap_s;
	 i, x, y, gid:integer;
begin
   dev := user;
   model := dev^.dest^.colorspace;

	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
		//return;
    exit;
	end;

	//* make the mask the exact size needed */
	bbox := fz_round_rect(fz_bound_text(text, ctm));
	bbox := fz_intersect_bbox(bbox, dev^.scissor);

	mask := fz_new_pixmap_with_rect(nil, bbox);
	fz_clear_pixmap(mask);
	dest := fz_new_pixmap_with_rect(model, bbox);
	//* FIXME: See note #1 */
	fz_clear_pixmap(dest);
	if (dev^.shape<>nil) then
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end
	else
		shape := dev^.shape;

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].mask := mask;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
//* FIXME: See note #1 */
	dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;

	dev^.top:=dev^.top+1;

	if (not fz_is_empty_rect(bbox)) then
	begin
		tm := text^.trm;

		for i := 0 to text^.len-1 do
		begin
			gid := fz_text_items(text^.items)[i].gid;
			if (gid < 0)then
				continue;

			tm.e := fz_text_items(text^.items)[i].x;
			tm.f := fz_text_items(text^.items)[i].y;
			trm := fz_concat(tm, ctm);
			x := floor(trm.e);
			y := floor(trm.f);
			trm.e := QUANT(trm.e - floor(trm.e), HSUBPIX);
			trm.f := QUANT(trm.f - floor(trm.f), VSUBPIX);

			glyph := fz_render_stroked_glyph(dev^.cache, text^.font, gid, trm, ctm, stroke);
			if (glyph<>nil) then
			begin
				draw_glyph(nil, mask, glyph, x, y, bbox);
				if (dev^.shape<>nil) then
					draw_glyph(nil, dev^.shape, glyph, x, y, bbox);
				fz_drop_pixmap(glyph);
			end;
		end;
	end;
end;

procedure
fz_draw_ignore_text(user:pointer; text:pfz_text_s;ctm: fz_matrix);
begin
 exit;
end;

procedure
fz_draw_fill_shade(user:pointer; shade:pfz_shade_s; ctm: fz_matrix ; alpha:single);
var
  dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
  s:pbyte;
	dest:pfz_pixmap_s;
	bounds:fz_rect ;
  bbox, scissor:fz_bbox;
  colorbv:array[0..FZ_MAX_COLORS ] of byte;
  colorfv:array[0..FZ_MAX_COLORS-1] of single;
  x, y, n, i:integer;
 begin
  dev := user;
	model := dev^.dest^.colorspace;
  dest := dev^.dest;
	bounds := fz_bound_shade(shade, ctm);
  
	bbox := fz_intersect_bbox(fz_round_rect(bounds), dev^.scissor);
	scissor := dev^.scissor;

	// TODO: proper clip by shade^.bbox

	if (fz_is_empty_rect(bbox)) then
		exit;

	if (model=nil) then
	begin
		//fz_warn("cannot render shading directly to an alpha mask");
		//return;
    exit;
	end;

	if (alpha < 1) then
	begin
		dest := fz_new_pixmap_with_rect(dev^.dest^.colorspace, bbox);
		fz_clear_pixmap(dest);
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	if (shade^.use_background<>0) then
	begin

		fz_convert_color(shade^.colorspace, @shade^.background, model, @colorfv);
		for i := 0 to model^.n-1 do
			colorbv[i] := trunc(colorfv[i] * 255);
		colorbv[i] := 255;

		n := dest^.n;
    y := scissor.y0;
		while ( y < scissor.y1) do
		begin
      y:=y+1;
			s := pointer(cardinal(dest^.samples) + ((scissor.x0 - dest^.x) + (y - dest^.y) * dest^.w) * dest^.n);
			for x := scissor.x0 to scissor.x1-1 do
			begin
				for i := 0 to n-1 do
					s^:= colorbv[i];
          inc(s);
			end;
		end;
		if (dev^.shape<>nil) then
		begin
			for y := scissor.y0 to scissor.y1-1 do
			begin
				s := pointer(cardinal(dev^.shape^.samples) + (scissor.x0 - dev^.shape^.x) + (y - dev^.shape^.y) * dev^.shape^.w);
				for x := scissor.x0 to scissor.x1-1 do
				begin
					s^:=255;
          inc(s);
				end;
			end;
		end;
	end;

	fz_paint_shade(shade, ctm, dest, bbox);
	if (dev^.shape<>nil) then
		fz_clear_pixmap_rect_with_color(dev^.shape, 255, bbox);

	if (alpha < 1)  then
	begin
		fz_paint_pixmap(dev^.dest, dest, trunc(alpha * 255));
		fz_drop_pixmap(dest);
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

function fz_transform_pixmap(image:pfz_pixmap_s;ctm: pfz_matrix_s;  x,  y,  dx, dy,  gridfit:integer):pfz_pixmap_s;
var
	scaled:pfz_pixmap_s;
begin
	if ((ctm^.a <> 0) and (ctm^.b = 0) and (ctm^.c = 0) and (ctm^.d <> 0) ) then
	begin
		//* Unrotated or X-flip or Y-flip or XY-flip */
		scaled := fz_scale_pixmap_gridfit(image, ctm^.e, ctm^.f, ctm^.a, ctm^.d, gridfit);
		if (scaled = nil) then
    begin
			result:=nil;
      exit;
    end;
		ctm^.a := scaled^.w;
		ctm^.d := scaled^.h;
		ctm^.e := scaled^.x;
		ctm^.f := scaled^.y;
		result:= scaled;
    exit;
	end;

	if ((ctm^.a = 0) and (ctm^.b <> 0) and ( ctm^.c <> 0) and (ctm^.d = 0)) then
	begin
		//* Other orthogonal flip/rotation cases */
		scaled := fz_scale_pixmap_gridfit(image, ctm^.f, ctm^.e, ctm^.b, ctm^.c, gridfit);
		if (scaled = nil) then
    begin
			result:=nil;
      exit;
    end;
		ctm^.b := scaled^.w;
		ctm^.c := scaled^.h;
		ctm^.f := scaled^.x;
		ctm^.e := scaled^.y;
		result:=scaled;
    exit;
	end;

	//* Downscale, non rectilinear case */
	if (dx > 0) and (dy > 0) then
	begin
		scaled := fz_scale_pixmap(image, 0, 0, dx, dy);
		result:= scaled;
    exit;
	end;

	result:=nil;
end;

procedure
fz_draw_fill_image(user:pointer;  image:pfz_pixmap_s; ctm: fz_matrix;  alpha:single);
var
	dev:pfz_draw_device_s;
	model :pfz_colorspace_s;
	converted:pfz_pixmap_s;
	scaled:pfz_pixmap_s;
	after, dx, dy,gridfit:integer;
begin
  dev := user;
	model := dev^.dest^.colorspace;
	converted := nil;
	scaled := nil;
	if (model=nil) then
	begin
		//fz_warn("cannot render image directly to an alpha mask");
		//return;
    exit;
	end;

	if (image^.w = 0) or (image^.h = 0) then
		exit;

	//* convert images with more components (cmyk^.rgb) before scaling */
	//* convert images with fewer components (gray^.rgb after scaling */
	//* convert images with expensive colorspace transforms after scaling */

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	after := 0;
	if (image^.colorspace = get_fz_device_gray) then
		after := 1;

	if ((image^.colorspace <> model) and (after=0)) then
	begin
		converted := fz_new_pixmap_with_rect(model, fz_bound_pixmap(image));
		fz_convert_pixmap(image, converted);
		image := converted;
	end;

	dx := trunc(sqrt(ctm.a * ctm.a + ctm.b * ctm.b));
	dy := trunc(sqrt(ctm.c * ctm.c + ctm.d * ctm.d));
	if (dx < image^.w) and (dy < image^.h) then
	begin
    if ((alpha = 1.0) and ((dev^.flags and FZ_DRAWDEV_FLAGS_TYPE3)=0)) then
       gridfit:=1
       else
       gridfit:=0;
	 //	gridfit := alpha == 1.0f && !(dev^.flags & FZ_DRAWDEV_FLAGS_TYPE3);
		scaled := fz_transform_pixmap(image, @ctm, dev^.dest^.x, dev^.dest^.y, dx, dy, gridfit);
		if (scaled = nil) then
		begin
			if (dx < 1) then
				dx := 1;
			if (dy < 1) then
				dy := 1;
			scaled := fz_scale_pixmap(image, image^.x, image^.y, dx, dy);
		end;
		if (scaled <>nil) then
			image := scaled;
	end;

	if (image^.colorspace <> model) then
	begin
		if ((image^.colorspace = get_fz_device_gray) and (model = get_fz_device_rgb)) or
			((image^.colorspace = get_fz_device_gray) and (model = get_fz_device_bgr)) then
		begin
			//* We have special case rendering code for gray ^. rgb/bgr */
		end
		else
		begin
			converted := fz_new_pixmap_with_rect(model, fz_bound_pixmap(image));
			fz_convert_pixmap(image, converted);
			image := converted;
		end;
	end;
  //outprintf(inttostr( byte_items(image^.samples)[0]));
	fz_paint_image(dev^.dest, dev^.scissor, dev^.shape, image, ctm, trunc(alpha * 255));

	if (scaled<>nil) then
		fz_drop_pixmap(scaled);
	if (converted<>nil) then
		fz_drop_pixmap(converted);

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

procedure fz_draw_fill_image_mask(user:pointer; image:pfz_pixmap_s;ctm: fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle;  alpha:single);
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s ;
  colorbv:array[0..FZ_MAX_COLORS ] of byte;
  colorfv:array[0..FZ_MAX_COLORS-1] of single;
	scaled:pfz_pixmap_s;
	 dx, dy, i,gridfit:integer;
begin
  dev:=user;
  model:=dev^.dest^.colorspace;
  scaled:=nil;
	if (image^.w = 0) or (image^.h = 0) then
		exit;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	dx := trunc(sqrt(ctm.a * ctm.a + ctm.b * ctm.b));
	dy := trunc(sqrt(ctm.c * ctm.c + ctm.d * ctm.d));
	if (dx < image^.w) and (dy < image^.h) then
	begin
    if (alpha = 1.0) and ((dev^.flags and FZ_DRAWDEV_FLAGS_TYPE3)=0) then
      gridfit:=1
      else
      gridfit:=0;

		scaled := fz_transform_pixmap(image, @ctm, dev^.dest^.x, dev^.dest^.y, dx, dy, gridfit);
		if (scaled =nil) then
		begin
			if (dx < 1) then
				dx := 1;
			if (dy < 1) then
				dy := 1;
			scaled := fz_scale_pixmap(image, image^.x, image^.y, dx, dy);
		end;
		if (scaled <>nil) then
			image := scaled;
	end;

	fz_convert_color(colorspace, color, model, @colorfv);
	for i := 0 to model^.n-1 do
		colorbv[i] := trunc(colorfv[i] * 255);
	colorbv[i] := trunc(alpha * 255);

	fz_paint_image_with_color(dev^.dest, dev^.scissor, dev^.shape, image, ctm, @colorbv);

	if (scaled<>nil) then
		fz_drop_pixmap(scaled);

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);
end;

procedure
fz_draw_clip_image_mask(user:pointer; image:pfz_pixmap_s; rect:pfz_rect_s; ctm: fz_matrix);
var
	dev:pfz_draw_device_s;
	 model:pfz_colorspace_s;
	bbox:fz_bbox ;
	mask, dest, shape:pfz_pixmap_s;
	scaled:pfz_pixmap_s; 
	dx, dy,gridfit:integer;
begin
  dev := user;
  model := dev^.dest^.colorspace;
  scaled:=nil;
	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
		exit;
	end;

	if (image^.w = 0) or (image^.h = 0) then
	begin
		dev^.stack[dev^.top].scissor := dev^.scissor;
		dev^.stack[dev^.top].mask := nil;
		dev^.stack[dev^.top].dest := nil;
		dev^.stack[dev^.top].blendmode := dev^.blendmode;
		dev^.scissor := fz_empty_bbox;
		dev^.top:=dev^.top+1;
		exit;
	end;

	bbox := fz_round_rect(fz_transform_rect(ctm, fz_unit_rect));
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	if (rect<>nil) then
		bbox := fz_intersect_bbox(bbox, fz_round_rect(rect^));

	mask := fz_new_pixmap_with_rect(nil, bbox);
	fz_clear_pixmap(mask);
	dest := fz_new_pixmap_with_rect(model, bbox);
	//* FIXME: See note #1 */
	fz_clear_pixmap(dest);
	if (dev^.shape<>nil) then
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end
	else
		shape :=nil;

	dx := trunc(sqrt(ctm.a * ctm.a + ctm.b * ctm.b));
	dy := trunc(sqrt(ctm.c * ctm.c + ctm.d * ctm.d));
	if (dx < image^.w) and (dy < image^.h) then
	begin
    if (dev^.flags and FZ_DRAWDEV_FLAGS_TYPE3)=0 then
        gridfit:=1
        else
        gridfit:=0;
		scaled := fz_transform_pixmap(image, @ctm, dev^.dest^.x, dev^.dest^.y, dx, dy, gridfit);
		if (scaled = nil) then
		begin
			if (dx < 1) then
				dx := 1;
			if (dy < 1) then
				dy := 1;
			scaled := fz_scale_pixmap(image, image^.x, image^.y, dx, dy);
		end;
		if (scaled <>nil) then
			image := scaled;
	end;

	fz_paint_image(mask, bbox, dev^.shape, image, ctm, 255);

	if (scaled<>nil) then
		fz_drop_pixmap(scaled);

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].mask := mask;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
	//* FIXME: See note #1 */
	dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;
	dev^.top:=dev^.top+1;
end;

procedure
fz_draw_pop_clip(user:pointer);
var
	dev:pfz_draw_device_s;
	mask, dest, shape:pfz_pixmap_s;
begin
  dev := user;
	if (dev^.top > 0) then
	begin
		dev^.top:=dev^.top-1;
		dev^.scissor := dev^.stack[dev^.top].scissor;
		mask := dev^.stack[dev^.top].mask;
		dest := dev^.stack[dev^.top].dest;
		shape := dev^.stack[dev^.top].shape;
		dev^.blendmode := dev^.stack[dev^.top].blendmode;

		(* We can get here with mask == NULL if the clipping actually
		 * resolved to a rectangle earlier. In this case, we will
		 * have a dest, and the shape will be unchanged.
		 *)
		if (mask<>nil) then
		begin
			assert(dest<>nil);
			fz_paint_pixmap_with_mask(dest, dev^.dest, mask);
			if (shape <>nil) then
			begin
				assert(shape <> dev^.shape);
				fz_paint_pixmap_with_mask(shape, dev^.shape, mask);
				fz_drop_pixmap(dev^.shape);
				dev^.shape := shape;
			end;
			fz_drop_pixmap(mask);
			fz_drop_pixmap(dev^.dest);
			dev^.dest := dest;
		end
		else
		begin
			assert(dest = nil);
			assert(shape = dev^.shape);
		end;
	end;
end;

procedure
fz_draw_begin_mask(user:pointer; rect:fz_rect;  luminosity:integer;  colorspace:pfz_colorspace_s; colorfv:psingle);
var
	dev:pfz_draw_device_s;
	dest,shape:pfz_pixmap_s;
	bbox:fz_bbox;
  bc:single;
begin
  dev := user;
  shape := dev^.shape;
	if (dev^.top = STACK_SIZE) then
	begin
		//fz_warn("assert: too many buffers on stack");
		//return;
    exit;
	end;

	bbox := fz_round_rect(rect);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	dest := fz_new_pixmap_with_rect(get_fz_device_gray, bbox);
	if (dev^.shape<>nil) then
	begin
		(* FIXME: If we ever want to support AIS true, then we
		 * probably want to create a shape pixmap here, using:
		 *     shape = fz_new_pixmap_with_rect(NULL, bbox);
		 * then, in the end_mask code, we create the mask from this
		 * rather than dest.
		 *)
		shape := nil;
	end;

	if (luminosity<>0) then
	begin
			if (colorspace=nil) then
			colorspace := get_fz_device_gray;
		fz_convert_color(colorspace, colorfv, get_fz_device_gray, @bc);
		fz_clear_pixmap_with_color(dest, trunc(bc * 255));
		if (shape<>nil) then
			fz_clear_pixmap_with_color(shape, 255);
	end
	else
	begin
		fz_clear_pixmap(dest);
		if (shape<>nil) then
			fz_clear_pixmap(shape);
	end;

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].luminosity := luminosity;
	dev^.stack[dev^.top].shape := dev^.shape;
	dev^.stack[dev^.top].blendmode := dev^.blendmode;

	dev^.top:=dev^.top+1;

	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;
end;

procedure fz_draw_end_mask(user:pointer) ;
var
	dev:pfz_draw_device_s;
  mask,maskshape,temp, dest:pfz_pixmap_s;
	bbox:fz_bbox ;
	luminosity:integer;
begin
  dev := user;
	mask := dev^.dest;
	maskshape := dev^.shape;

	if (dev^.top = STACK_SIZE) then
	begin
		//fz_warn("assert: too many buffers on stack");
	 //	return;
   exit;
	end;

	if (dev^.top > 0) then
	begin
		//* pop soft mask buffer */
		dev^.top:=dev^.top-1;
		luminosity := dev^.stack[dev^.top].luminosity;
		dev^.scissor := dev^.stack[dev^.top].scissor;
		dev^.dest := dev^.stack[dev^.top].dest;
		dev^.shape := dev^.stack[dev^.top].shape;

		//* convert to alpha mask */
		temp := fz_alpha_from_gray(mask, luminosity);
		fz_drop_pixmap(mask);
		fz_drop_pixmap(maskshape);

		//* create new dest scratch buffer */
		bbox := fz_bound_pixmap(temp);
		dest := fz_new_pixmap_with_rect(dev^.dest^.colorspace, bbox);
		//* FIXME: See note #1 */
		fz_clear_pixmap(dest);

		//* push soft mask as clip mask */
		dev^.stack[dev^.top].scissor := dev^.scissor;
		dev^.stack[dev^.top].mask := temp;
		dev^.stack[dev^.top].dest := dev^.dest;
		//* FIXME: See note #1 */
		dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
		//* If we have a shape, then it'll need to be masked with the
		// * clip mask when we pop. So create a new shape now. */
		if (dev^.shape<>nil) then
		begin
			dev^.stack[dev^.top].shape := dev^.shape;
			dev^.shape := fz_new_pixmap_with_rect(nil, bbox);
			fz_clear_pixmap(dev^.shape);
		end;
		dev^.scissor := bbox;
		dev^.dest := dest;

		dev^.top:=dev^.top-1;
	end;
end;

procedure
fz_draw_begin_group(user:pointer;rect: fz_rect;  isolated,  knockout, blendmode:integer;  alpha:single);
var
 dev :pfz_draw_device_s;
 model:pfz_colorspace_s;
  bbox:	fz_bbox;
	dest, shape:pfz_pixmap_s;
  a1,a2:integer;
begin
  dev := user;
	model := dev^.dest^.colorspace;
	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
	 //	return;
   exit;
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);

	bbox := fz_round_rect(rect);
	bbox := fz_intersect_bbox(bbox, dev^.scissor);
	dest := fz_new_pixmap_with_rect(model, bbox);



	if (isolated<>0) then
	begin
		fz_clear_pixmap(dest);
	end
	else
	begin
		fz_copy_pixmap_rect(dest, dev^.dest, bbox);
	end;

	if ((blendmode = 0) and (alpha = 1.0) and (isolated<>0)) then
	begin
		//* We can render direct to any existing shape plane. If there
		// * isn't one, we don't need to make one. */
		shape := dev^.shape;
	end
	else
	begin
		shape := fz_new_pixmap_with_rect(nil, bbox);
		fz_clear_pixmap(shape);
	end;

	dev^.stack[dev^.top].alpha := alpha;
	dev^.stack[dev^.top].blendmode := dev^.blendmode;
	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;

	dev^.top:=dev^.top-1;

	dev^.scissor := bbox;
	dev^.dest := dest;
	dev^.shape := shape;
  if isolated<>0 then
  a1:=  FZ_BLEND_ISOLATED
  else
  a1:=0;
  if knockout<>0 then
  a2:=FZ_BLEND_KNOCKOUT
  else
  a2:=0;

	dev^.blendmode :=( blendmode or a1 or a2);
end;

procedure fz_draw_end_group(user:pointer);
var
	dev:pfz_draw_device_s;
	group,shape:pfz_pixmap_s;
	 blendmode, isolated:integer;
	 alpha:single;
begin
  dev := user;
	group := dev^.dest;
	shape := dev^.shape;
	if (dev^.top > 0) then
	begin
		dev^.top:=dev^.top-1;
		alpha := dev^.stack[dev^.top].alpha;
		blendmode:= dev^.blendmode and FZ_BLEND_MODEMASK;
		isolated := dev^.blendmode and FZ_BLEND_ISOLATED;
		dev^.blendmode := dev^.stack[dev^.top].blendmode;
		dev^.shape := dev^.stack[dev^.top].shape;
		dev^.dest := dev^.stack[dev^.top].dest;
		dev^.scissor := dev^.stack[dev^.top].scissor;

		if ((blendmode = 0) and (shape = nil)) then
			fz_paint_pixmap(dev^.dest, group, trunc(alpha * 255))
		else
			fz_blend_pixmap(dev^.dest, group, trunc(alpha * 255), blendmode, isolated, shape);

		fz_drop_pixmap(group);
		if (shape <> dev^.shape) then
		begin
			if (dev^.shape<>nil) then
			begin
				fz_paint_pixmap(dev^.shape, shape, trunc(alpha * 255));
			end;
			fz_drop_pixmap(shape);
		end;
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_end(dev);
end;

procedure
fz_draw_begin_tile(user:pointer;area: fz_rect ;view: fz_rect ;  xstep,  ystep:single;ctm: fz_matrix );
var
	dev:pfz_draw_device_s;
	model:pfz_colorspace_s;
  dest:pfz_pixmap_s;
	bbox:fz_bbox ;
begin
	//* area, view, xstep, ystep are in pattern space */
	//* ctm maps from pattern space to device space */
  dev := user;
  model := dev^.dest^.colorspace;
	if (dev^.top = STACK_SIZE) then
	begin
		fz_warn('assert: too many buffers on stack');
		exit;
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0  then
		fz_knockout_begin(dev);

	bbox := fz_round_rect(fz_transform_rect(ctm, view));
	dest := fz_new_pixmap_with_rect(model, bbox);
	//* FIXME: See note #1 */
	fz_clear_pixmap(dest);

	dev^.stack[dev^.top].scissor := dev^.scissor;
	dev^.stack[dev^.top].dest := dev^.dest;
	dev^.stack[dev^.top].shape := dev^.shape;
	//* FIXME: See note #1 */
	dev^.stack[dev^.top].blendmode := dev^.blendmode or FZ_BLEND_ISOLATED;
	dev^.stack[dev^.top].xstep := xstep;
	dev^.stack[dev^.top].ystep := ystep;
	dev^.stack[dev^.top].area := area;
	dev^.stack[dev^.top].ctm := ctm;
	dev^.top:=dev^.top+1;

	dev^.scissor := bbox;
	dev^.dest := dest;
end;

procedure fz_draw_end_tile(user:pointer);
var
	dev:pfz_draw_device_s;
	tile:pfz_pixmap_s;
	xstep, ystep:single;
	 ctm, ttm:fz_matrix;
	 area:fz_rect;
	x0, y0, x1, y1, x, y:integer;
begin
  dev := user;
	tile := dev^.dest;
	if (dev^.top > 0) then
	begin
		dev^.top:=dev^.top-1;

		xstep := dev^.stack[dev^.top].xstep;
		ystep := dev^.stack[dev^.top].ystep;
		area := dev^.stack[dev^.top].area;
		ctm := dev^.stack[dev^.top].ctm;
		dev^.scissor := dev^.stack[dev^.top].scissor;
		dev^.dest := dev^.stack[dev^.top].dest;
		dev^.blendmode := dev^.stack[dev^.top].blendmode;


		x0 := floor(area.x0 / xstep);
		y0 := floor(area.y0 / ystep);
		x1 := ceil(area.x1 / xstep);
		y1 := ceil(area.y1 / ystep);

		ctm.e := tile^.x;
		ctm.f := tile^.y;

		for y := y0  to y1-1 do
		begin
			for x := x0 to x1-1 do
			begin
				ttm := fz_concat(fz_translate(x * xstep, y * ystep), ctm);
				tile^.x := trunc(ttm.e);
				tile^.y := trunc(ttm.f);
				fz_paint_pixmap_with_rect(dev^.dest, tile, 255, dev^.scissor);
			end ;
    end;

		fz_drop_pixmap(tile);
	end;

	if (dev^.blendmode and FZ_BLEND_KNOCKOUT)<>0 then
		fz_knockout_begin(dev);
end ;

procedure fz_draw_free_user(user:pointer);
var
	dev:pfz_draw_device_s;
	//* TODO: pop and free the stacks */
begin
   dev := user;
	if (dev^.top > 0) then
		fz_warn('items left on stack in draw device: %d', [dev^.top]);
	fz_free_gel(dev^.gel);
	fz_free(dev);
end;


function fz_new_draw_device(cache:pfz_glyph_cache_s; dest:pfz_pixmap_s):pfz_device_s;
var
	dev:pfz_device_s;
	ddev:pfz_draw_device_s;
begin
  ddev := fz_malloc(sizeof(fz_draw_device_s));
	ddev^.cache := cache;
	ddev^.gel := fz_new_gel();
	ddev^.dest := dest;
	ddev^.shape := nil;
	ddev^.top := 0;
	ddev^.blendmode := 0;
	ddev^.flags := 0;

	ddev^.scissor.x0 := dest^.x;
	ddev^.scissor.y0 := dest^.y;
	ddev^.scissor.x1 := dest^.x + dest^.w;
	ddev^.scissor.y1 := dest^.y + dest^.h;

	dev := fz_new_device(ddev);
	dev^.free_user := fz_draw_free_user;

	dev^.fill_path := fz_draw_fill_path;
	dev^.stroke_path := fz_draw_stroke_path;
	dev^.clip_path := fz_draw_clip_path;
	dev^.clip_stroke_path := fz_draw_clip_stroke_path;

	dev^.fill_text := fz_draw_fill_text;
	dev^.stroke_text := fz_draw_stroke_text;
	dev^.clip_text := fz_draw_clip_text;
	dev^.clip_stroke_text := fz_draw_clip_stroke_text;
	dev^.ignore_text := fz_draw_ignore_text;

	dev^.fill_image_mask := fz_draw_fill_image_mask;
	dev^.clip_image_mask := fz_draw_clip_image_mask;
	dev^.fill_image := fz_draw_fill_image;
	dev^.fill_shade := fz_draw_fill_shade;

	dev^.pop_clip := fz_draw_pop_clip;

	dev^.begin_mask := fz_draw_begin_mask;
	dev^.end_mask := fz_draw_end_mask;
	dev^.begin_group := fz_draw_begin_group;
	dev^.end_group := fz_draw_end_group;

	dev^.begin_tile := fz_draw_begin_tile;
	dev^.end_tile := fz_draw_end_tile;

	result:= dev;
end;


function fz_new_draw_device_type3(cache:pfz_glyph_cache_s; dest:pfz_pixmap_s):pfz_device_s;
var
	dev:pfz_device_s;
  ddev:pfz_draw_device_s;
begin
  dev := fz_new_draw_device(cache, dest);
	 ddev := dev^.user;
	ddev^.flags :=	ddev^.flags or FZ_DRAWDEV_FLAGS_TYPE3;
	result:= dev;
end;


end.
