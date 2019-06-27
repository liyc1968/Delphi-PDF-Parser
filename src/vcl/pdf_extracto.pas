unit pdf_extracto;

interface
uses  SysUtils,digtypes,base_object_functions,base_error;
function isimage(obj:pfz_obj_s):boolean;
function isfontdesc(obj:pfz_obj_s):boolean;
function saveimage(num:integer;xref:ppdf_xref_s;dorgb:integer;filen:pchar):integer;
implementation
uses pdf_imagess,res_colorspace,fz_pixmapss;

function isimage(obj:pfz_obj_s):boolean;
var
  type1:pfz_obj_s;
begin
	type1 := fz_dict_gets(obj, 'Subtype');
	result:= fz_is_name(type1) and (strcomp(fz_to_name(type1), 'Image')=0);
end;

function isfontdesc(obj:pfz_obj_s):boolean;
var
  type1:pfz_obj_s;
begin
	type1 := fz_dict_gets(obj, 'Type');
  result:= fz_is_name(type1) and (strcomp(fz_to_name(type1), 'FontDescriptor')=0);
end;

function saveimage(num:integer;xref:ppdf_xref_s;dorgb:integer;filen:pchar):integer;
var
	error:integer;
	img:pfz_pixmap_s;
	ref:pfz_obj_s;
  temp:Pfz_pixmap_s;
	//char name[1024];
begin
	ref := fz_new_indirect(num, 0, xref);

	//* TODO: detect DCTD and save as jpeg */

	error := pdf_load_image(@img, xref, ref);
	if (error<0) then
  begin
	 //	die(error);
    result:=-1;
    exit;
  end;

	if ((dorgb<>0) and (img^.colorspace<>nil) and (img^.colorspace <> get_fz_device_rgb)) then
	begin
		temp := fz_new_pixmap_with_rect(get_fz_device_rgb, fz_bound_pixmap(img));
		fz_convert_pixmap(img, temp);
		fz_drop_pixmap(img);
		img := temp;
	end;
  //outprintf(inttostr( byte_items(img^.samples)[0]));
	if (img^.n <= 4) then
	begin
		fz_write_png(img, filen, 0);
	end
	else
	begin
		fz_write_pam(img, filen, 0);

	end;

	fz_drop_pixmap(img);
	fz_drop_obj(ref);
end;


end.
