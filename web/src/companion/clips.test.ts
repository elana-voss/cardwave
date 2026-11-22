import { AnimationClip, AnimationMixer, LoopRepeat, Object3D } from "three";
import { describe, expect, it } from "vitest";
import { CARRIED, Clips, MOODS, ROBOT } from "./clips";

/** The model's clips by name, a second each, without tracks. */
const clips = () => new Clips(new AnimationMixer(new Object3D()), ["Idle", "Walking", "Jump", "Wave", "Yes"].map((name) => new AnimationClip(name, 1, [])), ROBOT);

describe("the figure's clips", () => {
  it("of the robot are there for the feelings it has a fitting one for: excited, surprised, angry, afraid", async () => {
    const { FEELINGS } = await import("./live");
    const robot = (feeling: keyof typeof FEELINGS) => ROBOT.clips?.[FEELINGS[feeling]];
    expect([robot("excited"), robot("surprised"), robot("angry"), robot("afraid")]).toEqual(["Dance", "Jump", "No", "Jump"]);
  });


  it("play a clip over the state's clip, and hand back to the clip of the state it is in by the gesture's end", () => {
    const figure = clips();
    figure.show("idle");
    expect(figure.play("waving")).toBe(1000);
    expect(figure.current).toBe("Wave");
    figure.update(0.5);
    // The figure began to walk meanwhile: that ends the clip played over it.
    figure.show("walking");
    expect(figure.current).toBe("Walking");
    expect(figure.play("head_nod_yes")).toBe(1000);
    figure.update(0.6);
    figure.update(0.6);
    expect(figure.current).toBe("Walking");
  });

  it("play a clip over and over for the time asked, and none the model lacks", () => {
    const figure = clips();
    figure.show("idle");
    expect(figure.play("waving", 2500)).toBe(2500);
    figure.update(1.5);
    expect(figure.current).toBe("Wave");
    figure.update(1.1);
    expect(figure.current).toBe("Idle");
    expect(figure.play("yawn")).toBe(0);
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

/** The carrier's clips, a second each but those `lengths` names, without tracks, and the mixer that plays them. */
function carried(random: () => number = () => 0, lengths: Record<string, number> = {}) {
  const mixer = new AnimationMixer(new Object3D());
  const names = Object.keys(CARRIED.moods ?? {});
  const all = names.map((name) => new AnimationClip(name, lengths[name] ?? 1, []));
  /** Each clip's weight in the pose, of those that have one. */
  const weights = () => Object.fromEntries(all.flatMap((clip) => {
    const action = mixer.existingAction(clip);
    return action?.isRunning() && action.getEffectiveWeight() > 0 ? [[clip.name, action.getEffectiveWeight()]] : [];
  }));
  return { figure: new Clips(mixer, all, CARRIED, random), weights };
}

const total = (weights: Record<string, number>) => Object.values(weights).reduce((sum, weight) => sum + weight, 0);

describe("one clip into the next", () => {
  it("sits on the floor by a longer blend, and gets back up through standing up", () => {
    const { figure } = carried();
    figure.show("idle");
    figure.show("sitting");
    expect(figure.current).toBe("sitting_idle");
    figure.show("talking");
    expect(figure.current).toBe("standing_up");
    figure.update(1.05);
    expect(figure.current).toBe("talking");
  });

  it("gets up from lying before it does what it is told, and plays it for as long", () => {
    const { figure } = carried();
    figure.show("sleeping");
    figure.update(1);
    expect(figure.play("waving")).toBe(2000);
    expect(figure.current).toBe("stand_up");
    figure.update(1.05);
    expect(figure.current).toBe("waving");
    figure.update(1);
    expect(figure.current).toBe("sleeping_idle");
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

  it("gets up on to where it is told without getting up again, and stays down while it lands", () => {
    const { figure } = carried(() => 0, { stand_up: 8.3, hard_landing: 2 });
    figure.show("sleeping");
    figure.update(1);
    figure.show("talking");
    figure.update(3);
    figure.show("idle");
    expect(figure.current).toBe("stand_up");
    figure.update(5.4);
    expect(figure.current).toBe("idle");
    figure.show("landing");
    figure.update(1.5);
    expect(figure.between).toBe(true);
    figure.update(0.6);
    expect(figure.between).toBe(false);
  });

  it("bounces in a pose of its own in the air, not lying, at once when thrown; the robot in its jump", () => {
    const { figure } = carried();
    figure.show("thrown");
    figure.update(0.5);
    figure.show("bouncing");
    expect(figure.current).toBe("hard_landing");
    expect(CARRIED.poses?.[figure.current!]?.[0]).toBe("air");
    expect(CARRIED.states.bouncing).toMatchObject({ speed: 0, at: 0 });
    expect(ROBOT.states.bouncing.clips).toEqual(["Jump"]);
  });
});

describe("a state's clips", () => {
  it("rotate, the calm ones while the figure feels nothing, then those of its mood at once", () => {
    const { figure } = carried();
    figure.show("idle");
    expect(figure.current).toBe("idle");
    figure.update(12.1);
    expect(figure.current).toBe("idle_2");
    figure.feel("sad");
    expect(figure.current).toBe("sad_idle");
    figure.update(12.1);
    expect(figure.current).toBe("sad_idle_2");
    // Its mood passes: calm again.
    figure.update(60);
    expect(figure.current).toBe("idle");
  });

  it("give way to the mood's after the feeling's own clip", () => {
    const { figure } = carried();
    figure.show("idle");
    figure.play("disappointed");
    figure.feel("sad");
    figure.update(1.1);
    expect(figure.current).toBe("sad_idle");
  });

  it("afraid, playful, bashful and tired each give the mood of their name", () => {
    for (const feeling of ["afraid", "playful", "bashful", "tired"] as const) expect(MOODS[feeling]).toBe(feeling);
  });

  it("each come, by a mood the figure takes or calm", () => {
    const taken = new Set(["", ...Object.values(MOODS)]);
    for (const [name, mood] of Object.entries(CARRIED.moods ?? {})) expect(`${name}: ${taken.has(mood) ? "" : mood}`).toBe(`${name}: `);
  });

  it("are every one the carrier's, and a clip told by name plays one of its versions", () => {
    const names = Object.keys(CARRIED.moods ?? {});
    for (const state of Object.values(CARRIED.states)) for (const clip of state.clips) expect(names).toContain(clip);
    const { figure } = carried(() => 0.99);
    figure.show("idle");
    figure.play("agreeing");
    expect(figure.current).toBe("agreeing_2");
  });
});
