unit pdf_interprets;

interface
uses
 SysUtils,Math,digtypes,digcommtype,base_error;

  function pdf_run_xobject(csi:ppdf_csi_s; resources:pfz_obj_s; xobj:ppdf_xobject_s; transform: fz_matrix ):integer;
 procedure pdf_show_pattern(csi:ppdf_csi_s; pat: ppdf_pattern_s;area: fz_rect ; what:pdffillkind_e);
 procedure pdf_show_string(csi:ppdf_csi_s; buf:pbyte; len:integer);
 function pdf_run_buffer(csi:ppdf_csi_s; rdb:pfz_obj_s; contents:pfz_buffer_s):integer;
 function pdf_run_glyph(xref:ppdf_xref_s; resources:pfz_obj_s; contents:pfz_buffer_s; dev:pfz_device_s; ctm:fz_matrix):integer;
 procedure pdf_set_colorspace(csi:ppdf_csi_s; what:pdffillkind_e; colorspace:pfz_colorspace_s);
 function  pdf_run_page_with_usage(xref:ppdf_xref_s; page:ppdf_page_s; dev:pfz_device_s; ctm:fz_matrix; target:pchar):integer;
 function  pdf_run_page(xref:ppdf_xref_s; page:ppdf_page_s; dev:pfz_device_s; ctm:fz_matrix):integer;
implementation
uses base_object_functions,fz_dev_null,res_shades,fz_pathh,fz_textx,pdf_cmapss,pdf_fontss,pdf_metricss,
res_colorspace,pdf_load_patterns,pdf_xobjectxxx,draw_blendss,FZ_mystreams,pdf_imagess,fz_pixmapss,
pdf_color_spcasess,pdf_shadess;

function pdf_is_hidden_ocg(xobj:pfz_obj_s; target:pchar):boolean ;
var
	target_state:array[0..15] of char;
	obj:pfz_obj_s;
begin
	fz_strlcpy(@target_state, target, sizeof(target_state));
	fz_strlcat(@target_state, 'State', sizeof(target_state));

	obj := fz_dict_gets(xobj, 'OC');
	obj := fz_dict_gets(obj, 'OCGs');
	if (fz_is_array(obj)) then
		obj := fz_array_get(obj, 0);
	obj := fz_dict_gets(obj, 'Usage');
	obj := fz_dict_gets(obj, target);
	obj := fz_dict_gets(obj, target_state);
	if strcomp(fz_to_name(obj), 'OFF')=0 then
  result:=true
  else
  result:=false;
end;

//* * Emit graphics calls to device.  */

procedure pdf_begin_group(csi:ppdf_csi_s;bbox: fz_rect );
var
	gstate:ppdf_gstate_s;
	error:integer;
  softmask:ppdf_xobject_s;
  bbox1:fz_rect;
  save_ctm :fz_matrix;
begin
   gstate := @csi^.gstate;
   inc(gstate, csi^.gtop);
	if (gstate^.softmask<>nil) then
	begin
		softmask := gstate^.softmask;
		bbox1 := fz_transform_rect(gstate^.softmask_ctm, softmask^.bbox);
		save_ctm := gstate^.ctm;

		gstate^.softmask := nil;
		gstate^.ctm := gstate^.softmask_ctm;

		fz_begin_mask(csi^.dev, bbox, gstate^.luminosity,			softmask^.colorspace, @gstate^.softmask_bc);
		error := pdf_run_xobject(csi, nil, softmask, fz_identity);
		if (error<0)  then
			fz_catch(error, 'cannot run softmask');
		fz_end_mask(csi^.dev);

		gstate^.softmask := softmask;
		gstate^.ctm := save_ctm;
	end;

	if (gstate^.blendmode<>0) then
		fz_begin_group(csi^.dev, bbox, 1, 0, gstate^.blendmode, 1);
end;

procedure pdf_end_group(csi:ppdf_csi_s);
var
	gstate:ppdf_gstate_s;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	if (gstate^.blendmode<>0) then
		fz_end_group(csi^.dev);

	if (gstate^.softmask<>nil) then
		fz_pop_clip(csi^.dev);
end;

procedure pdf_show_shade(csi:ppdf_csi_s; shd:pfz_shade_s);
var
	gstate:ppdf_gstate_s;
	bbox:fz_rect;
begin
   gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	bbox := fz_bound_shade(shd, gstate^.ctm);

	pdf_begin_group(csi, bbox);

	fz_fill_shade(csi^.dev, shd, gstate^.ctm, gstate^.fill.alpha);

	pdf_end_group(csi);
end;

procedure pdf_show_image(csi:ppdf_csi_s; image:pfz_pixmap_s);
var
	gstate:ppdf_gstate_s;
	bbox:fz_rect;
begin
   gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	bbox := fz_transform_rect(gstate^.ctm, fz_unit_rect);

	if (image^.mask<>nil) then
	begin
		//* apply blend group even though we skip the softmask */
		if (gstate^.blendmode<>0) then
			fz_begin_group(csi^.dev, bbox, 0, 0, gstate^.blendmode, 1);


		fz_clip_image_mask(csi^.dev, image^.mask, @bbox, gstate^.ctm);
	end
	else
		pdf_begin_group(csi, bbox);

	if (image^.colorspace=nil) then
	begin

		case (gstate^.fill.kind) of
		PDF_MAT_NONE:  dddd;

		PDF_MAT_COLOR:
      begin
			fz_fill_image_mask(csi^.dev, image, gstate^.ctm,
			gstate^.fill.colorspace, @gstate^.fill.v, gstate^.fill.alpha);
		 end;
		PDF_MAT_PATTERN:
      begin
			if (gstate^.fill.pattern<>nil) then
			begin
				fz_clip_image_mask(csi^.dev, image, @bbox, gstate^.ctm);
				pdf_show_pattern(csi, gstate^.fill.pattern, bbox, PDF_FILL);
				fz_pop_clip(csi^.dev);
			end;
			end;
		PDF_MAT_SHADE:
      begin
			if (gstate^.fill.shade<>nil) then
			begin
				fz_clip_image_mask(csi^.dev, image, @bbox, gstate^.ctm);
				fz_fill_shade(csi^.dev, gstate^.fill.shade, gstate^.ctm, gstate^.fill.alpha);
				fz_pop_clip(csi^.dev);
			end;
			end;
		end;
	end
	else
	begin
		fz_fill_image(csi^.dev, image, gstate^.ctm, gstate^.fill.alpha);
	end;

	if (image^.mask<>nil) then
	begin
		fz_pop_clip(csi^.dev);
		if (gstate^.blendmode<>0) then
			fz_end_group(csi^.dev);
	end
	else
		pdf_end_group(csi);
end;

procedure pdf_show_clip(csi:ppdf_csi_s; even_odd:integer);
var
	gstate:ppdf_gstate_s;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.clip_depth:=gstate^.clip_depth+1;
	fz_clip_path(csi^.dev, csi^.path, nil, even_odd, gstate^.ctm);
end;

procedure pdf_show_path( csi:ppdf_csi_s; doclose,  dofill, dostroke, even_odd:integer);
var
		gstate:ppdf_gstate_s;

	path:pfz_path_s;
	bbox:fz_rect ;
  i:integer;
begin
   gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	path := csi^.path;
	csi^.path := fz_new_path();

	if (doclose<>0) then
		fz_closepath(path);

	if (dostroke<>0) then
		bbox := fz_bound_path(path, @gstate^.stroke_state, gstate^.ctm)
	else
		bbox := fz_bound_path(path, nil, gstate^.ctm);

  //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692391 */
	if (csi^.clip<>0) then
	begin
		gstate^.clip_depth:=gstate^.clip_depth+1;
    if  csi^.clip = 2 then
    i:=1
    else
    i:=0;
		fz_clip_path(csi^.dev, path, nil, i, gstate^.ctm);
		csi^.clip := 0;
	end;

	//* SumatraPDF: support inline OCGs */
	if (csi^.in_hidden_ocg > 0) then
  begin
    dostroke := 0;
		dofill := 0;
  end;


	if (dofill<>0) or (dostroke<>0) then
		pdf_begin_group(csi, bbox);

	if (dofill<>0) then
	begin
		case (gstate^.fill.kind) of
		PDF_MAT_NONE:
			dddd;
		PDF_MAT_COLOR:
      begin
			fz_fill_path(csi^.dev, path, even_odd, gstate^.ctm,
				gstate^.fill.colorspace, @gstate^.fill.v, gstate^.fill.alpha);
			end;
		PDF_MAT_PATTERN:
      begin
			if (gstate^.fill.pattern<>nil) then
			begin
				fz_clip_path(csi^.dev, path, nil, even_odd, gstate^.ctm);
				pdf_show_pattern(csi, gstate^.fill.pattern, bbox, PDF_FILL);
				fz_pop_clip(csi^.dev);
			end;
			end;
		PDF_MAT_SHADE:
      begin
			if (gstate^.fill.shade<>nil) then
			begin
				fz_clip_path(csi^.dev, path, nil, even_odd, gstate^.ctm);
				fz_fill_shade(csi^.dev, gstate^.fill.shade, csi^.top_ctm, gstate^.fill.alpha);
				fz_pop_clip(csi^.dev);
			end;
			end;
		end;
	end;

	if (dostroke<>0) then
	begin
		case (gstate^.stroke.kind) of
		PDF_MAT_NONE:
			dddd;
		PDF_MAT_COLOR:
      begin
			  fz_stroke_path(csi^.dev, path, @gstate^.stroke_state, gstate^.ctm,
				gstate^.stroke.colorspace, @gstate^.stroke.v, gstate^.stroke.alpha);
			end;
		PDF_MAT_PATTERN:
      begin
			if (gstate^.stroke.pattern<>nil) then
			begin
				fz_clip_stroke_path(csi^.dev, path, @bbox, @gstate^.stroke_state, gstate^.ctm);
				pdf_show_pattern(csi, gstate^.stroke.pattern, bbox, PDF_FILL);
				fz_pop_clip(csi^.dev);
			end;
			end;
		PDF_MAT_SHADE:
      begin
			if (gstate^.stroke.shade<>nil) then
			begin
				fz_clip_stroke_path(csi^.dev, path, @bbox, @gstate^.stroke_state, gstate^.ctm);
				fz_fill_shade(csi^.dev, gstate^.stroke.shade, csi^.top_ctm, gstate^.stroke.alpha);
				fz_pop_clip(csi^.dev);
			end;
		  end;
		end;
	end;

	if (dofill<>0) or  (dostroke<>0) then
		pdf_end_group(csi);

	fz_free_path(path);
