unit pdf_findfiles;

interface
uses
SysUtils, digtypes,font_base14,font_cjks,fond_droids;

function pdf_find_builtin_font(name:pchar; len:pword):pbyte;
function pdf_find_substitute_font( mono,  serif, bold, italic:integer; len:pdword):pbyte;
function pdf_find_substitute_cjk_font(ros, serif:integer; len:pinteger):pbyte;
implementation

function pdf_find_builtin_font(name:pchar; len:pword):pbyte;
begin
	if (strcomp('Courier', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusMonL_Regu);
		result:=@pdf_font_NimbusMonL_Regu;
    exit;
	end;
	if (strcomp('Courier-Bold', name)=0) then
  begin
		len^ := sizeof(pdf_font_NimbusMonL_Bold);
		result:=@pdf_font_NimbusMonL_Bold;
    exit;
	end;
	if (strcomp('Courier', name)=0) then
  begin
		len^ := sizeof(pdf_font_NimbusMonL_Regu);
		result:=@pdf_font_NimbusMonL_Regu;
    exit;
	end;
	if (strcomp('Courier-Bold', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusMonL_Bold);
		result:= @pdf_font_NimbusMonL_Bold;
    exit;
	end;
	if (strcomp('Courier-Oblique', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusMonL_ReguObli);
		result:=@pdf_font_NimbusMonL_ReguObli;
    exit;
	end;
	if (strcomp('Courier-BoldOblique', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusMonL_BoldObli);
		result:= @pdf_font_NimbusMonL_BoldObli;
    exit;
	end;
	if (strcomp('Helvetica', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusSanL_Regu);
		result:= @pdf_font_NimbusSanL_Regu;
    exit;
	end;
	if (strcomp('Helvetica-Bold', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusSanL_Bold);
		result:=@pdf_font_NimbusSanL_Bold;
    exit;
	end;
	if (strcomp('Helvetica-Oblique', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusSanL_ReguItal);
		result:= @pdf_font_NimbusSanL_ReguItal;
    exit;
	end;
	if (strcomp('Helvetica-BoldOblique', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusSanL_BoldItal);
		result:= @pdf_font_NimbusSanL_BoldItal;
    exit;
	end;
	if (strcomp('Times-Roman', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusRomNo9L_Regu);
		result:= @pdf_font_NimbusRomNo9L_Regu;
    exit;
	end;
	if (strcomp('Times-Bold', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusRomNo9L_Medi);
		result:= @pdf_font_NimbusRomNo9L_Medi;
    exit;
	end;
	if (strcomp('Times-Italic', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusRomNo9L_ReguItal);
		result:= @pdf_font_NimbusRomNo9L_ReguItal;
    exit;
	end;
	if (strcomp('Times-BoldItalic', name)=0) then
  begin
		len^ := sizeof( pdf_font_NimbusRomNo9L_MediItal);
		result:= @pdf_font_NimbusRomNo9L_MediItal;
    exit;
	end;
	if (strcomp('Symbol', name)=0) then
  begin
		len^ := sizeof( pdf_font_StandardSymL);
		result:= @pdf_font_StandardSymL;
    exit;
	end;
	if (strcomp('ZapfDingbats', name)=0) then
  begin
		len^ := sizeof( pdf_font_Dingbats);
		result:= @pdf_font_Dingbats;
    exit;
	end;
	len^ := 0;
	result:=nil;
  exit;
end;

function pdf_find_substitute_font( mono,  serif, bold, italic:integer; len:pdword):pbyte;
begin

	if (mono<>0) then
  begin
		len^ := sizeof(pdf_font_DroidSansMono);
		result:=@pdf_font_DroidSansMono;
    exit;
	end else
  begin
		len^ := sizeof(pdf_font_DroidSans);
		result:=@pdf_font_DroidSans;
    exit;
	end;

end;


function pdf_find_substitute_cjk_font(ros, serif:integer; len:pinteger):pbyte;
begin

	len^ := sizeof(pdf_font_DroidSansFallback);
		result:=@pdf_font_DroidSansFallback;
    exit;

end;



end.
