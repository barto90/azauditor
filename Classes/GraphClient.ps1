class GraphClient {
    # Required Microsoft Graph API scopes
    static [string[]] $RequiredScopes = @(
        'User.Read.All', 
        'UserAuthenticationMethod.Read.All', 
        'Policy.Read.All',
        'SecurityEvents.Read.All')
    
    [string]$AccessToken
    
    [bool]$UseCmdlets

    hidden [object]$GraphContext
    
    GraphClient() {
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Check if Graph modules are available
        $graphModules = Get-Module -ListAvailable -Name Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Identity.Policies
        
        if ($graphModules) {
            try {
                Import-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -ErrorAction Stop
                Import-Module Microsoft.Graph.Identity.Policies -ErrorAction SilentlyContinue
                
                $this.GraphContext = Get-MgContext -ErrorAction SilentlyContinue
                if ($this.GraphContext) {
                    # Check if we have the required scopes
                    $currentScopes = @()
                    if ($this.GraphContext.PSObject.Properties.Name -contains 'Scopes') {
                        $currentScopes = $this.GraphContext.Scopes
                    }
                    
                    # If no scopes property or empty, assume we need to reconnect
                    $hasRequiredScopes = $false
                    if ($currentScopes -and $currentScopes.Count -gt 0) {
                        $hasRequiredScopes = $true
                        foreach ($requiredScope in [GraphClient]::RequiredScopes) {
                            if ($currentScopes -notcontains $requiredScope) {
                                $hasRequiredScopes = $false
                                break
                            }
                        }
                    }
                    
                    if ($hasRequiredScopes) {
                        $this.UseCmdlets = $true
                        Write-Verbose "GraphClient: Using Microsoft Graph PowerShell cmdlets"
                        return
                    }
                    else {
                        if ($currentScopes) {
                            Write-Warning "GraphClient: Connected to Microsoft Graph but missing required scopes."
                            Write-Warning "Current scopes: $($currentScopes -join ', ')"
                        }
                        else {
                            Write-Warning "GraphClient: Connected to Microsoft Graph but scope information is unavailable."
                        }
                        Write-Warning "Required scopes: $([GraphClient]::RequiredScopes -join ', ')"
                        
                        if ($this.PromptForConnection()) {
                            $this.ConnectToGraph()
                            $this.GraphContext = Get-MgContext -ErrorAction SilentlyContinue
                            if ($this.GraphContext) {
                                $this.UseCmdlets = $true
                                Write-Verbose "GraphClient: Connected to Microsoft Graph with required scopes"
                                return
                            }
                        }
                    }
                }
                else {
                    # Not connected - prompt user
                    if ($this.PromptForConnection()) {
                        $this.ConnectToGraph()
                        $this.GraphContext = Get-MgContext -ErrorAction SilentlyContinue
                        if ($this.GraphContext) {
                            $this.UseCmdlets = $true
                            Write-Verbose "GraphClient: Connected to Microsoft Graph"
                            return
                        }
                    }
                }
            }
            catch {
                Write-Verbose "GraphClient: Failed to use Graph cmdlets: $($_.Exception.Message)"
            }
        }
        else {
            Write-Warning "GraphClient: Microsoft Graph PowerShell modules are not installed."
            Write-Warning "Please install: Install-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Identity.Policies -Scope CurrentUser"
        }
        
        # Fallback to REST API with token
        $this.UseCmdlets = $false
        try {
            $this.GetAccessToken()
        }
        catch {
            # If we can't get token, that's okay - some methods like GetSecureScore will get it themselves
            Write-Verbose "GraphClient: Could not get access token during initialization: $($_.Exception.Message)"
        }
    }
    
    [bool] PromptForConnection() {
        Write-Host ""
        Write-Host "Microsoft Graph connection is required to review Entra ID settings." -ForegroundColor Yellow
        Write-Host "Required scopes: $([GraphClient]::RequiredScopes -join ', ')" -ForegroundColor Yellow
        Write-Host ""
        
        $response = Read-Host "Do you want to connect to Microsoft Graph with an account that has the correct permissions? (Y/N)"
        
        if ($response -match '^[Yy]([Ee][Ss])?$') {
            return $true
        }
        
        Write-Warning "Microsoft Graph connection declined. Some Identity tests may fail."
        return $false
    }
    
    [void] ConnectToGraph() {
        try {
            $scopeString = [GraphClient]::RequiredScopes -join ','
            Write-Host "Connecting to Microsoft Graph with scopes: $scopeString" -ForegroundColor Cyan
            
            Connect-MgGraph -Scopes ([GraphClient]::RequiredScopes) -ErrorAction Stop
            
            Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
        }
        catch {
            throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        }
    }
    
    [void] GetAccessToken() {
        try {
            # Get token from Azure PowerShell context
            $context = Get-AzContext -ErrorAction SilentlyContinue
            if ($context) {
                $token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction SilentlyContinue).Token
                if ($token) {
                    $this.AccessToken = $token
                    Write-Verbose "GraphClient: Using token from Azure context"
                    return
                }
            }
            
            throw "Failed to obtain access token for Microsoft Graph. Please ensure you are connected to Azure (Connect-AzAccount) and have the necessary permissions."
        }
        catch {
            throw "GraphClient: Unable to authenticate. Error: $($_.Exception.Message)"
        }
    }
    
    [object] InvokeGraphRequest([string]$Uri, [string]$Method = 'Get', [object]$Body = $null) {
        if ($this.UseCmdlets) {
            throw "InvokeGraphRequest should not be called when UseCmdlets is true"
        }
        
        $headers = @{
            'Authorization' = "Bearer $($this.AccessToken)"
            'Content-Type' = 'application/json'
        }
        
        $params = @{
            Uri = $Uri
            Headers = $headers
            Method = $Method
            ErrorAction = 'Stop'
        }
        
        if ($Body) {
            $params['Body'] = ($Body | ConvertTo-Json -Depth 10)
        }
        
        return Invoke-RestMethod @params
    }
    
    [object] GetAuthenticationMethodsPolicy() {
        if ($this.UseCmdlets) {
            $cmdlet = Get-Command Get-MgPolicyAuthenticationMethodPolicy -ErrorAction SilentlyContinue
            if ($cmdlet) {
                return Get-MgPolicyAuthenticationMethodPolicy -ErrorAction Stop
            }
        }
        
        # Fallback to REST API
        return $this.InvokeGraphRequest("https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy")
    }
    
    [object] GetAuthenticationMethodConfiguration([string]$MethodId) {
        $policy = $this.GetAuthenticationMethodsPolicy()
        
        if ($this.UseCmdlets) {
            $configs = $policy.AuthenticationMethodConfigurations
            if ($configs) {
                return $configs | Where-Object { $_.Id -eq $MethodId }
            }
        }
        else {
            $configs = $policy.authenticationMethodConfigurations
            if ($configs) {
                return $configs | Where-Object { $_.id -eq $MethodId }
            }
        }
        
        return $null
    }
    
    [bool] IsAuthenticationMethodEnabled([string]$MethodId) {
        $config = $this.GetAuthenticationMethodConfiguration($MethodId)
        
        if (-not $config) {
            return $false
        }
        
        if ($this.UseCmdlets) {
            return $config.State -eq 'enabled'
        }
        else {
            return $config.state -eq 'enabled'
        }
    }
    
    [object[]] GetUsers([string[]]$Properties = @('Id', 'DisplayName', 'UserPrincipalName')) {
        if ($this.UseCmdlets) {
            $propertyString = $Properties -join ','
            return Get-MgUser -All -Property $propertyString -ErrorAction Stop
        }
        else {
            $selectString = $Properties -join ','
            $uri = "https://graph.microsoft.com/v1.0/users?`$select=$selectString"
            $allUsers = @()
            $nextLink = $uri
            
            while ($nextLink) {
                $response = $this.InvokeGraphRequest($nextLink)
                $allUsers += $response.value
                $nextLink = $response.'@odata.nextLink'
            }
            
            return $allUsers
        }
    }
    
    [object[]] GetUserAuthenticationMethods([string]$UserId) {
        if ($this.UseCmdlets) {
            return Get-MgUserAuthenticationMethod -UserId $UserId -ErrorAction Stop
        }
        else {
            $uri = "https://graph.microsoft.com/v1.0/users/$UserId/authentication/methods"
            $response = $this.InvokeGraphRequest($uri)
            return $response.value
        }
    }
    
    [object] GetSecureScore() {
        # Get the latest secure score from Microsoft Graph Security API
        # The Identity Secure Score is available via the security/secureScores endpoint
        # We need to get the latest score, which is typically the first result ordered by date
        if ($this.UseCmdlets) {
            # Try using Microsoft Graph Security cmdlets if available
            $securityModule = Get-Module -ListAvailable -Name Microsoft.Graph.Security -ErrorAction SilentlyContinue
            if ($securityModule) {
                try {
                    Import-Module Microsoft.Graph.Security -ErrorAction SilentlyContinue
                    $scores = Get-MgSecuritySecureScore -Top 1 -OrderBy createdDateTime -ErrorAction Stop
                    if ($scores) {
                        return $scores
                    }
                }
                catch {
                    Write-Verbose "GraphClient: Could not use Security cmdlets, falling back to REST API"
                }
            }
        }
        
        # Fallback to REST API
        $uri = "https://graph.microsoft.com/v1.0/security/secureScores?`$top=1&`$orderby=createdDateTime desc"
        $response = $this.InvokeGraphRequest($uri)
        
        if ($response.value -and $response.value.Count -gt 0) {
            return $response.value[0]
        }
        
        return $null
    }
}

