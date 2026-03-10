unit uMergeGeneral;

{$mode objfpc}
{$codepage utf8}
{$H+}

{ Слияние общих настроек 
  Уникальным ключом является тройка key-name-type
  <setting key="Confirmations" name="Exit" type="qword" value="0000000000000000"/>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure MergeGeneral (const BaseFile, PatchFile, OutputMergedFile: string);

implementation

function FindSetting (Root: TDOMNode; const SettingKey, SettingName, SettingType: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = nil then exit;

  Current := Root.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then
      with TDOMElement(Current) do
        if (GetAttribute('key') = SettingKey) and
          (GetAttribute('name') = SettingName) and
          (GetAttribute('type') = SettingType) then
        begin
          Result := TDOMElement(Current);
          Exit;
        end;
    Current := Current.NextSibling;
  end;
end;

procedure MergeSettings (BaseRoot, PatchRoot: TDOMNode);
var
  Current: TDOMNode;
  PatchSetting, BaseSetting: TDOMElement;
  SettingKey, SettingName, SettingType, SettingValue, value: DOMString;
  NewNode: TDOMNode;
begin
  if PatchRoot = nil then Exit;

  Current := PatchRoot.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then begin
      PatchSetting := TDOMElement(Current);

      SettingKey := PatchSetting.GetAttribute('key');
      SettingName := PatchSetting.GetAttribute('name');
      SettingType := PatchSetting.GetAttribute('type');
      SettingValue := PatchSetting.GetAttribute('value');

      BaseSetting := FindSetting(BaseRoot, SettingKey, SettingName, SettingType);

      if Assigned(BaseSetting) then begin // Обновляем существующий параметр
        value := BaseSetting.GetAttribute('value');
        if value <> SettingValue then begin
          //WriteLn('Changed ' + Format('%s.%s', [SettingKey, SettingName]));
          BaseSetting.SetAttribute('value', SettingValue)
        end;
      end
      else begin
        //WriteLn('Added ' + Format('%s.%s', [SettingKey, SettingName]));
        // Добавляем новый параметр (клонируем из патча в документ базы)
        NewNode := BaseRoot.OwnerDocument.ImportNode(Current, True);
        BaseRoot.AppendChild(NewNode);
      end;
    end;
    Current := Current.NextSibling;
  end;
end;

procedure MergeGeneral (const BaseFile, PatchFile, OutputMergedFile: string);
var
  BaseDoc, PatchDoc: TXMLDocument;
  BaseRoot, PatchRoot: TDOMNode;
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
    BaseRoot := BaseDoc.DocumentElement.FindNode('generalconfig');
    if PatchDoc.DocumentElement.NodeName = 'generalconfig' then
      PatchRoot := PatchDoc.DocumentElement      // уровень <farconfig> в файле патча можно опустить
    else
      PatchRoot := PatchDoc.DocumentElement.FindNode('generalconfig');

    if not Assigned(PatchRoot) then begin
      Writeln(StdErr, 'Предупреждение: Не найден узел <generalconfig> в файле-патче');
      Exit;
    end;

    if not Assigned(BaseRoot) then begin  // но при этом патч есть - странно
      Writeln(StdErr, 'Не найден узел <generalconfig> в базовом файле');
      Halt(3);
    end;

    // Выполняем слияние: добавляем новые и обновляем существующие настройки
    MergeSettings(BaseRoot, PatchRoot);

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
