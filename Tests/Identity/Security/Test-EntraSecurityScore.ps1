function Test-EntraSecurityScore {
    <#
    .SYNOPSIS
        Verifies that the Entra ID Identity Secure Score is above 70%.
    
    .DESCRIPTION
        Tests whether the tenant's Identity Secure Score meets the minimum threshold of 70%
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
        TestName = 'Entra-Security-Score'
        Category = 'Identity'
        SubCategory = 'Security'
        Description = 'Verifies that the Entra ID Identity Secure Score is above 70%'
        ResourceType = 'Microsoft.Graph/security/secureScores'
        WAFPillar = 'Security'
        Severity = 'High'
        ExpectedResult = '>= 70%'
    }
    
    # Test Execution
    $results = @()
    
    try {
        # Get secure score using GraphClient - GetSecureScore uses Azure token directly
        # so we don't need full GraphClient initialization (avoids double login prompt)
        $graphClient = [GraphClient]::new()
        
        # Get the latest secure score (GetSecureScore will get Azure token internally)
        $secureScore = $graphClient.GetSecureScore()
        
        if (-not $secureScore) {
            throw "Unable to retrieve secure score from Microsoft Graph API"
        }
        
        # Extract the score percentage
        # The secure score object has currentScore (points achieved) and maxScore (maximum possible points)
        # Percentage = (currentScore / maxScore) * 100
        $currentScore = $null
        $maxScore = $null
        
        if ($graphClient.UseCmdlets) {
            $currentScore = $secureScore.CurrentScore
            $maxScore = $secureScore.MaxScore
        }
        else {
            $currentScore = $secureScore.currentScore
            $maxScore = $secureScore.maxScore
        }
        
        if ($null -eq $currentScore -or $null -eq $maxScore -or $maxScore -eq 0) {
            throw "Invalid secure score data: currentScore=$currentScore, maxScore=$maxScore"
        }
        
        $scorePercentage = [math]::Round(($currentScore / $maxScore) * 100, 2)
        
        $actualResult = "$scorePercentage% ($currentScore / $maxScore points)"
        
        $rawResult = [PSCustomObject]@{
            'TenantId' = $TenantId
            'CurrentScore' = $currentScore
            'MaxScore' = $maxScore
            'ScorePercentage' = $scorePercentage
            'CreatedDateTime' = if ($graphClient.UseCmdlets) { $secureScore.CreatedDateTime } else { $secureScore.createdDateTime }
        }
        
        $result = [TestResult]@{
            ResourceId = "/tenants/$TenantId/security/secureScores"
            ResourceName = "Identity Secure Score"
            ResourceGroupName = $null
            SubscriptionId = $TenantId
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $actualResult
            RawResult = $rawResult
            ResultStatus = if ($scorePercentage -ge 70) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    catch {
        Write-Warning "Error executing Entra Security Score test: $($_.Exception.Message)"
        
        $errorRawResult = [PSCustomObject]@{
            Error = $_.Exception.Message
            TenantId = $TenantId
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

