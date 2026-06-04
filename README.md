# Bitbucket CI/CD Pipeline — Angular UI + .NET API → IIS on AWS EC2

A production-ready CI/CD pipeline for deploying an **Angular frontend** and **.NET 6 API** to **IIS on a Windows EC2 instance** using **MSDeploy (Web Deploy)** via Bitbucket Pipelines.

---

## Architecture Overview

```
Bitbucket Pipeline
│
├── Build Step (Linux runner)
│   ├── Angular → npm build → edge_publish_ui.zip
│   └── .NET 6  → dotnet publish → edge_publish_api.zip
│
├── SCP → Upload zip to EC2 Windows Server (C:\temp\)
├── SCP → Upload deploy.ps1 script to EC2
│
└── SSH → Execute deploy.ps1 on server
        └── MSDeploy sync → IIS wwwroot
```

---

## Downtime Characteristics

| Component | Downtime | Reason |
|---|---|---|
| Angular UI | ~0 seconds | MSDeploy writes files live; content-hashed filenames prevent stale cache |
| .NET API | ~10–30 seconds | App pool must stop to release `.dll` file locks before sync |

---

## Prerequisites

### On the EC2 Windows Server

1. **IIS** installed and configured with your site and app pool
2. **Web Deploy 3.5+** installed with full features:

   - Install with **Complete** option (not default/typical)
3. **OpenSSH Server** installed and running:
   ```powershell
   Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
   Start-Service sshd
   Set-Service -Name sshd -StartupType Automatic
   ```
4. **Port 22** open in EC2 Security Group for SSH/SCP
5. **`C:\temp`** directory exists on the server:
   ```powershell
   New-Item -ItemType Directory -Path "C:\temp" -Force
   ```

### Verify Web Deploy is working

```powershell
# Check MsDepSvc is running
Get-Service -Name MsDepSvc

# Verify MSDeploy can read your site path
& "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" `
  -verb:dump `
  -source:contentPath="C:\inetpub\wwwroot\your-site\wwwroot" `
  -verbose
```

---

## Bitbucket Repository Variables

Go to **Repository Settings → Repository Variables** and add:

| Variable | Example Value | Description |
|---|---|---|
| `REMOTE_USERNAME` | `administrator` | Windows login username |
| `REMOTE_PASSWORD` | `your-password` | Windows login password (mark as secured) |
| `REMOTE_SERVER_IP` | `13.233.x.x` | EC2 public or private IP |
| `IIS_UI_PHYSICAL_PATH` | `C:\inetpub\wwwroot\suite-edge\wwwroot` | Physical path of Angular site in IIS |
| `IIS_API_PHYSICAL_PATH` | `C:\inetpub\wwwroot\suite-edge\api` | Physical path of .NET API in IIS |
| `IIS_APP_POOL_NAME` | `suite-edge-pipeline` | IIS app pool name for the API |
| `IIS_SITE_NAME` | `suite-edge` | IIS site name |

> **Tip:** Mark `REMOTE_PASSWORD` as **Secured** in Bitbucket so it is masked in logs.

---

## Pipeline Structure

```
bitbucket-pipelines.yml         # Main pipeline definition
scripts/
  deploy_ui.ps1                 # PowerShell deploy script for Angular UI
  deploy_api.ps1                # PowerShell deploy script for .NET API
```

The pipeline:
1. **Generates** the PowerShell deploy scripts locally on the Linux runner
2. **Injects** Bitbucket variables into the scripts using `sed` (since `$env:` variables don't cross SSH sessions)
3. **Uploads** both the zip artifact and the `.ps1` script to the server via SCP
4. **Executes** the script remotely via SSH

---

## Files Protected from Overwrite

The following files on the server are **never overwritten** by MSDeploy, even if they exist in the build artifact:

| File | Reason |
|---|---|
| `web.config` | Contains server-specific IIS rewrite rules |
| `appsettings.json` | Contains environment-specific API configuration |
| `appsettings.*.json` | Environment-specific config overrides |
| `assets/configuration/appsetting.json` | Angular runtime configuration |

---

## How MSDeploy Differential Sync Works

Unlike a simple file copy, MSDeploy uses **checksum-based diffing**:

```
Build artifact (source)
        │
        ▼
MSDeploy compares checksums
        │
        ├── File unchanged → skip (no write)
        ├── File changed   → overwrite
        └── File new       → add
```

This means:
- Only **changed files** are written to disk
- The IIS site keeps **serving existing files** during the sync
- Angular's **content-hashed filenames** (`main.a1b2c3.js`) mean there is no moment where a browser gets a mismatched `index.html` and `.js` bundle

---

## Deployment Flow

### UI Deploy (automatic on push)
```
push to cicd-pipeline branch
    → npm install
    → ng build --configuration production
    → zip artifact
    → scp zip to C:\temp\
    → scp deploy_ui.ps1 to C:\temp\
    → ssh: powershell -File deploy_ui.ps1
        → Expand-Archive
        → msdeploy -verb:sync (skip web.config, appsetting.json)
        → cleanup temp files
```

### API Deploy (manual trigger)
```
manual trigger in Bitbucket
    → dotnet restore
    → dotnet publish -c Release
    → remove appsettings + web.config from artifact
    → zip artifact
    → scp zip to C:\temp\
    → scp deploy_api.ps1 to C:\temp\
    → ssh: powershell -File deploy_api.ps1
        → Expand-Archive
        → Stop-WebAppPool
        → msdeploy -verb:sync (skip appsettings*.json, web.config)
        → Start-WebAppPool
        → verify app pool state
        → cleanup temp files
```

---

## Troubleshooting

**SCP upload fails / zip not found on server**
```powershell
# Make sure C:\temp exists
New-Item -ItemType Directory -Path "C:\temp" -Force

# Check OpenSSH is running
Get-Service sshd
```

**MSDeploy skips not working**
```powershell
# Test skip rules manually on server
& "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" `
  -verb:sync `
  -source:contentPath="C:\temp\edge_publish_ui" `
  -dest:contentPath="C:\inetpub\wwwroot\your-site" `
  -skip:objectName=filePath,absolutePath='.*web\.config$' `
  -skip:objectName=filePath,absolutePath='.*appsetting\.json$' `
  -whatif `
  -verbose
```
> `-whatif` does a dry run — shows what would change without writing anything.

**App pool name is null / not found**
```powershell
# List all app pools and their physical paths
Get-WebApplication | Select-Object Path, ApplicationPool, PhysicalPath

# Check app pool state
Get-WebAppPoolState -Name "your-app-pool-name"
```

**PowerShell ExecutionPolicy blocking script**
```powershell
# On the server, allow remote signed scripts
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

---

## Security Notes

- Use **Bitbucket Secured Variables** for all credentials — they are masked in pipeline logs
- Consider replacing password auth with **SSH key pairs** for production
- Restrict EC2 Security Group port 22 to **Bitbucket's IP ranges** only
- The deploy scripts are deleted from `C:\temp\` after each run
