# Recovery Tests Documentation

This document describes all compliance tests for Azure Site Recovery and backup services.

---

## VM Site Recovery Protection

### What it does
Verifies that Virtual Machines are protected by Azure Site Recovery (ASR) for disaster recovery.

### Expected Result
- **Pass**: VM is found in the list of protected items in any Recovery Services Vault with replication state showing protection
- **Fail**: VM is not configured with Azure Site Recovery protection

### Why is this test important?
Azure Site Recovery provides critical disaster recovery capabilities:
- **Business Continuity**: Ensures workloads remain available during regional outages or disasters
- **RPO/RTO Control**: Recovery Point Objective (typically 5 minutes) and Recovery Time Objective control
- **Automated Failover**: Orchestrated failover to secondary region with minimal downtime
- **Cost-Effective DR**: Pay only for replication, not duplicate infrastructure
- **Compliance Requirements**: Many industries require documented disaster recovery capabilities

For production and critical workloads, ASR protection is essential. Without it, a regional failure could result in:
- Complete data loss (if no backups)
- Extended downtime (manual recovery process)
- Revenue loss and regulatory violations

This aligns with the Well-Architected Framework's Reliability pillar and is often mandated by business continuity plans.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.Compute/virtualMachines`  
**Related Service**: Azure Site Recovery (Recovery Services Vault)

---

## Architecture Notes

### ASR Hierarchy
Azure Site Recovery uses a hierarchical structure:
```
Recovery Services Vault
└── Fabric (Azure Region)
    └── Protection Container
        └── Protected Items (VMs)
```

The test traverses this hierarchy to identify all VMs with ASR protection enabled across all Recovery Services Vaults in the subscription.

### ASR vs Backup
- **Azure Site Recovery**: Disaster recovery, replicates entire VMs for regional failover
- **Azure Backup**: Point-in-time recovery, protects against data loss and corruption

Both services use Recovery Services Vaults but serve different purposes. This test focuses on ASR for disaster recovery scenarios.

---

## Summary

| Test | Pillar | Severity | Pass Criteria |
|------|--------|----------|---------------|
| VM Site Recovery Protection | Reliability | High | VM is protected by ASR |

