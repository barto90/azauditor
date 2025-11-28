1. Create a test for checking checking the VM naming convention
2. Dont make assumptions, ask questions
3. Update the markdown if its there with the test, or create a new one (see other tests)
4. Make sure the test pattern is equally the same as to the test below
5. make sure in the manifest you have the test defined as with the other tests
6. if its a new orchestrator make sure to update the Start-AzAuditor as well 

function Test-VMHyperVGeneration {

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
            RawResult = $vm
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

