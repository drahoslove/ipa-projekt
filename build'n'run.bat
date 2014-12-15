@echo off

set fn=ca

if not exist %fn%.obj goto j1
del %fn%.obj

:j1
if not exist %fn%.exe goto j2
del %fn%.exe

:j2

nasm -fobj %fn%.asm

if not exist %fn%.obj goto compile_err

alink -oPE %fn%.obj 

if not exist %fn%.exe goto link_err

%fn%.exe -h -s -p

goto exit

:compile_err
	echo Chyba pri prekladu programem NASM.EXE.
	goto exit
:link_err
	echo Chyba pri sestavovani programem ALINK.EXE.
:exit
