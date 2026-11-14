# Integration checklist (review step 2)

The checkout is the PR's **base**, so it is the source of truth for everything the diff must still fit into. Use the diff for the new code and the local files for the surrounding project.

Rules of use:

- Every claim about a consumer, caller, or dependency needs a search hit. No hit means no finding.
- Quote the local code that will break, not merely the diff line that seems risky.
- One finding per side effect, not one per file it touches.
- Skip anything tooling enforces, and let repository architecture rules override generic advice.

## A. Inventory the changed surface

- [ ] List every changed or added public symbol: functions, classes, interfaces, routes, handlers, CLI flags, config keys, environment variables, event names, queue topics, schemas, migrations, DTOs.
- [ ] List every deleted or renamed symbol.
- [ ] List every changed default, enum value, serialized field, or wire format.
- [ ] List every new dependency and every changed build/package file.

## B. Type and behavior compatibility

- [ ] All call sites pass the new parameters and handle the new return type.
- [ ] Implementations of changed interfaces are updated everywhere.
- [ ] Nullability, optionality, and default values remain safe for existing callers.
- [ ] Exhaustive switches, sealed hierarchies, and pattern matches still cover every case.
- [ ] Reflection, DI, and serialization names still resolve.
- [ ] Overloads and optional parameters do not create ambiguous calls.
- [ ] Behavior changes are intentional and reflected in callers, tests, and docs.

## C. Architecture and layering

- [ ] The change respects the dependency direction and module boundaries documented in `AGENTS.md` / `CONTRIBUTING.md`.
- [ ] No forbidden import, cycle, or cross-boundary reach is introduced.
- [ ] The code lives in the layer that owns the responsibility.
- [ ] Shared code is not placed in a leaf module or duplicated across layers.
- [ ] Platform-specific code stays behind the project's existing seams.

## D. Wiring, configuration, and build

- [ ] DI registrations, factories, providers, and scopes are updated.
- [ ] Routes, controllers, handlers, jobs, workers, and schedulers are registered.
- [ ] Feature flags, environment variables, and config defaults are added where needed.
- [ ] Build files, package manifests, and lockfiles are consistent.
- [ ] Generated clients, schemas, and code are regenerated from the source of truth.
- [ ] Deployment manifests, permissions, and secrets wiring are updated.

## E. Persistence and data

- [ ] Migrations run in the right order and tolerate the currently deployed code.
- [ ] Backfills are idempotent and bounded.
- [ ] Indexes support the new query patterns.
- [ ] ORM/model mappings and column types match the migration.
- [ ] Cache keys, queue payloads, and event schemas remain compatible.
- [ ] Transactions cover the writes that must succeed or fail together.
- [ ] Rollback leaves the database usable.

## F. External contracts

- [ ] OpenAPI, protobuf, GraphQL, and JSON schemas are updated with the implementation.
- [ ] SDK clients, generated types, and consumers outside the diff still compile or parse.
- [ ] Webhooks, callbacks, and CLI flags remain backward compatible or are versioned.
- [ ] Error codes and status codes remain meaningful to clients.
- [ ] Public documentation matches the new contract.

## G. Runtime side effects

- [ ] Startup and initialization order still works.
- [ ] Global state, singletons, and caches are not mutated in a way other features observe.
- [ ] Lifecycle, cancellation, and shutdown paths are respected.
- [ ] Threading, coroutine, and concurrency assumptions still hold.
- [ ] Logging, metrics, and tracing still describe the operation accurately.
- [ ] Permissions, capabilities, and platform settings are declared.

## H. Mergeability

- [ ] The PR's `mergeable` state is not `CONFLICTING`.
- [ ] The diff still applies to the verified base (the changed-line map was produced from that base).
- [ ] The base did not move in a way that invalidates the reviewed contract.

## Search recipes

Prefer the agent's search tool; use `rg` when running shell commands:

```bash
# Exact symbol usages
rg -n --hidden -g '!node_modules' -g '!build' -g '!dist' '\bSymbolName\b'

# Imports and module references
rg -n --hidden -g '!node_modules' -e 'from .*module' -e 'import .*module'

# Route / handler registration
rg -n 'register|route|endpoint|handler' --glob '*.{ts,js,kt,java,py,go,rs,dart,swift}'

# Config and env keys
rg -n 'NEW_CONFIG_KEY|NEW_ENV_VAR'

# Migrations and schema
rg -n 'schema|migration|createTable|alterTable'
```

## Reading the post-change file without checking it out

The diff often has only three lines of context. Fetch the head version read-only into `$SCRATCH` when the surrounding code matters. Use `$HEAD_REPO_SLUG` so fork PRs work:

```bash
gh api "repos/$HEAD_REPO_SLUG/contents/$PATH?ref=$HEAD_SHA" --jq .content | base64 --decode
```

Never write that output into the working tree.

## Severity hints

- `danger` — the integration breaks authentication, corrupts data, or leaks data.
- `major` — an existing caller, consumer, migration, or contract will break, or the PR cannot merge cleanly.
- `minor` — a wiring or compatibility gap with limited blast radius.
- `nit` — a structural preference with no behavioral consequence.
