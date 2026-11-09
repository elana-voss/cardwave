//! The desktop app: starts the Cardwave server in-process on a free local port
//! (none free: a message box, `no_free_port`) and opens a window on it, just
//! another browser client; logs in the data folder's `logs` (`open_logs`). A
//! second start brings the open window up and ends (not on a test's scratch folder).
//!
//! The companion window (`open_companion`) is see-through, frameless, on top
//! and as large as the work area; it lets clicks through but where its page
//! says the cursor is on what it shows, asked about 60 times a second
//! (`follow_cursor`). The pages call the commands here by a capability given
//! to the server's address (`allow_pages`). The last window closed ends the
//! process, a reply under way too (`end_with_last`). The page draws the title
//! bar (`window_*`); a link opened in a new window goes to the system's
//! browser (`outside`); `open_page` opens a third window, `page`. Updates:
//! update.rs.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[macro_use]
mod commands;
mod update;

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use cardwave_server::{DEFAULT_PORTS, Options, bind_local, router, serve};
use commands::COMMANDS;
use cw_platform::logs;
use tauri::generate_handler;
use tauri::ipc::CapabilityBuilder;
use tauri::webview::NewWindowResponse;
use tauri::{
    AppHandle, Manager, PhysicalPosition, PhysicalSize, State, Url, WebviewUrl, WebviewWindow,
    WebviewWindowBuilder,
};
use update::{update_check, update_install};

/// A folder for the app to keep everything in, in place of the user's own: its
/// database in `data`, and in `webview` what the window itself stores. The
/// tests in the desktop window run on a scratch folder this way, with a
/// throwaway key in `CARDWAVE_DB_KEY`, and never open the user's data.
const DATA_DIR_ENV: &str = "CARDWAVE_DATA_DIR";
const MAIN: &str = "main";
const COMPANION: &str = "companion";
const PAGE: &str = "page";

/// Where the server is and where the windows keep what they store.
struct Shell {
    url: String,
    scratch: Option<PathBuf>,
    logs: PathBuf,
}

/// The companion: whether it was started with the app already, whether the
/// cursor is on what its page shows, and whether its window was made anew
/// since `follow_cursor` last looked.
#[derive(Default)]
struct Companion {
    started: AtomicBool,
    over: AtomicBool,
    fresh: AtomicBool,
}

fn main() -> tauri::Result<()> {
    let scratch = std::env::var_os(DATA_DIR_ENV).map(PathBuf::from);
    let mut builder = tauri::Builder::default();
    // A second start brings the open window up and ends: two would share one
    // database. Not on a test's scratch folder, which the owner's open app
    // (the same identifier) would otherwise take over.
    if scratch.is_none() {
        builder = builder.plugin(tauri_plugin_single_instance::init(|app, _, _| {
            let app = app.clone();
            // Made off the main thread, where a window made waits for ever on Windows.
            tauri::async_runtime::spawn(async move {
                if let Err(failure) = bring(&app, MAIN, None, |hash| main_window(&app, hash)) {
                    eprintln!("the open window could not be brought up: {failure}");
                }
            });
        }));
    }
    builder
        .manage(Companion::default())
        .manage(update::Pending::default())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .invoke_handler(commands!(generate_handler))
        .on_window_event(|window, event| {
            if matches!(event, tauri::WindowEvent::Destroyed) {
                end_with_last(window.app_handle(), window.label());
            }
        })
        .setup(move |app| {
            let data_dir = match &scratch {
                Some(dir) => dir.join("data"),
                None => app.path().app_data_dir()?,
            };
            if let Err(failure) = logs::start(&data_dir) {
                eprintln!("the logs could not be started: {failure}");
            }
            let logs = logs::folder(&data_dir);
            let web_dir = web_dir(app.handle())?;
            let runtime = tokio::runtime::Runtime::new()?;
            let listener = runtime
                .block_on(bind_local(DEFAULT_PORTS))
                .inspect_err(|_| no_free_port())?;
            let url = format!("http://{}/", listener.local_addr()?);
            // The home network's listener starts on this runtime, where the database says so.
            let inside = runtime.enter();
            // `llama-server` comes with the app, filled in by `tools/llama.py`.
            let llama = app.path().resource_dir()?.join("llama");
            let mut options = Options::product(data_dir, Some(web_dir), llama)?;
            // A test's scratch folder has its own Documents, so the user's is never imported.
            if let Some(dir) = &scratch {
                options.documents = Some(dir.join("Documents"));
            }
            let server = router(options)?;
            drop(inside);
            std::thread::spawn(move || {
                if let Err(e) = runtime.block_on(serve(listener, server, std::future::pending())) {
                    eprintln!("Cardwave server stopped: {e}");
                }
            });
            allow_pages(app.handle(), &url)?;
            app.manage(Shell { url, scratch, logs });
            main_window(app.handle(), "")?;
            let handle = app.handle().clone();
            std::thread::spawn(move || follow_cursor(&handle));
            Ok(())
        })
        .run(tauri::generate_context!())
}

