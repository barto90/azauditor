function Test-VMAvailabilityZones {
    <#
    .SYNOPSIS
        Verifies that Virtual Machines are deployed across availability zones.
    
    .DESCRIPTION
        Tests whether VMs are configured with availability zones for high availability
        according to Well-Architected Framework reliability standards.
    
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
        TestName = 'VM-Availability-Zones'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs are deployed across availability zones'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $actualResult = ($vm.Zones.Count -gt 0)
        
        # Convert RawResult to JSON string for serialization through jobs
        $rawResultObj = [PSCustomObject]@{
            HasAvailabilityZones = $actualResult
            Zones = if ($vm.Zones) { @($vm.Zones) } else { @() }
        }
        $rawResultJson = $null
        try {
            $rawResultJson = $rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false
        }
        catch {
            $rawResultJson = ($rawResultObj | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
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
            RawResult = $rawResultJson
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

