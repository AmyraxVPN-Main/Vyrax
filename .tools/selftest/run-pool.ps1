$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir = Join-Path $env:TEMP 'vyrax-pool-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources = @('native\RoutingPool.cs','native\DelayProbe.cs','native\Json.cs','native\Preferences.cs','native\Cores.cs','native\Platform.cs','.tools\selftest\RoutingPoolSelfTest.cs') | ForEach-Object { Join-Path $projectDir $_ }
$exe = Join-Path $outDir 'RoutingPoolSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll /reference:System.Net.Http.dll @sources
if ($LASTEXITCODE -ne 0) { throw 'Pool tests failed to compile' }
& $exe (Join-Path $projectDir 'vendor\xray\xray.exe')
if ($LASTEXITCODE -ne 0) { throw 'Pool tests failed' }
