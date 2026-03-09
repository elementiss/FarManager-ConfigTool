program far_configtool;

{$mode objfpc}{$H+}
{$modeswitch ANONYMOUSFUNCTIONS+}
{$codepage utf8}

{ 
  Планируется :
    merge   base.farconfig patch.farconfig [output.farconfig]
    сравнить highlight
}

uses
  LazUtf8,
  Classes, SysUtils, DOM, XMLRead, 
  CLI.Interfaces, CLI.Application, CLI.Command, CLI.Parameter, CLI.Progress, CLI.Console,
  uCompareAssoc, uCompareGeneral, uCompareColors, uComparePlugins, uComparePanelModes,
  uDropSections, uPluginList, uKeepSections;

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


var
  App: ICLIApplication;
  CompareCmd: TCompareCommand;
  DropCmd: TDropCommand;
  KeepCmd: TKeepCommand;
  PluginListCmd: TPluginListCommand;

begin
  try
    App := CreateCLIApplication(APP_NAME, APP_VERSION);

    // todo сравнение других опций
    CompareCmd := TCompareCommand.Create('compare', 'Сравнивает файлы экспорта Far Manager, созданные командой `far /export file`.' + CR +
      '                 Выдает отчет по изменениям в указанном разделе: добавлено / удалено / изменено' + CR +
      '                 Поддерживаются разделы: ассоциации файлов, общие настройки, цвета, список плагинов' + CR +
      '                 Пример: `compare -s associations --old settings.farconfig --new new.farconfig`');
    with CompareCmd do begin
      AddPathParameter('-1', '--old', 'Путь к старому файлу экспорта', True);
      AddPathParameter('-2', '--new', 'Путь к новому файлу экспорта', True);
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
      AddEnumParameter('-s', '--section', 'Раздел для сравнения', 'associations|generalconfig|colors|pluginsconfig|panelmodes', False, 'associations');
    end;
    App.RegisterCommand(CompareCmd);

    // todo удаление плагинов
    DropCmd := TDropCommand.Create('drop', 'Удаляет указанные разделы и выводит результат в файл. Исходный файл не изменяется'+CR+
      '                 Use case: удаление конфиденциальной информации' + CR +
      '                 Пример: `drop -s history,shortcuts > new.farconfig`');
    with DropCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для удаления, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(DropCmd);

    KeepCmd := TKeepCommand.Create('keep', 'Удаляет все разделы, кроме указанных, и выводит результат в файл.' + CR +
      '                 Исходный файл не изменяется' + CR +
      '                 Use case: дальнейшее выборочное импортирование' + CR +
      '                 Пример: `keep -s colors,associations,highlight -i settings.farconfig`');
    with KeepCmd do begin
      AddArrayParameter('-s', '--section', 'Список разделов для сохранения, через запятую', True);
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(KeepCmd);

    PluginListCmd := TPluginListCommand.Create('plugins', 'Выдает список плагинов. Поля разделены tab');
    with PluginListCmd do begin
      AddPathParameter('-i', '--input', 'Путь к исходному файлу экспорта. По умолчанию - (stdin)', False, '-');
      AddPathParameter('-o', '--output', 'Путь к результирующему файлу. По умолчанию - (stdout)', False, '-');
    end;
    App.RegisterCommand(PluginListCmd);

    ExitCode := App.Execute;
  except
    on E: Exception do begin
      TConsole.WriteLn('Fatal Error: ' + E.Message, ccRed);
      ExitCode := 1;
    end;
  end;
end.