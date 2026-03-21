# Cost Optimization & Scaling Strategy

## 1. Compute Scaling (ECS Fargate)

### Target Tracking
- Auto Scaling is driven by a `TargetTrackingScaling` policy hooked to `ECSServiceAverageCPUUtilization`.
- **Target Value:** 60%. When CPU hits 60% on average, Fargate scales out.

### Right-Sizing
- **Dev/Staging:** `0.5 vCPU / 1GB RAM` (Fargate Spot recommended for non-prod).
- **Prod:** Starts at `2 vCPU / 4GB RAM` with min capacity of 3 tasks spread across 3 AZs.

### Spot Capacity Providers (Future Enhancement)
- Implementing Fargate Spot into the ECS Cluster capacity provider strategy can reduce task costs by up to 70% for fault-tolerant workers.

## 2. Database (RDS MySQL)

### Multi-AZ
- Prod uses Multi-AZ. Dev and Staging use Single-AZ to reduce costs significantly.

### Instance Sizing
- **Dev:** `db.t3.micro`
- **Prod:** `db.r6g.large` (Graviton2 instances provide up to 20% cost savings over x86 equivalents like m5/r5).

### Performance Insights
- Keep Performance Insights to the free 7-day retention tier unless actively debugging long-term queries.

## 3. Storage (EFS & S3)

### EFS Lifecycle Policies
- Transition files not accessed for 30 days to EFS Infrequent Access (IA).
- Saves up to 92% on storage costs for old themes/plugins or local backups.

### WP Offload Media (S3)
- Offloading media to S3 immediately reduces EFS bursting capacity usage and shrinks the EFS filesystem, significantly lowering overall storage costs and improving CloudFront hit rates.
