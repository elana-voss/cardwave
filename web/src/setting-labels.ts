// The labels of the settings on the settings' and the account's pages, once: each page draws its lines' labels from
// here, and Search Cardwave finds them here (`onPage`, find.ts), as the server does not know them. Each page's
// labels in the order its lines show, as an empty server's page has them: lines shown only once another is
// switched on ("Ask before writing") and the desktop app's own ("Companion", "Check for updates") are not here.
// Settings › Voices shows the voices and languages besides, which the search takes from the server (search-panel.ts).
// "Dictation"'s line (dictation-setup.ts) writes its label itself. Each label is read anew in the language in use
// (language.ts).
import { wording } from "./language/language";

export const LABELS = {
  settings: {
    get theme() {
      return wording("label-settings-theme");
    },
    get chatLayout() {
      return wording("label-settings-chat-layout");
    },
    get webPictures() {
      return wording("label-settings-web-pictures");
    },
    get appLanguage() {
      return wording("label-settings-app-language");
    },
    get language() {
      return wording("label-settings-language");
    },
    get providers() {
      return wording("label-settings-providers");
    },
    get chat() {
      return wording("label-settings-chat");
    },
    get images() {
      return wording("label-settings-images");
    },
    get voice() {
      return wording("label-settings-voice");
    },
    get search() {
      return wording("label-settings-search");
    },
    get dictation() {
      return wording("label-settings-dictation");
    },
    get web() {
      return wording("label-settings-web");
    },
    get files() {
      return wording("label-settings-files");
    },
    get commands() {
      return wording("label-settings-commands");
    },
    get imageGeneration() {
      return wording("label-settings-image-generation");
    },
    get app() {
      return wording("label-settings-app");
    },
    get dice() {
      return wording("label-settings-dice");
    },
    get folder() {
      return wording("label-settings-folder");
    },
    get written() {
      return wording("label-settings-written");
    },
    get coding() {
      return wording("label-settings-coding");
    },
    get trash() {
      return wording("label-settings-trash");
    },
    get backup() {
      return wording("label-settings-backup");
    },
    get restore() {
      return wording("label-settings-restore");
    },
    get cardsFolder() {
      return wording("label-settings-cards-folder");
    },
    get advanced() {
      return wording("label-settings-advanced");
    },
    get setup() {
      return wording("label-settings-setup");
    },
    get about() {
      return wording("label-settings-about");
    },
  },
  providers: {
    get thisComputer() {
      return wording("label-providers-this-computer");
    },
  },
  voices: {
    get model() {
      return wording("label-voices-model");
    },
    get speed() {
      return wording("label-voices-speed");
    },
    get english() {
      return wording("label-voices-english");
    },
  },
  advanced: {
    get background() {
      return wording("label-advanced-background");
    },
    get told() {
      return wording("label-advanced-told");
    },
    get describe() {
      return wording("label-advanced-describe");
    },
    get described() {
      return wording("label-advanced-described");
    },
    get interview() {
      return wording("label-advanced-interview");
    },
    get format() {
      return wording("label-advanced-format");
    },
    get history() {
      return wording("label-advanced-history");
    },
    get css() {
      return wording("label-advanced-css");
    },
  },
  coding: {
    get planner() {
      return wording("label-coding-planner");
    },
    get workers() {
      return wording("label-coding-workers");
    },
    get auditor() {
      return wording("label-coding-auditor");
    },
  },
  profile: {
    get name() {
      return wording("label-profile-name");
    },
    get picture() {
      return wording("label-profile-picture");
    },
    get password() {
      return wording("label-profile-password");
    },
  },
  server: {
    get network() {
      return wording("label-server-network");
    },
    get address() {
      return wording("label-server-address");
    },
    get mcp() {
      return wording("label-server-mcp");
    },
  },
};

/** The labels of the settings on each page, by its address, in the language in use. */
export const onPage = (): Record<string, string[]> => ({
  "#/settings": Object.values(LABELS.settings),
  "#/settings/providers": Object.values(LABELS.providers),
  "#/settings/voices": Object.values(LABELS.voices),
  "#/settings/advanced": Object.values(LABELS.advanced),
  "#/settings/tools/coding": Object.values(LABELS.coding),
  "#/account/profile": Object.values(LABELS.profile),
  "#/account/server": Object.values(LABELS.server),
});
