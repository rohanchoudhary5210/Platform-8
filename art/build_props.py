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

import bmesh
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


COACH_W = 3.0
BAND = (0.93, 1.77)  # window band, above the coach floor
DOOR_HALF = 0.7      # door opening is DOOR_Y ± this
SEGMENTS = [(-COACH_LEN / 2, DOOR_Y[0] - DOOR_HALF)] + \
    [(DOOR_Y[i] + DOOR_HALF, DOOR_Y[i + 1] - DOOR_HALF) for i in range(len(DOOR_Y) - 1)] + \
    [(DOOR_Y[-1] + DOOR_HALF, COACH_LEN / 2)]  # wall between the doors (and at the ends)


def glass_mat(name, rgb, alpha):
    """See-through glass (glTF alpha blend)."""
    if name in _mats:
        return _mats[name]
    m = mat(name, rgb, 0.0, 0.05)
    m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = alpha
    m.diffuse_color = (*rgb, alpha)
    return m


def window_spans():
    """Window openings: each wall segment minus 0.15 m pillars at both ends (none at the very coach ends)."""
    out = []
    for a, b in SEGMENTS:
        a2 = a + (0.6 if a == -COACH_LEN / 2 else 0.15)
        b2 = b - (0.6 if b == COACH_LEN / 2 else 0.15)
        if b2 - a2 > 0.5:
            out.append((a2, b2))
    return out


def join(name, objs):
    """Merge many small parts (handles, dots) into one mesh: one node, one draw call per material."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def wall_skin(r, prefix, material, x, thick, z0, z_bottom, z_top):
    """One side's wall from z_bottom to z_top (absolute), open at the doors and the window band."""
    for a, b in SEGMENTS:
        cy, ln = (a + b) / 2, b - a
        box(f"{prefix}Low_{a:.1f}", r, material, (thick, ln, z0 + BAND[0] - z_bottom), (x, cy, (z_bottom + z0 + BAND[0]) / 2))
        box(f"{prefix}High_{a:.1f}", r, material, (thick, ln, z_top - z0 - BAND[1]), (x, cy, (z0 + BAND[1] + z_top) / 2))
    edges = [-COACH_LEN / 2]
    for a, b in window_spans():
        edges += [a, b]
    edges.append(COACH_LEN / 2)
    for i in range(0, len(edges), 2):  # pillars in the band between windows, skipping door openings
        a, b = edges[i], edges[i + 1]
        for sa, sb in SEGMENTS:
            lo, hi = max(a, sa), min(b, sb)
            if hi - lo > 0.01:
                box(f"{prefix}Pillar_{lo:.2f}", r, material, (thick, hi - lo, BAND[1] - BAND[0]), (x, (lo + hi) / 2, z0 + sum(BAND) / 2))