/// Tells the user, in a system message box, that the app cannot start while
/// other programs hold all its ports; the app ends after it. English: the
/// shell has no texts of its own in the app's languages.
fn no_free_port() {
    rfd::MessageDialog::new()
        .set_level(rfd::MessageLevel::Error)
        .set_title("Cardwave")
        .set_description(NO_FREE_PORT)
        .set_buttons(rfd::MessageButtons::Ok)
        // Its answer can only be the one button.
        .show();
}

const NO_FREE_PORT: &str = "Cardwave could not start because the ports it uses are in use by \
    other programs. Close some programs or restart your computer, then start Cardwave again.";

/// Ends the app once its last window is gone. Tauri should end it then by
/// itself, but once a window closed while a reply was written left the process
/// serving without a window, holding the data folder (smoke test of 0.1.0):
/// so it is asked to, and the process ends after `LAST_GRACE` all the same.
/// A reply cut so is ended at the next start.
fn end_with_last(app: &AppHandle, gone: &str) {
    const LAST_GRACE: Duration = Duration::from_secs(3);
    if app.webview_windows().keys().any(|label| label != gone) {
        return;
    }
    std::thread::spawn(|| {
        std::thread::sleep(LAST_GRACE);
        std::process::exit(0);
    });
    app.exit(0);
}

/// Lets the server's pages, in the app's window and the companion's, call the
/// commands here, and no other page.
fn allow_pages(app: &AppHandle, url: &str) -> anyhow::Result<()> {
    let mut pages = CapabilityBuilder::new("pages")
        .remote(format!("{url}*"))
        .windows([MAIN, COMPANION, PAGE]);
    for command in COMMANDS {
        pages = pages.permission(format!("allow-{}", command.replace('_', "-")));
    }
    Ok(app.add_capability(pages)?)
}

/// A window on the server's page `page`, told it is the desktop app's.
fn window<'a>(
    app: &'a AppHandle,
    label: &'a str,
    page: &str,
) -> anyhow::Result<WebviewWindowBuilder<'a, tauri::Wry, AppHandle>> {
    let shell = app.state::<Shell>();
    let url = format!("{}{page}", shell.url);
    let window = WebviewWindowBuilder::new(app, label, WebviewUrl::External(url.parse()?))
        .on_new_window(|url, _| {
            outside(&url);
            NewWindowResponse::Deny
        });
    // The window saves a file into the user's Downloads folder without asking
    // (WebView2 does), so the app's page is told the folder, to say where a
    // file went, and which window it is in (the window of one page has no
    // tabs). Only that page: another site the window may come to show
    // learns nothing of the user's folders.
    // Without a Downloads folder the system can name, it is `null`, and the page still knows the app.
    let downloads = app.path().download_dir().ok();
    let mut window =
        window.initialization_script(told(&shell.url, downloads.as_deref(), &shell.logs, label));
    // Both windows keep what they store in one place, so they are signed in alike.
    if let Some(dir) = &shell.scratch {
        window = window.data_directory(dir.join("webview"));
    }
    Ok(window)
}

/// The script that tells the page at `url` (only there) it is in the desktop
/// app's window `label`, with the Downloads folder and the logs' folder.
fn told(url: &str, downloads: Option<&Path>, logs: &Path, label: &str) -> String {
    let downloads = downloads.map(Path::to_string_lossy);
    let origin = serde_json::json!(url.trim_end_matches('/'));
    let told = serde_json::json!({ "downloads": downloads, "logs": logs.to_string_lossy(), "window": label });
    format!("if (location.origin === {origin}) window.cardwaveDesktop = {told};")
}

/// Opens a web page's `url` in the system's browser; another kind of address
/// (a file, a program's) is not opened. Nothing to tell where it fails.
fn outside(url: &Url) {
    if !is_web(url) {
        return;
    }
    if let Err(failure) = system_open(&["rundll32", "url.dll,FileProtocolHandler"], url.as_str()) {
        eprintln!("the browser could not be opened: {failure}");
    }
}

