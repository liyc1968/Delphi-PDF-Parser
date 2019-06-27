unit draw_blendss;

interface
uses   SysUtils,Math,mylimits,digtypes;

procedure fz_blend_pixmap( dst:pfz_pixmap_s;src:pfz_pixmap_s; alpha, blendmode, isolated:integer; shape:pfz_pixmap_s);
function fz_find_blendmode(name:pchar):integer;
implementation
uses fz_pixmapss,base_object_functions;


function fz_find_blendmode(name:pchar):integer;
var
	i:integer;
begin
	for i := 0 to length(fz_blendmode_names)-1 do
		if (strcomp(name, pchar(fz_blendmode_names[i]))=0) then
    begin
			result:= i;
      exit;
    end;
	result:=FZ_BLEND_NORMAL;
end;

function fz_blendmode_name(blendmode:integer) :pchar;
begin
	if (blendmode >= 0) and (blendmode < length(fz_blendmode_names)) then
  begin
		result:=pchar(fz_blendmode_names[blendmode]);
    exit;
  end;
	result:='Normal';
end;

//* Separable blend modes */

function fz_screen_byte( b, s:integer):integer;
begin
	result:= b + s - fz_mul255(b, s);
end;

function fz_hard_light_byte( b, s:integer):integer;
var
s2:integer;
begin
	s2 := s shl 1;
	if (s <= 127) then
		result:= fz_mul255(b, s2)
	else
		result:=fz_screen_byte(b, s2 - 255);
end;

function fz_overlay_byte(b, s:integer):integer;
begin
	result:=fz_hard_light_byte(s, b); //* note swapped order */
end;

function fz_darken_byte( b, s:integer):integer;
begin
	result:= MIN(b, s);
end;

function fz_lighten_byte(b, s:integer):integer;
begin
	result:= MAX(b, s);
end;

function fz_color_dodge_byte(b, s:integer):integer;
begin
	s := 255 - s;
	if (b = 0) then
  begin
		result:= 0;
    exit;
  end
	else if (b >= s) then
  begin
		result:=255;
    exit;
  end
	else
		result:= trunc(($1fe * b + s) / (s shl 1));
end;

function fz_color_burn_byte(b, s:integer):integer;
begin
	b := 255 - b;
	if (b = 0) then
  begin
		result:= 255;
    exit;
  end
	else if (b >= s) then
	begin
		result:= 0;
    exit;
  end
	else
		result:= $ff - trunc(($1fe * b + s) / (s shl 1));
end;

function fz_soft_light_byte(b, s:integer):integer;
var
dbd:integer;
begin
	//* review this */
	if (s < 128) then
  begin
		result:= b - fz_mul255(fz_mul255((255 - (s shl 1)), b), 255 - b);
    exit;
	end
	else
  begin

		if (b < 64) then
			dbd := fz_mul255(fz_mul255((b shl 4) - 12, b) + 4, b)
		else
			dbd := trunc(sqrt(255.0 * b));
		result:= b + fz_mul255(((s shl 1) - 255), (dbd - b));
	end;
end;

function fz_difference_byte(b, s:integer):integer;
begin
	result:= ABS(b - s);
end;

function fz_exclusion_byte(b, s:integer):integer;
begin
	result:= b + s - (fz_mul255(b, s) shl 1);
end;

//* Non-separable blend modes */

procedure fz_luminosity_rgb(rd, gd, bd:pinteger;  rb, gb,  bb,  rs,  gs,  bs:integer);
var
	 delta, scale:integer;
	 r, g, b, y:integer;
   max1,min1:integer;
begin
	//* 0.3, 0.59, 0.11 in fixed point */
	delta := ((rs - rb) * 77 + (gs - gb) * 151 + (bs - bb) * 28 + $80) shr 8;
	r := rb + delta;
	g := gb + delta;
	b := bb + delta;

	if ((r or g or b) and $100)<>0 then
	begin
		y := (rs * 77 + gs * 151 + bs * 28 + $80) shr 8;
		if (delta > 0) then
		begin
			max1 := MAX(r,MAX(g, b));
			scale := trunc(((255 - y) shl 16) / (max1 - y));
		end
		else
		begin

			min1 := MIN(r, MIN(g, b));
			scale :=trunc( (y shl 16) / (y - min1));
		end;
		r := y + (((r - y) * scale + $8000) shr 16);
		g := y + (((g - y) * scale + $8000) shr 16);
		b := y + (((b - y) * scale + $8000) shr 16);
	end;

	rd^ := r;
	gd^ := g;
	bd^ := b;
