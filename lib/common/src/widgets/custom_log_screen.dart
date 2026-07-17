import 'dart:async';
import 'dart:convert';

import 'package:cardwave/common/src/utils/logging_service.dart';
import 'package:cardwave/common/src/utils/navigation_service.dart';
import 'package:cardwave/common/src/widgets/app_search_field.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app log viewer — a filterable, searchable list over
/// [LoggingService.logsNotifier], reachable from the logs route and the
/// settings menu. Lives in the UI layer (not in `logging_service.dart`)
/// so the service stays UI-free.
class CustomLogScreen extends StatefulWidget {
  const CustomLogScreen({super.key});

  @override
  State<CustomLogScreen> createState() => _CustomLogScreenState();
}

class _CustomLogScreenState extends State<CustomLogScreen> {
  final Set<LogLevelEnum> _activeFilters = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(t.common.logs.title),
        actions: [
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                icon: const Icon(Icons.filter_alt),
                tooltip: t.common.logs.filterTooltip,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: LogLevelEnum.values.map((level) {
              return CheckboxMenuButton(
                value: _activeFilters.contains(level),
                closeOnActivate: false,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _activeFilters.add(level);
                    } else {
                      _activeFilters.remove(level);
                    }
                  });
                },
                child: Text(
                  level.name,
                  style: TextStyle(
                    color: level.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: t.common.logs.clearTooltip,
            onPressed: () => LoggingService().logsNotifier.value = [],
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: t.common.logs.exportTooltip,
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: AppSearchField(
              controller: _searchController,
              hintText: t.common.logs.searchHint,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: LoggingService().logsNotifier,
              builder: (context, logs, _) {
                final searchQuery = _searchController.text.toLowerCase();
                final filteredLogs = logs.where((entry) {
                  if (_activeFilters.isNotEmpty &&
                      !_activeFilters.contains(entry.level)) {
                    return false;
                  }
                  if (searchQuery.isNotEmpty) {
                    return entry.message.toLowerCase().contains(searchQuery) ||
                        (entry.error?.toString().toLowerCase().contains(
                              searchQuery,
                            ) ??
                            false);
                  }
                  return true;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return Center(child: Text(t.common.logs.noLogsFound));
                }

                return ListView.builder(
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[filteredLogs.length - 1 - index];
                    return _LogEntryWidget(entry: entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    final logs = LoggingService().logsNotifier.value;
    if (logs.isEmpty) {
      NavigationService().showSnackBar(t.common.logs.noLogsToExport);
      return;
    }

    final sb = StringBuffer();
    for (final entry in logs) {
      final time = entry.timestamp
          .toIso8601String()
          .split('T')
          .last
          .substring(0, 12);
      sb.writeln('[$time] [${entry.level.name}] ${entry.message}');
      if (entry.error != null) sb.writeln('Error: ${entry.error}');
      if (entry.stackTrace != null) sb.writeln('${entry.stackTrace}');
      if (entry.dataContext != null) sb.writeln('${entry.dataContext}');
      sb.writeln('-' * 40);
    }

    try {
      final fileName =
          'cardwave_logs_${DateTime.now().millisecondsSinceEpoch}.txt';
      final result = await getSaveLocation(
        suggestedName: fileName,
      );

      if (result != null) {
        final fileData = Uint8List.fromList(
          utf8.encode(sb.toString()),
        );
        final textFile = XFile.fromData(
          fileData,
          mimeType: 'text/plain',
          name: fileName,
        );
        await textFile.saveTo(result.path);

        NavigationService().showSnackBar(t.common.logs.exportedSuccessfully);
      }
    } on Exception catch (e, st) {
      LoggingService().error('Log export failed', e, st);
      NavigationService().showSnackBar(t.common.logs.exportFailed);
    }
  }
}

class _LogEntryWidget extends StatefulWidget {
  const _LogEntryWidget({required this.entry});
  final LogEntry entry;

  @override
  State<_LogEntryWidget> createState() => _LogEntryWidgetState();
}

class _LogEntryWidgetState extends State<_LogEntryWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final time = widget.entry.timestamp
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 12);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      onLongPress: () {
        unawaited(Clipboard.setData(ClipboardData(text: widget.entry.message)));
        NavigationService().showSnackBar(t.common.logs.copiedToClipboard);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        // Non-uniform: `SizedBox(4)` and a conditional `Padding(top: 8)`
        // mixed; single `spacing:` can't express both.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[$time] [${widget.entry.level.name}]',
              style: TextStyle(
                color: widget.entry.level.color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.entry.message,
              maxLines: _isExpanded ? null : 3,
              overflow: _isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            if (_isExpanded && widget.entry.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.common.logs.errorPrefix(error: '${widget.entry.error}'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            if (_isExpanded && widget.entry.stackTrace != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${widget.entry.stackTrace}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            if (_isExpanded && widget.entry.dataContext != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${widget.entry.dataContext}',
                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            if (_isExpanded)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(t.common.logs.copyLogButton),
                  onPressed: () {
                    final fullLog =
                        '[$time] [${widget.entry.level.name}] ${widget.entry.message}'
                        '${widget.entry.error != null ? '\nError: ${widget.entry.error}' : ''}'
                        '${widget.entry.stackTrace != null ? '\n${widget.entry.stackTrace}' : ''}'
                        '${widget.entry.dataContext != null ? '\n${widget.entry.dataContext}' : ''}';
                    unawaited(Clipboard.setData(ClipboardData(text: fullLog)));
                    NavigationService().showSnackBar(
                      t.common.logs.copiedEntryToClipboard,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
