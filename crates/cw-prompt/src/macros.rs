//! SillyTavern-compatible `{{...}}` macros: `{{char}}`, `{{user}}`, `{{getvar::x}}`,
//! the `{{.x}}` / `{{$x}}` variable shorthand, `{{if}}` blocks and so on. One
//! left-to-right pass, so a variable written on the left is visible to a read on the
//! right and the dropped branch of an `{{if}}` never runs.

use std::borrow::Cow;
use std::cmp::Ordering;
use std::fmt;
use std::sync::LazyLock;

use chrono::{DateTime, Duration, Local, TimeZone, Utc};
use regex::{Captures, Regex};

use crate::Variables;

mod dates;

/// Limits re-expansion of a macro's returned value (a variable whose stored value
/// is itself `{{char}}`), so variables that refer to each other in a cycle end.
const MAX_VALUE_EXPANSION_DEPTH: usize = 50;
/// Limits how deep macros and blocks may nest; text nested deeper is left as it is,
/// so a hostile card cannot exhaust the stack.
const MAX_NESTING: usize = 128;
/// Size limits, so a card whose macros double a value over and over cannot fill
/// the memory: past `MAX_OUTPUT` bytes the rest of a text is left as it is, and a
/// variable is not set when its value or the number of variables is too large.
const MAX_OUTPUT: usize = 1024 * 1024;
const MAX_VALUE: usize = 32 * 1024;
const MAX_VARIABLES: usize = 1000;
const MAX_REPEAT: i64 = 100;
const MAX_DICE: i64 = 100;
const MAX_FACES: i64 = u32::MAX as i64;

fn compile(pattern: &str) -> Regex {
    // Every pattern given is a fixed one of this file, run by its tests.
    Regex::new(pattern).expect("built-in pattern is valid")
}

static SHORTHAND: LazyLock<Regex> = LazyLock::new(|| {
    compile(
        r"^\s*([.$])([a-zA-Z0-9_]+)\s*(\+\+|--|\+=|-=|\|\|=|\?\?=|\|\||\?\?|==|!=|>=|<=|>|<|=)?\s*(.*)$",
    )
});
static UTC_TIME: LazyLock<Regex> =
    LazyLock::new(|| compile(r"(?i)^time\s*(?:::?|_)\s*utc\s*([+-][0-9]+)\s*$"));
static IF_HEAD: LazyLock<Regex> = LazyLock::new(|| compile(r"(?i)^\s*if\b"));
static TRIM_TAG: LazyLock<Regex> = LazyLock::new(|| compile(r"(?i)\{\{\s*(/)?\s*trim\s*\}\}"));
static COND_TAG: LazyLock<Regex> =
    LazyLock::new(|| compile(r"(?i)\{\{\s*(?:(if)\b|(else)\s*\}\}|/\s*if\s*\}\})"));

/// What the macros in one text resolve against.
pub struct MacroContext<'a> {
    pub char_name: &'a str,
    pub user_name: &'a str,
    /// The chat's variables. Without them the local variable macros yield nothing.
    pub local: Option<&'a mut Variables>,
    /// The user's variables shared by all chats.
    pub global: Option<&'a mut Variables>,
    /// Names the text being rendered. With it and `local`, each `{{pick}}` keeps
    /// its choice across renders.
    pub tracking_id: Option<&'a str>,
    /// The app's language a text is shown in (a greeting), for `{{date}}` and
    /// `{{time}}`; none: English's forms, as the prompt has them.
    pub language: Option<&'a str>,
}

/// Replaces every macro in `text`. Unknown macros and unbalanced braces are left
/// as they are.
pub fn render(text: &str, ctx: &mut MacroContext<'_>) -> String {
    if !text.contains("{{") {
        return text.to_string();
    }
    Engine { ctx, picks: 0 }.render(text, 0, 0)
}

struct Engine<'e, 'a> {
    ctx: &'e mut MacroContext<'a>,
    /// Number of `{{pick}}`s met so far in this render.
    picks: usize,
}

