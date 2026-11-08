// What format.ts writes: `bytes`, the dates and numbers, each in English as it always was and in the language in use, and `spoken`.
import { afterEach, describe, expect, test } from "vitest";
import { bytes, clause, clock, comma, count, dateTime, day, dayAt, dayMonth, decimal, folderShort, moment, spoken } from "./format";
import { useLanguage } from "./language/language";

afterEach(() => useLanguage("en"));

describe("bytes", () => {
  const KB = 1024;
  const MB = 1024 * KB;

  test("a size is written in whole KB, of which a part counts as one", () => {
    expect(bytes(0)).toBe("0 KB");
    expect(bytes(1)).toBe("1 KB");
    expect(bytes(KB)).toBe("1 KB");
    expect(bytes(KB + 1)).toBe("2 KB");
    expect(bytes(999 * KB)).toBe("999 KB");
  });

  test("from 1000 KB on it is written in MB of 1024 KB each, with one decimal", () => {
    expect(bytes(999 * KB + 1)).toBe("1.0 MB");
    expect(bytes(1.5 * MB)).toBe("1.5 MB");
    expect(bytes(Math.round(999.9 * MB))).toBe("999.9 MB");
  });

  test("what would read 1000.0 MB is written in GB of 1024 MB each", () => {
    expect(bytes(Math.round(999.96 * MB))).toBe("1.0 GB");
    expect(bytes(5 * 1024 * MB)).toBe("5.0 GB");
  });
});

describe("day", () => {
  test("a moment is written as its day with the month's name: the same for a whole day, and without the time", () => {
    const [morning, evening, next] = [new Date(2026, 2, 9, 0, 0, 1), new Date(2026, 2, 9, 23, 59, 58), new Date(2026, 2, 10, 0, 0, 1)];
    expect(day(morning.getTime())).toBe("9 Mar 2026");
    // The month is a word, so that no one reads the 9th of March as the 3rd of September.
    expect(day(morning.getTime())).toMatch(/\p{L}/u);
    expect(day(morning.getTime())).toContain("2026");
    expect(day(evening.getTime())).toBe(day(morning.getTime()));
    expect(day(next.getTime())).not.toBe(day(morning.getTime()));
    expect(day(evening.getTime())).not.toContain("59");
  });
});

describe("dayMonth and dayAt", () => {
  test("a day is its day before its month, the year only where it is another; a version's moment adds its 24 h clock, today's \"Today\"", () => {
    const now = new Date(2026, 9, 25, 16, 0).getTime();
    expect(dayMonth(new Date(2026, 9, 12, 21, 10).getTime(), now)).toBe("12 Oct");
    expect(dayMonth(new Date(2025, 9, 12).getTime(), now)).toBe("12 Oct 2025");
    expect(dayMonth(new Date(2026, 9, 25, 9, 0).getTime(), now)).toBe("Today");
    expect(dayAt(new Date(2026, 9, 25, 14, 2).getTime(), now)).toBe("Today, 14:02");
    expect(dayAt(new Date(2026, 9, 12, 21, 10).getTime(), now)).toBe("12 Oct, 21:10");
  });
});

describe("the language in use", () => {
  test("writes the dates and numbers, English as it always did", () => {
    const [now, at] = [new Date(2026, 9, 25, 16, 0).getTime(), new Date(2026, 9, 12, 21, 10).getTime()];
    const english = [dayAt(at, now), day(at), moment(at), dateTime(at), clock(at), count(1234567), decimal(0.4, 1)];
    expect(english).toEqual(["12 Oct, 21:10", "12 Oct 2026", "10/12/2026, 9:10:00 PM", "Oct 12, 2026, 9:10 PM", "09:10 PM", "1,234,567", "0.4"]);
    useLanguage("de", "");
    const german = [dayAt(at, now), day(at), moment(at), dateTime(at), clock(at), count(1234567), decimal(0.4, 1)];
    expect(german).toEqual(["12. Okt., 21:10", "12. Okt. 2026", "12.10.2026, 21:10:00", "12. Okt. 2026, 21:10", "21:10", "1.234.567", "0,4"]);
  });

  test("a list is joined by the language's own comma", () => {
    expect(["Alice", "Bob"].join(comma())).toBe("Alice, Bob");
    useLanguage("ja", "format-comma = 、");
    expect(["Alice", "Bob"].join(comma())).toBe("Alice、Bob");
  });

  test("a day and its time are joined by the language's own words, not its list comma", () => {
    const now = new Date(2026, 9, 25, 18, 0).getTime();
    useLanguage("ja", "format-comma = 、\nformat-today = 今日\nformat-day-at = { $day } { $time }");
    expect(dayAt(new Date(2026, 9, 25, 14, 2).getTime(), now)).toBe("今日 14:02");
  });
});

test("a code name is said as words", () => {
  expect(spoken("word_count")).toBe("Word count");
  expect(spoken("dice-roll")).toBe("Dice roll");
  expect(spoken("daysBetween")).toBe("Days between");
  expect(spoken("ok")).toBe("Ok");
});

test("a folder's long path keeps its start and its own name, cut in the middle", () => {
  expect(folderShort("C:\\Users\\someone\\OneDrive\\Documents")).toBe("C:\\Users\\…\\Documents");
  expect(folderShort("/home/someone/cards")).toBe("/home/someone/cards");
  expect(folderShort("D:\\cards")).toBe("D:\\cards");
  // A separator at the end, and a network share's start, keep the folder's own name.
  expect(folderShort("C:\\a\\b\\c\\cards\\")).toBe("C:\\a\\…\\cards");
  expect(folderShort("\\\\srv\\share\\a\\b")).toBe("\\\\srv\\…\\b");
  expect(folderShort("/home/someone/x/cards")).toBe("/home/…/cards");
});

test("a reason put inside a sentence loses its own full stop", () => {
  expect([clause("The key was not taken. "), clause("No answer"), clause("Wait...")]).toEqual(["The key was not taken", "No answer", "Wait..."]);
});
