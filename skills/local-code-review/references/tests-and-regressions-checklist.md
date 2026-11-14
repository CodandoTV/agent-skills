# Tests and regressions checklist (review step 3)

The checkout is the PR's **base**, not its head. This step is therefore **static**: inspect the test changes in the diff, reason about what they would catch, and map the regression surface. Do not execute PR code.

## A. Test inventory

- [ ] Identify the test framework, layout, naming conventions, and canonical command from local docs and manifests.
- [ ] Locate the tests that already cover the changed modules.
- [ ] Note the levels available: unit, integration, contract, end-to-end, snapshot.
- [ ] Note fixtures, factories, and test utilities that the change should reuse.

## B. Coverage of changed behavior

- [ ] Every changed behavior has at least one test at the right level.
- [ ] The happy path is covered.
- [ ] The failure paths added or changed by the diff are covered.
- [ ] Boundary and empty/null cases are covered where the change introduces them.
- [ ] Public contracts (API, serialization, CLI, events) have contract-level coverage.
- [ ] The test would plausibly fail without the production change. If it would pass either way, it does not cover the change.

## C. Test quality

- [ ] Assertions check observable behavior, not implementation details.
- [ ] Assertions are specific enough to fail for the right reason.
- [ ] Tests are deterministic: no sleeps, real clocks, live network, shared mutable state, or ordering assumptions.
- [ ] Tests are isolated and can run in any order.
- [ ] No `.skip`, `.only`, `@Ignore`, `pytest.mark.skip`, or commented-out tests hide a failure.
- [ ] No snapshot-only coverage where a behavior assertion is possible.
- [ ] Fixtures are minimal and do not encode production data.
- [ ] Test names describe the behavior and the expected outcome.

## D. Modified and deleted tests

- [ ] Changed assertions still express the intended behavior, not the new bug.
- [ ] Deleted tests are replaced when the behavior still exists.
- [ ] Tests were not weakened (loosened matchers, removed assertions, broadened tolerances) to make the suite pass.
- [ ] Snapshot updates are reviewed for unintended changes.
- [ ] Test-only changes are not hiding a production regression.

## E. Regression surfaces

- [ ] Defaults and configuration fallbacks still produce the previous result where expected.
- [ ] Serialization and wire formats remain compatible with existing data and consumers.
- [ ] Database migrations, backfills, and rollbacks are covered or explicitly reasoned about.
- [ ] API and event contracts remain compatible with local consumers found in step 2.
- [ ] Feature flags and rollout paths have a safe default.
- [ ] Existing tests that assert the old behavior were updated intentionally.
- [ ] Concurrency, retries, and idempotency behavior is unchanged or intentionally changed.

## F. CI state

Inspect the PR's checks:

```bash
gh pr checks "$PR_URL" --json name,state,bucket,link > "$SCRATCH/checks.json" || true
```

- [ ] Failing checks are recorded as findings, with the check name and link.
- [ ] Pending or skipped checks are not treated as passes.
- [ ] A failure that is clearly unrelated to the diff is labeled as pre-existing, with evidence.

## G. Execution policy

Do not check out or run the PR head in the reviewed clone. If the user wants to execute the PR's tests, print these commands for them to run in a throwaway worktree:

```bash
git fetch <remote> "pull/<n>/head"
git worktree add --detach "$SCRATCH/pr-<n>" FETCH_HEAD
( cd "$SCRATCH/pr-<n>" && <documented test command> )
git worktree remove "$SCRATCH/pr-<n>"
```

Treat PR code as untrusted: tests, fixtures, and build scripts from the PR can execute arbitrary code. Recommend a sandboxed environment or a disposable container for that run.

## Severity hints

- `danger` — a test or fixture introduces a credential or executes untrusted code in CI.
- `major` — no test for a changed behavior that can regress silently, a test deleted while the behavior remains, or a failing required check.
- `minor` — weak assertions, a missing edge case, or a documentation gap in the test suite.
- `nit` — naming or organization with no impact on coverage.