impl Engine<'_, '_> {
    /// One pass over `text`. At each `{{` the matching `}}` is found, nested macros
    /// are resolved first, then the macro itself is applied before the walk moves
    /// on. `depth` counts re-expansions of returned values, `level` all nesting.
    fn render(&mut self, text: &str, depth: usize, level: usize) -> String {
        if level > MAX_NESTING {
            return text.to_string();
        }
        let mut out = String::with_capacity(text.len());
        let mut i = 0;
        while let Some(open) = text[i..].find("{{").map(|p| p + i) {
            out.push_str(&text[i..open]);
            let Some(close) = matching_close(text.as_bytes(), open) else {
                // Unbalanced: the rest is left as it is.
                out.push_str(&text[open..]);
                return out;
            };
            let inner = &text[open + 2..close];
            let body_start = close + 2;

            if let Some(head) = IF_HEAD.find(inner) {
                let condition = &inner[head.end()..];
                i = self
                    .render_conditional(text, open, body_start, condition, &mut out, depth, level);
                continue;
            }

            let resolved = if inner.contains("{{") {
                Cow::Owned(self.render(inner, depth, level + 1))
            } else {
                Cow::Borrowed(inner)
            };

            // {{trim}}...{{/trim}} renders the block and strips the whitespace
            // around the result. A {{trim}} without a closing tag is left as it is,
            // like any unknown macro.
            if resolved.trim().eq_ignore_ascii_case("trim")
                && let Some((end_start, end_end)) = find_trim_end(text, body_start)
            {
                let body = self.render(&text[body_start..end_start], depth, level + 1);
                out.push_str(body.trim());
                i = end_end;
                continue;
            }

            if resolved.len() > MAX_OUTPUT {
                out.push_str(&text[open..]);
                return out;
            }
            let value = self.evaluate(&resolved);

            // A returned value that itself holds a macro (a variable storing
            // `{{char}}`) is expanded once more. A value equal to its own source
            // (unknown macro, variable that reads itself) is not, so this ends.
            let source = &text[open..body_start];
            if value != source && value.contains("{{") && depth < MAX_VALUE_EXPANSION_DEPTH {
                out.push_str(&self.render(&value, depth + 1, level + 1));
            } else {
                out.push_str(&value);
            }
            i = body_start;
            if out.len() > MAX_OUTPUT {
                break;
            }
        }
        out.push_str(&text[i..]);
        out
    }

    /// Renders the `{{if}}` block whose opening tag starts at `open` and whose body
    /// starts at `body_start`: only the branch that is kept. Returns the index just
    /// past `{{/if}}`, or past the opening tag (left as it is) when the block is
    /// never closed.
    #[allow(clippy::too_many_arguments)]
    fn render_conditional(
        &mut self,
        text: &str,
        open: usize,
        body_start: usize,
        condition: &str,
        out: &mut String,
        depth: usize,
        level: usize,
    ) -> usize {
        let Some(block) = find_block_end(text, body_start) else {
            out.push_str(&text[open..body_start]);
            return body_start;
        };
        let (end_start, end_end) = block.end;
        let taken = self.evaluate_condition(condition, depth, level);
        let branch = match (block.else_tag, taken) {
            (Some((else_start, _)), true) => &text[body_start..else_start],
            (Some((_, else_end)), false) => &text[else_end..end_start],
            (None, true) => &text[body_start..end_start],
            (None, false) => "",
        };
        out.push_str(&self.render(branch, depth, level + 1));
        end_end
    }

    /// Whether an `{{if}}` condition holds. Shorthand (`.x`, `$x`) and nested
    /// macros are resolved first; a plain word is tested as it is. A leading `!`
    /// inverts.
    fn evaluate_condition(&mut self, condition: &str, depth: usize, level: usize) -> bool {
        let mut cond = condition.trim();
        let mut inverted = false;
        while let Some(rest) = cond.strip_prefix('!') {
            inverted = !inverted;
            cond = rest.trim();
        }
        if cond.is_empty() {
            return inverted;
        }
        let truthy = if cond.contains("{{") {
            is_truthy(Some(&self.render(cond, depth, level + 1)))
        } else if cond.starts_with('.') || cond.starts_with('$') {
            is_truthy(Some(&self.render(
                &format!("{{{{{cond}}}}}"),
                depth,
                level + 1,
            )))
        } else {
            is_truthy(Some(cond))
        };
        inverted != truthy
    }

