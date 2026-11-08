//! Ported one to one from the Flutter app's `utils_prompt_test.dart`.

use cw_prompt::Variables;
use cw_prompt::macros::{MacroContext, render};

/// Renders with the given names, variables and tracking id.
fn render_full(
    text: &str,
    char: &str,
    local: Option<&mut Variables>,
    global: Option<&mut Variables>,
    tracking_id: Option<&str>,
) -> String {
    let mut ctx = MacroContext {
        char_name: char,
        user_name: "User",
        local,
        global,
        tracking_id,
        language: None,
    };
    render(text, &mut ctx)
}

fn plain(text: &str) -> String {
    render_full(text, "Cass", None, None, None)
}

fn with_local(text: &str, local: &mut Variables) -> String {
    render_full(text, "Cass", Some(local), None, None)
}

fn with_global(text: &str, global: &mut Variables) -> String {
    render_full(text, "Cass", None, Some(global), None)
}

fn tracked(text: &str, local: &mut Variables, tracking_id: &str) -> String {
    render_full(text, "Cass", Some(local), None, Some(tracking_id))
}

fn vars(pairs: &[(&str, &str)]) -> Variables {
    pairs
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect()
}

// identity and passthrough

#[test]
fn empty_or_brace_free_text_is_returned_unchanged() {
    assert_eq!(plain(""), "");
    assert_eq!(plain("plain text, no macros"), "plain text, no macros");
}

#[test]
fn char_bot_and_user_substitute_and_trim() {
    assert_eq!(plain("{{char}}"), "Cass");
    assert_eq!(plain("{{bot}}"), "Cass");
    assert_eq!(plain("{{user}}"), "User");
    assert_eq!(
        render_full("{{char}}", "  Cass  ", None, None, None),
        "Cass"
    );
    assert_eq!(plain("Hi {{user}}, I am {{char}}."), "Hi User, I am Cass.");
}

#[test]
fn unknown_macros_leak_verbatim() {
    assert_eq!(plain("{{description}}"), "{{description}}");
    assert_eq!(plain("{{trim}}"), "{{trim}}");
    assert_eq!(plain("{{incvar::x}}"), "{{incvar::x}}");
}

// trim

#[test]
fn scoped_trim_strips_surrounding_whitespace() {
    assert_eq!(plain("{{trim}}  hello world  {{/trim}}"), "hello world");
    assert_eq!(plain("{{trim}}\n\n  content{{/trim}}"), "content");
    assert_eq!(plain("{{trim}}content  \n\n{{/trim}}"), "content");
}

#[test]
fn scoped_trim_resolves_macros_then_trims() {
    assert_eq!(plain("{{trim}}  Hello {{user}}  {{/trim}}"), "Hello User");
}

#[test]
fn scoped_trim_nests() {
    assert_eq!(
        plain("{{trim}}  outer {{trim}}  inner  {{/trim}} outer  {{/trim}}"),
        "outer inner outer"
    );
}

#[test]
fn scoped_trim_of_whitespace_only_is_empty() {
    assert_eq!(plain("{{trim}}   \n\n   {{/trim}}"), "");
}

// comments and whitespace macros

#[test]
fn comment_forms_emit_nothing() {
    assert_eq!(plain("{{// hidden note}}"), "");
    assert_eq!(plain("{{noop}}"), "");
    assert_eq!(plain("{{hidden_key}}"), "");
    assert_eq!(plain("{{comment}}"), "");
    assert_eq!(plain("a{{// x}}b"), "ab");
}

#[test]
fn newline_and_space_with_and_without_counts() {
    assert_eq!(plain("{{newline}}"), "\n");
    assert_eq!(plain("{{newline::3}}"), "\n\n\n");
    assert_eq!(plain("{{space}}"), " ");
    assert_eq!(plain("{{space::4}}"), "    ");
}

#[test]
fn newline_and_space_counts_clamp_to_1_100() {
    assert_eq!(plain("{{newline::0}}"), "\n");
    assert_eq!(plain("{{space::0}}"), " ");
    assert_eq!(plain("{{newline::500}}").len(), 100);
}

#[test]
fn reverse() {
    assert_eq!(plain("{{reverse::abc}}"), "cba");
    assert_eq!(plain("{{reverse::}}"), "");
}

// roll

#[test]
fn roll_single_face_dice_are_deterministic() {
    assert_eq!(plain("{{roll::1d1}}"), "1");
    assert_eq!(plain("{{roll::10d1}}"), "10");
}

