function Test-VMSSOverprovisioning {
    <#
    .SYNOPSIS
        Verifies that Virtual Machine Scale Sets have overprovisioning enabled.
    
    .DESCRIPTION
        Tests whether VMSS are configured with overprovisioning to improve deployment speed
        and reduce costs according to Well-Architected Framework standards.
    
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
        TestName = 'VMSS-Overprovisioning'
        Category = 'Compute'
        SubCategory = 'VMSS'
        Description = 'Verifies that VMSS have overprovisioning enabled for faster deployments and cost efficiency'
        ResourceType = 'Microsoft.Compute/virtualMachineScaleSets'
        WAFPillar = 'Performance Efficiency, Cost Optimization'
        Severity = 'Low'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($scaleSet in $VMSS) {
        $overprovisioningEnabled = $scaleSet.Overprovision -eq $true
        
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
            ActualResult = $overprovisioningEnabled
            RawResult = $(
                $rawResultObj = [PSCustomObject]@{
                    Overprovision = $scaleSet.Overprovision
                }
                try {
                    $rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false
                }
                catch {
                    ($rawResultObj | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
                }
            )
            ResultStatus = if ($overprovisioningEnabled -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

