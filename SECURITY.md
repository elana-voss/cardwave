# Security policy

## Reporting a vulnerability

Report security issues privately via GitHub Security Advisories: https://github.com/elana-voss/cardwave/security/advisories/new

Please include:
- Affected version(s)
- Steps to reproduce
- Potential impact

Initial response within 14 days. Coordinated disclosure preferred.

## Where credentials are stored

Cardwave is a local-first app; your provider API keys never leave your device
except in requests to the AI provider you configured. On disk they are stored
in **plaintext** in the app-data directory, in two files:

- `settings.json` — the full app settings, including each provider's API key.
- the LLM-providers recovery mirror — a smaller file holding just the provider
  credentials, used to restore providers if `settings.json` is lost or its
  schema is invalidated by an upgrade.

Because these are unencrypted, treat the app-data folder as sensitive: exclude
it from screen-shares and public bug reports, and do not commit it to version
control or attach it to support bundles. On shared machines, rely on OS-level
account isolation and full-disk encryption to protect it.

