unit pdf_repair;

interface
uses  SysUtils,Math,digtypes,base_object_functions,digcommtype,base_error;

function pdf_repair_xref(xref:ppdf_xref_s; buf:pchar; bufsize:integer):fz_error;
function pdf_repair_obj_stms(xref:ppdf_xref_s):fz_error;  
implementation
uses FZ_mystreams,mypdfstream;

type
pentry_s=^entry_s;
entry_s=record
	num:integer;
	gen:integer;
	ofs:integer;
	stm_ofs:integer;
	stm_len:integer;
end;
entry_s_items=array of  entry_s;
function pdf_repair_obj(file1:pfz_stream_s; buf:pchar;  cap:integer; stmofsp:pinteger; stmlenp:pinteger; encrypt:ppfz_obj_s; id:ppfz_obj_s):fz_error;
var
	error:fz_error;
	tok:pdf_kind_e;
	stm_len:integer;
	len:integer;
	n:integer;
  dict, obj:pfz_obj_s;
  c:integer;
  buf1:array[0..8] of char;
  label atobjend;
begin
  buf1:='endstream';
	stmofsp^ := 0;
	stmlenp^ := -1;

	stm_len := 0;

	error := pdf_lex(@tok, file1, buf, cap, @len);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot parse object');
    exit;
  end;
	if (tok = PDF_TOK_OPEN_DICT) then
	begin


		//* Send NULL xref so we don't try to resolve references */
		error := pdf_parse_dict(@dict, nil, file1, buf, cap);
		if (error<0) then
    begin
			result:= fz_rethrow(error, 'cannot parse object');
      exit;
    end;

		obj := fz_dict_gets(dict, 'Type');
		if (fz_is_name(obj) and (strcomp(fz_to_name(obj), 'XRef')=0)) then
		begin
			obj := fz_dict_gets(dict, 'Encrypt');
			if (obj<>nil) then
			begin
				if (encrypt^<>nil) then
					fz_drop_obj(encrypt^);
				encrypt^ := fz_keep_obj(obj);
			end;

			obj := fz_dict_gets(dict, 'ID');
			if (obj<>nil) then
			begin
				if (id^<>nil) then
					fz_drop_obj(id^);
				id^ := fz_keep_obj(obj);
			end;
		end;

		obj := fz_dict_gets(dict, 'Length');
		if (fz_is_int(obj)) then
			stm_len := fz_to_int(obj);

		fz_drop_obj(dict);
	end;

	while (( tok <> PDF_TOK_STREAM) and
		(tok <> PDF_TOK_ENDOBJ) and
		(tok <> PDF_TOK_ERROR) and
		(tok <> PDF_TOK_EOF) )  do
	begin
		error := pdf_lex(@tok, file1, buf, cap, @len);
		if (error<=0) then
    begin
			result:= fz_rethrow(error, 'cannot scan for endobj or stream token');
      exit;
    end;
	end;

	if (tok = PDF_TOK_STREAM) then
	begin
		c := fz_read_byte(file1);
		if (c = 13) then
    begin
			c := fz_peek_byte(file1);
			if (c = 10) then
				fz_read_byte(file1);
		end;

		stmofsp^ := fz_tell(file1);
		if (stmofsp^ < 0) then
    begin
			result:=fz_throw('cannot seek in file');
      exit;
    end;

		if (stm_len > 0) then
		begin
			fz_seek(file1, stmofsp^ + stm_len, 0);
			error := pdf_lex(@tok, file1, buf, cap, @len);
			if (error<0) then
      begin
				fz_catch(error, 'cannot find endstream token, falling back to scanning');
        exit;
      end;

			if (tok = PDF_TOK_ENDSTREAM) then
				goto atobjend;
			fz_seek(file1, stmofsp^, 0);
		end;

		n := fz_read(file1, pbyte(buf), 9);
		if (n < 0) then
    begin
			result:=fz_rethrow(n, 'cannot read from file');
      exit;
    end;

		while (CompareMem(buf, @buf1, 9) =false) do
		begin
			c := fz_read_byte(file1);
			if (c = eEOF) then
				break;
		  move((buf + 1)^,buf^,  8);
			(buf + 8)^ := chr(c);
		end;

		stmlenp^ := fz_tell(file1) - stmofsp^ - 9;

