# Builds the HighwayIso scene (desert highway pull-off) in high_strangeness_scenes.blend.
# Same isometric camera as MotelIso (IsoCam, 80 px/m, 30 deg), so Godot's Iso
# defaults and projection.json apply unchanged. Re-runnable: every object it
# owns is prefixed hy_ and is rebuilt from scratch.
#
# World layout (metres): the two-lane road runs along X, like the motel's
# highway (the same road): bottom-right is towards the motel, top-left vanishes
# under the mountain. The gravel pull-off sits on the north (+Y) side around
# (-4, 8), where the Polaroid was taken. Objects named hy_det_<reading> are per-Polaroid
# -reading details: hidden in the backdrop, rendered as separate sprites.
import bpy, bmesh, math, random, os

HERE = r"C:\Users\jonathan.britton\OneDrive - WiseTech Global Pty Ltd\Documents\high_strangeness\assets\art\source"
lib = {"__name__": "lib"}
exec(compile(open(os.path.join(HERE, "motel_real.py"), encoding="utf8").read(), "motel_real.py", "exec"), lib)
for k in ("fresh", "N", "L", "sock", "setin", "pos", "noise", "voronoi", "math", "mrange", "mixc", "ramp",
          "bump", "bsdf", "grime", "m_decal", "m_paint", "m_metal", "scatter_group", "tuft_mesh"):
    globals()["_" + k if k == "math" else k] = lib[k]
nmath = lib["math"]

O, M = bpy.data.objects, bpy.data.materials
MOTEL = bpy.data.scenes["MotelIso"]
S = bpy.data.scenes.get("HighwayIso") or bpy.data.scenes.new("HighwayIso")
PULL = (-4.0, 8.0)          # centre of the pull-off
rng = random.Random(117)


# ------------------------------------------------------------------ helpers
def link(o):
    if o.name not in S.collection.objects:
        S.collection.objects.link(o)
    return o


def clear_owned():
    for o in [o for o in bpy.data.objects if o.name.startswith("hy_")]:
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves):
        for d in [d for d in coll if d.name.startswith("hy_") and d.users == 0]:
            coll.remove(d)


def mesh_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(M[m] if isinstance(m, str) else m)
    return link(bpy.data.objects.new(name, me))


def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in f])
    bm.normal_update()
    o = mesh_obj(name, bm, [mat])
    if bevel:
        md = o.modifiers.new("hy_bevel", "BEVEL")
        md.width, md.segments, md.use_clamp_overlap = bevel, 2, True
        md.limit_method = "ANGLE"
    return o


def cyl(name, x, y, z0, z1, r0, r1, mat, verts=10, tilt=(0.0, 0.0)):
    """Tapered cylinder from (x,y,z0) leaning by tilt (dx, dy) at the top."""
    bm = bmesh.new()
    bot, top = [], []
    for i in range(verts):
        a = i / verts * math.tau
        bot.append(bm.verts.new((x + math.cos(a) * r0, y + math.sin(a) * r0, z0)))
        top.append(bm.verts.new((x + tilt[0] + math.cos(a) * r1, y + tilt[1] + math.sin(a) * r1, z1)))
    for i in range(verts):
        j = (i + 1) % verts
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    bm.normal_update()
    return mesh_obj(name, bm, [mat])


def blob(name, x, y, z, r, squash, mat, subdiv=2, rough=0.25, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    rr = random.Random(seed)
    off = [rr.uniform(-1, 1) for _ in range(6)]
    for v in bm.verts:
        n = v.co.normalized()
        k = 1 + rough * (math.sin(n.x * 3 + off[0]) * math.sin(n.y * 4 + off[1]) * math.cos(n.z * 3 + off[2]))
        v.co = v.co * k
        v.co.z *= squash
        v.co += mathutils_vec((x, y, z))
    bm.normal_update()
    return mesh_obj(name, bm, [mat])


def mathutils_vec(t):
    import mathutils
    return mathutils.Vector(t)


def flat_poly(name, pts, z, mat, thick=0.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, y in pts]
    f = bm.faces.new(vs)
    if thick:
        r = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, verts=[e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, thick))
    bm.normal_update()
    return mesh_obj(name, bm, [mat])


