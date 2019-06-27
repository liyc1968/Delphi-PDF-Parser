unit pdf_metricss;

interface
uses 
SysUtils,Math,mylimits,digtypes,digcommtype,pdf_camp_tabless;

procedure pdf_set_default_hmtx(font:ppdf_font_desc_s; w:integer);
procedure pdf_add_hmtx(font:ppdf_font_desc_s;  lo,  hi,  w:integer);
procedure pdf_end_hmtx(font:ppdf_font_desc_s);
procedure pdf_set_default_vmtx(font:ppdf_font_desc_s;  y,  w:integer);
procedure pdf_set_font_wmode(font:ppdf_font_desc_s; wmode:integer);
procedure pdf_add_vmtx(font:ppdf_font_desc_s; lo,  hi,  x, y,  w:integer);
procedure pdf_end_vmtx(font:ppdf_font_desc_s);
function pdf_get_vmtx(font:ppdf_font_desc_s; cid:integer) :pdf_vmtx_s;
function pdf_get_hmtx(font:ppdf_font_desc_s; cid:integer):pdf_hmtx_s;
implementation
uses base_object_functions,QSort1;

procedure
pdf_set_font_wmode(font:ppdf_font_desc_s; wmode:integer);
begin
	font^.wmode := wmode;
end;

procedure
pdf_set_default_hmtx(font:ppdf_font_desc_s; w:integer);
begin
	font^.dhmtx.w := w;
end;

procedure pdf_set_default_vmtx(font:ppdf_font_desc_s;  y,  w:integer);
begin
	font^.dvmtx.y := y;
	font^.dvmtx.w := w;
end;

procedure pdf_add_hmtx(font:ppdf_font_desc_s;  lo,  hi,  w:integer);
begin
	if (font^.hmtx_len + 1 >= font^.hmtx_cap)  then
	begin
		font^.hmtx_cap := font^.hmtx_cap + 16;
		font^.hmtx := fz_realloc(font^.hmtx, font^.hmtx_cap, sizeof(pdf_hmtx_s));
	end;

	pdf_hmtx_s_items(font^.hmtx)[font^.hmtx_len].lo := lo;
	pdf_hmtx_s_items(font^.hmtx)[font^.hmtx_len].hi := hi;
	pdf_hmtx_s_items(font^.hmtx)[font^.hmtx_len].w := w;
	font^.hmtx_len:=font^.hmtx_len+1;
end;

procedure pdf_add_vmtx(font:ppdf_font_desc_s; lo,  hi,  x, y,  w:integer);
begin
	if (font^.vmtx_len + 1 >= font^.vmtx_cap) then
	begin
		font^.vmtx_cap := font^.vmtx_cap + 16;
		font^.vmtx:= fz_realloc(font^.vmtx, font^.vmtx_cap, sizeof(pdf_vmtx_s));
	end;

	pdf_vmtx_s_items(font^.hmtx)[font^.vmtx_len].lo := lo;
	pdf_vmtx_s_items(font^.hmtx)[font^.vmtx_len].hi := hi;
	pdf_vmtx_s_items(font^.hmtx)[font^.vmtx_len].x := x;
	pdf_vmtx_s_items(font^.hmtx)[font^.vmtx_len].y := y;
	pdf_vmtx_s_items(font^.hmtx)[font^.vmtx_len].w := w;
	font^.vmtx_len:=font^.vmtx_len+1;
end;

function cmph(a0:pointer; b0:pointer):integer;
var
a,b: ppdf_hmtx_s;
begin
	a :=a0;
	b :=b0;
	result:= a^.lo - b^.lo;
end;

function cmpv(a0:pointer; b0:pointer):integer;
var
a,b: ppdf_hmtx_s;
begin
	a :=a0;
	b :=b0;
	result:= a^.lo - b^.lo;
end;

procedure pdf_end_hmtx(font:ppdf_font_desc_s);
begin
	if (font^.hmtx=nil) then
		exit;
	quicksort(font^.hmtx, font^.hmtx_len, sizeof(pdf_hmtx_s), @cmph);
end;

procedure pdf_end_vmtx(font:ppdf_font_desc_s);
begin
	if (font^.vmtx=nil) then
		exit;
	quicksort(font^.vmtx, font^.vmtx_len, sizeof(pdf_vmtx_s), @cmpv);
end;


function pdf_get_hmtx(font:ppdf_font_desc_s; cid:integer):pdf_hmtx_s;
var
	l,r,m:integer;
  label notfound;
begin
  l := 0;
	r := font^.hmtx_len - 1;

	if (font^.hmtx=nil) then
		goto notfound;

	while (l <= r) do
	begin
		m := (l + r) shr 1;
		if (cid < pdf_hmtx_s_items(font^.hmtx)[m].lo) then
			r := m - 1
		else if (cid > pdf_hmtx_s_items(font^.hmtx)[m].hi) then
			l := m + 1
		else
    begin
			result:= pdf_hmtx_s_items(font^.hmtx)[m];
      exit;
    end;
	end;

notfound:
	result:= font^.dhmtx;
end;


function pdf_get_vmtx(font:ppdf_font_desc_s; cid:integer) :pdf_vmtx_s;
var
	h:pdf_hmtx_s;
	 v:pdf_vmtx_s;
	l,r,m:integer;
  label notfound;
begin
  l := 0;
	r := font^.vmtx_len - 1;
	if (font^.vmtx<>nil) then
		goto notfound;

	while (l <= r) do
	begin
		m := (l + r) shr 1;
		if (cid < pdf_vmtx_s_items(font^.vmtx)[m].lo)  then
			r := m - 1
		else if (cid > pdf_vmtx_s_items(font^.vmtx)[m].hi)  then
			l := m + 1
		else
    begin
			result:= pdf_vmtx_s_items(font^.vmtx)[m];
      exit;
    end;
	end;

notfound:
	h := pdf_get_hmtx(font, cid);
	v := font^.dvmtx;
	v.x := h.w div 2;
	result:= v;
end;


end.
