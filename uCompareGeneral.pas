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
  TSettingProc = procedure(NewRoot: TDOMNode; S: TDOMElement; var f: TextFile);

procedure IterateSettings(Root, Node: TDOMNode; var f: TextFile; Proc: TSettingProc);
var
  Current: TDOMNode;
begin
  if Node = nil then Exit;

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then
      Proc(Root, TDOMElement(Current), f);
    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode; const SettingKey, SettingName, SettingType: DOMString): TDOMNode;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = nil then exit;

  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then
      with TDOMElement(Current) do
        if (GetAttribute('key') = SettingKey) and
           (GetAttribute('name') = SettingName) and
           (GetAttribute('type') = SettingType) then begin
          Result := Current;
          Exit;
        end;
    Current := Current.NextSibling;
  end;
end;

procedure DeletedReport(Root: TDOMNode; S: TDOMElement; var f: TextFile);
var
  SettingKey, SettingName, SettingType, SettingValue: DOMString;
  Found: TDOMNode;
begin
  SettingKey   := S.GetAttribute('key');
  SettingName  := S.GetAttribute('name');
  SettingType  := S.GetAttribute('type');
  SettingValue := S.GetAttribute('value');

  Found := FindSetting(Root, SettingKey, SettingName, SettingType);

  if Found = nil then begin
    Writeln(f, Format('DELETED: %s.%s: %s: %s', [SettingKey, SettingName, SettingType, SettingValue]));
  end;
end;

procedure ChangedReport(BaseRoot: TDOMNode; S: TDOMElement; var f: TextFile);
var
  SettingKey, SettingName, SettingType, SettingValue, Value: DOMString;
  Found: TDOMNode;
begin
  SettingKey   := S.GetAttribute('key');
  SettingName  := S.GetAttribute('name');
  SettingType  := S.GetAttribute('type');
  SettingValue := S.GetAttribute('value');

  Found := FindSetting(BaseRoot, SettingKey, SettingName, SettingType);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s.%s: %s: %s', [SettingKey, SettingName, SettingType, SettingValue]));
  end
  else begin
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

  try
    BaseRoot := BaseDoc.DocumentElement.FindNode('generalconfig');
    NewRoot  := NewDoc.DocumentElement.FindNode('generalconfig');

    if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
      Writeln(StdErr, 'Не найден узел <generalconfig> в одном из файлов');
      Halt(3);
    end;

    if OutputFile = '-' then
      f := Output
    else begin
      AssignFile(f, OutputFile);
      Rewrite(f);
    end;

    Writeln(f, 'Сравнение generalconfig: ', ExtractFileName(FileBase), ' → ', ExtractFileName(FileNew));
    Writeln(f, '---------------------------------------------------');

    // Добавленные и измененные
    IterateSettings(BaseRoot, NewRoot, f, @ChangedReport);

    // Удаленные
    IterateSettings(NewRoot, BaseRoot, f, @DeletedReport);

    CloseFile(f);   // FPC защищает стандартные потоки от реального закрытия
  finally
    BaseDoc.Free;
    NewDoc.Free;
  end;
end;

end.
