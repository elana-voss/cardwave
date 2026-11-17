//! The names of the files the windows save on Linux, where WebKitGTK names a
//! file by its own rules ("Desk Lamp.png" becomes "Desk_Lamp.png"): the page
//! tells the name it gives a file just before it hands the file over (the
//! command `download_name`, `Named::tell`), and the file is saved under that
//! name in the folder the window chose (`Named::destination`), numbered where
//! the name is taken, as WebView2 does. On Windows the window keeps the page's
//! name itself and nothing here is asked.

use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

/// The name the page last gave a file it saves, with the file's address.
#[derive(Default)]
pub struct Named(Mutex<Option<(String, String)>>);

impl Named {
    /// The page saves the file at `url` under `name` next.
    pub fn tell(&self, url: String, name: String) {
        *self.0.lock().unwrap_or_else(PoisonError::into_inner) = Some((url, name));
    }

    /// Where the file at `url` goes instead of `chosen`: beside it under the
    /// page's name, "name (1).ext" where that is taken; `None` where the page
    /// named no file at that address (or no name), which keeps `chosen`.
    #[cfg_attr(not(target_os = "linux"), allow(dead_code))]
    pub fn destination(&self, url: &str, chosen: &Path) -> Option<PathBuf> {
        // Taken only for its own address: a name told for another file waits for that one.
        let mut slot = self.0.lock().unwrap_or_else(PoisonError::into_inner);
        let (_, name) = slot.take_if(|(told, _)| told == url)?;
        drop(slot);
        // A name is a file's, never a path to another folder.
        let name = name.replace(['/', '\\', '\0'], "_");
        if name.trim_matches('.').is_empty() {
            return None;
        }
        let folder = chosen.parent()?;
        let path = folder.join(&name);
        let named = Path::new(&name);
        let (stem, extension) = match (named.file_stem(), named.extension()) {
            (Some(stem), Some(extension)) => (
                stem.to_string_lossy(),
                format!(".{}", extension.to_string_lossy()),
            ),
            _ => (name.as_str().into(), String::new()),
        };
        std::iter::once(path)
            .chain((1..).map(|n| folder.join(format!("{stem} ({n}){extension}"))))
            .find(|path| !path.exists())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_file_keeps_the_pages_name_and_is_numbered_where_it_is_taken() {
        let folder =
            std::env::temp_dir().join(format!("cardwave-downloads-{}", std::process::id()));
        std::fs::create_dir_all(&folder).unwrap();
        let chosen = folder.join("Desk_Lamp.png");
        let named = Named::default();

        named.tell("blob:a".into(), "Desk Lamp.png".into());
        assert_eq!(
            named.destination("blob:a", &chosen),
            Some(folder.join("Desk Lamp.png"))
        );
        std::fs::write(folder.join("Desk Lamp.png"), b"").unwrap();
        named.tell("blob:a".into(), "Desk Lamp.png".into());
        assert_eq!(
            named.destination("blob:a", &chosen),
            Some(folder.join("Desk Lamp (1).png"))
        );
        // Told once: a second file at the address, another address, and a path for a name keep the window's.
        assert_eq!(named.destination("blob:a", &chosen), None);
        named.tell("blob:b".into(), "Other.png".into());
        assert_eq!(named.destination("blob:a", &chosen), None);
        // Another address's question leaves the name told for its own file.
        assert_eq!(
            named.destination("blob:b", &chosen),
            Some(folder.join("Other.png"))
        );
        named.tell("blob:c".into(), "../up/x.png".into());
        assert_eq!(
            named.destination("blob:c", &chosen),
            Some(folder.join(".._up_x.png"))
        );
        std::fs::remove_dir_all(&folder).unwrap();
    }
}
