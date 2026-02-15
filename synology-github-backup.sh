#!/bin/sh
set -eu

### CONFIG ###
TOKEN="PASTE_YOUR_GITHUB_TOKEN_HERE"

BACKUP_SHARE="/volume1/Github Backups"
REPOS_DIR="${BACKUP_SHARE}/repos"
WORK_DIR="${BACKUP_SHARE}/working"
LOG_DIR="${BACKUP_SHARE}/logs"
LOG_FILE="${LOG_DIR}/github-backup.log"
LAST_RUN_FILE="${LOG_DIR}/last-run.txt"

GIT="/usr/bin/git"
PER_PAGE=100

# Working copy mode:
#   none    -> mirror only (default)
#   default -> create/update one working copy on the repo default branch
#   all     -> create/update a subdirectory per branch (uses git worktrees)
WORKING_MODE="none"
### END CONFIG ###

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false

mkdir -p "$REPOS_DIR" "$LOG_DIR"
[ "$WORKING_MODE" = "none" ] || mkdir -p "$WORK_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
  echo "[$(ts)] $*" | tee -a "$LOG_FILE"
}

api_get_repos_page() {
  page="$1"
  curl -sS -H "Authorization: token ${TOKEN}" \
    "https://api.github.com/user/repos?type=all&per_page=${PER_PAGE}&page=${page}"
}

ensure_working_default() {
  full_name="$1"
  default_branch="$2"
  mirror_git_dir="$3"

  wd="${WORK_DIR}/${full_name}"
  mkdir -p "$(dirname "$wd")"

  if [ ! -d "$wd/.git" ]; then
    log "WORK default clone  ${full_name} (${default_branch})"
    "$GIT" clone "$mirror_git_dir" "$wd" >>"$LOG_FILE" 2>&1
  else
    log "WORK default update ${full_name} (${default_branch})"
  fi

  "$GIT" -C "$wd" fetch --all --prune >>"$LOG_FILE" 2>&1

  "$GIT" -C "$wd" checkout -f "$default_branch" >>"$LOG_FILE" 2>&1 \
    || "$GIT" -C "$wd" checkout -f -B "$default_branch" "origin/$default_branch" >>"$LOG_FILE" 2>&1

  "$GIT" -C "$wd" reset --hard "origin/$default_branch" >>"$LOG_FILE" 2>&1
}

ensure_working_all() {
  full_name="$1"
  default_branch="$2"
  mirror_git_dir="$3"

  repo_root="${WORK_DIR}/${full_name}"
  base_repo="${repo_root}/_repo"
  branches_root="${repo_root}/branches"

  mkdir -p "$base_repo" "$branches_root"

  if [ ! -d "$base_repo/.git" ]; then
    log "WORK all clone base ${full_name}"
    "$GIT" clone "$mirror_git_dir" "$base_repo" >>"$LOG_FILE" 2>&1
  fi

  "$GIT" -C "$base_repo" fetch --all --prune >>"$LOG_FILE" 2>&1
  "$GIT" -C "$base_repo" worktree prune >>"$LOG_FILE" 2>&1 || true

  "$GIT" -C "$base_repo" for-each-ref --format='%(refname:short)' refs/remotes/origin/ \
    | while read -r ref
      do
        [ -n "$ref" ] || continue
        [ "$ref" = "origin/HEAD" ] && continue

        branch="${ref#origin/}"
        wt_path="${branches_root}/${branch}"

        if [ -d "$wt_path/.git" ] || [ -d "$wt_path" ]; then
          log "WORK all update ${full_name} ${branch}"
          "$GIT" -C "$wt_path" checkout -f "$branch" >>"$LOG_FILE" 2>&1 \
            || "$GIT" -C "$wt_path" checkout -f -B "$branch" "origin/$branch" >>"$LOG_FILE" 2>&1
          "$GIT" -C "$wt_path" reset --hard "origin/$branch" >>"$LOG_FILE" 2>&1
        else
          log "WORK all add    ${full_name} ${branch}"
          mkdir -p "$(dirname "$wt_path")"
          "$GIT" -C "$base_repo" worktree add -f -B "$branch" "$wt_path" "origin/$branch" >>"$LOG_FILE" 2>&1
        fi
      done

  if [ -n "$default_branch" ] && [ -d "${branches_root}/${default_branch}" ]; then
    :
  fi
}

START_TS="$(ts)"
log "===== GitHub backup start (user $(whoami)) ====="
log "Target mirrors: $REPOS_DIR"
log "Working mode: $WORKING_MODE"

PAGE=1

while : ; do
  RESP="$(api_get_repos_page "$PAGE")"

  echo "$RESP" | jq -e 'type=="array"' >/dev/null 2>&1 || {
    log "ERROR GitHub API did not return a repo list"
    echo "$RESP" | tee -a "$LOG_FILE"
    echo "FAILED $(ts)" > "$LAST_RUN_FILE"
    exit 1
  }

  COUNT="$(echo "$RESP" | jq 'length')"
  [ "$COUNT" -eq 0 ] && break

  echo "$RESP" | jq -r '.[] | "\(.full_name)|\(.default_branch)"' \
    | while IFS='|' read -r FULL_NAME DEFAULT_BRANCH
      do
        [ -n "$FULL_NAME" ] || continue

        TARGET="${REPOS_DIR}/${FULL_NAME}.git"
        URL="https://${TOKEN}@github.com/${FULL_NAME}.git"
        mkdir -p "$(dirname "$TARGET")"

        if [ -d "$TARGET" ]; then
          log "MIRROR update ${FULL_NAME}"
          "$GIT" -C "$TARGET" remote set-url origin "$URL" >>"$LOG_FILE" 2>&1 || true
          "$GIT" -C "$TARGET" fetch --all --prune >>"$LOG_FILE" 2>&1
        else
          log "MIRROR clone  ${FULL_NAME}"
          "$GIT" clone --mirror "$URL" "$TARGET" >>"$LOG_FILE" 2>&1
        fi

        if [ "$WORKING_MODE" = "default" ]; then
          ensure_working_default "$FULL_NAME" "$DEFAULT_BRANCH" "$TARGET"
        elif [ "$WORKING_MODE" = "all" ]; then
          ensure_working_all "$FULL_NAME" "$DEFAULT_BRANCH" "$TARGET"
        fi
      done

  PAGE=$((PAGE+1))
done

END_TS="$(ts)"
log "===== GitHub backup end ====="
echo "OK $END_TS" > "$LAST_RUN_FILE"
