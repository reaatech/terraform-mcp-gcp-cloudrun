# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of terraform-mcp-gcp-cloudrun seriously. If you believe you have found a security vulnerability, please report it to us as described below.

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them privately via [GitHub security advisories](https://github.com/reaatech/terraform-mcp-gcp-cloudrun/security/advisories/new), including:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

## Security Best Practices

When using this module, please follow these security best practices:

### 1. Secrets Management
- Never store secrets in Terraform state or variables
- Use Secret Manager for all sensitive values
- Rotate secrets regularly
- Use short-lived credentials when possible

### 2. IAM
- Follow the principle of least privilege
- Use separate service accounts per MCP server
- Never use user-managed service account keys
- Regularly audit IAM bindings

### 3. Network Security
- Use internal ingress for production services
- Enable VPC Service Controls for sensitive workloads
- Configure VPC connectors for private network access
- Use Private Service Connect for Google APIs

### 4. Infrastructure
- Enable delete protection on Firestore databases
- Enable point-in-time recovery for disaster recovery
- Set appropriate resource limits to prevent DoS
- Monitor and alert on unusual activity

### 5. Monitoring
- Enable Cloud Audit Logs
- Configure alert policies for security events
- Monitor access patterns and anomalies
- Regularly review Cloud Logging for suspicious activity

## Known Limitations

1. **Terraform State**: While we design to avoid secrets in state, ensure your remote state backend is properly secured with appropriate access controls.

2. **Container Images**: Always use pinned container image digests in production to prevent supply chain attacks.

3. **Cold Starts**: Scale-to-zero can introduce cold start latency. Consider setting min_instances=1 for production workloads.

## Security Updates

Security updates will be released as patch versions. Critical security fixes may result in immediate releases.

Subscribe to our release notifications to stay informed about security updates.

## Acknowledgments

We would like to thank the following for their contributions to our security:

- All security researchers who responsibly disclose vulnerabilities
- The Terraform community for their security guidance
- Google Cloud Security team for their best practices

## References

- [Google Cloud Security Best Practices](https://cloud.google.com/security/best-practices)
- [Terraform Security Best Practices](https://developer.hashicorp.com/terraform/tutorials/configuration-language/security)
- [OWASP Cloud Security](https://owasp.org/www-project-cloud-security/)
