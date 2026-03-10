program far_configtool;

{$mode objfpc}{$H+}
{$codepage utf8}

{ 
  todo
      keep/drop отдельного плагинов
      логирование в мерже
      сравнение filters, history - не хочу
      заменить halt на raise Exception.Create - лень
}

uses
  LazUtf8,
  Classes, SysUtils, DOM, XMLRead, 
  CLI.Interfaces, CLI.Application, CLI.Command, CLI.Parameter, CLI.Progress, CLI.Console,
  uCompareAssoc, uCompareGeneral, uCompareColors, uComparePlugins, uComparePanelModes,
  uCompareShortcuts, uCompareHighlight, uDropSections, uPluginList, uKeepSections,
  uMergeGeneral;

const
  APP_NAME    = 'far_configtool';
  APP_VERSION = '0.1.0';
  CR = #13#10;

type
  TCompareCommand = class(TBaseCommand)
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
  Section: string;
begin
  Result := 0;
  if not GetParameterValue('--old', XmlFile1) then ; // обязательные
  if not GetParameterValue('--new', XmlFile2) then ;
  if not GetParameterValue('--output', OutputFile) then ;
  if not GetParameterValue('--section', Section) then ;

  case Section of
    'associations' : CompareAssociations(xmlFile1, xmlFile2, OutputFile); 
    'generalconfig' : CompareGeneral(xmlFile1, xmlFile2, OutputFile);
    'colors' : CompareColors(xmlFile1, xmlFile2, OutputFile);
    'pluginsconfig' : ComparePlugins(xmlFile1, xmlFile2, OutputFile);
    'panelmodes' : ComparePanelModes(xmlFile1, xmlFile2, OutputFile);
    'shortcuts' : CompareShortcuts(xmlFile1, xmlFile2, OutputFile);
    'highlight' : CompareHighlight(xmlFile1, xmlFile2, OutputFile);
  else
  end;
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
begin
  Result := 0;
  if not GetParameterValue('--base', XmlFile1) then ; // обязательные
  if not GetParameterValue('--patch', XmlFile2) then ;
  if not GetParameterValue('--output', OutputFile) then ;

  MergeGeneral(xmlFile1, xmlFile2, OutputFile);
end;

var
  App: ICLIApplication;
  CompareCmd: TCompareCommand;
  DropCmd: TDropCommand;
  KeepCmd: TKeepCommand;
  MergeCmd: TMergeCommand;
  PluginListCmd: TPluginListCommand;
begin
  try
    App := CreateCLIApplication(APP_NAME, APP_VERSION);

    CompareCmd := TCompareCommand.Create('compare', 'Сравнивает файлы экспорта Far Manager, созданные командой `far /export file`.' + CR +
      '                 Выдает отчет по изменениям в указанном разделе: добавлено / удалено / изменено' + CR +
      '                 Поддерживаются разделы: ' + CR + 
      '                   associations - ассоциации файлов' + CR +
      '                   generalconfig - общие настройки' + CR +
      '                   colors - цвета' + CR + 
      '                   pluginsconfig - список плагинов' + CR +
      '                   panelmodes - режимы панелей' + CR +
      '                   shortcuts - закладки на папки' + CR +
      '                   highlight - сортировки и раскраски файлов' + CR +
      '                 Пример: `compare -s associations --old settings.farconfig --new new.farconfig`');
    with CompareCmd do begin
      AddPathParameter('-1', '--old', 'Путь к старому файлу экспорта', True);
      AddPathParameter('-2', '--new', 'Путь к новому файлу экспорта', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
      AddEnumParameter('-s', '--section', 'Раздел для сравнения', 'associations|generalconfig|colors|pluginsconfig|panelmodes|shortcuts|highlight', False, 'associations');
    end;
    App.RegisterCommand(CompareCmd);

    DropCmd := TDropCommand.Create('drop', 'Удаляет указанные разделы и выводит результат в файл. Исходный файл не изменяется'+CR+
      '                 Use case: удаление конфиденциальной информации' + CR +
      '                 Команда универсальна, работает для любых узлов xml' + CR +
      '                 Пример: `drop -s history,shortcuts > new.farconfig`');
    with DropCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для удаления, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(DropCmd);

    KeepCmd := TKeepCommand.Create('keep', 'Удаляет все разделы, кроме указанных, и выводит результат в файл.' + CR +
      '                 Исходный файл не изменяется' + CR +
      '                 Use case: дальнейшее выборочное импортирование; подготовка патча' + CR +
      '                 Команда универсальна, работает для любых узлов xml' + CR +
      '                 Пример: `keep -s colors,associations,highlight -i settings.farconfig`');
    with KeepCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для сохранения, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(KeepCmd);

    PluginListCmd := TPluginListCommand.Create('plugins', 'Выдает список плагинов. Поля разделены символом tab');
    with PluginListCmd do begin
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(PluginListCmd);

    MergeCmd := TMergeCommand.Create('merge', 'Объединение файлов экспорта ' + CR +
      '                 Применяет патч к указанному файлу, добавляя новые и изменяя существующие параметры' + CR +
      '                 Поддерживаются разделы: ' + CR + 
      '                   generalconfig - общие настройки' + CR +
      '                   -associations - ассоциации файлов' + CR +
      '                   -pluginsconfig - список плагинов' + CR +
      '                   -panelmodes - режимы панелей' + CR +
      '                   -shortcuts - закладки на папки' + CR +
      '                   -highlight - сортировки и раскраски файлов' + CR +
      '                 Если в файле патча только один раздел, то уровень <farconfig> можно опустить' + CR +
      '                 Пример: `merge --base full.farconfig --patch selected.farconfig`');
    with MergeCmd do begin
      AddPathParameter('-b', '--base', 'Путь к основному файлу экспорта', True);
      AddPathParameter('-p', '--patch', 'Путь к файлу с данными для изменения/добавления в основной файл', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
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