end;

procedure
fz_saturation_rgb(rd, gd, bd:pinteger; rb,  gb,  bb,  rs,  gs,  bs:integer);
var
	 minb, maxb:integer;
	 mins, maxs:integer;
	 y:integer;
	 scale:integer;
	 r, g, b:integer;
    scalemin, scalemax:integer;
	  min1, max1:integer;
begin
	minb := MIN(rb, MIN(gb, bb));
	maxb := MAX(rb, MAX(gb, bb));
	if (minb = maxb) then
	begin
		//* backdrop has zero saturation, avoid divide by 0 */
		rd^ := gb;
		gd^ := gb;
		bd^ := gb;
		exit;
	end;

	mins := MIN(rs, MIN(gs, bs));
	maxs := MAX(rs, MAX(gs, bs));

	scale := trunc(((maxs - mins) shl 16) / (maxb - minb));
	y := (rb * 77 + gb * 151 + bb * 28 + $80) div 64;
	r := y + ((((rb - y) * scale) + $8000) div 65536);
	g := y + ((((gb - y) * scale) + $8000) div 65536);
	b := y + ((((bb - y) * scale) + $8000) div 65536);

	if ((r or g or b) and $100)<>0 then
	begin


		min1 := MIN(r, MIN(g, b));
		max1 := MAX(r, MAX(g, b));

		if (min1 < 0) then
			scalemin := trunc((y div 65536) / (y - min1))
		else
			scalemin := $10000;

		if (max1 > 255)  then
			scalemax := trunc(((255 - y) div 65536) / (max1 - y))
		else
			scalemax := $10000;

		scale := MIN(scalemin, scalemax);
		r := y + (((r - y) * scale + $8000) div 65536);
		g := y + (((g - y) * scale + $8000) div 65536);
		b := y + (((b - y) * scale + $8000) div 65536);
	end;

	rd^ := r;
	gd^ := g;
	bd^ := b;
end;

procedure fz_color_rgb(rr, rg, rb:pinteger; br, bg, bb, sr, sg, sb:integer);
begin
	fz_luminosity_rgb(rr, rg, rb, sr, sg, sb, br, bg, bb);
end;

procedure fz_hue_rgb(rr, rg, rb:pinteger;  br,  bg,  bb,  sr,  sg,  sb:integer);
var
	 tr, tg, tb:integer;
begin
	fz_luminosity_rgb(@tr, @tg, @tb, sr, sg, sb, br, bg, bb);
	fz_saturation_rgb(rr, rg, rb, tr, tg, tb, br, bg, bb);
end;

//* Blending loops */

procedure
fz_blend_separable( bp, sp:pbyte; n, w, blendmode:integer);
var
 k,n1:integer;
 sa,ba,saba,invsa,invba,sc,bc,rc :integer;
begin
  n1 := n - 1;
	while (w>0) do
  begin
    w:=w-1;
		 sa := byte_items(sp)[n1];
		 ba := byte_items(bp)[n1];
		 saba := fz_mul255(sa, ba);

	///* ugh, division to get non-premul components */
     if sa<>0 then
        invsa :=trunc(255 * 256 / sa)
        else
        invsa :=0;
     if ba<>0 then
        invba := trunc(255 * 256 / ba)
        else
        invba :=0;


		for k := 0 to n1-1 do
		begin
			sc := (byte_items(sp)[k] * invsa) shr 8;
			bc := (byte_items(bp)[k] * invba) shr 8;


			case blendmode of
			FZ_BLEND_NORMAL: rc := sc;
			FZ_BLEND_MULTIPLY: rc := fz_mul255(bc, sc);
			FZ_BLEND_SCREEN: rc := fz_screen_byte(bc, sc);
			FZ_BLEND_OVERLAY: rc := fz_overlay_byte(bc, sc);
			FZ_BLEND_DARKEN: rc := fz_darken_byte(bc, sc);
			FZ_BLEND_LIGHTEN: rc := fz_lighten_byte(bc, sc);
			FZ_BLEND_COLOR_DODGE: rc := fz_color_dodge_byte(bc, sc);
			FZ_BLEND_COLOR_BURN: rc := fz_color_burn_byte(bc, sc);
			FZ_BLEND_HARD_LIGHT: rc := fz_hard_light_byte(bc, sc);
			FZ_BLEND_SOFT_LIGHT: rc := fz_soft_light_byte(bc, sc);
			FZ_BLEND_DIFFERENCE: rc := fz_difference_byte(bc, sc);
			FZ_BLEND_EXCLUSION: rc := fz_exclusion_byte(bc, sc);
			end;

			byte_items(bp)[k] := fz_mul255(255 - sa, byte_items(bp)[k]) + fz_mul255(255 - ba, byte_items(sp)[k]) + fz_mul255(saba, rc);
		end;

	  byte_items(bp)[k] := ba + sa - saba;
    inc(sp,n);
    inc(bp,n);
	end;
