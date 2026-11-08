// The build's check of the UI's words (vite.config.ts runs it as the build starts): every key the UI uses,
// `wording("key")` (language.ts), is in the English file, and every use writes its key out, so the check sees
// it. `missing` answers with what fails, one line each, empty where all is well; it reads the texts it is given,
// so the tests give it theirs. Traps: the module that defines `wording` is not looked into; the comments are
// read as code, so a comment that shows a use shows a key the file has. `codesMissing` checks the server's error
// codes (api/generated/Code.ts) likewise: each has its words, `error-<code>` (errors.ts); `idsMissing` the
// interview's text ids (api/generated/InterviewTextId.ts), `interview-<id>` (interview.ts).

/** The keys of the messages in a Fluent file's text: a line that begins with a name and "=" (terms, "-name", are not keys). */
export function keysOf(ftl: string): Set<string> {
  return new Set([...ftl.matchAll(/^([a-zA-Z][\w-]*)\s*=/gm)].map((found) => found[1]));
}

/** What fails in `sources` (each a file's name and its text) against the English file's text: a key it lacks, or a key not written out. */
export function missing(sources: [string, string][], english: string): string[] {
  const keys = keysOf(english);
  const wrong: string[] = [];
  for (const [file, text] of sources) {
    for (const use of text.matchAll(/\bwording\(\s*(?:"([\w-]+)"|'([\w-]+)')?/g)) {
      const key = use[1] ?? use[2];
      const line = text.slice(0, use.index).split("\n").length;
      if (key === undefined) wrong.push(`${file}:${line}: a key not written out as "key"`);
      else if (!keys.has(key)) wrong.push(`${file}:${line}: "${key}" is not in en.ftl`);
    }
  }
  return wrong;
}

/** What fails of the error codes in `codeTs` (api/generated/Code.ts's text): a code whose words, `error-<code>`, the English file lacks. */
export function codesMissing(codeTs: string, english: string): string[] {
  const keys = keysOf(english);
  const codes = [...(codeTs.match(/type Code =([^;]*);/)?.[1] ?? "").matchAll(/"(\w+)"/g)].map((found) => found[1]);
  return codes.filter((code) => !keys.has(`error-${code.replaceAll("_", "-")}`)).map((code) => `the error code "${code}" has no words: error-${code.replaceAll("_", "-")} is not in en.ftl`);
}

/** What fails of the interview's text ids in `idsTs` (api/generated/InterviewTextId.ts's text): an id whose words, `interview-<id>`, the English file lacks. */
export function idsMissing(idsTs: string, english: string): string[] {
  const keys = keysOf(english);
  const ids = [...(idsTs.match(/type InterviewTextId =([^;]*);/)?.[1] ?? "").matchAll(/"([\w-]+)"/g)].map((found) => found[1]);
  return ids.filter((id) => !keys.has(`interview-${id}`)).map((id) => `the interview text "${id}" has no words: interview-${id} is not in en.ftl`);
}
