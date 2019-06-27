unit pdf_functionss;

interface
 uses  SysUtils, Math,digtypes,base_error;
const
RADIAN= 57.2957795;

const ps_op_names:array[0..42] of pchar=(
	'abs', 'add', 'and', 'atan', 'bitshift', 'ceiling', 'copy',
	'cos', 'cvi', 'cvr', 'div', 'dup', 'eq', 'exch', 'exp',
	'false', 'floor', 'ge', 'gt', 'idiv', 'index', 'le', 'ln',
	'log', 'lt', 'mod', 'mul', 'ne', 'neg', 'not', 'or', 'pop',
	'roll', 'round', 'sin', 'sqrt', 'sub', 'true', 'truncate',
	'xor', 'if', 'ifelse', 'return'
);
 function pdf_load_function(funcp:pppdf_function_s; xref:ppdf_xref_s; dict:pfz_obj_s) :integer;
procedure pdf_eval_function(func:ppdf_function_s; inp:psingle; inlen:integer; outp:psingle; outlen:integer);
procedure pdf_drop_function(func:ppdf_function_s);
implementation
uses base_object_functions,digcommtype,mypdfstream,FZ_mystreams,fz_pdf_store;

function  lerp( x,  xmin,  xmax,  ymin, ymax:single):single;
begin
	if (xmin = xmax) then
		begin
      result:=ymin;
      exit;
    end;
	if (ymin = ymax) then
  begin
		result:=ymin;
    exit;
  end;
	result:= ymin + (x - xmin) * (ymax - ymin) / (xmax - xmin);
end;

(*
 * PostScript calculator
 *)





procedure ps_init_stack(st:pps_stack_s) ;
begin
	fillchar(st^.stack, sizeof(st^.stack), 0);
	st^.sp := 0;
end;

function ps_overflow(st:pps_stack_s; n:integer):boolean;
begin
  if (n < 0) or ( st^.sp + n >= length(st^.stack)) then
	result:=true
  else
  result:=false;
end;

function ps_underflow(st:pps_stack_s; n:integer) :boolean;
begin
result:= (n < 0) or (st^.sp - n < 0);
end;

function ps_is_type(st:pps_stack_s; t:integer) :boolean;
begin
	result:= (not ps_underflow(st, 1)) and (st^.stack[st^.sp - 1].type1 = t);
end;

function ps_is_type2(st:pps_stack_s; t:integer):boolean;
begin
  result:= (not ps_underflow(st, 2)) and (st^.stack[st^.sp - 1].type1 = t) and (st^.stack[st^.sp - 2].type1 = t);
end;

procedure ps_push_bool(st:pps_stack_s; b:boolean);
begin
	if (not ps_overflow(st, 1)) then
	begin
		st^.stack[st^.sp].type1 := ord(PS_BOOL);
    if b then
		st^.stack[st^.sp].u.b := 1
    else
    st^.stack[st^.sp].u.b := 0;
		st^.sp:=st^.sp+1;
	end;
end;

procedure ps_push_int(st:pps_stack_s; n:integer) ;
begin
	if (not ps_overflow(st, 1)) then
	begin
		st^.stack[st^.sp].type1 := ord(PS_INT);
		st^.stack[st^.sp].u.i := n;
		st^.sp:=st^.sp+1;
	end;
end;

procedure ps_push_real(st:pps_stack_s;  n:single);
begin
	if (not ps_overflow(st, 1)) then
	begin
		st^.stack[st^.sp].type1 := ord(PS_REAL);
		st^.stack[st^.sp].u.f := n;
		st^.sp:=st^.sp+1;
	end;
end;

function ps_pop_bool(st:pps_stack_s):boolean;
var
k:integer;
begin
	if (not ps_underflow(st, 1)) then
	begin
		if (ps_is_type(st, ord(PS_BOOL))) then
    begin
    st^.sp:=st^.sp-1;
    k:=st^.stack[st^.sp].u.b;
    result:=k<>0;
    exit;
    end;
	end;
	result:=false;
end;

function ps_pop_int(st:pps_stack_s):integer;
begin
	if (not ps_underflow(st, 1)) then
	begin
		if (ps_is_type(st, ord(PS_INT))) then
    begin
			result:= st^.stack[--st^.sp].u.i;
      exit;
    end;
		if (ps_is_type(st, ord(PS_REAL))) then
    begin
      st^.sp:=st^.sp-1;
			result:=trunc(st^.stack[st^.sp].u.f);
    end;
	end;
	result:= 0;
end;

function ps_pop_real(st:pps_stack_s):single;
begin
	if (not ps_underflow(st, 1))   then
	begin
		if (ps_is_type(st, ord(PS_INT))) then
    begin
      st^.sp:=st^.sp-1;
			result:= st^.stack[--st^.sp].u.i;
      exit;
    end;
		if (ps_is_type(st, ord(PS_REAL))) then
    begin
      st^.sp:=st^.sp-1;
			result:= st^.stack[st^.sp].u.f;
      exit;
    end;
	end;
  result:= 0;
end;

procedure ps_copy(st:pps_stack_s; n:integer);

begin
	if (not ps_underflow(st, n)) and (not ps_overflow(st, n)) then
	begin

		copymemory(pointer(cardinal(@st^.stack) + sizeof(psobj_s)* st^.sp), pointer(cardinal(@st^.stack) + sizeof(psobj_s)*(st^.sp - n)), n * sizeof(psobj_s));
		st^.sp :=st^.sp + n;
	end;
end;

procedure
ps_roll(st:pps_stack_s;  n, j:integer);
var
 tmp:	psobj_s ;
	i:integer;
