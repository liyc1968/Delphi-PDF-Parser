unit fz_filterss;

interface
uses
 SysUtils,Math,digtypes,QSort1,base_object_functions,FZ_mystreams,ZLibEx,ZLibExApi,base_error;

type
z_stream=TZStreamRec;
z_streamp=^z_stream;
 pfz_flate_s=^fz_flate_s;
 fz_flate_s=record
	chain:pfz_stream_s;
  z: z_stream;
end;

type
pfz_rld_s=^fz_rld_s;
fz_rld_s=record
	chain:pfz_stream_s;
	run, n, c:integer;
end;

//* * Data filters. */
function  fz_open_copy(chain:pfz_stream_s):pfz_stream_s;
function  fz_open_null(chain:pfz_stream_s;len:integer):pfz_stream_s;
function  fz_open_arc4(chain:pfz_stream_s; key:pbyte; keylen:integer):pfz_stream_s;
function  fz_open_aesd(chain:pfz_stream_s;  key:pbyte; keylen:integer):pfz_stream_s;
function  fz_open_a85d(chain:pfz_stream_s):pfz_stream_s;
function  fz_open_ahxd(chain:pfz_stream_s):pfz_stream_s;
function  fz_open_rld(chain:pfz_stream_s):pfz_stream_s;


function  fz_open_flated(chain:pfz_stream_s):pfz_stream_s;

