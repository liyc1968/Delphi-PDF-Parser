unit dev_listss;

interface
uses digtypes,base_object_functions;

const STACK_SIZE= 96;
      ISOLATED = 1;
      KNOCKOUT = 2 ;
type
 fz_display_command_e=
(
	FZ_CMD_FILL_PATH,
	FZ_CMD_STROKE_PATH,
	FZ_CMD_CLIP_PATH,
	FZ_CMD_CLIP_STROKE_PATH,
	FZ_CMD_FILL_TEXT,
	FZ_CMD_STROKE_TEXT,
	FZ_CMD_CLIP_TEXT,
	FZ_CMD_CLIP_STROKE_TEXT,
	FZ_CMD_IGNORE_TEXT,
	FZ_CMD_FILL_SHADE,
	FZ_CMD_FILL_IMAGE,
	FZ_CMD_FILL_IMAGE_MASK,
	FZ_CMD_CLIP_IMAGE_MASK,
	FZ_CMD_POP_CLIP,
	FZ_CMD_BEGIN_MASK,
	FZ_CMD_END_MASK,
	FZ_CMD_BEGIN_GROUP,
	FZ_CMD_END_GROUP,
	FZ_CMD_BEGIN_TILE,
	FZ_CMD_END_TILE
) ;

type
itmmmss=record
case integer of
1: (path:pfz_path_s;);
2: (text:pfz_text_s;);
3: (shade:pfz_shade_s;);
4:  (image:pfz_pixmap_s;);
5: (blendmode:integer;);
end;

type
 pfz_display_node_s=^fz_display_node_s;
 fz_display_node_s=record
 cmd:fz_display_command_e;
	next:pfz_display_node_s;
	rect:fz_rect;
	item:itmmmss;
	stroke:pfz_stroke_state_s;
	flag:integer; //* even_odd, accumulate, isolated/knockout... */
	ctm:fz_matrix;
	colorspace:pfz_colorspace_s;
	alpha:single;
	color:array[0..FZ_MAX_COLORS-1] of single;
end;

stackksss=record
  update:pfz_rect;
	rect:fz_rect;
end;
pfz_display_list_s=^fz_display_list_s;
fz_display_list_s=record
	first:pfz_display_node_s;
	last:pfz_display_node_s;
	top:integer;
  stack:array[0..STACK_SIZE-1] of stackksss;
	tiled:integer;
end;


procedure fz_free_display_list(list:pfz_display_list_s);
procedure fz_execute_display_list(list:pfz_display_list_s; dev:pfz_device_s; top_ctm:fz_matrix; scissor:fz_bbox);
function  fz_new_list_device(list:pfz_display_list_s):pfz_device_s;
function fz_new_display_list():pfz_display_list_s;
implementation
uses res_colorspace,fz_pathh,fz_textx,res_shades,fz_pixmapss,fz_dev_null;

function
fz_new_display_node( cmd:fz_display_command_e;  ctm:fz_matrix;
	colorspace:pfz_colorspace_s;  color:psingle; alpha:single):pfz_display_node_s;
var
	node:pfz_display_node_s;
	i:integer;
begin
	node := fz_malloc(sizeof(fz_display_node_s));
	node^.cmd := cmd;
	node^.next := nil;
	node^.rect := fz_empty_rect;
	node^.item.path := nil;
	node^.stroke := nil;
	node^.flag := 0;
	node^.ctm := ctm;
	if (colorspace<>nil) then
	begin
		node^.colorspace := fz_keep_colorspace(colorspace);
		if (color<>nil) then
		begin
			for i := 0 to node^.colorspace^.n-1 do
				node^.color[i] := single_items(color)[i];
		end;
	end
	else
	begin
		node^.colorspace := nil;
	end;
	node^.alpha := alpha;

	result:= node;
end;

function  fz_clone_stroke_state(stroke:pfz_stroke_state_s):pfz_stroke_state_s;
var
  newstroke:pfz_stroke_state_s;

begin
	newstroke := fz_malloc(sizeof(fz_stroke_state_s));
	newstroke^ := stroke^;
	result:= newstroke;
end;

procedure fz_append_display_node(list:pfz_display_list_s; node:pfz_display_node_s);
var
  update:pfz_rect;
