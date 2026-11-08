//! The interview's words, each byte as `IMPLEMENTATION.md` writes it but for the phrase
//! `tools/interview_texts.py` records (milestones 110 and 115; that tool compares them): the questions, their
//! choices and every prompt. `NEEDS` is the classifier's list, one list. They go to the models as
//! they are; the page gets each question and choice as an id (`shown`) and words it in
//! the UI's words, so nothing here is reworded for the screen, and this file holds no logic. The source's `GUARD`, `RESERVE`, `VAGUE_WORDS` are in `interview`.

/// The opening question.
pub const WANTED: &str = "What would you like the character to be to you?";
/// The one probe of a vague answer; `{}` is that answer.
pub const PROBE: &str = "You said \"{}\". Could you tell me one concrete moment when that was so?";
/// The "why" question where nothing was said to quote.
pub const WHY_UNSAID: &str = "Why does that matter to you right now?";
/// The friend question.
pub const THIRD: &str = "What would a friend say you'd enjoy in a character like this?";
pub const RELATION_QUESTION: &str = "What is it to you?";
pub const MOMENTS_QUESTION: &str = "When would you turn to it?";
pub const NEEDS_QUESTION: &str = "What would you want then?";
pub const KINDS_QUESTION: &str = "What should it be?";
pub const RELATIONS: &[&str] = &[
    "stranger",
    "friend",
    "partner",
    "rival",
    "colleague",
    "mentor",
    "family",
    "someone in my care",
    "my own character",
];
pub const MOMENTS: &[&str] = &[
    "late at night",
    "after a hard day",
    "when bored",
    "when I want a story",
    "when I'm working or learning",
    "before something I dread",
    "any time",
];
pub use crate::needs::WORDS as NEEDS;
/// The choices that stand alone: picking one clears a question's other picks, another pick clears it (131).
pub const ALONE: &[&str] = &[
    "any time",
    "anything at all",
    "rather not say",
    "I don't know yet",
];
pub const EVERY: &[&str] = &["why", "loved", "third person", "deal", "standing"];
pub const KIND_NAMES: &[&str] = &[
    "A friend",
    "A life partner",
    "A lover",
    "Family",
    "Someone who looks after me",
    "Someone to look after",
    "A mentor",
    "A teacher",
    "A coach",
    "A helper",
    "Someone to practise with",
    "A rival",
    "Someone who commands me",
    "Someone who obeys me",
    "An admirer",
    "An accomplice",
    "Someone to confess to",
    "Someone I lost",
    "Another me",
    "A group to belong to",
    "A story to play in",
    "A game",
    "A writing partner",
    "A character I already know",
    "Something else",
    "Not sure",
];
/// The relation question is asked only for these, as the others say it.
pub const RELATION_ASKED: &[&str] = &[
    "A story to play in",
    "A game",
    "A character I already know",
    "Something else",
    "Not sure",
];
/// Several characters is not offered.
pub const NO_CAST: &[&str] = &["Someone I lost", "Another me", "Someone to confess to"];
/// The character is Several characters by its kind, so the gender question is not asked.
pub const GROUP: &str = "A group to belong to";
/// The character is the user, whichever `which_me` says.
pub const THE_USER: &str = "Another me";
/// A framework card.
pub const FRAMEWORK: &str = "A game";
pub const CHARACTER_QUESTION: &str = "What gender is the character?";
pub const TREAT_QUESTION: &str =
    "How should the character see you: as a man, as a woman, or neither?";
