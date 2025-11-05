function Test-Recovery {
    <#
    .SYNOPSIS
        Executes all Recovery and Disaster Recovery compliance tests.
    
    .DESCRIPTION
        Orchestrates all recovery-related compliance tests against Azure subscriptions.
        Optimized to collect Recovery Services Vaults and VMs once, then discovers and runs
        all individual recovery tests passing the collected data to each test for efficiency.
    #>
    [CmdletBinding()]
    param()
    
    # Collect all results
    $allResults = @()
    
    # Discover all recovery test files in subfolders (SiteRecovery, Backup, etc.)
    $recoveryTestFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot }  # Exclude the orchestrator itself
    
    if ($recoveryTestFiles.Count -eq 0) {
        Write-Warning "No recovery test files found in $PSScriptRoot subfolders"
        return $allResults
    }
    
    Write-Verbose "Discovered $($recoveryTestFiles.Count) recovery test file(s)"
    
    # Load all test functions
    foreach ($testFile in $recoveryTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get all subscriptions and iterate
    Get-AzSubscription | ForEach-Object {
        $subscription = $_
        Set-AzContext $_.Id | Out-Null
        
        Write-Verbose "Processing subscription: $($subscription.Name)"
        
        # Get all Recovery Services Vaults once for this subscription
        $recoveryVaults = @(Get-AzRecoveryServicesVault)
        
        # Get all VMs once for this subscription (needed for cross-referencing)
        $vms = @(Get-AzVM)
        
        # Collect protected items from all vaults
        $protectedItems = @()
        if ($recoveryVaults.Count -gt 0 -and $null -ne $recoveryVaults[0]) {
            Write-Verbose "Found $($recoveryVaults.Count) Recovery Services Vault(s) in subscription $($subscription.Name)"
            
            foreach ($vault in $recoveryVaults) {
                try {
                    # Set vault context
                    Set-AzRecoveryServicesVaultContext -Vault $vault | Out-Null
                    Write-Verbose "Processing vault: $($vault.Name)"
                    
                    # Get ASR fabrics for this vault
                    $fabrics = Get-AzRecoveryServicesAsrFabric -ErrorAction SilentlyContinue
                    
                    if ($fabrics) {
                        foreach ($fabric in $fabrics) {
                            # Get protection containers for this fabric
                            $containers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -ErrorAction SilentlyContinue
                            
                            if ($containers) {
                                foreach ($container in $containers) {
                                    # Get protected items from this container
                                    $containerProtectedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -ErrorAction SilentlyContinue
                                    
                                    if ($containerProtectedItems) {
                                        $protectedItems += $containerProtectedItems
                                        Write-Verbose "Found $(@($containerProtectedItems).Count) protected item(s) in container $($container.Name)"
                                    }
                                }
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Error querying vault '$($vault.Name)': $($_.Exception.Message)"
                    continue
                }
            }
        }
        else {
            Write-Verbose "No Recovery Services Vaults found in subscription $($subscription.Name)"
        }
        
        # Run tests only if we have VMs
        if ($vms.Count -gt 0 -and $null -ne $vms[0]) {
            Write-Verbose "Found $($vms.Count) VM(s) in subscription $($subscription.Name)"
            
            # Run each discovered test function
            foreach ($testFile in $recoveryTestFiles) {
                $functionName = $testFile.BaseName
                
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    Write-Verbose "Executing test: $functionName"
                    
                    try {
                        # Call test function with VMs, Protected Items, and Subscription
                        $testResults = & $functionName -VMs $vms -ProtectedItems $protectedItems -Subscription $subscription
                        
                        if ($testResults) {
                            $allResults += $testResults
                            Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
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

