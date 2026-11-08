import { AnimationClip, AnimationMixer, LoopRepeat, Object3D } from "three";
import { describe, expect, it } from "vitest";
import { CARRIED, Clips, ROBOT } from "./clips";

/** The model's clips by name, a second each, without tracks. */
const clips = () => new Clips(new AnimationMixer(new Object3D()), ["Idle", "Walking", "Jump", "Wave", "Yes"].map((name) => new AnimationClip(name, 1, [])), ROBOT);

describe("the figure's clips", () => {
  it("play a clip over the state's clip, and hand back to the clip of the state it is in by the gesture's end", () => {
    const figure = clips();
    figure.show("idle");
    expect(figure.play("wave")).toBe(1000);
    expect(figure.current).toBe("Wave");
    figure.update(0.5);
    // The figure began to walk meanwhile: that ends the clip played over it.
    figure.show("walking");
    expect(figure.current).toBe("Walking");
    expect(figure.play("nod")).toBe(1000);
    figure.update(0.6);
    figure.update(0.6);
    expect(figure.current).toBe("Walking");
  });

  it("play a clip over and over for the time asked, and none the model lacks", () => {
    const figure = clips();
    figure.show("idle");
    expect(figure.play("wave", 2500)).toBe(2500);
    figure.update(1.5);
    expect(figure.current).toBe("Wave");
    figure.update(1.1);
    expect(figure.current).toBe("Idle");
    expect(figure.play("stretch")).toBe(0);
  });

  it("hand back to the state's clip running on when the clip played is the state's own", () => {
    const mixer = new AnimationMixer(new Object3D());
    const idle = new AnimationClip("Idle", 1, []);
    const figure = new Clips(mixer, [idle, new AnimationClip("Wave", 1, [])], ROBOT);
    figure.show("idle");
    expect(figure.play("thinking")).toBe(1000);
    figure.update(1.1);
    figure.show("idle");
    const action = mixer.existingAction(idle)!;
    expect(action.loop).toBe(LoopRepeat);
    expect(action.paused).toBe(false);
  });
});

/** The carrier's clips, a second each, without tracks, and the mixer that plays them. */
function carried() {
  const mixer = new AnimationMixer(new Object3D());
  const names = [...new Set([...Object.values(CARRIED.states).map((state) => state.clip), ...Object.values(CARRIED.clips)])];
  const all = names.map((name) => new AnimationClip(name, 1, []));
  /** Each clip's weight in the pose, of those that have one. */
  const weights = () => Object.fromEntries(all.flatMap((clip) => {
    const action = mixer.existingAction(clip);
    return action?.isRunning() && action.getEffectiveWeight() > 0 ? [[clip.name, action.getEffectiveWeight()]] : [];
  }));
  return { figure: new Clips(mixer, all, CARRIED), weights };
}

const total = (weights: Record<string, number>) => Object.values(weights).reduce((sum, weight) => sum + weight, 0);

describe("one clip into the next", () => {
  it("goes from standing to sitting through sitting down, and back up through standing up", () => {
    const { figure } = carried();
    figure.show("idle");
    figure.show("sitting");
    expect(figure.current).toBe("sit_down");
    figure.update(1.05);
    expect(figure.current).toBe("sitting");
    figure.show("talking");
    expect(figure.current).toBe("stand_up");
    figure.update(1.05);
    expect(figure.current).toBe("talking");
  });

  it("gets up from lying before it does what it is told, and plays it for as long", () => {
    const { figure } = carried();
    figure.show("sleeping");
    figure.update(1);
    expect(figure.play("wave")).toBe(2000);
    expect(figure.current).toBe("get_up");
    figure.update(1.05);
    expect(figure.current).toBe("wave");
    figure.update(1);
    // Back to its state: it lies down again, by sitting first.
    expect(figure.current).toBe("sit_down");
  });

  it("blends from the pose it has, its weights adding up to one, however often it is changed mid-blend", () => {
    const { figure, weights } = carried();
    figure.show("idle");
    figure.update(1);
    expect(weights()).toEqual({ idle: 1 });
    for (const state of ["walking", "talking", "listening", "dragged", "idle"] as const) {
      const before = weights();
      figure.show(state);
      // A change moves nothing at once.
      expect(weights()).toEqual(before);
      figure.update(0.1);
      expect(total(weights())).toBeCloseTo(1);
    }
    figure.update(2);
    expect(weights()).toEqual({ idle: 1 });
  });

  it("bounces lying at once when thrown, not by sitting down first", () => {
    const { figure } = carried();
    figure.show("thrown");
    figure.update(0.5);
    figure.show("bouncing");
    expect(figure.current).toBe("lying");
  });

  it("stands once landing has played out, so sitting from there sits down first", () => {
    const { figure } = carried();
    figure.show("landing");
    figure.update(2);
    figure.show("sitting");
    expect(figure.current).toBe("sit_down");
  });
});
