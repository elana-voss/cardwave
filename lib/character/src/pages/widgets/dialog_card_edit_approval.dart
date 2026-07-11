import 'dart:async';

import 'package:cardwave/character/src/controllers/card_edit_gate_controller.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows one row per proposal, lets the user approve / deny each one, and
/// returns `List<ApprovalDecision>` in the same order as `proposals`. Used
/// by [CardEditGateController.askUser]; widget consumers normally invoke
/// it via [NavigationService.showCardEditApprovalDialog].
///
/// Defaults each row to approved; the user flips off the ones they want
/// to reject (and optionally types a reason the assistant sees). Bulk
/// "Approve all" / "Deny all" buttons flip every row at once.
class DialogCardEditApproval extends StatefulWidget {
  const DialogCardEditApproval({required this.proposals, super.key});
  final List<CardEditProposal> proposals;

  @override
  State<DialogCardEditApproval> createState() =>
      _DialogCardEditApprovalState();
}

class _DialogCardEditApprovalState extends State<DialogCardEditApproval> {
  late final List<_RowState> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List.generate(widget.proposals.length, (_) => _RowState());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _setAll({required bool approved}) {
    setState(() {
      for (final r in _rows) {
        r.approved = approved;
      }
    });
  }

  List<ApprovalDecision> _collect() {
    return [
      for (final r in _rows)
        if (r.approved)
          const ApprovalDecision(approved: true)
        else
          ApprovalDecision(
            approved: false,
            reason: r.reasonController.text.trim().isEmpty
                ? null
                : r.reasonController.text.trim(),
          ),
    ];
  }

  void _disableModalityApproval(CardEditModality m) {
    final svc = context.read<SettingsService>();
    final s = svc.settings;
    switch (m) {
      case CardEditModality.edit:
        s.assistantCardEditRequireApprovalForEdits = false;
      case CardEditModality.addition:
        s.assistantCardEditRequireApprovalForAdditions = false;
      case CardEditModality.deletion:
        s.assistantCardEditRequireApprovalForDeletions = false;
    }
    unawaited(svc.saveSettings());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modalities = widget.proposals.map((p) => p.modality).toSet();

    return AppDialog(
      showDismissButton: false,
      actions: [
        TextButton(
          onPressed: () => _setAll(approved: false),
          child: Text(t.character.cardEditApproval.denyAll),
        ),
        TextButton(
          onPressed: () => _setAll(approved: true),
          child: Text(t.character.cardEditApproval.approveAll),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_collect()),
          child: Text(t.character.cardEditApproval.confirm),
        ),
      ],
      builder: (context, isMobile) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              t.character.cardEditApproval.dialogTitle,
              style: theme.textTheme.titleLarge,
            ),
            for (var i = 0; i < widget.proposals.length; i++) ...[
              if (i > 0) const Divider(height: 8),
              _ProposalRow(
                // i bounded by widget.proposals.length; _rows was generated
                // with the same length in initState.
                // ignore: qcheck/avoid_unsafe_collection_methods
                proposal: widget.proposals[i],
                // ignore: qcheck/avoid_unsafe_collection_methods
                state: _rows[i],
                // ignore: qcheck/avoid_unsafe_collection_methods
                onApprovedChanged: (v) => setState(() => _rows[i].approved = v),
              ),
            ],
            if (modalities.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in modalities)
                    TextButton.icon(
                      icon: const Icon(Icons.notifications_off_outlined,
                          size: 18),
                      label: Text(
                        t.character.cardEditApproval.dontAskAgainFor(
                          modality: _modalityLabel(m),
                        ),
                      ),
                      onPressed: () => _disableModalityApproval(m),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

String _modalityLabel(CardEditModality m) {
  switch (m) {
    case CardEditModality.edit:
      return t.character.cardEditApproval.modalityLabel.edits;
    case CardEditModality.addition:
      return t.character.cardEditApproval.modalityLabel.additions;
    case CardEditModality.deletion:
      return t.character.cardEditApproval.modalityLabel.deletions;
  }
}

class _RowState {
  bool approved = true;
  final TextEditingController reasonController = TextEditingController();
  void dispose() => reasonController.dispose();
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.proposal,
    required this.state,
    required this.onApprovedChanged,
  });
  final CardEditProposal proposal;
  final _RowState state;
  final ValueChanged<bool> onApprovedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_modalityVerb(proposal.modality)} ${proposal.fieldLabel}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: Icon(
                state.approved
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: state.approved ? theme.colorScheme.primary : null,
              ),
              onPressed: () => onApprovedChanged(!state.approved),
              tooltip: state.approved
                  ? t.character.cardEditApproval.tapToDeny
                  : t.character.cardEditApproval.tapToApprove,
            ),
          ],
        ),
        _ProposalDiff(proposal: proposal),
        if (!state.approved)
          TextField(
            controller: state.reasonController,
            decoration: InputDecoration(
              labelText: t.character.cardEditApproval.reasonLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
      ],
    );
  }
}

