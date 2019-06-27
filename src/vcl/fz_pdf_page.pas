unit fz_pdf_page;

interface
uses    SysUtils, digcommtype,digtypes,base_object_functions,mypdfstream,math,fz_pdf_linkss,base_error;

function pdf_resources_use_blending(rdb:pfz_obj_s):integer;
procedure pdf_free_page(page:ppdf_page_s);
function pdf_load_page_tree(xref:ppdf_xref_s):integer;
function pdf_count_pages(xref:ppdf_xref_s):integer;
function pdf_find_page_number( xref:ppdf_xref_s; page:pfz_obj_s):integer;
function pdf_load_page(pagep:pppdf_page_s;xref :ppdf_xref_s ;number:integer):integer;
implementation
uses fz_pdf_store;



function pdf_count_pages(xref:ppdf_xref_s):integer;
begin
	result:=xref.page_len;
end;

function pdf_find_page_number( xref:ppdf_xref_s; page:pfz_obj_s):integer;
var
 i, num:integer;
begin
	num := fz_to_num(page);
	for i := 0 to xref.page_len-1 do
  begin
		if (num = fz_to_num(fz_obj_s_items(xref.page_refs)[i]))  then
    begin
			result:= i;
      exit;
    end;
  end;
	result:= -1;
end;

procedure pdf_load_page_tree_node(xref:ppdf_xref_s; node:pfz_obj_s;  info: info_s);
var
	dict, kids, count:pfz_obj_s;
	obj, tmp:pfz_obj_s;
	i, n:integer;
begin
	//* prevent infinite recursion */

 //  fz_debug_dict_gets(node);
	if (fz_dict_gets(node, '.seen')<>nil) then
		exit;

	kids := fz_dict_gets(node, 'Kids');
	count := fz_dict_gets(node, 'Count');

	if (fz_is_array(kids) and fz_is_int(count)) then
	begin
		obj := fz_dict_gets(node, 'Resources');
		if (obj<>nil)then
			info.resources := obj;
		obj := fz_dict_gets(node, 'MediaBox');
		if (obj<>nil) then
			info.mediabox := obj;
		obj := fz_dict_gets(node, 'CropBox');
		if (obj<>nil) then
			info.cropbox := obj;
		obj := fz_dict_gets(node, 'Rotate');
		if (obj<>nil) then
			info.rotate := obj;

		tmp := fz_new_null();
		fz_dict_puts(node, '.seen', tmp);
		fz_drop_obj(tmp);

		n := fz_array_len(kids);
		for i := 0 to n-1 do
		begin
			obj := fz_array_get(kids, i);
			pdf_load_page_tree_node(xref, obj, info);
		end;

		fz_dict_dels(node, '.seen');
	end
	else
	begin
		dict := fz_resolve_indirect(node);

		if (info.resources<>nil) and (fz_dict_gets(dict, 'Resources')=nil) then
			fz_dict_puts(dict, 'Resources', info.resources);
		if (info.mediabox<>nil) and (fz_dict_gets(dict, 'MediaBox')=nil)  then
			fz_dict_puts(dict, 'MediaBox', info.mediabox);
		if (info.cropbox<>nil) and (fz_dict_gets(dict, 'CropBox')=nil) then
			fz_dict_puts(dict, 'CropBox', info.cropbox);
		if (info.rotate<>nil) and (fz_dict_gets(dict, 'Rotate')=nil) then
			fz_dict_puts(dict, 'Rotate', info.rotate);

		if (xref.page_len = xref.page_cap)   then
		begin
			fz_warn('found more pages than expected');
			xref.page_cap:=xref.page_cap+1;
			xref.page_refs := fz_realloc(xref.page_refs, xref.page_cap, sizeof(pfz_obj_s));
			xref.page_objs := fz_realloc(xref.page_objs, xref.page_cap, sizeof(pfz_obj_s));
		end;

		fz_obj_s_items(xref.page_refs)[xref.page_len] := fz_keep_obj(node);
		fz_obj_s_items(xref.page_objs)[xref.page_len] := fz_keep_obj(dict);
		xref.page_len:=xref.page_len+1;
	end;
end;


function pdf_load_page_tree(xref:ppdf_xref_s):integer;
var
info: info_s ;
 catalog, pages ,count:pfz_obj_s;

begin
  catalog:=nil;
  pages:=nil;
  count:=nil;
	catalog := fz_dict_gets(xref.trailer, 'Root');
 // fz_debug_xref(xref);
  //fz_debug_dict_gets(catalog);
	pages := fz_dict_gets(catalog, 'Pages');

  //fz_debug_dict_gets(pages);
	count := fz_dict_gets(pages, 'Count');
