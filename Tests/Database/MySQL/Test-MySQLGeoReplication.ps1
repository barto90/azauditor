function Test-MySQLGeoReplication {
    <#
    .SYNOPSIS
        Verifies that Azure MySQL servers have read replicas configured in different regions.
    
    .DESCRIPTION
        Tests whether MySQL servers have at least one read replica in a different region
        for disaster recovery according to Well-Architected Framework reliability standards.
    
    .PARAMETER MySQLServers
        Array of Azure MySQL Server objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the servers belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$MySQLServers,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'MySQL-Geo-Replication'
        Category = 'Database'
        SubCategory = 'MySQL'
        Description = 'Verifies that MySQL servers have read replicas in different regions'
        ResourceType = 'Microsoft.DBforMySQL/servers'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($server in $MySQLServers) {
        # Get replicas for this server
        $replicas = Get-AzMySqlReplica `
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
            RawResult = $rawResult
            ResultStatus = if ($actualResult -eq $testMetadata.ExpectedResult) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