atobjend:
		error := pdf_lex(@tok, file1, buf, cap, @len);
		if (error<0) then
    begin
			result:=fz_rethrow(error, 'cannot scan for endobj token');
      exit;
    end;
		if (tok <> PDF_TOK_ENDOBJ) then
    			fz_warn('object missing endobj token');
	end;

	result:= fz_okay;
end;

function pdf_repair_obj_stm(xref:ppdf_xref_s; num, gen:integer):fz_error ;
var
	error:fz_error;
	obj:pfz_obj_s;
	stm:pfz_stream_s;
	tok:pdf_kind_e;
	i, n, count:integer;
	buf:array[0..255] of char;
begin
	error := pdf_load_object(@obj, xref, num, gen);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot load object stream object (%d %d R)', [num, gen]);     //fz_rethrow(error, 'cannot load object stream object (%d %d R)', [num, gen])
    exit;
  end;

	count := fz_to_int(fz_dict_gets(obj, 'N'));

	fz_drop_obj(obj);

	error := pdf_open_stream(@stm, xref, num, gen);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot open object stream object (%d %d R)', [num, gen]);
    exit;
  end;

	for i := 0 to count-1 do
	begin
		error := pdf_lex(@tok, stm, buf, sizeof(buf), @n);
		if (error<0) or (tok <> PDF_TOK_INT) then
		begin
			fz_close(stm);
			result:= fz_rethrow(error, 'corrupt object stream (%d %d R)', [num, gen]);
      exit;
		end;

		n := atoi(buf);
		if (n >= xref^.len) then
			pdf_resize_xref(xref, n + 1);

		table_items(xref^.table)[n].ofs := num;
		table_items(xref^.table)[n].gen := i;
		table_items(xref^.table)[n].stm_ofs := 0;
		table_items(xref^.table)[n].obj := nil;
		table_items(xref^.table)[n].type1 := ord('o');

		error := pdf_lex(@tok, stm, buf, sizeof(buf), @n);
		if (error<0) or (tok <> PDF_TOK_INT) then
		begin
			fz_close(stm);
			result:= fz_rethrow(error, 'corrupt object stream (%d %d R)', [num, gen]);
      EXIT;
		end;
	end;

	fz_close(stm);
	result:= fz_okay;
end;

function pdf_repair_xref(xref:ppdf_xref_s; buf:pchar; bufsize:integer):fz_error;
var
	error:fz_error;
	dict, obj:pfz_obj_s;
	length:pfz_obj_s;
  encrypt,id,root,info:pfz_obj_s;
  list:pentry_s;
  listlen:integer;
  listcap:integer;
  maxnum:integer;
  num :integer;
  gen :integer;
  tmpofs, numofs , genofs :integer;
  stm_len, stm_ofs:integer;
  tok:pdf_kind_e;
  next:integer;
  i, n, c:integer;
  buf1:array[0..4] of char;
 // kll:integer;
  label   cleanup;