begin
	if  ((node^.cmd=FZ_CMD_CLIP_PATH) or (node^.cmd=FZ_CMD_CLIP_STROKE_PATH) or  (node^.cmd=FZ_CMD_CLIP_IMAGE_MASK)) then
  begin
		if (list^.top < STACK_SIZE) then
		begin
			list^.stack[list^.top].update := @node^.rect;
			list^.stack[list^.top].rect := fz_empty_rect;
		end;
		list^.top:=list^.top+1;
	end else
  if  ((node^.cmd=FZ_CMD_END_MASK) or (node^.cmd=FZ_CMD_CLIP_TEXT) or  (node^.cmd=FZ_CMD_CLIP_STROKE_TEXT)) then
  begin

		if (list^.top < STACK_SIZE) then
		begin
			list^.stack[list^.top].update :=nil;
			list^.stack[list^.top].rect := fz_empty_rect;
		end;
		list^.top:=list^.top+1;
	end else
	if  node^.cmd=FZ_CMD_BEGIN_TILE then
  begin
		list^.tiled:=list^.tiled+1;
		if (list^.top > 0) and (list^.top < STACK_SIZE) then
		begin
			list^.stack[list^.top-1].rect := fz_infinite_rect;
		end;
	end
	else if node^.cmd=FZ_CMD_END_TILE then
  begin
		list^.tiled:=list^.tiled-1;
	end
	else if (node^.cmd= FZ_CMD_END_GROUP) then
		dddd
	else if node^.cmd= FZ_CMD_POP_CLIP then
  begin
		if (list^.top > STACK_SIZE) then
		begin
			list^.top:=list^.top-1;
			node^.rect := fz_infinite_rect;
		end
		else if (list^.top > 0)  then
		begin

			list^.top:=list^.top-1;
			update := list^.stack[list^.top].update;
			if (list^.tiled = 0) then
			begin
				if (update <> nil) then
				begin
					update^ := fz_intersect_rect(update^, list^.stack[list^.top].rect);
					node^.rect := update^;
				end
				else
					node^.rect := list^.stack[list^.top].rect;
			end
			else
				node^.rect := fz_infinite_rect;

        if ((list^.top > 0) and (list^.tiled = 0) and (list^.top <= STACK_SIZE)) then
			list^.stack[list^.top-1].rect := fz_union_rect(list^.stack[list^.top-1].rect, node^.rect);

		end
		//* fallthrough */
	else
  begin
		if ((list^.top > 0) and (list^.tiled = 0) and (list^.top <= STACK_SIZE)) then
			list^.stack[list^.top-1].rect := fz_union_rect(list^.stack[list^.top-1].rect, node^.rect);
	end;
  end;
	if (list^.first=nil) then
	begin
		list^.first := node;
		list^.last := node;
	end
	else
	begin
		list^.last^.next := node;
		list^.last := node;
	end;
end;

procedure fz_free_display_node(node:pfz_display_node_s);
begin
	case (node^.cmd) of
	 FZ_CMD_FILL_PATH:  fz_free_path(node^.item.path);
	 FZ_CMD_STROKE_PATH: fz_free_path(node^.item.path);
	 FZ_CMD_CLIP_PATH:  fz_free_path(node^.item.path);
	 FZ_CMD_CLIP_STROKE_PATH: fz_free_path(node^.item.path);

	 FZ_CMD_FILL_TEXT:fz_free_text(node^.item.text);
	 FZ_CMD_STROKE_TEXT:fz_free_text(node^.item.text);
	 FZ_CMD_CLIP_TEXT: fz_free_text(node^.item.text);
	 FZ_CMD_CLIP_STROKE_TEXT: fz_free_text(node^.item.text);
	 FZ_CMD_IGNORE_TEXT:  fz_free_text(node^.item.text);

   FZ_CMD_FILL_SHADE: fz_drop_shade(node^.item.shade);

   FZ_CMD_FILL_IMAGE:  fz_drop_pixmap(node^.item.image);
   FZ_CMD_FILL_IMAGE_MASK: fz_drop_pixmap(node^.item.image);
	 FZ_CMD_CLIP_IMAGE_MASK: fz_drop_pixmap(node^.item.image);

	 FZ_CMD_POP_CLIP:  dddd;
	 FZ_CMD_BEGIN_MASK:  dddd;
	 FZ_CMD_END_MASK:  dddd;
	 FZ_CMD_BEGIN_GROUP: dddd;
	 FZ_CMD_END_GROUP:  dddd;
	 FZ_CMD_BEGIN_TILE: dddd;
	 FZ_CMD_END_TILE:  dddd;
