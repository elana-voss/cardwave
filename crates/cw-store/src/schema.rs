//! The schema: the steps that make the database what this build reads, each
//! appended to `MIGRATIONS`, and `migrate`, which runs those not yet run.
//! Its tests are in schema/tests.rs.

use anyhow::{Context, bail};
use cw_core::{Code, Fail};
use rusqlite::Connection;

/// Schema steps, applied in order; `user_version` counts how many have run.
/// Append only: a released step never changes.
const MIGRATIONS: &[&str] = &[
    "create table meta (key text primary key, value text not null) strict, without rowid;",
    // Cards, personas and chats. A card version keeps the card's files as imported:
    // TOML as text, assets and the picture once per content hash in `blobs`.
    // A chat's messages form a tree: siblings are swipes, `head_id` is the newest
    // message of the branch in view. Messages go with their chat; `parent_id` has no
    // cascade of its own because SQLite stops a cascade after 1000 nested levels.
    // Trash is `trashed_at`, apart from `archived`, so a restored item is what it was.
    // Cards, personas and chats belong to one user. What a prompt build changes
    // (macro variables, the lorebook's timed state) is kept in `state` on the
    // message the build ended at, so every branch has its own.
    "create table blobs (
        id integer primary key,
        hash blob not null unique,
        data blob not null
     ) strict;
     create table users (
        id integer primary key,
        name text not null unique,
        created_at integer not null
     ) strict;
     create table cards (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        title text not null,
        favorite integer not null default 0,
        archived integer not null default 0,
        trashed_at integer,
        created_at integer not null,
        updated_at integer not null
     ) strict;
     create table card_versions (
        id integer primary key,
        card_id integer not null references cards (id) on delete cascade,
        number integer not null,
        image_id integer not null references blobs (id),
        created_at integer not null,
        unique (card_id, number)
     ) strict;
     create table card_files (
        version_id integer not null references card_versions (id) on delete cascade,
        name text not null,
        toml text,
        asset_id integer references blobs (id),
        primary key (version_id, name),
        check ((toml is null) <> (asset_id is null))
     ) strict, without rowid;
     create table personas (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        description text not null default '',
        favorite integer not null default 0,
        archived integer not null default 0,
        trashed_at integer,
        created_at integer not null
     ) strict;
     create table chats (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        title text not null,
        persona_id integer references personas (id) on delete set null,
        head_id integer references messages (id) on delete set null,
        favorite integer not null default 0,
        archived integer not null default 0,
        trashed_at integer,
        created_at integer not null,
        updated_at integer not null
     ) strict;
     create table chat_characters (
        id integer primary key,
        chat_id integer not null references chats (id) on delete cascade,
        position integer not null,
        version_id integer not null references card_versions (id),
        character text not null,
        unique (chat_id, position)
     ) strict;
     create index chat_characters_by_version on chat_characters (version_id);
     create table messages (
        id integer primary key,
        chat_id integer not null references chats (id) on delete cascade,
        parent_id integer references messages (id),
        role text not null check (role in ('system', 'user', 'assistant')),
        speaker_id integer references chat_characters (id) on delete set null,
        content text not null,
        complete integer not null default 1,
        token_count integer,
        state text,
        created_at integer not null
     ) strict;
     create index cards_by_user on cards (user_id);
     create index personas_by_user on personas (user_id);
     create index chats_by_user on chats (user_id);
     create index messages_by_chat on messages (chat_id);
     create index messages_by_parent on messages (parent_id);
     create index chats_by_persona on chats (persona_id);",
    // The model provider of each user: one OpenAI-compatible server. `sampling` is
    // JSON, the parameters the user chose to send along. A chat is asked on every
    // write whether a reply is being generated in it, hence the index.
    "create table providers (
        user_id integer primary key references users (id) on delete cascade,
        base_url text not null,
        api_key text not null,
        model text not null,
        sampling text not null,
        updated_at integer not null
     ) strict;
     create index messages_being_written on messages (chat_id) where complete = 0;",
    // What the library shows and searches of a card, taken from its newest version:
    // the characters' names and the card's tags (JSON lists), the start of the first
    // greeting, and `search`, the lower-case text a search looks in. All of it can
    // be built again from the card's files.
    "create table card_index (
        card_id integer primary key references cards (id) on delete cascade,
        version_id integer not null references card_versions (id) on delete cascade,
        names text not null,
        tags text not null,
        excerpt text not null,
        search text not null
     ) strict;",
    // What a user has chosen for the app as a whole, as JSON; see `settings`.
    "alter table users add column settings text not null default '{}';",
    // A chat that went to the trash with one of its cards comes back with it; see `trash`.
    // Until now a card went there alone: the chats of those that are there follow them.
    "alter table chats add column trashed_with integer references cards (id) on delete set null;
     update chats set (trashed_at, trashed_with) =
        (select c.trashed_at, c.id from chat_characters p
         join card_versions v on v.id = p.version_id join cards c on c.id = v.card_id
         where p.chat_id = chats.id and c.trashed_at is not null order by c.id limit 1)
     where trashed_at is null and exists
        (select 1 from chat_characters p
         join card_versions v on v.id = p.version_id join cards c on c.id = v.card_id
         where p.chat_id = chats.id and c.trashed_at is not null);",
    // What of its cards' lore a chat leaves out of its prompts, by the reference in
    // the card: a whole lorebook (`lorebook.ID`) or one entry (`lore.ID`). And on a
    // reply, as JSON, the entries that went into the prompt it answers.
    "create table chat_lore_off (
        chat_id integer not null references chats (id) on delete cascade,
        card_id integer not null references cards (id) on delete cascade,
        reference text not null,
        primary key (chat_id, card_id, reference)
     ) strict, without rowid;
     create index chat_lore_off_by_card on chat_lore_off (card_id);
     alter table messages add column lore text;",
    // The persona a user's new chats start with; see `personas`.
    "alter table users add column default_persona_id integer references personas (id) on delete set null;",
    // Lorebooks of the user's own (see `lorebooks`): each one CCV4 document, with
    // what the library lists and searches of it beside it. A chat takes some of
    // them along, and leaves out of each what `chat_lorebook_off` names: the
    // lorebook as a whole or single entries, by their references in the document,
    // as `chat_lore_off` does for a card's lore. That goes when the chat lets the
    // lorebook go.
    "create table lorebooks (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        description text not null default '',
        toml text not null,
        entries integer not null,
        entry_names text not null,
        favorite integer not null default 0,
        archived integer not null default 0,
        trashed_at integer,
        created_at integer not null
     ) strict;
     create index lorebooks_by_user on lorebooks (user_id);
     create table chat_lorebooks (
        chat_id integer not null references chats (id) on delete cascade,
        lorebook_id integer not null references lorebooks (id) on delete cascade,
        added_at integer not null,
        primary key (chat_id, lorebook_id)
     ) strict, without rowid;
     create index chat_lorebooks_by_lorebook on chat_lorebooks (lorebook_id);
     create table chat_lorebook_off (
        chat_id integer not null,
        lorebook_id integer not null,
        reference text not null,
        primary key (chat_id, lorebook_id, reference),
        foreign key (chat_id, lorebook_id) references chat_lorebooks (chat_id, lorebook_id) on delete cascade
     ) strict, without rowid;",
    // The lorebooks of the library a card has attached: every chat with one of
    // the card's characters has them, as it has those it took along itself. A
    // chat leaves things out of those too, so `chat_lorebook_off` no longer
    // hangs on the chat having taken the lorebook: it is made anew without
    // that tie, and its rows go with the chat, with the lorebook, or when the
    // chat no longer has the lorebook either way (`lorebooks::forget_unused`).
    "create table card_lorebooks (
        card_id integer not null references cards (id) on delete cascade,
        lorebook_id integer not null references lorebooks (id) on delete cascade,
        added_at integer not null,
        primary key (card_id, lorebook_id)
     ) strict, without rowid;
     create index card_lorebooks_by_lorebook on card_lorebooks (lorebook_id);
     create table chat_lorebook_left_out (
        chat_id integer not null references chats (id) on delete cascade,
        lorebook_id integer not null references lorebooks (id) on delete cascade,
        reference text not null,
        primary key (chat_id, lorebook_id, reference)
     ) strict, without rowid;
     insert into chat_lorebook_left_out select chat_id, lorebook_id, reference from chat_lorebook_off;
     drop table chat_lorebook_off;
     alter table chat_lorebook_left_out rename to chat_lorebook_off;
     create index chat_lorebook_off_by_lorebook on chat_lorebook_off (lorebook_id);",
    // What a chat's character is called in it, for the list of chats, which reads
    // no card: the name the card's version gives it, written when the chat starts
    // and when it is moved to another version. A character of a chat started
    // before has none until the server's start reads it (`chats::name_missing`).
    "alter table chat_characters add column name text;",
    // A card's picture made small for the lists (see `thumbnails`), by the box
    // in pixels it was made to fill. It is made when a list first asks for it
    // and can be made again, so the table may be emptied at any time. A small
    // picture goes with the picture it is of.
    "create table thumbnails (
        blob_id integer not null references blobs (id) on delete cascade,
        width integer not null,
        height integer not null,
        data blob not null,
        primary key (blob_id, width, height)
     ) strict;",
    // Who replies next in a chat of several characters (see `chats::turn`): the
    // chat's turn order, and the character picked by hand to reply in the
    // order's place, which the chat forgets when that character leaves it.
    "alter table chats add column turn_order text not null default 'natural'
        check (turn_order in ('natural', 'list', 'random'));
     alter table chats add column replier_id integer references chat_characters (id) on delete set null;
     create index chats_by_replier on chats (replier_id);",
    // Whether a character of a chat was muted, while there was muting; read
    // by nothing since (see `chats::turn`).
    "alter table chat_characters add column muted integer not null default 0 check (muted in (0, 1));",
    // Which user is this computer's account (see `users`): the one every
    // request acts for until there is a login. It was known by its name,
    // `local`, and is known by this mark from here on, so that it can be
    // renamed; there is at most one.
    "alter table users add column local integer not null default 0 check (local in (0, 1));
     update users set local = 1 where name = 'local';
     create unique index users_local on users (local) where local = 1;",
    // What the user calls a provider whose address is not on the list (see
    // `provider`), empty for none.
    "alter table providers add column name text not null default '';",
    // Model presets: providers under names, each with its key, its model and
    // its values as `providers` keeps them, one of which the user puts in the
    // stored provider's place. The provider it took that place of is kept as a
    // row of its own without a name (`replaced`), for the Undo of that, and no
    // list shows it (see `provider::presets`). A row's number is no other
    // row's later (`autoincrement`): the page names such a row by its number,
    // which must find nothing once the row is gone, not a preset made since.
    "create table presets (
        id integer primary key autoincrement,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        base_url text not null,
        api_key text not null,
        model text not null,
        sampling text not null,
        provider_name text not null,
        replaced integer not null default 0 check (replaced in (0, 1)),
        created_at integer not null
     ) strict;
     create unique index presets_by_name on presets (user_id, name) where replaced = 0;",
    // A message the user deleted is kept, hidden, until its deletion can no
    // longer be taken back (see `chats::delete_message`): `deleted_from` is the
    // chat's head when it was deleted, and null for a message that is there.
    "alter table messages add column deleted_from integer;
     create index messages_deleted on messages (chat_id) where deleted_from is not null;",
    // The worker model beside the chat model (see `provider`), empty for none;
    // of a preset, only the row kept for an Undo holds one.
    "alter table providers add column worker_model text not null default '';
     alter table presets add column worker_model text not null default '';",
    // A card described by the worker model (see `describe`): one row from the
    // moment it is queued, `state` saying how far it came. `tags` are the
    // classifier's terms as the library shows them, `terms` what is searched
    // for and not shown, `facets` the classification as read. A card's title
    // that the user gave (`title_edited`) is never replaced by a generated
    // one, and `own_tags` are the tags the user wrote, which a description
    // leaves as they are (see `cards`).
    "create table card_descriptions (
        card_id integer primary key references cards (id) on delete cascade,
        state text not null check (state in ('queued', 'described', 'failed', 'refused')),
        version_id integer,
        tags text not null default '[]',
        terms text not null default '',
        facets text not null default '',
        logline text not null default '',
        summary text not null default '',
        reason text not null default '',
        updated_at integer not null
     ) strict;
     alter table cards add column title_edited integer not null default 0 check (title_edited in (0, 1));
     alter table cards add column own_tags text not null default '[]';",
    // A card as the search model read it (see `search`): its vectors, each of
    // a piece of one of its fields, as 4-byte floats, and of which version and
    // by which model they were made. All of it can be made again.
    "create table card_search (
        card_id integer primary key references cards (id) on delete cascade,
        version_id integer not null,
        model text not null,
        read_at integer not null
     ) strict;
     create table card_chunks (
        id integer primary key,
        card_id integer not null references cards (id) on delete cascade,
        field integer not null,
        embedding blob not null
     ) strict;
     create index card_chunks_by_card on card_chunks (card_id);",
    // A chat's memories (see `memory`): each saved from one message, whose
    // branch it holds on; who of the chat's characters were there and who
    // know it, as JSON lists of `chat_characters` IDs; whether the user
    // deleted it (kept for the Undo until the server starts again).
    // `memory_replaced` says which memory took another's place, which holds
    // on the branches of the one that took it. `memory_reads` are the messages
    // a memory pass has read up to. `text_vectors` keeps a text's vectors by
    // the search model, by a hash of the model's name and the text, and when
    // they were last used; they can be made again.
    "create table memories (
        id integer primary key,
        chat_id integer not null references chats (id) on delete cascade,
        message_id integer not null references messages (id) on delete cascade,
        kind text not null check (kind in ('fact', 'event')),
        text text not null,
        scene text not null default '',
        present text not null default '[]',
        knows text not null default '[]',
        deleted integer not null default 0 check (deleted in (0, 1)),
        created_at integer not null
     ) strict;
     create index memories_by_chat on memories (chat_id);
     create index memories_by_message on memories (message_id);
     create table memory_replaced (
        memory_id integer not null references memories (id) on delete cascade,
        by_id integer not null references memories (id) on delete cascade,
        primary key (memory_id, by_id)
     ) strict;
     create table memory_reads (
        message_id integer primary key references messages (id) on delete cascade
     ) strict;
     create table text_vectors (
        hash blob primary key,
        embedding blob not null,
        used_at integer not null
     ) strict;",
    // Documents (see `documents`), each of a chat or of a card, kept as their
    // text; `model` is the search model that read it into `document_pieces`,
    // none until then; `deleted` as a memory's. A piece's `embedding` is the
    // vectors of its parts one after the other, as `text_vectors` keeps them.
    "create table documents (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        chat_id integer references chats (id) on delete cascade,
        card_id integer references cards (id) on delete cascade,
        name text not null,
        text text not null,
        words integer not null,
        model text,
        deleted integer not null default 0 check (deleted in (0, 1)),
        created_at integer not null,
        check ((chat_id is null) <> (card_id is null))
     ) strict;
     create index documents_by_chat on documents (chat_id);
     create index documents_by_card on documents (card_id);
     create table document_pieces (
        id integer primary key,
        document_id integer not null references documents (id) on delete cascade,
        text text not null,
        embedding blob not null
     ) strict;
     create index document_pieces_by_document on document_pieces (document_id);",
    // Prompt presets (see `prompt_presets`): a system prompt and an author's
    // note under a name, as CCV4 `prompt` blocks in TOML. The one in use for
    // the user's chats, none for the card's own prompt; and a chat's own
    // choice, where `prompt_preset_own` says it made one (`prompt_preset_id`
    // none: the card's own prompt), which a deleted preset takes back.
    "create table prompt_presets (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        blocks text not null,
        created_at integer not null
     ) strict;
     create unique index prompt_presets_by_name on prompt_presets (user_id, name);
     alter table users add column prompt_preset_id integer references prompt_presets (id) on delete set null;
     alter table chats add column prompt_preset_own integer not null default 0 check (prompt_preset_own in (0, 1));
     alter table chats add column prompt_preset_id integer references prompt_presets (id) on delete set null;
     create index chats_by_prompt_preset on chats (prompt_preset_id);",
    // Accounts: another account's password (argon2id, as a PHC string; this
    // computer's account has the database's own, `password.rs`), an account's
    // picture, and the sessions of the pages signed in, by their token's
    // SHA-256. `meta`'s `network` says whether other devices reach the server.
    "alter table users add column password text;
     alter table users add column picture blob;
     alter table users add column picture_at integer;
     create table sessions (
        token blob primary key,
        user_id integer not null references users (id) on delete cascade,
        created_at integer not null
     ) strict, without rowid;
     create index sessions_by_user on sessions (user_id);",
    // Pictures (see `images`): an account's image model, at its own address
    // with its own key, or at the chat provider's with its key where
    // `base_url` is null; and a picture a model made, with the message it
    // came as and the words it was made from.
    "create table image_models (
        user_id integer primary key references users (id) on delete cascade,
        base_url text,
        api_key text not null,
        model text not null,
        updated_at integer not null
     ) strict;
     create table pictures (
        message_id integer primary key references messages (id) on delete cascade,
        data blob not null,
        prompt text not null
     ) strict;",
    // A persona's picture, made small as an account's is; see `personas`.
    "alter table personas add column picture blob;
     alter table personas add column picture_at integer;",
    // On a reply, the tokens its prompt took and the context it had; see `chats::save_lore`.
    "alter table messages add column context_used integer;
     alter table messages add column context_size integer;",
    // What a chat allows its tools without asking ("Allow … for this chat"); see `chats::allow_tool`.
    "create table chat_tools_allowed (
        chat_id integer not null references chats (id) on delete cascade,
        kind text not null,
        primary key (chat_id, kind)
     ) strict, without rowid;",
    // The tools the model wrote (code mode); see `tools::written`. A deleted
    // one waits for Undo, flagged, until the server starts again.
    "create table written_tools (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        description text not null,
        parameters text not null,
        code text not null,
        enabled integer not null default 1,
        deleted integer not null default 0,
        chat_id integer references chats (id) on delete set null,
        created_at integer not null,
        uses integer not null default 0
     ) strict;
     create unique index written_tools_by_name on written_tools (user_id, name) where deleted = 0;",
    // The coding team's tasks, each with its card in a chat, its steps in
    // order, and per step the files it changed as they were before and after
    // it (none for a file not there), its checkpoint; see `coding`.
    "create table coding_tasks (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        chat_id integer not null references chats (id) on delete cascade,
        message_id integer references messages (id) on delete set null,
        goal text not null,
        folder text not null,
        team text not null,
        state text not null,
        planned integer not null default 0,
        verdict text,
        error text,
        started_at integer not null,
        ended_at integer
     ) strict;
     create index coding_tasks_by_message on coding_tasks (message_id);
     create table coding_steps (
        id integer primary key,
        task_id integer not null references coding_tasks (id) on delete cascade,
        who text not null,
        what text not null,
        detail text not null default '',
        state text not null,
        output text not null default '',
        checkpoint text,
        undone integer not null default 0,
        started_at integer not null
     ) strict;
     create table coding_changes (
        step_id integer not null references coding_steps (id) on delete cascade,
        path text not null,
        before blob,
        after blob,
        primary key (step_id, path)
     ) strict, without rowid;",
    // Assistant and companion (see `assistant`): the mode a chat was set to by
    // hand (none: it picks by itself) and the one it picked last; a
    // character's personality, the tools it may not use as an assistant (a
    // JSON list of their names) and whether it remembers; and an assistant's
    // memory, kept with its card's character across its chats.
    "alter table chats add column mode text;
     alter table chats add column auto_mode text;
     create table personalities (
        card_id integer not null references cards (id) on delete cascade,
        character text not null,
        tools_off text not null default '[]',
        memory integer not null default 1 check (memory in (0, 1)),
        primary key (card_id, character)
     ) strict, without rowid;
     alter table memories add column card_id integer references cards (id) on delete cascade;
     alter table memories add column character text;
     create index memories_by_character on memories (card_id, character);",
    // The model a reply was asked of, which a chat without a character names it by.
    "alter table messages add column model text;",
    // Every picture a card has had, which none is thrown away of: a card keeps
    // one version from now on (see `cards`), and its pictures stay here.
    "create table card_pictures (
        card_id integer not null references cards (id) on delete cascade,
        image_id integer not null references blobs (id),
        added_at integer not null,
        primary key (card_id, image_id)
     ) strict, without rowid;
     insert into card_pictures (card_id, image_id, added_at)
        select card_id, image_id, min(created_at) from card_versions group by card_id, image_id;",
    // A card version's id is never given again: the browser keeps its picture and files by it.
    "create table version_seq (last integer not null) strict;
     insert into version_seq select coalesce(max(id), 0) from card_versions;
     create trigger card_version_ids after insert on card_versions
     begin update version_seq set last = max(last, new.id); end;",
    // Where each of a card's pictures came from: `imported`, `file` or `made` (see `cards::pictures`).
    "alter table card_pictures add column source text not null default 'imported';",
    // Expression packs (see `expressions`): kept once per user by their pictures (`hash`), a picture per mood,
    // shared by the cards that have one; a pack goes to the Trash alone.
    "create table expression_packs (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        hash blob not null,
        trashed_at integer,
        created_at integer not null,
        unique (user_id, hash)
     ) strict;
     create table expression_pictures (
        pack_id integer not null references expression_packs (id) on delete cascade,
        mood text not null,
        image_id integer not null references blobs (id),
        primary key (pack_id, mood)
     ) strict, without rowid;
     alter table cards add column expression_pack_id integer references expression_packs (id) on delete set null;",
    // 3D figures (see `figures`): kept once per user by their file (`hash`), shared by the cards that have one,
    // as the card's or as one of its modes'; a figure goes to the Trash alone. Its number is never given again
    // (`autoincrement`), as the companion tells a figure by it.
    "create table figures (
        id integer primary key autoincrement,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        kind text not null,
        hash blob not null,
        file_id integer not null references blobs (id),
        still_id integer not null references blobs (id),
        trashed_at integer,
        created_at integer not null,
        unique (user_id, hash)
     ) strict;
     alter table cards add column figure_id integer references figures (id) on delete set null;
     create table card_mode_figures (
        card_id integer not null references cards (id) on delete cascade,
        mode text not null,
        figure_id integer not null references figures (id) on delete cascade,
        primary key (card_id, mode)
     ) strict, without rowid;",
    // A reply's "Used in this reply" (see `chats::messages`): its prompt's parts' tokens, and the pages and
    // files it read, each JSON.
    "alter table messages add column sent text;
     alter table messages add column reads text;",
    // How a chat's replies are written (see `chats::set_reply`): their length in tokens, and Code mode, which
    // were the account's settings before and are the chat's now, each chat keeping what its account had.
    "alter table chats add column reply_length integer not null default 350 check (reply_length > 0);
     alter table chats add column code_mode integer not null default 0 check (code_mode in (0, 1));
     update chats set code_mode = 1
      where user_id in (select id from users where json_extract(settings, '$.tools.code') = 1);
     update chats set reply_length = (select json_extract(p.sampling, '$.max_response_length')
                                      from providers p where p.user_id = chats.user_id)
      where (select json_extract(p.sampling, '$.max_response_length') from providers p where p.user_id = chats.user_id)
            between 1 and 100000;",
    // What a user attaches to a message (see `attachments`): a picture, kept here, or a document, kept in
    // `documents` for the chat; waiting for its message (none yet) until the message is sent.
    "create table attachments (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        chat_id integer not null references chats (id) on delete cascade,
        message_id integer references messages (id) on delete cascade,
        name text not null,
        picture blob,
        document_id integer references documents (id) on delete set null,
        created_at integer not null
     ) strict;
     create index attachments_by_chat on attachments (chat_id);
     create index attachments_by_message on attachments (message_id);",
    // How the characters of a chat of several keep replying by themselves (see `chats::set_talk`): the pause
    // between their replies in seconds and how many they write in a row, which were fixed at 4 and 10 before.
    "alter table chats add column talk_pause integer not null default 4 check (talk_pause between 0 and 600);
     alter table chats add column talk_replies integer not null default 10 check (talk_replies between 1 and 100);",
    // An account's providers (see `provider::kinds`): a row each, with its address, key and the name the user
    // gave it, and a row per kind of model (chat, background, images) naming the provider it is at, its model and
    // how its thinking is turned off (empty: it is not). The values for a reply are the account's. What was
    // kept before becomes rows of these: the stored provider with its chat and worker model and its values, the
    // image model's own address (else the chat provider's), and each model preset's provider; `providers` and
    // `image_models` go, keys and all.
    "create table provider_entries (
        id integer primary key autoincrement,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        base_url text not null,
        api_key text not null,
        created_at integer not null
     ) strict;
     create index provider_entries_by_user on provider_entries (user_id);
     create table model_kinds (
        user_id integer not null references users (id) on delete cascade,
        kind text not null check (kind in ('chat', 'background', 'images')),
        entry_id integer not null references provider_entries (id) on delete cascade,
        model text not null,
        thinking text not null default '',
        primary key (user_id, kind)
     ) strict, without rowid;
     create index model_kinds_by_entry on model_kinds (entry_id);
     alter table users add column sampling text not null default '{}';
     insert into provider_entries (user_id, name, base_url, api_key, created_at)
        select user_id, name, base_url, api_key, updated_at from providers order by user_id;
     insert into model_kinds (user_id, kind, entry_id, model)
        select p.user_id, 'chat', e.id, p.model from providers p join provider_entries e on e.user_id = p.user_id;
     insert into model_kinds (user_id, kind, entry_id, model)
        select p.user_id, 'background', e.id, p.worker_model
        from providers p join provider_entries e on e.user_id = p.user_id where p.worker_model <> '';
     update users set sampling = (select sampling from providers p where p.user_id = users.id)
        where id in (select user_id from providers);
     insert into provider_entries (user_id, name, base_url, api_key, created_at)
        select i.user_id, '', i.base_url, i.api_key, i.updated_at from image_models i
        where i.base_url is not null and not exists (select 1 from provider_entries e
            where e.user_id = i.user_id and e.base_url = i.base_url and e.api_key = i.api_key);
     insert into model_kinds (user_id, kind, entry_id, model)
        select i.user_id, 'images', coalesce(
            (select min(e.id) from provider_entries e
              where e.user_id = i.user_id and e.base_url = i.base_url and e.api_key = i.api_key),
            (select k.entry_id from model_kinds k where k.user_id = i.user_id and k.kind = 'chat')), i.model
        from image_models i
        where i.base_url is not null or exists (select 1 from model_kinds k where k.user_id = i.user_id and k.kind = 'chat');
     insert into provider_entries (user_id, name, base_url, api_key, created_at)
        select r.user_id, min(r.provider_name), r.base_url, r.api_key, min(r.created_at) from presets r
        where r.replaced = 0 and not exists (select 1 from provider_entries e
            where e.user_id = r.user_id and e.base_url = r.base_url and e.api_key = r.api_key)
        group by r.user_id, r.base_url, r.api_key;
     delete from presets where replaced = 1;
     alter table presets drop column worker_model;
     drop table providers;
     drop table image_models;",
    // A ComfyUI's saved workflow picked on Settings › Providers, by its name, and the node and input its
    // picture's words go into (`provider::kinds::Workflow`); empty while ComfyUI's default one is used.
    "alter table provider_entries add column workflow text not null default '';
     alter table provider_entries add column workflow_node text not null default '';
     alter table provider_entries add column workflow_input text not null default '';",
    // Voices (see `voice::own`): those a user made from a recording, the recording as prepared (a WAV file),
    // each numbered once (`autoincrement`), as a voice is told by its number; and the voice a card's character
    // reads in, a shipped voice's id or `own-<n>`.
    "create table own_voices (
        id integer primary key autoincrement,
        user_id integer not null references users (id) on delete cascade,
        name text not null,
        recording blob not null,
        created_at integer not null
     ) strict;
     create table card_voices (
        card_id integer primary key references cards (id) on delete cascade,
        voice text not null
     ) strict;",
    // What the user typed in a field and has not saved yet (`unsaved`), by the name the page gives the field.
    "create table unsaved (
        user_id integer not null references users (id) on delete cascade,
        field text not null,
        text text not null,
        updated_at integer not null,
        primary key (user_id, field)
     ) strict, without rowid;",
    // The memories of `memory` (`memory.rs`' head): a chat's (roleplay) or a card's character's (assistant,
    // companion), with its day 1; its state after each block read, kept to read the blocks after a changed one
    // again; its texts' vectors. What was remembered before goes, unread (the owner: greenfield).
    "drop table memory_reads;
     drop table memory_replaced;
     drop table memories;
     create table memory_stores (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        chat_id integer unique references chats (id) on delete cascade,
        card_id integer references cards (id) on delete cascade,
        character text,
        day_one integer,
        check ((chat_id is null) <> (card_id is null))
     ) strict;
     create unique index memory_stores_by_character on memory_stores (card_id, character);
     create index memory_stores_by_user on memory_stores (user_id);
     create table memory_blocks (
        id integer primary key autoincrement,
        store_id integer not null references memory_stores (id) on delete cascade,
        chat_id integer references chats (id) on delete set null,
        block integer not null,
        chain text not null,
        state text not null,
        saved text not null default '[]',
        message_id integer references messages (id) on delete set null
     ) strict;
     create index memory_blocks_by_store on memory_blocks (store_id, id);
     create index memory_blocks_by_chat on memory_blocks (chat_id);
     create index memory_blocks_by_message on memory_blocks (message_id);
     create table memory_vectors (
        store_id integer not null references memory_stores (id) on delete cascade,
        hash blob not null,
        embedding blob not null,
        primary key (store_id, hash)
     ) strict, without rowid;",
    // Search and voice as kinds a provider serves (`provider::kinds::Kind`), beside this computer's downloads.
    "create table model_kinds_new (
        user_id integer not null references users (id) on delete cascade,
        kind text not null check (kind in ('chat', 'background', 'images', 'search', 'voice')),
        entry_id integer not null references provider_entries (id) on delete cascade,
        model text not null,
        thinking text not null default '',
        primary key (user_id, kind)
     ) strict, without rowid;
     insert into model_kinds_new select user_id, kind, entry_id, model, thinking from model_kinds;
     drop table model_kinds;
     alter table model_kinds_new rename to model_kinds;
     create index model_kinds_by_entry on model_kinds (entry_id);",
    // Lorebooks of the library for every chat (`everywhere_at`, when it was made
    // one, null for none) and for a persona's chats (`persona_lorebooks`); a chat
    // has them as it has those of its cards (`lorebooks::HAD`).
    "alter table lorebooks add column everywhere_at integer;
     create table persona_lorebooks (
        persona_id integer not null references personas (id) on delete cascade,
        lorebook_id integer not null references lorebooks (id) on delete cascade,
        added_at integer not null,
        primary key (persona_id, lorebook_id)
     ) strict, without rowid;
     create index persona_lorebooks_by_lorebook on persona_lorebooks (lorebook_id);",
    // Whether an answer of the kind's model carried thinking (`provider::kinds::saw_thinking`).
    "alter table model_kinds add column seen_thinking integer not null default 0 check (seen_thinking in (0, 1));",
    // A reply's statistics (`chats::messages`): whom its model was asked of, in words, and how long it took (JSON).
    "alter table messages add column provider text;
     alter table messages add column times text;",
    // Search Cardwave (`find`): what a card's characters say, its words searched in (`card_index.texts`; the
    // index is built anew at the next start), and the texts of lorebooks and their entries, personas and memories,
    // each by its owner (`search::kept::Owner`) and with its vectors once the search model read them (all can be made again).
    // An entry's row has its lorebook's name in `within`, a memory's the names of who know it in `line`.
    "alter table card_index add column texts text not null default '';
     delete from card_index;
     create table search_texts (
        id integer primary key,
        user_id integer not null references users (id) on delete cascade,
        lorebook_id integer references lorebooks (id) on delete cascade,
        card_id integer references cards (id) on delete cascade,
        persona_id integer references personas (id) on delete cascade,
        store_id integer references memory_stores (id) on delete cascade,
        chat_id integer references chats (id) on delete cascade,
        book text not null default '',
        entry text not null default '',
        title text not null,
        within text not null default '',
        keys text not null default '',
        text text not null default '',
        line text not null default '',
        model text,
        embedding blob,
        check ((lorebook_id is not null) + (card_id is not null) + (persona_id is not null) + (store_id is not null) = 1)
     ) strict;
     create index search_texts_by_user on search_texts (user_id);
     create index search_texts_by_lorebook on search_texts (lorebook_id);
     create index search_texts_by_card on search_texts (card_id);
     create index search_texts_by_persona on search_texts (persona_id);
     create index search_texts_by_store on search_texts (store_id);
     create index search_texts_by_chat on search_texts (chat_id);",
    // The name of the file a card was imported from, which its texts' imported drafts show; none for a card
    // made in the app or sent without one.
    "alter table cards add column file_name text;",
    // The SHA-256 of the file a card was imported from, by which the same file is known again; none for a
    // card made in the app or imported by an older build.
    "alter table cards add column fingerprint blob;
     create index cards_by_fingerprint on cards (user_id, fingerprint);",
    // The files of a folder of cards found to hold no card (`cards/folder.rs`), by their path, size and time
    // written (ms), so one unchanged is passed over unread.
    "create table not_cards (
        user_id integer not null references users (id) on delete cascade,
        path text not null,
        len integer not null,
        modified integer not null,
        primary key (user_id, path)
     ) strict, without rowid;",
    // The files the watched folder of cards took (`cards/folder.rs`), imported or found in the library, by
    // the same stamp, so one unchanged is passed over unread at the next start too.
    "create table watched_files (
        user_id integer not null references users (id) on delete cascade,
        path text not null,
        len integer not null,
        modified integer not null,
        primary key (user_id, path)
     ) strict, without rowid;",
    // The SHA-256 of what a card version holds (`copies`), by which an exact copy is known at import; those
    // written before are sealed at the start.
    "alter table card_versions add column content blob;
     create index card_versions_by_content on card_versions (content);",
    // How many lorebooks a card brings itself (`CardIndex::brings`), so the lorebooks list reads only
    // those cards; the index is built anew at the next start.
    "alter table card_index add column brings integer not null default 0;
     delete from card_index;",
    // Whether a chat has its title (`titled`): one with a character is named by the model after its first turns
    // too, once; a chat still called as it started (empty, or its first character's name) is still to be named.
    "alter table chats add column titled integer not null default 1 check (titled in (0, 1));
     update chats set titled = 0 where title = ''
        or title = (select name from chat_characters where chat_id = chats.id order by position limit 1);",
    // A card's needs (`needs`), a row from its queueing on; `levels` the found needs as JSON.
    "create table card_needs (
        card_id integer primary key references cards(id) on delete cascade,
        state text not null check (state in ('queued', 'asked', 'refused', 'failed')),
        version_id integer,
        levels text not null default '[]',
        reason text not null default '',
        updated_at integer not null
     ) strict;",
    // A need's rank in its card (`needs`): answers from before it are dropped, and asked anew at the next start.
    // A refusal holds no needs, and one by the describer would not be queued again, so it stays.
    "delete from card_needs where state <> 'refused';",
    // A character waiting to be read again (`needs::read_again`), or how that ended; apart from `card_needs`,
    // whose reading stands until the new one has come.
    "create table card_rereads (
        card_id integer primary key references cards(id) on delete cascade,
        state text not null check (state in ('waiting', 'read', 'failed')),
        reason text not null default ''
     ) strict;",
    // "Describe all again" (`again`) in place of reading the needs again; a summary the user wrote stays through it.
    "drop table card_rereads;
     create table card_redos (
        card_id integer primary key references cards(id) on delete cascade,
        state text not null check (state in ('waiting', 'describing', 'needs', 'read', 'failed')),
        reason text not null default '',
        stopped integer not null default 0
     ) strict;
     alter table card_descriptions add column summary_edited integer not null default 0;",
    // A poster's texts (`posters`) and the faces on a picture (`faces`), [] where it has none.
    "alter table card_descriptions add column tagline text not null default '';
     alter table card_descriptions add column mood text not null default '';
     create table picture_faces (
        blob_id integer primary key references blobs (id) on delete cascade,
        faces text not null
     ) strict;",
    // Which of its mood's poster designs a card takes and its picture's means (`posters`), given once.
    "alter table cards add column poster_letter text;
     alter table cards add column poster_means text;",
    // A coding step and a memory's search row keep their JSON in a form read strictly (`json`): the older
    // ones go (a memory's rows are written anew at the next start, `index_missing`).
    "delete from coding_tasks;
     delete from search_texts where store_id is not null;",
    // A persona is neither a favourite nor archived: the Personas page has neither (131s).
    "alter table personas drop column favorite;
     alter table personas drop column archived;",
    // A memory's search row tells the user apart from the characters who know it (131s): the older rows go,
    // written anew at the next start (`index_missing`).
    "delete from search_texts where store_id is not null;",
    // A reply cut off by the app's close says so when its chat is opened again (`chat_messages::end_unwritten`).
    "alter table messages add column broke_off integer not null default 0;",
    // Whether the provider said it no longer offers the kind's model (`provider::kinds::set_gone`).
    "alter table model_kinds add column gone integer not null default 0 check (gone in (0, 1));",
    // What the user changed of a memory's entries, held when their block is read again (`memory::changes`).
    "alter table memory_stores add column changes text not null default '';",
];

/// The `what` of the refusal of a database a newer Cardwave wrote.
pub(crate) const NEWER: &str = "newer_database";

pub(super) fn migrate(conn: &mut Connection) -> anyhow::Result<()> {
    let done = conn.pragma_query_value(None, "user_version", |r| r.get::<_, u32>(0))? as usize;
    if done > MIGRATIONS.len() {
        bail!(
            Fail::said(
                Code::NotReadable,
                format!(
                    "the database was written by a newer Cardwave (schema {done}, this build knows {})",
                    MIGRATIONS.len()
                )
            )
            .with("what", NEWER)
        );
    }
    for (i, step) in MIGRATIONS.iter().enumerate().skip(done) {
        let tx = conn.transaction()?;
        tx.execute_batch(step)
            .with_context(|| format!("schema step {} failed", i + 1))?;
        tx.pragma_update(None, "user_version", i as u32 + 1)?;
        tx.commit()?;
    }
    Ok(())
}

/// Number of schema steps this build knows.
pub fn schema_version() -> usize {
    MIGRATIONS.len()
}

#[cfg(test)]
mod tests;
