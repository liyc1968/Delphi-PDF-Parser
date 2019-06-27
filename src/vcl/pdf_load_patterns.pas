unit pdf_load_patterns;

interface
uses
 SysUtils,Math,digtypes,base_error;

procedure pdf_drop_pattern(pat:ppdf_pattern_s);
function pdf_keep_pattern(pat:ppdf_pattern_s) :ppdf_pattern_s;
function pdf_load_pattern(patp:pppdf_pattern_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
implementation
uses base_object_functions,fz_pdf_store,mypdfstream,res_shades;

function pdf_load_pattern(patp:pppdf_pattern_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	pat:ppdf_pattern_s;
	obj:pfz_obj_s;
begin
	patp^ := pdf_find_item(xref^.store, @pdf_drop_pattern, dict);
  if (patp^<>nil) then
	begin
		pdf_keep_pattern(patp^);
		//return fz_okay;
    result:=1;
    exit;
	end;

	pat := fz_malloc(sizeof(pdf_pattern_s));
	pat^.refs := 1;
	pat^.resources := nil;
	pat^.contents := nil;

	//* Store pattern now, to avoid possible recursion if objects refer back to this one */
	pdf_store_item(xref^.store, @pdf_keep_pattern, @pdf_drop_pattern, dict, pat);
  if fz_to_int(fz_dict_gets(dict, 'PaintType')) = 2 then
	pat^.ismask :=1
  else
   pat^.ismask :=0;
	pat^.xstep := fz_to_real(fz_dict_gets(dict, 'XStep'));
	pat^.ystep := fz_to_real(fz_dict_gets(dict, 'YStep'));

	obj := fz_dict_gets(dict, 'BBox');
	pat^.bbox := pdf_to_rect(obj);

	obj := fz_dict_gets(dict, 'Matrix');
	if (obj<>nil) then
		pat^.matrix := pdf_to_matrix(obj)
	else
		pat^.matrix := fz_identity;

	pat^.resources := fz_dict_gets(dict, 'Resources');
	if (pat^.resources<>nil) then
		fz_keep_obj(pat^.resources);

	error := pdf_load_stream(@pat^.contents, xref, fz_to_num(dict), fz_to_gen(dict));
	if (error<0) then
	begin
		pdf_remove_item(xref^.store, @pdf_drop_pattern, dict);
		pdf_drop_pattern(pat);
		result:=fz_rethrow(error, 'cannot load pattern stream (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);

    exit;
	end;

	patp^ := pat;
	result:=1; // fz_okay;
  exit;
end;

function pdf_keep_pattern(pat:ppdf_pattern_s) :ppdf_pattern_s;
begin
	pat^.refs:=pat^.refs+1;
	result:= pat;
end;

procedure pdf_drop_pattern(pat:ppdf_pattern_s);
begin
  if pat=nil then
  exit;
  pat^.refs:=pat^.refs-1;
	if (pat^.refs = 0) then
	begin
		if (pat^.resources<>nil) then
			fz_drop_obj(pat^.resources);
		if (pat^.contents<>nil) then
			fz_drop_buffer(pat^.contents);
		fz_free(pat);
	end;
end;



end.
