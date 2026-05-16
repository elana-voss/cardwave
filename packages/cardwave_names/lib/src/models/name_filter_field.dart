/// Indexes the optional fields on [NameFilters] for the graceful
/// degradation drop-order. Defines a single source of truth so the
/// `relaxedFilters` reported back to the LLM uses the same identifiers
/// the algorithm uses internally.
enum NameFilterField {
  gender,
  languageEthnicity,
  mythology,
  race,
  age,
  era,
  role,
  intelligence,
  allure,
  commonness,
  genre,
  themes,
}
