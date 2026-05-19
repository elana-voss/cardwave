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
        await NavigationService().showCardEditApprovalDialog(gated) ??
            // Dialog dismissed without a verdict → treat all gated edits as
            // denied so the assistant learns the user opted out of this round.
            List<ApprovalDecision>.generate(
              gated.length,
              (_) => const ApprovalDecision(
                approved: false,
                reason: '(dismissed)',
              ),
            );

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
