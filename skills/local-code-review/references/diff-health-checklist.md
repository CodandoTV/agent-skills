# Diff-health checklist (review step 1)

Apply this to every changed file and hunk. The question is narrow: **is this diff good for the project's health?**

Rules of use:

- Repository-documented standards (`AGENTS.md`, `CONTRIBUTING.md`, linter/formatter config) override this list. Skip anything tooling already enforces.
- Quote the offending line, or state the explicit absence ("no timeout on the new call"). A finding without evidence is not a finding.
- Report one finding per root cause. If the same bug repeats in three hunks, one finding with three locations is better than three findings.
- This step is about the diff itself. Missing tests and integration side effects belong to steps 2 and 3.

## A. Correctness and edge cases

- [ ] Null, empty, undefined, and missing-value paths are handled.
- [ ] Bounds, indexes, and off-by-one cases are safe.
- [ ] Error paths return or throw the right thing instead of falling through.
- [ ] Concurrent or re-entrant paths are atomic where they must be.
- [ ] Defaults are explicit and match the previous behavior unless the change intends otherwise.
- [ ] Retries, idempotency, and duplicate delivery are considered for writes and jobs.
- [ ] Time zones, locales, encodings, and number/date formats are handled.
- [ ] State machines cannot reach impossible states.

## B. Error handling and failure modes

- [ ] Exceptions are not swallowed, and failures are not hidden behind a default value.
- [ ] Errors carry enough context to diagnose the failure.
- [ ] The code fails closed on auth, permission, and validation paths.
- [ ] Network and I/O calls have timeouts, cancellation, and bounded retries.
- [ ] Resources (files, sockets, locks, transactions, streams) are released on every path.
- [ ] User-facing errors are mapped without leaking internals.
- [ ] Partial failures leave data in a recoverable state.

## C. Security and privacy

- [ ] Inputs are validated at the trust boundary (type, length, range, format).
- [ ] SQL, shell, path, template, and log injection are prevented.
- [ ] New routes, handlers, jobs, and tools enforce authentication and authorization.
- [ ] Secrets, tokens, keys, and passwords are not added to code, fixtures, logs, or examples.
- [ ] PII and sensitive values are not logged or returned unnecessarily.
- [ ] Deserialization, file upload, and archive handling are safe.
- [ ] Crypto usage is current and correct (no home-grown crypto, no weak hashes for secrets).
- [ ] CSRF, SSRF, open redirects, and unsafe URL fetches are considered.
- [ ] New dependencies are justified, maintained, pinned, and license-compatible.

## D. Data and contracts

- [ ] Schema and migration changes are compatible with existing rows and rolling deploys.
- [ ] Serialization formats stay backward/forward compatible, or the break is versioned.
- [ ] Public function, API, event, and CLI contracts are not broken without a migration path.
- [ ] Response and payload shapes remain valid for existing consumers.
- [ ] Defaults and enum values do not change silently.
- [ ] Transactions and ordering prevent partial or corrupt writes.
- [ ] Data loss and irreversible operations are called out and guarded.
- [ ] Rollback is possible, and its ordering relative to the migration is safe.

## E. Resource safety and performance

- [ ] No leaks of memory, handles, connections, listeners, or subscriptions.
- [ ] Loops, queues, caches, and buffers are bounded.
- [ ] N+1 queries and repeated remote calls are avoided on hot paths.
- [ ] Blocking I/O does not run on a latency-sensitive thread.
- [ ] Queries use indexes and pagination where data can grow.
- [ ] Cache keys and invalidation are correct.
- [ ] Large payloads are streamed or bounded.

## F. Readability and maintainability

- [ ] Names reveal intent; no mysterious abbreviations.
- [ ] Dead code, commented-out code, and unused imports/parameters are removed.
- [ ] Duplication is extracted when the same shape appears more than once in the change.
- [ ] Complexity is justified; deep nesting and long functions are split where it helps.
- [ ] Comments explain *why*, not *what*.
- [ ] The change follows adjacent patterns instead of introducing a second way to do the same thing.
- [ ] Abstractions are not added for a need the change does not have.

## G. Change hygiene and scope

- [ ] The diff stays on the stated problem; unrelated edits are split out.
- [ ] Generated and vendored files are changed only through their generator.
- [ ] Debug artifacts (`print`, `console.log`, `dbg!`, breakpoints, temporary flags) are removed.
- [ ] TODOs and FIXMEs have an owner or an issue, or are removed.
- [ ] No binaries, dumps, or large assets are added without a stated reason.
- [ ] Formatting noise does not bury the real change.
- [ ] New dependencies and version bumps are intentional and explained.
- [ ] Commit messages and PR description match the actual change.

## H. Documentation and rollout

- [ ] Behavior, API, and configuration changes are reflected in docs or CHANGELOG where the repo expects it.
- [ ] New environment variables, flags, and permissions are documented.
- [ ] A feature flag or kill switch exists when rollout risk warrants it.
- [ ] Migration/backfill ordering and rollback steps are documented.
- [ ] Operational impact (metrics, alerts, runbooks) is covered where relevant.

## I. Repository standards (override)

- [ ] Read `AGENTS.md`, `CONTRIBUTING.md`, and the relevant linter/formatter config before judging style.
- [ ] When a documented rule conflicts with this checklist, the repository rule wins.
- [ ] When tooling already enforces a rule, do not report it.

## Turning a check into a finding

Use the smallest severity that is honest:

- `danger` — security breach, secret exposure, data loss/corruption, auth bypass, destructive migration, remote code execution.
- `major` — a likely runtime bug, an unhandled real failure path, a broken contract, or a resource risk on a real path.
- `minor` — a non-critical edge case, a weak error message, a small performance or documentation gap.
- `nit` — naming, style, or preference with no behavioral consequence.

If a check cannot be verified from the diff and local code, record it as an **unverified note** in the final report, not as a finding.
