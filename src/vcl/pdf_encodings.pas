unit pdf_encodings;

interface
uses
SysUtils,digtypes;

 procedure pdf_load_encoding(estrings:parray256; encoding:pchar) ;
 function pdf_lookup_agl(name:pchar):integer;
 function  pdf_lookup_agl_duplicates( ucs:integer):ppchar;
 
implementation
uses date_glyphlist,base_object_functions;
procedure pdf_load_encoding( estrings:parray256; encoding:pchar) ;
var
	bstrings:parray256;
	 i:integer;
begin
  bstrings:=nil;
	if (strcomp(encoding, 'StandardEncoding')=0) then
		bstrings := @pdf_standard;
	if (strcomp(encoding, 'MacRomanEncoding')=0) then
		bstrings := @pdf_mac_roman;
	if (strcomp(encoding, 'MacExpertEncoding')=0) then
		bstrings := @pdf_mac_expert;
	if (strcomp(encoding, 'WinAnsiEncoding')=0)  then
		bstrings := @pdf_win_ansi;

	if (bstrings<>nil) then
		for i := 0 to 256-1 do
			estrings^[i] :=bstrings^[i];
end;

function OctToInt(Value: string): Longint;
var
i: Integer;
int: Integer;
begin
  int := 0;
  for i := 1 to Length(Value) do
  begin
    int := int * 8 + StrToInt(Copy(Value, i, 1));
  end;
  Result := int;
end;

function pdf_lookup_agl(name:pchar):integer;
var
	buf:array[0..63] of char;
	p:pchar;
	l,r,m,c:integer;
  s:string;
begin
  l:=0;
	r := length(agl_name_list) - 1;

	fz_strlcpy(@buf, name, sizeof(buf));

	//* kill anything after first period and underscore */
	p := strchr(buf, '.');
	if (p<>nil) then p[0] := #0;
	p := strchr(buf, '_');
	if (p<>nil) then p[0] := #0;
  result:=0;
	while (l <= r) do
	begin
		m := (l + r) shr 1;
		c := strcomp(buf, agl_name_list[m]);
		if (c < 0) then
			r := m - 1
		else if (c > 0) then
			l := m + 1
		else
      begin
		  result:= agl_code_list[m];
      exit;
      end;
	end;

	if (strstr(@buf, 'uni') =@buf) then
  begin
    s:=buf;
    s:=copy(s,4,length(s));
		result:= StrToIntdef('$'+s,0);
    exit;
  end
	else if (strstr(@buf, 'u') = @buf) then
  begin
	  s:=buf;
    s:=copy(s,2,length(s));
		result:= StrToIntdef(s,0);
    exit;
  end
	else if (strstr(@buf, 'a') = @buf) and  (strlen(@buf) >= 3)  then
  begin
		s:=buf;
    s:=copy(s,2,length(s));
		result:= StrToIntdef(s,0);
    exit;
  end  ;
  {else if (strstr(@buf, 'H') = @buf) and  (strlen(@buf) >= 3)  then
  begin
		s:=buf;
    s:=copy(s,2,length(s));
    try
		result:=   StrToIntdef(s,0);  // OctToInt(s);      
    except
    result:=0;
    end;
    exit;
  end;  }

	result:= 0;
end;

const empty_dup_list:array[0..0] of pchar= (nil);


function  pdf_lookup_agl_duplicates( ucs:integer):ppchar;
var
l,r,m:integer;
begin
	l := 0;
	r := length(agl_dup_offsets) div 2 - 1;
	while (l <= r)  do
	begin
		m := (l + r) shr 1;
		if (ucs < agl_dup_offsets[m shl 1])  then
			r := m - 1
		else if (ucs > agl_dup_offsets[m shl 1]) then
			l := m + 1
		else
    begin
			result:= @agl_dup_names;
      inc(result, agl_dup_offsets[(m shl 1) + 1]);
      exit;
    end;
	end;
	result:= @empty_dup_list;
end;


end.
