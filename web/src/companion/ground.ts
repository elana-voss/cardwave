// Where a figure's lowest point is, in whatever pose its clips and their blends give it, cheaply enough for every
// frame (`Soles`): its skin's lowest point is one of each bone's outermost points in some direction, so only those
// are moved by the bones (`outermost`), about a thousand points of tens of thousands. `Ground` lowers or raises the
// figure each frame (figure.ts's `draw`) so that lying, landing, sitting or getting up it rests on the floor as
// standing does, and measures how fast each walk's feet go (`paceOf`), which body.ts walks at (milestone 160): one
// rule for every clip, size and set of animations, nothing set per clip.
//
// Traps: the skin is moved by its bones' world matrices, so the model's `updateMatrixWorld` comes first; a VRM's
// bones it draws are set from its normalized ones by its `update`, which comes before too.
import { type AnimationAction, AnimationMixer, type AnimationClip, type Box3, type Mesh, type Object3D, type SkinnedMesh, Vector3 } from "three";

/** The directions a bone's part of the skin is seen to reach out in: each axis, each edge and each corner of a cube. */
const DIRECTIONS: Vector3[] = [];
for (const x of [-1, 0, 1]) for (const y of [-1, 0, 1]) for (const z of [-1, 0, 1]) if (x || y || z) DIRECTIONS.push(new Vector3(x, y, z).normalize());

/** The points of `mesh`'s skin that reach out furthest in each of `DIRECTIONS`, among those each bone (the one
 * weighing most on it) moves; a mesh without bones, its own outermost points. As the vertices' indices. */
export function outermost(mesh: Mesh): number[] {
  const position = mesh.geometry.getAttribute("position");
  const best = new Map<number, { at: number[]; reach: number[] }>();
  const point = new Vector3();
  for (let i = 0; i < position.count; i++) {
    const bone = boneOf(mesh, i);
    point.fromBufferAttribute(position, i);
    let mine = best.get(bone);
    if (!mine) best.set(bone, (mine = { at: DIRECTIONS.map(() => i), reach: DIRECTIONS.map(() => -Infinity) }));
    for (let d = 0; d < DIRECTIONS.length; d++) {
      const reach = point.dot(DIRECTIONS[d]!);
      if (reach > mine.reach[d]!) [mine.reach[d], mine.at[d]] = [reach, i];
    }
  }
  return [...new Set([...best.values()].flatMap((mine) => mine.at))];
}

/** The index of the bone weighing most on `mesh`'s vertex `i`, among its skeleton's; -1 without bones. */
function boneOf(mesh: Mesh, i: number): number {
  const weights = mesh.geometry.getAttribute("skinWeight");
  const indices = mesh.geometry.getAttribute("skinIndex");
  let [most, bone] = [0, -1];
  if (weights && indices) {
    for (let k = 0; k < 4; k++) {
      const weight = weights.getComponent(i, k);
      if (weight > most) [most, bone] = [weight, indices.getComponent(i, k)];
    }
  }
  return bone;
}

/** The lowest point of a model's skin as it is posed now, from each mesh's `outermost` points. */
export class Soles {
  private readonly meshes: { mesh: Mesh; at: number[]; bones: (Object3D | null)[] }[] = [];
  private readonly point = new Vector3();

  constructor(model: Object3D) {
    model.traverse((part) => {
      const mesh = part as Mesh;
      if (!mesh.isMesh || !mesh.geometry.getAttribute("position")) return;
      const at = outermost(mesh);
      const skeleton = (mesh as SkinnedMesh).skeleton;
      this.meshes.push({ mesh, at, bones: at.map((i) => skeleton?.bones[boneOf(mesh, i)] ?? null) });
    });
  }

  /** The lowest point found last, in the world, which point of the skin it is, and the bone that moves it most
   * (null: a mesh without bones). */
  readonly at = new Vector3();
  which = "";
  bone: Object3D | null = null;

  /** The height in the world of the lowest point, the model's world matrices being up to date; Infinity without skin. */
  lowest(): number {
    let lowest = Infinity;
    for (const [m, { mesh, at, bones }] of this.meshes.entries()) {
      if (!mesh.visible) continue;
      for (const [k, i] of at.entries()) {
        // A skinned mesh's point is moved by its bones; a plain mesh's is where its file puts it.
        mesh.getVertexPosition(i, this.point).applyMatrix4(mesh.matrixWorld);
        if (this.point.y < lowest) {
          lowest = this.point.y;
          this.at.copy(this.point);
          this.bone = bones[k]!;
          this.which = `${m}:${i}`;
        }
      }
    }
    return lowest;
  }
}

/** How many frames a second a clip is looked at for where it rests, and for its feet's pace. */
const REST_FPS = 10;
const PACE_FPS = 30;

