unit pdf_color_spcasess;

interface
 uses  SysUtils, Math,digtypes,pdf_functionss,base_error;
function pdf_load_colorspace(csp:ppfz_colorspace_s; xref:ppdf_xref_s; obj:pfz_obj_s):integer;
function   get_fz_device_lab:pfz_colorspace_s;
function pdf_expand_indexed_pixmap(src:pfz_pixmap_s):pfz_pixmap_s;
function pdf_load_colorspace_imp(csp:ppfz_colorspace_s; xref:ppdf_xref_s; obj:pfz_obj_s):integer;
implementation
uses base_object_functions,res_colorspace,fz_pixmapss,mypdfstream,FZ_mystreams,fz_pdf_store;

function load_icc_based(csp:ppfz_colorspace_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	 n:integer;
begin
	n := fz_to_int(fz_dict_gets(dict, 'N'));

	case (n) of
	1:
  begin
    csp^ := get_fz_device_gray;
    result:=1;
    exit;
  end;
	3:
  begin
    csp^ := get_fz_device_rgb; 
    result:=1;
    exit;
  end;
	4:
  begin
    csp^ := get_fz_device_cmyk;
    result:=1;
    exit;
  end;
	end;

	result:= fz_throw('syntaxerror: ICCBased must have 1, 3 or 4 components');

  exit;
end;

(* Lab *)

function fung(x:single) :single;
begin
	if (x >= 6.0 / 29.0) then
  begin
		result:= x * x * x;
    exit;
  end;
	result:= (108.0 / 841.0) * (x - (4.0 / 29.0));
end;

procedure 
lab_to_rgb(cs:pfz_colorspace_s; lab, rgb:psingle);
var
	//* input is in range (0..100, -128..127, -128..127) not (0..1, 0..1, 0..1) */
	lstar, astar, bstar, l, m, n, x, y, z, r, g, b:single;
begin
	lstar := single_items(lab)[0];
	astar := single_items(lab)[1];
	bstar := single_items(lab)[2];
	m := (lstar + 16) / 116;
	l := m + astar / 500;
	n := m - bstar / 200;
	x := fung(l);
	y := fung(m);
	z := fung(n);
	r := (3.240449 * x + -1.537136 * y + -0.498531 * z) * 0.830026;
	g := (-0.969265 * x + 1.876011 * y + 0.041556 * z) * 1.05452;
	b := (0.055643 * x + -0.204026 * y + 1.057229 * z) * 1.1003;
	single_items(rgb)[0] := sqrt(CLAMP(r, 0, 1));
	single_items(rgb)[1] := sqrt(CLAMP(g, 0, 1));
	single_items(rgb)[2] := sqrt(CLAMP(b, 0, 1));
end;

procedure rgb_to_lab(cs:pfz_colorspace_s; rgb, lab:psingle);
begin
 	fz_warn('cannot convert into L*a*b colorspace');
	single_items(lab)[0] := single_items(rgb)[0];
	single_items(lab)[1] := single_items(rgb)[1];
	single_items(lab)[2] := single_items(rgb)[2];
end;



const  k_device_lab:fz_colorspace_s = (refs: -1;name: 'Lab'; n: 3; to_rgb: lab_to_rgb; from_rgb:rgb_to_lab;free_data:nil;data:nil);
const  fz_device_lab:pfz_colorspace_s = @k_device_lab;

//* Separation and DeviceN */

type
 pseparation=^separation;
 separation=record
	base:pfz_colorspace_s;
	tint:ppdf_function_s;
end;
function   get_fz_device_lab:pfz_colorspace_s;
begin
  result:=fz_device_lab;
end;

procedure separation_to_rgb(cs:pfz_colorspace_s; color, rgb:psingle);
var
 sep: pseparation;
 alt:array[0..FZ_MAX_COLORS-1] of single;
begin
	sep := cs^.data;

	pdf_eval_function(sep^.tint, color, cs^.n, @alt, sep^.base^.n);
	sep^.base^.to_rgb(sep^.base, @alt, rgb);
end;

procedure free_separation(cs:pfz_colorspace_s);
var
	sep:pseparation;
begin
  sep:= cs^.data;
	fz_drop_colorspace(sep^.base);
	pdf_drop_function(sep^.tint);
	fz_free(sep);
end;

function
load_separation(csp:ppfz_colorspace_s; xref:ppdf_xref_s; array1:pfz_obj_s):integer;
var
	error:integer;
	cs:pfz_colorspace_s;
	 sep:pseparation;
	nameobj:pfz_obj_s ;
	baseobj:pfz_obj_s;
	tintobj:pfz_obj_s ;
	base:pfz_colorspace_s;
	tint:ppdf_function_s;
	n:integer;
begin
  nameobj := fz_array_get(array1, 1);
	baseobj := fz_array_get(array1, 2);
	tintobj := fz_array_get(array1, 3);
	if (fz_is_array(nameobj)) then
		n := fz_array_len(nameobj)
	else
		n := 1;

	if (n > FZ_MAX_COLORS)  then
  begin
		result:= fz_throw('too many components in colorspace');
    exit;
  end;

	error := pdf_load_colorspace(@base, xref, baseobj);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load base colorspace (%d %d R)', [fz_to_num(baseobj), fz_to_gen(baseobj)]);
    exit;
  end;

	error := pdf_load_function(@tint, xref, tintobj);
	if (error<0)  then
	begin
		fz_drop_colorspace(base);
	 result:= fz_rethrow(error, 'cannot load tint function (%d %d R)', [fz_to_num(tintobj), fz_to_gen(tintobj)]);
   exit;
	end;

	sep := fz_malloc(sizeof(separation));
	sep^.base := base;
	sep^.tint := tint;
  if n=1 then
     cs := fz_new_colorspace('Separation',n)
     else
     cs := fz_new_colorspace('DeviceN',n);
	
	cs^.to_rgb := separation_to_rgb;
	cs^.free_data := free_separation;
	cs^.data := sep;

	csp^ := cs;
	result:=1; // fz_okay;
end;

//* Indexed */



procedure indexed_to_rgb(cs:pfz_colorspace_s; color, rgb:psingle);
var
	 idx:pindexed_s;
	alt:array[0..FZ_MAX_COLORS-1] of single;
	i, k:integer;
begin
  idx := cs^.data;
	i := trunc(single_items(color)[0] * 255);
	i := CLAMP(i, 0, idx^.high);
	for k := 0 to idx^.base^.n-1 do
		alt[k] := byte_items(idx^.lookup)[i * idx^.base^.n + k] / 255.0;
	idx^.base^.to_rgb(idx^.base, @alt, rgb);
end;

procedure free_indexed(cs:pfz_colorspace_s);
var
	idx:pindexed_s;
begin
  idx := cs^.data;
	if (idx^.base<>nil) then
		fz_drop_colorspace(idx^.base);
	fz_free(idx^.lookup);
	fz_free(idx);
end;

function pdf_expand_indexed_pixmap(src:pfz_pixmap_s):pfz_pixmap_s;
var
  idx:pindexed_s;
	dst:pfz_pixmap_s;
	s, d:pbyte;
	y, x, k, n, high,v,a:integer;
	lookup:pbyte;
begin
	assert(@src^.colorspace^.to_rgb = @indexed_to_rgb);
	assert(src^.n = 2);

	idx := src^.colorspace^.data;
	high := idx^.high;
	lookup := idx^.lookup;
	n := idx^.base^.n;

	dst := fz_new_pixmap_with_rect(idx^.base, fz_bound_pixmap(src));
	s := src^.samples;
	d := dst^.samples;

	for y := 0 to src^.h-1 do
	begin
		for x := 0 to src^.w-1 do
		begin
			v := s^;
      inc(s);
			a := s^;
      inc(s);
			v := MIN(v, high);
			for k := 0 to n-1 do
      begin
        d^:=  fz_mul255(byte_items(lookup)[v * n + k], a);
        inc(d);
      end;
      d^:=a;
      inc(d);
		end;
	end;

	if (src^.mask<>nil) then
		dst^.mask := fz_keep_pixmap(src^.mask);
	dst^.interpolate := src^.interpolate;

	result:= dst;
end;

function
load_indexed(csp:ppfz_colorspace_s; xref:ppdf_xref_s; array1:pfz_obj_s)  :integer;
var
	error:integer;
	cs:pfz_colorspace_s;
	 idx:pindexed_s;
	baseobj:pfz_obj_s;
	highobj:pfz_obj_s;
	lookup:pfz_obj_s;
	base:pfz_colorspace_s;
	i, n:integer;
  file1:pfz_stream_s;
  buf:pbyte;
begin
   baseobj := fz_array_get(array1, 1);
   highobj := fz_array_get(array1, 2);
	 lookup := fz_array_get(array1, 3);

	error := pdf_load_colorspace(@base, xref, baseobj);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load base colorspace (%d %d R)', [fz_to_num(baseobj), fz_to_gen(baseobj)]);
    exit;
  end;

	idx := fz_malloc(sizeof(indexed_s));
	idx^.base := base;
	idx^.high := fz_to_int(highobj);
	idx^.high := CLAMP(idx^.high, 0, 255);
	n := base^.n * (idx^.high + 1);
	idx^.lookup := fz_malloc(n);
	fillchar(idx^.lookup^, n, 0);

	cs := fz_new_colorspace('Indexed', 1);
	cs^.to_rgb := indexed_to_rgb;
	cs^.free_data := free_indexed;
	cs^.data := idx;

	if (fz_is_string(lookup)) and (fz_to_str_len(lookup) = n) then
	begin
		buf := pbyte( fz_to_str_buf(lookup));
		for i := 0 to  n-1 do
			byte_items(idx^.lookup)[i] := 	byte_items(buf)[i];
	end
	else if (fz_is_indirect(lookup))   then
	begin


		error := pdf_open_stream(@file1, xref, fz_to_num(lookup), fz_to_gen(lookup));
		if (error<0)  then
		begin
			fz_drop_colorspace(cs);
			result:= fz_rethrow(error, 'cannot open colorspace lookup table (%d 0 R)', [fz_to_num(lookup)]);
      exit;
		end;
		i := fz_read(file1, idx^.lookup, n);
		if (i < 0)  then
		begin
			fz_drop_colorspace(cs);
			result:=fz_throw('cannot read colorspace lookup table (%d 0 R)', [fz_to_num(lookup)]);
      exit;
		end;

		fz_close(file1);
	end
	else
	begin
		fz_drop_colorspace(cs);
		result:= fz_throw('cannot parse colorspace lookup table');
    exit;
	end;

	csp^ := cs;
	result:=1; //fz_okay;
end;

//* Parse and create colorspace from PDF object */

function pdf_load_colorspace_imp(csp:ppfz_colorspace_s; xref:ppdf_xref_s; obj:pfz_obj_s):integer;
var
name: pfz_obj_s;
error:integer;
begin
	if (fz_is_name(obj)) then
	begin
		if (strcomp(fz_to_name(obj), 'Pattern')=0) then
			csp^ := get_fz_device_gray
		else if (strcomp(fz_to_name(obj), 'G')=0) then
			csp^ := get_fz_device_gray
		else if (strcomp(fz_to_name(obj), 'RGB')=0) then
			csp^ := get_fz_device_rgb
		else if (strcomp(fz_to_name(obj), 'CMYK')=0) then
			csp^ := get_fz_device_cmyk
		else if (strcomp(fz_to_name(obj), 'DeviceGray')=0) then
			csp^ := get_fz_device_gray
		else if (strcomp(fz_to_name(obj), 'DeviceRGB')=0) then
			csp^ := get_fz_device_rgb
		else if (strcomp(fz_to_name(obj), 'DeviceCMYK')=0) then
			csp^ := get_fz_device_cmyk
		else
    begin
			result:= fz_throw('unknown colorspace: %s', [fz_to_name(obj)]);
	  //	return fz_okay;
    end;
    result:=1;
    exit;
	end

	else if (fz_is_array(obj)) then
	begin
		name := fz_array_get(obj, 0);

		if (fz_is_name(name)) then
		begin
			//* load base colorspace instead */
			if (strcomp(fz_to_name(name), 'Pattern')=0) then
			begin
			 obj := fz_array_get(obj, 1);
				if (obj=nil) then
				begin
					csp^ := get_fz_device_gray;
					//return fz_okay;
          result:=1;
          exit;
				end;

				error := pdf_load_colorspace(csp, xref, obj);
				if (error<0)  then
        begin
					result:= fz_rethrow(error, 'cannot load pattern (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
          exit;
        end;
			end

			else if (strcomp(fz_to_name(name), 'G')=0) then
				csp^ := get_fz_device_gray
			else if (strcomp(fz_to_name(name), 'RGB')=0) then
				csp^ := get_fz_device_rgb
			else if (strcomp(fz_to_name(name), 'CMYK')=0) then
				csp^ := get_fz_device_cmyk
			else if (strcomp(fz_to_name(name), 'DeviceGray')=0) then
				csp^ := get_fz_device_gray
			else if (strcomp(fz_to_name(name), 'DeviceRGB')=0) then
				csp^ := get_fz_device_rgb
			else if (strcomp(fz_to_name(name), 'DeviceCMYK')=0) then
				csp^ := get_fz_device_cmyk
			else if (strcomp(fz_to_name(name), 'CalGray')=0) then
				csp^ := get_fz_device_gray
			else if (strcomp(fz_to_name(name), 'CalRGB')=0) then
				csp^ := get_fz_device_rgb
			else if (strcomp(fz_to_name(name), 'CalCMYK')=0) then
				csp^ := get_fz_device_cmyk
			else if (strcomp(fz_to_name(name), 'Lab')=0) then
				csp^ := get_fz_device_lab

			else if (strcomp(fz_to_name(name), 'ICCBased')=0) then
      begin
				result:= load_icc_based(csp, xref, fz_array_get(obj, 1));
        exit;
      end

			else if (strcomp(fz_to_name(name), 'Indexed')=0) then
      begin
				result:=load_indexed(csp, xref, obj);
        exit;
      end
			else if (strcomp(fz_to_name(name), 'I')=0) then
      begin
				result:= load_indexed(csp, xref, obj);
        exit;
      end

			else if (strcomp(fz_to_name(name), 'Separation')=0) then
      begin
				result:= load_separation(csp, xref, obj);
      end


			else if (strcomp(fz_to_name(name), 'DeviceN')=0) then
      begin
				result:= load_separation(csp, xref, obj);
        exit;
      end

			else
      begin
				result:=fz_throw('syntaxerror: unknown colorspace %s', [fz_to_name(name)]);
        exit;
      end;

			result:=1;
      exit;
		end;
	end;

	result:= fz_throw('syntaxerror: could not parse color space (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);

  exit;
end;

function pdf_load_colorspace(csp:ppfz_colorspace_s; xref:ppdf_xref_s; obj:pfz_obj_s):integer;
var
 error:integer;
begin

	csp^ := pdf_find_item(xref^.store, @fz_drop_colorspace, obj);
  if (csp^<>nil) then
	begin
		fz_keep_colorspace(csp^);
		result:=1; // fz_okay;
    exit;
	end;

	error := pdf_load_colorspace_imp(csp, xref, obj);
	if (error<0)  then
  begin
		result:= fz_rethrow(error, 'cannot load colorspace (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);
    exit;
  end;

	pdf_store_item(xref^.store, @fz_keep_colorspace, @fz_drop_colorspace, obj, csp^);

	result:=1; // fz_okay;
end;

end.
