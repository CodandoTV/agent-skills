# Plan template

Loaded during Phase 4 of `local-triage-work`. The plan is a proposal, not a work
order: nothing is created until the user chooses **Proceed**.

## Shape

Print this in chat, filled in. Omit a section only when it genuinely does not apply,
and say why.

````markdown
## Implementation plan — <one-line title>

**Problem:** one sentence naming the broken, missing, or risky thing.
**Approach:** one sentence naming the mechanism that will change it.

### Evidence

- Issue: <ref> (<state>) — one-line summary of what it asks for
- Code: `path` / `Symbol` — current behavior, quoted
- Reproduction: `<command>` → `<result>` (or "not reproduced: <what was tried>")
- Existing tests: `<path>` covers <behavior>
- Conventions: <AGENTS.md / CONTRIBUTING.md / build tool> requires <rule>

### Approach

**Chosen:** <mechanism>.
Why: <one or two sentences tying it to the evidence and the repository's patterns>.

**Rejected:** <alternative> — <one line: cost, risk, or mismatch>.
**Rejected:** <alternative> — <one line>.

If the work is too big for one branch: "This plan covers <slice>; <rest> is a
follow-up."

### Changes by subsystem

- `<area>` — <files and symbols>; <what changes and why>
- `<area>` — ...

### Interface and data changes

- Public API / CLI / config: <signature, default, compatibility>
- Schema or migration: <change, backfill, rollback>
- Data flow: `<producer>` → `<transformer>` → `<consumer>`, carrying <data>
- Serialization / wire format: <change or "unchanged">

Write "none" explicitly when a category is untouched.

### Steps

1. <step> — verify: `<command or check>`
2. <step> — verify: ...
3. ...

Each step should leave the tree in a state the repository's checks still accept.

### Verification

- `<test command>` — expected: <result>
- `<typecheck / lint command>` — expected: <result>
- Manual: <what to do and what to look for>

### Acceptance criteria

- [ ] <independently checkable criterion>
- [ ] <independently checkable criterion>

### Risks and rollback

- <risk> → <mitigation>
- Rollback: `<git command>` or <revert plan>

### Delivery

- Base: `<remote>/<base>` @ `<short sha>`
- Branch: `<type>/<slug>`
- Commits: one per completed step, conventional messages, local only
- Nothing is pushed; `local-open-pr` opens the PR later

### Out of scope / follow-ups

- <thing this deliberately does not do>
- <thing deferred to a later change>

### Assumptions

- <decision taken without a direct answer, and why>
````

## Approval block

After printing the plan, ask exactly one question:

```text
1. Proceed (Recommended) — cut <branch> from <remote>/<base> and implement the
   plan, committing each step locally.
2. Adjust plan — tell me what to change; I revise and re-present the whole plan.
3. Stop — create nothing; the plan stays in chat.
```

- An empty or skipped answer means **Stop**.
- "Sounds good", "go ahead", or a partial answer is not **Proceed**; ask once more
  with the three options.
- On **Adjust**, apply every point, re-print the full plan, and ask again.
- Never create the branch, write a file, or commit before **Proceed**.

## Branch conventions

- `<type>/<slug>`, where `<type>` maps the request:
  bug → `fix`, feature → `feat`, tech debt → `refactor` (or `chore` when it is
  housekeeping), documentation-only → `docs`, test-only → `test`.
- `<slug>` is 2–5 lowercase kebab-case words drawn from the request, for example
  `fix/login-timeout`, `feat/saved-search`, `refactor/payment-client`.
- Propose the name in the delivery section; the user can change it while reviewing.
- Cut from the fetched `<remote>/<base>`, not from the local `<base>`, and use
  `--no-track` so the branch does not inherit the base as its upstream.
- If the branch already exists, ask reuse vs rename. Never force or delete. Reuse only
  with the user's explicit choice, and never fold unrelated commits into the work.

## Commit conventions

- One commit per completed plan step; do not leave WIP commits behind.
- Subject: `<type>(<scope>): <imperative summary>`, under about 72 characters, no
  trailing period. Body: why the change is needed, and anything a reviewer would
  otherwise have to reconstruct.
- Match the repository's observed convention when it differs from this default.
- Stage explicit paths. Never `git add -A` or `git add .`.
- Let pre-commit hooks run. Never `--no-verify` unless the user explicitly asks.
- Never commit secrets, credentials, build output, generated files, or changes a
  step did not touch.

## Quality bar

Before presenting, check the plan against this list:

- [ ] Every step has a completion criterion and a verification.
- [ ] Every acceptance criterion can be checked without reading the implementer's
      mind.
- [ ] The chosen approach explains why the rejected ones lost.
- [ ] Public API, schema, and data-flow changes are stated, or explicitly "none".
- [ ] The branch name and base are concrete, not `feature/...`.
- [ ] Assumptions are visible and marked.
- [ ] The work fits one branch; anything else is a follow-up.
- [ ] No section hides a decision the user has not seen.

## Filled example

````markdown
## Implementation plan — Stop dropping the trailing search term on quote

**Problem:** A query that ends inside a quoted phrase loses its last word when the
filter is built, so searches like `"payment timeout` return unrelated results.
**Approach:** Tokenize once in `SearchQueryParser` and carry the partial phrase
through normalization instead of trimming it.

### Evidence

- Issue: #142 (open) — trailing quoted terms are dropped
- Code: `SearchQueryParser.kt` / `parse()` — `trimEnd()` runs after quote pairing
- Reproduction: `./gradlew test --tests SearchQueryParserTest` → 1 failing case
- Existing tests: `SearchQueryParserTest` covers balanced quotes only
- Conventions: CONTRIBUTING.md requires a test per parser edge case

### Approach

**Chosen:** keep the partial phrase as a `Phrase(open = true)` token and let the
filter render it as a prefix match.
Why: it reuses the existing token model; no new parser and no change to the query
DSL.

**Rejected:** special-case the final quote in the filter — duplicates parser logic.
**Rejected:** reject unbalanced queries — breaks the current lenient behavior.

### Changes by subsystem

- Search parsing — `SearchQueryParser` token model; one new token flag
- Search filtering — `FilterBuilder` renders open phrases as prefix matches

### Interface and data changes

- Public API: `FilterBuilder.build()` signature unchanged
- Schema: none
- Data flow: `SearchQueryParser` → `FilterBuilder` → `SearchRepository`, carrying
  `Phrase(token, open)`

### Steps

1. Add the `open` flag and pair the trailing quote — verify: new parser test
2. Render open phrases as prefix matches — verify: filter test
3. Remove the trimming — verify: full search suite

### Verification

- `./gradlew test --tests '*Search*'` — all green
- `./gradlew lint` — clean
- Manual: search `"payment timeout` in the debug build

### Acceptance criteria

- [ ] Unbalanced trailing quotes keep their last term
- [ ] Balanced quotes behave exactly as before
- [ ] A parser test covers both cases

### Risks and rollback

- Risk: prefix matches broaden results → keep the existing term limit
- Rollback: `git switch <base>` and delete the branch

### Delivery

- Base: `origin/main` @ `a1b2c3d`
- Branch: `fix/search-trailing-quote`
- Commits: one per step, conventional, local only

### Out of scope

- Fuzzy matching, ranking changes, and the query DSL

### Assumptions

- Lenient parsing is intentional; no user-facing error is required
````