end;
	if (node^.stroke<>nil) then
		fz_free(node^.stroke);
	if (node^.colorspace<>nil) then
		fz_drop_colorspace(node^.colorspace);
	fz_free(node);
end;

procedure fz_list_fill_path(user:pointer; path:pfz_path_s; even_odd:integer; ctm:fz_matrix;
	colorspace:pfz_colorspace_s;  color:psingle;  alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_FILL_PATH, ctm, colorspace, color, alpha);
	node^.rect := fz_bound_path(path, nil, ctm);
	node^.item.path := fz_clone_path(path);
	node^.flag := even_odd;
	fz_append_display_node(user, node);
end;

procedure fz_list_stroke_path(user:pointer; path:pfz_path_s; stroke:pfz_stroke_state_s; ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_STROKE_PATH, ctm, colorspace, color, alpha);
	node^.rect := fz_bound_path(path, stroke, ctm);
	node^.item.path := fz_clone_path(path);
	node^.stroke := fz_clone_stroke_state(stroke);
	fz_append_display_node(user, node);
end;

procedure fz_list_clip_path(user:pointer; path:pfz_path_s; rect:pfz_rect; even_odd:integer; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_CLIP_PATH, ctm, nil, nil, 0);
	node^.rect := fz_bound_path(path, nil, ctm);
	if (rect <>nil) then
		node^.rect := fz_intersect_rect(node^.rect, rect^);
	node^.item.path := fz_clone_path(path);
	node^.flag := even_odd;
	fz_append_display_node(user, node);
end;

procedure fz_list_clip_stroke_path(user:pointer; path:pfz_path_s; rect:pfz_rect_s; stroke:pfz_stroke_state_s; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_CLIP_STROKE_PATH, ctm, nil, nil, 0);
	node^.rect := fz_bound_path(path, stroke, ctm);
	if (rect <> nil) THEN
		node^.rect := fz_intersect_rect(node^.rect, rect^);
	node^.item.path := fz_clone_path(path);
	node^.stroke := fz_clone_stroke_state(stroke);
	fz_append_display_node(user, node);
end;

procedure fz_list_fill_text(user:pointer; text:pfz_text_s; ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_FILL_TEXT, ctm, colorspace, color, alpha);
	node^.rect := fz_bound_text(text, ctm);
	node^.item.text := fz_clone_text(text);
	fz_append_display_node(user, node);
end;

procedure fz_list_stroke_text(user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s; ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_STROKE_TEXT, ctm, colorspace, color, alpha);
	node^.rect := fz_bound_text(text, ctm);
	node^.item.text := fz_clone_text(text);
	node^.stroke := fz_clone_stroke_state(stroke);
	fz_append_display_node(user, node);
end;

procedure fz_list_clip_text(user:pointer; text:pfz_text_s; ctm:fz_matrix; accumulate:integer);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_CLIP_TEXT, ctm, nil, nil, 0);
	node^.rect := fz_bound_text(text, ctm);
	node^.item.text := fz_clone_text(text);
	node^.flag := accumulate;
	//* when accumulating, be conservative about culling */
	if (accumulate<>0) then
		node^.rect := fz_infinite_rect;
	fz_append_display_node(user, node);
end;

procedure
fz_list_clip_stroke_text(user:pointer; text:pfz_text_s; stroke:pfz_stroke_state_s; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_CLIP_STROKE_TEXT, ctm, nil, nil, 0);
	node^.rect := fz_bound_text(text, ctm);
	node^.item.text := fz_clone_text(text);
	node^.stroke := fz_clone_stroke_state(stroke);
	fz_append_display_node(user, node);
end;

procedure
fz_list_ignore_text(user:pointer; text:pfz_text_s; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_IGNORE_TEXT, ctm, nil, nil, 0);
	node^.rect := fz_bound_text(text, ctm);
	node^.item.text := fz_clone_text(text);
	fz_append_display_node(user, node);
end;

procedure fz_list_pop_clip(user:pointer) ;
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_POP_CLIP, fz_identity, nil, nil, 0);
	fz_append_display_node(user, node);
end;

