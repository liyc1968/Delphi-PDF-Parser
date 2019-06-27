unit FZ_mystreams;

interface
   uses SysUtils,digtypes,Math,base_error;
const
  errno=1;
 function fz_new_stream(state:pointer;	read:read1;close:close1)  :pfz_stream_s ;
 function fz_keep_stream(stm:pfz_stream_s):pfz_stream_s ;
 procedure fz_close(stm:pfz_stream_s);
 function read_file(stm:pfz_stream_s;  buf:pbyte;len:integer):integer;
 procedure seek_file(stm:pfz_stream_s; offset:integer; whence:integer);
 procedure close_file(stm:pfz_stream_s)  ;
 function fz_open_fd(fd:cardinal):pfz_stream_s ;
 function fz_open_file(const name:pchar) :pfz_stream_s ;
 function fz_open_file_w(const name:pwidechar) :pfz_stream_s ;         //还没有支持UNICODE
 function read_buffer(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
 procedure seek_buffer(stm:pfz_stream_s; offset:integer; whence:integer);
 procedure close_buffer(stm:pfz_stream_s);
 function fz_open_buffer(buf:pfz_buffer_s):pfz_stream_s;
 function fz_open_memory(data:pbyte; len:integer):pfz_stream_s;
 function fz_read(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
 procedure fz_fill_buffer(stm:pfz_stream_s);
 function fz_read_all(bufp:ppfz_buffer_s; stm:pfz_stream_s; initial:integer):integer;
 //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692260 */
 function fz_read_all2(bufp:ppfz_buffer_s; stm:pfz_stream_s; initial:integer; fail_on_error:integer):integer;
 function fz_read_byte(stm:pfz_stream_s):integer;
 function fz_peek_byte(stm:pfz_stream_s) :integer;
 procedure fz_unread_byte(stm:pfz_stream_s);
 procedure fz_read_line(stm:pfz_stream_s;MEM:POINTER; n:integer);
 function fz_tell(stm:pfz_stream_s):integer;
 procedure fz_seek(stm:pfz_stream_s;offset, whence:integer);
 function fz_is_eof(stm:pfz_stream_s):integer;
 function fz_is_eof_bits(stm:pfz_stream_s):boolean;
 function fz_read_bits(stm:pfz_stream_s; n:integer):dword;
implementation
uses base_object_functions;

function fz_new_stream(state:pointer;	read:read1;close:close1)  :pfz_stream_s ;
var
  stm:pfz_stream_s;
begin
	stm := fz_malloc(sizeof(fz_stream_s));
	stm^.refs := 1;
	stm^.error := 0;
	stm^.eof := 0;
	stm^.pos := 0;
	stm^.bits := 0;
	stm^.avail := 0;
	stm^.bp := @stm^.buf;
	stm^.rp := stm^.bp;
	stm^.wp := stm^.bp;
	stm^.ep := pointer(cardinal(@stm^.buf) + sizeof(stm^.buf));
	stm^.state := state;
	stm^.read := read;
	stm^.close := close;
	stm^.seek := nil;
	result:=stm;
end;

function fz_keep_stream(stm:pfz_stream_s):pfz_stream_s ;
begin
	stm^.refs:=stm^.refs+1;
	result:=stm;
end;

procedure fz_close(stm:pfz_stream_s);
begin
  if stm=nil then
  exit;
	stm^.refs:=stm^.refs-1;
	if (stm^.refs = 0) then
	begin
		if (@stm^.close<>nil) then
			stm^.close(stm);
		fz_free(stm);
	end;
end;

//* File stream */

function read_file(stm:pfz_stream_s;  buf:pbyte;len:integer):integer;
var
n:integer;
//PP:STRING;
begin

	 n := FileRead(cardinal(stm^.state^), buf^, len);
  // PP:=STRING(BUF);

	if (n < 0) then
  begin
	 result:= fz_throw('read error: %s', [strerror(errno)]);
   exit;
  end;
	result:=n;
end;

procedure seek_file(stm:pfz_stream_s; offset:integer; whence:integer);
var
n:integer;
begin
	 n := fileseek(cardinal(stm^.state^), offset, whence);
	if (n < 0) then
	 	fz_warn('cannot lseek: %s', [strerror(errno)]);

	stm^.pos := n;
	stm^.rp := stm^.bp;
	stm^.wp := stm^.bp;
end;

procedure close_file(stm:pfz_stream_s)  ;
var
//n:integer;
f:pinteger;
begin
  f:= stm^.state;
   FileClose(f^);
 //	if (n < 0) then
	//	fz_warn('close error: %s', [strerror(errno)]);
	fz_free(stm^.state);
end;


function fz_open_fd(fd:cardinal):pfz_stream_s ;
var
	stm:pfz_stream_s;
	state:pointer;
begin
	state := fz_malloc(sizeof(cardinal));
	cardinal(state^):= fd;

	stm := fz_new_stream(state, read_file, close_file);
	stm^.seek := seek_file;

	result:=stm;
end;

function fz_open_file(const name:pchar) :pfz_stream_s ;
var
fd:cardinal;
begin
	fd := FileOpen(name, fmShareDenyNone or fmOpenRead);
	if (fd = cardinal(-1)) then
		result:=nil
    else
	 result:=fz_open_fd(fd);
end;



function fz_open_file_w(const name:pwidechar) :pfz_stream_s ;         //还没有支持UNICODE
var
fd:cardinal;
begin
	fd := FileOpen(name, fmShareDenyNone or fmOpenRead);
	if (fd = cardinal(-1)) then
		result:=nil
    else
	 result:=fz_open_fd(fd);
end;

//* Memory stream */

function read_buffer(stm:pfz_stream_s; buf:pbyte;len:integer):integer;
begin
	result:=0;
end;

function CLAMPP(x,a,b:pointer):pointer;
begin
 if cardinal(x)>cardinal(b) then
   result:=b
   else
   begin
     if cardinal(x)<cardinal(a) then
     result:=a
     else
     result:=x;
   end;

end;

procedure seek_buffer(stm:pfz_stream_s; offset:integer; whence:integer);
begin
	if (whence = 0) then
		stm^.rp :=pointer(cardinal(stm^.bp) + offset);
	if (whence = 1) then
		stm^.rp :=pointer(cardinal(stm^.rp) + offset);
	if (whence = 2) then
		stm^.rp :=pointer(cardinal(stm^.ep) - offset);
	stm^.rp := CLAMPP(stm^.rp, stm^.bp, stm^.ep);
	stm^.wp := stm^.ep;
end;

procedure close_buffer(stm:pfz_stream_s);
begin
	if (stm^.state<>nil) then
		fz_drop_buffer(stm^.state);
end  ;

function fz_open_buffer(buf:pfz_buffer_s):pfz_stream_s;
var
	stm:pfz_stream_s;
begin
	stm := fz_new_stream(fz_keep_buffer(buf), read_buffer, close_buffer);
	stm^.seek := seek_buffer;

	stm^.bp := buf^.data;
	stm^.rp := buf^.data;
	stm^.wp :=pointer(cardinal(buf^.data) + buf^.len);
	stm^.ep := pointer(cardinal(buf^.data) + buf^.len);
	stm^.pos := buf^.len;
	result:=stm;
end;

function fz_open_memory(data:pbyte; len:integer):pfz_stream_s;
var
	stm:pfz_stream_s;

begin
	stm := fz_new_stream(nil, read_buffer, close_buffer);
	stm^.seek := seek_buffer;

	stm^.bp := data;
	stm^.rp := data;
	stm^.wp := pointer(cardinal(data) + len);
	stm^.ep := pointer(cardinal(data) + len);

	stm^.pos := len;

	result:=stm;
end;



function fz_read(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	count, n:integer;
  p:pbyte;
begin
	count := MIN(len, cardinal(stm^.wp) - cardinal(stm^.rp));
	if (count<>0) then
	begin
		copymemory(buf, stm^.rp, count);
		stm^.rp:=pointer(cardinal(stm^.rp)+ count);
	end;

	if ((count = len) or (stm^.error<>0) or (stm^.eof<>0))    then
  begin
		result:=count;
    exit;
  end;
	assert(stm^.rp = stm^.wp);

	if (len - count < cardinal(stm^.ep) - cardinal(stm^.bp)) then
	begin
		n := stm^.read(stm, stm^.bp, cardinal(stm^.ep) - cardinal(stm^.bp));
		if (n < 0) then
		begin
			stm^.error := 1;
      result:=fz_rethrow(n, 'read error');
      exit;
			//return
		end
		else if (n = 0) then
		begin
			stm^.eof := 1;
		end
		else if (n > 0) then
		begin
			stm^.rp := stm^.bp;
			stm^.wp := pointer(cardinal(stm^.bp) + n);
			stm^.pos :=stm^.pos + n;
		end;

		n := MIN(len - count, cardinal(stm^.wp) - cardinal(stm^.rp));
		if (n<>0) then
		begin
			copymemory(pointer(cardinal(buf) + count), stm^.rp, n);
			stm^.rp:=pointer(cardinal(stm^.rp)+ n);
			count:=count+n;
		end;
	end
	else
	begin
    p:=pointer(cardinal(buf) + count);

		n := stm^.read(stm,p , len - count);
		if (n < 0) then
		begin
			stm^.error := 1;
		 result:= fz_rethrow(n, 'read error');
     exit;
		end
		else if (n = 0) then
		begin
			stm^.eof := 1;
		end
		else if (n > 0)then
		begin
			stm^.pos:=stm^.pos+ n;
			count :=count+ n;
		end;
	end;

	result:= count;
end;

procedure fz_fill_buffer(stm:pfz_stream_s);
var
	n:integer;
begin
	assert(stm^.rp = stm^.wp);

	if (stm^.error<>0) or  (stm^.eof<>0) then
  exit;

	n := stm^.read(stm, stm^.bp, cardinal(stm^.ep) - cardinal(stm^.bp));
	if (n < 0) then
	begin
		stm^.error := 1;
		fz_catch(n, 'read error; treating as end of file');

    exit;

	end
	else if (n = 0) then
	begin
		stm^.eof := 1;
	end
	else if (n > 0) then
	begin
		stm^.rp := stm^.bp;
		stm^.wp :=pointer(cardinal(stm^.bp) + n);
		stm^.pos :=stm^.pos+ n;
	end;
end;

 //* cf. http://bugs.ghostscript.com/show_bug.cgi?id=692260 */

function fz_read_all2(bufp:ppfz_buffer_s; stm:pfz_stream_s; initial:integer; fail_on_error:integer):integer;
var
	buf:pfz_buffer_s;
	n:integer;
begin
	if (initial < 1024) then
		initial := 1024;

	buf := fz_new_buffer(initial);

	while (true)  do
	begin
		if (buf^.len = buf^.cap) then
			fz_grow_buffer(buf);

		if (buf^.len / 200 > initial)  then
		begin
			fz_drop_buffer(buf);
			result:= fz_throw('compression bomb detected');
      exit;
		end;

		n := fz_read(stm, pointer(cardinal(buf^.data) + buf^.len), buf^.cap - buf^.len);
		if ((n < 0) and ((fail_on_error<>0) or (buf^.len = 0))) then
		begin
			fz_drop_buffer(buf);
			result:= fz_rethrow(n, 'read error');
      exit;
		end;
		if (n < 0)  then
    begin
			result:=fz_catch(n, 'capping stream at read error');
      exit;
    end;
		if (n = 0) then
			break;

		buf^.len :=buf^.len+ n;
	end;

	bufp^ := buf;
	result:=1;
end;

function fz_read_all(bufp:ppfz_buffer_s; stm:pfz_stream_s; initial:integer):integer;
begin
result:=fz_read_all2(bufp, stm, initial, 1);
end;


function fz_read_byte(stm:pfz_stream_s):integer;
begin
	if (cardinal(stm^.rp) = cardinal(stm^.wp)) then
	begin
		fz_fill_buffer(stm);
    if cardinal(stm^.rp)<cardinal(stm^.wp) then
    begin


       
       	result:=stm^.rp^;
        inc(stm^.rp,1);

       exit;
    end
    else
    begin
      result:=eeof;
      exit;
    end;
	end;

	result:=stm^.rp^;
  inc(stm^.rp,1);

       exit;
end;

function fz_peek_byte(stm:pfz_stream_s) :integer;
begin
		if (cardinal(stm^.rp) = cardinal(stm^.wp)) then
	begin
		fz_fill_buffer(stm);
    if cardinal(stm^.rp)<cardinal(stm^.wp) then
    begin
       result:=stm^.rp^;
     
       exit;
    end
    else
    begin
      result:=eeof;
      exit;
    end;
	end;

	result:=stm^.rp^;

       exit;
end;

procedure fz_unread_byte(stm:pfz_stream_s);
begin
	if (cardinal(stm^.rp) > cardinal(stm^.bp)) then
		inc(stm^.rp,-1);
end ;

function fz_is_eof(stm:pfz_stream_s):integer;
begin
	if (stm^.rp = stm^.wp) then
	begin
		if (stm^.eof<>0) then
    begin
    result:=1;
    exit;
		end;
    if fz_peek_byte(stm)= EEOF then
		result:=1
    else
    result:=0;
    exit;
	end;
	result:= 0;
end;

procedure fz_read_line(stm:pfz_stream_s;  mem:POINTER; n:integer);
var
  s:pchar;
	c:integer;
begin
  c:=eeof;
  s:=mem;
	while (n > 1) do
  begin
		c := fz_read_byte(stm);
		if (c = eEOF) then
			break;
		if (c =13) then    //\r
    begin
			c := fz_peek_byte(stm);
			if (c = 10) then     //\n
				fz_read_byte(stm);
			break;
		end;
		if (c =10) then  //\n
			break;

     s^:=chr(c);
     inc(s);
		 n:=n-1;
    // OutputDebugString(S);
	end ;
	if (n<>0) then
    s^:=#0;
 
end;

function fz_tell(stm:pfz_stream_s):integer;
begin
	result:= stm^.pos - (cardinal(stm^.wp) - cardinal(stm^.rp));
end;

procedure fz_seek(stm:pfz_stream_s;offset, whence:integer);
var
p:pbyte;
begin
	if (@stm^.seek<>nil) then
	begin
		if (whence = 1) then
		begin
			offset := fz_tell(stm) + offset;
			whence := 0;
		end;
		if (whence = 0) then
		begin
     p := pointer(cardinal(stm^.wp) - (stm^.pos - offset));
			if (cardinal(p) >= cardinal(stm^.bp)) and (cardinal(p) <= cardinal(stm^.wp)) then
			begin
				stm^.rp := p;
				stm^.eof := 0;
				exit;
			end;
		end;
		stm^.seek(stm, offset, whence);
		stm^.eof := 0;
	end
	else if (whence <> 2) then
	begin
		if (whence = 0) then
			offset:=offset-fz_tell(stm);
		if (offset < 0) then
			fz_warn('cannot seek backwards');

	 //* dog slow, but rare enough */

		while (offset> 0) do
    begin
			fz_read_byte(stm);
      offset:=offset-1;
    end;
	end
	else
		fz_warn('cannot seek');
    exit;
end;

function fz_read_bits(stm:pfz_stream_s; n:integer):dword;
var
	 x:dword;
begin
	if (n <= stm^.avail) then
	begin
		stm^.avail :=stm^.avail - n;
		x := (stm^.bits shr stm^.avail) or ((1 shl n) - 1);
	end
	else
	begin
		x := stm^.bits and ((1 shl stm^.avail) - 1);
		n :=n - stm^.avail;
		stm^.avail := 0;

		while (n > 8) do
		begin
			x := (x shl 8) or fz_read_byte(stm);
			n :=n - 8;
		end;

		if (n > 0) then
		begin
			stm^.bits := fz_read_byte(stm);
			stm^.avail := 8 - n;
			x := (x shl n) or (stm^.bits shr stm^.avail);
		end;
	end;

	result:= x;
end;

procedure fz_sync_bits(stm:pfz_stream_s);
begin
	stm^.avail := 0;
end;

function fz_is_eof_bits(stm:pfz_stream_s):boolean;
begin
	result:= ((fz_is_eof(stm)=1) and ((stm^.avail = 0) or (stm^.bits = eEOF)));
end;




end.
