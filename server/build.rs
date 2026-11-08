//! Gives the server the moment it was built (`CARDWAVE_BUILT`, in ms since
//! 1970), which `/api/status` tells beside the version. Run anew when the
//! server's code, what it embeds, its version or its crates change, not on
//! every change of a test.
//!
//! And the API's routes as tools (`tools::app`): each file of `src/api` whose
//! `fn routes` has routes gets `$OUT_DIR/route_tools/<file>.rs`, which it
//! includes, a `route_tools()` of each route's method, path, handler's doc and
//! the types its handler takes (`Json<…>` the body, `Query<…>` the query,
//! `Path<…>` the path's parts); `api.rs`'s also gathers all. A handler that
//! takes what a tool cannot give (`UNREACHABLE`), or that is not a function of
//! the file, is no tool. Traps: a file that gains routes needs the `include!`
//! line; a handler's types need `ts_rs::TS`.

use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::path::Path;

use quote::ToTokens;
use syn::visit::Visit;

fn main() {
    let built = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("the clock is after 1970")
        .as_millis();
    println!("cargo:rustc-env=CARDWAVE_BUILT={built}");
    println!("cargo:rerun-if-changed=src");
    println!("cargo:rerun-if-changed=providers");
    println!("cargo:rerun-if-changed=../Cargo.toml");
    println!("cargo:rerun-if-changed=../Cargo.lock");
    route_tools();
}

const METHODS: [&str; 5] = ["get", "post", "put", "patch", "delete"];

/// Extractors a tool's request cannot fill: a file sent as the body, a form
/// (the backup's, which answers a file), a socket, the address it came from
/// (the password's, which counts tries by it).
const UNREACHABLE: [&str; 7] = [
    "Bytes",
    "Body",
    "Request",
    "Multipart",
    "Form",
    "WebSocketUpgrade",
    "ConnectInfo",
];

/// A route's method and path, and the name of its handler.
struct Found {
    method: String,
    path: String,
    handler: String,
}

/// Finds `.route("…", get(handler).post(handler)…)`.
#[derive(Default)]
struct Routes {
    path: Option<String>,
    found: Vec<Found>,
}

impl Routes {
    fn handler(&mut self, method: &syn::Ident, argument: Option<&syn::Expr>) {
        let (Some(path), Some(syn::Expr::Path(handler))) = (&self.path, argument) else {
            return;
        };
        let method = method.to_string();
        if !METHODS.contains(&method.as_str()) {
            return;
        }
        let Some(last) = handler.path.segments.last() else {
            return;
        };
        self.found.push(Found {
            method: method.to_uppercase(),
            path: path.clone(),
            handler: last.ident.to_string(),
        });
    }
}

impl<'a> Visit<'a> for Routes {
    fn visit_expr_method_call(&mut self, call: &'a syn::ExprMethodCall) {
        if call.method == "route" && call.args.len() == 2 {
            self.visit_expr(&call.receiver);
            if let Some(syn::Expr::Lit(syn::ExprLit {
                lit: syn::Lit::Str(path),
                ..
            })) = call.args.first()
            {
                self.path = Some(path.value());
                self.visit_expr(&call.args[1]);
                self.path = None;
            }
            return;
        }
        self.handler(&call.method, call.args.first());
        syn::visit::visit_expr_method_call(self, call);
    }

    fn visit_expr_call(&mut self, call: &'a syn::ExprCall) {
        if let syn::Expr::Path(function) = &*call.func
            && let Some(last) = function.path.segments.last()
            && function.path.segments.len() == 1
        {
            self.handler(&last.ident, call.args.first());
        }
        syn::visit::visit_expr_call(self, call);
    }

    // A handler written in place is no tool, and what it calls no handler.
    fn visit_expr_closure(&mut self, _: &'a syn::ExprClosure) {}
}

/// The last name of a type's path, and its first generic argument.
fn outer(ty: &syn::Type) -> Option<(String, Option<&syn::Type>)> {
    let syn::Type::Path(path) = ty else {
        return None;
    };
    let last = path.path.segments.last()?;
    let inner = match &last.arguments {
        syn::PathArguments::AngleBracketed(arguments) => {
            arguments.args.iter().find_map(|argument| match argument {
                syn::GenericArgument::Type(ty) => Some(ty),
                _ => None,
            })
        }
        _ => None,
    };
    Some((last.ident.to_string(), inner))
}

/// The JSON type of a path's part of the Rust type `ty`.
fn json_type(ty: &syn::Type) -> &'static str {
    match outer(ty).map(|(name, _)| name).as_deref() {
        Some("i64" | "i32" | "u32" | "u64" | "usize") => "integer",
        _ => "string",
    }
}

/// The parts `{name}` and `{*name}` of a path.
fn parts(path: &str) -> Vec<String> {
    path.split('/')
        .filter_map(|segment| segment.strip_prefix('{')?.strip_suffix('}'))
        .map(|part| part.trim_start_matches('*').to_string())
        .collect()
}

/// A tool's name: its method and its path after `/api/`, `get_cards_id_chats`.
fn tool_name(method: &str, path: &str) -> String {
    let rest = path.trim_start_matches("/api/").trim_start_matches('/');
    let rest: String = rest
        .chars()
        .filter(|c| !matches!(c, '{' | '}' | '*'))
        .map(|c| if c == '/' || c == '-' { '_' } else { c })
        .collect();
    format!("{}_{rest}", method.to_lowercase())
}

