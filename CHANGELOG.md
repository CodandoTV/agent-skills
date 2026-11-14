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
  is a major release when published.

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

[Unreleased]: https://github.com/CodandoTV/agent-skills/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/CodandoTV/agent-skills/releases/tag/v1.0.0