def coach_inside(r, z0):
    """Everything inside a coach whose floor is at z0: Delhi Metro style stainless long benches, draft screens,
    poles, grab handles, route maps and ads over the windows, an LED display frame in the middle of each wall
    (Display_L / Display_R: the game writes on them), door leaves with a status lamp, a light strip."""
    wall = mat("CoachWall", (0.85, 0.86, 0.88), 0.1, 0.5)
    wall_low = mat("CoachWallLow", (0.72, 0.74, 0.77), 0.1, 0.5)
    frame = mat("WindowRubber", (0.18, 0.19, 0.2), 0.0, 0.8)
    steel = mat("SeatSteel", (0.68, 0.7, 0.73), 0.35, 0.3)
    pole = mat("Pole", (0.75, 0.6, 0.15), 0.4, 0.3)
    screen = mat("DraftScreen", (0.55, 0.62, 0.66), 0.1, 0.15)
    line = mat("RouteLine", (0.84, 0.2, 0.42))
    white = mat("PanelWhite", (0.92, 0.92, 0.9), 0.0, 0.5)
    half, L = COACH_W / 2, COACH_LEN
    box("Floor", r, mat("CoachFloor", (0.36, 0.37, 0.4), 0.0, 0.7), (COACH_W - 0.1, L, 0.1), (0, 0, z0 - 0.05))
    for side in (-1, 1):
        box(f"FloorEdge{side}", r, mat("CoachFloorDark", (0.2, 0.21, 0.23), 0.0, 0.8), (0.55, L, 0.004), (side * 1.18, 0, z0 + 0.002))
    for y in DOOR_Y:
        box(f"DoorPlate{y}", r, mat("DoorPlate", (0.85, 0.65, 0.1), 0.2, 0.5), (COACH_W - 0.1, 1.3, 0.006), (0, y, z0 + 0.003))
    box("Ceiling", r, wall, (2.3, L, 0.1), (0, 0, z0 + 2.55))
    box("LightStrip", r, mat("CoachLight", (1, 1, 0.95), emit=(1, 0.98, 0.9)), (0.3, L - 1.0, 0.03), (0, 0, z0 + 2.49))
    for side in (-1, 1):
        box(f"Cove{side}", r, wall, (0.5, L, 0.06), (side * 1.24, 0, z0 + 2.42), rot=(0, side * math.radians(28), 0))
        box(f"AcGrille{side}", r, mat("Grille", (0.25, 0.26, 0.28), 0.2, 0.6), (0.14, L - 1.0, 0.02), (side * 0.38, 0, z0 + 2.495))
    cyl("Cctv", r, DARK(), 0.07, 0.06, (0.0, 8.0, z0 + 2.47), verts=16)
    for side in (-1, 1):
        x = side * half
        n = "L" if side == -1 else "R"
        wall_skin(r, f"Inner{side}", wall_low, side * (half - 0.04), 0.04, z0, z0, z0 + 2.6)
        for a, b in window_spans():  # window rubber
            box(f"Sill{side}_{a:.1f}", r, frame, (0.08, b - a, 0.05), (side * (half - 0.06), (a + b) / 2, z0 + BAND[0]))
            box(f"Header{side}_{a:.1f}", r, frame, (0.08, b - a, 0.05), (side * (half - 0.06), (a + b) / 2, z0 + BAND[1]))
        for j, y in enumerate(DOOR_Y):
            box(f"DoorHeader{side}_{j}", r, wall, (0.06, 2 * DOOR_HALF, 0.55), (side * (half - 0.04), y, z0 + 2.3))
            box(f"DoorLamp{side}_{j}", r, mat("DoorLamp", (0.9, 0.2, 0.1), emit=(1.0, 0.15, 0.05)), (0.03, 0.12, 0.05),
                (side * (half - 0.08), y, z0 + 2.15))
            box(f"Alarm{side}_{j}", r, mat("AlarmRed", (0.75, 0.05, 0.05), 0.0, 0.4), (0.04, 0.1, 0.16),
                (side * (half - 0.07), y + DOOR_HALF + 0.12, z0 + 1.35))
        # Stainless long benches in each wall segment, a groove every 0.48 m, draft screens at the ends.
        for a, b in SEGMENTS:
            y0, y1 = a + 0.25, b - 0.25
            if y1 - y0 < 0.8:
                continue
            cy = (y0 + y1) / 2
            box(f"Seat{side}_{y0:.1f}", r, steel, (0.46, y1 - y0, 0.05), (side * (half - 0.3), cy, z0 + 0.46), bevel=0.015)
            box(f"SeatBack{side}_{y0:.1f}", r, steel, (0.05, y1 - y0, 0.42), (side * (half - 0.09), cy, z0 + 0.74), rot=(0, side * math.radians(-8), 0))
            box(f"SeatBase{side}_{y0:.1f}", r, DARK(), (0.36, y1 - y0 - 0.1, 0.4), (side * (half - 0.31), cy, z0 + 0.2))
            grooves, k = [], y0 + 0.48
            while k < y1 - 0.2:
                grooves.append(box(f"Groove{side}_{k:.2f}", r, DARK(), (0.44, 0.012, 0.006), (side * (half - 0.3), k, z0 + 0.488)))
                k += 0.48
            if grooves:
                join(f"Grooves{side}_{y0:.1f}", grooves)
            for y in (a, b):
                if abs(y) >= L / 2 - 0.01:
                    continue
                inner = y + (0.08 if y == a else -0.08)
                box(f"Screen{side}_{y:.1f}", r, screen, (0.55, 0.02, 0.75), (side * (half - 0.35), inner, z0 + 0.95))
                box(f"ScreenRail{side}_{y:.1f}", r, pole, (0.6, 0.03, 0.03), (side * (half - 0.34), inner, z0 + 1.34))
                cyl(f"Pole{side}_{y:.1f}", r, pole, 0.02, 2.5, (side * 0.85, inner, z0 + 1.25), verts=10)
        box(f"LadiesSign{side}", r, mat("LadiesPink", (0.9, 0.4, 0.6)), (0.01, 0.4, 0.14), (side * (half - 0.07), -5.0 * side, z0 + 0.95))
        cyl(f"GrabRail{side}", r, pole, 0.018, L - 1, (side * 0.6, 0, z0 + 2.05), rot=(1.5708, 0, 0), verts=10)
        straps, y = [], -L / 2 + 0.8
        poles = [s + d for s in DOOR_Y for d in (-DOOR_HALF - 0.08, DOOR_HALF + 0.08)]
        while y < L / 2 - 0.7:
            if all(abs(y - p) > 0.3 for p in poles):
                straps.append(box(f"Strap{side}_{y:.2f}", r, mat("Strap", (0.2, 0.22, 0.25)), (0.025, 0.01, 0.17), (side * 0.6, y, z0 + 1.95)))
                h = obj_from(bpy.ops.mesh.primitive_torus_add, f"Handle{side}_{y:.2f}", r, pole, (side * 0.6, y, z0 + 1.81),
                             major_radius=0.05, minor_radius=0.009, major_segments=14, minor_segments=5)
                h.rotation_euler = (math.radians(90), 0, math.radians(90))
                straps.append(h)
            y += 0.45
        join(f"GrabHandles{side}", straps)
        # Over the windows: the LED display in the middle, route maps on the next ones, ads beyond.
        px = side * (half - 0.07)
        for k, (a, b) in enumerate(window_spans()):
            cy, w = (a + b) / 2, b - a
            if abs(cy) < 0.1:
                box(f"Display_{n}", r, mat("DisplayDark", (0.02, 0.02, 0.025), 0.0, 0.3), (0.02, 1.8, 0.34), (px, 0, z0 + 2.13))
                box(f"DisplayFrame_{n}", r, frame, (0.015, 1.9, 0.42), (px + side * 0.005, 0, z0 + 2.13))
            elif w > 2.0:
                box(f"RouteMap{side}_{k}", r, white, (0.01, w, 0.36), (px, cy, z0 + 2.13))
                box(f"RouteMapLine{side}_{k}", r, line, (0.012, w - 0.2, 0.03), (px - side * 0.002, cy, z0 + 2.13))
                dots = [cyl(f"Stop{side}_{k}_{i}", r, white, 0.022, 0.016, (px - side * 0.006, a + 0.2 + i * (w - 0.4) / 7, z0 + 2.13),
                            rot=(0, 1.5708, 0), verts=12) for i in range(8)]
                join(f"RouteMapStops{side}_{k}", dots)
            else:
                ad = (0.12, 0.35, 0.65) if (k + side) % 2 else (0.85, 0.45, 0.1)
                box(f"Ad{side}_{k}", r, mat(f"Ad{side}{k}", ad), (0.01, w, 0.36), (px, cy, z0 + 2.13))
                box(f"AdBand{side}_{k}", r, white, (0.012, w, 0.06), (px - side * 0.002, cy, z0 + 2.25))
    for end in (-1, 1):
        box(f"EndWall{end}", r, wall, (COACH_W, 0.08, 2.6), (0, end * L / 2, z0 + 1.3))
        box(f"Gangway{end}", r, DARK(), (1.1, 0.1, 2.0), (0, end * (L / 2 - 0.02), z0 + 1.0))
        for i, dx in enumerate((-0.6, 0.6)):
            box(f"GangwayFrame{end}_{i}", r, frame, (0.1, 0.12, 2.05), (dx, end * (L / 2 - 0.03), z0 + 1.02))
        box(f"GangwayTop{end}", r, frame, (1.3, 0.12, 0.1), (0, end * (L / 2 - 0.03), z0 + 2.05))