#[test]
fn roll_count_is_capped_at_100() {
    assert_eq!(plain("{{roll::150d1}}"), "100");
}

#[test]
fn roll_stays_within_range() {
    for _ in 0..200 {
        let flat: i64 = plain("{{roll::6}}").parse().unwrap();
        assert!((1..=6).contains(&flat));
        let dice: i64 = plain("{{roll::2d6}}").parse().unwrap();
        assert!((2..=12).contains(&dice));
    }
}

#[test]
fn roll_single_colon_form_parses() {
    assert_eq!(plain("{{roll:1d1}}"), "1");
}

// random and pick

#[test]
fn random_single_option_is_deterministic() {
    assert_eq!(plain("{{random::only}}"), "only");
    assert_eq!(plain("{{random::a::a}}"), "a");
}

#[test]
fn random_returns_a_member_of_the_list() {
    for _ in 0..100 {
        assert!(["a", "b", "c"].contains(&plain("{{random::a::b::c}}").as_str()));
    }
}

#[test]
fn random_comma_list_in_single_colon_form() {
    for _ in 0..50 {
        assert!(["x", "y"].contains(&plain("{{random:x,y}}").as_str()));
    }
}

#[test]
fn pick_is_stable_across_renders_with_same_map_and_tracking_id() {
    let mut local = Variables::new();
    let first = tracked("{{pick::a::b::c::d::e}}", &mut local, "chat1");
    for _ in 0..20 {
        assert_eq!(
            tracked("{{pick::a::b::c::d::e}}", &mut local, "chat1"),
            first
        );
    }
    assert!(local.contains_key("__sys_pick_chat1_0"));
}

#[test]
fn pick_falls_back_to_random_without_tracking_id_or_map() {
    for _ in 0..50 {
        assert!(["a", "b"].contains(&plain("{{pick::a::b}}").as_str()));
    }
}

// local and global variables (named forms)

#[test]
fn setvar_getvar_via_double_colon() {
    let mut local = Variables::new();
    assert_eq!(with_local("{{setvar::name::Alice}}", &mut local), "");
    assert_eq!(with_local("{{getvar::name}}", &mut local), "Alice");
}

#[test]
fn getvar_of_an_unset_name_is_empty() {
    assert_eq!(with_local("{{getvar::missing}}", &mut Variables::new()), "");
}

#[test]
fn setvar_single_colon_and_space_forms() {
    let mut c = Variables::new();
    with_local("{{setvar:k:v}}", &mut c);
    assert_eq!(with_local("{{getvar::k}}", &mut c), "v");
    let mut s = Variables::new();
    with_local("{{setvar k v}}", &mut s);
    assert_eq!(with_local("{{getvar::k}}", &mut s), "v");
}

#[test]
fn setglobalvar_getglobalvar() {
    let mut g = Variables::new();
    with_global("{{setglobalvar::g::42}}", &mut g);
    assert_eq!(with_global("{{getglobalvar::g}}", &mut g), "42");
}

#[test]
fn value_may_contain_a_double_colon() {
    let mut c = Variables::new();
    with_local("{{setvar::k::a::b}}", &mut c);
    assert_eq!(with_local("{{getvar::k}}", &mut c), "a::b");
}

// variable shorthand

#[test]
fn shorthand_read_set_and_the_dollar_dot_scopes() {
    let mut local = Variables::new();
    let mut global = Variables::new();
    assert_eq!(with_local("{{.x = 5}}", &mut local), "");
    assert_eq!(with_local("{{.x}}", &mut local), "5");
    with_global("{{$g = hi}}", &mut global);
    assert_eq!(with_global("{{$g}}", &mut global), "hi");
}

#[test]
fn shorthand_increment_decrement_default_to_0_and_emit_the_new_value() {
    let mut c = Variables::new();
    assert_eq!(with_local("{{.n++}}", &mut c), "1");
    assert_eq!(with_local("{{.n++}}", &mut c), "2");
    assert_eq!(with_local("{{.n--}}", &mut c), "1");
}

#[test]
fn shorthand_numeric_add_and_subtract() {
    let mut c = vars(&[("n", "10")]);
    with_local("{{.n += 5}}", &mut c);
    assert_eq!(c["n"], "15");
    with_local("{{.n -= 3}}", &mut c);
    assert_eq!(c["n"], "12");
}