begin
	if (ps_underflow(st, n) or (j = 0) or (n = 0)) then
		exit;;

	if (j >= 0)  then
	begin
		j :=j mod n;
	end
	else
	begin
		j := -j mod n;
		if (j <> 0) then
			j := n - j;
	end;

	for i := 0  to j-1 do
	begin
		tmp := st^.stack[st^.sp - 1];
		move(pointer(cardinal(@st^.stack) + sizeof(psobj_s)*(st^.sp - n + 1))^, pointer(cardinal(@st^.stack) + sizeof(psobj_s)*( st^.sp - n))^, n * sizeof(psobj_s));
		st^.stack[st^.sp - n] := tmp;
	end;
end;

procedure ps_index(st:pps_stack_s;  n:integer);
begin
	if (not ps_overflow(st, 1)) and (not ps_underflow(st, n)) then
	begin
		st^.stack[st^.sp] := st^.stack[st^.sp - n - 1];
		st^.sp:=st^.sp+1;
	end;
end;

procedure ps_run(code:ppsobj_s; st:pps_stack_s; pc:integer);
var
	i1, i2:integer;
	r1, r2:single;
	b1, b2:boolean;
  pp:integer;
  p1:PostScript_kind1_e;
  p2:PostScript_kind2_e ;
begin
	while (true) do
	begin
    pp:= psobj_s_items(code)[pc].type1;
    p1:=PostScript_kind1_e(pp);
		case p1 of
		PS_INT:
      begin
			ps_push_int(st, psobj_s_items(code)[pc].u.i);
      pc:=pc+1;
      end;
		PS_REAL:
      begin
			ps_push_real(st, psobj_s_items(code)[pc].u.f);
			pc:=pc+1;
      end;
		PS_OPERATOR:
    begin
      p2:=PostScript_kind2_e(psobj_s_items(code)[pc].u.op);
			case p2 of
			PS_OP_ABS:
        begin
				if (ps_is_type(st, ord(PS_INT))) then
					ps_push_int(st, abs(ps_pop_int(st)))
				else
					ps_push_real(st, abs(ps_pop_real(st)));
				end;

			PS_OP_ADD:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 + i2);
				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
					ps_push_real(st, r1 + r2);
				end;
				end;

			PS_OP_AND:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 and i2);
				end
				else begin
					b2 := ps_pop_bool(st);
					b1 := ps_pop_bool(st);
         
             ps_push_bool(st, b1 and b2)

				end;
				end;

		   PS_OP_ATAN:
        begin
				r2 := ps_pop_real(st);
				r1 := ps_pop_real(st);
				r1 := atan2(r1, r2) * RADIAN;
				if (r1 < 0) then
					r1 :=r1 + 360;
				ps_push_real(st, r1);
				end;

			PS_OP_BITSHIFT:
        begin
				i2 := ps_pop_int(st);
				i1 := ps_pop_int(st);
				if (i2 > 0) then
					ps_push_int(st, i1 shl i2)
				else if (i2 < 0) then
					ps_push_int(st, (i1 shr i2))
				else
					ps_push_int(st, i1);
				end;

			PS_OP_CEILING:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, ceil(r1));
			  end;

			PS_OP_COPY:
        begin
				ps_copy(st, ps_pop_int(st));
				end;

			PS_OP_COS:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, cos(r1/RADIAN));
				end;

			PS_OP_CVI:
        begin
				ps_push_int(st, ps_pop_int(st));
				end;

			PS_OP_CVR:
        begin
				ps_push_real(st, ps_pop_real(st));
				end;

			PS_OP_DIV:
        begin
				r2 := ps_pop_real(st);
				r1 := ps_pop_real(st);
				ps_push_real(st, r1 / r2);
				end;

			PS_OP_DUP:
        begin
				ps_copy(st, 1);
				end;

			PS_OP_EQ:
        begin
				if (ps_is_type2(st, ord(PS_BOOL))) then
         begin
					b2 := ps_pop_bool(st);
					b1 := ps_pop_bool(st);
       		ps_push_bool(st, b1 = b2)
         end
				else if (ps_is_type2(st, ord(PS_INT))) then
         begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);

					ps_push_bool(st, i1=i2)

				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);

					ps_push_bool(st, r1 = r2)
        
				end;
				end;

			PS_OP_EXCH:
        begin
				ps_roll(st, 2, 1);
				end;

			PS_OP_EXP:
        begin
				r2 := ps_pop_real(st);
				r1 := ps_pop_real(st);
				ps_push_real(st, power(r1, r2));
				end;

			PS_OP_FALSE:
        begin
				ps_push_bool(st, false);
				end;

			PS_OP_FLOOR:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, floor(r1));
			  end;

			PS_OP_GE:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);

					ps_push_bool(st, i1 >= i2)

				end
				else
        begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);

					ps_push_bool(st, r1 >= r2)

				end;
				end;

			PS_OP_GT:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
         begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);

					ps_push_bool(st, i1>i2)

				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
        	ps_push_bool(st, r1>r2)
        
				end;
				end;

			PS_OP_IDIV:
        begin
				i2 := ps_pop_int(st);
				i1 := ps_pop_int(st);
				ps_push_int(st, i1 div i2);
				end;

		  PS_OP_INDEX:
        begin
				ps_index(st, ps_pop_int(st));
				end;

			PS_OP_LE:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
         begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);

					ps_push_bool(st, i1 <= i2)

				end
				else
        begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
					ps_push_bool(st,r1 <= r2 )
				end;
				end;

			PS_OP_LN:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, log2(r1));
				end;

			PS_OP_LOG:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, log10(r1));
				end;

			PS_OP_LT:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);

					ps_push_bool(st, i1 < i2)

				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);

					ps_push_bool(st, r1 < r2)
         
				end;
				end;

			PS_OP_MOD:
        begin
				i2 := ps_pop_int(st);
				i1 := ps_pop_int(st);
				ps_push_int(st, i1 mod i2);
				end;

			PS_OP_MUL:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 * i2);
				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
					ps_push_real(st, r1 * r2);
				end;
				end;

			PS_OP_NE:
        begin
				if (ps_is_type2(st, ord(PS_BOOL))) then
        begin
					b2 := ps_pop_bool(st);
					b1 := ps_pop_bool(st);
					ps_push_bool(st, b1 <> b2)
				end
				else if (ps_is_type2(st,ord( PS_INT))) then
        begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_bool(st, i1 <> i2)
				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
         	ps_push_bool(st, r1 <> r2)
        end;
			  end;

			PS_OP_NEG:
        begin
				if (ps_is_type(st, ord(PS_INT))) then
					ps_push_int(st, -ps_pop_int(st))
				else
					ps_push_real(st, -ps_pop_real(st));
				end;

			PS_OP_NOT:
        begin
				if (ps_is_type(st, ord(PS_BOOL)))  THEN
					ps_push_bool(st, not ps_pop_bool(st))
				else
					ps_push_int(st, not ps_pop_int(st));
			  end;

			PS_OP_OR:
        begin
				if (ps_is_type2(st, ord(PS_BOOL))) then begin
					b2 := ps_pop_bool(st);
					b1 := ps_pop_bool(st);
					ps_push_bool(st, b1 or b2);
				end
				else begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 or i2);
				end;
				end;

			PS_OP_POP:
        begin
				if (not ps_underflow(st, 1)) then
					st^.sp:=st^.sp-1;
				end;

			PS_OP_ROLL:
        begin
				i2 := ps_pop_int(st);
				i1 := ps_pop_int(st);
				ps_roll(st, i1, i2);
				end;

		  PS_OP_ROUND:
        begin
				if (not ps_is_type(st, ord(PS_INT))) then
        begin
					r1 := ps_pop_real(st);
          if r1 >= 0 then
             ps_push_real(st,  floor(r1 + 0.5))
             else
             ps_push_real(st,  ceil(r1 - 0.5));
					
				end;
			  end;

			PS_OP_SIN:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, sin(r1/RADIAN));
				end;

			PS_OP_SQRT:
        begin
				r1 := ps_pop_real(st);
				ps_push_real(st, sqrt(r1));
				end;

			PS_OP_SUB:
        begin
				if (ps_is_type2(st, ord(PS_INT))) then
         begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 - i2);
				end
				else begin
					r2 := ps_pop_real(st);
					r1 := ps_pop_real(st);
					ps_push_real(st, r1 - r2);
				end;
				end;

		 PS_OP_TRUE:
        begin
				ps_push_bool(st, true);
				end;

			PS_OP_TRUNCATE:
        begin
				if (not ps_is_type(st, ord(PS_INT))) then begin
					r1 := ps_pop_real(st);
          if r1 >= 0 then
             ps_push_real(st,floor(r1))
             else
             ps_push_real(st,ceil(r1));
				
				end;
				end;

			PS_OP_XOR:
        begin
				if (ps_is_type2(st, ord(PS_BOOL))) then
         begin
					b2 := ps_pop_bool(st);
					b1 := ps_pop_bool(st);
					ps_push_bool(st, b1 xor b2);
				end
				else begin
					i2 := ps_pop_int(st);
					i1 := ps_pop_int(st);
					ps_push_int(st, i1 XOR i2);
				end;
				end;

			PS_OP_IF:
        begin
				b1 := ps_pop_bool(st);
				if (b1)  then
					ps_run(code, st, psobj_s_items(code)[pc + 1].u.block);
				pc := psobj_s_items(code)[pc + 2].u.block;
				end;

			PS_OP_IFELSE:
        begin
				b1 := ps_pop_bool(st);
				if (b1) then
					ps_run(code, st, psobj_s_items(code)[pc + 1].u.block)
				else
					ps_run(code, st, psobj_s_items(code)[pc + 0].u.block);
				pc := psobj_s_items(code)[pc + 2].u.block;
				end;

			PS_OP_RETURN:
        begin
				 exit;
        end;
			else
        begin
				//fz_warn("foreign operator in calculator function");
				exit;
        end;
			end;

      end;
		else
      begin
			 //fz_warn("foreign object in calculator function");
			 exit;
      end;
		end;
	end;
