# Builds the GasIso scene: a lonely desert gas station further west along the
# same highway (road along world X, like the motel and highway scenes; you
# arrive at the bottom-right end from the highway). Same IsoCam/projection, so
# Godot's Iso defaults apply. Re-runnable: everything it owns is prefixed gs_.
#
# Retro 1950s "Googie" station: up-swept canopy with a neon edge, round-
# shouldered pumps with lit globes, a streamline-moderne office with a rounded
# glass corner and racing stripes, two service bays, a roof fin and a pylon
# sign with a disc and starburst. Art Deco lettering (Broadway) like the motel.
#
# Layout (metres): road y in [-4, 4]; concrete forecourt on the north side
# (y 4..9.4) with the pump island at (-3, 6.5); the building behind it at
# y 9.6..14.6 (office west, bays east); pylon sign at (9, 6.5).
import bpy, bmesh, math, random, os

HERE = r"C:\Users\jonathan.britton\OneDrive - WiseTech Global Pty Ltd\Documents\high_strangeness\assets\art\source"
hw = {"__name__": "lib"}
exec(compile(open(os.path.join(HERE, "highway_build.py"), encoding="utf8").read(), "highway_build.py", "exec"), hw)
O, M = bpy.data.objects, bpy.data.materials
S = bpy.data.scenes.get("GasIso") or bpy.data.scenes.new("GasIso")
hw["S"] = S  # the highway helpers link new objects into whatever hw["S"] is
box, cyl, blob, flat_poly, mesh_obj, link = hw["box"], hw["cyl"], hw["blob"], hw["flat_poly"], hw["mesh_obj"], hw["link"]
ellipse_pts, joshua, mvec = hw["ellipse_pts"], hw["joshua"], hw["mathutils_vec"]
lib = hw["lib"]
fresh, bsdf, m_paint, m_metal, m_stucco, m_glass, m_emit = (lib[k] for k in (
    "fresh", "bsdf", "m_paint", "m_metal", "m_stucco", "m_glass", "m_emit"))
rng = random.Random(1986)


def clear_owned():
    for o in [o for o in bpy.data.objects if o.name.startswith("gs_")]:
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.lights):
        for d in [d for d in coll if d.name.startswith("gs_") and d.users == 0]:
            coll.remove(d)


