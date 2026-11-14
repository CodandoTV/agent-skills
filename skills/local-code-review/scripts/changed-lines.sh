#!/usr/bin/env bash
# List every added line in a unified diff as "<path>\t<new-side-line>".
#
# Usage:
#   changed-lines.sh <diff-file>
#
# Output: one tab-separated "path<TAB>new-line-number" row per added line,
# in diff order. Context lines are counted but not printed; deleted lines do
# not affect the new-side counter.
#
# The input is expected to be a git-style diff (each file starts with
# "diff --git"). It does not read the repository, so it also works for a fork
# PR diff produced by `gh pr diff --patch`.
#
# Limitation: git quotes unusual paths (for example paths containing tabs or
# escaped quotes). The output then contains the quoted form. If an anchor is
# not accepted by GitHub, fall back to a file-level comment.
#
# Exit codes: 0 on success, 2 on usage/file errors.

set -euo pipefail

usage() {
  printf 'usage: %s <diff-file>\n' "$(basename "$0")" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

if [ ! -f "$1" ]; then
  printf 'diff file not found: %s\n' "$1" >&2
  exit 2
fi

awk '
BEGIN {
  path = ""
  in_hunk = 0
  new_line = 0
  expect_header = 0
}

# A new file starts a new section and cancels any pending header.
/^diff --git / {
  path = ""
  in_hunk = 0
  new_line = 0
  expect_header = 0
  next
}

# A "---" line is a file header only when we are not inside a hunk. Inside a
# hunk it can be a deleted content line beginning with "-- ".
/^--- / {
  if (!in_hunk) {
    expect_header = 1
  }
  next
}

/^\+\+\+ / {
  if (expect_header) {
    expect_header = 0
    p = substr($0, 5)
    if (p == "/dev/null") {
      path = ""
      in_hunk = 0
      next
    }
    sub(/^b\//, "", p)
    path = p
    in_hunk = 0
    next
  }
  # Inside a hunk this is an added content line beginning with "++ ".
  if (in_hunk) {
    if (path != "") {
      print path "\t" new_line
    }
    new_line++
  }
  next
}

# Hunk header: @@ -old,count +new,count @@ optional-section
/^@@ / {
  if (path == "" || match($0, /\+[0-9]+(,[0-9]+)?/) == 0) {
    in_hunk = 0
    next
  }
  spec = substr($0, RSTART + 1, RLENGTH - 1)
  split(spec, parts, ",")
  new_line = parts[1] + 0
  in_hunk = 1
  next
}

in_hunk {
  first = substr($0, 1, 1)

  # Added line: print the new-side line number.
  if (first == "+") {
    if (path != "") {
      print path "\t" new_line
    }
    new_line++
    next
  }

  # Deleted line: no new-side line number to consume.
  if (first == "-") {
    next
  }

  # "\ No newline at end of file": no line number to consume.
  if (first == "\\") {
    next
  }

  # Context line (including a blank line whose leading space was trimmed).
  if (first == " " || $0 == "") {
    new_line++
    next
  }

  # Anything else ends the hunk.
  in_hunk = 0
}
' "$1"
