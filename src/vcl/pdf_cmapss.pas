unit pdf_cmapss;

interface
 uses
SysUtils,digtypes,base_error;
function pdf_lookup_cmap_full(cmap:ppdf_cmap_s;  cpt:integer;  outp:pinteger):integer;
function pdf_lookup_cmap(cmap:ppdf_cmap_s; cpt:integer):integer;
procedure pdf_drop_cmap(cmap:ppdf_cmap_s);
function pdf_keep_cmap(cmap:ppdf_cmap_s) :ppdf_cmap_s;
procedure
pdf_add_codespace(cmap:ppdf_cmap_s; low,  high, n:integer);
procedure
pdf_set_wmode(cmap:ppdf_cmap_s; wmode:integer);
procedure pdf_map_range_to_range(cmap:ppdf_cmap_s;  low,  high,  offset:integer);
procedure pdf_map_one_to_many(cmap:ppdf_cmap_s; low:integer;values:pinteger; len:integer);
function pdf_new_cmap():ppdf_cmap_s;
procedure pdf_set_usecmap(cmap,usecmap:ppdf_cmap_s);
procedure pdf_sort_cmap1(cmap:ppdf_cmap_s) ;
function  pdf_get_wmode(cmap:ppdf_cmap_s):integer;
function pdf_decode_cmap(cmap:ppdf_cmap_s; buf:pbyte; cpt:pinteger):pbyte;
implementation
uses base_object_functions,QSort1;

(*
#define pdf_range_high(r) ((r)->low + ((r)->extent_flags >> 2))
#define pdf_range_flags(r) ((r)->extent_flags & 3)
#define pdf_range_set_high(r, h) \
	((r)->extent_flags = (((r)->extent_flags & 3) | ((h - (r)->low) << 2)))
#define pdf_range_set_flags(r, f) \
	((r)->extent_flags = (((r)->extent_flags & ~3) | f))

*)

function pdf_range_high(r:ppdf_range_s) :integer;
begin
result:=(r^.low + (r^.extent_flags shr 2))
end;
function pdf_range_flags(r:ppdf_range_s):CAMP_kind_e;
begin
 result:=CAMP_kind_e(r^.extent_flags and 3);
end;

procedure pdf_range_set_high(r:ppdf_range_s; h:integer);
begin
	r^.extent_flags := ((r^.extent_flags and 3) or ((h - r^.low) shl 2)) ;
end;

procedure pdf_range_set_flags(r:ppdf_range_s; f:CAMP_kind_e);
begin
	r^.extent_flags := ((r^.extent_flags and (not 3)) or ord(f)) ;
end;

function pdf_new_cmap():ppdf_cmap_s;
var
	cmap:ppdf_cmap_s;
begin
	cmap := fz_malloc(sizeof(pdf_cmap_s));
	cmap^.refs := 1;

	strcopy(cmap^.cmap_name, '');
	strcopy(cmap^.usecmap_name, '');
	cmap^.usecmap := nil;
	cmap^.wmode := 0;
	cmap^.codespace_len := 0;

	cmap^.rlen := 0;
	cmap^.rcap := 0;
	cmap^.ranges := nil;

	cmap^.tlen := 0;
	cmap^.tcap := 0;
	cmap^.table := Nil;

	result:= cmap;
end;

function pdf_keep_cmap(cmap:ppdf_cmap_s) :ppdf_cmap_s;
begin
	if (cmap^.refs >= 0) then
		cmap^.refs :=cmap^.refs+1;
	result:= cmap;
end;

procedure pdf_drop_cmap(cmap:ppdf_cmap_s);
begin
	if (cmap^.refs >= 0) then
	begin
    cmap^.refs:=cmap^.refs-1;
		if (cmap^.refs = 0) then
		begin
			if (cmap^.usecmap<>nil) then
				pdf_drop_cmap(cmap^.usecmap);
			fz_free(cmap^.ranges);
			fz_free(cmap^.table);
			fz_free(cmap);
		end;
	end;
end;

procedure pdf_set_usecmap(cmap,usecmap:ppdf_cmap_s);
var
	i:integer;
begin
	if (cmap^.usecmap<>nil)  then
		pdf_drop_cmap(cmap^.usecmap);
	cmap^.usecmap := pdf_keep_cmap(usecmap);

	if (cmap^.codespace_len = 0) then
	begin
		cmap^.codespace_len := usecmap^.codespace_len;
		for i := 0 to usecmap^.codespace_len-1 do
			cmap^.codespace[i] := usecmap^.codespace[i];
	end;
