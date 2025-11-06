function Test-VMWorkloadDataSeparation {
    <#
    .SYNOPSIS
        Verifies that Virtual Machines have separate data disks for workload data isolation.
    
    .DESCRIPTION
        Tests whether VMs are configured with data disks to separate workload data from the OS disk.
        This ensures resilience, fault isolation, and simplifies recovery according to 
        Well-Architected Framework standards.
    
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
        TestName = 'VM-Workload-Data-Separation'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs have separate data disks for workload data isolation from OS disk'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'Medium'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $dataDiskCount = $vm.StorageProfile.DataDisks.Count
        $actualResult = ($dataDiskCount -gt 0)
        
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
            RawResult = [PSCustomObject]@{
                DataDiskCount = $dataDiskCount
                DataDisks = $vm.StorageProfile.DataDisks
            }
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

