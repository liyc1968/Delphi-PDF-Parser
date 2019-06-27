unit filt_dctdss;

interface
uses
SysUtils,Math,digtypes,QSort1,base_object_functions,FZ_mystreams,zlibh,base_error, myyjump,jmorecfg,
  jpeglib,
  jerror,
  jdeferr,
  jdmarker,
  jdmaster,
  jdapimin,
  jdapistd,
  jcparam,
  jcapimin,
  jcapistd,
  jcomapi;
type
pfz_dctd_s=^fz_dctd_s;
fz_dctd_s=record
	chain:pfz_stream_s;
	color_transform:integer;
	init:integer;
	stride:integer;
	scanline:pbyte;
	rp, wp:pbyte;
	cinfo:jpeg_decompress_struct;
	srcmgr:jpeg_source_mgr;
	errmgr:jpeg_error_mgr ;
	jb:jmp_buf;
	msg:array[0..JMSG_LENGTH_MAX-1] of char;
end;


function  fz_open_dctd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;

implementation
procedure error_exit(cinfo:j_common_ptr);
var
  state:pfz_dctd_s;
  s:string;
begin
	state := cinfo^.client_data;
  s:=state^.msg;
	cinfo^.err^.format_message(cinfo, s);
	longjmp(state^.jb, 1);
end;

PROCEDURE init_source(cinfo:j_decompress_ptr );
begin
	//* nothing to do */
end;

procedure term_source(cinfo:j_decompress_ptr );
begin
	//* nothing to do */
end;

function fill_input_buffer(cinfo:j_decompress_ptr ):boolean;
const
eoi:array[0..1] of byte=($FF, JPEG_EOI);
var
	src:jpeg_source_mgr_ptr;
	state:pfz_dctd_s;
	chain:pfz_stream_s;
 // eoi:array[0..1] of byte;
begin

  src := cinfo^.src;
	state := cinfo^.client_data;
	chain := state^.chain;
	chain^.rp := chain^.wp;
	fz_fill_buffer(chain);
	src^.next_input_byte := pointer(chain^.rp);

	src^.bytes_in_buffer := cardinal(chain^.wp) - cardinal(chain^.rp);

	if (src^.bytes_in_buffer = 0) then
	begin
	//	static unsigned char eoi[2] = { 0xFF, JPEG_EOI };
	 	fz_warn('premature end of file in jpeg');
		src^.next_input_byte := @eoi;
		src^.bytes_in_buffer := 2;
	end;

	result:=true;
end;

procedure skip_input_data(cinfo:j_decompress_ptr; num_bytes:longint) ;
var
  src:jpeg_source_mgr_ptr;
begin
  src := cinfo^.src;
	if (num_bytes > 0) then
	begin
		while (num_bytes > src^.bytes_in_buffer)   do
		begin
			num_bytes :=num_bytes - src^.bytes_in_buffer;
			 src^.fill_input_buffer(cinfo);
		end;
	 //	src^.next_input_byte :=src^.next_input_byte;
    inc(src^.next_input_byte, num_bytes);
		//src^.bytes_in_buffer :=	src^.bytes_in_buffer;
    inc(src^.bytes_in_buffer, - num_bytes);

	end;
end;

  function ByteClip(Value : Integer) : Integer;
  Begin
    if Value < 0 then Result := 0
    else if Value > 255 then Result := 255
    else Result := Value;
  end;

function  read_dctd(stm:pfz_stream_s; buf:pbyte; len:integer):integer;
var
	state:pfz_dctd_s;
	cinfo:j_decompress_ptr;
	p,ep:pbyte;
  CurPixel    : PChar;
  C, M, Y, K  : Integer;
  R, G, B, nI : Integer;
  D, E        : Integer;

