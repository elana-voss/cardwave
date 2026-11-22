//! The sandbox on Linux (`sandbox_linux.rs`): a command reaches its folder and
//! no other, a team's the internet but not this computer, the server's programs
//! and node with a folder of its own, and it ends at its
//! time, at its caps of processes and memory and with the server. Built on
//! Linux alone; needs the user's systemd manager, as the sandbox does. Tests of
//! the server ending, its manager refusing or another session bus run this
//! binary again as the server (the last two by `as_server`).

#![cfg(target_os = "linux")]

mod common;

use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::time::Duration;

use common::Folder;

/// How long a team command may take to start (as in `coding.rs`).
const COMMAND_START: Duration = Duration::from_secs(120);

#[test]
fn a_command_on_linux_reaches_its_folder_and_no_other() {
    let inside = Folder::new("inside");
    let outside = Folder::new("outside");
    let secret = outside.0.join("secret.txt");
    std::fs::write(&secret, "the secret").unwrap();
    let time = Duration::from_secs(20);
    let run = |folder: &Folder, command: &str| {
        cw_sandbox::run(&folder.0, command, time, &AtomicBool::new(false)).unwrap()
    };

    let ran = run(&inside, "echo made > made.txt && cat made.txt");
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    assert_eq!(ran.output.trim(), "made");
    let ran = run(&inside, cw_sandbox::LISTING);
    assert_eq!(
        (ran.code, ran.output.trim()),
        (Some(0), "made.txt"),
        "{}",
        ran.output
    );

    let ran = run(&inside, &format!("cat '{}'", secret.display()));
    assert!(!ran.output.contains("the secret"), "{}", ran.output);
    assert_ne!(ran.code, Some(0));
    let ran = run(&inside, &format!("ls '{}'", outside.0.display()));
    assert!(!ran.output.contains("secret.txt"), "{}", ran.output);
    assert_ne!(ran.code, Some(0));

    let planted = outside.0.join("planted.txt");
    let ran = run(&inside, &format!("echo x > '{}'", planted.display()));
    assert!(!planted.exists(), "{}", ran.output);
    let ran = run(&inside, &format!("rm -f '{}'", secret.display()));
    assert!(secret.exists(), "{}", ran.output);

    // A file's mode, times and length outside are not changed; inside they are.
    use std::os::unix::fs::{MetadataExt, PermissionsExt};
    let before = std::fs::metadata(&secret).unwrap();
    for change in ["chmod 000", "touch -d 2000-01-01", "truncate -s 0"] {
        let ran = run(&inside, &format!("{change} '{}'", secret.display()));
        assert!(
            ran.output.contains("Permission denied"),
            "{change}: {}",
            ran.output
        );
        assert_ne!(ran.code, Some(0), "{change}");
    }
    let after = std::fs::metadata(&secret).unwrap();
    assert_eq!(
        (after.mode(), after.mtime(), after.len()),
        (before.mode(), before.mtime(), before.len())
    );
    let ran = run(
        &inside,
        "chmod +x made.txt && truncate -s 2 made.txt && touch -d 2000-01-01 made.txt",
    );
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    let made = std::fs::metadata(inside.0.join("made.txt")).unwrap();
    assert_eq!(made.permissions().mode() & 0o100, 0o100);
    // 2000-01-01 in any time zone, before 2001-09-09.
    assert!(made.mtime() < 1_000_000_000, "{}", made.mtime());
    assert_eq!(made.len(), 2);

    // A tree with a link is copied with its times; a link's own times change
    // inside alone, never its target's outside nor a link outside.
    let ran = run(
        &inside,
        &format!(
            "mkdir tree && ln -s made.txt tree/link && ln -s '{}' away && cp -a tree copy \
             && tar cf t.tar tree && mkdir un && tar xf t.tar -C un && touch -h -d 2000-01-01 away",
            secret.display()
        ),
    );
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    let link = std::fs::symlink_metadata(inside.0.join("away")).unwrap();
    assert!(link.mtime() < 1_000_000_000, "{}", link.mtime());
    assert_eq!(std::fs::metadata(&secret).unwrap().mtime(), before.mtime());
    std::os::unix::fs::symlink(&secret, outside.0.join("link")).unwrap();
    let ran = run(
        &inside,
        &format!(
            "touch -h -d 2000-01-01 '{}'",
            outside.0.join("link").display()
        ),
    );
    assert!(ran.output.contains("Permission denied"), "{}", ran.output);

    // No network for a plain command, and no way to leave the process group.
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let ran = run(
        &inside,
        &format!("bash -c 'exec 3<>/dev/tcp/127.0.0.1/{port}' && echo reached"),
    );
    assert!(!ran.output.contains("reached"), "{}", ran.output);
    assert!(ran.output.contains("Permission denied"), "{}", ran.output);
    let ran = run(&inside, "setsid sh -c 'echo left' || echo kept");
    assert!(ran.output.contains("kept"), "{}", ran.output);
    assert!(!ran.output.contains("left"), "{}", ran.output);
    // A signal to the lowest group there is ends neither the call nor the server's watch.
    // sh's own kill refuses the number before any call: python3 makes it.
    if std::path::Path::new("/usr/bin/python3").exists() {
        // A chmod after it is the server's to do: it fails where its watch ended.
        let lowest = "touch low.txt; python3 -c 'import os; os.kill(-2147483648, 0)'; chmod +x low.txt && echo next";
        let ran = run(&inside, lowest);
        assert!(ran.output.contains("next"), "{}", ran.output);
        assert!(ran.output.contains("Error"), "{}", ran.output);
    } else {
        eprintln!("skipped: the lowest group's signal, python3 not installed on this computer");
    }
    let ran = run(&inside, "env");
    assert!(!ran.output.contains("CARGO"), "{}", ran.output);

    let made = inside.0.join("made.txt");
    let ran = run(&outside, &format!("cat '{}'", made.display()));
    assert!(ran.output.contains("Permission denied"), "{}", ran.output);
    assert_ne!(ran.code, Some(0));
}

