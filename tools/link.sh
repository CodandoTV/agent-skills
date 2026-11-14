#!/usr/bin/env bash
# Replace the installed copies with symlinks to this checkout.
#
#     tools/link.sh
#
# After this, editing ~/.agents/skills/<name>/SKILL.md edits the repository file:
# there is nothing to sync, and `make drift` stays quiet by construction. The
# DSH skill provider follows symlinked entries, so discovery is unaffected.
#
# Refuses when a copy has diverged, because linking would silently pick a side.
# The old copy is moved aside to .backup-<timestamp>-<name>, never deleted.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST=${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}
STAMP=$(date +%Y%m%d-%H%M%S)

python3 "$REPO_ROOT/tools/validate-skills.py" >/dev/null || {
  echo "error: the checkout does not validate; refusing to link" >&2
  exit 1
}
mkdir -p "$DEST"

refused=0
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  dir=${dir%/}
  target="$DEST/$name"

  if [ -L "$target" ]; then
    if [ "$(cd "$(dirname "$target")" && cd "$(readlink "$target")" && pwd)" = "$dir" ]; then
      printf 'linked  %s -> %s\n' "$name" "$dir"
    else
      printf 'drift   %s links elsewhere (%s)\n' "$name" "$(readlink "$target")"
      refused=1
    fi
    continue
  fi

  if [ -d "$target" ]; then
    if ! diff -rq "$target" "$dir" >/dev/null 2>&1; then
      printf 'refused %s: installed copy differs from the checkout\n' "$name"
      diff -rq "$target" "$dir" | sed 's/^/          /'
      refused=1
      continue
    fi
    mv "$target" "$DEST/.backup-$STAMP-$name"
    printf 'backup  %s -> .backup-%s-%s\n' "$name" "$STAMP" "$name"
  elif [ -e "$target" ]; then
    printf 'refused %s: installed path is not a directory\n' "$name"
    refused=1
    continue
  fi

  ln -s "$dir" "$target"
  printf 'link    %s -> %s\n' "$name" "$dir"
done

if [ "$refused" -ne 0 ]; then
  echo
  echo "some skills were left alone. run 'make sync' (installed copy wins) or" >&2
  echo "'make deploy' (checkout wins), then re-run 'make link'." >&2
  exit 1
fi

echo
echo "done. 'npx skills add' on these names would replace the links with copies —"
echo "deploy with 'make deploy' instead."
