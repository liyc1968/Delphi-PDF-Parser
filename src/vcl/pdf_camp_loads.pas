unit pdf_camp_loads;

interface
uses 
SysUtils,Math,mylimits,digtypes,digcommtype,pdf_camp_tabless,base_error;

  function pdf_load_system_cmap(cmapp:pppdf_cmap_s; cmap_name:pchar):integer;
  function pdf_new_identity_cmap(wmode, bytes:integer):ppdf_cmap_s;
 function pdf_load_embedded_cmap(cmapp:pppdf_cmap_s; xref:ppdf_xref_s; stmobj:pfz_obj_s):integer;
implementation
uses base_object_functions,fz_pdf_store,pdf_cmapss,mypdfstream,pdf_camp_parses,FZ_mystreams;

function
pdf_load_embedded_cmap(cmapp:pppdf_cmap_s; xref:ppdf_xref_s; stmobj:pfz_obj_s):integer;
var
	error :integer;
	file1:pfz_stream_s;
	cmap:ppdf_cmap_s;
	usecmap:ppdf_cmap_s;
	wmode:pfz_obj_s;
	obj:pfz_obj_s;
  label  cleanup;
begin
  file1:=nil;
  cmap:=nil;

  error := 1;
  cmapp^ := pdf_find_item(xref^.store, @pdf_drop_cmap, stmobj);
  if cmapp^<>nil then
	begin
		pdf_keep_cmap(cmapp^);
		result:=1;
    exit;
	end;

	error := pdf_open_stream(@file1, xref, fz_to_num(stmobj), fz_to_gen(stmobj));
	if (error<0)  then
	begin
	  error := fz_rethrow(error, 'cannot open cmap stream (%d %d R)', [fz_to_num(stmobj), fz_to_gen(stmobj)]);
  //  error:=-1;
		goto cleanup;
	end;

	error := pdf_parse_cmap(@cmap, file1);
	if (error<0)  then
	begin
		error := fz_rethrow(error, 'cannot parse cmap stream (%d %d R)', [fz_to_num(stmobj), fz_to_gen(stmobj)]);
    //error:=-1;
    exit;
		goto cleanup;
	end;
//  OutputDebugString(pchar(inttostr(pdf_range_s_items(cmap^.ranges)[341].low)));
	fz_close(file1);

	wmode := fz_dict_gets(stmobj, 'WMode');
	if (fz_is_int(wmode)) then
		pdf_set_wmode(cmap, fz_to_int(wmode));

	obj := fz_dict_gets(stmobj, 'UseCMap');
	if (fz_is_name(obj)) then
	begin
		error := pdf_load_system_cmap(@usecmap, fz_to_name(obj));
		if (error<0)  then
		begin
		  result:= fz_rethrow(error, 'cannot load system usecmap "%s"', [fz_to_name(obj)]);
     // result:=-1;
			goto cleanup;
		end;
		pdf_set_usecmap(cmap, usecmap);
		pdf_drop_cmap(usecmap);
	end
	else if (fz_is_indirect(obj)) then
	begin
		error := pdf_load_embedded_cmap(@usecmap, xref, obj);
		if (error<0)  then
		begin
			error := fz_rethrow(error, 'cannot load embedded usecmap (%d %d R)',[ fz_to_num(obj), fz_to_gen(obj)]);
      //error:=-1;
			goto cleanup;
		end;
		pdf_set_usecmap(cmap, usecmap);
		pdf_drop_cmap(usecmap);
	end;

	pdf_store_item(xref^.store, @pdf_keep_cmap, @pdf_drop_cmap, stmobj, cmap);

	cmapp^ := cmap;

  result:=1;
  exit;
cleanup:
	if (file1<>nil) then
		fz_close(file1);
	if (cmap<>nil) then
		pdf_drop_cmap(cmap);
	result:= error; //* already rethrown */
end;

(*
 * Create an Identity-* CMap (for both 1 and 2-byte encodings)
 *
 *)
function pdf_new_identity_cmap(wmode, bytes:integer):ppdf_cmap_s;
var
 cmap :ppdf_cmap_s;
begin
	cmap := pdf_new_cmap();
 if wmode<>0 then
    cmap^.cmap_name:='Identity-V'+#0
    else
    cmap^.cmap_name:='Identity-H'+#0;
 //	sprintf(cmap^.cmap_name, "Identity-%c", wmode ? 'V' : 'H');    }
	pdf_add_codespace(cmap, $0000, $ffff, bytes);

	pdf_map_range_to_range(cmap, $0000, $ffff, 0);

	pdf_sort_cmap1(cmap);

	pdf_set_wmode(cmap, wmode);
 
	result:= cmap;
end;

(*
 * Load predefined CMap from system.
 *)
function pdf_load_system_cmap(cmapp:pppdf_cmap_s; cmap_name:pchar):integer;
var
	usecmap:ppdf_cmap_s;
	cmap:ppdf_cmap_s;
begin
	cmap := pdf_find_builtin_cmap(cmap_name);
	if (cmap=nil) then
  begin
		//return fz_throw("no builtin cmap file: %s", cmap_name);
    result:=-1;
    exit;
  end;

	if (cmap^.usecmap_name[0]<>#0) and (cmap^.usecmap=nil) then
	begin
		usecmap := pdf_find_builtin_cmap(cmap^.usecmap_name);
		if (usecmap=nil) then
    begin
			//return fz_throw("nu builtin cmap file: %s", cmap^.usecmap_name);
      result:=-1;
      exit;
    end;
		pdf_set_usecmap(cmap, usecmap);
	end;

	cmapp^ := cmap;
	//return fz_okay;
  result:=1;
end;



end.
