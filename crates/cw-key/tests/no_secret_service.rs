//! On a Linux where no Secret Service answers, the key is kept in a file only
//! the user can read. Its own test program, as it sets the environment: no
//! session bus, and a config folder of its own.
#![cfg(target_os = "linux")]

use std::os::unix::fs::PermissionsExt;

use cw_key::Place;

#[test]
fn without_a_secret_service_the_key_is_a_file_only_the_user_reads() {
    let scratch = std::env::temp_dir().join(format!("cw-key-no-service-{}", std::process::id()));
    let (config, data) = (scratch.join("config"), scratch.join("data"));
    // SAFETY: this program's one test, so no other thread reads the environment.
    unsafe {
        std::env::set_var("DBUS_SESSION_BUS_ADDRESS", "unix:path=/nonexistent/bus");
        std::env::set_var("XDG_CONFIG_HOME", &config);
    }
    let place = Place::Store("cardwave-test-file".into());
    let key = place.load_or_create(&data).unwrap();
    let files: Vec<_> = std::fs::read_dir(config.join("cardwave-test-file"))
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .collect();
    assert_eq!(files.len(), 1);
    assert_eq!(
        std::fs::metadata(&files[0]).unwrap().permissions().mode() & 0o777,
        0o600
    );
    assert_eq!(place.load_or_create(&data).unwrap(), key);
    place.forget(&data).unwrap();
    assert!(!files[0].exists());
    std::fs::remove_dir_all(&scratch).unwrap();
}
