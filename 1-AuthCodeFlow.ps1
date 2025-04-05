#auth configuration
$tenantId = 'powers-hell.com'
$clientId = ''
$redirectUri = 'http://localhost:5001/auth/'
$scope    = 'https://graph.microsoft.com/.default'
#endregion

#region Az.Accounts method
Connect-AzAccount -Tenant $tenantId -ApplicationId $clientId
$token = Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
#endregion

#region Microsoft.Graph.Authentication method
Connect-MgGraph -ClientId $clientId -TenantId $tenantId
$token = Get-MgContext
$accessToken = $token.Token
#endregion

#region No-Dependency method
function New-PKCE {

    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidatePattern('(?# Code Verifier can only contain alphanumeric characters and . ~ - _)^[a-zA-Z0-9-._~]+$')][string]$codeVerifier,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [int]$length = 43
    )


    if ($length -gt 128 -or $length -lt 43) {
        Write-Warning "Code Verifier length must be of 43 to 128 characters in length (inclusive)."
        exit 
    }

    if ($codeVerifier) {
        if ($codeVerifier.Length -gt 128 -or $codeVerifier.Length -lt 43) {
            Write-Warning "Code Verifier length must be of 43 to 128 characters in length (inclusive)."
            exit 
        }  
    }

    $pkceTemplate = [pscustomobject][ordered]@{  
        code_verifier  = $null  
        code_challenge = $null   
    }  
        
    if ($codeVerifier) {
        $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
        $hash = $hashAlgo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
        $b64Hash = [System.Convert]::ToBase64String($hash)
        $code_challenge = $b64Hash.Substring(0, 43)

        $code_challenge = $code_challenge.Replace("/", "_")
        $code_challenge = $code_challenge.Replace("+", "-")
        $code_challenge = $code_challenge.Replace("=", "")

        $pkceChallenges = $pkceTemplate.PsObject.Copy()
        $pkceChallenges.code_challenge = $code_challenge 
        $pkceChallenges.code_verifier = $codeVerifier 

        return $pkceChallenges 
    }
    else {
        # PKCE Code verifier. Random alphanumeric string used on the client side
        # From the ASCII Table in Decimal A-Z a-z 0-9
        $codeVerifier = -join (((48..57) * 4) + ((65..90) * 4) + ((97..122) * 4) | Get-Random -Count $length | ForEach-Object { [char]$_ })

        $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
        $hash = $hashAlgo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
        $b64Hash = [System.Convert]::ToBase64String($hash)
        $code_challenge = $b64Hash.Substring(0, 43)
        
        $code_challenge = $code_challenge.Replace("/", "_")
        $code_challenge = $code_challenge.Replace("+", "-")
        $code_challenge = $code_challenge.Replace("=", "")

        $pkceChallenges = $pkceTemplate.PsObject.Copy()
        $pkceChallenges.code_challenge = $code_challenge
        $pkceChallenges.code_verifier = $codeVerifier 

        return $pkceChallenges 
    }
}
function New-StateValue {
    $stateBytes = New-Object byte[] 16
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($stateBytes)
    [System.BitConverter]::ToString($stateBytes) -replace "-"
}
function New-HttpListener {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$redirectUri
    )
    try {
        # Start a local HTTP listener to receive the authorization code
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($redirectUri)
        $listener.Start()
        $requestTask = $listener.GetContextAsync()

        # Open the authorization URL in the default web browser
        Start-Process $authorizationUrl

        Write-Host "Waiting for authorization code..." -ForegroundColor Cyan

        # Wait for the authorization code to be received
        $context = $requestTask.GetAwaiter().GetResult()
        $null = $context.Request.QueryString["code"]
        return $context
    }
    catch {
        Write-Warning $_.Exception.Message
    }
    finally {
        # send a response back to the browser to redirect
        $response = $context.Response
        $response.StatusCode = 302
        $response.RedirectLocation = "https://tabs-not-spaces.github.io/AccessGranted/"
        $response.Close()
        # Stop the HTTP listener
        $listener.Stop()
        
    }
}
function New-AuthTokenRequest {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The tenant ID to authenticate against. Default is 'common'.")]
        [string]$TenantId = 'common',

        [Parameter(Mandatory = $true, HelpMessage = "The client ID of the application.")]
        [string]$ClientId,

        [Parameter(Mandatory = $true, HelpMessage = "The redirect URI of the application.")]
        [string]$RedirectUri,

        [Parameter(Mandatory = $true, HelpMessage = "The scopes to request.")]
        [string[]]$Scopes,

        [Parameter(Mandatory = $false, HelpMessage = "Include the ID token in the response.")]
        [switch]$IncludeIdToken,

        [Parameter(Mandatory = $false, HelpMessage = "Include the refresh token in the response.")]
        [switch]$IncludeRefreshToken
    )

    $state = New-StateValue
    $pkce = New-PKCE -length 43
    $authority = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/authorize' -f $TenantId
    $tokenAuthority = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token' -f $TenantId
    $scopesDict = New-Object System.Collections.Generic.List[string]
    foreach ($scope in $Scopes) {
        $scopesDict.Add($scope)
    }
    if ($IncludeIdToken) {
        Write-Verbose "Including ID token in the response."
        "openid", "profile", "email" | ForEach-Object {
            $scopesDict.Add($_)
        }
    }
    if ($IncludeRefreshToken) {
        Write-Verbose "Including refresh token in the response."
        $scopesDict.Add("offline_access")
    }
    $uriBuilder
    $authorizationUrl = "{0}?response_type=code&client_id={1}&redirect_uri={2}&state={3}&scope={4}&code_challenge={5}&code_challenge_method=S256" -f $authority, $ClientId, $RedirectUri, $state, $($scopesDict -join "%20" ), $pkce.code_challenge
    $authorizationContext = New-HttpListener -Uri $authorizationUrl -redirectUri $RedirectUri
    $authCode = $authorizationContext.Request.QueryString["code"]

    # Exchange the authorization code for tokens
    $tokenRequestParams = @{
        client_id     = $ClientId
        grant_type    = "authorization_code"
        code          = $authCode
        code_verifier = $pkce.code_verifier
        redirect_uri  = $RedirectUri
    }
    $tokenResponse = Invoke-RestMethod -Uri $tokenAuthority -Method Post -Body $tokenRequestParams
    return $tokenResponse

}

$authParams = @{
    ClientId    = $clientId
    TenantId    = $tenantId
    RedirectUri = $redirectUri
    Scopes      = $scopes
}
$script:auth = New-AuthTokenRequest @authParams
#endregion