/// Has the system open `what` (a web page's address, a folder): on Windows
/// with the program and its arguments `windows`, elsewhere as the system opens files.
fn system_open(windows: &[&str], what: impl AsRef<std::ffi::OsStr>) -> std::io::Result<()> {
    #[cfg(windows)]
    let mut command = {
        let mut command = std::process::Command::new(windows[0]);
        command.args(&windows[1..]);
        command
    };
    #[cfg(target_os = "macos")]
    let mut command = std::process::Command::new("open");
    #[cfg(all(unix, not(target_os = "macos")))]
    let mut command = std::process::Command::new("xdg-open");
    #[cfg(not(windows))]
    let _ = windows;
    command.arg(what).spawn().map(drop)
}

/// Opens the logs' folder in the system's file manager ("About Cardwave").
#[tauri::command]
fn open_logs(shell: State<Shell>) -> Result<(), String> {
    // A folder the logs could not make is made here, so the file manager opens it and not another.
    std::fs::create_dir_all(&shell.logs).map_err(|failure| failure.to_string())?;
    system_open(&["explorer"], &shell.logs).map_err(|failure| failure.to_string())
}

/// Whether `url` is a web page's, which the system's browser may open.
fn is_web(url: &Url) -> bool {
    matches!(url.scheme(), "http" | "https")
}

/// The app's window, at the address `hash` of its page: 1200 × 800 where the
/// screen has room, else no larger than its work area with the frame, and
/// centred in it (at 200% a fixed size lay behind the taskbar).
fn main_window(app: &AppHandle, hash: &str) -> anyhow::Result<WebviewWindow> {
    app_window(app, MAIN, hash, (1200.0, 800.0), false)
}

/// A window of the app's pages, labelled `label`, at the address `hash`, of
/// the size `size` where the screen has room, else of its work area with the
/// frame; centred in the work area, or at its right edge where `right`.
fn app_window(
    app: &AppHandle,
    label: &str,
    hash: &str,
    size: (f64, f64),
    right: bool,
) -> anyhow::Result<WebviewWindow> {
    let shown = window(app, label, hash)?
        .title("Cardwave")
        // The page draws the title bar (docs/design.md, "Rail"); the edges still size the window.
        .decorations(false)
        .inner_size(size.0, size.1)
        .visible(false)
        // Files dropped on the window are the page's to take, as in any
        // browser: Tauri's own handler would keep them from it on Windows.
        .disable_drag_drop_handler()
        .build()?;
    let screen = match shown.current_monitor()? {
        Some(screen) => Some(screen),
        None => app.primary_monitor()?,
    };
    if let Some(screen) = screen {
        let area = *screen.work_area();
        let (inner, outer) = (shown.inner_size()?, shown.outer_size()?);
        let frame = (outer.width - inner.width, outer.height - inner.height);
        let width = inner.width.min(area.size.width.saturating_sub(frame.0));
        let height = inner.height.min(area.size.height.saturating_sub(frame.1));
        shown.set_size(PhysicalSize::new(width, height))?;
        let gap = |room: u32, size: u32| (room.saturating_sub(size) / 2) as i32;
        let left = if right {
            area.size.width.saturating_sub(width + frame.0) as i32
        } else {
            gap(area.size.width, width + frame.0)
        };
        shown.set_position(PhysicalPosition::new(
            area.position.x + left,
            area.position.y + gap(area.size.height, height + frame.1),
        ))?;
    }
    shown.show()?;
    Ok(shown)
}

/// Opens the companion window, or has an open one read its page anew (another
/// character may be the companion now).
fn open_companion(app: &AppHandle) -> anyhow::Result<()> {
    if let Some(open) = app.get_webview_window(COMPANION) {
        open.eval("location.reload()")?;
        return Ok(open.show()?);
    }
    let Some(screen) = app.primary_monitor()? else {
        return Ok(());
    };
    let area = *screen.work_area();
    let state = app.state::<Companion>();
    // Until its page says so, the cursor is on nothing it shows, whatever the window before said: the new one lets clicks through.
    state.over.store(false, Ordering::Relaxed);
    state.fresh.store(true, Ordering::Relaxed);
    let companion = window(app, COMPANION, "companion.html")?
        // Until its page names it in the page's language (`window_title`).
        .title("Cardwave")
        .transparent(true)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .shadow(false)
        .resizable(false)
        .visible(false)
        .disable_drag_drop_handler()
        .build()?;
    companion.set_position(PhysicalPosition::new(area.position.x, area.position.y))?;
    companion.set_size(PhysicalSize::new(area.size.width, area.size.height))?;
    companion.show()?;
    Ok(())
}

