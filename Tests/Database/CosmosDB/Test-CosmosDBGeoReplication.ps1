function Test-CosmosDBGeoReplication {
    <#
    .SYNOPSIS
        Verifies that CosmosDB accounts have multi-region replication configured.
    
    .DESCRIPTION
        Tests whether CosmosDB accounts have multiple read or write regions configured
        for disaster recovery according to Well-Architected Framework reliability standards.
    
    .PARAMETER CosmosDBAccounts
        Array of Azure CosmosDB Account objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the accounts belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$CosmosDBAccounts,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'CosmosDB-Geo-Replication'
        Category = 'Database'
        SubCategory = 'CosmosDB'
        Description = 'Verifies that CosmosDB accounts have multi-region replication configured'
        ResourceType = 'Microsoft.DocumentDB/databaseAccounts'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($account in $CosmosDBAccounts) {
        # Check if account has multiple locations
        $locations = @($account.Locations)
        $hasMultiRegion = $locations.Count -gt 1
        
        $writeLocations = @($account.WriteLocations)
        $readLocations = @($account.ReadLocations)
        
        $locationDetails = foreach ($location in $locations) {
            [PSCustomObject]@{
                LocationName = $location.LocationName
                FailoverPriority = $location.FailoverPriority
                IsZoneRedundant = $location.IsZoneRedundant
            }
        }
        
        $actualResult = $hasMultiRegion
        
        $rawResult = [PSCustomObject]@{
            HasMultiRegion = $hasMultiRegion
            TotalLocations = $locations.Count
            WriteLocationsCount = $writeLocations.Count
            ReadLocationsCount = $readLocations.Count
            EnableMultipleWriteLocations = $account.EnableMultipleWriteLocations
            Locations = $locationDetails
            ConsistencyLevel = $account.DefaultConsistencyLevel
        }
        
        $result = [TestResult]@{
            ResourceId = $account.Id
            ResourceName = $account.Name
            ResourceGroupName = $account.ResourceGroupName
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

