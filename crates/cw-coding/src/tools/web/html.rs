//! HTML read as a browser reads it, by `scraper` (html5ever's parser): a
//! page's title, where it refreshes to, its text, and the results on
//! DuckDuckGo's page without scripts. Entities and broken markup are the
//! parser's to mend. A page is parsed with scripting off, as a browser
//! without scripts reads it, so what `<noscript>` holds (a refresh) is markup.
//! The text is what a browser shows: what scripts, styles and the head hold
//! left out, a line after each block, spaces run together but in `<pre>`.
//! Trap: `Html` may not be sent between threads, so a page is parsed and read
//! in one go and never held over an `await`.

use std::sync::LazyLock;

use ego_tree::iter::Edge;
use html5ever::ParseOpts;
use html5ever::tendril::TendrilSink;
use html5ever::tree_builder::TreeBuilderOpts;
use scraper::{ElementRef, Html, HtmlTreeSink, Node, Selector};

/// The elements whose content a reader is not shown.
const HIDDEN: [&str; 6] = ["script", "style", "head", "noscript", "svg", "template"];

/// The elements a line ends before and after.
const BLOCKS: [&str; 20] = [
    "p",
    "div",
    "br",
    "li",
    "tr",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "section",
    "article",
    "header",
    "footer",
    "ul",
    "ol",
    "table",
    "pre",
    "blockquote",
];

/// A selector of this file's own, fixed, run by its tests: it parses.
fn selector(css: &str) -> Selector {
    Selector::parse(css).expect("a fixed selector")
}

/// A page read: its title as one line, empty where it has none; the content
/// of its `<meta http-equiv="refresh">`, where it has one; and its text.
pub(super) struct Read {
    pub title: String,
    pub refresh: Option<String>,
    pub text: String,
}

/// The page `html` read.
pub(super) fn read(html: &str) -> Read {
    static TITLE: LazyLock<Selector> = LazyLock::new(|| selector("title"));
    static META: LazyLock<Selector> = LazyLock::new(|| selector("meta[http-equiv][content]"));
    let page = parse(html);
    let title = page.select(&TITLE).next().map_or(String::new(), |title| {
        one_line(&title.text().collect::<String>())
    });
    let refresh = page
        .select(&META)
        .find(|meta| {
            meta.attr("http-equiv")
                .is_some_and(|kind| kind.trim().eq_ignore_ascii_case("refresh"))
        })
        .and_then(|meta| meta.attr("content"))
        .map(str::to_string);
    Read {
        title,
        refresh,
        text: text_of(page.root_element()),
    }
}

/// The document `html`, parsed with scripting off: a refresh in
/// `<noscript>`, which a page without scripts follows, is found.
fn parse(html: &str) -> Html {
    let opts = ParseOpts {
        tree_builder: TreeBuilderOpts {
            scripting_enabled: false,
            ..TreeBuilderOpts::default()
        },
        ..ParseOpts::default()
    };
    html5ever::parse_document(HtmlTreeSink::new(Html::new_document()), opts).one(html)
}

/// A result of a search: its title, its link as the page gives it, and what
/// the search says of it.
pub(super) struct Found {
    pub title: String,
    pub link: String,
    pub about: String,
}

/// The results on a page of DuckDuckGo's search without scripts: a link of
/// the class `result-link` each, and the first snippet after it before the
/// next link.
pub(super) fn results(html: &str) -> Vec<Found> {
    static PARTS: LazyLock<Selector> =
        LazyLock::new(|| selector("a.result-link[href], .result-snippet"));
    let page = parse(html);
    let mut found: Vec<Found> = Vec::new();
    let mut about_open = false;
    for part in page.select(&PARTS) {
        match part.attr("href").filter(|_| part.value().name() == "a") {
            Some(link) => {
                found.push(Found {
                    title: text_of(part),
                    link: link.to_string(),
                    about: String::new(),
                });
                about_open = true;
            }
            None => {
                if let Some(last) = found.last_mut().filter(|_| about_open) {
                    last.about = text_of(part);
                    about_open = false;
                }
            }
        }
    }
    found
}

