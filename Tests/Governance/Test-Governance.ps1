function Test-Governance {
    <#
    .SYNOPSIS
        Executes all Governance resource compliance tests.
    
    .DESCRIPTION
        Orchestrates all governance-related compliance tests against Azure tenant.
        These are tenant-level tests that run once per tenant (not per subscription).
        
        By default, uses parallel processing for faster execution.
        Use -Sequential flag for traditional sequential processing.
    
    .PARAMETER Sequential
        Forces sequential processing instead of parallel. Useful for troubleshooting.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Sequential
    )
    
    # Get module root and load TestResult class
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $classPath = Join-Path $moduleRoot "Classes\TestResult.ps1"
    . $classPath
    
    # Collect all results (must be after TestResult class is loaded)
    $allResults = [System.Collections.Generic.List[TestResult]]::new()
    
    # Discover all governance test files in subfolders (ManagementGroups, Policy, etc.)
    $governanceTestFiles = @(Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot })  # Exclude the orchestrator itself
    
    if ($governanceTestFiles.Count -eq 0) {
        Write-Warning "No governance test files found in $PSScriptRoot subfolders"
        return @()
    }
    
    Write-Verbose "Discovered $($governanceTestFiles.Count) governance test file(s)"
    
    # Load all test functions
    foreach ($testFile in $governanceTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get current context to determine active tenant
    $currentContext = Get-AzContext
    if (-not $currentContext) {
        Write-Warning "No Azure context found. Please run Connect-AzAccount first."
        return @()
    }
    
    $tenantId = $currentContext.Tenant.Id
    Write-Verbose "Running governance tests for tenant: $tenantId"
    
    # Get all subscriptions for subscription-based tests
    $subscriptions = @(Get-AzSubscription -TenantId $tenantId | Where-Object { $_.State -eq 'Enabled' })
    Write-Verbose "Found $($subscriptions.Count) enabled subscription(s) in tenant"
    
    # Governance tests can be tenant-level OR subscription-level
    # Determine test type by checking function parameters
    
    if ($Sequential) {
        # Sequential Processing
        Write-Verbose "Using sequential processing mode"
        
        foreach ($testFile in $governanceTestFiles) {
            $functionName = $testFile.BaseName
            
            if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                Write-Verbose "Executing test: $functionName"
                
                try {
                    # Check if test requires Subscription or TenantId parameter
                    $command = Get-Command $functionName
                    $isTenantLevel = $command.Parameters.ContainsKey('TenantId')
                    $isSubscriptionLevel = $command.Parameters.ContainsKey('Subscription')
                    
                    if ($isTenantLevel) {
                        # Tenant-level test (runs once)
                        $testResults = & $functionName -TenantId $tenantId
                        
                        if ($testResults) {
                            foreach ($result in $testResults) {
                                $allResults.Add($result)
                            }
                            Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
                        }
                    }
                    elseif ($isSubscriptionLevel) {
                        # Subscription-level test (runs per subscription)
                        foreach ($subscription in $subscriptions) {
                            Write-Verbose "Running $functionName for subscription: $($subscription.Name)"
                            
                            # Set context to subscription
                            Set-AzContext -SubscriptionId $subscription.Id -Force | Out-Null
                            
                            $testResults = & $functionName -Subscription $subscription
                            
                            if ($testResults) {
                                foreach ($result in $testResults) {
                                    $allResults.Add($result)
                                }
                                Write-Verbose "Test completed for $($subscription.Name): $functionName - Collected $($testResults.Count) result(s)"
                            }
                        }
                    }
                    else {
                        Write-Warning "Test $functionName has no TenantId or Subscription parameter - skipping"
                    }
                }
                catch {
                    Write-Warning "Error executing test '$functionName': $($_.Exception.Message)"
                    continue
                }
            }
        }
    }
    else {
        # Parallel Processing
        Write-Verbose "Using parallel processing mode"
        
        # Separate tenant-level and subscription-level tests
        $tenantLevelTests = @()
        $subscriptionLevelTests = @()
        
        foreach ($testFile in $governanceTestFiles) {
            . $testFile.FullName
            $command = Get-Command $testFile.BaseName -ErrorAction SilentlyContinue
            
            if ($command) {
                $testInfo = @{
                    FullName = $testFile.FullName
                    BaseName = $testFile.BaseName
                }
                
                if ($command.Parameters.ContainsKey('TenantId')) {
                    $tenantLevelTests += $testInfo
                }
                elseif ($command.Parameters.ContainsKey('Subscription')) {
                    $subscriptionLevelTests += $testInfo
                }
            }
        }
        
        Write-Verbose "Tenant-level tests: $($tenantLevelTests.Count), Subscription-level tests: $($subscriptionLevelTests.Count)"
        
        # Use the class path already loaded above
        # (moduleRoot and classPath are already set at the top of the function)
        
        # Run tenant-level tests in parallel
        if ($tenantLevelTests.Count -gt 0) {
            $parallelResults = $tenantLevelTests | ForEach-Object -ThrottleLimit 5 -Parallel {
                $testFile = $_
                $tenant = $using:tenantId
                $classFilePath = $using:classPath
                
                try {
                    # Load TestResult class
                    . $classFilePath
                    
                    # Load the test function
                    . $testFile.FullName
                    
                    $functionName = $testFile.BaseName
                    
                    if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                        # Execute the test with TenantId
                        $testResults = & $functionName -TenantId $tenant
                        
                        if ($testResults) {
                            $testResults
                        }
                    }
                }
                catch {
                    Write-Warning "Error executing test '$($testFile.BaseName)': $($_.Exception.Message)"
                    @()
                }
            }
            
            # Collect tenant-level results
            if ($parallelResults) {
                foreach ($result in $parallelResults) {
                    if ($result) {
                        $allResults.Add($result)
                    }
                }
            }
        }
        
        # Run subscription-level tests in parallel (per subscription)
        if ($subscriptionLevelTests.Count -gt 0) {
            $parallelResults = $subscriptions | ForEach-Object -ThrottleLimit 5 -Parallel {
                $subscription = $_
                $tests = $using:subscriptionLevelTests
                $classFilePath = $using:classPath
                
                # Set context for this subscription
                Set-AzContext -SubscriptionId $subscription.Id -Force | Out-Null
                
                $subscriptionResults = @()
                
                foreach ($testFile in $tests) {
                    try {
                        # Load TestResult class
                        . $classFilePath
                        
                        # Load the test function
                        . $testFile.FullName
                        
                        $functionName = $testFile.BaseName
                        
                        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                            # Execute the test with Subscription
                            $testResults = & $functionName -Subscription $subscription
                            
                            if ($testResults) {
                                $subscriptionResults += $testResults
                            }
                        }
                    }
                    catch {
                        Write-Warning "Error executing test '$($testFile.BaseName)' for $($subscription.Name): $($_.Exception.Message)"
                    }
                }
                
                # Output all results for this subscription
                $subscriptionResults
            }
            
            # Collect subscription-level results
            if ($parallelResults) {
                foreach ($result in $parallelResults) {
                    if ($result) {
                        $allResults.Add($result)
                    }
                }
            }
        }
    }
    
    return @($allResults)
}