end;

procedure resize_code(func:ppdf_function_s; newsize:integer);
begin
	if (newsize >= func^.u.p.cap) then
	begin
		func^.u.p.cap := func^.u.p.cap + 64;
		func^.u.p.code := fz_realloc(func^.u.p.code, func^.u.p.cap, sizeof(psobj_s));
	end;
end;

function parse_code(func:ppdf_function_s; stream:pfz_stream_s; codeptr:pinteger):integer;
var
	error:integer;
	 buf:array[0..63] of char;
	len:integer;
	tok:pdf_kind_e;
	opptr, elseptr, ifptr:integer;
	a, b, mid, cmp:integer;
begin
	fillchar(buf, sizeof(buf), 0);

	while (true) do
	begin
		error := pdf_lex(@tok, stream, buf, sizeof(buf), @len);
		if (error<0)  then
    begin
			//return fz_rethrow(error, "calculator function lexical error");
      result:=-1;
      exit;
    end;


		case tok of
		PDF_TOK_EOF:
    begin
			//return fz_throw("truncated calculator function");
      result:=-1;
      exit;
    end;

		PDF_TOK_INT:
    begin
			resize_code(func, codeptr^);
			psobj_s_items(func^.u.p.code)[codeptr^].type1 := ord(PS_INT);
			psobj_s_items(func^.u.p.code)[codeptr^].u.i := atoi(buf);
      codeptr^:=codeptr^+1;

		end;

		PDF_TOK_REAL:
    begin
			resize_code(func, codeptr^);
			psobj_s_items(func^.u.p.code)[codeptr^].type1 := ord(PS_REAL);
			psobj_s_items(func^.u.p.code)[codeptr^].u.f := fz_atof(buf);
			codeptr^:=codeptr^+1;
	  end;

		PDF_TOK_OPEN_BRACE:
    begin
			opptr := codeptr^;
			codeptr^ :=codeptr^ + 4;

			resize_code(func, codeptr^);

			ifptr := codeptr^;
			error := parse_code(func, stream, codeptr);
			if (error<0)  then
      begin
				//return fz_rethrow(error, "error in 'if' branch");
        result:=-1;
        exit;
      end;

			error := pdf_lex(@tok, stream, buf, sizeof(buf), @len);
			if (error<0)  then
      begin
				//return fz_rethrow(error, "calculator function syntax error");
        result:=-1;
        exit;
      end;

			if (tok = PDF_TOK_OPEN_BRACE) then
			begin
				elseptr := codeptr^;
				error := parse_code(func, stream, codeptr);
				if (error<0)  then
        begin
				 //	return fz_rethrow(error, "error in 'else' branch");
          result:=-1;
          exit;
        end;

				error := pdf_lex(@tok, stream, buf, sizeof(buf), @len);
				if (error<0)  then
        begin
					//return fz_rethrow(error, "calculator function syntax error");
          result:=-1;
          exit;
        end;
			end
			else
			begin
				elseptr := -1;
			end ;

			if (tok = PDF_TOK_KEYWORD) then
			begin
				if (strcomp(buf, 'if')=0) then
				begin
					if (elseptr >= 0) then
          begin
						//return fz_throw("too many branches for 'if'");
            result:=-1;
            exit;
          end;
					psobj_s_items(func^.u.p.code)[opptr].type1 := ord(PS_OPERATOR);
					psobj_s_items(func^.u.p.code)[opptr].u.op := ord(PS_OP_IF);
					psobj_s_items(func^.u.p.code)[opptr+2].type1 := ord(PS_BLOCK);
					psobj_s_items(func^.u.p.code)[opptr+2].u.block := ifptr;
					psobj_s_items(func^.u.p.code)[opptr+3].type1 := ord(PS_BLOCK);
					psobj_s_items(func^.u.p.code)[opptr+3].u.block := codeptr^;
				end
				else if (strcomp(buf, 'ifelse')=0) then
				begin
					if (elseptr < 0) then
          begin
						//return fz_throw("not enough branches for 'ifelse'");
            result:=-1;
            exit;
          end;
					psobj_s_items(func^.u.p.code)[opptr].type1 := ord(PS_OPERATOR);
					psobj_s_items(func^.u.p.code)[opptr].u.op := ord(PS_OP_IFELSE);
					psobj_s_items(func^.u.p.code)[opptr+1].type1 := ord(PS_BLOCK);
					psobj_s_items(func^.u.p.code)[opptr+1].u.block := elseptr;
					psobj_s_items(func^.u.p.code)[opptr+2].type1 := ord(PS_BLOCK);
					psobj_s_items(func^.u.p.code)[opptr+2].u.block := ifptr;
					psobj_s_items(func^.u.p.code)[opptr+3].type1 := ord(PS_BLOCK);
					psobj_s_items(func^.u.p.code)[opptr+3].u.block := codeptr^;
				end
				else
				begin
					result:= fz_throw('unknown keyword in "if-else" context: "%s"',[ buf]);
       //   result:=-1;
          exit;
				end;
			end
			else
			begin
				result:= fz_throw('missing keyword in "if-else" context');
      //  result:=-1;
          exit;
			end;
		end;

		PDF_TOK_CLOSE_BRACE:
      begin
			resize_code(func, codeptr^);
			psobj_s_items(func^.u.p.code)[codeptr^].type1 := ord(PS_OPERATOR);
			psobj_s_items(func^.u.p.code)[codeptr^].u.op := ord(PS_OP_RETURN);
			codeptr^:=codeptr^+1;
			result:=1;
      exit;
      end;
		PDF_TOK_KEYWORD:
      begin
			cmp := -1;
			a := -1;
			b := length(ps_op_names);
			while (b - a > 1)    do
			begin
				mid := (a + b) div 2;
				cmp := strcomp(buf, ps_op_names[mid]);
				if (cmp > 0) then
					a := mid
				else if (cmp < 0) then
					b := mid
				else
        begin
          if a=b then
          a:=1
          else
          a:=0;

        end;
			end;
			if (cmp <> 0) then
      begin
				result:= fz_throw('unknown operator: "%s"', [buf]);
        //result:=-1;
        exit;
      end;

			resize_code(func, codeptr^);
			psobj_s_items(func^.u.p.code)[codeptr^].type1 := ord(PS_OPERATOR);
			psobj_s_items(func^.u.p.code)[codeptr^].u.op := a;
			codeptr^:=codeptr^+1;
		end

		else
    begin
		  result:= fz_throw('calculator function syntax error');
      //result:=-1;
      exit;
    end;
		end;
	end;
