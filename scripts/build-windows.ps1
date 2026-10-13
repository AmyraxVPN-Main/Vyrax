$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectDir

Write-Output '1/6  building the UI'
& (Join-Path $PSScriptRoot 'generate-icon.ps1')
npm run build
if ($LASTEXITCODE -ne 0) { throw 'UI build failed' }

$bundleDir = Join-Path $projectDir 'release\Vyrax'
$bundleDir = [IO.Path]::GetFullPath($bundleDir)
$expectedBundleDir = [IO.Path]::GetFullPath((Join-Path $projectDir 'release\Vyrax'))
if ($bundleDir -ne $expectedBundleDir -or !(Split-Path $bundleDir -Parent).StartsWith($projectDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Build output must stay inside the workspace release folder'
}
$runningBundle = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($bundleDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) }
if ($runningBundle) { throw 'The release folder is in use. Close that copy before rebuilding.' }
if (Test-Path -LiteralPath $bundleDir) { Remove-Item -LiteralPath $bundleDir -Recurse -Force }
New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null

Write-Output '2/6  copying the UI'
$uiDir = Join-Path $bundleDir 'ui'
New-Item -ItemType Directory -Path $uiDir -Force | Out-Null
Copy-Item -Path (Join-Path $projectDir 'dist\*') -Destination $uiDir -Recurse -Force

Write-Output '3/6  copying cores and runtime'
New-Item -ItemType Directory -Path (Join-Path $bundleDir 'cores') -Force | Out-Null
Copy-Item -Path 'vendor\webview2\*.dll' -Destination $bundleDir -Force
Copy-Item -LiteralPath 'vendor\xray\xray.exe','vendor\sing-box\sing-box.exe' -Destination (Join-Path $bundleDir 'cores') -Force
Copy-Item -LiteralPath 'vendor\wintun\wintun.dll' -Destination (Join-Path $bundleDir 'cores') -Force
Copy-Item -LiteralPath 'native\geo.bin' -Destination $bundleDir -Force

Write-Output '4/6  compiling the native host'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
# HelperMain.cs نقطهٔ ورودِ هلپر است و این‌جا نباید باشد، وگرنه دو Main داریم.
$sourceFiles = @(Get-ChildItem -LiteralPath 'native' -Filter '*.cs' |
    Where-Object { $_.Name -ne 'HelperMain.cs' } | ForEach-Object FullName)
$argsList = @(
    '/nologo','/target:winexe','/platform:x64','/optimize+','/utf8output',
    ('/out:' + (Join-Path $bundleDir 'Vyrax.exe')),
    '/win32icon:native\Vyrax.ico',
    '/win32manifest:native\app.manifest',
    '/resource:project.json,Vyrax.project.json',
    '/reference:System.dll','/reference:System.Core.dll','/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll','/reference:System.Web.Extensions.dll',
    '/reference:System.Net.Http.dll','/reference:System.Security.dll',
    '/reference:vendor\webview2\Microsoft.Web.WebView2.Core.dll',
    '/reference:vendor\webview2\Microsoft.Web.WebView2.WinForms.dll'
)
& $compiler @argsList @sourceFiles
if ($LASTEXITCODE -ne 0) { throw 'Native build failed' }

Write-Output '5/6  compiling the VPN helper'
# هلپرِ حالت VPN: با UAC بالا می‌آید و فقط هستهٔ TUN را می‌گرداند، تا خودِ
# میزبانِ رابط (WebView2) بی‌دسترسی بماند.
# فهرستِ صریح، نه *.cs: هلپر نباید Program.cs یا Engine.cs را با خودش بکشد.
$helperSources = @(
    (Join-Path $projectDir 'native\Helper.cs'),
    (Join-Path $projectDir 'native\HelperMain.cs'),
    (Join-Path $projectDir 'native\Cores.cs'),
    (Join-Path $projectDir 'native\Json.cs'),
    (Join-Path $projectDir 'native\Preferences.cs'),
    (Join-Path $projectDir 'native\Platform.cs')
)
$helperArgs = @(
    '/nologo','/target:exe','/platform:x64','/optimize+','/utf8output',
    ('/out:' + (Join-Path $bundleDir 'VyraxHelper.exe')),
    '/reference:System.dll','/reference:System.Core.dll',
    '/reference:System.Web.Extensions.dll','/reference:System.Security.dll'
)
& $compiler @helperArgs @helperSources
if ($LASTEXITCODE -ne 0) { throw 'Helper build failed' }

Write-Output '6/6  copying licences'
New-Item -ItemType Directory -Path (Join-Path $bundleDir 'licenses') -Force | Out-Null
Copy-Item -LiteralPath 'vendor\versions.json' -Destination (Join-Path $bundleDir 'licenses\versions.json') -Force
Copy-Item -LiteralPath 'LICENSE','THIRD_PARTY_NOTICES.md' -Destination (Join-Path $bundleDir 'licenses') -Force
foreach ($component in @('xray','sing-box','webview2','wintun')) {
    Get-ChildItem -LiteralPath ('vendor\' + $component) -Filter 'LICENSE*' -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $bundleDir ('licenses\' + $component + '-' + $_.Name)) -Force }
}
Copy-Item -LiteralPath 'third_party\GPL-3.0.txt' -Destination (Join-Path $bundleDir 'licenses\GPL-3.0.txt') -Force
Copy-Item -Path 'vendor\npm-licenses\*' -Destination (Join-Path $bundleDir 'licenses') -Force

Write-Output ('ready: ' + $bundleDir)
