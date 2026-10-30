"""Dash, Flutter's mascot, out in Name City: a round blue hummingbird
sculpted like the people (sdf.py: shapes blended like clay, meshed,
brought down to a few thousand triangles, their normals the sculpture's
own), and what Dashes carry on holiday or on the way to work.

Each part keeps the frame dashes.dart poses it in (size 1: a Dash about
0.75 m to the top of its tuft, facing −z):
  dash_body, dash_eyes, dash_pupils, dash_glints
                         the ground under its middle
  dash_wing_r, _l        the shoulder, the wing hanging down −y
  dash_foot              the hip, the foot on the ground 0.11 below
  acc_glasses, acc_hat, acc_camera, acc_tie, acc_backpack
                         the body's frame (worn)
  acc_suitcase           its wheels' axle, the case standing up +y, its
                         handle at the top
  acc_briefcase          its handle's grip, the case hanging below
  acc_cup                its middle
  acc_ninja_hood, acc_ninja_band, acc_katana
                         the body's frame (worn: a ninja Dash's)
Colours are in the vertex colours (linear): the suitcase's and the
backpack's shells are light greys for an instance's colour to tint.

Run headless:
  Blender -b --factory-startup -P tool/blender/dash.py -- assets/models [--preview dir]
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sdf as S  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
OUT = argv[0]
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else None

bpy.ops.wm.read_factory_settings(use_empty=True)
made = []
F = S.F


def lin(c):
    """An sRGB colour (0xRRGGBB) as linear RGB."""
    return np.array([((c >> s) & 255) / 255.0 for s in (16, 8, 0)]) ** 2.2


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.clip(t, 0.0, 1.0)[:, None]
    return a * (1 - t) + b * t


def solid(c, n):
    return np.tile(c, (n, 1))


BLUE = lin(0x1177D6)
BLUE_DARK = lin(0x0A5DB2)
BELLY = lin(0xD4F2FF)
BEAK = lin(0x0B2340)
FEET = lin(0x163A66)


# ── From a field to a part (as people.py) ────────────────────────────────────


def part(name, field, lo, hi, step, tris, colour, reach=0.012):
    D, origin = S.sample(field, lo, hi, step)
    v, q = S.surface_nets(D, origin, step)
    q = S.orient(field, v, q)
    me = bpy.data.meshes.new(name)
    # (Blender's x, y, z are the city's x, z, y: a mirror, so each face
    # turns round to keep facing out.)
    me.from_pydata(v[:, [0, 2, 1]].tolist(), [], q[:, ::-1].tolist())
    me.validate()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    before = sum(len(p.vertices) - 2 for p in me.polygons)
    dec = ob.modifiers.new("decimate", "DECIMATE")
    dec.ratio = min(1.0, tris / max(1, before))
    dec.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    p = co.reshape(-1, 3)[:, [0, 2, 1]]
    p = S.project(field, p)
    nrm = S.normals(field, p)
    me.vertices.foreach_set("co", p[:, [0, 2, 1]].ravel())
    me.update()
    open_ = S.occlusion(field, p, nrm, reach=reach)
    col = np.clip(colour(p, nrm, open_), 0.0, 1.0)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.concatenate([col, np.ones((len(col), 1))], axis=1).ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    for poly in me.polygons:
        poly.use_smooth = True
    tri = np.array([list(poly.vertices) for poly in me.polygons])
    centre = p[tri].mean(axis=1)
    corner = (0.8 * p[tri] + 0.2 * centre[:, None, :]).reshape(-1, 3)
    loop_n = S.normals(field, corner)
    vi = tri.ravel()
    order = np.argsort(vi, kind="stable")
    bounds = np.searchsorted(vi[order], np.arange(len(p) + 1))
    cos_split = math.cos(math.radians(32))
    for k in range(len(p)):
        idx = order[bounds[k] : bounds[k + 1]]
        groups = []
        for i in idx:
            for g in groups:
                if loop_n[i] @ g[0] > cos_split:
                    g[1].append(i)
                    break
            else:
                groups.append([loop_n[i].copy(), [i]])
        for _, members in groups:
            m = loop_n[members].sum(axis=0)
            loop_n[members] = m / max(1e-9, np.linalg.norm(m))
    me.normals_split_custom_set(loop_n[:, [0, 2, 1]].tolist())
    made.append(ob)
    print(f"PART {name}: {len(me.polygons)} tris (from {before})")
    return ob


def shade(c, o, k=0.3):
    return c * (1 - k + k * o)[:, None]


# ── Dash ─────────────────────────────────────────────────────────────────────

# Its body: an egg, rounder below; the face on the front with the eyes
# high and wide apart, a long thin beak between them; a tuft of three
# feathers curling back off the top, a short fan of a tail.
EYES = [(s * 0.088, 0.455, -0.185) for s in (-1, 1)]
BEAK_A, BEAK_B = (0, 0.392, -0.21), (0, 0.366, -0.39)


def egg(p):
    d = S.ellipsoid(p, (0, 0.36, 0.0), (0.235, 0.27, 0.245))
    return S.smin(d, S.ellipsoid(p, (0, 0.25, -0.015), (0.215, 0.19, 0.215)), 0.07)


def body_field(p):
    d = egg(p)
    for a in (-0.4, 0.0, 0.4):
        tip = (math.sin(a) * 0.11, 0.14 + 0.03 * abs(a), 0.39 - 0.03 * abs(a))
        d = S.smin(d, S.round_cone(p, (0, 0.25, 0.17), tip, 0.052, 0.016), 0.04)
    for x0, x1, h, back in ((0.0, 0.0, 0.775, 0.08), (-0.045, -0.085, 0.72, 0.1), (0.045, 0.085, 0.72, 0.1)):
        d = S.smin(d, S.chain(p, [(x0, 0.575, -0.01), ((x0 + x1) / 2, h - 0.05, back * 0.25), (x1, h, back)], [0.03, 0.019, 0.008]), 0.022)
    return S.smin(d, S.round_cone(p, BEAK_A, BEAK_B, 0.036, 0.006), 0.012)


def body_colour(p, n, o):
    pf = p.astype(F)
    c = solid(BLUE, len(p))
    belly = S.ellipsoid(pf, (0, 0.265, -0.13), (0.165, 0.2, 0.17))
    c = mix(c, BELLY, smoothstep(0.01, -0.01, belly))
    # The feathers' tips a shade darker.
    tuft = smoothstep(0.66, 0.74, p[:, 1])
    tail = smoothstep(0.3, 0.4, p[:, 2])
    c = mix(c, BLUE_DARK, np.maximum(tuft, tail) * 0.8)
    beak = S.round_cone(pf, BEAK_A, BEAK_B, 0.036, 0.006)
    c = mix(c, BEAK, smoothstep(0.006, -0.001, beak) * (p[:, 2] < -0.2))
    return shade(c, o)


def eyes_field(p):
    d = None
    for c in EYES:
        e = S.sphere(p, c, 0.07)
        d = e if d is None else np.minimum(d, e)
    return d


def eyes_colour(p, n, o):
    return shade(solid(np.array([0.92, 0.94, 0.96]), len(p)), o, 0.25)


def _look(s):
    v = np.array([s * 0.12, 0.05, -1.0])
    return v / np.linalg.norm(v)


def pupils_field(p):
    # A big black cap on the front of each eye, a hair proud of it.
    d = None
    for s, c in zip((-1, 1), EYES):
        cap = np.maximum(S.sphere(p, c, 0.0712), -((p - np.array(c, dtype=F)) @ _look(s).astype(F) - F(0.07 * 0.68)))
        d = cap if d is None else np.minimum(d, cap)
    return d


def glints_field(p):
    d = None
    for s, c in zip((-1, 1), EYES):
        g = _look(s) + np.array([-s * 0.33, 0.42, 0.0])
        g /= np.linalg.norm(g)
        e = S.sphere(p, np.array(c) + 0.0705 * g, 0.0115)
        d = e if d is None else np.minimum(d, e)
    return d


def wing_field(side):
    def f(p):
        q = p.copy()
        q[:, 0] *= side
        d = S.ellipsoid(q, (0.018, -0.085, 0.03), (0.032, 0.115, 0.085), rot=S.rot_z(-0.22))
        for a in (-0.3, 0.0, 0.3):
            d = S.smin(d, S.round_cone(q, (0.024, -0.1, 0.03 + a * 0.06), (0.04, -0.205 + 0.03 * abs(a), 0.055 + a * 0.13), 0.028, 0.009), 0.02)
        return d

    return f


def wing_colour(p, n, o):
    c = mix(solid(BLUE, len(p)), BLUE_DARK, smoothstep(-0.12, -0.19, p[:, 1]))
    return shade(c, o)


def foot_field(p):
    d = S.capsule(p, (0, 0, 0), (0, -0.075, 0.005), 0.016)
    for a in (-0.5, 0.0, 0.5):
        tip = (math.sin(a) * 0.045, -0.1, -math.cos(a) * 0.058)
        d = S.smin(d, S.round_cone(p, (0, -0.088, 0.0), tip, 0.016, 0.01), 0.012)
    return S.smin(d, S.round_cone(p, (0, -0.088, 0.0), (0, -0.1, 0.035), 0.015, 0.009), 0.01)


# ── What they carry ──────────────────────────────────────────────────────────


def glasses_field(p):
    d = S.capsule(p, (-0.026, 0.474, -0.287), (0.026, 0.474, -0.287), 0.008)
    for s in (-1, 1):
        lens = S.ellipsoid(p, (s * 0.09, 0.46, -0.285), (0.074, 0.058, 0.012))
        arm = S.chain(p, [(s * 0.16, 0.472, -0.27), (s * 0.228, 0.472, -0.2), (s * 0.226, 0.47, -0.06)], [0.007, 0.007, 0.007])
        d = np.minimum(d, np.minimum(lens, arm))
    return d


def glasses_colour(p, n, o):
    lens = (np.abs(p[:, 0]) < 0.16) & (p[:, 2] < -0.276)
    c = np.where(lens[:, None], np.array([0.012, 0.02, 0.04]), np.array([0.02, 0.02, 0.022]))
    return shade(c, o, 0.2)


def hat_field(p):
    crown = S.ellipsoid(p, (0, 0.65, 0.015), (0.158, 0.138, 0.158))
    crown = np.maximum(crown, -(p[:, 1] - 0.585))
    brim = S.ellipsoid(p, (0, 0.592, 0.015), (0.3, 0.014, 0.3))
    return S.smin(crown, brim, 0.016)


def hat_colour(p, n, o):
    straw = lin(0xE6CF98)
    weave = 0.93 + 0.07 * np.sin(p[:, 0] * 180) * np.sin(p[:, 2] * 180)
    c = solid(straw, len(p)) * weave[:, None]
    band = (p[:, 1] > 0.6) & (p[:, 1] < 0.638) & (np.hypot(p[:, 0], p[:, 2] - 0.015) < 0.17)
    c = np.where(band[:, None], lin(0xD9474A), c)
    return shade(c, o, 0.35)


def camera_field(p):
    d = S.box(p, (0, 0.285, -0.258), (0.052, 0.034, 0.022), r=0.007)
    d = np.minimum(d, S.capsule(p, (0, 0.283, -0.27), (0, 0.283, -0.305), 0.021))
    for s in (-1, 1):
        d = np.minimum(d, S.chain(p, [(s * 0.046, 0.305, -0.252), (s * 0.13, 0.43, -0.2), (s * 0.19, 0.52, -0.09)], [0.006, 0.006, 0.006]))
    return d


def camera_colour(p, n, o):
    c = solid(np.array([0.025, 0.025, 0.028]), len(p))
    rim = (p[:, 2] < -0.29) & (np.hypot(p[:, 0], p[:, 1] - 0.283) > 0.012)
    c = np.where(rim[:, None], np.array([0.55, 0.56, 0.58]), c)
    top = (p[:, 1] > 0.312) & (np.abs(p[:, 0]) < 0.06) & (p[:, 2] < -0.236)
    c = np.where(top[:, None], np.array([0.5, 0.5, 0.52]), c)
    return shade(c, o, 0.25)


def tie_field(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    shell = np.abs(egg(p) - 0.006) - 0.0045
    w = np.interp(y, [0.2, 0.226, 0.31, 0.326], [0.0, 0.038, 0.02, 0.016])
    mask = np.maximum(np.abs(x) - w, np.maximum(0.2 - y, y - 0.326))
    blade = np.maximum(np.maximum(shell, mask), z + 0.12)
    knot = S.ellipsoid(p, (0, 0.336, -0.252), (0.024, 0.019, 0.013))
    return S.smin(blade, knot, 0.004)


def tie_colour(p, n, o):
    stripe = np.sin((p[:, 0] + p[:, 1]) * 140) > 0.55
    c = np.where(stripe[:, None], lin(0x8E1F2A), lin(0xC9303D))
    return shade(c, o, 0.25)


def backpack_field(p):
    bag = S.box(p, (0, 0.36, 0.255), (0.15, 0.16, 0.06), r=0.045)
    pocket = S.box(p, (0, 0.3, 0.31), (0.105, 0.075, 0.024), r=0.02)
    loop = S.capsule(p, (-0.03, 0.525, 0.24), (0.03, 0.525, 0.24), 0.008)
    return np.minimum(S.smin(bag, pocket, 0.01), loop)


def backpack_colour(p, n, o):
    c = solid(np.array([0.8, 0.8, 0.8]), len(p))
    c = np.where((p[:, 2] > 0.3)[:, None], np.array([0.62, 0.62, 0.62]), c)
    return shade(c, o, 0.35)


def suitcase_field(p):
    case = S.box(p, (0, 0.235, -0.065), (0.14, 0.205, 0.068), r=0.03)
    d = case
    for s in (-1, 1):
        d = np.minimum(d, S.capsule(p, (s * 0.085, 0.0, 0.0), (s * 0.118, 0.0, 0.0), 0.026))
        d = np.minimum(d, S.capsule(p, (s * 0.052, 0.43, -0.004), (s * 0.052, 0.64, -0.004), 0.007))
    return np.minimum(d, S.capsule(p, (-0.062, 0.645, -0.004), (0.062, 0.645, -0.004), 0.012))


def suitcase_colour(p, n, o):
    shell = np.array([0.85, 0.85, 0.85])
    ribs = np.where((np.abs(np.abs(p[:, 0]) - 0.07) < 0.008)[:, None], np.array([0.7, 0.7, 0.7]), shell)
    dark = (p[:, 1] < 0.035) | (p[:, 1] > 0.43)
    c = np.where(dark[:, None], np.array([0.03, 0.03, 0.035]), ribs)
    return shade(c, o, 0.3)


def briefcase_field(p):
    case = S.box(p, (0, -0.115, 0), (0.135, 0.088, 0.036), r=0.012)
    handle = S.chain(p, [(-0.048, -0.028, 0), (-0.042, -0.004, 0), (0.042, -0.004, 0), (0.048, -0.028, 0)], [0.008] * 4)
    clasp = S.box(p, (0, -0.045, -0.036), (0.018, 0.012, 0.006), r=0.003)
    return np.minimum(np.minimum(case, handle), clasp)


def briefcase_colour(p, n, o):
    c = solid(lin(0x7E4F2E), len(p))
    c = np.where((p[:, 1] > -0.03)[:, None], lin(0x4A2C18), c)
    clasp = (np.abs(p[:, 0]) < 0.02) & (p[:, 2] < -0.035) & (p[:, 1] > -0.06)
    c = np.where(clasp[:, None], lin(0xD8B25A), c)
    return shade(c, o, 0.3)


def cup_field(p):
    cup = S.round_cone(p, (0, -0.05, 0), (0, 0.045, 0), 0.029, 0.036)
    cup = np.maximum(cup, np.maximum(-(p[:, 1] + 0.058), p[:, 1] - 0.05))
    lid = S.ellipsoid(p, (0, 0.056, 0), (0.04, 0.012, 0.04))
    return S.smin(cup, lid, 0.004)


def cup_colour(p, n, o):
    c = solid(np.array([0.88, 0.87, 0.85]), len(p))
    c = np.where(((p[:, 1] > -0.022) & (p[:, 1] < 0.022))[:, None], lin(0xB27A48), c)
    c = np.where((p[:, 1] > 0.046)[:, None], np.array([0.04, 0.04, 0.045]), c)
    return shade(c, o, 0.25)


# ── A ninja's ───────────────────────────────────────────────────────────────


def hood_field(p):
    # A cowl over the head and down the neck, just off the feathers; its
    # slit open for the eyes (the beak comes through below it, the tuft
    # out of the top).
    shell = np.abs(egg(p) - 0.016) - 0.007
    cowl = np.maximum(shell, 0.34 - p[:, 1])
    slit = S.box(p, (0, 0.458, -0.2), (0.205, 0.062, 0.2), r=0.03)
    return np.maximum(cowl, -slit)


def hood_colour(p, n, o):
    return shade(solid(lin(0x1E2230), len(p)), o, 0.35)


def band_field(p):
    # Round the head over the slit, knotted behind, its tails flying.
    ring = np.maximum(np.abs(egg(p) - 0.03) - 0.006, np.abs(p[:, 1] - 0.548) - 0.022)
    knot = S.ellipsoid(p, (0, 0.55, 0.205), (0.032, 0.027, 0.022))
    tails = np.minimum(
        S.chain(p, [(0.0, 0.55, 0.21), (0.05, 0.53, 0.29), (0.09, 0.47, 0.35)], [0.015, 0.012, 0.009]),
        S.chain(p, [(0.0, 0.55, 0.21), (-0.03, 0.5, 0.28), (-0.045, 0.42, 0.32)], [0.015, 0.012, 0.009]),
    )
    return np.minimum(np.minimum(ring, knot), tails)


def band_colour(p, n, o):
    return shade(solid(lin(0xC8352B), len(p)), o, 0.3)


KATANA_A, KATANA_B = np.array([-0.14, 0.16, 0.245]), np.array([0.12, 0.58, 0.235])


def katana_field(p):
    # Across its back from the left hip to over the right shoulder: the
    # lacquered scabbard, the guard, the wrapped hilt.
    a, b = KATANA_A, KATANA_B
    d = (b - a) / np.linalg.norm(b - a)
    scabbard = S.capsule(p, a, b, 0.017)
    guard = S.round_cone(p, b - d * 0.005, b + d * 0.007, 0.033, 0.033)
    hilt = S.capsule(p, b + d * 0.02, b + d * 0.13, 0.0145)
    return np.minimum(np.minimum(scabbard, guard), hilt)


def katana_colour(p, n, o):
    a, b = KATANA_A, KATANA_B
    length = np.linalg.norm(b - a)
    t = (p - a) @ ((b - a) / length)
    c = solid(lin(0x1A1416), len(p))
    c = np.where(((t > length - 0.012) & (t < length + 0.012))[:, None], lin(0xC9A24A), c)
    wrap = np.where((np.sin(t * 160) > 0.2)[:, None], lin(0xE8DCC0), lin(0x1E1E22))
    c = np.where((t >= length + 0.012)[:, None], wrap, c)
    return shade(c, o, 0.3)


part("dash_body", body_field, (-0.3, 0.0, -0.42), (0.3, 0.82, 0.5), 0.0035, 3600, body_colour, reach=0.03)
part("dash_eyes", eyes_field, (-0.18, 0.37, -0.27), (0.18, 0.54, -0.1), 0.0012, 900, eyes_colour, reach=0.005)
part("dash_pupils", pupils_field, (-0.18, 0.37, -0.27), (0.18, 0.54, -0.18), 0.0008, 900, lambda p, n, o: shade(solid(np.array([0.01, 0.012, 0.018]), len(p)), o, 0.1), reach=0.003)
part("dash_glints", glints_field, (-0.18, 0.4, -0.27), (0.18, 0.53, -0.2), 0.0006, 300, lambda p, n, o: solid(np.array([1.0, 1.0, 1.0]), len(p)), reach=0.002)
part("dash_wing_r", wing_field(1), (-0.03, -0.25, -0.1), (0.1, 0.05, 0.2), 0.0018, 700, wing_colour, reach=0.01)
part("dash_wing_l", wing_field(-1), (-0.1, -0.25, -0.1), (0.03, 0.05, 0.2), 0.0018, 700, wing_colour, reach=0.01)
part("dash_foot", foot_field, (-0.08, -0.13, -0.09), (0.08, 0.03, 0.06), 0.0015, 500, lambda p, n, o: shade(solid(FEET, len(p)), o), reach=0.006)
part("acc_glasses", glasses_field, (-0.26, 0.38, -0.32), (0.26, 0.54, -0.03), 0.0013, 1200, glasses_colour, reach=0.004)
part("acc_hat", hat_field, (-0.32, 0.56, -0.3), (0.32, 0.81, 0.33), 0.0025, 2200, hat_colour, reach=0.02)
part("acc_camera", camera_field, (-0.22, 0.23, -0.33), (0.22, 0.56, -0.05), 0.0013, 1200, camera_colour, reach=0.006)
part("acc_tie", tie_field, (-0.06, 0.18, -0.29), (0.06, 0.37, -0.15), 0.001, 700, tie_colour, reach=0.004)
part("acc_backpack", backpack_field, (-0.2, 0.17, 0.15), (0.2, 0.56, 0.36), 0.0025, 1200, backpack_colour, reach=0.02)
part("acc_suitcase", suitcase_field, (-0.18, -0.04, -0.16), (0.18, 0.68, 0.04), 0.0025, 1400, suitcase_colour, reach=0.02)
part("acc_briefcase", briefcase_field, (-0.16, -0.22, -0.06), (0.16, 0.01, 0.06), 0.0016, 900, briefcase_colour, reach=0.01)
part("acc_cup", cup_field, (-0.05, -0.07, -0.05), (0.05, 0.08, 0.05), 0.0008, 600, cup_colour, reach=0.006)
part("acc_ninja_hood", hood_field, (-0.29, 0.32, -0.32), (0.29, 0.69, 0.3), 0.0025, 2600, hood_colour, reach=0.02)
part("acc_ninja_band", band_field, (-0.3, 0.4, -0.31), (0.3, 0.6, 0.39), 0.0018, 1600, band_colour, reach=0.01)
part("acc_katana", katana_field, (-0.18, 0.12, 0.2), (0.17, 0.73, 0.28), 0.0012, 1200, katana_colour, reach=0.006)


# ── Out ──────────────────────────────────────────────────────────────────────


def export(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_texcoords=False,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_active_vertex_color_when_no_material=True,
    )
    print(f"MODEL dash: {sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made)} tris -> {path}")


export(f"{OUT}/dash.glb")


# ── Previews (Blender's workbench, the parts assembled as dashes.dart does) ──


def placed(name, at=(0, 0, 0), rot=None, suffix=""):
    """A copy of part [name] moved to [at] (city coordinates), turned [rot]
    (Euler, radians, Blender's axes)."""
    src = bpy.data.objects[name]
    cp = src.copy()
    cp.data = src.data.copy()
    cp.name = f"{name}{suffix} preview"
    cp.location = (at[0], at[2], at[1])
    if rot:
        cp.rotation_euler = rot
    bpy.context.collection.objects.link(cp)
    return cp


def render(path, at, target, objects, lens=60, size=(560, 560)):
    scene = bpy.context.scene
    for o in scene.objects:
        o.hide_render = o.type == "MESH" and o not in objects
    cam = bpy.data.objects.get("cam") or bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.location = (at[0], at[2], at[1])
    cam.rotation_euler = (Vector((target[0], target[2], target[1])) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = False
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if PREVIEW:
    base = [placed("dash_body"), placed("dash_eyes"), placed("dash_pupils"), placed("dash_glints")]
    base += [placed("dash_wing_r", (0.215, 0.385, 0.02)), placed("dash_wing_l", (-0.215, 0.385, 0.02))]
    base += [placed("dash_foot", (0.07, 0.11, 0.0), suffix="r"), placed("dash_foot", (-0.07, 0.11, 0.0), suffix="l")]
    holiday = [placed("acc_glasses"), placed("acc_hat"), placed("acc_camera"), placed("acc_suitcase", (0.3, 0.0, 0.42), rot=(math.radians(-38), 0, 0))]
    work = [placed("acc_tie"), placed("acc_backpack"), placed("acc_cup", (0.26, 0.24, -0.1)), placed("acc_briefcase", (-0.27, 0.2, 0.03))]
    views = [((0.0, 0.45, -1.9), (0, 0.36, 0)), ((1.2, 0.6, -1.5), (0, 0.33, 0)), ((1.9, 0.45, 0.0), (0, 0.36, 0)), ((-1.0, 0.7, 1.6), (0, 0.33, 0))]
    ninja = [placed("acc_ninja_hood"), placed("acc_ninja_band"), placed("acc_katana")]
    for tag, extra in (("plain", []), ("holiday", holiday), ("work", work), ("ninja", ninja)):
        for k, (at, tgt) in enumerate(views):
            render(f"{PREVIEW}/dash_{tag}_{k}.png", at, tgt, base + extra)
