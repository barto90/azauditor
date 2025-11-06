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

## Summary

| Test | Pillar | Severity | Pass Criteria |
|------|--------|----------|---------------|
| Load Balancer Redundancy | Reliability | High | 2+ backend instances |
| Load Balancer Health Probes | Reliability | High | Health probes configured for all rules |

