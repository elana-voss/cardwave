# Reading the mood

This package takes a line of chat and makes a quick guess at the feeling behind it. Happy, angry, afraid, and so on.

## The feelings it knows

It works from a fixed list of 27 common feelings. Things like joy, anger, fear, sadness, love, gratitude, curiosity, and pride.

There is also one more answer, neutral, which means it could not settle on a clear feeling.

## How it makes the guess

It does not use a separate AI for this. It reuses the same tool the app already runs on the device for judging how close two pieces of writing are in meaning.

Each feeling comes with a short plain description. The one for fear is "feeling afraid, anxious, or threatened by danger." When the app starts, it reads all of these descriptions once and remembers them.

To read a line of chat, it compares that line against every description and picks the feeling whose description is the closest match.

## When it is not sure

If no feeling is a close enough match, it answers neutral instead of forcing a guess. There is a cutoff for how close the best match has to be, and anything below it reads as neutral.

That cutoff can be nudged up or down. A higher cutoff means it only commits to a feeling when it is fairly sure.

## How it is used in chat

During a chat it usually reads two lines together, the player's message and the character's reply, and returns a feeling for each. It handles them one after the other, because the underlying tool can only work on one thing at a time.

The story memory uses these readings to note the mood of each moment it saves.

## What it does not do

It does not need the internet, and it does not load a second AI model. It borrows the one the app already has.

It keeps no record of its own. It reads a line, returns an answer, and moves on.

It is a quick read, not a careful judgment. Broad feelings like joy or anger land well. Very close cousins, such as admiration against approval against gratitude, can blur, which is why each feeling is given its own clearly worded description.

## If you are reading the code

The package is small. One file lists the feelings. One file holds a short description for each. One file does the comparing and returns the closest feeling along with how close the match was.