end;

//*  * Assemble and emit text  */

procedure pdf_flush_text(csi:ppdf_csi_s);
var
	gstate:ppdf_gstate_s;

	text:pfz_text_s;
	dofill,	 dostroke,doclip ,doinvisible :integer;
	bbox:fz_rect;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
  dofill := 0;
	dostroke := 0;
	doclip := 0;
	doinvisible := 0;

	if (csi^.text=nil) then
		exit;
	text := csi^.text;
	csi^.text := nil;
  doinvisible := 0;
  doclip := doinvisible;
  dostroke := doclip;
	dofill := dostroke;
	case (csi^.text_mode) of
	 0: dofill := 1;
	 1: dostroke := 1;
	 2:
     begin
     dostroke := 1;
     dofill := dostroke;
     end;
	 3: doinvisible := 1;
	 4:
     begin
       doclip := 1;
       dofill := doclip;
     end;
	 5:
     begin
       doclip := 1;
       dostroke := doclip;
     end;
	 6:
     begin
       doclip := 1;
       dostroke := doclip;
       dofill := dostroke;
     end;
	 7: doclip := 1;
	 end;

	bbox := fz_bound_text(text, gstate^.ctm);

	pdf_begin_group(csi, bbox);

	if (doinvisible<>0) then
		fz_ignore_text(csi^.dev, text, gstate^.ctm);

	if (doclip<>0) then
	begin
		if (csi^.accumulate < 2) then
			gstate^.clip_depth:=gstate^.clip_depth+1;
		fz_clip_text(csi^.dev, text, gstate^.ctm, csi^.accumulate);
		csi^.accumulate := 2;
	end;

	if (dofill<>0) then
	begin
		case (gstate^.fill.kind) of
		PDF_MAT_NONE:
			dddd;
		PDF_MAT_COLOR:
      begin
	 		fz_fill_text(csi^.dev, text, gstate^.ctm,
				gstate^.fill.colorspace, @gstate^.fill.v, gstate^.fill.alpha);
			end;
		PDF_MAT_PATTERN:
      begin
			if (gstate^.fill.pattern<>nil) then
			begin
				fz_clip_text(csi^.dev, text, gstate^.ctm, 0);
				pdf_show_pattern(csi, gstate^.fill.pattern, bbox, PDF_FILL);
				fz_pop_clip(csi^.dev);
			end;
			end;
		PDF_MAT_SHADE:
      begin
			if (gstate^.fill.shade<>nil) then
			begin
				fz_clip_text(csi^.dev, text, gstate^.ctm, 0);
				fz_fill_shade(csi^.dev, gstate^.fill.shade, csi^.top_ctm, gstate^.fill.alpha);
				fz_pop_clip(csi^.dev);
			end;
		 end;
		end;
	end;

	if (dostroke<>0) then
	begin
		case (gstate^.stroke.kind) of
		PDF_MAT_NONE:
			dddd;
		PDF_MAT_COLOR:
      begin
			fz_stroke_text(csi^.dev, text, @gstate^.stroke_state, gstate^.ctm,
				gstate^.stroke.colorspace, @gstate^.stroke.v, gstate^.stroke.alpha);
			end;
		PDF_MAT_PATTERN:
      begin
			if (gstate^.stroke.pattern<>nil) then
			begin
				fz_clip_stroke_text(csi^.dev, text, @gstate^.stroke_state, gstate^.ctm);
				pdf_show_pattern(csi, gstate^.stroke.pattern, bbox, PDF_FILL);
				fz_pop_clip(csi^.dev);
			end;
			end;
		PDF_MAT_SHADE:
      begin
			if (gstate^.stroke.shade<>nil) then
			begin
				fz_clip_stroke_text(csi^.dev, text, @gstate^.stroke_state, gstate^.ctm);
				fz_fill_shade(csi^.dev, gstate^.stroke.shade, csi^.top_ctm, gstate^.stroke.alpha);
				fz_pop_clip(csi^.dev);
			end;
			end;
		end;
	end;

	pdf_end_group(csi);

	fz_free_text(text);
end;

procedure pdf_show_char(csi:ppdf_csi_s; cid:integer);
var
	gstate:ppdf_gstate_s;
	fontdesc:ppdf_font_desc_s;
	 tsm, trm:fz_matrix;
	 w0, w1, tx, ty:single;
	 h:pdf_hmtx_s;
	 v:pdf_vmtx_s;
	 gid:integer;
	ucsbuf:array[0..7] of integer;
	ucslen:integer;
	i:integer;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
  fontdesc := gstate^.font;
	tsm.a := gstate^.size * gstate^.scale;
	tsm.b := 0;
	tsm.c := 0;
	tsm.d := gstate^.size;
	tsm.e := 0;
	tsm.f := gstate^.rise;

	ucslen := 0;
	if (fontdesc^.to_unicode<>nil) then
		ucslen := pdf_lookup_cmap_full(fontdesc^.to_unicode, cid, @ucsbuf);
	if (ucslen = 0) and ( cid < fontdesc^.cid_to_ucs_len) then
	begin
		ucsbuf[0] := word_items(fontdesc^.cid_to_ucs)[cid];

		ucslen := 1;
	end;
	if (ucslen = 0) or ((ucslen = 1) and (ucsbuf[0] = 0)) then
	begin
		ucsbuf[0] := ord('?');
		ucslen := 1;
	end;

	gid := pdf_font_cid_to_gid(fontdesc, cid);

	if (fontdesc^.wmode = 1) then
	begin
		v := pdf_get_vmtx(fontdesc, cid);
		tsm.e :=tsm.e- v.x * gstate^.size * 0.001;
		tsm.f :=tsm.f - v.y * gstate^.size * 0.001;
	end;

	trm := fz_concat(tsm, csi^.tm);

	//* flush buffered text if face or matrix or rendermode has changed */
	if ((csi^.text=nil) or
		(fontdesc^.font <> csi^.text^.font) or
		(fontdesc^.wmode <> csi^.text^.wmode) or
		(abs(trm.a - csi^.text^.trm.a) > FLT_EPSILON) or
		(abs(trm.b - csi^.text^.trm.b) > FLT_EPSILON) or
		(abs(trm.c - csi^.text^.trm.c) > FLT_EPSILON ) or
		(abs(trm.d - csi^.text^.trm.d) > FLT_EPSILON) or
		(gstate^.render <> csi^.text_mode))  then
	begin
		pdf_flush_text(csi);

		csi^.text := fz_new_text(fontdesc^.font, trm, fontdesc^.wmode);
		csi^.text^.trm.e := 0;
		csi^.text^.trm.f := 0;
		csi^.text_mode := gstate^.render;
	end;

	//* add glyph to textobject */
	fz_add_text(csi^.text, gid, ucsbuf[0], trm.e, trm.f);

	//* add filler glyphs for one-to-many unicode mapping */
	for i := 1 to ucslen-1 do
		fz_add_text(csi^.text, -1, ucsbuf[i], trm.e, trm.f);

	if (fontdesc^.wmode = 0) then
	begin
		h := pdf_get_hmtx(fontdesc, cid);
		w0 := h.w * 0.001;
		tx := (w0 * gstate^.size + gstate^.char_space) * gstate^.scale;
		csi^.tm := fz_concat(fz_translate(tx, 0), csi^.tm);
	end;

	if (fontdesc^.wmode = 1) then
	begin
		w1 := v.w * 0.001;
		ty := w1 * gstate^.size + gstate^.char_space;
		csi^.tm := fz_concat(fz_translate(0, ty), csi^.tm);
	end;
end;

procedure pdf_show_space(csi:ppdf_csi_s;  tadj:single);
var
  gstate:ppdf_gstate_s;
  fontdesc:ppdf_font_desc_s;
begin
	 gstate := @csi^.gstate;
   inc(gstate, csi^.gtop);
	 fontdesc := gstate^.font;
//OutputDebugString(pchar('font.refs'+inttostr(gstate^.font.refs)));
	if (fontdesc=nil) then
	begin
		fz_warn('cannot draw text since font and size not set 1');
		//return;
    
    exit;
	end;


	if (fontdesc^.wmode = 0) then
		csi^.tm := fz_concat(fz_translate(tadj * gstate^.scale, 0), csi^.tm)
	else
		csi^.tm := fz_concat(fz_translate(0, tadj), csi^.tm);

end;

procedure
pdf_show_string(csi:ppdf_csi_s; buf:pbyte; len:integer);
var
gstate:ppdf_gstate_s;
fontdesc:ppdf_font_desc_s;
endp:pbyte;
cpt, cid:integer;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	fontdesc := gstate^.font;
	endp := buf;
  inc(endp, len);


	if (fontdesc=nil) then
	begin
		fz_warn('cannot draw text since font and size not set 2');
		exit;
	end;

	while (cardinal(buf) < cardinal(endp)) do
	begin

		buf := pdf_decode_cmap(fontdesc^.encoding, buf, @cpt);
		cid := pdf_lookup_cmap(fontdesc^.encoding, cpt);
		if (cid >= 0) then
			pdf_show_char(csi, cid)
		else
		 	fz_warn('cannot encode character with code point %d', [cpt]);

		if (cpt = 32) then
			pdf_show_space(csi, gstate^.word_space);
	end;
end;

procedure pdf_show_text(csi:ppdf_csi_s; text:pfz_obj_s) ;
var

  gstate:ppdf_gstate_s;
	i:integer;
  item :pfz_obj_s;
begin
  	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	if (fz_is_array(text))then
	begin
		for i := 0 to fz_array_len(text)-1 do
		begin
			item := fz_array_get(text, i);
			if (fz_is_string(item)) then
				pdf_show_string(csi, pbyte(fz_to_str_buf(item)), fz_to_str_len(item))
			else
				pdf_show_space(csi, - fz_to_real(item) * gstate^.size * 0.001);
		end;
	end
	else if (fz_is_string(text)) then
	begin
		pdf_show_string(csi, pbyte(fz_to_str_buf(text)), fz_to_str_len(text));
	end;