#[test]
fn shorthand_add_appends_when_either_side_is_non_numeric() {
    let mut c = vars(&[("s", "ab")]);
    with_local("{{.s += cd}}", &mut c);
    assert_eq!(c["s"], "abcd");
}

#[test]
fn shorthand_or_uses_fallback_when_falsy_and_coalesce_only_when_unset() {
    assert_eq!(with_local("{{.x || fb}}", &mut vars(&[("x", "0")])), "fb");
    assert_eq!(
        with_local("{{.x || fb}}", &mut vars(&[("x", "val")])),
        "val"
    );
    assert_eq!(with_local("{{.x ?? fb}}", &mut Variables::new()), "fb");
    assert_eq!(with_local("{{.x ?? fb}}", &mut vars(&[("x", "")])), "");
}

#[test]
fn shorthand_or_assign_and_coalesce_assign() {
    assert_eq!(with_local("{{.x ||= set}}", &mut vars(&[("x", "")])), "set");
    assert_eq!(
        with_local("{{.x ??= other}}", &mut vars(&[("x", "keep")])),
        "keep"
    );
}

#[test]
fn shorthand_equality_and_numeric_comparisons() {
    let mut c = vars(&[("x", "5")]);
    assert_eq!(with_local("{{.x == 5}}", &mut c), "true");
    assert_eq!(with_local("{{.x != 5}}", &mut c), "false");
    assert_eq!(with_local("{{.x > 3}}", &mut c), "true");
    assert_eq!(with_local("{{.x <= 5}}", &mut c), "true");
    assert_eq!(with_local("{{.x < 3}}", &mut c), "false");
    assert_eq!(
        with_local("{{.word > 3}}", &mut vars(&[("word", "abc")])),
        "false"
    );
}

// nested resolution

#[test]
fn a_stored_value_containing_a_macro_expands_when_read() {
    assert_eq!(
        with_local("{{getvar::x}}", &mut vars(&[("x", "{{char}}")])),
        "Cass"
    );
}

#[test]
fn setvar_then_getvar_in_the_same_text() {
    assert_eq!(
        with_local("{{setvar::x::5}}{{getvar::x}}", &mut Variables::new()),
        "5"
    );
}

#[test]
fn self_referential_variable_terminates() {
    assert_eq!(
        with_local("{{getvar::x}}", &mut vars(&[("x", "{{getvar::x}}")])),
        "{{getvar::x}}"
    );
}

// time

#[test]
fn time_and_date_resolve() {
    let time = plain("{{time}}");
    assert!(!time.is_empty());
    assert!(!time.contains("{{"));
    assert!(!plain("{{date}}").contains("{{"));
}

#[test]
fn utc_offset_forms_resolve_and_differ_across_offsets() {
    assert!(!plain("{{time_UTC+0}}").contains("{{"));
    assert!(!plain("{{time::UTC+0}}").contains("{{"));
    assert_ne!(plain("{{time_UTC+3}}"), plain("{{time_UTC-3}}"));
}

#[test]
fn malformed_utc_offset_leaks() {
    assert!(plain("{{time_UTC+abc}}").contains("{{"));
}

// conditionals

#[test]
fn if_then_else_with_shorthand_condition() {
    assert_eq!(
        with_local("{{if .v}}Y{{else}}N{{/if}}", &mut vars(&[("v", "1")])),
        "Y"
    );
    assert_eq!(
        with_local("{{if .v}}Y{{else}}N{{/if}}", &mut Variables::new()),
        "N"
    );
}

#[test]
fn if_without_else_is_empty_when_false() {
    assert_eq!(with_local("{{if .v}}Y{{/if}}", &mut Variables::new()), "");
    assert_eq!(
        with_local("{{if .v}}Y{{/if}}", &mut vars(&[("v", "on")])),
        "Y"
    );
}

#[test]
fn if_bang_inverts_the_condition() {
    assert_eq!(
        with_local("{{if !.flag}}X{{/if}}", &mut Variables::new()),
        "X"
    );
    assert_eq!(
        with_local("{{if !.flag}}X{{/if}}", &mut vars(&[("flag", "1")])),
        ""
    );
}

#[test]
fn if_zero_literal_is_falsy() {
    assert_eq!(plain("{{if 0}}x{{/if}}"), "");
    assert_eq!(plain("{{if 1}}x{{/if}}"), "x");
}

