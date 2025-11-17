# Example ADFS Claim Rules for SharePoint

This file contains example claim rules for different scenarios when configuring ADFS for SharePoint Subscription Edition.

## Basic Claim Rules

### Send Email and UPN from Active Directory

```
@RuleName = "Send LDAP Attributes"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"), query = ";mail,userPrincipalName;{0}", param = c.Value);
```

### Send UPN as Name Identifier

```
@RuleName = "Send UPN as Name ID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);
```

## Role-Based Claims

### Send Role Based on AD Group Membership

```
@RuleName = "Send Administrator Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-1234567890-1234567890-1234567890-1234", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Administrators");
```

Replace the SID with your actual group SID. To get the SID:

```powershell
# Get the SID of an AD group
Get-ADGroup -Identity "SharePoint Administrators" | Select-Object SID
```

### Send Multiple Roles

```
@RuleName = "Send Administrator Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxx-xxx-xxx-1001", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Administrators");

@RuleName = "Send Contributor Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxx-xxx-xxx-1002", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Contributors");

@RuleName = "Send Reader Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxx-xxx-xxx-1003", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Readers");
```

## Advanced Claims

### Send Display Name

```
@RuleName = "Send Display Name"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"), query = ";givenName,sn;{0}", param = c.Value);
```

### Send Department

```
@RuleName = "Send Department"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/claims/Department"), query = ";department;{0}", param = c.Value);
```

### Send Employee ID

```
@RuleName = "Send Employee ID"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/claims/EmployeeID"), query = ";employeeID;{0}", param = c.Value);
```

## Transform Claims

### Transform UPN to Email

```
@RuleName = "Transform UPN to Email"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", Value = c.Value);
```

### Add Domain to Username

```
@RuleName = "Add Domain to Username"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn", Value = c.Value + "@contoso.com");
```

## Complete Example Configuration

Here's a complete example with multiple claim rules:

```
@RuleName = "Send LDAP Attributes"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
=> issue(store = "Active Directory", types = ("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"), query = ";mail,userPrincipalName,givenName,sn;{0}", param = c.Value);

@RuleName = "Send UPN as Name ID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
=> issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);

@RuleName = "Send SharePoint Admin Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxx-xxx-xxx-1001", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "SPAdministrators");

@RuleName = "Send Site Collection Admin Role"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "S-1-5-21-xxx-xxx-xxx-1002", Issuer == "AD AUTHORITY"]
=> issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "SiteCollectionAdmins");
```

## Applying Claim Rules

### Using PowerShell

Save your claim rules to a text file (e.g., `ClaimRules.txt`), then apply them:

```powershell
$claimRulesFile = "C:\Temp\ClaimRules.txt"
$claimRules = Get-Content $claimRulesFile -Raw

Set-AdfsRelyingPartyTrust `
    -TargetName "SharePoint Subscription Edition" `
    -IssuanceTransformRules $claimRules
```

### Using ADFS Management Console

1. Open **ADFS Management**
2. Navigate to **Trust Relationships > Relying Party Trusts**
3. Right-click the SharePoint relying party trust
4. Select **Edit Claim Issuance Policy**
5. Add rules manually using the wizard or custom rule language

## Troubleshooting Claim Rules

### View Current Claim Rules

```powershell
$trust = Get-AdfsRelyingPartyTrust -Name "SharePoint Subscription Edition"
$trust.IssuanceTransformRules
```

### Test Claims

Use the ADFS test claim functionality:

```powershell
# Enable test endpoint
Set-AdfsProperties -EnableIdpInitiatedSignonPage $true
```

Then navigate to: `https://adfs.contoso.com/adfs/ls/idpinitiatedsignon.aspx`

## Best Practices

1. **Send only necessary claims** - Minimize token size by only including required claims
2. **Use specific group SIDs** - Don't use well-known SIDs that could cause security issues
3. **Test claim rules** - Always test in a dev environment before production
4. **Document custom claims** - Keep a record of any custom claim types you create
5. **Review regularly** - Audit claim rules periodically for security and accuracy

## References

- [ADFS Claim Rule Language](https://docs.microsoft.com/windows-server/identity/ad-fs/technical-reference/the-role-of-the-claim-rule-language)
- [Understanding Claims](https://docs.microsoft.com/windows-server/identity/ad-fs/technical-reference/understanding-claims)