procedure fz_list_fill_shade(user:pointer; shade:pfz_shade_s; ctm:fz_matrix; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_FILL_SHADE, ctm, nil, nil, alpha);
	node^.rect := fz_bound_shade(shade, ctm);
	node^.item.shade := fz_keep_shade(shade);
	fz_append_display_node(user, node);
end;

procedure fz_list_fill_image(user:pointer; image:pfz_pixmap_s; ctm:fz_matrix; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_FILL_IMAGE, ctm, nil, nil, alpha);
	node^.rect := fz_transform_rect(ctm, fz_unit_rect);
	node^.item.image := fz_keep_pixmap(image);
	fz_append_display_node(user, node);
end;

procedure fz_list_fill_image_mask(user:pointer; image:pfz_pixmap_s; ctm:fz_matrix;
	colorspace:pfz_colorspace_s; color:psingle; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_FILL_IMAGE_MASK, ctm, colorspace, color, alpha);
	node^.rect := fz_transform_rect(ctm, fz_unit_rect);
	node^.item.image := fz_keep_pixmap(image);
	fz_append_display_node(user, node);
end;

procedure fz_list_clip_image_mask(user:pointer; image:pfz_pixmap_s; rect:pfz_rect_s; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_CLIP_IMAGE_MASK, ctm, nil, nil, 0);
	node^.rect := fz_transform_rect(ctm, fz_unit_rect);
	if (rect <> nil) then
		node^.rect := fz_intersect_rect(node^.rect, rect^);
	node^.item.image := fz_keep_pixmap(image);
	fz_append_display_node(user, node);
end;

procedure fz_list_begin_mask(user:pointer; rect:fz_rect; luminosity:integer; colorspace:pfz_colorspace_s; color:psingle);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_BEGIN_MASK, fz_identity, colorspace, color, 0);
	node^.rect := rect;
	node^.flag := luminosity;
	fz_append_display_node(user, node);
end;

procedure
fz_list_end_mask(user:pointer);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_END_MASK, fz_identity, nil, nil, 0);
	fz_append_display_node(user, node);
end;

procedure 
fz_list_begin_group(user:pointer; rect:fz_rect; isolated:integer; knockout:integer; blendmode:integer; alpha:single);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_BEGIN_GROUP, fz_identity, nil, nil, alpha);
	node^.rect := rect;
	node^.item.blendmode := blendmode;
  if isolated<>0 then
      node^.flag:=node^.flag or ISOLATED
     else
      node^.flag:=node^.flag or 0;
   if knockout<>0 then
      node^.flag:=node^.flag or ISOLATED
     else
      node^.flag:=node^.flag or 0;
	fz_append_display_node(user, node);
end;

procedure 
fz_list_end_group(user:pointer) ;
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_END_GROUP, fz_identity, nil, nil, 0);
	fz_append_display_node(user, node);
end;

procedure fz_list_begin_tile(user:pointer; area:fz_rect; view:fz_rect_s; xstep, ystep:single; ctm:fz_matrix);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_BEGIN_TILE, ctm, nil, nil, 0);
	node^.rect := area;
	node^.color[0] := xstep;
	node^.color[1] := ystep;
	node^.color[2] := view.x0;
	node^.color[3] := view.y0;
	node^.color[4] := view.x1;
	node^.color[5] := view.y1;
	fz_append_display_node(user, node);
end;

procedure
fz_list_end_tile(user:pointer);
var
	node:pfz_display_node_s;
begin
	node := fz_new_display_node(FZ_CMD_END_TILE, fz_identity, nil, nil, 0);
	fz_append_display_node(user, node);
end;

function
fz_new_list_device(list:pfz_display_list_s):pfz_device_s;
var
  dev:pfz_device_s;
