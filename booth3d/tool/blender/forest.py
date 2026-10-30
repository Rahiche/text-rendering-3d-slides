"""Name City's kinds of tree, made in Blender, one kind to a place (the
park, the side streets, each town): each a trunk with its branches
('trunk') and a crown ('crown'), its colours baked into the vertices (the
city multiplies them by a near-white tint per tree).

  clump_round, clump_tall, clump_wide  the woods beyond the park: crowns of
                                       separate leaf clumps, each its shade
  sakura_round, sakura_wide            the park's cherries, in clumps, pink
  zelkova, zelkova_b                   keyaki: a vase of branches, its crown
                                       in clumps (Package Town's avenue)
  ginkgo, ginkgo_b                     an upright oval, gold (the streets)
  pine, pine_b                         a cloud-pruned black pine (ICU City)
  leafy_round, leafy_wide              two levels of branches, crowns of
                                       leaf sprites (UVs: the city's leaf
                                       texture, alpha-tested; Engine Town,
                                       the canal)

Run headless:
  Blender -b --factory-startup -P tool/blender/forest.py -- assets/models
writes tree_<kind>.glb there and prints each crown's middle height and
radius (for the city's flight volumes and fairy lights).
"""

import math
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]

CLUMP_TRIS = 2600


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def lin(h, k=1.0):
    """An sRGB hex colour, linear, times [k]."""
    def one(c):
        c /= 255
        return (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) * k
    return (one((h >> 16) & 255), one((h >> 8) & 255), one(h & 255))


def colour(obj, fn):
    me = obj.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        c = fn(obj.matrix_world @ v.co)
        attr.data[i].color = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = attr


# ── The wood ──────────────────────────────────────────────────────────────


def wood(segments, bark):
    """Tapering tubes along [segments] ((points, radii) each), named
    'trunk', the bark a little lighter going up."""
    cu = bpy.data.curves.new("trunk", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    for pts, radii in segments:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for p, co, r in zip(sp.points, pts, radii):
            p.co = (co[0], co[1], co[2], 1.0)
            p.radius = r
    o = bpy.data.objects.new("trunk", cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.view_layer.objects.active
    o.name = "trunk"
    bpy.ops.object.shade_smooth()
    o.select_set(False)
    colour(o, lambda p: tuple(c * (0.72 + 0.28 * min(1.0, p.z / 4.5)) for c in bark))
    return o


def trunk_to(base, top, lean, rnd, r0=0.2):
    pts, radii = [], []
    for i in range(8):
        t = i / 7
        pts.append((base[0] + lean[0] * t * t + 0.06 * math.sin(t * 5 + rnd.random() * 6), base[1] + lean[1] * t * t, base[2] + t * top))
        radii.append(r0 * (1 - 0.6 * t) * (1.4 if i == 0 else 1.0))
    return pts, radii


def branch(a, b, r0=0.08, droop=0.0):
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2 + Vector((0, 0, 0.18 - droop))
    return [a, mid, b], [r0, r0 * 0.7, r0 * 0.4]


# ── Crowns of clumps ──────────────────────────────────────────────────────


def clumps(centres, palette, rnd, squash=0.8, lump=0.16):
    """Separate leaf clumps (ico spheres, lumped), each its own shade from
    [palette], darker underneath and inside; one mesh, 'crown', brought
    down to about [CLUMP_TRIS] triangles."""
    tex = bpy.data.textures.new("lump", "CLOUDS")
    tex.noise_scale = 0.22
    parts = []
    middle = sum((Vector(c) for c, _ in centres), Vector()) / len(centres)
    for c, r in centres:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=c)
        o = bpy.context.active_object
        o.scale.z = squash
        o.rotation_euler.z = rnd.uniform(0, 6.28)
        d = o.modifiers.new("lump", "DISPLACE")
        d.texture = tex
        d.strength = lump * r
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=d.name)
        base = palette[rnd.randrange(len(palette))]
        jit = rnd.uniform(0.86, 1.12)
        zc = c[2]

        def shade(p, base=base, jit=jit, zc=zc, r=r):
            under = max(0.0, min(1.0, (p.z - (zc - r)) / (2 * r)))
            out = min(1.0, (p - middle).length / 2.4)
            k = jit * (0.6 + 0.4 * under) * (0.82 + 0.18 * out) * (0.94 + 0.12 * noise.noise(p * 2.3))
            return tuple(ch * k for ch in base)

        colour(o, shade)
        parts.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    crown = bpy.context.active_object
    crown.name = "crown"
    tris = sum(len(p.vertices) - 2 for p in crown.data.polygons)
    dec = crown.modifiers.new("decimate", "DECIMATE")
    dec.ratio = min(1.0, CLUMP_TRIS / max(1, tris))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    bpy.ops.object.shade_smooth()
    crown.select_set(False)
    return crown


