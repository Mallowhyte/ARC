# Supabase Backup Strategy (Free Tier)

> **Goal:** Maintain reliable backups of Supabase database and storage without upgrading to the Pro plan.

---

## 📋 Overview

This guide covers three low-cost backup approaches you can combine for redundancy:

| Strategy | What It Covers | Frequency | Cost | Notes |
|----------|----------------|-----------|------|-------|
| Manual `pg_dump` | Full PostgreSQL database | Ad hoc / weekly | Free | Run from local machine using Supabase connection credentials |
| Automated Script + Windows Task Scheduler | Full PostgreSQL database | Daily | Free | Uses `pg_dump` + batch/PowerShell script to run on Windows host |
| GitHub Actions (Optional) | Full database + encryption | Daily | Free | Requires GitHub repo and Supabase service role key stored as secret |

Supabase storage (files) backups are handled separately (see [Storage Backups](#storage-backups)).

---

## ✅ Prerequisites

1. **Supabase Project Credentials** (Dashboard → Project Settings → Database)
   - `Host` (e.g., `db.your-project.supabase.co`)
   - `Port` (default `5432`)
   - `Database` (typically `postgres`)
   - `User` (`postgres`)
   - `Password` (generate new if needed)

2. **Supabase Service Role Key** (Dashboard → Project Settings → API)
   - Needed only for GitHub Actions or backup scripts running outside your trusted network.
   - Treat as secret; never commit to git.

3. **PostgreSQL Client Tools** installed locally
   - Download from https://www.postgresql.org/download/windows/
   - Ensure `pg_dump` is available in PATH (e.g., `C:\Program Files\PostgreSQL\16\bin`).

---

## 🛠️ Strategy 1: Manual `pg_dump`

Run the following command from Windows PowerShell or CMD when you want to create a backup manually.

```powershell
# Replace placeholders with your Supabase credentials
set PGPASSWORD="<SUPABASE_DB_PASSWORD>"

pg_dump -h db.your-project.supabase.co ^
        -p 5432 ^
        -U postgres ^
        -d postgres ^
        -F c ^
        -f "C:\Backups\arc_backup_%date:~10,4%-%date:~4,2%-%date:~7,2%.dump"
```

**Explanation:**
- `-F c` generates a compressed custom-format dump (smaller + can restore specific tables).
- File name includes current date for versioned backups.

**Restore Command:**
```powershell
set PGPASSWORD="<SUPABASE_DB_PASSWORD>"

pg_restore -h db.your-project.supabase.co ^
           -p 5432 ^
           -U postgres ^
           -d postgres ^
           -c ^
           "C:\Backups\arc_backup_2024-11-13.dump"
```
- `-c` cleans (drops) existing database objects before restoring.
- Always test restores on a staging project first.

---

## 🔁 Strategy 2: Automated Backups (Windows Task Scheduler)

### Step 1: Create Backup Script

Save as `C:\Backups\scripts\backup_supabase.ps1`:

```powershell
param(
    [string]$BackupDir = "C:\Backups\supabase",
    [int]$RetentionDays = 14
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $BackupDir "arc_backup_$timestamp.dump"

# Ensure backup directory exists
if (!(Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

$env:PGPASSWORD = "<SUPABASE_DB_PASSWORD>"

$pgDumpPath = "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"

& $pgDumpPath `
  -h "db.your-project.supabase.co" `
  -p 5432 `
  -U "postgres" `
  -d "postgres" `
  -F c `
  -f $backupFile

if ($LASTEXITCODE -eq 0) {
    Write-Output "Backup successful: $backupFile"
} else {
    Write-Error "Backup failed with exit code $LASTEXITCODE"
}

# Retention policy
Get-ChildItem $BackupDir -Filter "*.dump" | Where-Object {
    $_.CreationTime -lt (Get-Date).AddDays(-$RetentionDays)
} | Remove-Item -Force
```

- Replace `<SUPABASE_DB_PASSWORD>` with actual password (or load from encrypted file/Windows Credential Manager).
- Adjust paths if PostgreSQL installed elsewhere.
- Retention default = 14 days (change if needed).

### Step 2: Schedule Daily Task

1. Open **Task Scheduler** → Create Task.
2. **General tab:**
   - Name: `Supabase Daily Backup`
   - "Run whether user is logged on or not"
   - Check "Run with highest privileges".
3. **Triggers tab:**
   - New → Daily → Set time (e.g., 2:00 AM).
4. **Actions tab:**
   - New → Start a program → Program/script: `powershell.exe`
   - Add arguments: `-File "C:\Backups\scripts\backup_supabase.ps1"`
5. **Conditions tab:** Optionally uncheck "Start only if on AC power".
6. Save task → Enter Windows admin password.
7. Test run via **Run** to ensure success.

🛡️ *Security Tip:* Store the password in Windows Credential Manager and update script to fetch it via `Get-StoredCredential` (requires `CredentialManager` PowerShell module).

---

## ☁️ Strategy 3: GitHub Actions (Optional)

Automate nightly backups stored in GitHub artifacts or pushed to cloud storage.

### Step 1: Create GitHub Secret
- `SUPABASE_DB_PASSWORD` – Database password
- `SUPABASE_DB_HOST` – e.g., `db.your-project.supabase.co`
- `SUPABASE_DB_USER` – `postgres`
- `SUPABASE_DB_NAME` – `postgres`

### Step 2: Add Workflow `.github/workflows/supabase-backup.yml`

```yaml
name: Supabase Backup

on:
  schedule:
    - cron: "0 18 * * *"  # Daily at 02:00 AM PHT (18:00 UTC)
  workflow_dispatch:

jobs:
  backup:
    runs-on: ubuntu-latest

    steps:
      - name: Install PostgreSQL client
        run: sudo apt-get update && sudo apt-get install -y postgresql-client

      - name: Run pg_dump
        env:
          PGPASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
        run: |
          mkdir -p backups
          TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
          pg_dump \
            -h ${{ secrets.SUPABASE_DB_HOST }} \
            -p 5432 \
            -U ${{ secrets.SUPABASE_DB_USER }} \
            -d ${{ secrets.SUPABASE_DB_NAME }} \
            -F c \
            -f backups/arc_backup_$TIMESTAMP.dump

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: supabase-backup
          path: backups/arc_backup_*.dump
          retention-days: 7
```

- Backups stored as GitHub artifacts (max 7 days; increase if needed).
- For longer retention, add step to upload to AWS S3, Google Drive API, or Supabase Storage.

---

## 🗃️ Storage Backups

Supabase storage (documents) must be backed up separately.

### Option 1: Supabase Storage API (Python)

```python
from supabase import create_client
import os

url = "https://yoursupabaseproject.supabase.co"
key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
client = create_client(url, key)

bucket = "documents"

objects = client.storage.from_(bucket).list()

for obj in objects:
    file_path = obj["name"]
    data = client.storage.from_(bucket).download(file_path)
    local_path = os.path.join("backups", file_path)
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    with open(local_path, "wb") as f:
        f.write(data)
    print(f"Saved {file_path}")
```

- Run weekly or monthly depending on volume.
- Zip backups afterward for space savings.

### Option 2: Supabase CLI

1. Install CLI: `npm install -g supabase`
2. Login: `supabase login`
3. Sync Storage:
   ```bash
   supabase storage list --bucket documents
   supabase storage download documents ./storage-backups
   ```

---

## ♻️ Retention & Rotation

| Backup Type | Location | Retention | Notes |
|-------------|----------|-----------|-------|
| Manual `pg_dump` | Local PC | 30 days | Keep latest 4 weekly backups |
| Automated (Task Scheduler) | Local server/PC | 14 days | Encrypted drive recommended |
| GitHub Actions | GitHub artifact | 7 days | Export to local monthly |
| Storage Files | Local drive | 30–90 days | Compress with `.zip` |

🛡️ **Security Tips:**
- Store backups on encrypted drives (BitLocker or VeraCrypt).
- Do not commit backups to git.
- Limit access to backup folders to system admins.

---

## 🔁 Disaster Recovery Test (Quarterly)

1. Provision a new Supabase project (staging).
2. Restore latest database dump using `pg_restore`.
3. Upload sample storage files.
4. Run backend + Flutter app against staging environment.
5. Validate login, upload, classification, approvals.
6. Document results and fix any restoration issues.

---

## 📑 Record Keeping Template

Use this log to track backups:

| Date | Method | File Name | Location | Status |
|------|--------|-----------|----------|--------|
| 2024-11-13 | Task Scheduler | arc_backup_20241113.dump | C:\Backups\supabase | ✅ |
| 2024-11-20 | GitHub Action | arc_backup_20241120.dump | GitHub Artifact | ✅ |

Store this log in your internal ISO documentation folder.

---

## 🆘 Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `pg_dump` timeout | Large database / slow network | Add `--verbose`, increase timeout, run during off-hours |
| Authentication failure | Wrong password | Reset DB password in Supabase → Project Settings → Database |
| `pg_dump` not recognized | PostgreSQL tools not in PATH | Add `C:\Program Files\PostgreSQL\16\bin` to PATH |
| GitHub Action fails | Missing secrets | Add secrets under repo Settings → Secrets → Actions |
| Storage download fails | Service role key missing | Use `SUPABASE_SERVICE_ROLE_KEY` in script |

---

## 📚 Related Documentation

- [ISO_MIGRATION_GUIDE.md](ISO_MIGRATION_GUIDE.md)
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Last Updated:** November 2024  
**Maintainer:** ARC Dev Team
