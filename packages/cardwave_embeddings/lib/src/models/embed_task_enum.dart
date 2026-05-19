/// Semantic role of an embed input. BGE-small-en-v1.5 uses an asymmetric
/// retrieval setup: queries get an instruction prefix; passages get none.
/// The instruction text is the one shipped in the model card.
enum EmbedTaskEnum {
  query(prefix: 'Represent this sentence for searching relevant passages: '),
  passage(prefix: '')
  ;

  const EmbedTaskEnum({required this.prefix});

  final String prefix;
}
