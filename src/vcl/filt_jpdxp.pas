unit filt_jpdxp;

interface
 uses  SysUtils,Math,digtypes,base_error;

function fz_load_jpx_image(imgp:ppfz_pixmap_s; data:pbyte; size:integer; defcs:pfz_colorspace_s):integer;
  
implementation
uses base_object_functions,OpenJpeg,res_colorspace,fz_pixmapss;

procedure  fz_opj_error_callback(msg:pchar; client_data:pointer) ;
begin
	//fprintf(stderr, "openjpeg error: %s", msg);
end;

procedure fz_opj_warning_callback(msg:pchar; client_data:pointer);
begin
	//fprintf(stderr, "openjpeg warning: %s", msg);
end;

procedure fz_opj_info_callback(msg:pchar; client_data:pointer);
begin
	//* fprintf(stderr, "openjpeg info: %s", msg); */
end;

function fz_load_jpx_image(imgp:ppfz_pixmap_s; data:pbyte; size:integer; defcs:pfz_colorspace_s):integer;
var
	img:pfz_pixmap_s;
  tmp:pfz_pixmap_s;
	evtmgr:opj_event_mgr_t;
	params:opj_dparameters_t;
	info:popj_dinfo_t;
	cio:popj_cio_t;
	jpx:popj_image_t;
	colorspace:pfz_colorspace_s;
	p:pbyte;
	format:OPJ_CODEC_FORMAT;
	a, n, w, h, depth, sgnd:integer;
	x, y, k, v:integer;
begin
	if (size < 2) then
  begin
	 result:= fz_throw('not enough data to determine image format');
   exit;
  end;


	//* Check for SOC marker -- if found we have a bare J2K stream */
	if (byte_items(data)[0] = $FF) and  (byte_items(data)[1] = $4F) then
		format := CODEC_J2K
	else
		format := CODEC_JP2;

	fillchar(evtmgr, sizeof(evtmgr), 0);
	evtmgr.error_handler := @fz_opj_error_callback;
	evtmgr.warning_handler := @fz_opj_warning_callback;
	evtmgr.info_handler := @fz_opj_info_callback;

	opj_set_default_decoder_parameters(@params);

	info := opj_create_decompress(format);
	opj_set_event_mgr(opj_common_ptr(info), @evtmgr, nil);   //stderr зЂвт
	opj_setup_decoder(info, @params);

	cio := opj_cio_open(opj_common_ptr(info), data, size);

	jpx := opj_decode(info, cio);

	opj_cio_close(cio);
	opj_destroy_decompress(info);

	if (jpx=NIL) then
  begin
		result:= fz_throw('opj_decode failed');
    exit;
  end;

	for k := 1 to jpx^.numcomps-1 do
	begin
		if (jpx^.comps[k].w <> jpx^.comps[0].w) then
    begin
			result:= fz_throw('image components have different width');
      exit;
    end;
		if (jpx^.comps[k].h <> jpx^.comps[0].h) then
    begin
		 result:= fz_throw('image components have different height');
      exit;
    end;
		if (jpx^.comps[k].prec <> jpx^.comps[0].prec)  then
    begin
		 result:=fz_throw('image components have different precision');
      exit;
    end;
	end;

	n := jpx^.numcomps;
	w := jpx^.comps[0].w;
	h := jpx^.comps[0].h;
	depth := jpx^.comps[0].prec;
	sgnd := jpx^.comps[0].sgnd;

	if (jpx^.color_space = CLRSPC_SRGB) and  (n = 4) then
  begin
    n := 3;
    a := 1;
  end
	else if (jpx^.color_space = CLRSPC_SYCC) and  (n = 4) then
  begin
    n := 3;
    a := 1;
  end
	else if (n = 2) then
  begin
    n := 1;
    a := 1;
  end
	else if (n > 4) then
  begin
    n := 4;
    a := 1;
  end
	else
  begin
   a := 0;
   end;

	if (defcs<>nil) then
	begin
		if (defcs^.n = n) then
		begin
			colorspace := defcs;
		end
		else
		begin
			fz_warn('jpx file and dict colorspaces do not match');
			defcs :=nil;
		end;
	end;

	if (defcs=nil) then
	begin
		case (n) of
		1: colorspace := get_fz_device_gray;
		3: colorspace := get_fz_device_rgb;
		4: colorspace := get_fz_device_cmyk;
		end;
	end;

	img := fz_new_pixmap_with_limit(colorspace, w, h);
	if (img=nil) then
	begin
		opj_image_destroy(jpx);
		result:= fz_throw('out of memory');
    result:=-1;
    exit;
	end;

	p := img^.samples;
	for y := 0 to h-1 do
	begin
		for x := 0 to w-1 do
		begin
			for k := 0 to n + a-1 do
			begin
				v := jpx^.comps[k].data[y * w + x];
				if (sgnd<>0) then
					v := v + (1 shl (depth - 1));
				if (depth > 8) then
					v := v shr (depth - 8);
        p^:=v;
        inc(p);

			end;
			if (a<>0) then
      begin
				p^:= 255;
        inc(p);
      end;
		end;
	end;

	if (a<>0) then
	begin
		if (n = 4) then
		begin
			tmp := fz_new_pixmap(get_fz_device_rgb, w, h);
			fz_convert_pixmap(img, tmp);
			fz_drop_pixmap(img);
			img := tmp;
		end;
		fz_premultiply_pixmap(img);
	end;

	opj_image_destroy(jpx);

	imgp^ := img;
	result:=1;
end;

end.