def door_leaves(r, prefix, x, z0, material, glass):
    """Each door: two leaves with a see-through glass panel (stiles, rails and the pane)."""
    for j, y in enumerate(DOOR_Y):
        for k, dy in enumerate((-0.35, 0.35)):
            c = y + dy
            box(f"{prefix}Bottom_{j}_{k}", r, material, (0.08, 0.69, 1.0), (x, c, z0 + 0.5))
            box(f"{prefix}Top_{j}_{k}", r, material, (0.08, 0.69, 0.25), (x, c, z0 + 1.875))
            for e in (-1, 1):
                box(f"{prefix}Stile_{j}_{k}_{e}", r, material, (0.08, 0.145, 0.75), (x, c + e * 0.2725, z0 + 1.375))
            box(f"{prefix}Glass_{j}_{k}", r, glass, (0.01, 0.4, 0.75), (x, c, z0 + 1.375))
        box(f"{prefix}Gap_{j}", r, DARK(), (0.085, 0.015, 2.0), (x, y, z0 + 1.0))


def train_coach():
    """One 20 m coach, origin at rail-top centre, floor at FLOOR_Z. Hollow with see-through windows and door
    glass, the full interior inside (coach_inside), so you can look in from the platform.
    Stripe* are the line colour bands; the game tints them."""
    r = root("train_coach")
    body = mat("CoachBody", (0.78, 0.8, 0.83), 0.35, 0.4)
    door = mat("CoachDoor", (0.68, 0.7, 0.73), 0.35, 0.35)
    stripe = mat("LineStripe", (0.84, 0.2, 0.42))
    glass = glass_mat("CoachGlassClear", (0.12, 0.16, 0.18), 0.22)
    rubber = mat("CoachRubber", (0.1, 0.1, 0.11), 0.0, 0.8)
    w, top = COACH_W, 4.0
    coach_inside(r, FLOOR_Z)
    box("Chassis", r, body, (w, COACH_LEN, FLOOR_Z - 0.55), (0, 0, (0.55 + FLOOR_Z) / 2))
    box("RoofSlab", r, body, (w, COACH_LEN, top - FLOOR_Z - 2.6), (0, 0, (FLOOR_Z + 2.6 + top) / 2), bevel=0.04)
    box("Roof", r, mat("CoachRoof", (0.55, 0.56, 0.58), 0.3, 0.5), (w - 0.3, COACH_LEN - 0.4, 0.15), (0, 0, top + 0.07))
    box("Skirt", r, DARK(), (w - 0.2, COACH_LEN - 1.0, 0.5), (0, 0, 0.4))
    for y in (-COACH_LEN / 2 + 3.0, COACH_LEN / 2 - 3.0):  # bogies
        box(f"Bogie{y}", r, DARK(), (2.2, 2.6, 0.45), (0, y, 0.25))
        for wy in (-0.9, 0.9):
            cyl(f"Wheel{y}_{wy}", r, DARK(), 0.42, 2.4, (0, y + wy, 0.42), rot=(0, 1.5708, 0), verts=16)
    for side in (-1, 1):
        x = side * (w / 2 - 0.02)
        wall_skin(r, f"Outer{side}", body, x, 0.05, FLOOR_Z, FLOOR_Z, FLOOR_Z + 2.6)
        door_leaves(r, f"Door{side}", side * (w / 2 - 0.05), FLOOR_Z, door, glass)
        box(f"Stripe{side}", r, stripe, (0.01, COACH_LEN - 0.2, 0.18), (side * (w / 2 + 0.008), 0, FLOOR_Z + 0.45))
        for i, (a, b) in enumerate(window_spans()):
            box(f"Window{side}_{i}", r, glass, (0.01, b - a, BAND[1] - BAND[0]), (side * (w / 2 - 0.02), (a + b) / 2, FLOOR_Z + sum(BAND) / 2))
            for z in BAND:  # black gasket top and bottom on the outside
                box(f"Gasket{side}_{i}_{z}", r, rubber, (0.012, b - a + 0.06, 0.05), (side * (w / 2 + 0.006), (a + b) / 2, FLOOR_Z + z))
        for j, y in enumerate(DOOR_Y):
            for e in (-1, 1):
                box(f"DoorSurround{side}_{j}_{e}", r, rubber, (0.012, 0.05, 2.05), (side * (w / 2 + 0.006), y + e * DOOR_HALF, FLOOR_Z + 1.02))
            box(f"DoorLamp{side}_{j}", r, mat("DoorLampAmber", (1.0, 0.55, 0.1), emit=(1.0, 0.5, 0.05)), (0.03, 0.14, 0.06),
                (side * (w / 2 + 0.02), y, FLOOR_Z + 2.25))
        box(f"NumberPlate{side}", r, mat("NumberPlate", (0.9, 0.9, 0.88)), (0.012, 0.6, 0.18), (side * (w / 2 + 0.008), COACH_LEN / 2 - 1.2, FLOOR_Z + 2.4))
        box(f"Gutter{side}", r, DARK(), (0.04, COACH_LEN - 0.4, 0.04), (side * (w / 2 - 0.05), 0, top - 0.02))
    for end in (-1, 1):
        box(f"EndOuter{end}", r, body, (w, 0.06, top - 0.55), (0, end * (COACH_LEN / 2 + 0.07), (0.55 + top) / 2))
        box(f"EndDoor{end}", r, door, (0.9, 0.02, 2.0), (0, end * (COACH_LEN / 2 + 0.105), FLOOR_Z + 1.0))
        for i in range(4):  # rubber gangway bellows to the next coach
            box(f"Bellows{end}_{i}", r, mat("Bellows", (0.06, 0.06, 0.07), 0.0, 0.9), (1.5 - (i % 2) * 0.08, 0.1, 2.4 - (i % 2) * 0.08),
                (0, end * (COACH_LEN / 2 + 0.16 + i * 0.1), FLOOR_Z + 1.15))
    for y in (-COACH_LEN / 4, COACH_LEN / 4):  # roof AC units with grilles, ribs between
        box(f"AcUnit{y}", r, mat("AcUnit", (0.62, 0.63, 0.65), 0.3, 0.5), (2.2, 3.2, 0.32), (0, y, top + 0.3), bevel=0.04)
        for k in range(5):
            box(f"AcGrille{y}_{k}", r, DARK(), (1.8, 0.08, 0.01), (0, y - 1.2 + k * 0.6, top + 0.465))
    for k in range(9):
        box(f"RoofRib{k}", r, mat("CoachRoof", (0.55, 0.56, 0.58), 0.3, 0.5), (w - 0.4, 0.05, 0.03), (0, -1.6 + k * 0.4, top + 0.16))
    for y, size in ((-3.2, 1.8), (0.0, 2.6), (3.2, 1.8)):  # underframe equipment boxes
        box(f"Underframe{y}", r, DARK(), (2.0, size, 0.38), (0, y, 0.42), bevel=0.02)
    return r


