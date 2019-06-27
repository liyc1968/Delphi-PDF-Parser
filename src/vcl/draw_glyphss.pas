unit draw_glyphss;

interface
uses
SysUtils, Math,digtypes;

function fz_new_glyph_cache():pfz_glyph_cache_s;
function fz_render_glyph(cache:pfz_glyph_cache_s;font:pfz_font_s; gid:integer;ctm: fz_matrix;model:pfz_colorspace_s):pfz_pixmap_s;
function fz_render_stroked_glyph(cache:pfz_glyph_cache_s; font:pfz_font_s; gid:integer;trm: fz_matrix;ctm: fz_matrix;stroke:pfz_stroke_state_s):pfz_pixmap_s;
procedure fz_free_glyph_cache(cache:pfz_glyph_cache_s);
implementation
uses base_object_functions,fz_textx,fz_pixmapss;

function fz_new_glyph_cache():pfz_glyph_cache_s;
var
	cache:pfz_glyph_cache_s;
begin
	cache := fz_malloc(sizeof(fz_glyph_cache_s));
	cache^.hash := fz_new_hash_table(509, sizeof(fz_glyph_key_s));
	cache^.total := 0;

	result:= cache;
end;

procedure fz_evict_glyph_cache(cache:pfz_glyph_cache_s);
var
	key:pfz_glyph_key_s;
	pixmap:pfz_pixmap_s;
	i:integer;
begin
	for i := 0 to fz_hash_len(cache^.hash)-1 do
	begin
		key := fz_hash_get_key(cache^.hash, i);
		if (key^.font<>nil) then
			fz_drop_font(key^.font);
		pixmap := fz_hash_get_val(cache^.hash, i);
		if (pixmap<>nil) then
			fz_drop_pixmap(pixmap);
	end;

	cache^.total := 0;

	fz_empty_hash(cache^.hash);
end;

procedure fz_free_glyph_cache(cache:pfz_glyph_cache_s);
begin
	fz_evict_glyph_cache(cache);
	fz_free_hash(cache^.hash);
	fz_free(cache);
end;

function fz_render_stroked_glyph(cache:pfz_glyph_cache_s; font:pfz_font_s; gid:integer;trm: fz_matrix;ctm: fz_matrix;stroke:pfz_stroke_state_s):pfz_pixmap_s;
begin
	if (font^.ft_face<>nil) then
  begin
		result:=fz_render_ft_stroked_glyph(font, gid, trm, ctm, stroke);
    exit;
  end;
	result:=fz_render_glyph(cache, font, gid, trm, nil);
end;

function fz_render_glyph(cache:pfz_glyph_cache_s;font:pfz_font_s; gid:integer;ctm: fz_matrix;model:pfz_colorspace_s):pfz_pixmap_s;
var
	key:fz_glyph_key_s ;
	val:pfz_pixmap_s;
  size:single;
begin
  size := fz_matrix_expansion(ctm);
	if (size > MAX_FONT_SIZE)  then
	begin
		//* TODO: this case should be handled by rendering glyph as a path fill */
	 //	fz_warn("font size too large (%g), not rendering glyph", size);
		result:= nil;
    exit;
	end;

	fillchar(key, sizeof(key), 0);
	key.font := font;
	key.gid := gid;
	key.a := trunc(ctm.a * 65536);
	key.b := trunc(ctm.b * 65536);
	key.c := trunc(ctm.c * 65536);
	key.d := trunc(ctm.d * 65536);
	key.e := trunc((ctm.e - floor(ctm.e)) * 256);
	key.f := trunc((ctm.f - floor(ctm.f)) * 256);

	val := fz_hash_find(cache^.hash, @key);
	if (val<>nil) then
  begin
		result:= fz_keep_pixmap(val);
    exit;
  end;

	ctm.e :=floor( ctm.e) + key.e / 256.0;
	ctm.f :=floor( ctm.f) + key.f / 256.0;

	if (font^.ft_face<>nil) then
	begin
		val := fz_render_ft_glyph(font, gid, ctm);
	end
	else if (@font^.t3procs<>nil) then
	begin
		val := fz_render_t3_glyph(font, gid, ctm, model);
	end
	else
	begin
		//fz_warn("assert: uninitialized font structure");
		result:=nil;
    exit;
	end;

	if (val<>nil) then
	begin
		if (val^.w < MAX_GLYPH_SIZE) and ( val^.h < MAX_GLYPH_SIZE)  then
		begin
			if (cache^.total + val^.w * val^.h > MAX_CACHE_SIZE) then
				fz_evict_glyph_cache(cache);
			fz_keep_font(key.font);
			fz_hash_insert(cache^.hash, @key, val);
			cache^.total :=cache^.total+ val^.w * val^.h;
			result:= fz_keep_pixmap(val);
      exit;
		end;
		result:= val;
    exit;
	end;

	result:=nil;
end;



end.
