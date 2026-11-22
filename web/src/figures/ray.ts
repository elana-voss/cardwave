// What a ray meets on a figure, nearest first (`meet`), quickly enough for a click on a figure of 800,000 triangles.
// A plain mesh is tested by three.js; a skinned one here, since three.js skins all three corners of every triangle
// it tests and can only skip a whole mesh by bounds measured in its first pose (half a second a click on such a
// figure, 170b). Here a skinned mesh's triangles are grouped once by the bone that pulls each corner most, each group
// with the sphere round its corners in that bone's own space; a click moves each sphere with its bone as posed now,
// tests only the groups whose sphere the ray meets and skins each corner once. The groups are made when the figure
// is placed (`prepare`), not at its first click.
//
// Traps: a corner pulled by several bones lies between where each would carry it, and a face shape moves it, so each
// leaf's sphere is widened by as far as these can take its corners (`reach`, a turn of a joint up to half a round;
// a bone moved, not turned, past that is not covered), and every sphere by `SLACK`. A look drawn on one side is met
// only there, as by three.js. The skinned mesh's own bounds are neither read nor measured.
import { BackSide, Box3, type BufferAttribute, DoubleSide, type Intersection, type Material, Matrix4, type Mesh, type Object3D, type Raycaster, type SkinnedMesh, Sphere, Vector3 } from "three";

/** Triangles of a skinned mesh and the sphere round their corners in their bone's space: either two halves or the
 * triangles themselves. */
interface Node {
  sphere: Sphere;
  halves?: [Node, Node];
  triangles?: Uint32Array;
}

/** A skinned mesh's triangles moved mostly by one bone, as a tree of halves in that bone's space. */
interface Group {
  bone: number;
  root: Node;
}

/** A skinned mesh's groups, and its corners as skinned at click number `stamp` (one per corner). */
interface Skin {
  groups: Group[];
  corners: Float32Array;
  stamp: Uint32Array;
}

/** How much wider than its corners' spheres a group counts as met, as a share of the group's size: corners pulled by
 * more than one bone lie between where each would carry them. */
const SLACK = 0.1;
/** At most this many triangles a node of a group's tree holds without halves. */
const LEAF = 64;
const skins = new WeakMap<SkinnedMesh, Skin>();
let click = 0;

/** Groups the triangles of each skinned mesh in `root` now (a figure of 800,000 triangles: about 400 ms), so that its
 * first click does not wait on it; one not grouped here is grouped at the first click that meets it. */
export function prepare(root: Object3D): void {
  root.traverse((node) => {
    const skinned = node as SkinnedMesh;
    if (skinned.isSkinnedMesh && !skins.has(skinned)) group(skinned);
  });
}

/** What `raycaster`'s ray meets of `root` and the meshes in it, nearest first; of a skinned mesh, its nearest. */
export function meet(raycaster: Raycaster, root: Object3D): Intersection[] {
  click += 1;
  const hits: Intersection[] = [];
  root.traverse((node) => {
    const skinned = node as SkinnedMesh;
    if (skinned.isSkinnedMesh) {
      const hit = meetSkinned(raycaster, skinned);
      if (hit) hits.push(hit);
    } else if ((node as Mesh).isMesh) raycaster.intersectObject(node, false, hits);
  });
  return hits.sort((a, b) => a.distance - b.distance);
}

/** The nearest triangle of `mesh` posed as now that the ray meets, testing only the leaves whose sphere it meets. */
function meetSkinned(raycaster: Raycaster, mesh: SkinnedMesh): Intersection | null {
  const skin = skins.get(mesh) ?? group(mesh);
  const { ray, near, far } = raycaster;
  const index = mesh.geometry.index;
  const toWorld = new Matrix4().multiplyMatrices(mesh.matrixWorld, mesh.bindMatrixInverse);
  const [toBone, local, sphere, met, a, b, c] = [new Matrix4(), ray.clone(), new Sphere(), new Vector3(), new Vector3(), new Vector3(), new Vector3()];
  const corner = (triangle: number, k: number, into: Vector3) => skinnedCorner(mesh, skin, index ? index.getX(triangle * 3 + k) : triangle * 3 + k, into);
  let best: Intersection | null = null;
  const test = (triangles: Uint32Array) => {
    for (const triangle of triangles) {
      // As three.js casts: a look drawn on one side is met only there.
      const side = drawnWith(mesh, triangle).side;
      corner(triangle, 0, a);
      corner(triangle, 2, c);
      const [first, last] = side === BackSide ? [c, a] : [a, c];
      if (!ray.intersectTriangle(first, corner(triangle, 1, b), last, side !== DoubleSide, met)) continue;
      const distance = ray.origin.distanceTo(met);
      if (distance < near || distance > far || (best && distance >= best.distance)) continue;
      best = { distance, point: met.clone(), object: mesh, faceIndex: triangle, face: { a: 0, b: 0, c: 0, normal: new Vector3(), materialIndex: lookOf(mesh, triangle) } };
    }
  };
  for (const { bone, root } of skin.groups) {
    const node = mesh.skeleton.bones[bone];
    if (!node) continue;
    local.copy(ray).applyMatrix4(toBone.multiplyMatrices(toWorld, node.matrixWorld).invert());
    const slack = root.sphere.radius * SLACK;
    const walk = (at: Node) => {
      sphere.copy(at.sphere).radius += slack;
      if (!local.intersectsSphere(sphere)) return;
      if (at.triangles) test(at.triangles);
      else for (const half of at.halves!) walk(half);
    };
    walk(root);
  }
  return best;
}