def coach_interior():
    """The coach from inside, for the ride: same interior as train_coach (floor at origin), no outer shell, so the
    window band opens on the tunnel. Display_L is in the middle of the left wall."""
    r = root("coach_interior")
    coach_inside(r, 0.0)
    for side in (-1, 1):
        door_leaves(r, f"Door{side}", side * (COACH_W / 2 - 0.05), 0.0, mat("CoachDoor", (0.68, 0.7, 0.73), 0.35, 0.35),
                    mat("CoachGlass", (0.03, 0.04, 0.05), 0.0, 0.1))
    return r


PROPS = [dustbin, fire_extinguisher, water_cooler, cctv_camera, wall_clock, afc_gate, bench, pillar,
         lift_doors, token_machine]
TRAINS = [train_coach, coach_interior]  # exported too, but kept out of the small-prop preview grid


STAIR_WIDTH, STAIR_DROP, STAIR_RUN = 1.6, 3.5, 6.0


def stairs(name, n):
    """One straight flight going down towards +Y (Godot -Z), origin at the top edge, floor level.
    n steps share the same drop and run, so stairs_extra (anomaly #34) is the same flight cut finer.
    Step<i> treads with yellow anti-slip nosing, side stringers and steel handrails."""
    r = root(name)
    rise, tread = STAIR_DROP / n, STAIR_RUN / n
    concrete = mat("StairConcrete", (0.42, 0.42, 0.43), 0.0, 0.8)
    nosing = mat("StairNosing", (0.9, 0.75, 0.1), 0.0, 0.5, emit=(0.12, 0.1, 0.01))  # faint glow: reads in the dim well
    for i in range(n):
        top = -(i + 1) * rise
        box(f"Step{i}", r, concrete, (STAIR_WIDTH, tread, rise + 0.25), (0, (i + 0.5) * tread, top - (rise + 0.25) / 2))
        box(f"Nosing{i}", r, nosing, (STAIR_WIDTH - 0.1, 0.07, 0.02), (0, (i + 1) * tread - 0.035, top + 0.01))
    slope = math.atan2(STAIR_DROP, STAIR_RUN)
    length = math.hypot(STAIR_DROP, STAIR_RUN)
    mid = Vector((0, STAIR_RUN / 2, -STAIR_DROP / 2))
    for side in (-1, 1):
        x = side * (STAIR_WIDTH / 2 + 0.03)
        box(f"Stringer{side}", r, DARK(), (0.06, length + 0.3, 0.35), mid + Vector((x, 0, 0.05)), rot=(-slope, 0, 0))
        cyl(f"Handrail{side}", r, STEEL(), 0.025, length + 0.4, mid + Vector((x, 0, 0.9)), rot=(math.pi / 2 - slope, 0, 0), verts=10)
        for k in range(4):
            t = (k + 0.5) / 4
            cyl(f"Post{side}_{k}", r, STEEL(), 0.02, 0.9, (x, STAIR_RUN * t, -STAIR_DROP * t + 0.45), verts=8)
    return r


