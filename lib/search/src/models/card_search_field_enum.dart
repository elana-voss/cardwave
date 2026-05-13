/// Per-card searchable fields with their relevance weights. Weight feeds
/// the keyword index's per-field boost; the higher the weight, the more
/// a literal hit in this field lifts a card in the ranking.
enum CardSearchFieldEnum {
  name(weight: 50),
  tags(weight: 30),
  personality(weight: 10),
  description(weight: 10),
  scenario(weight: 1)
  ;

  const CardSearchFieldEnum({required this.weight});
  final int weight;
}
