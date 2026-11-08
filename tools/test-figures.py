"""Writes the browser tests' 3D figures into e2e/figures/: a mannequin of boxes, one per bone, standing in T-pose,
in three skeletons: `mannequin.vrm` (VRoid's bone names, made a VRM 1.0 by its `VRMC_vrm` humanoid),
`mixamo.glb` and `mixamo.fbx` (Mixamo's names, no VRM) and `odd.glb` (a tail of bones no human skeleton has, which is refused).

Run once, with Blender 5.2: blender -b --python tools/test-figures.py
"""

import json
import pathlib
import struct

import bpy

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "e2e" / "figures"

# Each bone: its VRM humanoid name, its parent's, head and tail (Blender's metres, the figure facing -Y, its left +X).
BONES = [
    ("hips", None, (0, 0, 0.95), (0, 0, 1.05)),
    ("spine", "hips", (0, 0, 1.05), (0, 0, 1.2)),
    ("chest", "spine", (0, 0, 1.2), (0, 0, 1.32)),
    ("upperChest", "chest", (0, 0, 1.32), (0, 0, 1.45)),
    ("neck", "upperChest", (0, 0, 1.45), (0, 0, 1.55)),
    ("head", "neck", (0, 0, 1.55), (0, 0, 1.78)),
]
for side, x in (("left", 1), ("right", -1)):
    BONES += [
        (f"{side}Shoulder", "upperChest", (0.03 * x, 0, 1.42), (0.15 * x, 0, 1.42)),
        (f"{side}UpperArm", f"{side}Shoulder", (0.15 * x, 0, 1.42), (0.42 * x, 0, 1.42)),
        (f"{side}LowerArm", f"{side}UpperArm", (0.42 * x, 0, 1.42), (0.66 * x, 0, 1.42)),
        (f"{side}Hand", f"{side}LowerArm", (0.66 * x, 0, 1.42), (0.78 * x, 0, 1.42)),
        (f"{side}UpperLeg", "hips", (0.1 * x, 0, 0.95), (0.1 * x, 0, 0.52)),
        (f"{side}LowerLeg", f"{side}UpperLeg", (0.1 * x, 0, 0.52), (0.1 * x, 0, 0.09)),
        (f"{side}Foot", f"{side}LowerLeg", (0.1 * x, 0, 0.09), (0.1 * x, -0.12, 0.02)),
        (f"{side}Toes", f"{side}Foot", (0.1 * x, -0.12, 0.02), (0.1 * x, -0.18, 0.02)),
    ]

MIXAMO = {"hips": "Hips", "spine": "Spine", "chest": "Spine1", "upperChest": "Spine2", "neck": "Neck", "head": "Head"}
VROID = {"hips": "C_Hips", "spine": "C_Spine", "chest": "C_Chest", "upperChest": "C_UpperChest", "neck": "C_Neck", "head": "C_Head"}
for side in ("left", "right"):
    s, S = side[0].upper(), side.capitalize()
    MIXAMO.update({f"{side}Shoulder": f"{S}Shoulder", f"{side}UpperArm": f"{S}Arm", f"{side}LowerArm": f"{S}ForeArm", f"{side}Hand": f"{S}Hand",
                   f"{side}UpperLeg": f"{S}UpLeg", f"{side}LowerLeg": f"{S}Leg", f"{side}Foot": f"{S}Foot", f"{side}Toes": f"{S}ToeBase"})
    VROID.update({f"{side}Shoulder": f"{s}_Shoulder", f"{side}UpperArm": f"{s}_UpperArm", f"{side}LowerArm": f"{s}_LowerArm", f"{side}Hand": f"{s}_Hand",
                  f"{side}UpperLeg": f"{s}_UpperLeg", f"{side}LowerLeg": f"{s}_LowerLeg", f"{side}Foot": f"{s}_Foot", f"{side}Toes": f"{s}_ToeBase"})


def mannequin(names: dict, colour: tuple) -> None:
    """A fresh scene with the mannequin, its bones named by `names`."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    data = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in BONES:
        bone = data.edit_bones.new(names[name])
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = data.edit_bones[names[parent]]
    bpy.ops.object.mode_set(mode="OBJECT")
    material = bpy.data.materials.new("Skin")
    material.diffuse_color = (*colour, 1)
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
    verts, faces, groups = [], [], []
    for name, _, head, tail in BONES:
        if name.endswith("Toes"):
            continue
        lo = [min(a, b) - 0.04 for a, b in zip(head, tail)]
        hi = [max(a, b) + 0.04 for a, b in zip(head, tail)]
        if name == "head":
            lo, hi = [-0.09, -0.1, 1.55], [0.09, 0.1, 1.78]
        base = len(verts)
        verts += [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        faces += [tuple(base + i for i in face) for face in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))]
        groups.append((names[name], range(base, base + 8)))
    mesh = bpy.data.meshes.new("Body")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material)
    body = bpy.data.objects.new("Body", mesh)
    bpy.context.scene.collection.objects.link(body)
    for group, indices in groups:
        body.vertex_groups.new(name=group).add(list(indices), 1.0, "REPLACE")
    body.parent = rig
    body.modifiers.new("Armature", "ARMATURE").object = rig


def export(path: pathlib.Path) -> None:
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_animations=False)


def make_vrm(path: pathlib.Path, names: dict) -> None:
    """Makes the GLB at `path` a VRM 1.0: its humanoid's bones by node, and the meta VRM asks for."""
    blob = path.read_bytes()
    size = struct.unpack("<I", blob[12:16])[0]
    gltf = json.loads(blob[20 : 20 + size])
    rest = blob[20 + size :]
    node = {one.get("name"): at for at, one in enumerate(gltf["nodes"])}
    gltf.setdefault("extensionsUsed", []).append("VRMC_vrm")
    gltf.setdefault("extensions", {})["VRMC_vrm"] = {
        "specVersion": "1.0",
        "meta": {"name": "Test mannequin", "version": "1", "authors": ["Cardwave's tests"], "licenseUrl": "https://vrm.dev/licenses/1.0/",
                 "avatarPermission": "everyone", "commercialUsage": "corporation", "creditNotation": "unnecessary", "allowRedistribution": True, "modification": "allowModificationRedistribution"},
        "humanoid": {"humanBones": {name: {"node": node[names[name]]} for name, *_ in BONES}},
    }
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + len(rest)) + struct.pack("<II", len(text), 0x4E4F534A) + text + rest
    path.with_suffix(".vrm").write_bytes(out)
    path.unlink()


OUT.mkdir(exist_ok=True)
vroid = {key: f"J_Bip_{name}" for key, name in VROID.items()}
mannequin(vroid, (0.35, 0.6, 0.9))
export(OUT / "mannequin.glb")
make_vrm(OUT / "mannequin.glb", vroid)
mixamo = {key: f"mixamorig:{name}" for key, name in MIXAMO.items()}
mannequin(mixamo, (0.9, 0.55, 0.35))
export(OUT / "mixamo.glb")
bpy.ops.export_scene.fbx(filepath=str(OUT / "mixamo.fbx"), bake_anim=False, add_leaf_bones=False)
odd = {key: f"Bone.{at:03}" for at, (key, *_) in enumerate(BONES)}
mannequin(odd, (0.5, 0.5, 0.5))
export(OUT / "odd.glb")
