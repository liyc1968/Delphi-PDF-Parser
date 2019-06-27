unit fz_textx;

interface
uses
 Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,Math,digtypes,freetype,fz_pixmapss,base_error;
function ft_error_string(err:integer):pchar;
procedure fz_finalize_freetype();
function fz_bound_text(text:pfz_text_s;ctm: fz_matrix):fz_rect_s;
procedure fz_drop_font(font:pfz_font_s);
function fz_render_ft_stroked_glyph(font:pfz_font_s; gid:integer;trm: fz_matrix_s; ctm:fz_matrix_s; state:pfz_stroke_state_s):pfz_pixmap_s;
function fz_render_t3_glyph(font:pfz_font_s; gid:integer;  trm:fz_matrix;model:pfz_colorspace_s):pfz_pixmap_s;
function fz_render_ft_glyph(font:pfz_font_s;gid:integer;trm:fz_matrix_s) :pfz_pixmap_s;
function fz_keep_font(font:pfz_font_s):pfz_font_s;
procedure fz_free_text(text:pfz_text_s);
function fz_new_font_from_memory(fontp:ppfz_font_s; data:pbyte; len:integer; index:integer):integer;
function fz_new_text(font:pfz_font_s;trm: fz_matrix_s; wmode:integer) :pfz_text_s;
procedure fz_add_text(text:pfz_text_s;gid:integer;ucs:integer;x:single;y:single);
function fz_new_type3_font(name:pchar;matrix :fz_matrix ):pfz_font_s;
procedure fz_set_font_bbox(font:pfz_font_s; xmin:single; ymin:single;xmax:single; ymax:single);
function fz_clone_text(old:pfz_text_s) :pfz_text_s;

implementation
uses base_object_functions,draw_edge,fz_bboxxs,fz_dev_null,res_colorspace,draw_glyphss,draw_devicess;
var
fz_ftlib:FT_Library= nil;
fz_ftlib_refs:integer=0 ;



function fz_new_font(name:pchar):pfz_font_s;
var
	font:pfz_font_s;
begin
	font := fz_malloc(sizeof(fz_font_s));
	font^.refs := 1;

	if (name<>nil) then
		fz_strlcpy(@font^.name, name, sizeof(font^.name))
	else
		fz_strlcpy(@font^.name, '(null)', sizeof(font^.name));
 // fz_warn( pchar(@font^.name));
	font^.ft_face := nil;
	font^.ft_substitute := 0;
	font^.ft_bold := 0;
	font^.ft_italic := 0;
	font^.ft_hint := 0;

	font^.ft_file := NiL;
	font^.ft_data :=NiL;
	font^.ft_size := 0;

	font^.t3matrix := fz_identity;
	font^.t3resources := NiL;
	font^.t3procs := NiL;
	font^.t3widths := NiL;
	font^.t3xref := NiL;
	font^.t3run := NiL;

	font^.bbox.x0 := 0;
	font^.bbox.y0 := 0;
	font^.bbox.x1 := 1000;
	font^.bbox.y1 := 1000;

	font^.width_count := 0;
	font^.width_table := NiL;

	result:=font;
end;


function fz_keep_font(font:pfz_font_s):pfz_font_s;
begin
	font^.refs:= font^.refs+1;
	result:=font;
end;

procedure fz_drop_font(font:pfz_font_s);
var
  fterr:integer;
	i:integer;
begin
  if font=nil then
  exit;
  font^.refs:= font^.refs-1;
	if (font<>nil) and  (font^.refs = 0) then
	begin
		if (font^.t3procs<>nil) then
		begin
			if (font^.t3resources<>nil) then
				fz_drop_obj(font^.t3resources);
			for i := 0 to 256-1 do
				if (fz_buffer_s_items(font^.t3procs)[i]<>nil)  then
					fz_drop_buffer(fz_buffer_s_items(font^.t3procs)[i]);
			fz_free(font^.t3procs);
			fz_free(font^.t3widths);
		end;

		if (font^.ft_face<>nil) then
		begin
			fterr := FT_Done_Face(font^.ft_face);
			if (fterr<>0) then
				fz_warn('freetype finalizing face: %s', [ft_error_string(fterr)]);

			fz_finalize_freetype();
		end;

		if (font^.ft_file<>nil) then
			fz_free(font^.ft_file);
		if (font^.ft_data<>nil) then
			fz_free(font^.ft_data);

		if (font^.width_table<>nil) then
			fz_free(font^.width_table);

		fz_free(font);
	end;
