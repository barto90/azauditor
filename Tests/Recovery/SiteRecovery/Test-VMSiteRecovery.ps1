function Test-VMSiteRecovery {
    <#
    .SYNOPSIS
        Verifies that Virtual Machines have Azure Site Recovery (ASR) configured.
    
    .DESCRIPTION
        Tests whether VMs are protected by Azure Site Recovery for disaster recovery
        according to Well-Architected Framework reliability standards.
    
    .PARAMETER VMs
        Array of Azure VM objects to test.
    
    .PARAMETER ProtectedItems
        Array of ASR protected items from Recovery Services Vaults.
    
    .PARAMETER Subscription
        The Azure subscription object the VMs belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ProtectedItems,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Site-Recovery'
        Category = 'Recovery'
        SubCategory = 'SiteRecovery'
        Description = 'Verifies that VMs have Azure Site Recovery configured for disaster recovery'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Build a lookup set of protected VM IDs for faster comparison
    $protectedVMIds = @{}
    foreach ($item in $ProtectedItems) {
        if ($item.ProviderSpecificDetails -and $item.ProviderSpecificDetails.FabricObjectId) {
            # Extract VM ID from protected item
            $vmId = $item.ProviderSpecificDetails.FabricObjectId
            $protectedVMIds[$vmId] = $item
        }
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        # Check if this VM is in the protected items
        $isProtected = $protectedVMIds.ContainsKey($vm.Id)
        $actualResult = $isProtected
        
        $rawResult = if ($isProtected) {
            $protectedItem = $protectedVMIds[$vm.Id]
            [PSCustomObject]@{
                IsProtected = $true
                ProtectionState = if ($protectedItem.ProtectionState) { $protectedItem.ProtectionState } else { 'Unknown' }
                ReplicationHealth = if ($protectedItem.ReplicationHealth) { $protectedItem.ReplicationHealth } else { 'Unknown' }
                FailoverHealth = if ($protectedItem.FailoverHealth) { $protectedItem.FailoverHealth } else { 'Unknown' }
                ActiveLocation = if ($protectedItem.ActiveLocation) { $protectedItem.ActiveLocation } else { 'Unknown' }
            }
        }
        else {
            [PSCustomObject]@{
                IsProtected = $false
                ProtectionState = 'Not Protected'
                ReplicationHealth = 'N/A'
                FailoverHealth = 'N/A'
                ActiveLocation = 'N/A'
            }
        }
        
        # Convert RawResult to JSON string for serialization through jobs
        $rawResultJson = $null
        try {
            $rawResultJson = $rawResult | ConvertTo-Json -Depth 10 -Compress:$false
        }
        catch {
            $rawResultJson = ($rawResult | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
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

