import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
    final hasProvider = context.select<SettingsService, bool>(
      (s) => s.settings.providerConfigs.isNotEmpty,
    );

    var content = body;

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
    final hasProvider = context.select<SettingsService, bool>(
      (s) => s.settings.providerConfigs.isNotEmpty,
    );
    if (hasProvider) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Only one spacer in the Row; other adjacent child pairs are
          // flush (0 gap) and would gain an unwanted 16px gap.
          // ignore: qcheck/prefer_spacing
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t.common.missingProviderBanner.message,
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
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutesEnum.onboarding.name),
                child: Text(t.common.missingProviderBanner.setUpNowButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