/** Corner `i` of `mesh` as skinned now, in the world, skinned once per click. */
function skinnedCorner(mesh: SkinnedMesh, skin: Skin, i: number, into: Vector3): Vector3 {
  if (skin.stamp[i] !== click) {
    mesh.getVertexPosition(i, into).applyMatrix4(mesh.matrixWorld).toArray(skin.corners, i * 3);
    skin.stamp[i] = click;
  }
  return into.fromArray(skin.corners, i * 3);
}

/** The look (material's index) triangle `triangle` of `mesh` is drawn with. */
function lookOf(mesh: SkinnedMesh, triangle: number): number {
  if (!Array.isArray(mesh.material as Material | Material[])) return 0;
  const start = triangle * 3;
  return mesh.geometry.groups.find((one) => start >= one.start && start < one.start + one.count)?.materialIndex ?? 0;
}

/** The material triangle `triangle` of `mesh` is drawn with. */
function drawnWith(mesh: SkinnedMesh, triangle: number): Material {
  const material = mesh.material as Material | Material[];
  return Array.isArray(material) ? (material[lookOf(mesh, triangle)] ?? material[0]!) : material;
}

/** `mesh`'s triangles grouped by the bone that pulls each corner most, once; a triangle is in each of its corners'. */
function group(mesh: SkinnedMesh): Skin {
  const { geometry } = mesh;
  const position = geometry.attributes.position as BufferAttribute;
  const indices = geometry.attributes.skinIndex as BufferAttribute;
  const weights = geometry.attributes.skinWeight as BufferAttribute;
  const pulls = new Int32Array(position.count);
  for (let i = 0; i < position.count; i++) {
    let most = 0;
    for (let k = 1; k < 4; k++) if (weights.getComponent(i, k) > weights.getComponent(i, most)) most = k;
    pulls[i] = indices.getComponent(i, most);
  }
  const far = reach(mesh, pulls);
  const index = geometry.index;
  const count = (index ? index.count : position.count) / 3;
  const lists = new Map<number, number[]>();
  for (let t = 0; t < count; t++) {
    const [a, b, c] = [0, 1, 2].map((k) => pulls[index ? index.getX(t * 3 + k) : t * 3 + k]!) as [number, number, number];
    for (const bone of a === b ? (b === c ? [a] : [a, c]) : a === c || b === c ? [a, b] : [a, b, c]) (lists.get(bone) ?? lists.set(bone, []).get(bone)!).push(t);
  }
  const groups = [...lists].map(([bone, triangles]) => ({ bone, root: tree(mesh, bone, Uint32Array.from(triangles), far) }));
  const skin = { groups, corners: new Float32Array(position.count * 3), stamp: new Uint32Array(position.count) };
  skins.set(mesh, skin);
  return skin;
}

/** How far each corner of `mesh` may lie from where the bone pulling it most (`pulls`) carries it, in the mesh's own
 * units: each other bone pulling it by its weight times twice the corner's distance from the farther of the two bones'
 * joints (as far as a turn of the joint between them can move it), and its face shapes by their longest move. */