/// The first paragraph of an item's doc comment, on one line.
fn doc(attrs: &[syn::Attribute]) -> String {
    let mut lines = Vec::new();
    for attr in attrs {
        if let syn::Meta::NameValue(pair) = &attr.meta
            && pair.path.is_ident("doc")
            && let syn::Expr::Lit(syn::ExprLit {
                lit: syn::Lit::Str(text),
                ..
            }) = &pair.value
        {
            lines.push(text.value().trim().to_string());
        }
    }
    let first: Vec<String> = lines.into_iter().take_while(|l| !l.is_empty()).collect();
    // A link of rustdoc's is its words alone for the model.
    first.join(" ").replace(['`', '[', ']'], "")
}

/// The Rust code of one route's `Route`, or none where it is no tool.
fn route(found: &Found, handler: &syn::ItemFn) -> Option<String> {
    let (mut body, mut query, mut path_types) = ("None".to_string(), "None".to_string(), None);
    for input in &handler.sig.inputs {
        let syn::FnArg::Typed(typed) = input else {
            continue;
        };
        let Some((name, inner)) = outer(&typed.ty) else {
            continue;
        };
        let typed_of = |ty: &syn::Type| {
            format!(
                "Some(cw_coding::tools::app::typed::<{}>)",
                ty.to_token_stream()
            )
        };
        match (name.as_str(), inner) {
            (raw, _) if UNREACHABLE.contains(&raw) => return None,
            ("Json", Some(ty)) => body = typed_of(ty),
            ("Option", Some(ty)) => {
                if let Some(("Json", Some(ty))) = outer(ty).as_ref().map(|(n, t)| (n.as_str(), *t))
                {
                    body = typed_of(ty);
                }
            }
            // `Repeating` is axum-extra's `Query`, which takes a key more than once.
            ("Query" | "Repeating", Some(ty)) => query = typed_of(ty),
            ("Path", Some(syn::Type::Tuple(tuple))) => {
                path_types = Some(tuple.elems.iter().map(json_type).collect::<Vec<_>>())
            }
            ("Path", Some(ty)) => path_types = Some(vec![json_type(ty)]),
            _ => {}
        }
    }
    let names = parts(&found.path);
    let types = path_types.unwrap_or_default();
    let params: Vec<String> = names
        .iter()
        .enumerate()
        .map(|(at, name)| {
            format!(
                "({name:?}, {:?})",
                types.get(at).copied().unwrap_or("string")
            )
        })
        .collect();
    Some(format!(
        "        cw_coding::tools::app::Route {{ name: {:?}, method: {:?}, path: {:?}, doc: {:?}, params: &[{}], query: {query}, body: {body} }},\n",
        tool_name(&found.method, &found.path),
        found.method,
        found.path,
        doc(&handler.attrs),
        params.join(", "),
    ))
}

/// The routes of the file `source` as tools, or none where it has no routes.
fn tools_of(source: &str) -> Option<String> {
    let file = syn::parse_file(source).expect("an API file parses");
    let mut routes = Routes::default();
    // Those of `fn routes` alone, which `api::routes` merges: not the gate's.
    for item in &file.items {
        if let syn::Item::Fn(function) = item
            && function.sig.ident == "routes"
        {
            routes.visit_item_fn(function);
        }
    }
    if routes.found.is_empty() {
        return None;
    }
    let handlers: BTreeMap<String, &syn::ItemFn> = file
        .items
        .iter()
        .filter_map(|item| match item {
            syn::Item::Fn(function) => Some((function.sig.ident.to_string(), function)),
            _ => None,
        })
        .collect();
    let mut code = String::from("vec![\n");
    for found in &routes.found {
        if let Some(handler) = handlers.get(&found.handler)
            && let Some(line) = route(found, handler)
        {
            code.push_str(&line);
        }
    }
    code.push_str("    ]");
    Some(code)
}

fn route_tools() {
    let out = Path::new(&std::env::var("OUT_DIR").expect("cargo sets OUT_DIR")).join("route_tools");
    std::fs::create_dir_all(&out).expect("the build's folder can be written");
    let read = |path: &Path| std::fs::read_to_string(path).expect("an API file reads");
    let mut modules = Vec::new();
    let mut files: Vec<_> = std::fs::read_dir("src/api")
        .expect("src/api is there")
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| path.extension().is_some_and(|e| e == "rs"))
        .collect();
    files.sort();
    for path in files {
        let module = path
            .file_stem()
            .expect("a file has a name")
            .to_string_lossy()
            .to_string();
        if let Some(code) = tools_of(&read(&path)) {
            let text = format!(
                "/// This file's routes as tools; written by build.rs.\npub(super) fn route_tools() -> Vec<cw_coding::tools::app::Route> {{\n    {code}\n}}\n"
            );
            std::fs::write(out.join(format!("{module}.rs")), text).expect("written");
            modules.push(module);
        }
    }
    let own = tools_of(&read(Path::new("src/api.rs"))).unwrap_or_else(|| "vec![]".into());
    let mut all = format!(
        "/// Every route of the API as a tool; written by build.rs.\npub(crate) fn route_tools() -> Vec<cw_coding::tools::app::Route> {{\n    let mut all = {own};\n"
    );
    for module in modules {
        // Writing into a String cannot fail.
        let _ = writeln!(all, "    all.extend({module}::route_tools());");
    }
    all.push_str("    all\n}\n");
    std::fs::write(out.join("api.rs"), all).expect("written");
}
