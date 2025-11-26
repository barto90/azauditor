# Azure Auditor - Test Documentation

This directory contains comprehensive documentation for all Azure Auditor compliance tests.

## Documentation Files

- **[COMPUTE_TESTS.md](COMPUTE_TESTS.md)** - Virtual Machine availability, redundancy, and configuration tests
- **[NETWORKING_TESTS.md](NETWORKING_TESTS.md)** - Load Balancer redundancy and health monitoring tests
- **[RECOVERY_TESTS.md](RECOVERY_TESTS.md)** - Azure Site Recovery disaster recovery tests
- **[DATABASE_TESTS.md](DATABASE_TESTS.md)** - Database geo-replication and multi-region tests

## Test Categories Overview

### Compute (6 tests)
Tests focused on Virtual Machine and Scale Set high availability and performance:
- VM Availability Zones
- VM Availability Sets
- VM Hyper-V Generation
- VM Workload Data Separation
- VMSS Automatic Repairs
- VMSS Overprovisioning

### Networking (2 tests)
Tests focused on Load Balancer reliability:
- Load Balancer Redundancy
- Load Balancer Health Probes

### Recovery (1 test)
Tests focused on disaster recovery:
- VM Site Recovery Protection

### Database (4 tests)
Tests focused on database geo-replication:
- SQL Database Geo-Replication
- CosmosDB Geo-Replication
- PostgreSQL Geo-Replication
- MySQL Geo-Replication

## Well-Architected Framework Alignment

All tests are aligned with the [Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/) pillars:

| Pillar | Test Count | Focus |
|--------|------------|-------|
| **Reliability** | 11 | High availability, disaster recovery, redundancy, fault isolation, self-healing |
| **Performance Efficiency** | 2 | Resource optimization, modern configurations, deployment speed |
| **Cost Optimization** | 1 | Efficient resource usage |

## Test Severity Levels

- **High**: Tests that identify configurations that could lead to service outages, data loss, or major compliance violations
- **Medium**: Tests that identify suboptimal configurations or technical debt

## Using This Documentation

Each test document includes:
1. **What it does**: Clear description of what the test checks
2. **Expected Result**: Pass/fail criteria
3. **Why is this test important**: Business justification and technical rationale

Use these documents to:
- Understand test failures and their impact
- Justify remediation work to stakeholders
- Plan architecture improvements
- Meet compliance requirements
- Train team members on Azure best practices

## Test Development

When adding new tests, ensure documentation follows the same structure:
- What the test does (clear, concise)
- Expected result (explicit pass/fail criteria)
- Why it's important (business value, technical rationale, compliance alignment)

## Additional Resources

- [Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
- [Azure Reliability Documentation](https://docs.microsoft.com/azure/reliability/)
- [Azure Site Recovery Documentation](https://docs.microsoft.com/azure/site-recovery/)
- [Azure SQL Database High Availability](https://docs.microsoft.com/azure/azure-sql/database/high-availability-sla)

