$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $Root "main.lua"))) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not (Test-Path (Join-Path $Root "main.lua"))) {
        throw "Could not locate spyTool root (main.lua missing)."
    }
}

function Get-Fnv1aFingerprint([byte[]]$Bytes) {
    [uint64]$h1 = 0
    [uint64]$h2 = 0
    foreach ($b in $Bytes) {
        $h1 = ($h1 + [uint64]$b) % 4294967296
        $h2 = ($h2 + $h1) % 4294967296
    }
    return ("{0}:{1:x8}{2:x8}" -f $Bytes.Length, [uint32]$h1, [uint32]$h2)
}

function Get-FileFingerprint([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return Get-Fnv1aFingerprint $bytes
}

$ModulesDir = Join-Path $Root "modules"
New-Item -ItemType Directory -Force -Path $ModulesDir | Out-Null

$MainPath = Join-Path $Root "main.lua"
$lines = [System.IO.File]::ReadAllLines($MainPath)

# Only split if this still looks like the monolithic source (not the loader).
$isMonolith = $false
foreach ($line in $lines[0..([Math]::Min(40, $lines.Length - 1))]) {
    if ($line -match '^local HttpInterceptor\s*$' -or $line -match '^local SPYTOOL_WORKSPACE_FOLDER') {
        $isMonolith = $true
        break
    }
}
if (-not $isMonolith) {
    Write-Host "main.lua is already a loader; skipping split. Regenerating manifest only."
} else {
    $ranges = @(
        @{ Name = "01_core.lua"; Start = 1; End = 343 },
        @{ Name = "02_stealth.lua"; Start = 344; End = 847 },
        @{ Name = "03_parser.lua"; Start = 848; End = 1120 },
        @{ Name = "04_theme.lua"; Start = 1121; End = 1215 },
        @{ Name = "05_ui_kit.lua"; Start = 1216; End = 2942 },
        @{ Name = "06_function_analyzer.lua"; Start = 2943; End = 3045 },
        @{ Name = "07_remote_scanner.lua"; Start = 3046; End = 4401 },
        @{ Name = "08_http_interceptor.lua"; Start = 4403; End = 5463 },
        @{ Name = "09_module_explorer.lua"; Start = 5465; End = 6270 },
        @{ Name = "10_ui_components.lua"; Start = 6271; End = 8355 },
        @{ Name = "11_ui.lua"; Start = 8357; End = $lines.Length }
    )

    foreach ($r in $ranges) {
        $startIdx = $r.Start - 1
        $endIdx = $r.End - 1
        if ($startIdx -lt 0 -or $endIdx -ge $lines.Length -or $startIdx -gt $endIdx) {
            throw "Invalid range for $($r.Name): $($r.Start)-$($r.End) (file has $($lines.Length) lines)"
        }
        $slice = $lines[$startIdx..$endIdx]
        $header = @(
            "-- spyTool/modules/$($r.Name)",
            "-- Concat-loaded by main.lua (order matters; locals are shared across the chunk).",
            ""
        )
        $outPath = Join-Path $ModulesDir $r.Name
        $content = ($header + $slice) -join "`n"
        if (-not $content.EndsWith("`n")) { $content += "`n" }
        [System.IO.File]::WriteAllText($outPath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Wrote modules/$($r.Name) (lines $($r.Start)-$($r.End))"
    }

    # Simple loader
    $loader = @'
--[[
    Spy Tool entry (local)
    Concatenates modules/* into one chunk so shared locals keep working,
    then executes it. Prefer running spyTool.lua (GitHub bootstrap) in-game.
]]

local WORKSPACE_FOLDER = "spyTool"
local MODULES = {
    "modules/01_core.lua",
    "modules/02_stealth.lua",
    "modules/03_parser.lua",
    "modules/04_theme.lua",
    "modules/05_ui_kit.lua",
    "modules/06_function_analyzer.lua",
    "modules/07_remote_scanner.lua",
    "modules/08_http_interceptor.lua",
    "modules/09_module_explorer.lua",
    "modules/10_ui_components.lua",
    "modules/11_ui.lua",
}

local function resolvePath(rel)
    local primary = WORKSPACE_FOLDER .. "/" .. rel
    if type(isfile) == "function" then
        if isfile(primary) then
            return primary
        end
        if isfile(rel) then
            return rel
        end
    end
    return primary
end

local function readSource(rel)
    local path = resolvePath(rel)
    if type(readfile) ~= "function" then
        error("[SpyTool] readfile is unavailable on this executor")
    end
    if type(isfile) == "function" and not isfile(path) then
        error("[SpyTool] missing module: " .. path)
    end
    local ok, source = pcall(readfile, path)
    if not ok then
        error("[SpyTool] failed to readfile(" .. path .. "): " .. tostring(source))
    end
    if type(source) ~= "string" or source == "" then
        error("[SpyTool] module is empty: " .. path)
    end
    return source, path
end

local parts = {}
local loadedPaths = {}
for i, rel in ipairs(MODULES) do
    local source, path = readSource(rel)
    parts[i] = source
    loadedPaths[i] = path
end

local combined = table.concat(parts, "\n")
local chunk, err = loadstring(combined, "@" .. WORKSPACE_FOLDER .. "/modules")
if not chunk then
    error("[SpyTool] failed to compile modules: " .. tostring(err))
end

return chunk()
'@
    $loaderPath = Join-Path $Root "main.lua"
    $loaderText = $loader -replace "`r`n", "`n"
    if (-not $loaderText.EndsWith("`n")) { $loaderText += "`n" }
    [System.IO.File]::WriteAllText($loaderPath, $loaderText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote main.lua loader"
}

# Build manifest of syncable project files (not tools/, .git, local-only junk).
$excludeDirs = @(".git", ".vscode", "tools", "installer")
$excludeNames = @("-functionSpy.lua", ".gitattributes", ".gitignore")
$script:ManifestEntries = [System.Collections.Generic.List[object]]::new()

function Add-ManifestFiles([string]$Dir, [string]$Prefix) {
    Get-ChildItem -LiteralPath $Dir -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            if ($excludeDirs -contains $_.Name) { return }
            $nextPrefix = if ($Prefix) { "$Prefix/$($_.Name)" } else { $_.Name }
            Add-ManifestFiles $_.FullName $nextPrefix
        } else {
            if ($excludeNames -contains $_.Name) { return }
            if ($_.Name -eq "split_and_manifest.ps1") { return }
            $rel = if ($Prefix) { "$Prefix/$($_.Name)" } else { $_.Name }
            $rel = $rel -replace "\\", "/"
            if ($rel.StartsWith(".")) { return }
            $script:ManifestEntries.Add([pscustomobject]@{ Rel = $rel; Path = $_.FullName })
        }
    }
}

Add-ManifestFiles $Root ""
$files = @($script:ManifestEntries)

$manifestFiles = @()
foreach ($f in ($files | Sort-Object Rel)) {
    if ($f.Rel -eq "manifest.json") { continue }
    if ($f.Rel -eq "tools/split_and_manifest.ps1") { continue }
    $fp = Get-FileFingerprint $f.Path
    $manifestFiles += [pscustomobject]@{
        path = $f.Rel
        hash = $fp
    }
}

$manifest = [ordered]@{
    version = 1
    repo = "ProBaconHub/spyTool"
    branch = "main"
    algorithm = "adler32pair-length"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    files = @($manifestFiles | ForEach-Object { [ordered]@{ path = $_.path; hash = $_.hash } })
}

$json = $manifest | ConvertTo-Json -Depth 6
$json = $json -replace "`r`n", "`n"
$manifestPath = Join-Path $Root "manifest.json"
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote manifest.json with $($manifestFiles.Count) files"