function reach(mesh: SkinnedMesh, pulls: Int32Array): Float32Array {
  const { geometry, skeleton } = mesh;
  const position = geometry.attributes.position as BufferAttribute;
  const indices = geometry.attributes.skinIndex as BufferAttribute;
  const weights = geometry.attributes.skinWeight as BufferAttribute;
  const joints = skeleton.boneInverses.map((inverse) => new Vector3().setFromMatrixPosition(new Matrix4().multiplyMatrices(inverse, mesh.bindMatrix).invert()));
  const far = new Float32Array(position.count);
  const [corner, moved] = [new Vector3(), new Vector3()];
  for (let i = 0; i < position.count; i++) {
    corner.fromBufferAttribute(position, i);
    const own = joints[pulls[i]!];
    for (let k = 0; k < 4; k++) {
      const [bone, weight] = [indices.getComponent(i, k), weights.getComponent(i, k)];
      const other = joints[bone];
      if (bone === pulls[i] || weight <= 0 || !other || !own) continue;
      far[i]! += weight * 2 * Math.max(corner.distanceTo(other), corner.distanceTo(own));
    }
  }
  for (const shape of geometry.morphAttributes.position ?? []) {
    for (let i = 0; i < position.count; i++) {
      moved.fromBufferAttribute(shape, i);
      if (!geometry.morphTargetsRelative) moved.sub(corner.fromBufferAttribute(position, i));
      far[i] = Math.max(far[i]!, moved.length());
    }
  }
  return far;
}

/** `triangles` of `mesh` as a tree in bone `bone`'s own space, as bound, halved across their longest side; each leaf's
 * sphere widened by the farthest `far` (`reach`) of its corners. */
function tree(mesh: SkinnedMesh, bone: number, triangles: Uint32Array, far: Float32Array): Node {
  const toBone = new Matrix4().multiplyMatrices(mesh.skeleton.boneInverses[bone] ?? new Matrix4(), mesh.bindMatrix);
  const position = mesh.geometry.attributes.position as BufferAttribute;
  const index = mesh.geometry.index;
  const corners = new Float32Array(triangles.length * 9);
  const widen = new Float32Array(triangles.length);
  const scale = toBone.getMaxScaleOnAxis();
  const point = new Vector3();
  triangles.forEach((t, n) => {
    for (let k = 0; k < 3; k++) {
      const i = index ? index.getX(t * 3 + k) : t * 3 + k;
      point.fromBufferAttribute(position, i).applyMatrix4(toBone).toArray(corners, n * 9 + k * 3);
      widen[n] = Math.max(widen[n]!, far[i]! * scale);
    }
  });
  const order = Uint32Array.from(triangles.keys());
  const middle = (n: number, axis: number) => corners[n * 9 + axis]! + corners[n * 9 + 3 + axis]! + corners[n * 9 + 6 + axis]!;
  const build = (from: number, to: number): Node => {
    if (to - from <= LEAF) return leaf(corners, widen, order.subarray(from, to), triangles);
    const box = new Box3();
    for (let i = from; i < to; i++) box.expandByPoint(point.set(middle(order[i]!, 0), middle(order[i]!, 1), middle(order[i]!, 2)));
    const size = box.getSize(point);
    const axis = size.x >= size.y && size.x >= size.z ? 0 : size.y >= size.z ? 1 : 2;
    const cut = box.min.getComponent(axis) + size.getComponent(axis) / 2;
    let split = from;
    for (let i = from; i < to; i++) if (middle(order[i]!, axis) < cut) [order[i], order[split++]] = [order[split]!, order[i]!];
    if (split === from || split === to) split = (from + to) >> 1;
    const halves: [Node, Node] = [build(from, split), build(split, to)];
    return { sphere: halves[0].sphere.clone().union(halves[1].sphere), halves };
  };
  return build(0, triangles.length);
}

/** A node of the triangles at `order` (their places in `triangles`), its sphere round their `corners`, widened by the
 * most any of them is (`widen`). */
function leaf(corners: Float32Array, widen: Float32Array, order: Uint32Array, triangles: Uint32Array): Node {
  const [box, point] = [new Box3(), new Vector3()];
  const each = (seen: (point: Vector3) => void) => {
    for (const n of order) for (let k = 0; k < 3; k++) seen(point.fromArray(corners, n * 9 + k * 3));
  };
  each((one) => box.expandByPoint(one));
  const sphere = new Sphere(box.getCenter(new Vector3()), 0);
  each((one) => void (sphere.radius = Math.max(sphere.radius, one.distanceTo(sphere.center))));
  sphere.radius += Math.max(0, ...Array.from(order, (n) => widen[n]!));
  return { sphere, triangles: Uint32Array.from(order, (n) => triangles[n]!) };
}
