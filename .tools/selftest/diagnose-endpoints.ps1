param([switch]$Uplink)
$ErrorActionPreference='Stop'
$projectDir=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$diagnosticDir=Join-Path $projectDir '.inspect\endpoint-diagnostics'
New-Item -ItemType Directory -Path $diagnosticDir -Force | Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe=Join-Path $diagnosticDir 'EndpointDiagnostics.exe'
$sources=@('native\Json.cs','native\Preferences.cs','native\Cores.cs','native\Platform.cs','native\NetworkUplink.cs','native\RoutingPool.cs','native\DelayProbe.cs','.tools\selftest\EndpointDiagnostics.cs') | ForEach-Object {Join-Path $projectDir $_}
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Net.Http.dll /reference:System.Security.dll @sources
if($LASTEXITCODE -ne 0){throw 'Endpoint diagnostics failed to compile'}
$mode=if($Uplink){'uplink'}else{'system'}
& $exe (Join-Path $projectDir 'vendor\xray\xray.exe') $diagnosticDir $mode
if($LASTEXITCODE -ne 0){throw 'Endpoint diagnostics failed'}