def text(name, body, loc, size, mat, rot=(math.radians(90), 0, 0), align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body, cu.size, cu.align_x, cu.extrude = body, size, align, 0.004
    cu.materials.append(M[mat])
    t = link(bpy.data.objects.new(name, cu))
    t.location, t.rotation_euler = loc, rot
    return t


def light(name, kind, loc, energy, color, size=0.3, rot=(0, 0, 0)):
    ld = bpy.data.lights.new(name, kind)
    ld.energy, ld.color = energy, color
    if kind == "AREA":
        ld.size = size
    else:
        ld.shadow_soft_size = size
    o = link(bpy.data.objects.new(name, ld))
    o.location, o.rotation_euler = loc, rot
    return o


def materials():
    m_paint("gs_red", (0.42, 0.05, 0.04), 0.4, wear=0.35)
    m_paint("gs_cream", (0.66, 0.62, 0.52), 0.55, wear=0.3)
    m_paint("gs_teal", (0.06, 0.26, 0.25), 0.45, wear=0.3)
    m_paint("gs_canopy", (0.62, 0.6, 0.54), 0.5, wear=0.06)
    m_stucco("gs_wall", (0.58, 0.55, 0.47), (0.72, 0.69, 0.6))
    m_emit("gs_neon", (1.0, 0.16, 0.06), 9.0)
    m_emit("gs_globe", (1.0, 0.94, 0.82), 5.0)
    m_emit("gs_star", (1.0, 0.86, 0.55), 6.0)
    m_glass("gs_window", (1.0, 0.78, 0.5), 2.6, folds=False)
    m_emit("gs_pumpface", (1.0, 0.93, 0.72), 3.0)
    m_emit("gs_signlight", (1.0, 0.96, 0.86), 2.2)
    m_emit("gs_tube", (0.86, 0.96, 1.0), 4.0)
    m_metal("gs_garage", (0.34, 0.35, 0.33), 0.5, rust=0.25, grille=True, metallic=0.3)
    m, nt, out = fresh("gs_letter")
    bsdf(nt, out, (0.03, 0.03, 0.03), 0.6)


def setup_scene():
    H = bpy.data.scenes["HighwayIso"]
    for o in (O["IsoCam"], O["DuskSun.001"], O["iso_Sky"], O["iso_RidgeFar"], O["iso_RidgeMid"],
              O["iso_RidgeNear"], O["rl_TuftSrc"]):
        link(o)
    S.camera, S.world = H.camera, H.world
    r, hr = S.render, H.render
    r.resolution_x, r.resolution_y, r.resolution_percentage = hr.resolution_x, hr.resolution_y, 100
    try:
        r.engine = "CYCLES"
    except TypeError as e:
        print(e)
    for k in ("device", "samples", "use_adaptive_sampling", "adaptive_threshold", "use_denoising", "max_bounces",
              "diffuse_bounces", "glossy_bounces", "transparent_max_bounces", "caustics_reflective",
              "caustics_refractive", "blur_glossy", "sample_clamp_indirect"):
        setattr(S.cycles, k, getattr(H.cycles, k))
    S.view_settings.view_transform = H.view_settings.view_transform
    S.view_settings.look = H.view_settings.look
    S.view_settings.exposure = H.view_settings.exposure - 0.3  # the station's own lights carry it


def mountain():
    """Same range as the highway's, seen from further west: summit shifted right."""
    src = O["hy_Peak"]
    o = src.copy()
    o.data = src.data.copy()
    o.name = o.data.name = "gs_Peak"
    o.location.x += 14.0
    o.location.y += 14.0
    link(o)


def ground_and_road():
    bm = bmesh.new()
    vs = [bm.verts.new(((a + b) / 2.0, (a - b) / 2.0, 0.0)) for a, b in ((-60, -24), (60, -24), (60, 30), (-60, 30))]
    f = bm.faces.new(vs)
    bm.normal_update()
    if f.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=[f])
    g = mesh_obj("gs_Ground", bm, ["Dirt"])
    excl = [(-200, 200, -4.6, 4.6), (-16.0, 12.0, 3.5, 16.0)]
    g.modifiers.new("gs_scatter", "NODES").node_group = lib["scatter_group"]("gs_scatter", 0.0, excl, (45.0, 45.0), 0.5, 0.5)
    box("gs_Road", -90.0, 90.0, -4.0, 4.0, 0.0, 0.08, "Asphalt")
    for side in (-1, 1):
        box(f"gs_Edge{side}", -90.0, 90.0, side * 3.75 - 0.06, side * 3.75 + 0.06, 0.08, 0.083, "LineWhite")
        y0, y1 = (4.0, 6.2) if side > 0 else (-6.2, -4.0)
        if side < 0:
            box(f"gs_Shoulder{side}", -90.0, 90.0, y0, y1, 0.0, 0.05, "Gravel")
    for side_x0, side_x1 in ((-90.0, -15.5), (11.5, 90.0)):
        box(f"gs_ShoulderN{side_x0}", side_x0, side_x1, 4.0, 6.2, 0.0, 0.05, "Gravel")
    x, i = -90.0, 0
    while x < 90.0:
        box(f"gs_Dash{i}", x, x + 3.0, -0.06, 0.06, 0.08, 0.083, "LineYellow")
        x += 9.0
        i += 1
    # forecourt slab and a dirt-and-gravel side lot
    box("gs_Forecourt", -15.5, 11.5, 4.0, 9.6, 0.0, 0.06, "Concrete", 0.02)
    flat_poly("gs_SideLot", ellipse_pts(14.5, 11.0, 3.6, 4.2, seed=21), 0.0, "Gravel", 0.035)


