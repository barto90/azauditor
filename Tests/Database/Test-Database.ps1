function Test-Database {
    <#
    .SYNOPSIS
        Executes all Database resource compliance tests.
    
    .DESCRIPTION
        Orchestrates all database-related compliance tests against Azure subscriptions.
        Optimized to collect database resources once, then discovers and runs all individual
        database tests passing the collected data to each test for efficiency.
    #>
    [CmdletBinding()]
    param()
    
    # Collect all results
    $allResults = @()
    
    # Discover all database test files in subfolders (SQLDatabase, CosmosDB, PostgreSQL, MySQL, etc.)
    $databaseTestFiles = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot }  # Exclude the orchestrator itself
    
    if ($databaseTestFiles.Count -eq 0) {
        Write-Warning "No database test files found in $PSScriptRoot subfolders"
        return $allResults
    }
    
    Write-Verbose "Discovered $($databaseTestFiles.Count) database test file(s)"
    
    # Load all test functions
    foreach ($testFile in $databaseTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get all subscriptions and iterate
    Get-AzSubscription | ForEach-Object {
        $subscription = $_
        Set-AzContext $_.Id | Out-Null
        
        Write-Verbose "Processing subscription: $($subscription.Name)"
        
        # Get all SQL Servers and their databases once for this subscription
        $sqlServers = @(Get-AzSqlServer -ErrorAction SilentlyContinue)
        $sqlDatabases = @()
        
        if ($sqlServers.Count -gt 0 -and $null -ne $sqlServers[0]) {
            Write-Verbose "Found $($sqlServers.Count) SQL Server(s) in subscription $($subscription.Name)"
            
            foreach ($sqlServer in $sqlServers) {
                $databases = Get-AzSqlDatabase -ServerName $sqlServer.ServerName -ResourceGroupName $sqlServer.ResourceGroupName -ErrorAction SilentlyContinue
                if ($databases) {
                    # Filter out 'master' database
                    $sqlDatabases += $databases | Where-Object { $_.DatabaseName -ne 'master' }
                }
            }
            
            Write-Verbose "Found $($sqlDatabases.Count) SQL Database(s) in subscription $($subscription.Name)"
        }
        
        # Get all CosmosDB accounts once for this subscription
        $cosmosDBAccounts = @()
        $resourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue
        
        foreach ($rg in $resourceGroups) {
            $cosmosAccounts = Get-AzCosmosDBAccount -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
            if ($cosmosAccounts) {
                $cosmosDBAccounts += $cosmosAccounts
            }
        }
        
        if ($cosmosDBAccounts.Count -gt 0 -and $null -ne $cosmosDBAccounts[0]) {
            Write-Verbose "Found $($cosmosDBAccounts.Count) CosmosDB account(s) in subscription $($subscription.Name)"
        }
        
        # Get all PostgreSQL servers once for this subscription
        $postgreSQLServers = @()
        
        foreach ($rg in $resourceGroups) {
            $pgServers = Get-AzPostgreSqlServer -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
            if ($pgServers) {
                $postgreSQLServers += $pgServers
            }
        }
        
        if ($postgreSQLServers.Count -gt 0 -and $null -ne $postgreSQLServers[0]) {
            Write-Verbose "Found $($postgreSQLServers.Count) PostgreSQL server(s) in subscription $($subscription.Name)"
        }
        
        # Get all MySQL servers once for this subscription
        $mySQLServers = @()
        
        foreach ($rg in $resourceGroups) {
            $mysqlSrvs = Get-AzMySqlServer -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
            if ($mysqlSrvs) {
                $mySQLServers += $mysqlSrvs
            }
        }
        
        if ($mySQLServers.Count -gt 0 -and $null -ne $mySQLServers[0]) {
            Write-Verbose "Found $($mySQLServers.Count) MySQL server(s) in subscription $($subscription.Name)"
        }
        
        # Run each discovered test function with appropriate parameters
        foreach ($testFile in $databaseTestFiles) {
            $functionName = $testFile.BaseName
            
            if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                Write-Verbose "Executing test: $functionName"
                
                try {
                    $testResults = $null
                    
                    # Route to appropriate test based on function name
                    switch -Wildcard ($functionName) {
                        "*SQLDatabase*" {
                            if ($sqlDatabases.Count -gt 0) {
                                $testResults = & $functionName -SQLDatabases $sqlDatabases -Subscription $subscription
                            }
                        }
                        "*CosmosDB*" {
                            if ($cosmosDBAccounts.Count -gt 0) {
                                $testResults = & $functionName -CosmosDBAccounts $cosmosDBAccounts -Subscription $subscription
                            }
                        }
                        "*PostgreSQL*" {
                            if ($postgreSQLServers.Count -gt 0) {
                                $testResults = & $functionName -PostgreSQLServers $postgreSQLServers -Subscription $subscription
                            }
                        }
                        "*MySQL*" {
                            if ($mySQLServers.Count -gt 0) {
                                $testResults = & $functionName -MySQLServers $mySQLServers -Subscription $subscription
                            }
                        }
                    }
                    
                    if ($testResults) {
                        $allResults += $testResults
                        Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
                    }
                }
                catch {
                    Write-Warning "Error executing test '$functionName': $($_.Exception.Message)"
                    continue
                }
            }
        }
    }
    
    return $allResults
}

