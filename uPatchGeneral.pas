unit uPatchGeneral;

{$mode objfpc}
{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure CreateGeneralPatch(const BaseDoc, NewDoc, PatchDoc: TXMLDocument); 

implementation

const SECTION = 'generalconfig';

type
  TSettingProc = procedure(BaseRoot: TDOMNode; PatchDoc: TXMLDocument;
                           PatchRoot: TDOMElement; S: TDOMElement);

procedure IterateSettings(BaseRoot, Node: TDOMNode;
                          PatchDoc: TXMLDocument; PatchRoot: TDOMElement;
                          Proc: TSettingProc);
var
  Current: TDOMNode;
begin
  if Node = nil then Exit;

  Current := Node.FirstChild;
  while Assigned(Current) do begin
    if (Current.NodeType = ELEMENT_NODE) and (Current.NodeName = 'setting') then
      Proc(BaseRoot, PatchDoc, PatchRoot, TDOMElement(Current));

    Current := Current.NextSibling;
  end;
end;

function FindSetting(Root: TDOMNode;
   const SettingKey, SettingName, SettingType: DOMString): TDOMElement;
var
  Current: TDOMNode;
begin
  Result := nil;
  if Root = nil then Exit;

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

procedure AddSettingToPatch(PatchDoc: TXMLDocument;
     PatchRoot: TDOMElement; S: TDOMElement);
var
  NewNode: TDOMElement;
begin
  NewNode := PatchDoc.CreateElement('setting');

  NewNode.SetAttribute('key',   S.GetAttribute('key'));
  NewNode.SetAttribute('name',  S.GetAttribute('name'));
  NewNode.SetAttribute('type',  S.GetAttribute('type'));
  NewNode.SetAttribute('value', S.GetAttribute('value'));

  PatchRoot.AppendChild(NewNode);
end;

procedure ChangedPatch(BaseRoot: TDOMNode;
     PatchDoc: TXMLDocument; PatchRoot: TDOMElement; S: TDOMElement);
var
  SettingKey, SettingName, SettingType, SettingValue, Value: DOMString;
  Found: TDOMElement;
begin
  SettingKey   := S.GetAttribute('key');
  SettingName  := S.GetAttribute('name');
  SettingType  := S.GetAttribute('type');
  SettingValue := S.GetAttribute('value');

  Found := FindSetting(BaseRoot, SettingKey, SettingName, SettingType);

  if Found = nil then begin { ADDED }
    AddSettingToPatch(PatchDoc, PatchRoot, S);
  end
  else begin
    Value := Found.GetAttribute('value');

    if Value <> SettingValue then begin { CHANGED }
      AddSettingToPatch(PatchDoc, PatchRoot, S);
    end;
  end;
end;

procedure CreateGeneralPatch(const BaseDoc, NewDoc, PatchDoc: TXMLDocument);
var
  BaseRoot, NewRoot: TDOMNode;
  PatchRoot: TDOMElement;
begin
  BaseRoot := BaseDoc.DocumentElement.FindNode(SECTION);
  NewRoot  := NewDoc.DocumentElement.FindNode(SECTION);

  if not Assigned(BaseRoot) or not Assigned(NewRoot) then begin
    Writeln(StdErr, 'Не найден узел ' + SECTION + ' в одном из файлов');
    Halt(3);
  end;

  PatchRoot := PatchDoc.CreateElement(SECTION);
  PatchDoc.DocumentElement.AppendChild(PatchRoot);

  IterateSettings(BaseRoot, NewRoot, PatchDoc, PatchRoot, @ChangedPatch);
end;


end.
