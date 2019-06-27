unit pdfnamesstree;

interface
uses  SysUtils,digcommtype,digtypes,base_object_functions;

function pdf_lookup_dest(xref:ppdf_xref_s; needle:pfz_obj_s)  :pfz_obj_s;

implementation
uses mypdfstream;


function pdf_lookup_name_imp(node:pfz_obj_s; needle:pfz_obj_s):pfz_obj_s;
var
kids,names,kid,limits,first,last,key,val: pfz_obj_s;
l,r,m,c:integer;
begin
	kids := fz_dict_gets(node, 'Kids');
	names := fz_dict_gets(node, 'Names');

	if (fz_is_array(kids)) then
	begin
		l := 0;
		r := fz_array_len(kids) - 1;

		while (l <= r) do
		begin
			m := (l + r) shr 1;
			kid := fz_array_get(kids, m);
			limits := fz_dict_gets(kid, 'Limits');
			first := fz_array_get(limits, 0);
			last := fz_array_get(limits, 1);

			if (fz_objcmp(needle, first) < 0) then
				r := m - 1
			else if (fz_objcmp(needle, last) > 0) then
				l := m + 1
			else
      begin
				result:=pdf_lookup_name_imp(kid, needle);
        exit;
      end;
		end;
	end;

	if (fz_is_array(names)) then
	begin
		l := 0;
		r := (fz_array_len(names) div 2) - 1;

		while (l <= r) do
		begin
			m := (l + r) shr 1;

			key := fz_array_get(names, m * 2);
			val := fz_array_get(names, m * 2 + 1);

			c := fz_objcmp(needle, key);
			if (c < 0) then
				r := m - 1
			else if (c > 0) then
				l := m + 1
			else
      begin
				result:= val;
        exit;
      end;
		end;
	end;

	result:=nil;
end;

function pdf_lookup_name( xref:ppdf_xref_s; which:pchar;needle:pfz_obj_s) :pfz_obj_s;
var
root,names,tree: pfz_obj_s;
begin
	root := fz_dict_gets(xref.trailer, 'Root');
	names := fz_dict_gets(root, 'Names');
	tree := fz_dict_gets(names, which);
	result:=pdf_lookup_name_imp(tree, needle);
end;

function pdf_lookup_dest(xref:ppdf_xref_s; needle:pfz_obj_s)  :pfz_obj_s;
var
 root,dests,names,dest,tree: pfz_obj_s;
begin
	root := fz_dict_gets(xref.trailer, 'Root');
	dests := fz_dict_gets(root, 'Dests');
	names := fz_dict_gets(root, 'Names');
	dest := nil;

	//* PDF 1.1 has destinations in a dictionary */
	if (dests<>nil) then
	begin
		if (fz_is_name(needle))  then
    begin
			result:= fz_dict_get(dests, needle);
      exit;
    end
		else
    begin
		  result:= fz_dict_gets(dests, pchar(fz_to_str_buf(needle)));
      exit;
    end;
	end;

	//* PDF 1.2 has destinations in a name tree */
	if (names<>nil) and (dest=nil) then
	begin
		tree := fz_dict_gets(names, 'Dests');
		result:=pdf_lookup_name_imp(tree, needle);
    exit;
	end;

	result:=nil;
end;

procedure pdf_load_name_tree_imp(dict:pfz_obj_s;xref:ppdf_xref_s;node:pfz_obj_s);
var
	kids,names,key,val:pfz_obj_s ;
	i:integer;
begin
  kids := fz_dict_gets(node, 'Kids');
  names := fz_dict_gets(node, 'Names');

	if (kids<>nil) then
	begin
		for i := 0 to fz_array_len(kids)-1 do
			pdf_load_name_tree_imp(dict, xref, fz_array_get(kids, i));
	end;

	if (names<>nil) then
	begin
		for  i := 0  to fz_array_len(names)-2 do
		begin
      if i mod 2<>0 then
      continue;

			key := fz_array_get(names, i);
			val := fz_array_get(names, i + 1);
			if (fz_is_string(key)) then
			begin
				key := pdf_to_utf8_name(key);
				fz_dict_put(dict, key, val);
				fz_drop_obj(key);
			end
			else if (fz_is_name(key)) then
			begin
				fz_dict_put(dict, key, val);
			end;
		end;
	end;
end;

function pdf_load_name_tree(xref:ppdf_xref_s; which:pchar):pfz_obj_s;
var
root,names,tree,dict:pfz_obj_s;
begin
	root := fz_dict_gets(xref.trailer, 'Root');
	names := fz_dict_gets(root, 'Names');
	tree := fz_dict_gets(names, which);
	if (fz_is_dict(tree)) then
	begin
		dict := fz_new_dict(100);
		pdf_load_name_tree_imp(dict, xref, tree);
		result:= dict;
    exit;
	end;
	result:=nil;
end;

end.
