& ([scriptblock]::Create((New-Object Net.WebClient).DownloadString('https://zep.run/installer/installer.ps1')))
zep install


if (-not (Get-Command "zig" -errorAction SilentlyContinue))
{
    Write-Host "zig could not be found"
    Write-Host "SUGGESTION:"
    Write-Host " $ zep zig install 0.15.2"
    exit
}

$zigVersion = @("zig version")
if (-not ($zigVersion -eq "0.15.2"))
{
    Write-Host "zig could not be found"
    Write-Host "SUGGESTION:"
    Write-Host " $ zep zig install 0.15.2"
    exit
}
