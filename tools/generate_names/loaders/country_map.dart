// Maps ISO alpha-2 country codes to [LanguageEthnicityEnum]. Used by
// loaders whose source corpora tag entries by country (philipperemy,
// popular-names-by-country). Codes with no clean ethnicity match map to
// the closest fit (e.g. Austria → german); a handful are deliberately
// unmapped and those names get skipped at load time.

import 'local_taxonomy.dart';

const Map<String, LanguageEthnicityEnum> isoCountryToEthnicity = {
  // English-speaking
  'US': LanguageEthnicityEnum.english,
  'GB': LanguageEthnicityEnum.english,
  'CA': LanguageEthnicityEnum.english,
  'AU': LanguageEthnicityEnum.english,
  'NZ': LanguageEthnicityEnum.english,
  'IE': LanguageEthnicityEnum.irishGaelic,

  // Germanic / Northern Europe
  'DE': LanguageEthnicityEnum.german,
  'AT': LanguageEthnicityEnum.german,
  'CH': LanguageEthnicityEnum.german,
  'LI': LanguageEthnicityEnum.german,
  'NL': LanguageEthnicityEnum.dutch,
  'BE': LanguageEthnicityEnum.dutch,
  'LU': LanguageEthnicityEnum.french,
  'IS': LanguageEthnicityEnum.icelandic,
  'NO': LanguageEthnicityEnum.norwegian,
  'SE': LanguageEthnicityEnum.swedish,
  'DK': LanguageEthnicityEnum.scandinavian,
  'FI': LanguageEthnicityEnum.finnish,
  'EE': LanguageEthnicityEnum.estonian,

  // Romance
  'FR': LanguageEthnicityEnum.french,
  'MC': LanguageEthnicityEnum.french,
  'IT': LanguageEthnicityEnum.italian,
  'SM': LanguageEthnicityEnum.italian,
  'VA': LanguageEthnicityEnum.italian,
  'ES': LanguageEthnicityEnum.spanish,
  'PT': LanguageEthnicityEnum.portuguese,
  'BR': LanguageEthnicityEnum.portuguese,
  'AR': LanguageEthnicityEnum.spanish,
  'MX': LanguageEthnicityEnum.spanish,
  'CL': LanguageEthnicityEnum.spanish,
  'CO': LanguageEthnicityEnum.spanish,
  'PE': LanguageEthnicityEnum.spanish,
  'UY': LanguageEthnicityEnum.spanish,
  'VE': LanguageEthnicityEnum.spanish,
  'BO': LanguageEthnicityEnum.spanish,
  'EC': LanguageEthnicityEnum.spanish,
  'PY': LanguageEthnicityEnum.spanish,
  'CR': LanguageEthnicityEnum.spanish,
  'PA': LanguageEthnicityEnum.spanish,
  'DO': LanguageEthnicityEnum.spanish,
  'CU': LanguageEthnicityEnum.spanish,
  'GT': LanguageEthnicityEnum.spanish,
  'HN': LanguageEthnicityEnum.spanish,
  'NI': LanguageEthnicityEnum.spanish,
  'SV': LanguageEthnicityEnum.spanish,
  'PR': LanguageEthnicityEnum.spanish,
  'RO': LanguageEthnicityEnum.latin,

  // Slavic
  'RU': LanguageEthnicityEnum.slavicRussian,
  'BY': LanguageEthnicityEnum.slavicRussian,
  'PL': LanguageEthnicityEnum.slavicPolish,
  'UA': LanguageEthnicityEnum.ukrainian,
  'CZ': LanguageEthnicityEnum.slavicOther,
  'SK': LanguageEthnicityEnum.slavicOther,
  'BG': LanguageEthnicityEnum.slavicOther,
  'RS': LanguageEthnicityEnum.serbian,
  'HR': LanguageEthnicityEnum.slavicOther,
  'BA': LanguageEthnicityEnum.slavicOther,
  'MK': LanguageEthnicityEnum.slavicOther,
  'SI': LanguageEthnicityEnum.slavicOther,
  'ME': LanguageEthnicityEnum.serbian,

  // Celtic / British isles
  'GG': LanguageEthnicityEnum.english,
  'JE': LanguageEthnicityEnum.english,
  'IM': LanguageEthnicityEnum.english,

  // East Asia
  'JP': LanguageEthnicityEnum.japanese,
  'CN': LanguageEthnicityEnum.chinese,
  'TW': LanguageEthnicityEnum.chinese,
  'HK': LanguageEthnicityEnum.chinese,
  'KR': LanguageEthnicityEnum.korean,
  'KP': LanguageEthnicityEnum.korean,
  'MN': LanguageEthnicityEnum.mongolian,
  'VN': LanguageEthnicityEnum.vietnamese,
  'TH': LanguageEthnicityEnum.thai,
  'ID': LanguageEthnicityEnum.indonesian,
  'NP': LanguageEthnicityEnum.nepalese,

  // South Asia
  'IN': LanguageEthnicityEnum.hindi,
  'PK': LanguageEthnicityEnum.hindi,
  'BD': LanguageEthnicityEnum.hindi,
  'LK': LanguageEthnicityEnum.hindi,

  // Middle East / Arabic-speaking
  'SA': LanguageEthnicityEnum.arabic,
  'AE': LanguageEthnicityEnum.arabic,
  'EG': LanguageEthnicityEnum.arabic,
  'JO': LanguageEthnicityEnum.arabic,
  'LB': LanguageEthnicityEnum.arabic,
  'SY': LanguageEthnicityEnum.arabic,
  'IQ': LanguageEthnicityEnum.arabic,
  'KW': LanguageEthnicityEnum.arabic,
  'QA': LanguageEthnicityEnum.arabic,
  'OM': LanguageEthnicityEnum.arabic,
  'YE': LanguageEthnicityEnum.arabic,
  'BH': LanguageEthnicityEnum.arabic,
  'MA': LanguageEthnicityEnum.arabic,
  'DZ': LanguageEthnicityEnum.arabic,
  'TN': LanguageEthnicityEnum.arabic,
  'LY': LanguageEthnicityEnum.arabic,
  'SD': LanguageEthnicityEnum.arabic,
  'PS': LanguageEthnicityEnum.arabic,
  'IL': LanguageEthnicityEnum.hebrew,
  'IR': LanguageEthnicityEnum.persian,
  'AF': LanguageEthnicityEnum.persian,
  'TJ': LanguageEthnicityEnum.persian,
  'TR': LanguageEthnicityEnum.turkish,
  'AZ': LanguageEthnicityEnum.turkish,

  // Africa
  'KE': LanguageEthnicityEnum.swahili,
  'TZ': LanguageEthnicityEnum.swahili,
  'UG': LanguageEthnicityEnum.swahili,
  'NG': LanguageEthnicityEnum.nigerian,
  'GH': LanguageEthnicityEnum.yoruba,
  'BJ': LanguageEthnicityEnum.yoruba,
  'SO': LanguageEthnicityEnum.somali,
  'ET': LanguageEthnicityEnum.swahili,
  'ZA': LanguageEthnicityEnum.english,
  'ZW': LanguageEthnicityEnum.english,

  // Pacific / Oceania
  'WS': LanguageEthnicityEnum.maori,
  'TO': LanguageEthnicityEnum.maori,
  'FJ': LanguageEthnicityEnum.maori,

  // Greek / Mediterranean
  'GR': LanguageEthnicityEnum.greek,
  'CY': LanguageEthnicityEnum.greek,
  'MT': LanguageEthnicityEnum.italian,
  'AL': LanguageEthnicityEnum.slavicOther,
  'HU': LanguageEthnicityEnum.estonian, // approx — Hungarian closest to Finno-Ugric

  // Baltic
  'LT': LanguageEthnicityEnum.slavicOther,
  'LV': LanguageEthnicityEnum.slavicOther,
};
