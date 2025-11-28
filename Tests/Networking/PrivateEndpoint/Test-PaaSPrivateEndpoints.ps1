function Test-PaaSPrivateEndpoints {
    <#
    .SYNOPSIS
        Validates that PaaS resources have private endpoints configured.
    
    .DESCRIPTION
        Checks if Azure PaaS resources have private endpoint connections configured.
        
        Covered resource types:
        - Storage Accounts
        - SQL Servers
        - Key Vaults
        - Cosmos DB Accounts
        - App Services (Web Apps)
        - Container Registries
        - Service Bus Namespaces
        - Event Hub Namespaces
    
    .PARAMETER Subscription
        The Azure subscription object to test resources in.
    
    .OUTPUTS
        [TestResult[]] Array of test results for each PaaS resource.
    
    .EXAMPLE
        Test-PaaSPrivateEndpoints -Subscription $subscription
    
    .NOTES
        Category: Networking
        Sub-Category: PrivateEndpoint
        WAF Pillar: Security
        Recommendation: Use private endpoints to secure access to PaaS services and eliminate exposure to the public internet.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Subscription
    )
    
    # Import TestResult class
    $moduleRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    . "$moduleRoot\Classes\TestResult.ps1"
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'PaaS-Private-Endpoints'
        Category = 'Networking'
        SubCategory = 'PrivateEndpoint'
        Description = 'Verifies that PaaS resources have private endpoints configured'
        ResourceType = 'Multiple PaaS Services'
        WAFPillar = 'Security'
        Severity = 'High'
        ExpectedResult = 'Private endpoint configured'
    }
    
    $results = [System.Collections.Generic.List[TestResult]]::new()
    
    Write-Verbose "Checking PaaS resources for private endpoints in subscription: $($Subscription.Name)"
    
    # Define PaaS resource types to check
    $paasResourceTypes = @{
        'Microsoft.Storage/storageAccounts' = 'Storage Account'
        'Microsoft.Sql/servers' = 'SQL Server'
        'Microsoft.KeyVault/vaults' = 'Key Vault'
        'Microsoft.DocumentDB/databaseAccounts' = 'Cosmos DB'
        'Microsoft.ContainerRegistry/registries' = 'Container Registry'
        'Microsoft.Web/sites' = 'App Service'
        'Microsoft.ServiceBus/namespaces' = 'Service Bus'
        'Microsoft.EventHub/namespaces' = 'Event Hub'
    }
    
    # Get all PaaS resources in the subscription
    foreach ($resourceType in $paasResourceTypes.Keys) {
        $resourceTypeName = $paasResourceTypes[$resourceType]
        
        Write-Verbose "Checking for $resourceTypeName resources (type: $resourceType)..."
        
        try {
            $resources = @(Get-AzResource -ResourceType $resourceType -ErrorAction SilentlyContinue | 
                Where-Object { $_.ResourceId -like "/subscriptions/$($Subscription.Id)/*" })
            
            Write-Verbose "Found $($resources.Count) $resourceTypeName resource(s) in subscription $($Subscription.Name)"
            
            foreach ($resource in $resources) {
                Write-Verbose "Processing $resourceTypeName : $($resource.Name)"
                
                try {
                    # Get full resource details with properties
                    $resourceDetails = Get-AzResource -ResourceId $resource.ResourceId -ExpandProperties -ErrorAction Stop
                    
                    # Check for private endpoint connections
                    $privateEndpoints = @()
                    $hasPrivateEndpoint = $false
                    
                    # Check if resource has privateEndpointConnections property
                    if ($resourceDetails.Properties.PSObject.Properties.Name -contains 'privateEndpointConnections') {
                        $privateEndpoints = @($resourceDetails.Properties.privateEndpointConnections | 
                            Where-Object { 
                                $_.properties.privateLinkServiceConnectionState.status -eq 'Approved' 
                            })
                        $hasPrivateEndpoint = $privateEndpoints.Count -gt 0
                    }
                    
                    # Build private endpoint details for reporting
                    $privateEndpointDetails = @()
                    if ($hasPrivateEndpoint) {
                        $privateEndpointDetails = $privateEndpoints | ForEach-Object { 
                            @{
                                Id = $_.id
                                Name = if ($_.name) { $_.name } else { 'Unknown' }
                                Status = $_.properties.privateLinkServiceConnectionState.status
                                Description = $_.properties.privateLinkServiceConnectionState.description
                            }
                        }
                    }
                    
                    # Determine pass/fail
                    $passed = $hasPrivateEndpoint
                    $actualResult = if ($hasPrivateEndpoint) {
                        "Private endpoint configured ($($privateEndpoints.Count) connection(s))"
                    } else {
                        "No private endpoint configured"
                    }
                    
                    # Convert RawResult to JSON string for serialization through jobs
                    $rawResultObj = @{
                        ResourceType = $resourceTypeName
                        HasPrivateEndpoint = $hasPrivateEndpoint
                        PrivateEndpointCount = $privateEndpoints.Count
                        PrivateEndpoints = $privateEndpointDetails
                        Location = $resource.Location
                    }
                    $rawResultJson = $null
                    try {
                        $rawResultJson = ($rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false)
                    }
                    catch {
                        $rawResultJson = ($rawResultObj | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
                    }
                    
                    $results.Add([TestResult]@{
                        ResourceId = $resource.ResourceId
                        ResourceName = $resource.Name
                        ResourceGroupName = $resource.ResourceGroupName
                        SubscriptionId = $Subscription.Id
                        Category = $testMetadata.Category
                        SubCategory = $testMetadata.SubCategory
                        TestName = "$($testMetadata.TestName)-$($resourceTypeName -replace ' ', '')"
                        TestDescription = "Verifies that $resourceTypeName resources have private endpoints configured"
                        TimeStamp = (Get-Date).ToUniversalTime()
                        ExpectedResult = $testMetadata.ExpectedResult
                        ActualResult = $actualResult
                        RawResult = $rawResultJson
                        ResultStatus = if ($passed) { 'Pass' } else { 'Fail' }
                    })
                    
                }
                catch {
                    Write-Verbose "Error checking resource $($resource.Name): $($_.Exception.Message)"
                    
                    # Convert RawResult to JSON string for serialization through jobs
                    $rawResultObj = @{
                        ResourceType = $resourceTypeName
                        Error = $_.Exception.Message
                    }
                    $rawResultJson = $null
                    try {
                        $rawResultJson = ($rawResultObj | ConvertTo-Json -Depth 10 -Compress:$false)
                    }
                    catch {
                        $rawResultJson = ($rawResultObj | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false)
                    }
                    
                    $results.Add([TestResult]@{
                        ResourceId = $resource.ResourceId
                        ResourceName = $resource.Name
                        ResourceGroupName = $resource.ResourceGroupName
                        SubscriptionId = $Subscription.Id
                        Category = $testMetadata.Category
                        SubCategory = $testMetadata.SubCategory
                        TestName = "$($testMetadata.TestName)-$($resourceTypeName -replace ' ', '')"
                        TestDescription = "Verifies that $resourceTypeName resources have private endpoints configured"
                        TimeStamp = (Get-Date).ToUniversalTime()
                        ExpectedResult = $testMetadata.ExpectedResult
                        ActualResult = "Error: $($_.Exception.Message)"
                        RawResult = $rawResultJson
                        ResultStatus = 'Fail'
                    })
                }
            }
        }
        catch {
            Write-Warning "Error retrieving $resourceTypeName resources in subscription $($Subscription.Name): $($_.Exception.Message)"
        }
        
        Write-Verbose "Completed checking $resourceTypeName - processed $($resources.Count) resource(s)"
    }
    
    if ($results.Count -eq 0) {
        Write-Verbose "No PaaS resources found in subscription $($Subscription.Name)"
    }
    else {
        Write-Verbose "Completed PaaS Private Endpoint check for subscription $($Subscription.Name) - collected $($results.Count) result(s)"
    }
    
    return $results
}

