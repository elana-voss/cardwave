# Story memory

This package gives each chat a memory. As a conversation grows, it keeps track of what has happened and what is true right now, so the character can bring things up later instead of forgetting them.

It works one chat at a time. Each chat has its own memory, and nothing carries over between chats.

## Two kinds of memory

It keeps two different things.

Events are things that happened. "They met at the harbor." "She drew her blade." These are moments in the story. Once something has happened, it stays happened.

Facts are things that are true right now. "Mayla is the captain." "The two of them are enemies." Facts can change as the story moves on.

Keeping these apart is the whole point. If you ask what happened at the gate, you want events. If the character needs to know who someone is to them at this moment, that is a fact.

## How it learns

Every so often, after a few new messages, it reads them and writes down any new events and facts it finds. The reading is done by the AI model, and it happens in the background after a reply, so it never makes you wait.

It reads each message once. Older messages are shown alongside for context, but they are not copied into memory a second time.

## How it remembers at the right moment

Just before the character replies, it looks back through what it has stored and pulls out the few items that fit the current moment.

For events, it finds the ones closest in meaning to what was just said. It also gives a little extra weight to events that name a person or place the latest message mentions.

For facts, it looks up whoever is being talked about, including the character you are chatting with, and gathers what is currently true about them.

Those events and facts are handed to the character as background for its reply.

## When facts change

Stories move. A friend becomes an enemy. A sailor becomes a captain.

When it learns something that cancels an older fact, it marks the old fact as no longer true and keeps the new one in its place. The old fact is not thrown away. It is set aside, out of the way, in case it is ever needed again.

## When you edit or delete a message

Memory is built from the chat, so it follows the chat. If you change or delete a message, anything that was drawn from that message is dropped, and memory rebuilds from that point. This keeps it honest instead of holding on to something you took back.

There is one helpful detail. If you delete the very message that changed a fact, the older fact it had set aside comes back, because it is true again.

## What it does not do

It never edits or rewrites your chat. The chat is the real record. Memory only points at it, and it can be thrown away and rebuilt at any time without touching a single message.

It does not store background lore about the world or the character. That already lives in the character card and the lorebook. This memory is only for what comes up during the chat itself.

The side assistant chat does not get a memory. It is there to help, not to tell a story.

## Where it is kept

Each chat stores its memory in a small file next to that chat. Looking things up does not need the internet. Only the learning step, the part that reads new messages, uses the AI model.

## What the saved file looks like

The memory file is plain text you can open and read. It holds two lists, one of events and one of facts. Here is a short example with one of each.

```json
{
  "events": [
    {
      "id": "event-3f2a8b",
      "text": "Mayla drew her blade on the crew in the harbor tavern.",
      "contextual_prefix": "In the harbor tavern at dusk,",
      "message_ids": ["msg-12", "msg-13"],
      "recorded_at": 1747800000000,
      "character_emotion": "anger",
      "user_emotion": "fear",
      "importance": 4,
      "characters": ["Mayla"],
      "locations": ["Harbor Tavern"],
      "items": ["blade"],
      "concepts": ["betrayal"],
      "keywords": ["tavern", "blade"]
    }
  ],
  "facts": [
    {
      "id": "fact-9c8125",
      "subjects": ["mayla", "the crew"],
      "text": "Mayla and the crew are enemies.",
      "message_ids": ["msg-13"],
      "superseded_at": null,
      "superseded_by": null
    }
  ]
}
```

An event records what happened, which messages it came from, a rough read on the mood, and the people, places and things involved. A fact records what is true and who it is about.

The last two lines on a fact show whether it still holds. On a current fact they are empty. When a later fact replaces this one, the first fills in with the time of the change and the second points at the fact that replaced it. The old fact stays in the list, just marked this way, so it can come back if the change is undone.

The lists of numbers used to search by meaning are large and not readable, so they sit in a separate file next to this one and are left out here.

## If you are reading the code

The package is small and each file is named for its job.

The extractor reads a batch of messages and returns the new events and facts. The engine holds a chat's memory, runs the extractor as the chat grows, and handles edits and deletions. The retriever does the looking up. The graph is the stored shape, which is just a list of events and a list of facts. A thin service in the app connects all of this to the chat screen.