begin
	encrypt :=nil;
	id :=nil;
	root :=nil;
	info :=nil;

  list:=nil;
 maxnum := 0;

	num := 0;
	gen := 0;
	numofs := 0;
  genofs := 0;
	stm_ofs := 0;
	fz_seek(xref^.myfile, 0, 0);

	listlen := 0;
	listcap := 1024;
	list := fz_calloc(listcap, sizeof(entry_s));

	//* look for '%PDF' version marker within first kilobyte of file */
	n := fz_read(xref^.myfile, pbyte(buf), MAX(bufsize, 1024));
	if (n < 0)  then
	begin
		error := fz_rethrow(n, 'cannot read from file');
		goto cleanup;
	end;
  buf1:='%PDF';
	fz_seek(xref^.myfile, 0, 0);
	for i := 0 to n - 5 do
	begin
		if (CompareMem(buf + i, @buf1, 4) =true) then
		begin
			fz_seek(xref^.myfile, i + 8, 0); //* skip "%PDF-X.Y" */
			break;
		end;
	end;

	//* skip comment line after version marker since some generators
	// * forget to terminate the comment with a newline */
	c := fz_read_byte(xref^.myfile);
	while  (c >= 0) and ((c =ord(' ')) or (c = ord('%'))) do
		c := fz_read_byte(xref^.myfile);
	fz_unread_byte(xref^.myfile);
  //kll:=0;
	while (true) do
	begin
   // if kll=14 then
   // OutputDebugString(pchar('kll:'+inttostr(kll)));
   // kll:=kll+1;
		tmpofs := fz_tell(xref^.myfile);
		if (tmpofs < 0) then
		begin
			error := fz_throw('cannot tell in file');
			goto cleanup;
		end;

		error := pdf_lex(@tok, xref^.myfile, buf, bufsize, @n);
		if (error<0) then
		begin
			fz_catch(error, 'ignoring the rest of the file');
			break;
		end;

		if (tok = PDF_TOK_INT) then
		begin
			numofs := genofs;
			num := gen;
			genofs := tmpofs;
			gen := atoi(buf);
		end

		else if (tok = PDF_TOK_OBJ)  then
		begin
			error := pdf_repair_obj(xref^.myfile, buf, bufsize, @stm_ofs, @stm_len, @encrypt, @id);
			if (error<0) then
			begin
				error := fz_rethrow(error, 'cannot parse object (%d %d R)', [num, gen]);
				goto cleanup;
			end;

			if (listlen + 1 = listcap) then
			begin
				listcap := (listcap * 3) div 2;
				list := fz_realloc(list, listcap, sizeof(entry_s));
			end;

			entry_s_items(list)[listlen].num := num;
			entry_s_items(list)[listlen].gen := gen;
			entry_s_items(list)[listlen].ofs := numofs;
			entry_s_items(list)[listlen].stm_ofs := stm_ofs;
			entry_s_items(list)[listlen].stm_len := stm_len;
			listlen:=listlen+1;

			if (num > maxnum) then
				maxnum := num;
		end

		//* trailer dictionary */
		else if (tok = PDF_TOK_OPEN_DICT) then
		begin
			error := pdf_parse_dict(@dict, xref, xref^.myfile, buf, bufsize);
			if (error<0) then
			begin
				error := fz_rethrow(error, 'cannot parse object');
				goto cleanup;
			end;

			obj := fz_dict_gets(dict, 'Encrypt');
			if (obj<>nil) then
			begin
				if (encrypt<>nil) then
					fz_drop_obj(encrypt);
				encrypt := fz_keep_obj(obj);
			end;

			obj := fz_dict_gets(dict, 'ID');
			if (obj<>nil) then
			begin
				if (id<>nil) then
					fz_drop_obj(id);
				id := fz_keep_obj(obj);
			end;

			obj := fz_dict_gets(dict, 'Root');
			if (obj<>nil) then
			begin
				if (root<>nil) then
					fz_drop_obj(root);
				root := fz_keep_obj(obj);
			end;

			obj := fz_dict_gets(dict, 'Info');
			if (obj<>nil) then
			begin
				if (info<>nil) then
					fz_drop_obj(info);
				info := fz_keep_obj(obj);
			end;

			fz_drop_obj(dict);
		end

		else if (tok = PDF_TOK_ERROR) then
			fz_read_byte(xref^.myfile)

		else if (tok = PDF_TOK_EOF) then
			break;
	end;

	//* make xref reasonable */

	pdf_resize_xref(xref, maxnum + 1);

	for i := 0 to listlen-1 do
	begin
		table_items(xref^.table)[entry_s_items(list)[i].num].type1 := ord('n');
			table_items(xref^.table)[entry_s_items(list)[i].num].ofs := entry_s_items(list)[i].ofs;
			table_items(xref^.table)[entry_s_items(list)[i].num].gen := entry_s_items(list)[i].gen;

			table_items(xref^.table)[entry_s_items(list)[i].num].stm_ofs := entry_s_items(list)[i].stm_ofs;

		//* corrected stream length */
		if (entry_s_items(list)[i].stm_len >= 0)  then
		begin
			error := pdf_load_object(@dict, xref, entry_s_items(list)[i].num, entry_s_items(list)[i].gen);
			if (error<0) then
			begin
				error := fz_rethrow(error, 'cannot load stream object (%d %d R)', [entry_s_items(list)[i].num, entry_s_items(list)[i].gen]);
				goto cleanup;
			end;

			length := fz_new_int(entry_s_items(list)[i].stm_len);
			fz_dict_puts(dict, 'Length', length);
			fz_drop_obj(length);

			fz_drop_obj(dict);
		end;

	end;

	table_items(xref^.table)[0].type1 :=ord('f');
	table_items(xref^.table)[0].ofs := 0;
	table_items(xref^.table)[0].gen := 65535;
	table_items(xref^.table)[0].stm_ofs := 0;
	table_items(xref^.table)[0].obj := nil;

	next := 0;
	for i := xref^.len - 1 downto 0 do
	begin
		if (table_items(xref^.table)[i].type1 =ord( 'f')) then
		begin
			table_items(xref^.table)[i].ofs := next;
			if (table_items(xref^.table)[i].gen < 65535) then
				table_items(xref^.table)[i].gen:=table_items(xref^.table)[i].gen+1;
			next := i;
		end;
	end;

	//* create a repaired trailer, Root will be added later */

	xref^.trailer := fz_new_dict(5);

	obj := fz_new_int(maxnum + 1);
	fz_dict_puts(xref^.trailer, 'Size', obj);
	fz_drop_obj(obj);

	if (root<>nil) then
	begin
		fz_dict_puts(xref^.trailer, 'Root', root);
		fz_drop_obj(root);
	end;
	if (info<>nil) then
	begin
		fz_dict_puts(xref^.trailer, 'Info', info);
		fz_drop_obj(info);
	end;

	if (encrypt<>nil) then
	begin
		if (fz_is_indirect(encrypt)) then
		begin
			//* create new reference with non-NULL xref pointer */
			obj := fz_new_indirect(fz_to_num(encrypt), fz_to_gen(encrypt), xref);
			fz_drop_obj(encrypt);
			encrypt := obj;
		end;
		fz_dict_puts(xref^.trailer, 'Encrypt', encrypt);
		fz_drop_obj(encrypt);
	end;

	if (id<>nil) then
	begin
		if (fz_is_indirect(id)) then
		begin
			//* create new reference with non-NULL xref pointer */
			obj := fz_new_indirect(fz_to_num(id), fz_to_gen(id), xref);
			fz_drop_obj(id);
			id := obj;
		end;
		fz_dict_puts(xref^.trailer, 'ID', id);
		fz_drop_obj(id);
	end;

	fz_free(list);
	result:= fz_okay;
  exit;

cleanup:
	if (encrypt<>nil) then fz_drop_obj(encrypt);
	if (id<>nil) then  fz_drop_obj(id);
	if (root<>nil) then  fz_drop_obj(root);
	if (info<>nil) then fz_drop_obj(info);
	fz_free(list);
	result:= error; //* already rethrown */
end;

function pdf_repair_obj_stms(xref:ppdf_xref_s):fz_error;
var
	dict:pfz_obj_s;
	i:integer;
begin
	for i := 0 to xref^.len-1 do
	begin
		if (table_items(xref^.table)[i].stm_ofs<>0) then
		begin
			pdf_load_object(@dict, xref, i, 0);
			if (strcomp(fz_to_name(fz_dict_gets(dict, 'Type')), 'ObjStm')=0) then
				pdf_repair_obj_stm(xref, i, 0);
			fz_drop_obj(dict);
		end;
	end;

	result:= fz_okay;
end;


end.
