# Security Policy

## Supported versions

Only the latest release is supported. Fixes are shipped in new releases, not
backported — upgrading is the fix (`curl -fsSL
https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh |
bash`).

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Report them via
a [private security advisory](
https://github.com/ethanhunthere/novrix-cli/security/advisories/new) (or by
emailing the maintainers directly).

Include in your report:

- the novrix version (`novrix --version`) and your OS
- a minimal reproduction (commands, environment, any fixture/response data)
- the impact you observed and your suggested severity

You can expect an acknowledgement within 72 hours and a fix plan shortly
after. Once a patch is released, the advisory is published after a short
embargo so everyone has time to upgrade.

## Scope

novrix is a client-side bash script. Its only network calls are the public
NOVRIX, FRED and Telegram endpoints it is configured to read, plus the
DeepSeek API when an AI key is configured.

**In scope**

- Remote code execution via crafted API responses, Telegram channel HTML, or
  FRED CSV data.
- Secrets mishandling — the `DEEPSEEK_API_KEY` read from
  `~/.config/novrix/keys.conf` (never committed, never logged).
- Shell injection through user input (commands, questions, dates, env vars).

**Out of scope**

- The novrix.io API itself (report that to NOVRIX).
- Social engineering of the maintainers or other users.
- Missing or expired API keys — failing with a friendly hint is by design.

## Good hygiene for contributors

- Never commit `keys.conf` or any `sk-…` key — CI fails on hardcoded keys.
- `keys.conf` is created with `0600` permissions by the installer; keep it
  that way.
- The test suite is fully offline (fixture-driven) — new behavior needs a
  fixture, not a live API call.
