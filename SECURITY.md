# Security Policy

## Supported Versions

Currently, the following versions are supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## DevSecOps Integration

This CI/CD pipeline enforces several security best practices automatically:

1. **Secret Scanning:** All commits are scanned using `gitleaks` to prevent hardcoded credentials, API keys, or tokens from entering the repository.
2. **Dependency Scanning:** The pipeline uses `Snyk` to scan Node.js and .NET dependencies for known CVEs (Common Vulnerabilities and Exposures). Builds will fail if `CRITICAL` vulnerabilities are detected.
3. **Authentication:** CI/CD runners authenticate with production environments using SSH Key Pairs. Password-based authentication is strictly prohibited.
4. **Secret Management:** Sensitive variables (like SSH Keys, API tokens, and Webhooks) must be stored in **Bitbucket Secured Repository Variables** and must never be committed to source control.

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability within this repository or the pipeline infrastructure, please report it immediately.

**Do not file a public issue.**

Instead, please send an email to `security@yourdomain.com` (replace with your actual security contact). Include the following information:

*   Description of the vulnerability.
*   Steps to reproduce the issue.
*   Potential impact.

We will acknowledge receipt of your vulnerability report within 48 hours and strive to send you regular updates about our progress.

## Infrastructure Security (EC2 / IIS)

When implementing this pipeline on your own infrastructure, ensure the following:

*   **Network Security:** Limit inbound SSH (Port 22) access to Bitbucket's official IP ranges (see Atlassian documentation). Do not expose SSH to `0.0.0.0/0`.
*   **Web Deploy Security:** Use non-administrator accounts with delegated permissions for MSDeploy when possible, rather than using the root Administrator account.
*   **TLS/SSL:** Ensure IIS is configured to serve the application over HTTPS and redirect HTTP traffic.