#[test]
fn if_blocks_nest() {
    let tpl = "{{if .a}}A{{if .b}}B{{/if}}{{/if}}";
    assert_eq!(with_local(tpl, &mut vars(&[("a", "1"), ("b", "1")])), "AB");
    assert_eq!(with_local(tpl, &mut vars(&[("a", "1")])), "A");
    assert_eq!(with_local(tpl, &mut Variables::new()), "");
}

#[test]
fn if_condition_through_a_nested_getvar() {
    let tpl = "{{if {{getvar::flag}}}}yes{{/if}}";
    assert_eq!(with_local(tpl, &mut vars(&[("flag", "1")])), "yes");
    assert_eq!(with_local(tpl, &mut vars(&[("flag", "0")])), "");
}

#[test]
fn if_comparison_condition() {
    assert_eq!(
        with_local(
            "{{setvar::score::5}}{{if .score > 3}}high{{else}}low{{/if}}",
            &mut Variables::new()
        ),
        "high"
    );
    assert_eq!(
        with_local(
            "{{setvar::score::2}}{{if .score > 3}}high{{else}}low{{/if}}",
            &mut Variables::new()
        ),
        "low"
    );
}

#[test]
fn if_lenient_spacing_and_multi_line_block() {
    assert_eq!(
        with_local("{{ if .v }}Y{{ /if }}", &mut vars(&[("v", "1")])),
        "Y"
    );
    let multi = "{{if .v}}\nline one\nline two\n{{/if}}";
    assert_eq!(
        with_local(multi, &mut vars(&[("v", "1")])),
        "\nline one\nline two\n"
    );
}

#[test]
fn if_sees_a_variable_set_before_the_block() {
    assert_eq!(
        with_local("{{setvar::x::1}}{{if .x}}set{{/if}}", &mut Variables::new()),
        "set"
    );
}

#[test]
fn if_unbalanced_block_leaks_unchanged() {
    assert_eq!(
        with_local("{{if .a}}hello", &mut vars(&[("a", "1")])),
        "{{if .a}}hello"
    );
}

// The dropped branch is never rendered, so its setvar never runs: y keeps the
// value the taken branch set.
#[test]
fn if_side_effects_in_the_dropped_branch_do_not_run() {
    assert_eq!(
        with_local(
            "{{if .a}}{{setvar::y::1}}{{else}}{{setvar::y::2}}{{/if}}{{getvar::y}}",
            &mut vars(&[("a", "1")])
        ),
        "1"
    );
}

// single-pass ordering

#[test]
fn a_variable_assigned_a_macro_value_is_readable_later_in_the_text() {
    assert_eq!(
        with_local(
            "{{setvar::x::{{char}}}}[{{getvar::x}}]",
            &mut Variables::new()
        ),
        "[Cass]"
    );
}

#[test]
fn shorthand_assigned_a_macro_value_is_readable_later_in_the_text() {
    let mut local = Variables::new();
    assert_eq!(
        with_local("{{.who = {{char}}}}[{{.who}}]", &mut local),
        "[Cass]"
    );
    assert_eq!(local["who"], "Cass");
}

#[test]
fn a_variable_assigned_from_a_nested_pick_is_readable_later() {
    let mut local = Variables::new();
    let out = tracked(
        "{{.region = {{pick::tono::iya::kiso}}}}[{{.region}}]",
        &mut local,
        "chat1",
    );
    let picked = local["region"].clone();
    assert!(["tono", "iya", "kiso"].contains(&picked.as_str()));
    assert_eq!(out, format!("[{picked}]"));
}

#[test]
fn if_reads_a_variable_assigned_from_a_pick_earlier_in_the_text() {
    assert_eq!(
        tracked(
            "{{.region = {{pick::tono}}}}{{if {{.region == tono}}}}repair{{else}}none{{/if}}",
            &mut Variables::new(),
            "t"
        ),
        "repair"
    );
}

// A full card-style template: a hidden setup block assigns variables from nested
// picks, then later prose reads those variables and branches on them.

const TEMPLATE: &str = "<!--
{{.mode = alpha}}
{{.region = {{pick::north::south::east}}}}
{{.delay = {{pick::one day::two days::three days, maybe four}}}}
{{.notified = {{pick::yes::no}}}}
Setup notes: The delay is {{.delay}}. {{if {{.notified == yes}} }}The office already knows.{{else}}The office does not know yet.{{/if}} Decide nothing for them.
-->

