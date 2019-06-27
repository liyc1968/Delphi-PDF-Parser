unit draw_scaless;

interface
uses
SysUtils,Math,digtypes,mylimits,base_error;

type
row_scale1=procedure(dst:pinteger; src:pbyte; weights:pfz_weights_s);
function fz_scale_pixmap_gridfit(src:pfz_pixmap_s;  x,  y,  w,  h:single; gridfit:integer):pfz_pixmap_s;
function fz_scale_pixmap(src:pfz_pixmap_s;  x,  y,  w,  h:single) :pfz_pixmap_s;

implementation
uses base_object_functions,fz_pixmapss;
FUNCTION triangle(filter:pfz_scale_filter_s;  f:single):single;
begin
	if (f >= 1) then
		result:=0
    else
	 result:=1-f;
end;

function box(filter:pfz_scale_filter_s;  f:single):single;
begin
	if (f >= 0.5) then
		result:= 0
    else
    result:=1;
end;

function
simple(filter:pfz_scale_filter_s;  x:single):single;
begin
	if (x >= 1) then
		result:= 0
    else
    result:=1 + (2*x - 3)*x*x;
end;

function
lanczos2(filter:pfz_scale_filter_s;  x:single):single;
begin
	if (x >= 2) then
	 result:= 0
   else
	 result:=sin(M_PI*x) * sin(M_PI*x/2) / (M_PI*x) / (M_PI*x/2);
end;

function
lanczos3(filter:pfz_scale_filter_s;  f:single):single;
begin
	if (f >= 3)then
	 result:= 0
   else
	 result:= sin(M_PI*f) * sin(M_PI*f/3) / (M_PI*f) / (M_PI*f/3);
end;

function
mitchell(filter:pfz_scale_filter_s;  x:single):single;
begin
	if (x >= 2) then
  begin
		result:= 0;
    exit;
  end;
	if (x >= 1) then
  begin
		result:= (32 + x*(-60 + x*(36 - 7*x)))/18;
    exit;
  end;
 result:= (16 + x*x*(-36 + 21*x))/18;
end;

const
fz_scale_filter_box :fz_scale_filter_s= (width: 1; fn:box );
fz_scale_filter_triangle:fz_scale_filter_s = (width: 1;fn: triangle );
fz_scale_filter_simple :fz_scale_filter_s= ( width:1; fn:simple );
fz_scale_filter_lanczos2:fz_scale_filter_s = ( width:2;fn: lanczos2 );
fz_scale_filter_lanczos3:fz_scale_filter_s = ( width:3;fn: lanczos3 );
fz_scale_filter_mitchell:fz_scale_filter_s = ( width:2;fn: mitchell );


function
new_weights(filter:pfz_scale_filter_s; src_w:integer; dst_w:single; dst_w_i:integer; n:integer; flip:integer):pfz_weights_s;
var
	max_len:integer;
	weights:pfz_weights_s;
begin
	if (src_w > dst_w) then
	begin
		(* Scaling down, so there will be a maximum of
		 * 2*filterwidth*src_w/dst_w src pixels
		 * contributing to each dst pixel. *)
		max_len:= trunc(ceil((2 * filter^.width * src_w)/dst_w));
		if (max_len > src_w) then
			max_len := src_w;
	end
	else
	begin
		(* Scaling up, so there will be a maximum of
		 * 2*filterwidth src pixels contributing to each dst pixel.
		 *)
		max_len := 2 * filter^.width;
	end;
	(* We need the size of the struct,
	 * plus dst_w*sizeof(int) for the index
	 * plus (2+max_len)*sizeof(int) for the weights
	 * plus room for an extra set of weights for reordering.
	 *)
	weights := fz_malloc(sizeof(weights^)+(max_len+3)*(dst_w_i+1)*sizeof(integer));
	if (weights = Nil) then
  begin
		result:=nil;
    exit;
  end;
	weights^.count := -1;
	weights^.max_len := max_len;
	weights^.index[0] := dst_w_i;
	weights^.n := n;
	weights^.flip := flip;
	result:=weights;
end;

procedure init_weights(weights:pfz_weights_s; j:integer);
var
	index:integer;
