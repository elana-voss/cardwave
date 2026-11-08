/// The commands of src/main.rs that the server's pages may call, the one list
/// of them: build.rs declares them to Tauri (`COMMANDS`), main.rs hands them to
/// `generate_handler` (`commands!(generate_handler)`) and lets the pages call
/// them (`allow_pages`).
macro_rules! commands {
    ($with:ident) => {
        $with!(
            companion_open,
            companion_start,
            companion_quit,
            companion_over,
            open_main,
            open_page,
            window_minimize,
            window_maximize,
            window_close,
            window_drag,
            window_title,
            pick_folder,
            open_logs,
            update_check,
            update_install
        )
    };
}

/// The commands' names as strings.
macro_rules! names {
    ($($command:ident),*) => {
        &[$(stringify!($command)),*]
    };
}

pub const COMMANDS: &[&str] = commands!(names);
