# Networking Tests Documentation

This document describes all compliance tests for Azure Networking resources.

---

## Load Balancer Redundancy

### What it does
Verifies that Azure Load Balancers have multiple backend instances configured for redundancy.

### Expected Result
- **Pass**: Load Balancer has 2 or more backend instances/VMs configured
- **Fail**: Load Balancer has 0 or 1 backend instance (single point of failure)

### Why is this test important?
A load balancer with only one backend instance defeats the purpose of load balancing and creates a single point of failure. Multiple backend instances provide:
- **High Availability**: If one instance fails, traffic automatically routes to healthy instances
- **No Downtime**: Maintenance can be performed on instances without service interruption
- **Load Distribution**: Traffic is distributed across instances, preventing overload
- **Scalability**: Easy to add more instances as demand grows

This is fundamental to building resilient applications in Azure and a core principle of the Well-Architected Framework's Reliability pillar.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.Network/loadBalancers`

---

## Load Balancer Health Probes

### What it does
Verifies that Azure Load Balancers have health probes configured for all load-balanced endpoints.

### Expected Result
- **Pass**: Load Balancer has health probes defined AND the number of probes matches or exceeds the number of load balancing rules
- **Fail**: No health probes configured OR fewer probes than load balancing rules

### Why is this test important?
Health probes are critical for automatic failure detection and recovery:
- **Automatic Failure Detection**: Probes continuously check backend instance health
- **Traffic Routing**: Only healthy instances receive traffic (unhealthy ones are taken out of rotation)
- **Self-Healing**: When an instance recovers and passes health checks, it's automatically added back
- **Zero Manual Intervention**: No need to manually remove/add instances during failures

Without health probes, the load balancer blindly sends traffic to all backend instances, including failed ones, resulting in application errors and poor user experience. This violates the reliability and operational excellence pillars of the Well-Architected Framework.

**Azure Well-Architected Framework**: Reliability, Operational Excellence  
**Severity**: High  
**Resource Type**: `Microsoft.Network/loadBalancers`

---

## PaaS Private Endpoints

### What it does
Verifies that Azure PaaS resources have private endpoints configured to secure network access.

### Expected Result
- **Pass**: PaaS resource has at least one approved private endpoint connection
- **Fail**: PaaS resource has no private endpoint configured

### Covered PaaS Services
This test checks the following resource types:
- Storage Accounts (`Microsoft.Storage/storageAccounts`)
- SQL Servers (`Microsoft.Sql/servers`)
- Key Vaults (`Microsoft.KeyVault/vaults`)
- Cosmos DB Accounts (`Microsoft.DocumentDB/databaseAccounts`)
- Container Registries (`Microsoft.ContainerRegistry/registries`)
- App Services (`Microsoft.Web/sites`)
- Service Bus Namespaces (`Microsoft.ServiceBus/namespaces`)
- Event Hub Namespaces (`Microsoft.EventHub/namespaces`)

### Why is this test important?
Private endpoints provide secure, private connectivity to Azure PaaS services:

**Security Benefits:**
- **No Public Internet Exposure**: Traffic stays within your virtual network, never traversing the public internet
- **Eliminate Data Exfiltration Risks**: No public endpoints means reduced attack surface
- **Network Isolation**: PaaS resources integrate into your private network topology
- **Private IP Addressing**: Services are accessible via private IPs in your VNet

**Compliance Benefits:**
- **Zero Trust Architecture**: Follows zero trust principles by removing public access
- **Regulatory Requirements**: Many compliance frameworks (PCI-DSS, HIPAA) require private connectivity
- **Data Sovereignty**: Ensures data doesn't leave your controlled network boundaries

**Operational Benefits:**
- **DNS Integration**: Private DNS zones provide name resolution for private endpoints
- **Simplified Networking**: Use existing network security tools (NSGs, firewalls, etc.)
- **Connection Monitoring**: Track and audit all connections through Azure Monitor

**Without Private Endpoints:**
- PaaS resources are accessible from the public internet (even with firewall rules)
- Increased attack surface and exposure to threats
- Potential data exfiltration paths
- Difficulty meeting security and compliance requirements
- Reliance on service-level security features alone

**Note**: Resources that don't support private endpoints are automatically skipped by this test.

**Azure Well-Architected Framework**: Security  
**Severity**: High  
**Resource Types**: Multiple PaaS services

---

## Summary

| Test | Pillar | Severity | Pass Criteria |
|------|--------|----------|---------------|
| Load Balancer Redundancy | Reliability | High | 2+ backend instances |
| Load Balancer Health Probes | Reliability | High | Health probes configured for all rules |
| PaaS Private Endpoints | Security | High | Private endpoint configured |

