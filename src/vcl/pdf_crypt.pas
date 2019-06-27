unit pdf_crypt;

interface
  uses  SysUtils,
  Math,digtypes,digcommtype,base_object_functions,base_error;
  function pdf_new_crypt(cryptp:pppdf_crypt_s;dict: pfz_obj_s; id:pfz_obj_s):integer;
  procedure pdf_crypt_obj_imp(crypt:ppdf_crypt_s;obj:pfz_obj_s; key:pbyte; keylen:integer);
  procedure pdf_free_crypt(crypt:ppdf_crypt_s);
  function pdf_parse_crypt_filter(var cf:pdf_crypt_filter_s;cf_obj:pfz_obj_s; name:pchar;defaultlength:integer):integer;
  procedure pdf_crypt_obj(crypt:ppdf_crypt_s; obj:pfz_obj_s; num:integer;gen:integer);
   function pdf_open_crypt(chain:pfz_stream_s; crypt:ppdf_crypt_s; num,gen:integer) :pfz_stream_s;
   function pdf_open_crypt_with_filter(chain:pfz_stream_s; crypt:ppdf_crypt_s; name:pchar; num, gen:integer):pfz_stream_s;
   function pdf_needs_password(xref:ppdf_xref_s):integer;
   function pdf_authenticate_password(xref:ppdf_xref_s; password:pchar):integer;
implementation

 uses DCPsha256,ohhcrypt_md5,ohhcrypt_arc4,ohhcrypt_aes,fz_filterss;


//function pdf_parse_crypt_filter(cf:pdf_crypt_filter; dict:pfz_obj_s; name:pchar; defaultlength:integer):integer;

//* * Create crypt object for decrypting strings and streams  * given the Encryption and ID objects.  */


function pdf_new_crypt(cryptp:pppdf_crypt_s;dict: pfz_obj_s; id:pfz_obj_s):integer;
var
	crypt:ppdf_crypt_s;
	error:integer;
	obj:pfz_obj_s;
