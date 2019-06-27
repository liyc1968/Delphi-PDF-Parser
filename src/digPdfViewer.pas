unit digPdfViewer;

interface
 uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,digcommtype,digtypes,base_object_functions,fz_outline,fz_pdf_page,dev_listss,base_error,freetype;
const
MINRES= 54 ;
MAXRES= 300 ;

ARROW=0;
HAND=1;
WAIT=2;

type
  TdigPdfViewer = class(Tobject)
  private
    { Private declarations }

    procedure clearAll;

  public
    { Public declarations }
    pdf_xref:pdf_xref_s;
    myxref:ppdf_xref_s;
    out_line:ppdf_outline_s;
    title:widestring;
    Subject:widestring;
    Producer:widestring;
    author:widestring;
    CreationDate:widestring;
    ModDate:widestring;
    Creator:widestring;
    Keywords:widestring;
    pagecount:integer;
    gopage:integer;
	  cache:pfz_glyph_cache_s;

	//* current view params */
    resolution:integer;
	  rotate:integer;
	  image:pfz_pixmap_s;
	  grayscale:integer;

	//* current page params */
	  pageno:integer;
	  page_bbox:fz_rect;
	  page_rotate:single;
	  page_list:pfz_display_list_s;
	  page_text:pfz_text_span_s;
	  page_links:ppdf_link_s;

	//* snapback history */
	 hist:array[0..256] of integer;
	 histlen:integer;
	 marks:array[0..9] of integer;

	//* window system sizes */
	 winw, winh:integer;
	 scrw, scrh:integer;
	 shrinkwrap:integer;

	//* event handling state */
	 number:array[0..255] of char;
	 numberlen:integer;

	 ispanning:integer;
	 panx, pany:integer;

	 iscopying:integer;
	 selx, sely:integer;
	(* TODO - While sely keeps track of the relative change in
	 * cursor position between two ticks/events, beyondy shall keep
	 * track of the relative change in cursor position from the
	 * point where the user hits a scrolling limit. This is ugly.
	 * Used in pdfapp.c:pdfapp_onmouse.
	 *)
	 beyondy:integer;
	 selr:fz_bbox_s;

	//* search state */
	 isediting:integer;
	 search:array[0..512] of char;
	 hit:integer;
	 hitlen:integer;

	//* client context storage */
	 userdata:pointer;
   stext:string;
   ws:widestring;
    Constructor Create();
    Destructor Destroy;
    function loadfromstream(pdfstream:tstream):boolean;
    function openfile1(filename: string): integer;
    procedure parepdfb(reload:integer);
    procedure pdfapp_showpage(loadpage, drawpage, repaint:integer)  ;
    function pdfapp_viewctm():fz_matrix;
    procedure pdfapp_panview(newx, newy:integer);
    procedure pdfapp_loadpage_pdf();
    FUNCTION showtext(xref:ppdf_xref_S;  pagenum:integer):integer;
    function openfile2(filename: string;pageno:integer): integer;
    function openfile3(filename: string;outputdirectory:string): integer;
    function openfile4(filename: string;outputfile:string;pagenum: integer=1): integer;

  end;

implementation
uses FZ_mystreams,pdf_crypt,draw_glyphss,dev_textss,fz_pdf_linkss,fz_dev_null,fz_pixmapss,
res_colorspace,draw_devicess,pdf_interprets,fz_pdf_store,fz_textx,pdf_extracto,mypdfstream;


{ TdigPdfViewer }



procedure TdigPdfViewer.clearAll;
begin
 exit;
end;

constructor TdigPdfViewer.Create;
begin
  inherited;
  // init_FreeType2 ;
 // if not init_FreeType2 then
 //   SHOWMESSAGE('Error initializing FreeType2 Library');
     myxref:=nil;
      out_line:=nil;
end;

destructor TdigPdfViewer.Destroy;
begin
   
  inherited;
   
  //quit_FreeType2;
end;



function TdigPdfViewer.loadfromstream(pdfstream: tstream): boolean;
var
  size:pfz_obj_s   ;
  error:integer;
  pdf_xref:ppdf_xref_s;
  I:INTEGER;
begin
result:=false;
clearAll;


pdf_load_version(@pdf_xref);
pdf_read_start_xref(@pdf_xref);
pdf_read_trailer(@pdf_xref, pdf_xref.scratch, sizeof(pdf_xref.scratch));
	size := fz_dict_gets(pdf_xref.trailer, 'Size');
	if (size=nil) then
  begin
		//return fz_throw("trailer missing Size entry");
    exit;
  end;
 pdf_resize_xref(@pdf_xref, fz_to_int(size));

