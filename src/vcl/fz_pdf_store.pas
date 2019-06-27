unit fz_pdf_store;

interface
uses   SysUtils,digcommtype,digtypes,base_object_functions,mypdfstream,base_error;

TYPE
MYkeepfunc=function(p:pointer):pointer;
mydrop_func=procedure(p:pointer);
procedure pdf_free_store(store:ppdf_store_s) ;
function pdf_new_store():ppdf_store_s;
function pdf_find_item(store:ppdf_store_s; drop_func:pointer; key:pfz_obj_s):pointer;
procedure pdf_store_item(store:ppdf_store_s; keepfunc:pointer; drop_func:pointer;key:pfz_obj_s;val:pointer);
procedure pdf_remove_item(store:ppdf_store_s; drop_func:pointer; key:pfz_obj_s) ;
procedure pdf_age_store(store:ppdf_store_s;  maxage:integer);
procedure pdf_debug_store(store:ppdf_store_s);
implementation

function pdf_new_store():ppdf_store_s;
var
store:ppdf_store_s;
begin
	store := fz_malloc(sizeof(pdf_store_s));
	store^.hash := fz_new_hash_table(4096, sizeof(refkey_s));
	store^.root :=nil;
	result:=store;
end;

procedure pdf_store_item(store:ppdf_store_s; keepfunc:pointer; drop_func:pointer;key:pfz_obj_s;val:pointer);
var
 item:ppdf_item_s;
 refkey: refkey_s;
begin
	if (store=nil) then
		exit;

	item := fz_malloc(sizeof(pdf_item_s));
	item^.drop_func := drop_func;
	item^.key := fz_keep_obj(key);
	item^.val :=MYkeepfunc(keepfunc)(val);
	item^.age := 0;
	item^.next :=nil;

	if (fz_is_indirect(key))  then
	begin

		refkey.drop_func := drop_func;
		refkey.num := fz_to_num(key);
		refkey.gen := fz_to_gen(key);

		fz_hash_insert(store^.hash, @refkey, item);
	end
	else
	begin
		item^.next := store^.root;
		store^.root := item;
	end;
end;

function pdf_find_item(store:ppdf_store_s; drop_func:pointer; key:pfz_obj_s):pointer;
var
	refkey: refkey_s;
  item:ppdf_item_s;
begin
	if (store=nil) then
  begin
		result:=nil;
    exit;
  end;
	if (key = nil) then
	 begin
		result:=nil;
    exit;
  end;

	if (fz_is_indirect(key)) then
	begin
		refkey.drop_func := drop_func;
		refkey.num := fz_to_num(key);
		refkey.gen := fz_to_gen(key);
   // fz_debug_hash(store^.hash);
		item := fz_hash_find(store^.hash, @refkey);
		if (item<>nil) then
		begin
			item.age := 0;
			result:=item^.val;
      exit;
		end;
	end
	else
	begin
    item := store^.root;
		while item<>nil do
		begin
			if (@item^.drop_func = drop_func) and (fz_objcmp(item^.key, key)<>0)  then         //改过
			begin
				item^.age := 0;
				result:= item^.val;
			end;
      item := item^.next;
		end;
	end;

	result:=nil;
end;

procedure pdf_remove_item(store:ppdf_store_s; drop_func:pointer; key:pfz_obj_s) ;
var
	refkey: refkey_s;
	item, prev, next:ppdf_item_s;
begin
	if (fz_is_indirect(key)) then
	begin
		refkey.drop_func := drop_func;
		refkey.num := fz_to_num(key);
		refkey.gen := fz_to_gen(key);
		item := fz_hash_find(store^.hash, @refkey);
		if (item<>nil) then
		begin
			fz_hash_remove(store^.hash, @refkey);
			item^.drop_func(item^.val);
			fz_drop_obj(item^.key);
			fz_free(item);
		end;
	end
	else
	begin
		prev := nil;
    item := store^.root ;
		while item<>nil do
		begin
			next := item^.next;
			if (@item^.drop_func = drop_func) and (fz_objcmp(item^.key, key)<>0)   then
			begin
				if (prev<>nil) then
					store^.root := next
				else
					prev^.next := next;
				item^.drop_func(item^.val);
				fz_drop_obj(item^.key);
				fz_free(item);
			end
			else
				prev:= item;
		end;
    item := next;
	end;
end;

procedure pdf_age_store(store:ppdf_store_s;  maxage:integer);

VAR
  refkey: ^refkey_s;
  item,prev, next:ppdf_item_s;
	i:integer;
BEGIN
  i:=0;
//	for i := 0 to fz_hash_len(store^.hash)-1 do
//fz_debug_hash(store^.hash);
  while i< fz_hash_len(store^.hash) do
	begin

		refkey := fz_hash_get_key(store^.hash, i);
		item := fz_hash_get_val(store^.hash, i);
    if (item<>nil) and  (item^.age+1 > maxage) then
		begin
     //fz_warn('store[%d] (%d %d R) = %d\n"',[ i, refkey^.num, refkey^.gen, cardinal(item^.val)]);

			fz_hash_remove(store^.hash, refkey);
			item^.drop_func(item^.val);
			fz_drop_obj(item^.key);
			fz_free(item);
  //    fz_hash_get_Pval(store^.hash, i);

    	i:=i-1; //* items with same hash may move into place */
		end;
    i:=i+1;
	end;

	prev := nil;
  item := store^.root;
  while item<>nil do
	begin
		next := item^.next;
		if (item^.age+1 > maxage)  then
		begin
			if (prev=nil) then
				store^.root := next
			else
				prev^.next := next;
			item^.drop_func(item^.val);  //还不明白
			fz_drop_obj(item^.key);
			fz_free(item);
		end
		else
			prev := item;
   item := next;
	end;
end;

procedure pdf_free_store(store:ppdf_store_s) ;
begin
	pdf_age_store(store, 0);
	fz_free_hash(store^.hash);
	fz_free(store);
end;


procedure pdf_debug_store(store:ppdf_store_s);
var
	item:ppdf_item_s;
	next:ppdf_item_s;
	refkey:prefkey_s;
	i:integer;
begin
  IF store=NIL THEN
  EXIT;
  IF store^.hash=NIL THEN
  EXIT;
  fz_warn('-- resource store contents --\n');
	for i:= 0 to fz_hash_len(store^.hash)-1 do
	begin
		refkey := fz_hash_get_key(store^.hash, i);
		item := fz_hash_get_val(store^.hash, i);
		if (item<>nil) then
			fz_warn('store[%d] (%d %d R) = %d\n"',[ i, refkey^.num, refkey^.gen, cardinal(item^.val)]);
	end;
  item := store^.root;
	while (item<>nil )  do
	begin
		next := item^.next;
		fz_warn('store[*] ');
	 //	fz_debug_obj(item^.key);
		fz_warn(' = %p\n', [item^.val]);
    item := next ;
	end;
end;



end.
