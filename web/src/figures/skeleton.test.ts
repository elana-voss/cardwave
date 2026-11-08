import { describe, expect, it } from "vitest";
import { humanBoneOf, matchBones } from "./skeleton";

const sides = (names: (side: "Left" | "Right", s: "L" | "R") => string[]) => [...names("Left", "L"), ...names("Right", "R")];

describe("a skeleton told by its bones' names", () => {
  it("is matched for Mixamo's, Ready Player Me's, VRoid's, Unity's and VRChat's names", () => {
    const mixamo = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", ...sides((s) => [`${s}Shoulder`, `${s}Arm`, `${s}ForeArm`, `${s}Hand`, `${s}UpLeg`, `${s}Leg`, `${s}Foot`, `${s}ToeBase`])];
    const skeletons = {
      mixamo: mixamo.map((name) => `mixamorig:${name}`),
      "mixamo, as three.js reads it": mixamo.map((name) => `mixamorig${name}`),
      "ready player me": mixamo,
      vroid: ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_Neck", "J_Bip_C_Head", ...sides((_, s) => [`J_Bip_${s}_UpperArm`, `J_Bip_${s}_LowerArm`, `J_Bip_${s}_Hand`, `J_Bip_${s}_UpperLeg`, `J_Bip_${s}_LowerLeg`, `J_Bip_${s}_Foot`])],
      unity: ["Hips", "Spine", "Chest", "Neck", "Head", ...sides((s, l) => [`UpperArm_${l}`, `LowerArm_${l}`, `Hand_${l}`, `${s}UpperLeg`, `${s}LowerLeg`, `${s}Foot`])],
      "blender, as three.js reads it (no dots)": ["hips", "spine", "chest", "neck", "head", ...sides((_, s) => [`upper_arm${s}`, `forearm${s}`, `hand${s}`, `thigh${s}`, `shin${s}`, `foot${s}`])],
      vrchat: ["Hips", "Spine", "Chest", "Neck", "Head", ...sides((s) => [`${s} shoulder`, `${s} arm`, `${s} elbow`, `${s} wrist`, `${s} leg`, `${s} knee`, `${s} ankle`])],
    };
    for (const [name, names] of Object.entries(skeletons)) {
      const matched = matchBones(names);
      expect(matched, name).not.toBeNull();
      expect(matched!.get("hips"), name).toBe(names[0]);
    }
    // "Leg" is the lower leg beside "UpLeg", the upper one beside "knee".
    expect(matchBones(skeletons.mixamo)!.get("leftLowerLeg")).toBe("mixamorig:LeftLeg");
    expect(matchBones(skeletons.vrchat)!.get("leftUpperLeg")).toBe("Left leg");
    expect(matchBones(skeletons.vrchat)!.get("leftLowerLeg")).toBe("Left knee");
  });

  it("names Mixamo's fingers and leaves the ends of bones out", () => {
    expect(humanBoneOf("mixamorig:LeftHandThumb1")).toBe("leftThumbMetacarpal");
    expect(humanBoneOf("mixamorigRightHandIndex3")).toBe("rightIndexDistal");
    expect(humanBoneOf("mixamorig:LeftHandIndex4")).toBeNull();
    expect(humanBoneOf("mixamorig:HeadTop_End")).toBeNull();
  });

  it("is refused where a bone a human has is missing or the names are not a human's", () => {
    expect(matchBones(["Bone", "Bone.001", "Bone.002"])).toBeNull();
    const noLeftHand = ["Hips", "Spine", "Head", ...sides((s) => [`${s}Arm`, `${s}ForeArm`, `${s}Hand`, `${s}UpLeg`, `${s}Leg`, `${s}Foot`])].filter((name) => name !== "LeftHand");
    expect(matchBones(noLeftHand)).toBeNull();
  });
});