begin
	assert(weights^.count = j-1);
	weights^.count:=weights^.count+1;
	weights^.new_line := 1;
	if (j = 0) then
		index := weights^.index[0]
	else
	begin
		index := weights^.index[j-1];
		index :=index + 2 + weights^.index[index+1];
	end;
	weights^.index[j] := index; //* row pointer */
	weights^.index[index] := 0; //* min */
	weights^.index[index+1] := 0; //* len */
end;

procedure add_weight(weights:pfz_weights_s;  j, i:integer; filter: pfz_scale_filter_s;
	 x,  F,  G:single; src_w:integer; dst_w:single);
var
  dist,ff:single;
  min, len, index, weight,k:integer;
begin
	dist := j - x + 0.5 - ((i + 0.5)*dst_w/src_w);
	dist :=dist * G;
	if (dist < 0) then
		dist := -dist;
	ff := filter^.fn(filter, dist)*F;
	weight := trunc((256*ff+0.5));
	if (weight = 0) then
		exit;


	if (i < 0) then
	begin
		i := 0;
		weight := 0;
	end
	else if (i >= src_w) then
	begin
		i := src_w-1;
		weight := 0;
	end;
	if (weight = 0) then
		exit;
 //	DBUG(("add_weight[%d][%d] = %d(%g) dist=%g\n",j,i,weight,f,dist));

	if (weights^.new_line<>0) then
	begin
		//* New line */
		weights^.new_line := 0;
		index := weights^.index[j]; //* row pointer */
		weights^.index[index] := i; //* min */
		weights^.index[index+1] := 0; //* len */
	end;
	index := weights^.index[j];
	min := weights^.index[index];
  index:=index+1;
	len := weights^.index[index];
  index:=index+1;
	while (i < min) do
	begin
		(* This only happens in rare cases, but we need to insert
		 * one earlier. In exceedingly rare cases we may need to
		 * insert more than one earlier. *)
		for k := len downto 1 do
		begin
			weights^.index[index+k] := weights^.index[index+k-1];
	 end;
		weights^.index[index] := 0;
		min:=min-1;
		len:=len+1;
		weights^.index[index-2] := min;
		weights^.index[index-1] := len;
	end;
	if (i-min >= len)  then
	begin
		//* The usual case */
    len:=len+1;
		while (i-min >=len) do
		begin
			weights^.index[index+len-1] := 0;
		end;
		assert(len-1 = i-min);
		weights^.index[index+i-min] := weight;
		weights^.index[index-1] := len;
		assert(len <= weights^.max_len);
	end
	else
	begin
		//* Infrequent case */
		weights^.index[index+i-min] :=weights^.index[index+i-min]+ weight;
	end;
end;

procedure
reorder_weights(weights:pfz_weights_s;  j, src_w:integer);
var
	idx:integer;
	min:integer;
	len :integer;
	max:integer;
	tmp :integer;
	i, off:integer;
begin
  idx := weights^.index[j];
	min := weights^.index[idx];
  idx:=idx+1;
	len := weights^.index[idx];
  idx:=idx+1;
	max := weights^.max_len;
	tmp := idx+max;
	//* Copy into the temporary area */
 //	copymemory(@weights^.index[tmp], @weights^.index[idx], sizeof(integer)*len);
 	move((@weights^.index[idx])^,(@weights^.index[tmp])^,  sizeof(integer)*len);

	//* Pad out if required */
	assert(len <= max);
	assert(min+len <= src_w);
	off := 0;
	if (len < max) then
	begin
		fillchar(weights^.index[tmp+len], sizeof(integer)*(max-len), 0);
		len := max;
		if (min + len > src_w) then
		begin
			off := min + len - src_w;
			min := src_w - len;
			weights^.index[idx-2] := min;
		end;
		weights^.index[idx-1] := len;
	end;

	//* Copy back into the proper places */
	for i := 0 to len-1 do
	begin
		weights^.index[idx+((min+i+off) mod max)] := weights^.index[tmp+i];
	end;
end;

(* Due to rounding and edge effects, the sums for the weights sometimes don't
 * add up to 256. This causes visible rendering effects. Therefore, we take
 * pains to ensure that they 1) never exceed 256, and 2) add up to exactly
 * 256 for all pixels that are completely covered. See bug #691629. *)
procedure
check_weights(weights:pfz_weights_s;   j,  w:integer;  x,  wf:single)  ;
var
	idx, len:integer;
	sum :integer;
	max :integer;
	maxidx:integer;
	i,v:integer;
