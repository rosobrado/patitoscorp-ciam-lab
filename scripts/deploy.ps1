<#
.SYNOPSIS
CIAM Lab — End-to-end deployment (PowerShell equivalent of deploy.sh).

.DESCRIPTION
  Same flow as scripts/deploy.sh but native PowerShell, with az CLI + Invoke-RestMethod:
    1. Resource group
    2. App registration in CIAM tenant
    3. Client secret
    4. ARM deployment (App Service + Plan + Key Vault + RBAC)
    5. Store secret in Key Vault
    6. Patch redirect URI on the app reg
    7. dotnet publish + zip deploy
    8. (Optional) Upload branding via Graph

.PARAMETER CiamTenantId
  CIAM (Entra External ID) tenant id. Required.

.PARAMETER CiamDomain
CIAM authority host, e.g. contoso.ciamlogin.com

.LINK
  https://learn.microsoft.com/azure/azure-resource-manager/templates/
  https://learn.microsoft.com/entra/external-id/customers/overview-customers-ciam
  https://learn.microsoft.com/azure/app-service/configure-authentication-provider-openid-connect
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup    = "rg-ciam-lab",
  [string]$Location      = "westeurope",
  [string]$AppName       = "extid-lab-$([Guid]::NewGuid().ToString('N').Substring(0,6))",
  [string]$Sku           = "B1",

  [Parameter(Mandatory=$true)] [string]$CiamTenantId,
  [Parameter(Mandatory=$true)] [string]$CiamDomain,
    [string]$AppRegDisplay     = "CIAM Lab Web",
  [string]$InfraSubscription = $null,
  [bool]  $UploadBranding    = $true
)

$ErrorActionPreference = "Stop"
function Log  ($m) { Write-Host "`n▶ $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "  ✓ $m"    -ForegroundColor Green }
function Warn ($m) { Write-Host "  ! $m"    -ForegroundColor Yellow }

$Root      = Split-Path -Parent $PSScriptRoot
$InfraDir  = Join-Path $Root "infra"
$SrcDir    = Join-Path $Root "src"
$BrandDir  = Join-Path $Root "branding"
$OutDir    = Join-Path $Root ".deployment-output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- 1. Preflight -------------------------------------------------------------
Log "Preflight"
foreach ($cli in 'az','dotnet') {
  if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) { throw "Missing CLI: $cli" }
}
if (-not $InfraSubscription) { $InfraSubscription = az account show --query id -o tsv }
az account set --subscription $InfraSubscription | Out-Null
Ok "Subscription = $(az account show --query name -o tsv)"

# --- 2. Resource group --------------------------------------------------------
Log "Resource group: $ResourceGroup ($Location)"
az group create -n $ResourceGroup -l $Location -o none
Ok "Group ready"

