@echo off
rem cls
path=D:\fpcupdeluxe\fpc\bin\x86_64-win64\
fpc.exe -Fu"D:\lazdev\components\lazutils\lib\x86_64-win64;;D:\lazarus\comp\cli-fp\src" -vn- -Sa %1 || goto exit:

rem -vn- - не выводить замечания
rem -Sa - включать assertion

d:\utils\clt.exe "-----------------" -nn -c=DarkRed

%~n1.exe

del *.o *.ppu 2> nul

:exit