def deco_font():
    path = r"C:\Windows\Fonts\BROADW.TTF"
    for f in bpy.data.fonts:
        if f.filepath and os.path.basename(f.filepath).upper() == "BROADW.TTF":
            return f
    return bpy.data.fonts.load(path) if os.path.exists(path) else None


def deco(name, body, loc, size, mat, rot=(math.radians(90), 0, 0)):
    t = text(name, body, loc, size, mat, rot)
    f = deco_font()
    if f:
        t.data.font = f
    return t


def wedge(name, x0, x1, back, front, mat):
    """Slab of constant thickness rising from back=(y, z) to front=(y, z)."""
    (yb, zb), (yf, zf) = back, front
    th = 0.22
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((x0, yb, zb), (x1, yb, zb), (x1, yf, zf), (x0, yf, zf),
                                     (x0, yb, zb + th), (x1, yb, zb + th), (x1, yf, zf + th), (x0, yf, zf + th))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)):
        bm.faces.new([vs[i] for i in f])
    bm.normal_update()
    return mesh_obj(name, bm, [mat])


def rim(name, x0, x1, y0, y1, z0, z1, mat, w=0.18):
    """Four thin parapet walls (a solid cap would hide the roof inside it)."""
    for k, r in enumerate(((x0, x1, y0, y0 + w), (x0, x1, y1 - w, y1), (x0, x0 + w, y0, y1), (x1 - w, x1, y0, y1))):
        box(f"{name}{k}", r[0], r[1], r[2], r[3], z0, z1, mat, 0.015)


# ------------------------------------------------------------ library assets
PUMP_TURN = 0.0  # rotation (rad) so the pumps face the road / camera (-Y)
place = hw["place"]  # library asset placer (see highway_build.py)


def dressing():
    """Props from the asset library around the station."""
    # cans for sale by the office door, a fire extinguisher on the wall
    place("old_gas_can", "gs_Can0", (-1.15, 9.28, 0.0), 0.15, 0.7)
    place("old_gas_can", "gs_Can1", (-0.75, 9.3, 0.0), -0.2, 0.7)
    place("extinguisher", "gs_Extinguisher", (-0.25, 9.48, 0.85), 0.0)
    place("cactus_pot", "gs_Cactus0", (-3.25, 9.3, 0.0), 0.0, 1.6, 0.15)
    place("cactus_pot", "gs_Cactus1", (-3.6, 9.32, 0.0), 1.2, 1.3, 0.15)
    # between the bays: a step ladder; against the east wall: a tin cabinet of
    # automotive odds and ends, propane bottles, a utility box
    place("step_ladder", "gs_Ladder", (2.35, 9.38, 0.0), 0.0)
    place("metal_cabinet", "gs_Cabinet", (6.05, 10.1, 0.0), math.radians(90))
    for k, (key, dy) in enumerate((("motor_oil", -0.25), ("antifreeze", -0.05), ("carb_cleaner", 0.12), ("wd40", 0.27))):
        place(key, f"gs_Shelf{k}", (6.05, 10.1 + dy, 0.67), math.radians(90 + 15 * k))
    for k, y in enumerate((11.2, 11.6, 12.0)):
        place("propane_tank", f"gs_Propane{k}", (5.9, y, 0.0), k * 0.7)
    # barrels, a dumpster, crates and a container out on the east side lot
    place("rusty_barrel", "gs_Drum0", (7.4, 10.0, 0.0), 0.3)
    place("red_barrel", "gs_Drum1", (8.2, 10.7, 0.0), 1.1, 1.0, 0.2)
    place("blue_barrel", "gs_Drum2", (7.3, 11.1, 0.0), 2.0)
    place("wheel_rim", "gs_Rim", (6.85, 8.62, 0.2), 0.4)
    place("waste_bin", "gs_Dumpster", (9.4, 13.0, 0.0), math.radians(90))
    place("plastic_crate", "gs_Crate0", (6.2, 12.9, 0.0), 0.2)
    place("wooden_crate", "gs_Crate1", (6.25, 13.0, 0.26), -0.3, 1.0, 0.05)
    # (the BlendKit "Rigged box" comes in with its flaps unfolded; library only)
    place("container", "gs_Container", (12.0, 15.8, 0.0), math.radians(90))
    # the road west is closed (the gated exit)
    place("road_sign", "gs_RoadWork", (-18.5, 1.6, 0.0), math.radians(20), 1.2)
    # vegetation: desert-motel palms and some variety beyond the Joshua trees
    # (the 884k-face "Palm V2" stays in the library: too heavy for this CPU render)
    place("small_palm", "gs_PalmSmall", (11.9, 8.5, 0.0), 1.9, 0.9, 0.35)
    place("small_palm", "gs_PalmWest", (-8.6, 12.2, 0.0), 0.6, 1.2, 0.35)
    place("quiver_tree", "gs_Quiver0", (-12.6, 7.2, 0.0), 0.4, 1.8, 0.3)
    place("quiver_tree2", "gs_Quiver1", (14.8, 9.8, 0.0), 2.2, 2.2, 0.3)
    place("searsia", "gs_Searsia", (15.6, 14.2, 0.0), 1.0, 0.9, 0.15)


