"""Writes what the companion plays, from the owner's Mixamo material (../mixamo_dataset: its named clips in
data_named/animation_motion, their catalogue viewer/catalogue/clips.json) and the two characters, which this script
fetches once from an open copy of the dataset on Hugging Face into target/companion_figures (never handed out):
web/src/figures/animations.glb, the carrier: a bodiless Mixamo skeleton with the clips `CLIPS` names, given to every
figure (web/src/figures/retarget.ts), a name's other versions as `<name>_2`, `<name>_3`; animations.json, each action's
mood and start and end pose (`POSES`, web/src/companion/clips.ts); woman.glb and man.glb (`FIGURES`), textures at most
`TEXTURE` px, as JPEG. `CLIPS` is the owner's 100 names (ticket 141): a swap is one file name here, and its line in
crates/cw-chat/src/companion/clips.txt. Every clip's skeleton must rest as the first one's, or the run stops.
A figure's face shapes (morph targets), where its source has them, are kept under their names (web/src/figures/face.ts).
Run with Blender 5.2, from anywhere (every path is absolute): blender -b -P tools/companion_assets.py
One figure alone, from a source on this machine (FBX, GLB or glTF), packed as the base figures are, its shapes printed
as read and as written (nothing else written): blender -b -P tools/companion_assets.py -- <source> <out.glb>
"""

import hashlib
import json
import pathlib
import struct
import sys
import urllib.request

import bpy

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT.parent / "mixamo_dataset"
MOTION = DATA / "data_named" / "animation_motion"
CATALOGUE = DATA / "viewer" / "catalogue" / "clips.json"
OUT = ROOT / "web" / "src" / "figures"
TEXTURE = 1024

