// A voice's recording as the server takes it (`POST /api/voice/own`), and dictation's (`POST /api/dictation/hear`): a WAV file of 16-bit PCM, one channel.
// `toWav` makes one of what the window recorded or of a file chosen (WAV, MP3 or what else the browser
// decodes), at the voice's rate and cut at `LONGEST` seconds, so what is sent stays small; `wav` writes the
// file of samples, `resampled` brings samples to another rate (dictation's pieces, recorded at the microphone's).
// The server brings a voice's to its own form again (`voice::prepare`) and refuses one too short.

/** The longest recording kept, in seconds, and the shortest the server takes (`voice::LONGEST`, `voice::SHORTEST`). */
export const LONGEST = 30;
export const SHORTEST = 3;

/** `samples` (from -1 to 1) at `rate` a second as a WAV file of 16-bit PCM, one channel. */
export function wav(samples: Float32Array, rate: number): Blob {
  const data = samples.length * 2;
  const view = new DataView(new ArrayBuffer(44 + data));
  const text = (at: number, words: string) => [...words].forEach((c, i) => view.setUint8(at + i, c.charCodeAt(0)));
  text(0, "RIFF");
  view.setUint32(4, 36 + data, true);
  text(8, "WAVEfmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, data, true);
  samples.forEach((sample, at) => view.setInt16(44 + at * 2, Math.round(Math.max(-1, Math.min(1, sample)) * 32767), true));
  return new Blob([view.buffer], { type: "audio/wav" });
}

/** The sound of `file`, its channels made one, at `rate` a second and at most `longest` seconds, as a WAV file; with its length in seconds. */
export async function toWav(file: Blob, rate: number, longest = LONGEST): Promise<{ file: Blob; seconds: number }> {
  const sound = new AudioContext({ sampleRate: rate });
  try {
    const decoded = await sound.decodeAudioData(await file.arrayBuffer());
    const length = Math.min(decoded.length, longest * rate);
    const one = new Float32Array(length);
    for (let channel = 0; channel < decoded.numberOfChannels; channel++) {
      const samples = decoded.getChannelData(channel);
      for (let at = 0; at < length; at++) one[at] += samples[at] / decoded.numberOfChannels;
    }
    return { file: wav(one, rate), seconds: length / rate };
  } finally {
    void sound.close();
  }
}

/** `samples` (one channel) at `from` a second brought to `to` a second. */
export async function resampled(samples: Float32Array<ArrayBuffer>, from: number, to: number): Promise<Float32Array> {
  if (from === to) return samples;
  const sound = new OfflineAudioContext(1, Math.max(1, Math.ceil((samples.length * to) / from)), to);
  const buffer = sound.createBuffer(1, samples.length, from);
  buffer.copyToChannel(samples, 0);
  const source = sound.createBufferSource();
  source.buffer = buffer;
  source.connect(sound.destination);
  source.start();
  return (await sound.startRendering()).getChannelData(0);
}
