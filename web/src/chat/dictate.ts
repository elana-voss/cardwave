// Dictation in the message field: the microphone, a quiet icon button between the field and Send, shown while
// dictation's model is downloaded (Settings › Models › Dictation; `read`, at the start and on the event `dictation`)
// (Claude). Pressed, it records from the microphone: while it records the button is red and says "Stop dictating", and it stops by
// itself after `LONGEST` seconds. Each stretch said up to a pause (pauses.ts), and the rest once pressed again, goes
// to the server as a WAV at `RATE` (../voice/wav.ts), one after another, and its words are put in at the field's cursor, a
// space between them and words beside, as if typed (`input` is sent, so the field's unsaved text and "+"'s lines
// follow); after the recording the button waits for the last. Traps: a page that is no secure
// place (another device of the home network over http) has no microphone, so the button is not shown there; the
// microphone is let go when recording ends, also by the browser, and when the field leaves the page (another tab
// shown, a chat left), whose last words still go into the field (G4); after each hearing the model's state is read again.
import { getDictation, hear, loadDictation } from "../api/client";
import { announce, el, reason } from "../dom";
import { icon } from "../icons";
import { microphone } from "../voice/microphone";
import { resampled, wav } from "../voice/wav";
import { Pauses } from "./pauses";
import { wording } from "../language/language";

/** The rate the model hears at, a second. */
const RATE = 16_000;
/** The longest recording, in seconds. */
export const LONGEST = 120;

/** `text` put into `field` at its cursor, with a space on each side where a word stands beside it. */
export function inserted(value: string, start: number, end: number, text: string): { value: string; at: number } {
  const before = value.slice(0, start);
  const after = value.slice(end);
  const words = (before && !/\s$/.test(before) ? " " : "") + text + (after && !/^\s/.test(after) ? " " : "");
  return { value: before + words + after, at: before.length + words.length };
}

/** The microphone button of `field`; `read` asks the server anew whether dictation's model is there. */
export function dictateButton(field: HTMLTextAreaElement): { node: HTMLButtonElement; read(): void } {
  const button = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-lg dictate" }, icon("mic"));
  const label = (text: string) => {
    button.ariaLabel = text;
    button.title = text;
  };
  label(wording("dictate-dictate"));
  button.hidden = true;
  const read = () => {
    if (!navigator.mediaDevices?.getUserMedia) return;
    getDictation().then((model) => {
      if (!end) button.hidden = model.state !== "ready";
    }, () => {});
  };
  /** Ends the recording under way, if one is. */
  let end: (() => void) | null = null;
  const put = (text: string) => {
    const { value, at } = inserted(field.value, field.selectionStart, field.selectionEnd, text);
    field.value = value;
    field.setSelectionRange(at, at);
    field.dispatchEvent(new Event("input", { bubbles: true }));
    if (field.isConnected) field.focus();
  };
  const record = async () => {
    // The model loads while the user speaks (a first load took 26 s); a failure shows at the hearing.
    loadDictation().catch(() => {});
    const stream = await microphone();
    const sound = new AudioContext();
    void sound.resume();
    const rate = sound.sampleRate;
    const source = sound.createMediaStreamSource(stream);
    // Deprecated, but in every browser and without a module of its own; its sound out is silence.
    const taker = sound.createScriptProcessor(2048, 1, 1);
    const pauses = new Pauses(rate);
    /** The stretches said, heard one after another so their words keep their order. */
    let heard = Promise.resolve();
    let wrote = false;
    const send = (said: Float32Array<ArrayBuffer>) => {
      heard = heard
        .then(() => resampled(said, rate, RATE))
        .then((samples) => hear(wav(samples, RATE)))
        .then(({ text }) => {
          // Also into a field out of the page: a tab out of view keeps it, and a chat left keeps it as its unsaved text.
          if (!text) return;
          put(text);
          wrote = true;
        })
        .catch((error: unknown) => announce(wording("dictate-dictation-failed", { reason: reason(error) })));
    };
    taker.onaudioprocess = (event) => {
      const said = pauses.add(event.inputBuffer.getChannelData(0));
      if (said) send(said);
    };
    const longest = setTimeout(() => end?.(), LONGEST * 1000);
    const gone = setInterval(() => !button.isConnected && end?.(), 1000);
    end = () => {
      end = null;
      clearTimeout(longest);
      clearInterval(gone);
      taker.onaudioprocess = null;
      source.disconnect();
      taker.disconnect();
      for (const track of stream.getTracks()) track.stop();
      void sound.close();
      button.classList.remove("recording");
      const said = pauses.rest();
      if (said) send(said);
      button.disabled = true;
      label(wording("dictate-writing-what-was-said"));
      void heard.then(() => {
        if (!wrote && button.isConnected) announce(wording("dictate-nothing-was-heard"));
        reset();
        // The model may have been removed meanwhile.
        read();
      });
    };
    // The browser ends the recording itself where the microphone is unplugged.
    for (const track of stream.getTracks()) track.onended = () => end?.();
    source.connect(taker);
    taker.connect(sound.destination);
    button.classList.add("recording");
    label(wording("dictate-stop-dictating"));
  };
  const reset = () => {
    button.disabled = false;
    label(wording("dictate-dictate"));
  };
  button.onclick = () => {
    if (end) return end();
    button.disabled = true;
    void record()
      .catch((error: unknown) => announce(reason(error)))
      .finally(() => (button.disabled = false));
  };
  read();
  return { node: button, read };
}
