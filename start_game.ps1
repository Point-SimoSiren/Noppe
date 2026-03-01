$godot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe"

if (-not (Test-Path $godot)) {
	Write-Error "Godot executable was not found at $godot"
	exit 1
}

$project = Join-Path $PSScriptRoot "project.godot"

Start-Process -FilePath $godot -ArgumentList $project
