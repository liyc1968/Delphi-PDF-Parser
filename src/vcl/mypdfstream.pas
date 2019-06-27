unit mypdfstream;

interface
uses   SysUtils,Math,digtypes,base_object_functions,digcommtype,FZ_mystreams,fz_predictss,filt_faxdss,BASE_ERROR;


function pdf_load_object(objp:ppfz_obj_s;xref:ppdf_xref_s;  num, gen:integer):integer;
function pdf_open_stream_at(stmp:ppfz_stream_s; xref:ppdf_xref_s; num, gen:integer; dict:pfz_obj_s; stm_ofs:integer):integer;
function pdf_open_stream(stmp:ppfz_stream_s;xref: ppdf_xref_s; num:integer; gen:integer):integer;
function pdf_load_stream(bufp:ppfz_buffer_s; xref:ppdf_xref_s ;num, gen:integer):integer;
function pdf_is_stream(xref: ppdf_xref_s ; num, gen:integer):integer;
function pdf_cache_object(xref :ppdf_xref_s; num, gen:integer):integer;
function pdf_open_inline_stream(chain:pfz_stream_s; xref: ppdf_xref_s;stmobj: pfz_obj_s; length:integer) :pfz_stream_s;
implementation
 uses pdf_crypt,fz_filterss,filt_lzwdss,filt_dctdss;



 function pdf_load_obj_stm(xref:ppdf_xref_s;num,gen:integer;buf:pchar; cap:integer):integer;
var
	error:integer;
	stm:pfz_stream_s;
	objstm:pfz_obj_s;
  numbuf,ofsbuf:pinteger;
	obj:pfz_obj_s;
	first,count,i, n:integer;
	tok:pdf_kind_e;
  s:string;
  p:pchar;
  label    cleanupstm,cleanupbuf;
begin
	error := pdf_load_object(@objstm, xref, num, gen);
	if (error<0) then
  begin
	 result:= fz_rethrow(error, 'cannot load object stream object (%d %d R)', [num, gen]);

   exit;
   end;

	count := fz_to_int(fz_dict_gets(objstm, 'N'));
	first := fz_to_int(fz_dict_gets(objstm, 'First'));
  // setlength(numbuf, count);
  // setlength(ofsbuf, count);
 	numbuf := fz_calloc(count, sizeof(integer));
 	ofsbuf := fz_calloc(count, sizeof(integer));

	error := pdf_open_stream(@stm, xref, num, gen);
	if (error<0 ) then
	begin
		error :=fz_rethrow(error, 'cannot open object stream (%d %d R)', [num, gen]);
		goto cleanupbuf;
	end;

	for i := 0 to count-1 do
	begin
		error := pdf_lex(@tok, stm, buf, cap, @n);
		if (error<=0) or  (tok <> PDF_TOK_INT)  then
		begin
			error := fz_rethrow(error, 'corrupt object stream (%d %d R)', [num, gen]);
			goto cleanupstm;
		end;

		integer_items(numbuf)[i] := atoi(buf);

		error := pdf_lex(@tok, stm, buf, cap, @n);
		if (error<=0) or  (tok <> PDF_TOK_INT) then
		begin
		 	error := fz_rethrow(error, 'corrupt object stream (%d %d R)',[ num, gen]);
      //error:=-1;
			goto cleanupstm;
		end;
    s:=buf;
    s:=trim(s);
		integer_items(ofsbuf)[i] := strtoint(s);
	
	end;
  fz_seek(stm, first, 0);


	for i := 0 to count-1 do
	begin

    fz_seek(stm, first + integer_items(ofsbuf)[i], 0);

		error := pdf_parse_stm_obj(@obj, xref, stm, buf, cap);
		if (error<=0)  then
		begin
			error := fz_rethrow(error, 'cannot parse object %d in stream (%d %d R)', [i, num, gen]);
			goto cleanupstm;
	  end;

		if (integer_items(numbuf)[i] < 1) or (integer_items(numbuf)[i] >= xref.len) then
		begin
			fz_drop_obj(obj);
			error := fz_throw('object id (%d 0 R) out of range (0..%d)', [integer_items(numbuf)[i], xref^.len - 1]);
			goto cleanupstm;
		end;

		if (table_items(xref.table)[integer_items(numbuf)[i]].type1 = ord('o')) and  (table_items(xref.table)[integer_items(numbuf)[i]].ofs = num)  then
		begin
			if (table_items(xref.table)[integer_items(numbuf)[i]].obj<>nil) then
				fz_drop_obj(table_items(xref.table)[integer_items(numbuf)[i]].obj);
			 table_items(xref.table)[integer_items(numbuf)[i]].obj := obj;
		end
		else
		begin
			fz_drop_obj(obj);
		end;
	end;

	fz_close(stm);
 	fz_free(ofsbuf);
 	fz_free(numbuf);
	fz_drop_obj(objstm);
  result:=1;
  exit;