end;
(*
 * Interpreter and graphics state stack.
 *)

procedure pdf_init_gstate(gs:ppdf_gstate_s; ctm:fz_matrix);
begin
	gs^.ctm := ctm;
	gs^.clip_depth := 0;

	gs^.stroke_state.start_cap := 0;
	gs^.stroke_state.dash_cap := 0;
	gs^.stroke_state.end_cap := 0;
	gs^.stroke_state.linejoin := 0;
	gs^.stroke_state.linewidth := 1;
	gs^.stroke_state.miterlimit := 10;
	gs^.stroke_state.dash_phase := 0;
	gs^.stroke_state.dash_len := 0;
	fillchar(gs^.stroke_state.dash_list,  sizeof(gs^.stroke_state.dash_list),0);

	gs^.stroke.kind := PDF_MAT_COLOR;
	gs^.stroke.colorspace := fz_keep_colorspace(get_fz_device_gray);
	gs^.stroke.v[0] := 0;
	gs^.stroke.pattern := nil;
	gs^.stroke.shade := nil;
	gs^.stroke.alpha := 1;

	gs^.fill.kind := PDF_MAT_COLOR;
	gs^.fill.colorspace := fz_keep_colorspace(get_fz_device_gray);
	gs^.fill.v[0] := 0;
	gs^.fill.pattern :=nil;
	gs^.fill.shade := nil;
	gs^.fill.alpha := 1;

	gs^.char_space := 0;
	gs^.word_space := 0;
	gs^.scale := 1;
	gs^.leading := 0;
	gs^.font := nil;
	gs^.size := -1;
	gs^.render := 0;
	gs^.rise := 0;

	gs^.blendmode := 0;
	gs^.softmask := nil;
	gs^.softmask_ctm := fz_identity;
	gs^.luminosity := 0;
end;

function
pdf_new_csi(xref:ppdf_xref_s; dev:pfz_device_s; ctm:fz_matrix; target:pchar):ppdf_csi_s;
var
	csi:ppdf_csi_s;
begin
	csi := fz_malloc(sizeof(pdf_csi_s));
	csi^.xref := xref;
	csi^.dev := dev;
	csi^.target := target;

	csi^.top := 0;
	csi^.obj := nil;
	csi^.name[0] := #0;
	csi^.string_len := 0;
	fillchar(csi^.stack, sizeof(csi^.stack), 0);

	csi^.xbalance := 0;
	csi^.in_text := 0;

	csi^.path := fz_new_path();

	csi^.text := nil;
	csi^.tlm := fz_identity;
	csi^.tm := fz_identity;
	csi^.text_mode := 0;
	csi^.accumulate := 1;

	csi^.top_ctm := ctm;
	pdf_init_gstate(@csi^.gstate[0], ctm);
	csi^.gtop := 0;

	result:= csi;
end;

procedure pdf_clear_stack(csi:ppdf_csi_s)   ;
var
	i:integer;
begin
	if (csi^.obj<>nil) then
		fz_drop_obj(csi^.obj);
	csi^.obj := nil;

	csi^.name[0] := #0;
	csi^.string_len := 0;
	for i := 0 to csi^.top-1 do
		csi^.stack[i] := 0;

	csi^.top := 0;
end;

function
pdf_keep_material(mat:ppdf_material_s):ppdf_material_s;
begin
	if (mat^.colorspace<>nil) then
		fz_keep_colorspace(mat^.colorspace);
	if (mat^.pattern<>nil) then
		pdf_keep_pattern(mat^.pattern);
	if (mat^.shade<>nil) then
		fz_keep_shade(mat^.shade);
	result:= mat;
end;

function pdf_drop_material(mat:ppdf_material_s):ppdf_material_s;
begin
	if (mat^.colorspace<>nil) then
		fz_drop_colorspace(mat^.colorspace);
	if (mat^.pattern<>nil) then
		pdf_drop_pattern(mat^.pattern);
	if (mat^.shade<>nil) then
		fz_drop_shade(mat^.shade);
	result:= mat;
end;

procedure pdf_gsave(csi:ppdf_csi_s);
var
	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);

	if (csi^.gtop = length(csi^.gstate) - 1) then
	begin
		fz_warn('gstate overflow in content stream');
		exit;
	end;

	copymemory(@csi^.gstate[csi^.gtop + 1], @csi^.gstate[csi^.gtop], sizeof(pdf_gstate_s));

	csi^.gtop:=csi^.gtop+1;

	pdf_keep_material(@gs^.stroke);
	pdf_keep_material(@gs^.fill);
	if (gs^.font<>nil) then
		pdf_keep_font(gs^.font);
	if (gs^.softmask<>nil) then
		pdf_keep_xobject(gs^.softmask);
end;

procedure pdf_grestore(csi:ppdf_csi_s);
var
	clip_depth:integer;

	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);
  clip_depth := gs^.clip_depth;
	if (csi^.gtop = 0) then
	begin
	 	fz_warn('gstate underflow in content stream');
	 //	return;
    exit;
	end;

	pdf_drop_material(@gs^.stroke);
	pdf_drop_material(@gs^.fill);
	if (gs^.font<>nil) then
		pdf_drop_font(gs^.font);
	if (gs^.softmask<>nil) then
		pdf_drop_xobject(gs^.softmask);

	csi^.gtop :=csi^.gtop-1;

	gs := @csi^.gstate;
  inc(gs, csi^.gtop);
	while (clip_depth > gs^.clip_depth)   do
	begin
		fz_pop_clip(csi^.dev);
		clip_depth:=clip_depth-1;
	end;
end;

procedure pdf_free_csi(csi:ppdf_csi_s);
begin
	while (csi^.gtop<>0) do
		pdf_grestore(csi);

	pdf_drop_material(@csi^.gstate[0].fill);
	pdf_drop_material(@csi^.gstate[0].stroke);
	if (csi^.gstate[0].font<>nil) then
		pdf_drop_font(csi^.gstate[0].font);
	if (csi^.gstate[0].softmask<>nil) then
		pdf_drop_xobject(csi^.gstate[0].softmask);

	while (csi^.gstate[0].clip_depth<>0) do
  begin
    csi^.gstate[0].clip_depth:=csi^.gstate[0].clip_depth-1;
		fz_pop_clip(csi^.dev);

  end;

	if (csi^.path<>nil) then fz_free_path(csi^.path);
	if (csi^.text<>nil) then fz_free_text(csi^.text);

	pdf_clear_stack(csi);

	fz_free(csi);
end;

(*
 * Material state
 *)

procedure
pdf_set_colorspace(csi:ppdf_csi_s; what:pdffillkind_e; colorspace:pfz_colorspace_s);
var

	mat:ppdf_material_s;
	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);
	pdf_flush_text(csi);
  if what = PDF_FILL then
  mat:=@gs^.fill
  else
  mat:=@gs^.stroke;
	fz_drop_colorspace(mat^.colorspace);

	mat^.kind := PDF_MAT_COLOR;
	mat^.colorspace := fz_keep_colorspace(colorspace);

	mat^.v[0] := 0;
	mat^.v[1] := 0;
	mat^.v[2] := 0;
	mat^.v[3] := 1;
end;

procedure 
pdf_set_color(csi:ppdf_csi_s; what:pdffillkind_e; v:psingle);
var
  i:integer;
	mat:ppdf_material_s;
	gs:ppdf_gstate_s;
begin
    gs := @csi^.gstate;
  inc(gs, csi^.gtop);

	pdf_flush_text(csi);

	 if what = PDF_FILL then
  mat:=@gs^.fill
  else
  mat:=@gs^.stroke;

	if (mat^.kind=PDF_MAT_PATTERN) or  (mat^.kind=PDF_MAT_COLOR) then
  begin
		if (strcomp(mat^.colorspace^.name, 'Lab')=0) then
		begin
			mat^.v[0] := single_items(v)[0] / 100;
			mat^.v[1] := (single_items(v)[1] + 100) / 200;
			mat^.v[2] := (single_items(v)[2] + 100) / 200;
		end;
		for i := 0 to mat^.colorspace^.n-1 do
			mat^.v[i] := single_items(v)[i];
 	end
  else
		fz_warn('color incompatible with material');


end;

procedure 
pdf_set_shade(csi:ppdf_csi_s; what:pdffillkind_e; shade: pfz_shade_s) ;
var
  mat:ppdf_material_s;
	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);
  pdf_flush_text(csi);

	if what = PDF_FILL then
  mat:=@gs^.fill
  else
  mat:=@gs^.stroke;

	if (mat^.shade<>nil) then
		fz_drop_shade(mat^.shade);

	mat^.kind := PDF_MAT_SHADE;
	mat^.shade := fz_keep_shade(shade);
end;

procedure 
pdf_set_pattern(csi:ppdf_csi_s; what:pdffillkind_e; pat:ppdf_pattern_s; v:psingle);
var
  mat:ppdf_material_s;
	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);

	pdf_flush_text(csi);

	if what = PDF_FILL then
  mat:=@gs^.fill
  else
  mat:=@gs^.stroke;

	if (mat^.pattern<>nil) then
		pdf_drop_pattern(mat^.pattern);

	mat^.kind := PDF_MAT_PATTERN;
	if (pat<>nil) then
		mat^.pattern := pdf_keep_pattern(pat)
	else
		mat^.pattern := nil;

	if (v<>nil) then
		pdf_set_color(csi, what, v);
end;

procedure 
pdf_unset_pattern(csi:ppdf_csi_s; what:pdffillkind_e);
var
  mat:ppdf_material_s;
	gs:ppdf_gstate_s;
begin
  gs := @csi^.gstate;
  inc(gs, csi^.gtop);

	if what = PDF_FILL then
  mat:=@gs^.fill
  else
  mat:=@gs^.stroke;



	if (mat^.kind = PDF_MAT_PATTERN) then
	begin
		if (mat^.pattern<>nil) then
			pdf_drop_pattern(mat^.pattern);
		mat^.pattern := nil;
		mat^.kind := PDF_MAT_COLOR;
	end;
