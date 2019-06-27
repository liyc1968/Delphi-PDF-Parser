unit base_error;

interface
uses windows,SysUtils,digtypes,psapi;
function fz_warn(const Format1: string): fz_error;  overload;
function fz_warn(const Format1: string; const Args: array of const): fz_error; overload;
function fz_warn(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
function fz_rethrow(const Format1: string; const Args: array of const): fz_error; overload;
function fz_rethrow(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
function fz_rethrow(error:fz_error; const Format1: string): fz_error; overload;
function fz_rethrow(error:fz_error;const Format1: string; const Args: array of const): fz_error; overload;
function fz_throw(const Format1: string): fz_error;overload;
function fz_throw(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
function fz_throw(const Format1: string; const Args: array of const): fz_error; overload;

function fz_catch(const Format1: string): fz_error;overload;
function fz_catch(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
function fz_catch(const Format1: string; const Args: array of const): fz_error; overload;
function fz_catch(error:fz_error; const Format1: string): fz_error; overload;
function fz_catch(error:fz_error;const Format1: string; const Args: array of const): fz_error; overload;
procedure outprintf(s:string);
function CurrentMemoryUsage: Cardinal;
implementation
//Format(const Format: string; const Args: array of const): string; overload;
//function Format(const Format: string; const Args: array of const; const FormatSettings: TFormatSettings): string; overload;
{$DEFINE   basic}
function fz_warn(const Format1: string): fz_error;  overload;
begin
   {$IFDEF basic}
   OutputDebugString(pchar(Format1));
   {$ENDIF}

   result:=-1;
end;

function fz_warn(const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
   s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;
function fz_warn(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
  {$IFDEF basic}
  s:=Format(Format1, Args, FormatSettings);
  OutputDebugString(pchar(s));
  {$ENDIF}
  result:=-1;
end;

function fz_rethrow(error:fz_error; const Format1: string): fz_error; overload;
begin
   {$IFDEF basic}
   OutputDebugString(pchar(inttostr(error)+':'+Format1));
   {$ENDIF}
   result:=-1;
end;

function fz_rethrow(error:fz_error;const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
  {$IFDEF basic}
     s:=Format(Format1, Args);
   OutputDebugString(pchar(inttostr(error)+':'+s));
   {$ENDIF}
   result:=-1;
end;

function fz_rethrow(const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
  {$IFDEF basic}
     s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;
function fz_rethrow(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
   s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;
function fz_throw(const Format1: string): fz_error;  overload;
begin
   {$IFDEF basic}
   OutputDebugString(pchar(Format1));
   {$ENDIF}
   result:=-1;
end;
function fz_throw(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
   s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;

function fz_throw(const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
     s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;


function fz_catch(const Format1: string): fz_error;  overload;
begin
   {$IFDEF basic}
   OutputDebugString(pchar(Format1));
   {$ENDIF}
   result:=-1;
end;
function fz_catch(const Format1: string; const Args: array of const; const FormatSettings: TFormatSettings): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
   s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;

function fz_catch(const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
     s:=Format(Format1, Args);
   OutputDebugString(pchar(s));
   {$ENDIF}
   result:=-1;
end;

function fz_catch(error:fz_error; const Format1: string): fz_error; overload;
begin
   {$IFDEF basic}
   OutputDebugString(pchar(inttostr(error)+':'+Format1));
   {$ENDIF}
   result:=-1;
end;

function fz_catch(error:fz_error;const Format1: string; const Args: array of const): fz_error; overload;
{$IFDEF basic}
var
 s:string;   {$ENDIF}
begin
   {$IFDEF basic}
     s:=Format(Format1, Args);
   OutputDebugString(pchar(inttostr(error)+':'+s));
   {$ENDIF}
   result:=-1;
end;

procedure outprintf(s:string);
begin

 OutputDebugString(pchar(s));
end;

function CurrentMemoryUsage: Cardinal;
 var
   pmc: TProcessMemoryCounters;
 begin
  // ShowMessage(FormatFloat('Memory used: ,.# K', CurrentMemoryUsage )) ;
   pmc.cb := SizeOf(pmc) ;
   if GetProcessMemoryInfo(GetCurrentProcess, @pmc, SizeOf(pmc)) then
     Result := pmc.WorkingSetSize
   else
     RaiseLastOSError;
 end;

end.
