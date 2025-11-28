function Test-Identity {
    <#
    .SYNOPSIS
        Executes all Identity resource compliance tests.
    
    .DESCRIPTION
        Orchestrates all identity-related compliance tests against Azure tenant.
        These are tenant-level tests that run once per tenant (not per subscription).
    #>
    [CmdletBinding()]
    param()
    
    # Get module root and load TestResult class and GraphClient
    $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $classPath = Join-Path $moduleRoot "Classes\TestResult.ps1"
    $graphClientPath = Join-Path $moduleRoot "Classes\GraphClient.ps1"
    . $classPath
    . $graphClientPath
    
    # Collect all results (must be after TestResult class is loaded)
    $allResults = [System.Collections.Generic.List[TestResult]]::new()
    
    # Discover all identity test files in subfolders (Authentication, etc.)
    $identityTestFiles = @(Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "Test-*.ps1" -File | 
        Where-Object { $_.DirectoryName -ne $PSScriptRoot })  # Exclude the orchestrator itself
    
    if ($identityTestFiles.Count -eq 0) {
        Write-Warning "No identity test files found in $PSScriptRoot subfolders"
        return @()
    }
    
    Write-Verbose "Discovered $($identityTestFiles.Count) identity test file(s)"
    
    # Load all test functions
    foreach ($testFile in $identityTestFiles) {
        Write-Verbose "Loading test file: $($testFile.Name)"
        . $testFile.FullName
    }
    
    # Get current context to determine active tenant
    $currentContext = Get-AzContext
    if (-not $currentContext) {
        Write-Warning "No Azure context found. Please run Connect-AzAccount first."
        return @()
    }
    
    $tenantId = $currentContext.Tenant.Id
    Write-Verbose "Running identity tests for tenant: $tenantId"
    
    # Initialize GraphClient - this will handle connection prompting if needed
    try {
        $graphClient = [GraphClient]::new()
        
        if (-not $graphClient.UseCmdlets) {
            # GraphClient couldn't connect - tests will likely fail
            Write-Warning "GraphClient initialization failed. Identity tests may not work correctly."
            Write-Warning "Required scopes: $([GraphClient]::RequiredScopes -join ', ')"
            return @()
        }
        
        Write-Verbose "GraphClient initialized successfully. Using Microsoft Graph cmdlets."
    }
    catch {
        Write-Warning "Failed to initialize GraphClient: $($_.Exception.Message)"
        Write-Warning "Required scopes: $([GraphClient]::RequiredScopes -join ', ')"
        return @()
    }
    
    # Identity tests are tenant-level
    foreach ($testFile in $identityTestFiles) {
        $functionName = $testFile.BaseName
        
        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            Write-Verbose "Executing test: $functionName"
            
            try {
                # Check if test requires TenantId parameter
                $command = Get-Command $functionName
                $isTenantLevel = $command.Parameters.ContainsKey('TenantId')
                
                if ($isTenantLevel) {
                    # Tenant-level test (runs once)
                    $testResults = & $functionName -TenantId $tenantId
                    
                    if ($testResults) {
                        foreach ($result in $testResults) {
                            $allResults.Add($result)
                        }
                        Write-Verbose "Test completed: $functionName - Collected $($testResults.Count) result(s)"
                    }
                }
                else {
                    Write-Warning "Test $functionName has no TenantId parameter - skipping"
                }
            }
            catch {
                Write-Warning "Error executing test '$functionName': $($_.Exception.Message)"
                continue
            }
        }
    }
    
    return @($allResults)
}