    /// The value of one macro, given the text between its braces with nested
    /// macros already resolved.
    fn evaluate(&mut self, inner: &str) -> String {
        let trimmed = inner.trim_start();
        if trimmed.starts_with("//") {
            return String::new();
        }
        if (trimmed.starts_with('.') || trimmed.starts_with('$'))
            && let Some(caps) = SHORTHAND.captures(trimmed)
        {
            return self.shorthand(&caps);
        }
        if let Some(time) = utc_time(trimmed) {
            return time;
        }

        // `command::args`, `command:args` or `command args`.
        let (command, arg, double_colon) = if let Some((c, a)) = trimmed.split_once("::") {
            (c, a.trim(), true)
        } else if let Some((c, a)) = trimmed.split_once(':') {
            (c, a.trim(), false)
        } else if let Some((c, a)) = trimmed.split_once(' ') {
            (c, a.trim(), false)
        } else {
            (trimmed, "", false)
        };

        match command.to_lowercase().as_str() {
            "char" | "bot" => self.ctx.char_name.trim().to_string(),
            "user" => self.ctx.user_name.trim().to_string(),
            "time" => dates::time_in(self.ctx.language, Local::now().time()),
            "date" => dates::date_in(self.ctx.language, Local::now().date_naive()),
            "random" => options(arg, double_colon)
                .map(random_of)
                .unwrap_or_default(),
            "pick" => options(arg, double_colon)
                .map(|o| self.pick(o))
                .unwrap_or_default(),
            "roll" => roll(arg),
            "getvar" => get_var(self.ctx.local.as_deref(), arg, double_colon),
            "setvar" => set_var(self.ctx.local.as_deref_mut(), arg, double_colon),
            "getglobalvar" => get_var(self.ctx.global.as_deref(), arg, double_colon),
            "setglobalvar" => set_var(self.ctx.global.as_deref_mut(), arg, double_colon),
            "newline" => "\n".repeat(repeat_count(arg)),
            "space" => " ".repeat(repeat_count(arg)),
            "noop" | "hidden_key" | "comment" => String::new(),
            "reverse" => arg.chars().rev().collect(),
            _ => format!("{{{{{inner}}}}}"),
        }
    }

    /// `{{pick}}`: a random option that stays the same on later renders of the same
    /// text, remembered in the chat's variables. Without them or a tracking id it
    /// is a plain random choice.
    fn pick(&mut self, options: Vec<&str>) -> String {
        let (Some(local), Some(tracking_id)) =
            (self.ctx.local.as_deref_mut(), self.ctx.tracking_id)
        else {
            return random_of(options);
        };
        let key = format!("__sys_pick_{tracking_id}_{}", self.picks);
        self.picks += 1;
        if let Some(saved) = local.get(&key)
            && options.contains(&saved.as_str())
        {
            return saved.clone();
        }
        let picked = random_of(options);
        store(local, &key, picked.clone());
        picked
    }

    /// Variable shorthand: `{{.x}}` is a chat variable, `{{$x}}` a global one,
    /// optionally followed by an operator and a value.
    fn shorthand(&mut self, caps: &Captures<'_>) -> String {
        let group = |i| caps.get(i).map_or("", |m| m.as_str());
        let name = group(2);
        let operator = group(3);
        let value = group(4).trim();

        let vars = if group(1) == "$" {
            self.ctx.global.as_deref_mut()
        } else {
            self.ctx.local.as_deref_mut()
        };
        let Some(vars) = vars else {
            return String::new();
        };
        let current = vars.get(name).cloned();
        let current = current.as_deref();
        let current_num = current.and_then(Num::parse);
        let mut set = |v: String| store(vars, name, v);
        let truth = |b: bool| if b { "true" } else { "false" }.to_string();

        match operator {
            "" => current.unwrap_or("").to_string(),
            "=" => {
                set(value.to_string());
                String::new()
            }
            "++" | "--" => {
                let step = Num::Int(if operator == "++" { 1 } else { -1 });
                let result = current_num.unwrap_or(Num::Int(0)).add(step).to_string();
                set(result.clone());
                result
            }
            "+=" => {
                match (current_num, Num::parse(value)) {
                    (Some(a), Some(b)) => set(a.add(b).to_string()),
                    _ => set(format!("{}{value}", current.unwrap_or(""))),
                };
                String::new()
            }
            "-=" => {
                if let (Some(a), Some(b)) = (current_num, Num::parse(value)) {
                    set(a.sub(b).to_string());
                }
                String::new()
            }
            "||" => if is_truthy(current) {
                current.unwrap_or("")
            } else {
                value
            }
            .to_string(),
            "??" => current.unwrap_or(value).to_string(),
            "||=" => {
                if is_truthy(current) {
                    current.unwrap_or("").to_string()
                } else {
                    set(value.to_string());
                    value.to_string()
                }
            }
            "??=" => match current {
                Some(current) => current.to_string(),
                None => {
                    set(value.to_string());
                    value.to_string()
                }
            },
            "==" => truth(current.unwrap_or("") == value),
            "!=" => truth(current.unwrap_or("") != value),
            _ => {
                let order = match (current_num, Num::parse(value)) {
                    (Some(a), Some(b)) => a.compare(b),
                    _ => None,
                };
                truth(match (operator, order) {
                    (">", Some(o)) => o == Ordering::Greater,
                    (">=", Some(o)) => o != Ordering::Less,
                    ("<", Some(o)) => o == Ordering::Less,
                    ("<=", Some(o)) => o != Ordering::Greater,
                    _ => false,
                })
            }
        }
    }
}

