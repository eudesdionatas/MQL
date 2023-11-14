@echo off

SET srcDir=%~dp0
SET esSrcDir=%~dp0\EAs
SET indSrcDir=%~dp0\Indicators
REM @echo %srcDir%
REM @echo %esSrcDir%
REM @echo %indSrcDir%

cd..

SET eaTargetDir=%CD%\Experts\MQL_IA
SET indTargetDir=%CD%\Indicators\MQL_IA

REM @echo %eaTargetDir%
REM @echo %indTargetDir%

REM xcopy %esSrcDir% %eaTargetDir% /i /s /y
REM xcopy %indSrcDir% %indTargetDir% /i /s /y

robocopy %esSrcDir% %eaTargetDir% /E /is /it
robocopy %indSrcDir% %indTargetDir% /E /is /it

pause


rem SET mypath = %~dp0
rem set eaSourceDir = "\EAs"
rem set eaTargetDir = "\Alexess\Experts"
rem set indicatorSourceDir = ./
rem set indicatorTargetDir = ../Alexess/Indicators



