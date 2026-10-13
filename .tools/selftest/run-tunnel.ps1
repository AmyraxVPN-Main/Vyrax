$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outDir = Join-Path $env:TEMP 'vyrax-tunnel-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sources = @('native\Json.cs','native\Preferences.cs','native\Cores.cs','native\Platform.cs','.tools\selftest\TunnelRoutingSelfTest.cs') |
    ForEach-Object { Join-Path $projectDir $_ }
$exe = Join-Path $outDir 'Vyrax.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll @sources
if ($LASTEXITCODE -ne 0) { throw 'Tunnel test build failed' }
$core = Join-Path $projectDir 'vendor\sing-box\sing-box.exe'
$failures = 0
foreach ($case in @(@('Vyrax.exe','proxy'),@('xray.exe','direct'),@('sing-box.exe','direct'),@('BrowserTest.exe','proxy'))) {
    $testExe = Join-Path $outDir $case[0]
    if ($testExe -ne $exe) { Copy-Item -LiteralPath $exe -Destination $testExe -Force }
    & $testExe $core $case[1]
    if ($LASTEXITCODE -ne 0) { $failures++ }
}
if ($failures -gt 0) { throw "$failures routing tests failed" }

$probeSources = @('native\Json.cs','native\Preferences.cs','native\Cores.cs','native\Platform.cs','native\NetworkUplink.cs','native\Engine.cs','native\RoutingPool.cs','native\DelayProbe.cs','native\ConnectionSession.cs','native\ProxyShare.cs','native\Helper.cs','.tools\selftest\TunnelProbeSelfTest.cs') |
    ForEach-Object { Join-Path $projectDir $_ }
$probeExe = Join-Path $outDir 'TunnelProbeSelfTest.exe'
& $compiler /nologo /target:exe /platform:x64 /utf8output "/out:$probeExe" /reference:System.dll /reference:System.Core.dll /reference:System.Web.Extensions.dll /reference:System.Security.dll /reference:System.Net.Http.dll @probeSources
if ($LASTEXITCODE -ne 0) { throw 'Probe test build failed' }
& $probeExe
if ($LASTEXITCODE -ne 0) { throw 'Probe tests failed' }