//	return fz_okay;

cleanupstm:
 	fz_close(stm);
 sleep(0);
cleanupbuf:
//	fz_free(ofsbuf);
//	fz_free(numbuf);
	fz_drop_obj(objstm);
	result:= error; //* already rethrown */
end;



function pdf_cache_object(xref :ppdf_xref_s; num, gen:integer):integer;
var
	error:integer;
	x:ppdf_xref_entry_s;
	rnum, rgen:integer;
begin
	if (num < 0) or (num >= xref.len) then
  begin
	 result:= fz_throw('object out of range (%d %d R); xref size %d', [num, gen, xref^.len]);
   exit;
  end;
	x := @table_items(xref^.table)[num];

	if (x^.obj<>nil) then
  begin
		//return fz_okay;
    result:=1;
    exit;
  end;
	if (x^.type1 =ord( 'f')) then
	begin
		x^.obj := fz_new_null();
		//return fz_okay;
    result:=1;
    exit;
	end
	else if (x^.type1 = ord('n')) then
	begin
    fz_seek(xref.myfile, x.ofs, 0);

		error := pdf_parse_ind_obj( @x^.obj, xref, xref.myfile, @xref.scratch, sizeof(xref.scratch), @rnum, @rgen, @x^.stm_ofs);
		if (error<0) then
    begin
			result:= fz_rethrow(error, 'cannot parse object (%d %d R)',[ num, gen]);

      exit;
    end;
		if (rnum <> num)  then
    begin
		 result:= fz_throw('found object (%d %d R) instead of (%d %d R)', [rnum, rgen, num, gen]);

      exit;
    end;

		if (xref.crypt<>nil) then
			pdf_crypt_obj(xref.crypt, x^.obj, num, gen);
	end
	else if (x^.type1 =ord( 'o')) then
	begin
		if (x^.obj=nil) then
		begin
			error := pdf_load_obj_stm(xref, x^.ofs, 0, @xref.scratch, sizeof(xref.scratch));
			if (error<0) then
     begin                       				//return fz_rethrow(error, "cannot load object stream containing object (%d %d R)", num, gen);
        result:=fz_rethrow(error, 'cannot load object stream containing object (%d %d R)', [num, gen]);
        exit;
      end;
			if (x.obj=nil) then
      begin
				RESULT:= fz_throw('object (%d %d R) was not found in its object stream', [num, gen]);

        exit;
      end;
		end;
	end
	else
	begin
		result:= fz_throw('assert: corrupt xref struct');
    exit;
	end;

	result:=1; // fz_okay;
end;

function pdf_load_object(objp:ppfz_obj_s; xref:ppdf_xref_s;  num, gen:integer):integer;
var
	error:integer;
begin
	error := pdf_cache_object(xref, num, gen);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot load object (%d %d R) into cache', [num, gen]);

    exit;
  end;

	assert(table_items(xref.table)[num].obj<>nil);

	objp^ := fz_keep_obj(table_items(xref.table)[num].obj);
  result:=1;
  exit;
 //	return fz_okay;
end;


function pdf_is_stream(xref: ppdf_xref_s ; num, gen:integer):integer;
var
error:integer;
begin
	if (num < 0) or (num >= xref.len) then
  begin
		result:=0;
    exit;
  end;
	error := pdf_cache_object(xref, num, gen);
	if (error<0) then
	begin
	  fz_catch(error, 'cannot load object, ignoring error');
	  result:=0;
    exit;
	end;
   if table_items(xref.table)[num].stm_ofs > 0 then
  	result:=1
    else
    result:=0;
end;

//*           * Scan stream dictionary for an explicit /Crypt filter */
function pdf_stream_has_crypt(stm:pfz_obj_s):integer;
var
filters,obj:pfz_obj_s;
i:integer;
begin

	filters := fz_dict_getsa(stm, 'Filter', 'F');
	if (filters<>nil) then
	begin
		if (strcOmp(fz_to_name(filters), 'Crypt')=0)  THEN
    BEGIN
			result:= 1;
      exit;
    end;
		if (fz_is_array(filters))  then
		begin
			for i := 0 to fz_array_len(filters)-1 do
			begin
				obj := fz_array_get(filters, i);
				if (strcomp(fz_to_name(obj), 'Crypt')=0) then
        begin
					result:=1;
          exit;
        end;
			end;
		end;
	end;
	result:=0;
