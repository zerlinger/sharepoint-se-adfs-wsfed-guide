# PowerShell Scripts for SharePoint-ADFS Configuration

This directory contains PowerShell scripts to automate the configuration of Microsoft SharePoint Subscription Edition with ADFS using WS-Federation.

## Scripts Overview

Execute these scripts in order:

### 1. Export-ADFSCertificate.ps1
**Location:** ADFS Server  
**Purpose:** Exports the ADFS token-signing certificate

```powershell
.\1-Export-ADFSCertificate.ps1 -OutputPath "C:\Temp\ADFS-Token-Signing.cer"
```

### 2. Configure-ADFSRelyingPartyTrust.ps1
**Location:** ADFS Server  
**Purpose:** Creates and configures the relying party trust in ADFS

```powershell
.\2-Configure-ADFSRelyingPartyTrust.ps1 `
    -SharePointUrl "https://sharepoint.contoso.com" `
    -Realm "urn:sharepoint:contoso" `
    -TrustName "SharePoint Subscription Edition"
```

### 3. Configure-SharePointTrust.ps1
**Location:** SharePoint Server  
**Purpose:** Imports ADFS certificate and creates trusted identity token issuer

```powershell
.\3-Configure-SharePointTrust.ps1 `
    -CertificatePath "C:\Temp\ADFS-Token-Signing.cer" `
    -SignInUrl "https://adfs.contoso.com/adfs/ls/" `
    -SignOutUrl "https://adfs.contoso.com/adfs/ls/?wa=wsignout1.0" `
    -Realm "urn:sharepoint:contoso" `
    -ProviderName "ADFS Provider" `
    -IdentifierClaimType "email"
```

### 4. Enable-WebAppAuthentication.ps1
**Location:** SharePoint Server  
**Purpose:** Enables ADFS authentication on the SharePoint web application

```powershell
.\4-Enable-WebAppAuthentication.ps1 `
    -WebApplicationUrl "https://sharepoint.contoso.com" `
    -ProviderName "ADFS Provider" `
    -Zone "Default"
```

## Prerequisites

- Run all scripts with Administrator privileges
- ADFS scripts require the ADFS PowerShell module
- SharePoint scripts require SharePoint Management Shell
- Ensure proper network connectivity between servers

## Important Notes

- **Replace placeholder values** (contoso.com, etc.) with your actual environment values
- **Test in a development environment** before running in production
- **Backup your configuration** before making changes
- **Review each script** to understand what it does before execution

## Customization

Each script accepts parameters for customization. Use `Get-Help .\<ScriptName>.ps1 -Detailed` to see all available parameters and examples.

## Troubleshooting

If a script fails:
1. Check that you have appropriate permissions
2. Verify all required modules are loaded
3. Review the error message and script output
4. Consult the main README.md troubleshooting section

## Support

For detailed configuration instructions, troubleshooting, and best practices, refer to the main [README.md](../README.md) in the root directory.