def pumps():
    box("gs_Island", -5.7, -0.3, 6.05, 6.95, 0.0, 0.18, "Concrete", 0.03)
    # BlendKit "Old Petrol Pump": weathered, glass globe on top (2.65 m)
    for i, x in enumerate((-4.2, -1.8)):
        place("pump_b", f"gs_Pump{i}", (x, 6.5, 0.18), PUMP_TURN)
    # tapered canopy posts on the island (named gs_Pump_* so they share the occluder)
    for i, x in enumerate((-5.3, -0.7)):
        cyl(f"gs_Pump_post{i}", x, 6.5, 0.18, 4.5, 0.18, 0.09, "gs_cream", 14)
    # Googie canopy: rises towards the road, red fascia, neon along the front edge
    wedge("gs_Canopy_roof", -7.2, 1.2, (9.0, 3.9), (3.9, 4.75), "gs_canopy")
    wedge("gs_Canopy_fascia", -7.25, 1.25, (3.98, 4.6), (3.9, 4.75), "gs_red")
    box("gs_Canopy_neon", -7.2, 1.2, 3.84, 3.88, 4.78, 4.82, "gs_neon")
    for i, y in enumerate((5.2, 7.4)):
        box(f"gs_Canopy_tube{i}", -6.4, 0.4, y - 0.05, y + 0.05, 4.05 + (9.0 - y) * 0.0, 4.1, "gs_tube")
        light(f"gs_CanopyLight{i}", "AREA", (-3.0, y, 3.95), 110.0, (0.86, 0.96, 1.0), 1.0)
    light("gs_NeonGlow", "AREA", (-3.0, 3.6, 4.6), 60.0, (1.0, 0.2, 0.08), 3.0, (math.radians(-60), 0, 0))


