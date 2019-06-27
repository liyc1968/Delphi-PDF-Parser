{ *********************************************************************** }
{                                                                         }
{ Delphi Runtime Library                                                  }
{ JmpLib Unit                                                             }
{                                                                         }
{ Copyright (c) 2003, 2004 Will DeWitt Jr. <edge@boink.net>               }
{                                                                         }
{ This software is provided 'as-is', without any express or implied       }
{ warranty.  In no event will the authors be held liable for any damages  }
{ arising from the use of this software.                                  }
{                                                                         }
{ Permission is granted to anyone to use this software for any purpose,   }
{ including commercial applications, and to alter it and redistribute it  }
{ freely, subject to the following restrictions:                          }
{                                                                         }
{   1. The origin of this software must not be misrepresented; you must   }
{      not claim that you wrote the original software. If you use this    }
{      software in a product, an acknowledgment in the product            }
{      documentation would be appreciated but is not required.            }
{                                                                         }
{   2. Altered source versions must be plainly marked as such, and must   }
{      not be misrepresented as being the original software.              }
{                                                                         }
{   3. This notice may not be removed or altered from any source          }
{      distribution.                                                      }
{                                                                         }
{ *********************************************************************** }

unit JmpLib;

interface

type
  jmp_buf = record
    EBX,
    ESI,
    EDI,
    ESP,
    EBP,
    EIP: longword;
  end;

{ setjmp captures the complete task state which can later be used to perform
  a non-local goto using longjmp. setjmp returns 0 when it is initially called,
  and a non-zero value when it is returning from a call to longjmp. setjmp must
  be called before longjmp. }

function  setjmp(out jmpb: jmp_buf): integer;

{ longjmp restores the task state captured by setjmp (and passed in jmpb). It
  then returns in such a way that setjmp appears to have returned with the
  value retval. setjmp must be called before longjmp. }

procedure longjmp(const jmpb: jmp_buf; retval: integer);

implementation

function  setjmp(out jmpb: jmp_buf): integer; register;
asm
{     ->  EAX     jmpb   }
{     <-  EAX     Result }
          MOV     EDX, [ESP]  // Fetch return address (EIP)
          // Save task state
          MOV     [EAX+jmp_buf.&EBX], EBX
          MOV     [EAX+jmp_buf.&ESI], ESI
          MOV     [EAX+jmp_buf.&EDI], EDI
          MOV     [EAX+jmp_buf.&ESP], ESP
          MOV     [EAX+jmp_buf.&EBP], EBP
          MOV     [EAX+jmp_buf.&EIP], EDX

          SUB     EAX, EAX
@@1:
end;

procedure longjmp(const jmpb: jmp_buf; retval: integer); register;
asm
{     ->  EAX     jmpb   }
{         EDX     retval }
{     <-  EAX     Result }
          XCHG    EDX, EAX

          MOV     ECX, [EDX+jmp_buf.&EIP]
          // Restore task state
          MOV     EBX, [EDX+jmp_buf.&EBX]
          MOV     ESI, [EDX+jmp_buf.&ESI]
          MOV     EDI, [EDX+jmp_buf.&EDI]
          MOV     ESP, [EDX+jmp_buf.&ESP]
          MOV     EBP, [EDX+jmp_buf.&EBP]
          MOV     [ESP], ECX  // Restore return address (EIP)

          TEST    EAX, EAX    // Ensure retval is <> 0
          JNZ     @@1
          MOV     EAX, 1
@@1:
end;

end.

