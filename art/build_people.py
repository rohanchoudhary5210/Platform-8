"""Builds Platform 8's people in Blender: rigged, animated, exported one .gltf per person.

Run (from the project folder):
  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" --background --factory-startup --python art/build_people.py

Body: a stick skeleton -> Skin modifier -> Subdivision, so it's one smooth mesh. Head is a sphere with
eyes, brows, nose, ears, mouth and a hair cap. Rig: 18 bones, weights by distance to each bone.
Animations (glTF NLA tracks): "Idle" (4 s, breathing and a slow look around) and "Walk" (1 s, two steps).
Origin at the feet, facing -Y (Godot +Z). Outputs game/assets/models/npc_*.gltf and art/people_preview.png.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "models")
FPS = 24

_mats = {}


def mat(name, rgb, rough=0.7):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1)
    _mats[name] = m
    return m


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    bpy.context.scene.render.fps = FPS


# ── Skeleton (metres, for a 1.70 m person; scaled per person) ───────────
def joints(side):
    """Joint positions. side=+1 is the person's left (+X when facing -Y)."""
    x = side
    return {
        "shoulder": (x * 0.2, 0.0, 1.44), "elbow": (x * 0.225, 0.02, 1.16), "wrist": (x * 0.245, 0.0, 0.91),
        "hand": (x * 0.25, -0.01, 0.81),
        "hip": (x * 0.095, 0.0, 0.93), "knee": (x * 0.105, -0.01, 0.51), "ankle": (x * 0.11, 0.02, 0.09),
        "toe": (x * 0.11, -0.14, 0.035),
    }


CENTRE = {"pelvis": (0, 0, 0.95), "waist": (0, 0, 1.1), "chest": (0, 0, 1.35), "neck": (0, 0, 1.48),
          "neck_top": (0, 0, 1.56)}

# Skin radii (half-width, half-depth) before the body-width factor.
RADII = {"pelvis": (0.16, 0.1), "waist": (0.14, 0.095), "chest": (0.18, 0.115), "neck": (0.055, 0.055),
         "neck_top": (0.05, 0.05), "shoulder": (0.06, 0.06), "elbow": (0.045, 0.045), "wrist": (0.033, 0.03),
         "hand": (0.04, 0.02), "hip": (0.085, 0.085), "knee": (0.058, 0.06), "ankle": (0.042, 0.045),
         "toe": (0.045, 0.03)}

# Bones: name -> (head joint, tail joint, parent)
BONES = {
    "hips": ("pelvis", "waist", None), "spine": ("waist", "chest", "hips"), "chest": ("chest", "neck", "spine"),
    "neck": ("neck", "neck_top", "chest"), "head": ("neck_top", "head_top", "neck"),
}
for _s, _n in ((1, "L"), (-1, "R")):
    BONES.update({
        f"upperarm.{_n}": (f"shoulder.{_n}", f"elbow.{_n}", "chest"),
        f"forearm.{_n}": (f"elbow.{_n}", f"wrist.{_n}", f"upperarm.{_n}"),
        f"hand.{_n}": (f"wrist.{_n}", f"hand.{_n}", f"forearm.{_n}"),
        f"thigh.{_n}": (f"hip.{_n}", f"knee.{_n}", "hips"),
        f"shin.{_n}": (f"knee.{_n}", f"ankle.{_n}", f"thigh.{_n}"),
        f"foot.{_n}": (f"ankle.{_n}", f"toe.{_n}", f"shin.{_n}"),
    })


def all_joints(s):
    p = {k: Vector(v) * s for k, v in CENTRE.items()}
    p["head_top"] = Vector((0, 0, 1.76)) * s
    for side, n in ((1, "L"), (-1, "R")):
        for k, v in joints(side).items():
            p[f"{k}.{n}"] = Vector(v) * s
    return p


