//! Users of this server, its accounts. Cards, personas and chats each belong to
//! one user, and every storage function takes the user it acts for.
//!
//! `local` is this computer's account, the owner, which the server acts for
//! where a page has signed in as no other (`api.rs`, `Caller`): it is known by
//! the mark `users.local`, not by its name. Its password is the database's own
//! (`password.rs`); another account's (`add`, `set_password`) is kept here as
//! argon2id's PHC string and checked by `password::verify`. A name is not empty,
//! has at most `NAME_LIMIT` characters, and is no other account's, upper and
//! lower case aside (`checked`, `free`). A picture is kept small (`small`):
//! `PICTURE` pixels square, a PNG.

use std::io::Cursor;

use anyhow::{anyhow, ensure};
use cw_core::{Code, Fail};
use image::ImageFormat;
use image::imageops::FilterType;

use crate::password;
use cw_core::{NotFound, now_ms};

/// The most characters an account's name may have: it stands in one line of
/// the rail.
const NAME_LIMIT: usize = 40;

/// A picture's side in pixels: twice the largest round it is shown in.
const PICTURE: u32 = 128;

/// An account as `account` tells it.
pub struct Called {
    pub name: String,
    /// Whether it is this computer's account.
    pub local: bool,
    /// When its picture was set, where it has one.
    pub picture_at: Option<i64>,
}

/// An account as `list` tells it.
pub struct Listed {
    pub id: i64,
    pub name: String,
    pub local: bool,
    /// Whether it has a password of its own; this computer's has the database's.
    pub password: bool,
}

/// What the accounts need of the database, which `cw_store::users` gives.
pub trait Storage {
    /// Whether other devices on the network may reach the server.
    fn reached(&self) -> anyhow::Result<bool>;
    fn set_reached(&self, on: bool) -> anyhow::Result<()>;
    fn add_user(&self, name: &str) -> anyhow::Result<i64>;
    /// Adds an account with the password kept as `hash`, unless another
    /// account is called `name`, upper and lower case aside.
    fn add_account(&self, name: &str, hash: &str) -> anyhow::Result<Option<i64>>;
    /// Calls `user` `name`, unless another account is called so: whether it did.
    fn rename_account(&self, user: i64, name: &str) -> anyhow::Result<bool>;
    /// Keeps `hash` as the password of `user`, which is not this computer's
    /// account: whether it was there to.
    fn set_password(&self, user: i64, hash: &str) -> anyhow::Result<bool>;
    fn set_user_picture(
        &self,
        user: i64,
        picture: Option<&[u8]>,
        at: Option<i64>,
    ) -> anyhow::Result<()>;
    fn account(&self, user: i64) -> anyhow::Result<Called>;
    fn accounts(&self) -> anyhow::Result<Vec<Listed>>;
    fn password_of(&self, user: i64) -> anyhow::Result<Option<String>>;
    fn delete_account(&self, user: i64) -> anyhow::Result<()>;
    fn user_picture(&self, user: i64) -> anyhow::Result<Option<Vec<u8>>>;
    /// This computer's account, made called `name` if there is none.
    fn local_user(&self, name: &str) -> anyhow::Result<i64>;
}

pub fn create(db: &dyn Storage, name: &str) -> anyhow::Result<i64> {
    db.add_user(name)
}

/// `typed` without the space around it, if it may be a name.
fn checked(typed: &str) -> anyhow::Result<String> {
    let name = typed.trim();
    ensure!(
        !name.is_empty(),
        Fail::said(Code::Needed, "the account needs a name").with("what", "account_name")
    );
    ensure!(
        name.chars().count() <= NAME_LIMIT,
        Fail::said(
            Code::TooLong,
            format!("an account's name has at most {NAME_LIMIT} characters")
        )
        .with("what", "account_name")
        .with("name_limit", NAME_LIMIT)
    );
    ensure!(
        !name.chars().any(char::is_control),
        Fail::said(
            Code::NotReadable,
            "the name holds characters a name cannot have"
        )
        .with("what", "name_characters")
    );
    Ok(name.to_string())
}

