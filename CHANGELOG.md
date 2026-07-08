# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Security & Quality Gates:** Added `gitleaks` for secret scanning, `snyk` for dependency vulnerability scanning, and robust Angular linting/testing steps in the pipeline.
- **Rollback Strategy:** Implemented `rollback_ui.ps1` and `rollback_api.ps1` for immediate N-1 recovery in production environments. Added backup directory pruning (keeps last 3 releases).
- **Environment Promotion:** Added explicit `develop` (Staging) and `main` (Production) branch mapping to support a multi-environment workflow.
- **Slack Notifications:** Configured rich Slack webhooks for deployment success and failure alerts.
- **Smoke Tests:** Created `tests/smoke-test.sh` for robust HTTP health checks with retries and timeouts after deployments.
- **YAML DRY Principles:** Refactored `bitbucket-pipelines.yml` to use YAML anchors (`&` and `*`) and the `definitions` block, significantly reducing code duplication.
- **SECURITY.md:** Added security policies outlining secret management, vulnerability reporting, and infrastructure security.
- **Docs/Runbook:** Added `docs/runbook.md` detailing operational procedures for deployments and rollbacks.

### Changed
- **Authentication Strategy:** Replaced insecure `sshpass` password authentication with industry-standard SSH key authentication for all SCP and SSH commands.
- **.NET Version:** Upgraded API build environment from .NET 6 (EOL) to .NET 8 LTS.
- **Pipeline Structure:** Transitioned from a single `cicd-pipeline` branch approach to a standard Trunk-based/GitFlow compatible pipeline configuration.

### Removed
- Legacy single-branch pipeline configuration (`cicd-pipeline`), although the manual trigger logic is preserved for backward compatibility.

## [1.0.0] - Initial Showcase Release
### Added
- Working MSDeploy (Web Deploy) integration via SSH for zero-downtime Angular deployments and minimal-downtime .NET deployments.
- Basic PowerShell deployment scripts (`deploy_ui.ps1`, `deploy_api.ps1`).
- `README.md` with initial architecture explanation.