end;

procedure fz_set_font_bbox(font:pfz_font_s; xmin:single; ymin:single;xmax:single; ymax:single);
begin
	font^.bbox.x0 := xmin;
	font^.bbox.y0 := ymin;
	font^.bbox.x1 := xmax;
	font^.bbox.y1 := ymax;
end;

//*  * Freetype hooks  */


// #undef __FTERRORS_H__ #define FT_ERRORDEF(e, v, s)	{ (e), (s) }, #define FT_ERROR_START_LIST #define FT_ERROR_END_LIST	{ 0, NULL }   }



//static const struct ft_error ft_errors[] = { #include FT_ERRORS_H };

function ft_error_string(err:integer):pchar;
var
  e:^ft_error;
	//const struct ft_error *e;
begin
 //	for (e := ft_errors; e->str != NULL; e++)
	//	if (e->err == err)
	//		return e->str;

	result:='Unknown error';
end;

function fz_init_freetype() :integer;
var
fterr:integer;
maj, min, pat:integer;
begin
	if (fz_ftlib<>nil) then
	begin
		fz_ftlib_refs:=fz_ftlib_refs+1;
		//return fz_okay;
    result:=1;
    EXIT;
	end;

  fterr := FT_Init_FreeType(@fz_ftlib);
	if (fterr<>0) then
  begin
		result:=fz_throw('cannot init freetype: %s', [ft_error_string(fterr)]);
    exit;
  end;

 	FT_Library_Version(fz_ftlib, @maj, @min, @pat);
	if ((maj = 2) and (min = 1) and  (pat < 7)) then
	begin
		fterr := FT_Done_FreeType(fz_ftlib);
		if (fterr<>0) then
		 	fz_warn('freetype finalizing: %s', [ft_error_string(fterr)]);

	   result:= fz_throw('freetype version too old: %d.%d.%d', [maj, min, pat]);
   exit;
	end;

	fz_ftlib_refs:=fz_ftlib_refs+1;
	//return fz_okay;
  result:=1;
end;

procedure fz_finalize_freetype();
var
	 fterr:integer;
begin
  fz_ftlib_refs:=fz_ftlib_refs-1;
	if (fz_ftlib_refs = 0) then
	begin
		fterr := FT_Done_FreeType(fz_ftlib);
		if (fterr<>0) then
		 	fz_warn('freetype finalizing: %s', [ft_error_string(fterr)]);
		fz_ftlib := nil;
	end;
end;


function fz_new_font_from_file(fontp:ppfz_font_s; path:pchar;index:integer):integer;
var
	face:FT_Face ;
	error:integer;
	font:pfz_font_s;
	fterr:integer;
begin
	error := fz_init_freetype();
	if (error<0) then
  begin
	 result:= fz_rethrow(error, 'cannot init freetype library');

    exit;
  end;

	fterr := FT_New_Face(fz_ftlib, path, index, @face);
	if (fterr<>0) then
  begin
		result:=fz_throw('freetype: cannot load font: %s', [ft_error_string(fterr)]);
    exit;
  end;

	font := fz_new_font(face^.family_name);
	font^.ft_face := face;
	font^.bbox.x0 := face^.bbox.xMin * 1000 div face^.units_per_EM;
	font^.bbox.y0 := face^.bbox.yMin * 1000 div face^.units_per_EM;
	font^.bbox.x1 := face^.bbox.xMax * 1000 div face^.units_per_EM;
	font^.bbox.y1 := face^.bbox.yMax * 1000 div face^.units_per_EM;

	fontp^ := font;
	result:=1;
end;

function fz_new_font_from_memory(fontp:ppfz_font_s; data:pbyte; len:integer; index:integer):integer;
var
	face:FT_Face;
	 error:integer;
	font:pfz_font_s;
	fterr:integer;