begin
  sum := 0;
	max := -256;
	maxidx := 0;
	idx := weights^.index[j];
	idx:=idx+1; //* min */
	len := weights^.index[idx];
  idx:=idx+1;
	for i:=0 to len-1 do
	begin
		v := weights^.index[idx];
    idx:=idx+1;
		sum :=sum + v;
		if (v > max) then
		begin
			max := v;
			maxidx := idx;
		end;
	end;
 //	/* If we aren't the first or last pixel, OR if the sum is too big
	// * then adjust it. */
	if (((j <> 0) and (j <> w-1)) or (sum > 256)) then
		weights^.index[maxidx-1] :=weights^.index[maxidx-1] + 256-sum
	//* Otherwise, if we are the first pixel, and it's fully covered, then
	// * adjust it. */
	else if ((j = 0) and (x < 0.0001) and (sum <> 256)) then
		weights^.index[maxidx-1] := weights^.index[maxidx-1]+256-sum
	//* Finally, if we are the last pixel, and it's fully covered, then
	 //* adjust it. */
	else if ((j = w-1) and (w-wf < 0.0001) and (sum <> 256)) then
		weights^.index[maxidx-1] :=weights^.index[maxidx-1] + 256-sum;
 //	DBUG(("total weight %d = %d\n", j, sum));
end;

function
make_weights( src_w:integer;  x,  dst_w:single; filter:pfz_scale_filter_s; vertical, dst_w_int, n, flip:integer):pfz_weights_s;
var
	weights:pfz_weights_s;
	 F, G,centre:single;
	 window:single;
	 j,l, r:integer;
begin
	if (dst_w < src_w)  then
	begin
		//* Scaling down */
		F := dst_w / src_w;
		G := 1;
	end
	else
	begin
		//* Scaling up */
		F := 1;
		G := src_w / dst_w;
	end;
	window := filter^.width / F;
	//DBUG(("make_weights src_w=%d x=%g dst_w=%g dst_w_int=%d F=%g window=%g\n", src_w, x, dst_w, dst_w_int, F, window));
	weights:= new_weights(filter, src_w, dst_w, dst_w_int, n, flip);
	if (weights = nil) then
  begin
		result:= nil;
    exit;
  end;
	for j := 0 to dst_w_int-1 do
	begin
		//* find the position of the centre of dst[j] in src space */
		 centre := (j - x + 0.5)*src_w/dst_w - 0.5;
		l := ceil(centre - window);
		r := floor(centre + window);
	 //	DBUG(("%d: centre=%g l=%d r=%d\n", j, centre, l, r));
		init_weights(weights, j);
    while  l <= r do
		begin

			add_weight(weights, j, l, filter, x, F, G, src_w, dst_w);
      l:=l+1;
		end;
		check_weights(weights, j, dst_w_int, x, dst_w);
		if (vertical<>0) then
		begin
			reorder_weights(weights, j, src_w);
		end;
	end;
	weights^.count:=weights^.count+1; //* weights^.count = dst_w_int now */
	result:= weights;
end;

procedure
scale_row_to_temp(dst:pinteger; src:pbyte; weights: pfz_weights_s);
var
	contrib:pinteger;
	len, i, j, n:integer;
	min:pbyte;
begin
  contrib := @weights^.index[weights^.index[0]];
	n := weights^.n;
	if (weights^.flip<>0) then
	begin
		inc(dst,(weights^.count-1)*n);
		for i:=weights^.count downto 1 do
		begin
			min := pointer(cardinal(src)+n * contrib^);
      inc(contrib);
			len := contrib^;
      inc(contrib);
			for j := 0 to n-1 do
				integer_items(dst)[j] := 0;
			while (len > 0)  do
			begin
        len:=len-1;
				for j := n downto 1 do
        begin
           dst^:=dst^+min^*contrib^;
           inc(dst);
           inc(min);
        	//*dst++ += *min++ * *contrib;
        end;
				inc(dst, - n);

				inc(contrib);
			end;
			inc(dst, -n);
		end;
	end
	else
	begin
		for i:=weights^.count downto 1 do
		begin
      min := pointer(cardinal(src)+n * contrib^);
      inc(contrib);

			len := contrib^;
      inc(contrib);
			for j := 0 to n-1 do
				integer_items(dst)[j] := 0;
			while (len > 0) do
			begin
        len:=len-1;
				for j := n downto 1 do
        begin
					//*dst++ += *min++ * *contrib;
            dst^:=dst^+min^*contrib^;
           inc(contrib);
           inc(min);
        end;
				inc(dst,-n);
				inc(contrib);
			end;
			inc(dst,n);
		end;
	end;
