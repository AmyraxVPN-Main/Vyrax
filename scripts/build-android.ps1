param([string]$SdkRoot=$env:ANDROID_HOME,[string]$JdkRoot=$env:JAVA_HOME,[string]$GradlePath,[switch]$Release,[switch]$UsePreparedLibraries)
$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectDir
if(-not $SdkRoot -and (Test-Path -LiteralPath '.tools\android\sdk')){$SdkRoot=Join-Path $projectDir '.tools\android\sdk'}
if(-not $JdkRoot -and (Test-Path -LiteralPath '.tools\android\jdk')){$JdkRoot=(Get-ChildItem -LiteralPath '.tools\android\jdk' -Directory | Select-Object -First 1).FullName}
if(-not $GradlePath){$GradlePath=if(Test-Path -LiteralPath 'android\gradlew.bat'){Join-Path $projectDir 'android\gradlew.bat'}else{Join-Path $projectDir '.tools\android\gradle-8.9\bin\gradle.bat'}}
if(-not(Test-Path -LiteralPath (Join-Path $SdkRoot 'platforms\android-35\android.jar'))){throw 'Install Android SDK platform 35 and build-tools 35.0.0 first'}
if(-not(Test-Path -LiteralPath (Join-Path $JdkRoot 'bin\java.exe'))){throw 'JDK 17 is required'}
$env:JAVA_HOME=$JdkRoot;$env:ANDROID_HOME=$SdkRoot
if(-not $UsePreparedLibraries){& (Join-Path $PSScriptRoot 'prepare-android.ps1')}
if($Release -and -not $env:VYRAX_ANDROID_KEYSTORE){throw 'Set VYRAX_ANDROID_KEYSTORE and signing password/alias environment variables for signed release APKs'}
npm run build
if($LASTEXITCODE -ne 0){throw 'Android UI build failed'}
node .tools/gen-geo.mjs
if($LASTEXITCODE -ne 0){throw 'Android offline country data failed'}
node scripts/collect-licenses.mjs
if($LASTEXITCODE -ne 0){throw 'Dependency notice collection failed'}
$assets=[IO.Path]::GetFullPath((Join-Path $projectDir 'android\app\src\main\assets'))
$expected=[IO.Path]::GetFullPath((Join-Path $projectDir 'android\app\src\main\assets'))
if($assets -ne $expected -or -not $assets.StartsWith($projectDir+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected Android asset output'}
if(Test-Path -LiteralPath $assets){Remove-Item -LiteralPath $assets -Recurse -Force}
New-Item -ItemType Directory -Path "$assets\ui","$assets\licenses" -Force | Out-Null
Copy-Item -Path 'dist\*' -Destination "$assets\ui" -Recurse -Force
Copy-Item -LiteralPath 'project.json','native\geo.bin' -Destination $assets -Force
Copy-Item -LiteralPath 'LICENSE','THIRD_PARTY_NOTICES.md','third_party\GPL-3.0.txt','vendor\android-versions.json' -Destination "$assets\licenses" -Force
Copy-Item -Path 'third_party\android\*','vendor\npm-licenses\*' -Destination "$assets\licenses" -Force
Copy-Item -LiteralPath 'third_party\FoxyVPN-MIT.txt' -Destination "$assets\licenses" -Force
$icon=Join-Path $projectDir 'android\app\src\main\res\mipmap-xxxhdpi'
New-Item -ItemType Directory -Path $icon -Force | Out-Null
Copy-Item -LiteralPath 'public\vyrax-icon.png' -Destination "$icon\ic_launcher.png" -Force
('sdk.dir='+$SdkRoot.Replace('\','/')) | Set-Content -LiteralPath 'android\local.properties' -Encoding utf8
Push-Location -LiteralPath 'android'
try {
    if($Release){& $GradlePath --console=plain --no-daemon testReleaseUnitTest assembleRelease}
    else{& $GradlePath --console=plain --no-daemon testDebugUnitTest assembleDebug}
    if($LASTEXITCODE -ne 0){throw 'Android build/tests failed'}
}finally{Pop-Location}
$version=(Get-Content package.json -Raw | ConvertFrom-Json).version
$variant=if($Release){'release'}else{'debug'}
$output=Join-Path $projectDir ('release\android-'+$version)
New-Item -ItemType Directory -Path $output -Force | Out-Null
foreach($apk in Get-ChildItem -LiteralPath "android\app\build\outputs\apk\$variant" -Filter '*.apk'){
    $abi=if($apk.Name -match '(armeabi-v7a|arm64-v8a|x86_64|x86|universal)'){$Matches[1]}else{'universal'}
    Copy-Item -LiteralPath $apk.FullName -Destination (Join-Path $output ("Vyrax-$version-$abi-$variant.apk")) -Force
}
Write-Output ('Android APKs: '+$output)
