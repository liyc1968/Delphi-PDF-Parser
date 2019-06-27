unit fz_dev_null;

interface
 uses  SysUtils,Math,digtypes,base_error;

procedure fz_fill_shade(dev:pfz_device_s; shade:pfz_shade_s; ctm:fz_matrix;  alpha:single);
procedure fz_pop_clip(dev:pfz_device_s) ;
procedure fz_end_group(dev:pfz_device_s) ;
function fz_new_device(user:pointer):pfz_device_s;
procedure fz_free_device(dev:pfz_device_s) ;
procedure fz_begin_mask(dev:pfz_device_s; area:fz_rect; luminosity:integer; colorspace:pfz_colorspace_s; bc:psingle);
procedure  fz_end_mask(dev:pfz_device_s);
procedure fz_begin_group(dev:pfz_device_s; area:fz_rect;  isolated:integer; knockout:integer; blendmode:integer; alpha:single);
procedure fz_clip_image_mask(dev:pfz_device_s; image:pfz_pixmap_s; rect:pfz_rect_s;ctm: fz_matrix );
procedure fz_fill_image_mask(dev:pfz_device_s; image:pfz_pixmap_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
procedure fz_fill_image(dev:pfz_device_s; image:pfz_pixmap_s; ctm:fz_matrix ; alpha:single);
procedure fz_clip_path(dev:pfz_device_s; path:pfz_path_s;rect: pfz_rect_s;  even_odd:integer;ctm :fz_matrix );
procedure fz_fill_path(dev:pfz_device_s; path:pfz_path_s; even_odd:integer;ctm: fz_matrix;
	colorspace:pfz_colorspace_s;color:psingle; alpha:single);
procedure 
fz_stroke_path(dev:pfz_device_s; path:pfz_path_s;stroke: pfz_stroke_state_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
procedure
fz_clip_stroke_path(dev:pfz_device_s; path:pfz_path_s; rect: pfz_rect_s; stroke:pfz_stroke_state_s;ctm: fz_matrix );
procedure
fz_ignore_text(dev:pfz_device_s; text:pfz_text_s;ctm: fz_matrix );
procedure
fz_clip_text(dev:pfz_device_s; text:pfz_text_s;ctm: fz_matrix;  accumulate:integer);
procedure fz_fill_text(dev:pfz_device_s; text:pfz_text_s;ctm:fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
procedure
fz_stroke_text(dev:pfz_device_s; text:pfz_text_s; stroke:pfz_stroke_state_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
procedure
fz_clip_stroke_text(dev:pfz_device_s; text:pfz_text_s;stroke:pfz_stroke_state_s; ctm: fz_matrix);
procedure fz_begin_tile(dev:pfz_device_s;area: fz_rect ;view :fz_rect ; xstep:single;  ystep:single;ctm: fz_matrix );
procedure
fz_end_tile(dev:pfz_device_s);
implementation
  uses base_object_functions;

function fz_new_device(user:pointer):pfz_device_s;
var
dev:pfz_device_s;
begin
	dev := fz_malloc(sizeof(fz_device_s));
	fillchar(dev^, sizeof(fz_device_s), 0);
	dev^.hints := 0;
	dev^.flags := 0;
	dev^.user := user;
	result:=dev;
end;

procedure fz_free_device(dev:pfz_device_s) ;
begin
	if (@dev^.free_user<>nil)then
		dev^.free_user(dev^.user);
	fz_free(dev);
end;

procedure fz_fill_path(dev:pfz_device_s; path:pfz_path_s; even_odd:integer;ctm: fz_matrix;
	colorspace:pfz_colorspace_s;color:psingle; alpha:single);
begin
	if (@dev^.fill_path<>nil) then
		dev^.fill_path(dev^.user, path, even_odd, ctm, colorspace, color, alpha);
end;

procedure 
fz_stroke_path(dev:pfz_device_s; path:pfz_path_s;stroke: pfz_stroke_state_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
begin
	if (@dev^.stroke_path<>nil) then
		dev^.stroke_path(dev^.user, path, stroke, ctm, colorspace, color, alpha);
end;

procedure fz_clip_path(dev:pfz_device_s; path:pfz_path_s;rect: pfz_rect_s;  even_odd:integer;ctm :fz_matrix );
begin
	if (@dev^.clip_path<>nil) then
		dev^.clip_path(dev^.user, path, rect, even_odd, ctm);
end;

procedure
fz_clip_stroke_path(dev:pfz_device_s; path:pfz_path_s; rect: pfz_rect_s; stroke:pfz_stroke_state_s;ctm: fz_matrix );
begin
	if (@dev^.clip_stroke_path<>nil) then
		dev^.clip_stroke_path(dev^.user, path, rect, stroke, ctm);
end;

procedure fz_fill_text(dev:pfz_device_s; text:pfz_text_s;ctm:fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
begin
	if (@dev^.fill_text<>nil) then
		dev^.fill_text(dev^.user, text, ctm, colorspace, color, alpha);
   // OutputDebugString(pchar('lennpn:'+inttostr(pfz_text_device_s(dev^.user)^.span^.len))) ;
end;

procedure
fz_stroke_text(dev:pfz_device_s; text:pfz_text_s; stroke:pfz_stroke_state_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
begin
	if (@dev^.stroke_text<>nil) then
		dev^.stroke_text(dev^.user, text, stroke, ctm, colorspace, color, alpha);
end;

procedure
fz_clip_text(dev:pfz_device_s; text:pfz_text_s;ctm: fz_matrix;  accumulate:integer);
begin
	if (@dev^.clip_text<>nil) then
		dev^.clip_text(dev^.user, text, ctm, accumulate);
end;

procedure
fz_clip_stroke_text(dev:pfz_device_s; text:pfz_text_s;stroke:pfz_stroke_state_s; ctm: fz_matrix);
begin
	if (@dev^.clip_stroke_text<>nil) then
		dev^.clip_stroke_text(dev^.user, text, stroke, ctm);
end;

procedure
fz_ignore_text(dev:pfz_device_s; text:pfz_text_s;ctm: fz_matrix );
begin
	if (@dev^.ignore_text<>nil) then
		dev^.ignore_text(dev^.user, text, ctm);
end;

procedure fz_pop_clip(dev:pfz_device_s) ;
begin
	if (@dev^.pop_clip<>nil) then
		dev^.pop_clip(dev^.user);
end;

procedure fz_fill_shade(dev:pfz_device_s; shade:pfz_shade_s; ctm:fz_matrix;  alpha:single);
begin
	if (@dev^.fill_shade<>nil) then
		dev^.fill_shade(dev^.user, shade, ctm, alpha);
end;

procedure fz_fill_image(dev:pfz_device_s; image:pfz_pixmap_s; ctm:fz_matrix ; alpha:single);
begin
	if (@dev^.fill_image<>nil) then
		dev^.fill_image(dev^.user, image, ctm, alpha);
end;

procedure fz_fill_image_mask(dev:pfz_device_s; image:pfz_pixmap_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
begin
	if (@dev^.fill_image_mask<>nil) then
		dev^.fill_image_mask(dev^.user, image, ctm, colorspace, color, alpha);
end;

procedure fz_clip_image_mask(dev:pfz_device_s; image:pfz_pixmap_s; rect:pfz_rect_s;ctm: fz_matrix );
begin

	if (@dev^.clip_image_mask<>nil) then
		dev^.clip_image_mask(dev^.user, image, rect, ctm);
end;

procedure
fz_begin_mask(dev:pfz_device_s; area:fz_rect; luminosity:integer; colorspace:pfz_colorspace_s; bc:psingle);
begin
	if (@dev^.begin_mask<>nil) then
		dev^.begin_mask(dev^.user, area, luminosity, colorspace, bc);
end;

procedure  fz_end_mask(dev:pfz_device_s);
begin
	if (@dev^.end_mask<>nil)  then
		dev^.end_mask(dev^.user);
end;

procedure fz_begin_group(dev:pfz_device_s; area:fz_rect;  isolated:integer; knockout:integer; blendmode:integer; alpha:single);
begin
	if (@dev^.begin_group<>nil) then
		dev^.begin_group(dev^.user, area, isolated, knockout, blendmode, alpha);
end;

procedure fz_end_group(dev:pfz_device_s) ;
begin
	if (@dev^.end_group<>nil) then
		dev^.end_group(dev^.user);
end;

procedure fz_begin_tile(dev:pfz_device_s;area: fz_rect ;view :fz_rect ; xstep:single;  ystep:single;ctm: fz_matrix );
begin
	if (@dev^.begin_tile<> nil) then
		dev^.begin_tile(dev^.user, area, view, xstep, ystep, ctm);
end;

procedure
fz_end_tile(dev:pfz_device_s);
begin
	if (@dev^.end_tile<>nil) then
		dev^.end_tile(dev^.user);
end;


end.