# --- 3. App registration in CIAM tenant ---------------------------------------
Log "Logging in to CIAM tenant ($CiamTenantId)"
try   { az account get-access-token --tenant $CiamTenantId --resource https://graph.microsoft.com 2>$null | Out-Null }
catch { az login --tenant $CiamTenantId --allow-no-subscriptions --use-device-code | Out-Null }
$CiamToken = az account get-access-token --tenant $CiamTenantId --resource https://graph.microsoft.com --query accessToken -o tsv
$Headers   = @{ Authorization = "Bearer $CiamToken" }

Log "Creating app registration"
$body = @{
  displayName    = $AppRegDisplay
  signInAudience = "AzureADMyOrg"
  web            = @{ redirectUris = @(); implicitGrantSettings = @{ enableIdTokenIssuance = $false } }
} | ConvertTo-Json -Depth 5
$appReg = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/applications" -Headers $Headers -ContentType "application/json" -Body $body
$CiamClientId = $appReg.appId
$CiamObjectId = $appReg.id
Ok "App reg client id: $CiamClientId"

Log "Generating client secret"
$pwBody = @{ passwordCredential = @{ displayName = "deploy-script"; endDateTime = (Get-Date).AddMonths(24).ToString("yyyy-MM-ddTHH:mm:ssZ") } } | ConvertTo-Json -Depth 5
$pwResp = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/applications/$CiamObjectId/addPassword" -Headers $Headers -ContentType "application/json" -Body $pwBody
$CiamClientSecret = $pwResp.secretText
Ok "Secret generated"

# --- 4. ARM deployment --------------------------------------------------------
Log "Deploying ARM template"
$deploy = az deployment group create `
  --resource-group $ResourceGroup `
  --template-file (Join-Path $InfraDir "azuredeploy.json") `
  --parameters "appName=$AppName" "location=$Location" "skuName=$Sku" `
               "ciamTenantId=$CiamTenantId" "ciamClientId=$CiamClientId" "ciamDomain=$CiamDomain" `
  --query properties.outputs -o json | ConvertFrom-Json

$AppHost     = $deploy.appHostname.value
$AppUrl      = $deploy.appUrl.value
$RedirectUri = $deploy.redirectUri.value
$KvName      = $deploy.keyVaultName.value
Ok "App URL    : $AppUrl"
Ok "Redirect   : $RedirectUri"
Ok "Key Vault  : $KvName"

# --- 5. Store secret in Key Vault --------------------------------------------
Log "Storing secret in Key Vault"
$Me   = az ad signed-in-user show --query id -o tsv
$KvId = az keyvault show -n $KvName -g $ResourceGroup --query id -o tsv
az role assignment create --assignee-object-id $Me --assignee-principal-type User `
  --role "Key Vault Secrets Officer" --scope $KvId -o none 2>$null | Out-Null
Start-Sleep -Seconds 20
az keyvault secret set --vault-name $KvName --name "ExtIdClientSecret" --value $CiamClientSecret -o none
Ok "Secret stored"

# --- 6. Patch redirect URI ----------------------------------------------------
Log "Patching redirect URI"
$patchBody = @{ web = @{ redirectUris = @($RedirectUri) } } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Patch -Uri "https://graph.microsoft.com/v1.0/applications/$CiamObjectId" -Headers $Headers -ContentType "application/json" -Body $patchBody | Out-Null
Ok "Redirect URI registered"

# --- 7. Build + deploy app ----------------------------------------------------
Log "Building .NET 8 app"
$Pub = Join-Path $OutDir "publish"
$Zip = Join-Path $OutDir "app.zip"
if (Test-Path $Pub) { Remove-Item $Pub -Recurse -Force }
if (Test-Path $Zip) { Remove-Item $Zip -Force }
dotnet publish (Join-Path $SrcDir "CiamLabApp.csproj") -c Release -o $Pub --nologo | Out-Null
Compress-Archive -Path "$Pub\*" -DestinationPath $Zip -Force
Ok "Package: $((Get-Item $Zip).Length / 1MB) MB"

Log "Zip deploy"
az webapp deploy -g $ResourceGroup -n $AppName --src-path $Zip --type zip -o none
Ok "Deployed"

# --- 8. Branding (optional) ---------------------------------------------------
if ($UploadBranding -and (Test-Path $BrandDir)) {
  Log "Uploading branding via Graph"
  $org = $CiamTenantId
  try {
    $BrandName = if ($env:BRAND_NAME) { $env:BRAND_NAME } else { "CIAM Lab" }
$localBody = @{ id="0"; signInPageText="Bienvenido a $BrandName"; usernameHintText="correo@dominio.com"; backgroundColor="#1A1B3A" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/organization/$org/branding/localizations" -Headers $Headers -ContentType "application/json" -Body $localBody | Out-Null
  } catch { } # already exists -> ignore

  function PutAsset([string]$Path, [string]$Endpoint, [string]$Mime) {
    if (-not (Test-Path $Path)) { Warn "skip (missing): $Path"; return }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $h = @{ Authorization="Bearer $CiamToken"; "Accept-Language"="0" }
    Invoke-WebRequest -Method Put -Uri "https://graph.microsoft.com/v1.0/organization/$org/branding/localizations/0/$Endpoint" -Headers $h -ContentType $Mime -Body $bytes | Out-Null
    Ok "$Endpoint uploaded"
  }
  PutAsset (Join-Path $BrandDir "banner.png")     "bannerLogo"      "image/png"
  PutAsset (Join-Path $BrandDir "square.png")     "squareLogo"      "image/png"
  PutAsset (Join-Path $BrandDir "square.png")     "squareLogoDark"  "image/png"
  PutAsset (Join-Path $BrandDir "background.jpg") "backgroundImage" "image/jpeg"
}

# --- 9. Summary ---------------------------------------------------------------
@"

============================================================
 DEPLOY OK
------------------------------------------------------------
 App URL          : $AppUrl
 Redirect URI     : $RedirectUri
 Resource group   : $ResourceGroup
 App Service      : $AppName ($Sku)
 Key Vault        : $KvName
 CIAM tenant      : $CiamTenantId
 CIAM domain      : $CiamDomain
 App reg (client) : $CiamClientId
============================================================
"@ | Tee-Object -FilePath (Join-Path $OutDir "summary.txt")
