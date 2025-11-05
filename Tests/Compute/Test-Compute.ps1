function Test-Compute {
    <#
    .SYNOPSIS
        Executes all Compute resource compliance tests.
    
    .DESCRIPTION
        Orchestrates all VM-related compliance tests against Azure subscriptions.
        Optimized to collect VM data once, then discovers and runs all individual compute tests
        passing the collected data to each test for efficiency.
    #>
    [CmdletBinding()]
    param()
    
    # Collect all results
    $allResults = @()
    
    # Discover all compute test files in subfolders (VM, VMSS, Disks, etc.)
    $computeTestFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot }  # Exclude the orchestrator itself
    
    if ($computeTestFiles.Count -eq 0) {
        Write-Warning "No compute test files found in $PSScriptRoot subfolders"
        return $allResults
    }
    
    Write-Verbose "Discovered $($computeTestFiles.Count) compute test file(s)"
    
    # Load all test functions
    foreach ($testFile in $computeTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get all subscriptions and iterate
    Get-AzSubscription | ForEach-Object {
        $subscription = $_
        Set-AzContext $_.Id | Out-Null
        
        Write-Verbose "Processing subscription: $($subscription.Name)"
        
        # Get all VMs once for this subscription
        $vms = @(Get-AzVM)  # Force array to ensure .Count works correctly
        
        if ($vms.Count -gt 0 -and $null -ne $vms[0]) {
            Write-Verbose "Found $($vms.Count) VM(s) in subscription $($subscription.Name)"
            
            # Run each discovered test function, passing the VMs
            foreach ($testFile in $computeTestFiles) {
                $functionName = $testFile.BaseName
                
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    Write-Verbose "Executing test: $functionName"
                    
                    try {
                        # Double-check VMs array is valid before calling
                        if ($vms -and $vms.Count -gt 0) {
                            # Call test function with VMs and Subscription
                            $testResults = & $functionName -VMs $vms -Subscription $subscription
                            
                            if ($testResults) {
                                $allResults += $testResults
                                Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
                            }
                        }
                        else {
                            Write-Verbose "Skipping test $functionName - no VMs to process"
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
            Write-Verbose "No VMs found in subscription $($subscription.Name)"
        }
    }
    
    return $allResults
}
