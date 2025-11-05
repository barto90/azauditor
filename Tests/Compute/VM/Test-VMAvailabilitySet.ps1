function Test-VMAvailabilitySet {
    <#
    .SYNOPSIS
        Verifies that non-zone Virtual Machines are deployed in Availability Sets with proper fault and update domains.
    
    .DESCRIPTION
        Tests whether VMs not using availability zones are configured with Availability Sets
        that have at least 2 fault domains and 2 update domains for high availability
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
        TestName = 'VM-Availability-Set'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that non-zone VMs are in Availability Sets with 2+ fault domains and 2+ update domains'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    # Only test VMs that are NOT in availability zones
    $nonZoneVMs = $VMs | Where-Object { $_.Zones.Count -eq 0 -or $null -eq $_.Zones }
    
    foreach ($vm in $nonZoneVMs) {
        $actualResult = $false
        $rawResult = $null
        
        # Check if VM is in an Availability Set
        if ($vm.AvailabilitySetReference) {
            # Get Availability Set details
            $avSetId = $vm.AvailabilitySetReference.Id
            $avSetName = $avSetId.Split('/')[-1]
            $avSetResourceGroup = $vm.ResourceGroupName
            
            $availabilitySet = Get-AzAvailabilitySet -ResourceGroupName $avSetResourceGroup -Name $avSetName -ErrorAction SilentlyContinue
            
            if ($availabilitySet) {
                # Check if it has 2+ fault domains AND 2+ update domains
                $actualResult = ($availabilitySet.PlatformFaultDomainCount -ge 2) -and ($availabilitySet.PlatformUpdateDomainCount -ge 2)
                
                $rawResult = [PSCustomObject]@{
                    AvailabilitySetName = $availabilitySet.Name
                    FaultDomainCount = $availabilitySet.PlatformFaultDomainCount
                    UpdateDomainCount = $availabilitySet.PlatformUpdateDomainCount
                }
            }
            else {
                $rawResult = [PSCustomObject]@{
                    AvailabilitySetName = 'Not Found'
                    FaultDomainCount = 0
                    UpdateDomainCount = 0
                }
            }
        }
        else {
            $rawResult = [PSCustomObject]@{
                AvailabilitySetName = 'None'
                FaultDomainCount = 0
                UpdateDomainCount = 0
            }
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
            RawResult = $rawResult
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

