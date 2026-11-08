//! Builds the message list for one generation: the card's sections, the active
//! lorebook entries, as much chat history as fits the context, and the example
//! dialogue in what is left.
//!
//! What stays the same from reply to reply comes first, so the provider's
//! cache of the prompt's start holds (the owner): the system message, the
//! lorebook entries always given (`is_steady`), the example dialogue, the
//! history. What changes (the other lorebook entries triggered, the
//! documents' pieces, the memory note, in that order) stands just before the
//! newest message (build spec A7). The history is dropped in blocks, not
//! message by message (the owner): a block is an [`HISTORY_BLOCKS`]th of the
//! context, counted from the chat's first message, and the oldest message
//! kept is the first of its block. The example dialogue is cut to whole
//! blocks of room too, and is left out once the history no longer fits
//! whole. The memory note takes `MEMORY_ROOM` where that fits, so the history
//! does not move as it grows. The reply's room is kept first, and a part
//! that would leave none is left out; the newest message's room is kept
//! before the memory, the documents and the lorebook are added.

use crate::lorebook::{self, Activated};
use crate::macros::{self, MacroContext};
use crate::{Character, ChatState, PromptMessage, Role, Variables, tokens};

/// Share of the context kept free for the reply when no longer reply is asked for.
const REPLY_RESERVE_RATIO: f64 = 0.1;
const EXAMPLE_WRAPPER_SAFETY_MARGIN: usize = 10;
const EXAMPLE_TRUNCATION_SAFETY_RATIO: f64 = 0.95;
/// What follows example dialogue cut short.
const TRUNCATED: &str = "\n...[Example truncated for context limit]";
/// The context a memory note takes at least, in tokens (`tokens::estimate`):
/// what `memory` writes a note to fit.
pub const MEMORY_ROOM: usize = 2_000;
/// How many blocks of history the context holds (see the module's head).
const HISTORY_BLOCKS: usize = 8;

/// Everything a build needs besides the chat itself.
pub struct PromptRequest<'a> {
    /// The model's context window in tokens.
    pub context_size: usize,
    /// Tokens the reply may take, when that is more than a tenth of the context.
    pub max_response_length: Option<usize>,
    pub character: &'a Character,
    /// Text of the unlimited-NSFW section; set when the chat is in that mode.
    pub unlimited_mode: Option<&'a str>,
    /// Text of the scenario-mode section; set when the chat is in that mode.
    pub scenario_mode: Option<&'a str>,
    /// The memory note, as written, a system message of its own just before the newest message.
    pub memory_context: Option<&'a str>,
    /// Pieces of the documents of the chat and of the card, as written (no
    /// macro is expanded in them), a system message before the memory note.
    pub data_context: Option<&'a str>,
    /// Description of the tools enabled for this generation.
    pub tools_advertisement: Option<&'a str>,
    /// A one-off message placed after the chat log.
    pub injected_message: Option<(Role, &'a str)>,
    /// The model writes the user's next message, so an empty last reply stays in.
    pub is_impersonating: bool,
    pub count_tokens: &'a dyn Fn(&str) -> usize,
}

