@echo off
rem run_matrix_windows.bat - read every example database with one mx.exe and report.
rem
rem Usage:  run_matrix_windows.bat  WWW_DIR  MX_EXE
rem   WWW_DIR  the "www" folder of the ABCD repository
rem            (contains bases-examples_Linux and bases-examples_Windows)
rem   MX_EXE   full path to the mx.exe to test, e.g. C:\xampp\htdocs\ABCD\www\cgi-bin\ansi\mx.exe
rem
rem The repository is not written to: each database is copied to a temporary folder first.
rem Output: results\windows_matrix.txt (verdict per database) and results\out\<source>\<db>.txt
rem   verdict OK      = records were printed (mfn=...) and no fatal error
rem   verdict FATAL   = the program stopped with a fatal error (see the .txt file)
rem   verdict EMPTY   = no records and no message

if "%~2"=="" (
  echo usage: run_matrix_windows.bat WWW_DIR MX_EXE
  exit /b 1
)
set "WWW=%~f1"
set "MX=%~f2"
set "HERE=%~dp0.."
set "RES=%HERE%\results"
set "OUTD=%RES%\out"
set "WORK=%TEMP%\xiscore_matrix_%RANDOM%"
if not exist "%MX%" (
  echo ERROR: mx not found: %MX%
  exit /b 1
)
if not exist "%RES%" mkdir "%RES%"
if not exist "%OUTD%" mkdir "%OUTD%"
mkdir "%WORK%"
set "REPORT=%RES%\windows_matrix.txt"
echo binary: %MX% > "%REPORT%"
echo source     database               verdict  detail>> "%REPORT%"

for %%S in (bases-examples_Linux bases-examples_Windows) do (
  if exist "%WWW%\%%S" (
    for /d %%D in ("%WWW%\%%S\*") do call :one "%%S" "%%~D"
  ) else (
    echo missing: %WWW%\%%S
  )
)

echo.
echo report: %REPORT%
echo work dir (temporary copies, can be deleted): %WORK%
exit /b 0

:one
rem %1 = source folder name, %2 = database folder
set "SRC=%~1"
set "DBDIR=%~2"
set "DB=%~nx2"
if not exist "%DBDIR%\data\%DB%.mst" exit /b 0
if not exist "%OUTD%\%SRC%" mkdir "%OUTD%\%SRC%"
if exist "%WORK%\%SRC%\%DB%" rmdir /s /q "%WORK%\%SRC%\%DB%"
mkdir "%WORK%\%SRC%\%DB%\data"
xcopy "%DBDIR%\data" "%WORK%\%SRC%\%DB%\data\" /e /i /q /y >nul
set "OUTF=%OUTD%\%SRC%\%DB%.txt"
pushd "%WORK%\%SRC%\%DB%\data"
"%MX%" "%DB%" "" "" < nul > "%OUTF%" 2>&1
popd
set "V=EMPTY"
set "D=no records and no message"
findstr /c:"mfn=" "%OUTF%" >nul && set "V=OK"
findstr /i /c:"fatal" "%OUTF%" >nul && set "V=FATAL"
if "%V%"=="FATAL" (
  for /f "delims=" %%L in ('findstr /i /c:"fatal" "%OUTF%"') do set "D=%%L"
) else if "%V%"=="OK" (
  for /f %%N in ('findstr /c:"mfn=" "%OUTF%" ^| find /c /v ""') do set "D=%%N records"
)
echo %SRC%  %DB%  %V%  %D%>> "%REPORT%"
echo %SRC%  %DB%  %V%
exit /b 0
