// What a chat is called: `chatTitle`, its title as the lists show it, and `chatName`, its name in the rail and its tab.
import { wording } from "./language/language";

/** A chat's title as the lists show it. */
export const chatTitle = (title: string) => title || wording("title-new-chat");

/**
 * What a chat is called in the rail's latest chats and in its tab: "[character] · [chat title]", the character
 * alone where the chat has no title of its own or is called after it, and the title alone in a chat without a character.
 */
export function chatName(chat: { names: string[]; title: string }): string {
  const [name] = chat.names;
  if (!name) return chatTitle(chat.title);
  return !chat.title || chat.title === name ? name : `${name} · ${chat.title}`;
}
