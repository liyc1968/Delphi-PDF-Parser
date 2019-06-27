unit pdf_imagess;

interface
 uses  SysUtils,Math,digtypes,draw_unpackss,base_error;

function pdf_load_image(pixp:ppfz_pixmap_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
function pdf_is_jpx_image(dict:pfz_obj_s):integer;
function pdf_load_jpx_image(imgp:ppfz_pixmap_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
function pdf_load_inline_image(pixp:ppfz_pixmap_s; xref:ppdf_xref_s; rdb, dict:pfz_obj_s; file1:pfz_stream_s):integer;  
implementation
  uses base_object_functions,fz_pixmapss,pdf_color_spcasess,res_colorspace,mypdfstream,FZ_mystreams,filt_jpdxp,fz_pdf_store;

procedure
pdf_mask_color_key(pix:pfz_pixmap_s; n:integer; colorkey:pinteger) ;
var
	p:pbyte;
	len, k, t:integer;
begin
  p := pix^.samples;
  len := pix^.w * pix^.h;
	while (len<>0) do
	begin
    len:=len-1;
		t := 1;
		for k := 0 to n-1 do
			if (integer_items(p)[k] < integer_items(colorkey)[k * 2]) or (integer_items(p)[k] > integer_items(colorkey)[k * 2 + 1])   then
				t := 0;
		if (t<>0) then
			for k := 0 to pix^.n-1 do
				integer_items(p)[k] := 0;
	  inc(p,pix^.n);
	end;
end;

function pdf_load_image_imp(imgp:ppfz_pixmap_s; xref:ppdf_xref_s; rdb, dict:pfz_obj_s; cstm:pfz_stream_s; forcemask:integer):integer;
var
	stm:pfz_stream_s;
	tile:pfz_pixmap_s;
	obj, res:pfz_obj_s;
	error:integer;

	 w, h, bpc, n:integer;
	imagemask:integer;
	interpolate:integer;
	indexed:integer;
	colorspace:pfz_colorspace_s;
	mask:pfz_pixmap_s; //* explicit mask/softmask image */
	usecolorkey:integer;
	colorkey:array[0..FZ_MAX_COLORS * 2-1] of integer;
	decode:array[0..FZ_MAX_COLORS * 2-1] of single;
  tbuf:array[0..511] of byte;
	stride:integer;
	samples:pbyte;
  maxval:single;
  tlen:integer;
	i, len:integer;
  p:pbyte;
  conv:pfz_pixmap_s;
begin
	//* special case for JPEG2000 images */
	if (pdf_is_jpx_image(dict)<>0) then
	begin
		tile := nil;
		error := pdf_load_jpx_image(@tile, xref, dict);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load jpx image');
       exit;
    end;
		if (forcemask<>0) then
		begin
			if (tile^.n <> 2)then
			begin
				fz_drop_pixmap(tile);
			 result:= fz_throw('softmask must be grayscale');
       exit;
			end;
			mask := fz_alpha_from_gray(tile, 1);
			fz_drop_pixmap(tile);
			imgp^ := mask;
	    result:=1;
      exit;
		end;
		imgp^ := tile;
    result:=1;
    exit;
	end;

	w := fz_to_int(fz_dict_getsa(dict, 'Width', 'W'));
	h := fz_to_int(fz_dict_getsa(dict, 'Height', 'H'));
	bpc := fz_to_int(fz_dict_getsa(dict, 'BitsPerComponent', 'BPC'));
	imagemask := fz_to_bool(fz_dict_getsa(dict, 'ImageMask', 'IM'));
	interpolate := fz_to_bool(fz_dict_getsa(dict, 'Interpolate', 'I'));

	indexed := 0;
	usecolorkey := 0;
	colorspace := nil;
	mask :=nil;

	if (imagemask<>0) then
		bpc := 1;

	if (w = 0) then
  begin
		result:= fz_throw('image width is zero');
    exit;
  end;
	if (h = 0)  then
  begin
		result:=fz_throw('image height is zero');
    exit;
  end;
	if (bpc = 0) then
  begin
		 result:= fz_throw('image depth is zero');
    exit;
  end;
	if (bpc > 16) then
  begin
	 result:= fz_throw('image depth is too large: %d', [bpc]);
    exit;
  end;
	if (w > (1 shl 16))  then
  begin
	 result:= fz_throw('image is too wide');

    exit;
  end;
	if (h > (1 shl 16)) then
  begin
		result:= fz_throw('image is too high');

    exit;
  end;

	obj := fz_dict_getsa(dict, 'ColorSpace', 'CS');
	if ((obj<>nil) and (imagemask=0) and (forcemask=0)) then
	begin
		//* colorspace resource lookup is only done for inline images */
		if (fz_is_name(obj)) then
		begin
			res := fz_dict_get(fz_dict_gets(rdb, 'ColorSpace'), obj);
			if (res<>nil) then
				obj := res;
		end;

		error := pdf_load_colorspace(@colorspace, xref, obj);
		if (error<0)  then
    begin
			result:= fz_rethrow(error, 'cannot load image colorspace');
      exit;
    end;

		if (strcomp(colorspace^.name, 'Indexed')=0) then
			indexed := 1;

		n := colorspace^.n;
	end
	else
	begin
		n := 1;
	end;

	obj := fz_dict_getsa(dict, 'Decode', 'D');
	if (obj<>nil) then
	begin
		for i := 0 to n * 2-1 do
			decode[i] := fz_to_real(fz_array_get(obj, i));
	end
	else
	begin
    if indexed<>0 then
		maxval := (1 shl bpc) - 1
    else
    maxval:=1;
 
		for i := 0 to n * 2-1 do
    begin
      if (i and 1) <>0 then
        decode[i]:=maxval
        else
        decode[i]:=0;
		
    end;
	end;

	obj := fz_dict_getsa(dict, 'SMask', 'Mask');
	if (fz_is_dict(obj))  then
	begin
		//* Not allowed for inline images */
		if (cstm=nil) then
		begin
			error := pdf_load_image_imp(@mask, xref, rdb, obj, nil, 1);
			if (error<0)  then
			begin
				if (colorspace<>nil) then
					fz_drop_colorspace(colorspace);
				result:=fz_rethrow(error, 'cannot load image mask/softmask');
        //result:=-1;
        exit;
			end;
		end;
	end
	else if (fz_is_array(obj))  then
	begin
		usecolorkey := 1;
		for i := 0 to n * 2-1 do
			colorkey[i] := fz_to_int(fz_array_get(obj, i));
	end;

	//* Allocate now, to fail early if we run out of memory */
	tile := fz_new_pixmap_with_limit(colorspace, w, h);
	if (tile=nil)  then
	begin
		if (colorspace<>nil) then
			fz_drop_colorspace(colorspace);
		if (mask<>nil) then
			fz_drop_pixmap(mask);
		result:=fz_throw('out of memory');

    exit;
	end;

	if (colorspace<>nil) then
		fz_drop_colorspace(colorspace);

	tile^.mask := mask;
	tile^.interpolate := interpolate;

	stride := (w * n * bpc + 7) div 8;

	if (cstm<>nil) then
	begin
		stm := pdf_open_inline_stream(cstm, xref, dict, stride * h);
	end
	else
	begin
		error := pdf_open_stream(@stm, xref, fz_to_num(dict), fz_to_gen(dict));
		if (error<0)  then
		begin
			fz_drop_pixmap(tile);
			result:= fz_rethrow(error, 'cannot open image data stream (%d 0 R)', [fz_to_num(dict)]);
      exit;
		end;
	end;

	samples := fz_calloc(h, stride);

	len := fz_read(stm, samples, h * stride);
	if (len < 0) then
	begin
		fz_close(stm);
		fz_free(samples);
		fz_drop_pixmap(tile);
		result:= fz_rethrow(len, 'cannot read image data');
    exit;
	end;

	//* Make sure we read the EOF marker (for inline images only) */
	if (cstm<>nil)  then
	begin

		tlen := fz_read(stm, @tbuf, sizeof(tbuf));
		if (tlen < 0) then
			fz_catch(tlen, 'ignoring error at end of image');
		if (tlen > 0) then
		 	fz_warn('ignoring garbage at end of image');
	end;

	fz_close(stm);

	//* Pad truncated images */
	if (len < stride * h) then
	begin
		fz_warn('padding truncated image (%d 0 R)', [fz_to_num(dict)]);
		fillchar(pointer(cardinal(samples) + len)^, stride * h - len, 0);
	end;

	//* Invert 1-bit image masks */
	if (imagemask<>0)  then
	begin
		//* 0=opaque and 1=transparent so we need to invert */
		p := samples;
		len := h * stride;
		for i := 0 to len-1 do
			byte_items(p)[i] := not byte_items(p)[i];
	end;

	fz_unpack_tile(tile, samples, n, bpc, stride, indexed);

	fz_free(samples);

	if (usecolorkey<>0) then
		pdf_mask_color_key(tile, n, @colorkey);

	if (indexed<>0)  then
	begin

		fz_decode_indexed_tile(tile, @decode, (1 shl bpc) - 1);
		conv := pdf_expand_indexed_pixmap(tile);
		fz_drop_pixmap(tile);
		tile := conv;
	end
	else
	begin
		fz_decode_tile(tile, @decode);
	end;

	imgp^ := tile;
	result:=1;
end;

function pdf_load_inline_image(pixp:ppfz_pixmap_s; xref:ppdf_xref_s; rdb, dict:pfz_obj_s; file1:pfz_stream_s):integer;
var
	 error:integer;
begin
	error := pdf_load_image_imp(pixp, xref, rdb, dict, file1, 0);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot load inline image');
    exit;
  end;
 //	return fz_okay;
 result:=1;
end;

function pdf_is_jpx_image(dict:pfz_obj_s):integer;
var
	filter:pfz_obj_s;
	 i:integer;
begin
	filter := fz_dict_gets(dict, 'Filter');
	if (strcomp(fz_to_name(filter), 'JPXDecode')=0) then
  begin
		result:= 1;
    exit;
  end;
	for i := 0 to fz_array_len(filter)-1 do
		if (strcomp(fz_to_name(fz_array_get(filter, i)), 'JPXDecode')=0) then
    begin
			result:= 1;
      exit;
    end;
	result:=0;
end;

function
pdf_load_jpx_image(imgp:ppfz_pixmap_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
	buf:pfz_buffer_s;
	colorspace:pfz_colorspace_s;
	img:pfz_pixmap_s;
	obj:pfz_obj_s;
begin
	colorspace := nil;

	error := pdf_load_stream(@buf, xref, fz_to_num(dict), fz_to_gen(dict));
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load jpx image data');

    exit;
  end;

	obj := fz_dict_gets(dict, 'ColorSpace');
	if (obj<>nil) then
	begin
		error := pdf_load_colorspace(@colorspace, xref, obj);
		if (error<0)   then
    begin
			fz_catch(error, 'cannot load image colorspace');
    end;
	end;

	error := fz_load_jpx_image(@img, buf^.data, buf^.len, colorspace);
	if (error<0)  then
	begin
		if (colorspace<>nil) then
			fz_drop_colorspace(colorspace);
		fz_drop_buffer(buf);
	 	result:= fz_rethrow(error, 'cannot load jpx image');

    exit;
	end;

	if (colorspace<>nil) then
		fz_drop_colorspace(colorspace);
	fz_drop_buffer(buf);

	obj := fz_dict_getsa(dict, 'SMask', 'Mask');
	if (fz_is_dict(obj)) then
	begin
		error := pdf_load_image_imp(@img^.mask, xref,nil, obj, nil, 1);
		if (error<0)  then
		begin
			fz_drop_pixmap(img);
			result:= fz_rethrow(error, 'cannot load image mask/softmask');
      exit;
		end;
	end;

	imgp^ := img;
	result:=1;
end;

function pdf_load_image(pixp:ppfz_pixmap_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	error:integer;
begin
	pixp^ := pdf_find_item(xref^.store, @fz_drop_pixmap, dict);
  if (pixp^<>nil) then
	begin
		fz_keep_pixmap(pixp^);
		//return fz_okay;
    result:=1;
    exit;
	end;

	error := pdf_load_image_imp(pixp, xref, nil, dict, nil, 0);
	if (error<0)  then
  begin
  		result:= fz_rethrow(error, 'cannot load image (%d 0 R)', [fz_to_num(dict)]);

      exit;
  end;

	pdf_store_item(xref^.store, @fz_keep_pixmap, @fz_drop_pixmap, dict, pixp^);
  result:=1;
	//return fz_okay;
end;


end.
 