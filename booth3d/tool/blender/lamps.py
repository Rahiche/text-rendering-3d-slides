"""Name City's street lamps, made in Blender, one kind to a place: each in
parts by material ('body': painted metal; 'glow': what lights at night;
'banner': cloth and its letters), colours baked into the vertices.

  lamp_tokyo    the streets: a tapered pole on a base, a curved arm out
                over the road (Blender −y), a slim LED head; a street's
                banner on two brackets (+y), FONT FAIR down both faces
  lamp_suzuran  ICU City: a shopping street's lily-of-the-valley lamp, a
                dark green post, a crown of four curled arms, frosted bells
  lamp_lantern  the park and the plaza: a fluted cast-iron post on a
                stepped base, a four-sided glass lantern

Run headless:
  Blender -b --factory-startup -P tool/blender/lamps.py -- assets/models
writes lamp_<kind>.glb there (Blender x, y, z are the city's x, z, y).
"""

import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def lin(h, k=1.0):
    """An sRGB hex colour, linear, times [k]."""
    def one(c):
        c /= 255
        return (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) * k
    return (one((h >> 16) & 255), one((h >> 8) & 255), one(h & 255))


# The parts' pieces as they're made: part -> objects.
_parts = {}


def keep(o, part, rgb, smooth=False):
    """[o] painted [rgb] (its vertices'), for [part]."""
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    me = o.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(me.vertices)):
        attr.data[i].color = (rgb[0], rgb[1], rgb[2], 1.0)
    me.color_attributes.active_color = attr
    _parts.setdefault(part, []).append(o)
    return o


def box(sx, sy, sz, at, part, rgb, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return keep(o, part, rgb)


def cyl(r, h, at, part, rgb, r2=None, verts=14, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=h, location=at, rotation=rot)
    return keep(bpy.context.active_object, part, rgb, smooth=True)


def rod(a, b, r, part, rgb, verts=10):
    """A round bar from [a] to [b]."""
    dx, dy, dz = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
    return cyl(r, length + r, mid, part, rgb, verts=verts, rot=(math.atan2(math.hypot(dx, dy), dz), 0, math.atan2(dy, dx) + math.pi / 2))


def sphere(r, at, part, rgb, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=at, segments=12, ring_count=8)
    o = bpy.context.active_object
    o.scale.z = sz
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return keep(o, part, rgb, smooth=True)


def letter(ch, at, size, face, part, rgb):
    """A letter standing on a banner's face ([face] −1: facing −x; 1: +x)."""
    bpy.ops.object.text_add(location=at, rotation=(math.pi / 2, 0, face * math.pi / 2))
    o = bpy.context.active_object
    o.data.body = ch
    o.data.align_x = "CENTER"
    o.data.align_y = "CENTER"
    o.data.size = size
    o.data.extrude = 0.002
    o.data.resolution_u = 3
    bpy.ops.object.convert(target="MESH")
    return keep(bpy.context.active_object, part, rgb)


# ── The lamps ─────────────────────────────────────────────────────────────


def tokyo():
    steel, housing = lin(0x6A7078), lin(0x7A8088)
    cyl(0.17, 0.45, (0, 0, 0.225), "body", steel, r2=0.13, verts=16)
    cyl(0.115, 5.35, (0, 0, 0.45 + 2.675), "body", steel, r2=0.07, verts=16)
    pts = [(0, 0, 5.7), (0, -0.12, 6.0), (0, -0.42, 6.2), (0, -0.85, 6.28), (0, -1.3, 6.24)]
    for a, b in zip(pts, pts[1:]):
        rod(a, b, 0.05, "body", steel)
    tilt = (math.radians(-5), 0, 0)
    box(0.32, 0.82, 0.1, (0, -1.62, 6.2), "body", housing, rot=tilt)
    box(0.22, 0.6, 0.02, (0, -1.64, 6.14), "glow", lin(0xF4F1E8), rot=tilt)
    # The banner, on brackets out over the pavement.
    for z in (4.6, 3.0):
        rod((0, 0, z), (0, 0.62, z), 0.025, "body", steel, verts=8)
    box(0.015, 0.55, 1.5, (0, 0.36, 3.8), "banner", lin(0x2E6DA8))
    for face in (-1, 1):
        for i, ch in enumerate("FONTFAIR"):
            letter(ch, (face * 0.012, 0.36, 4.36 - i * 0.16), 0.14, face, "banner", lin(0xF4F1EA))


def suzuran():
    green, bell = lin(0x24382F), lin(0xF6F2E8)
    cyl(0.16, 0.5, (0, 0, 0.25), "body", green, r2=0.1)
    cyl(0.085, 4.1, (0, 0, 2.55), "body", green, r2=0.065)
    for k in range(6):
        cyl(0.1 - 0.004 * k, 0.04, (0, 0, 0.7 + 0.5 * k), "body", green)
    for a in (0.0, math.pi / 2, math.pi, -math.pi / 2):
        ex, ey = math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)
        p = [(0, 0, 4.35), (ex * 0.28, ey * 0.28, 4.55), (ex * 0.55, ey * 0.55, 4.6), (ex * 0.72, ey * 0.72, 4.5)]
        for a0, b0 in zip(p, p[1:]):
            rod(a0, b0, 0.022, "body", green, verts=8)
        bx, by = ex * 0.72, ey * 0.72
        rod((bx, by, 4.5), (bx, by, 4.32), 0.012, "body", green, verts=6)
        cyl(0.05, 0.06, (bx, by, 4.3), "body", green)
        cyl(0.07, 0.3, (bx, by, 4.12), "glow", bell, r2=0.05)
        cyl(0.17, 0.08, (bx, by, 3.95), "glow", bell, r2=0.07)
    cyl(0.07, 0.25, (0, 0, 4.62), "body", green, r2=0.02)
    sphere(0.05, (0, 0, 4.78), "body", green)


