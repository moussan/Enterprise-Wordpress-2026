# Operational Runbooks

## 1. Connecting to the Database via Bastion

Since the RDS instance is in an isolated subnet, you cannot connect to it from your local machine directly.

**Alternative via ECS Exec (Recommended):**
1. Ensure the AWS CLI and Session Manager Plugin are installed.
2. Jump into a running WordPress task:
   ```bash
   aws ecs execute-command --cluster wp-cluster-prod \
       --task <task_id> \
       --container wordpress \
       --interactive \
       --command "/bin/bash"
   ```
3. Use the `mysql` CLI directly from inside the container.

## 2. Forcing a Deployment / Container Refresh

If you updated the WordPress docker image tag or need to roll application changes:

```bash
aws ecs update-service --cluster wp-cluster-prod \
    --service wp-service-prod \
    --force-new-deployment
```

## 3. Retrieving the Database Password

The Master User password is auto-managed by AWS Secrets Manager.

```bash
aws secretsmanager get-secret-value \
    --secret-id <wp-rds-master-user-secret-arn> \
    --query SecretString \
    --output text
```

## 4. Manual Failover (RDS)

To test high-availability failover in production:
```bash
aws rds reboot-db-instance --db-instance-identifier wp-rds-prod --force-failover
```
