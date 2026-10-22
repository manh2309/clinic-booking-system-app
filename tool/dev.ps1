param(
    [ValidateSet('run', 'build', 'test', 'analyze')]
    [string]$Action = 'run',
    [string]$ApiBaseUrl = 'http://10.0.2.2:9000/api/v1',
    [string]$DeviceId = '',
    [string]$JdkPath = ''
)
$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = $mobileRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $repoRoot '.tools/flutter/bin/flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) {
    throw 'Chưa có Flutter SDK. Cài Flutter hoặc dùng SDK tại mobile/.tools/flutter.'
}
$apiUri = [uri]$ApiBaseUrl
if (-not $apiUri.IsAbsoluteUri -or $apiUri.Scheme -notin @('http', 'https') -or $apiUri.UserInfo -or $apiUri.Query -or $apiUri.Fragment) {
    throw 'ApiBaseUrl cần là URL HTTP/HTTPS không chứa tài khoản, query hoặc fragment.'
}
if ($JdkPath) { $env:JAVA_HOME = (Resolve-Path -LiteralPath $JdkPath).Path }
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Push-Location -LiteralPath $mobileRoot
try {
    & $flutterPath pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get chưa thành công.' }
    switch ($Action) {
        'analyze' { & $flutterPath analyze }
        'test' { & $flutterPath test }
        'build' { & $flutterPath build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl" }
        'run' {
            $runArguments = @('run', "--dart-define=API_BASE_URL=$ApiBaseUrl")
            if ($DeviceId) { $runArguments += @('-d', $DeviceId) }
            & $flutterPath @runArguments
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Flutter $Action chưa thành công. Xem thông báo bên trên." }
} finally {
    Pop-Location
}
