#!/usr/bin/env bash
# Tag, push, and publish a release, with notes taken from CHANGELOG.md.
#
#     tools/release.sh 1.1.0 --dry-run    # validate and show the plan
#     tools/release.sh 1.1.0
#
# Requires a clean tree and a '## [1.1.0] - YYYY-MM-DD' section in CHANGELOG.md.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=${1:-}
DRY_RUN=0
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1

if [ -z "$VERSION" ]; then
  echo "usage: tools/release.sh <major.minor.patch> [--dry-run]" >&2
  exit 1
fi
VERSION=${VERSION#v}

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: '$VERSION' is not major.minor.patch" >&2
  exit 1
fi
TAG="v$VERSION"

cd "$REPO_ROOT"

python3 tools/validate-skills.py || exit 1

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean; commit the change first" >&2
  git status --short >&2
  exit 1
fi

if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
  echo "error: CHANGELOG.md has no '## [$VERSION]' section" >&2
  echo "hint: add '## [$VERSION] - $(date +%Y-%m-%d)' and its entries above it" >&2
  exit 1
fi

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "error: tag $TAG already exists" >&2
  exit 1
fi

notes=$(awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" {flag = 1; next}
  flag && /^## \[/ {exit}
  flag {print}
' CHANGELOG.md | sed '/^[[:space:]]*$/d' | head -40)

if [ -z "$notes" ]; then
  echo "error: the '## [$VERSION]' section is empty" >&2
  exit 1
fi

if grep -q "compare/v$VERSION\.\.\.HEAD" CHANGELOG.md; then
  :
else
  echo "warning: the [Unreleased] compare link does not point at v$VERSION yet" >&2
  echo "         fix: [Unreleased]: https://github.com/$SLUG/compare/v$VERSION...HEAD" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "would tag $TAG on $(git rev-parse --short HEAD), push it, and publish:"
  echo "----- release notes -----"
  printf '%s\n' "$notes"
  echo "-------------------------"
  exit 0
fi

git tag -a "$TAG" -m "$TAG"
git push origin HEAD
git push origin "$TAG"

notes_file=$(mktemp)
printf '%s\n' "$notes" >"$notes_file"
echo
echo "**Full changelog:** https://github.com/$SLUG/blob/main/CHANGELOG.md" >>"$notes_file"
gh release create "$TAG" -R "$SLUG" --verify-tag --title "$TAG" --notes-file "$notes_file"
rm -f "$notes_file"
