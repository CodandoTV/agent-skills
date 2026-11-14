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
```

`references/` and `scripts/` are loaded on demand by the skill body, so keep them
beside the `SKILL.md` that mentions them.