Dummy opening paragraph one. Dummy opening paragraph two.

Dummy narration mentioning the delay of {{.delay}} and the situation at hand.

{{if {{.region == north}} }}Northern branch: a place in the north.{{/if}}{{if {{.region == south}} }}Southern branch: a place in the south.{{/if}}{{if {{.region == east}} }}Eastern branch: a place in the east.{{/if}}

Dummy closing line.";

const REGION_BRANCHES: [(&str, &str); 3] = [
    ("north", "Northern branch: a place in the north."),
    ("south", "Southern branch: a place in the south."),
    ("east", "Eastern branch: a place in the east."),
];

#[test]
fn template_assigns_from_nested_picks_then_reads_and_branches_on_them() {
    let mut local = Variables::new();
    let out = tracked(TEMPLATE, &mut local, "run1");

    // Each assignment captured a member of its own pick list.
    assert_eq!(local["mode"], "alpha");
    assert!(["north", "south", "east"].contains(&local["region"].as_str()));
    assert!(["one day", "two days", "three days, maybe four"].contains(&local["delay"].as_str()));
    assert!(["yes", "no"].contains(&local["notified"].as_str()));

    // Every macro resolved; no braces leaked into the output.
    assert!(!out.contains("{{"));

    // Both {{.delay}} reads return the stored value.
    let delay = &local["delay"];
    assert!(out.contains(&format!("The delay is {delay}.")));
    assert!(out.contains(&format!("delay of {delay}")));

    // The notified conditional rendered the branch matching the pick.
    let knows = local["notified"] == "yes";
    assert_eq!(out.contains("The office already knows."), knows);
    assert_eq!(out.contains("The office does not know yet."), !knows);

    // Exactly one region branch rendered, matching .region.
    for (region, branch) in REGION_BRANCHES {
        assert_eq!(out.contains(branch), local["region"] == region);
    }
}

#[test]
fn template_renders_identically_across_passes_with_the_same_map_and_tracking_id() {
    let mut local = Variables::new();
    let first = tracked(TEMPLATE, &mut local, "run1");
    for _ in 0..20 {
        assert_eq!(tracked(TEMPLATE, &mut local, "run1"), first);
    }
}

// Not in the Dart tests: guards this port adds.

#[test]
fn very_deep_nesting_does_not_overflow_the_stack() {
    let deep = format!("{}char{}", "{{".repeat(50_000), "}}".repeat(50_000));
    assert!(plain(&deep).contains("char"));
    let blocks = format!("{}x{}", "{{if 1}}".repeat(20_000), "{{/if}}".repeat(20_000));
    assert!(plain(&blocks).contains('x'));
}

#[test]
fn text_with_non_ascii_characters_passes_through() {
    assert_eq!(
        plain("「{{char}}」は猫です — {{reverse::añb}}"),
        "「Cass」は猫です — bña"
    );
}

#[test]
fn a_card_cannot_fill_the_memory_with_macros() {
    // Doubling a variable forty times would need terabytes.
    let mut local = Variables::new();
    let doubling = "{{setvar::a::xxxxxxxx}}".to_string()
        + &"{{setvar::a::{{getvar::a}}{{getvar::a}}}}".repeat(40);
    assert_eq!(with_local(&doubling, &mut local), "");
    assert_eq!(local["a"].len(), 32 * 1024);
    let appending = "{{.b=xxxxxxxx}}".to_string() + &"{{.b+={{.b}}}}".repeat(40);
    with_local(&appending, &mut local);
    assert_eq!(local["b"].len(), 32 * 1024);

    // Past a megabyte the rest of a text is left as it is.
    let flood = "{{getvar::a}}".repeat(1000);
    let out = with_local(&flood, &mut local);
    assert!(
        out.len() < 2 * 1024 * 1024 && out.ends_with("{{getvar::a}}"),
        "{}",
        out.len()
    );

    // A thousand variables are kept, and those can still change.
    let many: String = (0..1200)
        .map(|n| format!("{{{{setvar::n{n}::1}}}}"))
        .collect();
    let mut local = Variables::new();
    with_local(&many, &mut local);
    assert_eq!(local.len(), 1000);
    with_local("{{setvar::n0::2}}{{setvar::late::2}}", &mut local);
    assert_eq!(
        (local["n0"].as_str(), local.contains_key("late")),
        ("2", false)
    );
}