def building():
    wall, trim = "gs_wall", "gs_teal"
    # office (west) with a rounded streamline corner and a wrap-around glass band
    box("gs_Office", -6.0, -1.0, 9.6, 14.6, 0.0, 3.3, wall, 0.03)
    cx, cy, r = -6.0, 11.4, 1.8
    cyl("gs_Corner_lo", cx, cy, 0.0, 0.85, r, r, wall, 36)
    cyl("gs_Corner_glass", cx, cy, 0.85, 2.45, r - 0.04, r - 0.04, "gs_window", 36)
    cyl("gs_Corner_hi", cx, cy, 2.45, 3.3, r, r, wall, 36)
    for k, (z0, z1) in enumerate(((2.62, 2.74), (2.84, 2.92))):  # racing stripes
        cyl(f"gs_Corner_stripe{k}", cx, cy, z0, z1, r + 0.02, r + 0.02, "gs_red", 36)
        box(f"gs_Stripe{k}", -6.0, 5.6, 9.56, 9.6, z0, z1, "gs_red")
    box("gs_Window", -5.9, -3.0, 9.48, 9.56, 0.85, 2.45, "gs_window")
    box("gs_Window_frame", -5.95, -2.95, 9.53, 9.6, 0.8, 2.5, trim)
    box("gs_Door", -2.55, -1.55, 9.48, 9.56, 0.0, 2.3, "gs_window")
    box("gs_Door_frame", -2.65, -1.45, 9.53, 9.6, 0.0, 2.38, trim)
    rim("gs_Office_cap", -6.1, -0.9, 9.5, 14.7, 3.3, 3.5, "gs_cream")
    box("gs_Office_roof", -6.0, -1.0, 9.6, 14.6, 3.3, 3.36, "Roof")
    cyl("gs_Corner_cap", cx, cy, 3.3, 3.45, r + 0.1, r + 0.1, "gs_cream", 36)
    light("gs_Office0", "POINT", (-5.2, 11.4, 2.2), 160.0, (1.0, 0.76, 0.48), 0.4)
    light("gs_Office1", "POINT", (-3.0, 11.2, 2.2), 140.0, (1.0, 0.76, 0.48), 0.4)
    # service bays (east), slightly taller, with glazed roll-up doors
    box("gs_Bays", -1.0, 5.6, 9.6, 14.6, 0.0, 3.6, wall, 0.03)
    rim("gs_Bays_cap", -1.1, 5.7, 9.5, 14.7, 3.6, 3.8, "gs_cream")
    box("gs_Bays_roof", -1.0, 5.6, 9.6, 14.6, 3.6, 3.66, "Roof")
    for i, x0 in enumerate((-0.6, 2.6)):
        box(f"gs_BayDoor{i}", x0, x0 + 2.7, 9.52, 9.6, 0.0, 2.9, "gs_garage")
        box(f"gs_BayGlass{i}", x0 + 0.1, x0 + 2.6, 9.5, 9.53, 1.9, 2.45, "gs_window")
        box(f"gs_BayFrame{i}", x0 - 0.1, x0 + 2.8, 9.53, 9.61, 0.0, 3.0, trim)
    # roof fin spelling GAS, and the name in deco letters on the fascia
    box("gs_Fin", -4.6, -2.6, 11.0, 11.25, 3.45, 7.0, "gs_red", 0.03)
    box("gs_Fin_edge", -4.65, -2.55, 10.96, 11.0, 6.9, 7.05, "gs_neon")
    for k, ch in enumerate("GAS"):
        deco(f"gs_Fin_{ch}", ch, (-3.6, 10.95, 6.15 - k * 0.95), 0.75, "gs_signlight")
    deco("gs_NameText", "Last Chance", (-3.6, 9.47, 2.97), 0.38, "gs_red")


def price_sign():
    x, y = 9.0, 6.5
    box("gs_Sign_pylon", x - 0.22, x + 0.22, y - 0.12, y + 0.12, 0.0, 8.0, "gs_teal", 0.03)
    disc = cyl("gs_Sign_disc", 0, 0, -0.14, 0.14, 1.25, 1.25, "gs_cream", 40)
    disc.rotation_euler = (math.radians(90), 0, 0)
    disc.location = (x, y, 6.6)
    ring = cyl("gs_Sign_ring", 0, 0, -0.16, 0.16, 1.32, 1.32, "gs_red", 40)
    ring.rotation_euler = (math.radians(90), 0, 0)
    ring.location = (x, y + 0.03, 6.6)
    deco("gs_Sign_word", "GAS", (x, y - 0.15, 6.32), 0.7, "gs_red")
    box("gs_Sign_neon", x - 1.1, x + 1.1, y - 0.18, y - 0.15, 6.0, 6.04, "gs_neon")
    # starburst on top
    for k in range(10):
        a = k / 10 * math.tau
        L = 0.75 if k % 2 else 0.45
        sp = cyl(f"gs_Sign_star{k}", 0, 0, 0.0, L, 0.035, 0.005, "gs_star", 6)
        sp.rotation_euler = (math.radians(90), a, 0)
        sp.location = (x, y - 0.05, 8.35)
    blob("gs_Sign_starcore", x, y - 0.05, 8.35, 0.1, 1.0, "gs_star", 1, 0.0, 0)
    # price board lower down
    # price board hangs in front of the pylon (which is 0.24 deep) so it isn't cut in half
    box("gs_Sign_board", x - 1.0, x + 1.0, y - 0.3, y - 0.13, 3.9, 4.9, "gs_signlight", 0.02)
    text("gs_Sign_price", "1.09", (x, y - 0.31, 4.1), 0.62, "gs_letter")
    light("gs_SignLight", "POINT", (x, y - 1.4, 5.8), 140.0, (1.0, 0.95, 0.85), 0.5)