def ellipse_pts(cx, cy, rx, ry, n=48, wobble=0.12, seed=1):
    rr = random.Random(seed)
    ph = [rr.uniform(0, math.tau) for _ in range(3)]
    out = []
    for i in range(n):
        a = i / n * math.tau
        k = 1 + wobble * (math.sin(a * 3 + ph[0]) * 0.5 + math.sin(a * 7 + ph[1]) * 0.3 + math.sin(a * 13 + ph[2]) * 0.2)
        out.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return out


def strip(name, path, width, z, mat):
    """Flat ribbon along a polyline (tyre tracks)."""
    bm = bmesh.new()
    left, right = [], []
    for i, (x, y) in enumerate(path):
        x2, y2 = path[min(i + 1, len(path) - 1)]
        x1, y1 = path[max(i - 1, 0)]
        dx, dy = x2 - x1, y2 - y1
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln * width / 2, dx / ln * width / 2
        left.append(bm.verts.new((x + nx, y + ny, z)))
        right.append(bm.verts.new((x - nx, y - ny, z)))
    for i in range(len(path) - 1):
        bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
    bm.normal_update()
    return mesh_obj(name, bm, [mat])


def bez(p0, p1, p2, n):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / (n - 1) for i in range(n)]]


# ------------------------------------------------------------ library assets
LIB = os.path.join(HERE, "asset_library", "hs_assets.blend")


def asset_coll(key):
    """The library collection AL_<key>, appended from hs_assets.blend on first use."""
    name = "AL_" + key
    if name not in bpy.data.collections:
        with bpy.data.libraries.load(LIB, link=False) as (src, dst):
            dst.collections = [name]
    return bpy.data.collections[name]


def place(key, name, loc, rotz=0.0, scale=1.0, decimate=None):
    """Copy a library asset into the scene (objects copied, mesh data shared).
    The copies are prefixed with `name` (gs_...) so clear_owned() removes them.
    Subdivision is capped at one level and `decimate` (ratio) thins heavy meshes:
    at 80 px/m most props are a few dozen pixels and full detail only costs RAM."""
    coll = asset_coll(key)
    objs = list(coll.objects)
    new = {}
    for k, o in enumerate(objs):
        c = o.copy()
        c.name = f"{name}_{k}"
        new[o] = c
        link(c)
    for o, c in new.items():
        for md in c.modifiers:
            if md.type == "SUBSURF":
                md.levels, md.render_levels = min(md.levels, 1), min(md.render_levels, 1)
        if decimate and c.type == "MESH":
            dm = c.modifiers.new("gs_decimate", "DECIMATE")
            dm.ratio = decimate
        c.parent = new.get(o.parent)
        if c.parent is None:
            c.location = loc
            c.rotation_euler = (0.0, 0.0, rotz)
            c.scale = (scale, scale, scale)
        else:
            c.matrix_parent_inverse = o.matrix_parent_inverse.copy()
    return list(new.values())


