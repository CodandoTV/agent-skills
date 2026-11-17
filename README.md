# agent-skills

Agent skills for turning an issue or a work description into planned, locally
committed code, opening pull requests with a fixed-shape description, reviewing
a GitHub pull request from a local clone, and working through its review comments
with local commits and GitHub replies.

These are plain `SKILL.md` directories — no build step, no runtime, no package
manager. They work with any agent that reads the `SKILL.md` convention.

## Skills

| Skill | What it does | Trigger |
|---|---|---|
| [`local-triage-work`](skills/local-triage-work/SKILL.md) | Turns a GitHub issue link or a text description of a bug, feature, or tech debt into an agreed plan and local commits: interviews the user, designs a strategy, presents the plan for review, then on approval cuts a feature branch from the updated base branch and commits each step. Never pushes or opens a PR. | You paste an issue link or describe the work and ask to triage, plan, or implement it |
| [`local-open-pr`](skills/local-open-pr/SKILL.md) | Opens the PR for the current branch with a fixed shape: one sentence for the problem target with a `Closes` line for each issue it resolves, one for how it is solved, then a Mermaid data-flow diagram of the Dart, Kotlin, and Python components the diff touches. | "open a PR", "raise a pull request", "put this up for review" |
| [`local-code-review`](skills/local-code-review/SKILL.md) | Reviews a GitHub PR from a clone sitting on the PR's updated base branch: short PR summary, diff-health checklist, integration with the local code, tests and regressions, a green/yellow/orange/red diagnostic, then per-finding triage that publishes the accepted findings to GitHub. Read-only: never checks out or executes PR code. | You paste a `github.com/.../pull/...` URL and ask for a review |
| [`local-address-pr-comments`](skills/local-address-pr-comments/SKILL.md) | Works through the open review threads and comments on a GitHub PR from a clone on its head branch. Each one prompts **Fix and resolve** (smallest change, one local commit, thread resolved), **Comment and resolve** (reply posted, thread resolved), or **Skip**. Never pushes: resolved threads point at commits only the local clone has until the user pushes. | You paste a `github.com/.../pull/...` URL and ask to address, fix, or answer the review comments |

The four are stages of one pipeline, not alternatives: `local-triage-work` starts
from an issue or a description and ends at local commits on a feature branch,
`local-open-pr` starts once those commits exist and owns only the PR,
`local-code-review` starts from a reviewer's clone and owns only the review, and
`local-address-pr-comments` starts once comments exist and owns the local fixes
and the replies to them.

## Install

Global (available in every project):

```bash
npx skills add CodandoTV/agent-skills -g \
  --skill local-triage-work --skill local-code-review --skill local-open-pr \
  --skill local-address-pr-comments
```

Preview without installing (lists what the repository contains):

```bash
npx skills add CodandoTV/agent-skills -l
```

Project-scoped instead of global (commit-able, shared with everyone who clones
that repository):

```bash
npx skills add CodandoTV/agent-skills \
  --skill local-triage-work --skill local-code-review --skill local-open-pr \
  --skill local-address-pr-comments
```

The installer symlinks into the detected agent directories by default. From a
local checkout where the source may move, add `--copy`.

Manual install — copy the folders into any skill root your agent watches:

```bash
cp -R skills/local-triage-work skills/local-code-review skills/local-open-pr \
  skills/local-address-pr-comments ~/.agents/skills/
```

Update later with:

```bash
npx skills update local-triage-work local-code-review local-open-pr local-address-pr-comments
```

## Versioning

