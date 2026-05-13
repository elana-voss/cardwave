# AI development context & rules

## Project mission

A cross-platform Flutter application (Android, Web, Windows).
**License**: PolyForm Noncommercial 1.0.0 (source-available).

## Operational rules for LLM

1. **Commercial shield**: never suggest features or third-party SDKs that require a paid commercial license.
2. **License purity**: prefer MIT, Apache 2.0, or BSD-3-Clause libraries. Avoid GPL/AGPL libraries that would force a project-wide license change.
3. **Cross-platform first**: when writing Flutter code:
   - Use `kIsWeb` or `Platform.is...` checks for platform-specific APIs.
   - Ensure UI layouts are responsive (handle mobile vs. desktop screens).
   - Verify packages added to `pubspec.yaml` support Windows, Android, and Web.
4. **Branding**: do not modify assets in `branding/`. These are unregistered trademarks of Cardwave and are excluded from the software license.

## Code style

- Clean architecture.
- Keep `lib/` organized by feature or layer.
- Follow the existing patterns; match the style of neighboring files.