# ---------------------------------------------------------------- materials
def materials():
    m_paint("hy_green", (0.02, 0.17, 0.08), 0.4, wear=0.25)
    m_paint("hy_white", (0.62, 0.62, 0.6), 0.45, wear=0.08)
    m, nt, out = fresh("hy_signwhite")
    bsdf(nt, out, (0.82, 0.82, 0.8), 0.35)
    m, nt, out = fresh("hy_reflector")
    b = bsdf(nt, out, (0.9, 0.45, 0.05), 0.2, Emission_Color=(1.0, 0.45, 0.05), Emission_Strength=1.5)
    m, nt, out = fresh("hy_rock")
    p = pos(nt)
    col = ramp(nt, noise(nt, p, 1.2, 6), [(0.25, (0.13, 0.1, 0.085)), (0.75, (0.33, 0.27, 0.22))])
    col = mixc(nt, nmath(nt, "MULTIPLY", mrange(nt, voronoi(nt, p, 6), 0.0, 0.3, 0.5, 0.0), 1.0), col, (0.4, 0.36, 0.31))
    bsdf(nt, out, col, 0.85, normal=bump(nt, noise(nt, p, 12, 8, 0.7), 0.7, 0.03))
    m, nt, out = fresh("hy_alloy")
    p = pos(nt)
    extra = {}
    b = bsdf(nt, out, (0.78, 0.8, 0.84), mrange(nt, noise(nt, p, 30, 4), 0.3, 0.7, 0.06, 0.2), 1.0,
             normal=bump(nt, noise(nt, p, 60, 4), 0.15, 0.002))
    try:  # faint oil-slick iridescence: not quite any metal you know
        b.inputs["Thin Film Thickness"].default_value = 520.0
        b.inputs["Thin Film IOR"].default_value = 1.6
    except KeyError:
        pass
    m_decal("hy_scorch", (0.012, 0.01, 0.009), 0.75, 0.3, 0.93)
    m_decal("hy_fused", (0.02, 0.03, 0.025), 0.06, 0.15, 0.95)
    m_decal("hy_print", (0.045, 0.038, 0.03), 0.95, 0.35, 0.75)
    m, nt, out = fresh("hy_track")
    p = pos(nt)
    a = nmath(nt, "MULTIPLY", mrange(nt, noise(nt, p, 7, 5), 0.3, 0.7, 0.35, 0.85), 1.0)
    b = N(nt, "ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (0.05, 0.045, 0.04, 1)
    setin(b, Roughness=0.9)
    tr = N(nt, "ShaderNodeBsdfTransparent")
    mx = N(nt, "ShaderNodeMixShader")
    L(nt, a, mx.inputs[0])
    L(nt, tr.outputs[0], mx.inputs[1])
    L(nt, b.outputs[0], mx.inputs[2])
    L(nt, mx.outputs[0], out.inputs["Surface"])
    m, nt, out = fresh("hy_paper")
    bsdf(nt, out, ramp(nt, noise(nt, pos(nt), 9, 3), [(0.3, (0.6, 0.58, 0.52)), (0.8, (0.78, 0.76, 0.7))]), 0.7)
    m, nt, out = fresh("hy_envelope")
    bsdf(nt, out, (0.55, 0.42, 0.26), 0.75)
    m, nt, out = fresh("hy_butt")
    bsdf(nt, out, (0.7, 0.68, 0.62), 0.8)


# ------------------------------------------------------------------- scene
def setup_scene():
    for o in (O["IsoCam"], O["DuskSun.001"], O["iso_Sky"], O["iso_RidgeMid"], O["iso_RidgeNear"], O["rl_TuftSrc"]):
        link(o)
    S.camera = O["IsoCam"]
    S.world = MOTEL.world
    r, mr = S.render, MOTEL.render
    r.resolution_x, r.resolution_y, r.resolution_percentage = mr.resolution_x, mr.resolution_y, 100
    try:
        r.engine = "CYCLES"
    except TypeError as e:
        print(e)
    for k in ("device", "samples", "use_adaptive_sampling", "adaptive_threshold", "use_denoising", "max_bounces",
              "diffuse_bounces", "glossy_bounces", "transparent_max_bounces", "caustics_reflective",
              "caustics_refractive", "blur_glossy", "sample_clamp_indirect"):
        setattr(S.cycles, k, getattr(MOTEL.cycles, k))
    S.view_settings.view_transform = MOTEL.view_settings.view_transform
    S.view_settings.look = MOTEL.view_settings.look
    S.view_settings.exposure = MOTEL.view_settings.exposure + 0.7  # no motel lights out here


def peak():
    """The Polaroid's mountain: a dark silhouette card between the far and mid
    ridges, its summit above where the road meets the horizon. In this
    orthographic view height on screen is just z, so it's only ~8 m 'tall'."""
    link(O["iso_RidgeFar"])
    m, nt, out = fresh("hy_peak")
    p = pos(nt)
    sep = N(nt, "ShaderNodeSeparateXYZ")
    L(nt, p, sep.inputs[0])
    # haze at the foot, dusky violet silhouette above, faint rock texture
    col = ramp(nt, mrange(nt, sep.outputs[2], -1.0, 6.0),
               [(0.0, (0.2, 0.13, 0.2)), (0.45, (0.085, 0.06, 0.1)), (1.0, (0.05, 0.035, 0.07))])
    col = mixc(nt, nmath(nt, "MULTIPLY", noise(nt, p, 0.6, 8, 0.7), 0.25), col, (0.0, 0.0, 0.0), "MULTIPLY")
    e = N(nt, "ShaderNodeEmission")
    L(nt, col, e.inputs["Color"])
    L(nt, e.outputs[0], out.inputs["Surface"])

    off = -30.5  # x - y of the card plane
    bm = bmesh.new()
    rr = random.Random(5)
    ph = [rr.uniform(0, 6.28) for _ in range(4)]
    top, bot = [], []
    n = 480
    for i in range(n + 1):
        s = -60.0 + 120.0 * i / n                      # s = x + y
        # summit above where the road meets the horizon (top-left), a lower
        # shoulder further left and a long tail off to the right
        prof = (7.6 * math.exp(-((s + 21.0) / 13.0) ** 2) + 4.2 * math.exp(-((s + 39.0) / 9.0) ** 2)
                + 2.2 * math.exp(-((s - 2.0) / 14.0) ** 2) + 0.9)
        prof += (0.35 * math.sin(s * 0.9 + ph[0]) + 0.2 * math.sin(s * 2.3 + ph[1]) + 0.1 * math.sin(s * 5.1 + ph[2])
                 + 0.05 * math.sin(s * 11.7 + ph[3]) + 0.025 * math.sin(s * 23.0 + ph[0]))
        x, y = (s + off) / 2.0, (s - off) / 2.0
        top.append(bm.verts.new((x, y, prof)))
        bot.append(bm.verts.new((x, y, -3.0)))
    for i in range(n):
        bm.faces.new((bot[i], bot[i + 1], top[i + 1], top[i]))
    bm.normal_update()
    o = mesh_obj("hy_Peak", bm, ["hy_peak"])
    o.visible_diffuse = o.visible_glossy = o.visible_shadow = False
    return o



# Shoulder spots where the spare tyre can turn up (Godot picks one per day).
# It is rendered once at TIRE_SPOT and moved there as a sprite.
TIRE_SPOT = (6.0, -5.3)


def ground():
    # Ends just behind the near ridge card (x - y = -23.3), like the motel's
    # ground; any further and it shows above the far ridge where that dips.
    bm = bmesh.new()
    corners = [(-60, -24), (60, -24), (60, 30), (-60, 30)]  # (x + y, x - y)
    vs = [bm.verts.new(((a + b) / 2.0, (a - b) / 2.0, 0.0)) for a, b in corners]
    bm.faces.new(vs)
    bm.normal_update()
    if vs[0].link_faces[0].normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    o = mesh_obj("hy_Ground", bm, ["Dirt"])
    excl = [(-200, 200, -4.6, 4.6),                                         # asphalt
            (PULL[0] - 6.4, PULL[0] + 6.4, PULL[1] - 4.2, PULL[1] + 4.2),   # pull-off
            (5.0, 9.0, 9.0, 13.0)]                                           # scorch patch stays bare
    g = scatter_group("hy_scatter", 0.0, excl, (45.0, 45.0), 0.55, 0.6)
    o.modifiers.new("hy_scatter", "NODES").node_group = g


def road():
    box("hy_Road", -90.0, 90.0, -4.0, 4.0, 0.0, 0.08, "Asphalt")
    for side in (-1, 1):
        box(f"hy_Edge{side}", -90.0, 90.0, side * 3.75 - 0.06, side * 3.75 + 0.06, 0.08, 0.083, "LineWhite")
        y0, y1 = (4.0, 6.2) if side > 0 else (-6.2, -4.0)
        box(f"hy_Shoulder{side}", -90.0, 90.0, y0, y1, 0.0, 0.05, "Gravel")
    x = -90.0
    i = 0
    while x < 90.0:
        box(f"hy_Dash{i}", x, x + 3.0, -0.06, 0.06, 0.08, 0.083, "LineYellow")
        x += 9.0
        i += 1
    flat_poly("hy_Pulloff", ellipse_pts(PULL[0], PULL[1], 6.0, 3.8, seed=3), 0.0, "Gravel", 0.045)


def roadside():
    # mile marker on the north shoulder, plate facing the camera side (-Y)
    mx, my = 5.0, 6.8
    box("hy_MM_post", mx - 0.04, mx + 0.04, my - 0.04, my + 0.04, 0.0, 1.5, "p_steel", 0.01)
    box("hy_MM_plate", mx - 0.17, mx + 0.17, my - 0.07, my - 0.05, 0.98, 1.46, "hy_green", 0.008)
    for txt, z, size in (("MILE", 1.33, 0.09), ("117", 1.12, 0.17)):
        cu = bpy.data.curves.new(f"hy_MM_{txt}", "FONT")
        cu.body, cu.size, cu.align_x, cu.extrude = txt, size, "CENTER", 0.002
        t = link(bpy.data.objects.new(f"hy_MM_{txt}", cu))
        t.location = (mx, my - 0.075, z)
        t.rotation_euler = (math.radians(90), 0, 0)
        cu.materials.append(M["hy_signwhite"])
    # delineator posts with amber reflectors; the north side leaves a gap at the pull-off
    posts = [(x, -6.6) for x in (-24, -12, 0, 12, 24)] + [(x, 6.6) for x in (-30, -18, 12, 24)]
    for i, (x, y) in enumerate(posts):
        box(f"hy_Delin{i}_post", x - 0.025, x + 0.025, y - 0.05, y + 0.05, 0.0, 1.15, "hy_white", 0.01)
        box(f"hy_Delin{i}_refl", x - 0.035, x + 0.035, y - 0.058, y - 0.05, 0.95, 1.08, "hy_reflector")
    # barbed-wire fence along the north edge, behind the pull-off
    fy = 15.5
    tops = []
    x = -8.0
    i = 0
    while x <= 50.0:
        lean = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06))
        cyl(f"hy_Fence{i}", x, fy + rng.uniform(-0.1, 0.1), 0.0, 1.3, 0.06, 0.05, "p_wood", 6, lean)
        tops.append((x + lean[0], fy + lean[1]))
        x += 3.5 + rng.uniform(-0.3, 0.3)
        i += 1
    for k, z in enumerate((0.5, 0.85, 1.2)):
        cu = bpy.data.curves.new(f"hy_Wire{k}", "CURVE")
        cu.dimensions, cu.bevel_depth = "3D", 0.005
        sp = cu.splines.new("POLY")
        sp.points.add(len(tops) - 1)
        for j, (xx, yy) in enumerate(tops):
            sag = -0.05 if j % 2 else 0.0
            sp.points[j].co = (xx, yy, z + sag, 1)
        cu.materials.append(M["p_dark"])
        link(bpy.data.objects.new(f"hy_Wire{k}", cu))


