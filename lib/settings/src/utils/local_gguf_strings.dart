// Shared labels used by both the Settings "Add Local GGUF" dialog and the
// onboarding LLM-step expander. Kept in one place so the wording stays
// consistent across the two entry points.

import 'package:cardwave/i18n/gen/translations.g.dart';

String get kHaveLocalGgufExpanderTitle =>
    t.settings.localGguf.haveLocalGgufExpanderTitle;
String get kPickFileLabel => t.settings.localGguf.pickFileLabel;
String get kLoadModelLabel => t.settings.localGguf.loadModelLabel;
String get kNativeContextLabel => t.settings.localGguf.nativeContextLabel;
String get kFreeVramLabel => t.settings.localGguf.freeVramLabel;
String get kContextSizeLabel => t.settings.localGguf.contextSizeLabel;
String get kKvCacheLabel => t.settings.localGguf.kvCacheLabel;
String get kKvCacheAutoLabel => t.settings.localGguf.kvCacheAutoLabel;

String modelTooLargeForVramMessage({
  required int neededMb,
  required int freeMb,
}) => t.settings.localGguf.modelTooLargeForVramMessage(
  neededMb: neededMb,
  freeMb: freeMb,
);

String modelBarelyFitsMessage({required int minimumContext}) =>
    t.settings.localGguf.modelBarelyFitsMessage(
      minimumContext: minimumContext,
    );