String _modalityVerb(CardEditModality m) {
  switch (m) {
    case CardEditModality.edit:
      return t.character.cardEditApproval.modalityVerb.edit;
    case CardEditModality.addition:
      return t.character.cardEditApproval.modalityVerb.addition;
    case CardEditModality.deletion:
      return t.character.cardEditApproval.modalityVerb.deletion;
  }
}

class _ProposalDiff extends StatelessWidget {
  const _ProposalDiff({required this.proposal});
  final CardEditProposal proposal;

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    if (p is CardScalarSetProposal) {
      return _EditDiff(oldValue: p.oldValue, newValue: p.newValue);
    }
    if (p is CardListSetProposal) {
      return _EditDiff(oldValue: p.oldValue, newValue: p.newValue);
    }
    if (p is CardListAppendProposal) {
      return _SingleStyledPanel(
        title: t.character.cardEditApproval.newEntryTitle,
        text: p.newValue,
        kind: _SingleStyleKind.insertion,
      );
    }
    if (p is CardListDeleteProposal) {
      return _SingleStyledPanel(
        title: t.character.cardEditApproval.removingTitle,
        text: p.oldValue,
        kind: _SingleStyleKind.deletion,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Edit / list-set diff. Cached: `diff_match_patch` runs once at
/// `initState`; the dialog's `setState` rebuilds (row approve/deny
/// toggles) reuse the cached diff and only rebuild the inline spans.
class _EditDiff extends StatefulWidget {
  const _EditDiff({required this.oldValue, required this.newValue});
  final String oldValue;
  final String newValue;

  @override
  State<_EditDiff> createState() => _EditDiffState();
}

class _EditDiffState extends State<_EditDiff> {
  late List<Diff> _diffs;

  @override
  void initState() {
    super.initState();
    _diffs = _computeDiffs(widget.oldValue, widget.newValue);
  }

  @override
  void didUpdateWidget(_EditDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldValue != widget.oldValue ||
        oldWidget.newValue != widget.newValue) {
      _diffs = _computeDiffs(widget.oldValue, widget.newValue);
    }
  }

  static List<Diff> _computeDiffs(String oldValue, String newValue) {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(oldValue, newValue);
    dmp.diffCleanupSemantic(diffs);
    return diffs;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        DiffPanel(
          title: t.character.cardEditApproval.beforeTitle,
          spans: buildDiffSpans(context, _diffs, showDeletions: true),
          tokenCount: null,
        ),
        DiffPanel(
          title: t.character.cardEditApproval.afterTitle,
          spans: buildDiffSpans(context, _diffs, showInsertions: true),
          tokenCount: null,
        ),
      ],
    );
  }
}

enum _SingleStyleKind { insertion, deletion }

/// One-panel preview for an append (whole new entry shown insertion-styled)
/// or a delete (old entry shown strikethrough deletion-styled).
class _SingleStyledPanel extends StatelessWidget {
  const _SingleStyledPanel({
    required this.title,
    required this.text,
    required this.kind,
  });
  final String title;
  final String text;
  final _SingleStyleKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = switch (kind) {
      _SingleStyleKind.insertion => TextStyle(
          color: theme.colorScheme.primary,
          backgroundColor:
              theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
      _SingleStyleKind.deletion => TextStyle(
          color: theme.colorScheme.error,
          backgroundColor:
              theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          decoration: TextDecoration.lineThrough,
        ),
    };
    return DiffPanel(
      title: title,
      spans: [TextSpan(text: text, style: style)],
      tokenCount: null,
    );
  }
}