end;

function load_postscript_func(func:ppdf_function_s; xref:ppdf_xref_s; dict:pfz_obj_s; num, gen:integer):integer;
var
	error:integer;
	stream:pfz_stream_s;
	codeptr:integer;
	buf:array[0..63] of char;
	tok:pdf_kind_e;
	len:integer;
begin
	error := pdf_open_stream(@stream, xref, num, gen);
	if (error<0)  then
  begin
		result:=fz_rethrow(error, 'cannot open calculator function stream');
    //result:=-1;
    exit;
  end;

	error := pdf_lex(@tok, stream, buf, sizeof(buf), @len);
	if (error<0)  then
	begin
		fz_close(stream);
		 result:= fz_rethrow(error, 'stream is not a calculator function');

      exit;
	end;

	if (tok <> PDF_TOK_OPEN_BRACE) then
	begin
		fz_close(stream);
		result:= fz_throw('stream is not a calculator function');
    exit;
	end;

	func^.u.p.code := nil;
	func^.u.p.cap := 0;

	codeptr := 0;
	error := parse_code(func, stream, @codeptr);
	if (error<0)  then
	begin
		fz_close(stream);
		result:= fz_rethrow(error, 'cannot parse calculator function (%d %d R)', [num, gen]);
    exit;
	end;

	fz_close(stream);
	result:=1;
