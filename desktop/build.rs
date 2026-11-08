include!("src/commands.rs");

fn main() {
    // The commands of src/main.rs, so that a capability can let the server's pages call them (`allow_pages`).
    let commands = tauri_build::AppManifest::new().commands(COMMANDS);
    tauri_build::try_build(tauri_build::Attributes::new().app_manifest(commands))
        .expect("the Tauri build failed");
}