#[test]
fn a_teams_command_on_linux_reaches_the_internet_but_not_this_computer() {
    let inside = Folder::new("internet");
    let data = Folder::new("internet-data");
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let reach = cw_sandbox::Reach {
        network: true,
        programs: true,
        data: data.0.clone(),
    };
    // The internet itself was measured by hand (curl to an https site: 200); no test asks it.
    let command = format!("bash -c 'exec 3<>/dev/tcp/127.0.0.1/{port}' && echo reached");
    let ran = cw_sandbox::run_with(
        &inside.0,
        &command,
        Duration::from_secs(30),
        &AtomicBool::new(false),
        reach,
    )
    .unwrap();
    assert!(
        ran.output.contains("Network is unreachable"),
        "{}",
        ran.output
    );
    assert!(!ran.output.contains("reached"), "{}", ran.output);
}

#[test]
fn a_teams_command_on_linux_has_the_servers_programs_and_a_folder_of_its_own() {
    let folder = Folder::new("reach");
    let data = Folder::new("reach-data");
    let run = |reach| {
        let command =
            r#"echo "$PATH"; echo "[$HOME]"; echo kept > "$HOME/kept.txt" && cat "$HOME/kept.txt""#;
        cw_sandbox::run_with(
            &folder.0,
            command,
            Duration::from_secs(20),
            &AtomicBool::new(false),
            reach,
        )
        .unwrap()
    };
    let host = std::env::var("PATH").unwrap();
    // The system's own folders are on every command's PATH.
    let system = [
        "/usr/local/sbin",
        "/usr/local/bin",
        "/usr/sbin",
        "/usr/bin",
        "/sbin",
        "/bin",
    ];
    let granted = |part: &&str| {
        !system.contains(part) && cw_sandbox::grantable(std::path::Path::new(part), &data.0)
    };
    let last = host.split(':').rfind(granted).map(str::to_string);
    let reached = run(cw_sandbox::Reach {
        network: false,
        programs: true,
        data: data.0.clone(),
    });
    assert!(!reached.output.contains("[]"), "{}", reached.output);
    assert_eq!(reached.code, Some(0), "{}", reached.output);
    let bare = run(cw_sandbox::Reach::default());
    assert!(bare.output.contains("[]"), "{}", bare.output);
    assert_ne!(bare.code, Some(0), "{}", bare.output);
    if let Some(last) = last {
        assert!(reached.output.contains(&last), "{}", reached.output);
        assert!(!bare.output.contains(&last), "{}", bare.output);
    }
}

