$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir = Join-Path $env:TEMP 'vyrax-subscription-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $outDir 'SubscriptionFetchSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll (Join-Path $projectDir '.tools\selftest\SubscriptionFetchSelfTest.cs')
if ($LASTEXITCODE -ne 0) { throw 'Subscription fetch test failed to compile' }
& $exe (Join-Path $projectDir 'release\Vyrax\Vyrax.exe')
if ($LASTEXITCODE -ne 0) { throw 'Subscription fetch test failed' }