STAIRS = [lambda: stairs("stairs", 20), lambda: stairs("stairs_extra", 28)]  # exported, not in the preview grid


# ── Escalator ────────────────────────────────────────────────────────────
# Two lanes side by side going down towards +Y (Godot -Z): origin at the top of the step nosing line.
# The slope is 1:2 (10 m drop over 20 m), the same as a 0.2 m riser on a 0.4 m tread, so the steps
# make a true staircase on the incline. Lanes at x = -0.95 (up) and +0.95 (down), steps 1.0 m wide.
ESC_DROP, ESC_RUN = 10.0, 20.0
ESC_LANES = (-0.95, 0.95)
ESC_SLOPE = math.atan2(ESC_DROP, ESC_RUN)


def esc_z(d):
    """Height of the nosing line d metres (horizontal) down the run; flat beyond the ends."""
    return -ESC_DROP * min(max(d, 0.0), ESC_RUN) / ESC_RUN


def esc_part(name, r, material, x, w, h, off, d0=0.0, d1=ESC_RUN, bevel=0.0):
    """A box running along the escalator from d0 to d1, its centre `off` above the nosing line.
    Sloped on the incline, flat on the landings (d0, d1 both outside 0..ESC_RUN)."""
    if d1 <= 0.0 or d0 >= ESC_RUN:  # landing: flat
        return box(name, r, material, (w, d1 - d0, h), (x, (d0 + d1) / 2, esc_z(d0) + off), bevel=bevel)
    length = (d1 - d0) / math.cos(ESC_SLOPE)
    mid = (d0 + d1) / 2
    return box(name, r, material, (w, length, h), (x, mid, esc_z(mid) + off), rot=(-ESC_SLOPE, 0, 0), bevel=bevel)


