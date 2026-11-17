#!/usr/bin/env bash
# Fixture tests for the comment queue builder shipped by local-address-pr-comments.
#
#     bash tools/test-fetch-comments.sh
#
# The builder is skills/local-address-pr-comments/scripts/queue.jq. Every case
# feeds canned GitHub payloads through it and asserts the queue and the counts.
# No network, no gh, no repository state: this is the only part of the skill that
# can be checked without a live pull request.
#
# Exit 0 when every case passes, 1 otherwise.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKILL_DIR=$REPO_ROOT/skills/local-address-pr-comments
QUEUE=$SKILL_DIR/scripts/queue.jq
TMP=$(mktemp -d "${TMPDIR:-/tmp}/test-fetch-comments.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

VIEWER=me
PR_AUTHOR=author
failures=0

printf '[]\n' > "$TMP/empty.json"

cat > "$TMP/pr.json" <<'JSON'
{
  "number": 3,
  "url": "https://github.com/o/r/pull/3",
  "state": "OPEN",
  "isDraft": false,
  "baseRefName": "main",
  "headRefName": "feat/x",
  "headRefOid": "df0ccdfd1ed1ae398752f69a175bdee7fbcfd2c9",
  "headRepository": {"nameWithOwner": "o/r"},
  "isCrossRepository": false,
  "author": {"login": "author"},
  "title": "test PR"
}
JSON

run() { # <threads.json> <reviews.json> <issues.json> -> $TMP/out.json
  jq -n \
    --slurpfile threads "$1" \
    --slurpfile reviews "$2" \
    --slurpfile issues "$3" \
    --slurpfile pr "$TMP/pr.json" \
    --arg author "$PR_AUTHOR" \
    --arg viewer "$VIEWER" \
    --argjson permissions '{"push": true}' \
    -f "$QUEUE" > "$TMP/out.json"
}

check() { # <name> <jq filter> <expected>
  local name=$1 filter=$2 expected=$3 actual
  actual=$(jq -c "$filter" "$TMP/out.json")
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

if bash -n "$SKILL_DIR/scripts/fetch-comments.sh"; then
  printf 'ok   fetch-comments.sh parses\n'
else
  printf 'FAIL fetch-comments.sh does not parse\n'
  failures=$((failures + 1))
fi

# --- a conversation comment from a reviewer, unanswered ---------------------
cat > "$TMP/issues-reviewer.json" <<'JSON'
[
  {
    "id": 1001,
    "body": "Why is this call synchronous?",
    "user": {"login": "reviewer", "type": "User"},
    "created_at": "2026-01-01T10:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-1001",
    "isMinimized": false
  },
  {
    "id": 1002,
    "body": "A note by the viewer.",
    "user": {"login": "me", "type": "User"},
    "created_at": "2026-01-01T11:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-1002",
    "isMinimized": false
  },
  {
    "id": 1003,
    "body": "The author chiming in.",
    "user": {"login": "author", "type": "User"},
    "created_at": "2026-01-01T12:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-1003",
    "isMinimized": false
  },
  {
    "id": 1004,
    "body": "Hidden as minimized.",
    "user": {"login": "reviewer", "type": "User"},
    "created_at": "2026-01-01T13:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-1004",
    "isMinimized": true
  }
]
JSON

run "$TMP/empty.json" "$TMP/empty.json" "$TMP/issues-reviewer.json"
check "unanswered conversation comment is queued" '(.queue | length)' '1'
check "conversation item carries its key" '.queue[0].key' '"comment:1001"'
check "conversation item is a conversation" '.queue[0].kind' '"conversation"'
check "viewer, author and minimized comments are not queued" '.summary.counts.issue_comments_open' '1'
check "all fetched conversation comments are counted" '.summary.counts.issue_comments_total' '4'

# --- the same comment, answered by a marked reply --------------------------
# Regression: the reply is a separate conversation comment, not an edit of the
# original, so "answered" must be read from every body the skill could write.
cat > "$TMP/issues-answered.json" <<'JSON'
[
  {
    "id": 1001,
    "body": "Why is this call synchronous?",
    "user": {"login": "reviewer", "type": "User"},
    "created_at": "2026-01-01T10:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-1001",
    "isMinimized": false
  },
  {
    "id": 2001,
    "body": "> Why is this call synchronous?\n\nIt has to be: the caller needs the value.\n\n<!-- local-address-pr-comments:reply:comment:1001 -->",
    "user": {"login": "me", "type": "User"},
    "created_at": "2026-01-01T11:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-2001",
    "isMinimized": false
  }
]
JSON

run "$TMP/empty.json" "$TMP/empty.json" "$TMP/issues-answered.json"
check "an answered conversation comment is not queued again" '(.queue | length)' '0'
check "the answered conversation comment is counted" '.summary.counts.issue_comments_answered' '1'
check "answered_total counts the conversation answer" '.summary.counts.answered_total' '1'

# --- a review summary, one answered and one not ----------------------------
cat > "$TMP/reviews.json" <<'JSON'
[
  {
    "id": 3001,
    "body": "Please add a test for the empty case.",
    "user": {"login": "reviewer", "type": "User"},
    "state": "CHANGES_REQUESTED",
    "submitted_at": "2026-01-01T09:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#pullrequestreview-3001"
  },
  {
    "id": 3002,
    "body": "The naming here is odd.",
    "user": {"login": "reviewer", "type": "User"},
    "state": "COMMENTED",
    "submitted_at": "2026-01-01T09:30:00Z",
    "html_url": "https://github.com/o/r/pull/3#pullrequestreview-3002"
  }
]
JSON

cat > "$TMP/issues-review-reply.json" <<'JSON'
[
  {
    "id": 4001,
    "body": "> Please add a test for the empty case.\n\nAdded in the next push.\n\n<!-- local-address-pr-comments:reply:review:3001 -->",
    "user": {"login": "me", "type": "User"},
    "created_at": "2026-01-01T10:00:00Z",
    "html_url": "https://github.com/o/r/pull/3#issuecomment-4001",
    "isMinimized": false
  }
]
JSON

run "$TMP/empty.json" "$TMP/reviews.json" "$TMP/issues-review-reply.json"
check "an answered review summary is not queued again" '.summary.counts.reviews_answered' '1'
check "the unanswered review summary stays open" '.summary.counts.reviews_open' '1'
check "the open review summary is the queue" '.queue[0].key' '"review:3002"'

# --- threads: one open with feedback, one resolved -------------------------
cat > "$TMP/threads.json" <<'JSON'
[
  {
    "id": "PRRT_OPEN",
    "isResolved": false,
    "isOutdated": false,
    "viewerCanResolve": true,
    "viewerCanReply": true,
    "path": "a.sh",
    "line": 10,
    "originalLine": 10,
    "startLine": null,
    "subjectType": "LINE",
    "comments": {
      "nodes": [
        {
          "databaseId": 5001,
          "body": "This leaks the file descriptor.",
          "url": "https://github.com/o/r/pull/3#discussion_r5001",
          "createdAt": "2026-01-01T10:00:00Z",
          "replyTo": null,
          "author": {"__typename": "User", "login": "reviewer"}
        }
      ]
    }
  },
  {
    "id": "PRRT_RESOLVED",
    "isResolved": true,
    "isOutdated": false,
    "viewerCanResolve": true,
    "viewerCanReply": true,
    "path": "b.sh",
    "line": 20,
    "originalLine": 20,
    "startLine": null,
    "subjectType": "LINE",
    "comments": {
      "nodes": [
        {
          "databaseId": 6001,
          "body": "This was already fixed.",
          "url": "https://github.com/o/r/pull/3#discussion_r6001",
          "createdAt": "2026-01-01T10:00:00Z",
          "replyTo": null,
          "author": {"__typename": "User", "login": "reviewer"}
        }
      ]
    }
  }
]
JSON

run "$TMP/threads.json" "$TMP/empty.json" "$TMP/empty.json"
check "only the open thread is queued" '(.queue | length)' '1'
check "thread item carries the thread id" '.queue[0].thread_id' '"PRRT_OPEN"'
check "thread item is resolvable" '.queue[0].resolvable' 'true'
check "thread reply targets the root comment" '.queue[0].reply_to_comment_id' '5001'
check "the resolved thread is counted, not queued" '.summary.counts.threads_resolved' '1'
check "the open thread is counted as open" '.summary.counts.threads_open' '1'

# --- a thread answered by a marked in-thread reply -------------------------
cat > "$TMP/threads-answered.json" <<'JSON'
[
  {
    "id": "PRRT_OPEN",
    "isResolved": false,
    "isOutdated": false,
    "viewerCanResolve": true,
    "viewerCanReply": true,
    "path": "a.sh",
    "line": 10,
    "originalLine": 10,
    "startLine": null,
    "subjectType": "LINE",
    "comments": {
      "nodes": [
        {
          "databaseId": 5001,
          "body": "This leaks the file descriptor.",
          "url": "https://github.com/o/r/pull/3#discussion_r5001",
          "createdAt": "2026-01-01T10:00:00Z",
          "replyTo": null,
          "author": {"__typename": "User", "login": "reviewer"}
        },
        {
          "databaseId": 5002,
          "body": "Good catch, closing it in the finally block.\n\n<!-- local-address-pr-comments:reply:thread:PRRT_OPEN -->",
          "url": "https://github.com/o/r/pull/3#discussion_r5002",
          "createdAt": "2026-01-01T10:05:00Z",
          "replyTo": {"databaseId": 5001},
          "author": {"__typename": "User", "login": "me"}
        }
      ]
    }
  }
]
JSON

run "$TMP/threads-answered.json" "$TMP/empty.json" "$TMP/empty.json"
check "an answered thread is not queued again" '(.queue | length)' '0'
check "the answered thread is counted" '.summary.counts.threads_answered' '1'

# --- triage order: thread, then review, then conversation ------------------
cat > "$TMP/threads-one.json" <<'JSON'
[
  {
    "id": "PRRT_ONE",
    "isResolved": false,
    "isOutdated": false,
    "viewerCanResolve": true,
    "viewerCanReply": true,
    "path": "a.sh",
    "line": 10,
    "originalLine": 10,
    "startLine": null,
    "subjectType": "LINE",
    "comments": {
      "nodes": [
        {
          "databaseId": 7001,
          "body": "A thread comment.",
          "url": "https://github.com/o/r/pull/3#discussion_r7001",
          "createdAt": "2026-01-01T10:00:00Z",
          "replyTo": null,
          "author": {"__typename": "User", "login": "reviewer"}
        }
      ]
    }
  }
]
JSON

run "$TMP/threads-one.json" "$TMP/reviews.json" "$TMP/issues-reviewer.json"
check "queue is ordered thread, review, conversation" '[.queue[].kind]' '["thread","review","review","conversation"]'
check "queue length matches its parts" '(.queue | length)' '4'

echo
if [ "$failures" -eq 0 ]; then
  echo "all checks passed"
  exit 0
fi
echo "$failures check(s) failed"
exit 1
