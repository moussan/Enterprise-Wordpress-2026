# Threat Model

## Assumptions
- The infrastructure is deployed entirely via Terraform.
- No public ingress is allowed directly to ECS or RDS instances.

| Threat | Vulnerability | Mitigation Strategy | Status |
|--------|--------------|---------------------|--------|
| **SQL Injection** | Malicious payload in user input (forms, search) | Use AWS WAF (`AWSManagedRulesCommonRuleSet` + `AWSManagedRulesWordPressRuleSet`) on the ALB to block known SQLi signatures. | ✅ Active |
| **DDoS Attacks** | High volume of HTTP/S requests targeted at ALB/CloudFront | AWS Shield Standard (enabled globally), CloudFront caching, WAF rate-limiting, and Auto Scaling rules on ECS. | ✅ Active |
| **Brute Force WP-Admin** | Attackers repeatedly guessing admin passwords | Use WAF to rate-limit `/wp-login.php`. Offload authentication to a robust plugin with 2FA. CloudFront behavior bypasses cache for wp-admin to ensure WAF inspection. | ✅ Active |
| **Data Exfiltration** | Database dumped via unauthorized access | RDS is in an isolated subnet. Security Groups only permit ECS execution role. No public IP. Master password managed implicitly. | ✅ Active |
| **Lateral Movement** | Attacker compromises one WordPress container and attacks another | Fargate containers run in `awsvpc` mode with isolated ENIs. Shared EFS has strictly defined POSIX UIDs. | ✅ Active |
| **Unencrypted Data Transfer** | Man-in-the-middle reading traffic | TLS 1.2+ minimum strictly enforced on ALB and CloudFront. EFS transit encryption enabled between ECS and EFS. | ✅ Active |
