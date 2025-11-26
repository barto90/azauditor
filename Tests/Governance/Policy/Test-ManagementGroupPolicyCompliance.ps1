function Test-ManagementGroupPolicyCompliance {
    <#
    .SYNOPSIS
        Verifies that all Management Groups have policy assignments and are compliant.
    
    .DESCRIPTION
        Tests whether all management groups in the tenant have:
        - At least one policy assignment
        - 100% policy compliance (0 non-compliant resources)
    
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
        TestName = 'Management-Group-Policy-Compliance'
        Category = 'Governance'
        SubCategory = 'Policy'
        Description = 'Verifies that all Management Groups have policy assignments with 100% compliance'
        ResourceType = 'Microsoft.Authorization/policyAssignments'
        WAFPillar = 'Security'
        Severity = 'High'
        ExpectedResult = 'All management groups have policy assignments with 100% compliance (0 non-compliant resources)'
    }
    
    # Test Execution
    $results = @()
    
    try {
        # Get all management groups
        $allManagementGroups = @(Get-AzManagementGroup -ErrorAction Stop)
        
        if ($allManagementGroups.Count -eq 0) {
            Write-Warning "No management groups found in tenant"
            return @()
        }
        
        Write-Verbose "Checking policy compliance for $($allManagementGroups.Count) management group(s)"
        
        # Track compliance per management group
        $mgComplianceData = @{}
        $mgsWithoutPolicies = @()
        $mgsWithNonCompliance = @()
        
        foreach ($mg in $allManagementGroups) {
            Write-Verbose "Checking management group: $($mg.DisplayName)"
            
            # Get policy assignments for this management group
            $mgScope = "/providers/Microsoft.Management/managementGroups/$($mg.Name)"
            $policyAssignments = @(Get-AzPolicyAssignment -Scope $mgScope -ErrorAction SilentlyContinue)
            
            # Get policy compliance summary
            $complianceSummary = $null
            $nonCompliantCount = 0
            $compliantCount = 0
            $totalResources = 0
            
            try {
                $complianceSummary = Get-AzPolicyStateSummary -ManagementGroupName $mg.Name -ErrorAction SilentlyContinue
                
                if ($complianceSummary -and $complianceSummary.Results) {
                    # Extract compliance counts from the top-level Results
                    $nonCompliantCount = $complianceSummary.Results.NonCompliantResources
                    
                    # Get compliant and total from ResourceDetails
                    if ($complianceSummary.Results.ResourceDetails) {
                        foreach ($detail in $complianceSummary.Results.ResourceDetails) {
                            $totalResources += $detail.Count
                            
                            if ($detail.ComplianceState -eq 'compliant') {
                                $compliantCount = $detail.Count
                            }
                        }
                    }
                }
            }
            catch {
                Write-Verbose "Could not get compliance summary for $($mg.DisplayName): $($_.Exception.Message)"
            }
            
            # Store the data
            $mgComplianceData[$mg.Name] = @{
                DisplayName = if ($mg.DisplayName) { $mg.DisplayName } else { $mg.Name }
                PolicyCount = $policyAssignments.Count
                NonCompliantCount = $nonCompliantCount
                CompliantCount = $compliantCount
                TotalResources = $totalResources
                CompliancePercent = if ($totalResources -gt 0) { 
                    [math]::Round(($compliantCount / $totalResources) * 100, 2) 
                } else { 
                    100 
                }
            }
            
            # Track issues
            if ($policyAssignments.Count -eq 0) {
                $mgsWithoutPolicies += $mgComplianceData[$mg.Name].DisplayName
            }
            
            if ($nonCompliantCount -gt 0) {
                $mgsWithNonCompliance += "$($mgComplianceData[$mg.Name].DisplayName) ($nonCompliantCount non-compliant)"
            }
        }
        
        # Build actual result
        $actualResult = if ($mgsWithoutPolicies.Count -gt 0 -or $mgsWithNonCompliance.Count -gt 0) {
            $issues = @()
            
            if ($mgsWithoutPolicies.Count -gt 0) {
                $issues += "No policies: $($mgsWithoutPolicies -join ', ')"
            }
            
            if ($mgsWithNonCompliance.Count -gt 0) {
                $issues += "Non-compliant: $($mgsWithNonCompliance -join '; ')"
            }
            
            $issues -join ' | '
        }
        else {
            "All management groups have policy assignments with 100% compliance"
        }
        
        # Determine pass/fail
        $isPass = ($mgsWithoutPolicies.Count -eq 0) -and ($mgsWithNonCompliance.Count -eq 0)
        
        # Create detailed summary for raw result
        $summaryTable = $mgComplianceData.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                ManagementGroup = $_.Value.DisplayName
                Policies = $_.Value.PolicyCount
                TotalResources = $_.Value.TotalResources
                Compliant = $_.Value.CompliantCount
                NonCompliant = $_.Value.NonCompliantCount
                CompliancePercent = "$($_.Value.CompliancePercent)%"
            }
        } | Sort-Object ManagementGroup
        
        $result = [TestResult]@{
            ResourceId = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.Authorization/policyAssignments"
            ResourceName = "Management Group Policy Compliance"
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
                ManagementGroupsWithoutPolicies = $mgsWithoutPolicies
                ManagementGroupsWithNonCompliance = $mgsWithNonCompliance
                ComplianceSummary = $summaryTable
            }
            ResultStatus = if ($isPass) { [ResultStatus]::Pass } else { [ResultStatus]::Fail }
        }
        
        $results += $result
    }
    catch {
        Write-Warning "Error checking management group policy compliance: $($_.Exception.Message)"
        
        # Return a fail result if we can't check
        $result = [TestResult]@{
            ResourceId = "/providers/Microsoft.Management/managementGroups/$TenantId/providers/Microsoft.Authorization/policyAssignments"
            ResourceName = "Management Group Policy Compliance"
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

