unit uPatchAssoc;

{$mode objfpc}{$H+}
{$codepage utf8}

{ Создание XML-патча ассоциаций
  Формирует XML той же структуры, содержащий только изменённые и добавленные узлы
  
  Пример выходной структуры:
    <associations>
        <filetype mask="*.ps1" description="ps1">
            <command type="0" enabled="1" command="powershell.exe -file !.!"/>
            <command type="1" enabled="0" command="new command"/>
        </filetype>
    </associations>
}
interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

procedure CreateAssocPatch(const BaseDoc, NewDoc, PatchDoc: TXMLDocument); 

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
        Exit;
      end;
    Current := Current.NextSibling;
  end;
end;

function CopyCommand(Source: TDOMElement; Owner: TXMLDocument): TDOMElement;
begin
  Result := Owner.CreateElement('command');
  Result.SetAttribute('type', Source.GetAttribute('type'));
  Result.SetAttribute('enabled', Source.GetAttribute('enabled'));
  Result.SetAttribute('command', Source.GetAttribute('command'));
end;

function HasCommandChanges(NewCmd, BaseCmd: TDOMElement): Boolean;
begin
  // Считаем изменённой, если отличается текст команды или статус enabled,
  // при этом новая команда не должна быть пустой
  Result := (NewCmd.GetAttribute('command') <> '') and (
            (NewCmd.GetAttribute('command') <> BaseCmd.GetAttribute('command')) or
            (NewCmd.GetAttribute('enabled') <> BaseCmd.GetAttribute('enabled')));
end;

function CopyFileTypeWithChanges(Source, BaseFT: TDOMElement; 
            Owner: TXMLDocument; OnlyChanged: Boolean): TDOMElement;
var
  SrcCmd, BaseCmd: TDOMNode;
  CmdElem, BaseElem: TDOMElement;
  ShouldCopy: Boolean;
begin
  Result := Owner.CreateElement('filetype');
  Result.SetAttribute('mask', Source.GetAttribute('mask'));
  Result.SetAttribute('description', Source.GetAttribute('description'));
  
  SrcCmd := Source.FirstChild;
  while Assigned(SrcCmd) do begin
    if (SrcCmd.NodeType = ELEMENT_NODE) and (SrcCmd.NodeName = 'command') then begin
      CmdElem := TDOMElement(SrcCmd);
      ShouldCopy := False;
      
      if OnlyChanged and Assigned(BaseFT) then begin
        // Ищем команду с тем же type в базовом файле
        BaseCmd := BaseFT.FirstChild;
        while Assigned(BaseCmd) do begin
          if (BaseCmd.NodeType = ELEMENT_NODE) and 
             (BaseCmd.NodeName = 'command') and
             (TDOMElement(BaseCmd).GetAttribute('type') = CmdElem.GetAttribute('type')) then
          begin
            BaseElem := TDOMElement(BaseCmd);
            ShouldCopy := HasCommandChanges(CmdElem, BaseElem);
            Break;
          end;
          BaseCmd := BaseCmd.NextSibling;
        end;
      end
      else begin
        // Для добавленных: копируем все непустые команды
        ShouldCopy := CmdElem.GetAttribute('command') <> '';
      end;
      
      if ShouldCopy then
        Result.AppendChild(CopyCommand(CmdElem, Owner));
    end;
    SrcCmd := SrcCmd.NextSibling;
  end;
end;

procedure CreateAssocPatch(const BaseDoc, NewDoc, PatchDoc: TXMLDocument);
var
  BaseAssoc, NewAssoc, PatchAssoc: TDOMNode;
  FT, Found: TDOMNode;
  Mask, Desc: DOMString;
  NewFT: TDOMElement;
begin
  BaseAssoc := BaseDoc.DocumentElement.FindNode(SECTION);
  NewAssoc := NewDoc.DocumentElement.FindNode(SECTION);

  if not Assigned(BaseAssoc) or not Assigned(NewAssoc) then begin
    Writeln(StdErr, Format('Не найден узел <%s> в одном из файлов', [SECTION]));
    Halt(3);
  end;

  //PatchDoc.AppendChild(PatchDoc.CreateElement(SECTION));
  //PatchAssoc := PatchDoc.DocumentElement;
  PatchAssoc := PatchDoc.CreateElement(SECTION);
  PatchDoc.DocumentElement.AppendChild(PatchAssoc);

  // Обход новых ассоциаций
  FT := NewAssoc.FirstChild;
  while Assigned(FT) do begin
    if (FT.NodeType = ELEMENT_NODE) and (FT.NodeName = 'filetype') then begin
      Mask := TDOMElement(FT).GetAttribute('mask');
      Desc := TDOMElement(FT).GetAttribute('description');

      Found := FindFileType(BaseAssoc, Mask, Desc);

      if Found = nil then begin
        // ADDED: копируем всю ассоциацию с непустыми командами
        NewFT := CopyFileTypeWithChanges(TDOMElement(FT), nil, PatchDoc, False);
      end
      else begin
        // CHANGED: копируем только изменённые команды
        NewFT := CopyFileTypeWithChanges(TDOMElement(FT), TDOMElement(Found), PatchDoc, True);
      end;
      
      // Добавляем в патч только если есть что копировать
      if NewFT.HasChildNodes then
        PatchAssoc.AppendChild(NewFT);
    end;
    FT := FT.NextSibling;
  end;
end;


end.
