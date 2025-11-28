function Test-MicrosoftAuthenticator {
    <#
    .SYNOPSIS
        Verifies that Microsoft Authenticator is enabled as an authentication method at the tenant level.
    
    .DESCRIPTION
        Tests whether Microsoft Authenticator is enabled in the authentication methods policy
        according to security best practices.
    
    .PARAMETER TenantId
        The Azure tenant ID to test.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )
    
    # Import TestResult class and GraphClient
    $moduleRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    . "$moduleRoot\Classes\TestResult.ps1"
    . "$moduleRoot\Classes\GraphClient.ps1"
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'Microsoft-Authenticator-Enabled'
        Category = 'Identity'
        SubCategory = 'Authentication'
        Description = 'Verifies that Microsoft Authenticator is enabled as an authentication method policy at tenant level'
        ResourceType = 'Microsoft.Graph/policies/authenticationMethodsPolicy'
        WAFPillar = 'Security'
        Severity = 'High'
        ExpectedResult = 'Microsoft Authenticator enabled in authentication methods policy'
    }
    
    # Test Execution
    $results = @()
    
    try {
        $graphClient = [GraphClient]::new()
        
        # Check if Microsoft Authenticator is enabled
        $authenticatorEnabled = $graphClient.IsAuthenticationMethodEnabled('MicrosoftAuthenticator')
        
        # Get configuration details
        $authenticatorConfig = $graphClient.GetAuthenticationMethodConfiguration('MicrosoftAuthenticator')
        $policyDetails = $null
        
        if ($authenticatorConfig) {
            if ($graphClient.UseCmdlets) {
                $policyDetails = @{
                    'State' = $authenticatorConfig.State
                    'Id' = $authenticatorConfig.Id
                    'IncludeTargets' = $authenticatorConfig.IncludeTargets
                }
            }
            else {
                $policyDetails = @{
                    'State' = $authenticatorConfig.state
                    'Id' = $authenticatorConfig.id
                    'IncludeTargets' = $authenticatorConfig.includeTargets
                }
            }
        }
        
        $actualResult = if ($authenticatorEnabled) {
            "Microsoft Authenticator is enabled in authentication methods policy"
        } else {
            "Microsoft Authenticator is not enabled in authentication methods policy"
        }
        
        $rawResult = [PSCustomObject]@{
            'TenantId' = $TenantId
            'AuthenticatorEnabled' = $authenticatorEnabled
            'PolicyDetails' = $policyDetails
        }
        
        $result = [TestResult]@{
            ResourceId = "/tenants/$TenantId/policies/authenticationMethodsPolicy"
            ResourceName = "Authentication Methods Policy"
            ResourceGroupName = $null
            SubscriptionId = $TenantId
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $actualResult
            RawResult = $rawResult
            ResultStatus = if ($authenticatorEnabled) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    catch {
        Write-Warning "Error executing Microsoft Authenticator test: $($_.Exception.Message)"
        
        $errorRawResult = [PSCustomObject]@{
            Error = $_.Exception.Message
        }
        $result = [TestResult]@{
            ResourceId = "/tenants/$TenantId"
            ResourceName = "Tenant: $TenantId"
            ResourceGroupName = $null
            SubscriptionId = $TenantId
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = "Error: $($_.Exception.Message)"
            RawResult = $errorRawResult
            ResultStatus = [ResultStatus]::Fail
        }
        
        $results += $result
    }
    
    return $results
}