end;

(*
 * Patterns, XObjects and ExtGState
 *)

procedure pdf_show_pattern(csi:ppdf_csi_s; pat: ppdf_pattern_s; area: fz_rect ; what:pdffillkind_e);
var
	gstate:ppdf_gstate_s;
	ptm, invptm:fz_matrix_s;
	oldtopctm:fz_matrix_s;
	 error:integer;
	 x0, y0, x1, y1:integer;
	 oldtop:integer;
begin
	pdf_gsave(csi);
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	if (pat^.ismask<>0) then
	begin
		pdf_unset_pattern(csi, PDF_FILL);
		pdf_unset_pattern(csi, PDF_STROKE);
		if (what = PDF_FILL) then
		begin
			pdf_drop_material(@gstate^.stroke);
			pdf_keep_material(@gstate^.fill);
			gstate^.stroke := gstate^.fill;
		end;
		if (what = PDF_STROKE) then
		begin
			pdf_drop_material(@gstate^.fill);
			pdf_keep_material(@gstate^.stroke);
			gstate^.fill := gstate^.stroke;
		end;
	end
	else
	begin
		// TODO: unset only the current fill/stroke or both?
		pdf_unset_pattern(csi, what);
	end;

	//* don't apply softmasks to objects in the pattern as well */
	if (gstate^.softmask<>nil) then
	begin
		pdf_drop_xobject(gstate^.softmask);
		gstate^.softmask := nil;
	end;

	ptm := fz_concat(pat^.matrix, csi^.top_ctm);
	invptm := fz_invert_matrix(ptm);

	//* patterns are painted using the ctm in effect at the beginning of the content stream */
	//* get bbox of shape in pattern space for stamping */
	area := fz_transform_rect(invptm, area);
	x0 := floor(area.x0 / pat^.xstep);
	y0 := floor(area.y0 / pat^.ystep);
	x1 := ceil(area.x1 / pat^.xstep);
	y1 := ceil(area.y1 / pat^.ystep);

	oldtopctm := csi^.top_ctm;
	oldtop := csi^.gtop;


	if ((x1 - x0) * (y1 - y0) > 0) then
	begin
		fz_begin_tile(csi^.dev, area, pat^.bbox, pat^.xstep, pat^.ystep, ptm);
		gstate^.ctm := ptm;
		csi^.top_ctm := gstate^.ctm;
		pdf_gsave(csi);
		error := pdf_run_buffer(csi, pat^.resources, pat^.contents);
		if (error<0)  then
			fz_catch(error, 'cannot render pattern tile');
		pdf_grestore(csi);
		while (oldtop < csi^.gtop)  do
			pdf_grestore(csi);
		fz_end_tile(csi^.dev);
	end;


	csi^.top_ctm := oldtopctm;

	pdf_grestore(csi);
end;

function pdf_run_xobject(csi:ppdf_csi_s; resources:pfz_obj_s; xobj:ppdf_xobject_s; transform: fz_matrix_s ):integer;
var
 	gstate:ppdf_gstate_s;
	oldtopctm:fz_matrix_s;
  error:integer;
  oldtop,popmask:integer;
  softmask:ppdf_xobject_s;
  bbox:fz_rect;
begin
	pdf_gsave(csi);

  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	oldtop := csi^.gtop;
	popmask := 0;

	//* apply xobject's transform matrix */
	transform := fz_concat(xobj^.matrix, transform);
	gstate^.ctm := fz_concat(transform, gstate^.ctm);

	//* apply soft mask, create transparency group and reset state */
	if (xobj^.transparency<>0) then
	begin
		if (gstate^.softmask<>nil)  then
		begin
			softmask := gstate^.softmask;
			bbox := fz_transform_rect(gstate^.ctm, xobj^.bbox);

			gstate^.softmask := nil;
			popmask := 1;

			fz_begin_mask(csi^.dev, bbox, gstate^.luminosity,				softmask^.colorspace, @gstate^.softmask_bc);
			error := pdf_run_xobject(csi, resources, softmask, fz_identity);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot run softmask');
        exit;
      end;
			fz_end_mask(csi^.dev);

			pdf_drop_xobject(softmask);
		end;

		fz_begin_group(csi^.dev,
			fz_transform_rect(gstate^.ctm, xobj^.bbox),
			xobj^.isolated, xobj^.knockout, gstate^.blendmode, gstate^.fill.alpha);

		gstate^.blendmode := 0;
		gstate^.stroke.alpha := 1;
		gstate^.fill.alpha := 1;
	end;

	//* clip to the bounds */

	fz_moveto(csi^.path, xobj^.bbox.x0, xobj^.bbox.y0);
	fz_lineto(csi^.path, xobj^.bbox.x1, xobj^.bbox.y0);
	fz_lineto(csi^.path, xobj^.bbox.x1, xobj^.bbox.y1);
	fz_lineto(csi^.path, xobj^.bbox.x0, xobj^.bbox.y1);
	fz_closepath(csi^.path);
  csi^.clip := 1; //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692391 */
	pdf_show_clip(csi, 0);
	pdf_show_path(csi, 0, 0, 0, 0);

	//* run contents */

	oldtopctm := csi^.top_ctm;
	csi^.top_ctm := gstate^.ctm;

	if (xobj^.resources<>nil) then
		resources := xobj^.resources;

	error := pdf_run_buffer(csi, resources, xobj^.contents);
	if (error<0)  then
	 	fz_catch(error, 'cannot interpret XObject stream');

	csi^.top_ctm := oldtopctm;

	while (oldtop < csi^.gtop) do
		pdf_grestore(csi);

	pdf_grestore(csi);

	//* wrap up transparency stacks */

	if (xobj^.transparency<>0) then
	begin
		fz_end_group(csi^.dev);
		if (popmask<>0) then
			fz_pop_clip(csi^.dev);
	end;

	result:=1;
end;

function pdf_run_extgstate(csi:ppdf_csi_s; rdb:pfz_obj_s; extgstate:pfz_obj_s):integer;
var
	gstate:ppdf_gstate_s;
	colorspace:pfz_colorspace_s;
	i, k:integer;
  key,val,font:pfz_obj_s;
  dashes:pfz_obj_s;
  xobj :	ppdf_xobject_s;
  group, luminosity, bc:pfz_obj_s;
  s:pchar;
  error:integer;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	pdf_flush_text(csi);

	for i := 0 to fz_dict_len(extgstate)-1 do
	begin
		key := fz_dict_get_key(extgstate, i);
		val := fz_dict_get_val(extgstate, i);
		s := fz_to_name(key);
		if (strcomp(s, 'Font')=0) then
		begin
			if (fz_is_array(val)) and (fz_array_len(val) = 2) then
			begin

				font := fz_array_get(val, 0);

				if (gstate^.font<>nil) then
				begin
					pdf_drop_font(gstate^.font);
					gstate^.font := nil;
				end;

				error := pdf_load_font(@gstate^.font, csi^.xref, rdb, font);
				if (error<0)  then
        begin
					 result:= fz_rethrow(error, 'cannot load font (%d %d R)', [fz_to_num(font), fz_to_gen(font)]);
         // result:=-1;
          exit;
        end;
				if (gstate^.font=nil) then
        begin
					 result:= fz_throw('cannot find font in store');

          exit;
        end;
				gstate^.size := fz_to_real(fz_array_get(val, 1));
			end
			else
      begin
				 result:= fz_throw('malformed /Font dictionary');

        exit;
      end;
		end

		else if (strcomp(s, 'LC')=0) then
		begin
			gstate^.stroke_state.start_cap := fz_to_int(val);
			gstate^.stroke_state.dash_cap := fz_to_int(val);
			gstate^.stroke_state.end_cap := fz_to_int(val);
		end
		else if (strcomp(s, 'LW')=0)  then
			gstate^.stroke_state.linewidth := fz_to_real(val)
		else if (strcomp(s, 'LJ')=0)   then
			gstate^.stroke_state.linejoin := fz_to_int(val)
		else if (strcomp(s, 'ML')=0)   then
			gstate^.stroke_state.miterlimit := fz_to_real(val)

		else if (strcomp(s, 'D')=0) then
		begin
			if (fz_is_array(val)) and (fz_array_len(val) = 2) then
			begin
				dashes := fz_array_get(val, 0);
				gstate^.stroke_state.dash_len := MAX(fz_array_len(dashes), 32);
				for k := 0 to gstate^.stroke_state.dash_len-1 do
					gstate^.stroke_state.dash_list[k] := fz_to_real(fz_array_get(dashes, k));
				gstate^.stroke_state.dash_phase := fz_to_real(fz_array_get(val, 1));
			end
			else
      begin
				 result:= fz_throw('malformed /D');

        exit;
      end;
		end

		else if (strcomp(s, 'CA')=0)  then
			gstate^.stroke.alpha := fz_to_real(val)

		else if (strcomp(s, 'ca')=0)  then
			gstate^.fill.alpha := fz_to_real(val)

		else if (strcomp(s, 'BM')=0)  then
		begin
			if (fz_is_array(val)) then
				val := fz_array_get(val, 0);
			gstate^.blendmode := fz_find_blendmode(fz_to_name(val));
		end

		else if (strcomp(s, 'SMask')=0)  then
		begin
			if (fz_is_dict(val))  then
			begin



				if (gstate^.softmask<>nil) then
				begin
					pdf_drop_xobject(gstate^.softmask);
					gstate^.softmask := nil;
				end;

				group := fz_dict_gets(val, 'G');
				if (group=nil) then
        begin
					 result:= fz_throw('cannot load softmask xobject (%d %d R)', [fz_to_num(val), fz_to_gen(val)]);

          exit;
        end;
				error := pdf_load_xobject(@xobj, csi^.xref, group);
				if (error<0) then
        begin
				  result:= fz_rethrow(error, 'cannot load xobject (%d %d R)', [fz_to_num(val), fz_to_gen(val)]);
          exit;
        end;

				colorspace := xobj^.colorspace;
				if (colorspace=nil) then
					colorspace := get_fz_device_gray;

				gstate^.softmask_ctm := fz_concat(xobj^.matrix, gstate^.ctm);
				gstate^.softmask := xobj;
				for k := 0 to colorspace^.n-1 do
					gstate^.softmask_bc[k] := 0;

				bc := fz_dict_gets(val, 'BC');
				if (fz_is_array(bc))  then
				begin
					for k := 0 to  colorspace^.n-1 do
						gstate^.softmask_bc[k] := fz_to_real(fz_array_get(bc, k));
				end;

				luminosity := fz_dict_gets(val, 'S');
				if (fz_is_name(luminosity)) and (strcomp(fz_to_name(luminosity), 'Luminosity')=0) then
					gstate^.luminosity := 1
				else
					gstate^.luminosity := 0;
			end
			else if (fz_is_name(val)) and (strcomp(fz_to_name(val), 'None')=0) then
			begin
				if (gstate^.softmask<>nil) then
				begin
					pdf_drop_xobject(gstate^.softmask);
					gstate^.softmask := nil;
				end;
			end;
		end

		else if (strcomp(s, 'TR')=0) then
		begin
			if (fz_is_name(val)) and (strcomp(fz_to_name(val), 'Identity')<>0) then
				fz_warn('ignoring transfer function');

		end;
	end;

	//return fz_okay;
  result:=1;
