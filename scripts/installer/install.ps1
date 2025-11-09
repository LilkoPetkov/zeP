$p = "C:/Users/Public/AppData/Local/"
$zDir = Join-Path $p "zeP/bin"

$userPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not ($userPath.Split(';') -contains $zDir)) {
	if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
		$argString = $args -join ' '
		Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argString"
		exit
	}
	
	$newPath = $zDir + ";" + $userPath
	[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
	Write-Host "$zDir added to user PATH. You may need to restart your terminal to see the change."
}
else {
	exit
}