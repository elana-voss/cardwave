import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Adds a warning banner in case no
/// AI provider has been configured
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.onEndDrawerChanged,
    this.resizeToAvoidBottomInset,
    this.useSafeArea = true,
    this.floatingActionButton,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final void Function(bool)? onEndDrawerChanged;
  final bool? resizeToAvoidBottomInset;
  final bool useSafeArea;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    // 1. Check if the provider is missing globally
    final settingsService = context.watch<SettingsService>();
    final hasProvider = settingsService.settings.providerConfigs.isNotEmpty;

    // 2. Prepare the main content
    var content = body;

    // 3. If missing, inject the banner at the TOP of the page layout
    if (!hasProvider) {
      content = Column(
        children: [
          // Sits exactly where AppBar.bottom would be, but handles dynamic text heights!
          const _MissingProviderBanner(),

          // The rest of the page takes up the remaining space
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      // SafeArea handles notches and nav bars automatically
      body: useSafeArea ? SafeArea(child: content) : content,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      onEndDrawerChanged: onEndDrawerChanged,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _MissingProviderBanner extends StatelessWidget {
  const _MissingProviderBanner();

  @override
  Widget build(BuildContext context) {
    // Watching means the banner re-checks (and hides itself) as soon as a
    // provider is configured — e.g. when the user finishes onboarding.
    final profiles = context.watch<SettingsService>().settings.providerConfigs;
    if (profiles.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Connect an AI provider.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                  foregroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
                // No post-return work needed — `context.watch` above rebuilds
                // (and hides) the banner once onboarding adds a provider.
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutesEnum.onboarding.name),
                child: const Text('Set Up Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
