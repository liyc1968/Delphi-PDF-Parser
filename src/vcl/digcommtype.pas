unit digcommtype;

interface
uses  SysUtils,Math,digtypes,base_object_functions,FZ_mystreams,base_error;
   //tobjectlist

function pdf_open_xref(xref:pPdf_xref_s; const filename :pchar; password:pchar):integer;
function pdf_read_xref_sections(xref:ppdf_xref_s; ofs:integer; buf:pchar; cap:integer):integer;
function pdf_parse_stm_obj(op:ppfz_obj_s; xref:ppdf_xref_s; f:pfz_stream_s; buf:pchar; cap:integer):integer;
FUNCTION pdf_lex(tok:Ppdf_kind_e; f:pfz_stream_s; buf:pchar;const  n:integer; sl:pinteger):integer;
function pdf_load_version(xref:ppdf_xref_s):integer;
function pdf_read_start_xref(xref:ppdf_xref_s):integer;
function pdf_read_trailer(pdf_xref:ppdf_xref_s; buf:pchar; cap:integer):integer;
function pdf_parse_dict(op:pPfz_obj_S; pdf_xref:ppdf_xref_s; f:pfz_stream_s; buf:pchar; cap:integer):integer;
function pdf_parse_ind_obj(op:ppfz_obj_s;xref:ppdf_xref_s;f:pfz_stream_s; buf:pchar; cap:integer; onum:Pinteger; ogen :Pinteger; ostmofs:Pinteger) :integer;
FUNCTION pdf_read_new_trailer(xref:ppdf_xref_s; buf: pchar;cap:integer):INTEGER;
procedure fz_debug_xref(xref:ppdf_xref_s);
function IS_HEX(ch:char):boolean;
function iswhite(ch:char):boolean;
function unhex(ch:char):integer;
Function atan2(y : extended; x : extended): Extended;
FUNCTION pdf_parse_array(op:ppfz_obj_s; pdf_xref:ppdf_xref_s; f:pfz_stream_S;buf :pchar;  cap:integer):INTEGER;
procedure pdf_free_xref(xref:ppdf_xref_s);
function pdf_open_xref_with_stream(xrefp:pppdf_xref_s; file1:pfz_stream_s; password:pchar):fz_error;
implementation
uses mypdfstream,pdf_repair,fz_pdf_store,pdf_crypt;
function   StrLeft(const   mStr:   string;   mDelimiter:   string):   string;
  begin
      Result   :=   Copy(mStr,   1,   Pos(mDelimiter,   mStr)   -   1);
  end;   {   StrLeft   }   
    
  function   StrRight(const   mStr:   string;   mDelimiter:   string):   string;
  begin
      if   Pos(mDelimiter,   mStr)   >   0   then
          Result   :=   Copy(mStr,   Pos(mDelimiter,   mStr)   +   Length(mDelimiter),   MaxInt)
      else   Result   :=   '';   
  end;   {   StrRight   }


function pdf_load_version(xref:ppdf_xref_s):integer;
var
buf:array[0..19] of char;
buf1:array[0..4] of char;
begin
  xref.version:=-1;

  fz_seek(xref^.myfile, 0, 0);

	fz_read_line(xref^.myfile,@buf, sizeof(buf));
  buf1:='%PDF-';
	if (CompareMem(@buf, @buf1, 5)=false) THEN
  BEGIN

    EXIT;
  END;

	xref.version :=strtointdef(buf[5],-1)*10+strtointdef(buf[7],-1);

	result:=xref^.version;
end;

function iswhite(ch:char):boolean;
var
i:integer;
begin
  result:=false;
  i:=ord(ch);
  if ((i=0) or  (i=9) or  (i=10) or  (i=12) or  (i=13) or  (i=32)) then
  begin
    result:=true;
  end;
end;
function isdelim(c:char):boolean;

begin
result:=false;
if ((c='(') or  (c=')') or   (c='<') or  (c='>') or  (c='[') or  (c=']') or  (c='{')    or  (c='/')  or  (c='%')) then
   begin
    result:=true;
  end;

end;

function isnotnum(ch:char):boolean;

begin
  result:=false;
  if (ch>'9') or (ch<'0') then
  begin
     result:=true;
  end;
end;

function isaf(ch:char):boolean;

begin
  result:=true;
  if (ch>'f') or (ch<'a') then
  begin
     result:=false;
  end;
end;

function isDAF(ch:char):boolean;

begin
  result:=true;
  if (ch>'F') or (ch<'A') then
  begin
     result:=false;
  end;
end;

function IS_HEX(ch:char):boolean;
begin
  result:=false;
  if (ch>='A') or (ch<='F') then
  begin
     result:=true;
  end;
  if (ch>='0') or (ch<='9') then
  begin
     result:=true;
  end;

  if (ch>='0') or (ch<='f') then
  begin
     result:=true;
  end;

end;





function pdf_read_start_xref(xref:ppdf_xref_s):integer;
var
  buf:array[0..1023] of char;
  buf1:array[0..8] of char;
  t,n,i:integer;
  s:string;
  p:pbyte;
begin
  result:=-1;

  fz_seek(xref.myfile, 0, 2);

	xref.file_size := fz_tell(xref.myfile);
  buf1:= 'startxref';




	t := MAX(0, xref.file_size - sizeof (buf));
  fz_seek(xref.myfile, t, 0);
   p:=@buf;
	n := fz_read(xref.myfile, p, sizeof(buf));



  if (n < 0) then
  begin

  exit;
  end;
  i := n - 9;
   s:='';
	while i>=0 do
  begin

		if (CompareMem(@buf[i], @buf1, 9) =true) then
		begin
			i:=i+9;
			while (isnotnum(buf[i]) and (i < n)) do
      i:=i+1;

      while ((isnotnum(buf[i])=false) and (i < n)) do
      begin

       s:=s+buf[i];
       i:=i+1;
      end;
      xref.startxref :=strtointdef(s,-1);
		  result:=1;
      exit;
		end;
    i:=i-1;
	end;
end;







function lex_string(f:pfz_stream_s; buf :pchar;  n:integer):integer;
var
	s :pchar;
  c:char;
  c1:integer;
  bal,oct,i:integer;

  pp:cardinal;
  label toend;
