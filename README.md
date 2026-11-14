# agent-skills

Agent skills for reviewing a GitHub pull request from a local clone and for opening
pull requests with a fixed-shape description.

These are plain `SKILL.md` directories — no build step, no runtime, no package
manager. They work with any agent that reads the `SKILL.md` convention.

## Skills

| Skill | What it does | Trigger |
|---|---|---|
| [`local-code-review`](skills/local-code-review/SKILL.md) | Reviews a GitHub PR from a clone sitting on the PR's updated base branch: short PR summary, diff-health checklist, integration with the local code, tests and regressions, a green/yellow/orange/red diagnostic, then per-finding triage that publishes the accepted findings to GitHub. Read-only: never checks out or executes PR code. | You paste a `github.com/.../pull/...` URL and ask for a review |
| [`local-open-pr`](skills/local-open-pr/SKILL.md) | Opens the PR for the current branch with a fixed shape: one sentence for the problem target, one for how it is solved, then a Mermaid data-flow diagram of the Dart, Kotlin, and Python components the diff touches. | "open a PR", "raise a pull request", "put this up for review" |

The two are complements, not alternatives: `local-open-pr` starts once commits
exist and owns only the PR, while `local-code-review` starts from a reviewer's
clone and owns only the review.

## Install

Global (available in every project):

```bash
npx skills add CodandoTV/agent-skills -g --skill local-code-review --skill local-open-pr
```

Preview without installing (lists what the repository contains):

```bash
npx skills add CodandoTV/agent-skills -l
```

Project-scoped instead of global (commit-able, shared with everyone who clones
that repository):

```bash
npx skills add CodandoTV/agent-skills --skill local-code-review --skill local-open-pr
```

The installer symlinks into the detected agent directories by default. From a
local checkout where the source may move, add `--copy`.

Manual install — copy the folders into any skill root your agent watches:

```bash
cp -R skills/local-code-review skills/local-open-pr ~/.agents/skills/
```

Update later with:

```bash
npx skills update local-code-review local-open-pr
```

## Versioning

Versions are git tags. The installer has no semantic versioning of its own — a
version is whatever ref you ask it to clone. Latest release:
[v1.0.0](https://github.com/CodandoTV/agent-skills/releases/latest).

Installing without a ref follows `main`, so corrections arrive with
`npx skills update` (recommended):

```bash
npx skills add CodandoTV/agent-skills -g --skill local-code-review --skill local-open-pr
```

Pinning a release holds the skill still:

```bash
npx skills add CodandoTV/agent-skills#v1.0.0 -g --skill local-code-review --skill local-open-pr
```

That difference is not cosmetic. `npx skills update` re-resolves the ref recorded
in the lock file, so a pinned install is frozen on that tag and never moves — to
upgrade it you re-run `add` with the new tag. Pin by **tag**, not by commit SHA:
the installer clones with `git clone --branch`, which rejects a SHA.

One version covers the whole repository because the two skills are complements
that ship together. What counts as major, minor, and patch is written down at the
top of [CHANGELOG.md](CHANGELOG.md).

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

Do not run `npx skills add` (or `update`) for these two names once linked: the
installer materializes its own copy under `~/.agents/skills`, replacing the link,
and its lock entry then disagrees with your edits.

## Requirements

Both skills:

- `git`, with a clone that contains the target repository as a remote
- an authenticated GitHub CLI (`gh auth login`) with `repo` scope
- `jq`

`local-code-review` additionally uses `ripgrep` (`rg`) or the agent's own search
tool, and reads the local code around the diff, so the clone should be on an
up-to-date base branch.

`local-open-pr` draws its blast-radius diagram as Mermaid, so the component
listing is limited to Dart, Kotlin, and Python files in the diff.

## Layout

```text
skills/
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
tools/
  validate-skills.py            # frontmatter, catalog cap, cited paths
  drift.sh                      # installed copy vs checkout
  sync-from-global.sh           # installed copy -> checkout
  deploy.sh                     # checkout -> installed copy
  link.sh                       # replace installed copies with symlinks
  release.sh                    # validate, tag, push, publish
Makefile                        # make validate | drift | sync | deploy | link | release
.github/workflows/
  validate-skills.yml           # runs the validator plus a discovery smoke test
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

