unit res_bitpamss;

interface
uses SysUtils,digtypes,digcommtype,base_error;
implementation
uses base_object_functions;

function fz_new_bitmap( w, h, n:integer):pfz_bitmap_s;
var
	bit:pfz_bitmap_s;
begin
	bit := fz_malloc(sizeof(fz_bitmap_s));
	bit^.refs := 1;
	bit^.w := w;
	bit^.h := h;
	bit^.n := n;
	//* Span is 32 bit aligned. We may want to make this 64 bit if we
	// * use SSE2 etc. */
	bit^.stride := ((n * w + 31) and (not 31)) shr 3;

	bit^.samples := fz_calloc(h, bit^.stride);

	result:= bit;
end;

function fz_keep_bitmap( pix:pfz_bitmap_s) :pfz_bitmap_s;
begin
	pix^.refs:=pix^.refs+1;
	result:= pix;
end;

procedure fz_drop_bitmap(bit:pfz_bitmap_s) ;
begin
  if bit=nil then
  exit;
  bit^.refs:=bit^.refs-1;
	if (bit^.refs = 0) then
	begin
		fz_free(bit^.samples);
		fz_free(bit);
	end;
end;

procedure fz_clear_bitmap(bit:pfz_bitmap_s);
begin
	zeromemory(bit^.samples, bit^.stride * bit^.h);
end;

//*
 //* Write bitmap to PBM file
 //*/

function
fz_write_pbm(bitmap:pfz_bitmap_s; filename:pchar):integer;
var
	fp:cardinal;
	p:pbyte;
	 h, bytestride:integer;
   BUF:PCHAR;
   s:string;
   i:integer;
begin
	fp := FileOpen(filename, $FFFF	);

	if (fp=CARDINAL(-1)) then
  begin
		result:= fz_throw('cannot open file "%s"', [filename]);
    exit;
  end;

	assert(bitmap^.n = 1);
  s:=format('P4\n%d %d\n', [bitmap^.w, bitmap^.h]);
  i:=length(s);
  buf:=pchar(s);
  filewrite(fp,buf,i);
	p := bitmap^.samples;
	h := bitmap^.h;
	bytestride := (bitmap^.w + 7) shr 3;
	while (h<>0) do
	begin
		filewrite(fp,p^,  bytestride);
		inc(p, + bitmap^.stride);
	end;
	fileclose(fp);
	result:=1;
end;

end.
