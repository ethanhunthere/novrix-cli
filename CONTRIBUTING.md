# Contributing to novrix

Thanks for wanting to help! novrix is a small, focused CLI — the whole point
is that it stays **one lightweight bash script** that runs anywhere. Please
keep that spirit when you contribute.

## Ground rules

- **bash 4+, curl, jq only.** No Node, no Python, no Docker, no new runtime
  dependencies. If you're adding a feature that needs another tool, argue
  hard for it first — it probably belongs in a plugin.
- **Works on every platform.** Code must run on macOS (stock bash 3.2
  handled by the guard), every Linux, Windows Git Bash/MSYS2/Cygwin, and the
  BSDs. No GNU-only tools: no `find -mmin`, no `${var,,}`, no GNU `sed -i`.
  When in doubt, use the portable form (`tr`, POSIX `stat`) — CI runs the
  suite on three OSes and will catch you.
- **Offline tests.** Every new behavior needs a fixture in
  `tests/fixtures/` and a check in `tests/smoke.sh`. The suite must pass with
  zero network access (`NOVRIX_API_DIR` fixture mode).
- **Small, focused PRs.** One concern per PR. Squash your commits if they're
  noisy.

## Development loop

```sh
make build   # assemble bin/novrix from src/ modules
make test    # run the offline suite (bash tests/smoke.sh)
make lint    # shellcheck (if installed)
make check   # all of the above
```

If you edit `src/lib/*.sh`, run `bash build.sh` so `bin/novrix` stays in
sync — CI fails on drift (`build.sh` is deterministic, so the diff must be
empty).

## Where things live

| Concern | File |
| --- | --- |
| Runtime guards, constants, colors | `src/lib/bootstrap.sh` |
| Errors, spinner, option parsing, cache age | `src/lib/core.sh` |
| HTTP + cache + fixtures | `src/lib/api.sh` |
| jq snippets, rendering helpers | `src/lib/format.sh` |
| Command registries (SERIES/META/ALIASES) | `src/lib/data.sh` |
| AI agent (DeepSeek) | `src/lib/ai.sh` |
| Troll easter egg, typo resolution | `src/lib/typo.sh` |
| Command implementations | `src/lib/commands.sh` |
| Dispatch, REPL, entry point | `src/lib/cli.sh` |

Adding a command? Often it's one line in `src/lib/data.sh` plus one `cmd_*`
in `src/lib/commands.sh` — help, shortcuts, and typo-matching pick it up
automatically.

## Testing

```sh
bash tests/smoke.sh            # everything
```

To test the live AI agent locally (needs network + key):

```sh
export DEEPSEEK_API_KEY=sk-...
./bin/novrix fgredd            # spinner + AI fix
./bin/novrix fucking           # troll easter egg
./bin/novrix ai "hello"        # chat
```

Never commit a real API key — `tests/smoke.sh` has a guardrail that fails CI
if any key-shaped string appears in the repo.

## Commit conventions

- Imperative subject line, e.g. `fix typo resolution for multi-word phrases`
- Reference the issue/PR number when applicable
- `--no-gpg-sign` is fine; a clean history matters more than signatures

## Before you open the PR

1. `make check` passes locally.
2. `bin/novrix` is in sync with `src/` (rebuild + `git diff --stat` clean).
3. New behavior has fixtures + smoke checks.
4. README updated if the user-facing surface changed (commands, flags,
   env vars).
5. No secrets, no absolute paths, no OS-specific leftovers.

PRs are tested on **ubuntu, macOS, and Windows** via GitHub Actions — the
macOS job deliberately runs the suite on stock bash 3.2 to prove the
compat guards work.

Thank you 🚀