end;

//* * Create a filter given a name and param dictionary. */
function build_filter(chain:pfz_stream_s;xref:ppdf_xref_s; f:pfz_obj_s; p:pfz_obj_s; num, gen:integer):pfz_stream_s;
var
error:integer;
s:pchar;
globals:pfz_buffer_s;
obj:pfz_obj_s;
name:		pfz_obj_s ;
begin
	s := fz_to_name(f);

	if (strcomp(s, 'ASCIIHexDecode')=0) or  (strcomp(s, 'AHx')=0) then
  begin
		//return fz_open_ahxd(chain);
    result:=fz_open_ahxd(chain);
    exit;
  end

	else if (strcomp(s, 'ASCII85Decode')=0) or (strcomp(s, 'A85')=0) then
  begin
	 //	return fz_open_a85d(chain);
    result:=fz_open_a85d(chain);
    exit;
  end

	else if (strcomp(s, 'CCITTFaxDecode')=0) or  (strcomp(s, 'CCF')=0) then
  begin
		result:= fz_open_faxd(chain, p);
    exit;
  end

	else if (strcomp(s, 'DCTDecode')=0) or (strcomp(s, 'DCT')=0) then
  begin
		result:=fz_open_dctd(chain, p) ;
    exit;
  end
	else if (strcomp(s, 'RunLengthDecode')=0) or (strcomp(s, 'RL')=0)  then
  begin
		result:= fz_open_rld(chain);
    exit;
  end
	else if (strcomp(s,'FlateDecode')=0) or (strcomp(s, 'Fl')=0) then
	begin
		obj := fz_dict_gets(p, 'Predictor');
		if (fz_to_int(obj) > 1)  then
    begin
			result:=fz_open_predict(fz_open_flated(chain), p);
      exit;
    end;
		result:= fz_open_flated(chain);
    exit;
	end

	else if (strcomp(s, 'LZWDecode')=0) or (strcomp(s,'LZW')=0) then
	begin
		obj := fz_dict_gets(p, 'Predictor');
		if (fz_to_int(obj)>1 ) then
    begin
			result:=fz_open_predict(fz_open_lzwd(chain, p), p);
      exit;
    end;
		result:=fz_open_lzwd(chain, p);
    exit;
	end

	else if (strcomp(s, 'JBIG2Decode')=0) then
	begin
		obj := fz_dict_gets(p, 'JBIG2Globals');
		if (obj<>nil) then
		begin
			error := pdf_load_stream(@globals, xref, fz_to_num(obj), fz_to_gen(obj));
			if (error<0) then
				fz_catch(error, 'cannot load jbig2 global segments');
       // sleep(0);
			chain := fz_open_jbig2d(chain, globals);
			fz_drop_buffer(globals);
			result:= chain;
      exit;
		end;
		result:= fz_open_jbig2d(chain,nil);
    exit;
	end

	else if (strcomp(s, 'JPXDecode')=0)  then
    begin
	   	result:= chain; //* JPX decoding is special cased in the image loading code */
      exit;
    end
	else if (strcomp(s, 'Crypt')=0) then
	begin

		if (xref.crypt=nil) then
		begin
			fz_warn('crypt filter in unencrypted document');
			result:= chain;
      exit
		end;

		name := fz_dict_gets(p, 'Name');
		if (fz_is_name(name)) then
    begin
			result:= pdf_open_crypt_with_filter(chain, xref.crypt, fz_to_name(name), num, gen);
      exit;
    end;
		result:= chain;
    exit;
	end;

	fz_warn('unknown filter name (%s)', [s]);
	result:= chain;
end;

//* * Build a chain of filters given filter names and param dicts. * If head is given, start filter chain with it. * Assume ownership of head. */

function build_filter_chain(chain:pfz_stream_s;xref:ppdf_xref_s; fs:pfz_obj_s; ps:pfz_obj_s;  num,  gen:integer):pfz_stream_s;
var
	f:pfz_obj_s;
	p:pfz_obj_s;
	i:integer;