end;

procedure eval_postscript_func(func:ppdf_function_s; inp, outp:psingle);
var
	st:ps_stack_s ;
	x:single;
  i:integer;
begin
	ps_init_stack(@st);

	for i := 0 to func^.m-1 do
	begin
		x := CLAMP(single_items(inp)[i], func^.domain[i][0], func^.domain[i][1]);
		ps_push_real(@st, x);
	end;

	ps_run(func^.u.p.code, @st, 0);

	for i := func^.n - 1 downto 0 do
	begin
		x := ps_pop_real(@st);
		single_items(outp)[i] := CLAMP(x, func^.range[i][0], func^.range[i][1]);
	end;
end;

(*
 * Sample function
 *)

function
load_sample_func(func:ppdf_function_s; xref:ppdf_xref_s; dict:pfz_obj_s;  num, gen:integer):integer;
var
	error:integer;
	stream:pfz_stream_s;
	obj:pfz_obj_s;
	samplecount:integer;
	bps:integer;
	i:integer;
   x:dword;
	s:single;
begin
	func^.u.sa.samples := nil;

	obj := fz_dict_gets(dict, 'Size');
	if (not fz_is_array(obj)) or  (fz_array_len(obj) <> func^.m) then
  begin
	  result:= fz_throw('malformed /Size');
    exit;
  end;
	for i := 0 to func^.m-1 do
		func^.u.sa.size[i] := fz_to_int(fz_array_get(obj, i));

	obj := fz_dict_gets(dict, 'BitsPerSample');
	if (not fz_is_int(obj)) then
  begin
		result:= fz_throw('malformed /BitsPerSample');
    exit;
  end;
  bps := fz_to_int(obj) ;
	func^.u.sa.bps := bps;

	obj := fz_dict_gets(dict, 'Encode');
	if (fz_is_array(obj)) then
	begin
		if (fz_array_len(obj) <> func^.m * 2) then
    begin
		 	result:= fz_throw('malformed /Encode');
        result:=-1;
    exit;
   end;

		for i := 0 to func^.m-1 do
		begin
			func^.u.sa.encode[i][0] := fz_to_real(fz_array_get(obj, i*2+0));
			func^.u.sa.encode[i][1] := fz_to_real(fz_array_get(obj, i*2+1));
		end;
	end
	else
	begin
		for i := 0 to func^.m-1 do
		begin
			func^.u.sa.encode[i][0] := 0;
			func^.u.sa.encode[i][1] := func^.u.sa.size[i] - 1;
		end;
	end;

	obj := fz_dict_gets(dict, 'Decode');
	if (fz_is_array(obj))  then
	begin
		if (fz_array_len(obj) <> func^.n * 2) then
    begin
			result:= fz_throw('malformed /Decode');
      exit;
    end;
		for i := 0 to func^.n-1 do
		begin
			func^.u.sa.decode[i][0] := fz_to_real(fz_array_get(obj, i*2+0));
			func^.u.sa.decode[i][1] := fz_to_real(fz_array_get(obj, i*2+1));
		end;
	end
	else
	begin
		for i := 0 to func^.n-1 do
		begin
			func^.u.sa.decode[i][0] := func^.range[i][0];
			func^.u.sa.decode[i][1] := func^.range[i][1];
		end;
	end;
  i:=0;
  samplecount := func^.n;
	while i < func^.m do
  begin
		samplecount :=samplecount * func^.u.sa.size[i];
    i:=i+1;
  end;

	func^.u.sa.samples := fz_calloc(samplecount, sizeof(single));

	error := pdf_open_stream(@stream, xref, num, gen);
	if (error<0)  then
  begin
	   result:=fz_rethrow(error, 'cannot open samples stream (%d %d R)', [num, gen]);
     exit;
   end;

	//* read samples */
	for i := 0 to samplecount-1 do
	begin


		if (fz_is_eof_bits(stream)) then
		begin
			fz_close(stream);
			result:= fz_throw('truncated sample stream');
      exit;
		end;

		case (bps) of
		1: s := fz_read_bits(stream, 1);
		2: s := fz_read_bits(stream, 2) / 3.0;
		4: s := fz_read_bits(stream, 4) / 15.0;
		8: s := fz_read_byte(stream) / 255.0;
		12: s := fz_read_bits(stream, 12) / 4095.0;
		16:
      begin
			x := fz_read_byte(stream) shl 8;
			x :=x or fz_read_byte(stream);
			s := x / 65535.0;
			end;
		24:
      begin
			x := fz_read_byte(stream) shl 16;
			x :=x or fz_read_byte(stream) shl 8;
			x :=x or fz_read_byte(stream);
			s := x / 16777215.0;
			end;
		32:
      begin
			x := fz_read_byte(stream) shl 24;
			x :=x or fz_read_byte(stream) shl 16;
			x :=x or fz_read_byte(stream) shl 8;
			x :=x or fz_read_byte(stream);
			s := x / 4294967295.0;
			end;
		 else
      begin
			fz_close(stream);
			result:= fz_throw('sample stream bit depth %d unsupported', [bps]);
      exit;
      end;
		end;

		single_items(func^.u.sa.samples)[i] := s;
	end;

	fz_close(stream);

	result:=1;
