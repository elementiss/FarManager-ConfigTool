program far_configtool;

{$mode objfpc}{$H+}
{$codepage utf8}

{ 
  todo
      keep/drop отдельного плагинов
      логирование в мерже
      dry-run в мерже
      сравнение filters, history - не хочу
      заменить halt на raise Exception.Create - лень
}

uses
  LazUtf8,
  Classes, SysUtils, DOM, XMLRead, 
  CLI.Interfaces, CLI.Application, CLI.Command, CLI.Parameter, CLI.Progress, CLI.Console,
  uCompareAssoc, uCompareGeneral, uCompareColors, uComparePlugins, uComparePanelModes,
  uCompareShortcuts, uCompareHighlight, uDropSections, uPluginList, uKeepSections,
  uMerge, uMergeGeneral, uMergeAssoc, uPatches;

const
  APP_NAME    = 'far_configtool';
  APP_VERSION = '0.2.0';
  CR = #13#10;

type
  TCompareCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

  TPatchCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

  TDropCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

  TKeepCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

  TPluginListCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

  TMergeCommand = class(TBaseCommand)
  public
    function Execute: Integer; override;
  end;

function TCompareCommand.Execute: Integer;
var
  XmlFile1, XmlFile2: string;
  OutputFile: string;
  Section, SectionsRaw: string;
  Sections: array of string;
begin
  Result := 0;
  if not GetParameterValue('--old', XmlFile1) then ; // обязательные
  if not GetParameterValue('--new', XmlFile2) then ;
  if not GetParameterValue('--output', OutputFile) then ;
  if not GetParameterValue('--section', SectionsRaw) then ;

  if SectionsRaw = 'all' then
    Sections := ['associations','generalconfig','colors','pluginsconfig','panelmodes','shortcuts','highlight']
  else
    Sections := SectionsRaw.Split([','], TStringSplitOptions.ExcludeEmpty);

  for Section in Sections do begin
    case Section of
      'associations' : CompareAssociations(xmlFile1, xmlFile2, OutputFile); 
      'generalconfig' : CompareGeneral(xmlFile1, xmlFile2, OutputFile);
      'colors' : CompareColors(xmlFile1, xmlFile2, OutputFile);
      'pluginsconfig' : ComparePlugins(xmlFile1, xmlFile2, OutputFile);
      'panelmodes' : ComparePanelModes(xmlFile1, xmlFile2, OutputFile);
      'shortcuts' : CompareShortcuts(xmlFile1, xmlFile2, OutputFile);
      'highlight' : CompareHighlight(xmlFile1, xmlFile2, OutputFile);
    else
      WriteLn(StdErr, 'Ошибка: раздел не поддерживается: ', Section);
    end;
  end;
end;

function TPatchCommand.Execute: Integer;
var
  XmlFile1, XmlFile2: string;
  OutputFile: string;
  SectionsRaw: string;
  Sections: array of string;
begin
  Result := 0;
  if not GetParameterValue('--old', XmlFile1) then ; // обязательные
  if not GetParameterValue('--new', XmlFile2) then ;
  if not GetParameterValue('--output', OutputFile) then ;
  if not GetParameterValue('--section', SectionsRaw) then ;

//   Patch := False;  // пример флага - очень многословно
//   if GetParameterValue('--patch', PatchRaw) then begin
//     Patch := StrToBoolDef(PatchRaw, False);
//   end;

  if SectionsRaw = 'all' then
    Sections := ['associations','generalconfig']
  else
    Sections := SectionsRaw.Split([','], TStringSplitOptions.ExcludeEmpty);

  CreatePatch(xmlFile1, xmlFile2, OutputFile, Sections);
end;

function TDropCommand.Execute: Integer;
var
  Section: string;
  InputFile: string;
  OutputFile: string;
  Sections: array of string;
begin
  Result := 0;
  if not GetParameterValue('--section', Section) then ;
  if not GetParameterValue('--input', InputFile) then ; 
  if not GetParameterValue('--output', OutputFile) then ;

  Sections := Section.Split([','], TStringSplitOptions.ExcludeEmpty);

  DropSections(Sections, InputFile, OutputFile); 
end;

function TKeepCommand.Execute: Integer;
var
  Section: string;
  InputFile: string;
  OutputFile: string;
  Sections: array of string;
begin
  Result := 0;
  if not GetParameterValue('--section', Section) then ;
  if not GetParameterValue('--input', InputFile) then ; 
  if not GetParameterValue('--output', OutputFile) then ;

  Sections := Section.Split([','], TStringSplitOptions.ExcludeEmpty);

  KeepSections(Sections, InputFile, OutputFile); 
end;

function TPluginListCommand.Execute: Integer;
var
  InputFile: string;
  OutputFile: string;
begin
  Result := 0;
  if not GetParameterValue('--input', InputFile) then ; 
  if not GetParameterValue('--output', OutputFile) then ;

  ShowPluginList(InputFile, OutputFile); 
end;

function TMergeCommand.Execute: Integer;
var
  XmlFile1, XmlFile2: string;
  OutputFile: string;
  SectionsRaw: string;
  Sections: array of string;
begin
  Result := 0;
  if not GetParameterValue('--base', XmlFile1) then ; // обязательные
  if not GetParameterValue('--patch', XmlFile2) then ;
  if not GetParameterValue('--output', OutputFile) then ;
  if not GetParameterValue('--section', SectionsRaw) then ;

  if SectionsRaw = 'all' then
    Sections := ['associations','generalconfig']
  else
    Sections := SectionsRaw.Split([','], TStringSplitOptions.ExcludeEmpty);

  MergeAll(Sections, xmlFile1, xmlFile2, OutputFile);
