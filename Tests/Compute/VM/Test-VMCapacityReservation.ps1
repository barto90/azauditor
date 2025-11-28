function Test-VMCapacityReservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        [object]$Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Capacity-Reservation'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs are associated with Capacity Reservation Groups to guarantee compute capacity availability'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'Low'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $hasCapacityReservation = $false
        $capacityReservationInfo = $null
        
        # Check if VM has Capacity Reservation Group assigned
        if ($vm.CapacityReservation -and $vm.CapacityReservation.CapacityReservationGroup) {
            $hasCapacityReservation = $true
            $capacityReservationInfo = $vm.CapacityReservation.CapacityReservationGroup.Id
        }
        
        # Convert RawResult to JSON string for serialization through jobs
        $rawResultObj = [PSCustomObject]@{
            HasCapacityReservation = $hasCapacityReservation
            CapacityReservationGroupId = $capacityReservationInfo
            CapacityReservationObject = $vm.CapacityReservation
        }
        $rawResultJson = $null
        try {
            $rawResultJson = $rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false
        }
        catch {
            # Fallback if JSON conversion fails
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
            ActualResult = $hasCapacityReservation
            RawResult = $rawResultJson
            ResultStatus = if ($hasCapacityReservation -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

