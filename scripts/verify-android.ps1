param([string]$SdkRoot=$env:ANDROID_HOME)
$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
if(-not $SdkRoot){$SdkRoot=Join-Path $projectDir '.tools\android\sdk'}
if(-not $env:JAVA_HOME){$env:JAVA_HOME=(Get-ChildItem (Join-Path $projectDir '.tools\android\jdk') -Directory | Select-Object -First 1).FullName}
$buildTools=Join-Path $SdkRoot 'build-tools\35.0.0'
$version=(Get-Content (Join-Path $projectDir 'package.json') -Raw | ConvertFrom-Json).version
$output=Join-Path $projectDir ('release\android-'+$version)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$certificate=$null
$results=foreach($apk in Get-ChildItem $output -Filter '*-release.apk'){
    $abi=([regex]::Match($apk.Name,'(armeabi-v7a|arm64-v8a|x86_64|x86|universal)')).Value
    $expected=if($abi -eq 'universal'){@('armeabi-v7a','arm64-v8a','x86','x86_64')}else{@($abi)}
    $badging=& "$buildTools\aapt.exe" dump badging $apk.FullName
    if($LASTEXITCODE -ne 0 -or $badging[0] -notmatch "name='com.amyrax.vyrax'.*versionName='$([regex]::Escape($version))'" -or $badging -notcontains "sdkVersion:'29'"){throw 'APK identity/minimum Android version is incorrect'}
    if($badging -contains 'application-debuggable'){throw 'Distributable APK must not be debuggable'}
    $signature=& "$buildTools\apksigner.bat" verify --verbose --print-certs $apk.FullName
    if($LASTEXITCODE -ne 0){throw 'APK signature verification failed'}
    $digest=([regex]::Match(($signature -join "`n"),'certificate SHA-256 digest: ([a-f0-9]+)')).Groups[1].Value
    if(-not $digest -or ($certificate -and $digest -ne $certificate)){throw 'APK variants must have the same owner signature'}
    $certificate=$digest
    $previous=Join-Path $projectDir 'release\android-0.1.18\Vyrax-0.1.18-arm64-v8a-release.apk'
    if(Test-Path -LiteralPath $previous){
        $previousSignature=& "$buildTools\apksigner.bat" verify --print-certs $previous
        $previousDigest=([regex]::Match(($previousSignature -join "`n"),'certificate SHA-256 digest: ([a-f0-9]+)')).Groups[1].Value
        if($LASTEXITCODE -ne 0 -or $previousDigest -ne $digest){throw 'Signing identity changed; existing users cannot upgrade'}
    }
    & "$buildTools\zipalign.exe" -c -P 16 4 $apk.FullName
    if($LASTEXITCODE -ne 0){throw 'APK native-library page alignment failed'}
    $zip=[IO.Compression.ZipFile]::OpenRead($apk.FullName)
    try{
        $libraries=@($zip.Entries | Where-Object {$_.FullName -match '^lib/[^/]+/[^/]+\.so$'})
        $actual=@($libraries | ForEach-Object {$_.FullName.Split('/')[1]} | Sort-Object -Unique)
        if(@(Compare-Object ($expected | Sort-Object) $actual).Count -ne 0){throw 'APK contains incorrect CPU architectures'}
        foreach($entry in $libraries){
            if($entry.Length -ne $entry.CompressedLength){throw 'Native libraries must be stored uncompressed'}
            $stream=$entry.Open();$memory=[IO.MemoryStream]::new()
            try{$stream.CopyTo($memory);$bytes=$memory.ToArray()}finally{$stream.Dispose();$memory.Dispose()}
            if($bytes[0] -ne 127 -or [Text.Encoding]::ASCII.GetString($bytes,1,3) -ne 'ELF'){throw 'Invalid native library'}
            $is64=$bytes[4] -eq 2
            $phoff=if($is64){[BitConverter]::ToUInt64($bytes,32)}else{[BitConverter]::ToUInt32($bytes,28)}
            $phsize=[BitConverter]::ToUInt16($bytes, $(if($is64){54}else{42}))
            $phnum=[BitConverter]::ToUInt16($bytes, $(if($is64){56}else{44}))
            for($i=0;$i -lt $phnum;$i++){
                $p=[int]($phoff+$i*$phsize)
                if([BitConverter]::ToUInt32($bytes,$p) -ne 1){continue}
                $align=if($is64){[BitConverter]::ToUInt64($bytes,$p+48)}else{[BitConverter]::ToUInt32($bytes,$p+28)}
                if($align -lt $(if($is64){16384}else{4096})){throw ('Native ELF page alignment failed: '+$entry.FullName)}
            }
        }
        foreach($asset in @('assets/ui/index.html','assets/project.json','assets/licenses/LICENSE','assets/licenses/AndroidLibXrayLite-LGPL-3.0.txt','assets/licenses/Xray-MPL-2.0.txt')){if(-not $zip.GetEntry($asset)){throw ('Missing bundled asset: '+$asset)}}
        if($zip.Entries | Where-Object {$_.FullName -match '(?i)(\.jks$|\.keystore$|profiles\.enc$|last-tunnel|\.log$)'}){throw 'Private or diagnostic file found in APK'}
    }finally{$zip.Dispose()}
    [pscustomobject]@{file=$apk.Name;bytes=$apk.Length;sha256=(Get-FileHash $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant();architectures=$actual;version=$version;minSdk=29;targetSdk=35;certificateSha256=$digest;nativeLibraries=$libraries.Count;pageAlignment64=16384}
}
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'verification.json') -Encoding utf8
Write-Output ('Verified signatures, architectures, bundled assets and page alignment for '+@($results).Count+' APKs.')
