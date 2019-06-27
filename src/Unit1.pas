unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,digPdfViewer, TntStdCtrls,digtypes, ComCtrls,
  TntComCtrls,base_object_functions,fz_outline,freetype ,

  ExtDlgs, ExtCtrls,shellapi, ToolWin,shlobj; // FastMMUsageTracker,

type
  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Button4: TButton;
    Button5: TButton;
    Button7: TButton;
    OpenDialog1: TOpenDialog;
    Button9: TButton;
    Label2: TLabel;
    SaveDialog1: TSaveDialog;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    memo2: TTntMemo;
    memo1: TTntMemo;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
  private
    { Private declarations }
    digPdfViewer:tdigPdfViewer;
  public
    { Public declarations }
    dig:TdigPdfViewer;

  end;

var
  Form1: TForm1;
Saved8087CW: Word;
implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
if not OpenDialog1.Execute then
exit;

edit1.Text:=OpenDialog1.FileName;

end;

procedure addchildnodee(mainnode: TtnttreeNode; pp: ppdf_outline_s;tt:ttnttreeView);
var
tempnode1,tempnode2:TtnttreeNode;
outline1:ppdf_outline_s;

begin
  outline1:=pp;
  while outline1<>nil do
  begin

  tempnode1:=tt.Items.Addchild(mainnode,getwidestr(outline1^.title)) ;
  if outline1^.child<>nil then
  begin
    addchildnodee(tempnode1, outline1^.child,tt);
  end;
   outline1:=outline1^.next;
  end;
end;



procedure TForm1.FormCreate(Sender: TObject);
begin
Saved8087CW := Default8087CW;
Set8087CW($133f);
Font.Name := 'MS Shell Dlg 2';
//init_FreeType2  ;
 if not init_FreeType2 then
   SHOWMESSAGE('Error initializing FreeType2 Library');
end;


procedure TForm1.Button4Click(Sender: TObject);
var
outline1:ppdf_outline_s ;
pw:PWideChar;
pagenumber:integer;
begin

   digPdfViewer:=tdigPdfViewer.Create;
   pagenumber:=1;

   digPdfViewer.gopage:=pagenumber;
   digPdfViewer.openfile1(edit1.Text);
   memo2.Lines.Clear;
   memo2.Lines.Add('title:'+digPdfViewer.title);
   memo2.Lines.Add('Subject:'+digPdfViewer.Subject) ;
   memo2.Lines.Add('author:'+digPdfViewer.author)  ;
   memo2.Lines.Add('Keywords:'+digPdfViewer.Keywords);
   memo2.Lines.Add('Producer:'+digPdfViewer.Producer) ;
   memo2.Lines.Add('Creator:'+digPdfViewer.Creator);
   memo2.Lines.Add('CreationDate:'+digPdfViewer.CreationDate);
   memo2.Lines.Add('ModDate:'+digPdfViewer.ModDate) ;
   memo2.Lines.Add(digPdfViewer.ws);

   digPdfViewer.FREE;

end;

procedure TForm1.Button5Click(Sender: TObject);
begin

 digPdfViewer:=tdigPdfViewer.Create;
 digPdfViewer.openfile2(edit1.Text,1);
 memo1.Lines.clear;
 memo1.Lines.Add(digPdfViewer.ws);
 digPdfViewer.FREE;
end;

function   SelectDirectory(handle:hwnd;const   Caption:   string;   const   Root:   WideString;out   Directory:   string):   Boolean;   
  var   
  lpbi:_browseinfo;
  buf:array   [0..MAX_PATH]   of   char;   
  id:ishellfolder;   
  eaten,att:cardinal;   
  rt:pitemidlist;   
  initdir:pwidechar;


  begin   
  result:=false;   
  lpbi.hwndOwner:=handle;   
  lpbi.lpfn:=nil;
  lpbi.lpszTitle:=pchar(caption);
  lpbi.ulFlags:=BIF_RETURNONLYFSDIRS+16;
  SHGetDesktopFolder(id);
  initdir:=nil; //pwchar(root);
  id.ParseDisplayName(0,nil,initdir,eaten,rt,att);
  lpbi.pidlRoot:=rt;   
  getmem(lpbi.pszDisplayName,MAX_PATH);   
  try
  result:=shgetpathfromidlist(shbrowseforfolder(lpbi),buf);
  except
  freemem(lpbi.pszDisplayName);
  end;
  if   result   then   directory:=buf;   
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
Set8087CW(Saved8087CW);
end;

procedure TForm1.Button7Click(Sender: TObject);
var
outline1:ppdf_outline_s ;
pw:PWideChar;
pagenumber:integer;
outputdirectory:string;

begin
  IF NOT SelectDirectory(handle,'Please select folder','',outputdirectory) THEN
     EXIT;

   outputdirectory:=ExcludeTrailingPathDelimiter(outputdirectory);
   
   digPdfViewer:=tdigPdfViewer.Create;
   pagenumber:=1;
   digPdfViewer.gopage:=pagenumber;
   digPdfViewer.openfile3(edit1.Text,outputdirectory);
   digPdfViewer.FREE;
   showmessage('ok');
end;

procedure TForm1.Button9Click(Sender: TObject);
var
 digPdfViewer:tdigPdfViewer;
 pagenumber:integer;
begin
  if not SaveDialog1.Execute then
  exit;
  digPdfViewer:=tdigPdfViewer.Create;
  pagenumber:=1;
  digPdfViewer.openfile4(edit1.Text,SaveDialog1.FileName,1);
  digPdfViewer.Free;
end;

end.
