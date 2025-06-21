#region auth configuration
$tenantId = 'powers-hell.com'
$clientId = 'a0530fb7-7198-4a11-b996-9e711097b24f'
$scope    = 'https://graph.microsoft.com/.default'
#endregion

#region Az.Accounts method
Connect-AzAccount -Tenant $tenantId -ApplicationId $clientId -UseDeviceAuthentication
$token = Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
#endregion











#region no-dependency method
$authorizationParams = @{
    Method = "Post"
    Uri    = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/devicecode' -f $($tenantId ?? 'common')
    Body   = @{
        client_id = $clientId
        scope     = $scope
    }
}
$deviceCode = Invoke-RestMethod @authorizationParams

$deviceCode.user_code | Set-Clipboard
start-process 'https://microsoft.com/devicelogin'

$limit = (Get-Date).AddSeconds($deviceCode.expires_in)
while ((Get-Date) -lt $limit) {
    Start-Sleep -Seconds $deviceCode.interval
    try {
        $tokenUri = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token' -f $($tenantId ?? 'common')
        $authResponse = Invoke-RestMethod -method Post -Uri $tokenUri -Body @{
            client_id   = $clientId
            grant_type  = "device_code"
            device_code = $deviceCode.device_code
        }
    }
    catch {
        if ($_ -match '"error":\s*"authorization_pending"') { continue }
        $PSCmdlet.ThrowTerminatingError($_)
    }
    if ($authResponse) {
        $authResponse
        break
    }
}
#endregion