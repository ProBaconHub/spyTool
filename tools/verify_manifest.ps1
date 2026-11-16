$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifestPath = Join-Path $Root "manifest.json"
$json = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
Write-Output ("algorithm=" + $json.algorithm)
Write-Output ("files=" + $json.files.Count)
$json.files |
    Where-Object { $_.path -like "modules/*" -or $_.path -eq "main.lua" -or $_.path -eq "spyTool.lua" } |
    ForEach-Object { Write-Output ($_.path + " " + $_.hash) }