def joshua(name, x, y, h, branches, seed):
    r = random.Random(seed)
    parts = [cyl(f"{name}_trunk", x, y, 0.0, h, 0.26, 0.2, "p_jt", 10)]
    for b in range(branches):
        a = r.uniform(0, math.tau)
        ln = r.uniform(1.0, 1.9)
        z0 = h - r.uniform(0.0, 0.8)
        dx, dy = math.cos(a) * ln * 0.75, math.sin(a) * ln * 0.75
        parts.append(cyl(f"{name}_br{b}", x, y, z0, z0 + ln * 0.8, 0.13, 0.1, "p_jt", 8, (dx, dy)))
        hd = blob(f"{name}_head{b}", x + dx, y + dy, z0 + ln * 0.8 + 0.25, 0.5, 1.0, "p_jtleaf", 2, 0.15, seed + b)
        hd.modifiers.new("hy_gn", "NODES").node_group = bpy.data.node_groups["rl_yucca"]
        parts.append(hd)
    top = blob(f"{name}_headT", x, y, h + 0.35, 0.6, 1.0, "p_jtleaf", 2, 0.15, seed + 9)
    top.modifiers.new("hy_gn", "NODES").node_group = bpy.data.node_groups["rl_yucca"]
    parts.append(top)
    return parts


