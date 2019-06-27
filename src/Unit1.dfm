object Form1: TForm1
  Left = 218
  Top = 83
  Width = 741
  Height = 461
  Caption = 'PDF parser demo'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label2: TLabel
    Left = 24
    Top = 16
    Width = 81
    Height = 13
    Caption = 'Please a PDF file'
  end
  object Button1: TButton
    Left = 224
    Top = 40
    Width = 113
    Height = 25
    Caption = 'Select PDF file'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Edit1: TEdit
    Left = 24
    Top = 40
    Width = 193
    Height = 21
    TabOrder = 1
  end
  object GroupBox1: TGroupBox
    Left = 24
    Top = 104
    Width = 225
    Height = 265
    Caption = 'Get first page png image '
    TabOrder = 2
    object Button9: TButton
      Left = 16
      Top = 24
      Width = 161
      Height = 25
      Caption = 'Get first page image png file'
      TabOrder = 0
      OnClick = Button9Click
    end
    object Button5: TButton
      Left = 16
      Top = 56
      Width = 161
      Height = 25
      Caption = 'Get first page text'
      TabOrder = 1
      OnClick = Button5Click
    end
    object memo1: TTntMemo
      Left = 8
      Top = 88
      Width = 209
      Height = 129
      Lines.Strings = (
        'memo1')
      ScrollBars = ssVertical
      TabOrder = 2
    end
  end
  object GroupBox2: TGroupBox
    Left = 256
    Top = 104
    Width = 249
    Height = 265
    Caption = 'Get PDF properties'
    TabOrder = 3
    object memo2: TTntMemo
      Left = 16
      Top = 72
      Width = 217
      Height = 185
      Lines.Strings = (
        '')
      ScrollBars = ssVertical
      TabOrder = 0
    end
    object Button4: TButton
      Left = 14
      Top = 32
      Width = 147
      Height = 25
      Caption = 'Get PDF properties'
      TabOrder = 1
      OnClick = Button4Click
    end
  end
  object GroupBox3: TGroupBox
    Left = 512
    Top = 104
    Width = 185
    Height = 265
    Caption = 'Get images from PDF'
    TabOrder = 4
    object Button7: TButton
      Left = 30
      Top = 88
      Width = 99
      Height = 25
      Caption = 'EXtract all Images'
      TabOrder = 0
      OnClick = Button7Click
    end
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = '.pdf'
    Filter = 'PDF file|*.PDF;*.pdf'
    Left = 208
    Top = 376
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'png'
    Filter = 'PNG FILE|*.PNG;*.png'
    Left = 144
    Top = 376
  end
end