//  fz_debug_dict_gets(count);
  //  fz_debug_xref(xref);
	if (fz_is_dict(pages)=false) then
  begin
		//return fz_throw("missing page tree");
    result:=-1;
    exit;
  end;
	if (fz_is_int(count)=false) then
  begin
	 //	return fz_throw("missing page count");
    result:=-1;
    exit;
  end;
	xref.page_cap := fz_to_int(count);
	xref.page_len := 0;
	xref.page_refs := fz_calloc(xref.page_cap, sizeof(pfz_obj_s));
	xref.page_objs := fz_calloc(xref.page_cap, sizeof(pfz_obj_s));

	info.resources := nil;
	info.mediabox := nil;
	info.cropbox := nil;
	info.rotate := nil;

	pdf_load_page_tree_node(xref, pages, info);

	result:=1;
end;

//* We need to know whether to install a page-level transparency group */

//function pdf_resources_use_blending(rdb:pfz_obj_s):integer;

function pdf_extgstate_uses_blending(dict:pfz_obj_s) :integer;
var
obj:pfz_obj_s;
begin
   obj := fz_dict_gets(dict, 'BM');
	if (fz_is_name(obj)) and (strcomp(fz_to_name(obj), 'Normal')<>0)  then
  begin
		result:=1;
    exit;
  end;
	result:=0;
end;

function pdf_pattern_uses_blending(dict:pfz_obj_s) :integer;
var
obj:pfz_obj_s;
begin
	obj := fz_dict_gets(dict, 'Resources');
	if (pdf_resources_use_blending(obj)=1)  then
  begin
		result:=1;
    exit;
  end;
	obj := fz_dict_gets(dict, 'ExtGState');
	if (pdf_extgstate_uses_blending(obj)=1)  then
  begin
		result:=1;
    exit;
  end;
	result:=0;
end;

function pdf_xobject_uses_blending(dict:pfz_obj_s):integer;
var
obj:pfz_obj_s;
begin
	obj := fz_dict_gets(dict, 'Resources');
	if (pdf_resources_use_blending(obj)=1)  then
  begin
		result:=1;
    exit;
  end;
	result:=0;
end;

function pdf_resources_use_blending(rdb:pfz_obj_s):integer;
var
	dict:pfz_obj_s;
	tmp:pfz_obj_s;
	i:integer;
  label found;
begin
	if (rdb=nil) then
  begin
		//return 0;
    result:=0;
    exit;
  end;
	//* stop on cyclic resource dependencies */
	if (fz_dict_gets(rdb, '.useBM')<>nil) then
  begin
    //return fz_to_bool(fz_dict_gets(rdb, ".useBM"));
    result:=fz_to_bool(fz_dict_gets(rdb, '.useBM'));
    exit;
  end;
	tmp := fz_new_bool(0);
	fz_dict_puts(rdb, '.useBM', tmp);
	fz_drop_obj(tmp);

	dict := fz_dict_gets(rdb, 'ExtGState');
	for i := 0 to fz_dict_len(dict)-1 do
		if (pdf_extgstate_uses_blending(fz_dict_get_val(dict, i))=1) then
			goto found;

	dict := fz_dict_gets(rdb, 'Pattern');
	for i := 0 to fz_dict_len(dict)-1 do
		if (pdf_pattern_uses_blending(fz_dict_get_val(dict, i))=1) then
			goto found;

	dict := fz_dict_gets(rdb, 'XObject');
	for i := 0 to fz_dict_len(dict)-1 do
		if (pdf_xobject_uses_blending(fz_dict_get_val(dict, i))=1) then
			goto found;

	result:=0;
  exit;

found:
	tmp := fz_new_bool(1);
	fz_dict_puts(rdb, '.useBM', tmp);
	fz_drop_obj(tmp);
	result:=1;
end;

//* we need to combine all sub-streams into one for the content stream interpreter */

function pdf_load_page_contents_array(bigbufp:ppfz_buffer_s;xref :ppdf_xref_s; list:pfz_obj_s):integer;
var
	error:integer;
  big:	pfz_buffer_s ;
  one:	pfz_buffer_s ;
  stm:  pfz_obj_s;
  i, n:integer;
begin
	big := fz_new_buffer(32 * 1024);

	n := fz_array_len(list);
	for i := 0 to  n-1 do
	begin
		stm := fz_array_get(list, i);
		error := pdf_load_stream(@one, xref, fz_to_num(stm), fz_to_gen(stm));
		if (error<0) then
		begin
			fz_catch(error, 'cannot load content stream part %d/%d', [i + 1, n]);
			continue;
		end;

		if (big^.len + one^.len + 1 > big^.cap) then
			fz_resize_buffer(big, big^.len + one^.len + 1);
	 //	copymemory(pointer(integer(big^.data) + big^.len), one^.data, one^.len);
   	move(one^.data^,pointer(cardinal(big^.data) + big^.len)^,  one^.len);
		byte_items(big^.data)[big^.len + one^.len] := ord(' ');
		big^.len :=big^.len+ one^.len + 1;

		fz_drop_buffer(one);
	end;

	if (n > 0) and (big^.len = 0) then
	begin
		fz_drop_buffer(big);
		result:=fz_throw('cannot load content stream');
    exit;
	end;

	bigbufp^ := big;
 //	return fz_okay;
  result:=1;
end;