//error := pdf_read_xref_sections(pdf_xref, pdf_xref.startxref, pdf_xref.scratch, sizeof(pdf_xref.scratch));
//	if (error<=0) THEN
//  BEGIN
	 //	return fz_rethrow(error, "cannot read xref");
//    EXIT;
// END;

end;






function TdigPdfViewer.openfile1(filename: string): integer;
var
	error:fz_error;
	f:pfz_stream_s;
	password:pchar;
	obj:pfz_obj_s;
	info:pfz_obj_s;
  okay:integer;
  ppp:pchar;
  PPO:PWIDECHAR;
  I:INTEGER;
begin
	(*
	 * Open PDF and load xref table
	 *)

  f:= fz_open_file(pchar(filename));
	if (f=nil) then
  begin
		//return fz_throw("cannot open file '%s': %s", filename, strerror(errno));
    result:=-1;
    exit;
  end;
	error := pdf_open_xref_with_stream( @myxref, f, nil);
	if (error<0) then
  begin
	  showmessage('sdf');
    result:=-1;
  end;
 	fz_close(f);


	(*
	 * Handle encrypted PDF files
	 *)

	if (pdf_needs_password(myxref)<>0)   then
	begin
		okay := pdf_authenticate_password(myxref, password);
		while (okay=0) do
		begin
			password :=pchar( InputBox('qw','asdf','123'));
			if (password=nil) then
				exit;
			okay := pdf_authenticate_password(myxref, password);
			if (okay=0) then
				showmessage('Invalid password.');
		end;
 end;

	(*
	 * Load meta information
	 *)

// 	out_line:= pdf_load_outline(myxref);




	info := fz_dict_gets(myxref^.trailer, 'Info');


	if (info<>nil) then
	begin
		obj := fz_dict_gets(info, 'Title');
		if (obj<>nil)then
    begin
        ppp:=pdf_to_utf8(obj);
        TITLE:=getwidestr(ppp);

         fz_free(ppp);
      //  fz_free(obj);

    end;
    	obj := fz_dict_gets(info, 'Subject');
		if (obj<>nil)then
    begin
        ppp:=pdf_to_utf8(obj);
   			Subject:=getwidestr(ppp);
         fz_free(ppp);
   		 // fz_free(obj);
    end;
     	obj := fz_dict_gets(info, 'Producer');
     if (obj<>nil)then
     begin
        ppp:=pdf_to_utf8(obj);
   			Producer:=getwidestr(ppp);
         fz_free(ppp);
   		//	Producer:= pdf_to_utf8(obj);
     //   fz_free(obj);
     end;
      	obj := fz_dict_gets(info, 'Author');
     if (obj<>nil)then
     begin
         ppp:=pdf_to_utf8(obj);
   			Author:=getwidestr(ppp);
   			 fz_free(ppp);
     //   fz_free(obj);
     end;
     	obj := fz_dict_gets(info, 'CreationDate');
     if (obj<>nil)then
     begin
         ppp:=pdf_to_utf8(obj);
   			CreationDate:=getwidestr(ppp);
   		  fz_free(ppp);
      //  fz_free(obj);
     end;

     	obj := fz_dict_gets(info, 'ModDate');
     if (obj<>nil)then
     begin
          ppp:=pdf_to_utf8(obj);
   			ModDate:=getwidestr(ppp);
   		  fz_free(ppp);
      //  fz_free(obj);
     end;

     	obj := fz_dict_gets(info, 'Creator');
     if (obj<>nil)then
     begin
            ppp:=pdf_to_utf8(obj);
   				Creator:=getwidestr(ppp);
   		     fz_free(ppp);
      //  fz_free(obj);
     end;

      	obj := fz_dict_gets(info, 'Keywords');
     if (obj<>nil)then
     begin
              ppp:=pdf_to_utf8(obj);
   				 Keywords:=getwidestr(ppp);
   		   fz_free(ppp);
      //  fz_free(obj);
     end;
    // fz_free(info);
	end;


 result:=pdf_load_page_tree(myxref);

 if (error<0) then
		showmessage('cannot load page tree');
 pagecount:=pdf_count_pages(myxref);
 ws:='';
//  FOR I:=1 TO pagecount DO
//  showtext(myxref,I);             //

 // showtext(myxref,gopage);
 pdf_free_xref(myxref);
 //quit_FreeType2;
 exit;
 pdf_free_xref(myxref);
// fz_close(f);

end;


