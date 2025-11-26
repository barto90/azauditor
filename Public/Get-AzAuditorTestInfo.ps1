function Get-AzAuditorTestInfo {
    <#
    .SYNOPSIS
        Displays information about the currently installed Azure Auditor tests.
    
    .DESCRIPTION
        Shows test source, location, version, and count. Also checks for available updates
        from the GitHub repository.
    
    .EXAMPLE
        Get-AzAuditorTestInfo
        
        Displays test information and checks for updates.
    #>
    [CmdletBinding()]
    param()
    
    process {
        $moduleRoot = Split-Path $PSScriptRoot -Parent
        $localManifestPath = Join-Path $moduleRoot "manifest.json"
        $localTestPath = Join-Path $moduleRoot "Tests"
        
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║      Azure Auditor - Test Information        ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Check local manifest
        if (Test-Path $localManifestPath) {
            $localManifest = Get-Content $localManifestPath -Raw | ConvertFrom-Json
            $allFiles = @($localManifest.tests.PSObject.Properties)
            $orchestrators = $allFiles | Where-Object { $_.Name -match '^[^/]+/Test-[^/]+\.ps1$' }
            $actualTests = $allFiles | Where-Object { $_.Name -match '/' -and $_.Name -notmatch '^[^/]+/Test-[^/]+\.ps1$' }
            
            Write-Host "📦 Test Source:    " -NoNewline -ForegroundColor Yellow
            Write-Host "Module" -ForegroundColor Green
            Write-Host "📍 Test Location:  " -NoNewline -ForegroundColor Yellow
            Write-Host $localTestPath -ForegroundColor Cyan
            Write-Host "🏷️ Version:        " -NoNewline -ForegroundColor Yellow
            Write-Host "v$($localManifest.version)" -ForegroundColor Green
            Write-Host "📅 Last Updated:   " -NoNewline -ForegroundColor Yellow
            Write-Host $localManifest.lastUpdated -ForegroundColor Gray
            Write-Host "🧪 Test Count:     " -NoNewline -ForegroundColor Yellow
            Write-Host "$($actualTests.Count) tests" -NoNewline -ForegroundColor White
            Write-Host " + $($orchestrators.Count) orchestrators" -ForegroundColor Gray
        }
        else {
            Write-Host "⚠️  No manifest found!" -ForegroundColor Red
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
            $headers = @{ 'Cache-Control' = 'no-cache' }
            $remoteManifest = Invoke-RestMethod -Uri "$repoUrl/manifest.json" -Headers $headers -TimeoutSec 3 -ErrorAction Stop
            
            if (Test-Path $localManifestPath) {
                $localManifest = Get-Content $localManifestPath -Raw | ConvertFrom-Json
                
                # Compare individual test files
                $remoteTests = @($remoteManifest.tests.PSObject.Properties)
                $localTests = @($localManifest.tests.PSObject.Properties)
                
                $newTests = $remoteTests | Where-Object { $_.Name -notin $localTests.Name }
                $updatedTests = $remoteTests | Where-Object { 
                    $testName = $_.Name
                    $local = $localTests | Where-Object { $_.Name -eq $testName }
                    $local -and $_.Value -ne $local.Value
                }
                $removedTests = $localTests | Where-Object { $_.Name -notin $remoteTests.Name }
                
                $hasUpdates = ($newTests.Count -gt 0) -or ($updatedTests.Count -gt 0) -or ($removedTests.Count -gt 0)
                
                if ($hasUpdates) {
                    Write-Host ""
                    Write-Host "🆕 Updates Available!" -ForegroundColor Green
                    
                    if ($newTests.Count -gt 0) {
                        Write-Host "   📥 $($newTests.Count) new test(s)" -ForegroundColor Cyan
                    }
                    if ($updatedTests.Count -gt 0) {
                        Write-Host "   🔄 $($updatedTests.Count) updated test(s)" -ForegroundColor Yellow
                    }
                    if ($removedTests.Count -gt 0) {
                        Write-Host "   🗑️  $($removedTests.Count) removed test(s)" -ForegroundColor Red
                    }
                    
                    Write-Host ""
                    Write-Host "   Run " -NoNewline -ForegroundColor Gray
                    Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Cyan
                    Write-Host " to update" -ForegroundColor Gray
                }
                else {
                    Write-Host "✓ Tests are up to date (v$($localManifest.version))" -ForegroundColor Green
                }
            }
            else {
                Write-Host "⚠️  No local manifest found" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Run " -NoNewline -ForegroundColor Gray
                Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Cyan
                Write-Host " to download tests" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "⚠️  Could not check for updates (offline or repository unavailable)" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
}