end;

function 
interpolate_sample(func:ppdf_function_s;scale, e0, e1:pinteger; efrac:psingle; dim, idx:integer) :single;
var
	a, b:single;
	idx0, idx1:integer;
begin
	idx0 := integer_items(e0)[dim] * integer_items(scale)[dim] + idx;
	idx1 := integer_items(e1)[dim] * integer_items(scale)[dim] + idx;

	if (dim = 0) then
	begin
		a := single_items(func^.u.sa.samples)[idx0];
		b := single_items(func^.u.sa.samples)[idx1];
	end
	else
	begin
		a := interpolate_sample(func, scale, e0, e1, efrac, dim - 1, idx0);
		b := interpolate_sample(func, scale, e0, e1, efrac, dim - 1, idx1);
	end;

	result:= a + (b - a) * single_items(efrac)[dim];
end;

procedure eval_sample_func(func:ppdf_function_s; inp,outp:psingle) ;
var
	 e0, e1, scale:array[0..MAXM-1] of integer;
	efrac:array[0..MAXM-1] of single;
	 x:single;
	i,s0,s1:integer;
  a,b,ab,c,d,cd,abcd:single;
begin
	//* encode input coordinates */
	for i := 0 to func^.m-1 do
	begin
		x := CLAMP(single_items(inp)[i], func^.domain[i][0], func^.domain[i][1]);
		x := lerp(x, func^.domain[i][0], func^.domain[i][1],
			func^.u.sa.encode[i][0], func^.u.sa.encode[i][1]);
		x := CLAMP(x, 0, func^.u.sa.size[i] - 1);
		e0[i] := floor(x);
		e1[i] := ceil(x);
		efrac[i] := x - floor(x);
	end;

	scale[0] := func^.n;
	for i := 1 to func^.m-1 do
		scale[i] := scale[i - 1] * func^.u.sa.size[i];

	for i := 0 to func^.n-1 do
	begin
		if (func^.m = 1) then
		begin
		 a := single_items(func^.u.sa.samples)[e0[0] * func^.n + i];
		 b := single_items(func^.u.sa.samples)[e1[0] * func^.n + i];

			ab := a + (b - a) * efrac[0];

			single_items(outp)[i]:= lerp(ab, 0, 1, func^.u.sa.decode[i][0], func^.u.sa.decode[i][1]);
			single_items(outp)[i] := CLAMP(single_items(outp)[i], func^.range[i][0], func^.range[i][1]);
		end

		else if (func^.m = 2) then
		begin
			s0 := func^.n;
			s1 := s0 * func^.u.sa.size[0];

			a := single_items(func^.u.sa.samples)[e0[0] * s0 + e0[1] * s1 + i];
			b := single_items(func^.u.sa.samples)[e1[0] * s0 + e0[1] * s1 + i];
			c := single_items(func^.u.sa.samples)[e0[0] * s0 + e1[1] * s1 + i];
			d := single_items(func^.u.sa.samples)[e1[0] * s0 + e1[1] * s1 + i];

			ab := a + (b - a) * efrac[0];
			cd := c + (d - c) * efrac[0];
			abcd := ab + (cd - ab) * efrac[1];

			single_items(outp)[i] := lerp(abcd, 0, 1, func^.u.sa.decode[i][0], func^.u.sa.decode[i][1]);
			single_items(outp)[i] := CLAMP(single_items(outp)[i], func^.range[i][0], func^.range[i][1]);
		end

		else
		begin
			x := interpolate_sample(func, @scale, @e0, @e1, @efrac, func^.m - 1, i);
			single_items(outp)[i] := lerp(x, 0, 1, func^.u.sa.decode[i][0], func^.u.sa.decode[i][1]);
			single_items(outp)[i] := CLAMP(single_items(outp)[i], func^.range[i][0], func^.range[i][1]);
		end;
	end;
end;

(*
 * Exponential function
 *)

function
load_exponential_func(func:ppdf_function_s;  dict:pfz_obj_s):integer;
var
	obj:pfz_obj_s;
	i:integer;
begin
	if (func^.m <> 1)  then
  begin
		result:= fz_throw('/Domain must be one dimension (%d)', [func^.m]);
    exit;
  end;

	obj := fz_dict_gets(dict, 'N');
	if (not fz_is_int(obj)) and (not fz_is_real(obj)) then
  begin
		result:= fz_throw('malformed /N');
    exit;
  end;


	func^.u.e.n := fz_to_real(obj);

	obj := fz_dict_gets(dict, 'C0');
	if (fz_is_array(obj)) then
	begin
		func^.n := fz_array_len(obj);
		if (func^.n >= MAXN) then
    begin
		 result:= fz_throw('exponential function result array out of range');
     exit;
    end;

		for i := 0 to func^.n-1 do
			func^.u.e.c0[i] := fz_to_real(fz_array_get(obj, i));
	end
	else
	begin
		func^.n := 1;
		func^.u.e.c0[0] := 0;
	end;

	obj := fz_dict_gets(dict, 'C1');
	if (fz_is_array(obj)) then
	begin
		if (fz_array_len(obj) <> func^.n) then
    begin
			result:= fz_throw('/C1 must match /C0 length');
      result:=-1;
      exit;
    end;
		for i := 0 to func^.n-1 do
			func^.u.e.c1[i] := fz_to_real(fz_array_get(obj, i));
	end
	else
	begin
		if (func^.n <> 1) then
    begin
			result:= fz_throw('/C1 must match /C0 length');
    exit;
    end;

		func^.u.e.c1[0] := 1;
	end;

	result:=1;
end;

procedure
eval_exponential_func(func:ppdf_function_s; inp:single; outp:psingle);
var
	x:single;
	tmp:single;
	i:integer;
