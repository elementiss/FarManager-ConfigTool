unit uComparePanelModes;

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение режимов панелей 
  Уникальным ключом является key name (для стандартных это цифра 0..9 - клавиша активации, для custom - просто цифра)
  value name может быть и пустым, и неуникальным

  <panelmodes>
    <hierarchicalconfig>
      <key name="0">
          <value name="ColumnTitles" type="text" value="NM,SC,D"/>
          <value name="ColumnWidths" type="text" value="0,10,0"/>
          <value name="Flags" type="qword" value="0000000000000002"/>
          <value name="Name" type="text" value=""/>
          <value name="StatusColumnTitles" type="text" value="NR"/>
          <value name="StatusColumnWidths" type="text" value="0"/>
      </key>
      ...
      <key name="CustomModes">
          <key name="0">
              <value name="ColumnTitles" type="text" value="N,S,&lt;VER&gt;"/>
              <value name="ColumnWidths" type="text" value="0,12,12"/>
              <value name="Flags" type="qword" value="0000000000000000"/>
              <value name="Name" type="text" value="версия и платформа ver_C0"/>
              <value name="StatusColumnTitles" type="text" value="N"/>
              <value name="StatusColumnWidths" type="text" value="0"/>
          </key>
      ...
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure ComparePanelModes(const FileBase, FileNew, OutputFile: string);

implementation

const CR = #13#10;

type
  TSettingProc = procedure(NewRoot: TDOMNode; S: TDOMElement; var f: TextFile);

procedure IterateSettings(Root, Node: TDOMNode; var f: TextFile; Proc: TSettingProc);
var
  Current: TDOMNode;
begin
  if Node = nil then Exit;

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'key') then 
      Proc(Root, TDOMElement(Current), f);
    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode; const AName: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'key') then
      if TDOMElement(Current).GetAttribute('name') = AName then begin
        Result := TDOMElement(Current);
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

function GetDesc(Node: TDOMNode): DOMString;
var
  Current: TDOMNode;
begin
  Result := '';

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'value') then 
      with TDOMElement(Current) do begin
        Result := Result + '   ' + GetAttribute('name') + '=' + GetAttribute('value') + CR;
      end;
    Current := Current.NextSibling;
  end;
end;

procedure DeletedReport(Root: TDOMNode; S: TDOMElement; var f: TextFile);
var
  name: DOMString;
  Found: TDOMElement;
begin
  name := S.GetAttribute('name');

  Found := FindSetting(Root, name);

  if Found = nil then begin
    Writeln(f, Format('DELETED: %s'#13#10'%s', [name, GetDesc(S)]));
  end;
end;

procedure ChangedReport(BaseRoot: TDOMNode; S: TDOMElement; var f: TextFile);
var
  Found: TDOMElement;
  name: DOMString;
  desc, olddesc: DOMString;
begin
  name := S.GetAttribute('name');
  desc := GetDesc(S);

  Found := FindSetting(BaseRoot, name);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s'#13#10'%s', [name, desc]));
  end else begin   // если найден
    olddesc := GetDesc(Found);
    if desc <> olddesc then begin
      Writeln(f, Format('CHANGED: %s'#13#10'%s  ->'#13#10'%s', [name, olddesc, desc]));
    end;
  end;
end;

procedure ComparePanelModes(const FileBase, FileNew, OutputFile: string);
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

  BaseRoot := BaseDoc.DocumentElement.FindNode('panelmodes');
  NewRoot := NewDoc.DocumentElement.FindNode('panelmodes');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <panelmodes> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(3);
  end;

  BaseRoot := BaseRoot.FindNode('hierarchicalconfig');
  NewRoot := NewRoot.FindNode('hierarchicalconfig');
  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <panelmodes> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(4);
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

  // кастомные 
  WriteLn('=== CustomModes ===' + CR);

  BaseRoot := FindSetting(BaseRoot, 'CustomModes');
  NewRoot := FindSetting(NewRoot, 'CustomModes');
  if Assigned(BaseRoot) and Assigned(NewRoot) then begin // есть кастомные в обоих
    IterateSettings(BaseRoot, NewRoot, f, @ChangedReport);
    IterateSettings(NewRoot, BaseRoot, f, @DeletedReport);
  end
  else if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    writeln('!!!!!!!!!!!!!');
  end;

  CloseFile(f);

  BaseDoc.Free;
  NewDoc.Free;

end;

end.
