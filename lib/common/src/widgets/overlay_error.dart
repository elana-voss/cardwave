import 'dart:async';

import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/common/src/utils/logging_service.dart';
import 'package:cardwave/common/src/utils/navigation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OverlayError extends StatefulWidget {
  const OverlayError({required this.child, super.key});
  final Widget child;

  @override
  State<OverlayError> createState() => _OverlayErrorState();
}

class _OverlayErrorState extends State<OverlayError> {
  bool _hasError = false;
  bool _isLogScreenOpen = false;

  @override
  void initState() {
    super.initState();
    LoggingService().logsNotifier.addListener(_onLogUpdated);
  }

  @override
  void dispose() {
    LoggingService().logsNotifier.removeListener(_onLogUpdated);
    super.dispose();
  }

  void _onLogUpdated() {
    final logs = LoggingService().logsNotifier.value;
    if (logs.isNotEmpty &&
        logs.last.level == LogLevelEnum.error &&
        mounted &&
        !_hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _hasError = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          left: 16,
          bottom: 16,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: (_hasError && kDebugMode)
                  ?
                    // tooltip causes error due to the way the FAB is shown/hidden, so we will skip it for now
                    // ignore: qcheck/prefer_action_button_tooltip
                    FloatingActionButton.small(
                      key: ValueKey('log_fab_$_hasError'),
                      heroTag: 'error_overlay_fab',
                      // tooltip: 'Open logs',
                      backgroundColor: Theme.of(context).colorScheme.error,
                      elevation: 6,
                      onPressed: () {
                        setState(() => _hasError = false);
                        if (_isLogScreenOpen) {
                          NavigationService().navigatorKey.currentState?.pop();
                        } else {
                          _isLogScreenOpen = true;

                          if (context.mounted) {
                            unawaited(
                              NavigationService().navigatorKey.currentState
                                  ?.pushNamed(AppRoutesEnum.logging.name)
                                  .then((_) => _isLogScreenOpen = false),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.bug_report, color: Colors.white),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
