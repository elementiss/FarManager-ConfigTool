unit uKeepSections;
// Извлечение указанных разделов верхнего уровня

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure KeepSections (const Sections: array of string; const InputFile: string; const OutputFile: string);


implementation

procedure KeepSections(const Sections: array of string; const InputFile: string; const OutputFile: string);
var
  Doc: TXMLDocument;
  Root: TDOMNode;
  Node, NextNode: TDOMNode;
  i: Integer;
  Found: Boolean;
begin
  Doc := nil;
  try
    if InputFile = '-' then
      ReadXMLFile(Doc, Input)
    else
      ReadXMLFile(Doc, InputFile);

    if Doc = nil then begin
      Writeln(StdErr, 'Ошибка: не удалось прочитать файл ', InputFile);
      Halt(1);
    end;

    Root := Doc.DocumentElement;
    if Root = nil then begin
      Writeln(StdErr, 'Ошибка: в файле отсутствует корневой элемент');
      Doc.Free;
      Halt(1);
    end;

    if Root.NodeName <> 'farconfig' then
      Writeln(StdErr, 'Предупреждение: корневой элемент не <farconfig>, найден: ', Root.NodeName);
    
    Node := Root.FirstChild;
    while Assigned(Node) do begin
      NextNode := Node.NextSibling;

      if Node.NodeType = ELEMENT_NODE then begin
        Found := False;

        for i := Low(Sections) to High(Sections) do
          if Node.NodeName = DOMString(Sections[i]) then begin
            Found := True;
            Break;
          end;

        // если секция НЕ в списке — удаляем
        if not Found then begin
          Root.RemoveChild(Node);
          Node.Free;
        end;
      end;

      Node := NextNode;
    end;

    if OutputFile = '-' then
      WriteXMLFile(Doc, Output)
    else
      WriteXMLFile(Doc, OutputFile);

  except
    on E: Exception do begin
      Writeln(StdErr, 'Ошибка при обработке: ', E.Message);
      if Assigned(Doc) then Doc.Free;
      Halt(2);
    end;
  end;
  Doc.Free;
end;

end.
