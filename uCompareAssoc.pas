unit uCompareAssoc;       

{$mode objfpc}{$H+}
{$codepage utf8} 

{ Сравнение ассоциаций
  Пара mask-description уникальным ключом не является - технически можно создать две разные ассоциации 
  с одинаковыми масками и описанием. Но поскольку такие ассоциации будут показаны как неразличимые пункты меню,
  то в этом нет практического смысла. Поэтому программа считает ключом ассоциации пару mask-description
  
  Пример структуры
    <associations>                                    // 0..5 = Enter, Ctrl+PgDn, F3, Alt+F3, F4, Alt+F4
        <filetype mask="*.ps1" description="ps1">
            <command type="0" enabled="1" command="powershell.exe -file !.!"/>
            <command type="1" enabled="1" command=""/>
            <command type="2" enabled="1" command=""/>
            <command type="3" enabled="1" command=""/>
            <command type="4" enabled="1" command=""/>
            <command type="5" enabled="1" command=""/>
        </filetype>
    ...
    </associations>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareAssociations(const FileBase, FileNew, OutputFile: string);

implementation

const SECTION = 'associations';

function FindFileType(Assoc: TDOMNode; const Mask, Desc: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  Current := Assoc.FirstChild;

  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'filetype') then
      if (TDOMElement(Current).GetAttribute('mask') = Mask) and
        (TDOMElement(Current).GetAttribute('description') = Desc) then
      begin
        Result := TDOMElement(Current);
        exit;
      end;
    Current := Current.NextSibling;
  end;
end;

procedure PrintCommands(FT: TDOMNode; var f: TextFile);
var
  C: TDOMNode;
  t, cmd, enabled: DOMString;
begin
  C := FT.FirstChild;

  while Assigned(C) do begin
    if (C.NodeType = ELEMENT_NODE) and (C.NodeName = 'command') then begin
      t := TDOMElement(C).GetAttribute('type');  
      cmd := TDOMElement(C).GetAttribute('command');
      enabled := TDOMElement(C).GetAttribute('enabled');

      if cmd <> '' then
        Writeln(f, Format('   command[%s]: %s: %s', [t, enabled, cmd]));
    end;
    C := C.NextSibling;
  end;
end;

procedure CompareCommands(BaseFT, NewFT: TDOMNode; const Mask, Desc: DOMString; var f: TextFile);
var
  C, N: TDOMNode;
  type_, enabled, newenabled: DOMString;
  basecmd, newcmd: DOMString;
begin
  C := BaseFT.FirstChild;

  while Assigned(C) do begin
    if (C.NodeType = ELEMENT_NODE) and (C.NodeName = 'command') then begin
      with TDOMElement(C) do begin
        type_ := GetAttribute('type');
        basecmd := GetAttribute('command');
        enabled := GetAttribute('enabled');
      end;

      N := NewFT.FirstChild;

      while Assigned(N) do begin
        if (N.NodeName = 'command') and
          (TDOMElement(N).GetAttribute('type') = type_) then
        begin
          newcmd := TDOMElement(N).GetAttribute('command');
          newenabled := TDOMElement(N).GetAttribute('enabled');

          if (newcmd <> '') and ((newcmd <> basecmd) or (enabled <> newenabled)) then begin
            Writeln(f, Format(
              'CHANGED: %s | %s   command[%s]: %s:"%s" → %s:"%s"',
              [Mask, Desc, type_, enabled, basecmd, newenabled, newcmd]));
          end; // пустые новые команды не затирают существующие
          break;
        end;
        N := N.NextSibling;
      end;
    end;
    C := C.NextSibling;
  end;
end;

procedure CompareAssociations(const FileBase, FileNew, OutputFile: string);
var
  BaseDoc, NewDoc: TXMLDocument;
  BaseAssoc, NewAssoc: TDOMNode;
  FT, Found: TDOMNode;
  Mask, Desc: DOMString;
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
    BaseAssoc := BaseDoc.DocumentElement.FindNode(SECTION);
    NewAssoc := NewDoc.DocumentElement.FindNode(SECTION);

    if not Assigned(BaseAssoc) or not Assigned(NewAssoc) then begin
      Writeln(StdErr, Format('Не найден узел <%s> в одном из файлов', [SECTION]));
      Halt(3);
    end;

    if OutputFile = '-' then
      f := Output
    else begin
      AssignFile(f, OutputFile);
      Rewrite(f);
    end;

    Writeln(f, 'Сравнение ', SECTION, ': ', ExtractFileName(FileBase), ' → ', ExtractFileName(FileNew));
    Writeln(f, '---------------------------------------------------');

    // Добавленные и измененные ассоциации
    FT := NewAssoc.FirstChild;

    while Assigned(FT) do begin
      if FT.NodeName = 'filetype' then begin
        Mask := TDOMElement(FT).GetAttribute('mask');
        Desc := TDOMElement(FT).GetAttribute('description');

        Found := FindFileType(BaseAssoc, Mask, Desc);

        if Found = nil then begin
          Writeln(f, 'ADDED: ', Mask, ' | ', Desc);
          PrintCommands(FT, f);
        end
        else
          CompareCommands(Found, FT, Mask, Desc, f);
      end;

      FT := FT.NextSibling;
    end;

    // Удаленные ассоциации
    FT := BaseAssoc.FirstChild;

    while Assigned(FT) do begin
      if FT.NodeName = 'filetype' then begin
        Mask := TDOMElement(FT).GetAttribute('mask');
        Desc := TDOMElement(FT).GetAttribute('description');

        Found := FindFileType(NewAssoc, Mask, Desc);

        if Found = nil then begin
          Writeln(f, 'DELETED: ', Mask, ' | ', Desc);
          PrintCommands(FT, f);
        end;
      end;

      FT := FT.NextSibling;
    end;

    CloseFile(f);
  finally
    BaseDoc.Free;
    NewDoc.Free;
  end;
end;

end.