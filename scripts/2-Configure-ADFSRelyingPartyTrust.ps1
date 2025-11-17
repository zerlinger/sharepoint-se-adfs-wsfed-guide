# Configure ADFS Relying Party Trust for SharePoint
# Run this script on the ADFS server as Administrator

<#
.SYNOPSIS
    Configures ADFS Relying Party Trust for SharePoint Subscription Edition.

.DESCRIPTION
    This script creates a relying party trust in ADFS for SharePoint and configures
    the necessary claim rules for authentication.

.PARAMETER SharePointUrl
    The URL of the SharePoint web application.

.PARAMETER Realm
    The realm identifier for SharePoint (URN format).

.PARAMETER TrustName
    The name for the relying party trust.

.EXAMPLE
    .\2-Configure-ADFSRelyingPartyTrust.ps1 -SharePointUrl "https://sharepoint.contoso.com" -Realm "urn:sharepoint:contoso" -TrustName "SharePoint Subscription Edition"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SharePointUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$Realm,
    
    [Parameter(Mandatory=$false)]
    [string]$TrustName = "SharePoint Subscription Edition"
)

# Ensure the script is run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# Ensure ADFS module is available
if (-not (Get-Module -ListAvailable -Name ADFS)) {
    Write-Error "ADFS module is not available. This script must be run on an ADFS server."
    exit 1
}

# Normalize SharePoint URL (remove trailing slash)
$SharePointUrl = $SharePointUrl.TrimEnd('/')

try {
    Write-Host "Configuring ADFS Relying Party Trust for SharePoint..." -ForegroundColor Cyan
    
    # Check if relying party trust already exists
    $existingTrust = Get-AdfsRelyingPartyTrust -Name $TrustName -ErrorAction SilentlyContinue
    if ($existingTrust) {
        Write-Warning "A relying party trust with the name '$TrustName' already exists."
        $response = Read-Host "Do you want to remove it and create a new one? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Remove-AdfsRelyingPartyTrust -TargetName $TrustName
            Write-Host "Existing trust removed." -ForegroundColor Yellow
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Define claim rules
    $claimRules = @"
@RuleName = "Send LDAP Attributes"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"), query = ";mail,userPrincipalName;{0}", param = c.Value);

@RuleName = "Send UPN as Name ID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);
"@

    # Create the relying party trust
    Write-Host "Creating relying party trust..." -ForegroundColor Cyan
    Add-AdfsRelyingPartyTrust `
        -Name $TrustName `
        -Identifier $Realm `
        -WSFedEndpoint "$SharePointUrl/_trust/" `
        -IssuanceTransformRules $claimRules `
        -Notes "SharePoint Subscription Edition WS-Federation Trust"
    
    Write-Host "Relying party trust created successfully!" -ForegroundColor Green
    
    # Display ADFS URLs for SharePoint configuration
    $adfsHost = (Get-AdfsProperties).HostName
    Write-Host ""
    Write-Host "=== ADFS Configuration Complete ===" -ForegroundColor Green
    Write-Host "Use the following values for SharePoint configuration:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Sign-In URL:  https://$adfsHost/adfs/ls/" -ForegroundColor Cyan
    Write-Host "Sign-Out URL: https://$adfsHost/adfs/ls/?wa=wsignout1.0" -ForegroundColor Cyan
    Write-Host "Realm:        $Realm" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
