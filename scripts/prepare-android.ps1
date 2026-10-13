param([string]$ProjectRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$projectDir=[IO.Path]::GetFullPath($ProjectRoot)
$destination=Join-Path $projectDir 'vendor\android'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$components=Get-Content -LiteralPath (Join-Path $projectDir 'vendor\android-versions.json') -Raw | ConvertFrom-Json
foreach($component in $components){
    if($component.file -notin @('libv2ray.aar','hev-socks5-tunnel.aar') -or $component.url -notlike 'https://github.com/*/releases/download/*'){throw 'Invalid Android dependency manifest'}
    $file=Join-Path $destination $component.file
    if(-not(Test-Path -LiteralPath $file)){Invoke-WebRequest -Uri $component.url -OutFile $file -TimeoutSec 300}
    if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $component.sha256){throw ('Android dependency checksum mismatch: '+$component.name)}
    Write-Output ('Verified '+$component.name+' '+$component.version)
}
