# Architecture Overview

This document provides a detailed explanation of the SharePoint-ADFS WS-Federation architecture and authentication flow.

## High-Level Architecture

```
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │
         │ 1. Request Resource
         ▼
┌─────────────────────────────┐
│  SharePoint Web Application │
│  (Relying Party/SP)         │
└────────┬────────────────────┘
         │
         │ 2. Redirect to ADFS (if not authenticated)
         ▼
┌─────────────────────────────┐
│      ADFS Server            │
│   (Identity Provider/IdP)   │
└────────┬────────────────────┘
         │
         │ 3. Authenticate User
         ▼
┌─────────────────────────────┐
│   Active Directory          │
│   (User Store)              │
└─────────────────────────────┘
```

## Components

### 1. User Browser
- Initiates requests to SharePoint
- Receives and processes redirects
- Submits credentials to ADFS
- Holds authentication cookies/tokens

### 2. SharePoint Farm (Relying Party)
- **Web Application**: The application users access
- **Security Token Service (STS)**: Validates tokens from ADFS
- **Trusted Identity Token Issuer**: Configuration that establishes trust with ADFS
- **Claims Provider**: Processes claims from ADFS tokens

### 3. ADFS Server (Identity Provider)
- **Federation Service**: Core ADFS authentication engine
- **Token Signing Certificate**: Signs security tokens
- **Relying Party Trust**: Configuration for SharePoint
- **Claim Rules**: Transform AD attributes to claims

### 4. Active Directory
- User account repository
- Provides user attributes
- Validates credentials

## Authentication Flow (WS-Federation Passive Protocol)

### Initial Request (Unauthenticated User)

```
1. User → SharePoint: GET https://sharepoint.contoso.com/

2. SharePoint: Checks for authentication token
   - No valid token found
   
3. SharePoint → User: HTTP 302 Redirect to ADFS
   Location: https://adfs.contoso.com/adfs/ls/?
             wa=wsignin1.0&
             wtrealm=urn:sharepoint:contoso&
             wctx=contextinfo&
             wreply=https://sharepoint.contoso.com/_trust/

4. User → ADFS: GET (follows redirect)

5. ADFS: Displays login page

6. User → ADFS: POST credentials

7. ADFS → AD: Validates credentials

8. AD → ADFS: Validation result

9. ADFS: 
   - Creates security token
   - Applies claim rules
   - Signs token with certificate
   
10. ADFS → User: HTTP 302 Redirect to SharePoint
    Location: https://sharepoint.contoso.com/_trust/
    POST data: Security token (SAML)

11. User → SharePoint: POST token to /_trust/ endpoint

12. SharePoint:
    - Validates token signature using ADFS certificate
    - Extracts claims from token
    - Creates SharePoint claims identity
    - Establishes session
    
13. SharePoint → User: HTTP 302 Redirect to original URL
    Set-Cookie: FedAuth=..., rtFa=...

14. User → SharePoint: GET original URL with cookies

15. SharePoint → User: HTTP 200 OK (requested page)
```

### Subsequent Requests (Authenticated User)

```
1. User → SharePoint: GET https://sharepoint.contoso.com/page
   Cookie: FedAuth=..., rtFa=...

2. SharePoint:
   - Validates FedAuth cookie
   - Retrieves claims from cookie
   - Authorizes request

3. SharePoint → User: HTTP 200 OK (page content)
```

## WS-Federation Protocol Parameters

### Sign-In Request Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `wa` | Action to perform | `wsignin1.0` |
| `wtrealm` | Realm identifier | `urn:sharepoint:contoso` |
| `wreply` | Return URL after authentication | `https://sharepoint.contoso.com/_trust/` |
| `wctx` | Context information | (opaque string) |
| `whr` | Home realm (optional) | `https://adfs.contoso.com/adfs/services/trust` |

### Sign-In Response

The response is an HTML form with JavaScript auto-submit containing:
- `wa`: `wsignin1.0`
- `wresult`: Security token (SAML)
- `wctx`: Original context

### Sign-Out Request Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `wa` | Action to perform | `wsignout1.0` |
| `wreply` | Return URL after sign-out | `https://sharepoint.contoso.com` |

## Security Tokens

### Token Structure

```xml
<RequestSecurityTokenResponse>
  <RequestedSecurityToken>
    <saml:Assertion>
      <saml:Issuer>http://adfs.contoso.com/adfs/services/trust</saml:Issuer>
      <Signature><!-- Digital signature --></Signature>
      <saml:Subject>
        <saml:NameID>user@contoso.com</saml:NameID>
      </saml:Subject>
      <saml:AttributeStatement>
        <saml:Attribute Name="emailaddress">
          <saml:AttributeValue>user@contoso.com</saml:AttributeValue>
        </saml:Attribute>
        <saml:Attribute Name="upn">
          <saml:AttributeValue>user@contoso.com</saml:AttributeValue>
        </saml:Attribute>
        <!-- Additional claims -->
      </saml:AttributeStatement>
    </saml:Assertion>
  </RequestedSecurityToken>
</RequestSecurityTokenResponse>
```

### Token Validation

SharePoint validates tokens by:

