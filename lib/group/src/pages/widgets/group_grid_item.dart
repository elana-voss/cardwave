import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/controllers/group_grid_controller.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _GroupGridItemActionEnum { delete }

/// Group grid card — mirrors the row layout of `CharacterGridItem`: a fixed
/// thumbnail column on the left, an expanded details column on the right,
/// with an edit icon and popup action menu in the title row.
///
/// Members load once when the tile mounts and reload only when the library
/// changes or the group's member list does — a `FutureBuilder` here would
/// re-read every member card from disk on each unrelated rebuild (scroll,
/// theme, parent notify).
class GroupGridItem extends StatefulWidget {
  const GroupGridItem({
    required this.group,
    required this.onTap,
    required this.onChanged,
    super.key,
  });
  final GroupFile group;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  @override
  State<GroupGridItem> createState() => _GroupGridItemState();
}

class _GroupGridItemState extends State<GroupGridItem> {
  late final CharacterService _characterService;
  List<CharacterFile> _resolvedMembers = const [];

  @override
  void initState() {
    super.initState();
    _characterService = context.read<CharacterService>();
    _characterService.addListener(_reloadMembers);
    unawaited(_reloadMembers());
  }

  @override
  void didUpdateWidget(GroupGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.group.group.memberAppCardIds,
      widget.group.group.memberAppCardIds,
    )) {
      unawaited(_reloadMembers());
    }
  }

  @override
  void dispose() {
    _characterService.removeListener(_reloadMembers);
    super.dispose();
  }

  Future<void> _reloadMembers() async {
    final members = await _characterService.loadByAppCardIds(
      widget.group.group.memberAppCardIds,
    );
    if (!mounted) return;
    setState(() => _resolvedMembers = members);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupGridItemThumbnail(members: _resolvedMembers),
            _GroupGridItemDetails(
              group: widget.group,
              resolvedMembers: _resolvedMembers,
              onChanged: widget.onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGridItemThumbnail extends StatelessWidget {
  const _GroupGridItemThumbnail({required this.members});
  final List<CharacterFile> members;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppConstants.gridThumbnailWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (members.isEmpty)
            const _EmptyGroupPlaceholder()
          else
            _MosaicThumbnail(members: members),
        ],
      ),
    );
  }
}

