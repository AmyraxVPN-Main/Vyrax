$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectDir
$version = (Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json).version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid source version' }
$sourceDir = Join-Path $projectDir ('release\source-' + $version)
if (Test-Path -LiteralPath $sourceDir) { throw 'Source staging folder already exists; inspect it before replacing' }
New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
$paths = @('.gitignore','.gitattributes','LICENSE','README.md','THIRD_PARTY_NOTICES.md','package.json','package-lock.json','project.json','index.html','vite.config.js','src','public','native','scripts','docs','third_party','android','vendor/versions.json','vendor/android-versions.json','.tools/selftest','.tools/gen-geo.mjs','.tools/parse-test.mjs')
foreach ($relative in $paths) {
    $inputPath = Join-Path $projectDir $relative
    if (!(Test-Path -LiteralPath $inputPath)) { throw ('Missing source path: ' + $relative) }
    $items = if ((Get-Item -LiteralPath $inputPath).PSIsContainer) { Get-ChildItem -LiteralPath $inputPath -Recurse -File } else { Get-Item -LiteralPath $inputPath }
    foreach ($item in $items) {
        if ($item.Extension -in @('.bin','.log','.exe','.dll','.pdb','.dmp','.zip','.nupkg')) { continue }
        $local = $item.FullName.Substring($projectDir.Length + 1)
        if ($local -match '^android\\(\.gradle\\|(?:.*\\)?build\\|app\\src\\main\\assets\\|local\.properties$)' -or $item.Extension -in @('.apk','.aab','.jks','.keystore')) { continue }
        $destination = Join-Path $sourceDir $local
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $item.FullName -Destination $destination -Force
    }
}
$archive = Join-Path $projectDir ('release\VyraxSource-' + $version + '.zip')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporaryArchive = Join-Path $projectDir ('release\source-' + [Guid]::NewGuid().ToString('N') + '.zip')
$zip = [IO.Compression.ZipFile]::Open($temporaryArchive, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($item in Get-ChildItem -LiteralPath $sourceDir -Recurse -File -Force) {
        # ZIP paths use '/' so the same source archive extracts correctly on every OS.
        $entryName = $item.FullName.Substring($sourceDir.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $item.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} catch {
    $zip.Dispose()
    Remove-Item -LiteralPath $temporaryArchive -Force
    throw
} finally { $zip.Dispose() }
Move-Item -LiteralPath $temporaryArchive -Destination $archive -Force
Write-Output ('Source archive: ' + $archive)
