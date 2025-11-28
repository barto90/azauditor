function Test-VMNamingConvention {
    <#
    .SYNOPSIS
        Verifies that Virtual Machine names follow the configured naming convention patterns.
    
    .DESCRIPTION
        Tests whether VM names match one or more regex patterns defined in the NamingConventions.json
        configuration file. This ensures consistent naming standards across the Azure environment.
    
    .PARAMETER VMs
        Array of Azure VM objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the VMs belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$VMs,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Load naming convention configuration
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\..\Config\NamingConventions.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Warning "Naming convention configuration file not found at: $configPath"
        return @()
    }
    
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to parse naming convention configuration: $_"
        return @()
    }
    
    # Check if naming convention tests are enabled globally
    if (-not $config.globalSettings.enabled) {
        Write-Verbose "Naming convention validation is disabled globally. Skipping test."
        return @()
    }
    
    # Get VM-specific configuration
    $vmConfig = $config.resourceTypes.'Microsoft.Compute/virtualMachines'
    
    # Skip if not enabled for VMs
    if (-not $vmConfig.enabled) {
        Write-Verbose "Naming convention validation is disabled for Virtual Machines. Skipping test."
        return @()
    }
    
    # Skip if no patterns defined
    if ($null -eq $vmConfig.patterns -or $vmConfig.patterns.Count -eq 0) {
        Write-Verbose "No naming convention patterns defined for Virtual Machines. Skipping test."
        return @()
    }
    
    # Determine case sensitivity
    $caseSensitive = if ($null -ne $vmConfig.caseSensitive) { 
        $vmConfig.caseSensitive 
    } else { 
        $config.globalSettings.defaultCaseSensitive 
    }
    
    # Build expected result description
    $patternDescriptions = $vmConfig.patterns | ForEach-Object { 
        "$($_.name): $($_.regex)" 
    }
    $expectedResult = "Matches one of: $($patternDescriptions -join ' OR ')"
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'VM-Naming-Convention'
        Category = 'Compute'
        SubCategory = 'VM'
        Description = 'Verifies that VM names follow organizational naming convention standards'
        ResourceType = 'Microsoft.Compute/virtualMachines'
        WAFPillar = 'Operational Excellence'
        Severity = 'Low'
        ExpectedResult = $expectedResult
    }
    
    # Test Execution
    $results = @()
    
    foreach ($vm in $VMs) {
        $vmName = $vm.Name
        $matchedPattern = $null
        $isValid = $false
        
        # Test against each pattern
        foreach ($pattern in $vmConfig.patterns) {
            $regexOptions = if ($caseSensitive) { 
                [System.Text.RegularExpressions.RegexOptions]::None 
            } else { 
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase 
            }
            
            if ([regex]::IsMatch($vmName, $pattern.regex, $regexOptions)) {
                $matchedPattern = $pattern.name
                $isValid = $true
                break
            }
        }
        
        $actualResult = if ($isValid) {
            "Valid - Matches: $matchedPattern"
        } else {
            "Invalid - Does not match any configured pattern"
        }
        
        # Convert VM object to JSON string for serialization through jobs
        # This preserves the VM data when passing through Start-Job/Receive-Job
        $vmJson = $null
        try {
            $vmJson = $vm | ConvertTo-Json -Depth 10 -Compress:$false
        }
        catch {
            # Fallback if JSON conversion fails
            $vmJson = $vm | Select-Object * | ConvertTo-Json -Depth 10 -Compress:$false
        }
        
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
            RawResult = $vmJson
            ResultStatus = if ($isValid) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    
    return $results
}

