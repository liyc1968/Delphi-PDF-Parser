unit pdf_camp_parses;

interface
uses 
 SysUtils,Math,mylimits,digtypes,digcommtype,base_error;


function
pdf_parse_cmap(cmapp:pppdf_cmap_s; file1:pfz_stream_s):integer ;
implementation
uses base_object_functions,pdf_cmaps;

function pdf_cmap_token_from_keyword(key:pchar):pdf_kind_e;
begin
	if (strcomp(key, 'usecmap')=0) then
  begin
    result:=TOK_USECMAP;
    exit;
  end;
	if (strcomp(key, 'begincodespacerange')=0)  then
  begin
    result:=TOK_BEGIN_CODESPACE_RANGE;
    exit;
  end;

	if (strcomp(key, 'endcodespacerange')=0) then
  begin
    result:=TOK_END_CODESPACE_RANGE;
    exit;
  end;

	if (strcomp(key, 'beginbfchar')=0) then
  begin
    result:=TOK_BEGIN_BF_CHAR;
    exit;
  end;

	if (strcomp(key, 'endbfchar')=0) then
  begin
    result:=TOK_END_BF_CHAR;
    exit;
  end;

	if (strcomp(key, 'beginbfrange')=0) then
  begin
    result:=TOK_BEGIN_BF_RANGE;
    exit;
  end;

	if (strcomp(key, 'endbfrange')=0) then
  begin
    result:=TOK_END_BF_RANGE;
    exit;
  end;
	if (strcomp(key, 'begincidchar')=0) then
  begin
    result:=TOK_BEGIN_CID_CHAR;
    exit;
  end;
	if (strcomp(key, 'endcidchar')=0) then
  begin
    result:=TOK_END_CID_CHAR;
    exit;
  end;
	if (strcomp(key, 'begincidrange')=0) then
  begin
    result:=TOK_BEGIN_CID_RANGE;
    exit;
  end;
	if (strcomp(key, 'endcidrange')=0) then
  begin
    result:=TOK_END_CID_RANGE;
    exit;
  end;
	if (strcomp(key, 'endcmap')=0) then
  begin
    result:=TOK_END_CMAP;
    exit;
  end;
	result:= PDF_TOK_KEYWORD;
end;

function pdf_code_from_string(buf:pchar; len:integer):integer;
var
	a:integer;
begin
  a:=0;

	while (len<>0) do
  begin
    len:=len-1;
		a := (a shl 8) or ord(buf^); // *(unsigned char *)buf++;
    inc(buf);
  end;
	result:=a;
end;

function
pdf_lex_cmap(tok:ppdf_kind_e; file1:pfz_stream_s; buf:pchar; n:integer;  sl:pinteger):integer;
var
	error:integer;
begin

	error := pdf_lex(tok, file1, buf, n, sl);
	if (error<0)  then
  begin
	 result:= fz_rethrow(error, 'cannot parse cmap token');
   exit;
  end;

	if (tok^ = PDF_TOK_KEYWORD) then
		tok^ := pdf_cmap_token_from_keyword(buf);

	result:= 1;
end;