def vegetation():
    # hy_JT_occ stands just east of the pull-off, in front of where you'd stand
    trees = {"hy_JT_occ": (3.5, 10.0, 5.2, 4)}
    for i, (x, y, h, b) in enumerate([(-14.0, -8.0, 5.0, 4), (8.0, -12.0, 5.6, 3), (-4.0, -14.0, 4.4, 3),
                                      (14.0, 8.0, 5.0, 4), (14.0, -6.0, 4.2, 2), (-20.0, -2.0, 4.8, 3)]):
        trees[f"hy_JT{i}"] = (x, y, h, b)
    for k, (name, (x, y, h, b)) in enumerate(trees.items()):
        joshua(name, x, y, h, b, 40 + k * 7)
    n = 0
    while n < 70:
        x, y = rng.uniform(-32, 32), rng.uniform(-30, 30)
        if not (-22 < x - y < 21) or abs(x + y) > 36 or abs(y) < 7.0:
            continue
        if abs(x - PULL[0]) < 8 and abs(y - PULL[1]) < 6:
            continue
        r = rng.uniform(0.35, 0.85)
        o = blob(f"hy_Scrub{n}", x, y, r * 0.35, r, 0.6, "p_scrub", 3, 0.3, n)
        o.data.shade_smooth()
        o.modifiers.new("hy_gn", "NODES").node_group = bpy.data.node_groups["rl_bush"]
        n += 1


