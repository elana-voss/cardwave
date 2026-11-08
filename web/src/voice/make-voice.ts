// The dialog "Make a voice from a recording" (board "MakeVoice"), opened from Settings › Voices: Name; the box
// Recording, which says "Record" until something is recorded (Claude), while recording a red dot, the time, a
// red bar filling to `LONGEST` seconds, where it stops by itself, and Stop, then play back, the time and "Record
// again"; the grey hint; "Make voice" (once a recording or a file is there), "Choose a file" (WAV or MP3, which
// takes the recording's place), Cancel, and the grey line on the right to use a voice. What is recorded or chosen
// becomes a WAV at the voice's rate (wav.ts) before it is sent; the server prepares it as the shipped
// recordings are and refuses one too short, saying so in the dialog. Closing it stops the microphone.
import { makeVoice } from "../api/client";
import { el, noticeBox, oneAtATime, reason } from "../dom";
import { dialog } from "../dialogs";
import { icon } from "../icons";
import { LONGEST, SHORTEST, toWav } from "./wav";
import { wording } from "../language/language";

/** Seconds as the board writes them: "0:12". */
export const clock = (seconds: number) => `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;

/** Opens the dialog in `home`; the voice's sound is at `rate` a second; `made` is told once a voice is made. */
export function makeVoiceDialog(home: HTMLElement, rate: number, made: () => void): void {
  const name = el("input", { id: "made-voice-name", className: "field", type: "text", maxLength: 60, autocomplete: "off", placeholder: wording("make-voice-my-voice") });
  const box = el("div", { className: "recording flex ai-c g-12 bg-fill" });
  const why = noticeBox();
  const make = el("button", { type: "button", className: "primary btn btn-primary", disabled: true }, wording("make-voice-make-voice"));
  const file = el("input", { type: "file", accept: "audio/wav,audio/x-wav,audio/mpeg,.wav,.mp3", hidden: true });
  const choose = el("button", { type: "button", className: "btn btn-secondary", onclick: () => file.click() }, wording("make-voice-choose-a-file"));
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const attempt = oneAtATime(why);
  /** The recording or file as it is sent, and its length. */
  let taken: { file: Blob; seconds: number } | null = null;
  /** What stops the microphone while it records. */
  let stopRecording: (() => void) | null = null;
  let playing: HTMLAudioElement | null = null;

  const idle = () => {
    const record = el("button", { type: "button", className: "btn btn-secondary on-box" }, el("span", { className: "rec" }), wording("make-voice-record"));
    record.onclick = () => void attempt(start);
    box.replaceChildren(record);
  };
  const recorded = (sound: { file: Blob; seconds: number }) => {
    taken = sound;
    make.disabled = false;
    const back = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("make-voice-play-back") }, icon("play", 16));
    back.onclick = () => {
      if (playing) {
        playing.pause();
        playing = null;
        back.replaceChildren(icon("play", 16));
        return;
      }
      const url = URL.createObjectURL(sound.file);
      playing = new Audio(url);
      back.replaceChildren(icon("stop", 16));
      playing.onended = () => {
        playing = null;
        URL.revokeObjectURL(url);
        back.replaceChildren(icon("play", 16));
      };
      void playing.play();
    };
    const again = el("button", { type: "button", className: "btn btn-secondary on-box", onclick: () => void attempt(start) }, icon("mic", 16), wording("make-voice-record-again"));
    box.replaceChildren(back, el("span", { className: "recording-time" }, clock(sound.seconds)), el("div", { className: "bar" }), again);
  };
  const start = async () => {
    playing?.pause();
    playing = null;
    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (error) {
      throw new Error(wording("dictate-the-microphone-cannot-be", { reason: reason(error) }));
    }
    // The dialog closed while the window asked whether the microphone may be used.
    if (!shown.open) {
      for (const track of stream.getTracks()) track.stop();
      return;
    }
    // While it records, what was made before is not what "Make voice" would send.
    make.disabled = true;
    const recorder = new MediaRecorder(stream);
    const pieces: Blob[] = [];
    const began = Date.now();
    const time = el("span", { className: "recording-time" }, clock(0));
    const filled = el("div");
    const stop = el("button", { type: "button", className: "btn btn-secondary on-box" }, icon("stop", 16), wording("gen-stop"));
    box.replaceChildren(el("span", { className: "rec" }), time, el("div", { className: "bar recording-bar" }, filled), stop);
    const tick = setInterval(() => {
      const seconds = (Date.now() - began) / 1000;
      time.textContent = clock(seconds);
      filled.style.width = `${Math.min(100, (seconds * 100) / LONGEST)}%`;
      if (seconds >= LONGEST) end();
    }, 200);
    const end = () => {
      clearInterval(tick);
      stopRecording = null;
      if (recorder.state !== "inactive") recorder.stop();
      for (const track of stream.getTracks()) track.stop();
    };
    stopRecording = end;
    stop.onclick = end;
    recorder.ondataavailable = (event) => pieces.push(event.data);
    recorder.onstop = () =>
      void attempt(async () => {
        if (!box.isConnected) return;
        make.disabled = !taken;
        take(await toWav(new Blob(pieces, { type: recorder.mimeType }), rate));
      });
    recorder.start();
  };
  /** A sound recorded or chosen, too short or not. */
  const take = (sound: { file: Blob; seconds: number }) => {
    if (sound.seconds < SHORTEST) {
      // What was there before stays: the recording made, or "Record".
      if (taken) recorded(taken);
      else idle();
      throw new Error(wording("make-voice-the-recording-is-too", { SHORTEST }));
    }
    recorded(sound);
  };
  file.onchange = () => {
    const chosen = file.files?.[0];
    file.value = "";
    if (!chosen) return;
    void attempt(async () => {
      let sound;
      try {
        sound = await toWav(chosen, rate);
      } catch {
        throw new Error(wording("make-voice-cardwave-cant-read-choose", { name: chosen.name }));
      }
      take(sound);
    });
  };

  const shown = dialog(
    home,
    wording("voices-make"),
    el(
      "div",
      { className: "dlg-body make-voice" },
      el("div", { className: "fld" }, el("label", { className: "label", htmlFor: name.id }, wording("common-name")), name),
      el("div", { className: "fld" }, el("span", { className: "label" }, wording("make-voice-recording")), box, el("p", { className: "hint" }, wording("make-voice-a-short-recording-of", { LONGEST }))),
      why,
    ),
    el("div", { className: "dfoot f-col ai-st g-10" }, el("div", { className: "flex g-8" }, make, choose, cancel, file), el("p", { className: "hint m0" }, wording("make-voice-use-only-a-voice"))),
  );
  shown.classList.add("form-dialog");
  make.onclick = () =>
    void attempt(async () => {
      if (!name.value.trim()) throw new Error(wording("make-voice-give-the-voice-a"));
      await makeVoice(name.value, taken!.file);
      made();
      shown.close();
    });
  cancel.onclick = () => shown.close();
  shown.addEventListener("close", () => {
    stopRecording?.();
    playing?.pause();
  });
  idle();
  name.focus();
}