function TdigPdfViewer.openfile2(filename: string;pageno:integer): integer;
var
	error:fz_error;
	f:pfz_stream_s;
	password:pchar;
	obj:pfz_obj_s;
	info:pfz_obj_s;
  okay:integer;
  ppp:pchar;
  PPO:PWIDECHAR;
  I:INTEGER;
begin
	(*
	 * Open PDF and load xref table
	 *)
   ws:='';
  for i:=1 to pageno do
  begin
  f:= fz_open_file(pchar(filename));
	if (f=nil) then
  begin
		//return fz_throw("cannot open file '%s': %s", filename, strerror(errno));
    result:=-1;
    exit;
  end;
	error := pdf_open_xref_with_stream( @myxref, f, nil);
	if (error<0) then
  begin
	  showmessage('error');
    result:=-1;
  end;
 	fz_close(f);


	(*
	 * Handle encrypted PDF files
	 *)

	if (pdf_needs_password(myxref)<>0)   then
	begin
		okay := pdf_authenticate_password(myxref, password);
		while (okay=0) do
		begin
			password :=pchar( InputBox('qw','asdf','123'));
			if (password=nil) then
				exit;
			okay := pdf_authenticate_password(myxref, password);
			if (okay=0) then
				showmessage('Invalid password.');
		end;
 end;

	(*
	 * Load meta information
	 *)

  //out_line:= pdf_load_outline(myxref);







 error:=pdf_load_page_tree(myxref);

 if (error<0) then
		showmessage('cannot load page tree');
 pagecount:=pdf_count_pages(myxref);

 // FOR I:=1 TO pagecount DO
   showtext(myxref,I);             //

 // showtext(myxref,gopage);
 pdf_free_xref(myxref);
 //quit_FreeType2;
// exit;

end;
// fz_close(f);

end;



procedure TdigPdfViewer.parepdfb(reload:integer);
begin
cache := fz_new_glyph_cache();

if (pageno < 1) then
		pageno := 1;
	if (pageno > pagecount) then
		pageno :=pagecount;
	if (resolution < MINRES)  then
		resolution := MINRES;
	if (resolution > MAXRES) then
		resolution := MAXRES;

	if (reload=0) then
	begin
		shrinkwrap := 1;
		rotate := 0;
		panx := 0;
		pany := 0;
	end;

	pdfapp_showpage( 1, 1, 1);
end;

procedure TdigPdfViewer.pdfapp_showpage(loadpage, drawpage, repaint:integer);
var
	buf:array[0..255] of char;
	idev:pfz_device_s;
	tdev:pfz_device_s;
	colorspace:pfz_colorspace_s;
	ctm:fz_matrix;
	bbox:fz_bbox;
  w,h:integer;
begin
	//wincursor(app, WAIT);

	if (loadpage<>0) then
	begin
		if (page_list<>nil) then
			fz_free_display_list(page_list);
		if (page_text<>nil) then
			fz_free_text_span(page_text);
		if (page_links<>nil) then
			pdf_free_link(page_links);

   if (MYxref<>NIL) THEN
			pdfapp_loadpage_pdf();
		//* Zero search hit position */
		hit := -1;
		hitlen := 0;

		//* Extract text */
		page_text := fz_new_text_span();
		tdev := fz_new_text_device(page_text);
		fz_execute_display_list(page_list, tdev, fz_identity, fz_infinite_bbox);
		fz_free_device(tdev);
	end;

	if (drawpage<>0) then
	BEGIN
		//wintitle(app, buf);

		ctm := pdfapp_viewctm();
		bbox := fz_round_rect(fz_transform_rect(ctm, page_bbox));

		//* Draw */
		if (image<>NIL) then
			fz_drop_pixmap(image);
		if (grayscale<>0) then
			colorspace := get_fz_device_gray
		else
			colorspace := get_fz_device_bgr;

		image := fz_new_pixmap_with_rect(colorspace, bbox);
		fz_clear_pixmap_with_color(image, 255);
		idev := fz_new_draw_device(cache, image);
		fz_execute_display_list(page_list, idev, ctm, bbox);
		fz_free_device(idev);

	END;

	if (repaint<>0) then
	begin
		pdfapp_panview( panx, pany);

		if (shrinkwrap<>0) then
		begin
			w := image^.w;
			h := image^.h;
			if (winw = w) then
				panx := 0;
			if (winh = h) then
				pany := 0;
			if (w > scrw * 90 / 100) then
				w := scrw * 90 div 100;
			if (h > scrh * 90 / 100)  then
				h := scrh * 90 div 100;
		 //	if (w <> winw) or (h <> winh) then
		//		winresize( w, h);
		end;

		//winrepaint(app);

	//	wincursor(app, ARROW);
	end;

 //	fz_flush_warnings();