end;

procedure
scale_row_to_temp1(dst:pinteger; src:pbyte; weights:pfz_weights_s);
var
	contrib:pinteger;
	len, i,val:integer;
	min:pbyte;
begin
  contrib := @weights^.index[weights^.index[0]];
	assert(weights^.n = 1);
	if (weights^.flip<>0) then
	begin
		inc(dst, weights^.count);
		for i:=weights^.count downto 1 do
		begin
		  val := 0;
       min := pointer(cardinal(src)+contrib^);
			 inc(contrib);
			len := contrib^;
      inc(contrib);
			while (len > 0) do
			begin
        len:=len-1;
				val :=val + min^* contrib^;
         inc( min);
           inc(contrib);
			end;
      inc(dst,-1);
      dst^:=val;
		end;
	end
	else
	begin
		for i:=weights^.count downto 1 do
		begin
			val := 0;
		  min := pointer(cardinal(src)+contrib^);
      inc(contrib);
			len := contrib^;
      inc(contrib);
			while (len > 0) do
			begin
        len:=len-1;
				val :=val + min^ * contrib^;
        inc( min);
        inc(contrib);
			end;
			dst^ := val;
      inc(dst);
		end;
	end;
end;

procedure scale_row_to_temp2(dst:pinteger; src:pbyte; weights:pfz_weights_s);
var
	 contrib:pinteger;
	 len, i:integer;
	 min:pbyte;
   c1,c2:integer;
begin
  contrib := @weights^.index[weights^.index[0]];
	assert(weights^.n = 2);
	if (weights^.flip<>0) then
	begin
		inc(dst, 2*weights^.count);
		for i:=weights^.count downto 1 do
		begin
      min := pointer(cardinal(src)+2*contrib^);
      inc(contrib);
			len := contrib^;
      inc(contrib);
			while (len > 0) do
			begin
        len:=len-1;
				c1 :=c1 + min^ * contrib^;

        inc(min);
				c2 :=c2 + min^ * contrib^;
        inc(contrib);
        inc(min);
			end;
      inc(dst,-1);
      dst^:=c2;
      inc(dst,-1);
      dst^:=c1;
		end;
	end
	else
	begin
		for i:=weights^.count downto 1 do
		begin
			 c1 := 0;
			 c2 := 0;
		 min := pointer(cardinal(src)+2*contrib^);
      inc(contrib);
			len := contrib^;
      inc(contrib);
			while (len > 0) do
			begin
        len:=len-1;
				c1 := c1 +min^ * contrib^;

        inc(min);
				c2 := c2 + min^ * contrib^;
         inc(contrib);
        inc(min);
			end;
      dst^:=c1;
      inc(dst);
      dst^:=c2;
      inc(dst);

		end;
	end;
end;

procedure
scale_row_to_temp4(dst:pinteger; src:pbyte; weights:pfz_weights_s);
var
	contrib:pinteger;
  len, i:integer;
	min:pbyte;
  r,g,b,a:integer;
begin
  contrib := @weights^.index[weights^.index[0]];
	assert(weights^.n = 4);
	if (weights^.flip<>0) then
	begin
		inc(dst, 4*weights^.count);

		for i:=weights^.count downto 1 do
		begin
			r := 0;
			g := 0;
			b := 0;
			a := 0;

      min := pointer(cardinal(src)+4*contrib^);
      inc( contrib);
			len := contrib^;
       inc( contrib);
			while (len> 0) do
			begin
        len:=len-1;
				r :=r + min^ * contrib^;
        inc(min);
				g :=g + min^ * contrib^;
        inc(min);
				b :=b + min^ * contrib^;
        inc(min);
				a :=a + min^ * contrib^;
        inc(min);
        inc(contrib);
			end;
      inc(dst,-1);
      dst^:=a;
      inc(dst,-1);
      dst^:=b;
      inc(dst,-1);
      dst^:=g;
      inc(dst,-1);
      dst^:=r;
			
		end;

	end
	else
	begin

		for i:=weights^.count downto 1 do
		begin
			 r := 0;
			 g := 0;
			 b := 0;
			 a := 0;
			 min := pointer(cardinal(src)+4*contrib^);
      inc( contrib);
			len := contrib^;
       inc( contrib);
			while (len> 0) do
			begin
        len:=len-1;
				r :=r + min^ * contrib^;
        inc(min);
				g :=g + min^ * contrib^;
        inc(min);
				b :=b + min^ * contrib^;
        inc(min);
				a :=a + min^ * contrib^;
        inc(min);
        inc(contrib);
			end;
      dst^:=r;
      inc(dst);
      dst^:=g;
      inc(dst);
      dst^:=b;
      inc(dst);
      dst^:=a;
      inc(dst);
			
		end;

	end;
