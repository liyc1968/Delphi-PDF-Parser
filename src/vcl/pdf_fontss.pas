unit pdf_fontss;

interface
uses
 SysUtils, Math,digtypes,freetype,base_error;
function pdf_load_builtin_font(fontdesc:ppdf_font_desc_s; fontname:pchar):integer;
function
pdf_load_font_descriptor(fontdesc:ppdf_font_desc_s; xref:ppdf_xref_s; dict:pfz_obj_s; collection:pchar; basefont:pchar):integer;
function pdf_keep_font(fontdesc:ppdf_font_desc_s):ppdf_font_desc_s;
function pdf_font_cid_to_gid(fontdesc:ppdf_font_desc_s; cid:integer):integer;
procedure pdf_drop_font(fontdesc:ppdf_font_desc_s) ;
function pdf_new_font_desc():ppdf_font_desc_s;
function
pdf_load_font(fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s;rdb:Pfz_obj_s; dict:Pfz_obj_s)  :integer;
implementation
uses base_object_functions,pdf_cmapss,pdf_findfiles,
fz_textx,mypdfstream,pdf_camp_loads,pdf_encodings,
pdf_unicodess,pdf_metricss,fz_pdf_store,pdf_type3s;

function is_dynalab(name:pchar):integer;
begin
	if (pos(name, 'HuaTian')<>0) then
  begin
		result:=1;
    exit;
  end;
	if (pos(name, 'MingLi')<>0)   then
  begin
		result:=1;
    exit;
  end;
	if ((pos(name, 'DF') =1) or (pos(name, '+DF')<>0)) then
  begin
		result:=1;
    exit;
  end;
	if ((pos(name, 'DLC')= 1) or (pos(name, '+DLC')<>0)) then
  begin
		result:=1;
    exit;
  end;
	result:= 0;
end;