begin
	error := fz_init_freetype();
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot init freetype library');
     //result:=-1 ;
     exit;
  end;

	fterr := FT_New_Memory_Face(fz_ftlib, FT_Byte_ptr(data), len, index, @face);
	if (fterr<>0) then
   begin
		result:=fz_throw('freetype: cannot load font: %s', [ft_error_string(fterr)]);
    exit;
  end;

	font := fz_new_font(face^.family_name);
	font^.ft_face := face;
	font^.bbox.x0 := face^.bbox.xMin * 1000 div face^.units_per_EM;
	font^.bbox.y0 := face^.bbox.yMin * 1000 div face^.units_per_EM;
	font^.bbox.x1 := face^.bbox.xMax * 1000 div face^.units_per_EM;
	font^.bbox.y1 := face^.bbox.yMax * 1000 div face^.units_per_EM;

	fontp^ := font;
 //	return fz_okay;
   result:=1;
   exit;
end;

function fz_adjust_ft_glyph_width(font:pfz_font_s;gid:integer;trm:fz_matrix_s):fz_matrix_s;
const
FT_LOAD_NO_BITMAP=$8;
FT_LOAD_IGNORE_TRANSFORM=$800;
var
  fterr:FT_Error;
  subw:integer;
  realw:integer;
	scale:single;
begin
	//* Fudge the font matrix to stretch the glyph if we've substituted the font. */
	if (font^.ft_substitute<>0) and (gid < font^.width_count)  then
	begin


		//* TODO: use FT_Get_Advance */
		fterr := FT_Set_Char_Size(font^.ft_face, 1000, 1000, 72, 72);
		if (fterr<>0) then
		 	fz_warn('"freetype setting character size: %s', [ft_error_string(fterr)]);


		fterr := FT_Load_Glyph(font^.ft_face, gid,FT_LOAD_NO_HINTING or FT_LOAD_NO_BITMAP or FT_LOAD_IGNORE_TRANSFORM);
		if (fterr<>0) then
			fz_warn('freetype failed to load glyph: %s', [ft_error_string(fterr)]);


		realw := FT_Face(font^.ft_face).glyph^.metrics.horiAdvance;
		subw := integer_items(font^.width_table)[gid];
		if (realw<>0) then
			scale:= subw / realw
		else
			scale := 1;

		result:= fz_concat(fz_scale(scale, 1), trm);
    EXIT;
	end;

	result:=trm;
end;


function fz_copy_ft_bitmap(left:integer;top:integer; bitmap:FT_Bitmap_ptr):pfz_pixmap_s;
var
	pixmap:pfz_pixmap_s;
	y:integer;
  w:integer;
  outp,inp:pbyte;
  bit:byte ;
begin
	pixmap := fz_new_pixmap(nil, bitmap^.width, bitmap^.rows);
	pixmap^.x := left;
	pixmap^.y := top - bitmap^.rows;

	if (bitmap^.pixel_mode = char(FT_PIXEL_MODE_MONO)) then
	begin
		for y := 0 to pixmap^.h-1 do
		begin
			outp := pointer(cardinal(pixmap^.samples) + y * pixmap^.w);
			inp := pointer(cardinal(bitmap^.buffer) + (pixmap^.h - y - 1) * bitmap^.pitch);
			bit := $80;
			 w := pixmap^.w;
			while (w>0) do
			begin
        if inp^ and bit<>0 then
         outp^:=255
         else
         outp^:=0;
        inc(outp);
				bit:=bit shr 1;
				if (bit = 0) then
				begin
					bit := $80;
					inc(inp);
				end;
        w:=w-1;
			end;
		end;
	end
	else
	begin
		for y := 0 to pixmap^.h-1 do
		begin
      move(
      pointer(cardinal(	bitmap^.buffer) + (pixmap^.h - y - 1) * bitmap^.pitch)^,
       pointer(cardinal(pixmap^.samples) + y * pixmap^.w)^,
      pixmap^.w);
		end;
	end;

	result:= pixmap;
end;

function fz_render_ft_glyph(font:pfz_font_s;gid:integer;trm:fz_matrix_s) :pfz_pixmap_s;
var
	face :ft_face;
	m:FT_Matrix;
	v:FT_Vector;
	fterr:FT_Error;
  scale,strength:single;
begin
  face := font^.ft_face;
	trm := fz_adjust_ft_glyph_width(font, gid, trm);

	if (font^.ft_italic<>0) then
		trm := fz_concat(fz_shear(0.3, 0), trm);