end;

function pdf_get_wmode(cmap:ppdf_cmap_s):integer;
begin
	result:= cmap^.wmode;
end;

procedure
pdf_set_wmode(cmap:ppdf_cmap_s; wmode:integer);
begin
	cmap^.wmode := wmode;
end;


(*
 * Add a codespacerange section.
 * These ranges are used by pdf_decode_cmap to decode
 * multi-byte encoded strings.
 *)

procedure
pdf_add_codespace(cmap:ppdf_cmap_s; low,  high, n:integer);
begin
	if (cmap^.codespace_len + 1 = (sizeof(cmap^.codespace))/sizeof(cmap^.codespace[0])) then
	begin
		fz_warn('assert: too many code space ranges');
		//return;
    exit;
	end;

	cmap^.codespace[cmap^.codespace_len].n := n;
	cmap^.codespace[cmap^.codespace_len].low := low;
	cmap^.codespace[cmap^.codespace_len].high := high;
	cmap^.codespace_len:=cmap^.codespace_len+1;
end;

(*
 * Add an integer to the table.
 *)
procedure
add_table(cmap:ppdf_cmap_s; value:integer);
begin
	if (cmap^.tlen = USHRT_MAX) then
	begin
		fz_warn('cmap table is full; ignoring additional entries');
		//return;
    exit;
	end;
	if (cmap^.tlen + 1 > cmap^.tcap) then
	begin
    if cmap^.tcap > 1 then
   		cmap^.tcap :=  trunc((cmap^.tcap * 3) / 2)
      else
      cmap^.tcap :=  256;
		cmap^.table := fz_realloc(cmap^.table, cmap^.tcap, sizeof(word));
	end;
	word_items(cmap^.table)[cmap^.tlen] := value;
  cmap^.tlen:=cmap^.tlen+1;
end;

//*  * Add a range.  */
procedure add_range(cmap:ppdf_cmap_s; low,  high:integer;  flag:CAMP_kind_e; offset:integer);
begin
	//* If the range is too large to be represented, split it */
	if (high - low > $3fff) then
	begin
		add_range(cmap, low, low+$3fff, flag, offset);
		add_range(cmap, low+$3fff, high, flag, offset+$3fff);

		exit;
	end;
	if (cmap^.rlen + 1 > cmap^.rcap) then
	begin
    if cmap^.rcap > 1 then
       cmap^.rcap :=(cmap^.rcap * 3) DIV 2 
       else
       cmap^.rcap :=256;

		cmap^.ranges := fz_realloc(cmap^.ranges, cmap^.rcap, sizeof(pdf_range_s));
	end;
	pdf_range_s_items(cmap^.ranges)[cmap^.rlen].low := low;
	pdf_range_set_high(@pdf_range_s_items(cmap^.ranges)[cmap^.rlen], high);
	pdf_range_set_flags(@pdf_range_s_items(cmap^.ranges)[cmap^.rlen], flag);
	pdf_range_s_items(cmap^.ranges)[cmap^.rlen].offset := offset;
	cmap^.rlen:=cmap^.rlen +1;
end;

//* * Add a range-to-table mapping. */
procedure
pdf_map_range_to_table(cmap:ppdf_cmap_s;  low:integer; table:pinteger; len:integer);
var
	 i,high,offset:integer;

begin
  high := low + len;
	offset := cmap^.tlen;
	if (cmap^.tlen + len >= USHRT_MAX) then
		fz_warn('cannot map range to table; table is full')

	else
	begin
		for i := 0 to len-1 do
			add_table(cmap, integer_items(table)[i]);
		add_range(cmap, low, high, PDF_CMAP_TABLE, offset);
	end;
end;

//* * Add a range of contiguous one-to-one mappings (ie 1..5 maps to 21..25) */
procedure pdf_map_range_to_range(cmap:ppdf_cmap_s;  low,  high,  offset:integer);
var
k:CAMP_kind_e;
begin
  if high - low = 0 then
  k:=PDF_CMAP_SINGLE
  else
  k:= PDF_CMAP_RANGE;
	add_range(cmap, low, high, k, offset);
end;

(*
 * Add a single one-to-many mapping.
 *)
procedure pdf_map_one_to_many(cmap:ppdf_cmap_s; low:integer;values:pinteger; len:integer);
var
	offset, i:integer;
