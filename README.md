# Enterprise WordPress on AWS  
Enterprise-grade WordPress deployment on AWS using ECS Fargate, Terraform, and Zero-Trust security principles.

---

## 1. Executive Summary

This repository provisions a highly available, auto-scaling, and security-hardened WordPress platform designed for:

- 1,000+ concurrent users
- Horizontal scaling
- Cost optimization
- Defense-in-depth security
- Enterprise observability
- Multi-environment deployment (Dev / Staging / Production)

The solution is built using Infrastructure as Code (Terraform) and follows AWS Well-Architected Framework best practices.

---

## 2. Architecture Overview

Core components:

- AWS VPC (Multi-AZ)
- ECS Fargate (WordPress containers)
- RDS MySQL (Multi-AZ)
- Application Load Balancer
- AWS WAF
- CloudFront (optional CDN)
- S3 (media storage)
- Auto Scaling policies
- CloudWatch monitoring
- IAM least-privilege policies

See `/architecture/diagrams` for full diagrams.

---

## 3. Design Principles

- Infrastructure as Code first
- Immutable container builds
- Multi-AZ high availability
- Stateless application tier
- Principle of Least Privilege (IAM)
- Autoscaling based on real metrics
- Cost-aware architecture
- Zero-downtime deployment

---

## 4. Repository Structure

| Directory | Purpose |
|------------|----------|
| `modules/` | Reusable Terraform modules |
| `environments/` | Environment-specific configuration |
| `architecture/` | Diagrams and ADRs |
| `security/` | Security documentation and compliance mapping |
| `docs/` | Operational runbooks |
| `cost-optimization/` | Cost estimation and scaling strategy |
| `.github/workflows` | CI/CD automation |

---

## 5. Prerequisites

- Terraform >= 1.5
- AWS CLI configured
- Docker
- GitHub Actions (for CI/CD)

---

## 6. Deployment Workflow

### Step 1 — Initialize
### Step 2 — Plan
''' terraform plan -var-file=environments/dev/terraform.tfvars
### Step 3 — Apply
''' terraform apply -var-file=environments/dev/terraform.tfvars

Production deployments should only occur via GitHub Actions.

---

## 7. Security Controls

- Private subnets for ECS and RDS
- No public database access
- AWS WAF managed rule sets
- IAM least-privilege policies
- Security groups scoped to minimum ports
- Optional CloudFront + Shield Advanced
- Encrypted storage (RDS + S3)
- Secrets stored in AWS Secrets Manager

See `/security` for detailed mappings.

---

## 8. Scaling Strategy

- ECS Service Auto Scaling (CPU + Memory metrics)
- RDS read replica (optional)
- ALB target tracking scaling
- Horizontal container scaling
- Optional Aurora Serverless (future enhancement)

---

## 9. Disaster Recovery

- Automated RDS backups
- S3 versioning enabled
- Multi-AZ deployment
- Infrastructure redeployable via Terraform
- RTO and RPO documented in `/docs/disaster-recovery.md`

---

## 10. Cost Optimization

- Fargate Spot (optional)
- Right-sized RDS instances
- Autoscaling policies tuned for load
- CloudFront to reduce origin load
- Monitoring unused resources

See `/cost-optimization`.

---

## 11. Compliance Alignment

Designed to align with:

- CIS AWS Foundations Benchmark
- ISO 27001 (Infrastructure layer)
- SOC2 Controls
- NIST Security Framework (mapped in `/security/compliance-mapping.md`)

---

## 12. CI/CD

GitHub Actions:

- Terraform validate
- Terraform plan on PR
- Terraform apply on merge to main
- Security scanning (tfsec / checkov)

---

## 13. Roadmap

- Blue/Green deployments
- Canary releases
- Aurora MySQL migration
- Redis caching layer
- Elasticache integration
- Observability with Datadog or OpenTelemetry

---

## 14. Maintainers

Enterprise Cloud Architecture Team

---

## License

MIT