end;

procedure fz_blend_nonseparable( bp,sp:pbyte; w, blendmode:integer);
var
   rr, rg, rb:integer;
   sa,ba,saba,invsa,invba ,sr, sg,sb,br,bg,bb:integer;

begin
	while (w>0) do
	begin
    w:=w-1;
		 sa := byte_items(sp)[3];
		 ba := byte_items(bp)[3];
		 saba := fz_mul255(sa, ba);

		//* ugh, division to get non-premul components */
    if sa<>0 then
		invsa := trunc(255 * 256 / sa)
    else
     invsa:= 0;
    if ba<>0 then
		invba := trunc( 255 * 256 / ba)
    else
     invba := 0;
    sr := ( byte_items(sp)[0] * invsa) shr 8;
		sg := ( byte_items(sp)[1] * invsa) shr 8;
		sb := ( byte_items(sp)[2] * invsa) shr 8;

		br := ( byte_items(bp)[0] * invba) shr 8;
		bg := (byte_items(bp)[1] * invba) shr 8;
		bb := (byte_items(bp)[2] * invba) shr 8;

		case (blendmode) of

		FZ_BLEND_HUE:
			fz_hue_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

		FZ_BLEND_SATURATION:
			fz_saturation_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

		FZ_BLEND_COLOR:
			fz_color_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

		FZ_BLEND_LUMINOSITY:
			fz_luminosity_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

		end;

		byte_items(bp)[0] := fz_mul255(255 - sa, byte_items(bp)[0]) + fz_mul255(255 - ba,  byte_items(sp)[0]) + fz_mul255(saba, rr);
		byte_items(bp)[1] := fz_mul255(255 - sa, byte_items(bp)[1]) + fz_mul255(255 - ba,  byte_items(sp)[1]) + fz_mul255(saba, rg);
		byte_items(bp)[2] := fz_mul255(255 - sa, byte_items(bp)[2]) + fz_mul255(255 - ba,  byte_items(sp)[2]) + fz_mul255(saba, rb);
		byte_items(bp)[3] := ba + sa - saba;
    inc(sp,4);
    inc(bp,4);

	end;
end;

procedure
fz_blend_separable_nonisolated( bp, sp:pbyte;  n,  w,  blendmode:integer;  hp:pbyte; alpha:integer);
var
	 k,n1:integer;
   ra,ha,haa,invha,invsa,invba:integer;
   sa,ba,sc,bc,rc,baha:integer;