{	/*
	Freetype mutilates complex glyphs if they are loaded
	with FT_Set_Char_Size 1.0. it rounds the coordinates
	before applying transformation. to get more precision in
	freetype, we shift part of the scale in the matrix
	into FT_Set_Char_Size instead
	*/   }

	m.xx := trunc(trm.a * 64); //* should be 65536 */
	m.yx := trunc(trm.b * 64);
	m.xY := trunc(trm.c * 64);
	m.yy := trunc(trm.d * 64);
	v.x := trunc(trm.e * 64);
	v.y := trunc(trm.f * 64);

	fterr := FT_Set_Char_Size(face, 65536, 65536, 72, 72); //* should be 64, 64 */
	if (fterr<>0) then
		fz_warn('freetype setting character size: %s', [ft_error_string(fterr)]);

	FT_Set_Transform(face, @m, @v);

	if (fz_get_aa_level() = 0) then
	begin
		//* If you really want grid fitting, enable this code. */
		scale := fz_matrix_expansion(trm);
		m.xx := trunc(trm.a * 65536 / scale);
		m.xy := trunc(trm.b * 65536 / scale);
		m.yx := trunc(trm.c * 65536 / scale);
		m.yy := trunc(trm.d * 65536 / scale);
		v.x := 0;
		v.y := 0;

		fterr := FT_Set_Char_Size(face, trunc(64 * scale), trunc(64 * scale), 72, 72);
		if (fterr<>0) then
			fz_warn('freetype setting character size: %s', [ft_error_string(fterr)]);

		FT_Set_Transform(face, @m, @v);
		fterr := FT_Load_Glyph(face, gid, FT_LOAD_NO_BITMAP or FT_LOAD_TARGET_MONO);
		if (fterr<>0) then
		 	fz_warn('freetype load glyph (gid %d): %s', [gid, ft_error_string(fterr)]);

	end
	else if (font^.ft_hint<>0)  then
	begin
	 {	/*
		Enable hinting, but keep the huge char size so that
		it is hinted for a character. This will in effect nullify
		the effect of grid fitting. This form of hinting should
		only be used for DynaLab and similar tricky TrueType fonts,
		so that we get the correct outline shape.
		*/  }
		fterr := FT_Load_Glyph(face, gid, FT_LOAD_NO_BITMAP);
		if (fterr<>0) then
			fz_warn('freetype load glyph (gid %d): %s', [gid, ft_error_string(fterr)]);

	end
	else
	begin
		fterr := FT_Load_Glyph(face, gid, FT_LOAD_NO_BITMAP or FT_LOAD_NO_HINTING);
		if (fterr<>0) then
		begin
			fz_warn('freetype load glyph (gid %d): %s', [gid, ft_error_string(fterr)]);
			result:=nil; // NULL;
      exit;
		end;
	end;

	if (font^.ft_bold<>0) then
	begin
		strength := fz_matrix_expansion(trm) * 0.04;
		FT_Outline_Embolden(@face^.glyph^.outline, trunc(strength * 64));
		FT_Outline_Translate(@face^.glyph^.outline, trunc(-strength * 32), trunc(-strength * 32));
	end;
  if   fz_get_aa_level() > 0 then
      fterr := FT_Render_Glyph(face^.glyph,  FT_RENDER_MODE_NORMAL)
      else
       fterr := FT_Render_Glyph(face^.glyph,  FT_RENDER_MODE_MONO) ;
 //	fterr := FT_Render_Glyph(face^.glyph, fz_get_aa_level() > 0 ? FT_RENDER_MODE_NORMAL : FT_RENDER_MODE_MONO);
	if (fterr<>0) then
	begin
	  	fz_warn('freetype render glyph (gid %d): %s', [gid, ft_error_string(fterr)]);
		//return NULL;
    result:=nil;
    exit;
	end;

	result:= fz_copy_ft_bitmap(face^.glyph^.bitmap_left, face^.glyph^.bitmap_top, @face^.glyph^.bitmap);
end;

