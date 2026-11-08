// When the companion's figure reacts by itself to the hand and to time, apart from the window so a test runs it:
// `Reactions` asks the worker model once the figure stands again after the hand took it, and while it is left
// idle again and again, each a while (`gap`) after the last moves ended, never two such questions at once (one that
// cannot be asked yet waits for a later frame); where no model can be asked or its answer has no moves, the figure
// walks of its own (`wander`), but not when the hand took it meanwhile. `Clicks` startles the figure at a click that no press follows within the
// double-click's time.
//
// Traps: a press cancels a pending startle, so a click followed by a drag does not startle the figure afterwards.
import type { Occasion } from "../api/generated/Occasion";

/** Asks the worker model and has its moves done: whether it gave any; null where nothing can be asked (no companion). */
export type Ask = (occasion: Exclude<Occasion, "reply">) => Promise<boolean> | null;

export class Reactions {
  private handled = false;
  /** When the figure began to stand idle, and when it is asked then; null while it is not idle. */
  private idle: { due: number } | null = null;
  private asking = false;

  constructor(
    private readonly ask: Ask,
    private readonly wander: () => void,
    private readonly gap: () => number,
  ) {}

  /** The hand took the figure. */
  took(): void {
    this.handled = true;
  }

  /** The figure or its chat was used: being idle counts from now. */
  used(): void {
    this.idle = null;
  }

  /** Each frame the figure stands at rest at `now` (ms); `idle`: nothing else moves it or is used. */
  standing(idle: boolean, now: number): void {
    if (this.handled) {
      // Asked once it can be; without a model, not at all.
      if (this.asking) return;
      this.handled = false;
      return this.begin("handled");
    }
    if (!idle) return void (this.idle = null);
    this.idle ??= { due: now + this.gap() };
    if (now < this.idle.due || this.asking) return;
    this.idle = null;
    this.begin("alone");
  }

  /** Asks. A question about being idle that cannot be asked or gives no moves is a walk of its own, unless the hand
   * took the figure meanwhile. */
  private begin(occasion: Exclude<Occasion, "reply">): void {
    const asked = this.ask(occasion);
    if (!asked) return this.answered(occasion, false);
    this.asking = true;
    void asked
      .catch(() => false)
      .then((acted) => {
        this.asking = false;
        this.answered(occasion, acted);
      });
  }

  private answered(occasion: Exclude<Occasion, "reply">, acted: boolean): void {
    if (!acted && occasion === "alone" && !this.handled) this.wander();
  }
}

export class Clicks {
  private pending: ReturnType<typeof setTimeout> | undefined;

  constructor(
    private readonly startle: () => void,
    private readonly doubleMs: number,
  ) {}

  /** A press on the figure, or a double-click: no startle of an earlier click. */
  down(): void {
    clearTimeout(this.pending);
  }

  /** The press let go; a click (not a drag) startles once no second click has come. */
  up(dragged: boolean): void {
    clearTimeout(this.pending);
    if (!dragged) this.pending = setTimeout(this.startle, this.doubleMs);
  }
}
