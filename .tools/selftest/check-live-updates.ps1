$ErrorActionPreference = 'Stop'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $projectDir 'release\Vyrax\Vyrax.exe'))
$method = $assembly.GetType('Vyrax.AppUpdates').GetMethod('Latest')
$request = $method.Invoke($null,@())
$result = $request.GetAwaiter().GetResult()
if ($null -eq $result['release']) {
    Write-Output 'Live configured GitHub endpoint: no published release; no update banner.'
} else {
    Write-Output ('Live configured GitHub endpoint returned published release metadata: ' + $result['release']['tag_name'])
}