begin
	for i:=0 to fz_array_len(fs)-1 do
	begin
		f := fz_array_get(fs, i);
		p := fz_array_get(ps, i);
		chain := build_filter(chain, xref, f, p, num, gen);
	end;

	result:=chain;
end;

{/*
 * Build a filter for reading raw stream data.
 * This is a null filter to constrain reading to the
 * stream length, followed by a decryption filter.
 */  }


function pdf_open_raw_filter(chain:pfz_stream_s; xref:ppdf_xref_s; stmobj:pfz_obj_s; num, gen:integer):pfz_stream_s;
var
  hascrypt,len:	integer;

  begin

	//* don't close chain when we close this filter */
 	fz_keep_stream(chain);

	len := fz_to_int(fz_dict_gets(stmobj, 'Length'));
	chain := fz_open_null(chain, len);

	hascrypt := pdf_stream_has_crypt(stmobj);
	if (xref.crypt<>nil) and (hascrypt=0) then
		chain := pdf_open_crypt(chain, xref.crypt, num, gen);

	result:= chain;
end;

{/*
 * Construct a filter to decode a stream, constraining
 * to stream length and decrypting.
 */ }
function pdf_open_filter(chain:pfz_stream_s; xref:ppdf_xref_s; stmobj:pfz_obj_s; num, gen:integer):pfz_stream_s;
var
 filters:	pfz_obj_s;
params :	pfz_obj_s;
begin
	filters := fz_dict_getsa(stmobj, 'Filter', 'F');
	params := fz_dict_getsa(stmobj, 'DecodeParms', 'DP');

	chain := pdf_open_raw_filter(chain, xref, stmobj, num, gen);

	if (fz_is_name(filters)) then
  begin
		result:= build_filter(chain, xref, filters, params, num, gen);
    exit;
  end;
	if (fz_array_len(filters) > 0) then
  begin
		result:= build_filter_chain(chain, xref, filters, params, num, gen);
    exit;
  end;
	result:= chain;
end;

{/*
 * Construct a filter to decode a stream, without
 * constraining to stream length, and without decryption.
 */}
function pdf_open_inline_stream(chain:pfz_stream_s; xref: ppdf_xref_s;stmobj: pfz_obj_s; length:integer) :pfz_stream_s;
var
 filters:	pfz_obj_s;
params :	pfz_obj_s;
begin
	filters := fz_dict_getsa(stmobj, 'Filter', 'F');
	params := fz_dict_getsa(stmobj, 'DecodeParms', 'DP');

	//* don't close chain when we close this filter */
	fz_keep_stream(chain);

	if (fz_is_name(filters)) then
  begin
		result:= build_filter(chain, xref, filters, params, 0, 0);
    exit;
  end;
	if (fz_array_len(filters) > 0) then
  begin
		result:= build_filter_chain(chain, xref, filters, params, 0, 0);
     exit;
  end;
	result:= fz_open_null(chain, length);
end;

{/*
 * Open a stream for reading the raw (compressed but decrypted) data.
 * Using xref->file while this is open is a bad idea.
 */  }
function pdf_open_raw_stream(stmp:pfz_stream_s;xref:ppdf_xref_s ; num, gen:integer):integer;
var
x: ppdf_xref_entry_s;
	error:integer;
begin
	if (num < 0) or (num >= xref.len) then
  begin
	 result:= fz_throw('object id out of range (%d %d R)', [num, gen]);
   exit;
  end;
	x := @table_items(xref.table)[num];

	error := pdf_cache_object(xref, num, gen);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot load stream object (%d %d R)', [num, gen]);
    exit;
  end;
	if (x^.stm_ofs<>0) then
	begin
		stmp := pdf_open_raw_filter(xref.myfile, xref, x^.obj, num, gen);
		//fz_seek(xref->file, x->stm_ofs, 0);

     fz_seek(xref.myfile, x^.stm_ofs, 0);
	 //	return fz_okay;
   result:=1;
   exit;
	end;

	result:=fz_throw('object is not a stream');
end;

{/*
 * Open a stream for reading uncompressed data.
 * Put the opened file in xref->stream.
 * Using xref->file while a stream is open is a Bad idea.
 */  }
