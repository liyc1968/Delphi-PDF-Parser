unit dev_textss;
interface
uses  SysUtils,Math,digtypes,FreeType ,base_error;


procedure
fz_free_text_span(span:pfz_text_span_s);

function fz_new_text_span():pfz_text_span_s;
function fz_new_text_device(root:pfz_text_span_s):pfz_device_s;  
implementation
uses base_object_functions,fz_textx,fz_dev_null;

const
LINE_DIST= 0.9;
SPACE_DIST= 0.2;

function fz_new_text_span():pfz_text_span_s;
var
	span:pfz_text_span_s;
begin
	span := fz_malloc(sizeof(fz_text_span_s));
	span^.font := nil;
	span^.wmode := 0;
	span^.size := 0;
	span^.len := 0;
	span^.cap := 0;
	span^.text := nil;
	span^.next := nil;
	span^.eol := 0;
	result:=span;
end;

procedure
fz_free_text_span(span:pfz_text_span_s);
begin
 //  OutputDebugString(pchar('fontoo1.refs'+inttostr(span^.font.refs)));
	if (span^.font<>nil) then
		fz_drop_font(span^.font);
	if (span^.next<>nil) then
		fz_free_text_span(span^.next);
	fz_free(span^.text);
	fz_free(span);
end;

procedure fz_add_text_char_imp(span: pfz_text_span_s;  c:integer; bbox:fz_bbox);

begin

	if (span^.len + 1 >= span^.cap) then
	begin
     if span^.cap > 1 then
        span^.cap := (span^.cap * 3) div 2
        else
        span^.cap :=80;

		span^.text := fz_realloc(span^.text, span^.cap, sizeof(fz_text_char_s));
	end;
	fz_text_char_s_items(span^.text)[span^.len].c := c;
	fz_text_char_s_items(span^.text)[span^.len].bbox := bbox;
	span^.len:=span^.len+1;
end;

function
fz_split_bbox(bbox:fz_bbox;  i, n:integer) :fz_bbox;
var
w,x0:single;
begin
	w := (bbox.x1 - bbox.x0) / n;
	x0 := bbox.x0;
	bbox.x0 := trunc(x0 + i * w);
	bbox.x1 := trunc(x0 + (i + 1) * w);
	result:= bbox;
end;

procedure fz_add_text_char(last:ppfz_text_span_s; font:pfz_font_s; size:single; wmode, c:integer; bbox:fz_bbox);
var
	span: pfz_text_span_s;
begin
  span:= last^;
	if (span^.font=nil) then
	begin
		span^.font := fz_keep_font(font);
		span^.size := size;
	end;

	if ((span^.font <> font) or (span^.size <> size) or (span^.wmode <> wmode)) and (c <> 32) then
	begin
		span := fz_new_text_span();
		span^.font := fz_keep_font(font);
		span^.size := size;
		span^.wmode := wmode;
		(last^)^.next := span;
		last^ := span;
	end;

	case (c) of
	-1: dddd; ///* ignore when one unicode character maps to multiple glyphs */
	$FB00: //* ff */
    begin
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 0, 2));
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 1, 2));
		end;
	$FB01: //* fi */
    begin
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 0, 2));
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 1, 2));
		end;
  $FB02: //* fl */
    begin
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 0, 2));
		fz_add_text_char_imp(span, ord('l'), fz_split_bbox(bbox, 1, 2));
		end;
	$FB03: //* ffi */
    begin
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 0, 3));
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 1, 3));
		fz_add_text_char_imp(span, ord('i'), fz_split_bbox(bbox, 2, 3));
		end;
	$FB04: //* ffl */
    begin
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 0, 3));
		fz_add_text_char_imp(span, ord('f'), fz_split_bbox(bbox, 1, 3));
		fz_add_text_char_imp(span, ord('l'), fz_split_bbox(bbox, 2, 3));
		end;
	$FB05: //* long st */
   begin
		fz_add_text_char_imp(span, ord('s'), fz_split_bbox(bbox, 0, 2));
		fz_add_text_char_imp(span, ord('t'), fz_split_bbox(bbox, 1, 2));
    end;
	$FB06: //* st */
    begin
		fz_add_text_char_imp(span, ord('s'), fz_split_bbox(bbox, 0, 2));
		fz_add_text_char_imp(span, ord('t'), fz_split_bbox(bbox, 1, 2));
    end;
	else
		fz_add_text_char_imp(span, c, bbox);

	end;