begin
	if (len = 1) then
	begin
		add_range(cmap, low, low, PDF_CMAP_SINGLE, integer_items(values)[0]);
		exit;
	end;

	if (len > 8) then
	begin
		fz_warn('one to many mapping is too large (%d); truncating', [len]);
		len := 8;
	end;

	if ((len = 2) and
		(integer_items(values)[0] >= $D800) and (integer_items(values)[0] <= $DBFF) and
		(integer_items(values)[1] >= $DC00) and (integer_items(values)[1] <= $DFFF)) then
	begin
		fz_warn('ignoring surrogate pair mapping in cmap');
		//return;
    exit;
	end;

	if (cmap^.tlen + len + 1 >= USHRT_MAX) then
		fz_warn('cannot map one to many; table is full')
	else
	begin
		offset := cmap^.tlen;
		add_table(cmap, len);
		for i := 0 to len-1 do
			add_table(cmap, integer_items(values)[i]);
		add_range(cmap, low, low, PDF_CMAP_MULTI, offset);
	end;
end;

(*
 * Sort the input ranges.
 * Merge contiguous input ranges to range-to-range if the output is contiguous.
 * Merge contiguous input ranges to range-to-table if the output is random.
 *)

function cmprange(va:pointer;vb:pointer):integer;
begin
	result:=ppdf_range_s(va)^.low - ppdf_range_s(vb)^.low;
end;

procedure
pdf_sort_cmap1(cmap:ppdf_cmap_s) ;
var
	a:ppdf_range_s;			//* last written range on output */
	b:ppdf_range_s;			//* current range examined on input */
 // c:ppdf_range_s;
begin
	if (cmap^.rlen = 0) then
		exit;
//  OutputDebugString(pchar('ppp_3:'+inttostr(pdf_range_s_items(cmap^.ranges)[0].extent_flags)));
	QuickSort(cmap^.ranges, cmap^.rlen, sizeof(pdf_range_s), @cmprange);


	if (cmap^.tlen = USHRT_MAX) then
	begin
		fz_warn('cmap table is full; will not combine ranges');
	 //	return;
   exit;
	end;

	a := cmap^.ranges;
	b := cmap^.ranges ;
  inc(b);

	while cardinal(b) < cardinal(@(pdf_range_s_items(cmap^.ranges)[cmap^.rlen])) do
	begin
		//* ignore one-to-many mappings */
		if (pdf_range_flags(b) = PDF_CMAP_MULTI) then
		begin
		//	*(++a) = *b;
      inc(a);
      a^:=b^;
		end

		//* input contiguous */
		else if (pdf_range_high(a) + 1 = b^.low) then
		begin
			//* output contiguous */
			if (pdf_range_high(a) - a^.low + a^.offset + 1 =b^.offset) then
			begin
				//* SR ^. R and SS ^. R and RR ^. R and RS ^. R */
				if ((pdf_range_flags(a) = PDF_CMAP_SINGLE)  or (pdf_range_flags(a) = PDF_CMAP_RANGE)) and (pdf_range_high(b) - a^.low <= $3fff)   then
				begin
					pdf_range_set_flags(a, PDF_CMAP_RANGE);
					pdf_range_set_high(a, pdf_range_high(b));
				end

				//* LS ^. L */
				else if ((pdf_range_flags(a) = PDF_CMAP_TABLE) and (pdf_range_flags(b) = PDF_CMAP_SINGLE) and (pdf_range_high(b) - a^.low <= $3fff)) then
				begin
					pdf_range_set_high(a, pdf_range_high(b));
					add_table(cmap, b^.offset);
				end

				//* LR ^. LR */
				else if (pdf_range_flags(a) = PDF_CMAP_TABLE) and (pdf_range_flags(b) = PDF_CMAP_RANGE)  then
				begin
				 //	*(++a) = *b;
          inc(a);
          a^:=b^;
				end

				//* XX ^. XX */
				else
				begin
				 //	*(++a) = *b;
           inc(a);
          a^:=b^;
				end;
			end

			//* output separated */
			else
			begin
				//* SS ^. L */
				if (pdf_range_flags(a) = PDF_CMAP_SINGLE) and (pdf_range_flags(b) = PDF_CMAP_SINGLE) then
				begin
					pdf_range_set_flags(a, PDF_CMAP_TABLE);
					pdf_range_set_high(a, pdf_range_high(b));
					add_table(cmap, a^.offset);
					add_table(cmap, b^.offset);
					a^.offset := cmap^.tlen - 2;
				end

				//* LS ^. L */
				else if ((pdf_range_flags(a) = PDF_CMAP_TABLE) and (pdf_range_flags(b) = PDF_CMAP_SINGLE) and (pdf_range_high(b) - a^.low <= $3fff))  then
				begin
					pdf_range_set_high(a, pdf_range_high(b));
					add_table(cmap, b^.offset);
				end

				//* XX ^. XX */
				else
				begin
					 inc(a);
          a^:=b^;
				end
			end;
		end

		//* input separated: XX ^. XX */
		else
		begin
			 inc(a);
          a^:=b^;
		end;

		inc(b);
	end;

	cmap^.rlen := (cardinal(a) - cardinal(cmap^.ranges)) div sizeof(pdf_range_s)+ 1;

	//fz_flush_warnings();
