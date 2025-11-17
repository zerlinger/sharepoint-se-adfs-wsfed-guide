# Quick Start Guide

This quick start guide provides a streamlined process for configuring SharePoint Subscription Edition with ADFS using WS-Federation.

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] SharePoint Subscription Edition farm installed
- [ ] ADFS 4.0 or later configured
- [ ] Active Directory environment
- [ ] SSL certificates installed
- [ ] Administrator access to both servers
- [ ] Network connectivity between SharePoint and ADFS

## Configuration Steps

### Step 1: Prepare Your Environment

Define your configuration parameters:

```powershell
# Environment Variables
$SharePointUrl = "https://sharepoint.contoso.com"
$ADFSUrl = "https://adfs.contoso.com"
$Realm = "urn:sharepoint:contoso"
$CertPath = "C:\Temp\ADFS-Token-Signing.cer"
```

### Step 2: ADFS Server Configuration (15-20 minutes)

On the **ADFS server**, run PowerShell as Administrator:

#### Export Certificate

```powershell
# Get and export token-signing certificate
$cert = Get-AdfsCertificate -CertificateType Token-Signing
$certBytes = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes("C:\Temp\ADFS-Token-Signing.cer", $certBytes)
```

#### Create Relying Party Trust

```powershell
# Define claim rules
$claimRules = @"
@RuleName = "Send LDAP Attributes"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"), query = ";mail,userPrincipalName;{0}", param = c.Value);

@RuleName = "Send UPN as Name ID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);
"@

# Create relying party trust
Add-AdfsRelyingPartyTrust `
    -Name "SharePoint Subscription Edition" `
    -Identifier "urn:sharepoint:contoso" `
    -WSFedEndpoint "https://sharepoint.contoso.com/_trust/" `
    -IssuanceTransformRules $claimRules
```

#### Get ADFS URLs

```powershell
# Display URLs for SharePoint configuration
$adfsHost = (Get-AdfsProperties).HostName
Write-Host "Sign-In URL: https://$adfsHost/adfs/ls/"
Write-Host "Sign-Out URL: https://$adfsHost/adfs/ls/?wa=wsignout1.0"
```

**Copy the certificate file to your SharePoint server.**

### Step 3: SharePoint Server Configuration (10-15 minutes)

On the **SharePoint server**, open SharePoint Management Shell as Administrator:

#### Import Certificate and Create Trust

```powershell
# Import certificate
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("C:\Temp\ADFS-Token-Signing.cer")
New-SPTrustedRootAuthority -Name "ADFS Token Signing" -Certificate $cert

# Create claim mappings
$emailClaimMap = New-SPClaimTypeMapping `
    -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" `
    -IncomingClaimTypeDisplayName "EmailAddress" `
    -SameAsIncoming

$upnClaimMap = New-SPClaimTypeMapping `
    -IncomingClaimType "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn" `
    -IncomingClaimTypeDisplayName "UPN" `
    -SameAsIncoming

# Create trusted identity token issuer
$ap = New-SPTrustedIdentityTokenIssuer `
    -Name "ADFS Provider" `
    -Description "ADFS Authentication Provider" `
    -Realm "urn:sharepoint:contoso" `
    -ImportTrustCertificate $cert `
    -ClaimsMappings $emailClaimMap, $upnClaimMap `
    -SignInUrl "https://adfs.contoso.com/adfs/ls/" `
    -IdentifierClaim $emailClaimMap.InputClaimType

# Enable UseWReplyParameter
$ap.UseWReplyParameter = $true
$ap.Update()
```

#### Enable on Web Application

```powershell
# Get web application and provider
$webApp = Get-SPWebApplication "https://sharepoint.contoso.com"
$provider = Get-SPTrustedIdentityTokenIssuer "ADFS Provider"

# Enable claims authentication
$webApp.UseClaimsAuthentication = $true
$webApp.Update()

# Configure authentication provider
$authProvider = New-SPAuthenticationProvider -TrustedIdentityTokenIssuer $provider
Set-SPWebApplication -Identity $webApp -Zone Default -AuthenticationProvider $authProvider -SignInRedirectURL ""
```

### Step 4: Verification (5 minutes)

1. Open a **private/incognito browser window**
2. Navigate to: `https://sharepoint.contoso.com`
3. You should be redirected to ADFS login page
4. Enter your domain credentials
5. Upon successful authentication, you'll be redirected to SharePoint

### Step 5: Grant Permissions (Optional)

Add users to SharePoint:

```powershell
# Add a user as site collection administrator
$web = Get-SPWeb "https://sharepoint.contoso.com"
$user = $web.EnsureUser("i:05.t|adfs provider|user@contoso.com")
$web.Site.RootWeb.SiteAdministrators.Add($user)
$web.Dispose()
```

## Troubleshooting Quick Checks

### Check Trust Configuration

```powershell
# On SharePoint
Get-SPTrustedIdentityTokenIssuer | Select-Object Name, SignInUrl, IdentifierClaim
Get-SPTrustedRootAuthority | Where-Object {$_.Name -like "*ADFS*"}
```

### Check Web Application Configuration

```powershell
# On SharePoint
$webApp = Get-SPWebApplication "https://sharepoint.contoso.com"
$webApp.IisSettings["Default"].ClaimsAuthenticationProviders
```

### Check ADFS Relying Party

```powershell
# On ADFS
Get-AdfsRelyingPartyTrust -Name "SharePoint Subscription Edition" | Select-Object Name, Identifier, WSFedEndpoint
```

### View SharePoint Logs

```powershell
# On SharePoint
Get-SPLogEvent -StartTime (Get-Date).AddMinutes(-10) | 
    Where-Object {$_.Category -eq "Claims Authentication"} | 
    Select-Object Timestamp, Level, Message
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Certificate error | Verify certificate is imported correctly: `Get-SPTrustedRootAuthority` |
| Redirect loop | Ensure realm matches between ADFS and SharePoint |
| User not found | Check IdentifierClaim and ensure it matches user attribute |
| Access denied | Grant user permissions using site collection admin tools |

## Using the Automated Scripts

Instead of manual configuration, you can use the provided scripts:

```powershell
# On ADFS Server
.\scripts\1-Export-ADFSCertificate.ps1
.\scripts\2-Configure-ADFSRelyingPartyTrust.ps1 -SharePointUrl "https://sharepoint.contoso.com" -Realm "urn:sharepoint:contoso"

# On SharePoint Server  
.\scripts\3-Configure-SharePointTrust.ps1 -CertificatePath "C:\Temp\ADFS-Token-Signing.cer" -SignInUrl "https://adfs.contoso.com/adfs/ls/" -SignOutUrl "https://adfs.contoso.com/adfs/ls/?wa=wsignout1.0" -Realm "urn:sharepoint:contoso"
.\scripts\4-Enable-WebAppAuthentication.ps1 -WebApplicationUrl "https://sharepoint.contoso.com"
```

## Next Steps

After successful configuration:

1. Configure People Picker for user resolution
2. Set up User Profile Service synchronization
3. Configure additional claim rules if needed
4. Test with multiple user accounts
5. Document your specific configuration

## Support

For detailed information, see the complete [README.md](../README.md) guide.
