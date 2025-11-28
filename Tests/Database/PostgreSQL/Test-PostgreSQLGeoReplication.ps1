function Test-PostgreSQLGeoReplication {
    <#
    .SYNOPSIS
        Verifies that Azure PostgreSQL servers have read replicas configured in different regions.
    
    .DESCRIPTION
        Tests whether PostgreSQL servers have at least one read replica in a different region
        for disaster recovery according to Well-Architected Framework reliability standards.
    
    .PARAMETER PostgreSQLServers
        Array of Azure PostgreSQL Server objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the servers belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$PostgreSQLServers,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'PostgreSQL-Geo-Replication'
        Category = 'Database'
        SubCategory = 'PostgreSQL'
        Description = 'Verifies that PostgreSQL servers have read replicas in different regions'
        ResourceType = 'Microsoft.DBforPostgreSQL/servers'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($server in $PostgreSQLServers) {
        # Get replicas for this server
        $replicas = Get-AzPostgreSqlReplica `
            -ResourceGroupName $server.ResourceGroupName `
            -ServerName $server.Name `
            -ErrorAction SilentlyContinue
        
        $hasGeoReplication = $false
        $replicaDetails = @()
        
        if ($replicas) {
            $replicas = @($replicas)
            
            # Check if any replica is in a different region
            foreach ($replica in $replicas) {
                $replicaDetails += [PSCustomObject]@{
                    ReplicaName = $replica.Name
                    ReplicaLocation = $replica.Location
                    ReplicationRole = $replica.ReplicationRole
                    MasterServerId = $replica.MasterServerId
                }
                
                # Check if replica is in different region than master
                if ($replica.Location -ne $server.Location) {
                    $hasGeoReplication = $true
                }
            }
        }
        
        $actualResult = $hasGeoReplication
        
        $rawResult = [PSCustomObject]@{
            HasGeoReplication = $hasGeoReplication
            PrimaryLocation = $server.Location
            TotalReplicas = $replicas.Count
            CrossRegionReplicas = ($replicaDetails | Where-Object { $_.ReplicaLocation -ne $server.Location }).Count
            Replicas = $replicaDetails
            ServerVersion = $server.Version
            Sku = $server.Sku.Name
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
            ResourceId = $server.Id
            ResourceName = $server.Name
            ResourceGroupName = $server.ResourceGroupName
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

