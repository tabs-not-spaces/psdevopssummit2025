#region auth configuration
$tenantId = 'powers-hell.com'
$clientId = 'a0530fb7-7198-4a11-b996-9e711097b24f'
$clientSecret = ''
$scope    = 'https://graph.microsoft.com/.default'
#endregion


#region Az.Accounts method
$credentials = New-Object System.Management.Automation.PSCredential $clientId, ($clientSecret | ConvertTo-SecureString -AsPlainText -Force)
Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenantId
$token = (Get-AzAccessToken -resourceUrl "https://graph.microsoft.com/")
#endregion









#region No-Dependency method
$authParams = @{
    Method = "Post"
    Uri    = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token' -f $($tenantId ?? 'common')
    Body   = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = $scope
        grant_type    = "client_credentials"
    }
}
$authResponse = Invoke-RestMethod @authParams
$authResponse
$token = $authResponse.access_token
#endregion