begin
  state := stm^.state;
	cinfo := @state^.cinfo;
	p := buf;
	ep := buf;
  inc(ep, + len);
	if (setjmp(state^.jb)<>0) then
	begin
		if (cinfo^.src<>nil) then
			state^.chain^.rp := pointer(cardinal(state^.chain^.wp) - cardinal(cinfo^.src^.bytes_in_buffer));
		result:=fz_throw('jpeg error: %s', [state^.msg]);
    exit;
	end;

	if (state^.init=0) then
	begin
		cinfo^.client_data := state;
		cinfo^.err := @state^.errmgr;
		jpeg_std_error( cinfo^.err^);

		cinfo^.err^.error_exit := error_exit;
		jpeg_create_decompress(cinfo);
		cinfo^.src := @state^.srcmgr;
		cinfo^.src^.init_source := init_source;
		cinfo^.src^.fill_input_buffer := fill_input_buffer;
		cinfo^.src^.skip_input_data := skip_input_data;
		cinfo^.src^.resync_to_restart := jpeg_resync_to_restart;
		cinfo^.src^.term_source := term_source;
		cinfo^.src^.next_input_byte := pointer(state^.chain^.rp);
		cinfo^.src^.bytes_in_buffer := cardinal(state^.chain^.wp) - cardinal(state^.chain^.rp);

		jpeg_read_header(cinfo, true);

		//* speed up jpeg decoding a bit */
		cinfo^.dct_method := JDCT_FASTEST;
		cinfo^.do_fancy_upsampling := FALSE;

	 //	/* default value if ColorTransform is not set */
		if (state^.color_transform = -1) then
		begin
			if (state^.cinfo.num_components = 3) then
				state^.color_transform := 1
			else
				state^.color_transform := 0;
		end;

		if (cinfo^.saw_Adobe_marker) then
			state^.color_transform := cinfo^.Adobe_transform;

		//* Guess the input colorspace, and set output colorspace accordingly */
		case (cinfo^.num_components) of
		3:
			if (state^.color_transform<>0) then
				cinfo^.jpeg_color_space := JCS_YCbCr
			else
				cinfo^.jpeg_color_space := JCS_RGB;

		4:
			if (state^.color_transform<>0) then
				cinfo^.jpeg_color_space := JCS_YCCK
			else
				cinfo^.jpeg_color_space := JCS_CMYK;

		end;

		jpeg_start_decompress(cinfo);

		state^.stride := cinfo^.output_width * cinfo^.output_components;
		state^.scanline := fz_malloc(state^.stride);
		state^.rp := state^.scanline;
		state^.wp := state^.scanline;

		state^.init := 1;
	end;

	while (cardinal(state^.rp) < cardinal(state^.wp)) and (cardinal(p) < cardinal(ep)) do
  begin
	 //	*p++ = *state^.rp++;
    p^:=state^.rp^;
    inc(p);
    inc(state^.rp);
  end;

	while (cardinal(p) < cardinal(ep)) do
	begin
		if (cinfo^.output_scanline = cinfo^.output_height) then
			break;

		if (cardinal(p) + state^.stride <= cardinal(ep))  then
		begin
			jpeg_read_scanlines(cinfo, @P, 1);
      if cinfo^.out_color_space = JCS_YCbCr then
       Begin
                CurPixel := pchar(state^.scanline);

                for nI := 0 to cinfo^.image_width-1 do
                Begin
                  // YUV to RGB conversie
                  C := Integer(CurPixel[0]);
                  D := Integer(CurPixel[1]);
                  E := Integer(CurPixel[2]);

                  CurPixel[0] := Char(Byteclip(298 * C           + 409 * E + 128));
                  CurPixel[1] := Char(Byteclip(298 * C - 100 * D - 208 * E + 128));
                  CurPixel[2] := Char(Byteclip(298 * C + 516 * D           + 128));
                  Inc(CurPixel, 3);
                end;
        end;
      inc(p,state^.stride);
			//p += state^.stride;
		end
		else
		begin
			jpeg_read_scanlines(cinfo, @state^.scanline, 1);

       if cinfo^.out_color_space = JCS_YCbCr then
       Begin
                CurPixel := pchar(state^.scanline);

                for nI := 0 to cinfo^.image_width-1 do
                Begin
                  // YUV to RGB conversie
                  C := Integer(CurPixel[0]);
                  D := Integer(CurPixel[1]);
                  E := Integer(CurPixel[2]);

                  CurPixel[0] := Char(Byteclip(298 * C           + 409 * E + 128));
                  CurPixel[1] := Char(Byteclip(298 * C - 100 * D - 208 * E + 128));
                  CurPixel[2] := Char(Byteclip(298 * C + 516 * D           + 128));
                  Inc(CurPixel, 3);
                end;
        end;

			state^.rp := state^.scanline;
			state^.wp := state^.scanline;
      inc(state^.wp, + state^.stride);
		end;

		while (cardinal(state^.rp) < cardinal(state^.wp)) and ( cardinal(p) < cardinal(ep)) do
    begin
		 //	*p++ = *state^.rp++;
      p^:=state^.rp^;
      inc(p);
      inc(state^.rp);
    end;
	end;

	result:=cardinal(p) -cardinal( buf);
end;

procedure close_dctd(stm:pfz_stream_s);
var
  state:pfz_dctd_s;
  label skip;
begin
	state := stm^.state;

	if (setjmp(state^.jb)<>0) then
	begin
		state^.chain^.rp := pointer(cardinal(state^.chain^.wp) - state^.cinfo.src^.bytes_in_buffer);
		fz_warn('jpeg error: %s', [state^.msg]);
		goto skip;
	end;

	if (state^.init<>0) then
		jpeg_finish_decompress(@state^.cinfo);

skip:
	state^.chain^.rp := pointer(cardinal(state^.chain^.wp) - state^.cinfo.src^.bytes_in_buffer);
	jpeg_destroy_decompress(@state^.cinfo);
	fz_free(state^.scanline);
	fz_close(state^.chain);
	fz_free(state);
end;

function fz_open_dctd(chain:pfz_stream_s; params:pfz_obj_s):pfz_stream_s;
var
	state:pfz_dctd_s;
	obj:pfz_obj_s;
begin
	state := fz_malloc(sizeof(fz_dctd_s));
	fillchar(state^, sizeof(fz_dctd_s), 0);
	state^.chain := chain;
	state^.color_transform := -1; //* unset */
	state^.init := 0;

	obj:= fz_dict_gets(params, 'ColorTransform');
	if (obj<>nil) then
		state^.color_transform := fz_to_int(obj);

	result:= fz_new_stream(state, read_dctd, close_dctd);
end;


end.
