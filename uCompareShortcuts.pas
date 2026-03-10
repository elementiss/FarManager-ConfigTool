unit uCompareShortcuts;

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение закладок на папки 
  Уникальным ключом является key name (это цифра 0..9 - клавиша активации, кастомных нет)
  Внутри неограниченное количество value name="NameN",  value name="ShortcutN"

<shortcuts>
	<hierarchicalconfig>
		<key name="Shortcuts">
			<key name="1">
				<value name="Name0" type="text" value=""/>
				<value name="Shortcut0" type="text" value="D:\Sandbox"/>
			</key>
			<key name="2"/>
			<key name="3"/>
			<key name="4"/>
			<key name="5"/>
			<key name="6"/>
			<key name="7"/>
			<key name="8"/>
			<key name="9">
				<value name="Name0" type="text" value=""/>
				<value name="Name1" type="text" value=""/>
				<value name="Shortcut0" type="text" value="D:\Work"/>
				<value name="Shortcut1" type="text" value="C:\Far"/>
				<value name="Name2" type="text" value=""/>
				<value name="PluginData2" type="text" value="C:\5888.xml"/>
				<value name="PluginFile2" type="text" value="C:\5888.xml"/>
				<value name="PluginGuid2" type="text" value="F10829AE-E1DE-4A70-8266-176DF3841044"/>
				<value name="Shortcut2" type="text" value="/farconfig/shortcuts/hierarchicalconfig/key/key[8]"/>
			</key>
		</key>
	</hierarchicalconfig>
</shortcuts>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareShortcuts(const FileBase, FileNew, OutputFile: string);

implementation

type
  TSettingProc = procedure(NewRoot: TDOMNode; S: TDOMElement; var f: TextFile);

{ Перебирает все <key> внутри Node и вызывает процедуру для каждого }
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

{ Ищет <key name="AName"> внутри Root. Устойчив к Root = nil }
function FindSetting(Root: TDOMNode; const AName: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = nil then Exit;
  
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

{ Формирует текстовое описание всех <value> внутри узла }
function GetDesc(Node: TDOMNode): DOMString;
var
  Current: TDOMNode;
begin
  Result := '';
  if Node = nil then Exit;
  
  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'value') then 
      with TDOMElement(Current) do begin
        Result := Result + '   ' + GetAttribute('name') + '=' + GetAttribute('value') + #13#10;
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
  desc, newdesc: DOMString;
begin
  name := S.GetAttribute('name');
  desc := GetDesc(S);

  Found := FindSetting(BaseRoot, name);

  if Found = nil then begin
    Writeln(f, Format('ADDED: %s'#13#10'%s', [name, desc]));
  end else begin   // если найден
    newdesc := GetDesc(Found);
    if desc <> newdesc then begin
      Writeln(f, Format('CHANGED: %s'#13#10'%s  ->'#13#10'%s', [name, desc, newdesc]));
    end;
  end;
end;

procedure CompareShortcuts(const FileBase, FileNew, OutputFile: string);
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

  BaseRoot := BaseDoc.DocumentElement.FindNode('shortcuts');
  NewRoot := NewDoc.DocumentElement.FindNode('shortcuts');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <shortcuts> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(3);
  end;

  BaseRoot := BaseRoot.FindNode('hierarchicalconfig');
  NewRoot := NewRoot.FindNode('hierarchicalconfig');
  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <shortcuts> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(4);
  end;

  { Спуск к ветке с закладками <key name="Shortcuts"> }
  BaseRoot := FindSetting(BaseRoot, 'Shortcuts');
  NewRoot := findsetting(NewRoot, 'Shortcuts');

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