end;

procedure scale_row_from_temp(dst:pbyte; src:pinteger; weights:pfz_weights_s;  width, row:integer);
var
	contrib,min,contrib2:pinteger;
	val,len2,len, x:integer;

begin
  contrib := @weights^.index[weights^.index[row]];
  inc( contrib);
 //	contrib++; //* Skip min */
	len := contrib^;
  inc( contrib);
	for x:=width downto 1 do
	begin
		min := src;
		val := 0;
		len2 := len;
		contrib2 := contrib;

		while (len2> 0) do
		begin
      len2:=len2-1;
			val :=val + min^ * contrib2^;
      inc(contrib2);
      INC(min , width);
	 //		val :=val + width;
		end;
		val := (val+(1 shl 15)) shr 16;
		if (val < 0) then
			val := 0
		else if (val > 255)  then
			val := 255;
    dst^:=val;
    inc(dst);
		inc(src);
	end;
end;


procedure duplicate_single_pixel(dst:pbyte; src:pbyte;  n, w, h:integer);
var
	 i:integer;
begin
	for i := n downto 1 do
  begin
    dst^:=src^;
		inc(dst);
    inc(src);
  end;
	for i := (w*h-1)*n downto 1 do
	begin
		dst^ :=byte_items(dst)[-n];
		inc(dst);
	end;
end;

procedure
scale_single_row(dst:pbyte; src:pbyte; weights:pfz_weights_s; src_w, h:integer);
var
	contrib:pinteger;
	min, len, i, j, val, n:integer;
	tmp:array[0..FZ_MAX_COLORS-1]of integer;
begin
  contrib := @weights^.index[weights^.index[0]];
	n := weights^.n;
	//* Scale a single row */
	if (weights^.flip<>0) then
	begin
		inc(dst,(weights^.count-1)*n);
		for i:=weights^.count-1 downto 1 do
		begin
			min := contrib^;
      inc(contrib);
			len := contrib^;
      inc(contrib);
			min:=min * n;
			for j := 0 to n-1 do
				tmp[j] := 0;
			while (len> 0) do
			begin
        len:=len-1;
				for j := 0 to n-1 do
        begin
					tmp[j] :=tmp[j] + byte_items(src)[min] * contrib^;
          min:=min+1;
        end;
				inc(contrib);
			end;
			for j := 0 to n-1 do
			begin
				val := (tmp[j]+(1 shl 7))shr 8;
				if (val < 0) then
					val := 0
				else if (val > 255)  then
					val := 255;

				dst^ := val;
        inc(dst);
			end;
			inc(dst, -2*n);
		end;
		inc(dst, n * (weights^.count+1));
	end
	else
	begin
		for i:=weights^.count  downto 1 do
		begin
			min := contrib^;
      inc(contrib);
			len :=contrib^;
      inc(contrib);
			min :=min * n;
			for j := 0 to n-1 do
				tmp[j] := 0;
			while (len > 0) do
			begin
        len:=len-1;
				for j := 0  to n-1 do
        begin
					tmp[j] :=tmp[j]+ byte_items(src)[min] * contrib^;
          min:=min+1;
        end;
				inc(contrib);
			end;
			for j := 0 to n-1 do
			begin
				val := (tmp[j]+(1 shl 7)) shr 8;
				if (val < 0) then
					val := 0
				else if (val > 255)  then
					val := 255;
				dst^:= val;
        inc(dst);
			end;
		end;
	end;
	//* And then duplicate it h times */
	n :=n * weights^.count;
  h:=h-1;
	while (h > 0) do
	begin
    h:=h-1;
    move(pointer(cardinal(dst)-n)^,dst^,  n);
		inc(dst,n);
	end;