end;

(*
 * Operators
 *)

procedure  pdf_run_BDC(csi:ppdf_csi_s);
begin
end;

function pdf_run_BI(csi:ppdf_csi_s; rdb:pfz_obj_s; file1:pfz_stream_s):integer;
var
	ch:integer;
	error:integer;
	buf:pchar;
	buflen:integer;
	img:pfz_pixmap_s;
	obj:pfz_obj_s;
  ch1:char;
begin
  buf := csi^.xref^.scratch;
  buflen := sizeof(csi^.xref^.scratch);

	error := pdf_parse_dict(@obj, csi^.xref, file1, buf, buflen);
	if (error<0)  then
  begin
	  result:= fz_rethrow(error, 'cannot parse inline image dictionary');

    exit;
  end;

	//* read whitespace after ID keyword */
	ch := fz_read_byte(file1);
	if (ch =13)  then
		if (fz_peek_byte(file1) = 10) then
			fz_read_byte(file1);

	error := pdf_load_inline_image(@img, csi^.xref, rdb, obj, file1);
	fz_drop_obj(obj);
	if (error<0)  then
  begin
		 result:= fz_rethrow(error, 'cannot load inline image');
    exit;
  end;
	pdf_show_image(csi, img);

	fz_drop_pixmap(img);

	//* find EI */
	ch := fz_read_byte(file1);
	while ((ch <> ord('E')) and (ch <> eEOF))  do
		ch := fz_read_byte(file1);
	ch := fz_read_byte(file1);
	if (ch <> ord('I')) then
  begin
		 result:= fz_rethrow(error, 'syntax error after inline image');
    exit;
  end;
  result:=1;
	//return fz_okay;
end;

procedure  pdf_run_B(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 1, 1, 0);
end;

procedure  pdf_run_BMC(csi:ppdf_csi_s);
begin
end;

procedure  pdf_run_BT(csi:ppdf_csi_s) ;
begin
	csi^.in_text := 1;
	csi^.tm := fz_identity;
	csi^.tlm := fz_identity;
end;

procedure  pdf_run_BX(csi:ppdf_csi_s);
begin
	csi^.xbalance:=csi^.xbalance+1;
end;

procedure  pdf_run_Bstar(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 1, 1, 1);
end;

function pdf_run_cs_imp(csi:ppdf_csi_s; rdb:pfz_obj_s; what:pdffillkind_e):integer;
var
	colorspace:pfz_colorspace_s;
	obj, dict:pfz_obj_s;
	error:integer;
begin
	if (strcomp(csi^.name, 'Pattern')=0) then
	begin
		pdf_set_pattern(csi, what, nil, nil);
	end
	else
	begin
		if (strcomp(csi^.name, 'DeviceGray')=0) then
			colorspace := fz_keep_colorspace(get_fz_device_gray)
		else if (strcomp(csi^.name, 'DeviceRGB')=0) then
			colorspace := fz_keep_colorspace(get_fz_device_rgb)
		else if (strcomp(csi^.name, 'DeviceCMYK')=0) then
			colorspace := fz_keep_colorspace(get_fz_device_cmyk)
		else
		begin
			dict := fz_dict_gets(rdb, 'ColorSpace');
			if (dict=nil) then
      begin
				result:= fz_throw('cannot find ColorSpace dictionary');
        result:=-1;
        exit;
      end;
			obj := fz_dict_gets(dict, csi^.name);
			if (obj=nil) then
      begin
				 result:= fz_throw('cannot find colorspace resource "%s"', [csi^.name]);
        result:=-1;
        exit;
      end;
			error := pdf_load_colorspace(@colorspace, csi^.xref, obj);
			if (error<0)  then
      begin
				 result:= fz_rethrow(error, 'cannot load colorspace (%d 0 R)', [fz_to_num(obj)]);
         exit;
      end;
		end;

		pdf_set_colorspace(csi, what, colorspace);

		fz_drop_colorspace(colorspace);
	end;
 //	return fz_okay;
   result:=1;
end;

procedure  pdf_run_CS(csi:ppdf_csi_s; rdb:pfz_obj_s);
var
error:integer;
begin

	error := pdf_run_cs_imp(csi, rdb, PDF_STROKE);
	if (error<0)  then
  begin
		fz_catch(error, 'cannot set colorspace');
    exit;
  end;
end;

procedure  pdf_run_cs1(csi:ppdf_csi_s; rdb:pfz_obj_s);
var
	error:integer;
begin
	error := pdf_run_cs_imp(csi, rdb, PDF_FILL);
	if (error<0)  then
		fz_catch(error, 'cannot set colorspace');

end;

procedure  pdf_run_DP(csi:ppdf_csi_s);
begin
end;

function  pdf_run_Do(csi:ppdf_csi_s; rdb:pfz_obj_s):integer;
var
	dict,obj,subtype:pfz_obj_s;
	error:integer;
  	xobj:ppdf_xobject_s;
    img:pfz_pixmap_s;
