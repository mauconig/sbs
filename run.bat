@echo off
setlocal
cd /d "%~dp0"

where godot >nul 2>nul
if %errorlevel%==0 (
    godot --path "%cd%"
    goto :eof
)

set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" (
    "%GODOT%" --path "%cd%"
    goto :eof
)

echo Godot 4.7 was not found. Install it with:
echo   winget install GodotEngine.GodotEngine
pause