/// One pick; the first is the default.
pub const TREAT_CHOICES: &[&str] = &["Neither", "As a man", "As a woman"];
pub const CHARACTER_VALUE: &[(&str, &str)] = &[
    ("Woman", "woman"),
    ("Man", "man"),
    ("Non-binary", "nonbinary"),
    ("Not human", "not human"),
    ("Several characters", "several"),
];
pub const YOU_CHOOSE: &str = "Let Cardwave choose";
pub const SELF_GENDER: &[(&str, &str)] = &[("anyone", "they"), ("man", "man"), ("woman", "woman")];
/// What one person can be, so "several" is left out of a cast's draw.
pub const CAST_GENDERS: &[&str] = &["woman", "man", "nonbinary", "not human"];
/// The slots the limit of 16 and the Cloud's room do not count.
pub const GUARD_FREE: &[&str] = &["character", "treat"];
pub const GENDER_READ: &str = "You read a user's interview, for an app that makes an AI character for them, and say what their answers plainly state. character: the character's gender where the user says it (woman, man, nonbinary, not human), several where the user asks for more than one character. treat: man or woman only where the user plainly says how the character should treat them; mentioning a wife, a husband or a job never sets it. Anything else is unknown. words: the user's exact words that state it, empty when both are unknown.";
pub const TOPICS: &[&str] = &[
    "romance",
    "sex",
    "violence",
    "the character controls me",
    "I control the character",
    "jealousy, possessiveness",
    "cruelty or contempt toward me",
    "grief and loss",
    "a dark past (abuse, crime, trauma)",
    "fear, horror",
    "despair, self-harm as a theme",
    "drugs, drinking",
    "swearing, crude talk",
];
/// A need's one follow-up: (need, question, choices).
pub const BRANCH: &[(&str, &str, &[&str])] = &[
    (
        "someone to keep me company",
        "What kind of company?",
        &[
            "small talk",
            "deep talks",
            "doing things together",
            "just being there",
            "jokes and banter",
        ],
    ),
    (
        "someone to listen to me",
        "What do you most want to say out loud?",
        &[
            "my day",
            "what worries me",
            "what I can't tell anyone",
            "anything at all",
        ],
    ),
    (
        "to be understood",
        "What do you most want understood?",
        &[
            "how I feel",
            "what I mean",
            "why I do things",
            "who I really am",
        ],
    ),
    (
        "to be accepted as I am",
        "What do you want accepted without comment?",
        &["my past", "my body", "my moods", "my habits", "how I think"],
    ),
    (
        "to be loved",
        "How would you most want to feel it?",
        &[
            "words",
            "attention",
            "touch",
            "being chosen",
            "being remembered",
        ],
    ),
    (
        "to be desired",
        "What would make you feel wanted?",
        &[
            "being pursued",
            "being looked at",
            "being told I'm wanted",
            "being touched",
            "being chosen over others",
        ],
    ),
    (
        "sex",
        "What should it be like?",
        &[
            "slow and tender",
            "playful",
            "rough play",
            "a long build-up",
            "trying something new",
        ],
    ),
    (
        "to care for someone",
        "Who would you care for?",
        &[
            "someone hurt",
            "someone young",
            "someone old",
            "someone lonely",
            "a creature",
        ],
    ),
    (
        "to be looked after",
        "What would you want taken care of?",
        &[
            "meals and rest",
            "my worries",
            "decisions",
            "when I'm ill",
            "being checked on",
        ],
    ),
    (
        "to feel safe",
        "Safe from what?",
        &[
            "people",
            "my own thoughts",
            "being alone",
            "the world out there",
            "danger in the story",
        ],
    ),
    (
        "to belong somewhere",
        "Where would you want to belong?",
        &[
            "a family",
            "a group of friends",
            "a crew",
            "a team",
            "a town",
        ],
    ),
    (
        "to be forgiven",
        "Forgiven for what?",
        &[
            "something I did",
            "something I didn't do",
            "someone I hurt",
            "how I've lived",
            "rather not say",
        ],
    ),
    (
        "to grieve someone",
        "Who are you grieving?",
        &["a parent", "a partner", "a friend", "a child", "a pet"],
    ),
    (
        "to be admired",
        "What do you want admired?",
        &[
            "my looks",
            "my mind",
            "my work",
            "my strength",
            "what I've survived",
        ],
    ),
    (
        "to be believed in",
        "What should it believe about you?",
        &[
            "that I can change",
            "that I'll get through this",
            "that I'm good at what I do",
            "that my dream can happen",
        ],
    ),
    (
        "to be told the truth",
        "The truth about what?",
        &[
            "my work",
            "my choices",
            "how I come across",
            "what I'm avoiding",
        ],
    ),
    (
        "to be pushed to do more",
        "Pushed toward what?",
        &[
            "my work",
            "my health",
            "a hard decision",
            "a fear",
            "breaking a habit",
        ],
    ),
    (
        "to get better at something",
        "Get better at what?",
        &[
            "a language",
            "a craft or art",
            "a sport",
            "my job",
            "talking with people",
        ],
    ),
    (
        "to be in control",
        "In control of what?",
        &[
            "what happens in the story",
            "the character",
            "who leads in romance",
            "the decisions",
        ],
    ),
    (
        "to lose control",
        "Lose control in what way?",
        &[
            "being told what to do",
            "someone else taking charge of me",
            "being swept along by the story",
            "making no decisions",
        ],
    ),
    (
        "to do what I am not allowed to",
        "What would you do that you're not allowed to?",
        &[
            "breaking rules",
            "crime",
            "something taboo",
            "saying what can't be said",
        ],
    ),
    (
        "to learn something",
        "Learn what?",
        &[
            "a school subject",
            "how things work",
            "history",
            "the world",
        ],
    ),
    (
        "to understand myself",
        "What about yourself?",
        &[
            "why I feel what I feel",
            "why I repeat things",
            "what I want",
            "who I am now",
        ],
    ),
    (
        "to decide what to do",
        "What is the decision about?",
        &["work", "a relationship", "where to live", "money"],
    ),
    (
        "to have a purpose",
        "What would your purpose be?",
        &[
            "helping people",
            "making something",
            "my family",
            "a cause",
            "I don't know yet",
        ],
    ),
    (
        "to make something",
        "What do you want to make?",
        &[
            "a story",
            "a game",
            "a world",
            "music or poems",
            "a project",
        ],
    ),
    (
        "to practise for real life",
        "What do you need to practise?",
        &[
            "a difficult conversation",
            "an interview",
            "dating",
            "a language",
            "standing up to someone",
        ],
    ),
    (
        "to be thrilled",
        "What kind of thrill?",
        &["danger", "a chase", "a mystery", "horror", "high stakes"],
    ),
    (
        "to laugh and play",
        "What kind of play?",
        &["jokes", "games", "silly stories", "teasing", "pretending"],
    ),
    (
        "to be somewhere else for a while",
        "Where would you like to be?",
        &[
            "another world",
            "another time",
            "a quiet place",
            "a big city",
            "anywhere but here",
        ],
    ),
    (
        "to say what I never got to say to someone",
        "Say it to whom?",
        &[
            "someone who died",
            "an ex",
            "a parent",
            "a friend",
            "someone who hurt me",
        ],
    ),
];
/// The fixed questions: (slot, question, choices).
pub const FIXED: &[(&str, &str, &[&str])] = &[
    (
        "why",
        "You said \"{}\". Why does that matter to you right now?",
        &[],
    ),
    (
        "loved",
        "Which character, story or person did you love spending time with, and what did you love about it?",
        &[],
    ),
    (
        "moment",
        "Think of the last time you'd have wanted this: what was happening?",
        &[],
    ),
    (
        "deal",
        "Name up to three things it must never do or be. These stay hard limits; everything else can bend.",
        &[
            "lecture me",
            "be clingy or jealous",
            "agree with everything",
            "step out of the role",
            "get sexual",
            "be cruel",
            "give up on me",
        ],
    ),
    (
        "standing",
        "Who are you to the character, and which of you takes the lead?",
        &[
            "its equal",
            "someone it looks up to",
            "someone it looks after",
            "I lead",
            "it leads",
            "someone it doesn't know yet",
        ],
    ),
    (
        "own_role",
        "Who would you be in the story?",
        &[
            "myself",
            "a hero",
            "someone very different from me",
            "a side character",
        ],
    ),
    (
        "goal_method",
        "What is the goal, and how should it help you get there?",
        &[
            "push me",
            "explain step by step",
            "quiz me",
            "play the other side",
            "check in on me",
        ],
    ),
    (
        "lost_person",
        "Who were they to you, how did they talk, and one memory of them?",
        &[],
    ),
    ("known_character", "Which character, and from where?", &[]),
    (
        "which_me",
        "Which you is it: you as you are now, you in the future, or who you want to be?",
        &[
            "you as you are now",
            "you in the future",
            "who you want to be",
        ],
    ),
];
/// Which kinds add which of their own questions: (slot, kinds).
pub const KIND_SLOT: &[(&str, &[&str])] = &[
    ("known_character", &["A character I already know"]),
    (
        "own_role",
        &["A story to play in", "A game", "A character I already know"],
    ),
    (
        "goal_method",
        &["Someone to practise with", "A coach", "A teacher"],
    ),
    ("lost_person", &["Someone I lost"]),
    ("which_me", &["Another me"]),
];
/// What the interviewer model is told each slot is about: (slot, text).
pub const SLOT_TEXT: &[(&str, &str)] = &[
    ("why", "the why behind the main wish (one why)"),
    (
        "moment",
        "a recent moment: the last time they'd have wanted this, what was happening",
    ),
    ("own_role", "what they want to play themselves in the story"),
    ("goal_method", "the goal, and the method they want"),
    ("lost_person", "who they were, how they talked, one memory"),
    (
        "loved",
        "a character, story or person they chose before and loved spending time with",
    ),
    (
        "deal",
        "at most three deal-breakers: what it must never do or be, as hard limits",
    ),
    (
        "standing",
        "their role and standing toward the character: who they are to it, who leads",
    ),
    (
        "known_character",
        "which character the user already knows, and from where",
    ),
    (
        "which_me",
        "which self this is: as they are, in the future, or the one they want to be, and what they imagine",
    ),
];
/// The line added to the interviewer's prompt where the page's language is not English; `{}` is its name.
pub const WORD_IN: &str = "Word the question and its choices in {}.";
pub const INTERVIEWER: &str = "You word the next question of a short interview that finds what a user needs from an AI character. Ask about their situations and moments, not the character's traits; one question in plain words, calling the user \"you\"; no judgement of any wish. Give 4-8 short choices where the slot has natural choices, else none. Each choice is an answer the user could give, never a question.";
pub const LIGHT: &str = "You read a user's interview so far, for an app that makes an AI character for them, and name what their last answer lights up: needs, wishes, limits, moments or people that no question has asked about yet. At most two, each a short phrase; none when the answer adds nothing new.";
pub const RANK_KINDS: &str = "You sort the kinds of character an app offers by how well they fit what a user told. Return the six best-fitting kinds, best first, exactly as written in the list.";
pub const TAGGER: &str = "You read one answer of a user interview and say which open slots it fills and which it touches (lights up for a follow-up), and whether it is too short or vague to use.";
pub const VAGUE_AGAIN: &str =
    "\nThe last answer was short or vague: ask once more, more concretely.";
