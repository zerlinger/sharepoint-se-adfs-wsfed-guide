# Configure SharePoint Trust with ADFS
# Run this script on the SharePoint server using SharePoint Management Shell as Administrator

<#
.SYNOPSIS
    Configures SharePoint Subscription Edition to trust ADFS for authentication.

.DESCRIPTION
    This script imports the ADFS certificate, creates claim mappings, and establishes
    a trusted identity token issuer in SharePoint.

.PARAMETER CertificatePath
    The path to the ADFS token-signing certificate file.

.PARAMETER SignInUrl
    The ADFS sign-in URL.

.PARAMETER SignOutUrl
    The ADFS sign-out URL.

.PARAMETER Realm
    The realm identifier (must match ADFS configuration).

.PARAMETER ProviderName
    The name for the authentication provider in SharePoint.

.PARAMETER IdentifierClaimType
    The claim type to use as the unique identifier (email or upn).

.EXAMPLE
    .\3-Configure-SharePointTrust.ps1 -CertificatePath "C:\Temp\ADFS-Token-Signing.cer" -SignInUrl "https://adfs.contoso.com/adfs/ls/" -SignOutUrl "https://adfs.contoso.com/adfs/ls/?wa=wsignout1.0" -Realm "urn:sharepoint:contoso" -ProviderName "ADFS Provider" -IdentifierClaimType "email"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CertificatePath,
    
    [Parameter(Mandatory=$true)]
    [string]$SignInUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SignOutUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$Realm,
    
    [Parameter(Mandatory=$false)]
    [string]$ProviderName = "ADFS Provider",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("email", "upn")]
    [string]$IdentifierClaimType = "email"
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

# Verify certificate file exists
if (-not (Test-Path -Path $CertificatePath)) {
    Write-Error "Certificate file not found at: $CertificatePath"
    exit 1
}

try {
    Write-Host "Configuring SharePoint trust with ADFS..." -ForegroundColor Cyan
    
    # Import the ADFS token-signing certificate
    Write-Host "Importing ADFS certificate..." -ForegroundColor Cyan
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
    
    Write-Host "Certificate Subject: $($cert.Subject)" -ForegroundColor Green
    Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    Write-Host "Certificate Expiration: $($cert.NotAfter)" -ForegroundColor Green
    
    # Check if trusted root authority already exists
    $existingAuthority = Get-SPTrustedRootAuthority | Where-Object {$_.Certificate.Thumbprint -eq $cert.Thumbprint}
    if ($existingAuthority) {
        Write-Host "Certificate already imported as trusted root authority: $($existingAuthority.Name)" -ForegroundColor Yellow
    } else {
        New-SPTrustedRootAuthority -Name "ADFS Token Signing" -Certificate $cert
        Write-Host "Certificate imported successfully!" -ForegroundColor Green
    }
    
    # Create claim mappings
    Write-Host "Creating claim mappings..." -ForegroundColor Cyan
    
    $emailClaimMap = New-SPClaimTypeMapping `
        -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" `
        -IncomingClaimTypeDisplayName "EmailAddress" `
        -SameAsIncoming
    
    $upnClaimMap = New-SPClaimTypeMapping `
        -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn" `
        -IncomingClaimTypeDisplayName "UPN" `
        -SameAsIncoming
    
    $roleClaimMap = New-SPClaimTypeMapping `
        -IncomingClaimType "http://schemas.microsoft.com/ws/2008/06/identity/claims/role" `
        -IncomingClaimTypeDisplayName "Role" `
        -SameAsIncoming
    
    Write-Host "Claim mappings created." -ForegroundColor Green
    
    # Determine identifier claim
    if ($IdentifierClaimType -eq "email") {
        $identifierClaim = $emailClaimMap.InputClaimType
    } else {
        $identifierClaim = $upnClaimMap.InputClaimType
    }
    
    # Check if trusted identity token issuer already exists
    $existingProvider = Get-SPTrustedIdentityTokenIssuer -Identity $ProviderName -ErrorAction SilentlyContinue
    if ($existingProvider) {
        Write-Warning "A trusted identity token issuer with the name '$ProviderName' already exists."
        $response = Read-Host "Do you want to remove it and create a new one? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Remove-SPTrustedIdentityTokenIssuer -Identity $ProviderName -Confirm:$false
            Write-Host "Existing provider removed." -ForegroundColor Yellow
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Create trusted identity token issuer
    Write-Host "Creating trusted identity token issuer..." -ForegroundColor Cyan
    $ap = New-SPTrustedIdentityTokenIssuer `
        -Name $ProviderName `
        -Description "ADFS Authentication Provider for WS-Federation" `
        -Realm $Realm `
        -ImportTrustCertificate $cert `
        -ClaimsMappings $emailClaimMap, $upnClaimMap, $roleClaimMap `
        -SignInUrl $SignInUrl `
        -IdentifierClaim $identifierClaim
    
    # Configure additional properties
    $ap.UseWReplyParameter = $true
    $ap.Update()
    
    Write-Host ""
    Write-Host "=== SharePoint Trust Configuration Complete ===" -ForegroundColor Green
    Write-Host "Trusted identity token issuer '$ProviderName' created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Configure your web application to use the '$ProviderName' authentication provider" -ForegroundColor Yellow
    Write-Host "2. Use Central Administration or PowerShell to enable the provider on your web application" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Error "An error occurred: $_"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
