unit uComparePlugins;

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение списков плагинов 
  Уникальным ключом является guid
  
  <plugin guid="0364224C-A21A-42ED-95FD-34189BA4B204">
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure ComparePlugins(const FileBase, FileNew, OutputFile: string);

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
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'plugin') then 
      Proc(Root, TDOMElement(Current), f);
    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode; const AGuid: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'plugin') then
      if TDOMElement(Current).GetAttribute('guid') = AGuid then begin
        Result := TDOMElement(Current);
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

function GetDesc(PluginNode: TDOMNode): DOMString;
var
  KeyNode: TDOMNode;
begin
  Result := '';

  KeyNode := PluginNode.FindNode('hierarchicalconfig');
  if Assigned(KeyNode) then
     KeyNode := KeyNode.FindNode('key');

  if (KeyNode <> nil) and (KeyNode is TDOMElement) then
     Result := TDOMElement(KeyNode).GetAttribute('description');
end;

procedure DeletedReport(Root: TDOMNode; S: TDOMElement; var f: TextFile);
var
  guid: DOMString;
  Found: TDOMElement;
begin
  guid := S.GetAttribute('guid');
  if guid = '' then
    writeln(StdErr, 'Не найден GUID плагина');

  Found := FindSetting(Root, guid);

  if Found = nil then begin
    Writeln(f, Format('DELETED: %s - %s', [guid, GetDesc(S)]));
  end;
end;

procedure ChangedReport(BaseRoot: TDOMNode; S: TDOMElement; var f: TextFile);
var
  Found: TDOMElement;
  guid: DOMString;
  desc, newdesc: DOMString;
begin
  guid := S.GetAttribute('guid');
  if guid = '' then
    writeln(StdErr, 'Не найден GUID плагина');
  desc := GetDesc(S);

  Found := FindSetting(BaseRoot, guid);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s - %s', [guid, desc]));
  end else begin
    // если найден можно сравнить описание и даже настройки
    newdesc := GetDesc(Found);
    if desc <> newdesc then begin
      Writeln(f, Format('CHANGED: %s: %s → %s', [guid, desc, newdesc]));
    end;
  end;
end;

procedure ComparePlugins(const FileBase, FileNew, OutputFile: string);
var
  BaseDoc, NewDoc: TXMLDocument;
  BaseRoot, NewRoot: TDOMNode;
  FT, Found: TDOMNode;
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

  BaseRoot := BaseDoc.DocumentElement.FindNode('pluginsconfig');
  NewRoot := NewDoc.DocumentElement.FindNode('pluginsconfig');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <pluginsconfig> в одном из файлов');
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