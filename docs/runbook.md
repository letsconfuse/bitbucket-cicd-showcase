# CI/CD Deployment Runbook

This document serves as the operational guide for deploying, managing, and troubleshooting the Angular UI and .NET API via the Bitbucket CI/CD pipeline.

## 1. Environments

| Environment | Branch | Server URL | Auto-Deploy? | Trigger |
| :--- | :--- | :--- | :--- | :--- |
| **Staging** | `develop` | `https://staging.example.com` | Yes | Push to `develop` |
| **Staging (Pre-Prod)** | `main` | `https://staging.example.com` | Yes | Push to `main` |
| **Production** | `main` | `https://example.com` | No | Manual trigger in Bitbucket |

## 2. Standard Deployment Procedure (Production)

Production deployments are gated by manual triggers to ensure control over the release window, particularly for the API which incurs a brief (~15 second) downtime.

1.  **Merge to `main`:** Create a PR from `develop` to `main` and merge it.
2.  **Verify Staging:** The pipeline will automatically build and deploy the changes to the Staging environment.
3.  **Approve Production Release:**
    *   Navigate to **Bitbucket > Pipelines**.
    *   Locate the pipeline run for the `main` branch.
    *   Find the manual steps: `🚀 Deploy UI → Production` and `🚀 Deploy API → Production`.
    *   Click **Deploy** on the UI step first (Zero downtime).
    *   Click **Deploy** on the API step second (Brief downtime).
4.  **Monitor Slack:** Ensure the Slack channel receives the `✅ Production Deployed Successfully` notification.

## 3. Incident Management & Rollback Strategy

If a deployment fails the automated smoke tests, or if a critical bug is discovered immediately post-deployment, follow the rollback procedure.

### Instant Rollback (N-1)

The pipeline automatically archives the previous working directory (`C:\releases\ui\` and `C:\releases\api\`) before applying new changes.

1.  Navigate to **Bitbucket > Pipelines**.
2.  Click **Run pipeline**.
3.  Select the `main` branch.
4.  Under **Pipeline**, choose **Custom**.
5.  Select `rollback-ui-production` or `rollback-api-production`.
6.  Click **Run**.
7.  The N-1 version will be restored within seconds.

### Troubleshooting Failed Deployments

*   **Error: App Pool failed to start.**
    *   *Cause:* The newly deployed API code is crashing on startup (e.g., bad configuration in `appsettings.json`, missing dependencies).
    *   *Action:* Trigger `rollback-api-production`. Log into the server, check the **Windows Event Viewer (Application Log)** or the IIS `stdout` logs for the specific .NET exception.
*   **Error: MSDeploy file lock error.**
    *   *Cause:* The app pool wasn't stopped in time, or another process is holding a `.dll` open.
    *   *Action:* Re-run the deployment pipeline. The script is idempotent.
*   **Pipeline hangs during SSH/SCP.**
    *   *Cause:* The Bitbucket runner cannot reach the EC2 instance, or the SSH key is rejected.
    *   *Action:* Verify the EC2 Security Group allows Port 22 traffic from Bitbucket IPs. Check the `known_hosts` configuration.

## 4. Pipeline Variables Configuration

The pipeline requires specific repository variables to function. Ensure these are configured in **Repository settings > Repository variables**.

### Required Secure Variables (Must be masked)
*   `SLACK_WEBHOOK_URL`
*   `SNYK_TOKEN`

*(Refer to `bitbucket-pipelines.yml` header for the complete list of required environment variables).*
