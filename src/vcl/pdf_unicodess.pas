unit pdf_unicodess;

interface
uses
SysUtils,Math,digtypes,base_error;
function pdf_load_to_unicode(font:ppdf_font_desc_s; xref:ppdf_xref_s;	strings:pparray256 ; collection:pchar; cmapstm:pfz_obj_s):integer;
implementation
uses mypdfstream,base_object_functions,pdf_cmapss,pdf_camp_loads,pdf_encodings;

function pdf_load_to_unicode(font:ppdf_font_desc_s; xref:ppdf_xref_s;	strings:pparray256 ; collection:pchar; cmapstm:pfz_obj_s):integer;
var
	error :integer;
	cmap:ppdf_cmap_s;
	cid:integer;
	ucsbuf:array[0..7] of integer;
	ucslen, i,k:integer;

begin
  error :=1;
	if (pdf_is_stream(xref, fz_to_num(cmapstm), fz_to_gen(cmapstm))<>0) then
	begin
		error := pdf_load_embedded_cmap(@cmap, xref, cmapstm);
		if (error<0) then
    begin
			result:= fz_rethrow(error, 'cannot load embedded cmap (%d %d R)', [fz_to_num(cmapstm), fz_to_gen(cmapstm)]);
      exit;
    end;

		font^.to_unicode := pdf_new_cmap();
    if strings<>nil then
    k:=255
    else
    k:=65535;

		for i := 0 to k do
		begin
			cid := pdf_lookup_cmap(font^.encoding, i);
			if (cid >= 0) then
			begin
				ucslen := pdf_lookup_cmap_full(cmap, i, @ucsbuf);
				if (ucslen = 1) then
					pdf_map_range_to_range(font^.to_unicode, cid, cid, ucsbuf[0]);
				if (ucslen > 1) then
					pdf_map_one_to_many(font^.to_unicode, cid, @ucsbuf, ucslen);
			end;
		end;

		pdf_sort_cmap1(font^.to_unicode);

		pdf_drop_cmap(cmap);
	end

	else if (collection<>nil) then
	begin
		error :=1; // fz_okay;

		if (strcomp(collection, 'Adobe-CNS1')=0) then
			error := pdf_load_system_cmap(@font^.to_unicode, 'Adobe-CNS1-UCS2')
		else if (strcomp(collection, 'Adobe-GB1')=0)  then
			error := pdf_load_system_cmap(@font^.to_unicode, 'Adobe-GB1-UCS2')
		else if (strcomp(collection, 'Adobe-Japan1')=0) then
			error := pdf_load_system_cmap(@font^.to_unicode, 'Adobe-Japan1-UCS2')
		else if (strcomp(collection, 'Adobe-Korea1')=0) then
			error := pdf_load_system_cmap(@font^.to_unicode, 'Adobe-Korea1-UCS2');

		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load ToUnicode system cmap %s-UCS2', [collection]);
      exit;
    end;
	end;

	if (strings<>nil) then
	begin
		//* TODO one-to-many mappings */

		font^.cid_to_ucs_len := 256;
		font^.cid_to_ucs := fz_calloc(256, sizeof(word));

		for i := 0 to 256-1 do
		begin

			if (parray256(strings)[i]<>nil) then
				word_items(font^.cid_to_ucs)[i] := pdf_lookup_agl(parray256(strings)[i])
			else
				word_items(font^.cid_to_ucs)[i] := ord('?');

		end;
	end;

	if (font^.to_unicode=nil) and (font^.cid_to_ucs=nil)  then
	begin
		//* TODO: synthesize a ToUnicode if it's a freetype font with
		// * cmap and/or post tables or if it has glyph names. */
	end;

	result:=1;
end;

end.
