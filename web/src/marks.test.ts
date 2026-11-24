// What marks.ts reads: speech, italics, bold, underline, code, links and pictures, nested, crossed and left open.
import { expect, test } from "vitest";
import { blocks, paragraphs, plain, read, type Piece } from "./marks";

const TAG = { speech: "s", italics: "i", bold: "b", underline: "u" } as const;
/** Pieces as short tags: <s> speech, <i> italics, <b> bold, <u> underline, <a url>, <code>, <img url alt>. */
const shown = (pieces: Piece[]): string =>
  pieces
    .map((piece) => {
      if (piece.kind === "text") return piece.text;
      if (piece.kind === "code") return `<code>${piece.text}</code>`;
      if (piece.kind === "picture") return `<img ${piece.url} ${piece.alt}>`;
      if (piece.kind === "link") return `<a ${piece.url}>${shown(piece.pieces)}</a>`;
      return `<${TAG[piece.mark]}>${shown(piece.pieces)}</${TAG[piece.mark]}>`;
    })
    .join("");
const marks = (text: string, open = false) => shown(read(text, { open, links: true }));

test("narration between asterisks is italics without them, speech keeps its quotation marks", () => {
  expect(marks('*She looks up.* "You are late," *she says.*')).toBe('<i>She looks up.</i> <s>"You are late,"</s> <i>she says.</i>');
  expect(marks("No marks here.")).toBe("No marks here.");
  expect(marks("")).toBe("");
});

test("an asterisk beside a space or inside a word or number marks nothing", () => {
  for (const text of ["2 * 3 * 4", "a * b* c", "*not closed", "* a list line *", "2*3*4", "a*b*c and x*y", "é*t*é", "****bar****"]) expect(marks(text)).toBe(text);
  expect(marks("2*3 *told* 4*5")).toBe("2*3 <i>told</i> 4*5");
  expect(marks('"Fine."*She nods.*"Go."')).toBe('<s>"Fine."</s><i>She nods.</i><s>"Go."</s>');
});

test("two asterisks are bold, three bold italics, nested within each other", () => {
  expect(marks("**bold** and *told*")).toBe("<b>bold</b> and <i>told</i>");
  expect(marks("***both***")).toBe("<i><b>both</b></i>");
  expect(marks("**bold *it* bold**")).toBe("<b>bold <i>it</i> bold</b>");
  expect(marks("*it **bold** it*")).toBe("<i>it <b>bold</b> it</i>");
});

test("being written, a mark begun runs to the end; once finished an open sign shows, speech to its paragraph's end", () => {
  expect(marks("*She looks", true)).toBe("<i>She looks</i>");
  expect(marks('"Wait." *She', true)).toBe('<s>"Wait."</s> <i>She</i>');
  expect(marks("*one* two *", true)).toBe("<i>one</i> two ");
  expect(marks("**Bo", true)).toBe("<b>Bo</b>");
  expect(marks("<u>und", true)).toBe("<u>und</u>");
  expect(marks('"I will', true)).toBe('<s>"I will</s>');
  expect(marks("2 * 3", true)).toBe("2 * 3");
  expect(marks("*She looks")).toBe("*She looks");
  expect(marks("<u>und")).toBe("<u>und");
  expect(marks('"The first of a long speech')).toBe('<s>"The first of a long speech</s>');
});

test.each(['"Yes"', "“Yes”", "„Ja“", "«Да»", "»Ja«", "「はい」", "『はい』"])("speech in %s", (text) => {
  expect(marks(`She says ${text} once.`)).toBe(`She says <s>${text}</s> once.`);
});

test("single quotes are no speech, nor a quotation mark right after a digit, which still ends speech", () => {
  expect(marks("'Fine,' she said, isn't it")).toBe("'Fine,' she said, isn't it");
  expect(marks('He is 5\'10" tall.')).toBe('He is 5\'10" tall.');
  expect(marks('"Born in 1999" she says.')).toBe('<s>"Born in 1999"</s> she says.');
  expect(marks("終わり」")).toBe("終わり」");
  expect(marks("「彼は『はい』と」")).toBe("<s>「彼は<s>『はい』</s>と」</s>");
});

test("crossing marks: the one begun later ends with the earlier, its own end shows as written", () => {
  expect(marks('*She says "hello* there"')).toBe('<i>She says <s>"hello</s></i> there"');
  expect(marks('"She *nods" and smiles*')).toBe('<s>"She <i>nods</i>"</s> and smiles*');
});