def handrail_end(name, r, material, x, d, z, keep_back):
    """Handrail turning down at a newel: half a torus in the YZ plane."""
    bpy.ops.mesh.primitive_torus_add(location=(x, d, z + 0.45), rotation=(0, math.pi / 2, 0),
                                     major_radius=0.45, minor_radius=0.04, major_segments=32, minor_segments=8)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co.y > 0.001 if keep_back else v.co.y < -0.001)], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    o.parent = r
    return o


def escalator():
    """Balustrades (glass, steel deck, black handrail, skirt lights), comb plates and landing plates
    for both lanes. The moving steps are escalator_step, placed by Station.gd."""
    r = root("escalator")
    glass = glass_mat("EscGlass", (0.6, 0.75, 0.78), 0.22)
    rail = mat("Handrail", (0.03, 0.03, 0.03), 0.0, 0.35)
    deck = mat("EscDeck", (0.6, 0.62, 0.64), 0.35, 0.3)
    skirt = mat("EscSkirt", (0.5, 0.52, 0.54), 0.35, 0.25)
    glow = mat("SkirtLight", (0.9, 0.95, 1.0), emit=(0.8, 0.9, 1.0))
    comb = mat("CombYellow", (0.85, 0.65, 0.08), 0.2, 0.5)
    plate = mat("LandingPlate", (0.42, 0.43, 0.45), 0.35, 0.45)
    parts = {"glass": [], "rail": [], "deck": [], "skirt": [], "glow": [], "comb": [], "plate": []}
    spans = [(-1.2, 0.0), (0.0, ESC_RUN), (ESC_RUN, ESC_RUN + 1.2)]  # top newel, incline, bottom newel
    for lane in ESC_LANES:
        for side in (-1, 1):
            gx, kx = lane + side * 0.6, lane + side * 0.52
            for i, (d0, d1) in enumerate(spans):
                parts["glass"].append(esc_part(f"Glass{lane}{side}{i}", r, glass, gx, 0.02, 0.8, 0.55, d0, d1))
                parts["rail"].append(esc_part(f"Rail{lane}{side}{i}", r, rail, gx, 0.08, 0.05, 0.98, d0, d1, bevel=0.02))
                parts["skirt"].append(esc_part(f"Skirt{lane}{side}{i}", r, skirt, kx, 0.02, 0.37, -0.065, d0, d1))
                parts["glow"].append(esc_part(f"Glow{lane}{side}{i}", r, glow, lane + side * 0.505, 0.01, 0.012, 0.11, d0, d1))
            parts["rail"].append(handrail_end(f"RailTop{lane}{side}", r, rail, gx, -1.2, 0.08, True))
            parts["rail"].append(handrail_end(f"RailBot{lane}{side}", r, rail, gx, ESC_RUN + 1.2, esc_z(ESC_RUN) + 0.08, False))
        # Comb plates where the steps slide under, and ribbed landing plates beyond them.
        for d0, d1, cd in ((-0.35, 0.0, 0.0), (ESC_RUN, ESC_RUN + 0.35, ESC_RUN)):
            parts["comb"].append(box(f"Comb{lane}{d0}", r, comb, (1.0, 0.08, 0.025), (lane, cd + (-0.04 if d0 < 0 else 0.04), esc_z(cd) + 0.0125)))
            parts["plate"].append(box(f"CombPlate{lane}{d0}", r, plate, (1.0, d1 - d0, 0.02), (lane, (d0 + d1) / 2, esc_z(cd) + 0.01)))
        for d0, d1 in ((-1.3, -0.35), (ESC_RUN + 0.35, ESC_RUN + 1.3)):
            parts["plate"].append(box(f"Landing{lane}{d0}", r, plate, (1.15, d1 - d0, 0.015), (lane, (d0 + d1) / 2, esc_z(d0) + 0.0075)))
            for k in range(8):  # ribs
                parts["plate"].append(box(f"Rib{lane}{d0}_{k}", r, plate, (1.1, 0.02, 0.01),
                                          (lane, d0 + (k + 0.5) * (d1 - d0) / 8, esc_z(d0) + 0.02)))
    # Decks: the centre one between the lanes, the outer ones out to the shaft walls.
    for x, w in ((0.0, 0.86), (1.735, 0.53), (-1.735, 0.53)):
        for i, (d0, d1) in enumerate(spans):
            parts["deck"].append(esc_part(f"Deck{x}{i}", r, deck, x, w, 0.04, 0.12, d0, d1))
            parts["deck"].append(esc_part(f"DeckSide{x}{i}", r, deck, x, w - 0.04, 0.3, -0.05, d0, d1))
    for k, objs in parts.items():  # one mesh per material: a few draw calls, not hundreds
        join(k.capitalize(), objs).parent = r
    return r