def body_mesh(p, s, width):
    """The stick figure as a Skin-modified mesh, applied and subdivided into one smooth body."""
    names = list(p.keys())
    names.remove("head_top")
    edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "neck"), ("neck", "neck_top")]
    for n in ("L", "R"):
        edges += [("chest", f"shoulder.{n}"), (f"shoulder.{n}", f"elbow.{n}"), (f"elbow.{n}", f"wrist.{n}"),
                  (f"wrist.{n}", f"hand.{n}"), ("pelvis", f"hip.{n}"), (f"hip.{n}", f"knee.{n}"),
                  (f"knee.{n}", f"ankle.{n}"), (f"ankle.{n}", f"toe.{n}")]
    me = bpy.data.meshes.new("Body")
    me.from_pydata([p[n] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
    o = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(o)
    skin = o.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    for i, n in enumerate(names):
        rx, ry = RADII[n.split(".")[0]]
        wide = width if n.split(".")[0] in ("pelvis", "waist", "chest") else 1.0
        o.data.skin_vertices[0].data[i].radius = (rx * s * wide, ry * s * wide)
        o.data.skin_vertices[0].data[i].use_root = n == "pelvis"
    sub = o.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Sub")
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def paint(o, p, s, shirt, pants, skin, shoes, long_top):
    """Material per face by where it sits on the body."""
    mats = [shirt, pants, skin, shoes]
    for m in mats:
        o.data.materials.append(m)
    wrist_z = p["wrist.L"].z - 0.01 * s
    for f in o.data.polygons:
        c = f.center
        if c.z < 0.13 * s:
            f.material_index = 3
        elif c.z > p["neck"].z - 0.01 * s or (abs(c.x) > 0.17 * s and c.z < wrist_z):
            f.material_index = 2  # neck, hands
        elif c.z < p["pelvis"].z - 0.02 * s and abs(c.x) < 0.2 * s:
            hem = p["knee.L"].z + 0.08 * s if long_top else 0.0
            f.material_index = 0 if c.z > hem and long_top else 1
        else:
            f.material_index = 0


def part(op, name, material, loc, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    op(location=loc, rotation=rot, **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def sphere(name, material, loc, r, scale=(1, 1, 1), segs=20, rings=12):
    return part(bpy.ops.mesh.primitive_uv_sphere_add, name, material, loc, scale, radius=r, segments=segs,
                ring_count=rings)


def boxp(name, material, loc, size, rot=(0, 0, 0)):
    o = part(bpy.ops.mesh.primitive_cube_add, name, material, loc, (size[0] / 2, size[1] / 2, size[2] / 2), rot,
             size=2.0)
    for f in o.data.polygons:
        f.use_smooth = False
    return o


def head(s, skin, hair, eye_dark, long_hair=False):
    """Head sphere plus face features and a hair cap. Everything is weighted to the 'head' bone."""
    c = Vector((0, -0.005, 1.645)) * s
    parts = [sphere("Head", skin, c, 0.1 * s, (0.9, 1.0, 1.15))]
    for side in (-1, 1):
        parts.append(sphere(f"Eye{side}", eye_dark, c + Vector((side * 0.034, -0.088, 0.018)) * s, 0.011 * s, segs=8, rings=6))
        parts.append(boxp(f"Brow{side}", hair, c + Vector((side * 0.035, -0.092, 0.042)) * s, Vector((0.034, 0.01, 0.008)) * s,
                          rot=(0, side * -0.12, 0)))
        parts.append(sphere(f"Ear{side}", skin, c + Vector((side * 0.09, 0.005, 0.005)) * s, 0.026 * s, (0.35, 0.7, 1.0), segs=10, rings=6))
    parts.append(sphere("Nose", skin, c + Vector((0, -0.1, -0.005)) * s, 0.017 * s, (0.8, 1.0, 1.4), segs=10, rings=6))
    parts.append(boxp("Mouth", mat("Lips", (0.3, 0.13, 0.11)), c + Vector((0, -0.094, -0.045)) * s, Vector((0.034, 0.008, 0.007)) * s))
    # Hair: a slightly bigger sphere, cut away below the hairline and over the face.
    h = sphere("Hair", hair, c + Vector((0, 0.006, 0.012)) * s, 0.104 * s, (0.93, 1.03, 1.15), segs=24, rings=16)
    bm = bmesh.new()
    bm.from_mesh(h.data)
    drop = []
    for v in bm.verts:
        d = v.co  # mesh coords are already relative to the hair's centre
        back = d.y > 0.02 * s
        if d.z < (-0.09 if long_hair and back else (-0.035 if back else 0.03)) * s or (d.y < -0.03 * s and d.z < 0.06 * s):
            drop.append(v)
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(h.data)
    bm.free()
    parts.append(h)
    return parts


# ── Rig, weights, animation ─────────────────────────────────────────────
def make_rig(p):
    arm = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (a, b, parent) in BONES.items():
        eb = arm.edit_bones.new(name)
        eb.head, eb.tail = p[a], p[b]
        eb.roll = 0.0
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def seg_dist(v, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (v - a).dot(ab) / ab.length_squared))
    return (v - (a + ab * t)).length


def weight_body(o, p):
    """Each vertex to its two nearest bones, blended by inverse distance. Simple and stable."""
    groups = {n: o.vertex_groups.new(name=n) for n in BONES}
    segs = {n: (p[a], p[b]) for n, (a, b, _) in BONES.items()}
    for v in o.data.vertices:
        d = sorted((seg_dist(v.co, *segs[n]), n) for n in BONES)[:2]
        w = [1.0 / max(x, 1e-4) ** 4 for x, _ in d]
        for (_, n), wi in zip(d, w):
            groups[n].add([v.index], wi / sum(w), "REPLACE")


def bind(o, bone):
    """A rigid part that follows one bone."""
    o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))), 1.0, "REPLACE")


