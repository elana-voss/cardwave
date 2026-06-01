import 'package:cardwave/common/common.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// One user decision for one proposed card edit. Returned from the
/// approval dialog by the gate controller, one per proposal in input order.
class ApprovalDecision {
  const ApprovalDecision({required this.approved, this.reason});
  final bool approved;
  final String? reason;
}

/// Stateless orchestrator for the assistant-chat card-edit approval flow.
/// Filters proposals against the per-modality require-approval toggles,
/// opens the dialog only when at least one proposal needs human review,
/// and returns one decision per proposal in the input order.
class CardEditGateController {
  const CardEditGateController._();

  /// Returns one decision per proposal in `proposals` order. Proposals
  /// whose modality has the require-approval toggle off are auto-approved
  /// without a dialog; the remaining ones are gathered into one dialog.
  static Future<List<ApprovalDecision>> askUser(
    List<CardEditProposal> proposals, {
    required bool requireApprovalForEdits,
    required bool requireApprovalForAdditions,
    required bool requireApprovalForDeletions,
  }) async {
    if (proposals.isEmpty) return const [];

    bool needsApproval(CardEditProposal p) {
      switch (p.modality) {
        case CardEditModality.edit:
          return requireApprovalForEdits;
        case CardEditModality.addition:
          return requireApprovalForAdditions;
        case CardEditModality.deletion:
          return requireApprovalForDeletions;
      }
    }

    final gatedIndices = <int>[];
    final gated = <CardEditProposal>[];
    for (var i = 0; i < proposals.length; i++) {
      if (needsApproval(proposals[i])) {
        gatedIndices.add(i);
        gated.add(proposals[i]);
      }
    }

    if (gated.isEmpty) {
      return List<ApprovalDecision>.generate(
        proposals.length,
        (_) => const ApprovalDecision(approved: true),
      );
    }

    final gatedDecisions =
        await NavigationService().showCardEditApprovalDialog(gated);
    if (gatedDecisions == null) {
      // Dialog dismissed (back button / Escape) → cancel the whole batch,
      // including proposals auto-approved without being shown. Closing the
      // box reads as "I don't want any of these".
      return List<ApprovalDecision>.generate(
        proposals.length,
        (_) => const ApprovalDecision(approved: false, reason: '(dismissed)'),
      );
    }

    final out = List<ApprovalDecision>.filled(
      proposals.length,
      const ApprovalDecision(approved: true),
    );
    for (var i = 0; i < gatedIndices.length; i++) {
      // gatedIndices and gatedDecisions were built in step (one decision
      // per gated proposal); i is bounded by gatedIndices.length.
      // ignore: qcheck/avoid_unsafe_collection_methods
      out[gatedIndices[i]] = gatedDecisions[i];
    }
    return out;
  }
}

