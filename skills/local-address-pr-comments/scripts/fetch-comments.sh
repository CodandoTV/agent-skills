#!/usr/bin/env bash
# Fetch every comment on a pull request and write the triage queue.
#
# Usage:
#   fetch-comments.sh <PR_URL> <OUT_DIR>
#
# <PR_URL> is a github.com pull request URL; a trailing slash, query, or
# /files, /commits, /checks suffix is accepted and dropped.
#
# Output files under <OUT_DIR>:
#   pr.json            PR metadata (number, state, head sha, author, ...)
#   threads.json       every review thread, resolved or not, with its comments
#   issue-comments.json
#   reviews.json
#   queue.json         actionable items in triage order; each carries the ids a
#                      reply or a resolve needs
#   summary.json       counts and permissions for the run header
#
# The queue and the summary are built by queue.jq next to this script.
#
# The queue excludes what needs no prompt: resolved threads, threads or
# comments already answered by this skill (its hidden marker is in the body),
# comments written by the viewer or by the PR author, empty review bodies, and
# comments hidden by GitHub as minimized.
#
# Exit codes: 2 usage or not a PR URL, 3 missing tool or auth, 4 an API call
# failed or GitHub returned no pull request.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  printf 'usage: %s <PR_URL> <OUT_DIR>\n' "$(basename "$0")" >&2
}

[ "$#" -eq 2 ] || { usage; exit 2; }

PR_URL=$1
OUT=$2

for bin in gh jq; do
  command -v "$bin" >/dev/null 2>&1 || {
    printf '%s is required but was not found in PATH\n' "$bin" >&2
    exit 3
  }
done

case "$PR_URL" in
  https://github.com/*/pull/*|http://github.com/*/pull/*) ;;
  *)
    printf 'not a github.com pull request URL: %s\n' "$PR_URL" >&2
    exit 2
    ;;
esac
PR_URL=$(printf '%s' "$PR_URL" | sed -E 's#^(https?://github\.com/[^/]+/[^/]+/pull/[0-9]+).*#\1#')

if ! gh auth status >/dev/null 2>&1; then
  echo 'gh is not authenticated; run: gh auth login' >&2
  exit 3
fi

mkdir -p "$OUT"

gh pr view "$PR_URL" \
  --json number,url,state,isDraft,baseRefName,headRefName,headRefOid,headRepository,isCrossRepository,author,title \
  > "$OUT/pr.json"

REPO_SLUG=$(jq -r '.url | capture("github\\.com/(?<slug>[^/]+/[^/]+)/pull").slug' "$OUT/pr.json")
OWNER=${REPO_SLUG%/*}
REPO=${REPO_SLUG#*/}
N=$(jq -r .number "$OUT/pr.json")
PR_AUTHOR=$(jq -r '.author.login // ""' "$OUT/pr.json")
VIEWER=$(gh api user --jq .login)

PERMISSIONS=$(gh api "repos/$OWNER/$REPO" --jq '.permissions // {}')

THREADS_QUERY='
query($owner:String!,$repo:String!,$number:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      reviewThreads(first:100,after:$endCursor){
        pageInfo{hasNextPage endCursor}
        nodes{
          id
          isResolved
          isOutdated
          viewerCanResolve
          viewerCanReply
          path
          line
          originalLine
          startLine
          subjectType
          comments(first:100){
            nodes{
              databaseId
              body
              url
              createdAt
              replyTo{databaseId}
              author{__typename login}
            }
          }
        }
      }
    }
  }
}'

if ! gh api graphql --paginate --slurp -f query="$THREADS_QUERY" \
  -F owner="$OWNER" -F repo="$REPO" -F number="$N" \
  | jq '[.[].data.repository.pullRequest.reviewThreads.nodes[]]' > "$OUT/threads.json"; then
  echo 'failed to read review threads (does the PR exist and can you see it?)' >&2
  exit 4
fi

gh api --paginate --slurp "repos/$OWNER/$REPO/issues/$N/comments?per_page=100" \
  | jq 'add // []' > "$OUT/issue-comments.json"
gh api --paginate --slurp "repos/$OWNER/$REPO/pulls/$N/reviews?per_page=100" \
  | jq 'add // []' > "$OUT/reviews.json"

if ! jq -n \
  --slurpfile threads "$OUT/threads.json" \
  --slurpfile reviews "$OUT/reviews.json" \
  --slurpfile issues "$OUT/issue-comments.json" \
  --slurpfile pr "$OUT/pr.json" \
  --arg author "$PR_AUTHOR" \
  --arg viewer "$VIEWER" \
  --argjson permissions "$PERMISSIONS" \
  -f "$SCRIPT_DIR/queue.jq" > "$OUT/data.json"; then
  echo 'failed to build the comment queue' >&2
  exit 4
fi

jq '.queue' "$OUT/data.json" > "$OUT/queue.json"
jq '.summary' "$OUT/data.json" > "$OUT/summary.json"
rm -f "$OUT/data.json"

C=$(jq -c '.counts' "$OUT/summary.json")
printf '%s#%s  %s\n' "$OWNER/$REPO" "$N" "$(jq -r .title "$OUT/pr.json")"
printf 'viewer %s · PR author %s · state %s%s\n' \
  "$VIEWER" "$PR_AUTHOR" \
  "$(jq -r .state "$OUT/pr.json")" \
  "$( [ "$(jq -r .isDraft "$OUT/pr.json")" = true ] && printf ' (draft)' )"
printf 'threads: %s total, %s with feedback, %s open, %s resolved, %s already answered\n' \
  "$(jq -r .threads_total <<<"$C")" "$(jq -r .threads_with_feedback <<<"$C")" \
  "$(jq -r .threads_open <<<"$C")" "$(jq -r .threads_resolved <<<"$C")" \
  "$(jq -r .threads_answered <<<"$C")"
printf 'reviews: %s total, %s open · conversation comments: %s total, %s open\n' \
  "$(jq -r .reviews_total <<<"$C")" "$(jq -r .reviews_open <<<"$C")" \
  "$(jq -r .issue_comments_total <<<"$C")" "$(jq -r .issue_comments_open <<<"$C")"
printf 'queue: %s item(s) -> %s\n' \
  "$(jq -r .queue <<<"$C")" "$OUT/queue.json"