function
pdf_parse_cmap_name(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
begin
	error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
	if (error<0)  then
  begin
  		result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
  end;
	if (tok = PDF_TOK_NAME) then
		fz_strlcpy(@cmap^.cmap_name, @buf, sizeof(cmap^.cmap_name))
	else
	 	fz_warn('expected name after CMapName in cmap');


	result:=1;
end;

function
pdf_parse_wmode(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
begin
	error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
	if (error<0)  then
  begin
	  result:= fz_rethrow(error, 'syntaxerror in cmap');
    exit;
  end;

	if (tok = PDF_TOK_INT) then
		pdf_set_wmode(cmap, atoi(buf))
	else
	 	fz_warn('expected integer after WMode in cmap');


	result:=1;
end;

function
pdf_parse_codespace_range(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	lo, hi:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = TOK_END_CODESPACE_RANGE) then
    begin
		 //	return fz_okay;
      result:=1;
      exit;
    end

		else if (tok = PDF_TOK_STRING) then
		begin
			lo := pdf_code_from_string(buf, len);
			error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'syntaxerror in cmap');
        exit;
      end;
			if (tok = PDF_TOK_STRING) then
			begin
				hi := pdf_code_from_string(buf, len);
				pdf_add_codespace(cmap, lo, hi, len);
			end
			else break;
	  end

		else break;
	end;
  result:= fz_throw('expected string or endcodespacerange');
end;

function
pdf_parse_cid_range(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	lo, hi, dst:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = TOK_END_CID_RANGE) then
    begin
		 //	return fz_okay;
      result:=1;
      exit;
    end

		else if (tok <> PDF_TOK_STRING) then
    begin
			result:= fz_throw('expected string or endcidrange');
      exit;
    end;

		lo := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof( buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;
		if (tok <> PDF_TOK_STRING) then
    begin
		  result:= fz_throw('expected string');
      exit;
    end;

		hi := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, '"syntaxerror in cmap');
      exit;
    end;
		if (tok <> PDF_TOK_INT) then
    begin
		 result:= fz_throw('expected integer');
     exit;
     end;

		dst := atoi(buf);

		pdf_map_range_to_range(cmap, lo, hi, dst);
	end;
end;

function pdf_parse_cid_char(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	 src, dst:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = TOK_END_CID_CHAR)  then
    begin
			//return fz_okay;
      result:=1;
      exit;
    end

		else if (tok <> PDF_TOK_STRING) then
    begin
			result:= fz_throw('expected string or endcidchar');
      exit;
    end;

		src := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;
		if (tok <> PDF_TOK_INT) then
    begin
		 result:= fz_throw('expected integer');
     exit;
    end;

		dst := atoi(buf);

		pdf_map_range_to_range(cmap, src, src, dst);
	end;
end;

function
pdf_parse_bf_range_array(cmap:ppdf_cmap_s; file1:pfz_stream_s; lo, hi:integer):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	 dst:array[0..256-1] of integer;
	i:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:=fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = PDF_TOK_CLOSE_ARRAY) then
    begin
			//return fz_okay;
      result:=1;
      exit;
    end

		//* Note: does not handle [ /Name /Name ... ] */
		else if (tok <> PDF_TOK_STRING) then
    begin
			result:= fz_throw('expected string or ]');
      exit;
    end;

		if (len div 2)<>0 then
		begin
			for i := 0 to  trunc(len / 2)-1 do
      begin
				dst[i] := pdf_code_from_string(buf + i * 2, 2);
      end;
			pdf_map_one_to_many(cmap, lo, @dst, len div 2);
		end;

		lo:=lo+1;
	end;
end;

function 
pdf_parse_bf_range(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	lo, hi, dst:integer;
  dststr:array[0..256-1] of integer;
	i:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
		  result:= fz_rethrow(error, 'syntaxerror in cmap');
           result:=-1;
      exit;
    end;

		if (tok = TOK_END_BF_RANGE) then
    begin
			//return fz_okay;
       result:=1;
      exit;
    end

		else if (tok <> PDF_TOK_STRING) then
    begin
     	result:= fz_throw('expected string or endbfrange');

      exit;
    end;

		lo := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof( buf), @len);
		if (error<0)  then
    begin
		  result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end  ;

		if (tok <> PDF_TOK_STRING) then
    begin
			result:= fz_throw('expected string');
      exit;
    end;

		hi := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = PDF_TOK_STRING) then
		begin
			if (len = 2) then
			begin
				dst := pdf_code_from_string(buf, len);
				pdf_map_range_to_range(cmap, lo, hi, dst);
			end
			else
			begin


				if (len div 2)<>0 then
				begin
					for i := 0 to len div 2-1 do
						dststr[i] := pdf_code_from_string(buf + i * 2, 2);

					while (lo <= hi) do
					begin
						dststr[i-1]:=dststr[i-1]+1;
						pdf_map_one_to_many(cmap, lo, @dststr, i);
						lo:=lo+1;;
					end;
				end;
			end;
		end

		else if (tok = PDF_TOK_OPEN_ARRAY) then
		begin
			error := pdf_parse_bf_range_array(cmap, file1, lo, hi);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot map bfrange');
        exit;
      end;
		end

		else
		begin
			result:= fz_throw('expected string or array or endbfrange');
      exit;
    end;
	end;
end;

function
pdf_parse_bf_char(cmap:ppdf_cmap_s; file1:pfz_stream_s):integer;
var
	error:integer;
	buf:array[0..256-1] of char;
	tok:pdf_kind_e;
	len:integer;
	dst:array[0..256-1] of integer;
	src:integer;
	i:integer;