1. **Signature Verification**: Uses ADFS public key certificate
2. **Issuer Validation**: Ensures token is from trusted ADFS
3. **Audience Validation**: Confirms token is for this SharePoint farm (realm match)
4. **Time Validation**: Checks NotBefore and NotOnOrAfter timestamps
5. **Replay Detection**: Prevents token reuse

## Claims Mapping

### ADFS Claims → SharePoint Claims

```
ADFS Output Claims                      SharePoint Claims
─────────────────────                   ─────────────────
emailaddress                      →     i:05.t|provider|user@contoso.com
  (Identity Claim)
  
upn                              →      Mapped to User Profile
  
role                             →      Used for authorization
  
givenname, surname              →      Display name
```

### SharePoint User Identity Format

```
i:05.t|[provider]|[identifier claim value]

Example:
i:05.t|adfs provider|user@contoso.com

Where:
- i: = Claims identity prefix
- 05 = Trusted identity claim type
- .t = Trusted
- provider = Name of SPTrustedIdentityTokenIssuer
- identifier claim value = Value from the identifier claim (email/UPN)
```

## Certificate Trust Chain

```
ADFS Token Signing Certificate
│
├─ Private Key (ADFS Server)
│  └─ Used to sign security tokens
│
└─ Public Key Certificate (.cer file)
   └─ Imported to SharePoint
      └─ SPTrustedRootAuthority
         └─ Used to verify token signatures
```

## Session Management

### SharePoint Session Cookies

1. **FedAuth**: Primary authentication cookie
   - Contains encrypted claims
   - HttpOnly, Secure flags set
   - Path: /
   
2. **rtFa**: Refresh token
   - Used to refresh FedAuth when expired
   - Longer lifetime than FedAuth

### Token Lifetime

```
ADFS Token (SAML)
├─ Default: 60 minutes
├─ Configurable via ADFS settings
└─ Single use (consumed by SharePoint)

SharePoint Session (FedAuth)
├─ Default: 10 hours (WindowsTokenLifetime)
├─ Configurable via SPSecurityTokenServiceConfig
└─ Renewable with rtFa cookie
```

## Network Communication

### Ports and Protocols

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| Browser | SharePoint | 443 | HTTPS | Access resources |
| Browser | ADFS | 443 | HTTPS | Authentication |
| SharePoint | ADFS | - | - | No direct connection* |
| ADFS | AD | 389/636 | LDAP/LDAPS | User lookup |
| ADFS | AD | 88 | Kerberos | Authentication |

*SharePoint and ADFS don't communicate directly; all communication is through browser redirects.

## High Availability Considerations

### ADFS Farm

```
            ┌─────────────┐
            │ Load Balancer│
            │ (ADFS VIP)   │
            └──────┬───────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
   │ ADFS 1 │ │ ADFS 2 │ │ ADFS 3 │
   └────┬───┘ └───┬────┘ └───┬────┘
        │         │          │
        └─────────┼──────────┘
                  │
           ┌──────▼──────┐
           │ ADFS Config │
           │   Database  │
           │ (SQL Server)│
           └─────────────┘
```

### SharePoint Farm

```
            ┌─────────────┐
            │ Load Balancer│
            │   (SP VIP)   │
            └──────┬───────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
   ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
   │  WFE 1 │ │  WFE 2 │ │  WFE 3 │
   └────┬───┘ └───┬────┘ └───┬────┘
        │         │          │
        └─────────┼──────────┘
                  │
           ┌──────▼──────┐
           │ SharePoint  │
           │   Config &  │
           │   Content   │
           │  Databases  │
           └─────────────┘
```

## Security Considerations

### Transport Security
- All communication must use HTTPS/TLS
- Valid SSL certificates required
- Certificate chain validation

### Token Security
- Tokens signed with ADFS private key
- Tokens have limited lifetime
- Replay detection enabled
- Tokens encrypted in transit

### Certificate Management
- Monitor certificate expiration
- Plan certificate renewal process
- Secure private key storage
- Regular certificate rotation

### Claims Security
- Send only necessary claims
- Validate claim values
- Use least privilege principle
- Audit claim rules regularly

## Troubleshooting Flow

```
Issue: User cannot authenticate
│
├─ Check: Can user access SharePoint URL?
│  NO → Network/DNS issue
│  YES ↓
│
├─ Check: Is user redirected to ADFS?
│  NO → SharePoint trust configuration issue
│  YES ↓
│
├─ Check: Can user see ADFS login page?
│  NO → ADFS server/DNS issue
│  YES ↓
│
├─ Check: Do credentials work in ADFS?
│  NO → AD authentication issue
│  YES ↓
│
├─ Check: Is user redirected back to SharePoint?
│  NO → ADFS relying party trust issue
│  YES ↓
│
├─ Check: Does SharePoint show error?
│  YES → Token validation issue
│      └─ Check certificate
│      └─ Check realm match
│      └─ Check claim mappings
│  NO ↓
│
└─ Success!
```

## References

- [WS-Federation Specification](https://docs.oasis-open.org/wsfed/federation/v1.2/os/ws-federation-1.2-spec-os.html)
- [SAML 2.0 Specification](http://docs.oasis-open.org/security/saml/v2.0/)
- [Claims-Based Identity in SharePoint](https://docs.microsoft.com/sharepoint/dev/general-development/claims-based-identity-in-sharepoint)