Versions are git tags. The installer has no semantic versioning of its own — a
version is whatever ref you ask it to clone. Latest release:
[v2.1.0](https://github.com/CodandoTV/agent-skills/releases/latest).

Installing without a ref follows `main`, so corrections arrive with
`npx skills update` (recommended):

```bash
npx skills add CodandoTV/agent-skills -g \
  --skill local-triage-work --skill local-code-review --skill local-open-pr \
  --skill local-address-pr-comments
```

Pinning a release holds the skill still:

```bash
npx skills add CodandoTV/agent-skills#v2.1.0 -g \
  --skill local-triage-work --skill local-code-review --skill local-open-pr \
  --skill local-address-pr-comments
```

That difference is not cosmetic. `npx skills update` re-resolves the ref recorded
in the lock file, so a pinned install is frozen on that tag and never moves — to
upgrade it you re-run `add` with the new tag. Pin by **tag**, not by commit SHA:
the installer clones with `git clone --branch`, which rejects a SHA.

One version covers the whole repository because the skills are stages of one
pipeline that ship together. What counts as major, minor, and patch is written down
at the top of [CHANGELOG.md](CHANGELOG.md).

## Editing a skill

On a machine that installs these skills there are two copies — this checkout and
the one the agent reads in `~/.agents/skills`. Pick one writable side, or they
drift silently.

**Recommended: link the installed copies to the checkout (once).**

```bash
make link
```

This replaces `~/.agents/skills/<name>` with a symlink into `skills/<name>` here,
so editing the installed copy *is* editing the repository: nothing to sync, and
`make drift` stays quiet by construction. The skill provider follows symlinked
entries, so discovery is unaffected. Old copies are moved to
`.backup-<timestamp>-<name>`, never deleted. `make link` refuses when a copy has
diverged, because linking would silently pick a side.

**If you edit the installed copy instead** (another machine, or before linking):

```bash
make sync-dry   # what would change, including deletions
make sync       # installed copy wins; validates, then prints git status
```

**If you edit here** and want the agent to use it right away:

```bash
make deploy     # checkout wins; the agent re-reads the body on its next load
```

Then publish, the same way in every case:

```bash
# 1. add "## [x.y.z] - YYYY-MM-DD" with its entries to CHANGELOG.md
# 2. commit
make release VERSION=x.y.z
```

`make release` validates, refuses a dirty tree or a missing CHANGELOG section,
tags `vX.Y.Z`, pushes, and publishes notes taken from that section. To see the
plan without touching GitHub: `bash tools/release.sh x.y.z --dry-run`.

Do not run `npx skills add` (or `update`) for these names once linked: the
installer materializes its own copy under `~/.agents/skills`, replacing the link,
and its lock entry then disagrees with your edits.

## Requirements

All four:

- `git`, with a clone of the repository the work belongs to.

`local-triage-work` additionally uses an authenticated GitHub CLI (`gh auth login`,
`repo` scope) only when the input is a GitHub issue link, and runs the target
repository's own test and typecheck commands.

`local-code-review` additionally uses an authenticated `gh` (`repo` scope), `jq`,
and `ripgrep` (`rg`) or the agent's own search tool, and reads the local code around
the diff, so the clone should be on an up-to-date base branch.

`local-open-pr` uses an authenticated `gh` (`repo` scope) to resolve issues and create
the PR, and draws its blast-radius diagram as Mermaid, so the component listing is
limited to Dart, Kotlin, and Python files in the diff.

`local-address-pr-comments` additionally uses an authenticated `gh` with write access
to the PR's repository (for replies and thread resolution), `jq`, and a clone checked
out on the PR's head branch. It commits each accepted fix locally and never pushes.

## Layout

```text
skills/
  local-address-pr-comments/
    SKILL.md
    references/
      response-strategies.md     # how to fix vs. answer each kind of comment
    scripts/
      fetch-comments.sh          # comment queue from the GitHub API
      queue.jq                   # the queue and summary builder, over the fetched JSON
  local-code-review/
    SKILL.md
    references/
      diff-health-checklist.md
      integration-checklist.md
      tests-and-regressions-checklist.md
    scripts/
      changed-lines.sh          # maps added lines to inline-comment anchors
  local-open-pr/
    SKILL.md
  local-triage-work/
    SKILL.md
    references/
      interview-checklist.md
      plan-template.md
tools/
  validate-skills.py            # frontmatter, catalog cap, cited paths
  drift.sh                      # installed copy vs checkout
  sync-from-global.sh           # installed copy -> checkout
  deploy.sh                     # checkout -> installed copy
  link.sh                       # replace installed copies with symlinks
  release.sh                    # validate, tag, push, publish
  test-fetch-comments.sh        # fixture tests for the comment queue builder
Makefile                        # make validate | test | drift | sync | deploy | link | release
.github/workflows/
  validate-skills.yml           # validator, queue tests, discovery smoke test
```

`references/` and `scripts/` are loaded on demand by the skill body, so keep them
beside the `SKILL.md` that mentions them.

## Changing a skill

Run the validator before pushing — CI runs the same thing and will fail the PR:

```bash
pip install pyyaml
python3 tools/validate-skills.py
```

It rejects a `name` that does not match its directory, a `description` over the
500-character catalog cap (the tail with the trigger phrases is what gets
truncated), a body that cites a `references/` or `scripts/` path that does not
exist, and camelCase invocation flags. Adding a behavioural change means adding a
[CHANGELOG.md](CHANGELOG.md) entry and tagging the release.

