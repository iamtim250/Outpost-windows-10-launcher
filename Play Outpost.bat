@echo off
title Outpost (Sierra, 1994)
cd /d "%~dp0"

rem ===============================================================
rem  SETTINGS - edit these two numbers to taste.
rem  Outpost draws itself at 1994 sizes, so on a big modern screen it
rem  looks tiny. While the game runs, the launcher switches the monitor
rem  to this resolution (everything appears bigger) and switches back
rem  when you close the game.  Common choices:
rem     1280 720  - 1.5x bigger, keeps widescreen shape (default)
rem     1024 768  - about 2x bigger, 4:3 shape
rem      800 600  - about 2.4x bigger, 4:3 shape
rem  Set both to 0 to leave your screen alone.
rem ===============================================================
set GAME_WIDTH=1280
set GAME_HEIGHT=720

rem ---------------------------------------------------------------
rem  First run: fetch otvdm (winevdm), the free 16-bit Windows
rem  runner for 64-bit Windows, into the "otvdm" subfolder.
rem ---------------------------------------------------------------
if exist "otvdm\otvdm.exe" goto :haveotvdm

echo.
echo  First-time setup: downloading the 16-bit Windows runner (otvdm, about 10 MB)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$zip=Join-Path $PWD 'otvdm.zip';" ^
  "Invoke-WebRequest -UseBasicParsing 'https://github.com/otya128/winevdm/releases/download/v0.9.0/otvdm-v0.9.0.zip' -OutFile $zip;" ^
  "Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $PWD 'otvdm_tmp') -Force;" ^
  "$exe=Get-ChildItem -LiteralPath (Join-Path $PWD 'otvdm_tmp') -Recurse -Filter otvdm.exe | Select-Object -First 1;" ^
  "if(-not $exe){throw 'otvdm.exe not found in download'};" ^
  "if(Test-Path (Join-Path $PWD 'otvdm')){Remove-Item -LiteralPath (Join-Path $PWD 'otvdm') -Recurse -Force};" ^
  "Move-Item -LiteralPath $exe.DirectoryName -Destination (Join-Path $PWD 'otvdm');" ^
  "Remove-Item -LiteralPath (Join-Path $PWD 'otvdm_tmp') -Recurse -Force -ErrorAction SilentlyContinue;" ^
  "Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue;"
if not exist "otvdm\otvdm.exe" (
  echo.
  echo  The download did not work. Check your internet connection and run this again,
  echo  or download otvdm-v0.9.0.zip yourself from
  echo     https://github.com/otya128/winevdm/releases
  echo  and unzip it into a folder named  otvdm  next to this file.
  echo.
  pause
  exit /b 1
)
echo  Done.

:haveotvdm
rem ---------------------------------------------------------------
rem  First run: unpack the game (from RESOURCE.000) and copy the
rem  BITMAPS / VIDEOS / MUSIC folders off your Outpost CD or CD image.
rem ---------------------------------------------------------------
if exist "OUTPOST.EXE" if exist "BITMAPS\" if exist "VIDEOS\" if exist "MUSIC\" goto :havedata
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-cd-data.ps1"
if not exist "OUTPOST.EXE" goto :setupfailed
if not exist "VIDEOS\" goto :setupfailed
goto :havedata
:setupfailed
echo.
echo  Setup did not finish. Make sure your Outpost CD image (Outpost.bin or .iso)
echo  is in this folder, in Downloads, or on the Desktop, then run this again.
echo  See README for doing it by hand.
echo.
pause
exit /b 1

:havedata
rem ---------------------------------------------------------------
rem  Point OUTPOST.INI at the BITMAPS / VIDEOS / MUSIC folders here
rem  (the game expects these on the CD).  Short 8.3 paths are used so
rem  the 16-bit game never sees spaces or long names.
rem ---------------------------------------------------------------
for %%I in ("%~dp0.") do set "SHORTDIR=%%~sI"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ini=Join-Path $PWD 'OUTPOST.INI';" ^
  "$s='%SHORTDIR%'.TrimEnd('\');" ^
  "$line='opimage='+$s+'\BITMAPS;'+$s+'\VIDEOS;'+$s+'\MUSIC';" ^
  "$t=Get-Content -LiteralPath $ini -Raw;" ^
  "if($t -match '(?m)^opimage=[^\r\n]*'){$t=[regex]::Replace($t,'(?m)^opimage=[^\r\n]*',$line.Replace('$','$$'))}else{$t=$t -replace '\[general\]',('[general]'+[char]13+[char]10+$line)};" ^
  "[IO.File]::WriteAllText($ini,$t,[Text.Encoding]::ASCII)"

rem ---------------------------------------------------------------
rem  Launch.  run-game.ps1 (hidden, no console window) lowers the screen
rem  resolution, starts the game through otvdm, waits for it to close and
rem  then restores the screen - even if the game crashes.
rem ---------------------------------------------------------------
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0run-game.ps1" %GAME_WIDTH% %GAME_HEIGHT%
exit /b 0