# The companion's name of each clip (the model plays it by this name, crates/cw-chat's `Clip`) and its versions' files
# in MOTION.
CLIPS = {
    "acknowledging": ['Acknowledging.fbx'],
    "agreeing": ['Agreeing.fbx', 'Agreeing_2.fbx'],
    "angry": ['Angry.fbx'],
    "arm_stretching": ['Arm_Stretching.fbx'],
    "bashful": ['Bashful.fbx'],
    "being_cocky": ['Being_Cocky.fbx'],
    "bellydancing": ['Bellydancing.fbx'],
    "blow_a_kiss": ['Blow_A_Kiss.fbx'],
    "bored": ['Bored.fbx'],
    "braced_hang_shimmy": ['Braced_Hang_Shimmy.fbx', 'Braced_Hang_Shimmy_2.fbx'],
    "breathing_idle": ['Breathing_Idle.fbx'],
    "can_can": ['Can_Can.fbx'],
    "cheering": ['Cheering.fbx', 'Cheering_2.fbx'],
    "chicken_dance": ['Chicken_Dance.fbx'],
    "clapping": ['Clapping.fbx'],
    "climbing_down_wall": ['Climbing_Down_Wall.fbx'],
    "climbing_up_wall": ['Climbing_Up_Wall.fbx'],
    "crying": ['Crying.fbx'],
    "dancing": ['Dancing.fbx', 'Dancing_5.fbx'],
    "defeat": ['Defeat.fbx', 'Defeat_2.fbx'],
    "disappointed": ['Disappointed.fbx'],
    "dismissing_gesture": ['Dismissing_Gesture.fbx'],
    "excited": ['Excited.fbx'],
    "fall_landing": ['Fall_A_Land_To_Standing_Idle_01.fbx'],
    "fall_loop": ['Fall_A_Loop.fbx'],
    "falling_down": ['Falling_Down.fbx'],
    "falling_idle": ['Falling_Idle.fbx'],
    "freehang_climb": ['Freehang_Climb.fbx'],
    "freehang_drop": ['Freehang_Drop.fbx'],
    "getting_up": ['Getting_Up.fbx', 'Getting_Up_4.fbx'],
    "hand_raising": ['Hand_Raising.fbx'],
    "hanging_idle": ['Hanging_Idle.fbx', 'Hanging_Idle_2.fbx'],
    "happy": ['Happy.fbx'],
    "happy_idle": ['Happy_Idle.fbx', 'Happy_Idle_2.fbx'],
    "happy_walk": ['Happy_Walk.fbx'],
    "hard_landing": ['Hard_Landing.fbx', 'Hard_Landing_2.fbx'],
    "head_nod_yes": ['Head_Nod_Yes.fbx'],
    "hip_hop_dancing": ['Hip_Hop_Dancing.fbx', 'Hip_Hop_Dancing_3.fbx', 'Hip_Hop_Dancing_13.fbx'],
    "idle": ['Idle.fbx', 'Idle_2.fbx', 'Idle_14.fbx', 'Idle_16.fbx'],
    "joyful_jump": ['Joyful_Jump.fbx'],
    "jump": ['Jump.fbx', 'Jump_2.fbx', 'Jump_5.fbx'],
    "laughing": ['Laughing.fbx'],
    "laying_idle": ['Laying_Idle.fbx', 'Laying_Idle_2.fbx'],
    "laying_sleeping": ['Laying_Sleeping.fbx'],
    "leaning": ['Leaning_2.fbx'],
    "look_around": ['Look_Around.fbx', 'Look_Around_3.fbx'],
    "looking": ['Looking.fbx', 'Looking_2.fbx'],
    "looking_around": ['Looking_Around.fbx'],
    "macarena_dance": ['Macarena_Dance.fbx'],
    "nervously_look_around": ['Nervously_Look_Around.fbx'],
    "neutral_idle": ['Neutral_Idle.fbx'],
    "no": ['No.fbx'],
    "one_shoulder_lean": ['One_Shoulder_Lean.fbx'],
    "pointing_gesture": ['Pointing_Gesture.fbx'],
    "pouting": ['Pouting.fbx'],
    "quick_formal_bow": ['Quick_Formal_Bow.fbx'],
    "quick_informal_bow": ['Quick_Informal_Bow.fbx'],
    "reacting": ['Reacting.fbx'],
    "relieved_sigh": ['Relieved_Sigh.fbx'],
    "run_forward": ['Run_Forward.fbx', 'Run_Forward_3.fbx'],
    "sad_idle": ['Sad_Idle.fbx', 'Sad_Idle_2.fbx'],
    "sad_walk": ['Sad_Walk.fbx'],
    "scratch_idle": ['Zombie_Scratch_Idle.fbx'],
    "seated_idle": ['Seated_Idle.fbx'],
    "shake_fist": ['Shake_Fist.fbx'],
    "shaking_head_no": ['Shaking_Head_No.fbx'],
    "shrugging": ['Shrugging.fbx'],
    "shuffling": ['Shuffling.fbx'],
    "silly_dancing": ['Silly_Dancing_2.fbx', 'Silly_Dancing.fbx'],
    "sitting_idle": ['Sitting_Idle.fbx', 'Sitting_Idle_2.fbx'],
    "sleeping_idle": ['Sleeping_Idle.fbx', 'Sleeping_Idle_2.fbx'],
    "snake_hip_hop_dance": ['Snake_Hip_Hop_Dance.fbx'],
    "sneak_walk": ['Sneak_Walk.fbx', 'Sneak_Walk_2.fbx'],
    "stand_to_sit": ['Stand_To_Sit.fbx'],
    "stand_up": ['Stand_Up_2.fbx', 'Stand_Up_3.fbx'],
    "standard_idle": ['Standard_Idle.fbx'],
    "standing_greeting": ['Standing_Greeting.fbx'],
    "standing_thumbs_up": ['Standing_Thumbs_Up.fbx'],
    "standing_up": ['Standing_Up.fbx', 'Standing_Up_3.fbx'],
    "start_walking": ['Female_Start_Walking.fbx', 'Start_Walking.fbx'],
    "stop_walking": ['Female_Stop_Walking.fbx', 'Stop_Walking_2.fbx'],
    "stumble_backwards": ['Stumble_Backwards.fbx'],
    "surprised": ['Surprised.fbx'],
    "talking": ['Talking.fbx', 'Talking_2.fbx', 'Talking_5.fbx'],
    "telling_a_secret": ['Telling_A_Secret.fbx'],
    "terrified": ['Terrified.fbx'],
    "thankful": ['Thankful.fbx'],
    "thinking": ['Thinking.fbx'],
    "thoughtful_head_nod": ['Thoughtful_Head_Nod.fbx'],
    "twist_dance": ['Twist_Dance.fbx'],
    "victory_idle": ['Victory_Idle.fbx', 'Victory_Idle_2.fbx'],
    "waking": ['Waking.fbx'],
    "walk_backwards": ['Walk_Backwards.fbx'],
    "walking": ['Walking.fbx', 'Walking_12.fbx', 'Walking_13.fbx', 'Walking_2.fbx'],
    "wave_hip_hop_dance": ['Wave_Hip_Hop_Dance.fbx', 'Wave_Hip_Hop_Dance_2.fbx'],
    "waving": ['Waving.fbx', 'Waving_3.fbx'],
    "weight_shift": ['Weight_Shift.fbx'],
    "whatever_gesture": ['Whatever_Gesture.fbx'],
    "yawn": ['Yawn.fbx'],
    "ymca_dance": ['Ymca_Dance.fbx'],
}
# The catalogue's poses as the companion's (a lying one face down lies too; a crouch is where a landing ends).
POSES = {"stand": "stand", "sit": "sit", "sit-floor": "floor", "lie": "lie", "lie-front": "lie", "hang": "hang",
         "air": "air", "crouch": "land"}
