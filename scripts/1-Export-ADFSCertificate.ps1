# Export ADFS Token-Signing Certificate
# Run this script on the ADFS server as Administrator

<#
.SYNOPSIS
    Exports the ADFS token-signing certificate for use in SharePoint configuration.

.DESCRIPTION
    This script exports the ADFS token-signing certificate to a file that can be
    imported into SharePoint to establish trust.

.PARAMETER OutputPath
    The path where the certificate file will be saved.

.EXAMPLE
    .\1-Export-ADFSCertificate.ps1 -OutputPath "C:\Temp\ADFS-Token-Signing.cer"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\Temp\ADFS-Token-Signing.cer"
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

try {
    Write-Host "Retrieving ADFS token-signing certificate..." -ForegroundColor Cyan
    
    # Get the token-signing certificate
    $cert = Get-AdfsCertificate -CertificateType Token-Signing
    
    if ($null -eq $cert) {
        Write-Error "Failed to retrieve ADFS token-signing certificate."
        exit 1
    }
    
    # Display certificate information
    Write-Host "Certificate Subject: $($cert.Certificate.Subject)" -ForegroundColor Green
    Write-Host "Certificate Thumbprint: $($cert.Certificate.Thumbprint)" -ForegroundColor Green
    Write-Host "Certificate Expiration: $($cert.Certificate.NotAfter)" -ForegroundColor Green
    
    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Export the certificate
    Write-Host "Exporting certificate to $OutputPath..." -ForegroundColor Cyan
    $certBytes = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    [System.IO.File]::WriteAllBytes($OutputPath, $certBytes)
    
    Write-Host "Certificate exported successfully!" -ForegroundColor Green
    Write-Host "Please copy this file to your SharePoint server." -ForegroundColor Yellow
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
