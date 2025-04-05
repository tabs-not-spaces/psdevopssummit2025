#region auth configuration
$tenantId = 'powers-hell.com'
$clientId = ''
$scope    = 'https://graph.microsoft.com/.default'
#endregion

#region Az.Accounts method
Connect-AzAccount -Tenant $tenandId -ApplicationId $clientId -UseDeviceAuthentication
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

$deviceCode.user_code | clip
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