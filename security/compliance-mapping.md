# Security Compliance Mapping

This architecture aligns with best practices from the **AWS Foundational Security Best Practices (FSBP)** and **CIS AWS Foundations Benchmark**.

## 1. Network Security Layer

| Control / Feature | Description | Status |
|-------------------|-------------|--------|
| **VPC Isolation** | RDS and ECS Tasks are placed in private/isolated subnets with no direct ingress from the internet. | ✅ Implemented |
| **Edge Protection** | AWS WAFv2 is enabled on the ALB to block common OWASP Top 10 vulnerabilities, SQL injection, and rate-limit attacks. | ✅ Implemented |
| **In-transit Encryption** | TLS 1.2+ is enforced at the ALB and CloudFront levels. EFS Transit Encryption is enabled. | ✅ Implemented |
| **Security Groups** | Traffic is explicitly allowed. ALB -> ECS (80/443), ECS -> RDS (3306), ECS -> EFS (2049). | ✅ Implemented |

## 2. Identity and Access Management (IAM)

| Control / Feature | Description | Status |
|-------------------|-------------|--------|
| **Least Privilege** | Dedicated, granular IAM roles are created for ECS Task Execution and ECS Task runtime. | ✅ Implemented |
| **Secrets Management** | Database credentials are managed natively by AWS Secrets Manager with automatic rotation. No hardcoded passwords in Terraform or ECS definitions. | ✅ Implemented |
| **Temporary Credentials** | AWS workloads assume temporary IAM roles; no static access keys are utilized. | ✅ Implemented |

## 3. Data Protection (At Rest)

| Control / Feature | Description | Status |
|-------------------|-------------|--------|
| **RDS Encryption** | Amazon RDS storage is encrypted using AWS KMS. | ✅ Implemented |
| **EFS Encryption** | Amazon EFS file system is encrypted at rest using AWS KMS. | ✅ Implemented |
| **S3 Encryption** | S3 bucket utilizes default bucket encryption with BucketOwnerEnforced object ownership. | ✅ Implemented |

## 4. Logging and Monitoring

| Control / Feature | Description | Status |
|-------------------|-------------|--------|
| **Application Logs** | WordPress container logs are streamed directly to Amazon CloudWatch via `awslogs` driver. | ✅ Implemented |
| **WAF Analytics** | CloudWatch Metrics are enabled for AWS WAF to monitor rule triggers. | ✅ Implemented |
