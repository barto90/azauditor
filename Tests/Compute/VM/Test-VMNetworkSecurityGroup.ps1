function Test-VMNetworkSecurityGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        [object]$Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Network-Security-Group'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VMs are protected by Network Security Groups either on the NIC or subnet level'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Security'
        Severity = 'Low'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $hasNSG = $false
        $nsgLocation = 'None'
        $nsgInfo = $null
        
        # Get VM network profile
        $networkInterfaces = $vm.NetworkProfile.NetworkInterfaces
        
        foreach ($nicReference in $networkInterfaces) {
            # Get the actual NIC resource
            $nicId = $nicReference.Id
            $nic = Get-AzNetworkInterface -ResourceId $nicId -ErrorAction SilentlyContinue
            
            if ($nic) {
                # Check if NIC has NSG directly assigned
                if ($nic.NetworkSecurityGroup) {
                    $hasNSG = $true
                    $nsgLocation = 'NIC'
                    $nsgInfo = $nic.NetworkSecurityGroup.Id
                    break
                }
                
                # If no NSG on NIC, check the subnet
                foreach ($ipConfig in $nic.IpConfigurations) {
                    if ($ipConfig.Subnet) {
                        $subnetId = $ipConfig.Subnet.Id
                        
                        # Parse subnet ID to get VNet and subnet name
                        if ($subnetId -match '/virtualNetworks/([^/]+)/subnets/([^/]+)') {
                            $vnetName = $matches[1]
                            $subnetName = $matches[2]
                            $resourceGroupName = ($subnetId -split '/')[4]
                            
                            # Get the subnet details
                            $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
                            if ($vnet) {
                                $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
                                
                                if ($subnet -and $subnet.NetworkSecurityGroup) {
                                    $hasNSG = $true
                                    $nsgLocation = 'Subnet'
                                    $nsgInfo = $subnet.NetworkSecurityGroup.Id
                                    break
                                }
                            }
                        }
                    }
                }
                
                if ($hasNSG) {
                    break
                }
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
            ActualResult = $hasNSG
            RawResult = $(
                $rawResultObj = [PSCustomObject]@{
                    HasNSG = $hasNSG
                    NSGLocation = $nsgLocation
                    NSGId = $nsgInfo
                    NetworkInterfaces = $networkInterfaces.Id
                }
                try {
                    $rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false
                }
                catch {
                    ($rawResultObj | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
                }
            )
            ResultStatus = if ($hasNSG -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

