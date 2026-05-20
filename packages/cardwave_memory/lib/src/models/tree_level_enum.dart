/// The five story-tree levels, coarsest to finest. Events aggregate into
/// scenes, scenes into chapters, chapters into parts, parts under the single
/// [book] root. [eventTurn] is the leaf a `StoryEvent` sits at.
enum TreeLevelEnum { book, part, chapter, scene, eventTurn }
