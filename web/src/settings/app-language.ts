// The line "Language of the app" (Settings' group Language; first run's step 1 its field alone): the app's field of the languages
// the app has files for, each in its own words (language.ts `appLanguages`), at the language in use. A language
// taken is stored (the server's `app_language`, which "Language the AI writes in" follows until changed itself)
// and taken at once; the page follows the choice at its start and when the settings change (`readAppLanguage`).
// `notice` says why it was not stored.
import { changeSettings, getSettings } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { aboutChoice, el, failure, item, noticeBox, reason, selectField } from "../dom";
import { LABELS } from "../setting-labels";
import { appLanguages, chooseLanguage, language, wording } from "../language/language";

/** The line (`node`, Settings') and its field alone (`field`, first run's step 1, without the line's name and grey words). */
export function appLanguageLine(): { node: HTMLElement; field: HTMLElement; notice: HTMLElement } {
  const notice = noticeBox();
  const take = (code: string) => {
    notice.replaceChildren();
    changeSettings({ app_language: code }).then(
      (settings) => {
        say(settings);
        chooseLanguage(settings.app_language);
      },
      (error: unknown) => {
        field.value = language();
        notice.replaceChildren(failure(reason(error)));
      },
    );
  };
  const options = appLanguages().map((one) => ({ value: one.code, label: one.name }));
  const field = selectField(options, language(), take, { ariaLabel: LABELS.settings.appLanguage, wide: true });
  // The grey line says the computer's language is followed until one is chosen, then that the user chose it.
  const about = el("span", { className: "meta" }, wording("language-line-taken-from-this-computer"));
  const say = (settings: Settings) => (about.textContent = aboutChoice(settings.app_language !== null, wording("language-line-taken-from-this-computer")));
  getSettings().then(say, () => {}); // unread, the first state's words stay
  const node = item(LABELS.settings.appLanguage, about, field.node);
  return { node, field: field.node, notice };
}

/** Takes the language the settings name, the computer's while they name none; a failed reading leaves it as it is. */
export function readAppLanguage(settings: Promise<Settings> = getSettings()): void {
  settings.then(
    (read) => chooseLanguage(read.app_language),
    () => {},
  );
}
