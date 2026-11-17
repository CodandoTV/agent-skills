# Response strategies

Read a comment as a request, then classify it before choosing the smallest action that answers it. The repository's own rules (`AGENTS.md`, `CONTRIBUTING.md`, linter and formatter config, nearby code) override anything here.

| Comment asks for | Fix? | What the fix must contain |
|---|---|---|
| A bug, with or without steps | Yes | The behavior change plus a test that fails before and passes after, when the suite has a place for it |
| A missing test | Yes | The test only; do not refactor the code it covers |
| A null, empty, boundary, or error case | Yes | The guard and one test for the case the reviewer named |
| Style, naming, or formatting | Usually | Apply it only when repo tooling does not already enforce it; never fight a formatter |
| A question about the code | No | A reply that answers it with quoted evidence |
| A design or architecture suggestion | Sometimes | Only when it fits the repository's existing pattern and stays inside this PR's scope; otherwise reply with the tradeoff |
| Documentation or comment wording | Yes | The wording; keep the file's voice |
| Something out of scope or already tracked | No | A reply naming where it is tracked, without inventing an issue |
| A change that contradicts another comment, the PR's stated goal, or the repository's rules | No | Say so in chat before acting; let the user decide |
| A secret, token, or credential pasted into the thread | No | Redact it everywhere, never quote the value, advise rotation, and treat it as a security finding |

## Before fixing

- Read the anchored line, the whole changed file, and the nearby call sites. A comment can be right about a symptom and wrong about the fix.
- Search for the reviewer's vocabulary (function names, error strings, config keys) so the change lands where the reviewer looked.
- Check whether the fix is already in the working tree. Two comments can request the same change; the second one gets no empty commit.
- Identify the narrowest check that can fail because of this change: the file's test, the package's typecheck, the linter on the touched path. Run it, not the whole suite.
- If the comment is marked outdated, verify it against the current code first. The change may have landed already; then the action is a comment or a resolve, not an edit.

## Writing the commit

- Conventional subject, imperative, under about 72 characters, scoped to the area the comment is about.
- The body carries the trace: `Addresses review comment <url>`.
- One commit per comment. Do not fold two comments into one commit, do not amend an earlier one, do not add an unrelated cleanup.
- If a pre-commit hook rewrites files, re-read the diff; stage only the files the fix owns.

## Writing the reply

- Two to six sentences. Say what happened and where: fixed and committed, already handled at another line, intentionally unchanged and why.
- Quote a symbol or line, not the whole diff. The thread already has the diff.
- No `@` mentions, no emoji-only replies, no promises about dates.
- Match the language of the thread when it is clearly not English; otherwise English.
- Do not claim a fix is pushed, merged, or visible on GitHub. The commits are local.
- Never paste a secret, a token, a customer value, or a stack trace containing credentials.
- End with the hidden marker the skill appends; it is what makes a re-run skip this item.

## Replies that usually answer without code

- **Intentional behavior** — name the reason and the test or contract that depends on it.
- **Already handled** — point at the commit or the line where it landed.
- **Out of scope** — say why it is not this PR's job and where it belongs, without inventing a tracking issue.
- **Disagreement on approach** — state the tradeoff in one sentence and ask the reviewer to weigh in; do not silently keep the code.
- **Needs a product decision** — say the decision is not yours to make and ask the user in chat, not the reviewer.