begin
  x:=inp;
	x := CLAMP(x, func^.domain[0][0], func^.domain[0][1]);

	//* constraint */
	if ((func^.u.e.n <> func^.u.e.n) and (x < 0)) or ((func^.u.e.n < 0) and (x = 0)) then
	begin
		fz_warn('constraint error');
		exit;
	end;

	tmp := power(x, func^.u.e.n);
	for i := 0 to func^.n-1 do
	begin
		single_items(outp)[i] := func^.u.e.c0[i] + tmp * (func^.u.e.c1[i] - func^.u.e.c0[i]);
		if (func^.has_range<>0) then
			single_items(outp)[i] := CLAMP(single_items(outp)[i], func^.range[i][0], func^.range[i][1]);
	end;
end;

(*
 * Stitching function
 *)

function
load_stitching_func(func:ppdf_function_s; xref:ppdf_xref_s; dict:pfz_obj_s):integer;
var
	funcs:pppdf_function_s;
	error:integer;
	obj,sub,num:pfz_obj_s;
	k,i:integer;

begin
	func^.u.st.k := 0;

	if (func^.m <> 1) then
  begin
		result:= fz_throw('"/Domain must be one dimension (%d)',[ func^.m]);
    exit;
  end;

	obj := fz_dict_gets(dict, 'Functions');
	if (not fz_is_array(obj)) then
  begin
		result:= fz_throw('stitching function has no input functions');
    exit;
  end;
	begin
		k := fz_array_len(obj);

		func^.u.st.funcs := fz_calloc(k, sizeof(ppdf_function_s));   //??????
		func^.u.st.bounds := fz_calloc(k - 1, sizeof(single));
		func^.u.st.encode := fz_calloc(k * 2, sizeof(single));
		funcs := func^.u.st.funcs;

		for i := 0 to k-1 do
		begin
			sub := fz_array_get(obj, i);
			error := pdf_load_function(@ppdf_function_s_items(funcs)[i], xref, sub);
			if (error<0)  then
      begin
				result:= fz_rethrow(error, 'cannot load sub function %d (%d %d R)', [ i,fz_to_num(sub), fz_to_gen(sub)]);
        exit;
      end;
			if (ppdf_function_s_items(funcs)[i]^.m <> 1) or (ppdf_function_s_items(funcs)[i]^.n <> ppdf_function_s_items(funcs)[0]^.n) then
      begin
			 result:= fz_throw('sub function %d /Domain or /Range mismatch', [i]);
       exit;
      end;
			func^.u.st.k :=func^.u.st.k+1;
		end;

		if (func^.n=0) then
			func^.n := ppdf_function_s_items(funcs)[0]^.n
		else if (func^.n <> ppdf_function_s_items(funcs)[0]^.n) then
    begin
			result:= fz_throw('sub function /Domain or /Range mismatch');
      exit;
    end;
	end;

	obj := fz_dict_gets(dict, 'Bounds');
	if (not fz_is_array(obj)) then
  begin
	 	result:= fz_throw('stitching function has no bounds');

      exit;
  end;
	begin
		if (not fz_is_array(obj)) or (fz_array_len(obj) <> k - 1) then
    begin
			result:= fz_throw('malformed /Bounds (not array or wrong length)');
      exit;
    end;

		for i := 0 to k-1-1 do
		begin
			num := fz_array_get(obj, i);
			if (not fz_is_int(num)) and (not fz_is_real(num))  then
      begin
			   result:= fz_throw('malformed /Bounds (item not real)');
          exit;
      end;
			single_items(func^.u.st.bounds)[i] := fz_to_real(num);
			if (i<>0) and (single_items(func^.u.st.bounds)[i-1] > single_items(func^.u.st.bounds)[i])  then
      begin
				result:= fz_throw('malformed /Bounds (item not monotonic)');
        exit;
      end;
		end;

		if (k <> 1) and  ((func^.domain[0][0] > single_items(func^.u.st.bounds)[0]) or
			(func^.domain[0][1] < single_items(func^.u.st.bounds)[k-2])) then
      begin
		    fz_warn('malformed shading function bounds (domain mismatch), proceeding anyway.');

      end;
	end;

	obj := fz_dict_gets(dict, 'Encode');
	if (not fz_is_array(obj)) then
  begin
		result:= fz_throw('stitching function is missing encoding');
     exit;
  end;
	begin
		if (not fz_is_array(obj)) or (fz_array_len(obj) <> k * 2) then
    begin
			result:= fz_throw('malformed /Encode');
      exit;
    end;
		for i := 0 to k-1 do
		begin
			single_items(func^.u.st.encode)[i*2+0] := fz_to_real(fz_array_get(obj, i*2+0));
			single_items(func^.u.st.encode)[i*2+1] := fz_to_real(fz_array_get(obj, i*2+1));
		end;
	end;

	result:=1;
end;

procedure
eval_stitching_func(func:ppdf_function_s; inp:single; outp:psingle);
var
	low, high:single;
	k:integer;
	bounds:psingle;
	i:integer;
begin
  k := func^.u.st.k;
  bounds:= func^.u.st.bounds;
	inp := CLAMP(inp, func^.domain[0][0], func^.domain[0][1]);
  i:=0;
	for i := 0 to k - 2 do
	begin
		if (inp < single_items(bounds)[i])  then
			break;
	end;

	if (i = 0) and (k = 1) then
	begin
		low := func^.domain[0][0];
		high := func^.domain[0][1];
	end
	else if (i = 0) then
	begin
		low := func^.domain[0][0];
		high := single_items(bounds)[0];
	end
	else if (i = k - 1) then
	begin
		low := single_items(bounds)[k-2];
		high := func^.domain[0][1];
	end
	else
	begin
		low := single_items(bounds)[i-1];
		high := single_items(bounds)[i];
	end;

	inp := lerp(inp, low, high, single_items(func^.u.st.encode)[i*2+0], single_items(func^.u.st.encode)[i*2+1]);

	pdf_eval_function(ppdf_function_s_items(func^.u.st.funcs)[i], @inp, 1, outp, func^.n);
