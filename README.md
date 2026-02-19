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