end;

function TdigPdfViewer.pdfapp_viewctm():fz_matrix;
var
	ctm:fz_matrix;
begin
	ctm := fz_identity;
	ctm := fz_concat(ctm, fz_translate(0, -page_bbox.y1));
	if (myxref<>nil) then
		ctm := fz_concat(ctm, fz_scale(resolution/72.0, -resolution/72.0))
	else
		ctm := fz_concat(ctm, fz_scale(resolution/96.0, resolution/96.0));
	ctm := fz_concat(ctm, fz_rotate(rotate + page_rotate));
	result:= ctm;
end;

procedure TdigPdfViewer.pdfapp_panview(newx, newy:integer);
begin
	if (newx > 0) then
		newx := 0;
	if (newy > 0) then
		newy := 0;

	if (newx + image^.w < winw) then
		newx := winw - image^.w;
	if (newy + image^.h < winh) then
		newy := winh - image^.h;

	if (winw >= image^.w) then
		newx := (winw - image^.w) div 2;
	if (winh >= image^.h) then
		newy := (winh - image^.h) div 2;

 //	if (newx <> panx) or (newy <> pany) then
 //		winrepaint();

	panx := newx;
	pany := newy;
end;


procedure TdigPdfViewer.pdfapp_loadpage_pdf();
var
	page:ppdf_page_s;
	error:integer;
	mdev:pfz_device_s;
begin
	error := pdf_load_page(@page, myxref, pageno - 1);
	if (error<0) then
	  showmessage('	pdfapp_error(app, error)');;

	page_bbox := page^.mediabox;
	page_rotate := page^.rotate;
	page_links := page^.links;
	page^.links := nil;

	//* Create display list */
	page_list := fz_new_display_list();
	mdev := fz_new_list_device(page_list);
	error := pdf_run_page(myxref, page, mdev, fz_identity);
	if (error<0) then
	begin
		error := fz_rethrow(error, 'cannot draw page %d in "%s"', [pageno, 'doctitle']);
    exit;
		//pdfapp_error(app, error);
	end;
	fz_free_device(mdev);

	pdf_free_page(page);

	pdf_age_store(myxref^.store, 3);
end;