def props():
    for i in range(3):  # stacked tyres
        cyl(f"gs_TireStack{i}", 6.4, 9.0, i * 0.22, i * 0.22 + 0.21, 0.36, 0.36, "Tire", 20)
    # oil-can pyramid by the bays
    k = 0
    for row, n in enumerate((4, 3, 2)):
        for c in range(n):
            cyl(f"gs_OilCan{k}", 5.75 + row * 0.07 + c * 0.14, 9.42, row * 0.15, row * 0.15 + 0.14, 0.06, 0.06,
                "gs_teal" if (k % 2) else "gs_red", 10)
            k += 1
    # red cooler with a white lid, payphone, air pump
    box("gs_Ice", -8.6, -7.4, 9.0, 9.6, 0.0, 0.95, "gs_red", 0.05)
    box("gs_Ice_lid", -8.62, -7.38, 8.98, 9.62, 0.95, 1.05, "gs_cream", 0.03)
    deco("gs_IceText", "ICE COLD", (-8.0, 8.995, 0.55), 0.16, "gs_cream")
    cyl("gs_Phone_post", -9.6, 8.4, 0.0, 1.45, 0.05, 0.05, "p_steel", 8)
    box("gs_Phone_box", -9.82, -9.38, 8.22, 8.52, 1.1, 1.62, "gs_teal", 0.02)
    cyl("gs_Air_post", 3.6, 7.6, 0.0, 1.1, 0.09, 0.09, "gs_red", 10)
    blob("gs_Air_globe", 3.6, 7.6, 1.2, 0.1, 1.0, "gs_cream", 1, 0.0, 0)
    # behind the station: power pole, an old water tank, desert
    cyl("gs_Pole", -3.0, 19.0, 0.0, 8.5, 0.17, 0.13, "p_wood", 8)
    box("gs_PoleArm", -3.9, -2.1, 18.95, 19.05, 7.9, 8.02, "p_wood")
    cyl("gs_Tank", 9.0, 16.5, 0.0, 2.4, 1.1, 1.1, "p_steel", 20)
    trees = [(-12.0, -9.0), (9.0, -12.0), (-5.0, -15.0), (14.0, 4.0), (16.0, -6.0), (-18.0, 1.0), (12.0, 19.0)]
    for k, (x, y) in enumerate(trees):
        joshua(f"gs_JT{k}", x, y, rng.uniform(4.2, 5.6), rng.randint(2, 4), 300 + k * 11)
    n = 0
    while n < 55:
        x, y = rng.uniform(-32, 32), rng.uniform(-30, 30)
        if not (-22 < x - y < 21) or abs(x + y) > 36 or abs(y) < 7.0:
            continue
        if -17 < x < 13 and 3 < y < 17:
            continue
        r = rng.uniform(0.35, 0.85)
        o = blob(f"gs_Scrub{n}", x, y, r * 0.35, r, 0.6, "p_scrub", 3, 0.3, 500 + n)
        o.data.shade_smooth()
        o.modifiers.new("gs_gn", "NODES").node_group = bpy.data.node_groups["rl_bush"]
        n += 1


def build():
    clear_owned()
    hw["materials"]()
    materials()
    setup_scene()
    mountain()
    ground_and_road()
    pumps()
    building()
    price_sign()
    props()
    dressing()
    print("gas_build: built", len([o for o in S.objects if o.name.startswith("gs_")]), "objects")


if __name__ in ("gas_build", "__main__"):
    build()