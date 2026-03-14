@echo off
rem cls
path=D:\lazarus\fpc\3.2.2\bin\x86_64-win64\
fpc.exe -Fu"D:\lazarus\components\lazutils\;D:\lazarus\comp\cli-fp\src"  -Sa %1 || goto exit:

rem -vn- - не выводить замечания
rem -Sa - включать assertion

d:\utils\clt.exe "-----------------" -nn -c=DarkRed

%~n1.exe

del *.o *.ppu 2> nul

:exit