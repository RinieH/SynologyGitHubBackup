# Synology GitHub Backup

A simple, safe, and fully self-contained GitHub backup script for Synology NAS.

This solution mirrors all repositories from your personal GitHub account to a shared folder on your Synology. It performs read-only operations and never writes back to GitHub.

It is designed to run as a Scheduled Task in DSM without external dependencies beyond Git and standard system tools.

---

## What This Script Does

- Fetches all repositories from your personal GitHub account  
- Mirrors each repository using `git clone --mirror`  
- Updates repositories on subsequent runs using `git fetch --all --prune`  
- Stores repositories in a dedicated Synology shared folder  
- Writes a detailed log file  
- Tracks the last successful run  

### What Is Backed Up

- Full Git history  
- All branches  
- All tags  
- All refs  

### What Is Not Backed Up

- Issues  
- Pull requests  
- GitHub Actions logs  
- Repository settings  

This is a Git mirror backup, not a full GitHub platform export.

---

## Requirements

### 1. Install Git Server

Open DSM → Package Center → Install **Git Server**

Git Server installs the required Git binary. You do not need to configure it as a Git hosting server.

---

### 2. Enable SSH (One Time Only)

Go to:

Control Panel → Terminal & SNMP → Enable SSH

SSH is required once to verify that Git is installed correctly (`git --version`).

After setup is complete, SSH can be disabled again.

---

### 3. Create a Dedicated Shared Folder

Create a new shared folder, for example:
Github Backups


Keeping backups in a dedicated share makes protection and versioning easier.

---

## Creating a GitHub Token

Create a **Classic Personal Access Token**:

GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (Classic)

Required scope:
repo

No additional scopes are required.

If your repositories are inside an organization, ensure the token is approved for that organization.

---

## Installing the Script

Open:

DSM → Control Panel → Task Scheduler

Create:

Create → Scheduled Task → User-defined script

Run the task as a user that has write access to the shared folder.

Paste the full backup script into the **Run command** field.

Configure:

- `TOKEN` → Your GitHub Personal Access Token  
- `BACKUP_SHARE` → Your Synology shared folder path  

Example:
/volume1/Github Backups

Make sure the path matches exactly what File Station shows.

---

## Scheduling

Set the schedule to run daily during low activity hours.

Optionally enable email notifications for failures.

---

## Logging

The script creates:
/Github Backups/logs/github-backup.log
/Github Backups/logs/last-run.txt

You can open these directly in File Station to see:

- What was cloned
- What was updated
- When the last run completed
- Whether any errors occurred

---

## Does It Write Back to GitHub?

No.

The script only performs:

- `git clone --mirror`
- `git fetch --all --prune`
- GitHub API read operations

There are no push operations.

---

## Versioning and Protection

The script maintains a current mirror of each repository. It does not create historical versions of the backup set.

For proper protection, use Synology’s built-in features.

---

### Option 1: Snapshot Replication (Recommended)

If your volume uses Btrfs:

Enable scheduled snapshots for the shared folder.

Benefits:

- Point-in-time recovery  
- Fast restore  
- Protection against accidental deletion  
- Protection against ransomware  

A common baseline:

- Daily snapshots  
- 30-day retention  

---

### Option 2: Hyper Backup

Use Hyper Backup to protect the shared folder to:

- Another NAS  
- External USB disk  
- Synology C2  
- Other supported cloud providers  

You can combine snapshots and Hyper Backup for layered protection.

Recommended strategy:

Mirror → Snapshots → Hyper Backup

This gives you:

- Local restore capability  
- Version history  
- Off-device protection  

---

## Why Mirror Instead of ZIP?

`git clone --mirror` preserves:

- All branches  
- All tags  
- All refs  
- Full history  

This allows full restoration or migration to another Git host.

This is the same method recommended by GitHub for repository backups.

---

## Restoring a Repository

To restore to GitHub or another Git host:
git clone --mirror repo.git
git push --mirror NEW_REMOTE

---

## Recommended Folder Structure
Github Backups/
repos/
username/repo.git
logs/
github-backup.log
last-run.txt

---

## Security Notes

- Your GitHub token is stored inside the scheduled task configuration  
- Restrict access to DSM administrator accounts  
- Limit permissions on the backup shared folder  
- Disable SSH after setup if not needed  

For higher security, consider using a fine-grained token limited to repository read access only.

---

## Final Notes

This solution keeps your Git data local, versionable, and under your control.

For full resilience:

Mirror locally  
Enable snapshots  
Protect off-device with Hyper Backup  

That combination gives you practical, production-grade protection for your GitHub repositories.