function fz_render_ft_stroked_glyph(font:pfz_font_s; gid:integer;trm: fz_matrix_s; ctm:fz_matrix_s; state:pfz_stroke_state_s):pfz_pixmap_s;
var
	face:FT_Face;
	expansion:single;
	 linewidth:integer; // = state->linewidth * expansion * 64 / 2;
	m:FT_Matrix ;
	v:FT_Vector ;
	fterr:FT_Error ;
  stroker:FT_Stroker;
	glyph:FT_Glyph ;
	bitmap:FT_BitmapGlyph ;
	pixmap:pfz_pixmap_s;

begin
 face := font^.ft_face;
 expansion := fz_matrix_expansion(ctm);
 linewidth := trunc(state^.linewidth * expansion * 64 / 2);
	trm := fz_adjust_ft_glyph_width(font, gid, trm);

	if (font^.ft_italic<>0) then
		trm := fz_concat(fz_shear(0.3, 0), trm);

	m.xx := trunc(trm.a * 64); //* should be 65536 */
	m.yx := trunc(trm.b * 64);
	m.xy := trunc(trm.c * 64);
	m.yy := trunc(trm.d * 64);
	v.x := trunc(trm.e * 64);
	v.y := trunc(trm.f * 64);

	fterr := FT_Set_Char_Size(face, 65536, 65536, 72, 72); //* should be 64, 64 */
		if (fterr<>0) then
	begin
	  fz_warn('FT_Set_Char_Size: %s',[ ft_error_string(fterr)]);
		result:=nil;
    exit;
	end;

	FT_Set_Transform(face, @m, @v);

	fterr := FT_Load_Glyph(face, gid, FT_LOAD_NO_BITMAP or FT_LOAD_NO_HINTING);
		if (fterr<>0) then
	begin
	  	fz_warn('FT_Load_Glyph(gid %d): %s', [gid, ft_error_string(fterr)]);
		result:=nil;
    exit;
	end;

 	fterr:= FT_Stroker_New(fz_ftlib,@stroker);
	if (fterr<>0) then
	begin
		fz_warn('FT_Stroker_New: %s', [ft_error_string(fterr)]);
		result:=nil;
    exit;
	end;

	FT_Stroker_Set(stroker, linewidth, FT_Stroker_LineCap(state^.start_cap), FT_Stroker_LineJoin( state^.linejoin), round(state^.miterlimit * 65536));

	fterr := FT_Get_Glyph(face^.glyph, @glyph);
	if (fterr<>0) then
	begin
		fz_warn('FT_Get_Glyph: %s', [ft_error_string(fterr)]);
		FT_Stroker_Done(stroker);
		//return NULL;
    result:=nil;
    exit;
	end;

	fterr := FT_Glyph_Stroke(@glyph, stroker, 1);
		if (fterr<>0) then
	begin
	 	fz_warn('FT_Glyph_Stroke: %s', [ft_error_string(fterr)]);
		FT_Done_Glyph(glyph);
		FT_Stroker_Done(stroker);
		result:=nil;
    exit;
	end;

	FT_Stroker_Done(stroker);
  if  fz_get_aa_level() > 0 then
    fterr := FT_Glyph_To_Bitmap(@glyph,  FT_RENDER_MODE_NORMAL , 0, 1)
    else
	fterr := FT_Glyph_To_Bitmap(@glyph,  FT_RENDER_MODE_MONO, 0, 1);
		if (fterr<>0) then
	begin
	 	fz_warn('FT_Glyph_To_Bitmap: %s', [ft_error_string(fterr)]);
		FT_Done_Glyph(glyph);
		result:=nil;
    exit;
	end;

	bitmap := FT_BitmapGlyph(glyph);
	pixmap := fz_copy_ft_bitmap(bitmap^.left, bitmap^.top, @bitmap^.bitmap);
	FT_Done_Glyph(glyph);

	result:= pixmap;
end;

//* * Type 3 fonts... */ *
function fz_new_type3_font(name:pchar;matrix :fz_matrix ):pfz_font_s;
var
	 font:pfz_font_s;
	i:integer;
begin
	font := fz_new_font(name);
	font^.t3procs := fz_calloc(256, sizeof(pfz_buffer_s));
	font^.t3widths := fz_calloc(256, sizeof(single));

	font^.t3matrix := matrix;
	for i := 0 to 256-1 do
	begin
		fz_obj_s_items(font^.t3procs)[i] := nil;
		single_items(font^.t3widths)[i] := 0;
	end;

	result:=font;
