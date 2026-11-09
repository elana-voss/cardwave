// Settings › "About Cardwave" (board "About Cardwave, licenses"), at `#/settings/about` with the path "Settings / About
// Cardwave": the logo, the name, the version and the day its server was built (`/api/status`), the link to the community's
// Discord server (`community`, the owner, 2026-11-09); the line "Logs", which in the
// desktop app names the logs' folder and opens it ("Open folder"); the group "What's new", a line per version,
// newest first, from the file `web/public/whats-new.<code>.md` in the language in use, else the English `whats-new.md` (`versions`); then the groups Models, "Figures and
// animations" (the companion's figure and Mixamo), Voices, "Open-source software" and "Provider and model list".
// Models, figures and lists have "Licence" at their right; a press on a package's
// row (its name is the button that reaches over the line, `.row-link`) opens the panel from the right with its
// license texts; the libraries are searched by name as typed. The voices are the shipped ones (`/api/voice/shipped`, also where Voice is at a provider), each with
// its set, license and whom CC BY asks to be named, in the app's language (`voiceText`); the rest is the file tools/licenses.py writes, which comes with
// the UI: nothing is fetched from elsewhere.
import { language, wording } from "../language/language";
import { getLicenses, getShippedVoices, getStatus, getWhatsNew, type Library, type Licensed, type Licenses } from "../api/client";
import type { VoiceChoice } from "../api/generated/VoiceChoice";
import { announce, el, failure, group, reason, searchField, type View } from "../dom";
import { sheet } from "../dialogs";
import { clause, day } from "../format";
import { desktop } from "../desktop";
import logo from "../logo.png";
import { linked } from "../narration";

/** A license's SPDX expression as the page says it: "MIT or Apache-2.0". */
export function spoken(license: string): string {
  return license
    .replace(/\s*\/\s*/g, " OR ")
    .replace(/\b(OR|AND|WITH)\b/g, (word) => (word === "OR" ? wording("about-or") : word === "AND" ? wording("about-and") : wording("about-with")))
    .replace(/\s+/g, " ")
    .trim();
}

/** The libraries whose name holds what was typed, whatever its case; all where nothing was. */
export function found(libraries: Library[], typed: string): Library[] {
  const asked = typed.trim().toLowerCase();
  return asked ? libraries.filter((library) => library.name.toLowerCase().includes(asked)) : libraries;
}

/** A version and what it brought, as "What's new" shows it. */
export type Version = { version: string; notes: HTMLElement[] };

/**
 * The file `web/public/whats-new.md`, a version under each "# " heading (its number), in the file's order, which
 * is the newest first: "## " a heading within it, "- " a list's points, every other line a paragraph's, an empty
 * line between two parts; a link in it opens in the browser (`linked`). Words before the first version are left out.
 */
export function versions(text: string): Version[] {
  const all: Version[] = [];
  let list: HTMLElement | null = null;
  for (const line of text.split(/\r?\n/).map((line) => line.trim())) {
    const heading = /^# (.*)$/.exec(line);
    if (heading) {
      all.push({ version: heading[1]!.trim(), notes: [] });
      list = null;
      continue;
    }
    const now = all[all.length - 1];
    if (!now) continue;
    const point = /^[-*] (.*)$/.exec(line);
    if (point) {
      if (!list) now.notes.push((list = el("ul")));
      list.append(el("li", null, ...linked(point[1]!)));
      continue;
    }
    list = null;
    const part = /^## (.*)$/.exec(line);
    if (part) now.notes.push(el("h4", null, part[1]!));
    else if (line) now.notes.push(el("p", null, ...linked(line)));
  }
  return all;
}

/** The link to the community's Discord server, under the version; it opens outside the app. */
export function community(): HTMLAnchorElement {
  return el("a", { href: "https://discord.gg/C62KZVg6J", target: "_blank", rel: "noopener noreferrer" }, wording("about-community"));
}

