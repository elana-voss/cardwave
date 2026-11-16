// What a chat is called: `chatTitle`, its title as the lists show it, and `chatName`, its name in the rail and its tab.
import { dayAt, dayMonth } from "./format";
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

/**
 * The names of `chats` as the rail says them: `chatName`, and where several have one name, each with its day, and with
 * its time too where another of that name falls on the same day.
 */
export function chatNames(chats: { names: string[]; title: string; updated_at: number }[]): string[] {
  const names = chats.map(chatName);
  const days = chats.map((chat) => dayMonth(chat.updated_at));
  return names.map((name, at) => {
    const twins = names.flatMap((other, to) => (to !== at && other === name ? [to] : []));
    if (twins.length === 0) return name;
    const when = twins.some((to) => days[to] === days[at]) ? dayAt(chats[at].updated_at) : days[at];
    return `${name} · ${when}`;
  });
}
