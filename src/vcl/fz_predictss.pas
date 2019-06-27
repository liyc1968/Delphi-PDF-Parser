unit fz_predictss;

interface
uses  SysUtils,digtypes,FZ_mystreams,math,base_error;
const
MAXC = 32 ;
type
pfz_predict_s=^fz_predict_s;
fz_predict_s=record
	chain:pfz_stream_s;
  predictor:integer;
	columns:integer;
	colors:integer;
	bpc:integer;
  stride:integer;
  bpp:integer;
	inp:pbyte;
	outp:pbyte;
	ref:pbyte;
	rp:pbyte;
  wp:pbyte;
end;
function fz_open_predict(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
implementation
uses base_object_functions;
function getcomponent(line1:pbyte; x:integer; bpc:integer):integer;

var
line:byte_items;
begin
  line:=byte_items(line1);
	case bpc of
	1:
   begin
     result:=(line[x shr 3] shr ( 7 - (x and 7) ) ) and 1;
     exit;
   end;
	2:
   begin
     result:=(line[x shr 2] shr ( ( 3 - (x and 3) ) shl 1 ) ) and 3;
     exit;
   end;
	4:
   begin
     result:=(line[x shr 1] shr ( ( 1 - (x and 1) ) shl 2 ) ) and 15;
     exit;
   end;
	8:
  begin
     result:=line[x];
     exit;
	end;
  end;
	result:=0;
end;


procedure putcomponent(buf1:pbyte; x:integer;bpc:integer;value:integer);

var
buf:byte_items;
begin
  buf:=byte_items(buf1);
	case (bpc) of
	1:
  begin
    buf[x shr 3] :=buf[x shr 3] or ( value shl (7 - (x and 7)));
    exit;
  end;
	2:
  begin
    buf[x shr 2] :=buf[x shr 2] or ( value shl ((3 - (x and 3)) shl 1));
    exit;
  end;
	4:
  begin
    buf[x shr 1] :=buf[x shr 1] or ( value shl ((1 - (x and 1)) shl 2));
    exit;
  end;
	8:
  begin
    buf[x] := value;
    exit;
  end;
  end;
end;

function paeth(a:integer; b:integer; c:integer):integer;
var
 ac,pa,pb,pc,bc,abcc:integer;
begin
	//* The definitions of ac and bc are correct, not a typo. */
	ac := b - c;
  bc := a - c;
  abcc := ac + bc;
	pa := ABS(ac);
	pb := ABS(bc);
	pc := ABS(abcc);
  if (pa<=pb) and  (pa <= pc) then
  result:=a
  else
  if  pb <= pc then
  result:=b
  else
  result:=c;

end;

procedure fz_predict_tiff(state:pfz_predict_s;outp:pbyte; inp:pbyte;len:integer);
var
	left:array[0..MAXC-1] of integer;
	a,b,c,i, k:integer;
begin
	for k := 0 to state^.colors-1 do
		left[k] := 0;

	for i := 0 to state^.columns-1 do
	begin
		for k := 0 to state^.colors-1 do
		begin
			a := getcomponent(inp, i * state^.colors + k, state^.bpc);
			b := a + left[k];
			c := b mod (1 shl state^.bpc);
			putcomponent(outp, i * state^.colors + k, state^.bpc, c);
			left[k] := c;
		end;
	end;
end;

procedure fz_predict_png(state:pfz_predict_s;outp:pbyte; inp:pbyte; len:integer;predictor:integer);
var
	bpp:integer;
	i:integer;
	ref:pbyte;
begin
  bpp := state^.bpp;
  ref := state^.ref;
	case predictor of
  0:
  begin
	 //	copymemory(outp, inp, len);
   	move(inp^,outp^,  len);
		exit;
  end;
	1:
  begin
		for i := bpp downto 1 do
		begin
    outp^:=inp^;
    inc(outp);
    inc(inp);
		end;
		for i := len - bpp downto 1 do
		begin
			outp^:=inp^ + byte_items(outp)[-bpp];
      inc(outp);
      inc(inp);
		end;
  	exit;
  end;
	2:
  begin
		for i := bpp downto 1 do
		begin
      outp^:=inp^+ref^;
      inc(outp);
      inc(inp);
			inc(ref);
		end;
		for i := len - bpp downto 1 do
		begin
			outp^:=inp^+ref^;
      inc(outp);
      inc(inp);
			inc(ref);
		end;
		exit;
  end;
	 3:
  begin
		for i := bpp downto 1 do
		begin
		  outp^:=inp^+ref^ div 2;
      inc(outp);
      inc(inp);
			inc(ref);

		end;
		for i := len - bpp downto 1 do
		begin
			outp^:=inp^+(ref^+byte_items(outp)[-bpp]) div 2;
      inc(outp);
      inc(inp);
			inc(ref);

		end;
		exit;
  end;
	 4:
  begin
		for i := bpp downto 1 do
		begin

     	outp^:=inp^+paeth(0, ref^ ,0);
      inc(outp);
      inc(inp);
			inc(ref);

		end;
		for i := len - bpp downto 1 do
		begin
      outp^:=inp^+paeth( byte_items(outp)[-bpp] ,ref^,byte_items(ref)[-bpp]);
      inc(outp);
      inc(inp);
			inc(ref);


		end;
		exit;
	end;
  end;
end;

function read_predict(stm:pfz_stream_s;buf:pbyte; len:integer):integer;
var
	state:pfz_predict_s;
	p ,ep:pbyte;
	ispng:integer;
	n:integer;
begin
  state := stm^.state;
  p := buf;
  ep := pointer(cardinal(buf) + len);
  ispng :=0;
  if  state^.predictor >= 10 then
  ispng := 1;

	while (cardinal(state^.rp) < cardinal(state^.wp)) and (cardinal(p) < cardinal(ep))  do
  begin
    p^:=state^.rp^;
		INC(P);
    inc(state^.rp);
  end;
	while (cardinal(p) < cardinal(ep)) do
	begin
		n := fz_read(state^.chain, state^.inp, state^.stride + ispng);
		if (n < 0)  then
    begin
		 result:= fz_rethrow(n, 'read error in prediction filter');
     exit;
    end;
		if (n = 0) then
    begin
			result:=cardinal(p) - cardinal(buf);
      exit;
    end;

		if (state^.predictor = 1) then
			//copymemory(state^.outp, state^.inp, n)
      move(state^.inp^, state^.outp^, n)
		else if (state^.predictor = 2) then
			fz_predict_tiff(state, state^.outp, state^.inp, n)
		else
		begin
			fz_predict_png(state, state^.outp, pointer(cardinal(state^.inp) + 1), n - 1, state^.inp^);
			//copymemory(state^.ref, state^.outp, state^.stride);
      move(state^.outp^,state^.ref^,  state^.stride);
		end;

		state^.rp := state^.outp;
		state^.wp := pointer(cardinal(state^.outp) + n - ispng);

		while (cardinal(state^.rp) < cardinal(state^.wp)) and (cardinal(p) < cardinal(ep)) do
    begin
      p^:=state^.rp^;
      inc(p);
      inc(  state^.rp);

    end;
	end;

	result:= cardinal(p) - cardinal(buf);
end;

procedure close_predict(stm:pfz_stream_s);
var
  state:pfz_predict_s;
begin
	state := stm^.state;
	fz_close(state^.chain);
	fz_free(state^.inp);
	fz_free(state^.outp);
	fz_free(state^.ref);
	fz_free(state);
end;

function fz_open_predict(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
var
	state:pfz_predict_s;
	obj:pfz_obj_s;
begin
	state := fz_malloc(sizeof(fz_predict_s));
	state^.chain := chain;

	state^.predictor := 1;
	state^.columns := 1;
	state^.colors := 1;
	state^.bpc := 8;

	obj := fz_dict_gets(params, 'Predictor');
	if (obj<>nil) then
		state^.predictor := fz_to_int(obj);

	if ((state^.predictor <> 1) and (state^.predictor <> 2) and
		(state^.predictor <> 10) and  (state^.predictor <> 11) and
		(state^.predictor <> 12) and  (state^.predictor <> 13) and
		(state^.predictor <> 14) and (state^.predictor <> 15)) then
	begin
		fz_warn('invalid predictor: %d', [state^.predictor]);
		state^.predictor := 1;
	end;

	obj := fz_dict_gets(params, 'Columns');
	if (obj<>nil) then
		state^.columns := fz_to_int(obj);

	obj := fz_dict_gets(params, 'Colors');
	if (obj<>nil) then
		state^.colors := fz_to_int(obj);

	obj := fz_dict_gets(params, 'BitsPerComponent');
	if (obj<>nil) then
		state^.bpc := fz_to_int(obj);

	state^.stride := (state^.bpc * state^.colors * state^.columns + 7) div 8;
	state^.bpp:= (state^.bpc * state^.colors + 7) div 8;

	state^.inp := fz_malloc(state^.stride + 1);
	state^.outp := fz_malloc(state^.stride);
	state^.ref := fz_malloc(state^.stride);
	state^.rp := state^.outp;
	state^.wp := state^.outp;

	fillchar(state^.ref^, state^.stride, 0);

	result:=fz_new_stream(state, read_predict, close_predict);
end;



end.
