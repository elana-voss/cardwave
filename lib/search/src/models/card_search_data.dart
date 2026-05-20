import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// A card's per-field search data — embedded vectors, lowercase tokens, and
/// source hashes, keyed by [CardSearchFieldEnum]. An alias over the generic
/// package type so the search domain reads in card terms.
typedef CardSearchData = FieldSearchData<CardSearchFieldEnum>;
