# Contributing to Cardwave

Thanks for being part of the community. Contributions that make this tool better for hobbyists and personal users are welcome.

## Contributor License Agreement

By submitting a Pull Request or contributing code:

- Your contributions are licensed under PolyForm Noncommercial 1.0.0.
- You grant Cardwave a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare derivative works of, sublicense, and distribute your contributions.
- You represent that you are the legal owner of the code you are submitting.

The `sublicense` grant lets Cardwave re-license the combined work later without per-contributor consent.

## Development guidelines

- **Flutter channel**: stable
- **State management**: Provider + ChangeNotifier (`context.read` for one-shot, `context.watch` / `context.select` for rebuilds)
- **Platforms**: test on Windows, Android, and Web before opening a PR
- **Dependencies**: avoid commercial-only packages; avoid GPL/AGPL libraries without prior discussion (would force a license change for the whole project)

## Non-commercial intent

Built for the community. Contributions must align with keeping this free for personal use and unavailable for commercial exploitation.
