unit QSort2;
{*********************************************************
 *                     QSORT.PAS                         *
 *           C-like QuickSort implementation             *
 *     Written 931118 by Bj”rn Felten @ 2:203/208        *
 *           After an idea by Pontus Rydin               *
 *********************************************************}
interface
uses windows,SysUtils;
type CompFunc = function(Item1, Item2 : pointer) : integer;

procedure QuickSort(
    Data:pointer;
{An array. Must be [0..Count-1] and not [1..Count] or anything else! }
    Count,
{Number of elements in the array}
    Size    : word;
{Size in bytes of a single element -- e.g. 2 for integers or words,
4 for longints, 256 for strings and so on }
    Compare : CompFunc);
{The function that decides which element is "greater" or "less". Must
return an integer that's < 0 if the first element is less, 0 if they're
equal and > 0 if the first element is greater. A simple Compare for
words can look like this:

 function WordCompare(Item1, Item2: word): integer;
 begin
     WordCompare := MyArray[Item1] - MyArray[Item2]
 end;

NB. It's not the =indices= that shall be compared, it's the elements that
the supplied indices points to! Very important to remember!
Also note that the array may be sorted in descending order just by
means of a simple swap of Item1 and Item2 in the example.}

implementation
procedure QuickSort;

  procedure Swap(Item1, Item2 : pointer);
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
  function q_getpointe(index:integer):pointer;
  begin
    result:=pointer(integer(data)+index*size);
  end;

  procedure Sort(Left, Right: integer);
  var  i, j, x, y : integer;
  begin
     i := Left; j := Right; x := (Left+Right) div 2;
     repeat
        while compare(q_getpointe(i), q_getpointe(x)) < 0 do
        begin
          inc(i);
        end;
        while compare(q_getpointe(x), q_getpointe(j)) < 0 do
        begin
          dec(j);
        end;
        if i <= j then
        begin
           swap(q_getpointe(i), q_getpointe(j));
           inc(i);
           dec(j)
        end
     until i > j;
     if Left < j then Sort(Left, j);
     if i < Right then Sort(i, Right)
  end;

begin Sort(0, Count-1) end;

end. { of unit }
