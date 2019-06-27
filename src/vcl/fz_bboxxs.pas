unit fz_bboxxs;

interface
uses   SysUtils,digtypes,fz_textx;

 function fz_new_bbox_device(result1:pfz_bbox) :pfz_device_s;

implementation
uses base_object_functions,fz_pathh,res_shades,fz_dev_null;

procedure fz_bbox_fill_path(user:pointer; path:pfz_path_s; even_odd:integer; ctm:fz_matrix;colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
 result1: pfz_bbox_s;
 bbox:fz_bbox;
begin
	result1 := user;
	 bbox := fz_round_rect(fz_bound_path(path, nil, ctm));
	result1^ := fz_union_bbox(result1^, bbox);
end;

procedure fz_bbox_stroke_path(user:pointer; path:pfz_path_s; stroke:pfz_stroke_state_s; ctm:fz_matrix;colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	 result1:pfz_bbox;
   bbox:	fz_bbox;
begin
  result1:= user;
  bbox := fz_round_rect(fz_bound_path(path, stroke, ctm));
	result1^:= fz_union_bbox(result1^, bbox);
end;

procedure fz_bbox_fill_text(user:pointer; text:pfz_text_s; ctm:fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
 result1:pfz_bbox;
 bbox :fz_bbox;
begin
  result1 := user;
	 bbox := fz_round_rect(fz_bound_text(text, ctm));
	result1^:= fz_union_bbox(result1^, bbox);
end;

procedure fz_bbox_stroke_text(user:pointer; text:pfz_text_s;stroke:pfz_stroke_state_s;ctm: fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single) ;
var
 result1:pfz_bbox;
 bbox :fz_bbox;
begin
	result1 := user;
	bbox := fz_round_rect(fz_bound_text(text, ctm));
	result1^ := fz_union_bbox(result1^, bbox);
end;

procedure fz_bbox_fill_shade(user:pointer;shade:pfz_shade_s;ctm:fz_matrix; alpha:single);
var
 result1:pfz_bbox;
 bbox :fz_bbox;
begin
	result1 := user;
	bbox := fz_round_rect(fz_bound_shade(shade, ctm));
	result1^:= fz_union_bbox(result1^, bbox);
end;

procedure
fz_bbox_fill_image(user:pointer;image :pfz_pixmap_s;ctm: fz_matrix; alpha:single);
var
 result1:pfz_bbox;
 bbox :fz_bbox;
begin
	result1:= user;
	bbox := fz_round_rect(fz_transform_rect(ctm, fz_unit_rect));
	result1^ := fz_union_bbox(result1^, bbox);
end;

procedure
fz_bbox_fill_image_mask(user:pointer;image :pfz_pixmap_s;ctm: fz_matrix ;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
begin
	fz_bbox_fill_image(user, image, ctm, alpha);
end;

function fz_new_bbox_device(result1:pfz_bbox) :pfz_device_s;
var
	dev:pfz_device_s;
begin
	dev := fz_new_device(result1);

	dev^.fill_path := fz_bbox_fill_path;
	dev^.stroke_path := fz_bbox_stroke_path;
	dev^.fill_text := fz_bbox_fill_text;
	dev^.stroke_text := fz_bbox_stroke_text;
	dev^.fill_shade := fz_bbox_fill_shade;
	dev^.fill_image := fz_bbox_fill_image;
	dev^.fill_image_mask := fz_bbox_fill_image_mask;

	result1^ := fz_empty_bbox;

	result:=dev;
end;

end.