# The base figures: each one's file in that copy's character_fbx_upgraded and its SHA-256.
CHARACTERS = "https://huggingface.co/dkatz2391/Mixamo2/resolve/be20d37d53e653ef98746f62dab2969da2465236/character_fbx_upgraded"
FIGURES = {
    "woman": ("cf7e9c498421b75e2df678adc5284783.fbx", "c95814203cb663d73cdfe9a87aa492879d5769e05ff75d25fb705655b85e5174"),
    "man": ("8dfaf7ace7778cd25a6b181d98cd7e77.fbx", "f9ad33201fc01d782480b461bafe2deef0ad9731765cd8d52c89cb1ac8634b12"),
}
FETCHED = ROOT / "target" / "companion_figures"


def fetched(file: str, sha256: str) -> pathlib.Path:
    """The character `file`, downloaded the first time; the run stops where it is not the file named."""
    path = FETCHED / file
    if not path.exists():
        FETCHED.mkdir(parents=True, exist_ok=True)
        part = path.with_suffix(".part")
        urllib.request.urlretrieve(f"{CHARACTERS}/{file}", part)
        part.replace(path)
    found = hashlib.sha256(path.read_bytes()).hexdigest()
    assert found == sha256, f"{file}: another file ({found})"
    return path


def imported(path: pathlib.Path) -> list:
    """The objects the FBX, GLB or glTF at `path` adds to the scene."""
    before = set(bpy.data.objects)
    if path.suffix.lower() in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        bpy.ops.import_scene.fbx(filepath=str(path))
    return [one for one in bpy.data.objects if one not in before]


def carrier() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = None
    catalogue = {entry["file"]: entry for entry in json.loads(CATALOGUE.read_text(encoding="utf-8"))}
    meta = {}
    versions = [(name if i == 0 else f"{name}_{i + 1}", file) for name, files in CLIPS.items() for i, file in enumerate(files)]
    for name, file in versions:
        entry = catalogue[file]
        meta[name] = [entry["mood"], POSES[entry["startPose"]], POSES[entry["endPose"]]]
        new = imported(MOTION / file)
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
    (OUT / "animations.json").write_text(json.dumps(meta, indent=0, sort_keys=True) + "\n", encoding="utf-8")


def shapes_read() -> dict:
    """Each mesh object's face shapes (shape keys but the basis) in the scene."""
    return {one.name: [key.name for key in one.data.shape_keys.key_blocks[1:]]
            for one in bpy.data.objects if one.type == "MESH" and one.data.shape_keys}


def shapes_written(path: pathlib.Path) -> dict:
    """Each mesh's morph targets' names in the GLB at `path` (Blender's exporter names them in the mesh's extras)."""
    data = path.read_bytes()
    gltf = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    return {mesh.get("name"): mesh.get("extras", {}).get("targetNames", []) for mesh in gltf.get("meshes", [])
            if "targets" in mesh["primitives"][0]}


def figure(name: str, file: str, sha256: str) -> None:
    pack(fetched(file, sha256), OUT / f"{name}.glb")


def pack(source: pathlib.Path, out: pathlib.Path) -> None:
    """The figure at `source` as a base figure at `out`: no animation, textures at most `TEXTURE` px as JPEG, its face
    shapes kept."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for one in imported(source):
        if one.animation_data:
            one.animation_data_clear()
        if one.type == "MESH" and one.data.shape_keys and one.data.shape_keys.animation_data:
            one.data.shape_keys.animation_data_clear()
    for image in bpy.data.images:
        width, height = image.size
        if max(width, height) > TEXTURE:
            scale = TEXTURE / max(width, height)
            image.scale(round(width * scale), round(height * scale))
    read = shapes_read()
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_animations=False,
        export_image_format="JPEG",
        export_image_quality=85,
        export_morph=True,
        export_morph_normal=False,
    )
    print("SHAPES read", json.dumps(read))
    print("SHAPES written", json.dumps(shapes_written(out)))


ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if ARGS:
    pack(pathlib.Path(ARGS[0]).resolve(), pathlib.Path(ARGS[1]).resolve())
else:
    carrier()
    for name, (file, sha256) in FIGURES.items():
        figure(name, file, sha256)