begin
	dict := fz_dict_gets(rdb, 'XObject');
	if (dict=nil) then
  begin
		 result:= fz_throw('cannot find XObject dictionary when looking for: "%s"', [csi^.name]);
     exit;
  end;

	obj := fz_dict_gets(dict, csi^.name);
	if (obj=nil) then
  begin
		 result:= fz_throw('cannot find xobject resource: "%s"',[ csi^.name]);
    exit;
  end;

	subtype := fz_dict_gets(obj, 'Subtype');
	if (not fz_is_name(subtype)) then
  begin
		 result:= fz_throw('no XObject subtype specified');
    exit;
  end;

	if (pdf_is_hidden_ocg(obj, csi^.target))  then
  begin
		//return fz_okay;
    result:=1;
    exit;
  end;

	if (strcomp(fz_to_name(subtype), 'Form')=0) and (fz_dict_gets(obj, 'Subtype2')<>nil) then
		subtype := fz_dict_gets(obj, 'Subtype2');

	if (strcomp(fz_to_name(subtype), 'Form')=0) then
	begin


		error := pdf_load_xobject(@xobj, csi^.xref, obj);
		if (error<0)  then
    begin
			 result:= fz_rethrow(error, 'cannot load xobject (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
       exit;
      end;

		//* Inherit parent resources, in case this one was empty XXX check where it's loaded */
		if (xobj^.resources=nil) then
			xobj^.resources := fz_keep_obj(rdb);

		error := pdf_run_xobject(csi, xobj^.resources, xobj, fz_identity);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot draw xobject (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
      exit;
    end;

		pdf_drop_xobject(xobj);
	end

	else if (strcomp(fz_to_name(subtype), 'Image')=0) then
	begin
		if ((csi^.dev^.hints and FZ_IGNORE_IMAGE) = 0) then
		begin

			error := pdf_load_image(@img, csi^.xref, obj);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot load image (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);

        exit;
      end;
			pdf_show_image(csi, img);
			fz_drop_pixmap(img);
		end;
	end

	else if (strcomp(fz_to_name(subtype), 'PS')=0) then
	begin
	 	fz_warn('ignoring XObject with subtype PS');
  end

	else
	begin
		result:=fz_throw('unknown XObject subtype: "%s"', [fz_to_name(subtype)]);
    exit;
	end;
  result:=1;
	//return fz_okay;
end;

procedure  pdf_run_EMC(csi:ppdf_csi_s);
begin
end;

procedure  pdf_run_ET(csi:ppdf_csi_s);
begin
	pdf_flush_text(csi);
	csi^.accumulate := 1;
	csi^.in_text := 0;
end;

procedure  pdf_run_EX(csi:ppdf_csi_s) ;
begin
	csi^.xbalance :=csi^.xbalance-1;
end;

procedure  pdf_run_F(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 1, 0, 0);
end;

procedure  pdf_run_G(csi:ppdf_csi_s);
begin
	pdf_set_colorspace(csi, PDF_STROKE, get_fz_device_gray);
	pdf_set_color(csi, PDF_STROKE, @csi^.stack);
end;

procedure  pdf_run_J(csi:ppdf_csi_s);
var
gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.stroke_state.start_cap := trunc(csi^.stack[0]);
	gstate^.stroke_state.dash_cap := trunc(csi^.stack[0]);
	gstate^.stroke_state.end_cap := trunc(csi^.stack[0]);
end;

procedure  pdf_run_K(csi:ppdf_csi_s);
begin
	pdf_set_colorspace(csi, PDF_STROKE, get_fz_device_cmyk);
	pdf_set_color(csi, PDF_STROKE, @csi^.stack);
end;

procedure  pdf_run_M(csi:ppdf_csi_s);
var
gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
   inc(gstate, csi^.gtop);
	gstate^.stroke_state.miterlimit := csi^.stack[0];
end;

procedure  pdf_run_MP(csi:ppdf_csi_s);
begin
end;

procedure  pdf_run_Q(csi:ppdf_csi_s);
begin
	pdf_grestore(csi);
end;

procedure  pdf_run_RG(csi:ppdf_csi_s);
begin
	pdf_set_colorspace(csi, PDF_STROKE, get_fz_device_rgb);
	pdf_set_color(csi, PDF_STROKE, @csi^.stack);
end;

procedure  pdf_run_S(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 0, 1, 0);
end;

function pdf_run_SC_imp(csi:ppdf_csi_s; rdb:pfz_obj_s; what:pdffillkind_e; mat:ppdf_material_s ):integer;
var
	error:integer;
	patterntype,dict,	obj:pfz_obj_s;
	kind:fillkind_e;
  pat:ppdf_pattern_s;
  shd:pfz_shade_s;
begin
	kind := mat^.kind;
	if (csi^.name[0]<>#0)  then
		kind := PDF_MAT_PATTERN;

	case (kind) of
	PDF_MAT_NONE:
  begin
		result:= fz_throw('cannot set color in mask objects');
    exit;
  end;

	PDF_MAT_COLOR:
		pdf_set_color(csi, what, @csi^.stack);


	PDF_MAT_PATTERN:
  begin
		dict := fz_dict_gets(rdb, 'Pattern');
		if (dict=nil) then
    begin
		 result:= fz_throw('cannot find Pattern dictionary');
     exit;
   end;

		obj := fz_dict_gets(dict, csi^.name);
		if (obj=nil) then
    begin
			result:= fz_throw('cannot find pattern resource "%s"', [csi^.name]);
      exit;
   end;

		patterntype := fz_dict_gets(obj, 'PatternType');

		if (fz_to_int(patterntype) = 1) then
		begin

			error := pdf_load_pattern(@pat, csi^.xref, obj);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot load pattern (%d 0 R)', [fz_to_num(obj)]);
        exit;
      end;
      if csi^.top > 0 then
			pdf_set_pattern(csi, what, pat,  @csi^.stack)
      else
      pdf_set_pattern(csi, what, pat, nil);
			pdf_drop_pattern(pat);
		end
		else if (fz_to_int(patterntype) = 2) then
		begin

			error := pdf_load_shading(@shd, csi^.xref, obj);
			if (error<0)  then
      begin
			 result:= fz_rethrow(error, 'cannot load shading (%d 0 R)', [fz_to_num(obj)]);
       exit;
      end;
			pdf_set_shade(csi, what, shd);
			fz_drop_shade(shd);
		end
		else
		begin
			result:= fz_throw('unknown pattern type: %d', [fz_to_int(patterntype)]);
      exit;
		end;
		end;

	PDF_MAT_SHADE:
  begin
		result:= fz_throw('cannot set color in shade objects');
    exit;
		end;
	end;

	result:=1;
end;

procedure  pdf_run_SC(csi:ppdf_csi_s; rdb:pfz_obj_s);
var
	error:integer;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	error := pdf_run_SC_imp(csi, rdb, PDF_STROKE, @gstate^.stroke);
	if (error<0)  then
		fz_catch(error, 'cannot set color and colorspace');

end;

procedure  pdf_run_sc1(csi:ppdf_csi_s; rdb:pfz_obj_s);
var
	error:integer;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	error := pdf_run_SC_imp(csi, rdb, PDF_FILL, @gstate^.fill);
	if (error<0)  then
		fz_catch(error, 'cannot set color and colorspace');

end;

procedure  pdf_run_Tc(csi:ppdf_csi_s) ;
var
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	gstate^.char_space := csi^.stack[0];
end;

procedure  pdf_run_Tw(csi:ppdf_csi_s) ;
var
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.word_space := csi^.stack[0];
end;

procedure  pdf_run_Tz(csi:ppdf_csi_s);
var
  a:single;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	a := csi^.stack[0] / 100;
	pdf_flush_text(csi);
	gstate^.scale := a;
end;

procedure  pdf_run_TL(csi:ppdf_csi_s);
var
  gstate:ppdf_gstate_s;
begin
  gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.leading := csi^.stack[0];
end;

function  pdf_run_Tf(csi:ppdf_csi_s; rdb:pfz_obj_s):integer;
var

	error:integer;
	dict:pfz_obj_s;
	obj:pfz_obj_s;
  gstate:ppdf_gstate_s;
begin
  gstate := @csi^.gstate;
   inc(gstate, csi^.gtop);
	gstate^.size := csi^.stack[0];
	if (gstate^.font<>nil) then
		pdf_drop_font(gstate^.font);
	gstate^.font := nil;

	dict := fz_dict_gets(rdb, 'Font');
	if (dict=nil) then
  begin
		result:= fz_throw('"cannot find Font dictionary');
    exit;
  end;

	obj := fz_dict_gets(dict, csi^.name);
	if (obj=nil) then
  begin
		result:=fz_throw('cannot find font resource: "%s"', [csi^.name]);
    exit;
  end;

	error := pdf_load_font(@gstate^.font, csi^.xref, rdb, obj);
	if (error<0)  then
  begin
	 	result:=fz_rethrow(error, 'cannot load font (%d 0 R)', [fz_to_num(obj)]);
    exit;
  end;
   result:=1;
	//return fz_okay;
end;

procedure  pdf_run_Tr(csi:ppdf_csi_s);
var
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.render := trunc(csi^.stack[0]);
end;

procedure pdf_run_Ts(csi:ppdf_csi_s);
var
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	gstate^.rise := csi^.stack[0];
end;

procedure  pdf_run_Td(csi:ppdf_csi_s);
var
m: fz_matrix_s;
begin
	m := fz_translate(csi^.stack[0], csi^.stack[1]);
	csi^.tlm := fz_concat(m, csi^.tlm);
	csi^.tm := csi^.tlm;
end;

procedure  pdf_run_TD1(csi:ppdf_csi_s);
var
m: fz_matrix_s;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	gstate^.leading := -csi^.stack[1];
	m := fz_translate(csi^.stack[0], csi^.stack[1]);
	csi^.tlm := fz_concat(m, csi^.tlm);
	csi^.tm := csi^.tlm;
end;

procedure  pdf_run_Tm(csi:ppdf_csi_s);
begin
	csi^.tm.a := csi^.stack[0];
	csi^.tm.b := csi^.stack[1];
	csi^.tm.c := csi^.stack[2];
	csi^.tm.d := csi^.stack[3];
	csi^.tm.e := csi^.stack[4];
	csi^.tm.f := csi^.stack[5];
	csi^.tlm := csi^.tm;
end;

procedure  pdf_run_Tstar(csi:ppdf_csi_s) ;
var
  m: fz_matrix_s;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	m := fz_translate(0, -gstate^.leading);
	csi^.tlm := fz_concat(m, csi^.tlm);
	csi^.tm := csi^.tlm;
end;

procedure  pdf_run_Tj(csi:ppdf_csi_s) ;
begin
	if (csi^.string_len<>0) then
		pdf_show_string(csi, @csi^.string1, csi^.string_len)
	else
		pdf_show_text(csi, csi^.obj);
end;

procedure  pdf_run_TJ1(csi:ppdf_csi_s);
begin
	if (csi^.string_len<>0) then
		pdf_show_string(csi, @csi^.string1, csi^.string_len)
	else
		pdf_show_text(csi, csi^.obj);
end;

procedure  pdf_run_W(csi:ppdf_csi_s);
begin
	pdf_show_clip(csi, 0);
end;

procedure  pdf_run_Wstar(csi:ppdf_csi_s);
begin
	pdf_show_clip(csi, 1);
end;

procedure  pdf_run_b1(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 1, 1, 1, 0);
end;

procedure  pdf_run_bstar1(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 1, 1, 1, 1);
end;

procedure  pdf_run_c(csi:ppdf_csi_s);
var
	 a, b, c, d, e, f:single;
begin
	a := csi^.stack[0];
	b := csi^.stack[1];
	c := csi^.stack[2];
	d := csi^.stack[3];
	e := csi^.stack[4];
	f := csi^.stack[5];
	fz_curveto(csi^.path, a, b, c, d, e, f);
end;

procedure  pdf_run_cm(csi:ppdf_csi_s);
var
m: fz_matrix_s;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	m.a := csi^.stack[0];
	m.b := csi^.stack[1];
	m.c := csi^.stack[2];
	m.d := csi^.stack[3];
	m.e := csi^.stack[4];
	m.f := csi^.stack[5];

	gstate^.ctm := fz_concat(m, gstate^.ctm);
end;

procedure  pdf_run_d(csi:ppdf_csi_s);
var
	gstate:ppdf_gstate_s;
	array1:pfz_obj_s;
	i:integer;
begin
  	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);
	array1 := csi^.obj;
	gstate^.stroke_state.dash_len := MIN(fz_array_len(array1), length(gstate^.stroke_state.dash_list));
	for i := 0 to gstate^.stroke_state.dash_len-1 do
		gstate^.stroke_state.dash_list[i] := fz_to_real(fz_array_get(array1, i));
	gstate^.stroke_state.dash_phase := csi^.stack[0];
end;

procedure  pdf_run_d0(csi:ppdf_csi_s);
begin
	csi^.dev^.flags :=csi^.dev^.flags or FZ_CHARPROC_COLOR;
end;

procedure  pdf_run_d1(csi:ppdf_csi_s);
begin
	csi^.dev^.flags :=	csi^.dev^.flags or FZ_CHARPROC_MASK;
end;

procedure  pdf_run_f1(csi:ppdf_csi_s) ;
begin
	pdf_show_path(csi, 0, 1, 0, 0);
end;

procedure  pdf_run_fstar(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 1, 0, 1);
end;

procedure  pdf_run_g1(csi:ppdf_csi_s) ;
begin
	pdf_set_colorspace(csi, PDF_FILL, get_fz_device_gray);
	pdf_set_color(csi, PDF_FILL, @csi^.stack);
end;

function pdf_run_gs(csi:ppdf_csi_s; rdb:pfz_obj_s):integer;
var
	error:integer;
	dict,obj:pfz_obj_s;
begin
	dict := fz_dict_gets(rdb, 'ExtGState');
	if (dict=nil) then
  begin
		result:= fz_throw('cannot find ExtGState dictionary');
    exit;
  end;

	obj := fz_dict_gets(dict, csi^.name);
	if (obj=nil) then
  begin
		result:= fz_throw('"cannot find extgstate resource "%s"',[ csi^.name]);
    exit;
  end;

	error := pdf_run_extgstate(csi, rdb, obj);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot set ExtGState (%d 0 R)', [fz_to_num(obj)]);
    exit;
  end;
 //	return fz_okay;
  result:=1;
end;

procedure  pdf_run_h(csi:ppdf_csi_s) ;
begin
	fz_closepath(csi^.path);
end;

procedure  pdf_run_i(csi:ppdf_csi_s) ;
begin
end;

procedure  pdf_run_j1(csi:ppdf_csi_s);
var
	gstate:ppdf_gstate_s;
begin
  	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);;
	gstate^.stroke_state.linejoin := trunc(csi^.stack[0]);
end;

procedure  pdf_run_k1(csi:ppdf_csi_s);
begin
	pdf_set_colorspace(csi, PDF_FILL, get_fz_device_cmyk);
	pdf_set_color(csi, PDF_FILL, @csi^.stack);
end;

procedure  pdf_run_l(csi:ppdf_csi_s) ;
var
	 a, b:single;
begin
	a := csi^.stack[0];
	b := csi^.stack[1];
	fz_lineto(csi^.path, a, b);
end;

procedure  pdf_run_m1(csi:ppdf_csi_s);
var
	 a, b:single;
begin
	a := csi^.stack[0];
	b := csi^.stack[1];
	fz_moveto(csi^.path, a, b);
end;

procedure  pdf_run_n(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 0, 0, 0, 0);
end;

procedure  pdf_run_q1(csi:ppdf_csi_s);
begin
	pdf_gsave(csi);
end;

procedure  pdf_run_re(csi:ppdf_csi_s);
var
	x, y, w, h:single;
begin
	x := csi^.stack[0];
	y := csi^.stack[1];
	w := csi^.stack[2];
	h := csi^.stack[3];

	fz_moveto(csi^.path, x, y);
	fz_lineto(csi^.path, x + w, y);
	fz_lineto(csi^.path, x + w, y + h);
	fz_lineto(csi^.path, x, y + h);
	fz_closepath(csi^.path);
end;

procedure  pdf_run_rg1(csi:ppdf_csi_s);
begin
	pdf_set_colorspace(csi, PDF_FILL, get_fz_device_rgb);
	pdf_set_color(csi, PDF_FILL, @csi^.stack);
end;

procedure  pdf_run_ri(csi:ppdf_csi_s) ;
begin
end;

procedure  pdf_run(csi:ppdf_csi_s);
begin
	pdf_show_path(csi, 1, 0, 1, 0);
end;

function pdf_run_sh(csi:ppdf_csi_s; rdb:pfz_obj_s):integer;
var
	dict:pfz_obj_s;
	obj:pfz_obj_s;
	shd:pfz_shade_s;
	error:integer;
begin
	dict := fz_dict_gets(rdb, 'Shading');
	if (dict=nil) then
  begin
		result:= fz_throw('cannot find shading dictionary');
    exit;
  end;

	obj := fz_dict_gets(dict, csi^.name);
	if (obj=nil) then
  begin
		result:= fz_throw('cannot find shading resource: %s', [csi^.name]);
    exit;
  end;

	if ((csi^.dev^.hints and FZ_IGNORE_SHADE) = 0) then
	begin
		error := pdf_load_shading(@shd, csi^.xref, obj);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load shading (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
      exit;
    end;
		pdf_show_shade(csi, shd);
		fz_drop_shade(shd);
	end;
	//return fz_okay;
  result:=1;
end;

procedure  pdf_run_v(csi:ppdf_csi_s);
var
	a, b, c, d:integer;
begin
	a := trunc(csi^.stack[0]);
	b := trunc(csi^.stack[1]);
	c := trunc(csi^.stack[2]);
	d := trunc(csi^.stack[3]);
	fz_curvetov(csi^.path, a, b, c, d);
end;

procedure  pdf_run_w1(csi:ppdf_csi_s);
var
	gstate:ppdf_gstate_s;
begin
  	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);;
	pdf_flush_text(csi); //* linewidth affects stroked text rendering mode */
	gstate^.stroke_state.linewidth := csi^.stack[0];
end;

procedure  pdf_run_y(csi:ppdf_csi_s);
var
	 a, b, c, d:single;
begin
	a := csi^.stack[0];
	b := csi^.stack[1];
	c := csi^.stack[2];
	d := csi^.stack[3];
	fz_curvetoy(csi^.path, a, b, c, d);
end;

procedure  pdf_run_squote(csi:ppdf_csi_s);
var
  m: fz_matrix_s;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	m := fz_translate(0, -gstate^.leading);
	csi^.tlm := fz_concat(m, csi^.tlm);
	csi^.tm := csi^.tlm;

	if (csi^.string_len<>0) then
		pdf_show_string(csi, @csi^.string1, csi^.string_len)
	else
		pdf_show_text(csi, csi^.obj);
end;

procedure  pdf_run_dquote(csi:ppdf_csi_s);
var
  m: fz_matrix_s;
  gstate:ppdf_gstate_s;
begin
	gstate := @csi^.gstate;
  inc(gstate, csi^.gtop);

	gstate^.word_space := csi^.stack[0];
	gstate^.char_space := csi^.stack[1];

	m := fz_translate(0, -gstate^.leading);
	csi^.tlm := fz_concat(m, csi^.tlm);
	csi^.tm := csi^.tlm;

	if (csi^.string_len)<>0 then
		pdf_show_string(csi, @csi^.string1, csi^.string_len)
	else
		pdf_show_text(csi, csi^.obj);
end;

(*#define A(a) (a)
#define B(a,b) (a | b << 8)
#define C(a,b,c) (a | b << 8 | c << 16) *)

function a(a:char):integer;
begin
  result:=ord(a);
end;

function b(a,b:char):integer;
begin
  result:=ord(a) or (ord(b) shl 8);
end;

function c(a,b,c:char):integer;
begin
  result:=ord(a) or (ord(b) shl 8) or (ord(c) shl 16);
end;

function
pdf_run_keyword(csi:ppdf_csi_s;rdb:pfz_obj_s; file1:pfz_stream_s; buf:pchar):integer;
var
	error:integer;
	key:integer;
  key1:char;
begin
	key := ord((buf+0)^);
	if ord((buf+1)^)<>0 then
	begin
		key :=key or (ord((buf+1)^) shl 8);
		if  ord((buf+2)^)<>0 then
		begin
			key :=key or (ord((buf+2)^) shl 16);
			if ord((buf+3)^)<>0  then
				key := 0;
		end;
	end;
  //key1:=chr(key);
	IF key = A('"') then
            pdf_run_dquote(csi)
    else  if key=A('''') then
               pdf_run_squote(csi)
    else if key=A('B') then
    pdf_run_B(csi)
    else if key=B('B','*') then
    pdf_run_Bstar(csi)
    else if key=C('B','D','C')
    then  pdf_run_BDC(csi)
    else if  key=B('B','I') then
    begin
       error := pdf_run_BI(csi, rdb, file1);
	   	if (error<0)  then
      begin
			  result:= fz_rethrow(error, 'cannot draw inline image');
        exit;
      end;
    end
    else if  key =C('B','M','C') then
    pdf_run_BMC(csi)
    else if  key=B('B','T') then
    pdf_run_BT(csi)
    else if  key=B('B','X') then
    pdf_run_BX(csi)
    else if  key= B('C','S') then
    pdf_run_CS(csi, rdb)
    else if  key=B('D','P') then
    pdf_run_DP(csi)
    else if  key=B('D','o') then
    begin
   		error := pdf_run_Do(csi, rdb);
	  	if (error<0)  then
      begin
		   	fz_catch(error, 'cannot draw xobject/image');
      end;
    end
    else if  key=C('E','M','C')then
    pdf_run_EMC(csi)
    else if  key=B('E','T') then
    pdf_run_ET(csi)
     else if  key=B('E','X')then
     pdf_run_EX(csi)
     else if  key=A('F') then
     pdf_run_F(csi)
     else if  key=A('G') then
     pdf_run_G(csi)
     else if  key=A('J') then
     pdf_run_J(csi)
     else if  key= A('K') then
      pdf_run_K(csi)
     else if  key=A('M') then
     pdf_run_M(csi)
     else if  key=B('M','P') then
     pdf_run_MP(csi)
     else if  key=A('Q') then
     pdf_run_Q(csi)
     else if  key=B('R','G') then
      pdf_run_RG(csi)
     else if  key=A('S') then
      pdf_run_S(csi)
     else if  key=B('S','C') then
      pdf_run_SC(csi, rdb)
     else if  key=C('S','C','N') then
     pdf_run_SC(csi, rdb)
     else if  key=B('T','*') then
     pdf_run_Tstar(csi)
     else if  key=B('T','D') then
       pdf_run_TD1(csi)
     else if  key=B('T','J') then
      pdf_run_TJ1(csi)
     else if  key=B('T','L') then
      pdf_run_TL(csi)
      else if  key=B('T','c') then
       pdf_run_Tc(csi)
    else if  key=B('T','d') then
    pdf_run_Td(csi)
    else if  key=B('T','f') then
    begin
		error := pdf_run_Tf(csi, rdb);
		if (error<0)  then
    begin
			fz_catch(error, 'cannot set font');
    end;
    end
    else if  key=B('T','j') then
     pdf_run_Tj(csi)
    else if  key=B('T','m') then
     pdf_run_Tm(csi)
    else if  key=B('T','r') then
    pdf_run_Tr(csi)
    else if  key=B('T','s') then
     pdf_run_Ts(csi)
    else if  key=B('T','w') then
    pdf_run_Tw(csi)
    else if  key=B('T','z') then
     pdf_run_Tz(csi)
    else if  key=A('W') then
    pdf_run_W(csi)
    else if  key=B('W','*') then
     pdf_run_Wstar(csi)
    else if  key=A('b') then
    pdf_run_b1(csi)
    else if  key=B('b','*') then
     pdf_run_bstar1(csi)
    else if  key=A('c') then
     pdf_run_c(csi)
    else if  key=B('c','m') then
     pdf_run_cm(csi)
    else if  key=B('c','m') then
     pdf_run_cm(csi)
    else if  key=B('c','s') then
     pdf_run_cs1(csi, rdb)
    else if  key=A('d') then
     pdf_run_d(csi)
    else if  key=B('d','0') then
     pdf_run_d0(csi)
    else if  key=B('d','1') then
     pdf_run_d1(csi)
    else if  key=A('f') then
     pdf_run_f1(csi)
    else if  key=B('f','*') then
     pdf_run_fstar(csi)
    else if  key=A('g') then
     pdf_run_g1(csi)
    else if  key=B('g','s') then
    begin
		error := pdf_run_gs(csi, rdb);
		if (error<0)  then
			fz_catch(error, 'cannot set graphics state');

		end
    else if  key=A('h') then
    pdf_run_h(csi)
    else if  key=A('i') then
    pdf_run_i(csi)
    else if  key=A('j') then
    pdf_run_j1(csi)
    else if  key=A('k') then
    pdf_run_k1(csi)
    else if  key=A('l') then
    pdf_run_l(csi)
    else if  key=A('m') then
    pdf_run_m1(csi)
    else if  key=A('n') then
     pdf_run_n(csi)
    else if  key=A('q') then
     pdf_run_q1(csi)
    else if  key=B('r','e') then
     pdf_run_re(csi)
    else if  key=B('r','g') then
     pdf_run_rg1(csi)
    else if  key=B('r','i') then
     pdf_run_ri(csi)
    else if  key=A('s') then
    pdf_run(csi)
    else if  key=B('s','c') then
     pdf_run_sc1(csi, rdb)
    else if  key=C('s','c','n') then
    pdf_run_sc1(csi, rdb)
    else if  key=B('s','h') then
    begin
     	error := pdf_run_sh(csi, rdb);
	  	if (error<0)  then
			  fz_catch(error, 'cannot draw shading');

    end
    else if  key=A('v') then
    pdf_run_v(csi)
    else if  key=A('w') then
     pdf_run_w1(csi)
    else if  key=A('y') then
     pdf_run_y(csi)
    else
    begin
  		if (csi^.xbalance=0) then
			  fz_warn('unknown keyword: %s', [buf]);

		end;
  result:=1;

	//return fz_okay;
end;

function
pdf_run_stream(csi:ppdf_csi_s; rdb:pfz_obj_s; file1:pfz_stream_s; buf:pchar; buflen:integer):integer;
var
	error:integer;
	 tok:pdf_kind_e;
    len, in_array:integer;
   gstate: ppdf_gstate_s;
  i:integer;
begin
	//* make sure we have a clean slate if we come here from flush_text */
	pdf_clear_stack(csi);

ppppppppppp:=ppppppppppp+1;
	in_array := 0;
  i:=0;
	while (true) do
	begin
		if (csi^.top = length(csi^.stack) - 1) then
    begin
			result:= fz_throw('stack overflow');

      exit;
    end;
    i:=i+1;
 // outprintf('pdf_run_stream:'+inttostr(ppppppppppp)+'--'+inttostr(i));
  //   if (i=2) and (ppppppppppp=5) then
   //   outprintf('pdf_run_stream:'+inttostr(i));
  //    if i=4004 then
    //  outprintf('pdf_run_stream:'+inttostr(i));
  {   i:=i+1;
    if i>=197 then
     outprintf(inttostr(i));
    if i=41 then
     outprintf(inttostr(i));  }
  //   if i=560 then
  //   OutputDebugString(pchar(inttostr(i)));
		error := pdf_lex(@tok, file1, buf, buflen, @len);

    //if i=55 then
   // outprintf(pchar(inttostr(i)));
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'lexical error in content stream');
      exit;
    end;

		if (in_array<>0) then
		begin
			if (tok = PDF_TOK_CLOSE_ARRAY) then
			begin
				in_array := 0;
			end
			else if (tok = PDF_TOK_INT) or (tok = PDF_TOK_REAL) then
			begin
				gstate := @csi^.gstate;
        inc(gstate, csi^.gtop);
			 	pdf_show_space(csi, -fz_atof(buf) * gstate^.size * 0.001);
			end
			else if (tok = PDF_TOK_STRING) then
			begin
				pdf_show_string(csi, pbyte(buf), len);
			end
			else if (tok = PDF_TOK_KEYWORD) then
			begin
				if (strcomp(buf, 'Tw')=0) or (strcomp(buf, 'Tc')=0) then
					fz_warn('ignoring keyword "%s" inside array',[ buf])
				else
        begin
					result:= fz_throw('syntax error in array');
          exit;
        end;
			end
			else if (tok = PDF_TOK_EOF) then
      begin
				//return fz_okay;
        result:=1;
        exit;
      end
			else
      begin
				result:= fz_throw('syntax error in array');
        exit;
      end;
		end

		else
    begin
    case tok of
		PDF_TOK_ENDSTREAM:
    begin
      result:=1;
      exit;
    end;
		PDF_TOK_EOF:
    begin
		 //	return fz_okay;
       result:=1;
      exit;
    end;

		PDF_TOK_OPEN_ARRAY:
      begin
			if (csi^.in_text=0) then
			begin
				error := pdf_parse_array(@csi^.obj, csi^.xref, file1, buf, buflen);
				if (error<0)  then
        begin
					result:= fz_rethrow(error, 'cannot parse array');
          exit;
        end;
			end
			else
			begin
				in_array := 1;
			end;
		 end;

		PDF_TOK_OPEN_DICT:
      begin
			error := pdf_parse_dict(@csi^.obj, csi^.xref, file1, buf, buflen);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot parse dictionary');
        exit;
      end;
			end;

		PDF_TOK_NAME: fz_strlcpy(@csi^.name, buf, sizeof(csi^.name));
		PDF_TOK_INT:
      begin
			csi^.stack[csi^.top] := atoi(buf);
			csi^.top:=csi^.top +1;
			end;

		PDF_TOK_REAL:
      begin
			csi^.stack[csi^.top] := fz_atof(buf);
			csi^.top:=csi^.top +1;
			end;

		PDF_TOK_STRING:
      begin
			if (len <= sizeof(csi^.string1)) then
			begin
				copymemory(@csi^.string1, buf, len);
				csi^.string_len := len;
			end
			else
			begin
				csi^.obj := fz_new_string(buf, len);
			end;
		  end;

		PDF_TOK_KEYWORD:
    begin

		  error := pdf_run_keyword(csi, rdb, file1, buf);
			if (error<0)  then
      begin
				result:=fz_rethrow(error, 'cannot run keyword');
        exit;
      end;
			pdf_clear_stack(csi);

   end;
   else
   begin
			result:= fz_throw('syntax error in content stream');

      exit;
   end;
	 end;
   end;
	end;
end;

(*
 * Entry points
 *)
function pdf_run_buffer(csi:ppdf_csi_s; rdb:pfz_obj_s; contents:pfz_buffer_s):integer;
var
	error:integer;
	len :integer;
	buf:pchar;
	file1:pfz_stream_s;
	save_in_text:integer;

begin
  len := sizeof(csi^.xref^.scratch);
  buf := fz_malloc(len); //* we must be re-entrant for type3 fonts */
  file1 := fz_open_buffer(contents);
  save_in_text := csi^.in_text;

	csi^.in_text := 0;
	error := pdf_run_stream(csi, rdb, file1, buf, len);
	csi^.in_text := save_in_text;
	fz_close(file1);
	fz_free(buf);
	if (error<0)  then
  begin
    //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692260 */
		result:= fz_rethrow(error, 'couldn''t parse the whole content stream, rendering anyway');

    exit;
  end;
	result:=1; // fz_okay;
end;

function
pdf_run_page_with_usage(xref:ppdf_xref_s; page:ppdf_page_s; dev:pfz_device_s; ctm:fz_matrix; target:pchar):integer;
var
	csi:ppdf_csi_s;
	error:integer;
	annot:ppdf_annot_s;
	flags:integer;
begin
	if (page^.transparency<>0) then
		fz_begin_group(dev, fz_transform_rect(ctm, page^.mediabox), 1, 0, 0, 1);

	csi := pdf_new_csi(xref, dev, ctm, target);

	error := pdf_run_buffer(csi, page^.resources, page^.contents);
	pdf_free_csi(csi);

	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot parse page content stream');

    exit;
  end;


  annot := page^.annots;
  while ( annot<>nil )  do          //annot = annot^.next
	begin
		flags := fz_to_int(fz_dict_gets(annot^.obj, 'F'));

		//* TODO: NoZoom and NoRotate */
		if (flags and (1 shl 0))<>0 then //* Invisible */
    begin
      annot := annot^.next;
			continue;
    end;
		if (flags and (1 shl 1))<>0 then //* Hidden */
    begin
      annot := annot^.next;
			continue;
    end;
		if (flags and (1 shl 5))<>0 then //* NoView */
    begin
      annot := annot^.next;
			continue;
    end;
		if (pdf_is_hidden_ocg(annot^.obj, target)) then
    begin
      annot := annot^.next;
			continue;
    end;
		csi := pdf_new_csi(xref, dev, ctm, target);
		error := pdf_run_xobject(csi, page^.resources, annot^.ap, annot^.matrix);
		pdf_free_csi(csi);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot parse annotation appearance stream');

      exit;
    end;
     annot := annot^.next;
	end;

	if (page^.transparency<>0) then
		fz_end_group(dev);
  result:=1;
 //	return fz_okay;
end;

function
pdf_run_page(xref:ppdf_xref_s; page:ppdf_page_s; dev:pfz_device_s; ctm:fz_matrix):integer;
begin
	result:= pdf_run_page_with_usage(xref, page, dev, ctm, 'View');
end;

function
pdf_run_glyph(xref:ppdf_xref_s; resources:pfz_obj_s; contents:pfz_buffer_s; dev:pfz_device_s; ctm:fz_matrix):integer;
var
csi:ppdf_csi_s;
error:integer;
begin
	csi:= pdf_new_csi(xref, dev, ctm, 'View');
	error := pdf_run_buffer(csi, resources, contents);
	pdf_free_csi(csi);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot parse glyph content stream');

    exit;
  end;
	result:=1;
end;



end.
