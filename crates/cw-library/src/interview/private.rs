//! The private list of sensitive matters as the writer gets it. Rows of "don't
//! know" are not in `rows`: the list's page leaves them out.

use cw_ccv4::creation::Private;

/// At most this many "no" rows are nevers.
const MOST_NEVERS: usize = 3;

/// The list's writing rules and its nevers: yes in, fantasy "in the story only",
/// maybe "only when the user leads", no soft, unless marked never.
pub fn sensitive_lines(private: &Private) -> (Vec<String>, Vec<String>) {
    let (mut lines, mut soft, mut nevers) = (Vec::new(), Vec::new(), Vec::new());
    for row in &private.rows {
        let topic = row.topic.as_str();
        match row.answer.as_str() {
            "yes" => lines.push(format!("{topic}: welcome")),
            "fantasy only" => lines.push(format!("{topic}: in the story only")),
            "maybe" => lines.push(format!("{topic}: only when the user leads")),
            "no" if row.never && nevers.len() < MOST_NEVERS => nevers.push(topic.to_string()),
            "no" => soft.push(topic),
            _ => {}
        }
    }
    if !soft.is_empty() {
        lines.push(format!("keeps away from: {}", soft.join(", ")));
    }
    if !private.free.trim().is_empty() {
        lines.push(format!("the user's own line: {}", private.free));
    }
    (lines, nevers)
}
