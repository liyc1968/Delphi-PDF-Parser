unit QSort1;
{*********************************************************
 *                     QSORT.PAS                         *
 *           C-like QuickSort implementation             *
 *     Written 931118 by Bj”rn Felten @ 2:203/208        *
 *           After an idea by Pontus Rydin               *
 *********************************************************}
interface
uses windows,SysUtils;
type CompFunc = function(Item1, Item2 : pointer) : integer;

procedure QuickSort(Data:pointer;count,size: Longint; const Compare: CompFunc);

implementation
var
size:integer;
data:pointer;
procedure Swap(Item1, Item2 : pointer;size:integer);
  var  pp:pointer;
  begin
     if CompareMem(Item1, Item2,size)=false then
     begin
        getmem(pp,size);
        copymemory(pp,Item1,size);
        copymemory(Item1, Item2,size);
        copymemory(Item2,pp,size);
        freemem(pp);
     end
  end;
  function q_getpointe(index:integer;data:pointer;size:integer):pointer;
  begin
    result:=pointer(integer(data)+index*size);
  end;

function Partition(const p, r: Longint; const Compare: CompFunc;data:pointer;size:integer): Longint;
var
  i, j: Longint;
begin
  i := p;
  j := r;
  Result := 0; { to remove compiler warning }
  while True do begin
    while ((j > p) and (Compare(q_getpointe(j,data,size), q_getpointe(p,data,size)) >= 0)) do
      Dec(j);
    while ((i < r) and (Compare(q_getpointe(i,data,size), q_getpointe(p,data,size)) < 0)) do
      Inc(i);
    if i < j then
      Swap(q_getpointe(i,data,size), q_getpointe(j,data,size),size)  
    else begin
      Result := j;
      Break;
    end; {else}
  end; {while}
end;



procedure QuickSort1(const p, r: Longint; const Compare: CompFunc;data:pointer;size:integer) ;
var
  q: Longint;
begin


  if (p < r) then begin
    q := Partition(p, r, Compare,data,size);
    QuickSort1(p, q, Compare,data,size);
    QuickSort1(q + 1, r, Compare,data,size);
  end;
end;

procedure QuickSort(Data:pointer;count,size: Longint; const Compare: CompFunc);
var
 p,r:integer;
begin
  p:=0;
  r:=count-1;
  QuickSort1(p, r, Compare,data,size);
end;


end.
