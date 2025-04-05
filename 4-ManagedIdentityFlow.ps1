#region Az.Accounts method
if ($env:MSI_SECRET) {
    # get a token for the MSI
    $msiToken = Get-AzAccessToken -ResourceUrl "api://AzureADTokenExchange" -AsSecureString
    # using the MSI token, connect to remote tenant.
    Connect-azAccount -Tenant $tenantId -ApplicationId $env:CLIENT_ID -FederatedToken $($msiToken.Token | ConvertFrom-SecureString)
    # get an access token for graph
    $token = Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
}
#endregion







#region No-Dependency method
if ($env:MSI_SECRET) {
    # request msi access token
    # most guides reference $env:IDENTITY_ENDPOINT and $env:IDENTITY_HEADER
    # but for clarity, the values in MSI_ENDPOINT and MSI_SECRET are exactly the same.
    # MSI_ENDPOINT is a uri pointing to an internal api endpoint on the app service
    # which is usually something like http://localhost:{PORT_NUMBER}/MSI/token/
    # MSI_SECRET is a key that is rotated periodically and is used to protect against SSRF attacks
    $resourceUri = 'api://AzureADTokenExchange'
    $tokenUri = '{0}?resource={1}&api-version=2019-08-01' -f $env:MSI_ENDPOINT, $resourceURI
    $tokenHeader = @{ "X-IDENTITY-HEADER" = $env:MSI_SECRET }
    $msiTokenReq = Invoke-RestMethod -Method Get -Headers $tokenHeader -Uri $tokenUri
    $msiToken = $msiTokenReq.access_token

    # swap msi token for graph access token
    $clientTokenReqBody = @{
        client_id             = $env:CLIENT_ID
        scope                 = 'https://graph.microsoft.com/.default'
        grant_type            = "client_credentials"
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion      = $msiToken
    }
    Write-Host $clientTokenReqBody
    $azueAuthURI = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token' -f $tenantId
    $clientAccessTokenReq = Invoke-RestMethod -Method Post -Uri $azueAuthURI -Form $clientTokenReqBody
    $token = $clientAccessTokenReq.access_token
}
#endregion