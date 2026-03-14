unit uPatches;

{$mode objfpc}
{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure CreatePatch(const FileBase, FileNew, PatchFile: string; const Sections: array of string);

implementation

uses
  uPatchGeneral, uPatchAssoc;

procedure CreatePatch(const FileBase, FileNew, PatchFile: string; const Sections: array of string);
var
  BaseDoc, NewDoc, PatchDoc: TXMLDocument;
  PatchRoot: TDOMNode;
  Section: string;
begin
  PatchDoc := TXMLDocument.Create;

  // Чтение исходных файлов
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
    PatchRoot := PatchDoc.CreateElement('farconfig');
    PatchDoc.AppendChild(PatchRoot);

    for Section in Sections do begin
      case Section of
        'generalconfig': CreateGeneralPatch(BaseDoc, NewDoc, PatchDoc);
        'associations': CreateAssocPatch(BaseDoc, NewDoc, PatchDoc);
      else
        WriteLn(StdErr, 'Ошибка: раздел не поддерживается: ', Section);
      end;
    end;

    if PatchFile = '-' then
      WriteXML(PatchDoc, Output)
    else
      WriteXMLFile(PatchDoc, PatchFile);
  finally
    BaseDoc.Free;
    NewDoc.Free;
    PatchDoc.Free;
  end;
end;

end.