/** Rests a model's lowest point on the floor its standing pose stands on, frame by frame, and tells how fast each
 * walk's feet go. A clip that never touches the floor (lying, a VRM's clip made for a taller figure) is lowered by
 * the least its lowest point stays above the floor over the clip (`restOf`), so a jump, which starts and ends on the
 * floor, still leaves it; then whatever pose would sink is raised onto it. A clip held at one moment (a speed of 0)
 * rests by that moment. Each clip is looked at once, on its first use, by a mixer of its own, after which the pose
 * is put back as it was. */
export class Ground {
  private readonly soles: Soles;
  private readonly sampler: AnimationMixer;
  private readonly base: number;
  private readonly floor: number;
  private readonly height: number;
  private readonly rests = new Map<string, number>();
  private readonly paces = new Map<string, number>();

  /** `stood`: the model's box standing (figure.ts's `standing`), at its place as loaded; `humanoid`: a VRM's, which
   * copies the bones the clips move to those it draws. */
  constructor(
    private readonly model: Object3D,
    stood: Box3,
    private readonly humanoid: { update(): void } | null,
  ) {
    this.soles = new Soles(model);
    this.sampler = new AnimationMixer(model);
    this.base = model.position.y;
    this.floor = stood.min.y;
    this.height = stood.max.y - stood.min.y;
  }

  /** Lowers the model, posed now by the clips `playing` at their weights, by what lifts their clips off the floor,
   * then raises it where it would sink; its world matrices are up to date after. */
  settle(playing: ReadonlyMap<AnimationAction, number>): void {
    let shift = 0;
    for (const [action, weight] of playing) shift += weight * Math.max(0, this.restOf(action));
    this.model.position.y = this.base - shift;
    this.model.updateMatrixWorld(true);
    const low = this.soles.lowest();
    if (low < this.floor) {
      this.model.position.y += this.floor - low;
      this.model.updateMatrixWorld(true);
    }
  }

  /** How far above the floor `action`'s clip keeps the lowest point at least, over the clip, or at its moment where
   * it is held (a speed of 0); negative where it sinks. In the model's units. */
  restOf(action: AnimationAction): number {
    const clip = action.getClip();
    const held = action.timeScale === 0;
    const key = held ? `${clip.uuid}@${action.time}` : clip.uuid;
    let rest = this.rests.get(key);
    if (rest === undefined) {
      const times = held ? [action.time] : frames(clip.duration, REST_FPS);
      rest = Math.min(...this.sample(clip, times, () => this.soles.lowest())) - this.floor;
      this.rests.set(key, rest);
    }
    return rest;
  }

  /** How fast `clip`'s feet go backward while on the floor, in heights standing a second: the bone that moves its
   * lowest point (the foot on the floor, or its toes), while it stays the same, followed frame by frame (a figure
   * without bones, that point itself); the middle of those speeds, as a foot that drags or rolls is now and then
   * lowest while it swings forward. 0 where it never stays. */
  paceOf(clip: AnimationClip): number {
    let pace = this.paces.get(clip.uuid);
    if (pace === undefined) {
      const speeds: number[] = [];
      let before: { key: unknown; z: number } | null = null;
      const where = new Vector3();
      this.sample(clip, frames(clip.duration, PACE_FPS), () => {
        this.soles.lowest();
        const { bone } = this.soles;
        const key = bone ?? this.soles.which;
        const z = bone ? bone.getWorldPosition(where).z : this.soles.at.z;
        if (before?.key === key) speeds.push((before.z - z) * PACE_FPS);
        before = { key, z };
      });
      speeds.sort((a, b) => a - b);
      pace = speeds.length > 0 ? Math.abs(speeds[Math.floor(speeds.length / 2)]!) / this.height : 0;
      this.paces.set(clip.uuid, pace);
    }
    return pace;
  }

  /** `clip` posed at each of `times` (s), the model unturned at its place as loaded, and `each` asked of each pose;
   * then the model as it was. */
  private sample<T>(clip: AnimationClip, times: number[], each: () => T): T[] {
    const { position, rotation } = this.model;
    const [y, turn] = [position.y, rotation.clone()];
    position.y = this.base;
    rotation.set(0, 0, 0);
    const action = this.sampler.clipAction(clip).play();
    const answers = times.map((time) => {
      this.sampler.setTime(time);
      this.humanoid?.update();
      this.model.updateMatrixWorld(true);
      return each();
    });
    // Stopping puts back what the clip moved; the drawn bones follow.
    action.stop();
    this.sampler.uncacheClip(clip);
    this.humanoid?.update();
    position.y = y;
    rotation.copy(turn);
    this.model.updateMatrixWorld(true);
    return answers;
  }
}

/** The moments of a clip `duration` s long at `fps`, its first and last included. */
function frames(duration: number, fps: number): number[] {
  const count = Math.max(1, Math.round(duration * fps));
  return Array.from({ length: count + 1 }, (_, i) => (duration * i) / count);
}
