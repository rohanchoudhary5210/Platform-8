"""Builds Platform 8's station props in Blender and exports one .gltf per prop.

Run (from the project folder):
  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" --background --factory-startup --python art/build_props.py

Outputs:
  game/assets/models/<prop>.gltf  one per prop (+ .bin), origin at floor centre, metres, +Y up in Godot
  art/platform8_props.blend       all props side by side, for hand tweaks
  art/preview.png                 contact sheet render

Low-poly, flat materials (base colour / metal / roughness only) so they suit the greybox + fog look.
Keep metallic low (~0.35): the GL Compatibility renderer has no reflections, so full metal renders black.
Named sub-objects (Body, Hand_Second, Flap_L, Door_L...) are what anomalies will drive later.
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "models")
os.makedirs(OUT, exist_ok=True)

_mats = {}


def mat(name, rgb, metal=0.0, rough=0.6, emit=None):
    """One shared material per name."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    m.diffuse_color = (*rgb, 1)  # what Workbench previews show
    _mats[name] = m
    return m


STEEL = lambda: mat("Steel", (0.62, 0.64, 0.66), 0.35, 0.4)
DARK = lambda: mat("DarkMetal", (0.08, 0.08, 0.09), 0.6, 0.5)
PLASTIC_W = lambda: mat("WhitePlastic", (0.85, 0.85, 0.82), 0.0, 0.45)