/// Decides the fate of one dispatch pass of card-edit write tools and applies
/// the approved ones. Pulled out of the chat controller so the propose →
/// gate → apply decision can be exercised without the full controller.
///
/// [writeRaw] is the dispatcher's result per write (same order); [proposals]
/// are the proposals the successful writes recorded, in execution order.
/// Proposals whose key is already in [deniedKeys] are denied again without
/// reopening the dialog, and newly-denied ones are added to it, so a model
/// that re-proposes the same change across rounds of one reply can't pop the
/// approval dialog repeatedly. After the dialog returns, [ctx] is re-checked
/// for a Stop pressed while it was open: if set, nothing is applied. Approved
/// proposals are handed to [applyApproved]. Returns one result per write: a
/// generic success for approved writes, the denial reason for denied ones,
/// and the raw at-execute failure for writes that errored before producing a
/// proposal.
Future<List<ToolResult>> resolveCardEditApprovals({
  required List<ToolResult> writeRaw,
  required List<CardEditProposal> proposals,
  required ToolCallContext ctx,
  required Set<String> deniedKeys,
  required bool requireApprovalForEdits,
  required bool requireApprovalForAdditions,
  required bool requireApprovalForDeletions,
  required Future<void> Function(List<CardEditProposal> approved) applyApproved,
}) async {
  // Walk writeRaw and proposals together; proposals were appended in the order
  // of successful executes, so the n-th successful write maps to proposals[n].
  final proposalIdxForWrite = <int, int>{};
  var pIdx = 0;
  for (var i = 0; i < writeRaw.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (writeRaw[i].success) proposalIdxForWrite[i] = pIdx++;
  }

  // Skip proposals the user already declined earlier in this reply.
  final askable = <CardEditProposal>[];
  final askableProposalIdx = <int>[];
  for (var i = 0; i < proposals.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (deniedKeys.contains(cardEditProposalDedupKey(proposals[i]))) continue;
    // ignore: qcheck/avoid_unsafe_collection_methods
    askable.add(proposals[i]);
    askableProposalIdx.add(i);
  }

  final askedDecisions = await CardEditGateController.askUser(
    askable,
    requireApprovalForEdits: requireApprovalForEdits,
    requireApprovalForAdditions: requireApprovalForAdditions,
    requireApprovalForDeletions: requireApprovalForDeletions,
  );

  // Stop pressed while the approval dialog was open: don't apply or save
  // anything. The reply is being discarded; a write begun before Stop must
  // not land.
  if (ctx.isCancelled) {
    return [
      for (final _ in writeRaw) const ToolResult.failure('Cancelled by user.'),
    ];
  }

  // Re-expand to one decision per proposal: previously-declined proposals are
  // denied; the rest take the dialog's verdict.
  final decisions = List<ApprovalDecision>.filled(
    proposals.length,
    const ApprovalDecision(
      approved: false,
      reason: 'already declined earlier in this reply',
    ),
  );
  for (var i = 0; i < askableProposalIdx.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    decisions[askableProposalIdx[i]] = askedDecisions[i];
  }

  // Remember every denied change so a later round this reply skips the dialog.
  for (var i = 0; i < proposals.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (!decisions[i].approved) {
      // ignore: qcheck/avoid_unsafe_collection_methods
      deniedKeys.add(cardEditProposalDedupKey(proposals[i]));
    }
  }

  final approved = <CardEditProposal>[];
  for (var i = 0; i < proposals.length; i++) {
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (decisions[i].approved) approved.add(proposals[i]);
  }
  if (approved.isNotEmpty) await applyApproved(approved);

  final results = <ToolResult>[];
  for (var i = 0; i < writeRaw.length; i++) {
    final pi = proposalIdxForWrite[i];
    if (pi == null) {
      // ignore: qcheck/avoid_unsafe_collection_methods
      results.add(writeRaw[i]);
      continue;
    }
    // ignore: qcheck/avoid_unsafe_collection_methods
    final decision = decisions[pi];
    if (decision.approved) {
      results.add(const ToolResult.ok(data: 'edit applied'));
    } else {
      results.add(
        ToolResult.failure('user denied: ${decision.reason ?? "(no reason)"}'),
      );
    }
  }
  return results;
}

/// Stable key for a proposed card edit, used to skip reopening the approval
/// dialog for a change the user already declined earlier in the same reply.
/// Set/append keys include the new value so a different replacement re-asks;
/// delete keys are location-only.
String cardEditProposalDedupKey(CardEditProposal p) => switch (p) {
  CardScalarSetProposal(:final field, :final newValue) =>
    'set:${field.jsonKey}=$newValue',
  CardListSetProposal(:final field, :final index, :final newValue) =>
    'lset:${field.jsonKey}[$index]=$newValue',
  CardListAppendProposal(:final field, :final newValue) =>
    'lappend:${field.jsonKey}=$newValue',
  CardListDeleteProposal(:final field, :final index) =>
    'ldelete:${field.jsonKey}[$index]',
};