begin
	dev := fz_new_device(list);

	dev^.fill_path := @fz_list_fill_path;
	dev^.stroke_path := @fz_list_stroke_path;
	dev^.clip_path := fz_list_clip_path;
	dev^.clip_stroke_path := fz_list_clip_stroke_path;

	dev^.fill_text := fz_list_fill_text;
	dev^.stroke_text := fz_list_stroke_text;
	dev^.clip_text := fz_list_clip_text;
	dev^.clip_stroke_text := fz_list_clip_stroke_text;
	dev^.ignore_text := fz_list_ignore_text;

	dev^.fill_shade := fz_list_fill_shade;
	dev^.fill_image := fz_list_fill_image;
	dev^.fill_image_mask := fz_list_fill_image_mask;
	dev^.clip_image_mask := fz_list_clip_image_mask;

	dev^.pop_clip := fz_list_pop_clip;

	dev^.begin_mask := fz_list_begin_mask;
	dev^.end_mask := fz_list_end_mask;
	dev^.begin_group := fz_list_begin_group;
	dev^.end_group := fz_list_end_group;

	dev^.begin_tile := fz_list_begin_tile;
	dev^.end_tile := fz_list_end_tile;

	result:= dev;
end;

function fz_new_display_list():pfz_display_list_s;
var
list:pfz_display_list_s;
begin
	list := fz_malloc(sizeof(fz_display_list_s));
	list^.first := nil;
	list^.last := nil;
	list^.top := 0;
	list^.tiled := 0;
	result:=list;
end;

procedure fz_free_display_list(list:pfz_display_list_s);
var
	node:pfz_display_node_s;
  next:pfz_display_node_s;
begin
  node := list^.first;
	while (node<>nil) do
	begin
		next := node^.next;
		fz_free_display_node(node);
		node := next;
	end;
	fz_free(list);
end;

procedure
fz_execute_display_list(list:pfz_display_list_s; dev:pfz_device_s; top_ctm:fz_matrix; scissor:fz_bbox);
var
	node:pfz_display_node_s;
	ctm:fz_matrix;
	rect:fz_rect;
	bbox:fz_bbox;
	clipped:integer;
	tiled:integer;
	empty:boolean;
  trect1:fz_rect;
  a1,a2:integer;
  label visible1;
