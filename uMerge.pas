unit uMerge;

{$mode objfpc}{$H+}
{$codepage utf8}

{ Слияние настроек }
interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure MergeAll(Sections: array of string; const BaseFile, PatchFile, OutputMergedFile: string);

implementation

uses
  uMergeGeneral, uMergeAssoc;

procedure MergeAll(Sections: array of string; const BaseFile, PatchFile, OutputMergedFile: string);
var
  BaseDoc, PatchDoc: TXMLDocument;
  Section: string;
begin
  try
    ReadXMLFile(BaseDoc, BaseFile);
    ReadXMLFile(PatchDoc, PatchFile);
  except
    on E: Exception do begin
      Writeln(StdErr, 'Ошибка чтения XML: ', E.Message);
      Halt(2);
    end;
  end;

  try
    for Section in Sections do begin
      case Section of
        'associations' : MergeAssoc(BaseDoc, PatchDoc);
        'generalconfig' : MergeGeneral(BaseDoc, PatchDoc);
      else
        WriteLn(StdErr, 'Ошибка: раздел не поддерживается ', Section);
      end;
    end;  

    if OutputMergedFile = '-' then
      WriteXMLFile(BaseDoc, StdOut)
    else
      WriteXMLFile(BaseDoc, OutputMergedFile);

  finally
    BaseDoc.Free;
    PatchDoc.Free;
  end;
end;

end.
