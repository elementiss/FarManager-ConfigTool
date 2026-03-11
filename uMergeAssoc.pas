unit uMergeAssoc;

{$mode objfpc}
{$codepage utf8}
{$H+}

{ Слияние ассоциаций
  Пара mask-description является уникальным ключом
  - Новые filetype из патча добавляются в базовый файл
  - Существующие команды обновляются: команды с непустым command перезаписывают атрибуты
  - Пустые команды в патче игнорируются (не затирают базовые)

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
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure MergeAssoc(const BaseDoc, PatchDoc: TXMLDocument);

implementation

{ Поиск filetype по уникальному ключу (mask + description) }
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
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

{ Слияние команд: обновляет атрибуты в BaseFT из PatchFT для совпадающих type }
procedure MergeCommands(BaseFT, PatchFT: TDOMElement);
var
  PatchCmd, BaseCmd: TDOMNode;
  CmdType, PatchCmdVal, PatchEnabled, BaseCmdVal, BaseEnabled: DOMString;
begin
  PatchCmd := PatchFT.FirstChild;
  while Assigned(PatchCmd) do begin
    if (PatchCmd.NodeType = ELEMENT_NODE) and (PatchCmd.NodeName = 'command') then begin
      with TDOMElement(PatchCmd) do begin
        CmdType := GetAttribute('type');        // 0..5 = Enter, Ctrl+PgDn, F3, Alt+F3, F4, Alt+F4
        PatchCmdVal := GetAttribute('command');
        PatchEnabled := GetAttribute('enabled');
      end;

      { Пустые команды в патче не перезаписывают существующие }
      if PatchCmdVal <> '' then begin
        BaseCmd := BaseFT.FirstChild;
        while Assigned(BaseCmd) do begin
          if (BaseCmd.NodeType = ELEMENT_NODE) and
            (BaseCmd.NodeName = 'command') and
            (TDOMElement(BaseCmd).GetAttribute('type') = CmdType) then
          begin
            { Обновляем атрибуты команды из патча }
            with TDOMElement(BaseCmd) do begin
              BaseCmdVal := GetAttribute('command');
              BaseEnabled := GetAttribute('enabled');
              if (PatchEnabled <> BaseEnabled) or (PatchCmdVal <> BaseCmdVal) then begin
                // write log
                SetAttribute('command', PatchCmdVal);
                SetAttribute('enabled', PatchEnabled);
              end;
            end;
            Break;
          end;
          BaseCmd := BaseCmd.NextSibling;
        end;
      end;
    end;
    PatchCmd := PatchCmd.NextSibling;
  end;
end;

procedure MergeAssoc(const BaseDoc, PatchDoc: TXMLDocument);
var
  BaseAssoc, PatchAssoc: TDOMNode;
  PatchFT, BaseFT: TDOMNode;
  Mask, Desc: DOMString;
begin
  BaseAssoc := BaseDoc.DocumentElement.FindNode('associations');
  if PatchDoc.DocumentElement.NodeName = 'associations' then
    PatchAssoc := PatchDoc.DocumentElement      // уровень <farconfig> в файле патча можно опустить
  else
    PatchAssoc := PatchDoc.DocumentElement.FindNode('associations');

  if not Assigned(PatchAssoc) then begin
    // Writeln(StdErr, 'Не найден узел <associations> в патче');
    Halt(3);
  end;

  if not Assigned(BaseAssoc) then begin
    Writeln(StdErr, 'Не найден узел <associations> в базовом файле');  // патч некуда применять
    Halt(3);
  end;

  { Обработка каждого filetype из файла-патча }
  PatchFT := PatchAssoc.FirstChild;
  while Assigned(PatchFT) do begin
    if (PatchFT.NodeType = ELEMENT_NODE) and (PatchFT.NodeName = 'filetype') then begin
      Mask := TDOMElement(PatchFT).GetAttribute('mask');
      Desc := TDOMElement(PatchFT).GetAttribute('description');

      BaseFT := FindFileType(BaseAssoc, Mask, Desc);

      if BaseFT = nil then begin // Добавляем новый filetype
        // write log
        BaseAssoc.AppendChild(BaseDoc.ImportNode(PatchFT, True));
      end
      else
        MergeCommands(TDOMElement(BaseFT), TDOMElement(PatchFT)){ Обновляем существующий: сливаем команды };
    end;
    PatchFT := PatchFT.NextSibling;
  end;
end;

end.
