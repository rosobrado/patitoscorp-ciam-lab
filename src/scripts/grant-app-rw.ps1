$ErrorActionPreference = 'Stop'
$tenantId='938a8e7d-00ed-46bc-8109-161428d9d67c'
$adminAppId='521b8fa2-b8d0-4fa7-8917-648f083e676f'
$adminSecret=(Get-Content "$env:TEMP\extid-graph-secret.txt" -Raw).Trim()
$tok=(Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body @{client_id=$adminAppId;client_secret=$adminSecret;scope='https://graph.microsoft.com/.default';grant_type='client_credentials'} -ContentType 'application/x-www-form-urlencoded').access_token
$h=@{Authorization="Bearer $tok"}
$adminSpId='3c8bc59c-6e4c-436a-8372-647938dc2d69'
$graphSp=Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')" -Headers $h
$role=$graphSp.appRoles | Where-Object { $_.value -eq 'Application.ReadWrite.All' }
"GraphSpId=$($graphSp.id)"
"RoleId=$($role.id)"
$body=@{principalId=$adminSpId; resourceId=$graphSp.id; appRoleId=$role.id} | ConvertTo-Json
try {
  $r = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$adminSpId/appRoleAssignments" -Headers $h -Body $body -ContentType 'application/json'
  "GRANTED: $($r.id)"
} catch {
  "ERROR: $($_.ErrorDetails.Message)"
}