end;

function fz_render_t3_glyph(font:pfz_font_s; gid:integer;  trm:fz_matrix;model:pfz_colorspace_s):pfz_pixmap_s;
var
	error:integer;
	ctm:fz_matrix ;
	contents:pfz_buffer_s;
	bbox:fz_bbox ;
  dev:pfz_device_s;
	cache:pfz_glyph_cache_s;
	glyph:pfz_pixmap_S;
 //	result:pfz_pixmap_s;
begin
	if (gid < 0) or (gid > 255) then
	begin
    result:=nil;
    exit;
  end;

	contents := fz_buffer_s_items(font.t3procs)[gid];
	if (contents=nil) then
	begin
    result:=nil;
    exit;
  end;

	ctm := fz_concat(font^.t3matrix, trm);
	dev := fz_new_bbox_device(@bbox);
	error := font^.t3run(font^.t3xref, font^.t3resources, contents, dev, ctm);
	if (error<0) then
	 	fz_catch(error, 'cannot draw type3 glyph');


	if (dev^.flags  and FZ_CHARPROC_MASK)<>0 then
	begin
		if (dev^.flags and FZ_CHARPROC_COLOR)<>0 then
			fz_warn('type3 glyph claims to be both masked and colored');

		model := nil;
	end
	else if (dev^.flags and FZ_CHARPROC_COLOR)<>0 then
	begin
		if (model =nil) then
			fz_warn('colored type3 glyph wanted in masked context');
	end
	else
	begin
	 	fz_warn('type3 glyph does not specify masked or colored');
		model :=nil; //* Treat as masked */
	end;

	fz_free_device(dev);
  bbox.x0:=bbox.x0-1;

	bbox.y0:=bbox.y0-1;
	bbox.x1:=bbox.x1+1;
	bbox.y1:=bbox.y1+1;
  if model<>nil then
     glyph := fz_new_pixmap_with_rect(model, bbox)
     else
     glyph := fz_new_pixmap_with_rect(get_fz_device_gray(), bbox);

	fz_clear_pixmap(glyph);

	cache := fz_new_glyph_cache();
	dev := fz_new_draw_device_type3(cache, glyph);
	error := font^.t3run(font^.t3xref, font^.t3resources, contents, dev, ctm);
	if (error<0) then
	 	fz_catch(error, 'cannot draw type3 glyph');

	fz_free_device(dev);
	fz_free_glyph_cache(cache);

	if (model = niL) then
	begin
		result := fz_alpha_from_gray(glyph, 0);
		fz_drop_pixmap(glyph);
	end
	else
		result := glyph;


end;

procedure fz_debug_font(font:pfz_font_s);
begin
 //	printf("font '%s' {\n", font->name);

//	if (font->ft_face) then
	begin
//		printf("\tfreetype face %p\n", font->ft_face);
//		if (font->ft_substitute)
//			printf("\tsubstitute font\n");
	end;

 //	if (font->t3procs) then
	begin
	//	printf("\ttype3 matrix [%g %g %g %g]\n",
	//		font->t3matrix.a, font->t3matrix.b,
	//		font->t3matrix.c, font->t3matrix.d);
	end;

 //	printf("\tbbox [%g %g %g %g]\n",
 //		font->bbox.x0, font->bbox.y0,
 //		font->bbox.x1, font->bbox.y1);

 //	printf("}\n");
end;


function fz_new_text(font:pfz_font_s;trm: fz_matrix_s; wmode:integer) :pfz_text_s;
var
text:pfz_text_s;
begin
	text := fz_malloc(sizeof(fz_text_s));
	text^.font := fz_keep_font(font);
	text^.trm := trm;
	text^.wmode := wmode;
	text^.len := 0;
	text^.cap := 0;
	text^.items := nil;

	result:= text;
end;

procedure fz_free_text(text:pfz_text_s);
begin
	fz_drop_font(text^.font);
	fz_free(text^.items);
	fz_free(text);
end;


function fz_clone_text(old:pfz_text_s) :pfz_text_s;
var
	text:pfz_text_s;