end;

procedure fz_divide_text_chars(last:ppfz_text_span_s; n:integer; bbox:fz_bbox);
var
	span: pfz_text_span_s;
	i, x:integer;
begin
  span:= last^;
	x := span^.len - n;
	if (x >= 0)  then
  begin
		for i := 0 to n-1 do
			fz_text_char_s_items(span^.text)[x + i].bbox := fz_split_bbox(bbox, i, n);
  end;
end;

procedure fz_add_text_newline(last:ppfz_text_span_s; font:pfz_font_s; size:single; wmode:integer);
var
	span: pfz_text_span_s;
begin
	span := fz_new_text_span();
	span^.font := fz_keep_font(font);
	span^.size := size;
	span^.wmode := wmode;

	(last^)^.eol := 1;
	(last^)^.next := span;
	last^ := span;
end;



procedure fz_text_extract_span(last:ppfz_text_span_s; text:pfz_text_s; ctm:fz_matrix; pen:pfz_point_s);
var
	font:pfz_font_s;
	face:FT_Face;
	 tm:fz_matrix;
	 trm:fz_matrix;
	 size:single;
	 adv:single;
	 rect:fz_rect;
	 dir, ndir:fz_point_s;
	 delta, ndelta:fz_point_s;
	 dist, dot:single;
	 ascender:single;
	 descender:single;
	 multi:integer;
	 i,c, err:integer;
   spacerect:fz_rect;
   mask:integer;
   ftadv:FT_Fixed;
begin
  font := text^.font;
  face := font^.ft_face;
  tm := text^.trm;
  ascender := 1;
  descender := 0;
	if (text^.len = 0) then
		exit;

	if (font^.ft_face<>nil) then
	begin
		err := FT_Set_Char_Size(font^.ft_face, 64, 64, 72, 72);
		if (err<>0) then
			fz_warn('freetype set character size: %s', [ft_error_string(err)]);
		ascender := face^.ascender / face^.units_per_EM;
		descender := face^.descender / face^.units_per_EM;
	end;

	rect := fz_empty_rect;

	if (text^.wmode = 0) then
	begin
		dir.x := 1;
		dir.y := 0;
	end
	else
	begin
		dir.x := 0;
		dir.y := 1;
	end;

	tm.e := 0;
	tm.f := 0;
	trm := fz_concat(tm, ctm);
	dir := fz_transform_vector(trm, dir);
	dist := sqrt(dir.x * dir.x + dir.y * dir.y);
	ndir.x := dir.x / dist;
	ndir.y := dir.y / dist;

	size := fz_matrix_expansion(trm);

	multi := 1;

	for i := 0 to text^.len-1 do
	begin
		if (fz_text_items(text^.items)[i].gid < 0)  then
		begin
			fz_add_text_char(last, font, size, text^.wmode, fz_text_items(text^.items)[i].ucs, fz_round_rect(rect));
			multi:=multi+1;
			fz_divide_text_chars(last, multi, fz_round_rect(rect));
			continue;
		end;
		multi := 1;

		//* Calculate new pen location and delta */
		tm.e := fz_text_items(text^.items)[i].x;
		tm.f := fz_text_items(text^.items)[i].y;
		trm := fz_concat(tm, ctm);

		delta.x := pen^.x - trm.e;
		delta.y := pen^.y - trm.f;
		if (pen^.x = -1) and (pen^.y = -1) then
    begin
      delta.y := 0;
			delta.x := delta.y ;
    end;

		dist := sqrt(delta.x * delta.x + delta.y * delta.y);

		//* Add space and newlines based on pen movement */
		if (dist > 0)  then
		begin
			ndelta.x := delta.x / dist;
			ndelta.y := delta.y / dist;
			dot := ndelta.x * ndir.x + ndelta.y * ndir.y;

			if (dist > size * LINE_DIST)  then
			begin
				fz_add_text_newline(last, font, size, text^.wmode);
			end
			else if (abs(dot) > 0.95) and  (dist > size * SPACE_DIST) then
			begin
        c:= fz_text_char_s_items((last^)^.text)[(last^)^.len - 1].c;
				if (((last^)^.len > 0) and   ( c<> ord(' ')) )   then
				begin

					spacerect.x0 := -0.2;
					spacerect.y0 := 0;
					spacerect.x1 := 0;
					spacerect.y1 := 1;
					spacerect := fz_transform_rect(trm, spacerect);
					fz_add_text_char(last, font, size, text^.wmode, ord(' '), fz_round_rect(spacerect));
				end;
			end;
		end;

		//* Calculate bounding box and new pen position based on font metrics */
		if (font^.ft_face<>nil) then
		begin
			ftadv := 0;
			mask := FT_LOAD_NO_BITMAP or FT_LOAD_NO_HINTING or FT_LOAD_IGNORE_TRANSFORM;

			//* TODO: freetype returns broken vertical metrics */
			//* if (text^.wmode) mask |= FT_LOAD_VERTICAL_LAYOUT; */

			FT_Get_Advance(font^.ft_face, fz_text_items(text^.items)[i].gid, mask, @ftadv);
			adv := ftadv / 65536.0;

			rect.x0 := 0;
			rect.y0 := descender;
			rect.x1 := adv;
			rect.y1 := ascender;
		end
		else
		begin
			adv := single_items(font^.t3widths)[fz_text_items(text^.items)[i].gid];
			rect.x0 := 0;
			rect.y0 := descender;
			rect.x1 := adv;
			rect.y1 := ascender;
		end;

		rect := fz_transform_rect(trm, rect);
		pen^.x := trm.e + dir.x * adv;
		pen^.y := trm.f + dir.y * adv;

		fz_add_text_char(last, font, size, text^.wmode, fz_text_items(text^.items)[i].ucs, fz_round_rect(rect));
	end;
