function Get-AzAuditorTestInfo {
    <#
    .SYNOPSIS
        Displays information about installed Azure Auditor tests.
    
    .DESCRIPTION
        Shows the current version of tests, whether local or bundled tests are being used,
        and the location of test files.
    
    .EXAMPLE
        Get-AzAuditorTestInfo
        
        Displays test version and location information.
    #>
    [CmdletBinding()]
    param()
    
    $localTestPath = Join-Path $env:APPDATA "AzAuditor\Tests"
    $localManifestPath = Join-Path $env:APPDATA "AzAuditor\manifest.json"
    $bundledManifestPath = Join-Path $PSScriptRoot "..\manifest.json"
    
    Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      Azure Auditor - Test Information       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Check local tests
    if (Test-Path $localManifestPath) {
        $localManifest = Get-Content $localManifestPath -Raw | ConvertFrom-Json
        $testCount = $localManifest.tests.PSObject.Properties.Count
        
        Write-Host "📦 Test Source:    " -NoNewline -ForegroundColor Yellow
        Write-Host "Local (Downloaded)" -ForegroundColor Green
        Write-Host "📍 Test Location:  " -NoNewline -ForegroundColor Yellow
        Write-Host $localTestPath -ForegroundColor Cyan
        Write-Host "🏷️  Version:        " -NoNewline -ForegroundColor Yellow
        Write-Host "v$($localManifest.version)" -ForegroundColor Green
        Write-Host "📅 Last Updated:   " -NoNewline -ForegroundColor Yellow
        Write-Host $localManifest.lastUpdated -ForegroundColor Gray
        Write-Host "🧪 Test Count:     " -NoNewline -ForegroundColor Yellow
        Write-Host "$testCount tests" -ForegroundColor White
    }
    # Check bundled tests
    elseif (Test-Path $bundledManifestPath) {
        $bundledManifest = Get-Content $bundledManifestPath -Raw | ConvertFrom-Json
        $testCount = $bundledManifest.tests.PSObject.Properties.Count
        $bundledTestPath = Join-Path $PSScriptRoot "..\Tests"
        
        Write-Host "📦 Test Source:    " -NoNewline -ForegroundColor Yellow
        Write-Host "Bundled (Module)" -ForegroundColor Cyan
        Write-Host "📍 Test Location:  " -NoNewline -ForegroundColor Yellow
        Write-Host $bundledTestPath -ForegroundColor Cyan
        Write-Host "🏷️  Version:        " -NoNewline -ForegroundColor Yellow
        Write-Host "v$($bundledManifest.version)" -ForegroundColor Green
        Write-Host "🧪 Test Count:     " -NoNewline -ForegroundColor Yellow
        Write-Host "$testCount tests" -ForegroundColor White
        
        Write-Host ""
        Write-Host "💡 Tip: Run " -NoNewline -ForegroundColor Cyan
        Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Yellow
        Write-Host " to download latest tests" -ForegroundColor Cyan
    }
    else {
        Write-Host "⚠️  No tests found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Run " -NoNewline -ForegroundColor Yellow
        Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Cyan
        Write-Host " to download tests." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    
    # Check for updates
    try {
        Write-Host ""
        Write-Host "Checking for updates..." -ForegroundColor Gray
        $repoUrl = "https://raw.githubusercontent.com/barto90/azauditor/main"
        $remoteManifest = Invoke-RestMethod -Uri "$repoUrl/manifest.json" -TimeoutSec 3 -ErrorAction Stop
        
        $currentVersion = if (Test-Path $localManifestPath) {
            (Get-Content $localManifestPath -Raw | ConvertFrom-Json).version
        } elseif (Test-Path $bundledManifestPath) {
            (Get-Content $bundledManifestPath -Raw | ConvertFrom-Json).version
        } else {
            "0.0.0"
        }
        
        if ($remoteManifest.version -ne $currentVersion) {
            Write-Host ""
            Write-Host "🆕 Update Available!" -ForegroundColor Green
            Write-Host "   Current: v$currentVersion" -ForegroundColor Gray
            Write-Host "   Latest:  v$($remoteManifest.version)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Run " -NoNewline -ForegroundColor Gray
            Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Cyan
            Write-Host " to update" -ForegroundColor Gray
        }
        else {
            Write-Host "✓ Tests are up to date (v$currentVersion)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️  Could not check for updates (offline or repository unavailable)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