#[test]
fn a_teams_command_on_linux_runs_node_and_npm_where_they_are_installed_and_reads_no_other_file() {
    let installed = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .any(|folder| folder.join("node").is_file() && folder.join("npm").is_file());
    let folder = Folder::new("node");
    let other = Folder::new("node-other");
    let data = Folder::new("node-data");
    std::fs::write(other.0.join("secret.txt"), "kept").unwrap();
    let run = |command: &str| {
        let reach = cw_sandbox::Reach {
            network: false,
            programs: true,
            data: data.0.clone(),
        };
        cw_sandbox::run_with(
            &folder.0,
            command,
            COMMAND_START,
            &AtomicBool::new(false),
            reach,
        )
        .unwrap()
    };
    let secret = run(&format!("cat '{}/secret.txt'", other.path()));
    assert!(!secret.output.contains("kept"), "{}", secret.output);
    assert!(
        secret.output.contains("Permission denied"),
        "{}",
        secret.output
    );
    let own = run("echo mine > own.txt && cat own.txt");
    assert_eq!(own.output.trim(), "mine", "{}", own.output);
    if !installed {
        eprintln!("skipped: node and npm, not installed on this computer");
        return;
    }
    let ran = run(r#"node -e "console.log(1)" && npm --version"#);
    assert_eq!(ran.code, Some(0), "{}", ran.output);
    assert_eq!(ran.output.lines().next(), Some("1"), "{}", ran.output);
}

#[test]
fn a_command_on_linux_that_runs_too_long_is_ended() {
    let inside = Folder::new("long");
    // A child that would outlive the shell, also in a session of its own, is ended with it.
    let sleep = "sleep 1093 & setsid sleep 1094 & while :; do :; done";
    let left = || {
        let found = std::process::Command::new("pgrep")
            .args(["-f", "sleep 109[34]"])
            .output()
            .unwrap();
        String::from_utf8_lossy(&found.stdout).trim().to_string()
    };
    let began = std::time::Instant::now();
    let ran = cw_sandbox::run(
        &inside.0,
        sleep,
        Duration::from_secs(2),
        &AtomicBool::new(false),
    )
    .unwrap();
    assert_eq!(ran.code, None, "{}", ran.output);
    assert!(began.elapsed() < Duration::from_secs(10));
    assert_eq!(left(), "", "{}", ran.output);

    let stopped = Arc::new(AtomicBool::new(false));
    let stop = stopped.clone();
    std::thread::spawn(move || {
        std::thread::sleep(Duration::from_secs(1));
        stop.store(true, std::sync::atomic::Ordering::Relaxed);
    });
    let began = std::time::Instant::now();
    let ran = cw_sandbox::run(&inside.0, sleep, Duration::from_secs(60), &stopped).unwrap();
    assert_eq!(ran.code, None, "{}", ran.output);
    assert!(began.elapsed() < Duration::from_secs(10));
}

/// A command and all it starts hold at most the sandbox's 512 processes and
/// threads (`TASKS` in `linux/scope.rs`): a fork bomb stops.
#[test]
fn a_command_on_linux_cannot_start_more_processes_than_its_cap() {
    let inside = Folder::new("processes");
    let command = "n=0; while [ $n -lt 1024 ]; do sleep 60 >/dev/null 2>&1 & n=$((n+1)); echo $n; done; echo all started";
    let ran = cw_sandbox::run(
        &inside.0,
        command,
        Duration::from_secs(60),
        &AtomicBool::new(false),
    )
    .unwrap();
    let started: u32 = ran
        .output
        .lines()
        .rev()
        .find_map(|line| line.trim().parse().ok())
        .unwrap_or(0);
    assert!(!ran.output.contains("all started"), "{started} started");
    assert!(
        started < 1024 && started > 100,
        "{started} started: {}",
        ran.output
    );
}

/// A command and all it starts hold 1 GiB of memory together (`MEMORY` in
/// `linux/scope.rs`), as on Windows: of two processes of 600 MB each (`tail`
/// keeps the last bytes it read), at most one ends.
#[test]
fn a_command_on_linux_holds_its_memory_with_all_it_starts() {
    let inside = Folder::new("memory");
    let take = "head -c 600000000 /dev/zero | tail -c 600000000 >/dev/null";
    let command = format!("{take} && echo one & {take} && echo two & wait");
    let ran = cw_sandbox::run(
        &inside.0,
        &command,
        Duration::from_secs(60),
        &AtomicBool::new(false),
    )
    .unwrap();
    assert!(
        !(ran.output.contains("one") && ran.output.contains("two")),
        "both ran: {:?} {}",
        ran.code,
        ran.output
    );
}

/// The server killed, a command's children end with it. The test runs itself
/// again as the server, with the folder named by `CW_SERVER_ENDS`.
#[test]
fn a_command_on_linux_ends_with_the_server() {
    const NAME: &str = "a_command_on_linux_ends_with_the_server";
    if let Some(folder) = std::env::var_os("CW_SERVER_ENDS") {
        let command = "sleep 1095 & echo $! > started; wait";
        // Ignored: this process is killed while it runs.
        let _ = cw_sandbox::run(
            std::path::Path::new(&folder),
            command,
            Duration::from_secs(60),
            &AtomicBool::new(false),
        );
        return;
    }
    let folder = Folder::new("server-ends");
    let mut server = std::process::Command::new(std::env::current_exe().unwrap())
        .args([NAME, "--exact", "--test-threads=1"])
        .env("CW_SERVER_ENDS", &folder.0)
        .stdout(std::process::Stdio::null())
        .spawn()
        .unwrap();
    let started = folder.0.join("started");
    let began = std::time::Instant::now();
    while !started.exists() && began.elapsed() < Duration::from_secs(20) {
        std::thread::sleep(Duration::from_millis(100));
    }
    server.kill().unwrap();
    server.wait().unwrap();
    let pid = std::fs::read_to_string(&started).unwrap();
    // Alive while its stat is there and not a zombie's, which waits only for init.
    let alive = || {
        std::fs::read_to_string(format!("/proc/{}/stat", pid.trim())).is_ok_and(|stat| {
            !stat
                .rsplit(')')
                .next()
                .unwrap_or("")
                .trim_start()
                .starts_with('Z')
        })
    };
    let killed = std::time::Instant::now();
    while alive() && killed.elapsed() < Duration::from_secs(5) {
        std::thread::sleep(Duration::from_millis(100));
    }
    assert!(!alive(), "sleep {} outlived the server", pid.trim());
}

/// The user's manager refusing the command's scope (here: no `busctl` on the
/// server's `PATH`), the command is refused as unsafe, unrun, and the call
/// returns. The test runs itself again as the server, with `CW_NO_SCOPE` set.
#[test]
fn a_command_on_linux_whose_scope_is_refused_is_refused() {
    const NAME: &str = "a_command_on_linux_whose_scope_is_refused_is_refused";
    let folder = Folder::new("no-scope");
    if std::env::var_os("CW_NO_SCOPE").is_some() {
        let ran = cw_sandbox::run(
            &folder.0,
            "echo ran > ran.txt",
            Duration::from_secs(20),
            &AtomicBool::new(false),
        );
        let error = format!("{:#}", ran.expect_err("the command ran without its scope"));
        assert!(error.contains("cannot run safely"), "{error}");
        assert!(!folder.0.join("ran.txt").exists(), "the command ran");
        return;
    }
    let status = as_server(
        NAME,
        &[("CW_NO_SCOPE", "1".as_ref()), ("PATH", folder.0.as_ref())],
    );
    assert!(status.success(), "refused wrongly");
}

/// A command refused for its missing sandbox fails with the one failure the
/// settings give for it (`Code::CommandsUnsafe`), not a text of its own.
#[test]
fn a_command_on_linux_without_its_sandbox_fails_as_commands_unsafe() {
    const NAME: &str = "a_command_on_linux_without_its_sandbox_fails_as_commands_unsafe";
    let folder = Folder::new("no-scope-code");
    if std::env::var_os("CW_NO_SCOPE").is_some() {
        let time = Duration::from_secs(20);
        let ran = cw_sandbox::run(&folder.0, "echo ran", time, &AtomicBool::new(false));
        let error = ran.expect_err("the command ran without its scope");
        let code = cw_core::coded(&error).map(|fail| fail.code);
        assert_eq!(code, Some(cw_core::Code::CommandsUnsafe), "{error:#}");
        return;
    }
    let status = as_server(
        NAME,
        &[("CW_NO_SCOPE", "1".as_ref()), ("PATH", folder.0.as_ref())],
    );
    assert!(status.success(), "not told as commands unsafe");
}

/// A session bus that is not the systemd manager's (`dbus-launch`'s,
/// `dbus-run-session`'s) named by `DBUS_SESSION_BUS_ADDRESS`, a command still
/// runs: its scope is asked of the manager's own bus. The test runs itself
/// again as the server, with `CW_OTHER_BUS` set.
#[test]
fn a_command_on_linux_runs_beside_another_session_bus() {
    const NAME: &str = "a_command_on_linux_runs_beside_another_session_bus";
    if std::env::var_os("CW_OTHER_BUS").is_some() {
        let folder = Folder::new("other-bus");
        let time = Duration::from_secs(20);
        let ran = cw_sandbox::run(&folder.0, "echo ran", time, &AtomicBool::new(false));
        let ran = ran.unwrap();
        assert_eq!(
            (ran.code, ran.output.trim()),
            (Some(0), "ran"),
            "{}",
            ran.output
        );
        return;
    }
    let bus = "unix:path=/nonexistent/cardwave-test/bus".as_ref();
    let status = as_server(
        NAME,
        &[
            ("CW_OTHER_BUS", "1".as_ref()),
            ("DBUS_SESSION_BUS_ADDRESS", bus),
        ],
    );
    assert!(status.success(), "the command did not run");
}

/// Runs test `name` of this binary again as the server with `variables` set;
/// its exit, which a hang past 30 s fails.
fn as_server(name: &str, variables: &[(&str, &std::ffi::OsStr)]) -> std::process::ExitStatus {
    let mut server = std::process::Command::new(std::env::current_exe().unwrap());
    server
        .args([name, "--exact", "--test-threads=1"])
        .stdout(std::process::Stdio::null());
    for (name, value) in variables {
        server.env(name, value);
    }
    let mut server = server.spawn().unwrap();
    let began = std::time::Instant::now();
    while began.elapsed() < Duration::from_secs(30) {
        if let Some(status) = server.try_wait().unwrap() {
            return status;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    // Ignored: the test fails here whether or not the kill and wait succeed.
    let _ = server.kill();
    let _ = server.wait();
    panic!("the command hung");
}