function gettexttt(span:pfz_text_span_s):widestring;
var
c, n, k, i:integer;
buf:array[0..9] of char;
begin
  result:='';
  result:=fz_span_to_wchar(span,pchar(#13#10+#0))  ;
  exit;
	for i := 0 to span^.len-1 do
	begin
		c := fz_text_char_s_items(span^.text)[i].c;
		if (c < 128) then
			result:=result+chr(c)
		else
		begin
			n := runetochar(@buf, @c);
			for k := 0  to n-1 do
				result:=result+(buf+k)^
		end;
	end;

	if (span^.eol<>0) then
		result:=result+#10;

	if (span^.next<>nil) then
		result:=result+gettexttt(span^.next);


end;

FUNCTION TdigPdfViewer.showtext(xref:ppdf_xref_S;  pagenum:integer):integer;
var
ERROR:INTEGER;
text:pfz_text_span_s;
dev:pfz_device_s;
list:pfz_display_list_s;
page:ppdf_page_s;
i,j:integer;
begin
  //  ShowMessage(FormatFloat('Memory used: ,.# K', CurrentMemoryUsage )) ;

    error := pdf_load_page(@page, xref, pagenum - 1);

    if (error<0) THEN
		  fz_rethrow(error, 'cannot load page %d in file "%s"', [pagenum, 'filename']);

	 	text := fz_new_text_span();
   	dev := fz_new_text_device(text);

   pdf_run_page(xref, page, dev, fz_identity);

 		fz_free_device(dev);
	 	//	fz_debug_text_span(text);
   ws:=WS+gettexttt(text);

   //  stext:=gettexttt(text);

 // ws:=getwidestr(pchar(stext));
 //      ws:=stext;
 	 	fz_free_text_span(text);
    
    pdf_free_page(page);
  //  ShowMessage(FormatFloat('Memory used: ,.# K', CurrentMemoryUsage )) ;
    //setprocessworkingsetsize(getcurrentprocess, $ffffffff, $ffffffff);
	END;


  function TdigPdfViewer.openfile3(filename: string;outputdirectory:string): integer;
var
	error:fz_error;
	f:pfz_stream_s;
	password:pchar;
	obj:pfz_obj_s;
	info:pfz_obj_s;
  okay:integer;
  ppp:pchar;
  PPO:PWIDECHAR;
  I:INTEGER;
begin
	(*
	 * Open PDF and load xref table
	 *)

  f:= fz_open_file(pchar(filename));
	if (f=nil) then
  begin
		//return fz_throw("cannot open file '%s': %s", filename, strerror(errno));
    result:=-1;
    exit;
  end;
	error := pdf_open_xref_with_stream( @myxref, f, nil);
	if (error<0) then
  begin
	  showmessage('sdf');
    result:=-1;
  end;
 	fz_close(f);


	(*
	 * Handle encrypted PDF files
	 *)

	if (pdf_needs_password(myxref)<>0)   then
	begin
		okay := pdf_authenticate_password(myxref, password);
		while (okay=0) do
		begin
			password :=pchar( InputBox('qw','asdf','123'));
			if (password=nil) then
				exit;
			okay := pdf_authenticate_password(myxref, password);
			if (okay=0) then
				showmessage('Invalid password.');
		end;
 end;

 for i:=0 to  myxref^.len-1 do
 begin
   error := pdf_load_object(@obj, myxref, i, 0);
	if (error<=0) THEN
		CONTINUE;

	if (isimage(obj))  THEN
   	saveimage(i,myxref,0,pchar(outputdirectory+'\a'+inttostr(i)+'.png'));
	//else if (isfontdesc(obj))
	//	savefont(obj, num);

	fz_drop_obj(obj);
 end;
 pdf_free_xref(myxref);
 //quit_FreeType2;
 exit;
 pdf_free_xref(myxref);
// fz_close(f);

end;

  function TdigPdfViewer.openfile4(filename: string;outputfile:string;pagenum: integer=1): integer;
var
	error:fz_error;
	f:pfz_stream_s;
	password:pchar;
	obj:pfz_obj_s;
	info:pfz_obj_s;
  okay:integer;
  ppp:pchar;
  PPO:PWIDECHAR;
  I:INTEGER;
  zoom:single;
		 ctm:fz_matrix;
		 bbox:fz_bbox;
		 pix:pfz_pixmap_s;

   page:ppdf_page_s;
   rotation:single;
   colorspace:pfz_colorspace_s;
   glyphcache:pfz_glyph_cache_s;
   dev:pfz_device_s;
begin
	(*
	 * Open PDF and load xref table
	 *)

  f:= fz_open_file(pchar(filename));
	if (f=nil) then
  begin
		//return fz_throw("cannot open file '%s': %s", filename, strerror(errno));
    result:=-1;
    exit;
  end;
	error := pdf_open_xref_with_stream( @myxref, f, nil);
	if (error<0) then
  begin
	  showmessage('error');
    result:=-1;
  end;
 	fz_close(f);


	(*
	 * Handle encrypted PDF files
	 *)

	if (pdf_needs_password(myxref)<>0)   then
	begin
		okay := pdf_authenticate_password(myxref, password);
		while (okay=0) do
		begin
			password :=pchar( InputBox('qw','asdf','123'));
			if (password=nil) then
				exit;
			okay := pdf_authenticate_password(myxref, password);
			if (okay=0) then
				showmessage('Invalid password.');
		end;
 end;
 rotation:=0;
 error:=pdf_load_page_tree(myxref);
 error := pdf_load_page(@page, myxref, pagenum - 1);
 resolution:=72;
 zoom := resolution / 72;
		ctm := fz_translate(0, -page^.mediabox.y1);
		ctm := fz_concat(ctm, fz_scale(zoom, -zoom));
		ctm := fz_concat(ctm, fz_rotate(page^.rotate));
		ctm := fz_concat(ctm, fz_rotate(rotation));
		bbox := fz_round_rect(fz_transform_rect(ctm, page^.mediabox));

		//* TODO: banded rendering and multi-page ppm */
    glyphcache := fz_new_glyph_cache();
    colorspace := get_fz_device_rgb;
		pix := fz_new_pixmap_with_rect(colorspace, bbox);
    fz_clear_pixmap_with_color(pix, 255);
   dev := fz_new_draw_device(glyphcache, pix);
   pdf_run_page(myxref, page, dev, ctm);

   fz_free_device(dev);

   fz_write_png(pix, pchar(outputfile),0);
   fz_drop_pixmap(pix);
   pdf_free_page(page);
 pdf_free_xref(myxref);
// fz_close(f);

end;

end.