def key(rig, frame, poses):
    """poses: bone -> (rx, ry, rz) in degrees, or ('loc', (x, y, z))."""
    for bone, val in poses.items():
        pb = rig.pose.bones[bone]
        if val[0] == "loc":
            pb.location = val[1]
            pb.keyframe_insert("location", frame=frame)
        else:
            pb.rotation_euler = [math.radians(a) for a in val]
            pb.keyframe_insert("rotation_euler", frame=frame)


def walk_pose(phase):
    """phase 0..1 over one full cycle (two steps). Sign conventions checked in the preview render."""
    sw = math.sin(phase * math.tau)
    lift_l = max(0.0, -math.sin(phase * math.tau + 0.6))  # knee bends while the leg swings forward
    lift_r = max(0.0, math.sin(phase * math.tau + 0.6))
    return {
        "thigh.L": (-24 * sw, 0, 0), "thigh.R": (24 * sw, 0, 0),
        "shin.L": (40 * lift_l + 4, 0, 0), "shin.R": (40 * lift_r + 4, 0, 0),
        "foot.L": (-10 * lift_l, 0, 0), "foot.R": (-10 * lift_r, 0, 0),
        "upperarm.L": (16 * sw, 0, 4), "upperarm.R": (-16 * sw, 0, -4),
        "forearm.L": (-12 - 8 * max(0, sw), 0, 0), "forearm.R": (-12 - 8 * max(0, -sw), 0, 0),
        "spine": (0, 5 * sw, 0), "chest": (0, -4 * sw, 0),
        "hips": ("loc", (0, 0.025 * abs(math.cos(phase * math.tau)), 0)),
    }


def idle_pose(phase):
    b = math.sin(phase * math.tau * 2)  # two breaths per loop
    look = math.sin(phase * math.tau)
    return {
        "spine": (1.2 * b, 0, 0), "chest": (1.0 * b, 0, 0), "neck": (0, 0, 4 * look),
        "head": (2 * math.sin(phase * math.tau * 3), 0, 6 * look),
        "upperarm.L": (2 * b, 0, 3), "upperarm.R": (2 * b, 0, -3),
        "forearm.L": (-8, 0, 0), "forearm.R": (-8, 0, 0),
        "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "shin.L": (2, 0, 0), "shin.R": (2, 0, 0),
        "hips": ("loc", (0, 0, 0)),
    }


