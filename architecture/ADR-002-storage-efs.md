# Architecture Decision Record: Storage

## Title: Rely on Amazon EFS for Shared WordPress Storage

### Status: Accepted

### Context
When scaling WordPress horizontally across multiple containers, the application requires a shared filesystem for `wp-content/` (themes, plugins, and certain dynamically generated files).

### Decision
We will use Amazon Elastic File System (EFS) mounted to the ECS Fargate tasks. Media uploads should ideally be offloaded to S3 using a plugin (like WP Offload Media), using EFS strictly for application artifacts that require POSIX limits.

### Consequences
**Positive:**
- Native integration with ECS Fargate.
- Elastic capacity without pre-provisioning.
- Can be shared concurrently across hundreds of WordPress containers.
- Strong encryption at rest and in transit.

**Negative:**
- Performance penalty for small file reads compared to local EBS or instance store.
- Requires careful handling of EFS Access Points and IAM permissions.

### Alternatives Considered
- **S3 (solely via s3fs wrapper):** Provides poor performance for PHP opcache and small file reads.
- **EBS:** Cannot be attached to multiple Fargate tasks concurrently.