end;

(*
 * Common
 *)

function
pdf_keep_function(func:ppdf_function_s)  :ppdf_function_s;
begin
	func^.refs:=func^.refs+1;
	result:= func;
end;

procedure pdf_drop_function(func:ppdf_function_s);
var
	 i:integer;
   k:fz_pdfcolor_e;
begin
  func^.refs:=func^.refs-1;
	if (func^.refs = 0) then
	begin
    k:=fz_pdfcolor_e(func^.type1);
		case k of
		SAMPLE:
			fz_free(func^.u.sa.samples);

		EXPONENTIAL:
			dddd;
		STITCHING:
      begin
			for i := 0 to func^.u.st.k-1 do
				pdf_drop_function(ppdf_function_s_items(func^.u.st.funcs)[i]);
			fz_free(func^.u.st.funcs);
			fz_free(func^.u.st.bounds);
			fz_free(func^.u.st.encode);
			end;
	  POSTSCRIPT:
			fz_free(func^.u.p.code);

		end;
		fz_free(func);
	end;
end;

function pdf_load_function(funcp:pppdf_function_s; xref:ppdf_xref_s; dict:pfz_obj_s) :integer;
var
	error:integer;
	func:ppdf_function_s;
	obj:pfz_obj_s;
	i:integer;
  OO:fz_pdfcolor_e;
 begin
	funcp^ := pdf_find_item(xref^.store, @pdf_drop_function, dict);
  if (funcp^<>nil) then
	begin
		pdf_keep_function(funcp^);
		result:=1;
	end;

	func := fz_malloc(sizeof(pdf_function_s));
	fillchar(func^, sizeof(pdf_function_s), 0);
	func^.refs := 1;

	obj := fz_dict_gets(dict, 'FunctionType');
	func^.type1 := fz_to_int(obj);

	//* required for all */
	obj := fz_dict_gets(dict, 'Domain');
	func^.m := fz_array_len(obj) div 2;
	for i := 0 to func^.m-1 do
	begin
		func^.domain[i][0] := fz_to_real(fz_array_get(obj, i * 2 + 0));
		func^.domain[i][1] := fz_to_real(fz_array_get(obj, i * 2 + 1));
	end;

	//* required for type0 and type4, optional otherwise */
	obj := fz_dict_gets(dict, 'Range');
	if (fz_is_array(obj)) then
	begin
		func^.has_range := 1;
		func^.n := fz_array_len(obj) div 2;
		for i := 0 to func^.n-1 do
		begin
			func^.range[i][0] := fz_to_real(fz_array_get(obj, i * 2 + 0));
			func^.range[i][1] := fz_to_real(fz_array_get(obj, i * 2 + 1));
		end;
	end
	else
	begin
		func^.has_range := 0;
		func^.n := 0;
	end;

	if (func^.m >= MAXM) or (func^.n >= MAXN)  then
	begin
		fz_free(func);
		result:= fz_throw('assert: /Domain or /Range too big');
    result:=-1;
    exit;
	end;
  OO:=fz_pdfcolor_e(func^.type1);
	case oo of
	SAMPLE:
    begin
		error := load_sample_func(func, xref, dict, fz_to_num(dict), fz_to_gen(dict));
		if (error<0)  then
		begin
			pdf_drop_function(func);
			result:= fz_rethrow(error, 'cannot load sampled function (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
      exit;
		end;
		end;

  EXPONENTIAL:
    begin
		error := load_exponential_func(func, dict);
		if (error<0)  then
		begin
			pdf_drop_function(func);
			result:= fz_rethrow(error, 'cannot load exponential function (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
      exit;
		end;
	  end;

	STITCHING:
    begin
		error := load_stitching_func(func, xref, dict);
		if (error<0)  then
		begin
			pdf_drop_function(func);
			result:= fz_rethrow(error, 'cannot load stitching function (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
      exit;
		end;
		end;

	POSTSCRIPT:
    begin
		error := load_postscript_func(func, xref, dict, fz_to_num(dict), fz_to_gen(dict));
		if (error<0)  then
		begin
			pdf_drop_function(func);
			result:= fz_rethrow(error, 'cannot load calculator function (%d %d R)', [fz_to_num(dict), fz_to_gen(dict)]);
      exit;
		end;
	 end;

	else
    begin
		fz_free(func);
		result:= fz_throw('unknown function type (%d %d R)',[ fz_to_num(dict), fz_to_gen(dict)]);
    exit;
    end;
	end;

	pdf_store_item(xref^.store, @pdf_keep_function, @pdf_drop_function, dict, func);

	funcp^ := func;
	result:=1; //fz_okay;
end;

procedure pdf_eval_function(func:ppdf_function_s; inp:psingle; inlen:integer; outp:psingle; outlen:integer);
var
OO:fz_pdfcolor_e;
begin
	fillchar(outp^, sizeof(single) * outlen, 0);

	if (inlen <> func^.m) then
	begin
		fz_warn('tried to evaluate function with wrong number of inputs');
		exit;
	end;
	if (func^.n <> outlen) then
	begin
		fz_warn('tried to evaluate function with wrong number of outputs');
		exit;
	end;
  OO:=fz_pdfcolor_e(func^.type1);
	case oo of
	SAMPLE: eval_sample_func(func, inp, outp);
	EXPONENTIAL: eval_exponential_func(func, inp^, outp);
	STITCHING: eval_stitching_func(func, inp^, outp);
	POSTSCRIPT: eval_postscript_func(func, inp, outp);
	end;
end;




end.
F
