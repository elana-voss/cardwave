import 'package:flutter/material.dart';

/// Scaffold chrome for a sub-page pushed inside the end drawer's nested
/// navigator — an app bar with a back arrow and the page title, the body
/// below. Used by the workspace drawer's `chatSpecificRoutes`.
class AppDrawerPage extends StatelessWidget {
  const AppDrawerPage({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: child,
    );
  }
}
