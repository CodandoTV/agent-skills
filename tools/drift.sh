#!/usr/bin/env bash
# Report whether the skills installed globally differ from this checkout.
#
# Exit 0 when every installed skill is identical to the repository, 1 when they
# diverge, so it can gate a release or just be run before committing.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC=${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}

drift=0
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  installed="$SRC/$name"

  if [ ! -e "$installed" ] && [ ! -L "$installed" ]; then
    printf 'absent  %s  (not installed in %s)\n' "$name" "$SRC"
    drift=1
    continue
  fi

  if [ -L "$installed" ]; then
    target=$(cd "$(dirname "$installed")" && cd "$(readlink "$installed")" 2>/dev/null && pwd || true)
    if [ "$target" = "$dir" ] || [ "$target" = "${dir%/}" ]; then
      printf 'linked  %s  -> %s\n' "$name" "$target"
      continue
    fi
    printf 'drift   %s  links to %s, not %s\n' "$name" "${target:-?}" "${dir%/}"
    drift=1
    continue
  fi

  if diff -rq "$installed" "$dir" >/dev/null 2>&1; then
    printf 'same    %s\n' "$name"
  else
    printf 'drift   %s\n' "$name"
    diff -rq "$installed" "$dir" | sed 's/^/          /'
    drift=1
  fi
done

exit "$drift"