function strcmp_ignore_space(a, b:pchar):integer;
begin

  if string(a)=string(b) then
  result:=0
  else
  result:=1;
  exit;
	while (true)  do
	begin

		while (a<>nil) and (a^ = ' ')   do
      inc(a);
		while (b<>nil) and (b^ = ' ')  do
			inc(b);
		if (a^ <> b^) then
    begin
			result:=1;
      exit;
    end;
		if (a^ = #0) then
    begin
      if a^<>b^ then
      result:=1
      else
      result:=0;
			exit;
    end;
		if (b^ = #0) then
    begin
     if a^<>b^ then
      result:=1
      else
      result:=0;
			exit;
     end;
		inc(a);
    inc(b);

	end;
end;

function clean_font_name(fontname:pchar):pchar;
var
i,k:integer;
begin

	for i := 0 to 14-1 do
  begin
    k:=0;
    while base_font_names[i][k]<>nil do
    begin
    k:=k+1;
			if (strcmp_ignore_space(base_font_names[i][k], fontname)=0) then
      begin
				result:= base_font_names[i][0];
        exit;
      end;
    end;
  end;
	result:= fontname;
end;

(*
 * FreeType and Rendering glue
 *)

//enum { UNKNOWN, TYPE1, TRUETYPE };

function ft_kind(face:FT_Face ):pdf_font_kind;
var
	kind :pchar;
begin
  kind := FT_Get_X11_Font_Format(face);
	if (strcomp(kind, 'TrueType')=0) then
  begin
		result:= TRUETYPE;
    exit;
  end;
	if (strcomp(kind, 'Type 1')=0) then
  begin
		result:= TYPE1;
    exit;
  end;
	if (strcomp(kind, 'CFF')=0) then
  begin
		result:= TYPE1;
    exit;
  end;
	if (strcomp(kind, 'CID Type 1')=0) then
  begin
		result:= TYPE1;
    exit;
  end;
	result:= UNKNOWN;
  exit;
end;

function ft_is_bold(face:FT_Face):integer;
begin
	result:= face^.style_flags and FT_STYLE_FLAG_BOLD;
end;

function ft_is_italic(face:FT_Face ):integer;
begin
	result:= face^.style_flags and FT_STYLE_FLAG_ITALIC;
end;

function ft_char_index(face:FT_Face ; cid:integer):integer;
var
  gid:integer;
begin
	gid := FT_Get_Char_Index(face, cid);
	if (gid = 0) then
		gid := FT_Get_Char_Index(face, $f000 + cid);

	//* some chinese fonts only ship the similarly looking 0x2026 */
	if (gid = 0) and (cid = $22ef) then
		gid := FT_Get_Char_Index(face, $2026);

	result:= gid;
end;

function ft_cid_to_gid(fontdesc:ppdf_font_desc_s; cid:integer):integer;
begin
	if (fontdesc^.to_ttf_cmap<>nil) then
	begin
		cid := pdf_lookup_cmap(fontdesc^.to_ttf_cmap, cid);
		result:= ft_char_index(fontdesc^.font^.ft_face, cid);
    exit;
	end;

	if (fontdesc^.cid_to_gid<>nil) then
  begin
		result:= word_items(fontdesc^.cid_to_gid)[cid];
    exit;
  end;

	result:= cid;
end;

function pdf_font_cid_to_gid(fontdesc:ppdf_font_desc_s; cid:integer):integer;
begin
	if (fontdesc^.font^.ft_face<>nil) then
  begin
		result:=ft_cid_to_gid(fontdesc, cid);
    exit;
  end;
	result:= cid;
end;

function ft_width(fontdesc:ppdf_font_desc_s; cid:integer):integer;
var
 gid,fterr:integer;
begin
	gid := ft_cid_to_gid(fontdesc, cid);
	fterr := FT_Load_Glyph(fontdesc^.font^.ft_face, gid,
			FT_LOAD_NO_HINTING or FT_LOAD_NO_BITMAP or FT_LOAD_IGNORE_TRANSFORM);
	if (fterr<>0) then
	begin
		fz_warn('freetype load glyph (gid %d): %s', [gid, ft_error_string(fterr)]);
		result:=0;
    exit;
	end;
	result:=(fontdesc^.font^.ft_face)^.glyph^.advance.x;
end;

function lookup_mre_code(name:pchar):integer;
var
	 i:integer;
begin
	for i := 0 to 255 do
		if  (pdf_mac_roman[i]<>nil) and  (strcomp(name, pdf_mac_roman[i])=0) then
    begin
			result:= i;
      exit;
    end;
	result:= -1;
end;

(*
 * Load font files.
 *)

function pdf_load_builtin_font(fontdesc:ppdf_font_desc_s; fontname:pchar):integer;
var
	 error:integer;
	data:pbyte;
	len:word;
begin
	data := pdf_find_builtin_font(fontname, @len);
	if (data=nil) then
  begin
		 result:= fz_throw('cannot find builtin font: "%s"', [fontname]);
    exit;
  end;

	error := fz_new_font_from_memory(@fontdesc^.font, data, len, 0);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load freetype font from memory');
    exit;
  end;

	if (strcomp(fontname, 'Symbol')=0) or (strcomp(fontname, 'ZapfDingbats')=0) then
		fontdesc^.flags :=fontdesc^.flags or ord(PDF_FD_SYMBOLIC);

	result:=1;
end;

function pdf_load_substitute_font(fontdesc:ppdf_font_desc_s;  mono, serif, bold, italic:integer):integer;
var
	error:integer;
	data:pbyte;
	len:dword;
begin
	data := pdf_find_substitute_font(mono, serif, bold, italic, @len);
	if (data=nil) then
  begin
		result:= fz_throw('cannot find substitute font');
   // result:=-1;
    exit;
  end;

	error := fz_new_font_from_memory(@fontdesc^.font, data, len, 0);
	if (error<0)  then
  begin
	 result:= fz_rethrow(error, 'cannot load freetype font from memory');
    result:=-1;
    exit;
  end;

	fontdesc^.font^.ft_substitute := 1;
  if  (bold<>0) and (ft_is_bold(fontdesc^.font^.ft_face)<>0) then
  	fontdesc^.font^.ft_bold :=1
    else
       fontdesc^.font^.ft_bold :=0;
  if (italic<>0) and (ft_is_italic(fontdesc^.font^.ft_face)<>0) then
      fontdesc^.font^.ft_italic:=1
      else
      fontdesc^.font^.ft_italic:=0;
	result:=1;

end;

function  pdf_load_substitute_cjk_font(fontdesc:ppdf_font_desc_s;  ros, serif:integer):integer;
var
	error:integer;
	data:pbyte;
	len:dword;
begin
	data := pdf_find_substitute_cjk_font(ros, serif, @len);
	if (data=nil) then
  begin
		result:=fz_throw('cannot find builtin CJK font');

    exit;
  end;

	error := fz_new_font_from_memory(@fontdesc^.font, data, len, 0);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load builtin CJK font');

    exit;
  end;

	fontdesc^.font^.ft_substitute := 1;
	result:=1;
end;

function pdf_load_system_font( fontdesc:ppdf_font_desc_s; fontname:pchar;collection:pchar):integer;
var
	error,bold,italic,serif,mono:integer;
begin
  bold := 0;
	italic := 0;
	serif := 0;
	mono := 0;

	if (pos(fontname, 'Bold')<>0) then
		bold := 1;
	if (pos(fontname, 'Italic')<>0) then
		italic := 1;
	if (pos(fontname, 'Oblique')<>0) then
		italic := 1;

	if (fontdesc^.flags and PDF_FD_FIXED_PITCH)<>0 then
		mono := 1;
	if (fontdesc^.flags and PDF_FD_SERIF)<>0 then
		serif := 1;
	if (fontdesc^.flags and PDF_FD_ITALIC)<>0 then
		italic := 1;
	if (fontdesc^.flags and PDF_FD_FORCE_BOLD)<>0 then
		bold := 1;

	if (collection<>nil) then
	begin
		if (strcomp(collection, 'Adobe-CNS1')=0)  then
    begin
			result:= pdf_load_substitute_cjk_font(fontdesc, PDF_ROS_CNS, serif);
      exit;
    end
		else if (strcomp(collection, 'Adobe-GB1')=0) then
    begin
			result:=pdf_load_substitute_cjk_font(fontdesc, PDF_ROS_GB, serif);
      exit;
    end
		else if (strcomp(collection, 'Adobe-Japan1')=0) then
    begin
			result:=pdf_load_substitute_cjk_font(fontdesc, PDF_ROS_JAPAN, serif);
      exit;
      end
		else if (strcomp(collection, 'Adobe-Korea1')=0)then
    begin
			result:=pdf_load_substitute_cjk_font(fontdesc, PDF_ROS_KOREA, serif);
      exit;
    end;
	  result:= fz_throw('unknown cid collection: %s', [collection]);
    exit;
	end;
   //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=691690 */
 if (fontdesc^.flags AND PDF_FD_SYMBOLIC)<>0 THEN
 BEGIN
   result:= fz_throw('symbolic font "%s" is missing', [fontname]);
   EXIT;
 END;
	error := pdf_load_substitute_font(fontdesc, mono, serif, bold, italic);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load substitute font');
    exit;
  end;

	result:=1; // fz_okay;
end;

function
pdf_load_embedded_font(fontdesc:ppdf_font_desc_s; xref:ppdf_xref_s; stmref:pfz_obj_s):integer;
var
	error:integer;
	buf:pfz_buffer_s;
begin
	error := pdf_load_stream(@buf, xref, fz_to_num(stmref), fz_to_gen(stmref));
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot load font stream (%d %d R)', [fz_to_num(stmref), fz_to_gen(stmref)]);
    exit;
  end;

	error := fz_new_font_from_memory(@fontdesc^.font, buf^.data, buf^.len, 0);
	if (error<0)  then
	begin
		fz_drop_buffer(buf);
	 	result:=fz_rethrow(error, 'cannot load embedded font (%d %d R)', [fz_to_num(stmref), fz_to_gen(stmref)]);

    exit;
  end;

	//* save the buffer so we can free it later */
	fontdesc^.font^.ft_data := buf^.data;
	fontdesc^.font^.ft_size := buf^.len;
	fz_free(buf); //* only free the fz_buffer struct, not the contained data */

	fontdesc^.is_embedded := 1;

	result:=1;
end;

(*
 * Create and destroy
 *)

function pdf_keep_font(fontdesc:ppdf_font_desc_s):ppdf_font_desc_s;
begin
	fontdesc^.refs:=fontdesc^.refs+1;
	result:= fontdesc;
end;

procedure pdf_drop_font(fontdesc:ppdf_font_desc_s) ;
begin
  if  fontdesc=nil then
  exit;
  fontdesc^.refs:=fontdesc^.refs-1;
	if (fontdesc<>nil) and (fontdesc^.refs = 0) then
	begin
		if (fontdesc^.font<>nil) then
			fz_drop_font(fontdesc^.font);
		if (fontdesc^.encoding<>nil) then
			pdf_drop_cmap(fontdesc^.encoding);
		if (fontdesc^.to_ttf_cmap<>nil) then
			pdf_drop_cmap(fontdesc^.to_ttf_cmap);
		if (fontdesc^.to_unicode<>nil) then
			pdf_drop_cmap(fontdesc^.to_unicode);
		fz_free(fontdesc^.cid_to_gid);
		fz_free(fontdesc^.cid_to_ucs);
		fz_free(fontdesc^.hmtx);
		fz_free(fontdesc^.vmtx);
		fz_free(fontdesc);
	end;
end;

function pdf_new_font_desc():ppdf_font_desc_s;
var
	fontdesc:ppdf_font_desc_s;
begin
	fontdesc := fz_malloc(sizeof(pdf_font_desc_s));
	fontdesc^.refs := 1;

	fontdesc^.font := Nil;

	fontdesc^.flags := 0;
	fontdesc^.italic_angle := 0;
	fontdesc^.ascent := 0;
	fontdesc^.descent := 0;
	fontdesc^.cap_height := 0;
	fontdesc^.x_height := 0;
	fontdesc^.missing_width := 0;

	fontdesc^.encoding := nil;
	fontdesc^.to_ttf_cmap := nil;
	fontdesc^.cid_to_gid_len := 0;
	fontdesc^.cid_to_gid := nil;

	fontdesc^.to_unicode := nil;
	fontdesc^.cid_to_ucs_len := 0;
	fontdesc^.cid_to_ucs := nil;

	fontdesc^.wmode := 0;

	fontdesc^.hmtx_cap := 0;
	fontdesc^.vmtx_cap := 0;
	fontdesc^.hmtx_len := 0;
	fontdesc^.vmtx_len := 0;
	fontdesc^.hmtx := nil;
	fontdesc^.vmtx := nil;

	fontdesc^.dhmtx.lo := $0000;
	fontdesc^.dhmtx.hi := $FFFF;
	fontdesc^.dhmtx.w := 1000;

	fontdesc^.dvmtx.lo := $0000;
	fontdesc^.dvmtx.hi := $FFFF;
	fontdesc^.dvmtx.x := 0;
	fontdesc^.dvmtx.y := 880;
	fontdesc^.dvmtx.w := -1000;

	fontdesc^.is_embedded := 0;

	result:= fontdesc;
end;

(*
 * Simple fonts (Type1 and TrueType)
 *)

function pdf_load_simple_font( fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	descriptor:pfz_obj_s;
	encoding:pfz_obj_s;
	widths:pfz_obj_s;
	etable:pword;
	fontdesc:ppdf_font_desc_s;
	face:FT_Face ;
	cmap,test:FT_CharMap;
	symbolic:integer;
	kind:pdf_font_kind;
  base, diff, item:pfz_obj_s;
	basefont:pchar;
	fontname:pchar;
	estrings:array256;
	ebuffer:array[0..256-1,0..32-1] of char;
	i, k, n:integer;
	fterr:integer;
  aglcode:integer;
  first, last,wid:integer;
 dupnames:ppchar;
  label cleanup , skip_encoding;
begin


  etable:=nil;
	basefont := fz_to_name(fz_dict_gets(dict, 'BaseFont'));
	fontname := clean_font_name(basefont);

	//* Load font file */

	fontdesc := pdf_new_font_desc();

	descriptor:= fz_dict_gets(dict, 'FontDescriptor');
	if (descriptor<>nil) then
		error := pdf_load_font_descriptor(fontdesc, xref, descriptor, nil, basefont)
	else
		error := pdf_load_builtin_font(fontdesc, fontname);
  //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=691690 */
	if (error<0) and ((fontdesc^.flags and PDF_FD_SYMBOLIC)<>0) then
	begin
		fz_catch(error, 'using bullet-substitute font for "%s" (%d %d R)', [fontname, fz_to_num(dict), fz_to_gen(dict)]);
		pdf_drop_font(fontdesc);
		fontdesc := pdf_new_font_desc();
		error := pdf_load_builtin_font(fontdesc, 'Symbol');
		if (error<0) then
		begin
			face := fontdesc^.font^.ft_face;
			kind := ft_kind(face);
			fontdesc^.encoding := pdf_new_identity_cmap(0, 1);
			fontdesc^.cid_to_gid_len := 256;
			fontdesc^.cid_to_gid := fz_calloc(256, sizeof(word));
			k := FT_Get_Name_Index(face, 'bullet');
			for i := 0 to 256-1 do
				word_items(fontdesc^.cid_to_gid)[i] := k;
			goto skip_encoding;
		end;
	end;

	if (error<0)  then
		goto cleanup;

	//* Some chinese documents mistakenly consider WinAnsiEncoding to be codepage 936 */
	if ((fontdesc^.font^.name=nil) and
		(fz_dict_gets(dict, 'ToUnicode')=nil) and
		(strcomp(fz_to_name(fz_dict_gets(dict, 'Encoding')), 'WinAnsiEncoding')=0) and
		(fz_to_int(fz_dict_gets(descriptor, 'Flags')) = 4)) then
	begin
		//* note: without the comma, pdf_load_font_descriptor would prefer /FontName over /BaseFont */

    i:=0;
		while (cp936fonts[i]<>nil) do
    begin
      I:=i+2;
			if (strcomp(basefont, cp936fonts[i])=0) then
				break;
    end;
		if (cp936fonts[i]<>NIL) THEN
		begin
		 	fz_warn('workaround for S22PDF lying about chinese font encodings');
			pdf_drop_font(fontdesc);
			fontdesc := pdf_new_font_desc();
			error := pdf_load_font_descriptor(fontdesc, xref, descriptor, 'Adobe-GB1', cp936fonts[i+1]);   //可能错了
			error :=error or pdf_load_system_cmap(@fontdesc^.encoding, 'GBK-EUC-H');
			error :=error or pdf_load_system_cmap(@fontdesc^.to_unicode, 'Adobe-GB1-UCS2');
			error :=error or pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-GB1-UCS2');
			if (error<0)  then
      begin
				result:=fz_rethrow(error, 'cannot load font');
        EXIT;
      end;

			face := fontdesc^.font^.ft_face;
			kind := ft_kind(face);
			goto skip_encoding;
		end;
	end;

	face := fontdesc^.font^.ft_face;
	kind := ft_kind(face);

	//* Encoding */

	symbolic := fontdesc^.flags and 4;

	if (face^.num_charmaps > 0) then
		cmap := FT_CharMap_items(face^.charmaps)[0]
	else
		cmap := nil;

	for i := 0 to  face^.num_charmaps-1 do
	begin
		test := FT_CharMap_items(face^.charmaps)[i];

		if (kind = TYPE1) then
		begin
			if (test^.platform_id = 7) then
				cmap := test;
		end;

		if (kind = TRUETYPE) then
		begin
			if (test^.platform_id = 1) and  (test^.encoding_id = 0) then
				cmap := test;
			if (test^.platform_id = 3) and (test^.encoding_id = 1) then
				cmap := test;
		end;
	end;

	if (cmap<>nil) then
	begin
		fterr := FT_Set_Charmap(face, cmap);
		if (fterr<>0) then
		 	fz_warn('freetype could not set cmap: %s', [ft_error_string(fterr)]);

	end
	else
	 	fz_warn('freetype could not find any cmaps');


	etable := fz_calloc(256, sizeof(word));
	for i := 0 to 256-1 do
	begin
		estrings[i] := nil;
		word_items(etable)[i] := 0;
	end;

	encoding := fz_dict_gets(dict, 'Encoding');
	if (encoding<>nil) then
	begin
		if (fz_is_name(encoding))  then
			pdf_load_encoding(@estrings, fz_to_name(encoding));

		if (fz_is_dict(encoding)) then
		begin


			base := fz_dict_gets(encoding, 'BaseEncoding');
			if (fz_is_name(base)) then
				pdf_load_encoding(@estrings, fz_to_name(base))
			else if (fontdesc^.is_embedded<>0) and (symbolic<>0) then
				pdf_load_encoding(@estrings, 'StandardEncoding');

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
					if (fz_is_name(item)) then
          begin
						estrings[k] := fz_to_name(item);
            k:=k+1;
          end;
					if (k < 0) then k := 0;
					if (k > 255) then k := 255;
				end;
			end;
		end;
	end;

	//* start with the builtin encoding */
	for i := 0 to 256-1 do
		word_items(etable)[i] := ft_char_index(face, i);

	//* encode by glyph name where we can */
	if (kind = TYPE1) then
	begin
		for i := 0 to 256-1 do
		begin
			if estrings[i]<>nil then
			begin
     //   if i=90 then
    //    dddd;
				word_items(etable)[i] := FT_Get_Name_Index(face, pchar(estrings[i])); //(face, estrings[i]);
        //outprintf(pchar(inttostr(i)));
        //outprintf(pchar(estrings[i]));
				if (word_items(etable)[i] = 0) then
				begin
					aglcode := pdf_lookup_agl(estrings[i]);
					dupnames := pdf_lookup_agl_duplicates(aglcode);
					while (dupnames^<>nil) do
					begin
						word_items(etable)[i] := FT_Get_Name_Index(face, dupnames^);
						if (word_items(etable)[i]<>0) then
							break;
						inc(dupnames);
					end;
				end;
			end;
		end;
	end;

	//* encode by glyph name where we can */
 //	if (kind = TRUETYPE) then
 ///* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692090 */
  if ((kind = TRUETYPE) or (strcomp(fz_to_name(fz_dict_gets(dict, 'Subtype')), 'TrueType')=0)) and (symbolic<>0) then
	begin
		//* Unicode cmap */
		if ((symbolic=0) and  (face^.charmap<>nil) and (face^.charmap^.platform_id = 3)) then
		begin
			for i := 0 to 256-1 do
			begin
				if (estrings[i]<>nil) then
				begin
					aglcode := pdf_lookup_agl(estrings[i]);
					if (aglcode<>0) then
						word_items(etable)[i] := FT_Get_Name_Index(face, estrings[i])
					else
						word_items(etable)[i] := ft_char_index(face, aglcode);
				end;
			end;
		end

		//* MacRoman cmap */
		else if ((symbolic=0) and  (face^.charmap<>nil) and (face^.charmap^.platform_id = 1)) then
		begin
			for i := 0 to 256-1 do
			begin
				if (estrings[i]<>nil) then
				begin
					k := lookup_mre_code(estrings[i]);
					if (k <= 0) then
						word_items(etable)[i] := FT_Get_Name_Index(face, estrings[i])
					else
						word_items(etable)[i] := ft_char_index(face, k);
				end;
			end;
	  end

		//* Symbolic cmap */
    //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692493 */
		else  if ((symbolic=0) or (face^.charmap=nil) or (face^.charmap^.encoding <> FT_ENCODING_MS_SYMBOL) ) then
		begin
			for i := 0 to  256-1 do
			begin
				if (estrings[i]<>nil) then
				begin
					word_items(etable)[i] := FT_Get_Name_Index(face, estrings[i]);
					if (word_items(etable)[i] = 0) then
						word_items(etable)[i] := ft_char_index(face, i);
				end;
			end;
		end;
	end;

	//* try to reverse the glyph names from the builtin encoding */
	for i := 0 to 256-1 do
	begin
		if (word_items(etable)[i]<>0) and (estrings[i]=nil) then
		begin
			if (FT_HAS_GLYPH_NAMES(face)) then
			begin
				fterr := FT_Get_Glyph_Name(face, word_items(etable)[i], @ebuffer[i], 32);
				if (fterr<>0) then
					fz_warn('freetype get glyph name (gid %d): %s', [word_items(etable)[i], ft_error_string(fterr)]);

				if (ebuffer[i][0]<>#0) then
					estrings[i] := ebuffer[i];
			end
			else
			begin
				estrings[i]:=  pdf_win_ansi[i]; //* discard const */
			end;
		end;
	end;

	fontdesc^.encoding := pdf_new_identity_cmap(0, 1);
  
	fontdesc^.cid_to_gid_len := 256;
	fontdesc^.cid_to_gid := etable;

	error := pdf_load_to_unicode(fontdesc, xref, @estrings, nil, fz_dict_gets(dict, 'ToUnicode'));
	if (error<0)  then
		fz_catch(error, 'cannot load to_unicode');


skip_encoding:

	//* Widths */

	pdf_set_default_hmtx(fontdesc, round(fontdesc^.missing_width));

	widths := fz_dict_gets(dict, 'Widths');
	if (widths<>nil) then
	begin


		first := fz_to_int(fz_dict_gets(dict, 'FirstChar'));
		last := fz_to_int(fz_dict_gets(dict, 'LastChar'));

		if ((first < 0) or (last > 255) or (first > last)) then
    begin
      last:=0;
			first := last;
    end;

		for i := 0 to last - first do
		begin
			wid := fz_to_int(fz_array_get(widths, i));
      //* cf. http://code.google.com/p/sumatrapdf/issues/detail?id=1616 */
			if (wid=0) and (i >= fz_array_len(widths)) then
			begin
				fz_warn('font width missing for glyph %d (%d %d R)', [i + first, fz_to_num(dict), fz_to_gen(dict)]);
				FT_Set_Char_Size(face, 1000, 1000, 72, 72);
				wid := ft_width(fontdesc, i + first);
			end;


			pdf_add_hmtx(fontdesc, i + first, i + first, wid);
		end;
	end
	else
	begin
		fterr := FT_Set_Char_Size(face, 1000, 1000, 72, 72);
		if (fterr<>0) then
			fz_warn('freetype set character size: %s', [ft_error_string(fterr)]);

		for i := 0 to 256-1 do
		begin
			pdf_add_hmtx(fontdesc, i, i, ft_width(fontdesc, i));
		end;
	end;

	pdf_end_hmtx(fontdesc);

	fontdescp^ := fontdesc;
	result:=1; //fz_okay;
  exit;

cleanup:
	if (etable <> fontdesc^.cid_to_gid) then
		fz_free(etable);
	pdf_drop_font(fontdesc);
	result:=fz_rethrow(error, 'cannot load simple font (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
  exit; //return fz_rethrow(error, "cannot load simple font (%d %d R)", fz_to_num(dict), fz_to_gen(dict));
end;

(*
 * CID Fonts
 *)

function
load_cid_font(fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s; dict:pfz_obj_s; encoding:pfz_obj_s; to_unicode:pfz_obj_s):integer;
var
	 error:integer;
	 widths:pfz_obj_s;
	descriptor:pfz_obj_s;
	fontdesc:ppdf_font_desc_s;
	 face:FT_Face;
	kind:pdf_font_kind;
  collection:array[0..255] of char;
  tmpstr:array[0..63] of char;
	basefont:pchar;
	i, k, fterr:integer;
	obj:pfz_obj_s;
  cidinfo:pfz_obj_s;
  cidtogidmap:pfz_obj_s;
  tmplen:integer;
  buf:pfz_buffer_s;
	dw:integer;
  c0, c1, w:integer;
  dw2y, dw2w :integer;
   x, y:integer;
  label cleanup;
begin

	//* Get font name and CID collection */
 begin
	basefont := fz_to_name(fz_dict_gets(dict, 'BaseFont'));
	cidinfo := fz_dict_gets(dict, 'CIDSystemInfo');
		if (cidinfo=nil) then
    begin
			result:= fz_throw('cid font is missing info');
      exit;
    end;

		obj := fz_dict_gets(cidinfo, 'Registry');
		tmplen := MIN(sizeof(tmpstr) - 1, fz_to_str_len(obj));
	//	copymemory(@tmpstr, fz_to_str_buf(obj), tmplen);
    move(fz_to_str_buf(obj)^, tmpstr,tmplen);
		tmpstr[tmplen] := #0;
		fz_strlcpy(collection, tmpstr, sizeof(collection));

		fz_strlcat(collection, '-', sizeof(collection));

		obj := fz_dict_gets(cidinfo, 'Ordering');
		tmplen := MIN(sizeof(tmpstr) - 1, fz_to_str_len(obj));
	 //	copymemory(@tmpstr, fz_to_str_buf(obj), tmplen);
   move(fz_to_str_buf(obj)^,tmpstr,tmplen);
		tmpstr[tmplen] := #0;
		fz_strlcat(@collection, tmpstr, sizeof(collection));
	end;

	//* Load font file */

	fontdesc := pdf_new_font_desc();

	descriptor := fz_dict_gets(dict, 'FontDescriptor');
	if (descriptor<>nil) then
		error := pdf_load_font_descriptor(fontdesc, xref, descriptor, collection, basefont)
	else
  begin
		error:=  fz_throw('syntaxerror: missing font descriptor');

    exit;
  end;
	if (error<0)  then
		goto cleanup;

	face := fontdesc^.font^.ft_face;
	kind := ft_kind(face);

	//* Encoding */

	error := 1; //fz_okay;
	if (fz_is_name(encoding)) then
	begin
		if (strcomp(fz_to_name(encoding), 'Identity-H')=0) then
			fontdesc^.encoding := pdf_new_identity_cmap(0, 2)
		else if (strcomp(fz_to_name(encoding), 'Identity-V')=0) then
			fontdesc^.encoding := pdf_new_identity_cmap(1, 2)
		else
			error := pdf_load_system_cmap(@fontdesc^.encoding, fz_to_name(encoding));
	end
	else if (fz_is_indirect(encoding))  then
	begin
		error := pdf_load_embedded_cmap(@fontdesc^.encoding, xref, encoding);
	end
	else
	begin
		error:= fz_throw('syntaxerror: font missing encoding');
  end;

	if (error<0)  then
		goto cleanup;

	pdf_set_font_wmode(fontdesc, pdf_get_wmode(fontdesc^.encoding));

	if (kind = TRUETYPE) then
	begin

		cidtogidmap := fz_dict_gets(dict, 'CIDToGIDMap');
		if (fz_is_indirect(cidtogidmap))  then
		begin
			error := pdf_load_stream(@buf, xref, fz_to_num(cidtogidmap), fz_to_gen(cidtogidmap));
			if (error<0)  then
				goto cleanup;

			fontdesc^.cid_to_gid_len := (buf^.len) div 2;
			fontdesc^.cid_to_gid := fz_calloc(fontdesc^.cid_to_gid_len, sizeof(word));
			for i := 0 to fontdesc^.cid_to_gid_len-1 do
				word_items(fontdesc^.cid_to_gid)[i] := (	word_items(buf^.data)[i * 2] shl 8) + 	word_items(buf^.data)[i * 2 + 1];

			fz_drop_buffer(buf);
		end

		//* if truetype font is external, cidtogidmap should not be identity */
		//* so we map from cid to unicode and then map that through the (3 1) */
		//* unicode cmap to get a glyph id */
		else if (fontdesc^.font^.ft_substitute<>0) then
		begin
			fterr := FT_Select_Charmap(face, ft_encoding_unicode);
			if (fterr<>0) then
			begin
				error := fz_throw('fonterror: no unicode cmap when emulating CID font: %s', [ft_error_string(fterr)]);
				goto cleanup;
			end;

			if (strcomp(collection, 'Adobe-CNS1')=0) then
				error := pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-CNS1-UCS2')
			else if (strcomp(collection, 'Adobe-GB1')=0) then
				error := pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-GB1-UCS2')
			else if (strcomp(collection, 'Adobe-Japan1')=0) then
				error := pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-Japan1-UCS2')
			else if (strcomp(collection, 'Adobe-Japan2')=0) then
				error := pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-Japan2-UCS2')
			else if (strcomp(collection, 'Adobe-Korea1')=0) then
				error := pdf_load_system_cmap(@fontdesc^.to_ttf_cmap, 'Adobe-Korea1-UCS2')
			else
				error :=1; // fz_okay;

			if (error<0)  then
			begin
				error := fz_rethrow(error, 'cannot load system cmap %s', [collection]);
				goto cleanup;
			end;
		end;
	end;

	error := pdf_load_to_unicode(fontdesc, xref,nil, collection, to_unicode);
	if (error<0)  then
  begin
		fz_catch(error, 'cannot load to_unicode');
    result:=-1;
    exit;
  end;


	///* Horizontal */

	dw := 1000;
	obj := fz_dict_gets(dict, 'DW');
	if (obj<>nil) then
		dw := fz_to_int(obj);
	pdf_set_default_hmtx(fontdesc, dw);

	widths := fz_dict_gets(dict, 'W');
	if (widths<>nil) then
	begin
    i:=0;
		while i< fz_array_len(widths) do
		begin
			c0 := fz_to_int(fz_array_get(widths, i));
			obj := fz_array_get(widths, i + 1);
			if (fz_is_array(obj)) then
			begin
				for k := 0 to fz_array_len(obj)-1 do
				begin
					w := fz_to_int(fz_array_get(obj, k));
					pdf_add_hmtx(fontdesc, c0 + k, c0 + k, w);
				end;
				i :=i+ 2;
			end
			else
			begin
				c1 := fz_to_int(obj);
				w := fz_to_int(fz_array_get(widths, i + 2));
				pdf_add_hmtx(fontdesc, c0, c1, w);
				i :=i+3;
			end;

	 end;
	end;

	pdf_end_hmtx(fontdesc);

	//* Vertical */

	if (pdf_get_wmode(fontdesc^.encoding) = 1) then
	begin
		dw2y := 880;
		dw2w := -1000;

		obj := fz_dict_gets(dict, 'DW2');
		if (obj<>nil) then
		begin
			dw2y := fz_to_int(fz_array_get(obj, 0));
			dw2w := fz_to_int(fz_array_get(obj, 1));
		end;

		pdf_set_default_vmtx(fontdesc, dw2y, dw2w);

		widths := fz_dict_gets(dict, 'W2');
		if (widths<>nil) then
		begin
      i:=0;
			while i< fz_array_len(widths) do
			begin
				c0 := fz_to_int(fz_array_get(widths, i));
				obj := fz_array_get(widths, i + 1);
				if (fz_is_array(obj)) then
				begin
          k:=0;
					while k * 3 < fz_array_len(obj) do
					begin
						w := fz_to_int(fz_array_get(obj, k * 3 + 0));
						x := fz_to_int(fz_array_get(obj, k * 3 + 1));
						y := fz_to_int(fz_array_get(obj, k * 3 + 2));
						pdf_add_vmtx(fontdesc, c0 + k, c0 + k, x, y, w);
            k:=k+1;
					end;
					i:=i+2;
				end
				else
				begin
					c1 := fz_to_int(obj);
					w := fz_to_int(fz_array_get(widths, i + 2));
					x := fz_to_int(fz_array_get(widths, i + 3));
					y := fz_to_int(fz_array_get(widths, i + 4));
					pdf_add_vmtx(fontdesc, c0, c1, x, y, w);
					i:=i + 5;
				end;
			end;
		end;

		pdf_end_vmtx(fontdesc);
	end;

	fontdescp^ := fontdesc;
	result:=1;
  exit;
cleanup:
	pdf_drop_font(fontdesc);
	result:= fz_rethrow(error, 'cannot load cid font (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
end;

function pdf_load_type0_font(fontdescp:pppdf_font_desc_s;xref: ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	dfonts,dfont,subtype,encoding,to_unicode:pfz_obj_s;
begin
	dfonts := fz_dict_gets(dict, 'DescendantFonts');
	if (dfonts=nil) then
  begin
		result:= fz_throw('cid font is missing descendant fonts');

    exit;
  end;

	dfont := fz_array_get(dfonts, 0);

	subtype := fz_dict_gets(dfont, 'Subtype');
	encoding := fz_dict_gets(dict, 'Encoding');
	to_unicode := fz_dict_gets(dict, 'ToUnicode');

	if (fz_is_name(subtype)) and (strcomp(fz_to_name(subtype), 'CIDFontType0')=0) then
		error := load_cid_font(fontdescp, xref, dfont, encoding, to_unicode)
	else if (fz_is_name(subtype)) and (strcomp(fz_to_name(subtype), 'CIDFontType2')=0) then
		error := load_cid_font(fontdescp, xref, dfont, encoding, to_unicode)
	else
		error := fz_throw('syntaxerror: unknown cid font type');
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load descendant font (%d %d R)', [fz_to_num(dfont), fz_to_gen(dfont)]);

    exit;
  end;

	result:=1; // fz_okay;
end;

(* FontDescriptor
 *)

function
pdf_load_font_descriptor(fontdesc:ppdf_font_desc_s; xref:ppdf_xref_s; dict:pfz_obj_s; collection:pchar; basefont:pchar):integer;
var
	error:integer;
	obj1, obj2, obj3, obj:pfz_obj_s;
	fontname,origname:pchar;
	face:FT_Face ;
begin

	if (strchr(basefont, ',')=nil) or (strchr(basefont, '+')<>nil) then
		origname := fz_to_name(fz_dict_gets(dict, 'FontName'))
	else
		origname := basefont;
	fontname := clean_font_name(origname);

	fontdesc^.flags := fz_to_int(fz_dict_gets(dict, 'Flags'));
	fontdesc^.italic_angle := fz_to_real(fz_dict_gets(dict, 'ItalicAngle'));
	fontdesc^.ascent := fz_to_real(fz_dict_gets(dict, 'Ascent'));
	fontdesc^.descent := fz_to_real(fz_dict_gets(dict, 'Descent'));
	fontdesc^.cap_height := fz_to_real(fz_dict_gets(dict, 'CapHeight'));
	fontdesc^.x_height := fz_to_real(fz_dict_gets(dict, 'XHeight'));
	fontdesc^.missing_width := fz_to_real(fz_dict_gets(dict, 'MissingWidth'));

	obj1 := fz_dict_gets(dict, 'FontFile');
	obj2 := fz_dict_gets(dict, 'FontFile2');
	obj3 := fz_dict_gets(dict, 'FontFile3');
  if obj1<>nil then
    obj:=obj1
    else if  obj2<>nil then
    obj:=obj2
    else
    obj:=obj3;


	if (fz_is_indirect(obj))  then
	begin
		error := pdf_load_embedded_font(fontdesc, xref, obj);
		if (error<0)  then
		begin
		 	fz_catch(error, 'ignored error when loading embedded font, attempting to load system font');
			if (origname <> fontname)  then
				error := pdf_load_builtin_font(fontdesc, fontname)
			else
				error := pdf_load_system_font(fontdesc, fontname, collection);
			if (error<0)  then
        begin
			 result:= fz_rethrow(error, 'cannot load font descriptor (%d %d R)',[ fz_to_num(dict), fz_to_gen(dict)]);
      //  result:=-1 ;
        exit;
        end;
		end;
	end
	else
	begin
		if (origname <> fontname) then
			error := pdf_load_builtin_font(fontdesc, fontname)
		else
			error := pdf_load_system_font(fontdesc, fontname, collection);
		if (error<0)  then
    begin
		 result:= fz_rethrow(error, 'cannot load font descriptor (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
        exit;
   end;
	end;

	fz_strlcpy(@fontdesc^.font^.name, fontname, sizeof(fontdesc^.font^.name));

	//* Check for DynaLab fonts that must use hinting */
	face := fontdesc^.font^.ft_face;
	if (ft_kind(face) = TRUETYPE) then
  begin
	 	if (((face^.face_flags and FT_FACE_FLAG_TRICKY)<>0) or (is_dynalab(fontdesc^.font^.name)<>0))  then      //没有完成
			fontdesc^.font^.ft_hint := 1;
	end;

	RESULT:=1; ///fz_okay;

end;

procedure pdf_make_width_table(fontdesc:ppdf_font_desc_s);
var
	font:pfz_font_s;
	i, k, cid, gid:integer;
begin
   font := fontdesc^.font;
	font^.width_count := 0;
	for i := 0 to fontdesc^.hmtx_len-1 do
	begin
		for k := pdf_hmtx_s_items(fontdesc^.hmtx)[i].lo to  pdf_hmtx_s_items(fontdesc^.hmtx)[i].hi do
		begin
			cid := pdf_lookup_cmap(fontdesc^.encoding, k);
			gid := pdf_font_cid_to_gid(fontdesc, cid);
			if (gid > font^.width_count) then
				font^.width_count := gid;
		end;
	end;
	font^.width_count:=font^.width_count+1;

	font^.width_table := fz_calloc(font^.width_count, sizeof(intEGER));
	fillchar(font^.width_table^, sizeof(integer) * font^.width_count, 0);

	for i := 0 to  fontdesc^.hmtx_len-1 do
	begin
		for k := pdf_hmtx_s_items(fontdesc^.hmtx)[i].lo to pdf_hmtx_s_items(fontdesc^.hmtx)[i].hi do
		begin
			cid := pdf_lookup_cmap(fontdesc^.encoding, k);
			gid := pdf_font_cid_to_gid(fontdesc, cid);
			if (gid >= 0) and  (gid < font^.width_count) then
				integer_items(font^.width_table)[gid] := pdf_hmtx_s_items(fontdesc^.hmtx)[i].w;
		end;
	end;
end;

function
pdf_load_font(fontdescp:pppdf_font_desc_s; xref:ppdf_xref_s;rdb:Pfz_obj_s; dict:Pfz_obj_s)  :integer;
var
	error:integer;
	subtype:pchar;
	dfonts:Pfz_obj_s;
	charprocs:Pfz_obj_s;
  fontdesc:ppdf_font_desc_s;
begin

	fontdescp^ := pdf_find_item(xref^.store, @pdf_drop_font, dict) ;
  if fontdescp^<>nil   then
	begin
		pdf_keep_font(fontdescp^);
		///return fz_okay;
    result:=1;
    exit;
	end;

	subtype := fz_to_name(fz_dict_gets(dict, 'Subtype'));
	dfonts := fz_dict_gets(dict, 'DescendantFonts');
	charprocs := fz_dict_gets(dict, 'CharProcs');

	if (subtype<>nil) and (strcomp(subtype, 'Type0')=0) then
		error := pdf_load_type0_font(fontdescp, xref, dict)
	else if (subtype<>nil) and (strcomp(subtype, 'Type1')=0) then
		error := pdf_load_simple_font(fontdescp, xref, dict)
	else if (subtype<>nil) and (strcomp(subtype, 'MMType1')=0)  then
		error := pdf_load_simple_font(fontdescp, xref, dict)
	else if (subtype<>nil) and (strcomp(subtype, 'TrueType')=0)  then
		error := pdf_load_simple_font(fontdescp, xref, dict)
	else if (subtype<>nil) and (strcomp(subtype, 'Type3')=0) then
		error := pdf_load_type3_font(fontdescp, xref, rdb, dict)
	else if (charprocs<>nil) then
	begin
		fz_warn('unknown font format, guessing type3.');
		error := pdf_load_type3_font(fontdescp, xref, rdb, dict);
	end
	else if (dfonts<>nil) then
	begin
		fz_warn('unknown font format, guessing type0.');
		error := pdf_load_type0_font(fontdescp, xref, dict);
	end
	else
	begin
		fz_warn('unknown font format, guessing type1 or truetype.');
		error := pdf_load_simple_font(fontdescp, xref, dict);
	end;
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load font (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);

    exit;
  end;

	//* Save the widths to stretch non-CJK substitute fonts */
  fontdesc:=fontdescp^;
	if (fontdesc^.font^.ft_substitute<>0) and (fontdescp^.to_ttf_cmap=nil) then
		pdf_make_width_table(fontdescp^);

	pdf_store_item(xref^.store, @pdf_keep_font, @pdf_drop_font, dict, fontdescp^);

 //	return fz_okay;
 result:=1;
end;








end.
