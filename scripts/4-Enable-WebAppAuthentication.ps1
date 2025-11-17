# Enable ADFS Authentication on SharePoint Web Application
# Run this script on the SharePoint server using SharePoint Management Shell as Administrator

<#
.SYNOPSIS
    Enables ADFS authentication provider on a SharePoint web application.

.DESCRIPTION
    This script configures a SharePoint web application to use the ADFS trusted
    identity token issuer for authentication.

.PARAMETER WebApplicationUrl
    The URL of the SharePoint web application.

.PARAMETER ProviderName
    The name of the trusted identity token issuer.

.PARAMETER Zone
    The zone to configure (Default, Intranet, Extranet, Internet, or Custom).

.EXAMPLE
    .\4-Enable-WebAppAuthentication.ps1 -WebApplicationUrl "https://sharepoint.contoso.com" -ProviderName "ADFS Provider" -Zone "Default"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WebApplicationUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ProviderName = "ADFS Provider",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Default", "Intranet", "Extranet", "Internet", "Custom")]
    [string]$Zone = "Default"
)

# Ensure the script is run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Ensure SharePoint PowerShell snapin is loaded
if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapin Microsoft.SharePoint.PowerShell
}

try {
    Write-Host "Enabling ADFS authentication on SharePoint web application..." -ForegroundColor Cyan
    
    # Get the web application
    Write-Host "Getting web application: $WebApplicationUrl" -ForegroundColor Cyan
    $webApp = Get-SPWebApplication $WebApplicationUrl -ErrorAction Stop
    
    if ($null -eq $webApp) {
        Write-Error "Web application not found: $WebApplicationUrl"
        exit 1
    }
    
    # Get the ADFS provider
    Write-Host "Getting authentication provider: $ProviderName" -ForegroundColor Cyan
    $provider = Get-SPTrustedIdentityTokenIssuer -Identity $ProviderName -ErrorAction Stop
    
    if ($null -eq $provider) {
        Write-Error "Trusted identity token issuer not found: $ProviderName"
        exit 1
    }
    
    # Enable claims authentication on the web application
    Write-Host "Enabling claims authentication..." -ForegroundColor Cyan
    $webApp.UseClaimsAuthentication = $true
    $webApp.Update()
    
    # Get the zone
    $zoneEnum = [Microsoft.SharePoint.Administration.SPUrlZone]::$Zone
    
    # Configure authentication for the zone
    Write-Host "Configuring authentication provider for $Zone zone..." -ForegroundColor Cyan
    
    $authProvider = New-SPAuthenticationProvider -TrustedIdentityTokenIssuer $provider
    
    Set-SPWebApplication -Identity $webApp -Zone $zoneEnum -AuthenticationProvider $authProvider -SignInRedirectURL ""
    
    Write-Host ""
    Write-Host "=== Web Application Authentication Enabled ===" -ForegroundColor Green
    Write-Host "Web Application: $WebApplicationUrl" -ForegroundColor Green
    Write-Host "Zone: $Zone" -ForegroundColor Green
    Write-Host "Provider: $ProviderName" -ForegroundColor Green
    Write-Host ""
    Write-Host "Users can now authenticate using ADFS!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Test the configuration by:" -ForegroundColor Yellow
    Write-Host "1. Opening a browser in private/incognito mode" -ForegroundColor Yellow
    Write-Host "2. Navigating to: $WebApplicationUrl" -ForegroundColor Yellow
    Write-Host "3. You should be redirected to ADFS for authentication" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Error "An error occurred: $_"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
