# Disaster Recovery Plan

## RTO and RPO Targets

- **Recovery Time Objective (RTO):** 2 Hours
- **Recovery Point Objective (RPO):** 5-15 Minutes (depending on RDS backups and S3 replication)

## Backup Mechanisms

### 1. Database Backups (Amazon RDS)
- Automated snapshots run daily from `03:00 to 04:00 UTC`.
- Retention period is 7 days.
- Point-In-Time Recovery (PITR) is enabled for RDS.

### 2. Application Files (EFS)
- EFS is highly durable across multiple AZs. 
- *Recommendation for Enterprise:* Implement AWS Backup for EFS to take daily snapshots of the `wp-content` directory.

### 3. Media Files (S3)
- Media bucket has Versioning enabled (if configured).

### 4. Infrastructure
- Infrastructure is fully codified in Terraform. RTO for full recreation in a secondary region is under 15 minutes.

## Failure Scenarios

### Scenario A: ECS Cluster / Container Failure
- **Action:** None required. Auto-Scaling will terminate unhealthy containers and spin up replacements automatically.

### Scenario B: Database Instance Failure
- **Action:** If Multi-AZ, RDS handles failover automatically under 60 seconds. Application temporarily pauses and re-establishes connection.

### Scenario C: Accidental Deletion / Corruption of Database
- **Action:** Use Terraform to spawn a new DB instance from a Point-in-Time snapshot, or manually restore a snapshot and update the database endpoint in AWS Secrets Manager / Terraform state.

### Scenario D: Total Region Failure (us-east-1)
- **Action:** 
  1. Update `providers.tf` to point to a new region (e.g., `us-west-2`).
  2. Restore the latest RDS Cross-Region Snapshot.
  3. Deploy the Terraform stack (`terraform apply`) using the restored snapshot ARN.
  4. Update Route 53 to point to the new CloudFront / ALB endpoint.
