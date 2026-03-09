unit uCompareAssoc;       

{$mode objfpc}{$H+}
{$codepage utf8} 

{ Сравнение ассоциаций
  Пара mask-description уникальным ключом не являтся - технически можно создать две разные ассоциации 
  с одинаковыми масками и описанием. Но поскольку такие ассоциации будут показаны как одинаковые пункты меню,
  то в этом нет практического смысла. Поэтому программа считает ключом ассоциации пару mask-description
}
interface

uses
  Classes, SysUtils, DOM, XMLRead;


procedure CompareAssociations(const FileBase, FileNew, OutputFile: string);

implementation

function FindFileType (Assoc: TDOMNode; const Mask, Desc: DOMString): TDOMNode;
var
  N: TDOMNode;
begin
  Result := nil;
  N := Assoc.FirstChild;

  while Assigned(N) do begin
    if (N.NodeName = 'filetype') then
      if (TDOMElement(N).GetAttribute('mask') = Mask) and
        (TDOMElement(N).GetAttribute('description') = Desc) then
      begin
        Result := N;
        exit;
      end;
    N := N.NextSibling;
  end;
end;

procedure PrintCommands(FT: TDOMNode; var f: TextFile);
var
  C: TDOMNode;
  t, cmd, enabled: DOMString;
begin
  C := FT.FirstChild;

  while Assigned(C) do begin
    if C.NodeName = 'command' then begin
      t := TDOMElement(C).GetAttribute('type');  // 0..5 = Enter, Ctrl+PgDn, F3, Alt+F3, F4, Alt+F4
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
    if C.NodeName = 'command' then begin
      type_ := TDOMElement(C).GetAttribute('type');
      basecmd := TDOMElement(C).GetAttribute('command');
      enabled := TDOMElement(C).GetAttribute('enabled');

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
          end;
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

  BaseAssoc := BaseDoc.DocumentElement.FindNode('associations');
  NewAssoc := NewDoc.DocumentElement.FindNode('associations');

  if not Assigned(BaseAssoc) or not Assigned(NewAssoc) then begin
    Writeln(StdErr, 'Не найден узел <associations> в одном из файлов');
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

  BaseDoc.Free;
  NewDoc.Free;
end;

end.