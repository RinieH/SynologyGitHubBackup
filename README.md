# Synology GitHub Backup

A simple, safe, and fully self-contained GitHub backup solution for Synology NAS.

This solution mirrors all repositories from your personal GitHub account to a shared folder on your Synology. It performs read-only operations and never writes back to GitHub.

It is designed to run as a Scheduled Task in DSM without external dependencies beyond Git and standard system tools.

<img width="1632" height="640" alt="image" src="https://github.com/user-attachments/assets/59ce5f89-097b-42c2-a24f-445390193e54" />

---

## What This Script Does

- Fetches all repositories from your personal GitHub account  
- Mirrors each repository using `git clone --mirror`  
- Updates repositories on subsequent runs using `git fetch --all --prune`  
- Stores repositories in a dedicated Synology shared folder  
- Optionally creates readable working copies of your repositories  
- Writes a detailed log file  
- Tracks the last successful run  

---

## What Is Backed Up

- Full Git history  
- All branches  
- All tags  
- All refs  

---

## What Is Not Backed Up

- Issues  
- Pull requests  
- GitHub Actions logs  
- Repository settings  

This is a Git-level backup, not a full GitHub platform export.

---

# Requirements

## 1. Install Git Server

Open DSM → Package Center → Install **Git Server**

Git Server installs the required Git binary. You do not need to configure it as a Git hosting server.

---

## 2. Enable SSH (One Time Only)

Go to:

Control Panel → Terminal & SNMP → Enable SSH

SSH is required once to verify that Git is installed correctly (`git --version`).

After setup is complete, SSH can be disabled again.

---

## 3. Create a Dedicated Shared Folder

Create a new shared folder, for example:

Github Backups

Keeping backups in a dedicated share makes protection and versioning easier.

---

# Creating a GitHub Token

Create a **Classic Personal Access Token**:

GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (Classic)

Required scope:

repo

No additional scopes are required.

If your repositories are inside an organization, ensure the token is approved for that organization.

---

# Installing the Script

Open:

DSM → Control Panel → Task Scheduler

Create:

Create → Scheduled Task → User-defined script

Run the task as a user that has write access to the shared folder.

Paste the full backup script into the Run command field.

Configure:

- TOKEN → Your GitHub Personal Access Token  
- BACKUP_SHARE → Your Synology shared folder path  
- WORKING_MODE → Optional working copy behavior  

Example:

/volume1/Github Backups

Make sure the path matches exactly what File Station shows.

---

# Working Copy Modes (Optional)

The script supports three modes:

## WORKING_MODE="none"  (Default)

Mirror backup only.

- Stores only `.git` mirror repositories  
- Most storage efficient  
- Recommended for pure backup scenarios  

Use this if:

- You only care about disaster recovery  
- You want the smallest storage footprint  
- You are comfortable using Git to restore  

---

## WORKING_MODE="default"

Creates one readable working copy per repository on the default branch (usually `main`).

Structure:

Github Backups/
  repos/
  working/
    owner/
      repo/
        (actual source files)

Use this if:

- You want easy file browsing in File Station  
- You only need the default branch  
- You want minimal duplication  

Recommended for most users who want convenience without large storage growth.

---

## WORKING_MODE="all"

Creates a subdirectory per branch using Git worktrees.

Structure:

Github Backups/
  working/
    owner/
      repo/
        _repo/
        branches/
          main/
          dev/
          feature-x/

Use this if:

- You need file-level access to every branch  
- You want full branch visibility without Git commands  
- Storage usage is not a concern  

Warning:

This mode consumes more disk space on repositories with many branches.

---

# Scheduling

Set the schedule to run daily during low activity hours.

Optionally enable email notifications for failures.

---

# Logging

The script creates:

Github Backups/logs/github-backup.log  
Github Backups/logs/last-run.txt  

These show:

- What was cloned  
- What was updated  
- When the last run completed  
- Whether any errors occurred  

---

# Versioning and Protection

The script maintains a current mirror of each repository. It does not create historical versions of the backup set.

For proper protection, use Synology’s built-in features.

---

## Snapshot Replication (Recommended)

If your volume uses Btrfs:

Enable scheduled snapshots for the shared folder.

Benefits:

- Point-in-time recovery  
- Fast restore  
- Protection against accidental deletion  
- Protection against ransomware  

Recommended baseline:

- Daily snapshots  
- 30-day retention  

---

## Hyper Backup

Use Hyper Backup to protect the shared folder to:

- Another NAS  
- External USB disk  
- Synology C2  
- Other supported cloud providers  

Recommended strategy:

Mirror → Snapshots → Hyper Backup

This gives you:

- Local restore capability  
- Version history  
- Off-device protection  

---

# Verifying Your Backup Locally

To confirm the `.git` mirror contains everything:

## Step 1: Copy a Mirror Repository

From File Station, copy:

\\NAS-NAME\Github Backups\repos\owner\repo.git

to your local machine, for example:

C:\Temp\repo.git

---

## Step 2: Inspect the Mirror

Open PowerShell or Git Bash:

git --git-dir "C:\Temp\repo.git" show-ref --heads

List tags:

git --git-dir "C:\Temp\repo.git" tag

View history:

git --git-dir "C:\Temp\repo.git" log --oneline --all

If branches and commits appear correctly, your backup is complete.

---

## Step 3: Create a Working Copy (Optional)

cd C:\Temp  
git clone "C:\Temp\repo.git" repo  
cd repo  
git branch -a  

Switch branches:

git checkout dev

If files appear correctly, your backup is fully restorable.

---

# Cleanup

After testing, you can safely delete the copied `.git` folder and the test working directory from your local machine. This does not affect the backup stored on your Synology.
