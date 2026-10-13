$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir = Join-Path $env:TEMP 'vyrax-settings-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources = @('native\Json.cs','native\Cores.cs','native\Platform.cs','native\Preferences.cs','native\ConnectionSession.cs','.tools\selftest\SettingsSelfTest.cs') | ForEach-Object { Join-Path $projectDir $_ }
$exe = Join-Path $outDir 'SettingsSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll @sources
if ($LASTEXITCODE -ne 0) { throw 'Settings tests failed to compile' }
& $exe (Join-Path $projectDir 'vendor\xray\xray.exe') (Join-Path $projectDir 'vendor\sing-box\sing-box.exe')
if ($LASTEXITCODE -ne 0) { throw 'Settings tests failed' }
