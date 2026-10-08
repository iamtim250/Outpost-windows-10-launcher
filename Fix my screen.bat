@echo off
rem Puts your monitor back to its normal resolution if Outpost ever leaves it small.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-game.ps1" restore
