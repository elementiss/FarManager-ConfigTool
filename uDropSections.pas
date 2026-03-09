unit uDropSections;
// Удаление разделов верхнего уровня

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure DropSections (const Sections: array of string; const InputFile: string; const OutputFile: string);


implementation

procedure DropSections (const Sections: array of string; const InputFile: string; const OutputFile: string);
var
  Doc: TXMLDocument;
  Root: TDOMNode;
  Node, NextNode: TDOMNode;
  SectionName: DOMString;
  Found: Boolean;
  i: Integer;
begin
  Doc := nil;
  try
    if InputFile = '-' then
      ReadXMLFile(Doc, Input) // stdin
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

    // Цикл по именам секций, которые нужно удалить
    for i := Low(Sections) to High(Sections) do begin
      SectionName := DOMString(Sections[i]);
      Found := False;

      Node := Root.FirstChild;
      while Assigned(Node) do begin
        NextNode := Node.NextSibling;  // сохраняем заранее, т.к. можем удалять

        if (Node.NodeType = ELEMENT_NODE) and (Node.NodeName = SectionName) then begin
          Root.RemoveChild(Node);
          Node.Free;                     // освобождаем удалённый узел
          Found := True;
          // после удаления можно прервать поиск внутри этой секции, т.к. предполагаем уникальность
          Break;
        end;

        Node := NextNode;
      end;

      if not Found then
        Writeln(StdErr, 'Предупреждение: секция <', SectionName, '> не найдена в файле');
//      else Writeln(StdOut, 'Удалена секция: <', SectionName, '>'); не нужно портить stdout
    end;

    // Выводим модифицированный XML
    if OutputFile = '-' then
      WriteXMLFile(Doc, Output) // stdout
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
