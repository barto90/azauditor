# Database Tests Documentation

This document describes all compliance tests for Azure Database services.

---

## SQL Database Geo-Replication

### What it does
Verifies that Azure SQL Databases have geo-replication configured for disaster recovery and high availability.

### Expected Result
- **Pass**: Database has a replication role of `Secondary` or `Primary` (indicating participation in geo-replication)
- **Fail**: Database replication role is `None` (no geo-replication configured)

### Why is this test important?
Geo-replication provides critical protection for Azure SQL Database:
- **Regional Disaster Recovery**: Maintains readable secondary database in different Azure region
- **Near-Zero Data Loss**: Continuous asynchronous replication (RPO ~5 seconds)
- **Fast Failover**: Quick recovery time objective (RTO) with automated or manual failover
- **Read Scale-Out**: Secondary replicas can serve read-only workloads, reducing load on primary
- **Business Continuity**: Protects against regional outages, datacenter failures

For production databases, geo-replication is essential insurance against:
- Regional Azure outages (rare but possible)
- Datacenter-level disasters
- Data corruption that could cascade to backups

This is a fundamental component of the Well-Architected Framework's Reliability pillar and often required for compliance (SOC 2, ISO 27001, HIPAA).

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.Sql/servers/databases`

---

## CosmosDB Geo-Replication

### What it does
Verifies that Azure Cosmos DB accounts are configured with multi-region deployment for global distribution.

### Expected Result
- **Pass**: Cosmos DB account has 2 or more locations/regions configured
- **Fail**: Cosmos DB account has only 1 location (single region)

### Why is this test important?
Cosmos DB multi-region configuration provides:
- **99.999% Availability SLA**: With multi-region writes enabled
- **Global Distribution**: Data replicated to multiple Azure regions automatically
- **Low Latency**: Users connect to nearest region for best performance
- **Automatic Failover**: Seamless failover during regional outages
- **Regional Isolation**: Problems in one region don't affect others

Single-region Cosmos DB deployments lack:
- Protection against regional outages
- Global performance optimization
- Compliance with multi-region requirements

For globally distributed applications or mission-critical workloads, multi-region Cosmos DB is essential for reliability and performance.

**Azure Well-Architected Framework**: Reliability, Performance Efficiency  
**Severity**: High  
**Resource Type**: `Microsoft.DocumentDB/databaseAccounts`

---

## PostgreSQL Geo-Replication

### What it does
Verifies that Azure Database for PostgreSQL servers have cross-region read replicas configured for disaster recovery.

### Expected Result
- **Pass**: PostgreSQL server has 1 or more read replicas in different regions
- **Fail**: PostgreSQL server has no read replicas (no cross-region redundancy)

### Why is this test important?
PostgreSQL read replicas provide:
- **Disaster Recovery**: Cross-region replica can be promoted to primary during outages
- **Regional Redundancy**: Protection against Azure region failures
- **Read Scale-Out**: Offload read workloads from primary server
- **Geographic Distribution**: Serve users from closest region for lower latency
- **Data Protection**: Additional copy of data for protection against corruption

Without cross-region replicas:
- Regional outage = complete database unavailability
- Recovery depends on geo-redundant backups (longer RTO)
- All traffic concentrated on single region

This aligns with the Well-Architected Framework's Reliability pillar and is critical for production PostgreSQL workloads.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.DBforPostgreSQL/servers`

---

## MySQL Geo-Replication

### What it does
Verifies that Azure Database for MySQL servers have cross-region read replicas configured for disaster recovery.

### Expected Result
- **Pass**: MySQL server has 1 or more read replicas in different regions
- **Fail**: MySQL server has no read replicas (no cross-region redundancy)

### Why is this test important?
MySQL read replicas provide:
- **Disaster Recovery**: Cross-region replica can be promoted to primary during outages
- **Regional Redundancy**: Protection against Azure region failures
- **Read Scale-Out**: Offload read workloads from primary server
- **Geographic Distribution**: Serve users from closest region for lower latency
- **Data Protection**: Additional copy of data for protection against corruption

Without cross-region replicas:
- Regional outage = complete database unavailability
- Recovery depends on geo-redundant backups (longer RTO)
- All traffic concentrated on single region

This aligns with the Well-Architected Framework's Reliability pillar and is critical for production MySQL workloads.

**Azure Well-Architected Framework**: Reliability  
**Severity**: High  
**Resource Type**: `Microsoft.DBforMySQL/servers`

---

## Summary

| Test | Database Type | Pillar | Severity | Pass Criteria |
|------|---------------|--------|----------|---------------|
| SQL Database Geo-Replication | Azure SQL | Reliability | High | Replication role is Primary or Secondary |
| CosmosDB Geo-Replication | Cosmos DB | Reliability | High | 2+ regions configured |
| PostgreSQL Geo-Replication | PostgreSQL | Reliability | High | Cross-region read replicas exist |
| MySQL Geo-Replication | MySQL | Reliability | High | Cross-region read replicas exist |

---

## Common Patterns

All database tests follow the same reliability principle: **data should exist in multiple geographic regions** to protect against:
- Regional Azure outages
- Datacenter disasters
- Network partitions
- Data corruption

The specific implementation varies by database service, but the goal remains consistent: ensure business continuity and data durability across geographic boundaries.