def envelope(c, rx, rz, n, rnd, rmin, rmax, low=-0.35):
    out = [(c, min(rx, rz) * 0.55)]
    for _ in range(n):
        z = rnd.uniform(low, 1.0)
        a = rnd.uniform(0, 2 * math.pi)
        s = math.sqrt(max(0.0, 1 - z * z))
        out.append(((c[0] + s * math.cos(a) * rx * 0.85, c[1] + s * math.sin(a) * rx * 0.85, c[2] + z * rz * 0.85), rnd.uniform(rmin, rmax)))
    return out


def clump_tree(seed, top, c, rx, rz, n, rmin, rmax, palette, bark, lean=(0.15, 0.05)):
    rnd = random.Random(seed)
    centres = envelope(c, rx, rz, n, rnd, rmin, rmax)
    segs = [trunk_to((0, 0, 0), top, lean, rnd)]
    t = Vector((lean[0], lean[1], top * 0.85))
    for cc, r in centres[1:]:
        if rnd.random() < 0.55:
            tip = Vector(cc) + (Vector(cc) - t).normalized() * (-0.45 * r)
            segs.append(branch(t + Vector((0, 0, rnd.uniform(-0.4, 0.3))), tip, 0.07))
    wood(segs, bark)
    clumps(centres, palette, rnd)
    return c[2], max(rx, rz)


def zelkova(seed, palette, bark):
    """Keyaki: branches fanning up from a short trunk, a vase; clumps along
    their upper reaches."""
    rnd = random.Random(seed)
    segs = [trunk_to((0, 0, 0), 2.2, (0.05, 0.0), rnd, 0.24)]
    centres = []
    for b in range(7):
        a = b / 7 * 2 * math.pi + rnd.uniform(-0.3, 0.3)
        tip = Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, 5.4 + rnd.uniform(-0.5, 0.4)))
        segs.append(branch((0, 0, 2.0), tip, 0.1))
        for k in range(3):
            t = 0.55 + 0.22 * k
            p = Vector((0, 0, 2.0)).lerp(tip, t) + Vector((rnd.gauss(0, 0.35), rnd.gauss(0, 0.35), 0.25))
            centres.append((tuple(p), rnd.uniform(0.55, 0.85)))
    wood(segs, bark)
    clumps(centres, palette, rnd)
    return 4.6, 2.4


def pine(seed, palette, bark):
    """A cloud-pruned black pine (niwaki): a leaning, twisting trunk, flat
    pads of needles held out on its branches."""
    rnd = random.Random(seed)
    sway = rnd.uniform(0.7, 1.0) * (1 if seed % 2 else -1)
    def on_trunk(h):
        t = h / 4.6
        return Vector((sway * math.sin(t * 2.6), 0.3 * math.sin(t * 4.0), h))
    pts, radii = [], []
    for i in range(9):
        t = i / 8
        pts.append(tuple(on_trunk(t * 4.6)))
        radii.append(0.22 * (1 - 0.55 * t))
    segs = [(pts, radii)]
    pads = []
    for h, a, reach in [(1.9, 0.4, 1.7), (2.8, 3.3, 1.5), (3.6, 1.2, 1.3), (4.4, 4.2, 0.9), (4.9, 0.0, 0.0)]:
        a += rnd.uniform(-0.4, 0.4)
        p0 = on_trunk(h)
        tip = p0 + Vector((math.cos(a) * reach, math.sin(a) * reach, 0.25))
        if reach > 0:
            segs.append(branch(p0, tip, 0.07, droop=0.25))
        for _ in range(4):
            pads.append((tuple(tip + Vector((rnd.gauss(0, 0.35), rnd.gauss(0, 0.35), rnd.gauss(0.15, 0.05)))), rnd.uniform(0.45, 0.65)))
    wood(segs, bark)
    clumps(pads, palette, rnd, squash=0.45, lump=0.22)
    return 3.6, 2.2


# ── Crowns of leaf sprites ────────────────────────────────────────────────


