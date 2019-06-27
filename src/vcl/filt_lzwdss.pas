unit filt_lzwdss;

interface
uses
 SysUtils,Math,digtypes,base_error  ;

const
	MIN_BITS = 9;
	MAX_BITS = 12;
	NUM_CODES = (1 shl MAX_BITS);
	LZW_CLEAR = 256;
	LZW_EOD = 257;
	LZW_FIRST = 258;
	MAX_LENGTH = 4097;


type

plzw_code_s=^lzw_code_s;
pfz_lzwd_s=^fz_lzwd_s;
lzw_code_s=record
	prev:integer; 	//		/* prev code (in string) */
	length:word;		//* string len, including this token */
	value:byte;		//* data value */
	first_char:byte;  //;	/* first token of string */
end;

fz_lzwd_s=record
	chain:pfz_stream_s;
	eod:integer;
	early_change:integer;
	code_bits:integer;			//* num bits/code */
	code:integer;			//* current code */
	old_code:integer;			//* previously recognized code */
	next_code:integer;			//* next free entry */
	table:array[0..NUM_CODES-1] of lzw_code_s;
  bp:array[0..MAX_LENGTH-1] of byte;
	rp, wp:pbyte;
end;
lzw_code_s_items=array of lzw_code_s;


function fz_open_lzwd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;



implementation
uses base_object_functions,FZ_mystreams;

function read_lzwd(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	lzw:pfz_lzwd_s;
	table:plzw_code_s;
	p,ep:pbyte;
	s:pbyte;
	codelen:integer;

	code_bits :integer;
	code :integer;
	old_code :integer;
	next_code:integer;
begin
  lzw := stm^.state;
	table := @lzw^.table;
	p := buf;
	ep := buf;
  inc(ep,len);
	code_bits := lzw^.code_bits;
	code := lzw^.code;
	old_code := lzw^.old_code;
	next_code := lzw^.next_code;


	while (cardinal(lzw^.rp) < cardinal(lzw^.wp)) and ( cardinal(p) < cardinal(ep)) do
  begin
	//	*p++ = *lzw^.rp++;
    p^:= lzw^.rp^;
    inc(p);
    inc(lzw^.rp);
  end;

	while (cardinal(p) < cardinal(ep)) do
	begin
		if (lzw^.eod<>0) then
    begin
		result:=0   ;
    exit;
    end;
		code := fz_read_bits(lzw^.chain, code_bits);

		if (fz_is_eof_bits(lzw^.chain)) then
		begin
			lzw^.eod := 1;
			break;
		end;

		if (code = LZW_EOD) then
		begin
			lzw^.eod := 1;
			break;
		end;

		if (code = LZW_CLEAR) then
		begin
			code_bits := MIN_BITS;
			next_code := LZW_FIRST;
			old_code := -1;
			continue;
		end;

		//* if stream starts without a clear code, old_code is undefined... */
		if (old_code = -1) then
		begin
			old_code := code;
		end
		else
		begin
			//* add new entry to the code table */
			lzw_code_s_items(table)[next_code].prev := old_code;
			lzw_code_s_items(table)[next_code].first_char := lzw_code_s_items(table)[old_code].first_char;
			lzw_code_s_items(table)[next_code].length := lzw_code_s_items(table)[old_code].length + 1;
			if (code < next_code) then
				lzw_code_s_items(table)[next_code].value:=lzw_code_s_items(table)[code].first_char
			else if (code = next_code) then
		  	lzw_code_s_items(table)[next_code].value := lzw_code_s_items(table)[next_code].first_char
			else
			 fz_warn('out of range code encountered in lzw decode');


			next_code:=next_code+1;

			if (next_code > (1 shl code_bits) - lzw^.early_change - 1)  then
			begin
				code_bits:=code_bits+1;
				if (code_bits > MAX_BITS) then
					code_bits := MAX_BITS;	//* FIXME */
			end;

			old_code := code;
		end;

		//* code maps to a string, copy to output (in reverse...) */
		if (code > 255)   then
		begin
			codelen := lzw_code_s_items(table)[code].length;
			lzw^.rp := @lzw^.bp;
			lzw^.wp := pointer(cardinal(@lzw^.bp) + codelen);

			assert(codelen < MAX_LENGTH);

			s := lzw^.wp;
			repeat
        inc(s,-1);
        s^:= lzw_code_s_items(table)[code].value;
				code := lzw_code_s_items(table)[code].prev;
		  until not ((code >= 0) and (cardinal(s) > cardinal(@lzw^.bp)));
		end

		//* ... or just a single character */
		else
		begin
			lzw^.bp[0] := code;
			lzw^.rp := @lzw^.bp;
			lzw^.wp := pointer(cardinal( @lzw^.bp) + 1);
		end;

		//* copy to output */
		while (cardinal(lzw^.rp) < cardinal(lzw^.wp)) and  (cardinal(p) < cardinal(ep))   do
    begin
      p^:=lzw^.rp^;
      inc(p);
      inc(lzw^.rp);
    end;
	end;

	lzw^.code_bits := code_bits;
	lzw^.code := code;
	lzw^.old_code := old_code;
	lzw^.next_code := next_code;

	result:= cardinal(p) - cardinal(buf);
end;

procedure close_lzwd( stm:pfz_stream_s);
var
  lzw :pfz_lzwd_s;
begin
	 lzw := stm^.state;
	fz_close(lzw^.chain);
	fz_free(lzw);
end;

function fz_open_lzwd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
var
	lzw:pfz_lzwd_s;
	obj:pfz_obj_s;
	i:integer;
begin
	lzw := fz_malloc(sizeof(fz_lzwd_s));
	lzw^.chain := chain;
	lzw^.eod := 0;
	lzw^.early_change := 1;

	obj := fz_dict_gets(params, 'EarlyChange');
	if (obj<>nil) then
  begin
    if fz_to_int(obj)<>0 then
		lzw^.early_change := 1
    else
     lzw^.early_change := 0;

  end;

	for i := 0 to 256-1 do
	begin
		lzw^.table[i].value := i;
		lzw^.table[i].first_char := i;
		lzw^.table[i].length := 1;
		lzw^.table[i].prev := -1;
	end;

	for i := 256 to  NUM_CODES-1 do
	begin
		lzw^.table[i].value := 0;
		lzw^.table[i].first_char := 0;
		lzw^.table[i].length := 0;
		lzw^.table[i].prev := -1;
	end;

	lzw^.code_bits := MIN_BITS;
	lzw^.code := -1;
	lzw^.next_code := LZW_FIRST;
	lzw^.old_code := -1;
	lzw^.rp := @lzw^.bp;
	lzw^.wp := @lzw^.bp;

	result:=fz_new_stream(lzw, read_lzwd, close_lzwd);
end;


end.