def escalator_step():
    """One step, origin at its nosing (front top edge), tread running back towards -Y (Godot +Z, uphill).
    Grooved aluminium tread with yellow demarcation edges, riser below the nosing."""
    r = root("escalator_step")
    alu = mat("StepAlu", (0.32, 0.33, 0.35), 0.35, 0.45)
    yellow = mat("StepYellow", (0.95, 0.75, 0.05), 0.0, 0.5)
    parts = [box("Tread", r, alu, (1.0, 0.4, 0.03), (0, -0.2, -0.019)),
             box("Riser", r, alu, (1.0, 0.015, 0.2), (0, -0.0075, -0.1))]
    for k in range(25):  # cleats
        parts.append(box(f"Cleat{k}", r, alu, (0.012, 0.4, 0.008), (-0.48 + k * 0.04, -0.2, -0.002)))
    edges = [box("EdgeFront", r, yellow, (1.0, 0.045, 0.01), (0, -0.0225, 0.0))]
    for side in (-1, 1):
        edges.append(box(f"EdgeSide{side}", r, yellow, (0.035, 0.4, 0.01), (side * 0.4825, -0.2, 0.0)))
    tread = join("Step", parts + edges)
    tread.parent = r
    return r


ESCALATOR = [escalator, escalator_step]  # exported, not in the preview grid


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
    for p in PROPS + TRAINS + STAIRS + ESCALATOR:
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