begin
	while (true) do
	begin
		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
	    result:=fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		if (tok = TOK_END_BF_CHAR) then
    begin
			//return fz_okay;
      result:=1;
      exit;
    end

		else if (tok <> PDF_TOK_STRING) then
    begin
			result:=fz_throw('expected string or endbfchar');
      exit;
    end;

		src := pdf_code_from_string(buf, len);

		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'syntaxerror in cmap');
      exit;
    end;

		//* Note: does not handle /dstName */
		if (tok <> PDF_TOK_STRING) then
    begin
			result:= fz_throw('expected string');
      exit;
    end;

		if (len div 2)<>0 then
		begin
			for i := 0 to (len div 2)-1 do
				dst[i] := pdf_code_from_string(buf + i * 2, 2);
			pdf_map_one_to_many(cmap, src, @dst, i);
		end;
	end;
end;

function
pdf_parse_cmap(cmapp:pppdf_cmap_s; file1:pfz_stream_s):integer ;
var
	error:integer;
	cmap:ppdf_cmap_s;
	key:array[0..63] of char;
	buf:array[0..255] of char;
	len:integer;
  tok:pdf_kind_e;
  label cleanup;
begin
	cmap := pdf_new_cmap();

	strcopy(key, '.notdef');

	while (true)  do
	begin

		error := pdf_lex_cmap(@tok, file1, buf, sizeof(buf), @len);
		if (error<0)  then
		begin
			 error:= fz_rethrow(error, 'syntaxerror in cmap');
      //error:=-1;
			goto cleanup;
		end;

		if (tok = PDF_TOK_EOF) or (tok = TOK_END_CMAP) then
    begin

			break;
    end
		else if (tok = PDF_TOK_NAME) then
		begin
			if (strcomp(buf, 'CMapName')=0) then
			begin
				error := pdf_parse_cmap_name(cmap, file1);
				if (error<0)  then
				begin
					error := fz_rethrow(error, 'syntaxerror in cmap after CMapName');
					goto cleanup;
				end;
			end
			else if (strcomp(buf, 'WMode')=0) then
			begin
				error := pdf_parse_wmode(cmap, file1);
				if (error<0)  then
				begin
					error := fz_rethrow(error, 'syntaxerror in cmap after WMode');
					goto cleanup;
				end;
			end
			else
				fz_strlcpy(@key, @buf, sizeof(key));
		end

		else if (tok = TOK_USECMAP) then
		begin
			fz_strlcpy(@cmap^.usecmap_name, @key, sizeof(cmap^.usecmap_name));
		end

		else if (tok = TOK_BEGIN_CODESPACE_RANGE) then
		begin
			error := pdf_parse_codespace_range(cmap, file1);
			if (error<0)  then
			begin
				error:=  fz_rethrow(error, 'syntaxerror in cmap codespacerange');
				goto cleanup;
			end;
		end

		else if (tok = TOK_BEGIN_BF_CHAR) then
		begin
			error := pdf_parse_bf_char(cmap, file1);
			if (error<0)  then
			begin
				error:= fz_rethrow(error, 'syntaxerror in cmap bfchar');
        goto cleanup;
			end;
		end

		else if (tok = TOK_BEGIN_CID_CHAR) then
		begin
			error := pdf_parse_cid_char(cmap, file1);
			if (error<0)  then
			begin
				error:= fz_rethrow(error, 'syntaxerror in cmap cidchar');
				goto cleanup;
			end;
		end

		else if (tok = TOK_BEGIN_BF_RANGE) then
		begin
			error := pdf_parse_bf_range(cmap, file1);
			if (error<0)  then
			begin
				error:= fz_rethrow(error, 'syntaxerror in cmap bfrange');
        
				goto cleanup;
			end;
		end

		else if (tok = TOK_BEGIN_CID_RANGE) then
		begin
			error := pdf_parse_cid_range(cmap, file1);
			if (error<0)  then
			begin
				error:= fz_rethrow(error, 'syntaxerror in cmap cidrange');
				goto cleanup;
			end;
		end;

		//* ignore everything else */
	end;
 // OutputDebugString(pchar(inttostr(pdf_range_s_items(cmap^.ranges)[275].low)));


	pdf_sort_cmap1(cmap);

	cmapp^ := cmap;

	result:= 1;
  exit;

cleanup:
	pdf_drop_cmap(cmap);
	result:= error; //* already rethrown */
end;


end.