FRAG = (0.1, 10.0)


def rocks_and_fragment():
    for i, (x, y, r) in enumerate([(0.9, 10.9, 0.7), (1.9, 10.2, 0.45), (-0.3, 11.6, 0.35)]):
        blob(f"hy_Rock{i}", x, y, r * 0.3, r, 0.65, "hy_rock", 3, 0.3, 70 + i)
    for i, (x, y, r) in enumerate([(-12.0, -9.0, 1.0), (10.0, 12.0, 1.3), (-6.0, -16.0, 0.8), (16.0, -2.0, 0.4)]):
        blob(f"hy_Boulder{i}", x, y, r * 0.3, r, 0.6, "hy_rock", 3, 0.3, 90 + i)
    # the fragment: a twisted, folded shard half-buried against the rocks
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=8, y_segments=4, size=0.5)
    for v in bm.verts:
        u, w = v.co.x, v.co.y
        v.co.x, v.co.y = u * 0.6, w * 0.25
        tw = u * 1.6
        v.co.z = math.sin(tw) * w * 0.35 + 0.05 * math.sin(u * 9.0) + 0.06 * u * u
    o = mesh_obj("hy_Fragment", bm, ["hy_alloy"])
    o.modifiers.new("hy_solid", "SOLIDIFY").thickness = 0.012
    o.location = (FRAG[0], FRAG[1], 0.05)
    o.rotation_euler = (math.radians(14), math.radians(-22), math.radians(35))
    for i, (dx, dy, s) in enumerate([(-0.35, 0.3, 0.35), (0.25, -0.4, 0.25)]):
        c = o.copy()
        c.data = o.data.copy()
        c.name = f"hy_FragmentBit{i}"
        c.scale = (s, s, s)
        c.location = (FRAG[0] + dx, FRAG[1] + dy, 0.02)
        c.rotation_euler = (math.radians(rng.uniform(-30, 30)), math.radians(rng.uniform(-30, 30)), rng.uniform(0, 6))
        link(c)


def spare_tire():
    """Poly Haven "Old Tyre" (BlendKit, CC0), lying flat on the shoulder. Not
    hy_-prefixed so clear_owned() keeps it. Hidden in the backdrop; rendered as
    an item sprite."""
    t = O["hk_item_tire"]
    link(t)
    link(O["hk_item_tire_mesh"])
    t.location = (TIRE_SPOT[0], TIRE_SPOT[1], 0.0)
    t.rotation_euler = (math.radians(3), math.radians(-4), 0.7)