/// Adds an account called `typed`, which signs in with `password`.
pub fn add(db: &dyn Storage, typed: &str, password: &str) -> anyhow::Result<i64> {
    let name = checked(typed)?;
    let hash = password::hash(password)?;
    let added = db.add_account(&name, &hash)?;
    added.ok_or_else(|| {
        anyhow!(
            Fail::said(Code::Taken, format!("another account is called “{name}”"))
                .with("what", "account_name")
                .with("name", name.to_string())
        )
    })
}

/// What `user` is called, whether it is this computer's account, and when its
/// picture was set.
pub fn account(db: &dyn Storage, user: i64) -> anyhow::Result<Called> {
    db.account(user)
}

/// Every account, this computer's first, then by name.
pub fn list(db: &dyn Storage) -> anyhow::Result<Vec<Listed>> {
    db.accounts()
}

/// Calls `user` by the name `typed`, without the space around it, and answers
/// as [`account`] does then.
pub fn rename(db: &dyn Storage, user: i64, typed: &str) -> anyhow::Result<Called> {
    let name = checked(typed)?;
    let renamed = db.rename_account(user, &name)?;
    ensure!(
        renamed,
        Fail::said(Code::Taken, format!("another account is called “{name}”"))
            .with("what", "account_name")
            .with("name", name.to_string())
    );
    account(db, user)
}

/// Gives `user`, which is not this computer's account, the password `password`.
pub fn set_password(db: &dyn Storage, user: i64, password: &str) -> anyhow::Result<()> {
    let hash = password::hash(password)?;
    ensure!(db.set_password(user, &hash)?, NotFound("account"));
    Ok(())
}

/// The password of `user` as it is kept, where it has one of its own.
pub fn password_of(db: &dyn Storage, user: i64) -> anyhow::Result<Option<String>> {
    db.password_of(user)
}

/// Deletes `user` and all it holds, which cannot be undone; this computer's
/// account is not deleted.
pub fn delete(db: &dyn Storage, user: i64) -> anyhow::Result<()> {
    db.delete_account(user)
}

/// The picture `file` (a PNG or a JPEG) made `PICTURE` pixels square, of its
/// middle, as a PNG.
pub fn small(file: &[u8]) -> anyhow::Result<Vec<u8>> {
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(4096);
    limits.max_image_height = Some(4096);
    limits.max_alloc = Some(64 << 20);
    let mut reader = image::ImageReader::new(Cursor::new(file)).with_guessed_format()?;
    reader.limits(limits);
    let picture = reader.decode().map_err(|_| {
        anyhow!(
            Fail::said(
                Code::NotReadable,
                "the picture is no PNG or JPEG of at most 4,096 pixels a side that can be read"
            )
            .with("what", "account_picture")
        )
    })?;
    let side = picture.width().min(picture.height());
    let middle = picture.crop_imm(
        (picture.width() - side) / 2,
        (picture.height() - side) / 2,
        side,
        side,
    );
    let mut out = Cursor::new(Vec::new());
    middle
        .resize_exact(PICTURE, PICTURE, FilterType::Lanczos3)
        .to_rgba8()
        .write_to(&mut out, ImageFormat::Png)?;
    Ok(out.into_inner())
}

/// Gives `user` the picture `file`, made small, or takes its picture away.
pub fn set_picture(db: &dyn Storage, user: i64, file: Option<&[u8]>) -> anyhow::Result<()> {
    let picture = file.map(small).transpose()?;
    let at = picture.as_ref().map(|_| now_ms());
    db.set_user_picture(user, picture.as_deref(), at)
}

/// The picture of `user`, where it has one.
pub fn picture(db: &dyn Storage, user: i64) -> anyhow::Result<Option<Vec<u8>>> {
    db.user_picture(user)
}

/// Whether other devices reach the server, kept as `meta`'s `network`.
pub fn reached(db: &dyn Storage) -> anyhow::Result<bool> {
    db.reached()
}

/// Keeps whether other devices reach the server.
pub fn set_reached(db: &dyn Storage, on: bool) -> anyhow::Result<()> {
    db.set_reached(on)
}

/// This computer's account, the server's one built-in user, made on first use
/// and called `wanted` then (the system's user name), or "You" where that
/// cannot be a name.
pub fn local(db: &dyn Storage, wanted: &str) -> anyhow::Result<i64> {
    let name = checked(wanted).unwrap_or_else(|_| FIRST_NAME.to_string());
    db.local_user(&name)
}

/// What this computer's account is called where the system tells no name.
pub const FIRST_NAME: &str = "You";