/// Index of the `}}` that closes the `{{` at `open`, counting nested braces.
fn matching_close(bytes: &[u8], open: usize) -> Option<usize> {
    let mut depth = 0usize;
    let mut i = open;
    while i + 1 < bytes.len() {
        if bytes[i] == b'{' && bytes[i + 1] == b'{' {
            depth += 1;
            i += 2;
        } else if bytes[i] == b'}' && bytes[i + 1] == b'}' {
            depth = depth.saturating_sub(1);
            if depth == 0 {
                return Some(i);
            }
            i += 2;
        } else {
            i += 1;
        }
    }
    None
}

struct Block {
    /// Start and end of the block's own `{{else}}`, if it has one.
    else_tag: Option<(usize, usize)>,
    /// Start and end of its `{{/if}}`.
    end: (usize, usize),
}

/// Finds the `{{else}}` and `{{/if}}` of the `{{if}}` block whose body starts at
/// `body_start`, skipping nested blocks.
fn find_block_end(text: &str, body_start: usize) -> Option<Block> {
    let mut nesting = 1usize;
    let mut else_tag = None;
    for caps in COND_TAG.captures_iter(&text[body_start..]) {
        let Some(tag) = caps.get(0) else { continue };
        let span = (body_start + tag.start(), body_start + tag.end());
        if caps.get(1).is_some() {
            nesting += 1;
        } else if caps.get(2).is_some() {
            if nesting == 1 && else_tag.is_none() {
                else_tag = Some(span);
            }
        } else {
            nesting -= 1;
            if nesting == 0 {
                return Some(Block {
                    else_tag,
                    end: span,
                });
            }
        }
    }
    None
}

/// Start and end of the `{{/trim}}` that closes the block whose body starts at
/// `body_start`, skipping nested blocks.
fn find_trim_end(text: &str, body_start: usize) -> Option<(usize, usize)> {
    let mut nesting = 1usize;
    for caps in TRIM_TAG.captures_iter(&text[body_start..]) {
        let Some(tag) = caps.get(0) else { continue };
        if caps.get(1).is_none() {
            nesting += 1;
            continue;
        }
        nesting -= 1;
        if nesting == 0 {
            return Some((body_start + tag.start(), body_start + tag.end()));
        }
    }
    None
}

fn is_truthy(value: Option<&str>) -> bool {
    let Some(value) = value else { return false };
    let lower = value.trim().to_lowercase();
    !matches!(lower.as_str(), "" | "false" | "0" | "off" | "no")
}

fn format_time<Tz: TimeZone>(time: DateTime<Tz>) -> String
where
    Tz::Offset: fmt::Display,
{
    time.format("%-I:%M %p").to_string()
}

/// SillyTavern's time at a UTC offset in whole hours: `{{time_UTC+2}}` (the form
/// real cards use) and the documented `{{time::UTC+2}}`. `None` when `trimmed` is
/// not such a macro.
fn utc_time(trimmed: &str) -> Option<String> {
    let caps = UTC_TIME.captures(trimmed)?;
    let hours = caps.get(1)?.as_str().parse().ok()?;
    let shifted = Utc::now().checked_add_signed(Duration::try_hours(hours)?)?;
    Some(format_time(shifted))
}

fn parse_int(text: &str) -> Option<i64> {
    text.trim().parse().ok()
}

/// The options of `{{random}}` / `{{pick}}`: split on `::`, or on commas in the
/// single-colon form. `None` when there are none.
fn options(arg: &str, double_colon: bool) -> Option<Vec<&str>> {
    let raw: Vec<&str> = if double_colon {
        arg.split("::").collect()
    } else if arg.contains(',') {
        arg.split(',').collect()
    } else {
        vec![arg]
    };
    let options: Vec<&str> = raw
        .into_iter()
        .map(str::trim)
        .filter(|o| !o.is_empty())
        .collect();
    (!options.is_empty()).then_some(options)
}

