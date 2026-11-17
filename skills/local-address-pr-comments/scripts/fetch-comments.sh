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
# The queue excludes what needs no prompt: resolved threads, threads or
# comments already answered by this skill (its hidden marker is in the body),
# comments written by the viewer or by the PR author, empty review bodies, and
# comments hidden by GitHub as minimized.
#
# Exit codes: 2 usage or not a PR URL, 3 missing tool or auth, 4 an API call
# failed or GitHub returned no pull request.

set -euo pipefail

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

JQ_PROGRAM=$(mktemp "${TMPDIR:-/tmp}/fetch-comments-jq.XXXXXX")
trap 'rm -f "$JQ_PROGRAM"' EXIT

cat > "$JQ_PROGRAM" <<'JQ'
def is_bot: (. // "") | endswith("[bot]");
def marker: "<!-- local-address-pr-comments:";
def answered($comments): any($comments[]; ((.body // "") | contains("<!-- local-address-pr-comments:")));

($threads[0] // [] | map(
    . as $t
    | ($t.comments.nodes | sort_by(.createdAt)) as $comments
    | ([$comments[]
        | select((.author.login // "") != $viewer and (.author.login // "") != $author)]
       | first) as $primary
    | if $primary == null then
        null
      else
        {
          key: ("thread:" + $t.id),
          kind: "thread",
          resolvable: ($t.viewerCanResolve // false),
          can_reply: ($t.viewerCanReply // false),
          thread_id: $t.id,
          reply_to_comment_id: ($comments[0].databaseId // null),
          comment_id: null,
          path: $t.path,
          line: $t.line,
          original_line: $t.originalLine,
          start_line: $t.startLine,
          subject_type: $t.subjectType,
          outdated: ($t.isOutdated // false),
          author: ($primary.author.login // "unknown"),
          bot: (((($primary.author.__typename // "") == "Bot") or ($primary.author.login | is_bot))),
          created_at: $primary.createdAt,
          body: ($primary.body // ""),
          url: ($primary.url // ""),
          review_state: null,
          transcript: [
            $comments[]
            | {
                author: (.author.login // "unknown"),
                body: (.body // ""),
                created_at: .createdAt,
                url: (.url // "")
              }
          ],
          status: (
            if $t.isResolved then "resolved"
            elif answered($comments) then "answered"
            else "open"
            end
          )
        }
      end
  )
) as $thread_items
| ($thread_items | map(select(. != null))) as $threads_with_feedback
| ([$threads_with_feedback[] | select(.status == "open")] | length) as $threads_open

| ($reviews[0] // [] | map(
      . as $r
      | select(((.body // "") | test("\\S")))
      | select((.user.login // "") != $viewer and (.user.login // "") != $author)
      | {
          key: ("review:" + (.id | tostring)),
          kind: "review",
          resolvable: false,
          can_reply: true,
          thread_id: null,
          reply_to_comment_id: null,
          comment_id: .id,
          path: null,
          line: null,
          original_line: null,
          start_line: null,
          subject_type: null,
          outdated: false,
          author: (.user.login // "unknown"),
          bot: ((((.user.type // "") == "Bot") or (.user.login | is_bot))),
          created_at: .submitted_at,
          body: .body,
          url: (.html_url // ""),
          review_state: .state,
          transcript: [],
          status: (
            if (.body | contains(marker)) then "answered" else "open" end
          )
        }
    )
) as $review_items

| ($issues[0] // [] | map(
      . as $c
      | select(((.body // "") | test("\\S")))
      | select((.user.login // "") != $viewer and (.user.login // "") != $author)
      | select((.isMinimized // false) | not)
      | {
          key: ("comment:" + (.id | tostring)),
          kind: "conversation",
          resolvable: false,
          can_reply: true,
          thread_id: null,
          reply_to_comment_id: null,
          comment_id: .id,
          path: null,
          line: null,
          original_line: null,
          start_line: null,
          subject_type: null,
          outdated: false,
          author: (.user.login // "unknown"),
          bot: ((((.user.type // "") == "Bot") or (.user.login | is_bot))),
          created_at: .created_at,
          body: .body,
          url: (.html_url // ""),
          review_state: null,
          transcript: [],
          status: (
            if (.body | contains(marker)) then "answered" else "open" end
          )
        }
    )
) as $comment_items

| ($threads_with_feedback + $review_items + $comment_items) as $all
| ($all | map(select(.status == "open"))) as $queue
| {
    queue: ($queue
      | sort_by([
          (if .kind == "thread" then 0 elif .kind == "review" then 1 else 2 end),
          (.path // ""),
          (.line // 0),
          .created_at
        ])
    ),
    summary: {
      pr: $pr[0],
      viewer: $viewer,
      pr_author: $author,
      permissions: $permissions,
      counts: {
        threads_total: (($threads[0] // []) | length),
        threads_with_feedback: ($threads_with_feedback | length),
        threads_open: $threads_open,
        threads_resolved: ([$threads_with_feedback[] | select(.status == "resolved")] | length),
        threads_answered: ([$threads_with_feedback[] | select(.status == "answered")] | length),
        reviews_total: (($reviews[0] // []) | length),
        reviews_open: ([$review_items[] | select(.status == "open")] | length),
        reviews_answered: ([$review_items[] | select(.status == "answered")] | length),
        issue_comments_total: (($issues[0] // []) | length),
        issue_comments_open: ([$comment_items[] | select(.status == "open")] | length),
        issue_comments_answered: ([$comment_items[] | select(.status == "answered")] | length),
        answered_total: (
          ([$threads_with_feedback[] | select(.status == "answered")] | length)
          + ([$review_items[] | select(.status == "answered")] | length)
          + ([$comment_items[] | select(.status == "answered")] | length)
        ),
        queue: ($queue | length)
      }
    }
  }
JQ

if ! jq -n \
  --slurpfile threads "$OUT/threads.json" \
  --slurpfile reviews "$OUT/reviews.json" \
  --slurpfile issues "$OUT/issue-comments.json" \
  --slurpfile pr "$OUT/pr.json" \
  --arg author "$PR_AUTHOR" \
  --arg viewer "$VIEWER" \
  --argjson permissions "$PERMISSIONS" \
  -f "$JQ_PROGRAM" > "$OUT/data.json"; then
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
