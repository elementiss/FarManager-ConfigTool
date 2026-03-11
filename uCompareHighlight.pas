unit uCompareHighlight;

{$mode objfpc}
{$codepage utf8}
{$H+} 

{ Сравнение раскрасок файлов и групп сортировки
  На верхнем уровне два узла
     <key name="Highlight">
     <key name="SortGroups">
  Внутри каждого - группы
  Уникальным ключом группы является key name. Это:
    "GroupN" или "LastGroupN" (lowest) для первого узла
    "LowerGroupN" или "UpperGroupN" для второго узла
  Логику разделения на Highlight и Sort не поняла

  Внутри группы параметры value-type-name или name-type-background-foreground-flags

  В итерфейсе 4 панели:
    - GroupN
    - UpperGroupN
    - LowerGroupN
    - LastGroupN
  Shift+F11 - использовать группы сортировки
<highlight>
	<hierarchicalconfig>
		<key name="Highlight">
			<key name="Group0">
                <value name="Mask" type="text" value=""/>
                <value name="Title" type="text" value="lua"/>    - почти всегда пусто, описание для пользователя
				<value name="AttrClear" type="qword" value="0000000000000000"/>
    			<value name="MarkCharCursorColor" type="color" background="00000000" foreground="FF000000" flags="fg4bit bg4bit"/>
    		</key>
			<key name="Group1">
              ...
    		</key>
		</key>
    	<key name="SortGroups">
			<key name="LowerGroup0">
                <value name="Mask" type="text" value="*.$$$,*.*~*,*.bak,*.*log,*.map,*.old,*.temp,*.tmp,*.url,~$*.*,thumbs.db,desktop.ini,*.*_,*.dcu,*.*_old,*.dproj.local,*.identcache,*.tvsconfig,*.dsk,*.stat,*.torrent,*.ppu,*.o,backup"/>
				<value name="AttrClear" type="qword" value="0000000000000000"/>
    		</key>
			<key name="UpperGroup0">
    			<value name="AttrClear" type="qword" value="0000000000000000"/>
    		</key>
    		<key name="UpperGroup1">
    		</key>

    	</key>
    </hierarchicalconfig>
</highlight>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareHighlight(const FileBase, FileNew, OutputFile: string);

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

{ Ищет <key name="AName"> внутри Root }
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
  name, value: DOMString;
  background, foreground, flags1: DOMString;
begin
  Result := '';
  if Node = nil then Exit;
  
  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'value') then 
      with TDOMElement(Current) do begin
        name := GetAttribute('name');
        if HasAttribute('value') then begin
          value := GetAttribute('value');
          // if not ((name = 'Mark') and (value = '')) then  // для совместимости с предыдущими версиями, в которых не было Mark - нет смысла, т к цвета тоже по-другому
          Result := Result + '   ' + name + '=' + value + #13#10;
        end
        else if HasAttribute('type') and (GetAttribute('type') = 'color') then begin
          background := GetAttribute('background');  // в новых версиях некоторые атрибуты цвета могут отсутствовать
          foreground := GetAttribute('foreground');
          flags1 := GetAttribute('flags');           // флаги тоже изменились
          Result := Result + '   ' + DOMString(Format('%s=%s,%s,%s', [name, foreground, background, flags1]))+ #13#10;
        end;
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

procedure CompareHighlight(const FileBase, FileNew, OutputFile: string);
var
  BaseDoc, NewDoc: TXMLDocument;
  BaseRoot, NewRoot: TDOMNode;
  BaseRoot0, NewRoot0: TDOMNode;
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

  BaseRoot := BaseDoc.DocumentElement.FindNode('highlight');
  NewRoot := NewDoc.DocumentElement.FindNode('highlight');

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел <highlight> в одном из файлов');
    BaseDoc.Free;
    NewDoc.Free;
    Halt(3);
  end;

  BaseRoot0 := BaseRoot.FindNode('hierarchicalconfig');
  NewRoot0 := NewRoot.FindNode('hierarchicalconfig');
  if not Assigned(BaseRoot0) or not Assigned(NewRoot0) then begin
    Writeln(StdErr, 'Не найден узел <highlight> в одном из файлов');
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

  Writeln(f, 'Сравнение highlight: ', ExtractFileName(FileBase), ' → ', ExtractFileName(FileNew));
  Writeln(f, '---------------------------------------------------');

  // Спуск к ветке с закладками <key name="Highlight"> 
  BaseRoot := FindSetting(BaseRoot0, 'Highlight');
  NewRoot := findsetting(NewRoot0, 'Highlight');

  // Добавленные и измененные
  IterateSettings(BaseRoot, NewRoot, f, @ChangedReport);
  // Удаленные 
  IterateSettings(NewRoot, BaseRoot, f, @DeletedReport);

  // Спуск к ветке с закладками <key name="SortGroups"> 
  BaseRoot := FindSetting(BaseRoot0, 'SortGroups');
  NewRoot := findsetting(NewRoot0, 'SortGroups'); 

  // Добавленные и измененные
  IterateSettings(BaseRoot, NewRoot, f, @ChangedReport);
  // Удаленные 
  IterateSettings(NewRoot, BaseRoot, f, @DeletedReport);

  CloseFile(f);

  BaseDoc.Free;
  NewDoc.Free;
end;

end.