impl<'a> PromptRequest<'a> {
    /// A plain request for `character`, counting tokens with [`tokens::estimate`].
    pub fn new(character: &'a Character, context_size: usize) -> Self {
        Self {
            context_size,
            max_response_length: None,
            character,
            unlimited_mode: None,
            scenario_mode: None,
            memory_context: None,
            data_context: None,
            tools_advertisement: None,
            injected_message: None,
            is_impersonating: false,
            count_tokens: &tokens::estimate,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SegmentKind {
    Identity,
    SystemPrompt,
    NsfwMode,
    ScenarioMode,
    Description,
    Personality,
    Scenario,
    UserPersona,
    Memory,
    CardData,
    Tools,
    PostHistory,
    DepthPrompt,
    WorldInfo,
    Injected,
    ExampleDialogue,
    History,
    CurrentMessage,
}

/// One part of the prompt and what it costs, for display.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Segment {
    pub kind: SegmentKind,
    pub tokens: usize,
    pub text: String,
}

/// Where the context went, part by part.
#[derive(Clone, Debug)]
pub struct Breakdown {
    pub context_size: usize,
    pub reserved_reply: usize,
    pub segments: Vec<Segment>,
}

#[derive(Clone, Debug)]
pub struct BuiltPrompt {
    pub messages: Vec<PromptMessage>,
    pub breakdown: Breakdown,
    /// The lorebook entries in the prompt, by their key in the chat's sticky
    /// and cooldown state, in the order they stand there.
    pub lore: Vec<String>,
    /// The tokens of the system message (the character, the persona, the
    /// tools), where it did not fit and was left out.
    pub system_left_out: Option<usize>,
}

/// Builds the prompt for the next reply in `chat`. Macros may write `chat`'s and
/// the user's `globals` variables, lorebook entries start and end their timed
/// phases in `chat`, and messages get their token counts cached.
pub fn build(
    req: &PromptRequest<'_>,
    chat: &mut ChatState,
    globals: &mut Variables,
) -> BuiltPrompt {
    let reservation = (req.context_size as f64 * REPLY_RESERVE_RATIO) as usize;
    // A reply length near or past the context keeps half of it for the prompt.
    let reserved_reply = req
        .max_response_length
        .map_or(reservation, |max| max.max(reservation))
        .min(req.context_size / 2);
    let mut builder = Builder {
        req,
        chat,
        globals,
        used: reserved_reply,
        segments: Vec::new(),
        messages: Vec::new(),
        depth_insertions: Vec::new(),
        post_history: None,
        depth_prompts: Vec::new(),
        triggered: None,
        documents: None,
        memory: None,
        injected: None,
        history_cut: false,
        system_left_out: None,
    };
    builder.build_static();
    // The newest message's room, kept while what is recalled for it is added.
    let newest = builder.newest_cost();
    builder.used += newest;
    builder.build_recalled();
    let lore = builder.build_lorebook();
    builder.used -= newest;
    let history = builder.build_history();
    builder.build_examples();
    builder.assemble(history);
    BuiltPrompt {
        messages: builder.messages,
        breakdown: Breakdown {
            context_size: req.context_size,
            reserved_reply,
            segments: builder.segments,
        },
        lore,
        system_left_out: builder.system_left_out,
    }
}

struct Builder<'r, 'a> {
    req: &'r PromptRequest<'a>,
    chat: &'r mut ChatState,
    globals: &'r mut Variables,
    /// Tokens spent so far, the reply's reservation included. The one figure the
    /// budget is checked against; segment counts are for display only.
    used: usize,
    segments: Vec<Segment>,
    messages: Vec<PromptMessage>,
    /// Messages to place inside the chat log, with their depth.
    depth_insertions: Vec<(PromptMessage, usize)>,
    post_history: Option<PromptMessage>,
    depth_prompts: Vec<(PromptMessage, usize)>,
    /// The lorebook entries triggered that are not steady, the documents'
    /// pieces and the memory note: just before the newest message, after
    /// every depth insertion, in this order.
    triggered: Option<PromptMessage>,
    documents: Option<PromptMessage>,
    memory: Option<PromptMessage>,
    injected: Option<PromptMessage>,
    /// Older messages of the chat were left out of the history.
    history_cut: bool,
    system_left_out: Option<usize>,
}

/// Appends `<tag>` / content / `</tag>`, each on its own line.
fn add_section(buffer: &mut String, tag: &str, content: &str) {
    if content.is_empty() {
        return;
    }
    buffer.push_str(&format!("<{tag}>\n{content}\n</{tag}>\n"));
}

/// Whether an entry, once in the prompt, is there at every reply: one always
/// given, by no chance and without a cooldown. Such stand at the start.
fn is_steady(entry: &crate::LorebookEntry) -> bool {
    entry.constant && entry.probability >= 100 && entry.cooldown == 0
}

/// The world-info block of `entries`; none without words.
fn world_info(entries: &[String]) -> Option<PromptMessage> {
    let text = entries.join("\n\n");
    let text = text.trim();
    (!text.is_empty())
        .then(|| PromptMessage::new(Role::System, format!("<world_info>\n{text}\n</world_info>")))
}

impl Builder<'_, '_> {
    fn count(&self, text: &str) -> usize {
        (self.req.count_tokens)(text)
    }

    fn expand(&mut self, text: &str, tracking_id: &str) -> String {
        let mut ctx = MacroContext {
            char_name: self.req.character.display_name(),
            user_name: &self.chat.persona_name,
            local: Some(&mut self.chat.local_variables),
            global: Some(&mut *self.globals),
            tracking_id: Some(tracking_id),
            language: None,
        };
        macros::render(text, &mut ctx)
    }

    /// Adds a section to the system message and records its cost.
    fn add_counted(&mut self, buffer: &mut String, kind: SegmentKind, tag: &str, content: &str) {
        if content.is_empty() {
            return;
        }
        add_section(buffer, tag, content);
        let tokens = self.count(content);
        self.segments.push(Segment {
            kind,
            tokens,
            text: content.to_string(),
        });
    }

    /// Whether `tokens` more leave the reply its room.
    fn fits(&self, tokens: usize) -> bool {
        self.used + tokens <= self.req.context_size
    }

    /// Counts a message that stands outside the system message against the
    /// budget and records it, where it fits; false where it is left out.
    fn record(&mut self, kind: SegmentKind, content: &str) -> bool {
        let tokens = self.count(content);
        if !self.fits(tokens) {
            return false;
        }
        self.used += tokens;
        self.segments.push(Segment {
            kind,
            tokens,
            text: content.to_string(),
        });
        true
    }

    /// The system message, where it fits, then what stands after the chat (`build_later`).
    fn build_static(&mut self) {
        let req = self.req;
        let recorded = self.segments.len();
        let mut system = self.character_text();
        if let Some(text) = req.tools_advertisement {
            self.add_counted(&mut system, SegmentKind::Tools, "available_tools", text);
        }
        if !system.is_empty() {
            let content = self.expand(&system, "system").trim().to_string();
            let tokens = self.count(&content);
            if self.fits(tokens) {
                self.used += tokens;
                self.messages
                    .push(PromptMessage::new(Role::System, content));
            } else {
                self.segments.truncate(recorded);
                self.system_left_out = Some(tokens);
            }
        }
        self.build_later();
    }

    /// The memory note and the documents' pieces, each where it fits. Both
    /// are given as written: their `{{…}}` is no macro, and a memory is not
    /// rolled anew at each reply.
    fn build_recalled(&mut self) {
        let req = self.req;
        if let Some(text) = req.memory_context.filter(|text| !text.is_empty()) {
            let content = format!("[Memory]\n{text}");
            let tokens = self.count(&content);
            // Its whole budget where that fits, else what it takes.
            let room = [tokens.max(MEMORY_ROOM), tokens]
                .into_iter()
                .find(|room| self.fits(*room));
            if let Some(room) = room {
                self.used += room;
                self.segments.push(Segment {
                    kind: SegmentKind::Memory,
                    tokens,
                    text: text.to_string(),
                });
                self.memory = Some(PromptMessage::new(Role::System, content));
            }
        }
        if let Some(text) = req.data_context.filter(|text| !text.is_empty()) {
            let mut buffer = String::new();
            add_section(&mut buffer, "supplemental_data_context", text);
            let content = buffer.trim().to_string();
            if self.record(SegmentKind::CardData, &content) {
                self.documents = Some(PromptMessage::new(Role::System, content));
            }
        }
    }

    /// The system message's sections of the character, its modes and the
    /// user's persona, counted, as written (macros unexpanded).
    fn character_text(&mut self) -> String {
        let req = self.req;
        let card = req.character;
        let mut system = String::new();

        if !card.name.is_empty() {
            let identity = format!("You are {}.", card.name);
            self.add_counted(&mut system, SegmentKind::Identity, "identity", &identity);
        }
        self.add_counted(
            &mut system,
            SegmentKind::SystemPrompt,
            "system_prompt",
            &card.system_prompt,
        );
        if let Some(text) = req.unlimited_mode {
            self.add_counted(
                &mut system,
                SegmentKind::NsfwMode,
                "unlimited_nsfw_mode",
                text,
            );
        }
        if let Some(text) = req.scenario_mode {
            self.add_counted(
                &mut system,
                SegmentKind::ScenarioMode,
                "scenario_mode",
                text,
            );
        }
        self.add_counted(
            &mut system,
            SegmentKind::Description,
            "description",
            &card.description,
        );
        self.add_counted(
            &mut system,
            SegmentKind::Personality,
            "personality",
            &card.personality,
        );
        self.add_counted(
            &mut system,
            SegmentKind::Scenario,
            "scenario",
            &card.scenario,
        );

        let persona_name = self.chat.persona_name.trim();
        let persona_description = self.chat.persona_description.trim();
        if !persona_name.is_empty() || !persona_description.is_empty() {
            let persona = if persona_description.is_empty() {
                format!("Name: {persona_name}")
            } else {
                format!("Name: {persona_name}\n{persona_description}")
            };
            self.add_counted(
                &mut system,
                SegmentKind::UserPersona,
                "user_persona",
                &persona,
            );
        }

        system
    }

    /// What stands after the chat: the post-history instructions, the notes
    /// at a depth and the injected message.
    fn build_later(&mut self) {
        let req = self.req;
        let card = req.character;
        if !card.post_history_instructions.is_empty() {
            let mut buffer = String::new();
            add_section(
                &mut buffer,
                "post_history_instructions",
                &card.post_history_instructions,
            );
            let content = self.expand(buffer.trim(), "postHistory");
            if self.record(SegmentKind::PostHistory, &content) {
                self.post_history = Some(PromptMessage::new(Role::System, content));
            }
        }

        for (i, depth_prompt) in card.depth_prompts.iter().enumerate() {
            if depth_prompt.prompt.is_empty() {
                continue;
            }
            let tracking_id = if i == 0 {
                "depthPrompt".to_string()
            } else {
                format!("depthPrompt_{i}")
            };
            let mut content = self.expand(&depth_prompt.prompt, &tracking_id);
            if depth_prompt.role == Role::System {
                let mut buffer = String::new();
                add_section(&mut buffer, "depth_prompt", &content);
                content = buffer.trim().to_string();
            }
            if self.record(SegmentKind::DepthPrompt, &content) {
                self.depth_prompts.push((
                    PromptMessage::new(depth_prompt.role, content),
                    depth_prompt.depth,
                ));
            }
        }

        if let Some((role, text)) = req.injected_message {
            let content = self.expand(text, "injected");
            if self.record(SegmentKind::Injected, &content) {
                self.injected = Some(PromptMessage::new(role, content));
            }
        }
    }

    /// Adds the lorebook entries that apply and fit. Returns their keys.
    fn build_lorebook(&mut self) -> Vec<String> {
        let card = self.req.character;
        let candidates = lorebook::evaluate(card, self.chat);
        let budget = card.lorebook.as_ref().map_or(0, |book| book.token_budget);
        let mut budget_used = 0;
        let mut accepted: Vec<(Activated<'_>, String)> = Vec::new();
        let mut world_info_tokens = 0;
        let mut world_info_text = Vec::new();

        // Candidates come in budget order; one that does not fit is skipped and
        // the smaller ones after it still get their chance.
        for candidate in candidates {
            let content = self.expand(&candidate.content, &format!("lorebook_{}", candidate.uid));
            let cost = self.count(&content);
            if !self.fits(cost) {
                continue;
            }
            let ignore_budget = candidate.entry.ignore_budget;
            if !ignore_budget && budget > 0 && budget_used + cost > budget {
                continue;
            }
            self.used += cost;
            world_info_tokens += cost;
            world_info_text.push(content.clone());
            if !ignore_budget {
                budget_used += cost;
            }
            accepted.push((candidate, content));
        }

        lorebook::commit_timed_effects(self.chat, accepted.iter().map(|(candidate, _)| candidate));
        accepted.sort_by_key(|(candidate, _)| candidate.entry.insertion_order);
        let lore = accepted
            .iter()
            .map(|(candidate, _)| candidate.uid.clone())
            .collect();

        // Entries either join a world-info block, the steady ones' at the start
        // or the others' before the newest message, or go into the chat log at
        // a depth, where those sharing depth and role become one message.
        let (mut steady, mut triggered) = (Vec::new(), Vec::new());
        let mut at_depth: Vec<(usize, Role, String)> = Vec::new();
        for (candidate, content) in accepted {
            let entry = candidate.entry;
            if !entry.at_depth && candidate.depth_override.is_none() {
                if is_steady(entry) {
                    steady.push(content);
                } else {
                    triggered.push(content);
                }
                continue;
            }
            let depth = candidate.depth_override.unwrap_or(entry.depth);
            let role = candidate.role_override.unwrap_or(entry.role);
            match at_depth
                .iter_mut()
                .find(|(d, r, _)| *d == depth && *r == role)
            {
                Some((_, _, existing)) => {
                    existing.push_str("\n\n");
                    existing.push_str(&content);
                }
                None => at_depth.push((depth, role, content)),
            }
        }

        self.messages.extend(world_info(&steady));
        self.triggered = world_info(&triggered);
        for (depth, role, content) in at_depth {
            self.depth_insertions
                .push((PromptMessage::new(role, content), depth));
        }
        if world_info_tokens > 0 {
            self.segments.push(Segment {
                kind: SegmentKind::WorldInfo,
                tokens: world_info_tokens,
                text: world_info_text.join("\n\n").trim().to_string(),
            });
        }
        lore
    }

    /// Tokens in a block of history.
    fn block(&self) -> usize {
        (self.req.context_size / HISTORY_BLOCKS).max(1)
    }

    /// The first message to keep where those from `first` on fit: the first
    /// message of a block at or after `first`, by the tokens of the chat
    /// before it, unless that would leave out the newest user message (at
    /// `newest`), when `first` is kept.
    fn block_start(&self, first: usize, newest: usize) -> usize {
        let block = self.block();
        let mut before = 0;
        let mut previous = None;
        for (i, message) in self.chat.messages.iter().enumerate().take(newest + 1) {
            let here = before / block;
            if i >= first && previous != Some(here) {
                return i;
            }
            previous = Some(here);
            before += message
                .token_count
                .unwrap_or_else(|| (self.req.count_tokens)(&message.content));
        }
        first
    }

    /// Whether the chat's `i`th message is sent: a complete one, but the empty
    /// reply about to be generated.
    fn is_sent(&self, i: usize) -> bool {
        let message = &self.chat.messages[i];
        message.complete
            && (self.req.is_impersonating
                || i + 1 != self.chat.messages.len()
                || !message.content.is_empty()
                || message.role != Role::Assistant)
    }

    /// What the newest message sent costs, by its words as written.
    fn newest_cost(&self) -> usize {
        (0..self.chat.messages.len())
            .rev()
            .find(|i| self.is_sent(*i))
            .map_or(0, |i| {
                let message = &self.chat.messages[i];
                message
                    .token_count
                    .unwrap_or_else(|| self.count(&message.content))
                    + message.pictures.len() * crate::PICTURE_TOKENS
            })
    }

    /// Takes chat messages from the newest back until the context is full,
    /// then leaves out those before the first message of a block. Returns
    /// them newest first.
    fn build_history(&mut self) -> Vec<PromptMessage> {
        let mut history = Vec::new();
        let total = self.chat.messages.len();
        let latest_user = self
            .chat
            .messages
            .iter()
            .rposition(|m| m.role == Role::User);
        let mut current: Option<(usize, String)> = None;
        // Each message taken: where it stands in the chat, its tokens and text.
        let mut taken: Vec<(usize, usize, String)> = Vec::new();
        let mut full = None;

        for i in (0..total).rev() {
            if !self.is_sent(i) {
                continue;
            }
            let message = &self.chat.messages[i];
            let role = message.role;
            let cached = message.token_count.unwrap_or(0);
            let tracking_id = format!("history_{}", message.id);
            let raw = message.content.clone();
            let pictures = message.pictures.clone();
            let content = self.expand(&raw, &tracking_id);

            let mut tokens = cached;
            if tokens == 0 && !content.is_empty() {
                tokens = self.count(&content);
                self.chat.messages[i].token_count = Some(tokens);
            }
            // A message's count is of its words; its pictures cost the context besides.
            tokens += pictures.len() * crate::PICTURE_TOKENS;
            if !self.fits(tokens) {
                full = Some(i);
                break;
            }
            self.used += tokens;
            history.push(PromptMessage {
                pictures,
                ..PromptMessage::new(role, content.clone())
            });
            taken.push((i, tokens, content));
        }
        if let Some(full) = full {
            self.history_cut = true;
            let newest = taken.first().map_or(full, |(i, ..)| *i);
            let keep = latest_user.filter(|&at| at > full).unwrap_or(newest);
            let start = self.block_start(full + 1, keep);
            while taken.last().is_some_and(|(i, ..)| *i < start) {
                if let Some((_, tokens, _)) = taken.pop() {
                    self.used -= tokens;
                    history.pop();
                }
            }
        }
        let mut history_tokens = 0;
        let mut history_text: Vec<String> = Vec::new();
        for (i, tokens, content) in taken {
            if Some(i) == latest_user {
                current = Some((tokens, content));
            } else {
                history_tokens += tokens;
                history_text.push(content);
            }
        }

        if let Some((tokens, text)) = current
            && tokens > 0
        {
            self.segments.push(Segment {
                kind: SegmentKind::CurrentMessage,
                tokens,
                text,
            });
        }
        if history_tokens > 0 {
            // Collected newest first; shown oldest first, like the chat.
            history_text.reverse();
            self.segments.push(Segment {
                kind: SegmentKind::History,
                tokens: history_tokens,
                text: history_text.join("\n\n"),
            });
        }
        history
    }

    /// Adds the card's example dialogue after the system message and the
    /// steady lorebook entries if room is left, cut short when it only fits in part.
    fn build_examples(&mut self) {
        let card = self.req.character;
        if card.mes_example.is_empty() || self.history_cut {
            return;
        }
        let mut example = self.expand(&card.mes_example, "mesExample");
        let wrapper_cost = self.count("<example_dialogue>\n\n</example_dialogue>");
        let available = self.req.context_size.saturating_sub(self.used);
        if available <= wrapper_cost + EXAMPLE_WRAPPER_SAFETY_MARGIN {
            return;
        }
        let mut content_budget = available - wrapper_cost;
        let example_tokens = self.count(&example);
        if example_tokens > content_budget {
            // Whole blocks of room beside the note that it is cut, so a
            // growing chat cuts the examples anew only now and then.
            let block = self.block();
            content_budget = content_budget.saturating_sub(self.count(TRUNCATED)) / block * block;
            let ratio = content_budget as f64 / example_tokens as f64;
            let chars = example.chars().count() as f64;
            let keep = (chars * ratio * EXAMPLE_TRUNCATION_SAFETY_RATIO).floor() as usize;
            if keep == 0 {
                return;
            }
            let kept: String = example.chars().take(keep).collect();
            example = format!("{kept}{TRUNCATED}");
        }
        if example.is_empty() {
            return;
        }
        let mut buffer = String::new();
        add_section(&mut buffer, "example_dialogue", &example);
        let content = buffer.trim().to_string();
        if self.record(SegmentKind::ExampleDialogue, &content) {
            self.messages
                .push(PromptMessage::new(Role::System, content));
        }
    }

    fn assemble(&mut self, history: Vec<PromptMessage>) {
        // Where the chat log starts and ends in the final list. Depth insertions
        // go inside that span and nowhere else, as in SillyTavern: the system
        // blocks above the log and the injected and post-history messages below
        // it are never counted as positions.
        let log_start = self.messages.len();
        self.messages.extend(history.into_iter().rev());
        let log_end = self.messages.len();

        self.messages.extend(self.injected.take());
        self.messages.extend(self.post_history.take());

        let mut insertions = std::mem::take(&mut self.depth_insertions);
        insertions.append(&mut self.depth_prompts);
        insertions.sort_by_key(|(_, depth)| std::cmp::Reverse(*depth));
        // What is recalled for the reply, nearest of all before the newest
        // message, the memory note last.
        let recalled = [
            self.triggered.take(),
            self.documents.take(),
            self.memory.take(),
        ];
        let at = insertions
            .iter()
            .position(|(_, depth)| *depth < 1)
            .unwrap_or(insertions.len());
        insertions.splice(at..at, recalled.into_iter().flatten().map(|m| (m, 1)));

        // Depth counts chat messages back from the newest: 0 lands right after
        // the newest message, 1 before it, and a depth at or past the log's
        // length before its oldest message. Deepest first, with the log's end
        // moving along, so several insertions stack as they do in SillyTavern.
        for (added, (message, depth)) in insertions.into_iter().enumerate() {
            let end = log_end + added;
            let index = end.saturating_sub(depth).clamp(log_start, end);
            self.messages.insert(index, message);
        }
    }
}