/// The text a reader is shown of `element`. Walked without recursion, so a
/// deeply nested page cannot run out of stack.
fn text_of(element: ElementRef) -> String {
    let mut text = String::new();
    // How deep inside hidden elements and inside `<pre>` the walk is.
    let (mut hidden, mut pre) = (0usize, 0usize);
    for edge in element.traverse() {
        match edge {
            Edge::Open(node) => match node.value() {
                Node::Element(tag) => {
                    let name = tag.name();
                    hidden += usize::from(HIDDEN.contains(&name));
                    pre += usize::from(name == "pre");
                    if hidden == 0 && BLOCKS.contains(&name) {
                        text.push('\n');
                    }
                }
                Node::Text(words) if hidden == 0 => {
                    for sign in words.chars() {
                        text.push(match sign {
                            '\n' if pre > 0 => '\n',
                            sign if sign.is_whitespace() => ' ',
                            sign => sign,
                        });
                    }
                }
                _ => {}
            },
            Edge::Close(node) => {
                if let Node::Element(tag) = node.value() {
                    let name = tag.name();
                    if hidden == 0 && BLOCKS.contains(&name) {
                        text.push('\n');
                    }
                    hidden -= usize::from(HIDDEN.contains(&name));
                    pre -= usize::from(name == "pre");
                }
            }
        }
    }
    text.lines()
        .map(one_line)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

/// `text`'s words in one line, a space between each.
fn one_line(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_is_what_a_browser_shows() {
        let page = read(
            "<html><head><title> Lamp\n oil &amp; wicks </title><style>p { }</style></head>\
             <body><h1>Lamps</h1><!-- a note --><p data-x=\"a > b\">Keep the light&rsquo;s\n\
             wick <i>trimmed</i>.</p><script>if (a < b) steal()</script><pre>one\ntwo</pre>\
             <p>Oil&nbsp;&hellip;</body></html>",
        );
        assert_eq!(page.title, "Lamp oil & wicks");
        assert_eq!(page.refresh, None);
        assert_eq!(
            page.text,
            "Lamps\nKeep the light\u{2019}s wick trimmed.\none\ntwo\nOil \u{2026}"
        );
    }

    #[test]
    fn a_refresh_in_noscript_is_found() {
        let page = read(
            "<html><head><noscript><meta http-equiv=\"refresh\" content=\"0; url=/basic\">             </noscript></head><body>Hi</body></html>",
        );
        assert_eq!(page.refresh.as_deref(), Some("0; url=/basic"));
    }

    #[test]
    fn an_unclosed_script_hides_only_itself() {
        let page = read("<html><body><p>Shown.</p><script>never shown");
        assert_eq!(page.text, "Shown.");
    }

    #[test]
    fn a_refresh_is_found_by_its_kind_in_any_case() {
        let page = read(r#"<meta content="0; URL='/new'" http-equiv=" Refresh ">"#);
        assert_eq!(page.refresh.as_deref(), Some("0; URL='/new'"));
    }

    #[test]
    fn a_result_takes_the_snippet_before_the_next_link_only() {
        let found = results(
            "<table><tr><td><a class='result-link' href='/a?x=1&amp;y=2'>A <b>one</b></a></td></tr>\
             <tr><td><a class='result-link' href='/b'>B</a></td></tr>\
             <tr><td class='result-snippet'>About\n  B.</td></tr></table>",
        );
        let found: Vec<_> = found
            .iter()
            .map(|one| (one.title.as_str(), one.link.as_str(), one.about.as_str()))
            .collect();
        assert_eq!(
            found,
            [("A one", "/a?x=1&y=2", ""), ("B", "/b", "About B.")]
        );
    }
}
