param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$projectDir = [IO.Path]::GetFullPath($ProjectRoot)
$vendorDir = Join-Path $projectDir 'vendor'
$cacheDir = Join-Path $vendorDir '.downloads'
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
$components = Get-Content -LiteralPath (Join-Path $vendorDir 'versions.json') -Raw | ConvertFrom-Json

function Copy-UniqueFile([string]$Folder, [string]$Name, [string]$Destination) {
    $fileMatches = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Filter $Name)
    if ($fileMatches.Count -ne 1) { throw "Expected one $Name in pinned archive" }
    Copy-Item -LiteralPath $fileMatches[0].FullName -Destination $Destination -Force
}
foreach ($component in $components) {
    if ($component.name -notin @('xray','sing-box','webview2','wintun') -or $component.version -notmatch '^[0-9.]+$') { throw 'Invalid vendor manifest entry' }
    $archive = Join-Path $cacheDir ($component.name + '-' + $component.version + '.zip')
    if (!(Test-Path -LiteralPath $archive)) {
        Write-Output ('Downloading pinned ' + $component.name + ' ' + $component.version)
        Invoke-WebRequest -Uri $component.url -OutFile $archive -UseBasicParsing -TimeoutSec 180
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $component.sha256) { throw ('Archive hash mismatch: ' + $component.name) }
    $extracted = Join-Path $cacheDir ($component.name + '-' + $component.version)
    $extractRoot = [IO.Path]::GetFullPath($extracted) + [IO.Path]::DirectorySeparatorChar
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($entry in $zip.Entries) {
            $entryPath = [IO.Path]::GetFullPath((Join-Path $extracted $entry.FullName))
            if (!$entryPath.StartsWith($extractRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive entry escapes extraction folder' }
        }
    } finally { $zip.Dispose() }
    Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force
    $destination = Join-Path $vendorDir $component.name
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    switch ($component.name) {
        'xray' { Copy-UniqueFile $extracted 'xray.exe' $destination }
        'sing-box' { Copy-UniqueFile $extracted 'sing-box.exe' $destination }
        'wintun' { Copy-Item -LiteralPath (Join-Path $extracted 'wintun\bin\amd64\wintun.dll') -Destination $destination -Force }
        'webview2' {
            Copy-Item -LiteralPath (Join-Path $extracted 'lib\net462\Microsoft.Web.WebView2.Core.dll'),(Join-Path $extracted 'lib\net462\Microsoft.Web.WebView2.WinForms.dll'),(Join-Path $extracted 'runtimes\win-x64\native\WebView2Loader.dll') -Destination $destination -Force
        }
    }
    $licenses = @(Get-ChildItem -LiteralPath $extracted -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|COPYING)(\..*)?$' })
    if (!$licenses.Count) { throw ('No license in pinned archive: ' + $component.name) }
    foreach ($item in $licenses) { Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $destination ('LICENSE-' + $item.Name + '.txt')) -Force }
    Write-Output ('Verified and prepared ' + $component.name)
}
Push-Location -LiteralPath $projectDir
try {
    node scripts/collect-licenses.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dependency notices failed' }
    node .tools/gen-geo.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Offline country data generation failed' }
} finally { Pop-Location }
