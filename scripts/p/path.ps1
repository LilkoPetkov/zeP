if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
	$argString = $args -join ' '
	Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argString"
	exit
}

$p = "C:/Users/Public/AppData/Local/"
$zDir = Join-Path $p "zeP"
$zigDir = Join-Path $zDir "zig"
$zigExe = Join-Path $zigDir "zig.exe"

# Create directories if they don't exist
New-Item -Path $zDir -ItemType Directory -Force | Out-Null
New-Item -Path $zigDir -ItemType Directory -Force | Out-Null

$userPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not ($userPath.Split(';') -contains $zigDir)) {
	$newPath = $zigDir + ";" + $userPath
	[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
	Write-Host "$zigDir added to user PATH. You may need to restart your terminal to see the change."
}
else {
	Write-Host "$zigDir is already in the PATH."
}

if ($args.Length -eq 0) {
	exit
}

$target = $args[0]
if (Test-Path $zigExe) { Remove-Item $zigExe -Force }
New-Item -ItemType SymbolicLink -Target $target -Path $zigExe | Out-Null  # zigExe is the symlink