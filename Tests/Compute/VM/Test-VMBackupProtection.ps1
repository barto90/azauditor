function Test-VMBackupProtection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        [object]$Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Backup-Protection'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs are protected with Azure Backup for data protection and disaster recovery'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Reliability'
        Severity = 'Medium'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    # Get all Recovery Services Vaults in the subscription (filter to current subscription only)
    $vaults = @(Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue | Where-Object { $_.ID -like "/subscriptions/$($Subscription.Id)/*" })
    
    # Build a hash of protected VM IDs for faster lookup
    $protectedVMs = @{}
    
    foreach ($vault in $vaults) {
        try {
            # Verify vault's resource group exists in current subscription before accessing
            if ($vault.ResourceGroupName) {
                $vaultRG = Get-AzResourceGroup -Name $vault.ResourceGroupName -ErrorAction SilentlyContinue
                if (-not $vaultRG) {
                    # Vault's RG doesn't exist in this subscription, skip it
                    Write-Verbose "Skipping vault '$($vault.Name)' - resource group not in current subscription"
                    continue
                }
            }
            
            # Set vault context
            Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction Stop | Out-Null
            
            # Get all backup containers
            $containers = @(Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction SilentlyContinue)
            
            foreach ($container in $containers) {
                # Get backup items in this container
                $backupItems = @(Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -ErrorAction SilentlyContinue)
                
                foreach ($item in $backupItems) {
                    if ($item.VirtualMachineId) {
                        $protectedVMs[$item.VirtualMachineId] = $true
                    }
                }
            }
        }
        catch {
            # Silently skip vaults that cause cross-subscription errors
            # Only log verbose if it's not a "resource not found" error
            if ($_.Exception.Message -notlike "*was not found*" -and $_.Exception.Message -notlike "*could not be found*") {
                Write-Verbose "Error checking vault $($vault.Name): $($_.Exception.Message)"
            }
        }
    }
    
    # Check each VM
    foreach ($vm in $VMs) {
        $isProtected = $protectedVMs.ContainsKey($vm.Id)
        
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
            ActualResult = $isProtected
            RawResult = [PSCustomObject]@{
                BackupEnabled = $isProtected
                VMId = $vm.Id
            }
            ResultStatus = if ($isProtected -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

