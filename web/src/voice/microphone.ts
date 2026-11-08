// The microphone asked for, for dictation and for a voice recorded, and why it cannot be used told in the app's
// words per case, never the browser's own text: none found; not allowed (in the desktop app by Windows' privacy
// settings, in a browser by its permission for the site); in use or broken; not offered at this address (a page
// over plain http, another device of the home network, has no `navigator.mediaDevices`).
import { inDesktop } from "../desktop";
import { wording } from "../language/language";

/** The microphone's sound, or an error whose message says why it cannot be used. */
export async function microphone(): Promise<MediaStream> {
  if (!navigator.mediaDevices?.getUserMedia) throw new Error(wording("mic-not-offered"));
  try {
    return await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (error) {
    throw new Error(failure(error));
  }
}

function failure(error: unknown): string {
  const name = error instanceof DOMException ? error.name : "";
  if (name === "NotFoundError" || name === "OverconstrainedError") return wording("mic-none");
  if (name === "NotAllowedError" || name === "SecurityError") return inDesktop() ? wording("mic-not-allowed-desktop") : wording("mic-not-allowed-browser");
  return wording("mic-not-started");
}