end;

procedure fz_text_fill_text(user:pointer; text:pfz_text_s; ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;
	fz_text_extract_span(@tdev^.span, text, ctm, @tdev^.point);
 // OutputDebugString(pchar('lennn:'+inttostr(tdev^.span^.len))) ;
end;

procedure fz_text_stroke_text( user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s;  ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;
	fz_text_extract_span(@tdev^.span, text, ctm, @tdev^.point);
end;

procedure
fz_text_clip_text(user:pointer; text:pfz_text_s; ctm:fz_matrix;  accumulate:integer);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;
	fz_text_extract_span(@tdev^.span, text, ctm, @tdev^.point);
end;

procedure
fz_text_clip_stroke_text(user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s; ctm:fz_matrix);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;
	fz_text_extract_span(@tdev^.span, text, ctm, @tdev^.point);
end;

procedure
fz_text_ignore_text(user:pointer; text:pfz_text_s; ctm:fz_matrix);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;
	fz_text_extract_span(@tdev^.span, text, ctm, @tdev^.point);
end;

procedure
fz_text_free_user(user:pointer);
var
  tdev:pfz_text_device_s;
begin
	tdev := user;

	tdev^.span^.eol := 1;

	//* TODO: unicode NFC normalization */
	//* TODO: bidi logical reordering */

	fz_free(tdev);
end;


function fz_new_text_device(root:pfz_text_span_s):pfz_device_s;
var
	dev:pfz_device_s;
	tdev:pfz_text_device_s;
begin
  tdev := fz_malloc(sizeof(fz_text_device_s));
	tdev^.head := root;
	tdev^.span := root;
	tdev^.point.x := -1;
	tdev^.point.y := -1;

	dev := fz_new_device(tdev);
	dev^.hints := FZ_IGNORE_IMAGE or FZ_IGNORE_SHADE;
	dev^.free_user := fz_text_free_user;
	dev^.fill_text := fz_text_fill_text;
	dev^.stroke_text := fz_text_stroke_text;
	dev^.clip_text := fz_text_clip_text;
	dev^.clip_stroke_text := fz_text_clip_stroke_text;
	dev^.ignore_text := fz_text_ignore_text;
	result:= dev;
end;


end.