begin
  n1 := n - 1;
	if (alpha = 255) and (blendmode = 0) then
	begin
		//* In this case, the uncompositing and the recompositing
		 //* cancel one another out, and it's just a simple copy. */
		//* FIXME: Maybe we can avoid using the shape plane entirely
		// * and just copy? */
		while (w>0) do
		begin
      w:=w-1;
			ha := fz_mul255(hp^, alpha); //* ha = shape_alpha */
      inc(hp);
			//* If ha == 0 then leave everything unchanged */
			if (ha <> 0) then
			begin
				for k := 0 to n-1 do
				begin
					byte_items(bp)[k] := byte_items(sp)[k];
				end;
			end;
      inc(sp,n);
      inc(bp,n);
		end;
		exit;
	end;
	while (w>0) do
	begin
    w:=w-1;
		ha := hp^;
    inc(hp);
		haa := fz_mul255(ha, alpha); //* ha = shape_alpha */
		//* If haa == 0 then leave everything unchanged */
		if (haa <> 0) then
		begin
			sa := byte_items(sp)[n1];
			 ba := byte_items(bp)[n1];
			baha := fz_mul255(ba, haa);

			//* ugh, division to get non-premul components */
		if sa<>0 then
		invsa := trunc(255 * 256 / sa)
    else
     invsa:= 0;
    if ba<>0 then
		invba := trunc( 255 * 256 / ba)
    else
     invba := 0;
			//* Calculate result_alpha */
      byte_items(bp)[n1] := ba - baha + haa;
			ra := byte_items(bp)[n1];

			(* Because we are a non-isolated group, we need to
			 * 'uncomposite' before we blend (recomposite).
			 * We assume that normal blending has been done inside
			 * the group, so:   ra.rc = (1-ha).bc + ha.sc
			 * A bit of rearrangement, and that gives us that:
			 *  sc = (ra.rc - bc)/ha + bc
			 * Now, the result of the blend was stored in src, so:
			 *)
       if ha<>0 then
			invha :=  trunc(255 * 256 / ha)
      else
       invha :=0;

			if (ra <> 0) then
      for k := 0 to n1-1 do
			begin
				sc := (byte_items(sp)[k] * invsa) shr 8;
				bc := (byte_items(bp)[k] * invba) shr 8;

				//* Uncomposite */
				sc := (((sc-bc)*invha) shr 8) + bc;
				if (sc < 0) then sc := 0;
				if (sc > 255) then sc := 255;

				case blendmode of
        FZ_BLEND_NORMAL: rc := sc;
				FZ_BLEND_MULTIPLY: rc := fz_mul255(bc, sc);
				FZ_BLEND_SCREEN: rc := fz_screen_byte(bc, sc);
				FZ_BLEND_OVERLAY: rc := fz_overlay_byte(bc, sc);
				FZ_BLEND_DARKEN: rc := fz_darken_byte(bc, sc);
				FZ_BLEND_LIGHTEN: rc := fz_lighten_byte(bc, sc);
				FZ_BLEND_COLOR_DODGE: rc := fz_color_dodge_byte(bc, sc);
				FZ_BLEND_COLOR_BURN: rc := fz_color_burn_byte(bc, sc);
				FZ_BLEND_HARD_LIGHT: rc := fz_hard_light_byte(bc, sc);
				FZ_BLEND_SOFT_LIGHT: rc := fz_soft_light_byte(bc, sc);
				FZ_BLEND_DIFFERENCE: rc := fz_difference_byte(bc, sc);
				FZ_BLEND_EXCLUSION: rc := fz_exclusion_byte(bc, sc);
				end;
				rc := fz_mul255(255 - haa, bc) + fz_mul255(fz_mul255(255 - ba, sc), haa) + fz_mul255(baha, rc);
				if (rc < 0) then rc := 0;
				if (rc > 255) then rc := 255;
				byte_items(bp)[k] := fz_mul255(rc, ra);
			end;
		end;

		inc(sp,n);
    inc(bp,n);
	end;
end;

procedure fz_blend_nonseparable_nonisolated( bp,  sp:pbyte;  w,  blendmode:integer;  hp:pbyte; alpha:integer);
var
   ha, haa:integer;
   rr, rg, rb:integer;
   invha,invsa,invba:integer;
   baha,sa,ba, ra,sr, sg ,sb, br , bg ,bb :integer;

begin
	while (w<>0) do
  begin
    w:=w-1;
		ha := hp^;
    inc(hp);
		haa := fz_mul255(ha, alpha);
		if (haa <> 0) then
		begin
			 sa := byte_items(sp)[3];
			 ba := byte_items(bp)[3];
			 baha := fz_mul255(ba, haa);

			//* Calculate result_alpha */
      byte_items(bp)[3] := ba - baha + haa;
			ra := byte_items(bp)[3];
			if (ra <> 0) then
			begin
				(* Because we are a non-isolated group, we
				 * need to 'uncomposite' before we blend
				 * (recomposite). We assume that normal
				 * blending has been done inside the group,
				 * so:     ra.rc = (1-ha).bc + ha.sc
				 * A bit of rearrangement, and that gives us
				 * that:   sc = (ra.rc - bc)/ha + bc
				 * Now, the result of the blend was stored in
				 * src, so: *)
        if ha<>0 then
            invha := trunc( 255 * 256 / ha)
            else
             invha:=0;
				//* ugh, division to get non-premul components */
      	if sa<>0 then
      		invsa := trunc(255 * 256 / sa)
        else
         invsa:= 0;
        if ba<>0 then
	     	invba := trunc( 255 * 256 / ba)
        else
        invba := 0;

				sr := (byte_items(sp)[0] * invsa) shr 8;
				sg := (byte_items(sp)[1] * invsa) shr 8;
				sb := (byte_items(sp)[2] * invsa) shr 8;

				br := (byte_items(bp)[0] * invba) shr 8;
				bg := (byte_items(bp)[1] * invba) shr 8;
				bb := (byte_items(bp)[2] * invba) shr 8;

				//* Uncomposite */

       sr := (((sr-br)*invha) div 256) + br;
				sg := (((sg-bg)*invha) div 256) + bg;
				sb := (((sb-bb)*invha) div 256) + bb;

