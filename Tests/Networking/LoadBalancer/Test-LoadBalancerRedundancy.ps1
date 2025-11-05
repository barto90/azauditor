function Test-LoadBalancerRedundancy {
    <#
    .SYNOPSIS
        Verifies that Load Balancers are configured with multiple backend instances for redundancy.
    
    .DESCRIPTION
        Tests whether Load Balancers have at least 2 backend instances/VMs in their backend pools
        to ensure redundancy and high availability according to Well-Architected Framework reliability standards.
    
    .PARAMETER LoadBalancers
        Array of Azure Load Balancer objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the Load Balancers belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$LoadBalancers,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'LoadBalancer-Redundancy'
        Category = 'Networking'
        SubCategory = 'LoadBalancer'
        Description = 'Verifies that Load Balancers have 2+ backend instances for redundancy'
        ResourceType = 'Microsoft.Network/loadBalancers'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($lb in $LoadBalancers) {
        $actualResult = $false
        $rawResult = $null
        
        # Count backend instances across all backend address pools
        $totalBackendInstances = 0
        $backendPoolDetails = @()
        
        if ($lb.BackendAddressPools -and $lb.BackendAddressPools.Count -gt 0) {
            foreach ($backendPool in $lb.BackendAddressPools) {
                $instanceCount = 0
                
                # Count backend IP configurations (VMs/instances in the pool)
                if ($backendPool.BackendIpConfigurations) {
                    $instanceCount = $backendPool.BackendIpConfigurations.Count
                }
                
                $totalBackendInstances += $instanceCount
                
                $backendPoolDetails += [PSCustomObject]@{
                    PoolName = $backendPool.Name
                    InstanceCount = $instanceCount
                }
            }
            
            # Pass if total backend instances is 2 or more
            $actualResult = ($totalBackendInstances -ge 2)
            
            $rawResult = [PSCustomObject]@{
                TotalBackendInstances = $totalBackendInstances
                BackendPoolCount = $lb.BackendAddressPools.Count
                BackendPools = $backendPoolDetails
            }
        }
        else {
            $rawResult = [PSCustomObject]@{
                TotalBackendInstances = 0
                BackendPoolCount = 0
                BackendPools = @()
            }
        }
        
        $result = [TestResult]@{
            ResourceId = $lb.Id
            ResourceName = $lb.Name
            ResourceGroupName = $lb.ResourceGroupName
            SubscriptionId = $Subscription.Id
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $actualResult
            RawResult = $rawResult
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

