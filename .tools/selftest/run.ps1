# کامپایل و اجرای آزمونِ خودکارِ Helper (بدون نیاز به دسترسی مدیر).
# همان فایل‌های هلپر را برمی‌دارد و یک نقطهٔ ورودِ آزمون به آن‌ها اضافه می‌کند.
# usage: powershell -File .tools/selftest/run.ps1
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $projectDir

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$outDir = Join-Path $env:TEMP 'vyrax-selftest'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$exe = Join-Path $outDir 'HelperSelfTest.exe'

$sources = @(
    'native\Helper.cs',
    'native\Cores.cs',
    'native\Json.cs','native\Preferences.cs',
    'native\Platform.cs',
    '.tools\selftest\HelperSelfTest.cs'
) | ForEach-Object { Join-Path $projectDir $_ }

$argsList = @(
    '/nologo','/target:exe','/platform:x64','/utf8output',
    ('/out:' + $exe),
    '/reference:System.dll','/reference:System.Core.dll',
    '/reference:System.Web.Extensions.dll','/reference:System.Security.dll'
)

& $compiler @argsList @sources
if ($LASTEXITCODE -ne 0) { throw 'self-test build failed' }

& $exe
exit $LASTEXITCODE
