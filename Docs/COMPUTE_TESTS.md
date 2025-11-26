# Compute Tests Documentation

This document describes all compliance tests for Azure Compute resources.

---

## VM Availability Zones

### What it does
Verifies that Virtual Machines are deployed across availability zones for high availability.

### Expected Result
- **Pass**: VM is configured with one or more availability zones (`Zones` property is not empty)
- **Fail**: VM has no availability zone configuration

### Why is this test important?
Availability zones are physically separate locations within an Azure region, each with independent power, cooling, and networking. Deploying VMs across zones protects against datacenter-level failures and provides 99.99% SLA (compared to 99.9% for single-instance VMs). This is a critical component of the Well-Architected Framework's Reliability pillar.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.Compute/virtualMachines`

---

## VM Availability Sets

### What it does
Verifies that non-zone Virtual Machines are deployed in Availability Sets with proper fault and update domain configuration.

### Expected Result
- **Pass**: VM is either in an availability zone OR in an Availability Set with 2+ fault domains AND 2+ update domains
- **Fail**: VM has no high availability configuration OR Availability Set doesn't meet minimum domain requirements

### Why is this test important?
For VMs not using availability zones, Availability Sets provide redundancy by distributing VMs across multiple fault domains (separate racks/power/network) and update domains (controlled maintenance groups). This protects against hardware failures and planned maintenance events. Minimum 2 fault domains and 2 update domains ensures basic redundancy. VMs without either zones or proper availability sets are single points of failure.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.Compute/virtualMachines`

---

## VM Hyper-V Generation

### What it does
Verifies that Virtual Machines are using Hyper-V Generation 2 (modern standard) rather than Generation 1 (legacy).

### Expected Result
- **Pass**: VM is using Generation 2 (`HyperVGeneration` = `V2`)
- **Fail**: VM is using Generation 1 (`HyperVGeneration` = `V1`)

### Why is this test important?
Generation 2 VMs provide significant advantages over Generation 1:
- **Better Performance**: UEFI-based boot architecture (faster boot times)
- **Larger Disk Support**: Up to 64 TB OS disks (Gen1 limited to 2 TB)
- **Modern Features**: Support for Secure Boot, vTPM, and Trusted Launch security features
- **Future-Proofing**: Gen1 is legacy technology with limited support for new Azure features

While Gen1 VMs continue to work, Microsoft recommends Gen2 for all new deployments. Migrating existing Gen1 VMs requires recreation, making it important to identify and plan migrations.

**Azure Well-Architected Framework**: Performance Efficiency  
**Severity**: Medium  
**Resource Type**: `Microsoft.Compute/virtualMachines`

---

## VM Workload Data Separation

### What it does
Verifies that Virtual Machines have separate data disks attached for workload data, keeping it isolated from the OS disk.

### Expected Result
- **Pass**: VM has 1 or more data disks attached
- **Fail**: VM has no data disks (workload data on OS disk)

### Why is this test important?
Separating workload data onto dedicated data disks provides critical benefits:
- **Fault Isolation**: OS issues don't corrupt application data; data issues don't affect OS
- **Simplified Recovery**: If VM fails, attach data disk to new VM with fresh OS (faster recovery)
- **Independent Management**: OS and data can be backed up, replicated, or upgraded independently
- **Performance Optimization**: Different disk types/tiers for OS vs data (e.g., Premium SSD for data, Standard for OS)
- **Ephemeral OS Support**: Enables ephemeral OS disks (stored on local VM storage) for better performance and lower cost

Without data disk separation:
- OS corruption can impact application data
- VM recovery requires full restoration (OS + data together)
- Limited flexibility for disk optimization
- Higher risk during OS updates or patches

This pattern is a fundamental best practice for resilient Azure VM architectures and aligns with the Well-Architected Framework's Reliability pillar.

**Azure Well-Architected Framework**: Reliability  
**Severity**: Medium  
**Resource Type**: `Microsoft.Compute/virtualMachines`

---

## VMSS Automatic Repairs

### What it does
Verifies that Virtual Machine Scale Sets have automatic instance repairs enabled for self-healing capabilities.

### Expected Result
- **Pass**: VMSS has automatic repairs enabled (`AutomaticRepairsPolicy.Enabled = $true`)
- **Fail**: VMSS does not have automatic repairs enabled or policy is not configured

### Why is this test important?
Automatic instance repairs provide critical self-healing for scale sets:
- **Automatic Detection**: Continuously monitors instance health via health probes or application health extension
- **Automatic Replacement**: Unhealthy instances are automatically deleted and replaced with new healthy instances
- **No Manual Intervention**: Reduces operational burden and mean time to recovery (MTTR)
- **Resilience**: Maintains desired capacity and application availability during instance failures
- **Grace Period Support**: Allows time for instances to stabilize after changes before repair actions trigger

Without automatic repairs:
- Failed instances remain in the scale set, serving errors to users
- Manual detection and remediation required (slower recovery)
- Application availability degrades during instance failures
- Higher operational overhead for maintaining healthy capacity

The Well-Architected Framework recommends configuring a grace period (typically 30+ minutes) to prevent repair loops during deployments or configuration changes. This test verifies the feature is enabled but doesn't enforce a specific grace period value, giving flexibility for different workload requirements.

**Azure Well-Architected Framework**: Reliability  
**Severity**: Medium  
**Resource Type**: `Microsoft.Compute/virtualMachineScaleSets`

---

## VMSS Overprovisioning

### What it does
Verifies that Virtual Machine Scale Sets have overprovisioning enabled for faster deployments and cost efficiency.

### Expected Result
- **Pass**: VMSS has overprovisioning enabled (`Overprovision = $true`)
- **Fail**: VMSS has overprovisioning disabled

### Why is this test important?
Overprovisioning provides significant benefits for scale set deployments:
- **Faster Deployments**: Azure provisions more VMs than requested (typically 20% more), then keeps only the requested number that successfully deploy
- **Higher Success Rate**: If some instances fail during deployment, you still reach desired capacity
- **No Extra Cost**: Extra VMs that are deleted are not billed (you only pay for the VMs that remain)
- **Better Reliability**: Reduces impact of transient deployment failures
- **Improved User Experience**: Applications reach full capacity faster

How it works:
1. You request 10 VMs
2. Azure provisions 12 VMs (20% overprovision)
3. Once 10 VMs successfully deploy, the extra 2 are immediately deleted
4. You're only billed for the 10 VMs you requested

Without overprovisioning:
- Slower deployment times (sequential retry logic for failures)
- May not reach desired capacity if some instances fail
- Longer time to achieve application availability

This is a default-enabled feature in Azure, but can be disabled. The Well-Architected Framework recommends keeping it enabled unless you have specific stateful workload requirements that conflict with the overprovision model.

**Azure Well-Architected Framework**: Performance Efficiency, Cost Optimization  
**Severity**: Low  
**Resource Type**: `Microsoft.Compute/virtualMachineScaleSets`

---

## VM Naming Convention

### What it does
Verifies that Virtual Machine names follow the organizational naming convention standards defined in the configuration file.

### Expected Result
- **Pass**: VM name matches one of the configured regex patterns
- **Fail**: VM name does not match any configured pattern

### Why is this test important?
Consistent naming conventions are a fundamental aspect of operational excellence:
- **Organization**: Easy to identify resource purpose, location, and type at a glance
- **Automation**: Predictable names enable scripting and automation workflows
- **Cost Management**: Simplifies resource grouping and cost allocation through naming patterns
- **Governance**: Enforces organizational standards and compliance requirements
- **Troubleshooting**: Faster incident response when resource names follow predictable patterns
- **Discovery**: Easier to find and filter resources across subscriptions

The naming convention is configured in `Config/NamingConventions.json` and supports:
- Multiple valid patterns per resource type
- Regular expression validation
- Case-sensitive or case-insensitive matching
- Per-resource-type configuration
- Easy pattern updates without code changes

Example pattern `azweusr001`:
- `az` = Azure prefix
- `weu` = Location (West Europe)
- `sr` = Server type
- `001` = Sequential number

**Configuration**: `Config/NamingConventions.json`  
**Azure Well-Architected Framework**: Operational Excellence  
**Severity**: Low  
**Resource Type**: `Microsoft.Compute/virtualMachines`

---

## Summary

| Test | Pillar | Severity | Pass Criteria |
|------|--------|----------|---------------|
| VM Availability Zones | Reliability | High | VM has zones configured |
| VM Availability Sets | Reliability | High | Non-zone VM in AvSet with 2+ FD/UD |
| VM Hyper-V Generation | Performance | Medium | VM is Generation 2 (V2) |
| VM Workload Data Separation | Reliability | Medium | VM has 1+ data disks |
| VM Naming Convention | Operational Excellence | Low | VM name matches configured pattern |
| VMSS Automatic Repairs | Reliability | Medium | VMSS has automatic repairs enabled |
| VMSS Overprovisioning | Performance, Cost | Low | VMSS has overprovisioning enabled |