end;

procedure
scale_single_col(dst:pbyte; src:pbyte; weights:pfz_weights_s; src_w, n, w, flip_y:integer);
var
	contrib:pinteger;
	 min, len, i, j, val:integer;
	 tmp:array[0..FZ_MAX_COLORS-1] of integer;
begin
  contrib := @weights^.index[weights^.index[0]];
	if (flip_y<>0) then
	begin
		src_w := (src_w-1)*n;
		w := (w-1)*n;
		for i:=weights^.count downto 1 do
		begin
			//* Scale the next pixel in the column */
			min := contrib^;
      inc(contrib);
			len := contrib^;
      inc(contrib);
			min := src_w-min*n;
			for j := 0 to  n-1 do
				tmp[j] := 0;
			while (len > 0) do
			begin
        len:=len-1;
				for j := 0 to n-1 do
					tmp[j] :=tmp[j]+ byte_items(src)[src_w-min+j] * contrib^;
        inc(contrib);
			end;
			for j := 0 to n-1 do
			begin
				val := (tmp[j]+(1 shl 7)) shr 8;
				if (val < 0) then
					val := 0
				else if (val > 255) then
					val := 255;
          dst^:=val;
          inc(dst);

			end;
			//* And then duplicate it across the row */
			for j := w downto 1 do
			begin
				dst^ := byte_items(dst)[-n];
				inc(dst);
			end;
		end;
	end
	else
	begin
		w := (w-1)*n;
		for i:=weights^.count downto 1 do
		begin
			//* Scale the next pixel in the column */
			min := contrib^;
      inc(contrib);
			len := contrib^;
      inc(contrib);
			min :=min * n;
			for j := 0 to n-1 do
				tmp[j] := 0;
			while (len > 0) do
			begin
        len:=len-1;
				for j := 0 to n-1 do
        begin
					tmp[j] :=tmp[j]+ byte_items(src)[min] * contrib^;
          min:=min+1;
        end;
				inc(contrib);
			end;
			for j := 0 to n-1 do
			begin
				val := (tmp[j]+(1 shl 7)) shr 8;
				if (val < 0) then
					val := 0
				else if (val > 255) then
					val := 255;
				dst^ := val;
        inc(dst);
			end;
			//* And then duplicate it across the row */
			for j := w downto 1 do
			begin
				dst^ := byte_items(dst)[-n];
				inc(dst);
			end;
		end;
	end;
end;


function fz_scale_pixmap_gridfit(src:pfz_pixmap_s;  x,  y,  w,  h:single; gridfit:integer):pfz_pixmap_s;
var
n:single;
begin
	if (gridfit<>0) then
  begin
		if (w > 0) then
    begin
			//* Adjust the left hand edge, leftwards to a pixel boundary */
			n := trunc(x);   //* n is now on a pixel boundary */
			if (n > x) then          //* Ensure it's the pixel boundary BELOW x */
				n :=n - 1.0;
			w :=w +x-n;            //* width gets wider as x >= n */
			x := n;
			//* Adjust the right hand edge rightwards to a pixel boundary */
			n := trunc(w);   //* n is now the integer width <= w */
			if (n <> w) then          //* If w isn't an integer already, bump it */
				w := 1.0 + n;  //* up to the next integer. */
		 end
     else
     begin
			//* Adjust the right hand edge, rightwards to a pixel boundary */
			n := trunc(x);   //* n is now on a pixel boundary */
			if (n > x) then          //* Ensure it's the pixel boundary <= x */
				n :=n - 1.0;
			if (n <> x) then         //* If x isn't on a pixel boundary already, */
				n :=n + 1.0;   //* make n be the pixel boundary above x. */
			w :=w - (n-x);            //* Expand width (more negative!) as n >= x */
			x := n;
			//* Adjust the left hand edge leftwards to a pixel boundary */
			n := trunc(w);
			if (n <> w) then
				w := n - 1.0;
	  end;
		if (h > 0)  then
    begin
			//* Adjust the bottom edge, downwards to a pixel boundary */
			n := trunc(y);   //* n is now on a pixel boundary */
			if (n > y) then          //* Ensure it's the pixel boundary BELOW y */
				n :=n - 1.0;
			h :=h + y-n;            //* height gets larger as y >= n */
			y := n;
			//* Adjust the top edge upwards to a pixel boundary */
			n := trunc(h);   //* n is now the integer height <= h */
			if (n <> h)then          //* If h isn't an integer already, bump it */
				h := 1.0 + n;  //* up to the next integer. */
		end
    else
    begin
			//* Adjust the top edge, upwards to a pixel boundary */
			n := trunc(y);   //* n is now on a pixel boundary */
			if (n > y) then          //* Ensure it's the pixel boundary <= y */
			n :=n - 1.0;
			if (n <> y) then         //* If y isn't on a pixel boundary already, */
				n :=n + 1.0;   //* make n be the pixel boundary above y. */
			h :=h - (n-y);            //*/ Expand height (more negative!) as n >= y */
			y := n;
			//* Adjust the bottom edge downwards to a pixel boundary */
			n := trunc(h);
			if (n <> h) then
				h := n - 1.0;
		end;
	end;
	result:=fz_scale_pixmap(src, x, y, w, h);
