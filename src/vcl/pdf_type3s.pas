unit pdf_type3s;

interface
uses
 SysUtils,Math,digtypes,BASE_ERROR;

function  pdf_load_type3_font(fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s; rdb, dict:pfz_obj_s):integer;

implementation
uses base_object_functions,pdf_interprets,pdf_fontss,fz_textx,pdf_encodings,pdf_camp_loads,
pdf_unicodess,pdf_metricss,mypdfstream;

function pdf_run_glyph_func(xref:ppdf_xref_s; rdb:pfz_obj_s; contents:pfz_buffer_s; dev:pfz_device_s; ctm:fz_matrix ):integer ;
begin
	result:= pdf_run_glyph(xref, rdb, contents, dev, ctm);
end;

function  pdf_load_type3_font(fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s; rdb, dict:pfz_obj_s):integer;
var
	error:integer;
	buf:array[0..255] of char;
	estrings:parray256; //array[0..255] of pchar;
	fontdesc:ppdf_font_desc_s;
	encoding:pfz_obj_s;
  widths:pfz_obj_s;
	charprocs:pfz_obj_s;
	obj:pfz_obj_s;
	 first, last:integer;
	 i, k, n:integer;
	bbox:fz_rect ;
	 matrix:fz_matrix_s;
   	base, diff, item:pfz_obj_s;
    w:single;

  label cleanup;
begin
	obj := fz_dict_gets(dict, 'Name');
	if (fz_is_name(obj)) then
		fz_strlcpy(@buf, fz_to_name(obj), sizeof( buf))
	else
		//sprintf(buf, 'Unnamed-T3');
    buf:='Unnamed-T3'+#0;

	fontdesc := pdf_new_font_desc();

	obj := fz_dict_gets(dict, 'FontMatrix');
	matrix := pdf_to_matrix(obj);

	obj := fz_dict_gets(dict, 'FontBBox');
	bbox := pdf_to_rect(obj);

	fontdesc^.font := fz_new_type3_font(buf, matrix);

	fz_set_font_bbox(fontdesc^.font, bbox.x0, bbox.y0, bbox.x1, bbox.y1);

	//* Encoding */

	for i := 0 to 256-1 do
		estrings[i] := nil;

	encoding := fz_dict_gets(dict, 'Encoding');
	if (encoding=nil) then
	begin
		error := fz_throw('syntaxerror: Type3 font missing Encoding');
		goto cleanup;
	end;

	if (fz_is_name(encoding)) then
		pdf_load_encoding(estrings, fz_to_name(encoding));

	if (fz_is_dict(encoding))  then
	begin


		base := fz_dict_gets(encoding, 'BaseEncoding');
		if (fz_is_name(base)) then
			pdf_load_encoding(estrings, fz_to_name(base));

		diff := fz_dict_gets(encoding, 'Differences');
		if (fz_is_array(diff)) then
		begin
			n := fz_array_len(diff);
			k := 0;
			for i := 0 to n-1 do
			begin
				item := fz_array_get(diff, i);
				if (fz_is_int(item)) then
					k := fz_to_int(item);
				if (fz_is_name(item))  then
        begin
					estrings[k] := fz_to_name(item);
          k:=k+1;
        end;
				if (k < 0) then k := 0;
				if (k > 255) then k := 255;
			end;
		end;
	end;

	fontdesc^.encoding := pdf_new_identity_cmap(0, 1);

	error := pdf_load_to_unicode(fontdesc, xref, @estrings, nil, fz_dict_gets(dict, 'ToUnicode'));
	if (error<0) then
		goto cleanup;

	//* Widths */

	pdf_set_default_hmtx(fontdesc, 0);

	first := fz_to_int(fz_dict_gets(dict, 'FirstChar'));
	last := fz_to_int(fz_dict_gets(dict, 'LastChar'));

	widths := fz_dict_gets(dict, 'Widths');
	if (widths=nil) then
	begin
		error:= fz_throw('syntaxerror: Type3 font missing Widths');
		goto cleanup;
	end;

	for i := first to last-1 do
	begin
		w := fz_to_real(fz_array_get(widths, i - first));
		w := fontdesc^.font^.t3matrix.a * w * 1000;
		single_items(fontdesc^.font^.t3widths)[i] := w * 0.001;
		pdf_add_hmtx(fontdesc, i, i, trunc(w));
	end;

	pdf_end_hmtx(fontdesc);

	//* Resources -- inherit page resources if the font doesn't have its own */

	fontdesc^.font^.t3resources := fz_dict_gets(dict, 'Resources');
	if (fontdesc^.font^.t3resources=nil) then
		fontdesc^.font^.t3resources := rdb;
	if (fontdesc^.font^.t3resources<>nil) then
		fz_keep_obj(fontdesc^.font^.t3resources);
	if (fontdesc^.font^.t3resources=nil) then
  begin
		fz_warn('no resource dictionary for type 3 font!');

  end;

	fontdesc^.font^.t3xref := xref;
	fontdesc^.font^.t3run := @pdf_run_glyph_func;

	//* CharProcs */

	charprocs := fz_dict_gets(dict, 'CharProcs');
	if (charprocs=nil) then
	begin
		error := fz_throw('syntaxerror: Type3 font missing CharProcs');
		goto cleanup;
	end;

	for i := 0 to 256-1 do
	begin
		if (estrings[i]<>#0)then
		begin
			obj := fz_dict_gets(charprocs, estrings[i]);
			if (pdf_is_stream(xref, fz_to_num(obj), fz_to_gen(obj)))<>0 then
			begin
				error := pdf_load_stream(@fz_buffer_s_items(fontdesc^.font^.t3procs)[i], xref, fz_to_num(obj), fz_to_gen(obj));
				if (error<0) then
					goto cleanup;
			end;
		end;
	end;

	fontdescp^ := fontdesc;
	//return fz_okay;
  result:=1;
  exit;

cleanup:
	fz_drop_font(fontdesc^.font);
	fz_free(fontdesc);
	result:=fz_rethrow(error, 'cannot load type3 font (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
  
end;


end.