def dressing():
    """Library assets out on the highway."""
    # a lone dead tree east of the pull-off (scaled down from 18 m)
    place("dead_tree", "hy_DeadTree", (8.6, 11.2, 0.0), 0.8, 0.38, 0.4)
    # a weathered barrel out by the fence, cans where people pull over
    place("blue_barrel", "hy_Barrel", (2.6, 14.8, 0.0), 0.6)
    for k, (x, y, a) in enumerate(((-6.3, 9.6, 0.4), (-5.6, 10.3, 2.2), (-1.8, 5.2, 4.1), (-8.2, 7.4, 1.0))):
        place("crushed_can", f"hy_Can{k}", (x, y, 0.045), a, 1.2)


# ------------------------------------------------------------- reading details
def details():
    # light: a scorched ring in the dirt with a glassy, fused centre
    flat_poly("hy_det_light_scorch", ellipse_pts(7.0, 11.0, 1.7, 1.7, 40, 0.18, 8), 0.012, "hy_scorch")
    flat_poly("hy_det_light_glass", ellipse_pts(7.05, 10.95, 0.65, 0.6, 28, 0.25, 9), 0.016, "hy_fused")
    # watcher: tyre tracks swinging off the road onto the gravel, cigarette butts
    for k, off in enumerate((-0.8, 0.8)):
        path = bez((-11.0, 3.6 + off * 0.2), (-8.0 + off, 6.0), (-3.0 + off * 0.6, 8.6), 20)
        strip(f"hy_det_watcher_track{k}", path, 0.22, 0.05, "hy_track")
    for i, (x, y, a) in enumerate([(-2.4, 9.6, 0.4), (-2.0, 9.9, 2.1), (-2.7, 10.2, 4.0)]):
        o = cyl(f"hy_det_watcher_butt{i}", 0, 0, 0, 0.07, 0.008, 0.008, "hy_butt", 6)
        o.rotation_euler = (math.radians(90), 0, a)
        o.location = (x, y, 0.055)
    # planted: paper scattered across the asphalt by the pull-off entrance, an envelope
    for i in range(6):
        x, y = rng.uniform(-7.0, -3.0), rng.uniform(0.5, 3.4)
        o = box(f"hy_det_planted_paper{i}", -0.105, 0.105, -0.14, 0.14, 0.0, 0.002, "hy_paper")
        o.location = (x, y, 0.083)
        o.rotation_euler = (math.radians(rng.uniform(-4, 4)), math.radians(rng.uniform(-4, 4)), rng.uniform(0, 6.28))
    o = box("hy_det_planted_envelope", -0.12, 0.12, -0.055, 0.055, 0.0, 0.004, "hy_envelope")
    o.location, o.rotation_euler = (-4.6, 2.2, 0.084), (0, 0, 0.6)
    # shadow: two sets of footprints walking side by side from the road to the spot
    for trail, off in enumerate((0.0, 0.62)):
        p0, p1 = (-6.5 + off, 4.3 + off * 0.3), (-3.4 + off * 0.6, 8.6 + off * 0.2)
        steps = int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / 0.36)
        ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
        for s in range(steps):
            t = s / max(steps - 1, 1)
            side = 0.11 if s % 2 else -0.11
            x = p0[0] + (p1[0] - p0[0]) * t - math.sin(ang) * side
            y = p0[1] + (p1[1] - p0[1]) * t + math.cos(ang) * side
            o = flat_poly(f"hy_det_shadow_print{trail}_{s}", ellipse_pts(0, 0, 0.14, 0.055, 14, 0.1, s), 0.0, "hy_print")
            o.location = (x, y, 0.06)
            o.rotation_euler = (0, 0, ang)


def build():
    clear_owned()
    materials()
    setup_scene()
    peak()
    ground()
    road()
    roadside()
    vegetation()
    rocks_and_fragment()
    dressing()
    spare_tire()
    details()
    print("highway_build: built", len([o for o in S.objects if o.name.startswith("hy_")]), "objects")


if __name__ in ("highway_build", "__main__"):
    build()