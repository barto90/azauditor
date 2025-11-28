function Test-LoadBalancerHealthProbes {
    <#
    .SYNOPSIS
        Verifies that Load Balancers have health probes configured for all load-balanced endpoints.
    
    .DESCRIPTION
        Tests whether Load Balancers have health probes configured and that all load balancing rules
        reference a health probe for monitoring endpoint health according to Well-Architected Framework
        reliability standards.
    
    .PARAMETER LoadBalancers
        Array of Azure Load Balancer objects to test.
    
    .PARAMETER Subscription
        The Azure subscription object the Load Balancers belong to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$LoadBalancers,
        
        [Parameter(Mandatory)]
        $Subscription
    )
    
    # Test Metadata
    $testMetadata = @{
        TestName = 'LoadBalancer-Health-Probes'
        Category = 'Networking'
        SubCategory = 'LoadBalancer'
        Description = 'Verifies that Load Balancers have health probes configured for all load-balanced endpoints'
        ResourceType = 'Microsoft.Network/loadBalancers'
        WAFPillar = 'Reliability'
        Severity = 'High'
        ExpectedResult = $true
    }
    
    # Test Execution
    $results = @()
    
    foreach ($lb in $LoadBalancers) {
        $actualResult = $false
        $rawResult = $null
        
        # Check if Load Balancer has any load balancing rules
        if ($lb.LoadBalancingRules -and $lb.LoadBalancingRules.Count -gt 0) {
            $totalRules = $lb.LoadBalancingRules.Count
            $rulesWithProbes = 0
            $ruleDetails = @()
            
            foreach ($rule in $lb.LoadBalancingRules) {
                $hasProbe = $false
                $probeName = 'None'
                
                # Check if the rule has a health probe reference
                if ($rule.Probe -and $rule.Probe.Id) {
                    $hasProbe = $true
                    $probeName = $rule.Probe.Id.Split('/')[-1]
                    $rulesWithProbes++
                }
                
                $ruleDetails += [PSCustomObject]@{
                    RuleName = $rule.Name
                    FrontendPort = $rule.FrontendPort
                    BackendPort = $rule.BackendPort
                    Protocol = $rule.Protocol
                    HasHealthProbe = $hasProbe
                    ProbeName = $probeName
                }
            }
            
            # Pass if all rules have health probes configured
            $actualResult = ($rulesWithProbes -eq $totalRules)
            
            $rawResult = [PSCustomObject]@{
                TotalLoadBalancingRules = $totalRules
                RulesWithHealthProbes = $rulesWithProbes
                RulesWithoutHealthProbes = ($totalRules - $rulesWithProbes)
                TotalHealthProbes = if ($lb.Probes) { $lb.Probes.Count } else { 0 }
                LoadBalancingRules = $ruleDetails
            }
        }
        else {
            # No load balancing rules configured
            $rawResult = [PSCustomObject]@{
                TotalLoadBalancingRules = 0
                RulesWithHealthProbes = 0
                RulesWithoutHealthProbes = 0
                TotalHealthProbes = if ($lb.Probes) { $lb.Probes.Count } else { 0 }
                LoadBalancingRules = @()
            }
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
            ResourceId = $lb.Id
            ResourceName = $lb.Name
            ResourceGroupName = $lb.ResourceGroupName
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

