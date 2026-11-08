//! The accounts: who uses the app (`users`), who is signed in (`sessions`)
//! and the password that locks the database's key (`password`). `users` and
//! `sessions` each take their own `Storage`, which cw-store implements.

pub mod password;
pub mod sessions;
pub mod users;
