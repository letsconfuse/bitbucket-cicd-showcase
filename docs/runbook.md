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

## 5. Linux Deployment Procedure

The Linux pipeline (`linux/bitbucket-pipelines.yml`) mirrors the Windows process but targets a Linux environment using Nginx and systemd.

1. **Merge to `main`:** Create a PR from `develop` to `main` and merge it.
2. **Verify Staging:** The pipeline automatically deploys to Linux Staging.
3. **Approve Production Release:**
   * Locate the pipeline run in Bitbucket.
   * Trigger the manual Linux deployment steps for UI (Nginx) and API (systemd).
4. **Troubleshooting Linux:**
   * UI issues: Check Nginx logs (`/var/log/nginx/error.log`).
   * API issues: Check systemd service status (`systemctl status zentixs-api` and `journalctl -u zentixs-api`).

## 6. DevSecOps Gate Failures

The pipeline incorporates DevSecOps tools to prevent insecure code from being deployed.

* **Gitleaks Failure:**
  * *Cause:* A secret (e.g., API key, token) was detected in the commit history.
  * *Action:* DO NOT simply delete the file and commit again. The secret must be scrubbed from the git history completely, and any leaked credentials must be revoked and rotated immediately.
* **Snyk Failure:**
  * *Cause:* Vulnerabilities found in open-source dependencies (npm packages, NuGet).
  * *Action:* Review the Snyk report in the pipeline logs. Update the vulnerable dependencies to the recommended patched versions, test locally, and push the fix.

## 7. Database Deployment Procedure (DACPAC)

Database changes are managed via DACPAC files, providing declarative schema management.

1. **Dry Run (Staging & Prod):** Before applying any changes, the pipeline runs a "Dry Run" which generates T-SQL migration scripts as artifacts (`sql_scripts/**`).
2. **Review:** DBAs or lead engineers should download and review the migration scripts to ensure no destructive changes are made unexpectedly.
3. **Execution:** The deployment step runs `sqlpackage` against all target databases concurrently.
4. **Safety Gates:** The deployment enforces `BlockOnPossibleDataLoss=True`, failing the pipeline if data loss is suspected.
5. **Failures:** If a database fails to deploy, the pipeline logs the error in `/tmp/failed.log` and exits. Inspect the logs for the specific SQL Server error and correct the DACPAC definition in the source repository.
