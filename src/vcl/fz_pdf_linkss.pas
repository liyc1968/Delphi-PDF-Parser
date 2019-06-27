unit fz_pdf_linkss;

interface
uses   SysUtils,digcommtype,digtypes,base_object_functions,base_error;
//function pdf_load_link(xref:ppdf_xref_s; dict:pfz_obj_s):ppdf_link_s;
procedure pdf_load_links(linkp:pppdf_link_s;xref:ppdf_xref_s; annots:pfz_obj_s) ;
procedure pdf_load_annots(annotp:pppdf_annot_s; xref:ppdf_xref_s;annots:pfz_obj_s) ;
procedure pdf_free_link(link:ppdf_link_s);
procedure pdf_free_annot(annot:ppdf_annot_s) ;
implementation
uses mypdfstream,pdfnamesstree,pdf_xobjectxxx;
procedure pdf_free_link(link:ppdf_link_s);
begin
	if (link^.next<>nil) then
		pdf_free_link(link^.next);
	if (link^.dest<>nil) then
		fz_drop_obj(link^.dest);
	fz_free(link);
end;

function resolve_dest(xref:ppdf_xref_s;dest:pfz_obj_s):pfz_obj_s;
begin
	if (fz_is_name(dest) or fz_is_string(dest)) then
	begin
		dest := pdf_lookup_dest(xref, dest);
		result:=resolve_dest(xref, dest);
    exit;
	end

	else if (fz_is_array(dest))   then
	begin
		result:= dest;
    exit;
	end

	else if (fz_is_dict(dest)) then
	begin
		dest := fz_dict_gets(dest, 'D');
		result:= resolve_dest(xref, dest);
    exit;
	end

	else if (fz_is_indirect(dest)) then
  begin
		result:= dest;
    exit;
  end;
	result:=nil;
end;

function pdf_load_link(xref:ppdf_xref_s; dict:pfz_obj_s):ppdf_link_s;
var
 dest,action,obj:pfz_obj_s;
   link:ppdf_link_s;
	bbox:fz_rect ;
  kind:	pdf_link_kind_e;
begin
	dest := nil;

	obj := fz_dict_gets(dict, 'Rect');
	if (obj<>nil) then
		bbox := pdf_to_rect(obj)
	else
		bbox := fz_empty_rect;

	obj := fz_dict_gets(dict, 'Dest');
	if (obj<>nil) then
	begin
		kind := PDF_LINK_GOTO;
		dest := resolve_dest(xref, obj);
	end;

	action := fz_dict_gets(dict, 'A');

///* fall back to additional action button's down/up action */
	if (action=nil) then
		action := fz_dict_getsa(fz_dict_gets(dict, 'AA'), 'U', 'D');

	if (action<>nil) then
	begin
		obj := fz_dict_gets(action, 'S');
		if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'GoTo')=0)) then
		begin
			kind := PDF_LINK_GOTO;
			dest := resolve_dest(xref, fz_dict_gets(action, 'D'));
		end
		else if (fz_is_name(obj) and  (strcomp(fz_to_name(obj), 'URI')=0))  then
		begin
			kind := PDF_LINK_URI;
			dest := fz_dict_gets(action, 'URI');
		end
		else if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'Launch')=0)) then
		begin
			kind := PDF_LINK_LAUNCH;
			dest := fz_dict_gets(action, 'F');
		end
		else if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'Named')=0)) then
		begin
			kind := PDF_LINK_NAMED;
			dest := fz_dict_gets(action, 'N');
		end
		else if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'GoToR')=0)) then
		begin
			kind := PDF_LINK_ACTION;
			dest := action;
		end
		else
		begin
			dest :=nil;
		end;
	end;

	if (dest<>nil) then
	begin
		link := fz_malloc(sizeof(pdf_link_s));
		link^.kind := kind;
		link^.rect := bbox;
		link^.dest := fz_keep_obj(dest);
		link^.next := nil;
		result:=link;
    exit;
	end;

	result:= nil;
end;

procedure pdf_load_links(linkp:pppdf_link_s;xref:ppdf_xref_s; annots:pfz_obj_s) ;
var
	link, head, tail:ppdf_link_s;
	obj:pfz_obj_s;
	i:integer;
begin
	head :=nil;
  tail:= nil;
	link:= nil;

	for i := 0 to fz_array_len(annots)-1 do
	begin
		obj := fz_array_get(annots, i);
		link := pdf_load_link(xref, obj);
		if (link<>nil) then
		begin
			if (head=nil) then
      begin
				 tail := link;
         head :=link;
      end
			else
			begin
				tail^.next := link;
				tail := link;
			end;
		end;
	end;

	linkp^ := head;
end;

procedure pdf_free_annot(annot:ppdf_annot_s) ;
begin
	if (annot^.next<>nil) then
		pdf_free_annot(annot^.next);
	if (annot^.ap<>nil) then
		pdf_drop_xobject(annot^.ap);
	if (annot^.obj<>nil) then
		fz_drop_obj(annot^.obj);
	fz_free(annot);
end;

procedure pdf_transform_annot(annot:ppdf_annot_s) ;
var
 matrix:fz_matrix;
 bbox:fz_rect;
 rect: fz_rect;
 w, h, x, y:single;
begin
	 matrix := annot^.ap^.matrix;
	 bbox := annot^.ap^.bbox;
	 rect := annot^.rect;


	bbox := fz_transform_rect(matrix, bbox);
	w := (rect.x1 - rect.x0) / (bbox.x1 - bbox.x0);
	h := (rect.y1 - rect.y0) / (bbox.y1 - bbox.y0);
	x := rect.x0 - bbox.x0;
	y := rect.y0 - bbox.y0;

	annot^.matrix := fz_concat(fz_scale(w, h), fz_translate(x, y));
end;

procedure pdf_load_annots(annotp:pppdf_annot_s; xref:ppdf_xref_s;annots:pfz_obj_s) ;
var
	annot, head, tail:ppdf_annot_s;
	obj, ap, as1, n, rect:pfz_obj_s;
	form:ppdf_xobject_s;
	 error:integer;
	i:integer;
begin
	tail := nil;
  head := nil;
	annot := nil;

	for i := 0 to fz_array_len(annots)-1 do
	begin
		obj := fz_array_get(annots, i);

		rect := fz_dict_gets(obj, 'Rect');
		ap := fz_dict_gets(obj, 'AP');
		as1 := fz_dict_gets(obj, 'AS');
		if (fz_is_dict(ap)) then
		begin
			n := fz_dict_gets(ap, 'N'); //* normal state */

			//* lookup current state in sub-dictionary */
			if ( pdf_is_stream(xref, fz_to_num(n), fz_to_gen(n))=0)  then
				n := fz_dict_get(n, as1);

			if (pdf_is_stream(xref, fz_to_num(n), fz_to_gen(n))<>0) then
			begin
				error := pdf_load_xobject(@form, xref, n);
				if (error<=0) then
				begin
				 	fz_catch(error, 'ignoring broken annotation');
					continue;
				end;

				annot := fz_malloc(sizeof(pdf_annot_s));
				annot^.obj := fz_keep_obj(obj);
				annot^.rect := pdf_to_rect(rect);
				annot^.ap := form;
				annot^.next := nil;

				pdf_transform_annot(annot);

				if (annot<>nil) then
				begin
					if (head=nil) then
          begin
						tail := annot;
            head := annot;
          end
					else
					begin
						tail^.next := annot;
						tail := annot;
					end;
				end;
			end;
		end;
	end;

	annotp^ := head;
end;

end.
