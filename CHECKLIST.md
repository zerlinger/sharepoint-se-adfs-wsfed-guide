# Configuration Checklist

Use this checklist to track your progress when configuring SharePoint Subscription Edition with ADFS using WS-Federation.

## Pre-Configuration Phase

### Environment Preparation
- [ ] SharePoint Subscription Edition farm installed and operational
- [ ] ADFS 4.0 or later installed and configured
- [ ] Active Directory domain environment accessible
- [ ] SSL certificates installed on both SharePoint and ADFS servers
- [ ] Valid DNS records configured for both servers
- [ ] Network connectivity verified between servers

### Permissions and Access
- [ ] Administrator access to ADFS server
- [ ] Farm Administrator access to SharePoint
- [ ] Ability to run PowerShell as Administrator on both servers
- [ ] Access to Active Directory for group SID lookups (if using role claims)

### Information Gathering
- [ ] SharePoint web application URL: ___________________________
- [ ] ADFS server URL: ___________________________
- [ ] Realm identifier decided: ___________________________
- [ ] Identity claim type chosen (email or UPN): ___________________________
- [ ] Required claims identified: ___________________________

## ADFS Configuration Phase

### Certificate Export
- [ ] Connected to ADFS server
- [ ] Opened PowerShell as Administrator
- [ ] Verified ADFS service is running
- [ ] Retrieved token-signing certificate
- [ ] Exported certificate to file
- [ ] Verified certificate file created successfully
- [ ] Noted certificate expiration date: ___________________________
- [ ] Copied certificate file to SharePoint server

### Relying Party Trust Configuration
- [ ] Created claim rules file or documented rules
- [ ] Verified SharePoint URL is correct
- [ ] Verified realm identifier is correct
- [ ] Created relying party trust in ADFS
- [ ] Verified trust creation succeeded
- [ ] Noted Sign-In URL: ___________________________
- [ ] Noted Sign-Out URL: ___________________________
- [ ] Tested ADFS login page accessibility

### Claim Rules Verification
- [ ] Reviewed default claim rules
- [ ] Added email/UPN claim rules
- [ ] Added Name ID claim rule
- [ ] Added role claim rules (if applicable)
- [ ] Verified claim rules syntax
- [ ] Tested claim rules (using ADFS test page if available)

## SharePoint Configuration Phase

### Certificate Import
- [ ] Copied ADFS certificate to SharePoint server
- [ ] Opened SharePoint Management Shell as Administrator
- [ ] Imported certificate to SharePoint
- [ ] Created SPTrustedRootAuthority
- [ ] Verified certificate import with Get-SPTrustedRootAuthority

### Claim Mappings
- [ ] Created email claim mapping
- [ ] Created UPN claim mapping
- [ ] Created role claim mapping (if applicable)
- [ ] Created additional claim mappings (if needed)
- [ ] Verified all claim mappings created successfully

### Trusted Identity Token Issuer
- [ ] Prepared all required parameters (realm, sign-in URL, etc.)
- [ ] Created SPTrustedIdentityTokenIssuer
- [ ] Set UseWReplyParameter to true
- [ ] Updated token issuer configuration
- [ ] Verified creation with Get-SPTrustedIdentityTokenIssuer
- [ ] Provider name: ___________________________

### Web Application Configuration
- [ ] Identified target web application
- [ ] Enabled claims authentication on web application
- [ ] Created authentication provider
- [ ] Applied authentication provider to web application zone
- [ ] Verified configuration with Get-SPWebApplication

## Post-Configuration Phase

### Initial Testing
- [ ] Opened private/incognito browser window
- [ ] Navigated to SharePoint URL
- [ ] Verified redirect to ADFS
- [ ] Entered test user credentials
- [ ] Successfully authenticated
- [ ] Verified redirect back to SharePoint
- [ ] Confirmed user logged into SharePoint

### User Permissions
- [ ] Added test user as site collection administrator
- [ ] Verified user can access site
- [ ] Tested user permissions
- [ ] Documented user identifier format: ___________________________

### People Picker Configuration (Optional but Recommended)
- [ ] Configured People Picker settings
- [ ] Tested user search functionality
- [ ] Verified user resolution works correctly

### User Profile Service (Optional but Recommended)
- [ ] Configured User Profile Service Application
- [ ] Set up Active Directory synchronization
- [ ] Ran initial profile synchronization
- [ ] Verified user profiles created

## Verification Phase

