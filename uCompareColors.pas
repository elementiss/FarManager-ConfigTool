unit uCompareColors;       

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение цветов  
  Уникальным ключом является name
  <object name="WarnDialog.List.Text.Selected" background="FF000007" foreground="FF000000" flags="fg4bit bg4bit"/>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareColors(const FileBase, FileNew, OutputFile: string);

implementation

type
  TSettingProc = procedure(NewRoot: TDOMNode; S: TDOMElement; var f: TextFile);

procedure IterateSettings(Root, Node: TDOMNode; var f: TextFile; Proc: TSettingProc);
var
  Current: TDOMNode;
begin
  if Node = nil then Exit;

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'object') then 
      Proc(Root, TDOMElement(Current), f);
    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode; const SettingName: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = Nil then exit;
  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'object') then
      if TDOMElement(Current).GetAttribute('name') = SettingName then begin
        Result := TDOMElement(Current);
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

procedure DeletedReport(Root: TDOMNode; S: TDOMElement; var f: TextFile);
var
  SettingName, flags, foreground, background: DOMString;
  Found: TDOMElement;
begin
  flags       := S.GetAttribute('flags');
  SettingName := S.GetAttribute('name');
  foreground  := S.GetAttribute('foreground');
  background  := S.GetAttribute('background');

  Found := FindSetting(Root, SettingName);

  if Found = nil then begin
    Writeln(f, Format('DELETED: %s: %s, %s, %s', [SettingName, foreground, background, flags]));
  end;
end;

procedure ChangedReport(BaseRoot: TDOMNode; S: TDOMElement; var f: TextFile);
var
  SettingName, flags, foreground, background: DOMString;
  flags2, foreground2, background2: DOMString;
  Found: TDOMElement;
begin
  flags       := S.GetAttribute('flags');
  SettingName := S.GetAttribute('name');
  foreground  := S.GetAttribute('foreground');
  background  := S.GetAttribute('background');

  Found := FindSetting(BaseRoot, SettingName);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s: %s, %s, %s', [SettingName, foreground, background, flags]));
  end else begin
    flags2      := Found.GetAttribute('flags');
    foreground2 := Found.GetAttribute('foreground');
    background2 := Found.GetAttribute('background');
    if (flags <> flags2) or (foreground <> foreground2) or (background <> background2) then begin
      Writeln(f, Format('CHANGED: %s: %s → %s, %s → %s, %s → %s', [SettingName, 
        foreground, foreground2, background, background2, flags, flags2]));
    end;
  end;
end;

procedure CompareColors(const FileBase, FileNew, OutputFile: string);
var
  BaseDoc, NewDoc: TXMLDocument;
  BaseRoot, NewRoot: TDOMNode;
  f: TextFile;
begin
  try
    ReadXMLFile(BaseDoc, FileBase);
    ReadXMLFile(NewDoc, FileNew);
  except
    on E: Exception do begin
      Writeln(StdErr, 'Ошибка чтения XML: ', E.Message);
      Halt(2);
    end;
  end;

  BaseRoot := BaseDoc.DocumentElement.FindNode('colors');
  NewRoot := NewDoc.DocumentElement.FindNode('colors');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <colors> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(3);
  end;

  if OutputFile = '-' then
     f := Output
  else begin
    AssignFile(f, OutputFile);
    Rewrite(f);
  end;

  Writeln(f, 'Сравнение: ', ExtractFileName(FileBase), ' → ', ExtractFileName(FileNew));
  Writeln(f, '---------------------------------------------------');

  // Добавленные и измененные
  IterateSettings(BaseRoot, NewRoot, f, @ChangedReport);

  // Удаленные 
  IterateSettings(NewRoot, BaseRoot, f, @DeletedReport);

  CloseFile(f);

  BaseDoc.Free;
  NewDoc.Free;
end;

end.