//function  fz_open_predict(chain:pfz_stream_s; param:pfz_obj_s):pfz_stream_s;
function  fz_open_jbig2d(chain:pfz_stream_s;  global:pfz_buffer_s):pfz_stream_s;
function read_ahxd(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
procedure close_ahxd(stm:pfz_stream_s);
FUNCTION zalloc(opaque:pointer; items:integer; size:integer):POINTER;
implementation
uses digcommtype,ohhcrypt_arc4,ohhcrypt_aes;

function iswhite1(c:char):boolean;
var
i:integer;
begin
  result:=false;
  i:=ord(c);
  if ((i=10) or (i=13) or (i=9) or (i=32) or (i=0) or (i=12) or (i=8) or (i= 127)) then
  begin
    result:=true;
  end;
 // case '\n': case '\r': case '\t': case ' ':
 //	case '\0': case '\f': case '\b': case 0177:

//  '\r' 13; '\n' 11; '\b' 8; '\t' 09 ; ' ' 32;  \f 12;


end;
//read1=function(stm:pfz_stream_s;var buf:pbyte;len:integer):integer;
function read_ahxd(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
var
  state: pfz_ahxd_s;
  ep,p:pchar;
   a, b, c1, odd:integer;
   c:char;
begin
  p:=pchar(buf);
  ep:=pointer(cardinal(buf)+len);
	odd := 0;

	while (cardinal(p) < cardinal(ep))  do
	begin
		if (state^.eod<>0) then
    begin
			result:= p - buf;
      exit;
    end;
		c1 := fz_read_byte(state^.chain);
		if (c1 < 0) then
    begin
			result:= p - buf;
      exit;
    end;
    c:=chr(c1);
		if (IS_HEX(c)) then
		begin
			if (odd<>0)  then
			begin
				a := unhex(c);
				odd := 1;
			end
			else
			begin
				b := unhex(c);
        P^:=chr((A SHL 4) or B);
				inc(p);
				odd := 0;
			end;
		end
		else if (c = '>') then
		begin
			if (odd<>0) then
      begin
				P^:=chr((A SHL 4) OR B);
				inc(p);
      end;
			state^.eod := 1;
		end
		else if (not iswhite1(c)) then
		begin
		 //	return fz_throw("bad data in ahxd: '%c'", c);
     result:=-1;
     exit;
		end;
	end;

	result:= cardinal(p) - cardinal(buf);
end;

procedure close_ahxd(stm:pfz_stream_s);
var
state:pfz_ahxd_s;
begin
	state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;




function read_null(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
var
  state:pnull_filter_s;
  amount,n:integer;
begin
	state := stm^.state;
	amount := MIN(len, state^.remain);
	n := fz_read(state^.chain, buf, amount);
	if (n < 0) then
  begin
		fz_rethrow(n, 'read error in null filter');
    result:=-1;
    exit;
  end;
	state^.remain:= state^.remain-n;
	result:=n;
end;

procedure close_null(stm:pfz_stream_s) ;
var
state:pnull_filter_s;
begin
  state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;

function fz_open_null(chain:pfz_stream_s; len:integer):pfz_stream_s;
var
state:pnull_filter_s;
begin
	state := fz_malloc(sizeof(null_filter_s));
	state^.chain := chain;
	state^.remain := len;

	result:=fz_new_stream(state, read_null, close_null);
  exit;
end;


function  fz_open_copy(chain:pfz_stream_s):pfz_stream_s;
begin
  result:=fz_keep_stream(chain);
end;

function read_rld(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	state:pfz_rld_s;
	p:pbyte;
	ep:pbyte;
  c:integer;
begin
  state := stm^.state;
	p := buf;
	ep := buf;
  inc(ep, len);
	while (cardinal(p) < cardinal(ep)) do
	begin
		if (state^.run = 128) then
    begin
			result:= cardinal(p) - cardinal(buf);
      exit;
    end;
		if (state^.n = 0) then
		begin
			state^.run := fz_read_byte(state^.chain);
			if (state^.run < 0) then
				state^.run := 128;
			if (state^.run < 128) then
				state^.n := state^.run + 1;
			if (state^.run > 128) then
			begin
				state^.n := 257 - state^.run;
				state^.c := fz_read_byte(state^.chain);
				if (state^.c < 0) then
        begin
			  	result:=fz_throw('premature end of data in run length decode');
        //result:=-1;
          exit;
        end;
			end;
		end;

		if (state^.run < 128) then
		begin
			while (cardinal(p) < cardinal(ep)) and (state^.n<>0) do
			begin
				c := fz_read_byte(state^.chain);
				if (c < 0) then
        begin
					result:=fz_throw('premature end of data in run length decode');
          exit;
        end;
        p^:=c;
        inc(p);

				state^.n:=state^.n-1;
			end;
		end;

		if (state^.run > 128) then
		begin
			while(cardinal(p) < cardinal(ep)) and (state^.n<>0) do
			begin
         p^:= state^.c;
				inc(p);
				state^.n:=state^.n-1;
			end;
		end;
	end;

	result:= cardinal(p) - cardinal(buf);
end;

procedure   close_rld(stm:pfz_stream_s);
var
state:pfz_rld_s;
begin

	state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;

function  fz_open_rld(chain:pfz_stream_s):pfz_stream_s;
var
state:pfz_rld_s;
begin
	state := fz_malloc(sizeof(fz_rld_s));
	state^.chain := chain;
	state^.run:= 0;
	state^.n := 0;
	state^.c := 0;

  result:=fz_new_stream(state, read_rld, close_rld);
end;


//* RC4 Filter */

type
pfz_arc4c_s=^fz_arc4c_s;
fz_arc4c_s=record
	chain:pfz_stream_s;
	arc4:fz_arc4_s;
end;

function
read_arc4(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	state:pfz_arc4c_s;
	n:integer;
begin
  state := stm^.state;
	n := fz_read(state^.chain, buf, len);
	if (n < 0) then
  begin
		result:=fz_rethrow(n, 'read error in arc4 filter');
    exit;
  end;

	fz_arc4_encrypt(@state^.arc4, buf^, buf^, n);

	result:= n;
end;

procedure close_arc4(stm:pfz_stream_s);
var
	state:pfz_arc4c_s;
begin
  state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;


function  fz_open_arc4(chain:pfz_stream_s; key:pbyte; keylen:integer):pfz_stream_s;
var
  state:pfz_arc4c_s;
begin

	state := fz_malloc(sizeof(fz_arc4c_s));
	state^.chain := chain;
	fz_arc4_init(@state^.arc4, key, keylen);
  result:= fz_new_stream(state, read_arc4, close_arc4);
end;





function  fz_open_ahxd(chain:pfz_stream_s):pfz_stream_s;
var
  state:pointer; //pfz_ahxd_s;
begin
	state := fz_malloc(sizeof(fz_ahxd_s));
	fz_ahxd_s(state^).chain := chain;
	fz_ahxd_s(state^).eod := 0;

	result:=fz_new_stream(state, read_ahxd, close_ahxd);

end;





FUNCTION zalloc(opaque:pointer; items:integer; size:integer):POINTER;
begin
	result:=fz_calloc(items, size);
end;
procedure zfree(opaque:pointer; ptr:pointer) ;
begin
	fz_free(ptr);
end;


function read_flated(stm:pfz_stream_s;outbuf:pbyte;outlen:integer):integer;
var
	state:pfz_flate_s;
  chain:pfz_stream_s;
  zp:z_streamp;
	code:integer;
begin
  state:=stm^.state;
  chain := state^.chain;
  zp := @state^.z;
	zp^.next_out :=pointer(cardinal(outbuf)); //pbytef(outbuf);
	zp^.avail_out := outlen;

	while (zp.avail_out > 0)  do
	begin
		if (cardinal(chain^.rp) = cardinal(chain^.wp))  then
			fz_fill_buffer(chain);

		zp^.next_in :=pointer(cardinal( chain^.rp));
		zp^.avail_in := cardinal(chain^.wp) - cardinal(chain^.rp);

		code := inflate(TZStreamRec(zp^), Z_SYNC_FLUSH);

		chain^.rp :=pointer( cardinal(chain^.wp) - cardinal(zp.avail_in));

		if (code = Z_STREAM_END) then
		begin
			result:=outlen - zp.avail_out;
      exit;
		end
		else if (code = Z_BUF_ERROR) then
		begin
			fz_warn('premature end of data in flate filter');
			result:= outlen - zp.avail_out;
      exit;
		end
		else if (code = Z_DATA_ERROR) and (zp.avail_in = 0)  then
		begin
		 	fz_warn('ignoring zlib error: %s', [zp.msg]);
			result:=outlen - zp^.avail_out;
      exit;
		end
		else if (code <> Z_OK) then
		begin
			result:= fz_throw('zlib error: %s', [zp.msg]);
         // ³ö´í
      exit;
		end;
	end;

	result:= outlen - zp^.avail_out;
end;

procedure close_flated(stm:pfz_stream_s)  ;
var
 state:pfz_flate_s;
 code:integer;
begin
	state := stm^.state;
	code := inflateEnd(TZStreamRec(state^.z));
	if (code <> Z_OK)  THEN
		fz_warn('zlib error: inflateEnd: %s;', [state^.z.msg]);

	fz_close(state^.chain);
	fz_free(state);
end;

FUNCTION  fz_open_flated(chain:pfz_stream_s):Pfz_stream_S;
VAR
	state:Pfz_flate_S;
	code:INTEGER;
BEGIN
	state := fz_malloc(sizeof(fz_flate_s));
	state^.chain := chain;

	state^.z.zalloc := zalloc;
	state^.z.zfree := zfree;
	state^.z.opaque := nil;
	state^.z.next_in := nil;
	state^.z.avail_in := 0;

	code := inflateInit(TZStreamRec(state^.z));
	if (code <> Z_OK) then
		fz_warn('zlib error: inflateInit: %s', [state^.z.msg]);


	result:=fz_new_stream(state, read_flated, close_flated);
END;



function  fz_open_jbig2d(chain:pfz_stream_s;  global:pfz_buffer_s):pfz_stream_s;
begin
  result:=nil;
end;



//* ASCII 85 Decode */
type
pfz_a85d_s=^fz_a85d_s;
fz_a85d_s=record
	chain:pfz_stream_s;
	bp:array[0..3] of byte;
	rp, wp:pbyte;
	eod:integer;
end;

function read_a85d(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	state:pfz_a85d_s;
	p,ep:pbyte;
	 count:integer;
	word :integer;
	c:integer;
begin
  state := stm^.state;
	p := buf;
	ep := buf;
  inc(ep, + len);
	count := 0;
	word := 0;

	while (cardinal(state^.rp) < cardinal(state^.wp)) and ((cardinal(p) < cardinal(ep))) do
  begin
		p^:=state^.rp^;
    inc(p);
    inc(state^.rp);
  end;
	while (cardinal(p) < cardinal(ep)) do
	begin
		if (state^.eod<>0) then
    begin
			result:=cardinal(p) -cardinal( buf);
      exit;
    end;

		c := fz_read_byte(state^.chain);
		if (c < 0) then
    begin
			result:=cardinal(p) -cardinal( buf);
      exit;
    end;

		if (c >= ord('!')) and (c <= ord('u')) then
		begin
			if (count = 4) then
			begin
				word := word * 85 + (c - ord('!'));

				state^.bp[0] := (word shr 24) and $ff;
				state^.bp[1] := (word shr 16) and $ff;
				state^.bp[2] := (word shr 8) and $ff;
				state^.bp[3] := (word) and $ff;
				state^.rp := @state^.bp;
				state^.wp := @state^.bp ;
        inc(state^.wp,+ 4);

				word := 0;
				count := 0;
			end
			else
			begin
				word := word * 85 + (c - ord('!'));
				count:=count+1;
			end;
		end

		else if (c = ord('z')) and (count = 0)  then
		begin
			state^.bp[0] := 0;
			state^.bp[1] := 0;
			state^.bp[2] := 0;
			state^.bp[3] := 0;
			state^.rp := @state^.bp;
			state^.wp := pointer(cardinal(state^.bp) + 4);
		end

		else if (c = ord('~')) then
		begin
			c := fz_read_byte(state^.chain);
			if (c <>ord( '>')) then
      begin
				fz_warn('bad eod marker in a85d');
      end;

			case (count) of
			0:
				dddd;
			1:
        begin
				  result:=fz_throw('partial final byte in a85d');
          exit;
        end;
			2:
        begin
				word := word * (85 * 85 * 85) + $ffffff;
				state^.bp[0] := word shr 24;
				state^.rp := @state^.bp;
				state^.wp := @state^.bp;
        inc( state^.wp,+ 1);
				end;
			3:
        begin
				word := word * (85 * 85) + $ffff;
				state^.bp[0] := word shr 24;
				state^.bp[1] := word shr 16;
				state^.rp := @state^.bp;
				state^.wp := @state^.bp;
        inc( state^.wp,+ 2);
				end;
			4:
        begin
        word := word * 85 + $ff;
				state^.bp[0] := word shr 24;
				state^.bp[1] := word shr 16;
				state^.bp[2] := word shr 8;
				state^.rp := @state^.bp;
        state^.wp := @state^.bp;
				inc( state^.wp,+ 3);
				end;
			end;
			state^.eod := 1;
		end

		else if (iswhite1(chr(c))) then
		begin
			result:= fz_throw('bad data in a85d: %c', [c]);
		end;

		while (cardinal(state^.rp) < cardinal(state^.wp)) and ((cardinal(p) < cardinal(ep)))  do
    begin
      p^:=state^.rp^;
      inc(p);
      inc(state^.rp);
     end;
	end;

		result:=cardinal(p) -cardinal( buf);
end;

procedure close_a85d(stm:pfz_stream_s);
var
	state:pfz_a85d_s;
begin
  state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;

function fz_open_a85d(chain:pfz_stream_s):pfz_stream_s;
var
	state:pfz_a85d_s;
begin
	state := fz_malloc(sizeof(fz_a85d_s));
	state^.chain := chain;
	state^.rp := @state^.bp;
	state^.wp := @state^.bp;
	state^.eod := 0;

	result:=fz_new_stream(state, read_a85d, close_a85d);
end;






type
 pfz_aesd_s=^fz_aesd_s;
 fz_aesd_s=record
	chain:pfz_stream_s;
	aes:fz_aes_s;
	iv:array[0..15] of byte;
	ivcount:integer;
	 bp:array[0..15] of byte;
	rp, wp:pbyte;
end;

function read_aesd(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
var
	state:pfz_aesd_s;
	p,ep:pbyte;
  c,n,pad:integer;
begin
  state := stm^.state;
	p := buf;
	ep := buf;
  inc(ep, + len);

	while (state^.ivcount < 16) do
	begin
		c := fz_read_byte(state^.chain);
		if (c < 0) then
    begin
			result:=fz_throw('premature end in aes filter');
      exit;
    end;
		state^.iv[state^.ivcount] := c;
    state^.ivcount:=state^.ivcount+1;
	end;

	while (cardinal(state^.rp) < cardinal(state^.wp)) and (cardinal(p) < cardinal(ep))  do
  begin
     p^:=state^.rp^;
     inc(p);
     inc(state^.rp);

  end;

	while (cardinal(p) < cardinal(ep)) do
	begin
		n := fz_read(state^.chain, @state^.bp, 16);
		if (n < 0) then
    begin
			result:=fz_rethrow(n, 'read error in aes filter');
      exit;
    end
		else if (n = 0) then
    begin
			result:=cardinal(p) - cardinal(buf);
      exit;
    end
		else if (n < 16) then
    begin
			result:=fz_throw('partial block in aes filter');
      exit;
    end;


		aes_crypt_cbc(@state^.aes, AES_DECRYPT, 16, state^.iv, @state^.bp, @state^.bp);
		state^.rp := @state^.bp;
		state^.wp := pointer(cardinal(@state^.bp) + 16);

		//* strip padding at end of file */
		if (fz_is_eof(state^.chain))<>0 then
		begin
			pad := state^.bp[15];
			if (pad < 1) or (pad > 16) then
      begin
			  result:= fz_throw('aes padding out of range: %d', [pad]);
        exit;
      end;
			inc(state^.wp, - pad);
		end;
    while (cardinal(state^.rp) < cardinal(state^.wp)) and (cardinal(p) < cardinal(ep))  do
		begin
     p^:=state^.rp^;
     inc(p);
     inc(state^.rp);
    end;
	end;

	result:=cardinal(p) - cardinal(buf);
end;

procedure close_aesd(stm:pfz_stream_s) ;
var
	state:pfz_aesd_s;
begin
  state := stm^.state;
	fz_close(state^.chain);
	fz_free(state);
end;



function  fz_open_aesd(chain:pfz_stream_s;  key:pbyte; keylen:integer):pfz_stream_s;
var
	state:pfz_aesd_s;
begin
	state := fz_malloc(sizeof(fz_aesd_s));
	state^.chain := chain;
	aes_setkey_dec(@state^.aes, key, keylen * 8);
	state^.ivcount := 0;
	state^.rp := @state^.bp;
	state^.wp := @state^.bp;

	result:=fz_new_stream(state, read_aesd, close_aesd);
end;

end.