end;

function fz_scale_pixmap(src:pfz_pixmap_s;  x,  y,  w,  h:single) :pfz_pixmap_s;
var
	 filter :pfz_scale_filter_s;
	contrib_rows :pfz_weights_s;
	contrib_cols :pfz_weights_s;
	output:pfz_pixmap_s;
	temp:pinteger;
	 max_row, temp_span, temp_rows, row:integer;
	 dst_w_int, dst_h_int, dst_x_int, dst_y_int:integer;
	flip_x, flip_y:integer;
  tmp:single;
   row_index , row_min, row_len:integer;
   row_scale:row_scale1;
    ppp:integer;
  label cleanup;
begin
  filter := @fz_scale_filter_simple;
	contrib_rows := nil;
	contrib_cols := nil;
	output := nil;
	temp := nil;

	//DBUG(("Scale: (%d,%d) to (%g,%g) at (%g,%g)\n",src^.w,src^.h,w,h,x,y));
  //fz_warn('Scale: (%d,%d) to (%10.2f,%10.2f) at (%10.2f,%10.2f)\n',[src^.w,src^.h,w,h,x,y]) ;

	(* Find the destination bbox, width/height, and sub pixel offset,
	 * allowing for whether we're flipping or not. */
	/* Note that the x and y sub pixel offsets here are different.
	 * The (x,y) position given describes where the bottom left corner
	 * of the source image should be mapped to (i.e. where (0,h) in image
	 * space ends up, not the more logical and sane (0,0)). Also there
	 * are differences in the way we scale horizontally and vertically.
	 * When scaling rows horizontally, we always read forwards through
	 * the source, and store either forwards or in reverse as required.
	 * When scaling vertically, we always store out forwards, but may
	 * feed source rows in in a different order.
	 *
	 * Consider the image rectange 'r' to which the image is mapped,
	 * and the (possibly) larger rectangle 'R', given by expanding 'r' to
	 * complete pixels.
	 *
	 * x can either be r.xmin-R.xmin or R.xmax-r.xmax depending on whether
	 * the image is x flipped or not. Whatever happens 0 <= x < 1.
	 * y is always R.ymax - r.ymax.
	 */
	/* dst_x_int is calculated to be the left of the scaled image, and
	 * x (the sub_pixel_offset) is the distance in from either the left
	 * or right pixel expanded edge. *)
   flip_x:=0;
   if w<0 then
     flip_x:=1;

	if (flip_x<>0) then
	begin

		w := -w;
		dst_x_int := floor(x-w);
		tmp := ceil(x);
		dst_w_int :=trunc(tmp);
		x := tmp - x;
		dst_w_int :=dst_w_int - dst_x_int;
	end
	else
	begin
		dst_x_int := floor(x);
		x :=x - dst_x_int;
		dst_w_int := ceil(x + w);
	end;

  flip_Y:=0;
   if h<0 then
     flip_Y:=1;
	(* dst_y_int is calculated to be the bottom of the scaled image, but
	 * y (the sub pixel offset) has to end up being the value at the top.
	 *)
	if (flip_y<>0) then
	begin
		h := -h;
		dst_y_int := floor(y-h);
		dst_h_int := ceil(y) - dst_y_int;
	end
  else
  begin
		dst_y_int := floor(y);
		y :=y + h;
		dst_h_int := ceil(y) - dst_y_int;
	end;
	(* y is the top edge position in floats. We want it to be the
	 * distance down from the next pixel boundary. *)
	y := ceil(y) - y;

//	DBUG(("Result image: (%d,%d) at (%d,%d) (subpix=%g,%g)\n", dst_w_int, dst_h_int, dst_x_int, dst_y_int, x, y));

	//* Step 1: Calculate the weights for columns and rows */

	if (src^.w = 1) then
	begin
		contrib_cols := nil;
	end
	else

	begin
		contrib_cols := make_weights(src^.w, x, w, filter, 0, dst_w_int, src^.n, flip_x);
		if (contrib_cols = Nil) then
			goto cleanup;
	end;

	if (src^.h = 1) then
	begin
		contrib_rows := nil;
	end
	else

	begin
		contrib_rows := make_weights(src^.h, y, h, filter, 1, dst_h_int, src^.n, flip_y);
		if (contrib_rows =nil)  then
			goto cleanup;
	end;

	assert((contrib_cols = NiL) or (contrib_cols^.count = dst_w_int));
	assert((contrib_rows =NiL) or ( contrib_rows^.count = dst_h_int));
	output := fz_new_pixmap(src^.colorspace, dst_w_int, dst_h_int);
	output^.x := dst_x_int;
	output^.y := dst_y_int;

	//* Step 2: Apply the weights */

	if (contrib_rows =nil) then
	begin
		//* Only 1 source pixel high. */
		if (contrib_cols =nil) then
		begin
			//* Only 1 pixel in the entire image! */
			duplicate_single_pixel(output^.samples, src^.samples, src^.n, dst_w_int, dst_h_int);
		end
		else
		begin
		 //	/* Scale the row once, then copy it. */
			scale_single_row(output^.samples, src^.samples, contrib_cols, src^.w, dst_h_int);
		end;
	end
	else if (contrib_cols = nil) then
	begin
		//* Only 1 source pixel wide. Scale the col and duplicate. */
		scale_single_col(output^.samples, src^.samples, contrib_rows, src^.h, src^.n, dst_w_int, flip_y);
	end
	else

	begin


		temp_span := contrib_cols^.count * src^.n;
		temp_rows := contrib_rows^.max_len;
		if (temp_span <= 0) or (temp_rows > INT_MAX / temp_span) then
			goto cleanup;
		temp := fz_calloc(temp_span*temp_rows, sizeof(integer));
		if (temp = nil) then
			goto cleanup;
		case  (src^.n) of
		 1: //* Image mask case */
			row_scale := scale_row_to_temp1;

		  2: //* Greyscale with alpha case */
			row_scale := scale_row_to_temp2;
		 4: //* RGBA */
			row_scale := scale_row_to_temp4;
		 else
			row_scale := scale_row_to_temp;

		end;
		max_row := 0;
		for row := 0 to contrib_rows^.count-1 do
		begin
			(*
			Which source rows do we need to have scaled into the
			temporary buffer in order to be able to do the final
			scale?
			*)
			row_index := contrib_rows^.index[row];
			row_min := contrib_rows^.index[row_index];
       row_index:=row_index+1;
			row_len := contrib_rows^.index[row_index];
      row_index:=row_index+1;
			while (max_row < row_min+row_len) do
			begin
				//* Scale another row */
				assert(max_row < src^.h);
				//DBUG(("scaling row %d to temp\n", max_row));
        if flip_y<>0 then
        ppp:=src^.h-1-max_row
        else
        ppp:=max_row;
        row_scale(@integer_items(temp)[temp_span*(max_row mod temp_rows)], pointer(cardinal(src^.samples)+ppp*src^.w*src^.n), contrib_cols);
		 //	 row_scale(@temp[temp_span*(max_row mod temp_rows)], @src^.samples[(flip_y ? (src^.h-1-max_row): max_row)*src^.w*src^.n], contrib_cols);
				max_row:=max_row+1;
			end;
			//DBUG(("scaling row %d from temp\n", row));
			scale_row_from_temp(pointer(cardinal(output^.samples)+row*output^.w*output^.n), temp, contrib_rows, temp_span, row);
		end;
		fz_free(temp);
	end;

cleanup:
	fz_free(contrib_rows);
	fz_free(contrib_cols);
	result:= output;
end;



end.