end;

(*
 * Lookup the mapping of a codepoint.
 *)
function pdf_lookup_cmap(cmap:ppdf_cmap_s; cpt:integer):integer;
var
	l,r,m,i:integer;
begin
  l := 0;
	 r := cmap^.rlen - 1;
	while (l <= r) do
  begin
		m := (l + r) shr 1;
		if (cpt < pdf_range_s_items(cmap^.ranges)[m].low) then
			r := m - 1
		else if (cpt > pdf_range_high(@pdf_range_s_items(cmap^.ranges)[m])) then
			l := m + 1
		else
		begin
			i := cpt - pdf_range_s_items(cmap^.ranges)[m].low + pdf_range_s_items(cmap^.ranges)[m].offset;
			if (pdf_range_flags(@pdf_range_s_items(cmap^.ranges)[m]) = PDF_CMAP_TABLE) then
      begin
				result:= word_items(cmap^.table)[i];
        exit;
      end;
			if (pdf_range_flags(@pdf_range_s_items(cmap^.ranges)[m]) = PDF_CMAP_MULTI)  then
      begin
				result:= -1; //* should use lookup_cmap_full */
        exit;
      end;
			result:= i;
      exit;
		end;
	end;

	if (cmap^.usecmap<>nil) then
  begin
		result:= pdf_lookup_cmap(cmap^.usecmap, cpt);
    exit;
  end;

	result:= -1;
end;

function pdf_lookup_cmap_full(cmap:ppdf_cmap_s;  cpt:integer;  outp:pinteger):integer;
var
	 i, k, n,l,r,m:integer;

begin
  l := 0;
	r := cmap^.rlen - 1;
	while (l <= r) do
	begin
		m := (l + r) shr 1;
		if (cpt < pdf_range_s_items(cmap^.ranges)[m].low)  then
			r := m - 1
		else if (cpt > pdf_range_high(@pdf_range_s_items(cmap^.ranges)[m]))  then
			l := m + 1
		else
		begin
			k := cpt - pdf_range_s_items(cmap^.ranges)[m].low + pdf_range_s_items(cmap^.ranges)[m].offset;
			if (pdf_range_flags(@pdf_range_s_items(cmap^.ranges)[m]) = PDF_CMAP_TABLE) then
			begin
				integer_items(outp)[0] := word_items(cmap^.table)[k];
				result:= 1;
        exit;
			end
			else if (pdf_range_flags(@pdf_range_s_items(cmap^.ranges)[m]) = PDF_CMAP_MULTI)  then
			begin
				n := pdf_range_s_items(cmap^.ranges)[m].offset;
				for i := 0 to word_items(cmap^.table)[n]-1 do
					integer_items(outp)[i] := word_items(cmap^.table)[n + i + 1];
				result:= word_items(cmap^.table)[n];
        exit;
			end
			else
			begin
				integer_items(outp)[0] := k;
				result:=1;
        exit;
			end;
		end;
	end;

	if (cmap^.usecmap<>nil) then
  begin
		result:= pdf_lookup_cmap_full(cmap^.usecmap, cpt, outp);
    exit;
  end;

	result:= 0;
end;

(*
 * Use the codespace ranges to extract a codepoint from a
 * multi-byte encoded string.
 *)
function pdf_decode_cmap(cmap:ppdf_cmap_s; buf:pbyte; cpt:pinteger):pbyte;
var
	k, n, c:integer;
begin
	c := 0;
	for n := 0 to 3 do
	begin
		c := (c shl 8) or byte_items(buf)[n];
		for k := 0 to cmap^.codespace_len-1 do
		begin
			if (cmap^.codespace[k].n = n + 1) then
			begin
				if (c >= cmap^.codespace[k].low) and (c <= cmap^.codespace[k].high) then
				begin
					cpt^ := c;
					result:= pointer(cardinal(buf) + n + 1);
          exit;
				end;
			end;
		end;
	end;

	cpt^ := 0;
	result:= pointer(cardinal(buf) +  1);
end;


end.