def lantern():
    iron, glass = lin(0x1F2226), lin(0xFFF3DA)
    box(0.52, 0.52, 0.22, (0, 0, 0.11), "body", iron)
    box(0.4, 0.4, 0.2, (0, 0, 0.32), "body", iron)
    cyl(0.17, 0.7, (0, 0, 0.77), "body", iron, r2=0.115)
    cyl(0.085, 2.4, (0, 0, 2.3), "body", iron, r2=0.07, verts=16)
    for k in range(10):
        a = k / 10 * math.tau
        cyl(0.014, 2.3, (math.cos(a) * 0.082, math.sin(a) * 0.082, 2.3), "body", iron, r2=0.012, verts=5)
    cyl(0.12, 0.08, (0, 0, 1.15), "body", iron)
    cyl(0.16, 0.12, (0, 0, 3.55), "body", iron, r2=0.11)
    box(0.38, 0.38, 0.55, (0, 0, 3.92), "glow", glass)
    for dx in (-0.2, 0.2):
        for dy in (-0.2, 0.2):
            box(0.035, 0.035, 0.62, (dx, dy, 3.92), "body", iron)
    box(0.46, 0.46, 0.05, (0, 0, 3.62), "body", iron)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.38, radius2=0.05, depth=0.28, location=(0, 0, 4.33), rotation=(0, 0, math.pi / 4))
    keep(bpy.context.active_object, "body", iron)
    sphere(0.055, (0, 0, 4.52), "body", iron)


# ── Out ───────────────────────────────────────────────────────────────────


def export(kind):
    """Each part's pieces joined into one mesh named for the part."""
    for part, objs in _parts.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = part
        joined.data.name = part
    bpy.ops.object.select_all(action="SELECT")
    path = f"{OUT}/lamp_{kind}.glb"
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
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH"}
    print(f"LAMP {kind}: {tris} -> {path}")


for kind, make in [("tokyo", tokyo), ("suzuran", suzuran), ("lantern", lantern)]:
    reset()
    _parts.clear()
    make()
    export(kind)
print("LAMPS DONE")