begin
  clipped := 0;
	tiled := 0;
	if (not fz_is_infinite_bbox(scissor)) then
	begin
		(* add some fuzz at the edges, as especially glyph rects
		 * are sometimes not actually completely bounding the glyph *)
		scissor.x0 :=scissor.x0 -scissor.x0- 20;
    scissor.y0 :=scissor.y0- 20;
		scissor.x1 :=scissor.x1 + 20;
    scissor.y1 :=scissor.y1 + 20;
	end;
  node := list^.first;
	while node<>nil do  //;node = node^.next)
	begin
		//* cull objects to draw using a quick visibility test */

		if ((tiled<>0) or   (node^.cmd = FZ_CMD_BEGIN_TILE) or (node^.cmd = FZ_CMD_END_TILE)) then
		begin
			empty := false;
		end
		else
		begin
			bbox := fz_round_rect(fz_transform_rect(top_ctm, node^.rect));
			bbox := fz_intersect_bbox(bbox, scissor);
			empty := fz_is_empty_bbox(bbox);
		end;

		if (clipped<>0) or  (empty) then
		begin
			case (node^.cmd) of
			FZ_CMD_CLIP_PATH:
        begin
          clipped:=clipped+1;
          node := node^.next;
				  continue;
        end;
			FZ_CMD_CLIP_STROKE_PATH:
        begin
          clipped:=clipped+1;
          node := node^.next;
				  continue;
        end;
			FZ_CMD_CLIP_TEXT:
        begin
          clipped:=clipped+1;
          node := node^.next;
				  continue;
        end;
			FZ_CMD_CLIP_STROKE_TEXT:
        begin
          clipped:=clipped+1;
          node := node^.next ;
				  continue;
        end;
			FZ_CMD_CLIP_IMAGE_MASK:
        begin
          clipped:=clipped+1;
          node := node^.next  ;
				  continue;
        end;
			FZ_CMD_BEGIN_MASK:
        begin
          clipped:=clipped+1;
          node := node^.next  ;
				  continue;
        end;
			FZ_CMD_BEGIN_GROUP:
				begin
          clipped:=clipped+1;
          node := node^.next  ;
				  continue;
        end;
			FZ_CMD_POP_CLIP:
         begin
				if (clipped=0) then
					goto visible1;
				clipped:=clipped-1;
        node := node^.next;
				continue;
        end;
			FZ_CMD_END_GROUP:
        begin
				if (clipped=0) then
					goto visible1;
				clipped:=clipped-1;
        node := node^.next ;
				continue;
        end;
			FZ_CMD_END_MASK:
        begin
				if (clipped=0) then
					goto visible1;
          node := node^.next ;
				continue;
        end;
			else
        begin
        node := node^.next;
				continue;
        end;
			end;
		end;

  visible1:
		ctm := fz_concat(node^.ctm, top_ctm);

		case (node^.cmd) of

    FZ_CMD_FILL_PATH:
      begin
		   	fz_fill_path(dev, node^.item.path, node^.flag, ctm,
				node^.colorspace, @node^.color, node^.alpha);
			end;
		FZ_CMD_STROKE_PATH:
      begin
			fz_stroke_path(dev, node^.item.path, node^.stroke, ctm,
				node^.colorspace, @node^.color, node^.alpha);
			end;
		FZ_CMD_CLIP_PATH:
	  	begin
		  	trect1 := fz_transform_rect(top_ctm, node^.rect);
	   		fz_clip_path(dev, node^.item.path, @trect1, node^.flag, ctm);
  		end;
		FZ_CMD_CLIP_STROKE_PATH:
		  begin
			  trect1 := fz_transform_rect(top_ctm, node^.rect);
			  fz_clip_stroke_path(dev, node^.item.path, @trect1, node^.stroke, ctm);
		  end;
		FZ_CMD_FILL_TEXT:
      begin
			  fz_fill_text(dev, node^.item.text, ctm,
				node^.colorspace, @node^.color, node^.alpha);
			end;
		FZ_CMD_STROKE_TEXT:
      begin
	  		fz_stroke_text(dev, node^.item.text, node^.stroke, ctm,
				node^.colorspace, @node^.color, node^.alpha);
			end;
		FZ_CMD_CLIP_TEXT:
      begin
			fz_clip_text(dev, node^.item.text, ctm, node^.flag);
			end;
		FZ_CMD_CLIP_STROKE_TEXT:
      begin
			fz_clip_stroke_text(dev, node^.item.text, node^.stroke, ctm);
			end;
		FZ_CMD_IGNORE_TEXT:
      begin
			fz_ignore_text(dev, node^.item.text, ctm);
			end;
		FZ_CMD_FILL_SHADE:
      begin
			fz_fill_shade(dev, node^.item.shade, ctm, node^.alpha);
			end;
		FZ_CMD_FILL_IMAGE:
      begin
			fz_fill_image(dev, node^.item.image, ctm, node^.alpha);
			end;
		FZ_CMD_FILL_IMAGE_MASK:
      begin
			fz_fill_image_mask(dev, node^.item.image, ctm,
				node^.colorspace, @node^.color, node^.alpha);
			end;
		FZ_CMD_CLIP_IMAGE_MASK:
		  begin
			trect1 := fz_transform_rect(top_ctm, node^.rect);
			fz_clip_image_mask(dev, node^.item.image, @trect1, ctm);
		  end;
		FZ_CMD_POP_CLIP:
      begin
			fz_pop_clip(dev);
			end;
		FZ_CMD_BEGIN_MASK:
      begin
			rect := fz_transform_rect(top_ctm, node^.rect);
			fz_begin_mask(dev, rect, node^.flag, node^.colorspace, @node^.color);
			end;
		FZ_CMD_END_MASK:
      begin
			fz_end_mask(dev);
			end;
		FZ_CMD_BEGIN_GROUP:
      begin
			rect := fz_transform_rect(top_ctm, node^.rect);
      if  (node^.flag and ISOLATED) <> 0 then
      a1:=1
      else
      a1:=0;
      if (node^.flag and KNOCKOUT) <> 0 then
      a2:=1
      else
      a2:=0;
			fz_begin_group(dev, rect,
				a1, a2,
				node^.item.blendmode, node^.alpha);
		  end;
		FZ_CMD_END_GROUP:
      begin
		  	fz_end_group(dev);
			end;
		FZ_CMD_BEGIN_TILE:
      begin
			tiled:=tiled+1;
			rect.x0 := node^.color[2];
			rect.y0 := node^.color[3];
			rect.x1 := node^.color[4];
			rect.y1 := node^.color[5];
			fz_begin_tile(dev, node^.rect, rect,
				node^.color[0], node^.color[1], ctm);
			end;
		FZ_CMD_END_TILE:
      begin
			tiled:=tiled-1;
			fz_end_tile(dev);
			end;
		end;
    node := node^.next;
	end;
end;


end.