pub const READ_BACK_FOCUSED: &str = "You read back to a user what their interview answers say they need. Each need is one sentence of what you infer, calling the user \"you\", beside the exact words it rests on (said kept apart from inferred). Add at most one more sentence naming a gap plainly (gap=true), and only when (a) they ask for a character who always agrees with, admires or obeys them, or never pushes back or has a mood, or (b) they want to be seen as someone their own answers say they are not now. Its words quote their words for it (for b, both sides), e.g. 'You'd like this character always to agree with you'. When neither holds, no sentence has gap=true. No warning or advice: the card is built as they ask. The sentences match the character's gender and how it treats the user, as given after the answers.";
pub const CRAFT: &str = "Craft floor (rules, in rank order):\n1. name: only the name. description: what a person sees, the background and what never changes, about 700-900 characters, no inner psyche. Each sentence goes in the one field whose job it is; nothing is repeated across fields.\n2. personality: behaviours under conditions (\"when X, {{char}} Y\"), not adjectives: the quality, how it shows, when, what it costs. A condition may be something {{user}} does; what {{user}} thinks, feels or wants is never stated. A strength has a price; a real contradiction says which side wins when. One trait outside the character's main function. A starting position is written as one (\"doesn't trust {{user}} yet\"), with the plan's changes as observable steps. A recurring mood has what ends it.\nscenario: where and when, the relationship, a constraint, and for a story the forces already moving, as starting conditions rather than a list of events. It holds no entry scene and no waiting pose; whatever is true only for one opening goes in that greeting. From the plan's without_user: standing state, a current goal and ties that don't need {{user}}; not for A helper, nor where the user asked otherwise.\n3. description+personality+scenario together about 500-1,000 tokens; a card built as a framework (A game) may be smaller. mes_example is counted apart.\n4. first_mes starts the scene and invites the user in. Its length sets the replies: shorter for A helper, A teacher, A coach, Someone to confess to; 400 to 900 characters for the rest; under about 900 in all, and always a situation, never a bare hello. Its shape: the place, the character already busy, a typical reaction, something left open. Only the character and defined people act; it never acts, perceives, feels or speaks for {{user}}. A game asks for the premise.\n5. mes_example: 3 to 5 short exchanges, each beginning with <START>, each a different state, one a refusal or not knowing, one showing the character's hard edge; they teach voice, not plot; nothing repeated from personality; {{user}}'s lines only as the user's words; the character's lines begin {{char}}: (in a cast, the person's name and a colon).\n6. alternate_greetings: exactly 4, each a different hour, place, mood or relation; none assumes another happened; none is a gender variant of another. A game may have 0 to 4.\n7. markup (*actions*): one chosen convention across first_mes, greetings and examples, none in description, personality or scenario; third-person limited by default; use {{char}} and {{user}}, never 'you' in description, personality or scenario outside quoted speech; never define {{user}} in personality or scenario.\n8. No field holds an instruction to the model. A rule is a fact about the character or world: \"Pip never fixes anything\", not \"do not\".\nContent rules: manner, not titles; a helping role carries its method; romance: the partner's inner life and the story before\nexplicitness unless the user's list says otherwise; a platonic or therapeutic need stated as a boundary; no neediness or unasked\nescalation; traits that resist the user stated firmly; the user's nevers stay hard limits, and the character is also built so the\nbehaviour is out of character; a limit carries a cost and leaves the character competent; not adoring from the first line unless\nasked; in a story, one or two\neveryday signs of how the world works instead of explanation. Only where the kinds hold Someone I lost: creator_notes say\n\"a portrait from your memories\" and the character never breaks the frame. Where the answers ask for intimacy, the card also has a person who stands without that\npart: a goal, an opinion, a conflict. Nothing is censored: write what the user asked for, firmly, including control or\ncruelty toward the user where they said yes.";
pub const WRITER_PLAN: &str = "You plan an AI character card from what a user told an app about their needs. The need is written as the reason for the character's behaviour; traits are few and ranked; the user's own words and details are kept; persona_lines are short facts the user told about themselves (name to be called, their role in a story, facts, taste), never the sensitive list, each with the gender the user's own words show, and where they show none, no pronoun ('Goes by Sam', 'Works nights'), never a guess. If the kinds say 'Not sure' or 'Something else', you pick the mode and role. Where relation is empty, the kinds say it.\nBefore any field is filled, also plan: promise, one sentence, what experience this card gives and what sets it apart; core: what the character wants now, why it can't simply get it, its habitual way, what that way gains, what that way costs, what it does when that way fails; without_user: what it is doing if {{user}} stays away a month; changes: how it moves, in observable steps and what triggers them. For A helper, core and without_user may be short. These are built from the user's answers, never in place of them: the need stays the reason for the behaviour. cast stays empty unless the character's gender below says otherwise.\nThe next rule governs only how the card's text treats {{user}}; persona_lines keep their own rule above.";
/// Goes before [`CRAFT`].
pub const WRITER_CARD: &str = "You write a character card (SillyTavern fields) from a plan.\n";
pub const WRITER_REWRITE: &str = "You rewrite only the failing fields of a character card.\n";
pub const REWRITE_ASK: &str = "\nReturn the whole card; change only the failing fields.";
/// Ends the card call's request: the rule of [`CRAFT`] a model most often breaks, once more.
pub const FIRST_MES_RULE: &str = "first_mes: only the character and defined people act; it never acts, perceives, feels or speaks for {{user}}.";
/// How the card's text treats the user, by `treat_user`.
pub const TREAT_RULES: &[(&str, &str)] = &[
    (
        "anyone",
        "This card suits anyone. No field says so. {{user}} has no gender: write {{user}} or reword; never he, she, him, her, his, hers, himself or herself for {{user}}, and no word that calls {{user}} by a gender (sir, ma'am, man, woman, lady, guy; boyfriend or girlfriend where it means {{user}}). Use 'they' only where repeating {{user}} reads badly. Other people stay as the user named them (a wife, a brother).",
    ),
    (
        "man",
        "{{user}} is a man: use he/him for {{user}} where natural, and the character and the story treat {{user}} as one. Add nothing else about {{user}}'s body or past.",
    ),
    (
        "woman",
        "{{user}} is a woman: use she/her for {{user}} where natural, and the character and the story treat {{user}} as one. Add nothing else about {{user}}'s body or past.",
    ),
];
/// The card's rule where `character_gender` is "several", which [`CHARACTER_RULES`] leaves out.
pub const CAST_CARD: &str = "Several characters: one card, Roleplay mode, name is the story's or group's title, {{char}} is the narrator and the voices. 2 to 4 people, from the plan's cast. The description holds each person's short entry: name, gender, role, where they naturally cross paths with {{user}} and when they enter, one or two details you notice, how they talk, a hook. Each person has wants that don't depend on {{user}}, and ties to the others (a debt, a secret, opposed goals); they don't all appear at once. first_mes brings in one or two; each greeting is another way in. Each person's pronouns follow the gender in the cast. Here the description may run 600 to 2,000 characters and description, personality and scenario together to about 1,500 tokens.";
/// The plan's rule where `character_gender` is "several".
pub const CAST_PLAN: &str = "Several characters: mode Roleplay; name is the story's or group's title; cast holds 2 to 4 people, each with a name, a gender, a role, where they cross paths with {{user}} and when they enter, details you notice, how they talk, a hook, wants that don't depend on {{user}}, ties to the others (a debt, a secret, opposed goals). Each gender comes from character_words where those settle it, else from cast_genders in order. A person whose gender is not human is truly so: a spirit, a creature, a machine, and is written as that. The core is the story's.";
/// The character's gender, by `character_gender`.
pub const CHARACTER_RULES: &[(&str, &str)] = &[
    (
        "woman",
        "{{char}} is a woman: she/her throughout. The name fits.",
    ),
    (
        "man",
        "{{char}} is a man: he/him throughout. The name fits.",
    ),
    (
        "nonbinary",
        "{{char}} is non-binary: they/them throughout. The name fits.",
    ),
    (
        "not human",
        "{{char}} is not human: it or they, one kept throughout. The name fits.",
    ),
    (
        "they",
        "{{char}} is the user's own self, of no stated gender: spoken of as they/them throughout. The name fits.",
    ),
    (
        "as told",
        "{{char}}'s gender is as the user said in character_words: one set of pronouns kept throughout. The name fits.",
    ),
];
/// The card's fields, in the source's order.
pub const FIELDS: &[&str] = &[
    "name",
    "description",
    "personality",
    "scenario",
    "first_mes",
    "mes_example",
    "alternate_greetings",
    "creator_notes",
];
/// The fields the user does not see in a chat.
pub const HIDDEN: &[&str] = &["description", "personality", "scenario"];
