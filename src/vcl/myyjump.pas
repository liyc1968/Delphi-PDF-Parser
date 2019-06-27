unit myyjump;

interface

type
  jmp_buf = pointer;

 function setjmp(setjmp_buffer : jmp_buf) : integer;
 procedure longjmp(setjmp_buffer : jmp_buf; flag : integer);
implementation
 function setjmp(setjmp_buffer : jmp_buf) : integer;
begin
  setjmp := 0;
end;
procedure longjmp(setjmp_buffer : jmp_buf; flag : integer);
begin
  Halt(2);
end;

end.