/// For as long as the app runs, started once: while the companion window is
/// open, tells its page where the cursor is whenever it moves (CSS pixels of
/// the window, or `null` outside it), and lets clicks through but where the
/// page says the cursor is on what it shows; while none is open, waits. A
/// window made anew (`fresh`, also one closed and made again between two
/// looks) takes clicks and has been told nothing.
fn follow_cursor(app: &AppHandle) {
    let Companion { over, fresh, .. } = &*app.state::<Companion>();
    // Not known yet: the first round lets clicks through, as the window is shown by then.
    let mut ignoring = false;
    let mut told: Option<Option<(i32, i32)>> = None;
    loop {
        let Some(window) = app.get_webview_window(COMPANION) else {
            std::thread::sleep(Duration::from_millis(250));
            continue;
        };
        if fresh.swap(false, Ordering::Relaxed) {
            (ignoring, told) = (false, None);
        }
        std::thread::sleep(Duration::from_millis(16));
        let (Ok(cursor), Ok(at), Ok(size), Ok(scale)) = (
            app.cursor_position(),
            window.inner_position(),
            window.inner_size(),
            window.scale_factor(),
        ) else {
            continue;
        };
        let (x, y) = (cursor.x - f64::from(at.x), cursor.y - f64::from(at.y));
        let inside =
            x >= 0.0 && y >= 0.0 && x < f64::from(size.width) && y < f64::from(size.height);
        let now = inside.then(|| ((x / scale) as i32, (y / scale) as i32));
        if told != Some(now) {
            let script = match now {
                Some((x, y)) => format!("window.companionCursor?.({x}, {y})"),
                None => "window.companionCursor?.(null, null)".to_string(),
            };
            // It fails only on a window closing, which needs no telling.
            let _ = window.eval(script);
            told = Some(now);
        }
        let accept = inside && over.load(Ordering::Relaxed);
        if accept == ignoring {
            ignoring = !accept;
            // It fails only on a window closing.
            let _ = window.set_ignore_cursor_events(ignoring);
        }
    }
}

/// Opens the companion window (the settings' switch, "Make companion"). A
/// command that makes a window is `async`, as one run on the main thread
/// waits for it there for ever on Windows (seen; Tauri's documentation says so).
#[tauri::command]
async fn companion_open(app: AppHandle) -> Result<(), String> {
    open_companion(&app).map_err(|e| e.to_string())
}

/// Opens the companion window as the app starts, once however often the
/// app's page starts.
#[tauri::command]
async fn companion_start(app: AppHandle, companion: State<'_, Companion>) -> Result<(), String> {
    if companion.started.swap(true, Ordering::Relaxed) {
        return Ok(());
    }
    open_companion(&app).map_err(|e| e.to_string())
}

/// Closes the companion window.
#[tauri::command]
fn companion_quit(app: AppHandle) -> Result<(), String> {
    match app.get_webview_window(COMPANION) {
        Some(window) => window.destroy().map_err(|e| e.to_string()),
        None => Ok(()),
    }
}

/// Whether the cursor is on what the companion's page shows.
#[tauri::command]
fn companion_over(over: bool, companion: State<Companion>) {
    companion.over.store(over, Ordering::Relaxed);
}

/// Shows the app's window, made anew where it was closed, at the address
/// `hash` of its page where one is given.
#[tauri::command]
async fn open_main(app: AppHandle, hash: Option<String>) -> Result<(), String> {
    bring(&app, MAIN, hash.as_deref(), |hash| main_window(&app, hash))
}

/// Shows the app's page at the address `hash` in a window of its own, at the
/// work area's right, beside the app's window: made where there is none, else
/// moved to the address and brought to the front.
#[tauri::command]
async fn open_page(app: AppHandle, hash: String) -> Result<(), String> {
    bring(&app, PAGE, Some(&hash), |hash| {
        app_window(&app, PAGE, hash, (900.0, 800.0), true)
    })
}

