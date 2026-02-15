#!/bin/sh
set -eu

TOKEN="PASTE_YOUR_GITHUB_TOKEN_HERE"
BACKUP_SHARE="/volume1/Github Backups"
REPOS_DIR="${BACKUP_SHARE}/repos"
LOG_DIR="${BACKUP_SHARE}/logs"
LOG_FILE="${LOG_DIR}/github-backup.log"
LAST_RUN_FILE="${LOG_DIR}/last-run.txt"
GIT="/usr/bin/git"
PER_PAGE=100

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false

mkdir -p "$REPOS_DIR" "$LOG_DIR"

TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[$TS] ===== GitHub backup start (user $(whoami)) =====" | tee -a "$LOG_FILE"
echo "[$TS] Target: $REPOS_DIR" | tee -a "$LOG_FILE"

PAGE=1

while : ; do
  API_URL="https://api.github.com/user/repos?type=all&per_page=${PER_PAGE}&page=${PAGE}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fetching page ${PAGE}" | tee -a "$LOG_FILE"

  RESP="$(curl -sS -H "Authorization: token ${TOKEN}" "${API_URL}")"

  echo "$RESP" | jq -e 'type=="array"' >/dev/null 2>&1 || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR GitHub API did not return a repo list" | tee -a "$LOG_FILE"
    echo "$RESP" | tee -a "$LOG_FILE"
    echo "FAILED $(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_RUN_FILE"
    exit 1
  }

  COUNT="$(echo "$RESP" | jq 'length')"
  [ "$COUNT" -eq 0 ] && break

  echo "$RESP" | jq -r '.[] | .full_name' | while read -r REPO
  do
    TARGET="${REPOS_DIR}/${REPO}.git"
    URL="https://${TOKEN}@github.com/${REPO}.git"

    mkdir -p "$(dirname "$TARGET")"

    if [ -d "$TARGET" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] UPDATE  ${REPO}" | tee -a "$LOG_FILE"
      "$GIT" -C "$TARGET" fetch --all --prune >>"$LOG_FILE" 2>&1 || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR updating ${REPO}" | tee -a "$LOG_FILE"
        exit 1
      }
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] CLONE   ${REPO}" | tee -a "$LOG_FILE"
      "$GIT" clone --mirror "$URL" "$TARGET" >>"$LOG_FILE" 2>&1 || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR cloning ${REPO}" | tee -a "$LOG_FILE"
        exit 1
      }
    fi
  done

  PAGE=$((PAGE+1))
done

END_TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[$END_TS] ===== GitHub backup end =====" | tee -a "$LOG_FILE"
echo "OK $END_TS" > "$LAST_RUN_FILE"
