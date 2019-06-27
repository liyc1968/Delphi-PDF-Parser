unit fz_outline;

interface
uses
   SysUtils,digcommtype,digtypes,base_object_functions;
                                      //关于LINK没有加上
function pdf_load_outline(xref:ppdf_xref_s):ppdf_outline_s  ;
procedure pdf_free_outline(outline:ppdf_outline_s);
implementation

function pdf_load_outline_imp(xref:ppdf_xref_s; dict:pfz_obj_s):ppdf_outline_s;
var
 node:ppdf_outline_s ;
 obj:pfz_obj_s;
begin
	if (fz_is_null(dict))  then
  begin
		result:= nil;
    exit;
  end;
	node := fz_malloc(sizeof(pdf_outline_s));
	node^.title := nil;
	node^.link := nil;
	node^.child := nil;
	node^.next := nil;
	node^.count:= 0;

	obj := fz_dict_gets(dict, 'Title');
	if (obj<>nil) then
		node^.title := pdf_to_utf8(obj);

	obj := fz_dict_gets(dict, 'Count');
	if (obj<>nil) then
		node^.count := fz_to_int(obj);

//	if (fz_dict_gets(dict, 'Dest')<>nil) or  (fz_dict_gets(dict, 'A')<>nil) then
 //		node^.link := pdf_load_link(xref, dict);

	obj := fz_dict_gets(dict, 'First');
	if (obj<>nil) then
		node^.child := pdf_load_outline_imp(xref, obj);

	obj := fz_dict_gets(dict, 'Next');
	if (obj<>nil) then
		node^.next := pdf_load_outline_imp(xref, obj);

	result:=node;
end;

function pdf_load_outline(xref:ppdf_xref_s):ppdf_outline_s  ;
var
	root,obj,first:pfz_obj_s;

begin
	root := fz_dict_gets(xref.trailer, 'Root');
	obj := fz_dict_gets(root, 'Outlines');
	first := fz_dict_gets(obj, 'First');
	if (first<>nil) then
  begin
		result:= pdf_load_outline_imp(xref, first);
    exit;
  end;
	result:= nil;
end;

procedure pdf_free_outline(outline:ppdf_outline_s);
begin
	if (outline^.child<>nil) then
		pdf_free_outline(outline^.child);
	if (outline^.next<>nil)  then
		pdf_free_outline(outline^.next);
//	if (outline^.link<>nil)
 //		pdf_free_link(outline^.link);
	fz_free(outline^.title);
	fz_free(outline);
end;









end.
