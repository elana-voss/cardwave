// The line "Language the AI writes in" (the board "Settings", its group Language; first run's step 2 has it too):
// the app's field of the languages the server knows, the account's chosen, stored at once when another is taken,
// and in grey that it follows "Language of the app" until changed (the server's `language_chosen`). `notice` says why it was not read or not stored.
import { changeSettings, getSettings, listLanguages } from "../api/client";
import type { Language } from "../api/generated/Language";
import { el, failure, item, noticeBox, reason, selectField } from "../dom";
import { LABELS } from "../setting-labels";
import { languageName, wording } from "../language/language";

export function languageLine(): { node: HTMLElement; notice: HTMLElement; read(): void } {
  const notice = noticeBox();
  let saving = Promise.resolve();
  const take = (code: string) =>
    void (saving = saving.then(async () => {
      notice.replaceChildren();
      try {
        field.value = (await changeSettings({ language: code })).language;
      } catch (error) {
        notice.replaceChildren(failure(reason(error)));
      }
    }));
  const field = selectField([], "", take, { ariaLabel: wording("label-settings-language"), disabled: true, wide: true });
  // The languages once they were read; a reading that failed is tried again at the next.
  let languages: Promise<Language[]> | null = null;
  const read = () =>
    void Promise.all([(languages ??= listLanguages()), getSettings()]).then(
      ([all, settings]) => {
        field.offer(all.map((one) => ({ value: one.code, label: languageName(one.code, one.name) })));
        field.value = settings.language;
        field.field.disabled = false;
        notice.replaceChildren();
      },
      (error: unknown) => {
        languages = null;
        notice.replaceChildren(failure(reason(error)));
      },
    );
  read();
  const node = item(LABELS.settings.language, wording("language-line-follows-the-app"), field.node);
  return { node, notice, read };
}