def animate(rig, name, frames, pose_fn, step=3):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    for f in range(0, frames + 1, step):
        key(rig, f + 1, pose_fn(f / frames))
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    rig.animation_data.action = None


# ── People ──────────────────────────────────────────────────────────────
SKIN = [(0.56, 0.38, 0.27), (0.43, 0.29, 0.2), (0.66, 0.47, 0.35)]


def person(name, shirt, pants, skin, hair, shoes=(0.06, 0.05, 0.05), height=1.7, width=1.0, long_top=False,
           long_hair=False, extras=None):
    """extras(s, p) -> list of (object, bone) to add, e.g. a bag on the chest bone."""
    s = height / 1.7
    p = all_joints(s)
    r = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(r)
    m_shirt, m_pants, m_skin = mat(name + "Shirt", shirt), mat(name + "Pants", pants), mat(name + "Skin", skin)
    body = body_mesh(p, s, width)
    paint(body, p, s, m_shirt, m_pants, m_skin, mat("Shoes", shoes, 0.4), long_top)
    weight_body(body, p)
    rigid = [(o, "head") for o in head(s, m_skin, mat("Hair", hair, 0.9), mat("EyeDark", (0.02, 0.015, 0.015), 0.3), long_hair)]
    if not long_top:  # belt hides the shirt/trouser seam
        b = part(bpy.ops.mesh.primitive_cylinder_add, "Belt", mat("Belt", (0.07, 0.05, 0.03)), (0, 0, 0.955 * s),
                 (1.0, 0.7, 1.0), radius=0.152 * s * width, depth=0.045 * s, vertices=24)
        rigid.append((b, "hips"))
    if long_top:  # kurta skirt from waist to knee
        k = part(bpy.ops.mesh.primitive_cone_add, "Kurta", m_shirt, (0, 0, 0.73 * s), (1.0, 0.72, 1.0),
                 radius1=0.235 * s * width, radius2=0.165 * s * width, depth=0.42 * s, vertices=24, end_fill_type="NOTHING")
        rigid.append((k, "hips"))
    rigid += (extras(s, p) if extras else [])
    for o, bone in rigid:
        bind(o, bone)
    bpy.ops.object.select_all(action="DESELECT")
    for o, _ in rigid:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    rig = make_rig(p)
    rig.parent = r
    body.parent = rig
    body.modifiers.new("Rig", "ARMATURE").object = rig
    animate(rig, "Idle", 4 * FPS, idle_pose)
    animate(rig, "Walk", FPS, walk_pose)
    return r


def npc_commuter_a():
    """Office commuter: light blue shirt, grey trousers, backpack."""
    def bag(s, p):
        return [(boxp("Backpack", mat("Backpack", (0.08, 0.1, 0.09)), Vector((0, 0.17, 1.2)) * s, Vector((0.3, 0.14, 0.42)) * s), "chest")]
    return person("npc_commuter_a", (0.45, 0.6, 0.78), (0.22, 0.22, 0.25), SKIN[0], (0.03, 0.025, 0.02), extras=bag)


def npc_commuter_b():
    """Woman in a long maroon kurta with dark leggings, plait down the back, phone in hand."""
    def phone(s, p):
        return [(boxp("Phone", mat("Phone", (0.02, 0.02, 0.03)), p["hand.R"] + Vector((0, -0.03, 0.02)) * s,
                      Vector((0.012, 0.07, 0.14)) * s), "hand.R")]
    return person("npc_commuter_b", (0.5, 0.1, 0.16), (0.1, 0.1, 0.12), SKIN[1], (0.02, 0.015, 0.012),
                  height=1.6, width=0.92, long_top=True, long_hair=True, extras=phone)


