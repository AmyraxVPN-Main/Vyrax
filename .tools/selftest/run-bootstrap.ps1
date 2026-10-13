$ErrorActionPreference='Stop'
$projectDir=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir=Join-Path $env:TEMP 'vyrax-bootstrap-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources=@('native\Json.cs','native\Preferences.cs','native\Cores.cs','native\Platform.cs','native\NetworkUplink.cs','native\RoutingPool.cs','native\DelayProbe.cs','.tools\selftest\TunnelBootstrapSelfTest.cs') | ForEach-Object {Join-Path $projectDir $_}
$exe=Join-Path $outDir 'TunnelBootstrapSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Security.dll /reference:System.Web.Extensions.dll /reference:System.Net.Http.dll @sources
if($LASTEXITCODE -ne 0){throw 'Bootstrap test build failed'}
& $exe (Join-Path $projectDir 'vendor\xray\xray.exe')
if($LASTEXITCODE -ne 0){throw 'Bootstrap tests failed'}
