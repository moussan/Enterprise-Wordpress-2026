# Architecture Decision Record: Compute Platform

## Title: Use ECS Fargate for WordPress Compute

### Status: Accepted

### Context
WordPress is traditionally deployed on EC2 instances. However, managing OS patching, instance lifecycle, and scaling EC2 instances introduces significant operational overhead for an Enterprise deployment. We needed a compute platform that allows us to focus purely on the application container.

### Decision
We will use Amazon ECS with the AWS Fargate launch type for our WordPress application containers.

### Consequences
**Positive:**
- Zero server management (no EC2 instances to patch).
- Seamless horizontal scaling via Target Tracking Auto Scaling.
- Simplified networking with `awsvpc` mode (each container gets its own ENI).
- Granular IAM roles per task for better security.

**Negative:**
- Executing into containers is slightly more complex (requires ECS Exec) compared to SSH.
- Costs can be slightly higher than reserved EC2 instances if not using Fargate Spot or Compute Savings Plans.

### Alternatives Considered
- **EKS (Kubernetes):** Deemed overkill for a single-application architecture like WordPress. Unnecessary control plane overhead.
- **EC2 Auto Scaling Groups:** Requires AMIs, patching pipelines, and complex UserData scripts to bootstrap the application.
