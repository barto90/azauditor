# Identity Tests Documentation

This document describes all compliance tests for Azure Identity resources.

---

## Microsoft Authenticator Enabled

### What it does
Verifies that Microsoft Authenticator is enabled as an authentication method for all users in the tenant.

### Expected Result
**Pass**: Microsoft Authenticator is enabled as an authentication method for all users.

**Fail**: Any user does not have Microsoft Authenticator enabled as an authentication method.

### Why is this test important?
Microsoft Authenticator provides strong, passwordless authentication that enhances security:

**Security Benefits:**
- **Passwordless Authentication**: Eliminates password-based attacks (phishing, credential stuffing, brute force)
- **Multi-Factor Authentication**: Provides an additional layer of security beyond passwords
- **Device-Based Security**: Uses device biometrics (fingerprint, face recognition) for authentication
- **Push Notifications**: Users can approve sign-ins with a simple tap on their mobile device
- **Time-Based Codes**: Backup authentication method using time-based one-time passwords (TOTP)

**Compliance Benefits:**
- **Zero Trust**: Aligns with Zero Trust security model requiring strong authentication
- **Regulatory Compliance**: Meets requirements for multi-factor authentication in various compliance frameworks
- **Risk Reduction**: Significantly reduces risk of account compromise
- **User Experience**: Provides convenient authentication without sacrificing security

**Without Microsoft Authenticator:**
- Users rely solely on passwords, which are vulnerable to attacks
- Increased risk of account compromise through credential theft
- Difficulty meeting compliance requirements for strong authentication
- Poor user experience with traditional MFA methods (SMS, phone calls)

### How it works
1. Retrieves all users in the Azure AD tenant using Microsoft Graph API
2. For each user, checks their authentication methods
3. Verifies if Microsoft Authenticator (`microsoftAuthenticatorAuthenticationMethod`) is configured
4. Reports pass/fail status for each user

### Test Details
- **Category**: Identity
- **Sub-Category**: Authentication
- **Resource Type**: Microsoft.Graph/users
- **WAF Pillar**: Security
- **Severity**: High
- **Tenant-Level**: Yes (runs once per tenant, not per subscription)

### Prerequisites
- Azure PowerShell module installed and connected (`Connect-AzAccount`)
- **Microsoft Graph PowerShell module** installed and connected:
  ```powershell
  # Install the required modules
  Install-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -Scope CurrentUser
  
  # Connect with required permissions
  Connect-MgGraph -Scopes 'User.Read.All','UserAuthenticationMethod.Read.All'
  ```
- Required Microsoft Graph API permissions:
  - `User.Read.All` - To read user information
  - `UserAuthenticationMethod.Read.All` - To read authentication methods
  
**Note:** These permissions may require admin consent depending on your organization's policies.

### Example Output
```
Test Name: Microsoft-Authenticator-Enabled
Resource: John Doe (john.doe@contoso.com)
Status: Pass
Actual Result: Microsoft Authenticator enabled
```

---

## Entra ID Security Score

### What it does
Verifies that the Entra ID Identity Secure Score is above 70% (minimum recommended threshold).

### Expected Result
**Pass**: Identity Secure Score is 70% or higher.

**Fail**: Identity Secure Score is below 70%.

### Why is this test important?
The Identity Secure Score is a metric that reflects how well your organization's security configurations align with Microsoft's best practices:

**Security Benefits:**
- **Comprehensive Security Posture**: Provides a single metric to assess overall identity security
- **Best Practice Alignment**: Ensures your tenant follows Microsoft's recommended security configurations
- **Risk Identification**: Highlights areas where security can be improved
- **Continuous Improvement**: Score updates daily based on your security settings and configurations

**Compliance Benefits:**
- **Security Baseline**: Establishes a minimum security threshold (70% is considered a strong baseline)
- **Regulatory Compliance**: Helps meet security requirements in various compliance frameworks
- **Risk Management**: Lower scores indicate higher security risk exposure
- **Executive Reporting**: Provides a clear metric for security posture reporting

**Without a High Security Score:**
- Increased risk of security incidents and breaches
- Non-compliance with security best practices
- Difficulty meeting regulatory requirements
- Poor security posture visibility

### How it works
1. Retrieves the latest Identity Secure Score from Microsoft Graph Security API
2. Calculates the percentage score: (currentScore / maxScore) × 100
3. Compares the score against the 70% threshold
4. Reports pass/fail status based on whether the score meets or exceeds 70%

### Test Details
- **Category**: Identity
- **Sub-Category**: Security
- **Resource Type**: Microsoft.Graph/security/secureScores
- **WAF Pillar**: Security
- **Severity**: High
- **Tenant-Level**: Yes (runs once per tenant, not per subscription)

### Prerequisites
- Azure PowerShell module installed and connected (`Connect-AzAccount`)
- **Microsoft Graph PowerShell module** installed and connected:
  ```powershell
  # Install the required modules
  Install-Module Microsoft.Graph.Security -Scope CurrentUser
  
  # Connect with required permissions
  Connect-MgGraph -Scopes 'SecurityEvents.Read.All'
  ```
- Required Microsoft Graph API permissions:
  - `SecurityEvents.Read.All` - To read security scores
  
**Note:** These permissions may require admin consent depending on your organization's policies.

### Example Output
```
Test Name: Entra-Security-Score
Resource: Identity Secure Score
Status: Pass
Actual Result: 75.5% (151 / 200 points)
```

---

## Future Tests

Additional identity tests planned:
- Conditional Access Policy compliance
- Password policy enforcement
- Service principal authentication methods
- Privileged Identity Management (PIM) configuration

