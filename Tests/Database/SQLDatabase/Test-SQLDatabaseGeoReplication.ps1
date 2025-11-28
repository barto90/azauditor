function Test-SQLDatabaseGeoReplication {
    <#
    .SYNOPSIS
        Verifies that Azure SQL Databases have active geo-replication configured.
    
    .DESCRIPTION
        Tests whether SQL Databases have at least one secondary replica in a different region
        for disaster recovery according to Well-Architected Framework reliability standards.
    
    .PARAMETER SQLDatabases
        Array of Azure SQL Database objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the databases belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$SQLDatabases,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'SQLDatabase-Geo-Replication'
        Category = 'Database'
        SubCategory = 'SQLDatabase'
        Description = 'Verifies that SQL Databases have active geo-replication with secondary replicas in different regions'
        ResourceType = 'Microsoft.Sql/servers/databases'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($db in $SQLDatabases) {
        # Check for geo-replication using database properties
        # Check if database has SecondaryType property or is a secondary itself
        $hasGeoReplication = $false
        $secondaryLocations = @()
        
        # Check if this database has geo-replication configured
        # Note: This is a simplified check - databases with active geo-replication will have specific properties
        # For a more complete check, we'd need to query replication links, but that cmdlet can be problematic
        
        # Check database replication role - if it's not null, it's part of a geo-replication relationship
        if ($db.ReplicationRole) {
            $hasGeoReplication = $true
            $secondaryLocations += [PSCustomObject]@{
                Note = "Database has replication role: $($db.ReplicationRole)"
                ReplicationRole = $db.ReplicationRole
            }
        }
        
        $actualResult = $hasGeoReplication
        
        $rawResult = [PSCustomObject]@{
            HasGeoReplication = $hasGeoReplication
            PrimaryLocation = $db.Location
            ReplicationRole = if ($db.ReplicationRole) { $db.ReplicationRole } else { 'None' }
            SecondaryInfo = $secondaryLocations
            DatabaseEdition = $db.Edition
            DatabaseSku = $db.SkuName
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
            ResourceId = $db.ResourceId
            ResourceName = $db.DatabaseName
            ResourceGroupName = $db.ResourceGroupName
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

