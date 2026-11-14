#!/usr/bin/env bash
# Copy this checkout's skills into the installed (global) location.
#
#     tools/deploy.sh --dry-run
#     tools/deploy.sh
#
# Use this instead of `npx skills add` for these skills: the installer
# materializes its own copy in ~/.agents/skills and records a lock entry whose
# upstream hashes no longer match your edits. A running agent picks up file
# changes on the next load; no restart is needed.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST=${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

python3 "$REPO_ROOT/tools/validate-skills.py" >/dev/null || {
  echo "error: the checkout does not validate; fix it before deploying" >&2
  exit 1
}

mkdir -p "$DEST"
changed=0
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  target="$DEST/$name"

  if [ -L "$target" ]; then
    echo "skip    $name is a link to $(readlink "$target") — already the same files"
    continue
  fi
  if [ -d "$target" ] && diff -rq "$target" "$dir" >/dev/null 2>&1; then
    printf 'same    %s\n' "$name"
    continue
  fi

  changed=1
  printf 'deploy  %s -> %s\n' "$name" "$target"
  rsync -a --delete --dry-run --itemize-changes "$dir" "$target/" | sed 's/^/          /'
  if [ "$DRY_RUN" -eq 0 ]; then
    rsync -a --delete "$dir" "$target/"
  fi
done

if [ "$changed" -eq 0 ]; then
  echo "nothing to deploy"
elif [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "dry run: re-run without --dry-run to apply"
else
  echo
  echo "deployed. commit with 'make release VERSION=x.y.z' when the change is worth publishing."
fi
