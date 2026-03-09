unit uPluginList;
// список плагинов

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure ShowPluginList(const InputFile: string; const OutputFile: string);


implementation

procedure ShowPluginList(const InputFile: string; const OutputFile: string);
var
  Doc: TXMLDocument;
  Root: TDOMNode;
  PluginsNode, PluginNode, KeyNode: TDOMNode;
  Guid, Desc: DOMString;
  Stream: TStringStream;
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

    PluginsNode := Doc.DocumentElement.FindNode('pluginsconfig');
    if PluginsNode = nil then begin
      Writeln(StdErr, 'Секция <pluginsconfig> не найдена');
      Exit;
    end;

    Stream := TStringStream.Create('');
    try
      i := -1;
      PluginNode := PluginsNode.FirstChild;

      while Assigned(PluginNode) do begin
        if (PluginNode.NodeName = 'plugin') and (PluginNode is TDOMElement) then begin
          Inc(i);

          Guid := TDOMElement(PluginNode).GetAttribute('guid');
          Desc := '';

          KeyNode := PluginNode.FindNode('hierarchicalconfig');
          if Assigned(KeyNode) then
            KeyNode := KeyNode.FindNode('key');

          if (KeyNode <> nil) and (KeyNode is TDOMElement) then
            Desc := TDOMElement(KeyNode).GetAttribute('description');

          Stream.WriteString(IntToStr(i) + #9 + UTF8Encode(Guid) + #9 + UTF8Encode(Desc) + LineEnding);
        end;

        PluginNode := PluginNode.NextSibling;
      end;

    if OutputFile = '-' then
      Write(Stream.DataString) // stdout
    else
      Stream.SaveToFile(OutputFile);

    finally
      Stream.Free;
      Doc.Free;
    end;

  except
    on E: Exception do begin
      Writeln(StdErr, 'Ошибка при обработке: ', E.Message);
      if Assigned(Doc) then Doc.Free;
      Halt(2);
    end;
  end;
end;

end.
