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
    
    # Get module root and load TestResult class
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $classPath = Join-Path $moduleRoot "Classes\TestResult.ps1"
    . $classPath
    
    # Collect all results (must be after TestResult class is loaded)
    $allResults = [System.Collections.Generic.List[TestResult]]::new()
    
    # Discover all recovery test files in subfolders (SiteRecovery, Backup, etc.)
    $recoveryTestFiles = @(Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot })  # Exclude the orchestrator itself
    
    if ($recoveryTestFiles.Count -eq 0) {
        Write-Warning "No recovery test files found in $PSScriptRoot subfolders"
        return @()
    }
    
    Write-Verbose "Discovered $($recoveryTestFiles.Count) recovery test file(s)"
    
    # Load all test functions
    foreach ($testFile in $recoveryTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get current context to determine active tenant
    $currentContext = Get-AzContext
    if (-not $currentContext) {
        Write-Warning "No Azure context found. Please run Connect-AzAccount first."
        return @()
    }
    
    # Get subscriptions filtered by current tenant
    $subscriptions = @(Get-AzSubscription -TenantId $currentContext.Tenant.Id)
    if ($subscriptions.Count -eq 0) {
        Write-Warning "No subscriptions found in tenant: $($currentContext.Tenant.Id)"
        return @()
    }
    
    Write-Verbose "Found $($subscriptions.Count) subscription(s) in tenant: $($currentContext.Tenant.Id)"
    
    # Prepare test file paths for jobs
    $testFilePaths = $recoveryTestFiles | ForEach-Object { $_.FullName }
    
    # Scriptblock for processing a single subscription in a job
    $jobScriptBlock = {
        param(
            [PSCustomObject]$Subscription,
            [string[]]$TestFilePaths,
            [string]$ClassPath
        )
        
        try {
            Import-Module Az.Accounts, Az.Compute, Az.RecoveryServices -ErrorAction Stop | Out-Null
            . $ClassPath
            $null = Set-AzContext -SubscriptionId $Subscription.Id -Force -ErrorAction Stop
            
            foreach ($testFilePath in $TestFilePaths) {
                . $testFilePath
            }
            
            $recoveryVaults = @(Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue | Where-Object { $_.ID -like "/subscriptions/$($Subscription.Id)/*" })
            $vms = @(Get-AzVM -ErrorAction SilentlyContinue | Where-Object { $_.Id -like "/subscriptions/$($Subscription.Id)/*" })
            
            $protectedItems = @()
            if ($recoveryVaults.Count -gt 0) {
                foreach ($vault in $recoveryVaults) {
                    try {
                        if ($vault.ResourceGroupName) {
                            $vaultRG = Get-AzResourceGroup -Name $vault.ResourceGroupName -ErrorAction SilentlyContinue
                            if (-not $vaultRG) {
                                continue
                            }
                        }
                        
                        $null = Set-AzContext -SubscriptionId $Subscription.Id -Force -ErrorAction Stop
                        Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction Stop | Out-Null
                        
                        $fabrics = Get-AzRecoveryServicesAsrFabric -ErrorAction SilentlyContinue
                        if ($fabrics) {
                            foreach ($fabric in $fabrics) {
                                $containers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -ErrorAction SilentlyContinue
                                if ($containers) {
                                    foreach ($container in $containers) {
                                        $containerProtectedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -ErrorAction SilentlyContinue
                                        if ($containerProtectedItems) {
                                            $protectedItems += $containerProtectedItems
                                        }
                                    }
                                }
                            }
                        }
                    }
                    catch {
                        if ($_.Exception.Message -notlike "*could not be found*") {
                            Write-Warning "Error querying vault '$($vault.Name)' in subscription $($Subscription.Name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            
            $subscriptionResults = @()
            
            if ($vms.Count -gt 0) {
                foreach ($testFilePath in $TestFilePaths) {
                    $functionName = (Get-Item $testFilePath).BaseName
                    
                    if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                        try {
                            $testResults = & $functionName -VMs $vms -ProtectedItems $protectedItems -Subscription $Subscription
                            if ($testResults) {
                                $subscriptionResults += $testResults
                            }
                        }
                        catch {
                            Write-Warning "Error executing test '$functionName' in subscription $($Subscription.Name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            
            return $subscriptionResults
        }
        catch {
            Write-Warning "Error processing subscription '$($Subscription.Name)': $($_.Exception.Message)"
            return @()
        }
    }
    
    # Start jobs for all subscriptions
    $jobs = @()
    foreach ($subscription in $subscriptions) {
        $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $subscription, $testFilePaths, $classPath -Name "Recovery-$($subscription.Name)"
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    $completedJobs = 0
    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
        Write-Progress -Activity "Processing Subscriptions (Parallel Jobs)" -Status "Completed: $completedJobs of $($subscriptions.Count)" -PercentComplete (($completedJobs / $subscriptions.Count) * 100)
        Start-Sleep -Milliseconds 500
    }
    
    Write-Progress -Activity "Processing Subscriptions (Parallel Jobs)" -Completed
    
    # Collect results from all jobs
    foreach ($job in $jobs) {
        try {
            if ($job.State -eq 'Failed') {
                Write-Warning "Job '$($job.Name)' failed"
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                continue
            }
            
            $jobResults = Receive-Job -Job $job -ErrorAction Stop
            
            if ($jobResults) {
                if ($jobResults -isnot [System.Array]) {
                    $jobResults = @($jobResults)
                }
                
                foreach ($result in $jobResults) {
                    if ($null -ne $result) {
                        if ($result -is [TestResult]) {
                            $allResults.Add($result)
                        }
                        elseif ($result -is [PSCustomObject]) {
                            $allResults.Add([TestResult]$result)
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Error receiving results from job '$($job.Name)': $($_.Exception.Message)"
        }
        finally {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
    
    return @($allResults)
}
