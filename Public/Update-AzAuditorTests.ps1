function Update-AzAuditorTests {
    <#
    .SYNOPSIS
        Updates Azure Auditor tests from the central GitHub repository.
    
    .DESCRIPTION
        Fetches the latest test manifest from GitHub and downloads new or updated test files
        to the module Tests directory. Compares versions to determine which tests need updating.
    
    .PARAMETER Force
        Downloads all tests without prompting, even if they haven't changed.
    
    .PARAMETER WhatIf
        Shows what changes would be made without actually downloading files.
    
    .EXAMPLE
        Update-AzAuditorTests
        
        Checks for updates and prompts before downloading.
    
    .EXAMPLE
        Update-AzAuditorTests -Force
        
        Downloads all tests without prompting.
    
    .EXAMPLE
        Update-AzAuditorTests -WhatIf
        
        Shows what would be updated without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        $repoUrl = "https://raw.githubusercontent.com/barto90/azauditor/main"
        $moduleRoot = Split-Path $PSScriptRoot -Parent
        $localTestPath = Join-Path $moduleRoot "Tests"
        $localManifestPath = Join-Path $moduleRoot "manifest.json"
        
        Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║       Azure Auditor - Test Update Check      ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    }
    
    process {
        try {
            # Fetch remote manifest
            Write-Host "Fetching latest test manifest..." -ForegroundColor Yellow
            $remoteManifestUrl = "$repoUrl/manifest.json"
            $remoteManifest = Invoke-RestMethod -Uri $remoteManifestUrl -ErrorAction Stop
            
            Write-Host "✓ Remote version: $($remoteManifest.version)" -ForegroundColor Green
            
            # Load local manifest
            $localManifest = $null
            if (Test-Path $localManifestPath) {
                $localManifest = Get-Content $localManifestPath -Raw | ConvertFrom-Json
                Write-Host "✓ Local version:  $($localManifest.version)" -ForegroundColor Cyan
            }
            else {
                Write-Host "⚠️ No local manifest found" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            
            # Compare and determine what needs updating
            $testsToDownload = @()
            $newTests = @()
            $updatedTests = @()
            
            foreach ($testPath in $remoteManifest.tests.PSObject.Properties.Name) {
                $remoteVersion = $remoteManifest.tests.$testPath
                $localVersion = if ($localManifest) { $localManifest.tests.$testPath } else { $null }
                
                if (-not $localVersion) {
                    # New test
                    $newTests += [PSCustomObject]@{
                        Path = $testPath
                        Version = $remoteVersion
                    }
                    $testsToDownload += $testPath
                }
                elseif ($remoteVersion -ne $localVersion -or $Force) {
                    # Updated test
                    $updatedTests += [PSCustomObject]@{
                        Path = $testPath
                        OldVersion = $localVersion
                        NewVersion = $remoteVersion
                    }
                    $testsToDownload += $testPath
                }
            }
            
            # Display changes
            if ($testsToDownload.Count -eq 0) {
                Write-Host ""
                Write-Host "✓ All tests are up to date!" -ForegroundColor Green
                Write-Host ""
                return
            }
            
            Write-Host ""
            if ($newTests.Count -gt 0) {
                Write-Host "  NEW TESTS ($($newTests.Count)):" -ForegroundColor Green
                foreach ($test in $newTests) {
                    Write-Host "    [+] $($test.Path) (v$($test.Version))" -ForegroundColor Cyan
                }
                Write-Host ""
            }
            
            if ($updatedTests.Count -gt 0) {
                Write-Host "  UPDATED TESTS ($($updatedTests.Count)):" -ForegroundColor Yellow
                foreach ($test in $updatedTests) {
                    Write-Host "    [↑] $($test.Path) ($($test.OldVersion) → $($test.NewVersion))" -ForegroundColor Cyan
                }
                Write-Host ""
            }
            
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            
            # Prompt for confirmation unless Force is specified
            if (-not $Force -and -not $WhatIfPreference) {
                Write-Host ""
                $response = Read-Host "Download and apply these changes? [Y/n]"
                if ($response -and $response -ne 'Y' -and $response -ne 'y') {
                    Write-Host "Update cancelled." -ForegroundColor Yellow
                    return
                }
            }
            
            if ($WhatIfPreference) {
                Write-Host ""
                Write-Host "WhatIf: Would download $($testsToDownload.Count) test file(s)" -ForegroundColor Cyan
                return
            }
            
            # Create local directory if it doesn't exist
            if (-not (Test-Path $localTestPath)) {
                New-Item -Path $localTestPath -ItemType Directory -Force | Out-Null
            }
            
            # Download tests
            Write-Host ""
            Write-Host "Downloading test files..." -ForegroundColor Yellow
            $downloadedCount = 0
            
            foreach ($testPath in $testsToDownload) {
                try {
                    $testUrl = "$repoUrl/Tests/$testPath"
                    $localFilePath = Join-Path $localTestPath $testPath
                    
                    # Create directory if needed
                    $localFileDir = Split-Path $localFilePath -Parent
                    if (-not (Test-Path $localFileDir)) {
                        New-Item -Path $localFileDir -ItemType Directory -Force | Out-Null
                    }
                    
                    # Download file
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($testUrl, $localFilePath)
                    
                    $downloadedCount++
                    Write-Host "  ✓ Downloaded: $testPath" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to download $testPath : $($_.Exception.Message)"
                }
            }
            
            # Save updated manifest
            $remoteManifest | ConvertTo-Json -Depth 10 | Set-Content $localManifestPath -Encoding UTF8
            
            Write-Host ""
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "✓ Update complete! Downloaded $downloadedCount file(s)" -ForegroundColor Green
            Write-Host "  Test location: $localTestPath" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            Write-Host ""
            Write-Host "❌ Error updating tests: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Possible causes:" -ForegroundColor Yellow
            Write-Host "  • No internet connection" -ForegroundColor Gray
            Write-Host "  • GitHub repository not accessible" -ForegroundColor Gray
            Write-Host "  • Invalid manifest format" -ForegroundColor Gray
            Write-Host ""
        }
    }
}