begin
  s:=buf;
  bal:=1;

  pp:=cardinal(s)+n;

	while (cardinal(s)<pp) do
  begin

    c1 := fz_read_byte(f);
		if c1=eeof then
    BEGIN
      RESULT:=1;
      goto toend;
    END;
    c:=chr(c1);
    if c='(' then
    begin
      bal:=bal+1;

      s^:=c;
      inc(s);
      continue;
    end;

		if c=')' then
    begin
      bal:=bal-1;
      if bal=0 then
         goto toend;
      
      s^:=c;
      inc(s);
      continue;
    end;

    if c='\' then
    begin

       c1 := fz_read_byte(f);
       if c1=eeof then
          goto toend;
       c:=chr(c1);
       if c='n' then
       begin
         
         s^:=#10;  //\n
         inc(s);
         continue;
       end;

       if c='r' then
       begin
         
         s^:=#13;  //\r
         inc(s);
         continue;
       end;
       if c='t' then
       begin
         inc(s);
         s^:=#9;  //\t
         continue;
       end;
       if c='b' then
       begin
         
         s^:=#8;  //\b
         inc(s);
         continue;
       end;
       if c='f' then
       begin
         
         s^:=#12;  //\f
          inc(s);
         continue;
       end;

       if c='(' then
       begin
         
         s^:='(';  //\(
         inc(s);
         continue;
       end;
       if c=')' then
       begin
         
         s^:=')';  //\)
         inc(s);
         continue;
       end;
       if c='\' then
       begin
        
         s^:='\';  //\)
         inc(s);
         continue;
       end;
       if isnotnum(c)=false then
       begin
         oct:=ord(c)-ord('0');
         c1 := fz_read_byte(f);
         c:=chr(c1);
       
         if (c >= '0') and (c <= '9') then
         begin
           oct:=oct*8+(ord(c)-ord('0'));

           c1 := fz_read_byte(f);


           c:=chr(c1);
           if (c >= '0') and (c <= '9') then
           begin
              oct:=oct*8+(ord(c)-ord('0'));
           end
           else
           begin
             if (c1<>eeof) then
                fz_unread_byte(f);
           end;
         end
         else
         begin
           if (i<=0) then
                fz_unread_byte(f);
         end;

         
        // s^:=#13;  //\)
        s^:=chr(oct);
         inc(s);
         continue;

       end;

    end;

    if c=#10 then
    continue;
    if c=#13 then
    begin
      c1 := fz_read_byte(f);
      c:=chr(c1);
      if ((c <> #13) and (i<=0))  then
      begin
					 fz_unread_byte(f);
          continue;
      end;
    end;

		
    s^:=c;
    inc(s);
		continue;
	end;
  toend:
  begin
	result:=s - buf;
  exit;
  end;
end;


function lex_number(f:pfz_stream_s; s:pchar; nn:integer;  tok:Ppdf_kind_e) :integer;
var
n,c1:integer;
c:char;
p:pchar;
label   loop_after_sign,loop_after_dot,goend;
begin
  result:=-1;
  n:=nn;
 	tok^ := PDF_TOK_INT;
  FillChar(s^,nn,0);
  p:=s;
	//* Initially we might have +, -, . or a digit */
	if (n > 1)  then
	begin
    c1 := fz_read_byte(f);
		if c1=eeof then
    BEGIN
      goto goend;
      EXIT;
    END;
    c:=chr(c1);
		IF C='.' THEN
    BEGIN
			tok^ :=PDF_TOK_REAL;
      
      p^:=c;
      inc(p);
			n:=n-1;
			goto loop_after_dot;
    END;

		if ((c='+') or (c='-') or  (isnotnum(c)=false)) then
    begin

      p^:=c;
      inc(p);
      n:=n-1;
			goto loop_after_sign;
    end;
			fz_unread_byte(f);
       goto goend;
	end;

 //* We can't accept a sign from here on in, just . or a digit */
loop_after_sign:
begin
	while (n > 1)  do
  begin
		c1 := fz_read_byte(f);
		if c1=eeof then
    BEGIN
      goto goend;
      EXIT;
    END;
     c:=chr(c1);
	  if c='.' then
    begin
	   	tok^ :=PDF_TOK_REAL;
		
      p^:=c;
      inc(p);
			n:=n-1;
			goto loop_after_dot;
    end;
    if isnotnum(c)=false then
    begin

      p^:=c;
      inc(p);
      n:=n-1;
      continue;
    end;
	 		fz_unread_byte(f);
      goto goend;
      exit;
		end;
		n:=n-1;

end;

 //* In here, we've seen a dot, so can accept just digits */
loop_after_dot:
begin
	while (n > 1)  do
  begin
    	c1 := fz_read_byte(f);
		if c1=eeof then
    BEGIN
      RESULT:=1;
      EXIT;
    END;
     c:=chr(c1);
	if isnotnum(c)=false then
  begin
			
      p^:=c;
      inc(p);
      n:=n-1;
			continue;
  end;

			fz_unread_byte(f);
      goto goend;
      break;

 end;

end;
p^:=#0;
goend:
RESULT:=p-s;

end;

procedure lex_comment(f:pfz_stream_s);
var
c:integer;
i:integer;
begin
	repeat
    c := fz_read_byte(f);
  until ((c=10) or (c=13) or (c<0));

end;

procedure lex_white(f:pfz_stream_s);
var
c:integer;
i:integer;
begin
	repeat
    c := fz_read_byte(f);
    if c=eeof then
    break;
	until ((c > 32) or (not iswhite(chr(c))));
	if (c<>eeof) then
		fz_unread_byte(f);
end;


procedure lex_name(f:pfz_stream_s; s:pchar; nn:integer);
var
n,i,d,c1:integer;
c:char;
p:pchar;
begin
  n:=nn;
  p:=s;
  zeromemory(s,nn);
	while (n > 1) do
	begin
		c1 := fz_read_byte(f);
    if c1=eeof then
    begin
      break;
    end;
   // if ISWHITE(c) then
   //  continue;
     c:=chr(c1);
    if ISWHITE(c) OR ISDELIM(c) then
    begin
      fz_unread_byte(f);
      break;
    end;

   if c='#' then
   begin

      c1 := fz_read_byte(f);

      if c1=eeof then
      break;
      c:=chr(c1);
      if isnotnum(c)=false then
      begin
        d:=(ord(c)-ord('0')) shl 4;
        continue;
      end;

      if isaf(c)=true then
      begin
        d:=(ord(c)-ord('a')+10) shl 4;
        continue;
      end;

      if isdaf(c)=true then
      begin
        d:=(ord(c)-ord('A')+10) shl 4;
        continue;
      end;

			fz_unread_byte(f);

      c1 := fz_read_byte(f);
        if c1=eeof then
        exit;
        c:=chr(c1);
      if isnotnum(c)=false then
      begin
        d:=(ord(c)-ord('0'));
        c:=chr(d);
        continue;
      end;

      if isaf(c)=true then
      begin
        d:=(ord(c)-ord('a')+10);         //改过
        c:=chr(d);
        continue;
      end;

      if isdaf(c)=true then
      begin
        d:=(ord(c)-ord('A')+10);     //改过
        continue;
      end;

      fz_unread_byte(f);

      n:=n-1;
      continue;
   end;
     p^:=c;
     inc(p);
  		n:=n-1;
		 //	break;
end;

end;



function unhex(ch:char):integer;
begin
	if (ch >= '0') and (ch <= '9') then
  begin
   result:=ord(ch) - ord('0');
   exit;
  end;
	if (ch >= 'A') and (ch <= 'F') then
  begin
  result:=ord(ch) - ord('A') +$A;
  exit;
  end;

	if (ch >= 'a') and (ch <= 'f') then
  begin
  result:= ord(ch) - ord('a') + $A;
  exit;
  end;

	result:=0;
end ;


function lex_hex_string(f:pfz_stream_s; buf:pchar; nn:integer):integer ;
var
s:pchar;
a,x,i,n,c1:integer;
c:char;
pp:cardinal;
label toend;
begin
a:=0;
x:=0;
s:=buf;
n:=nn;
 pp:=cardinal(s)+n;
	while (cardinal(s)<pp) do
	begin
			c1 := fz_read_byte(f);
      if c1=eeof then
      goto toend;
    c:=chr(c1);
    if c='>' then
      goto toend;
    if ISWHITE(c)=true then
    continue;
		if IS_HEX(c)=true then
    begin
			if (x<>0) then
			begin
      
			s^:=char(a * 16 + unhex(c));
      inc(s);
				x := not x;
			end
			else
			begin
				a := unhex(c);
				x := not x;
			end;
			continue;
    end;

	end;
toend:
	result:= s - buf;
end;

function pdf_token_from_keyword(key:pchar):pdf_kind_e;
var

  c:char;
begin

  c:=key[0];
	case c of 
	'R':
		begin
    if StrComp(key, 'R')=0 then
    begin
    result:=PDF_TOK_R;
		exit;
    end;
    end;
	't':
		begin
    if (StrComp(key, 'true')=0) then
    begin
     result:=PDF_TOK_TRUE;
     exit;
    end;
		if (StrComp(key, 'trailer')=0) then
    begin
     result:=PDF_TOK_TRAILER;
		 exit;
     end;
    end;
	'f':
		begin
    if (StrComp(key, 'false')=0) then
    begin
      result:=PDF_TOK_FALSE;
	   	exit;
    end;
    end;
	'n':
		begin
    if (StrComp(key, 'null')=0) then
    begin
      result:=PDF_TOK_NULL;
		  exit;
     end;
    end;
	'o':
  begin
		if (StrComp(key, 'obj')=0) then
    begin
    result:=PDF_TOK_OBJ;
		exit;
    end;
    end;
	'e':
  begin
		if (StrComp(key, 'endobj')=0) then
    begin
     result:=PDF_TOK_ENDOBJ;
     exit;
    end;
		if (StrComp(key, 'endstream')=0) then
    begin
     result:=PDF_TOK_ENDSTREAM;
	   exit;
    end;
  end;
	's':
		begin
    if (StrComp(key, 'stream')=0) then
    begin
    result:=PDF_TOK_STREAM;
    exit;
    end;
		if (StrComp(key, 'startxref')=0) then
    begin
    result:=PDF_TOK_STARTXREF;
		exit;
    end;
    end;
	'x':
  begin
  if (StrComp(key, 'xref')=0) then
  begin
  result:=PDF_TOK_XREF;
	exit;
  end;
  end;
	end;

	result:= PDF_TOK_KEYWORD;
end;

function IS_NUMBER(c:char):boolean;
begin
  result:=false;
  if (c='+') or (c='-') then
  begin
  result:=true;
  exit;
  end;
  if (c='.')  then
  begin
  result:=true;
  exit;
  end;

  if (c>='0') and (c<='9') then
  begin
  result:=true;
  exit;
  end;



end;

FUNCTION pdf_lex(tok:Ppdf_kind_e; f:pfz_stream_s; buf:pchar; const n:integer; sl:pinteger):integer;
var
c1:integer;
c:char;
i:integer;
label   cleanuperror;
BEGIN
  result:=-19;
	while true do
	begin
    c1 := fz_read_byte(f);

		IF c1=eeof then
    begin
		  tok^ := PDF_TOK_EOF;
      result:=1;
			exit;
    end;
    c:=chr(c1);
		if ISWHITE(c)=true then
    begin
			lex_white(f);
		end else if c='%' then
    begin
      lex_comment(f);
    end else  if c='/' then
    begin
     lex_name(f, buf, n);
			sl^ := strlen(buf);
			tok^ := PDF_TOK_NAME;
			result:=1;
      exit;
    end else  if c= '(' then
    begin
			sl^ := lex_string(f, buf, n);
			tok^ :=PDF_TOK_STRING;
			result:=1;
      exit;
    end else if c= ')' then
    begin
			tok^ :=PDF_TOK_ERROR;
			goto cleanuperror;
    end else if c= '<' then
    begin
			c1 := fz_read_byte(f);
      c:=chr(c1);
			if (c = '<') then
      begin
				tok^ :=PDF_TOK_OPEN_DICT;
      end
			else
			begin
			   fz_unread_byte(f);
				sl^ := lex_hex_string(f, buf, n);
				tok^ :=PDF_TOK_STRING;
			end;
			result:=1;
      exit;
    end else if c= '>' then
    begin
			c1 := fz_read_byte(f);
      c:=chr(c1);
			if (c = '>') then
		  begin
				tok^ :=PDF_TOK_CLOSE_DICT;
        result:=1;
        exit;
			end;
			tok^ :=PDF_TOK_ERROR;
			goto cleanuperror;
   end else  if c= '[' then
   begin
			tok^ :=PDF_TOK_OPEN_ARRAY;
			result:=1;
        exit;
   end else if c= ']' then
   begin
			tok^ :=PDF_TOK_CLOSE_ARRAY;
			result:=1;
      exit;
   end else if c= '{' then
    begin
			tok^ :=PDF_TOK_OPEN_BRACE;
			result:=1;
      exit;
    end else if  c= '}' then
      begin
			tok^ :=PDF_TOK_CLOSE_BRACE;
			result:=1;
      exit;
      end else 	if  IS_NUMBER(c)=true then
    begin
				fz_unread_byte(f);
			sl^ := lex_number(f, buf, n, tok);
      result:=1;
			exit;
    end
    else
    begin
	 //	default: /* isregular: !isdelim && !iswhite && c != EOF */
		fz_unread_byte(f);
		lex_name(f, buf, n);
		sl^ := strlen(buf);
		tok^ := pdf_token_from_keyword(buf);
     result:=1;
     exit;
    end;

	end;
cleanuperror:
begin
tok^ :=PDF_TOK_ERROR;
result:=-1;
exit;
end;

END;




FUNCTION pdf_parse_array(op:ppfz_obj_s; pdf_xref:ppdf_xref_s; f:pfz_stream_S;buf :pchar;  cap:integer):INTEGER;
VAR
 ary, obj: pfz_obj_s;
 a,b,n,len:integer;
 tok:pdf_kind_e;
 error:integer;
 s:string;
BEGIN
 //	fz_error error = fz_okay;
 a:=0;
 b:=0;
 n:=0;
  ary:=nil;
  obj:=nil;
	ary := fz_new_array(4);

	while true do
	begin
		error := pdf_lex(@tok, f, buf, cap, @len);
		if (error<0) then
		begin
			fz_drop_obj(ary);
		  fz_rethrow(error, 'cannot parse array');
     exit;
		end;

		if (tok <> PDF_TOK_INT) and (tok <> PDF_TOK_R) then
		begin
			if (n > 0) then
			begin
				obj := fz_new_int(a);
				fz_array_push(ary, obj);
				fz_drop_obj(obj);
			end;
			if (n > 1) then
			begin
				obj := fz_new_int(b);
				fz_array_push(ary, obj);
				fz_drop_obj(obj);
			end;
			n := 0;
		end;

		if (tok = PDF_TOK_INT) and (n = 2) then
		begin
			obj := fz_new_int(a);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			a := b;
			n:=n-1;
		end;

	 //	switch (tok)
    case  tok of
		PDF_TOK_CLOSE_ARRAY:
      begin
			op^ := ary;
      result:=1;
      exit;
		   //	return fz_okay;
      end;
		PDF_TOK_INT:
      begin
			if (n = 0) then
      begin
    a:=atoi( buf);
      end;
         // a:=atoi( buf);

		//	 a :=strtoint((trim(string(buf)))); // atoi(buf);
			if (n = 1) then
      begin
       b:=atoi( buf);
      end;

			n:=n+1;
      continue;
      end;
		PDF_TOK_R:
      begin
			if (n <> 2) then
			begin
				fz_drop_obj(ary);
        result:=fz_throw('cannot parse indirect reference in array');
        exit;
				//return fz_throw("cannot parse indirect reference in array");
			end;
			obj := fz_new_indirect(a, b, pdf_xref);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			n := 0;
			continue;
      end;
		PDF_TOK_OPEN_ARRAY:
      begin
			error := pdf_parse_array(@obj, pdf_xref, f, buf, cap);
			if (error<0) then
			begin
				fz_drop_obj(ary);
        result:=fz_rethrow(error, 'cannot parse array');
        exit;
				//return fz_rethrow(error, "cannot parse array");
			end;
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		PDF_TOK_OPEN_DICT:
      begin
			error := pdf_parse_dict(@obj, pdf_xref, f, buf, cap);
			if (error<0) then
			begin
				fz_drop_obj(ary);
        result:=fz_rethrow(error,'cannot parse array');
        exit;
			//	return fz_rethrow(error, "cannot parse array");
			end;
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		PDF_TOK_NAME:
      begin
			obj := fz_new_name(buf);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
	   	continue;
      end;
		PDF_TOK_REAL:
      begin
			obj := fz_new_real(fz_atof(buf));
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
		  continue;
      end;
	  PDF_TOK_STRING:
      begin
			obj := fz_new_string(buf, len);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		PDF_TOK_TRUE:
      begin
			obj := fz_new_bool(1);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		PDF_TOK_FALSE:
      begin
			obj := fz_new_bool(0);
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		PDF_TOK_NULL:
      begin
			obj := fz_new_null();
			fz_array_push(ary, obj);
			fz_drop_obj(obj);
			continue;
      end;
		else
      begin
			fz_drop_obj(ary);
      result:=-1;
      //return fz_throw("cannot parse token in array");
      exit;
      end;
		 
		end;
	end;
END;


function pdf_parse_dict(op:PPfz_obj_S; pdf_xref:ppdf_xref_s; F:pfz_stream_s; buf:pchar; cap:integer):integer;
var
 dict:Pfz_obj_S;
 key:Pfz_obj_S;
 val:Pfz_obj_S;
 tok:pdf_kind_e;
 len,a, b:integer;
// ss:string;
 error:integer;

 label skip;
begin
 dict := nil;
 key := nil;
 val := nil;
 dict:= fz_new_dict(8);

	while (true) do
	begin
		error := pdf_lex(@tok, f, buf, cap, @len);
		if (error<0) then
		begin
			fz_drop_obj(dict);
		 //	return fz_rethrow(error, "cannot parse dict");
     result:=-1;
     exit;
		end;

skip:
		if (tok = PDF_TOK_CLOSE_DICT) then
		begin
			op^ := dict;
		//	return fz_okay;
      result:=1;
      exit;
		end;
    // ss:=buf;
    // ss:=trim(ss);
		//* for BI .. ID .. EI in content streams */
		if (tok = PDF_TOK_KEYWORD) and (strcomp(buf, 'ID')=0) then     //CompareStr
		begin
			op^ := dict;
			//return fz_okay;
      result:=1;
      exit;
		end;

		if (tok <> PDF_TOK_NAME) then
		begin
			fz_drop_obj(dict);
			result:=fz_throw('invalid key in dict');

      exit;
		end;

		key := fz_new_name(buf);

		error := pdf_lex(@tok, f, buf, cap, @len);
		if (error<0) then
		begin
			fz_drop_obj(key);
			fz_drop_obj(dict);
		 //	return fz_rethrow(error, "cannot parse dict");
      result:=-1;
      exit;
		end;

	 //	switch (tok)
    case tok of
			PDF_TOK_OPEN_ARRAY:
      begin
	   		error := pdf_parse_array(@val, pdf_xref,  f, buf, cap);
	  		if (error<0) then
  			begin
		  		fz_drop_obj(key);
	   			fz_drop_obj(dict);
		  	 //	return fz_rethrow(error, "cannot parse dict");
          result:=-1;
          exit;
	   		end;
			end;

		  PDF_TOK_OPEN_DICT:
      begin
			error := pdf_parse_dict(@val, pdf_xref,  f, buf, cap);
	  		if (error<0) then
	  		begin
		   		fz_drop_obj(key);
		  		fz_drop_obj(dict);
		  	//	return fz_rethrow(error, "cannot parse dict");
          result:=-1;
          exit;
		  	end;
		  end;
		PDF_TOK_NAME:
      val := fz_new_name(buf);
		PDF_TOK_REAL:
      val := fz_new_real(fz_atof(buf));
		PDF_TOK_STRING:
      val := fz_new_string(buf, len);
		PDF_TOK_TRUE:
      val := fz_new_bool(1);
		PDF_TOK_FALSE:
      val := fz_new_bool(0);
		PDF_TOK_NULL:
      val := fz_new_null();
  	PDF_TOK_INT:
			//* 64-bit to allow for numbers > INT_MAX and overflow */
      begin
	 //		a := (int) strtoll(buf, 0, 10);
      //ss:=buf;
    //  ss:=trim(ss);
    //  a:=strtointdef(ss,-1);
      a:=atoi(buf);
			error := pdf_lex(@tok, f, buf, cap, @len);
			if (error<0) then
			begin
				fz_drop_obj(key);
				fz_drop_obj(dict);
        result:=fz_rethrow(error, 'cannot parse dict');
          exit;
			 //	return fz_rethrow(error, "cannot parse dict");
			end;
      //ss:=buf;
      //ss:=trim(ss);
			if ((tok = PDF_TOK_CLOSE_DICT) or (tok = PDF_TOK_NAME) or ((tok = PDF_TOK_KEYWORD) and (strcomp(buf,'ID')=0)))  then                   //!strcmp(buf, "ID")
			begin
				val := fz_new_int(a);
				fz_dict_put(dict, key, val);
				fz_drop_obj(val);
				fz_drop_obj(key);
				goto skip;
			end;
			if (tok = PDF_TOK_INT)  then
			begin

				b := atoi(buf);
      // b:=strtoint(ss);
				error := pdf_lex(@tok, f, buf, cap, @len);
				if (error<=0)  then
				begin
					fz_drop_obj(key);
					fz_drop_obj(dict);
          result:=fz_rethrow(error, 'cannot parse dict');
          exit;
					//return fz_rethrow(error, "cannot parse dict");
				end;
				if (tok = PDF_TOK_R) then
				begin
					val := fz_new_indirect(a, b, pdf_xref);
				 //	continue;

         	fz_dict_put(dict, key, val);
	        	fz_drop_obj(val);
	        	fz_drop_obj(key);
            continue;
				end;
			end;
			fz_drop_obj(key);
			fz_drop_obj(dict);
      result:=fz_throw('invalid indirect reference in dict');
          exit;
			//return fz_throw("invalid indirect reference in dict");
      end;
		else
      begin
			fz_drop_obj(key);
			fz_drop_obj(dict);
      result:=fz_throw('unknown token in dict');
          exit;
      end;
			//return fz_throw("unknown token in dict");
		end;

		fz_dict_put(dict, key, val);
		fz_drop_obj(val);
		fz_drop_obj(key);
	end;

end;


function pdf_read_old_trailer(xref:ppdf_xref_s; buf:pchar; cap:integer):integer;
VAR
startn,len,n,t,c,i:integer;
tok:pdf_kind_e;
s:pchar;
buf1:array[0..3] of char;
error:integer;
p:pchar;
begin
   result:=-1;

  fz_read_line(xref.myfile,buf,cap);
  buf1:= 'xref';

	if (CompareMem(buf, @buf1, 4) =false) then
  begin

    exit;
	 //	return fz_throw("cannot find xref marker");
  end;

	while true do
  begin
    c := fz_peek_byte(xref.myfile);
		if not ((c >=ord('0')) and  (c <= ord('9'))) then
			break;


        fz_read_line(xref.myfile,buf,cap);
    s:=buf;
    fz_strsep(@s, ' '); //* ignore ofs */
    if s=nil then
    begin
     // continue;
      result:=-1;
      exit;
    end;
    //startn:=strtointdef(StrLeft(s,' '),-1);
    len := atoi(fz_strsep(@s, ' '));
   //	len:=strtointdef(StrRight(s,' '),-1);


    if (s<>nil) and (s^ <>#0) then
			fz_seek(xref.myfile, -(2 + strlen(s)), 1);    //

		t := fz_tell(xref.myfile);
		if (t < 0) then
    begin
			//return fz_throw("cannot tell in file");
      result:=-1;
      exit;
    end;

		fz_seek(xref.myfile, t + 20 * len, 0);
	end;

	error := pdf_lex(@tok, xref.myfile, buf, cap, @n);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot parse trailer');
    //result:=-1;
    exit;
  end;
  result:=error;

	if (tok <> PDF_TOK_TRAILER)  then
  begin
    result:=-1;
		//return fz_throw("un expected trailer marker");
    exit;
  end;

	error := pdf_lex(@tok, xref.myfile, buf, cap, @n);
	if (error<0) then
  begin
    result:=fz_rethrow(error, 'cannot parse trailer');
    exit;
	//	return
  end;
	if (tok <> PDF_TOK_OPEN_DICT)   then
  begin
	//	return fz_throw("expected trailer dictionary");
    result:=-1;
    exit;
  end;

	error := pdf_parse_dict(@xref.trailer, xref, xref.myfile, buf, cap);
	if (error<0) then
  begin
  result:=fz_rethrow(error, 'cannot parse trailer');
  exit;
   //	return
  end;

	result:=1; //fz_okay;
end;

function pdf_read_trailer(pdf_xref:ppdf_xref_s; buf:pchar; cap:integer):integer;
var
  c:char;
  c1:integer;
begin
  fz_seek(pdf_xref.myfile, pdf_xref.startxref, 0);

	while (iswhite(chr(fz_peek_byte(pdf_xref.myfile)))) do
		fz_read_byte(pdf_xref.myfile);

	c := chr(fz_peek_byte(pdf_xref.myfile));

 if (c = 'x') then
 begin

		result:=pdf_read_old_trailer(pdf_xref, buf, cap);
    exit;
	end
	else
  if (c >= '0') and  (c <= '9') then
  begin

		result:= pdf_read_new_trailer(pdf_xref, buf, cap);
		exit;
	end
	else
	begin
	  //	return fz_throw("cannot recognize xref format: '%c'", c);
    result:=-1;
  end;

end;

function pdf_read_new_xref_section(xref:ppdf_xref_s; stm:pfz_stream_s; i0,  i1, w0, w1, w2:integer):integer;
var
i,n,t,g:integer;
a,b,c:integer;
d:char;
begin

	if (i0 < 0) or ((i0 + i1) > xref.len)  then
  begin
		//return fz_throw("xref stream has too many entries");
    result:=-1;
    exit;
  end;

	for i := i0 to i0 + i1-1 do
	begin
    a:=0;
    b:=0;
    c:=0;
    if (fz_is_eof(stm)=1) then
    begin

			//return fz_throw("truncated xref stream");
      result:=-1;
      exit;
    end;

    for  n:=0  to w0-1 do
    begin

       a := (a shl 8) + fz_read_byte(stm);
    end;

    for  n:=0  to w1-1 do
    begin

       b := (b shl 8) + fz_read_byte(stm);
    end;
     for  n:=0  to w2-1 do
    begin

       c := (c shl 8) + fz_read_byte(stm);
    end;



		if (table_items(xref.table)[i].type1=0) then
		begin
       if w0<>0 then
       t:=a
       else
       t:=1;

       g:=0;
       if t=0 then
       g:=ord('f');
       if t=1 then
       g:=ord('n');
       if t=2 then
       g:=ord('o');

			table_items(xref.table)[i].type1:=g;
       g:=0;
       if w1<>0 then
       g:=b;
			table_items(xref.table)[i].ofs :=g;
       g:=0;
       if w2<>0 then
       g:=c;

			table_items(xref.table)[i].gen :=g;
		end;
	end;

	//return fz_okay;
  result:=1;
end;

function pdf_read_new_xref(trailerp:ppfz_obj_s; xref: ppdf_xref_s ; buf :pchar; cap:integer):integer;
var
	error:integer;
	stm :Pfz_stream_s;
	trailer:pfz_obj_s; // *trailer;
	index:pfz_obj_s;
	obj:pfz_obj_s;
	num, gen, stm_ofs:integer;
	size, w0, w1, w2:integer;
  i0,i1,J:integer;
	t:integer;
begin


	error := pdf_parse_ind_obj(@trailer, xref, xref.myfile, buf, cap, @num, @gen, @stm_ofs);
	if (error<0) then
  begin
		//return fz_rethrow(error, "cannot parse compressed xref stream object");
    result:=-1;
    exit;
  end;

	obj := fz_dict_gets(trailer, 'Size');
	if (obj=nil) then
	begin
		fz_drop_obj(trailer);
		//return fz_throw("xref stream missing Size entry (%d %d R)", num, gen);
    result:=-1;
    exit;
	end;
	size := fz_to_int(obj);

	if (size > xref.len)  then
	begin
		pdf_resize_xref(xref, size);
	end;

	if (num < 0) or (num >= xref.len) then
	begin
		fz_drop_obj(trailer);
	   result:= fz_throw('object id (%d %d R) out of range (0..%d)', [num, gen, xref^.len - 1]);

    exit;
	end;

	obj := fz_dict_gets(trailer, 'W');
	if (obj=nil) then
  begin
		fz_drop_obj(trailer);
		//return fz_throw("xref stream missing W entry (%d %d R)", num, gen);
    result:=-1;
    exit;
	end;
	w0 := fz_to_int(fz_array_get(obj, 0));
	w1 := fz_to_int(fz_array_get(obj, 1));
	w2 := fz_to_int(fz_array_get(obj, 2));

	index := fz_dict_gets(trailer, 'Index');

	error := pdf_open_stream_at(@stm, xref, num, gen, trailer, stm_ofs);
	if (error<0) then
  begin
		fz_drop_obj(trailer);
	 //	return fz_rethrow(error, "cannot open compressed xref stream (%d %d R)", num, gen);
   result:=-1;
    exit;
	end;

	if (index=nil)   then
	begin
		error := pdf_read_new_xref_section(xref, stm, 0, size, w0, w1, w2);
		if (error<0) then
		begin
		 fz_close(stm);
			fz_drop_obj(trailer);
		 result:= fz_rethrow(error, 'cannot read xref stream (%d %d R)', [num, gen]);

     exit;
		end;
	end
	else
	begin
		for t := 0 to fz_array_len(index)-1  do
		begin
      j:=T  mod   2;
      if   j<>0   then
        CONTINUE;
		  i0 := fz_to_int(fz_array_get(index, t + 0));
		  i1 := fz_to_int(fz_array_get(index, t + 1));
			error := pdf_read_new_xref_section(xref, stm, i0, i1, w0, w1, w2);
			if (error<0) then
			begin
			 fz_close(stm);
				fz_drop_obj(trailer);
				result:= fz_rethrow(error, 'cannot read xref stream section (%d %d R)', [num, gen]);

        EXIT;
			end;
		end;
	end;

 fz_close(stm);

	trailerp^ := trailer;
  result:=1;
  exit;
	//return fz_okay;
end;



function pdf_read_old_xref(trailerp:ppfz_obj_s; xref:ppdf_xref_s;  buf:pchar;  cap:Pinteger):integer;
var
	error:integer;
	ofs, len,n,i,k,c1:integer;
	s:pchar;
	tok:pdf_kind_e;
	c:char;
  buf1:array[0..4] of char;
  ss,ss1:string;
  p:pbyte;
begin
  fz_read_line(xref.myfile,buf,cap^);
   buf1:= 'xref';
	if (CompareMem(buf, @buf1, 4) =false) then
 //	if (strlncmp(buf, 'xref', 4) <> 0) then
  begin
	 //	return fz_throw("cannot find xref marker");
    result:=-1;
    exit;
  end;

	while (true)  do
	begin

    c1 := fz_peek_byte(xref.myfile);
  c:=chr(c1);
		if (not ((c >= '0') and (c <= '9'))) then
			break;

		fz_read_line(xref.myfile,buf,cap^);
		s:= buf;
  //  ss:=(string(buf));
  //  ss:=trim(s);
  //  ofs:=strtointdef(StrLeft(ss,' '),-1);

   //	len:=strtointdef(StrRight(ss,' '),-1);


     ofs := atoi(fz_strsep(@s, ' '));
		len := atoi(fz_strsep(@s, ' '));
		//* broken pdfs where the section is not on a separate line */
	 	if (s<>nil) and (s^ <>#0) then   // fz_seek(xref.myfile, -(2
		begin
		 	fz_warn('broken xref section. proceeding anyway.');
			fz_seek(xref^.myfile, -(2 + strlen(s)), 1);
		end;

		//* broken pdfs where size in trailer undershoots entries in xref sections */
		if (ofs + len > xref.len) then
		begin
		 	fz_warn('broken xref section, proceeding anyway.');
			pdf_resize_xref(xref, ofs + len);
		end;

		for i := ofs to ofs + len-1 do
		begin
	//		n := fz_read(xref->file, (unsigned char *) buf, 20);
     p:=pbyte(buf);
      n:=fz_read(xref.myfile,p,20);

			if (n < 0) then
      begin
        result:=-1;
				result:= fz_rethrow(n, 'cannot read xref table');
        exit;
      end;
			if (table_items(xref.table)[i].type1=0) then
			begin
				s := buf;

				// broken pdfs where line start with white space
				while ((s^<>#0) and (iswhite(s^)))  do
				  inc(s);
         ss:=buf;
         ss:=trim(ss) ;
         ss1:=copy(ss,1,10);
         ss1:=trim(ss1) ;
				table_items(xref.table)[i].ofs := strtoint(ss1);
        ss1:=copy(ss,12,6);
        ss1:=trim(ss1) ;
				table_items(xref.table)[i].gen := strtoint(ss1);
				table_items(xref.table)[i].type1 := ord(s[17]);
				if ((s[17] <> 'f') and (s[17] <> 'n') and (s[17] <> 'o')) then
        begin
				 result:= fz_throw('unexpected xref type: %x (%d %d R)', [s[17], i, table_items(xref.table)[i].gen]);
         result:=-1;
         exit;
        end;
			end;
		end;
	end;

	error:= pdf_lex(@tok, xref.myfile, buf, cap^, @n);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot parse trailer');

    exit;
  end;
	if (tok<>PDF_TOK_TRAILER) then
    begin
	   result:=-1;
     exit;
   // 	return fz_throw("expected trailer marker");
  end;


	error := pdf_lex(@tok, xref.myfile, buf, cap^, @n);
	if (error<0) then
    begin
	  result:= fz_rethrow(error, 'cannot parse trailer');
   // result:=-1;
    exit;
    end;
	if (tok <> PDF_TOK_OPEN_DICT) then
  begin
    result:=-1;
    exit;
   // 	return fz_throw("expected trailer marker");
  end;

	error := pdf_parse_dict(trailerp, xref, xref.myfile, buf, cap^);
	if (error<0)  then
  begin
    result:=fz_rethrow(error, 'cannot parse trailer');
    exit;
		//return
  end;
//	return fz_okay;
  result:=1;
  exit;
end;




function pdf_read_xref(trailerp:ppfz_obj_s; xref:ppdf_xref_s; ofs:integer; buf:pchar; cap:integer):integer ;
var
  error:integer;
  c:char;
  c1:integer;
  i:integer;
begin
  fz_seek(xref.myfile, ofs, 0);     //             fz_seek(xref->file, ofs, 0);


  while (iswhite(chr(fz_peek_byte(xref.myfile))))  DO
		fz_read_byte(xref.myfile);
  c1 := fz_peek_byte(xref.myfile);
  c:=chr(c1);


	if (c = 'x')  then
	begin
		error := pdf_read_old_xref(trailerp, xref, buf, @cap);
		if (error<0) then
    begin
			//return fz_rethrow(error, "cannot read xref (ofs=%d)", ofs);
      result:=-1;
      exit;
    end;
	end
	else if (c >= '0') and (c <= '9')  then
	begin
		error := pdf_read_new_xref(trailerp, xref, buf, cap);
		if (error<0)  then
    begin
      result:=-1;
      exit;
			//return fz_rethrow(error, "cannot read xref (ofs=%d)", ofs);
    end;
	end
	else
	begin
		//return fz_throw("cannot recognize xref format");
    RESULT:=-1;
    EXIT;
	end;
  result:=1;
	//return fz_okay;
end;


function pdf_read_xref_sections(xref:ppdf_xref_s; ofs:integer; buf:pchar; cap:integer):integer;
var
error:integer;
trailer,prev,xrefstm:pfz_obj_s;

begin
  result:=1;
  trailer:=nil;
  prev:=nil;
  xrefstm:=nil;
	error := pdf_read_xref(@trailer, xref, ofs, buf, cap);
	if (error<0) then
  begin
		//return fz_rethrow(error, "cannot read xref section");
    result:=-11;
    exit;
  end;

 //* FIXME: do we overwrite free entries properly? */
	xrefstm := fz_dict_gets(trailer, 'XRefStm');
	if (xrefstm<>nil) then
	begin
		error := pdf_read_xref_sections(xref, fz_to_int(xrefstm), buf, cap);
		if (error<0) then
		begin
			fz_drop_obj(trailer);
			//return fz_rethrow(error, "cannot read /XRefStm xref section");
      result:=-1;
      exit;
		end;
	end;

	prev := fz_dict_gets(trailer, 'Prev');
	if (prev<>nil) then
	begin
		error := pdf_read_xref_sections(xref, fz_to_int(prev), buf, cap);
		if (error<=0)  then
		begin
		 fz_drop_obj(trailer);
		 //	return fz_rethrow(error, "cannot read /Prev xref section");
     result:=-1;
     exit;
		end;
  end;

	fz_drop_obj(trailer);
 //	return fz_okay;
 result:=1;
 exit;
end;



function pdf_parse_stm_obj(op:ppfz_obj_s; xref:ppdf_xref_s; f:pfz_stream_s; buf:pchar; cap:integer):integer;
var
	error:integer;
	tok:pdf_kind_e;
	len:integer;
begin
	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
  begin
		//return fz_rethrow(error, "cannot parse token in object stream");
    result:=-1;
    exit;
  end;

	case tok of
	PDF_TOK_OPEN_ARRAY:
    begin
	  	error := pdf_parse_array(op, xref, f, buf, cap);
	  	if (error<0) then
      begin
	   		//return fz_rethrow(error, "cannot parse object stream");
        result:=-1;
        exit;
      end;
	    end;
	PDF_TOK_OPEN_DICT:
    begin
		error := pdf_parse_dict(op, xref, f, buf, cap);
		if (error<0) then
    begin
			//return fz_rethrow(error, "cannot parse object stream");
       result:=-1;
        exit;
    end;
		end;
	PDF_TOK_NAME:
    op^ := fz_new_name(buf);
	PDF_TOK_REAL:
    op^ := fz_new_real(fz_atof(buf));
	PDF_TOK_STRING:
    op^ := fz_new_string(buf, len);
	PDF_TOK_TRUE:
    op^ := fz_new_bool(1);
	PDF_TOK_FALSE:
    op^ := fz_new_bool(0);
	PDF_TOK_NULL:
    op^ := fz_new_null();
	PDF_TOK_INT:
    op^ := fz_new_int(atoi(buf));
	else
    begin
     // return fz_throw("unknown token in object stream");
     result:=-1;
     exit;
	  end;
  end;
	result:=1;
end;

function pdf_parse_ind_obj(op:ppfz_obj_s;xref:ppdf_xref_s;f:pfz_stream_s; buf:pchar; cap:integer; onum:Pinteger; ogen :Pinteger; ostmofs:Pinteger) :integer;
var
  error,c1:integer;
	obj:pfz_obj_s;
	num, gen, stm_ofs:integer;
	 tok:pdf_kind_e;
	 len,	 a, b:integer;
   ss:string;
   C:CHAR;
   label  skip;
begin
  obj:=nil;
  num := 0;
  gen := 0 ;
	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
    
    exit;
  end;
	if (tok <> PDF_TOK_INT) then
  begin
	 result:= fz_throw('expected object number (%d %d R)', [num, gen]);

    exit;
  end;

  num:=atoi(buf) ;

	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);

    exit;
  end;

	if (tok <> PDF_TOK_INT) then
  begin
	  result:= fz_throw('expected generation number (%d %d R)', [num, gen]);
    exit;
  end;

	gen := atoi(buf);

	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);

    exit;
  end;
	if (tok <> PDF_TOK_OBJ) then
  begin
	 result:= fz_throw('expected "obj" keyword (%d %d R)', [num, gen]);
  //  result:=-1;
    exit;
  end;

	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
  begin
		result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
    exit;
  end;

	case tok of
  PDF_TOK_OPEN_ARRAY:
    begin
	   	error := pdf_parse_array(@obj, xref, f, buf, cap);
  		if (error<0) then
      begin
   			result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
        exit;
      end;
    end;
	PDF_TOK_OPEN_DICT:
    begin
	  	error := pdf_parse_dict(@obj, xref, f, buf, cap);
   		if (error<0) then
      begin
	  		result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
        exit;
      end;
    end;
	PDF_TOK_NAME:
    obj := fz_new_name(buf);
	PDF_TOK_REAL:
    obj := fz_new_real(fz_atof(buf));
	PDF_TOK_STRING:
    obj := fz_new_string(buf, len);
	PDF_TOK_TRUE:
    obj := fz_new_bool(1);
	PDF_TOK_FALSE:
    obj := fz_new_bool(0);
	PDF_TOK_NULL:
    obj := fz_new_null();

	PDF_TOK_INT:
    begin
		a := atoi(buf);
		error := pdf_lex(@tok, f, buf, cap, @len);
		if (error<0) then
    begin
			result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
      exit;
    end;
		if (tok = PDF_TOK_STREAM) or (tok = PDF_TOK_ENDOBJ) then
		begin
			obj := fz_new_int(a);
			goto skip;
		end;
		if (tok = PDF_TOK_INT) then
		begin

		  b := atoi(buf);
			error := pdf_lex(@tok, f, buf, cap, @len);
			if (error<0) then
      begin
				result:= fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
        exit;
      end;
			if (tok = PDF_TOK_R) then
			begin
				obj := fz_new_indirect(a, b, @xref);
				//break;
			end;
		end;
       result:=fz_throw('expected R keyword (%d %d R)', [num, gen]);
        exit;
	 //	return fz_throw("expected 'R' keyword (%d %d R)", num, gen);
   end;
	PDF_TOK_ENDOBJ:
    begin
		obj := fz_new_null();
		goto skip;
    end;
	else
    begin
	  	result:= fz_throw('syntax error in object (%d %d R)', [num, gen]);

      exit;
    end;
	end;

	error := pdf_lex(@tok, f, buf, cap, @len);
	if (error<0) then
	begin
		fz_drop_obj(obj);
		 result:=fz_rethrow(error, 'cannot parse indirect object (%d %d R)', [num, gen]);
      exit;
	end;

skip:
	if (tok = PDF_TOK_STREAM) then
	begin
		 c1 := fz_read_byte(f);

		while (c1 =ord(' ')) do
			c1 :=fz_read_byte(f);
      c:=chr(c1);
		if (c = #13) then    //\R
		begin
			c := chr(fz_peek_byte(f));

			if (c <> #10)  THEN          //\N
			 	fz_warn('line feed missing after stream begin marker (%d %d R)', [num, gen])

			else
			 //	fz_read_byte(file);
        fz_read_byte(f);
		end;
		stm_ofs := fz_tell(f); //fz_tell(file);
	end
	else if (tok = PDF_TOK_ENDOBJ) then
	begin
		stm_ofs := 0;
	end
	else
	begin
	 	fz_warn('expected "endobj" or "stream" keyword (%d %d R)', [num, gen]);
		stm_ofs := 0;
	end;

	 onum^ := num;
	 ogen^ := gen;
	 ostmofs^ :=stm_ofs;
	op^ := obj;
 //	return fz_okay;
   result:=1;
   exit;
end;

function pdf_open_xref(xref:ppdf_xref_s; const filename :pchar; password:pchar):integer;
var
	error:integer;
	f:pfz_stream_s;
  size:pfz_obj_s   ;
  i:integer;
 // xref:ppdf_xref_s  ;
begin
	f:= fz_open_file(filename);
	if (f=nil) then
  begin
		 result:= fz_throw('"cannot open file "%s": %s', [filename, strerror(errno)]);
    exit;
  end;
//  xref := fz_malloc(sizeof(pdf_xref_s));
  zeromemory(xref,sizeof(pdf_xref_s));
  xref.myfile:=fz_keep_stream(f);
 // xrefp^:=xref;
 // xrefp^:=xref;
  pdf_load_version(xref);
  pdf_read_start_xref(xref);
  pdf_read_trailer(xref, xref.scratch, sizeof(xref.scratch));

	size := fz_dict_gets(xref.trailer, 'Size');
	if (size=nil) then
  begin
		fz_throw('trailer missing Size entry');
    exit;
  end;
 pdf_resize_xref(xref, fz_to_int(size));
  error:=1;
error := pdf_read_xref_sections(xref, xref.startxref, xref.scratch, sizeof(xref.scratch));
	if (error<0) then
  BEGIN
	   fz_rethrow(error, 'cannot read xref');
    EXIT;
 END;



// error := pdf_open_xref_with_stream(xrefp, f, password);
	if (error<0) then
  begin
		 result:= fz_rethrow(error, 'cannot load document "%s"', [filename]);
    result:=-1;
    exit;
  end;


  //* broken pdfs where first object is not free */
	if (table_items(xref.table)[0].type1 <> ord('f')) then
  begin
	   result:= fz_throw('first object in xref is not free');

    exit;
  end;
	//* broken pdfs where object offsets are out of range */
 // fz_debug_xref(xref);
	for i := 0 to xref.len-1 do
	begin
		if (table_items(xref.table)[i].type1 =ord('n'))  then
			if ((table_items(xref.table)[i].ofs <= 0) or (table_items(xref.table)[i].ofs >= xref.file_size)) then
      begin
				 result:= fz_throw('object offset out of range: %d (%d 0 R)', [table_items(xref.table)[i].ofs, i]);
      //  OutputDebugString(pchar(inttostr(table_items(xref.table)[i].ofs)));
       // result:=-1;
        exit;
      end;
		if (table_items(xref.table)[i].type1 = ord('o')) then
			if ((table_items(xref.table)[i].ofs <= 0) or (table_items(xref.table)[i].ofs >= xref.len) or  (table_items(xref.table)[table_items(xref.table)[i].ofs].type1 <>ord('n'))) then
      begin
				 result:= fz_throw('invalid reference to an objstm that does not exist: %d (%d 0 R)', [table_items(xref.table)[i].ofs, i]);
        
        exit;
      end;
	end;

 // fz_close(f);
	result:=1;
  exit;
end;


FUNCTION pdf_read_new_trailer(xref:ppdf_xref_s; buf: pchar;cap:integer):INTEGER;
var
error:integer;
a,b,c:integer ;
begin
	error := pdf_parse_ind_obj(@xref.trailer, xref, xref.myfile, buf, cap, @a, @b, @c);
	if (error<0) then
  begin
     result:=fz_rethrow(error, 'cannot parse trailer (compressed)');
     exit;
		//return
  end;
	result:=1;
end;
procedure fz_debug_xref(xref:ppdf_xref_s);
var
i,j:integer;
s:string;
//mm:table_items;
begin
 s:= format('xref: total table len: %d/n', [xref.len]);
 //OutputDebugString(pchar(s));
// mm:=table_items(xref.table);
 for i:=0 to xref.len-1 do
 begin
 {if i>10 then
 exit;   }
   s:= format('table %d/n', [i]);
  // OutputDebugString(pchar(s));
   j:=0;
   if table_items(xref.table)[i].obj<>nil then
   j:=1;
   s:= format('ofs=:%d, gen=:%d, type=:%d,stm_ofs=:%d, has obj:=%d',[table_items(xref.table)[i].ofs, table_items(xref.table)[i].gen,table_items(xref.table)[i].type1, table_items(xref.table)[i].stm_ofs,j ]);

   //OutputDebugString(pchar(s));
 end;

end;
Function atan2(y : extended; x : extended): Extended;
Assembler;
asm
  fld [y]
  fld [x]
  fpatan
end;

(*
 * load xref tables from pdf
 *)

function
pdf_load_xref(xref:ppdf_xref_s; buf:pchar; bufsize:integer):fz_error;
var
	f:pfz_stream_s;
  size:pfz_obj_s   ;
  i:integer;
  error:fz_error;
begin

	error := pdf_load_version(xref);
	if (error<0) then
  begin
		result:= fz_rethrow(error,'cannot read version marker');
    exit;
  end;

	error := pdf_read_start_xref(xref);
	if (error<=0) then
  begin
		result:= fz_rethrow( error,'cannot read startxref');
    exit;
  end;

	error := pdf_read_trailer(xref, buf, bufsize);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot read trailer');
    exit;
  end;
	size := fz_dict_gets(xref^.trailer, 'Size');
	if (size=nil) then
  begin
		result:=fz_throw('trailer missing Size entry');
    exit;
  end;

	pdf_resize_xref(xref, fz_to_int(size));

	error := pdf_read_xref_sections(xref, xref^.startxref, buf, bufsize);
	if (error<0) then
  begin
		result:=fz_rethrow(error, 'cannot read xref');
    exit;
  end;

	//* broken pdfs where first object is not free */
	if (table_items(xref.table)[0].type1 <> ord('f'))  then
  begin
		result:= fz_throw('first object in xref is not free');
    exit;
  end;

	//* broken pdfs where object offsets are out of range */
	for i := 0 to xref^.len-1 do
	begin
		if (table_items(xref.table)[i].type1 = ord('n')) then
			if ((table_items(xref.table)[i].ofs <= 0) or (table_items(xref.table)[i].ofs >= xref.file_size)) then
      begin
				result:=fz_throw('object offset out of range: %d (%d 0 R)',[table_items(xref.table)[i].ofs, i]);
        exit;
      end;
		if (table_items(xref.table)[i].type1 = ord('o')) then
			if ((table_items(xref.table)[i].ofs <= 0) or (table_items(xref.table)[i].ofs >= xref.len) or  (table_items(xref.table)[table_items(xref.table)[i].ofs].type1 <>ord('n'))) then
      begin
				result:= fz_throw('invalid reference to an objstm that does not exist: %d (%d 0 R)', [table_items(xref.table)[i].ofs, i]);
        exit;
      end;
	end;

	result:= fz_okay;
end;

function pdf_open_xref_with_stream(xrefp:pppdf_xref_s; file1:pfz_stream_s; password:pchar):fz_error;
var
	xref:ppdf_xref_s;
	error:fz_error;
	encrypt, id:pfz_obj_s;
	dict, obj:pfz_obj_s;
	i, repaired :integer;
  okay:integer;
  hasroot, hasinfo:integer;
begin
  repaired := 0;
	//* install pdf specific callback */
	//fz_resolve_indirect = pdf_resolve_indirect;

	xref := fz_malloc(sizeof(pdf_xref_s));

	fillchar(xref^,  sizeof(pdf_xref_s),0);

	xref^.myfile := fz_keep_stream(file1);

	error := pdf_load_xref(xref, xref^.scratch, sizeof(xref^.scratch));
	if (error<0) then
	begin
		fz_catch(error, 'trying to repair');
		if (xref^.table<>nil) then
		begin
			fz_free(xref^.table);
			xref^.table := nil;
			xref^.len := 0;
		end;
		if (xref^.trailer<>nil) then
		begin
			fz_drop_obj(xref^.trailer);
			xref^.trailer := nil;
		end;
		error := pdf_repair_xref(xref, xref^.scratch, sizeof(xref^.scratch));
		if (error<0) then
		begin
			pdf_free_xref(xref);
			result:= fz_rethrow(error, 'cannot repair document');
      exit;
		end;
		repaired := 1;
	end;

	encrypt := fz_dict_gets(xref^.trailer, 'Encrypt');
	id := fz_dict_gets(xref^.trailer, 'ID');
	if (fz_is_dict(encrypt)) then
	begin
		error := pdf_new_crypt(@xref^.crypt, encrypt, id);
		if (error<0) then
		begin
			pdf_free_xref(xref);
			result:= fz_rethrow(error, 'cannot decrypt document');
      exit;
		end;
	end;

	if (pdf_needs_password(xref)<>0)  then
	begin
		//* Only care if we have a password */
		if (password<>nil) then
		begin
			okay := pdf_authenticate_password(xref, password);
			if (okay=0) then
			begin
				pdf_free_xref(xref);
				result:= fz_throw('invalid password');
        exit;
			end;
		end;
	end;

	if (repaired<>0) then
	begin

		error := pdf_repair_obj_stms(xref);
		if (error<0) then
		begin
			pdf_free_xref(xref);
			result:= fz_rethrow(error, 'cannot repair document');
      exit;
		end;
    if fz_dict_gets(xref^.trailer, 'Root') <>nil then
		hasroot :=1
    else
    hasroot :=0;
    if fz_dict_gets(xref^.trailer, 'Info') <>nil then
		hasinfo :=1
    else
    hasinfo :=0;

		for i := 1 to xref^.len-1 do
		begin
			if (table_items(xref^.table)[i].type1 = 0) or (table_items(xref^.table)[i].type1 =ord( 'f')) then
				continue;

			error := pdf_load_object(@dict, xref, i, 0);
			if (error<0) then
			begin
				fz_catch(error, 'ignoring broken object (%d 0 R)',[ i]);
				continue;
			end;

			if (hasroot=0) then
			begin
				obj := fz_dict_gets(dict, 'Type');
				if (fz_is_name(obj)) and (strcomp(fz_to_name(obj), 'Catalog')=0) then
				begin
					obj := fz_new_indirect(i, 0, xref);
					fz_dict_puts(xref^.trailer, 'Root', obj);
					fz_drop_obj(obj);
				end;
			end;

			if (hasinfo=0) then
			begin
				if (fz_dict_gets(dict, 'Creator')<>nil) or (fz_dict_gets(dict, 'Producer')<>nil) then
				begin
					obj := fz_new_indirect(i, 0, xref);
					fz_dict_puts(xref^.trailer, 'Info', obj);
					fz_drop_obj(obj);
				end;
			end;

			fz_drop_obj(dict);
		end;
	end;

	xrefp^ := xref;
	result:= fz_okay;
end;





procedure pdf_free_xref(xref:ppdf_xref_s);
var
	i:integer;
begin

 // pdf_debug_store(xref^.store);
	if (xref^.store<>nil) then
		pdf_free_store(xref^.store);

	if (xref^.table<>nil) then
	begin
		for i := 0 to xref^.len-1 do
		begin
			if (table_items(xref^.table)[i].obj<>nil) then
			begin
       // if i=6054 then
      //  OutputDebugString(pchar(inttostr(i)));
				fz_drop_obj(table_items(xref^.table)[i].obj);
				table_items(xref^.table)[i].obj := nil;
			end;
		end;
		fz_free(xref^.table);
	end;

	if (xref^.page_objs<>nil) then
	begin
		for i := 0 to xref^.page_len-1 do
			fz_drop_obj(fz_obj_s_items(xref^.page_objs)[i]);
		fz_free(xref^.page_objs);
	end;

	if (xref^.page_refs<>nil) then
	begin
		for i := 0 to xref^.page_len-1 do
			fz_drop_obj(fz_obj_s_items(xref^.page_refs)[i]);
		fz_free(xref^.page_refs);
	end;

	if (xref^.myfile<>nil) then
		fz_close(xref^.myfile);
	if (xref^.trailer<>nil) then
		fz_drop_obj(xref^.trailer);
	if (xref^.crypt<>nil) then
		pdf_free_crypt(xref^.crypt);

	fz_free(xref);
end;










end.
