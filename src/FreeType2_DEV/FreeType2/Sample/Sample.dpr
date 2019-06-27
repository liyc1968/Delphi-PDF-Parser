program Sample;

{$APPTYPE CONSOLE}

{$MINENUMSIZE 4}


uses
  SysUtils,
  FreeType in '..\Freetype.pas';

var
  library_: FT_Library;
  Major, Minor, Build: FT_int;

  Error_: FT_Error;
  face: FT_Face;
  glyph: FT_Glyph;
  glyph_bitmap: FT_BitmapGlyph;
  glyph_outline: FT_OutlineGlyph;
  bitmap: FT_Bitmap_ptr;


procedure Error(Msg: String);
begin
  if library_ <> nil then begin
    FT_Done_FreeType(library_);
    library_ := nil;
  end;

  Writeln(Msg);
  Halt;
end;


begin
  // initialize dll
  if not init_FreeType2 then
    Error('Error initializing FreeType2 Library');

  // initialize freetype2
  if FT_Init_FreeType(@library_) <> 0 then
    Error('Error initialization FreeType2');

  // query and print version
  FT_Library_Version(library_, @Major, @Minor, @Build);
  writeln(Format('Using FreeType2 version %d.%d.%d'#13#10, [Major, Minor, Build]));

  // load font
  if FT_New_Face(library_, pChar(ParamStr(1)), 0, @face) <> 0 then
    raise Exception.Create('FT_New_Face failed');

  if FT_Set_Char_Size(face, 0, 24 shl 6, 96, 96) <> 0 then
    raise Exception.Create('FT_Set_Char_Size failed');

  // font properties
  Writeln('Fonts facename   : ' +  face^.family_name);
  Write('Stylename        : ' +  face^.style_name + ' (');
  case  face^.style_flags of
    0:
      write('Normal');

    FT_STYLE_FLAG_ITALIC:
      write('Italic');

    FT_STYLE_FLAG_BOLD:
      Write('Bold');

    FT_STYLE_FLAG_ITALIC or FT_STYLE_FLAG_BOLD:
      Write('Bold Italic');
  end;
  Writeln(')');
  Writeln('Number of Glyphs : ' +  IntToStr(face^.num_glyphs));

  // loading glyph
  if FT_Load_Glyph(face, FT_Get_Char_Index(face, Ord('1')), FT_LOAD_DEFAULT) <> 0 then
    raise Exception.Create('FT_Load_Glyph failed');

  // returning glyph
  if FT_Get_Glyph(face^.glyph, @glyph) <> 0 then
    raise Exception.Create('FT_Get_Glyph failed');

  glyph_outline := FT_OutlineGlyph(glyph);
  glyph_outline^.outline.n_contours := glyph_outline^.outline.n_contours;

  // convert to glyph
  if glyph^.format <> FT_GLYPH_FORMAT_BITMAP then begin
    Error_ := FT_Glyph_To_Bitmap(@glyph, FT_RENDER_MODE_NORMAL, nil, FT_TRUE);
    if Error_ <> 0 then
      raise Exception.Create('FT_Glyph_To_Bitmap failed');
  end;


  glyph_bitmap := FT_BitmapGlyph(glyph);
  bitmap := @(glyph_bitmap^.bitmap);

  writeln('Glyph ''a'' has following dimension:');
  writeln(Format('  Width    : %d', [Bitmap^.rows]));
  writeln(Format('  Height   : %d', [Bitmap^.width]));
  writeln(Format('  GraysNum : %d', [Bitmap^.num_grays]));

  // quit glyph
  FT_Done_Glyph(glyph);

  // quit face
  FT_Done_Face(face);

  // quit freetype2
  FT_Done_FreeType(library_);
  library_ := nil;

  // quit dll
  quit_FreeType2;

  writeln(#13#10'Press <enter> to quit.');
  readln;
end.
