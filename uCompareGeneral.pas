unit uCompareGeneral;       

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение общих настроек 
  Уникальным ключом является тройка key-name-type
  <setting key="Confirmations" name="Exit" type="qword" value="0000000000000000"/>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareGeneral(const FileBase, FileNew, OutputFile: string);

implementation

type
  TSettingProc = procedure(NewRoot, S: TDOMNode; var f: TextFile);

procedure IterateSettings(Root, Node: TDOMNode; var f: TextFile; Proc: TSettingProc);
var
  Current: TDOMNode;
begin
  if Node = nil then Exit;

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then 
      Proc(Root, Current, f);
    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode; const SettingKey, SettingName, SettingType: DOMString): TDOMNode;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = Nil then exit;
  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then
      if (TDOMElement(Current).GetAttribute('key') = SettingKey) and
         (TDOMElement(Current).GetAttribute('name') = SettingName) and
         (TDOMElement(Current).GetAttribute('type') = SettingType) then
      begin
        Result := Current;
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

procedure DeletedReport(Root, S: TDOMNode; var f: TextFile);
var
  SettingKey, SettingName, SettingType, SettingValue: DOMString;
  Found: TDOMNode;
begin
  SettingKey := TDOMElement(S).GetAttribute('key');
  SettingName := TDOMElement(S).GetAttribute('name');
  SettingType := TDOMElement(S).GetAttribute('type');
  SettingValue := TDOMElement(S).GetAttribute('value');

  Found := FindSetting(Root, SettingKey, SettingName, SettingType);

  if Found = nil then begin
    Writeln(f, Format('DELETED: %s.%s: %s: %s', [SettingKey, SettingName, SettingType, SettingValue]));
  end;
end;

procedure ChangedReport(BaseRoot, S: TDOMNode; var f: TextFile);
var
  SettingKey, SettingName, SettingType, SettingValue, Value: DOMString;
  Found: TDOMNode;
begin
  SettingKey := TDOMElement(S).GetAttribute('key');
  SettingName := TDOMElement(S).GetAttribute('name');
  SettingType := TDOMElement(S).GetAttribute('type');
  SettingValue := TDOMElement(S).GetAttribute('value');

  Found := FindSetting(BaseRoot, SettingKey, SettingName, SettingType);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s.%s: %s: %s', [SettingKey, SettingName, SettingType, SettingValue]));
  end else begin
    Value := TDOMElement(Found).GetAttribute('value');
    if Value <> SettingValue then begin
      Writeln(f, Format('CHANGED: %s.%s: %s: %s → %s', [SettingKey, SettingName, SettingType, Value, SettingValue]));
    end;
  end;
end;

procedure CompareGeneral(const FileBase, FileNew, OutputFile: string);
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

  BaseRoot := BaseDoc.DocumentElement.FindNode('generalconfig');
  NewRoot := NewDoc.DocumentElement.FindNode('generalconfig');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <generalconfig> в одном из файлов');
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
