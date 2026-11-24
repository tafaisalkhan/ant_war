@echo off
setlocal
set "GODOT_EXE=C:\Users\Supreme Traders\Downloads\Godot_Engine\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Open project.godot in Godot 4 and press F5.
  pause
  exit /b 1
)
start "Ant Colony Wars" "%GODOT_EXE%" --path "%~dp0." --resolution 1280x720
