function Test-Networking {
    <#
    .SYNOPSIS
        Executes all Networking resource compliance tests.
    
    .DESCRIPTION
        Orchestrates all networking-related compliance tests against Azure subscriptions.
        Optimized to collect networking resources once, then discovers and runs all individual networking tests
        passing the collected data to each test for efficiency.
    #>
    [CmdletBinding()]
    param()
    
    # Collect all results
    $allResults = @()
    
    # Discover all networking test files in subfolders (LoadBalancer, NSG, VNet, etc.)
    $networkingTestFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot }  # Exclude the orchestrator itself
    
    if ($networkingTestFiles.Count -eq 0) {
        Write-Warning "No networking test files found in $PSScriptRoot subfolders"
        return $allResults
    }
    
    Write-Verbose "Discovered $($networkingTestFiles.Count) networking test file(s)"
    
    # Load all test functions
    foreach ($testFile in $networkingTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get all subscriptions and iterate
    Get-AzSubscription | ForEach-Object {
        $subscription = $_
        Set-AzContext $_.Id | Out-Null
        
        Write-Verbose "Processing subscription: $($subscription.Name)"
        
        # Get all Load Balancers once for this subscription
        $loadBalancers = @(Get-AzLoadBalancer)
        
        if ($loadBalancers.Count -gt 0 -and $null -ne $loadBalancers[0]) {
            Write-Verbose "Found $($loadBalancers.Count) Load Balancer(s) in subscription $($subscription.Name)"
            
            # Run each discovered test function, passing the Load Balancers
            foreach ($testFile in $networkingTestFiles) {
                $functionName = $testFile.BaseName
                
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    Write-Verbose "Executing test: $functionName"
                    
                    try {
                        # Double-check Load Balancers array is valid before calling
                        if ($loadBalancers -and $loadBalancers.Count -gt 0) {
                            # Call test function with Load Balancers and Subscription
                            $testResults = & $functionName -LoadBalancers $loadBalancers -Subscription $subscription
                            
                            if ($testResults) {
                                $allResults += $testResults
                                Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
                            }
                        }
                        else {
                            Write-Verbose "Skipping test $functionName - no Load Balancers to process"
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
            Write-Verbose "No Load Balancers found in subscription $($subscription.Name)"
        }
    }
    
    return $allResults
}