def leafy(seed, top, c, rx, rz, cards, size, palette, bark):
    """Two levels of branches; round their ends, [cards] leaf sprites
    ([size] m), each a quad facing any way, coloured by [palette], darker
    low and in; one mesh, 'crown', with UVs for the city's leaf texture."""
    rnd = random.Random(seed)
    segs = [trunk_to((0, 0, 0), top, (0.1, 0.05), rnd, 0.22)]
    ends = []
    trunk_top = Vector((0.1, 0, top))
    for b in range(8):
        a = b / 8 * 2 * math.pi + rnd.uniform(-0.4, 0.4)
        p0 = trunk_top + Vector((0, 0, rnd.uniform(-0.8, 0.1)))
        p1 = Vector((c[0] + math.cos(a) * rx * 0.55, math.sin(a) * rx * 0.55, c[2] + rnd.uniform(-0.2, 0.6) * rz))
        segs.append(branch(p0, p1, 0.09))
        for _ in range(4):
            a2 = a + rnd.uniform(-0.9, 0.9)
            p2 = p1 + Vector((math.cos(a2) * rx * 0.35, math.sin(a2) * rx * 0.35, rnd.uniform(0.0, 0.5) * rz))
            segs.append(branch(p1, p2, 0.045))
            ends.append(p2)
    wood(segs, bark)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uvl = bm.loops.layers.uv.new("UVMap")
    middle = Vector(c)
    for _ in range(cards):
        e = ends[rnd.randrange(len(ends))]
        p = e + Vector((rnd.gauss(0, rx * 0.26), rnd.gauss(0, rx * 0.26), rnd.gauss(0.15, rz * 0.24)))
        nrm = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized()
        u = nrm.orthogonal().normalized()
        v = nrm.cross(u)
        s = size * rnd.uniform(0.8, 1.25)
        verts = [bm.verts.new(p + (u * dx + v * dy) * s / 2) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        f = bm.faces.new(verts)
        base = palette[rnd.randrange(len(palette))]
        low = max(0.0, min(1.0, (p.z - (c[2] - rz)) / (2 * rz)))
        out = min(1.0, (p - middle).length / max(rx, rz))
        k = rnd.uniform(0.88, 1.12) * (0.6 + 0.4 * low) * (0.8 + 0.2 * out)
        for loop, (uu, vv) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uvl].uv = (uu, vv)
            loop[col] = (base[0] * k, base[1] * k, base[2] * k, 1.0)
    me = bpy.data.meshes.new("crown")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("crown", me)
    bpy.context.collection.objects.link(o)
    return c[2], max(rx, rz)


# ── Out ───────────────────────────────────────────────────────────────────


def export(kind, dims, uvs=False):
    bpy.ops.object.select_all(action="SELECT")
    path = f"{OUT}/tree_{kind}.glb"
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_texcoords=uvs,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_active_vertex_color_when_no_material=True,
    )
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH"}
    print(f"TREE {kind}: crown middle {dims[0]:.2f} m, radius {dims[1]:.2f} m; {tris} -> {path}")


GREENS = [lin(0x3E7F45), lin(0x4B8C4A), lin(0x5E9B50), lin(0x356F3E), lin(0x6FA458)]
SAKURA = [lin(0xF2A2C8), lin(0xF7B7D6), lin(0xEA8FBC), lin(0xF5C6DD)]
KEYAKI = [lin(0x5C8F4A), lin(0x6FA35A), lin(0x4E7F3F), lin(0x86B06A)]
GOLD = [lin(0xD9A21E), lin(0xE8B22A), lin(0xCC9318), lin(0xEDBF3C)]
NEEDLES = [lin(0x2F5A3A), lin(0x3A6B44), lin(0x284F33)]
LEAVES = [lin(0x4F8A3C), lin(0x5E9A47), lin(0x3F7533), lin(0x6DA650), lin(0x45803A)]
BARK = lin(0x6A5442)
GREY_BARK = lin(0x6E655C)

for kind, make, uvs in [
    ("clump_round", lambda: clump_tree(11, 3.3, (0, 0, 4.1), 1.9, 1.45, 22, 0.55, 0.85, GREENS, BARK), False),
    ("clump_tall", lambda: clump_tree(12, 3.8, (0, 0, 4.8), 1.25, 2.1, 20, 0.5, 0.75, GREENS, BARK), False),
    ("clump_wide", lambda: clump_tree(13, 3.0, (0, 0, 3.7), 2.3, 1.2, 26, 0.55, 0.85, GREENS, BARK), False),
    ("sakura_round", lambda: clump_tree(14, 3.0, (0, 0, 3.7), 1.8, 1.3, 22, 0.5, 0.8, SAKURA, lin(0x4E3B33)), False),
    ("sakura_wide", lambda: clump_tree(15, 2.7, (0, 0, 3.3), 2.4, 1.05, 26, 0.5, 0.8, SAKURA, lin(0x4E3B33), lean=(0.35, 0.1)), False),
    ("zelkova", lambda: zelkova(32, KEYAKI, lin(0x7A6E62)), False),
    ("zelkova_b", lambda: zelkova(42, KEYAKI, lin(0x7A6E62)), False),
    ("ginkgo", lambda: clump_tree(31, 3.6, (0, 0, 4.6), 1.3, 2.0, 26, 0.45, 0.7, GOLD, GREY_BARK, lean=(0.05, 0.03)), False),
    ("ginkgo_b", lambda: clump_tree(51, 3.9, (0, 0, 5.0), 1.15, 2.3, 26, 0.42, 0.66, GOLD, GREY_BARK, lean=(0.05, 0.03)), False),
    ("pine", lambda: pine(33, NEEDLES, lin(0x5B4E44)), False),
    ("pine_b", lambda: pine(34, NEEDLES, lin(0x5B4E44)), False),
    ("leafy_round", lambda: leafy(21, 3.2, (0, 0, 4.2), 2.2, 1.4, 1300, 0.95, LEAVES, lin(0x5E4A3A)), True),
    ("leafy_wide", lambda: leafy(23, 2.9, (0, 0, 3.7), 2.5, 1.2, 1400, 0.95, LEAVES, lin(0x5E4A3A)), True),
]:
    reset()
    export(kind, make(), uvs)
print("FOREST DONE")
