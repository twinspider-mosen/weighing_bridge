param (
    [string]$Version,
    [switch]$NoBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$PubspecPath = Join-Path $ScriptDir "pubspec.yaml"
$AppVersionDartPath = Join-Path $ScriptDir "lib\utils\app_version.dart"

if (-not (Test-Path $PubspecPath)) {
    Write-Error "pubspec.yaml not found in $ScriptDir"
}

# 1. Read current version from pubspec.yaml
$pubspecContent = Get-Content $PubspecPath -Raw
$currentVersionString = ""
$currentBuildNumber = 1

if ($pubspecContent -match 'version:\s*([^\r\n]+)') {
    $rawVersion = $matches[1].Trim()
    if ($rawVersion -match '^([^+\r\n]+)\+?([0-9]+)?$') {
        $currentVersionString = $matches[1]
        if ($matches[2]) {
            $currentBuildNumber = [int]$matches[2]
        }
    }
}

Write-Host "Current Configured Version: $rawVersion" -ForegroundColor Cyan

# 2. Generate CalVer (YYYY.MM.DD.Revision)
$todayPrefix = (Get-Date).ToString("yyyy.MM.dd")

if ($Version) {
    # Custom version passed manually
    $newVersion = $Version
    if ($newVersion -match '\+([0-9]+)$') {
        $buildNumber = [int]$matches[1]
        $versionName = $newVersion -replace '\+[0-9]+$', ''
    } else {
        $buildNumber = $currentBuildNumber + 1
        $versionName = $newVersion
    }
} else {
    # Check if existing version matches today's date
    if ($currentVersionString -match "^$todayPrefix\.([0-9]+)$") {
        $todayRevision = [int]$matches[1] + 1
    } else {
        $todayRevision = 1
    }
    $versionName = "$todayPrefix.$todayRevision"
    $buildNumber = $todayRevision
}

$newFullVersion = "$versionName+$buildNumber"
Write-Host "New Version: $versionName (Full: $newFullVersion)" -ForegroundColor Green

# 3. Update pubspec.yaml
# Flutter Windows requires 3-segment semver in pubspec.yaml (e.g., YYYY.MM.DD+Build)
$pubspecSemver = "$todayPrefix+$buildNumber"
$updatedPubspec = $pubspecContent -replace 'version:\s*[^\r\n]+', "version: $pubspecSemver"
Set-Content -Path $PubspecPath -Value $updatedPubspec -NoNewline
Write-Host "Updated pubspec.yaml with version: $pubspecSemver" -ForegroundColor Gray

# 4. Update lib/utils/app_version.dart with the exact 4-part CalVer (YYYY.MM.DD.Revision)
$appVersionCode = @"
/// Application version configuration.
/// Auto-updated during build execution.
class AppVersion {
  static const String version = '$versionName';
  static const int buildNumber = $buildNumber;

  static String get fullVersion => 'v`$version';
  static String get displayVersion => 'v`$version';
}
"@

Set-Content -Path $AppVersionDartPath -Value $appVersionCode
Write-Host "Updated lib/utils/app_version.dart with version: $versionName" -ForegroundColor Gray

# 5. Build Windows Release
if (-not $NoBuild) {
    Write-Host "`nStarting Flutter Windows Release Build..." -ForegroundColor Yellow
    flutter build windows --release --build-name=$todayPrefix --build-number=$buildNumber
    
    if ($LASTEXITCODE -eq 0) {
        $ReleaseExe = Join-Path $ScriptDir "build\windows\x64\runner\Release\spider_weighbridge.exe"
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "Build Succeeded Successfully!" -ForegroundColor Green
        Write-Host "Release Artifact: $ReleaseExe" -ForegroundColor Cyan
        Write-Host "App Display Version: v$versionName" -ForegroundColor Green
        Write-Host "========================================================`n" -ForegroundColor Green
    } else {
        Write-Error "Flutter build failed with exit code $LASTEXITCODE"
    }
}
