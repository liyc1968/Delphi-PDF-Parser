unit pdf_xobjectxxx;

interface
uses  SysUtils,digcommtype,digtypes,base_object_functions,fz_pdf_store,base_error;

 procedure pdf_drop_xobject(xobj:ppdf_xobject_s);
function pdf_load_xobject(formp:pppdf_xobject_s;xref:ppdf_xref_s; dict:pfz_obj_s):integer;
 function pdf_keep_xobject(xobj:ppdf_xobject_s):ppdf_xobject_s;
implementation
uses mypdfstream,pdf_color_spcasess;



function pdf_load_xobject(formp:pppdf_xobject_s;xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	form:ppdf_xobject_s;
	obj:pfz_obj_s;
  attrs:pfz_obj_s;
begin

 formp^ := pdf_find_item(xref.store, @pdf_drop_xobject, dict);
 if formp^<>nil then
	begin
		pdf_keep_xobject(formp^);
		result:= 1;
    exit;
	end;

	form := fz_malloc(sizeof(pdf_xobject_s));
	form^.refs := 1;
	form^.resources := nil;
	form^.contents := nil;
//	form^.colorspace := nil;

	//* Store item immediately, to avoid possible recursion if objects refer back to this one */
	pdf_store_item(xref.store, @pdf_keep_xobject, @pdf_drop_xobject, dict, form);

	obj := fz_dict_gets(dict, 'BBox');
	form^.bbox := pdf_to_rect(obj);

	obj := fz_dict_gets(dict, 'Matrix');
	if (obj<>nil) then
		form^.matrix := pdf_to_matrix(obj)
	else
		form^.matrix := fz_identity;

	form^.isolated := 0;
	form^.knockout := 0;
	form^.transparency := 0;

	obj := fz_dict_gets(dict, 'Group');
	if (obj<>nil) then
	begin
		attrs := obj;

		form^.isolated := fz_to_bool(fz_dict_gets(attrs, 'I'));
		form^.knockout := fz_to_bool(fz_dict_gets(attrs, 'K'));

		obj := fz_dict_gets(attrs, 'S');
		if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'Transparency')<>0)) then
			form^.transparency := 1;

		obj := fz_dict_gets(attrs, 'CS');
		if (obj<>nil) then
		begin
			error := pdf_load_colorspace(@form^.colorspace, xref, obj);
			if (error<0) then
			 	fz_catch(error, 'cannot load xobject colorspace');

		end;
	end;

	form^.resources := fz_dict_gets(dict, 'Resources');
	if (form^.resources<>nil) then
		fz_keep_obj(form^.resources);

	error := pdf_load_stream(@form^.contents, xref, fz_to_num(dict), fz_to_gen(dict));
	if (error<0)  then
	begin
		pdf_remove_item(xref.store, @pdf_drop_xobject, dict);
		pdf_drop_xobject(form);
		result:= fz_rethrow(error, 'cannot load xobject content stream (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
    exit;
	end;

	formp^ := form;
	result:=1; // fz_okay;
  exit;
end;

function pdf_keep_xobject(xobj:ppdf_xobject_s):ppdf_xobject_s;
begin
	xobj^.refs:=xobj^.refs+1;
	result:=xobj;
end;

procedure pdf_drop_xobject(xobj:ppdf_xobject_s);
begin
  if (xobj=nil) then
  exit;
  xobj^.refs:=xobj^.refs-1;
	if (xobj<>nil) and (xobj^.refs= 0) then
	begin
	 //	if (xobj^.colorspace<>nil)
	//		fz_drop_colorspace(xobj->colorspace);
		if (xobj^.resources<>nil) then
			fz_drop_obj(xobj^.resources);
		if (xobj^.contents<>nil)then
			fz_drop_buffer(xobj^.contents);
		fz_free(xobj);
	end;
end;


end.