begin
	text := fz_malloc(sizeof(fz_text_s));
	text^.font := fz_keep_font(old^.font);
	text^.trm := old^.trm;
	text^.wmode := old^.wmode;
	text^.len := old^.len;
	text^.cap := text^.len;
	text^.items := fz_calloc(text^.len, sizeof(fz_text_item_s));
	//copymemory(text^.items, old^.items, text^.len * sizeof(fz_text_item_s));
  move(old^.items^,text^.items^,  text^.len * sizeof(fz_text_item_s));

	result:= text;
end;


function fz_bound_text(text:pfz_text_s;ctm: fz_matrix):fz_rect_s;
var
	trm:fz_matrix ;
	bbox:fz_rect ;
	fbox:fz_rect ;
	i:integer;
begin
	if (text^.len = 0) then
  begin
		result:= fz_empty_rect;
    exit;
  end;
 //	/* find bbox of glyph origins in ctm space */
  bbox.x1:=fz_text_items( text^.items)[0].x;
	bbox.x0 := bbox.x1;
  bbox.y1 := fz_text_items( text^.items)[0].y;
	bbox.y0 := bbox.y1;

	for i := 1 to text^.len-1 do
	begin
		bbox.x0:= MIN(bbox.x0, fz_text_items( text^.items)[i].x);
		bbox.y0 := MIN(bbox.y0, fz_text_items( text^.items)[i].y);
		bbox.x1 := MAX(bbox.x1, fz_text_items( text^.items)[i].x);
		bbox.y1 := MAX(bbox.y1, fz_text_items( text^.items)[i].y);
	end;

	bbox := fz_transform_rect(ctm, bbox);

 //	/* find bbox of font in trm * ctm space */

	trm := fz_concat(text^.trm, ctm);
	trm.e := 0;
	trm.f := 0;

	fbox.x0 := text^.font^.bbox.x0 * 0.001;
	fbox.y0 := text^.font^.bbox.y0 * 0.001;
	fbox.x1 := text^.font^.bbox.x1 * 0.001;
	fbox.y1 := text^.font^.bbox.y1 * 0.001;

	fbox := fz_transform_rect(trm, fbox);

	//* expand glyph origin bbox by font bbox */

	bbox.x0 :=bbox.x0+ fbox.x0;
	bbox.y0 :=bbox.y0+ fbox.y0;
	bbox.x1 :=bbox.x1+ fbox.x1;
	bbox.y1 :=bbox.y1+ fbox.y1;

	result:=bbox;
end;

procedure fz_grow_text(text:pfz_text_s;n:integer);
begin
	if (text^.len + n < text^.cap)  then
  exit;
	while (text^.len + n > text^.cap) do
		text^.cap := text^.cap + 36;
	text^.items := fz_realloc(text^.items, text^.cap, sizeof(fz_text_item_s));
end;

procedure fz_add_text(text:pfz_text_s;gid:integer;ucs:integer;x:single;y:single);
begin
	fz_grow_text(text, 1);

	fz_text_items( text^.items)[text^.len].ucs := ucs;
	fz_text_items( text^.items)[text^.len].gid := gid;
	fz_text_items( text^.items)[text^.len].x := x;
	fz_text_items( text^.items)[text^.len].y := y;
	text^.len:=text^.len+1;
end;

function isxmlmeta(c:integer):integer;

begin
  if ((c < 32) or (c >= 128) or (chr(c) = '&') or (chr(c) = '<') or  (chr(c) = '>') or (chr(c) = '''') or (chr(c) = '"')) then
  result:=1
  else
  result:=0;
end;

{
procedure fz_debug_text(text:pfz_text_s;indent:integer);
var
	int i, n;
begin
	for i := 0 to text->len-1 do
	begin
		for n := 0 to indent-1 do
			putchar(' ');
		if (not isxmlmeta(text->items[i].ucs))  then
			printf("<g ucs=\"%c\" gid=\"%d\" x=\"%g\" y=\"%g\" />\n",
				text->items[i].ucs, text->items[i].gid, text->items[i].x, text->items[i].y);
		else
			printf("<g ucs=\"U+%04X\" gid=\"%d\" x=\"%g\" y=\"%g\" />\n",
				text->items[i].ucs, text->items[i].gid, text->items[i].x, text->items[i].y);
	end;
end;
 }

end.
