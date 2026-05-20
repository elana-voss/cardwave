/// Who produced a memory message. The app maps `ChatRoleEnum` onto this: the
/// user stays [user]; the roleplay reply (assistant or named character)
/// becomes [character]. System messages are not story content and are
/// dropped before mapping.
enum MemoryRole { user, character }
