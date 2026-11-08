//! A reading made faster or slower without its pitch changed (Settings ›
//! Voices, "Speed"): WSOLA. Frames of `FRAME` samples in a Hann window are laid
//! down every `HOP` samples of the output, each taken from the input `HOP ×
//! speed` further on, moved by up to `REACH` samples to where it best matches
//! what would have followed the frame before, so the waves join without a
//! click. It takes the sound as it comes (`push`) and hands on what is done;
//! `finish` hands the rest. At the speed 1 the sound goes through untouched.

const FRAME: usize = 960;
const HOP: usize = FRAME / 2;
const REACH: usize = 240;

pub struct Stretch {
    speed: f64,
    /// The input not yet left behind; its first sample is the input's `base`th.
    input: Vec<f32>,
    base: usize,
    /// Where the next frame would be taken without moving it, in the input.
    nominal: f64,
    /// Where the frame before was taken, in the input.
    before: Option<usize>,
    /// The frame before's second half, which the next one's first is added to.
    tail: Vec<f32>,
    window: Vec<f32>,
}

impl Stretch {
    /// `speed` is how much faster than spoken, 0.5 to 2; one outside is taken
    /// as the nearest end (at 0 nothing would ever be laid down).
    pub fn new(speed: f64) -> Self {
        let speed = if speed.is_nan() {
            1.0
        } else {
            speed.clamp(0.5, 2.0)
        };
        let window = (0..FRAME)
            .map(
                |at| { 0.5 - 0.5 * (std::f64::consts::TAU * at as f64 / FRAME as f64).cos() }
                    as f32,
            )
            .collect();
        Self {
            speed,
            input: Vec::new(),
            base: 0,
            nominal: 0.0,
            before: None,
            tail: vec![0.0; HOP],
            window,
        }
    }

    fn untouched(&self) -> bool {
        (self.speed - 1.0).abs() < 1e-6
    }

    /// Takes `sound` in; answers the output made of it so far.
    pub fn push(&mut self, sound: &[f32]) -> Vec<f32> {
        if self.untouched() {
            return sound.to_vec();
        }
        self.input.extend_from_slice(sound);
        let mut out = Vec::new();
        while self.base + self.input.len() >= self.nominal as usize + REACH + FRAME {
            self.step(&mut out);
        }
        out
    }

    /// The rest of the output, once the input has ended.
    pub fn finish(mut self) -> Vec<f32> {
        if self.untouched() {
            return Vec::new();
        }
        let end = self.base + self.input.len();
        self.input.resize(self.input.len() + REACH + FRAME, 0.0);
        let mut out = Vec::new();
        while (self.nominal as usize) < end {
            self.step(&mut out);
        }
        out.extend_from_slice(&self.tail);
        out
    }

    /// Lays down one frame, adding `HOP` samples to `out`.
    fn step(&mut self, out: &mut Vec<f32>) {
        let nominal = self.nominal as usize;
        let at = match self.before {
            None => nominal,
            Some(before) => self.best(before + HOP, nominal),
        };
        let frame = &self.input[at - self.base..at - self.base + FRAME];
        out.extend(
            (self.tail.iter().zip(&frame[..HOP]).zip(&self.window[..HOP]))
                .map(|((t, f), w)| t + f * w),
        );
        for ((t, f), w) in self
            .tail
            .iter_mut()
            .zip(&frame[HOP..])
            .zip(&self.window[HOP..])
        {
            *t = f * w;
        }
        self.before = Some(at);
        self.nominal += HOP as f64 * self.speed;
        // What no later frame can reach is let go.
        let keep = (self.nominal as usize).saturating_sub(REACH).min(at + HOP);
        if keep > self.base {
            self.input.drain(..keep - self.base);
            self.base = keep;
        }
    }

    /// The start near `nominal` whose first `HOP` samples are most like those from `natural` on.
    fn best(&self, natural: usize, nominal: usize) -> usize {
        let first = nominal.saturating_sub(REACH).max(self.base);
        let last = nominal + REACH;
        let wanted = &self.input[natural - self.base..natural - self.base + HOP];
        // Each start's likeness once, as its sound's correlation with the wanted, so a louder start does not win alone.
        let score = |start: usize| -> f32 {
            let from = &self.input[start - self.base..start - self.base + HOP];
            let (product, energy) = from
                .iter()
                .zip(wanted)
                .fold((0.0, 0.0), |(p, e), (x, y)| (p + x * y, e + x * x));
            product / (energy.sqrt() + 1e-6)
        };
        (first..=last)
            .map(|start| (score(start), start))
            .max_by(|a, b| a.0.total_cmp(&b.0))
            .map_or(nominal, |(_, start)| start)
    }
}

#[cfg(test)]
mod tests {
    use crate::stretch::Stretch;

    fn tone(count: usize) -> Vec<f32> {
        (0..count)
            .map(|at| (at as f32 * 220.0 * std::f32::consts::TAU / 24_000.0).sin() * 0.5)
            .collect()
    }

    /// Upward zero crossings per sample.
    fn pitch(sound: &[f32]) -> f64 {
        let up = sound
            .windows(2)
            .filter(|w| w[0] < 0.0 && w[1] >= 0.0)
            .count();
        up as f64 / sound.len() as f64
    }

    /// The sound stretched at `speed`, given in pieces as the model hands them on.
    fn stretched(sound: &[f32], speed: f64) -> Vec<f32> {
        let mut stretch = Stretch::new(speed);
        let mut out = Vec::new();
        for piece in sound.chunks(3_840) {
            out.extend(stretch.push(piece));
        }
        out.extend(stretch.finish());
        out
    }

    #[test]
    fn faster_is_shorter_and_slower_longer_at_the_same_pitch() {
        let sound = tone(48_000);
        for speed in [0.5, 2.0, 1.3] {
            let out = stretched(&sound, speed);
            let length = out.len() as f64 / (sound.len() as f64 / speed);
            assert!((0.97..1.05).contains(&length), "{speed}: {length}");
            // The middle, away from the fade in and out.
            let middle = &out[2_000..out.len() - 2_000];
            let ratio = pitch(middle) / pitch(&sound);
            assert!((0.97..1.03).contains(&ratio), "{speed}: {ratio}");
        }
    }

    #[test]
    fn a_speed_outside_half_to_twice_is_taken_as_the_nearest_end() {
        let sound = tone(24_000);
        assert_eq!(stretched(&sound, 0.0), stretched(&sound, 0.5));
        assert_eq!(stretched(&sound, 9.0), stretched(&sound, 2.0));
    }

    #[test]
    fn at_the_speed_one_the_sound_goes_through_untouched() {
        let sound = tone(5_000);
        assert_eq!(stretched(&sound, 1.0), sound);
    }
}