export function aboutView(): View {
  const node = el("section", { className: "main g-24 about" });
  const said = el("span", { className: "meta" });
  const groups = el("div", { className: "page-col" });
  node.append(
    el("header", { className: "page-head" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-about")))),
    groups,
  );
  groups.append(el("div", { className: "about-head flex ai-c g-14" }, el("img", { src: logo, alt: "" }), el("div", { className: "flex f-col" }, el("span", { className: "fs-title bold" }, wording("app-name")), said, community())));

  /** Opens the panel with the texts `of` names. */
  const show = (title: string, about: string, texts: string[]) =>
    sheet(node, title, el("div", { className: "flex f-col g-8" }, el("p", { className: "meta" }, about), ...texts.map((text) => el("pre", { className: "code mono" }, text))));

  /** A group whose lines stand in one box. */
  const boxed = (name: string, lines: HTMLElement[], aside?: HTMLElement) =>
    group(name, aside, el("div", { className: "group" }, ...lines));

  const line = (label: string, about: string, control?: HTMLElement) =>
    el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), el("span", { className: "meta" }, about)), control);

  /** A model's or list's line, with "Licence" at its right. */
  const licensed = (all: Licenses) => (of: Licensed) => {
    const about = [of.what, spoken(of.license), of.by ? wording("about-by", { by: of.by }) : ""].filter(Boolean).join(" · ");
    const open = el("button", { type: "button", className: "textbtn fs-small about-license", ariaLabel: wording("about-licence-of", { name: of.name }), onclick: () => show(of.name, about, [all.texts[of.text]!]) }, wording("about-licence"));
    const node = line(of.name, about, open);
    node.classList.add("item-line");
    return node;
  };

  const voiceLine = (voice: VoiceChoice) => line(voice.name, voiceText(voice));

  // The desktop app tells the page the folder; a browser's page may be on another computer than the server.
  const folder = window.cardwaveDesktop?.logs;
  const open = folder ? el("button", { type: "button", className: "btn btn-secondary on-box", onclick: () => desktop("open_logs").catch((error) => announce(wording("about-folder-failed", { reason: clause(reason(error)), where: folder }))) }, wording("about-open-folder")) : undefined;
  const where = folder ?? wording("about-logs-where");
  // Under the head, before What's new, as the board has it: What's new points to it.
  groups.append(el("div", { className: "group" }, line(wording("about-logs"), wording("about-logs-about", { where }), open)));

  // What each version brought, in its place before the licenses' groups, which come after it.
  const news = el("div", { className: "group" });
  const versionLine = (one: Version) =>
    el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, wording("about-version", { version: one.version })), el("div", { className: "meta about-notes" }, ...one.notes)));
  groups.append(group(wording("about-whats-new"), null, news));

  const libraries = (all: Licenses) => {
    const asked = { q: "" };
    const lines = el("div", { className: "group about-libraries mt-10" });
    const libraryLine = (library: Library) => {
      const about = `${spoken(library.license)}${library.version ? ` · ${library.version}` : ""}`;
      const name = el("button", { type: "button", className: "row-link item-label", onclick: () => show(library.name, about, library.texts.map((at) => all.texts[at]!)) }, library.name);
      return el("div", { className: "item rel" }, el("div", { className: "item-text" }, name, el("span", { className: "meta" }, about)));
    };
    const draw = () => {
      const shown = found(all.libraries, asked.q);
      lines.replaceChildren(...(shown.length ? shown.map(libraryLine) : [el("div", { className: "item meta" }, wording("about-no-package"))]));
    };
    draw();
    const count = el("span", { className: "meta" }, wording("about-packages", { count: String(all.libraries.length) }));
    return group(wording("about-open-source"), count, searchField(wording("about-search"), wording("about-find"), asked, draw), lines);
  };

  // Each part fails alone: the licenses, which come with the UI, show also where the server does not answer.
  void getStatus()
    .then((status) => (said.textContent = wording("about-version-built", { version: status.version, built: day(status.built) })))
    .catch((error) => said.replaceChildren(failure(reason(error))));
  void getWhatsNew(language())
    .then((text) => {
      const all = versions(text);
      news.replaceChildren(...(all.length ? all.map(versionLine) : [el("div", { className: "item meta" }, wording("about-no-notes"))]));
    })
    .catch((error) => news.replaceChildren(failure(reason(error))));
  const voices = el("div", { className: "group" });
  void getShippedVoices()
    .then((shipped) => voices.replaceChildren(...shipped.map(voiceLine)))
    .catch((error) => voices.replaceChildren(failure(reason(error))));
  void getLicenses()
    .then((all) =>
      groups.append(
        boxed(wording("about-models"), all.models.map(licensed(all))),
        boxed(wording("about-figures"), all.figures.map(licensed(all))),
        group(wording("about-voices"), null, voices),
        libraries(all),
        boxed(wording("about-lists"), all.lists.map(licensed(all))),
      ),
    )
    .catch((error) => groups.append(failure(reason(error))));
  return { node: node };
}

/** A shipped voice's set, licence and whom it credits, as CC BY asks, in the app's language; the names as they are. */
export function voiceText(voice: VoiceChoice): string {
  const credit = voice.credit;
  const set = credit.kind === "donated" ? wording("about-voice-donations") : voice.set;
  const by =
    credit.kind === "acted_by"
      ? wording("about-voice-acted-by", { name: credit.name })
      : credit.kind === "vctk"
        ? wording("about-voice-vctk", { speaker: credit.speaker })
        : credit.kind === "cml_tts"
          ? credit.cleaned
            ? wording("about-voice-cml-tts-cleaned", { speaker: credit.speaker })
            : wording("about-voice-cml-tts", { speaker: credit.speaker })
          : "";
  return [set, voice.license, by].filter(Boolean).join(" · ");
}
