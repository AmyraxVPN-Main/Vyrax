param([switch]$Online)
$ErrorActionPreference='Stop'
$projectDir=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir=Join-Path $env:TEMP 'vyrax-free-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources=@('native\FreeProvider.cs','native\Json.cs','native\Platform.cs','native\Preferences.cs','.tools\selftest\FreeProviderSelfTest.cs') | ForEach-Object {Join-Path $projectDir $_}
$exe=Join-Path $outDir 'FreeProviderSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll /reference:System.Net.Http.dll @sources
if($LASTEXITCODE -ne 0){throw 'Free provider tests failed to compile'}
if($Online){& $exe --online}else{& $exe}
if($LASTEXITCODE -ne 0){throw 'Free provider tests failed'}
