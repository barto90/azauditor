function Start-AzAuditor {
    <#
    .SYNOPSIS
        Executes Azure compliance tests against configured resources.
    
    .DESCRIPTION
        Auto-discovers and runs all available compliance tests from the Tests directory.
        Tests are executed sequentially and results are collected into TestResult objects.
        Users can select which categories to test or run all tests.
    
    .PARAMETER Category
        Specifies which test categories to run. Use 'ALL' to run all tests, or specify one or more categories.
        If not specified, displays an interactive menu.
    
    .EXAMPLE
        Start-AzAuditor
        
        Displays interactive menu to select test categories.
    
    .EXAMPLE
        Start-AzAuditor -Category ALL
        
        Runs all available compliance tests.
    
    .EXAMPLE
        Start-AzAuditor -Category Compute, Networking
        
        Runs only Compute and Networking tests.
    
    .OUTPUTS
        TestResult[]
        Returns an array of TestResult objects containing the audit results.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Category
    )
    
    begin {
        Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║         Azure Auditor - Test Runner          ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        $allResults = @()
    }
    
    process {
        # Determine test location (local vs bundled)
        $localTestPath = Join-Path $env:APPDATA "AzAuditor\Tests"
        $bundledTestPath = Join-Path $PSScriptRoot "..\Tests"
        
        $testBasePath = if (Test-Path $localTestPath) {
            Write-Verbose "Using local tests from: $localTestPath"
            $localTestPath
        } else {
            Write-Verbose "Using bundled tests from: $bundledTestPath"
            
            # Suggest running Update-AzAuditorTests
            Write-Host "💡 Tip: Run " -NoNewline -ForegroundColor Cyan
            Write-Host "Update-AzAuditorTests" -NoNewline -ForegroundColor Yellow
            Write-Host " to download the latest tests from GitHub" -ForegroundColor Cyan
            Write-Host ""
            
            $bundledTestPath
        }
        
        # Discover only main orchestrator test files at category level
        $categoryDirs = Get-ChildItem -Path $testBasePath -Directory
        $availableCategories = @()
        $testFileMap = @{}
        
        foreach ($categoryDir in $categoryDirs) {
            # Only get Test-*.ps1 files directly in the category folder, not in subfolders
            $categoryTests = Get-ChildItem -Path $categoryDir.FullName -Filter "Test-*.ps1" -File
            
            if ($categoryTests) {
                $categoryName = $categoryDir.Name
                $availableCategories += $categoryName
                $testFileMap[$categoryName] = $categoryTests[0]
            }
        }
        
        if ($availableCategories.Count -eq 0) {
            Write-Warning "No test orchestrator files found in Tests directory."
            return $allResults
        }
        
        # If no category specified, show interactive menu
        if (-not $Category) {
            Write-Host "Available Test Categories:" -ForegroundColor Yellow
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "  [0] ALL - Run all tests" -ForegroundColor Green
            
            for ($i = 0; $i -lt $availableCategories.Count; $i++) {
                $icon = switch ($availableCategories[$i]) {
                    'Compute' { '💻' }
                    'Networking' { '🌐' }
                    'Database' { '🗄️' }
                    'Recovery' { '🔄' }
                    'Storage' { '💾' }
                    'Security' { '🔒' }
                    default { '📦' }
                }
                Write-Host "  [$($i + 1)] $icon $($availableCategories[$i])" -ForegroundColor Cyan
            }
            
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host ""
            
            $selection = Read-Host "Select categories to test (comma-separated numbers, or 0 for ALL)"
            
            if ($selection -eq '0') {
                $Category = @('ALL')
            }
            else {
                $selectedIndices = $selection -split ',' | ForEach-Object { $_.Trim() }
                $Category = @()
                
                foreach ($index in $selectedIndices) {
                    $idx = [int]$index - 1
                    if ($idx -ge 0 -and $idx -lt $availableCategories.Count) {
                        $Category += $availableCategories[$idx]
                    }
                }
                
                if ($Category.Count -eq 0) {
                    Write-Warning "Invalid selection. Running all tests."
                    $Category = @('ALL')
                }
            }
            
            Write-Host ""
        }
        
        # Determine which tests to run
        $testFilesToRun = @()
        
        if ($Category -contains 'ALL') {
            Write-Host "Running ALL test categories..." -ForegroundColor Green
            $testFilesToRun = $testFileMap.Values
        }
        else {
            Write-Host "Running selected categories: $($Category -join ', ')" -ForegroundColor Green
            foreach ($cat in $Category) {
                if ($testFileMap.ContainsKey($cat)) {
                    $testFilesToRun += $testFileMap[$cat]
                }
                else {
                    Write-Warning "Category '$cat' not found. Skipping."
                }
            }
        }
        
        if ($testFilesToRun.Count -eq 0) {
            Write-Warning "No test files to run."
            return $allResults
        }
        
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        
        # Load and execute each test
        foreach ($testFile in $testFilesToRun) {
            try {$re
                Write-Host "⚙️  Executing: $($testFile.Directory.Name) tests..." -ForegroundColor Cyan
                
                # Dot-source the test file to load the function
                . $testFile.FullName
                
                # Extract function name from file (assuming Test-*.ps1 contains function Test-*)
                $functionName = $testFile.BaseName
                
                # Check if function exists
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    # Execute the test and collect results
                    $testResults = & $functionName
                    
                    if ($testResults) {
                        $allResults += $testResults
                        $passCount = ($testResults | Where-Object { $_.ResultStatus -eq 'Pass' }).Count
                        $failCount = ($testResults | Where-Object { $_.ResultStatus -eq 'Fail' }).Count
                        
                        Write-Host "   ✓ Completed: $($testResults.Count) tests " -NoNewline -ForegroundColor Green
                        Write-Host "($passCount passed, $failCount failed)" -ForegroundColor Gray
                    }
                    else {
                        Write-Host "   ℹ No results returned" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Warning "Function '$functionName' not found in file: $($testFile.Name)"
                }
            }
            catch {
                Write-Warning "Error executing test '$($testFile.Name)': $($_.Exception.Message)"
                # Continue with next test
                continue
            }
        }
    }
    
    end {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        
        $totalPassed = ($allResults | Where-Object { $_.ResultStatus -eq 'Pass' }).Count
        $totalFailed = ($allResults | Where-Object { $_.ResultStatus -eq 'Fail' }).Count
        $passRate = if ($allResults.Count -gt 0) { [math]::Round(($totalPassed / $allResults.Count) * 100, 1) } else { 0 }
        
        Write-Host ""
        Write-Host "📊 Summary:" -ForegroundColor Yellow
        Write-Host "   Total Tests:  $($allResults.Count)" -ForegroundColor White
        Write-Host "   Passed:       $totalPassed ($passRate%)" -ForegroundColor Green
        Write-Host "   Failed:       $totalFailed" -ForegroundColor Red
        Write-Host ""
        
        if ($allResults.Count -gt 0) {
            Write-Host "💡 Tip: Use Export-AzAuditorReport to generate an HTML report" -ForegroundColor Cyan
        }
        
        Write-Host ""
        
        return $allResults
    }
}

