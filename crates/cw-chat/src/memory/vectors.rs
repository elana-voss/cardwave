//! A memory's vectors by the search model: those its newest state's texts
//! lack (`unembedded`), keeping them (`keep_vectors`) and reading them for a
//! reply (`kept_vectors`). A text's vector is of the text as kept, the user
//! without a persona as the mark (`USER_MARK`).

use super::{Storage, ToRender, USER_MARK, Vectors, system, word_renamed};

/// The stamp of `user`'s search model, and the texts of the memory `store`'s
/// newest state without a vector kept of that model.
pub fn unembedded(
    db: &dyn Storage,
    user: i64,
    store: i64,
) -> anyhow::Result<(String, Vec<String>)> {
    let stamp = db.search_stamp(user)?;
    let (_, missing) = texts_of(db, store, &stamp)?;
    Ok((stamp, missing))
}

/// The texts of the memory `store`'s newest state, and those of them without
/// a vector kept of the model of `stamp`.
fn texts_of(
    db: &dyn Storage,
    store: i64,
    stamp: &str,
) -> anyhow::Result<(Vec<String>, Vec<String>)> {
    let Some(last) = db.memory_blocks(store)?.last().map(|b| b.id) else {
        return Ok((Vec::new(), Vec::new()));
    };
    let texts = system().texts(&db.memory_state(last)?)?;
    let kept = db.memory_vectors(store)?;
    let missing = texts
        .iter()
        .filter(|text| !kept.contains_key(&cw_search::text_hash(stamp, text)))
        .cloned()
        .collect();
    Ok((texts, missing))
}

/// Keeps the vectors `new` of the memory `store`, by text hash, and lets go of
/// those its newest state, read now, has no text of: a pass that read an older
/// state never lets go of the vector of a text a later block set.
pub fn keep_vectors(
    db: &dyn Storage,
    store: i64,
    stamp: &str,
    new: &[(Vec<u8>, Vec<u8>)],
) -> anyhow::Result<()> {
    let (texts, _) = texts_of(db, store, stamp)?;
    let keep: Vec<Vec<u8>> = texts
        .iter()
        .map(|t| cw_search::text_hash(stamp, t))
        .collect();
    db.keep_memory_vectors(store, new, &keep)
}

/// The stamp of `user`'s search model, and the kept vectors of that model of
/// the texts of what a reply renders, by text; none where one is missing.
pub fn kept_vectors(
    db: &dyn Storage,
    user: i64,
    to_render: &ToRender,
) -> anyhow::Result<(String, Option<Vectors>)> {
    let stamp = db.search_stamp(user)?;
    let kept = db.memory_vectors(to_render.store)?;
    let vectors: Option<Vectors> = system()
        .texts(&to_render.state)?
        .into_iter()
        .map(|text| {
            // Its vector was made of the text as kept (`texts_of`).
            let as_kept = word_renamed(&text, to_render.stand_in, USER_MARK);
            let bytes = kept.get(&cw_search::text_hash(&stamp, &as_kept))?;
            let vector = bytes
                .as_chunks::<4>()
                .0
                .iter()
                .map(|b| f32::from_le_bytes(*b))
                .collect();
            Some((text, vector))
        })
        .collect();
    Ok((stamp, vectors))
}
