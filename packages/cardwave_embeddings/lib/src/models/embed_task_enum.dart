/// Semantic role of an embed input. e5-small uses asymmetric `query: ` /
/// `passage: ` prefixes — retrieval quality drops noticeably without them.
enum EmbedTaskEnum {
  query(prefix: 'query: '),
  passage(prefix: 'passage: ')
  ;

  const EmbedTaskEnum({required this.prefix});

  final String prefix;
}
