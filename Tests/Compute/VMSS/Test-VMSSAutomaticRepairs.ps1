function Test-VMSSAutomaticRepairs {
    <#
    .SYNOPSIS
        Verifies that Virtual Machine Scale Sets have automatic instance repairs enabled.
    
    .DESCRIPTION
        Tests whether VMSS are configured with automatic repairs to automatically detect
        and replace unhealthy instances according to Well-Architected Framework standards.
    
    .PARAMETER VMSS
        Array of Azure VMSS objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the VMSS belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMSS,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VMSS-Automatic-Repairs'
        Category = 'Compute'
        SubCategory = 'VMSS'
        Description = 'Verifies that VMSS have automatic instance repairs enabled for self-healing'
        ResourceType = 'Microsoft.Compute/virtualMachineScaleSets'
        WAFPillar = 'Reliability'
        Severity = 'Medium'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($scaleSet in $VMSS) {
        $automaticRepairsEnabled = $false
        $rawResult = $null
        
        if ($scaleSet.AutomaticRepairsPolicy) {
            $automaticRepairsEnabled = $scaleSet.AutomaticRepairsPolicy.Enabled -eq $true
            $rawResult = [PSCustomObject]@{
                Enabled = $scaleSet.AutomaticRepairsPolicy.Enabled
                GracePeriod = $scaleSet.AutomaticRepairsPolicy.GracePeriod
                RepairAction = $scaleSet.AutomaticRepairsPolicy.RepairAction
            }
        }
        else {
            $rawResult = [PSCustomObject]@{
                Enabled = $false
                GracePeriod = $null
                RepairAction = $null
            }
        }
        
        $result = [TestResult]@{
            ResourceId = $scaleSet.Id
            ResourceName = $scaleSet.Name
            ResourceGroupName = $scaleSet.ResourceGroupName
            SubscriptionId = $Subscription.Id
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $automaticRepairsEnabled
            RawResult = $rawResult
            ResultStatus = if ($automaticRepairsEnabled -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

