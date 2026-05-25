// Shared labels used by both the Settings "Add Local GGUF" dialog and the
// onboarding LLM-step expander. Kept in one place so the wording stays
// consistent across the two entry points.

const kHaveLocalGgufExpanderTitle = 'I have a local GGUF file';
const kPickFileLabel = 'Pick GGUF file...';
const kLoadModelLabel = 'Load model';
const kNativeContextLabel = 'Native context';
const kFreeVramLabel = 'Free VRAM';
const kContextSizeLabel = 'Context size';
const kKvCacheLabel = 'KV cache';
const kKvCacheAutoLabel = 'Auto';

String modelTooLargeForVramMessage({
  required int neededMb,
  required int freeMb,
}) =>
    'This model needs about ${neededMb}MB of GPU memory but only ${freeMb}MB '
    'is free. Close other GPU apps or pick a smaller / more-quantized model.';

String modelBarelyFitsMessage({required int minimumContext}) =>
    'This model barely fits even with q4_0 KV cache at $minimumContext '
    'tokens. Consider a more-aggressively-quantized model file.';
