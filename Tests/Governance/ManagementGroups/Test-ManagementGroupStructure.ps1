function Test-ManagementGroupStructure {
    <#
    .SYNOPSIS
        Verifies that the required Management Group structure exists.
    
    .DESCRIPTION
        Tests whether the tenant has the expected Management Group hierarchy following Azure Landing Zone best practices:
        - Platform Landing Zone with child groups (Connectivity, Identity, Management)
        - Landing Zones management group
        - Each management group has at least one subscription
    
    .PARAMETER TenantId
        The Azure tenant ID to test.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'Management-Group-Structure'
        Category = 'Governance'
        SubCategory = 'ManagementGroups'
        Description = 'Verifies that the required Management Group structure exists with Platform having child groups (Connectivity, Identity, Management) each with subscriptions'
        ResourceType = 'Microsoft.Management/managementGroups'
        WAFPillar = 'Operational Excellence'
        Severity = 'High'
        ExpectedResult = @"
Root
├── Platform Landing Zone
│   ├── Connectivity (with subscriptions)
│   ├── Identity (with subscriptions)
│   └── Management (with subscriptions)
└── Landing Zones
"@
    }
    
    # Test Execution
    $results = @()
    
    try {
        # Get all management groups
        $allManagementGroups = @(Get-AzManagementGroup -ErrorAction Stop)
        
        # Define expected management groups with patterns (case-insensitive)
        $expectedGroups = @{
            'PlatformLandingZone' = @{
                Pattern = 'platform'
                DisplayPattern = 'Platform Landing Zone'
                Found = $false
                HasSubscriptions = $false
                Children = @('Connectivity', 'Identity', 'Management')
                FoundChildren = @()
            }
            'Connectivity' = @{
                Pattern = 'connectivity|connect'
                DisplayPattern = 'Connectivity'
                Found = $false
                HasSubscriptions = $false
                ParentPattern = 'platform'
            }
            'Identity' = @{
                Pattern = 'identity|ident'
                DisplayPattern = 'Identity'
                Found = $false
                HasSubscriptions = $false
                ParentPattern = 'platform'
            }
            'Management' = @{
                Pattern = 'management|mgmt'
                DisplayPattern = 'Management'
                Found = $false
                HasSubscriptions = $false
                ParentPattern = 'platform'
            }
            'LandingZones' = @{
                Pattern = 'landing.?zone|lz'
                DisplayPattern = 'Landing Zones'
                Found = $false
                HasSubscriptions = $false
            }
        }
        
        # Find management groups and check subscriptions
        foreach ($mg in $allManagementGroups) {
            # Get expanded details including subscriptions and children
            $mgDetails = Get-AzManagementGroup -GroupId $mg.Name -Expand -Recurse -ErrorAction SilentlyContinue
            
            $mgDisplayName = if ($mgDetails.DisplayName) { $mgDetails.DisplayName } else { $mgDetails.Name }
            
            # Check Platform Landing Zone
            if ($mgDisplayName -match $expectedGroups['PlatformLandingZone'].Pattern) {
                $expectedGroups['PlatformLandingZone'].Found = $true
                $expectedGroups['PlatformLandingZone'].MgObject = $mgDetails
                
                # Check if it has subscriptions (Type like 'Microsoft.Management/subscriptions' or Id starting with /subscriptions/)
                if ($mgDetails.Children) {
                    $subCount = @($mgDetails.Children | Where-Object { 
                        $_.Type -like '*subscriptions*' -or $_.Id -like '/subscriptions/*'
                    }).Count
                    if ($subCount -gt 0) {
                        $expectedGroups['PlatformLandingZone'].HasSubscriptions = $true
                    }
                }
                
                # Check for child management groups
                if ($mgDetails.Children) {
                    # Filter for management groups (Type contains 'managementGroups', not 'subscriptions')
                    $childMGs = @($mgDetails.Children | Where-Object { 
                        $_.Type -like '*managementGroups*'
                    })
                    foreach ($child in $childMGs) {
                        # Get child display name
                        $childDisplayName = if ($child.DisplayName) { $child.DisplayName } else { $child.Name }
                        
                        # Match children and check subscriptions
                        if ($childDisplayName -match $expectedGroups['Connectivity'].Pattern) {
                            $expectedGroups['Connectivity'].Found = $true
                            $expectedGroups['PlatformLandingZone'].FoundChildren += 'Connectivity'
                            # Check child subscriptions
                            $childDetails = Get-AzManagementGroup -GroupId $child.Name -Expand -ErrorAction SilentlyContinue
                            if ($childDetails -and $childDetails.Children) {
                                # Subscriptions have Type like '/subscriptions' or ID starting with /subscriptions/
                                $childSubCount = @($childDetails.Children | Where-Object { 
                                    $_.Type -like '*subscriptions*' -or $_.Id -like '/subscriptions/*'
                                }).Count
                                if ($childSubCount -gt 0) {
                                    $expectedGroups['Connectivity'].HasSubscriptions = $true
                                }
                            }
                        }
                        elseif ($childDisplayName -match $expectedGroups['Identity'].Pattern) {
                            $expectedGroups['Identity'].Found = $true
                            $expectedGroups['PlatformLandingZone'].FoundChildren += 'Identity'
                            $childDetails = Get-AzManagementGroup -GroupId $child.Name -Expand -ErrorAction SilentlyContinue
                            if ($childDetails -and $childDetails.Children) {
                                $childSubCount = @($childDetails.Children | Where-Object { 
                                    $_.Type -like '*subscriptions*' -or $_.Id -like '/subscriptions/*'
                                }).Count
                                if ($childSubCount -gt 0) {
                                    $expectedGroups['Identity'].HasSubscriptions = $true
                                }
                            }
                        }
                        elseif ($childDisplayName -match $expectedGroups['Management'].Pattern) {
                            $expectedGroups['Management'].Found = $true
                            $expectedGroups['PlatformLandingZone'].FoundChildren += 'Management'
                            $childDetails = Get-AzManagementGroup -GroupId $child.Name -Expand -ErrorAction SilentlyContinue
                            if ($childDetails -and $childDetails.Children) {
                                $childSubCount = @($childDetails.Children | Where-Object { 
                                    $_.Type -like '*subscriptions*' -or $_.Id -like '/subscriptions/*'
                                }).Count
                                if ($childSubCount -gt 0) {
                                    $expectedGroups['Management'].HasSubscriptions = $true
                                }
                            }
                        }
                    }
                }
            }
            
            # Check Landing Zones (separate from Platform)
            if ($mgDisplayName -match $expectedGroups['LandingZones'].Pattern -and 
                $mgDisplayName -notmatch $expectedGroups['PlatformLandingZone'].Pattern) {
                $expectedGroups['LandingZones'].Found = $true
                if ($mgDetails.Children) {
                    $subCount = @($mgDetails.Children | Where-Object { 
                        $_.Type -like '*subscriptions*' -or $_.Id -like '/subscriptions/*'
                    }).Count
                    if ($subCount -gt 0) {
                        $expectedGroups['LandingZones'].HasSubscriptions = $true
                    }
                }
            }
        }
        
        # Determine what's missing
        $missingGroups = @()
        $groupsWithoutSubs = @()
        
        foreach ($key in $expectedGroups.Keys) {
            $group = $expectedGroups[$key]
            if (-not $group.Found) {
                $missingGroups += $group.DisplayPattern
            }
            elseif (-not $group.HasSubscriptions) {
                # Only require subscriptions for child groups (Connectivity, Identity, Management)
                # Platform and Landing Zones are parent/organizational groups and don't need direct subscriptions
                if ($key -notin @('PlatformLandingZone', 'LandingZones')) {
                    $groupsWithoutSubs += $group.DisplayPattern
                }
            }
        }
        
        # Check if Platform has all required children
        $missingChildren = @()
        if ($expectedGroups['PlatformLandingZone'].Found) {
            foreach ($expectedChild in $expectedGroups['PlatformLandingZone'].Children) {
                if ($expectedChild -notin $expectedGroups['PlatformLandingZone'].FoundChildren) {
                    $missingChildren += $expectedChild
                }
            }
        }
        
        # Build actual result
        $actualResult = if ($missingGroups.Count -gt 0) {
            "Missing management groups: $($missingGroups -join ', ')"
        }
        elseif ($missingChildren.Count -gt 0) {
            "Platform Landing Zone missing child groups: $($missingChildren -join ', ')"
        }
        elseif ($groupsWithoutSubs.Count -gt 0) {
            "Management groups without subscriptions: $($groupsWithoutSubs -join ', ')"
        }
        else {
            "All required management groups present with correct hierarchy and subscriptions"
        }
        
        # Determine pass/fail
        $isPass = ($missingGroups.Count -eq 0) -and ($missingChildren.Count -eq 0) -and ($groupsWithoutSubs.Count -eq 0)
        
        $result = [TestResult]@{
            ResourceId = "/providers/Microsoft.Management/managementGroups/$TenantId"
            ResourceName = "Management Group Structure"
            ResourceGroupName = "N/A (Tenant Level)"
            SubscriptionId = "N/A (Tenant Level)"
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = $actualResult
            RawResult = [PSCustomObject]@{
                TenantId = $TenantId
                TotalManagementGroups = $allManagementGroups.Count
                ExpectedGroups = $expectedGroups
                MissingGroups = $missingGroups
                MissingChildren = $missingChildren
                GroupsWithoutSubscriptions = $groupsWithoutSubs
            }
            ResultStatus = if ($isPass) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    catch {
        Write-Warning "Error checking management group structure: $($_.Exception.Message)"
        
        # Return a fail result if we can't check
        $result = [TestResult]@{
            ResourceId = "/providers/Microsoft.Management/managementGroups/$TenantId"
            ResourceName = "Management Group Structure"
            ResourceGroupName = "N/A (Tenant Level)"
            SubscriptionId = "N/A (Tenant Level)"
            Category = $testMetadata.Category
            SubCategory = $testMetadata.SubCategory
            TestName = $testMetadata.TestName
            TestDescription = $testMetadata.Description
            ExpectedResult = $testMetadata.ExpectedResult
            ActualResult = "Error: $($_.Exception.Message)"
            RawResult = $null
            ResultStatus = [ResultStatus]::Fail
        }
        
        $results += $result
    }
    
    return $results
}

