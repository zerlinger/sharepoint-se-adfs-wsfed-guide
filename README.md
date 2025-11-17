# SharePoint Subscription Edition with ADFS using WS-Federation

A comprehensive guide for configuring Microsoft SharePoint Subscription Edition with Active Directory Federation Services (ADFS) using WS-Federation authentication.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Overview](#overview)
- [Part 1: ADFS Configuration](#part-1-adfs-configuration)
- [Part 2: SharePoint Configuration](#part-2-sharepoint-configuration)
- [Part 3: User Mapping](#part-3-user-mapping)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [References](#references)

## Prerequisites

Before starting, ensure you have:

- **SharePoint Subscription Edition** installed and configured
- **ADFS 4.0 or later** (Windows Server 2016/2019/2022)
- **Active Directory** domain environment
- Administrative access to both SharePoint and ADFS servers
- SSL certificates for HTTPS communication
- Service accounts with appropriate permissions

### Required Permissions
- **SharePoint**: Farm Administrator
- **ADFS**: ADFS Administrator or Domain Administrator
- **PowerShell**: Run as Administrator on both servers

## Overview

WS-Federation (Web Services Federation) is a protocol that enables single sign-on (SSO) between SharePoint and ADFS. This guide covers the configuration of:

1. ADFS as the identity provider (IdP)
2. SharePoint as the relying party (service provider)
3. Trust relationship between SharePoint and ADFS

### Architecture

```
User Browser <---> SharePoint Farm <---> ADFS Server <---> Active Directory
```

## Part 1: ADFS Configuration

### Step 1: Export ADFS Token-Signing Certificate

On the ADFS server, open PowerShell as Administrator and export the token-signing certificate:

```powershell
# Get the token-signing certificate
$cert = Get-AdfsCertificate -CertificateType Token-Signing

# Export the certificate
$certBytes = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes("C:\Temp\ADFS-Token-Signing.cer", $certBytes)
```

Copy the exported certificate (`ADFS-Token-Signing.cer`) to your SharePoint server.

### Step 2: Configure Relying Party Trust in ADFS

Create a relying party trust for SharePoint:

```powershell
# Define SharePoint URLs
$spWebAppUrl = "https://sharepoint.contoso.com"
$spRealm = "urn:sharepoint:contoso"

# Create the relying party trust
Add-AdfsRelyingPartyTrust `
    -Name "SharePoint Subscription Edition" `
    -Identifier $spRealm `
    -WSFedEndpoint "$spWebAppUrl/_trust/" `
    -IssuanceTransformRulesFile "C:\Temp\ClaimRules.txt"
```

### Step 3: Create Claim Rules

Create a file `C:\Temp\ClaimRules.txt` with the following claim rules:

```
@RuleName = "Send LDAP Attributes"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"), query = ";mail,userPrincipalName;{0}", param = c.Value);

@RuleName = "Send UPN as Name ID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);

@RuleName = "Send Role Claim"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxxxxxxxxx-xxxxxxxxxx-xxxxxxxxxx-xxxx", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Administrators");
```

**Note**: Update the Group SID in the Role Claim rule with your actual AD group SID.

Alternatively, configure claim rules using the ADFS Management Console:

1. Open **ADFS Management**
2. Navigate to **Relying Party Trusts**
3. Right-click the SharePoint relying party trust
4. Select **Edit Claim Issuance Policy**
5. Add the rules as described above

### Step 4: Get ADFS Endpoint URLs

Note the following ADFS URLs for SharePoint configuration:

```powershell
# Get ADFS hostname
$adfsHost = (Get-AdfsProperties).HostName

# Sign-in URL
$signInUrl = "https://$adfsHost/adfs/ls/"

# Sign-out URL  
$signOutUrl = "https://$adfsHost/adfs/ls/?wa=wsignout1.0"

Write-Host "Sign-In URL: $signInUrl"
Write-Host "Sign-Out URL: $signOutUrl"
```

## Part 2: SharePoint Configuration

### Step 1: Import ADFS Certificate to SharePoint

On the SharePoint server, open **SharePoint Management Shell** as Administrator:

```powershell
# Import the ADFS token-signing certificate
$certPath = "C:\Temp\ADFS-Token-Signing.cer"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
New-SPTrustedRootAuthority -Name "ADFS Token Signing" -Certificate $cert
```

### Step 2: Create Claim Mappings

Define how ADFS claims map to SharePoint claims:

```powershell
# Email claim mapping
$emailClaimMap = New-SPClaimTypeMapping `
    -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" `
    -IncomingClaimTypeDisplayName "EmailAddress" `
    -SameAsIncoming

# UPN claim mapping
$upnClaimMap = New-SPClaimTypeMapping `
    -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn" `
    -IncomingClaimTypeDisplayName "UPN" `
    -SameAsIncoming

# Role claim mapping (optional)
$roleClaimMap = New-SPClaimTypeMapping `
    -IncomingClaimType "http://schemas.microsoft.com/ws/2008/06/identity/claims/role" `
    -IncomingClaimTypeDisplayName "Role" `
    -SameAsIncoming
```

### Step 3: Create SPTrustedIdentityTokenIssuer

Create the trust relationship between SharePoint and ADFS:

```powershell
# Define ADFS URLs (from Part 1, Step 4)
$signInUrl = "https://adfs.contoso.com/adfs/ls/"
$signOutUrl = "https://adfs.contoso.com/adfs/ls/?wa=wsignout1.0"
$realm = "urn:sharepoint:contoso"

# Import certificate
$certPath = "C:\Temp\ADFS-Token-Signing.cer"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)

# Create trusted identity token issuer
$ap = New-SPTrustedIdentityTokenIssuer `
    -Name "ADFS Provider" `
    -Description "ADFS Authentication Provider" `
    -Realm $realm `
    -ImportTrustCertificate $cert `
    -ClaimsMappings $emailClaimMap, $upnClaimMap, $roleClaimMap `
    -SignInUrl $signInUrl `
    -IdentifierClaim $emailClaimMap.InputClaimType
```

**Note**: The `-IdentifierClaim` must match the claim type used to uniquely identify users (typically email or UPN).

### Step 4: Configure Web Application

Enable the ADFS authentication provider for your SharePoint web application:

```powershell
# Get the web application
$webApp = Get-SPWebApplication "https://sharepoint.contoso.com"

# Get the ADFS provider
$provider = Get-SPTrustedIdentityTokenIssuer "ADFS Provider"

# Enable the provider on the web application
$webApp.UseClaimsAuthentication = $true
$webApp.Update()

# Set authentication provider
Set-SPWebApplication -Identity $webApp -Zone Default -AuthenticationProvider $provider -SignInRedirectURL ""
```

Alternatively, configure via Central Administration:

1. Open **Central Administration**
2. Navigate to **Application Management > Manage web applications**
3. Select your web application
4. Click **Authentication Providers** in the ribbon
5. Click the zone (e.g., **Default**)
6. Under **Claims Authentication Types**, select **Trusted Identity provider**
7. Check **ADFS Provider**
8. Click **Save**

### Step 5: Configure Web.config (If Needed)

In some cases, you may need to update the web.config file for the SharePoint web application to adjust timeout values:

```xml
<system.identityModel>
  <identityConfiguration>
    <securityTokenHandlers>
      <securityTokenHandlerConfiguration>
        <certificateValidation certificateValidationMode="None" />
        <issuerNameRegistry type="Microsoft.SharePoint.IdentityModel.SPIssuerNameRegistry, Microsoft.SharePoint.IdentityModel, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c" />
      </securityTokenHandlerConfiguration>
    </securityTokenHandlers>
  </identityConfiguration>
</system.identityModel>
```

## Part 3: User Mapping

### People Picker Configuration

For proper user resolution, configure the People Picker to search Active Directory:

```powershell
# Set People Picker to use AD
$webApp = Get-SPWebApplication "https://sharepoint.contoso.com"
$provider = Get-SPTrustedIdentityTokenIssuer "ADFS Provider"

# Configure People Picker
$sts = Get-SPSecurityTokenServiceConfig
$sts.WindowsTokenLifetime = (New-TimeSpan -minutes 720)
$sts.Update()

# Set up People Picker for the provider
$provider.UseWReplyParameter = $true
$provider.Update()
```

### User Profile Service Configuration

Ensure the User Profile Service is configured to synchronize with Active Directory:

1. Open **Central Administration**
2. Navigate to **Application Management > Manage service applications**
3. Click **User Profile Service Application**
4. Configure **Synchronization Connections** to your Active Directory

## Verification

### Step 1: Test Authentication

1. Open a web browser
2. Navigate to your SharePoint site (e.g., `https://sharepoint.contoso.com`)
3. You should be redirected to the ADFS sign-in page
4. Enter your domain credentials
5. Upon successful authentication, you should be redirected back to SharePoint

### Step 2: Verify Claims

Create a simple web part or page to display user claims:

```powershell
# Check current user claims
$web = Get-SPWeb "https://sharepoint.contoso.com"
$user = $web.CurrentUser
Write-Host "User Login Name: $($user.LoginName)"
Write-Host "User Display Name: $($user.Name)"
Write-Host "User Email: $($user.Email)"
$web.Dispose()
```

### Step 3: Check ULS Logs

Monitor SharePoint ULS logs for authentication-related events:

```powershell
# View recent authentication logs
Get-SPLogEvent | Where-Object {$_.Area -eq "SharePoint Foundation" -and $_.Category -eq "Claims Authentication"} | Select-Object -First 20 | Format-Table Timestamp, Level, Message -AutoSize
```

## Troubleshooting

### Common Issues

#### 1. "The server was unable to process the request due to an internal error"

**Cause**: Certificate mismatch or trust issue.

**Solution**:
- Verify the ADFS certificate is imported correctly in SharePoint
- Ensure the certificate hasn't expired
- Check that the certificate matches between ADFS and SharePoint

```powershell
# Verify certificate
Get-SPTrustedRootAuthority | Where-Object {$_.Name -eq "ADFS Token Signing"}
```

#### 2. "User cannot be found"

**Cause**: User mapping or People Picker configuration issue.

**Solution**:
- Verify the IdentifierClaim in SPTrustedIdentityTokenIssuer
- Ensure claim values match between ADFS and SharePoint
- Check People Picker configuration

```powershell
# Check trusted identity token issuer
Get-SPTrustedIdentityTokenIssuer | Select-Object Name, IdentifierClaim, ClaimsMappings
```

#### 3. Redirect Loop

**Cause**: Incorrect realm or sign-in URL configuration.

**Solution**:
- Verify the realm matches between ADFS and SharePoint
- Check the WSFedEndpoint in ADFS matches SharePoint's /_trust/ endpoint
- Ensure UseWReplyParameter is set correctly

```powershell
# Check and update realm
$ap = Get-SPTrustedIdentityTokenIssuer "ADFS Provider"
$ap.ProviderRealms
$ap.UseWReplyParameter = $true
$ap.Update()
```

#### 4. Token Lifetime Issues

**Cause**: Token expiration settings mismatch.

**Solution**:
- Adjust token lifetime in SharePoint

```powershell
$sts = Get-SPSecurityTokenServiceConfig
$sts.WindowsTokenLifetime = (New-TimeSpan -minutes 720)
$sts.FormsTokenLifetime = (New-TimeSpan -minutes 720)
$sts.Update()
```

### Enable Verbose Logging

For detailed troubleshooting, enable verbose logging:

```powershell
# Enable verbose logging for authentication
Set-SPLogLevel -TraceSeverity VerboseEx -IdentityName "SharePoint Foundation"
Set-SPLogLevel -TraceSeverity VerboseEx -IdentityName "Claims Authentication"

# View logs
Get-SPLogEvent -StartTime (Get-Date).AddMinutes(-30) | Where-Object {$_.Category -eq "Claims Authentication"} | Format-Table Timestamp, Level, Message -AutoSize

# Reset to default after troubleshooting
Clear-SPLogLevel
```

## Best Practices

### Security Recommendations

1. **Use HTTPS**: Always use SSL/TLS for all communication between browsers, SharePoint, and ADFS
2. **Certificate Management**: Monitor certificate expiration dates and renew before expiry
3. **Token Lifetime**: Set appropriate token lifetime values (typically 720 minutes)
4. **Claim Rules**: Only send necessary claims to minimize token size
5. **Access Control**: Use AD groups for authorization and send group claims if needed

### Performance Optimization

1. **Token Caching**: SharePoint caches security tokens to reduce ADFS load
2. **Connection Pooling**: Ensure proper network configuration between SharePoint and ADFS
3. **Load Balancing**: Use load balancers for both SharePoint and ADFS in production

### High Availability

1. **ADFS Farm**: Deploy ADFS in a farm configuration with multiple servers
2. **SharePoint Farm**: Use MinRole topology for optimal performance
3. **Database**: Use SQL Server AlwaysOn for high availability
4. **Monitoring**: Implement monitoring for both SharePoint and ADFS services

### Maintenance

1. **Regular Updates**: Keep SharePoint and ADFS up to date with latest patches
2. **Certificate Renewal**: Plan certificate renewals and updates
3. **Backup**: Regular backups of SharePoint configuration database
4. **Documentation**: Maintain documentation of your specific configuration

## References

### Microsoft Documentation

- [SharePoint Server authentication](https://docs.microsoft.com/sharepoint/security-for-sharepoint-server/authentication-overview)
- [Plan for user authentication methods in SharePoint Server](https://docs.microsoft.com/sharepoint/security-for-sharepoint-server/plan-user-authentication)
- [Active Directory Federation Services](https://docs.microsoft.com/windows-server/identity/active-directory-federation-services)
- [Configure SAML-based claims authentication with ADFS in SharePoint](https://docs.microsoft.com/sharepoint/security-for-sharepoint-server/configure-saml-based-claims-authentication-with-adfs-in-sharepoint)

### PowerShell Cmdlets

- [SharePoint PowerShell Cmdlets](https://docs.microsoft.com/powershell/sharepoint/)
- [ADFS PowerShell Cmdlets](https://docs.microsoft.com/powershell/module/adfs/)

### Additional Resources

- [Claims-based identity in SharePoint](https://docs.microsoft.com/sharepoint/dev/general-development/claims-based-identity-in-sharepoint)
- [WS-Federation Protocol](https://docs.oasis-open.org/wsfed/federation/v1.2/os/ws-federation-1.2-spec-os.html)

## Support and Contributing

For issues, questions, or contributions, please:
- Review the troubleshooting section above
- Check Microsoft documentation and support resources
- Consult with your organization's SharePoint administrator

## License

This guide is provided as-is under the MIT License. See [LICENSE](LICENSE) file for details.