### Authentication Flow Testing
- [ ] Tested login with multiple user accounts
- [ ] Verified claims are populated correctly
- [ ] Tested logout functionality
- [ ] Verified session timeout behavior
- [ ] Tested re-authentication after timeout

### SharePoint Functionality Testing
- [ ] Accessed site collections
- [ ] Created/edited content
- [ ] Tested search functionality
- [ ] Tested My Sites (if applicable)
- [ ] Verified all expected functionality works

### Log Review
- [ ] Reviewed SharePoint ULS logs for errors
- [ ] Reviewed ADFS event logs
- [ ] Reviewed Windows Event Logs on both servers
- [ ] Addressed any warning or error messages
- [ ] Documented any issues found: ___________________________

### Performance Testing
- [ ] Tested login performance
- [ ] Monitored ADFS server resource usage
- [ ] Monitored SharePoint server resource usage
- [ ] Verified acceptable response times

## Documentation Phase

### Configuration Documentation
- [ ] Documented SharePoint web application URL
- [ ] Documented ADFS server URL
- [ ] Documented realm identifier
- [ ] Documented certificate locations and expiration dates
- [ ] Documented claim mappings
- [ ] Documented provider name
- [ ] Documented any custom claim rules

### User Documentation
- [ ] Created user guide for login process
- [ ] Documented any differences from previous authentication
- [ ] Created troubleshooting guide for common user issues
- [ ] Communicated changes to users

### Admin Documentation
- [ ] Documented configuration steps taken
- [ ] Documented any deviations from standard process
- [ ] Documented custom scripts used
- [ ] Created runbook for common admin tasks
- [ ] Documented backup and recovery procedures

### Certificate Management
- [ ] Created certificate expiration calendar reminder
- [ ] Documented certificate renewal process
- [ ] Identified backup administrator for certificate renewal
- [ ] Documented certificate rollover procedure

## Maintenance Planning

### Regular Tasks
- [ ] Scheduled certificate expiration review
- [ ] Scheduled claim rules review
- [ ] Scheduled user access review
- [ ] Scheduled log review process
- [ ] Created monitoring alerts (if applicable)

### Backup and Recovery
- [ ] Backed up SharePoint configuration database
- [ ] Backed up ADFS configuration
- [ ] Documented recovery procedures
- [ ] Tested recovery procedures (if possible)

### Security Review
- [ ] Reviewed security best practices
- [ ] Implemented recommended security settings
- [ ] Scheduled regular security audits
- [ ] Documented security baseline

## Rollout Phase (Production)

### Pre-Rollout
- [ ] Tested in development environment
- [ ] Tested in staging/UAT environment
- [ ] Created rollback plan
- [ ] Identified maintenance window
- [ ] Notified users of upcoming changes
- [ ] Prepared support team

### During Rollout
- [ ] Executed configuration steps
- [ ] Performed initial verification
- [ ] Monitored for issues
- [ ] Documented any problems encountered

### Post-Rollout
- [ ] Verified all users can authenticate
- [ ] Monitored help desk tickets
- [ ] Addressed any reported issues
- [ ] Collected user feedback
- [ ] Performed post-rollout review

## Sign-Off

### Technical Sign-Off
- [ ] SharePoint Administrator: _________________ Date: _________
- [ ] ADFS Administrator: _________________ Date: _________
- [ ] Network Administrator: _________________ Date: _________
- [ ] Security Team: _________________ Date: _________

### Business Sign-Off
- [ ] Business Owner: _________________ Date: _________
- [ ] Project Manager: _________________ Date: _________

## Notes

Use this section to document any additional information, issues encountered, or customizations made:

_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________

## Appendix: Quick Reference

### Key PowerShell Commands

```powershell
# Check ADFS certificate
Get-AdfsCertificate -CertificateType Token-Signing

# Check relying party trust
Get-AdfsRelyingPartyTrust -Name "SharePoint Subscription Edition"

# Check SharePoint trust
Get-SPTrustedIdentityTokenIssuer

# Check trusted root authority
Get-SPTrustedRootAuthority

# Check web application authentication
$webApp = Get-SPWebApplication "https://sharepoint.contoso.com"
$webApp.IisSettings["Default"].ClaimsAuthenticationProviders
```

### Important URLs

- SharePoint Central Administration: ___________________________
- SharePoint Web Application: ___________________________
- ADFS Login Page: ___________________________
- ADFS Management Console: ___________________________

### Support Contacts

- SharePoint Admin: ___________________________
- ADFS Admin: ___________________________
- Network Admin: ___________________________
- Help Desk: ___________________________
