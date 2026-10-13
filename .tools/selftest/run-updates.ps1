$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir = Join-Path $env:TEMP 'vyrax-update-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $outDir 'ReleaseUpdatesSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Net.Http.dll (Join-Path $PSScriptRoot 'ReleaseUpdatesSelfTest.cs')
if ($LASTEXITCODE -ne 0) { throw 'Update tests failed to compile' }
& $exe (Join-Path $projectDir 'release\Vyrax\Vyrax.exe')
if ($LASTEXITCODE -ne 0) { throw 'Update tests failed' }
