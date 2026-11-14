#!/usr/bin/env bash
# Pull edits made in the installed (global) copy back into this checkout.
#
#     tools/sync-from-global.sh --dry-run     # report only
#     tools/sync-from-global.sh               # apply
#
# The installed copy wins: files that exist only in the checkout are removed so
# the two trees match, and every deletion is printed first ("*deleting" lines).
# Nothing is committed.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC=${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ ! -d "$SRC" ]; then
  echo "error: no installed skills at $SRC" >&2
  exit 1
fi

changed=0
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  installed="$SRC/$name"

  if [ -L "$installed" ]; then
    echo "skip    $name is a link to $(readlink "$installed") — edits already land in the checkout"
    continue
  fi
  if [ ! -d "$installed" ]; then
    printf 'skip    %s is not installed in %s\n' "$name" "$SRC"
    continue
  fi
  if diff -rq "$installed" "$dir" >/dev/null 2>&1; then
    printf 'same    %s\n' "$name"
    continue
  fi

  changed=1
  printf 'update  %s\n' "$name"
  rsync -a --delete --dry-run --itemize-changes "$installed/" "$dir" | sed 's/^/          /'

  if [ "$DRY_RUN" -eq 0 ]; then
    rsync -a --delete "$installed/" "$dir"
  fi
done

if [ "$changed" -eq 0 ]; then
  echo "nothing to sync"
  exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "dry run: re-run without --dry-run to apply"
  exit 0
fi

echo
python3 "$REPO_ROOT/tools/validate-skills.py"
echo
echo "--- git status ---"
git -C "$REPO_ROOT" status --short
echo
echo "next: review the diff, add a CHANGELOG entry, then make release VERSION=x.y.z"
