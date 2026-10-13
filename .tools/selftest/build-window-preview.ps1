$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $projectDir
$previewDir = Join-Path $projectDir '.inspect\window-preview'
New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
Copy-Item -Path 'vendor\webview2\*.dll' -Destination $previewDir -Force
New-Item -ItemType Directory -Path (Join-Path $previewDir 'ui') -Force | Out-Null
Copy-Item -Path 'dist\*' -Destination (Join-Path $previewDir 'ui') -Recurse -Force
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$compilerArgs = @('/nologo','/target:winexe','/platform:x64','/utf8output',('/out:'+(Join-Path $previewDir 'VyraxUiPreview.exe')), '/win32icon:native\Vyrax.ico',
    '/reference:System.dll','/reference:System.Core.dll','/reference:System.Drawing.dll','/reference:System.Windows.Forms.dll','/reference:System.Web.Extensions.dll',
    '/reference:vendor\webview2\Microsoft.Web.WebView2.Core.dll','/reference:vendor\webview2\Microsoft.Web.WebView2.WinForms.dll')
& $compiler @compilerArgs 'native\Program.cs' 'native\AssemblyInfo.cs' 'native\Preferences.cs' 'native\ConnectionSession.cs' '.tools\selftest\WindowPreviewServices.cs'
if ($LASTEXITCODE -ne 0) { throw 'Window preview build failed' }
Write-Output ('Isolated UI preview: ' + (Join-Path $previewDir 'VyraxUiPreview.exe'))