def obj_from(op, name, parent, material, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.0, **kw):
    """Create a primitive with bpy.ops, name it, give it a material, parent it."""
    op(location=loc, rotation=rot, **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    o.parent = parent
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def box(name, parent, material, size, loc, rot=(0, 0, 0), bevel=0.0):
    return obj_from(bpy.ops.mesh.primitive_cube_add, name, parent, material, loc, rot,
                    (size[0] / 2, size[1] / 2, size[2] / 2), bevel, size=1.0 * 2)


def cyl(name, parent, material, r, h, loc, rot=(0, 0, 0), verts=24, bevel=0.0):
    return obj_from(bpy.ops.mesh.primitive_cylinder_add, name, parent, material, loc, rot,
                    (1, 1, 1), bevel, radius=r, depth=h, vertices=verts)


def root(name):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    return e


# ── Props ────────────────────────────────────────────────────────────────
# Blender is Z-up; the glTF exporter converts to Godot's Y-up.

def dustbin():
    r = root("dustbin")
    green = mat("BinGreen", (0.12, 0.35, 0.18), 0.4, 0.5)
    cyl("Body", r, green, 0.28, 0.8, (0, 0, 0.4), bevel=0.01)
    cyl("Rim", r, STEEL(), 0.3, 0.05, (0, 0, 0.82))
    cyl("Lid", r, STEEL(), 0.26, 0.12, (0, 0, 0.9), verts=24)
    box("Flap", r, DARK(), (0.22, 0.02, 0.1), (0, -0.25, 0.9))
    box("Label", r, mat("BinWhite", (0.9, 0.9, 0.85)), (0.18, 0.01, 0.12), (0, -0.281, 0.55))
    return r


def fire_extinguisher():
    r = root("fire_extinguisher")
    red = mat("ExtRed", (0.75, 0.04, 0.04), 0.2, 0.35)  # anomaly #5 recolours "ExtRed"
    cyl("Body", r, red, 0.1, 0.5, (0, 0, 0.25), bevel=0.01)
    obj_from(bpy.ops.mesh.primitive_uv_sphere_add, "Dome", r, red, (0, 0, 0.5), scale=(1, 1, 0.5),
             radius=0.1, segments=24, ring_count=8)
    cyl("Neck", r, DARK(), 0.03, 0.08, (0, 0, 0.58))
    box("Handle", r, DARK(), (0.16, 0.03, 0.02), (0.03, 0, 0.64), rot=(0, math.radians(-12), 0))
    cyl("Hose", r, DARK(), 0.012, 0.35, (0.11, 0, 0.42), rot=(0, math.radians(8), 0), verts=8)
    box("Label", r, PLASTIC_W(), (0.12, 0.01, 0.16), (0, -0.1, 0.28))  # front (-Y) faces the room
    box("WallBracket", r, DARK(), (0.12, 0.04, 0.04), (0, 0.12, 0.5))
    return r


def water_cooler():
    r = root("water_cooler")
    box("Cabinet", r, STEEL(), (0.5, 0.45, 1.05), (0, 0, 0.525), bevel=0.01)
    box("Basin", r, DARK(), (0.36, 0.2, 0.05), (0, -0.15, 0.95))
    for x in (-0.08, 0.08):
        cyl("Tap", r, STEEL(), 0.015, 0.08, (x, -0.21, 1.0), rot=(math.radians(90), 0, 0), verts=8)
    box("Grille", r, DARK(), (0.36, 0.01, 0.3), (0, -0.226, 0.25))
    box("Sign", r, mat("SignBlue", (0.1, 0.25, 0.6)), (0.3, 0.01, 0.12), (0, -0.226, 0.7))
    return r


def cctv_camera():
    r = root("cctv_camera")
    box("Mount", r, DARK(), (0.08, 0.08, 0.2), (0, 0, -0.1))  # origin = ceiling point
    box("Arm", r, DARK(), (0.05, 0.25, 0.05), (0, -0.12, -0.2))
    body = box("Body", r, PLASTIC_W(), (0.14, 0.38, 0.14), (0, -0.3, -0.26), rot=(math.radians(-20), 0, 0), bevel=0.015)
    cyl("Lens", r, mat("Glass", (0.02, 0.02, 0.03), 0.0, 0.05), 0.045, 0.03, (0, -0.49, -0.33),
        rot=(math.radians(70), 0, 0))
    box("Hood", r, PLASTIC_W(), (0.18, 0.4, 0.02), (0, -0.31, -0.17), rot=(math.radians(-20), 0, 0))
    cyl("RecLed", r, mat("RecRed", (1, 0.05, 0.05), emit=(1, 0, 0)), 0.008, 0.01, (0.05, -0.47, -0.27),
        rot=(math.radians(70), 0, 0), verts=8)
    return r


def wall_clock():
    """Faces -Y (front). Hands are separate objects pivoting at the centre: Hand_Hour / Hand_Minute / Hand_Second."""
    r = root("wall_clock")
    cyl("Frame", r, DARK(), 0.42, 0.06, (0, 0, 0), rot=(math.radians(90), 0, 0), verts=48)
    cyl("Face", r, mat("ClockFace", (0.92, 0.92, 0.88), 0.0, 0.3), 0.38, 0.065, (0, 0, 0), rot=(math.radians(90), 0, 0), verts=48)
    for i in range(12):
        a = i * math.tau / 12
        long = i % 3 == 0
        box(f"Tick{i}", r, DARK(), (0.02, 0.01, 0.07 if long else 0.04),
            (math.sin(a) * 0.32, -0.04, math.cos(a) * 0.32), rot=(0, a, 0))
    for name, length, width, colour in (("Hand_Hour", 0.18, 0.03, DARK()), ("Hand_Minute", 0.28, 0.02, DARK()),
                                         ("Hand_Second", 0.32, 0.008, mat("HandRed", (0.7, 0.03, 0.03)))):
        h = box(name, r, colour, (width, 0.006, length), (0, -0.045, length / 2 - 0.03))
        h.location = (0, -0.045, 0)  # pivot at centre: move the mesh up, keep the origin
        for v in h.data.vertices:
            v.co.z += length / 2 - 0.03
    cyl("Pin", r, DARK(), 0.015, 0.02, (0, -0.05, 0), rot=(math.radians(90), 0, 0), verts=12)
    return r


def afc_gate():
    """One gate cabinet (stand it between lanes). Flap_L / Flap_R retract into the sides."""
    r = root("afc_gate")
    body_mat = mat("GateBody", (0.72, 0.73, 0.75), 0.3, 0.4)
    box("Cabinet", r, body_mat, (0.3, 1.4, 0.95), (0, 0, 0.475), bevel=0.02)
    box("Top", r, mat("GateTop", (0.15, 0.15, 0.17), 0.2, 0.4), (0.32, 1.42, 0.04), (0, 0, 0.97))
    box("Reader", r, mat("ReaderBlue", (0.1, 0.3, 0.7), emit=(0.1, 0.35, 1.0)), (0.2, 0.18, 0.015), (0, 0.45, 0.995))
    box("ArrowPanel", r, mat("ArrowGreen", (0.05, 0.5, 0.15), emit=(0.1, 1.0, 0.3)), (0.31, 0.12, 0.12), (0, 0.65, 0.8))
    flap = mat("FlapRed", (0.7, 0.08, 0.08), 0.0, 0.3)
    box("Flap_L", r, flap, (0.28, 0.03, 0.45), (-0.3, 0, 0.65), bevel=0.01)
    box("Flap_R", r, flap, (0.28, 0.03, 0.45), (0.3, 0, 0.65), bevel=0.01)
    return r


def bench():
    r = root("bench")
    for x in (-0.7, 0.7):
        box(f"Leg{x}", r, DARK(), (0.06, 0.4, 0.42), (x, 0, 0.21))
    for i in range(3):  # three moulded steel seats
        box(f"Seat{i}", r, STEEL(), (0.5, 0.42, 0.03), (-0.55 + i * 0.55, 0, 0.44), bevel=0.01)
        box(f"Back{i}", r, STEEL(), (0.5, 0.03, 0.38), (-0.55 + i * 0.55, 0.2, 0.66), rot=(math.radians(-10), 0, 0), bevel=0.01)
    box("Rail", r, DARK(), (1.7, 0.05, 0.05), (0, 0, 0.4))
    return r


def pillar():
    r = root("pillar")
    tile = mat("PillarTile", (0.78, 0.76, 0.7), 0.0, 0.25)
    box("Shaft", r, tile, (0.7, 0.7, 3.4), (0, 0, 1.7), bevel=0.02)
    box("Skirt", r, DARK(), (0.74, 0.74, 0.15), (0, 0, 0.075))
    box("Band", r, mat("LineBand", (0.84, 0.2, 0.42)), (0.72, 0.72, 0.12), (0, 0, 1.4))  # line colour band
    return r


def lift_doors():
    """Frame faces -Y. Door_L / Door_R slide along X."""
    r = root("lift_doors")
    frame = mat("LiftFrame", (0.5, 0.52, 0.55), 0.35, 0.35)
    box("Frame_Top", r, frame, (1.5, 0.12, 0.25), (0, 0, 2.225))
    box("Frame_L", r, frame, (0.15, 0.12, 2.1), (-0.675, 0, 1.05))
    box("Frame_R", r, frame, (0.15, 0.12, 2.1), (0.675, 0, 1.05))
    box("Shaft", r, mat("Void", (0.01, 0.01, 0.01), 0.0, 1.0), (1.2, 0.05, 2.1), (0, 0.06, 1.05))
    door = mat("LiftDoor", (0.7, 0.72, 0.75), 0.35, 0.3)
    box("Door_L", r, door, (0.6, 0.04, 2.1), (-0.3, -0.02, 1.05))
    box("Door_R", r, door, (0.6, 0.04, 2.1), (0.3, -0.02, 1.05))
    box("Indicator", r, mat("LiftLed", (0.9, 0.4, 0.05), emit=(1, 0.45, 0.05)), (0.3, 0.02, 0.1), (0, -0.07, 2.25))
    box("CallPanel", r, frame, (0.1, 0.03, 0.25), (0.9, -0.02, 1.1))
    return r


def token_machine():
    """Ticket / token vending machine (for the 'won't stop dispensing' anomaly later). Faces -Y."""
    r = root("token_machine")
    box("Cabinet", r, mat("TvmBlue", (0.12, 0.25, 0.55), 0.3, 0.4), (0.8, 0.6, 1.8), (0, 0, 0.9), bevel=0.02)
    box("Screen", r, mat("TvmScreen", (0.05, 0.15, 0.2), emit=(0.2, 0.6, 0.8)), (0.5, 0.01, 0.4), (0, -0.305, 1.3))
    box("Slot", r, DARK(), (0.3, 0.02, 0.15), (0, -0.305, 0.5))
    box("Tray", r, STEEL(), (0.3, 0.12, 0.05), (0, -0.33, 0.42))
    box("Keypad", r, DARK(), (0.2, 0.02, 0.15), (0.2, -0.305, 0.95))
    box("Header", r, mat("TvmYellow", (0.9, 0.7, 0.1)), (0.8, 0.02, 0.15), (0, -0.305, 1.68))
    return r


# ── Trains ───────────────────────────────────────────────────────────────
COACH_LEN = 20.0
DOOR_Y = (-7.5, -2.5, 2.5, 7.5)  # door centres along the coach
FLOOR_Z = 1.15  # coach floor above rail top (= platform height)


def train_coach():
    """Exterior of one 20 m coach, origin at rail-top centre. Doors on both sides at DOOR_Y.
    LineStripe is the line colour band; the game can tint it."""
    r = root("train_coach")
    body = mat("CoachBody", (0.78, 0.8, 0.83), 0.35, 0.4)
    glass = mat("CoachGlass", (0.03, 0.04, 0.05), 0.0, 0.1)
    door = mat("CoachDoor", (0.68, 0.7, 0.73), 0.35, 0.35)
    stripe = mat("LineStripe", (0.84, 0.2, 0.42))
    w, top = 3.0, 4.0
    box("Body", r, body, (w, COACH_LEN, top - 0.55), (0, 0, 0.55 + (top - 0.55) / 2), bevel=0.04)
    box("Roof", r, mat("CoachRoof", (0.55, 0.56, 0.58), 0.3, 0.5), (w - 0.3, COACH_LEN - 0.4, 0.15), (0, 0, top + 0.07))
    box("Skirt", r, DARK(), (w - 0.2, COACH_LEN - 1.0, 0.5), (0, 0, 0.4))
    for y in (-COACH_LEN / 2 + 3.0, COACH_LEN / 2 - 3.0):  # bogies
        box(f"Bogie{y}", r, DARK(), (2.2, 2.6, 0.45), (0, y, 0.25))
        for wy in (-0.9, 0.9):
            cyl(f"Wheel{y}_{wy}", r, DARK(), 0.42, 2.4, (0, y + wy, 0.42), rot=(0, 1.5708, 0), verts=16)
    for side in (-1, 1):
        x = side * (w / 2 + 0.005)
        box(f"Stripe{side}", r, stripe, (0.01, COACH_LEN - 0.2, 0.18), (x, 0, FLOOR_Z + 0.45))
        # Window band between doors.
        edges = [-COACH_LEN / 2 + 0.6] + [e for y in DOOR_Y for e in (y - 0.85, y + 0.85)] + [COACH_LEN / 2 - 0.6]
        for i in range(0, len(edges), 2):
            a, b = edges[i], edges[i + 1]
            if b - a > 0.6:
                box(f"Window{side}_{i}", r, glass, (0.01, b - a - 0.3, 0.85), (x, (a + b) / 2, FLOOR_Z + 1.35))
        for j, y in enumerate(DOOR_Y):
            for k, dy in enumerate((-0.35, 0.35)):
                box(f"Door{side}_{j}_{k}", r, door, (0.02, 0.69, 2.0), (x + side * 0.005, y + dy, FLOOR_Z + 1.0))
                box(f"DoorGlass{side}_{j}_{k}", r, glass, (0.01, 0.4, 0.7), (x + side * 0.016, y + dy, FLOOR_Z + 1.5))
    for end in (-1, 1):
        box(f"EndDoor{end}", r, door, (0.9, 0.02, 2.0), (0, end * (COACH_LEN / 2 + 0.005), FLOOR_Z + 1.0))
    return r


def coach_interior():
    """Inside of one coach for the ride: 3 m wide, 16 m long, floor at origin.
    Window band at z 1.0–1.8 (tunnel lights scroll past outside it). Long benches, poles, grab rails."""
    r = root("coach_interior")
    wall = mat("CoachWall", (0.85, 0.86, 0.88), 0.1, 0.5)
    seat = mat("SeatBlue", (0.18, 0.28, 0.55), 0.2, 0.4)
    pole = mat("Pole", (0.75, 0.6, 0.15), 0.4, 0.3)
    length, half = 16.0, 1.5
    box("Floor", r, mat("CoachFloor", (0.3, 0.32, 0.35), 0.0, 0.7), (3.0, length, 0.1), (0, 0, -0.05))
    box("Ceiling", r, wall, (3.0, length, 0.1), (0, 0, 2.5))
    for i in range(5):
        box(f"LightStrip{i}", r, mat("CoachLight", (1, 1, 0.95), emit=(1, 0.98, 0.9)), (0.25, 2.4, 0.02),
            (0, -6.4 + i * 3.2, 2.44))
    door_y = (-4.0, 4.0)
    for side in (-1, 1):
        x = side * half
        box(f"WallLow{side}", r, wall, (0.06, length, 1.0), (x, 0, 0.5))
        box(f"WallHigh{side}", r, wall, (0.06, length, 0.7), (x, 0, 2.15))
        for y in (-7.0, -1.6, 1.6, 7.0):  # window pillars
            box(f"Pillar{side}_{y}", r, wall, (0.08, 0.25, 0.8), (x, y, 1.4))
        for j, y in enumerate(door_y):
            box(f"Door{side}_{j}", r, mat("CoachDoorIn", (0.65, 0.67, 0.7), 0.3, 0.35), (0.05, 1.3, 2.0), (x * 0.99, y, 1.0))
            box(f"DoorGlass{side}_{j}", r, mat("CoachGlass", (0.03, 0.04, 0.05), 0.0, 0.1), (0.06, 0.8, 0.6), (x * 0.99, y, 1.45))
        # Long bench seats between the doors, like Indian metro coaches.
        for y0, y1 in ((-7.6, -4.9), (-3.1, 3.1), (4.9, 7.6)):
            box(f"Seat{side}_{y0}", r, seat, (0.45, y1 - y0, 0.08), (side * (half - 0.28), (y0 + y1) / 2, 0.45))
            box(f"SeatBack{side}_{y0}", r, seat, (0.06, y1 - y0, 0.45), (side * (half - 0.06), (y0 + y1) / 2, 0.75))
            box(f"SeatBase{side}_{y0}", r, DARK(), (0.4, y1 - y0, 0.4), (side * (half - 0.28), (y0 + y1) / 2, 0.2))
        for y in (-5.2, -2.0, 2.0, 5.2):  # vertical poles at seat ends
            cyl(f"Pole{side}_{y}", r, pole, 0.02, 2.5, (side * 0.85, y, 1.25), verts=10)
        cyl(f"GrabRail{side}", r, pole, 0.018, length - 1, (side * 0.6, 0, 2.05), rot=(1.5708, 0, 0), verts=10)
    for end in (-1, 1):
        box(f"EndWall{end}", r, wall, (3.0, 0.08, 2.5), (0, end * length / 2, 1.25))
        box(f"Gangway{end}", r, DARK(), (1.1, 0.1, 2.0), (0, end * (length / 2 - 0.02), 1.0))
    return r


PROPS = [dustbin, fire_extinguisher, water_cooler, cctv_camera, wall_clock, afc_gate, bench, pillar,
         lift_doors, token_machine]
TRAINS = [train_coach, coach_interior]  # exported too, but kept out of the small-prop preview grid


# ── Build, export, preview ───────────────────────────────────────────────

def select_tree(r):
    bpy.ops.object.select_all(action="DESELECT")
    r.select_set(True)
    for c in r.children_recursive:
        c.select_set(True)
    bpy.context.view_layer.objects.active = r


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def main():
    # One clean scene per prop, so part names stay exact (no "Body.001") in the exported file.
    for p in PROPS + TRAINS:
        reset()
        r = p()
        select_tree(r)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, r.name + ".gltf"), use_selection=True,
                                  export_apply=True, export_format="GLTF_SEPARATE")
    reset()
    roots = [p() for p in PROPS]
    # Lay them out on a 5 x 2 grid for the .blend and the preview.
    for i, r in enumerate(roots):
        r.location = (i % 5 * 2.2, i // 5 * 3.0, 0)
    roots[3].location.z = 2.0  # CCTV hangs from its ceiling point
    roots[4].location.z = 1.5  # wall clock
    for i, t in enumerate(TRAINS):
        t().location = (6 + i * 5, 14, 0)  # in the .blend, behind the preview grid
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "platform8_props.blend"))
    preview()


def preview():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1000
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 12.5
    cam.location = Vector((4.4 - 9.0, 1.5 - 11.0, 8.0))
    cam.rotation_euler = (math.radians(62), 0, math.radians(-39))
    scene.camera = cam
    scene.render.filepath = os.path.join(ROOT, "art", "preview.png")
    bpy.ops.render.render(write_still=True)


main()