class _EmptyGroupPlaceholder extends StatelessWidget {
  const _EmptyGroupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.group,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MosaicThumbnail extends StatelessWidget {
  const _MosaicThumbnail({required this.members});
  final List<CharacterFile> members;

  @override
  Widget build(BuildContext context) {
    final count = members.length;
    const width = AppConstants.gridThumbnailWidth;
    final shown = members.take(4).toList();
    final overflow = count > 4 ? count - 3 : 0;

    if (shown.length == 1) {
      return ImageThumbnail(file: shown.first, width: width);
    }
    if (shown.length == 2) {
      return Row(
        children: [
          Expanded(
            child: ImageThumbnail(file: shown.first, width: width / 2),
          ),
          Expanded(
            child: ImageThumbnail(file: shown[1], width: width / 2),
          ),
        ],
      );
    }
    if (shown.length == 3) {
      return Row(
        children: [
          Expanded(
            child: ImageThumbnail(file: shown.first, width: width / 2),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ImageThumbnail(file: shown[1], width: width / 2),
                ),
                Expanded(
                  child: ImageThumbnail(file: shown[2], width: width / 2),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // Reached only when `shown` has 4 entries (`members.take(4)` and the
    // 1/2/3 cases handled above), so indices 0..3 are all valid.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                // ignore: qcheck/avoid_unsafe_collection_methods
                child: ImageThumbnail(file: shown.first, width: width / 2),
              ),
              Expanded(
                // ignore: qcheck/avoid_unsafe_collection_methods
                child: ImageThumbnail(file: shown[1], width: width / 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                // ignore: qcheck/avoid_unsafe_collection_methods
                child: ImageThumbnail(file: shown[2], width: width / 2),
              ),
              Expanded(
                child: overflow > 0
                    ? _OverflowCell(count: overflow)
                    // ignore: qcheck/avoid_unsafe_collection_methods
                    : ImageThumbnail(file: shown[3], width: width / 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverflowCell extends StatelessWidget {
  const _OverflowCell({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        t.group.groupGridItem.overflowCountBadge(count: count),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GroupGridItemDetails extends StatelessWidget {
  const _GroupGridItemDetails({
    required this.group,
    required this.resolvedMembers,
    required this.onChanged,
  });
  final GroupFile group;
  final List<CharacterFile> resolvedMembers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GroupGridItemHeader(group: group, onChanged: onChanged),
            const SizedBox(height: 2),
            const SizedBox(height: 6),
            _GroupGridItemDescription(resolvedMembers: resolvedMembers),
            const SizedBox(height: 8),
            _GroupGridItemFooter(group: group),
          ],
        ),
      ),
    );
  }
}

class _GroupGridItemHeader extends StatelessWidget {
  const _GroupGridItemHeader({required this.group, required this.onChanged});
  final GroupFile group;
  final VoidCallback onChanged;

  Future<void> _rename(BuildContext context) async {
    final committed = await GroupGridController.renameGroup(
      service: context.read<GroupFileService>(),
      group: group,
    );
    if (committed) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // Adjacent `Expanded`/`IconButton` pair is flush (0 gap);
    // `spacing:` would add an unwanted gap.
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: group.group.name,
              preferBelow: false,
              child: Text(
                group.group.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () => _rename(context),
        ),
        const SizedBox(width: 4),
        _GroupGridActionMenu(group: group, onChanged: onChanged),
      ],
    );
  }
}

class _GroupGridActionMenu extends StatelessWidget {
  const _GroupGridActionMenu({required this.group, required this.onChanged});
  final GroupFile group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return PopupMenuButton<_GroupGridItemActionEnum>(
      padding: EdgeInsets.zero,
      onSelected: (value) {
        final service = context.read<GroupFileService>();
        final errorColor = Theme.of(context).colorScheme.error;
        unawaited(() async {
          switch (value) {
            case _GroupGridItemActionEnum.delete:
              final committed = await GroupGridController.confirmAndDelete(
                service: service,
                group: group,
                confirmColor: errorColor,
              );
              if (committed) onChanged();
          }
        }());
      },
      itemBuilder: (context) => [
        PopupMenuItem<_GroupGridItemActionEnum>(
          value: _GroupGridItemActionEnum.delete,
          child: Row(
            spacing: 8,
            children: [
              Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              Text(
                t.common.actions.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.more_vert, size: 20),
    );
  }
}

class _GroupGridItemDescription extends StatelessWidget {
  const _GroupGridItemDescription({required this.resolvedMembers});
  final List<CharacterFile> resolvedMembers;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final memberNames = resolvedMembers.map((m) => m.card.name).join(', ');
    return Expanded(
      child: Text(
        memberNames.isEmpty ? t.group.groupGridItem.noMembersYetMessage : memberNames,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
          height: 1.2,
        ),
      ),
    );
  }
}

class _GroupGridItemFooter extends StatelessWidget {
  const _GroupGridItemFooter({required this.group});
  final GroupFile group;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final memberCount = group.group.memberAppCardIds.length;
    return Text.rich(
      TextSpan(
        children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(Icons.group, size: 14, color: Colors.grey),
          ),
          TextSpan(
            text:
                ' ${t.group.dialogSelectGroup.memberCountLabel(n: memberCount)}',
          ),
          if (group.lastActive > 0) ...[
            const TextSpan(text: ' • '),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.chat_bubble_outline,
                size: 14,
                color: Colors.grey,
              ),
            ),
            TextSpan(text: ' ${UtilsApp.timeAgo(group.lastActive)}'),
          ],
        ],
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 10,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