begin
	crypt := fz_malloc(sizeof(pdf_crypt_s));
	  zeromemory(crypt,sizeof(pdf_crypt_s));
 //* Common to all security handlers (PDF 1.7 table 3.18) */

	obj := fz_dict_gets(dict, 'Filter');
	if (fz_is_name(obj)=false) then
	begin
		pdf_free_crypt(crypt);
	//	return fz_throw("unspecified encryption handler");
    result:=-1;
    exit;
	end;
	if (strcomp(fz_to_name(obj), pchar('Standard')) <>0)  then
	begin
		pdf_free_crypt(crypt);
	 //	return fz_throw("unknown encryption handler: '%s'", fz_to_name(obj));
    result:=-1;
    exit;
	end;

	crypt^.v := 0;
	obj := fz_dict_gets(dict, 'V');
	if (fz_is_int(obj)) then
		crypt^.v := fz_to_int(obj);
	if ((crypt^.v <>1) and (crypt^.v <> 2) and (crypt^.v <>4) and (crypt^.v <> 5)) then
	begin
		pdf_free_crypt(crypt);
		//return fz_throw("unknown encryption version");
    result:=-1;
    exit;
	end;

	crypt^.length := 40;
	if (crypt^.v = 2) or (crypt^.v = 4) then
	begin
		obj := fz_dict_gets(dict, 'Length');
		if (fz_is_int(obj)) then
			crypt^.length := fz_to_int(obj);

		//* work-around for pdf generators that assume length is in bytes */
		if (crypt^.length < 40) then
			crypt^.length := crypt^.length * 8;

		if (crypt^.length mod 8 <> 0)   then
		begin
			pdf_free_crypt(crypt);
		 //	return fz_throw("invalid encryption key length");
      result:=-1;
      exit;
		end;
		if (crypt^.length > 256)  then
		begin
			pdf_free_crypt(crypt);
		 //	return fz_throw("invalid encryption key length");
      result:=-1;
     exit;
		end;
	end;

	if (crypt^.v = 5) then
		crypt^.length := 256;

	if (crypt^.v = 1) or (crypt^.v = 2) then
	begin
		crypt^.stmf.method := PDF_CRYPT_RC4;
		crypt^.stmf.length := crypt^.length;

		crypt^.strf.method := PDF_CRYPT_RC4;
		crypt^.strf.length := crypt^.length;
	end;

	if (crypt^.v = 4) or (crypt^.v = 5) then
	begin
		crypt^.stmf.method := PDF_CRYPT_NONE;
		crypt^.stmf.length := crypt^.length;

		crypt^.strf.method := PDF_CRYPT_NONE;
		crypt^.strf.length := crypt^.length;

		obj := fz_dict_gets(dict, 'CF');
		if (fz_is_dict(obj)) then
		begin
			crypt^.cf := fz_keep_obj(obj);
		end
		else
		begin
			crypt^.cf := nil;
		end;

		obj := fz_dict_gets(dict, 'StmF');
		if (fz_is_name(obj)) then
		begin
			error := pdf_parse_crypt_filter(crypt^.stmf, crypt^.cf, fz_to_name(obj), crypt^.length);
			if (error<0) then
			begin
				pdf_free_crypt(crypt);
			 result:= fz_rethrow(error, 'cannot parse stream crypt filter (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);

        exit;
			end;
		end;

		obj := fz_dict_gets(dict, 'StrF');
		if (fz_is_name(obj))  then
		begin
			error := pdf_parse_crypt_filter(crypt^.strf, crypt^.cf, fz_to_name(obj), crypt^.length);
			if (error<0)   then
			begin
				pdf_free_crypt(crypt);
			  result:= fz_rethrow(error, 'cannot parse string crypt filter (%d %d R)', [fz_to_num(obj), fz_to_gen(obj)]);

        exit;
			end;
		end;

	 //* in crypt revision 4, the crypt filter determines the key length */
		if (crypt^.strf.method <> PDF_CRYPT_NONE) then
			crypt^.length := crypt^.stmf.length;
	end;

	//* Standard security handler (PDF 1.7 table 3.19) */

	obj := fz_dict_gets(dict, 'R');
	if (fz_is_int(obj)) then
		crypt^.r := fz_to_int(obj)
	else
	begin
		pdf_free_crypt(crypt);
		result:=fz_throw('encryption dictionary missing revision value');

        exit;
	end;

	obj := fz_dict_gets(dict, 'O');
	if (fz_is_string(obj)) and (fz_to_str_len(obj) = 32) then
		copymemory(@(crypt^.o[0]), pchar(fz_to_str_buf(obj)), 32)
 //* /O and /U are supposed to be 48 bytes long for revision 5, they're often longer, though */
	else
  if ((crypt^.r = 5) and (fz_is_string(obj)) and (fz_to_str_len(obj) >= 48) ) then
		copymemory(@(crypt^.o[0]), pchar(fz_to_str_buf(obj)), 48)
	else
	begin
		pdf_free_crypt(crypt);
		result:= fz_throw('encryption dictionary missing owner password');

        exit;
	end;

	obj := fz_dict_gets(dict, 'U');
	if (fz_is_string(obj)) and (fz_to_str_len(obj) = 32) then
		copymemory(@(crypt^.u[0]), pchar(fz_to_str_buf(obj)), 32)
	else if ((fz_is_string(obj)) and (fz_to_str_len(obj) >= 48) and  (crypt^.r = 5))  then
		copymemory(@(crypt^.u[0]), pchar(fz_to_str_buf(obj)), 48)
	else if (fz_is_string(obj)) and (fz_to_str_len(obj) < 32) then
	begin
	 	fz_warn('encryption password key too short (%d)', [fz_to_str_len(obj)]);
		copymemory(@(crypt^.u[0]), pchar(fz_to_str_buf(obj)), fz_to_str_len(obj));
	end
	else
	begin
		pdf_free_crypt(crypt);
	 result:= fz_throw('encryption dictionary missing user password');

        exit;
 end;

	obj := fz_dict_gets(dict, 'P');
	if (fz_is_int(obj)) then
		crypt^.p := fz_to_int(obj)
	else
	begin
		pdf_free_crypt(crypt);
		result:= fz_throw('encryption dictionary missing permissions value');
    exit;
	end;

	if (crypt^.r = 5) then
	begin
		obj := fz_dict_gets(dict, 'OE');
		if (NOT fz_is_string(obj)) or (fz_to_str_len(obj) <> 32) then
		begin
			pdf_free_crypt(crypt);
			result:= fz_throw('encryption dictionary missing owner encryption key');

        exit;
		end;
		copymemory(@(crypt^.oe[0]), pchar(fz_to_str_buf(obj)), 32);

		obj := fz_dict_gets(dict, 'UE');
		if (NOT fz_is_string(obj)) or (fz_to_str_len(obj) <> 32) then
		begin
			pdf_free_crypt(crypt);
			result:= fz_throw('encryption dictionary missing user encryption key');
      exit;
		end;
	 copymemory(@(crypt^.ue[0]), pchar(fz_to_str_buf(obj)), 32);
	end;

	crypt^.encrypt_metadata := 1;
	obj := fz_dict_gets(dict, 'EncryptMetadata');
	if (fz_is_bool(obj)) then
  begin
		crypt^.encrypt_metadata := fz_to_bool(obj);
  end;
	//* Extract file identifier string */

	if (fz_is_array(id)) and (fz_array_len(id) = 2) then
	begin
		obj := fz_array_get(id, 0);
		if (fz_is_string(obj)) then
			crypt^.id := fz_keep_obj(obj);
	end
	else
  begin
		result:=fz_warn('missing file identifier, may not be able to do decryption');

        exit;
   end;
	cryptp^ := crypt;
 //	return fz_okay;
  result:=1;
end;

procedure pdf_free_crypt(crypt:ppdf_crypt_S);
begin
	if (crypt^.id<>nil) then
     fz_drop_obj(crypt^.id);
	if (crypt^.cf<>nil ) then
     fz_drop_obj(crypt^.cf);
	fz_free(crypt);
end;

//*  * Parse a CF dictionary entry (PDF 1.7 table 3.22) */

function pdf_parse_crypt_filter(var cf:pdf_crypt_filter_s;cf_obj:pfz_obj_s; name:pchar;defaultlength:integer):integer;
var
	obj:pfz_obj_s;
	dict:pfz_obj_s ;
  is_identity,is_stdcf:integer;

begin
  if  (strcomp(name, 'Identity') = 0) then
     is_identity:=1
     else
     is_identity:=0;
  if (is_identity=0) and ((strcomp(name, 'StdCF') = 0)) then
	is_stdcf :=1
  else
      is_stdcf:=0;

	if (is_identity=0) and  (is_stdcf=0) then
	begin
	 result:= fz_throw('Crypt Filter not Identity or StdCF (%d %d R)', [fz_to_num(cf_obj), fz_to_gen(cf_obj)]);
   exit;
	end;
	cf.method := PDF_CRYPT_NONE;
	cf.length := defaultlength;

	if (cf_obj = NiL) then
	begin
     if  is_identity<>0 then
           cf.method := PDF_CRYPT_NONE
           else
            cf.method := PDF_CRYPT_RC4;
	 //	return fz_okay;
   result:=1;
   exit;
	end;

	dict := fz_dict_gets(cf_obj, name);
	if (fz_is_dict(dict)=false) then
	begin
	 result:= fz_throw('cannot parse crypt filter (%d %d R)', [fz_to_num(cf_obj), fz_to_gen(cf_obj)]);
   exit;
	end;
	obj := fz_dict_gets(dict, 'CFM');
	if (fz_is_name(obj)) then
	begin
		if (strcomp(fz_to_name(obj), pchar('None'))=0)  then
			cf.method := PDF_CRYPT_NONE
		else if (strcomp(fz_to_name(obj), pchar('V2'))=0)  then
			cf.method := PDF_CRYPT_RC4
		else if (strcomp(fz_to_name(obj), pchar('AESV2'))=0) then
			cf.method := PDF_CRYPT_AESV2
		else if (strcomp(fz_to_name(obj), pchar('AESV3'))=0)  then
			cf.method := PDF_CRYPT_AESV3
		else
      begin
		   result:=	fz_throw('unknown encryption method: %s',[ fz_to_name(obj)]);
       exit;
      end;
	end;

	obj := fz_dict_gets(dict, 'Length');
	if (fz_is_int(obj)) then
		cf.length := fz_to_int(obj);

	//* the length for crypt filters is supposed to be in bytes not bits */
	if (cf.length < 40) then
		cf.length := cf.length * 8;

	if ((cf.length mod 8) <> 0)  then
  begin
	    result:= fz_throw('invalid key length: %d', [cf.length]);
       exit;
  end;
   result:=1;
 //	return fz_okay;
end;

//*  * Compute an encryption key (PDF 1.7 algorithm 3.2)  */

const
 padding:array[0..31] of byte =(
	$28, $bf, $4e, $5e, $4e, $75, $8a, $41,
	$64, $00, $4e, $56, $ff, $fa, $01, $08,
	$2e, $2e, $00, $b6, $d0, $68, $3e, $80,
	$2f, $0c, $a9, $fe, $64, $53, $69, $7a
);

procedure pdf_compute_encryption_key(crypt:ppdf_crypt_s; password:array of byte; pwlen:integer; var key:array of byte) ;
var
  buf:array[0..31] of byte;
  p:longword;
  i,n:integer;
  md5:fz_md5;

   sp:pchar;
begin
	n := crypt^.length div 8;

	//* Step 1 - copy and pad password string */
	if (pwlen > 32) then
		pwlen := 32;
	copymemory(@buf[0], @password[0], pwlen);
	copymemory(pointer(cardinal(@buf[0])+ pwlen), @padding[0], 32 - pwlen);

	//* Step 2 - init md5 and pass value of step 1 */
	fz_md5_init(@md5);
	fz_md5_update(@md5, @buf, 32);

	//* Step 3 - pass O value */
	fz_md5_update(@md5, @crypt^.o, 32);

	//* Step 4 - pass P value as unsigned int, low-order byte first */
	p :=  crypt^.p;
	buf[0] := (p) and $FF;
	buf[1] := (p shr 8) and $FF;
	buf[2] := (p shr 16) and $FF;
	buf[3] := (p shr 24) and $FF;
	fz_md5_update(@md5, @buf, 4);

	//* Step 5 - pass first element of ID array */
  sp:=fz_to_str_buf(crypt^.id);

	fz_md5_update(@md5, pbyte(sp), fz_to_str_len(crypt^.id));

	//* Step 6 (revision 4 or greater) - if metadata is not encrypted pass 0xFFFFFFFF */
	if (crypt^.r >= 4) then
	begin
		if (crypt.encrypt_metadata<>0) then
		begin
			buf[0] := $FF;
			buf[1] := $FF;
			buf[2] := $FF;
			buf[3] := $FF;
			fz_md5_update(@md5, @buf, 4);
		end;
	end;

 //* Step 7 - finish the hash */
	fz_md5_final(@md5, @buf);

	//* Step 8 (revision 3 or greater) - do some voodoo 50 times */
	if (crypt.r >= 3)  THEN
	BEGIN
		for i := 0 TO 50-1 DO
		BEGIN
			fz_md5_init(@md5);
			fz_md5_update(@md5, @buf, n);
			fz_md5_final(@md5, @buf);
	  END;
	END;

//* Step 9 - the key is the first 'n' bytes of the result */
  COPYMEMORY(@key, @buf, n);

end;

{/*
 * Compute an encryption key (PDF 1.7 ExtensionLevel 3 algorithm 3.2a)
 */ }

procedure pdf_compute_encryption_key_r5(crypt:ppdf_crypt_s; password:array of byte;  pwlen:integer; ownerkey:integer; var validationkey :array of byte);
var
buffer:array[0..183] of byte;
mm1:array[0..32] of byte;
MM:array of byte;
//sha256:pfz_sha256_s;
DCPsha2561:TDCP_sha256;
//TDCP_rijndaeL1:TDCP_rijndael;
aes:fz_aes_s;

k:integer;
s:string;
p:pointer;
begin


	//* Step 2 - truncate UTF-8 password to 127 characters */

	if (pwlen > 127) then
		pwlen := 127;

	//* Step 3/4 - test password against owner/user key and compute encryption key */

	copymemory(@buffer, @password, pwlen);
	if (ownerkey<>0)  then
	begin
		copymemory(pointer(cardinal(@buffer) + pwlen), pointer(cardinal(@(crypt^.o)) + 32), 8);
		copymemory(pointer(cardinal(@buffer) + pwlen + 8), @(crypt^.u), 48);
	end
	else
		copymemory(pointer(cardinal(@buffer) + pwlen), pointer(cardinal(@(crypt^.u)) + 32), 8);

 //	fz_sha256_init(@sha256);
  DCPsha2561:=TDCP_sha256.Create(nil);
  DCPsha2561.Init;
  if ownerkey<>0 then
  k:=48
  else
  k:=0 ;
 //	fz_sha256_update(@sha256, @buffer, pwlen + 8 +k);

  DCPsha2561.Update(buffer,pwlen + 8 +k);

 //	fz_sha256_final(@sha256, validationkey);
 DCPsha2561.Final(validationkey);
 //* Step 3.5/4.5 - compute file encryption key from OE/UE */
	copymemory(pointer(cardinal(@buffer) + pwlen), pointer(cardinal(@(crypt^.u)) + 40), 8);


 //	fz_sha256_init(@sha256);
 //	fz_sha256_update(@sha256, @buffer, pwlen + 8);
 //	fz_sha256_final(@sha256, buffer);
  DCPsha2561.Init;
   DCPsha2561.Update(buffer,pwlen + 8 +k);
    DCPsha2561.Final(buffer);
   DCPsha2561.Free;

	// clear password buffer and use it as iv
  zeromemory(pointer(cardinal(@buffer) + 32),sizeof(buffer) - 32);
	aes_setkey_dec(@aes, @buffer, crypt^.length);

  zeromemory(@MM1,sizeof(MM1));

  if ownerkey<>0 then
  MM:= @crypt^.oe
  else
  MM:=@crypt^.ue;

	aes_crypt_cbc(@aes, AES_DECRYPT, 32, mm1, @mm[0], @crypt^.key);
end;

{/*
 * Computing the user password (PDF 1.7 algorithm 3.4 and 3.5)
 * Also save the generated key for decrypting objects and streams in crypt->key.
 */  }

procedure pdf_compute_user_password(crypt:ppdf_crypt_s; password:array of byte; pwlen:integer; var output:array of byte);
var
arc4:fz_arc4_s ;
xxor:array [0..31] of byte;
digest:array [0..15] of byte;
md5:fz_md5 ;
  p:pchar;
	i, x, n:integer;
begin
	if (crypt^.r = 2) then
	begin
		pdf_compute_encryption_key(crypt, password, pwlen,crypt^.key);
		fz_arc4_init(@arc4, @(crypt^.key), crypt^.length div 8);
		fz_arc4_encrypt(@arc4, output, padding, 32);
	end;

	if (crypt^.r = 3) or (crypt^.r = 4)  then
  begin
		n := crypt^.length div 8;

		pdf_compute_encryption_key(crypt, password, pwlen, crypt^.key);

		fz_md5_init(@md5);
		fz_md5_update(@md5, @padding, 32);
    p:=fz_to_str_buf(crypt^.id);
		fz_md5_update(@md5, pbyte(p), fz_to_str_len(crypt^.id));
		fz_md5_final(@md5, @digest);

		fz_arc4_init(@arc4, @(crypt^.key), n);
		fz_arc4_encrypt(@arc4, output, digest, 16);

		for x := 1 to 19 do
		begin
			for i := 0 to n-1 do
      				xxor[i] := crypt^.key[i] xor x;
			fz_arc4_init(@arc4, @xxor, n);
			fz_arc4_encrypt(@arc4, output, output, 16);
		end  ;

		copymemory(@output[16], @padding, 16);
	end;

	if (crypt^.r = 5) then
	begin
 // procedure pdf_compute_encryption_key_r5(crypt:ppdf_crypt_s; password:array of pbyte;  pwlen:integer; ownerkey:integer; var validationkey :array of pbyte);
		pdf_compute_encryption_key_r5(crypt, password, pwlen, 0, output);
	end;
end;

{/*
 * Authenticating the user password (PDF 1.7 algorithm 3.6
 * and ExtensionLevel 3 algorithm 3.11)
 * This also has the side effect of saving a key generated
 * from the password for decrypting objects and streams.
 */   }




function pdf_authenticate_user_password(crypt:ppdf_crypt_s; password:pbyte;  pwlen:integer):integer;
var
output:array[0..31] of byte;
begin
	pdf_compute_user_password(crypt, password^, pwlen, output);
	if (crypt^.r = 2) or (crypt^.r = 5) then
  begin
     result:=0;
     if memcmp(@output, @(crypt^.u), 32) = 0 then
     		result:=1
        else
        result:=0;
        exit;

  end;
	if (crypt^.r = 3) or (crypt^.r= 4) then
     result:=0;
		if memcmp(@output, @(crypt^.u), 16) = 0 then
    result:=1
        else
        result:=0;
        exit;
end;

{*
 * Authenticating the owner password (PDF 1.7 algorithm 3.7
 * and ExtensionLevel 3 algorithm 3.12)
 * Generates the user password from the owner password
 * and calls pdf_authenticate_user_password.
 *}

function pdf_authenticate_owner_password(crypt:ppdf_crypt_s; ownerpass:pbyte; pwlen:integer):integer;

var
pwbuf,key,xxor,userpass:array[0..31] of byte;

i, n, x:integer;
md5:pfz_md5_s ;
arc4:pfz_arc4_s ;
begin
	if (crypt^.r = 5) then
	begin
		//* PDF 1.7 ExtensionLevel 3 algorithm 3.12 */

		pdf_compute_encryption_key_r5(crypt, ownerpass^, pwlen, 1, key);
    if memcmp(@key, @crypt^.o, 32)=0 then
    result:=1
    else
    result:=0;

		exit;
	end;

	n := crypt^.length div 8;

	//* Step 1 -- steps 1 to 4 of PDF 1.7 algorithm 3.3 */

	//* copy and pad password string */
	if (pwlen > 32) then
		pwlen := 32;
	copymemory(@pwbuf, ownerpass, pwlen);
	copymemory(@pwbuf[pwlen], @padding, 32 - pwlen);

	//* take md5 hash of padded password */
	fz_md5_init(@md5);
	fz_md5_update(@md5, @pwbuf, 32);
	fz_md5_final(@md5, @key);

	//* do some voodoo 50 times (Revision 3 or greater) */
	if (crypt^.r >= 3)   then
	begin
		for i := 0 to 49 do
		begin
			fz_md5_init(@md5);
			fz_md5_update(@md5, @key, 16);
			fz_md5_final(@md5, @key);
		end;
	end;

 //* Step 2 (Revision 2) */
	if (crypt^.r = 2)  then
	begin
		fz_arc4_init(@arc4, @key, n);
		fz_arc4_encrypt(@arc4, userpass, crypt^.o, 32);
	end;

	//* Step 2 (Revision 3 or greater) */
	if (crypt^.r >= 3) then
	begin
		copymemory(@userpass, @(crypt^.o), 32);
		for x := 0 to 19 do
		begin
			for i := 0 to n-1 do
				xxor[i] := key[i] xor (19 - x);
			fz_arc4_init(@arc4, @xxor, n);
			fz_arc4_encrypt(@arc4, userpass, userpass, 32);
		end;
	end;

	result:= pdf_authenticate_user_password(crypt, @userpass, 32);
end;

function pdf_authenticate_password(xref:ppdf_xref_s; password:pchar):integer;
var
pp:pbyte;
begin
  pp:=PByte(password);
	if (xref.crypt<>nil) then
	begin
		if (pdf_authenticate_user_password(xref^.crypt, pp, strlen(password))>0) then
    begin
      result:=1;
      exit;
		//	return 1;
    end;
		if (pdf_authenticate_owner_password(xref^.crypt, pp, strlen(password))>0) then
    begin
			result:=1;
      exit;
    end;
		result:=0;
    exit;
	end;
	result:=1;
end;

function pdf_needs_password(xref:ppdf_xref_s):integer;
begin
	if (xref^.crypt=nil) then
  begin
		result:=0;
    exit;
  end;
	if (pdf_authenticate_password(xref, '')<>0)then
	begin
		result:=0;
    exit;
  end;
	result:=1;
end;

function pdf_has_permission(xref:ppdf_xref_s; p:integer):integer;
var
i:integer;
begin
	if (xref.crypt=nil) then
  begin
		result:= 1;
    exit;
  end;

	 i:=xref.crypt^.p and p;
   result:=i;
end;

function pdf_get_crypt_key(xref:ppdf_xref_s) :pbyte;
begin
	if (xref^.crypt<>nil)  then
  begin
		result:=@(xref.crypt.key);
    exit;
  end;
	result:=nil;
end;

function  pdf_get_crypt_revision(xref:ppdf_xref_s):integer;
begin
	if (xref^.crypt<>nil)  then
  begin
		result:= xref^.crypt^.v;
    exit;
  end;
	result:= 0;
end;

function  pdf_get_crypt_method(xref:ppdf_xref_s):pchar;
begin
	if (xref^.crypt<>nil)  then
	begin
		case xref^.crypt^.strf.method of

		PDF_CRYPT_NONE:
       begin
        result:='None';
        exit;
       end;
		PDF_CRYPT_RC4:
       begin
        result:='RC4';
        exit;
       end;
   	PDF_CRYPT_AESV2:
       begin
        result:='AES';
        exit;
       end;
		PDF_CRYPT_AESV3:
       begin
        result:='AES';
        exit;
       end;
		PDF_CRYPT_UNKNOWN:
       begin
        result:='Unknown';
        exit;
       end;
		end;
    
	end;
  result:= 'None';
end;

function  pdf_get_crypt_length(xref:pdf_xref_s):integer;
begin
		if (xref.crypt<>nil)  then
		result:=xref.crypt.length
    else
    result:=0;

end;

{/*
 * PDF 1.7 algorithm 3.1 and ExtensionLevel 3 algorithm 3.1a
 *
 * Using the global encryption key that was generated from the
 * password, create a new key that is used to decrypt indivual
 * objects and streams. This key is based on the object and
 * generation numbers.
 */ }

function pdf_compute_object_key(crypt:ppdf_crypt_s; cf:ppdf_crypt_filter_s;  num, gen:integer; key:pbyte):integer;
var
md5:fz_md5;
messages :array[0..4] of byte;
begin


	if (cf.method = PDF_CRYPT_AESV3) then
	begin
		copymemory(key, @(crypt^.key), crypt^.length div  8);
		result:=crypt^.length div 8;
    exit;
	end;

	fz_md5_init(@md5);
	fz_md5_update(@md5, @crypt^.key, crypt^.length div 8);
	messages[0] := (num) and $FF;
	messages[1] := (num shr 8) and $FF;
	messages[2] := (num shr 16) and $FF;
	messages[3] := (gen) and $FF;
	messages[4] := (gen shr 8) and $FF;
	fz_md5_update(@md5, @messages, 5);

	if (cf^.method = PDF_CRYPT_AESV2) then
  begin
		fz_md5_update(@md5, pbyte(pchar('sAlT')), 4);
  end;

	fz_md5_final(@md5, key);

	if (crypt^.length div 8 + 5 > 16) then
  begin
		result:= 16;
    exit;
  end;
	result:= crypt^.length div 8 + 5;
end;

{/*
 * PDF 1.7 algorithm 3.1 and ExtensionLevel 3 algorithm 3.1a
 *
 * Decrypt all strings in obj modifying the data in-place.
 * Recurse through arrays and dictionaries, but do not follow
 * indirect references.
 */   }

procedure pdf_crypt_obj_imp(crypt:ppdf_crypt_s;  obj:pfz_obj_s; key:pbyte;keylen:integer);
var
	s:pbyte;
  s1:pbyte;
  p:pchar;
	i, n:integer;
  ss:string;
  arc4:fz_arc4_s ;
  iv:array[0..15] of byte; //				unsigned char [16];
	aes:		fz_aes_s ;

begin
	if (fz_is_indirect(obj))  then
  exit;


	if (fz_is_string(obj))  then
	begin
    p:= fz_to_str_buf(obj);
		s:=pbyte(p);
		n := fz_to_str_len(obj);

		if (crypt^.strf.method = PDF_CRYPT_RC4) then
		begin

			fz_arc4_init(@arc4, key, keylen);
			fz_arc4_encrypt(@arc4, s^, s^, n);

		end;

		if (crypt^.strf.method = PDF_CRYPT_AESV2) or (crypt^.strf.method = PDF_CRYPT_AESV3)  then
		begin
			if ((n and 15)<>0) or (n < 32) then
				fz_warn('invalid string length for aes encryption')

			else
			begin

				copymemory(@iv, s, 16);
				aes_setkey_dec(@aes, key, keylen * 8);
        s1:= pointer(cardinal(s)+16);
				aes_crypt_cbc(@aes, AES_DECRYPT, n - 16, iv,s1 , s);



			 //* delete space used for iv and padding bytes at end */
        s1:= pointer(cardinal(s)+n-17);
				if (s1^ < 1) or (s1^ > 16) then
             	fz_warn('aes padding out of range')
				else
					fz_set_str_len(obj, n - 16 - s^);
			end;
		end;
	end

	else if (fz_is_array(obj)) then
	begin
		n := fz_array_len(obj);
		for i := 0 to n-1 do
		begin
			pdf_crypt_obj_imp(crypt, fz_array_get(obj, i), key, keylen);
		end;
	end

	else if (fz_is_dict(obj)) then
	begin
		n := fz_dict_len(obj);
		for i := 0 to n-1 do
		begin
			pdf_crypt_obj_imp(crypt, fz_dict_get_val(obj, i), key, keylen);

		end;
	end;
end;

procedure pdf_crypt_obj(crypt:ppdf_crypt_s; obj:pfz_obj_s; num:integer;gen:integer);
var
key :array[0..31] of byte ;
len:integer;
d:ppdf_crypt_filter_s;
begin
//function pdf_compute_object_key(crypt:ppdf_crypt_s; cf:ppdf_crypt_filter_s;  num, gen:integer; var key:pbyte):integer;
   d:=@(crypt^.strf);
	len := pdf_compute_object_key(crypt, d, num, gen, @key);

	pdf_crypt_obj_imp(crypt, obj, @key, len);
end;

{/*
 * PDF 1.7 algorithm 3.1 and ExtensionLevel 3 algorithm 3.1a
 *
 * Create filter suitable for de/encrypting a stream.
 */     }
function pdf_open_crypt_imp(chain:pfz_stream_s; crypt:ppdf_crypt_s;stmf:ppdf_crypt_filter_s; num:integer;gen:integer):pfz_stream_s;
var
	 key:array[0..31] of byte;
	 len:integer;
begin
	len := pdf_compute_object_key(crypt, stmf, num, gen, @key);

	if (stmf^.method = PDF_CRYPT_RC4)  then
  begin
		result:= fz_open_arc4(chain, @key, len);
    exit;
  end;
	if (stmf^.method = PDF_CRYPT_AESV2) or (stmf^.method = PDF_CRYPT_AESV3) then
  begin
		result:= fz_open_aesd(chain, @key, len);
    exit;
  end;
	result:=fz_open_copy(chain);
end;

function pdf_open_crypt(chain:pfz_stream_s; crypt:ppdf_crypt_s; num,gen:integer) :pfz_stream_s;
begin
	result:=pdf_open_crypt_imp(chain, crypt, @crypt^.stmf, num, gen);
end;

function pdf_open_crypt_with_filter(chain:pfz_stream_s; crypt:ppdf_crypt_s; name:pchar; num, gen:integer):pfz_stream_s;
var
error:integer;
cf:   	pdf_crypt_filter_s;
begin

	if strcomp(name, 'Identity')<>0 then
	begin
		error := pdf_parse_crypt_filter(cf, crypt^.cf, name, crypt^.length);
		if (error<0) then
    begin
			//fz_catch(error, "cannot parse crypt filter (%d %d R)", num, gen);
    end
		else
			result:=pdf_open_crypt_imp(chain, crypt, @cf, num, gen);
	end;
	result:= chain;
end;

procedure pdf_debug_crypt(crypt:ppdf_crypt_s);
var
i:integer;
begin
//	printf("crypt {\n");

//	printf("\tv=%d length=%d\n", crypt->v, crypt->length);
//	printf("\tstmf method=%d length=%d\n", crypt->stmf.method, crypt->stmf.length);
//	printf("\tstrf method=%d length=%d\n", crypt->strf.method, crypt->strf.length);
//	printf("\tr=%d\n", crypt->r);

//	printf("\to=<");
//	for (i = 0; i < 32; i++)
//		printf("%02X", crypt->o[i]);
//	printf(">\n");

//	printf("\tu=<");
//	for (i = 0; i < 32; i++)
//		printf("%02X", crypt->u[i]);
//	printf(">\n");

//	printf("}\n");
//}
 end;

end.