/// Brings the window `label` to the front, moved to the address `hash` where
/// one is given, or made at it (else at the page's start) by `make`.
fn bring(
    app: &AppHandle,
    label: &str,
    hash: Option<&str>,
    make: impl FnOnce(&str) -> anyhow::Result<WebviewWindow>,
) -> Result<(), String> {
    let shown = match app.get_webview_window(label) {
        Some(window) => {
            if let Some(hash) = hash {
                let hash = serde_json::json!(hash);
                window
                    .eval(format!("location.hash = {hash}"))
                    .map_err(|e| e.to_string())?;
            }
            window
        }
        None => make(hash.unwrap_or("")).map_err(|e| e.to_string())?,
    };
    // A window not minimized stays as it is; showing it follows.
    let _ = shown.unminimize();
    shown
        .show()
        .and_then(|()| shown.set_focus())
        .map_err(|e| e.to_string())
}

/// Release builds read the UI bundled as a resource; dev builds read `web/dist`.
fn web_dir(app: &tauri::AppHandle) -> tauri::Result<PathBuf> {
    if cfg!(debug_assertions) {
        Ok(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../web/dist"))
    } else {
        Ok(app.path().resource_dir()?.join("web"))
    }
}

/// Names the window the page is in, in the page's language: the companion
/// window, which shows no title bar but is named in the system's lists of
/// windows.
#[tauri::command]
fn window_title(window: WebviewWindow, title: String) -> Result<(), String> {
    window.set_title(&title).map_err(|e| e.to_string())
}

/// Minimizes the window the page is in: the title bar's first button.
#[tauri::command]
fn window_minimize(window: WebviewWindow) -> Result<(), String> {
    window.minimize().map_err(|e| e.to_string())
}

/// Maximizes the window the page is in, or gives it its size back where it
/// is maximized: the title bar's second button, and a double-click on it.
#[tauri::command]
fn window_maximize(window: WebviewWindow) -> Result<(), String> {
    let maximized = window.is_maximized().map_err(|e| e.to_string())?;
    if maximized {
        window.unmaximize()
    } else {
        window.maximize()
    }
    .map_err(|e| e.to_string())
}

/// Closes the window the page is in, as its frame's × would.
#[tauri::command]
fn window_close(window: WebviewWindow) -> Result<(), String> {
    window.close().map_err(|e| e.to_string())
}

/// Moves the window with the pointer while its button is held: a press on
/// the title bar.
#[tauri::command]
fn window_drag(window: WebviewWindow) -> Result<(), String> {
    window.start_dragging().map_err(|e| e.to_string())
}

/// The system's folder picker over the window the page is in, which answers
/// the folder chosen, or nothing where it was cancelled. `async`, so that
/// the main thread is free while it is open. It opens at `start`, or without
/// one in the user's Documents folder, as the system names it (`start_in`).
#[tauri::command]
async fn pick_folder(
    window: WebviewWindow,
    start: Option<String>,
) -> Result<Option<String>, String> {
    let mut picker = rfd::AsyncFileDialog::new().set_parent(&window);
    // Without a Documents folder the system's picker opens where it chooses.
    if let Some(folder) = start_in(start, cardwave_server::documents_folder()) {
        picker = picker.set_directory(folder);
    }
    let chosen = picker.pick_folder().await;
    Ok(chosen.map(|folder| folder.path().to_string_lossy().into_owned()))
}

/// Where the folder picker opens: at the folder asked for, else in the
/// user's Documents folder, where the system has one.
fn start_in(start: Option<String>, documents: Option<PathBuf>) -> Option<PathBuf> {
    start
        .filter(|start| !start.is_empty())
        .map(PathBuf::from)
        .or(documents)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_folder_picker_opens_in_documents_while_no_folder_is_asked_for() {
        let documents = Some(PathBuf::from("C:/Users/a/Documents"));
        assert_eq!(start_in(None, documents.clone()), documents);
        assert_eq!(start_in(Some(String::new()), documents.clone()), documents);
        assert_eq!(
            start_in(Some("D:/cards".into()), documents),
            Some(PathBuf::from("D:/cards"))
        );
        assert_eq!(start_in(None, None), None);
    }

    #[test]
    fn the_page_is_told_it_is_in_the_desktop_app_without_a_downloads_folder() {
        let script = told("http://127.0.0.1:8477/", None, Path::new("C:/logs"), MAIN);
        assert_eq!(
            script,
            r#"if (location.origin === "http://127.0.0.1:8477") window.cardwaveDesktop = {"downloads":null,"logs":"C:/logs","window":"main"};"#
        );
    }

    #[test]
    fn only_a_web_page_opens_in_the_browser() {
        let is = |url: &str| is_web(&url.parse().unwrap());
        assert!(is("https://example.com/a") && is("http://example.com"));
        assert!(!is("file:///C:/Windows/notepad.exe") && !is("javascript:alert(1)"));
    }
}
