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
    
    # Discover all networking test files in subfolders (LoadBalancer, NSG, VNet, etc.)
    $networkingTestFiles = @(Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot })  # Exclude the orchestrator itself
    
    if ($networkingTestFiles.Count -eq 0) {
        Write-Warning "No networking test files found in $PSScriptRoot subfolders"
        return @()
    }
    
    Write-Verbose "Discovered $($networkingTestFiles.Count) networking test file(s)"
    
    # Load all test functions
    foreach ($testFile in $networkingTestFiles) {
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
    
    # Get module root and load TestResult class
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $classPath = Join-Path $moduleRoot "Classes\TestResult.ps1"
    . $classPath
    
    # Collect all results (must be after TestResult class is loaded)
    $allResults = [System.Collections.Generic.List[TestResult]]::new()
    
    # Prepare test file paths for jobs
    $testFilePaths = $networkingTestFiles | ForEach-Object { $_.FullName }
    
    # Scriptblock for processing a single subscription in a job
    $jobScriptBlock = {
        param(
            [PSCustomObject]$Subscription,
            [string[]]$TestFilePaths,
            [string]$ClassPath
        )
        
        try {
            Import-Module Az.Accounts, Az.Network, Az.Storage, Az.KeyVault, Az.Sql, Az.Websites, Az.ContainerRegistry -ErrorAction Stop | Out-Null
            . $ClassPath
            $null = Set-AzContext -SubscriptionId $Subscription.Id -Force -ErrorAction Stop
            
            foreach ($testFilePath in $TestFilePaths) {
                . $testFilePath
            }
            
            $loadBalancers = @(Get-AzLoadBalancer -ErrorAction SilentlyContinue | Where-Object { $_.Id -like "/subscriptions/$($Subscription.Id)/*" })
            $subscriptionResults = @()
            
            foreach ($testFilePath in $TestFilePaths) {
                $functionName = (Get-Item $testFilePath).BaseName
                
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    try {
                        $command = Get-Command $functionName
                        $hasLoadBalancersParam = $command.Parameters.ContainsKey('LoadBalancers')
                        
                        if ($hasLoadBalancersParam -and $loadBalancers.Count -gt 0) {
                            $testResults = & $functionName -LoadBalancers $loadBalancers -Subscription $Subscription
                        }
                        elseif (-not $hasLoadBalancersParam) {
                            $testResults = & $functionName -Subscription $Subscription
                        }
                        
                        if ($testResults) {
                            $subscriptionResults += $testResults
                        }
                    }
                    catch {
                        Write-Warning "Error executing test '$functionName' in subscription $($Subscription.Name): $($_.Exception.Message)"
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
        $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $subscription, $testFilePaths, $classPath -Name "Networking-$($subscription.Name)"
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
                # Ensure $jobResults is an array (Receive-Job might return single object)
                if ($jobResults -isnot [System.Array]) {
                    $jobResults = @($jobResults)
                }
                
                foreach ($result in $jobResults) {
                    if ($null -ne $result) {
                        # Jobs serialize objects, so convert PSCustomObject back to TestResult
                        if ($result -is [TestResult]) {
                            $allResults.Add($result)
                        }
                        elseif ($result -is [PSCustomObject]) {
                            # PowerShell should handle conversion automatically
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
