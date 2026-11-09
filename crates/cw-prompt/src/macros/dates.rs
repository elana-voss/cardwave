//! `{{date}}` and `{{time}}` as a person reads them in the app's language
//! (a greeting shown in a chat): each language's own long date and clock, by
//! its file's code (cw-core's `file_code`). English's for a language the app
//! has no file of, and where no language is given: the prompt's form, which the
//! model reads. A text stored before it is shown (the library's excerpt) is
//! rendered with the language [`MARKS`] and gets the forms when it is read
//! ([`marks_in`]). Trap: a new language's file needs its forms here too.

use chrono::{Datelike, Local, NaiveDate, NaiveTime, Timelike};

/// Stands as the language for marks in place of `{{date}}` and `{{time}}`,
/// characters of Unicode's private use area, which no card's text holds.
pub const MARKS: &str = "\u{E001}";
const DATE_MARK: &str = "\u{E002}";
const TIME_MARK: &str = "\u{E003}";

/// Whether `text` holds a mark of [`MARKS`].
pub fn has_marks(text: &str) -> bool {
    text.contains(DATE_MARK) || text.contains(TIME_MARK)
}

/// `text` with its marks replaced by now's date and time as `language` writes them.
pub fn marks_in(text: &str, language: &str) -> String {
    let now = Local::now();
    text.replace(DATE_MARK, &date_in(Some(language), now.date_naive()))
        .replace(TIME_MARK, &time_in(Some(language), now.time()))
}

const DE: [&str; 12] = [
    "Januar",
    "Februar",
    "März",
    "April",
    "Mai",
    "Juni",
    "Juli",
    "August",
    "September",
    "Oktober",
    "November",
    "Dezember",
];
const ES: [&str; 12] = [
    "enero",
    "febrero",
    "marzo",
    "abril",
    "mayo",
    "junio",
    "julio",
    "agosto",
    "septiembre",
    "octubre",
    "noviembre",
    "diciembre",
];
const PT: [&str; 12] = [
    "janeiro",
    "fevereiro",
    "março",
    "abril",
    "maio",
    "junho",
    "julho",
    "agosto",
    "setembro",
    "outubro",
    "novembro",
    "dezembro",
];
const ID: [&str; 12] = [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember",
];
/// Russian's months as a date names them (the genitive).
const RU: [&str; 12] = [
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
];
const HI: [&str; 12] = [
    "जनवरी",
    "फ़रवरी",
    "मार्च",
    "अप्रैल",
    "मई",
    "जून",
    "जुलाई",
    "अगस्त",
    "सितंबर",
    "अक्तूबर",
    "नवंबर",
    "दिसंबर",
];
const EN: [&str; 12] = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];

/// `date` as `language` writes a day in full ("November 9, 2026", "9. November 2026").
pub(crate) fn date_in(language: Option<&str>, date: NaiveDate) -> String {
    if language == Some(MARKS) {
        return DATE_MARK.into();
    }
    let (day, year, month) = (date.day(), date.year(), date.month0() as usize);
    match code(language).as_str() {
        "de" => format!("{day}. {} {year}", DE[month]),
        "es" => format!("{day} de {} de {year}", ES[month]),
        "pt-BR" => format!("{day} de {} de {year}", PT[month]),
        "id" => format!("{day} {} {year}", ID[month]),
        "ru" => format!("{day} {} {year} г.", RU[month]),
        "hi" => format!("{day} {} {year}", HI[month]),
        "vi" => format!("ngày {day} tháng {} năm {year}", month + 1),
        "ja" | "zh-Hans" | "zh-Hant" => format!("{year}年{}月{day}日", month + 1),
        "ko" => format!("{year}년 {}월 {day}일", month + 1),
        _ => format!("{} {day}, {year}", EN[month]),
    }
}

/// `time` as `language` reads a clock ("9:05 PM", "21:05").
pub(crate) fn time_in(language: Option<&str>, time: NaiveTime) -> String {
    if language == Some(MARKS) {
        return TIME_MARK.into();
    }
    let (hour, minute) = (time.hour(), time.minute());
    let twelve = match hour % 12 {
        0 => 12,
        hour => hour,
    };
    let after_noon = hour >= 12;
    match code(language).as_str() {
        "de" | "es" | "pt-BR" | "ru" | "vi" | "ja" | "zh-Hans" => format!("{hour}:{minute:02}"),
        "id" => format!("{hour:02}.{minute:02}"),
        "hi" => format!(
            "{twelve}:{minute:02} {}",
            if after_noon { "pm" } else { "am" }
        ),
        "ko" => format!(
            "{} {twelve}:{minute:02}",
            if after_noon { "오후" } else { "오전" }
        ),
        "zh-Hant" => format!(
            "{}{twelve}:{minute:02}",
            if after_noon { "下午" } else { "上午" }
        ),
        _ => format!(
            "{twelve}:{minute:02} {}",
            if after_noon { "PM" } else { "AM" }
        ),
    }
}

/// The code of `language`'s file, English's where none is given.
fn code(language: Option<&str>) -> String {
    language.map_or_else(|| "en".into(), cw_core::languages::file_code)
}

#[cfg(test)]
mod tests {
    use chrono::Local;

    use super::*;
    use crate::macros::{MacroContext, render};

    #[test]
    fn a_date_and_time_shown_are_in_the_apps_language_and_the_prompts_stay_english() {
        let (day, evening) = (
            NaiveDate::from_ymd_opt(2026, 11, 9).unwrap(),
            NaiveTime::from_hms_opt(21, 5, 0).unwrap(),
        );
        assert_eq!(date_in(Some("de-DE"), day), "9. November 2026");
        assert_eq!(time_in(Some("de-DE"), evening), "21:05");
        assert_eq!(
            (date_in(None, day), time_in(None, evening)),
            ("November 9, 2026".into(), "9:05 PM".into())
        );
        let shown = |language| {
            render(
                "{{date}}",
                &mut MacroContext {
                    char_name: "Ann",
                    user_name: "Bo",
                    local: None,
                    global: None,
                    tracking_id: None,
                    language,
                    seed: None,
                },
            )
        };
        let today = Local::now().date_naive();
        assert_eq!(shown(Some("ja")), date_in(Some("ja"), today));
        assert_eq!(shown(None), date_in(None, today));
    }
}
