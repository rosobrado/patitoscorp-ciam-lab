<#
.SYNOPSIS
    Rebrand the Microsoft Entra External ID tenant from "Patitos Corp" to
    "Patitos Bank" and switch hosted-page copy / language to Spanish.

.DESCRIPTION
    Updates:
      1. Organization displayName  (Patitos Corp -> Patitos Bank)
      2. Organization preferredLanguage (en -> es-CR)
      3. Default tenant branding (sign-in page text, username hint, colors)
      4. es-CR localization (Spanish sign-in page)

    The CIAM initial domain (patitoscorp.ciamlogin.com) is immutable and
    will keep saying "patitoscorp" in the URL bar. The visible brand will
    say "Patitos Bank" everywhere.

.NOTES
    Run this once as a tenant admin:
        powershell -ExecutionPolicy Bypass -File .\scripts\update-tenant-branding.ps1
    Requires Microsoft.Graph PowerShell module.
#>

[CmdletBinding()]
param(
    [string]$TenantId = '938a8e7d-00ed-46bc-8109-161428d9d67c',
    [string]$DisplayName = 'Patitos Bank',
    [string]$PreferredLanguage = 'es-CR'
)

$ErrorActionPreference = 'Stop'

# --- Ensure module ---
$mods = @('Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Authentication')
foreach ($m in $mods) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "Installing $m ..." -ForegroundColor Yellow
        Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $m -ErrorAction Stop
}

Write-Host "Connecting to Microsoft Graph (tenant $TenantId) ..." -ForegroundColor Cyan
Connect-MgGraph -TenantId $TenantId `
    -Scopes 'Organization.ReadWrite.All' `
    -UseDeviceCode -NoWelcome

# --- 1. Rename organization ---
Write-Host "`n=== Renaming organization ===" -ForegroundColor Cyan
$orgBody = @{
    displayName       = $DisplayName
    preferredLanguage = $PreferredLanguage
}
Update-MgOrganization -OrganizationId $TenantId -BodyParameter $orgBody
$org = Get-MgOrganization -OrganizationId $TenantId
Write-Host "  displayName       : $($org.DisplayName)" -ForegroundColor Green
Write-Host "  preferredLanguage : $($org.PreferredLanguage)" -ForegroundColor Green

# --- 2. Update default branding (locale '0') ---
Write-Host "`n=== Updating default branding ===" -ForegroundColor Cyan
$defaultBranding = @{
    signInPageText   = "Patitos Bank - tu banco 100% digital. Inicia sesion con Google, Microsoft o tu correo electronico."
    usernameHintText = 'tu@correo.com'
    backgroundColor  = '#F5F3FF'
}
try {
    Update-MgOrganizationBranding -OrganizationId $TenantId -BodyParameter $defaultBranding
    Write-Host "  Default branding updated." -ForegroundColor Green
} catch {
    Write-Host "  No default branding yet, creating ..." -ForegroundColor Yellow
    $createBody = $defaultBranding.Clone()
    $createBody['id'] = '0'
    New-MgOrganizationBrandingLocalization -OrganizationId $TenantId -BodyParameter $createBody
    Write-Host "  Default branding created." -ForegroundColor Green
}

# --- 3. Spanish (Costa Rica) localization ---
Write-Host "`n=== Upserting es-CR localization ===" -ForegroundColor Cyan
$esBranding = @{
    id               = 'es-CR'
    signInPageText   = 'Bienvenido a Patitos Bank - el banco 100% digital. Inicia sesion con Google, Microsoft o tu correo electronico.'
    usernameHintText = 'tu@correo.com'
    backgroundColor  = '#F5F3FF'
}
try {
    New-MgOrganizationBrandingLocalization -OrganizationId $TenantId -BodyParameter $esBranding
    Write-Host "  es-CR localization created." -ForegroundColor Green
} catch {
    Write-Host "  es-CR exists, updating ..." -ForegroundColor Yellow
    $upd = $esBranding.Clone()
    $upd.Remove('id')
    Update-MgOrganizationBrandingLocalization `
        -OrganizationId $TenantId `
        -OrganizationalBrandingLocalizationId 'es-CR' `
        -BodyParameter $upd
    Write-Host "  es-CR localization updated." -ForegroundColor Green
}

Write-Host "`nDone. Open https://extid-lab-z6px9l.azurewebsites.net/ and click 'Abrir mi cuenta gratis' to verify." -ForegroundColor Cyan
Write-Host "Note: the URL host (patitoscorp.ciamlogin.com) is the immutable initial CIAM domain and cannot be renamed." -ForegroundColor DarkYellow