fn random_of(options: Vec<&str>) -> String {
    options[rand::random_range(0..options.len())].to_string()
}

/// `{{roll::6}}` or `{{roll::2d6}}`.
fn roll(arg: &str) -> String {
    if arg.is_empty() {
        return String::new();
    }
    let arg = arg.to_lowercase();
    let faces = |text: &str| parse_int(text).unwrap_or(20).clamp(1, MAX_FACES);
    let Some((count, sides)) = arg.split_once('d') else {
        return rand::random_range(1..=faces(&arg)).to_string();
    };
    let count = parse_int(count).unwrap_or(1).min(MAX_DICE);
    let sides = faces(sides);
    (0..count)
        .map(|_| rand::random_range(1..=sides))
        .sum::<i64>()
        .to_string()
}

fn repeat_count(arg: &str) -> usize {
    if arg.is_empty() {
        return 1;
    }
    parse_int(arg).unwrap_or(1).clamp(1, MAX_REPEAT) as usize
}

fn get_var(vars: Option<&Variables>, arg: &str, double_colon: bool) -> String {
    let Some(vars) = vars else {
        return String::new();
    };
    let name = if double_colon {
        arg.split("::").next().unwrap_or("").trim()
    } else {
        arg
    };
    vars.get(name).cloned().unwrap_or_default()
}

/// `{{setvar::name::value}}`, `{{setvar:name:value}}` or `{{setvar name value}}`.
fn set_var(vars: Option<&mut Variables>, arg: &str, double_colon: bool) -> String {
    let Some(vars) = vars else {
        return String::new();
    };
    if arg.is_empty() {
        return String::new();
    }
    let split = if double_colon {
        Some(arg.split_once("::").unwrap_or((arg, "")))
    } else {
        arg.split_once(' ').or_else(|| arg.split_once(':'))
    };
    if let Some((name, value)) = split {
        store(vars, name.trim(), value.trim().to_string());
    }
    String::new()
}

/// Sets a variable, within the size limits.
fn store(vars: &mut Variables, name: &str, value: String) {
    if value.len() <= MAX_VALUE && (vars.len() < MAX_VARIABLES || vars.contains_key(name)) {
        vars.insert(name.to_string(), value);
    }
}

/// A variable's value read as a number: whole numbers stay exact.
#[derive(Clone, Copy)]
enum Num {
    Int(i64),
    Float(f64),
}

impl Num {
    fn parse(text: &str) -> Option<Num> {
        let text = text.trim();
        if let Ok(int) = text.parse() {
            return Some(Num::Int(int));
        }
        // Rust would also read "inf" and "nan" as numbers; those stay text.
        let numeric = |b: u8| b.is_ascii_digit() || matches!(b, b'+' | b'-' | b'.' | b'e' | b'E');
        if !text.bytes().all(numeric) {
            return None;
        }
        text.parse().ok().map(Num::Float)
    }

    fn as_f64(self) -> f64 {
        match self {
            Num::Int(int) => int as f64,
            Num::Float(float) => float,
        }
    }

    fn add(self, other: Num) -> Num {
        match (self, other) {
            (Num::Int(a), Num::Int(b)) => a
                .checked_add(b)
                .map_or(Num::Float(a as f64 + b as f64), Num::Int),
            _ => Num::Float(self.as_f64() + other.as_f64()),
        }
    }

    fn sub(self, other: Num) -> Num {
        match (self, other) {
            (Num::Int(a), Num::Int(b)) => a
                .checked_sub(b)
                .map_or(Num::Float(a as f64 - b as f64), Num::Int),
            _ => Num::Float(self.as_f64() - other.as_f64()),
        }
    }

    fn compare(self, other: Num) -> Option<Ordering> {
        match (self, other) {
            (Num::Int(a), Num::Int(b)) => Some(a.cmp(&b)),
            _ => self.as_f64().partial_cmp(&other.as_f64()),
        }
    }
}

impl fmt::Display for Num {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match *self {
            Num::Int(int) => write!(f, "{int}"),
            // A whole result prints without a fraction: 1.5 + 1.5 is "3".
            Num::Float(float) if float.fract() == 0.0 && float.abs() < 1e15 => {
                write!(f, "{}", float as i64)
            }
            Num::Float(float) => write!(f, "{float}"),
        }
    }
}
