# Build the triage queue and its run summary from the fetched GitHub payloads.
#
# Called by fetch-comments.sh, which supplies every input as a named variable:
#
#   jq -n --slurpfile threads   threads.json
#         --slurpfile reviews   reviews.json
#         --slurpfile issues    issue-comments.json
#         --slurpfile pr        pr.json
#         --arg author "$PR_AUTHOR" --arg viewer "$VIEWER"
#         --argjson permissions "$PERMISSIONS"
#         -f queue.jq
#
# It lives in its own file so tools/test-fetch-comments.sh can run it over
# fixtures without touching the network.

def is_bot: (. // "") | endswith("[bot]");

# The hidden marker every reply this skill posts ends with. The key after it is
# the queue item's own `key`, so a later run can tell which item was answered.
def reply_marker: "<!-- local-address-pr-comments:reply:";
def reply_key_re: reply_marker + "([A-Za-z0-9:_-]+) -->";

# Every answer key written anywhere the skill could have written one: a reply
# inside a review thread, or a standalone conversation comment.
def reply_keys: [ .[] | (.body // "") | scan(reply_key_re) | .[0] ];

($threads[0] // []) as $T
| ($reviews[0] // []) as $R
| ($issues[0] // []) as $I

| ([ ($T[] | (.comments.nodes // [])[]), $I[] ] | reply_keys | unique) as $answered

| ($T | map(
    . as $t
    | (($t.comments.nodes // []) | sort_by(.createdAt)) as $comments
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
            elif ($answered | index("thread:" + $t.id)) != null then "answered"
            else "open"
            end
          )
        }
      end
  )
) as $thread_items
| ($thread_items | map(select(. != null))) as $threads_with_feedback
| ([$threads_with_feedback[] | select(.status == "open")] | length) as $threads_open

| ($R | map(
      . as $r
      | select(((.body // "") | test("\\S")))
      | select((.user.login // "") != $viewer and (.user.login // "") != $author)
      | {
          key: ("review:" + ($r.id | tostring)),
          kind: "review",
          resolvable: false,
          can_reply: true,
          thread_id: null,
          reply_to_comment_id: null,
          comment_id: $r.id,
          path: null,
          line: null,
          original_line: null,
          start_line: null,
          subject_type: null,
          outdated: false,
          author: (.user.login // "unknown"),
          bot: ((((.user.type // "") == "Bot") or (.user.login | is_bot))),
          created_at: $r.submitted_at,
          body: $r.body,
          url: ($r.html_url // ""),
          review_state: $r.state,
          transcript: [],
          status: (
            if ($answered | index("review:" + ($r.id | tostring))) != null then "answered"
            else "open"
            end
          )
        }
    )
) as $review_items

| ($I | map(
      . as $c
      | select(((.body // "") | test("\\S")))
      | select((.user.login // "") != $viewer and (.user.login // "") != $author)
      | select((.isMinimized // false) | not)
      | {
          key: ("comment:" + ($c.id | tostring)),
          kind: "conversation",
          resolvable: false,
          can_reply: true,
          thread_id: null,
          reply_to_comment_id: null,
          comment_id: $c.id,
          path: null,
          line: null,
          original_line: null,
          start_line: null,
          subject_type: null,
          outdated: false,
          author: (.user.login // "unknown"),
          bot: ((((.user.type // "") == "Bot") or (.user.login | is_bot))),
          created_at: $c.created_at,
          body: $c.body,
          url: ($c.html_url // ""),
          review_state: null,
          transcript: [],
          status: (
            if ($answered | index("comment:" + ($c.id | tostring))) != null then "answered"
            else "open"
            end
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
        threads_total: ($T | length),
        threads_with_feedback: ($threads_with_feedback | length),
        threads_open: $threads_open,
        threads_resolved: ([$threads_with_feedback[] | select(.status == "resolved")] | length),
        threads_answered: ([$threads_with_feedback[] | select(.status == "answered")] | length),
        reviews_total: ($R | length),
        reviews_open: ([$review_items[] | select(.status == "open")] | length),
        reviews_answered: ([$review_items[] | select(.status == "answered")] | length),
        issue_comments_total: ($I | length),
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