function pdf_load_page_contents(bufp:ppfz_buffer_s;xref:ppdf_xref_s;obj: pfz_obj_s):integer;
var
	error:integer;
begin
	if (fz_is_array(obj)) then
	begin
		error := pdf_load_page_contents_array(bufp, xref, obj);
		if (error<=0) then
    begin
			result:=fz_rethrow(error, 'cannot load content stream array');
      exit;
    end;
	end
	else if (pdf_is_stream(xref, fz_to_num(obj), fz_to_gen(obj))>0)  then
	begin
		error := pdf_load_stream(bufp, xref, fz_to_num(obj), fz_to_gen(obj));
		if (error<0) then
    begin
			result:=fz_rethrow(error, 'cannot load content stream (%d 0 R)', [fz_to_num(obj)]);

      exit;
    end;
	end
	else
	begin
		fz_warn('page contents missing, leaving page blank');
		bufp^ := fz_new_buffer(0);
	end;

	result:=1;
end;

function pdf_load_page(pagep:pppdf_page_s;xref :ppdf_xref_s ;number:integer):integer;
var
	error:integer;
	page:ppdf_page_s;
	annot:ppdf_annot_s;
	pageobj, pageref:pfz_obj_s;
	obj:pfz_obj_s;
	bbox:fz_bbox;
  cropbox:fz_bbox;
begin
	if (number < 0) or (number >= xref.page_len) then
  begin
		result:=fz_throw('cannot find page %d', [number + 1]);
    exit;
  end;
	//* Ensure that we have a store for resource objects */
  
	if (xref.store=nil) then
		xref.store := pdf_new_store();

	pageobj := fz_obj_s_items(xref.page_objs)[number];
	pageref := fz_obj_s_items(xref.page_refs)[number];

	page := fz_malloc(sizeof(pdf_page_s));
	page^.resources := nil;
	page^.contents := nil;
	page^.transparency := 0;
	page^.links := nil;
	page^.annots := nil;

	obj := fz_dict_gets(pageobj, 'MediaBox');
	bbox := fz_round_rect(pdf_to_rect(obj));
	if (fz_is_empty_rect(pdf_to_rect(obj))) then
	begin
		fz_warn('cannot find page size for page %d', [number + 1]);
		bbox.x0 := 0;
		bbox.y0 := 0;
		bbox.x1 := 612;
		bbox.y1 := 792;
	end;

	obj := fz_dict_gets(pageobj, 'CropBox');
	if (fz_is_array(obj))  then
	begin
		cropbox := fz_round_rect(pdf_to_rect(obj));
		bbox := fz_intersect_bbox(bbox, cropbox);
	end;

	page^.mediabox.x0 := MIN(bbox.x0, bbox.x1);
	page^.mediabox.y0 := MIN(bbox.y0, bbox.y1);
	page^.mediabox.x1 := MAX(bbox.x0, bbox.x1);
	page^.mediabox.y1 := MAX(bbox.y0, bbox.y1);

	if (page^.mediabox.x1 - page^.mediabox.x0 < 1) or (page^.mediabox.y1 - page^.mediabox.y0 < 1) then
	begin
		fz_warn('invalid page size in page %d', [number + 1]);
		page^.mediabox := fz_unit_rect;
 end;

	page^.rotate := fz_to_int(fz_dict_gets(pageobj, 'Rotate'));

	obj := fz_dict_gets(pageobj, 'Annots');
	if (obj<>nil) then
	begin
		pdf_load_links(@page^.links, xref, obj);
		pdf_load_annots(@page^.annots, xref, obj);
	end;

	page^.resources := fz_dict_gets(pageobj, 'Resources');
	if (page^.resources<>nil) then
		fz_keep_obj(page^.resources);

	obj := fz_dict_gets(pageobj, 'Contents');
	error := pdf_load_page_contents(@page^.contents, xref, obj);
	if (error<0)  then
	begin
		pdf_free_page(page);
		result:= fz_rethrow(error, 'cannot load page %d contents (%d 0 R)', [number + 1, fz_to_num(pageref)]);

    exit;
	end;

	if (pdf_resources_use_blending(page^.resources)=1) then
		page^.transparency := 1;
  annot := page^.annots;
  while  (annot<>nil) and (page^.transparency<>0) do
  begin
 //	for (annot := page^.annots; annot && !page->transparency; annot = annot->next)
		if (pdf_resources_use_blending(annot^.ap^.resources)<>0) then
			page^.transparency := 1;
      annot := annot^.next ;
  end;
	pagep^ := page;
	//return fz_okay;
  result:=1;
end;

procedure pdf_free_page(page:ppdf_page_s);
begin
  if page=nil then
  exit;
	if (page^.resources<>nil) then
  begin
		fz_drop_obj(page^.resources);
  end;
	if (page^.contents<>nil)  then
		fz_drop_buffer(page^.contents);
	if (page^.links)<>nil then
		pdf_free_link(page^.links);
	if (page^.annots)<>nil then
		pdf_free_annot(page^.annots);
	fz_free(page);
end;



end.
