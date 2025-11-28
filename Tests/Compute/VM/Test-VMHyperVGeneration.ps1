function Test-VMHyperVGeneration {
    <#
    .SYNOPSIS
        Verifies that Virtual Machines are using Hyper-V Generation 2.
    
    .DESCRIPTION
        Tests whether VMs are configured with Generation 2 (recommended for modern workloads)
        according to Well-Architected Framework standards.
    
    .PARAMETER VMs
        Array of Azure VM objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the VMs belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Hyper-V-Generation'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs are using Generation 2 (recommended for modern workloads)'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Performance'
        Severity = 'Medium'
        ExpectedResult = 'V2'
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $actualResult = $vm.HyperVGeneration
        
        # Convert VM object to JSON string for serialization through jobs
        # This preserves the VM data when passing through Start-Job/Receive-Job
        $vmJson = $null
        try {
            $vmJson = $vm | ConvertTo-Json -Depth 10 -Compress:$false
        }
        catch {
            # Fallback if JSON conversion fails
            $vmJson = $vm | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false
        }
        
        $result = [TestResult]@{
            ResourceId = $vm.Id
            ResourceName = $vm.Name
            ResourceGroupName = $vm.ResourceGroupName
            SubscriptionId = $Subscription.Id
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $actualResult
            RawResult = $vmJson
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

