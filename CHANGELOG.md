# Changelog

All notable changes to the skills in this repository are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
repository uses [Semantic Versioning](https://semver.org/spec/v2.0.0/). A release is
an annotated git tag `vX.Y.Z` on `main`: there is no build artifact, so the tag *is*
the version.

What the version numbers mean for a skill, which is not quite library software:

- **Major** — renaming or removing a skill; changing which requests the skill claims
  (the trigger phrases and conditions in `description`); changing an output contract
  something downstream depends on (the fixed PR shape of `local-open-pr`, the verdict
  banner and inline comments of `local-code-review`); renaming or removing a file the
  body cites.
- **Minor** — a new checklist, reference, or capability; a new optional input.
- **Patch** — wording, typos, prose tightened without moving triggers or outputs.

## [Unreleased]

### Added

- `local-address-pr-comments` — work through a GitHub pull request's review threads
  and conversation comments from a clone on its head branch, one prompt per item:
  **Fix and resolve** applies the smallest change, runs the narrowest check, makes one
  local commit, and resolves the thread; **Comment and resolve** posts an approved
  reply and resolves the thread; **Skip** leaves both alone. Never pushes, so resolved
  threads point at commits only the local clone has until the user pushes.
- `skills/local-address-pr-comments/scripts/fetch-comments.sh` — builds the triage
  queue from the GraphQL review threads plus the REST reviews and conversation
  comments, normalized with the ids a reply or a resolve needs.
- `skills/local-address-pr-comments/scripts/queue.jq` and
  `tools/test-fetch-comments.sh` — the queue builder's jq program, out of the shell
  heredoc so `make test` and CI run it over fixtures without a network or a live pull
  request, plus the fixtures themselves.
- `skills/local-address-pr-comments/references/response-strategies.md` — how to decide
  between fixing and answering each kind of review comment.

### Changed

- README documents the fourth skill, its install and update commands, its
  requirements, and the layout entry.

## [2.1.0] - 2026-11-14

### Added

- `local-triage-work` — turn a GitHub issue link or a text description of a bug,
  feature, or tech debt into an agreed plan and local commits: interview the user,
  design a strategy, present the implementation plan for review, then on approval cut
  a feature branch from the updated base branch and commit each step. Never pushes or
  opens a PR.

### Changed

- `local-open-pr` now names `local-triage-work` as the owner of branch and commits,
  replacing the reference to `local-feature-branch-pr`, which does not ship in this
  repository.
- README documents the three-skill pipeline and includes `local-triage-work` in the
  install, update, and layout instructions.
- Base-branch resolution is now unambiguous in `local-open-pr` and
  `local-triage-work`: use the only `master`/`main` that exists, and ask when both do,
  instead of preferring one and asking at the same time.

## [2.0.0] - 2026-11-14

### Added

- `make link`, `make sync`, `make deploy`, and `make drift` (scripts under `tools/`)
  so the installed copy in `~/.agents/skills` and this checkout cannot diverge
  unnoticed, plus `make release`, which validates, tags, pushes, and publishes notes
  from this file.
- README section "Editing a skill" documenting which side is writable and what to run
  after a change.

### Changed

- `local-open-pr` now links the issue(s) a PR resolves: the body carries one
  `Closes #N` (or `Closes owner/repo#N`) line per issue, resolved from the user's
  request, the branch commits, or the branch name, verified with `gh issue view`,
  and omitted when the branch closes none. This changes the fixed PR shape, so it
  is a major release.

## [1.0.0] - 2026-11-14

### Added

- `local-code-review` — review a GitHub pull request from a clone checked out on the
  PR's updated base branch: PR summary, diff-health checklist, integration with local
  code, tests and regressions, a green/yellow/orange/red diagnostic, and per-finding
  triage that publishes the accepted findings to GitHub.
- `local-open-pr` — open the pull request for the current branch with a fixed shape:
  one sentence for the problem target, one for how it is solved, and a Mermaid
  data-flow diagram of the Dart, Kotlin, and Python components the diff touches.
- `tools/validate-skills.py` plus the `validate-skills` workflow, keeping frontmatter,
  the catalog description cap, and the paths cited by each body in sync.

[Unreleased]: https://github.com/CodandoTV/agent-skills/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/CodandoTV/agent-skills/releases/tag/v2.1.0
[2.0.0]: https://github.com/CodandoTV/agent-skills/releases/tag/v2.0.0
[1.0.0]: https://github.com/CodandoTV/agent-skills/releases/tag/v1.0.0
