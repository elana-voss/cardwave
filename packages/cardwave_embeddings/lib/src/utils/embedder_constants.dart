/// Filename of the bundled GGUF model under `assets/models/`.
const String embeddingsModelFilename = 'bge-small-en-v1.5-q8_0.gguf';

/// Stable model id stamped into the sidecar header by app-side consumers.
/// One id across platforms because every build uses the same model, so
/// sidecars are portable native ↔ web. Bumped when we replaced
/// multilingual-e5-small with BGE-small-en-v1.5; older sidecars (with a
/// different id) are silently discarded and re-embedded.
const String embeddingsModelId = 'bge-small-en-v1.5-q8';

/// Output dimension of every vector this embedder returns.
const int embeddingsDim = 384;

/// Per-chunk token cap used by `chunkByTokens`. e5-small caps at 512
/// trained position embeddings; we leave ~32 tokens of headroom for the
/// task prefix ("query: " / "passage: ") and BERT special tokens
/// ([CLS], [SEP]).
const int embeddingsMaxTokensPerChunk = 480;

/// Both supported models cap their position embeddings at 512 tokens.
/// Setting [ModelParams.contextSize] to anything larger lets the tokenizer
/// accept inputs that crash the BERT forward pass on lookup.
const int embeddingsModelContextTokens = 512;
