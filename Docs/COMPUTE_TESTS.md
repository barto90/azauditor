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

## Summary

| Test | Pillar | Severity | Pass Criteria |
|------|--------|----------|---------------|
| VM Availability Zones | Reliability | High | VM has zones configured |
| VM Availability Sets | Reliability | High | Non-zone VM in AvSet with 2+ FD/UD |
| VM Hyper-V Generation | Performance | Medium | VM is Generation 2 (V2) |
| VM Workload Data Separation | Reliability | Medium | VM has 1+ data disks |