const LINK = "https://example.com";
test.each([
  ["link", "speech", `[say "hi"](${LINK})`, `<a ${LINK}>say <s>"hi"</s></a>`],
  ["link", "bold", `[a **b**](${LINK})`, `<a ${LINK}>a <b>b</b></a>`],
  ["link", "italics", `[*the* map](${LINK})`, `<a ${LINK}><i>the</i> map</a>`],
  ["speech", "link", `"see [it](${LINK})"`, `<s>"see <a ${LINK}>it</a>"</s>`],
  ["speech", "bold", '"a **b** c"', '<s>"a <b>b</b> c"</s>'],
  ["speech", "italics", '"a *b* c"', '<s>"a <i>b</i> c"</s>'],
  ["bold", "link", `**see ${LINK}**`, `<b>see <a ${LINK}>${LINK}</a></b>`],
  ["bold", "speech", '**a "b" c**', '<b>a <s>"b"</s> c</b>'],
  ["bold", "italics", "**a *b* c**", "<b>a <i>b</i> c</b>"],
  ["italics", "link", `*see [it](${LINK})*`, `<i>see <a ${LINK}>it</a></i>`],
  ["italics", "speech", '*a "b" c*', '<i>a <s>"b"</s> c</i>'],
  ["italics", "bold", "*a **b** c*", "<i>a <b>b</b> c</i>"],
])("%s holding %s", (_outer, _inner, text, expected) => {
  expect(marks(text)).toBe(expected);
});

test("code is read whole, before links; underline by its signs", () => {
  expect(marks('`*not* "read"` and "run `ls`"')).toBe('<code>*not* "read"</code> and <s>"run <code>ls</code>"</s>');
  expect(marks(`\`${LINK}\``)).toBe(`<code>${LINK}</code>`);
  expect(marks("<u>under *it*</u> and <U>up</U>")).toBe("<u>under <i>it</i></u> and <u>up</u>");
  expect(marks("a </u> b")).toBe("a </u> b");
});

test("links and pictures: a link's words read, no web address stays text, none read without links", () => {
  expect(marks(`![A lamp](${LINK}/l.png) ![Dot](data:image/png;base64,AA==)`)).toBe(`<img ${LINK}/l.png A lamp> <img data:image/png;base64,AA== Dot>`);
  expect(marks("[*no*](javascript:x) ![no](file:///a)")).toBe("[<i>no</i>](javascript:x) ![no](file:///a)");
  expect(marks(`*She points at ${LINK}.*`)).toBe(`<i>She points at <a ${LINK}>${LINK}</a>.</i>`);
  expect(shown(read(`[*a*](${LINK}) ${LINK}`))).toBe(`[<i>a</i>](${LINK}) ${LINK}`);
});

test("a paragraph's quotation blocks are its lines after '> '; plain text is without the signs of its marks", () => {
  expect(blocks("one\n> two\n> three\n>\n> four\n>_< five")).toEqual([
    { quote: false, text: "one" },
    { quote: true, text: "two\nthree\n\nfour" },
    { quote: false, text: ">_< five" },
  ]);
  expect(plain(read('*She* says **"hi"** <u>now</u> `x`'))).toBe('She says "hi" now x');
});

test("code fenced or in a run of backticks is read whole, the fence's language word left out", () => {
  expect(marks("```js\nlet a = 1;\n```")).toBe("<code>let a = 1;</code>");
  expect(marks("``a`b`` c")).toBe("<code>a`b</code> c");
  expect(paragraphs("```\na\n\nb\n```\n\nc")).toEqual(["```\na\n\nb\n```", "c"]);
});

test("an address keeps its brackets, a link its title, and a picture inside a link stays a picture", () => {
  expect(marks("see https://w.org/A_(b) now")).toBe("see <a https://w.org/A_(b)>https://w.org/A_(b)</a> now");
  expect(marks("[x](https://w.org/A_(b))")).toBe("<a https://w.org/A_(b)>x</a>");
  expect(marks('[x](https://x.com "title")')).toBe("<a https://x.com>x</a>");
  expect(marks("[![A lamp](https://x.com/l.png)](https://x.com)")).toBe("<a https://x.com><img https://x.com/l.png A lamp></a>");
  expect(marks("見て https://x.com。次")).toBe("見て <a https://x.com>https://x.com</a>。次");
});

test("crossing runs of asterisks: the later ends with the earlier, its own sign shown as written", () => {
  expect(marks("*a **b* c**")).toBe("<i>a <b>b</b></i> c**");
  expect(marks("**a *b** c*")).toBe("<b>a <i>b</i></b> c*");
  expect(marks("**bold*", true)).toBe("<b>bold</b>");
});
