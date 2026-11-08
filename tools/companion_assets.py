"""Writes what the companion plays, from the owner's Mixamo material (..\\mixamo_dataset, Make-It-Animatable's copy of
Mixamo's clips and characters; the raw files are never handed out, only these):

- web/src/figures/animations.glb, the carrier: a Mixamo skeleton with no body carrying the clips `CLIPS` names, which
  every 3D figure is given (web/src/figures/retarget.ts) and which is never shown;
- web/src/figures/woman.glb and man.glb, the base figures `FIGURES` names, textures at most `TEXTURE` px, as JPEG.

The clips were picked by their motion (milestone 95a; the plan holds the list and which chains into which): each is
in place (retarget.ts keeps only the hips' height), standing ones start and end near the idle's pose. Every clip's
skeleton must rest as the first one's, or the run stops.

Run with Blender 5.2, from anywhere (every path is absolute); a rerun writes the same bytes:
blender -b -P tools/companion_assets.py
"""

import pathlib

import bpy

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT.parent / "mixamo_dataset"
OUT = ROOT / "web" / "src" / "figures"
TEXTURE = 1024

# The companion's name of each clip (web/src/companion/figure.ts, `CARRIED`) and its file in DATA/animation.
CLIPS = {
    "idle": "3c19c4bd6db0faa8e5bd3437ad44e838",
    "idle_shift": "21d68",
    "stretch": "2042b",
    "thinking": "13a81",
    "listening": "13902",
    "talking": "30e75",
    "walk": "f5bf4",
    "sit_down": "fdb93",
    "sitting": "cd137",
    "stand_up": "9333a",
    "lying": "70929",
    "get_up": "4a510",
    "wave": "35b3b",
    "nod": "143d7",
    "no": "58396",
    "jump": "b60a4",
    "dance": "3ad27",
    "hanging": "13ea8",
    "climbing": "73a4b",
    "startled": "ff732",
    "falling": "27781",
    "shaken": "18db2",
    "landing": "19a3d",
}
# The base figures and their files in DATA/character_fbx_upgraded.
FIGURES = {"woman": "cf7e9c498421b75e2df678adc5284783", "man": "8dfaf7ace7778cd25a6b181d98cd7e77"}


def file_of(folder: str, prefix: str) -> pathlib.Path:
    """The one file in DATA/folder whose name starts with `prefix`."""
    found = sorted((DATA / folder).glob(f"{prefix}*.fbx"))
    assert len(found) == 1, f"{folder}/{prefix}: {len(found)} files"
    return found[0]


def imported(path: pathlib.Path) -> list:
    """The objects the FBX at `path` adds to the scene."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path))
    return [one for one in bpy.data.objects if one not in before]


def carrier() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = None
    for name, prefix in CLIPS.items():
        new = imported(file_of("animation", prefix))
        armature = next(one for one in new if one.type == "ARMATURE")
        action = armature.animation_data.action
        action.name = name
        action.use_fake_user = True
        if base is None:
            base = armature
            base.name = "carrier"
        else:
            rests = {bone.name: bone.matrix_local for bone in base.data.bones}
            off = max(
                max(abs(a - b) for row_a, row_b in zip(rests[bone.name], bone.matrix_local) for a, b in zip(row_a, row_b))
                for bone in armature.data.bones
                if bone.name in rests
            )
            assert off < 1e-3 and len(armature.data.bones) == len(rests), f"{name}: another skeleton ({off})"
            for one in new:
                bpy.data.objects.remove(one, do_unlink=True)
        track = base.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, int(action.frame_range[0]), action)
    base.animation_data.action = None
    for one in list(bpy.data.objects):
        if one != base:
            bpy.data.objects.remove(one, do_unlink=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "animations.glb"),
        export_format="GLB",
        export_animation_mode="NLA_TRACKS",
        export_optimize_animation_size=True,
        export_def_bones=False,
        export_materials="NONE",
    )


def figure(name: str, file: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for one in imported(file_of("character_fbx_upgraded", file)):
        if one.animation_data:
            one.animation_data_clear()
    for image in bpy.data.images:
        width, height = image.size
        if max(width, height) > TEXTURE:
            scale = TEXTURE / max(width, height)
            image.scale(round(width * scale), round(height * scale))
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f"{name}.glb"),
        export_format="GLB",
        export_animations=False,
        export_image_format="JPEG",
        export_image_quality=85,
    )


carrier()
for name, file in FIGURES.items():
    figure(name, file)