//				sr := (((sr-br)*invha) shr 8) + br;
//				sg := (((sg-bg)*invha) shr 8) + bg;
//				sb := (((sb-bb)*invha) shr 8) + bb;

				case blendmode of
				FZ_BLEND_HUE:
					fz_hue_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

				FZ_BLEND_SATURATION:
					fz_saturation_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

				FZ_BLEND_COLOR:
					fz_color_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

				FZ_BLEND_LUMINOSITY:
					fz_luminosity_rgb(@rr, @rg, @rb, br, bg, bb, sr, sg, sb);

				end;

				rr := fz_mul255(255 - haa, byte_items(bp)[0]) + fz_mul255(fz_mul255(255 - ba, sr), haa) + fz_mul255(baha, rr);
				rg := fz_mul255(255 - haa, byte_items(bp)[1]) + fz_mul255(fz_mul255(255 - ba, sg), haa) + fz_mul255(baha, rg);
				rb := fz_mul255(255 - haa, byte_items(bp)[2]) + fz_mul255(fz_mul255(255 - ba, sb), haa) + fz_mul255(baha, rb);
				byte_items(bp)[0] := fz_mul255(ra, rr);
				byte_items(bp)[1] := fz_mul255(ra, rg);
				byte_items(bp)[2] := fz_mul255(ra, rb);
			end;
		end;
    inc(sp,4);
    inc(bp,4);
	end;
end;

procedure fz_blend_pixmap( dst:pfz_pixmap_s;src:pfz_pixmap_s; alpha, blendmode, isolated:integer; shape:pfz_pixmap_s);
var
	sp, dp,hp:pbyte;
	bbox:fz_bbox ;
	 x, y, w, h, n:integer;
begin
	//* TODO: fix this hack! */
	if (isolated<>0) and (alpha < 255) then
	begin
		sp := src^.samples;
		n := src^.w * src^.h * src^.n;
		while (n<>0) do
		begin
      n:=n-1;
			sp^ := fz_mul255(sp^, alpha);
			inc(sp);
		end;
	end;

	bbox := fz_bound_pixmap(dst);
	bbox := fz_intersect_bbox(bbox, fz_bound_pixmap(src));

	x := bbox.x0;
	y := bbox.y0;
	w := bbox.x1 - bbox.x0;
	h := bbox.y1 - bbox.y0;

	n := src^.n;
	sp := pointer(cardinal(src^.samples) + ((y - src^.y) * src^.w + (x - src^.x)) * n);
	dp := pointer(cardinal(dst^.samples) + ((y - dst^.y) * dst^.w + (x - dst^.x)) * n);

	assert(src^.n = dst^.n);

	if (isolated<>0) then
	begin
		  hp := pointer(cardinal(shape^.samples) + (y - shape^.y) * shape^.w + (x - shape^.x));

			while (h<>0) do
		begin
      h:=h-1;

			if (n = 4) and (blendmode >= FZ_BLEND_HUE) then
				fz_blend_nonseparable_nonisolated(dp, sp, w, blendmode, hp, alpha)
			else
				fz_blend_separable_nonisolated(dp, sp, n, w, blendmode, hp, alpha);
      inc(sp, src^.w * n);

		  inc(dp, dst^.w * n);
			inc(hp,shape^.w);
		end;
	end
	else
	begin
		while (h<>0) do
		begin
      h:=h-1;
			if (n = 4) and (blendmode >= FZ_BLEND_HUE) then
				fz_blend_nonseparable(dp, sp, w, blendmode)
			else
				fz_blend_separable(dp, sp, n, w, blendmode);

      inc(sp,src^.w * n);
      inc(dp,dst^.w * n);

		end;
	end;
end;




end.