end;

var
  App: ICLIApplication;
  CompareCmd: TCompareCommand;
  DropCmd: TDropCommand;
  KeepCmd: TKeepCommand;
  MergeCmd: TMergeCommand;
  PatchCmd: TPatchCommand;
  PluginListCmd: TPluginListCommand;
begin
  try
    App := CreateCLIApplication(APP_NAME, APP_VERSION);
// (App as TCLIApplication).DebugMode := true;

    CompareCmd := TCompareCommand.Create('compare', 'Сравнивает файлы экспорта Far Manager, созданные командой `far /export file`.' + CR +
      '                 Выдает отчет по изменениям в указанном разделе: добавлено / удалено / изменено' + CR +
      '                 Поддерживаются разделы: ' + CR + 
      '                    associations - ассоциации файлов' + CR +
      '                    generalconfig - общие настройки' + CR +
      '                    colors - цвета' + CR + 
      '                    pluginsconfig - список плагинов' + CR +
      '                    panelmodes - режимы панелей' + CR +
      '                    shortcuts - закладки на папки' + CR +
      '                    highlight - сортировки и раскраски файлов' + CR +
      '                 Пример: `compare -s all --old old.farconfig --new new.farconfig`' + CR +
      '                    `compare -s associations,colors --old old.farconfig --new new.farconfig`');
    with CompareCmd do begin
      AddPathParameter('-1', '--old', 'Путь к старому файлу экспорта', True);
      AddPathParameter('-2', '--new', 'Путь к новому файлу экспорта', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию stdout', False, '-');
      AddArrayParameter('-s', '--section', 'Разделы для сравнения. По умолчанию все поддерживаемые', False, 'all');
    end;
    App.RegisterCommand(CompareCmd);

    DropCmd := TDropCommand.Create('drop', 'Удаляет указанные разделы и выводит результат в файл. Исходный файл не изменяется'+CR+
      '                 Use case: удаление конфиденциальной информации' + CR +
      '                 Команда универсальна, работает для любых узлов любого xml' + CR +
      '                 Пример: `drop -s history,shortcuts > new.farconfig`');
    with DropCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для удаления, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию stdin', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию stdout', False, '-');
    end;
    App.RegisterCommand(DropCmd);

    KeepCmd := TKeepCommand.Create('keep', 'Удаляет все разделы, кроме указанных, и выводит результат в файл.' + CR +
      '                 Исходный файл не изменяется' + CR +
      '                 Use case: дальнейшее выборочное импортирование; подготовка патча' + CR +
      '                 Команда универсальна, работает для любых узлов любого xml' + CR +
      '                 Пример: `keep -s colors,associations,highlight -i settings.farconfig`');
    with KeepCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для сохранения, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию stdin', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию stdout', False, '-');
    end;
    App.RegisterCommand(KeepCmd);

    PluginListCmd := TPluginListCommand.Create('plugins', 'Выдает список плагинов. Поля разделены символом tab');
    with PluginListCmd do begin
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию stdin', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию stdout', False, '-');
    end;
    App.RegisterCommand(PluginListCmd);

    PatchCmd := TPatchCommand.Create('patch', 'Создает файл-патч в формате xml, содержащий только новые и измененные' + CR + 
      '                 параметры для дальнейшего слияния командой merge' + CR +
      '                 Поддерживаются разделы: ' + CR + 
      '                    associations - ассоциации файлов' + CR +
      '                    generalconfig - общие настройки' + CR +
      '                 Пример: `patch -s all --old old.farconfig --new new.farconfig`' + CR +
      '                    `compare -s associations --old old.farconfig --new new.farconfig`');
    with PatchCmd do begin
      AddPathParameter('-1', '--old', 'Путь к базовому файлу экспорта', True);
      AddPathParameter('-2', '--new', 'Путь к новому файлу экспорта', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу-патчу. По умолчанию stdout', False, '-');
      AddArrayParameter('-s', '--section', 'Разделы для сравнения. По умолчанию все поддерживаемые', False, 'all');
    end;
    App.RegisterCommand(PatchCmd);

    MergeCmd := TMergeCommand.Create('merge', 'Слияние файлов экспорта ' + CR +
      '                 Применяет патч к базовому файлу, добавляя новые и изменяя существующие параметры' + CR +
      '                 Исходный файл не изменяется' + CR +
      '                 Поддерживаются разделы: ' + CR + 
      '                    generalconfig - общие настройки' + CR +
      '                    associations - ассоциации файлов' + CR +
      '                 Если в файле патча только один раздел, то уровень <farconfig> можно опустить' + CR +
      '                 Пример: `merge --base full.farconfig --patch selected.xml > new.farconfig`');
    with MergeCmd do begin
      AddPathParameter('-b', '--base', 'Путь к базовому файлу экспорта', True);
      AddPathParameter('-p', '--patch', 'Путь к файлу-патчу с данными для изменения/добавления', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию stdout', False, '-');
      AddArrayParameter('-s', '--section', 'Разделы для слияния. По умолчанию все поддерживаемые', False, 'all');
    end;
    App.RegisterCommand(MergeCmd);

    ExitCode := App.Execute;
  except
    on E: Exception do begin
      TConsole.WriteLn('Fatal Error: ' + E.Message, ccRed);
      ExitCode := 1;
    end;
  end;
end.
