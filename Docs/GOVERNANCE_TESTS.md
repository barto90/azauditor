# Governance Tests Documentation

This document describes all compliance tests for Azure Governance resources.

---

## Management Group Structure

### What it does
Verifies that the required Management Group structure exists following Azure Landing Zone best practices.

### Expected Result
```
Root
├── Platform Landing Zone
│   ├── Connectivity (with subscriptions)
│   ├── Identity (with subscriptions)
│   └── Management (with subscriptions)
└── Landing Zones
```

**Pass**: All required management groups exist with:
- Correct hierarchy (Platform has Connectivity, Identity, and Management as children)
- At least one subscription assigned to each **child** management group (Connectivity, Identity, Management)
- Platform and Landing Zones are organizational groups and don't require direct subscriptions

**Fail**: Any of the following:
- Missing management groups
- Missing child groups under Platform Landing Zone
- Child management groups (Connectivity, Identity, Management) have no subscriptions assigned

### Why is this test important?
A well-structured management group hierarchy is foundational for Azure governance and operational excellence:

**Organizational Structure:**
- **Platform Landing Zone**: Contains shared platform services and infrastructure
  - **Connectivity**: Network connectivity resources (hubs, gateways, firewalls)
  - **Identity**: Identity and access management resources (domain controllers, Azure AD DS)
  - **Management**: Central management and monitoring resources (Log Analytics, Automation)
- **Landing Zones**: Application landing zones for workloads

**Benefits of This Structure:**
- **Policy Inheritance**: Policies applied at management group level automatically cascade to child groups and subscriptions
- **RBAC Separation**: Clear role boundaries between platform and application teams
- **Cost Management**: Easy to track and allocate costs per organizational unit
- **Compliance**: Centralized governance enforcement across the organization
- **Scalability**: New subscriptions can be quickly placed in the appropriate management group
- **Best Practices**: Aligns with Microsoft's Azure Landing Zone architecture

**Without Proper Structure:**
- Inconsistent policy application across subscriptions
- Difficulty managing permissions at scale
- Poor cost visibility and chargeback
- Compliance gaps and audit challenges
- Manual governance overhead

This test uses **pattern matching** (case-insensitive) to identify management groups:
- Platform Landing Zone: matches "platform"
- Connectivity: matches "connectivity" or "connect"
- Identity: matches "identity" or "ident"
- Management: matches "management" or "mgmt"
- Landing Zones: matches "landing zone", "landing-zone", or "lz"

This allows flexibility in naming while ensuring the structure exists.

**Scope**: Tenant-level test (runs once per tenant, not per subscription)

**Azure Well-Architected Framework**: Operational Excellence  
**Severity**: High  
**Resource Type**: `Microsoft.Management/managementGroups`

---

## Management Group Policy Compliance

### What it does
Verifies that all Management Groups have policy assignments and all resources are compliant with those policies.

### Expected Result
**Pass**: All management groups have:
- At least one policy assignment
- 100% compliance (0 non-compliant resources)

**Fail**: Any of the following:
- Management groups with no policy assignments
- Management groups with non-compliant resources

### Why is this test important?
Azure Policy is the foundation of governance and compliance in Azure:

**Policy Enforcement:**
- **Preventive Controls**: Policies can deny resource creation that doesn't meet requirements
- **Detective Controls**: Policies audit existing resources for compliance
- **Automatic Remediation**: DeployIfNotExists policies can automatically fix non-compliant resources
- **Compliance at Scale**: Policies applied at management group level cascade to all child subscriptions

**Benefits of Policy Compliance:**
- **Security**: Enforce security baselines (encryption, network rules, allowed services)
- **Cost Management**: Prevent expensive resources or enforce tagging for cost allocation
- **Regulatory Compliance**: Meet industry standards (PCI-DSS, HIPAA, ISO 27001)
- **Operational Standards**: Enforce naming conventions, required tags, allowed locations
- **Audit Trail**: Complete record of policy evaluations and compliance state

**Without Policy Compliance:**
- No enforcement of organizational standards
- Manual compliance checking (error-prone and time-consuming)
- Security vulnerabilities from misconfigured resources
- Difficulty proving compliance during audits
- Inconsistent resource configurations across teams

**What This Test Checks:**
1. **Policy Coverage**: Every management group should have policies assigned
2. **Resource Compliance**: All resources under each MG must be compliant (0 non-compliant)
3. **Tenant-Wide View**: Single test result showing compliance across all MGs

The test uses `Get-AzPolicyStateSummary` to retrieve the same compliance data shown in the Azure Portal, providing a real-time snapshot of your governance posture.

**Scope**: Tenant-level test (runs once per tenant, checks all management groups)

**Azure Well-Architected Framework**: Security  
**Severity**: High  
**Resource Type**: `Microsoft.Authorization/policyAssignments`

---

## Summary

| Test | Pillar | Severity | Scope | Pass Criteria |
|------|--------|----------|-------|---------------|
| Management Group Structure | Operational Excellence | High | Tenant | All MGs exist with hierarchy and subscriptions |
| Management Group Policy Compliance | Security | High | Tenant | All MGs have policies with 0 non-compliant resources |

---

## Future Governance Tests

Potential additional tests for this category:
- **Specific Policy Validation**: Check for required policies (e.g., "Require Tags", "Allowed Locations")
- **Policy Initiatives**: Verify specific policy sets are assigned (e.g., Azure Security Benchmark)
- **Policy Exemptions**: Monitor and validate policy exemptions
- **RBAC Assignments**: Validate role assignments follow least privilege
- **Naming Standards**: Check management group names follow conventions
- **Subscription Organization**: Verify subscriptions are in correct management groups
- **Budgets and Alerts**: Ensure cost management is configured
- **Policy Parameters**: Validate specific parameter values in policy assignments

