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
HEARTBEAT_FILE="${LOG_DIR}/heartbeat.txt"

GIT="/usr/bin/git"
PER_PAGE=100

# Working copy mode:
#   none    -> mirror only
#   default -> one working copy per repo on default branch
WORKING_MODE="none"

# Space separated list of repos to exclude completely (owner/repo)
# Example: EXCLUDE_REPOS="ORG/Big_repoA ORG/Big_repoB"
EXCLUDE_REPOS=""
### END CONFIG ###

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false

mkdir -p "$REPOS_DIR" "$LOG_DIR"
[ "$WORKING_MODE" = "none" ] || mkdir -p "$WORK_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
epoch() { date '+%s'; }

log() {
  echo "[$(ts)] $*" | tee -a "$LOG_FILE"
}

heartbeat() {
  echo "[$(ts)] $*" > "$HEARTBEAT_FILE"
}

should_exclude_repo() {
  case " $EXCLUDE_REPOS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

run_git() {
  label="$1"
  shift
  start="$(epoch)"
  log "GIT start  ${label} :: $GIT $*"
  heartbeat "RUNNING ${label}"
  "$GIT" "$@" >>"$LOG_FILE" 2>&1
  rc=$?
  end="$(epoch)"
  dur=$((end-start))
  log "GIT end    ${label} rc=${rc} dur=${dur}s"
  heartbeat "DONE ${label} rc=${rc} dur=${dur}s"
  return $rc
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
    log "WORK init ${full_name} (${default_branch})"
    run_git "work.clone ${full_name}" clone "$mirror_git_dir" "$wd"
  else
    log "WORK exists ${full_name} (${default_branch})"
  fi

  # Ensure working copies never fetch from GitHub: origin points to local mirror
  run_git "work.set-origin ${full_name}" -C "$wd" remote set-url origin "$mirror_git_dir"
  run_git "work.fetch ${full_name}" -C "$wd" fetch --all --prune

  run_git "work.checkout ${full_name}" -C "$wd" checkout -f "$default_branch" || \
  run_git "work.checkout-create ${full_name}" -C "$wd" checkout -f -B "$default_branch" "origin/$default_branch"

  run_git "work.reset ${full_name}" -C "$wd" reset --hard "origin/$default_branch"
}

START_TS="$(ts)"
log "===== GitHub backup start (user $(whoami)) ====="
log "Target mirrors: $REPOS_DIR"
log "Working mode: $WORKING_MODE"
log "Exclude repos: ${EXCLUDE_REPOS:-<none>}"
heartbeat "STARTED"

PAGE=1

while : ; do
  log "Fetching page ${PAGE}"
  heartbeat "Fetching page ${PAGE}"

  RESP="$(api_get_repos_page "$PAGE")"

  echo "$RESP" | jq -e 'type=="array"' >/dev/null 2>&1 || {
    log "ERROR GitHub API did not return a repo list"
    echo "$RESP" | tee -a "$LOG_FILE"
    echo "FAILED $(ts)" > "$LAST_RUN_FILE"
    heartbeat "FAILED API"
    exit 1
  }

  COUNT="$(echo "$RESP" | jq 'length')"
  log "Page ${PAGE} repo count: ${COUNT}"
  [ "$COUNT" -eq 0 ] && break

  echo "$RESP" | jq -r '.[] | "\(.full_name)|\(.default_branch)"' \
    | while IFS='|' read -r FULL_NAME DEFAULT_BRANCH
      do
        [ -n "$FULL_NAME" ] || continue

        if should_exclude_repo "$FULL_NAME"; then
          log "SKIP excluded ${FULL_NAME}"
          continue
        fi

        TARGET="${REPOS_DIR}/${FULL_NAME}.git"
        URL="https://${TOKEN}@github.com/${FULL_NAME}.git"
        mkdir -p "$(dirname "$TARGET")"

        if [ -d "$TARGET" ]; then
          log "MIRROR update ${FULL_NAME}"
          run_git "mirror.set-origin ${FULL_NAME}" -C "$TARGET" remote set-url origin "$URL" || true
          run_git "mirror.fetch ${FULL_NAME}" -C "$TARGET" fetch --all --prune
        else
          log "MIRROR clone  ${FULL_NAME}"
          run_git "mirror.clone ${FULL_NAME}" clone --mirror "$URL" "$TARGET"
        fi

        if [ "$WORKING_MODE" = "default" ]; then
          ensure_working_default "$FULL_NAME" "$DEFAULT_BRANCH" "$TARGET"
        fi
      done

  PAGE=$((PAGE+1))
done

END_TS="$(ts)"
log "===== GitHub backup end ====="
echo "OK $END_TS" > "$LAST_RUN_FILE"
heartbeat "OK $END_TS"
