@echo off
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe"

if not exist "%GODOT%" (
	echo Godot executable was not found:
	echo %GODOT%
	exit /b 1
)

start "" "%GODOT%" --editor "%~dp0project.godot"