def npc_guard():
    """Security guard: khaki uniform, navy beret, moustache, belt."""
    def kit(s, p):
        c = Vector((0, -0.005, 1.645)) * s
        return [
            (sphere("Beret", mat("Beret", (0.08, 0.1, 0.25)), c + Vector((0.015, 0.01, 0.085)) * s, 0.105 * s, (1.08, 1.08, 0.4)), "head"),
            (boxp("Moustache", mat("Hair", (0.03, 0.025, 0.02)), c + Vector((0, -0.096, -0.028)) * s, Vector((0.05, 0.012, 0.012)) * s), "head"),
        ]
    return person("npc_guard", (0.52, 0.47, 0.32), (0.45, 0.4, 0.27), SKIN[0], (0.03, 0.025, 0.02),
                  height=1.76, width=1.08, extras=kit)


def npc_sweeper():
    """Night cleaner: grey overalls, orange safety vest, broom."""
    def kit(s, p):
        vest = part(bpy.ops.mesh.primitive_cylinder_add, "Vest", mat("SafetyVest", (0.95, 0.42, 0.05)), (0, 0, 1.22 * s),
                    (1.0, 0.66, 1.0), radius=0.178 * s, depth=0.34 * s, vertices=24, end_fill_type="NOTHING")
        handle = part(bpy.ops.mesh.primitive_cylinder_add, "BroomHandle", mat("Bamboo", (0.6, 0.5, 0.3)),
                      p["hand.R"] + Vector((0, -0.08, -0.25)) * s, rot=(0.3, 0, 0), radius=0.014 * s, depth=1.2 * s, vertices=8)
        head_b = boxp("BroomHead", mat("Bristle", (0.35, 0.3, 0.2)), p["hand.R"] + Vector((0, -0.25, -0.76)) * s, Vector((0.32, 0.07, 0.1)) * s)
        return [(vest, "chest"), (handle, "hand.R"), (head_b, "hand.R")]
    return person("npc_sweeper", (0.32, 0.34, 0.35), (0.3, 0.32, 0.33), SKIN[2], (0.05, 0.05, 0.05),
                  height=1.66, extras=kit)


PEOPLE = [npc_commuter_a, npc_commuter_b, npc_guard, npc_sweeper]


def select_tree(r):
    bpy.ops.object.select_all(action="DESELECT")
    r.select_set(True)
    for c in r.children_recursive:
        c.select_set(True)
    bpy.context.view_layer.objects.active = r


def main():
    for fn in PEOPLE:
        reset()
        r = fn()
        select_tree(r)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, r.name + ".gltf"), use_selection=True,
                                  export_format="GLTF_SEPARATE", export_animations=True,
                                  export_animation_mode="NLA_TRACKS", export_skins=True)
    preview()


def preview():
    """All four standing (Idle) plus a walking copy of the first, mid-stride, side-on."""
    reset()
    roots = [fn() for fn in PEOPLE]
    for i, r in enumerate(roots):
        r.location = (i * 0.9 - 1.35, 0, 0)
        [c for c in r.children if c.type == "ARMATURE"][0].animation_data.nla_tracks["Walk"].mute = True
    walker = npc_commuter_a()
    walker.location = (2.4, 0.6, 0)
    walker.rotation_euler = (0, 0, math.radians(90))  # side-on to the camera
    rig = [c for c in walker.children if c.type == "ARMATURE"][0]
    rig.animation_data.nla_tracks["Idle"].mute = True
    scene = bpy.context.scene
    scene.frame_set(7)  # quarter cycle: left leg forward
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = (0.5, -6.2, 1.25)
    cam.rotation_euler = (math.radians(88), 0, 0)
    scene.camera = cam
    scene.render.filepath = os.path.join(ROOT, "art", "people_preview.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "platform8_people.blend"))


main()