function pdf_open_stream(stmp:ppfz_stream_s;xref: ppdf_xref_s; num:integer; gen:integer):integer;
var
x: ppdf_xref_entry_s;
error:integer;
begin

	if (num < 0) or (num >= xref.len)  then
  begin
		result:= fz_throw('object id out of range (%d %d R)', [num, gen]);
    exit;
  end;

	x := @table_items(xref.table)[num]; // + num;

	error := pdf_cache_object(xref, num, gen);
	if (error<0)  then
  begin
		result:=fz_rethrow(error, 'cannot load stream object (%d %d R)', [num, gen]);
    exit;
  end;

	if (x^.stm_ofs<>0) then
	begin
		stmp^ := pdf_open_filter(xref.myfile, xref, x^.obj, num, gen);


    fz_seek(xref.myfile, x^.stm_ofs, 0);
		//return fz_okay;
    result:=1;
    exit;
	end;

 result:= fz_throw('object is not a stream');
end;

function pdf_open_stream_at(stmp:ppfz_stream_s; xref:ppdf_xref_s; num, gen:integer; dict:pfz_obj_s; stm_ofs:integer):integer;
begin
   result:=-1;
	if (stm_ofs<>0) then
	begin
		stmp^ := pdf_open_filter(xref.myfile, xref, dict, num, gen);

	  	fz_seek(xref.myfile, stm_ofs, 0);

		//return fz_okay;
    result:=1;
    exit;
	end;
	result:= fz_throw('object is not a stream');



end;

{/*
 * Load raw (compressed but decrypted) contents of a stream into buf.
 */   }

function pdf_load_raw_stream(bufp:ppfz_buffer_s; xref:ppdf_xref_s; num, gen:integer) :integer;
var
	error:integer;
	stm:pfz_stream_s;
	dict:pfz_obj_s;
	len:integer;
begin
	error := pdf_load_object(@dict, xref, num, gen);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot load stream dictionary (%d %d R)', [num, gen]);
    exit;
  end;
	len := fz_to_int(fz_dict_gets(dict, 'Length'));

	fz_drop_obj(dict);

	error := pdf_open_raw_stream(stm, xref, num, gen);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot open raw stream (%d %d R)', [num, gen]);
    exit;
  end;

	error := fz_read_all(bufp, stm, len);
	if (error<0) then
	begin
		fz_close(stm);
		result:=fz_rethrow(error, 'cannot read raw stream (%d %d R)', [num, gen]);
    exit;
	end;

 	fz_close(stm);
	//return fz_okay;
  result:=1;
end;

function pdf_guess_filter_length(len:integer; filter:pchar):integer;
begin
	if (strcomp(filter, 'ASCIIHexDecode')=0)   then
  begin
		result:=len div 2;
    exit;
  end;
	if (strcomp(filter, 'ASCII85Decode')=0) then
  begin
		result:= (len * 4) div 5;
    exit;
  end;
	if (strcomp(filter, 'FlateDecode')=0) then
  begin
		result:= len * 3;
    exit;
  end;

	if (strcomp(filter, 'RunLengthDecode')=0) then
  begin
		result:= len * 3;
    exit;
  end;
	if (strcomp(filter, 'LZWDecode')=0) then
  begin
		result:=len * 2;
  end;
	result:=len;
end;

//*  * Load uncompressed contents of a stream into buf. */

function pdf_load_stream(bufp:ppfz_buffer_s; xref:ppdf_xref_s ;num, gen:integer):integer;
var
	error:integer;
	stm:pfz_stream_s;
	dict, obj:pfz_obj_s;
	i, len:integer;
begin
	error := pdf_open_stream(@stm, xref, num, gen);
	if (error<0)  then
  begin
	  result:= fz_rethrow(error, 'cannot open stream (%d %d R)', [num, gen]);

    exit;
  end;

	error := pdf_load_object(@dict, xref, num, gen);
	if (error<0)  then
  begin
	  result:= fz_rethrow(error, 'cannot load stream dictionary (%d %d R)', [num, gen]);

    exit;
  end;

	len := fz_to_int(fz_dict_gets(dict, 'Length'));
	obj := fz_dict_gets(dict, 'Filter');
	len := pdf_guess_filter_length(len, fz_to_name(obj));
	for i := 0 to fz_array_len(obj)-1 do
  begin
		len := pdf_guess_filter_length(len, fz_to_name(fz_array_get(obj, i)));
  end;
	fz_drop_obj(dict);
  //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692260 */
	//error := fz_read_all(bufp, stm, len);
  error := fz_read_all2(bufp, stm, len, 0);
	if (error<=0)  then
	begin
		fz_close(stm);
	 result:=	 fz_rethrow(error, 'cannot read raw stream (%d %d R)', [num, gen]);
   exit;
	end;

  fz_close(stm);
	result:=1;
end;


end.
 