# Realism pass for the MotelIso scene (Blender 5.x, Cycles).
# Rebuilds materials in place (same names, so assignments survive), bevels
# hard-surface meshes, adds geometry-node foliage detail and small props, and
# swaps the stylised EEVEE look for Cycles + AgX. Object layout is unchanged
# so Godot's walk grid, doors and occluder pivots stay valid.
import bpy

S = bpy.data.scenes["MotelIso"]
O = bpy.data.objects
M = bpy.data.materials


# ---------------------------------------------------------------- node helpers
def fresh(name):
    m = M.get(name) or M.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    return m, nt, out


def N(nt, kind, **kw):
    n = nt.nodes.new(kind)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def L(nt, a, b):
    nt.links.new(a, b)


def sock(node, name, kind=None, out=False):
    for s in (node.outputs if out else node.inputs):
        if s.name == name and (kind is None or s.type == kind):
            return s
    raise KeyError(f"{node.bl_idname}.{name}")


def setin(node, **vals):
    for k, v in vals.items():
        node.inputs[k.replace("_", " ")].default_value = v


def pos(nt):
    return sock(N(nt, "ShaderNodeNewGeometry"), "Position", out=True)


def noise(nt, vec, scale, detail=4.0, rough=0.55, dist=0.0):
    n = N(nt, "ShaderNodeTexNoise")
    setin(n, Scale=scale, Detail=detail, Roughness=rough, Distortion=dist)
    if vec is not None:
        L(nt, vec, n.inputs["Vector"])
    return n.outputs[0]


def voronoi(nt, vec, scale, feature="F1", rand=1.0):
    n = N(nt, "ShaderNodeTexVoronoi", feature=feature)
    setin(n, Scale=scale, Randomness=rand)
    if vec is not None:
        L(nt, vec, n.inputs["Vector"])
    return n.outputs[0]


def math(nt, op, a, b=None, clamp=False):
    n = N(nt, "ShaderNodeMath", operation=op, use_clamp=clamp)
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            L(nt, v, n.inputs[i])
    return n.outputs[0]


def mrange(nt, v, a, b, c=0.0, d=1.0):
    n = N(nt, "ShaderNodeMapRange")
    L(nt, v, n.inputs[0])
    n.inputs[1].default_value, n.inputs[2].default_value = a, b
    n.inputs[3].default_value, n.inputs[4].default_value = c, d
    return n.outputs[0]


def mixc(nt, fac, a, b, blend="MIX"):
    n = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type=blend)
    fs = n.inputs[0]
    if isinstance(fac, (int, float)):
        fs.default_value = fac
    else:
        L(nt, fac, fs)
    for s, v in ((sock(n, "A", "RGBA"), a), (sock(n, "B", "RGBA"), b)):
        if isinstance(v, tuple):
            s.default_value = (*v[:3], 1.0)
        else:
            L(nt, v, s)
    return sock(n, "Result", "RGBA", out=True)


def ramp(nt, fac, stops):
    n = N(nt, "ShaderNodeValToRGB")
    els = n.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for e, (p, c) in zip(els, stops):
        e.position = p
        e.color = (*c[:3], 1.0)
    L(nt, fac, n.inputs[0])
    return n.outputs[0]


def bump(nt, h, strength, dist=0.02, normal=None):
    n = N(nt, "ShaderNodeBump")
    setin(n, Strength=strength, Distance=dist)
    L(nt, h, n.inputs["Height"])
    if normal is not None:
        L(nt, normal, n.inputs["Normal"])
    return n.outputs[0]


def ao(nt, dist=0.4):
    n = N(nt, "ShaderNodeAmbientOcclusion", samples=8)
    setin(n, Distance=dist)
    return n.outputs[1]  # AO factor


def bsdf(nt, out, color, rough=0.8, metal=0.0, normal=None, **extra):
    b = N(nt, "ShaderNodeBsdfPrincipled")
    for k, v in (("Base Color", color), ("Roughness", rough), ("Metallic", metal)):
        s = b.inputs[k]
        if isinstance(v, tuple):
            s.default_value = (*v[:3], 1.0)
        elif isinstance(v, (int, float)):
            s.default_value = v
        else:
            L(nt, v, s)
    if normal is not None:
        L(nt, normal, b.inputs["Normal"])
    for k, v in extra.items():
        s = b.inputs[k.replace("_", " ")]
        if isinstance(v, tuple):
            s.default_value = (*v[:3], 1.0) if len(s.default_value) == 4 else v
        elif isinstance(v, (int, float)):
            s.default_value = v
        else:
            L(nt, v, s)
    L(nt, b.outputs[0], out.inputs["Surface"])
    return b


def grime(nt, color, p, amount=0.6, height=0.9):
    """Darken towards the ground and in crevices (AO), streaked by noise."""
    sep = N(nt, "ShaderNodeSeparateXYZ")
    L(nt, p, sep.inputs[0])
    low = mrange(nt, sep.outputs[2], 0.0, height, 1.0, 0.0)
    streak_v = N(nt, "ShaderNodeVectorMath", operation="MULTIPLY")
    L(nt, p, streak_v.inputs[0])
    streak_v.inputs[1].default_value = (1.0, 1.0, 0.08)
    streak = mrange(nt, noise(nt, streak_v.outputs[0], 5.0, 6), 0.45, 0.75)
    crev = math(nt, "SUBTRACT", 1.0, ao(nt, 0.18))
    f = math(nt, "MAXIMUM", math(nt, "MULTIPLY", low, 0.9), math(nt, "MULTIPLY", crev, 0.8))
    f = math(nt, "MAXIMUM", f, math(nt, "MULTIPLY", streak, 0.35))
    f = math(nt, "MULTIPLY", f, amount, clamp=True)
    return mixc(nt, f, color, mixc(nt, 1.0, color, (0.32, 0.29, 0.27), "MULTIPLY"))


# ------------------------------------------------------------------- materials
def m_asphalt(name="Asphalt", light=0.105, dark=0.06):
    m, nt, out = fresh(name)
    p = pos(nt)
    big = noise(nt, p, 0.18, 5)
    mid = noise(nt, p, 2.2, 6)
    col = ramp(nt, math(nt, "ADD", math(nt, "MULTIPLY", big, 0.7), math(nt, "MULTIPLY", mid, 0.3)),
               [(0.35, (dark, dark, dark * 1.05)), (0.68, (light, light * 0.98, light * 0.95))])
    agg = voronoi(nt, p, 140.0)
    spk = mrange(nt, agg, 0.0, 0.18, 1.0, 0.0)
    col = mixc(nt, math(nt, "MULTIPLY", spk, 0.45), col, (0.2, 0.19, 0.18))
    # oil-dark wear band near the middle of each parking bay
    tire = mrange(nt, noise(nt, p, 0.9, 3), 0.55, 0.75)
    col = mixc(nt, math(nt, "MULTIPLY", tire, 0.35), col, (0.03, 0.03, 0.032))
    h = math(nt, "ADD", math(nt, "MULTIPLY", agg, 0.6), math(nt, "MULTIPLY", noise(nt, p, 30, 6), 0.4))
    rough = mrange(nt, tire, 0.0, 1.0, 0.92, 0.7)
    bsdf(nt, out, col, rough, normal=bump(nt, h, 0.35, 0.01))
    return m


def m_concrete():
    m, nt, out = fresh("Concrete")
    p = pos(nt)
    sep = N(nt, "ShaderNodeSeparateXYZ")
    L(nt, p, sep.inputs[0])
    joints = None
    for axis in (0, 1):
        v = math(nt, "FRACT", math(nt, "DIVIDE", sep.outputs[axis], 1.5))
        d = math(nt, "MULTIPLY", math(nt, "MINIMUM", v, math(nt, "SUBTRACT", 1.0, v)), 1.5)
        j = mrange(nt, d, 0.004, 0.014, 1.0, 0.0)
        joints = j if joints is None else math(nt, "MAXIMUM", joints, j)
    base = ramp(nt, noise(nt, p, 1.5, 6), [(0.3, (0.27, 0.255, 0.24)), (0.7, (0.38, 0.36, 0.34))])
    base = mixc(nt, math(nt, "MULTIPLY", mrange(nt, noise(nt, p, 0.6, 3), 0.55, 0.8), 0.5), base, (0.16, 0.14, 0.12))
    col = mixc(nt, joints, base, (0.06, 0.055, 0.05))
    h = math(nt, "SUBTRACT", math(nt, "MULTIPLY", noise(nt, p, 60, 8), 0.3), math(nt, "MULTIPLY", joints, 0.7))
    bsdf(nt, out, grime(nt, col, p, 0.35, 0.3), 0.9, normal=bump(nt, h, 0.3, 0.01))
    return m


def m_stucco(name, c1, c2):
    m, nt, out = fresh(name)
    p = pos(nt)
    col = ramp(nt, noise(nt, p, 0.8, 5), [(0.3, c1), (0.75, c2)])
    fine = noise(nt, p, 55, 10, 0.7)
    col = mixc(nt, math(nt, "MULTIPLY", mrange(nt, fine, 0.35, 0.7), 0.15), col, (0.0, 0.0, 0.0), "MULTIPLY")
    h = math(nt, "ADD", fine, math(nt, "MULTIPLY", voronoi(nt, p, 90), 0.5))
    bsdf(nt, out, grime(nt, col, p, 0.75, 1.2), 0.95, normal=bump(nt, h, 0.22, 0.008))
    return m


def m_paint(name, color, rough=0.55, metal=0.0, wear=0.25):
    m, nt, out = fresh(name)
    p = pos(nt)
    n1 = noise(nt, p, 3.0, 6)
    col = mixc(nt, math(nt, "MULTIPLY", n1, 0.18), color, (0.0, 0.0, 0.0), "MULTIPLY")
    chip = mrange(nt, noise(nt, p, 35, 8, 0.7), 0.74, 0.77)
    col = mixc(nt, math(nt, "MULTIPLY", chip, wear), col, (0.12, 0.1, 0.09))
    r = mrange(nt, n1, 0.3, 0.7, rough - 0.12, rough + 0.12)
    bsdf(nt, out, grime(nt, col, p, 0.5, 0.6), r, metal,
         normal=bump(nt, math(nt, "ADD", chip, math(nt, "MULTIPLY", noise(nt, p, 80, 6), 0.2)), 0.12, 0.004))
    return m


def m_roof():
    m, nt, out = fresh("Roof")
    p = pos(nt)
    grav = voronoi(nt, p, 160)
    col = ramp(nt, noise(nt, p, 0.5, 5), [(0.3, (0.075, 0.073, 0.072)), (0.7, (0.13, 0.125, 0.12))])
    col = mixc(nt, mrange(nt, grav, 0.0, 0.25, 0.45, 0.0), col, (0.2, 0.19, 0.18))
    col = mixc(nt, math(nt, "MULTIPLY", mrange(nt, noise(nt, p, 0.3, 4), 0.55, 0.75), 0.6), col, (0.06, 0.055, 0.05))
    bsdf(nt, out, col, 0.95, normal=bump(nt, grav, 0.35, 0.006))
    return m


def m_metal(name, color, rough=0.45, rust=0.0, grille=False, metallic=0.85):
    m, nt, out = fresh(name)
    p = pos(nt)
    n1 = noise(nt, p, 6, 6)
    col = mixc(nt, math(nt, "MULTIPLY", n1, 0.25), color, (0.0, 0.0, 0.0), "MULTIPLY")
    h = math(nt, "MULTIPLY", noise(nt, p, 90, 6), 0.2)
    rmask = None
    if rust:
        rmask = math(nt, "MULTIPLY", mrange(nt, noise(nt, p, 4, 8, 0.65, 0.6), 0.52, 0.66), rust)
        rc = ramp(nt, noise(nt, p, 25, 6), [(0.3, (0.12, 0.045, 0.02)), (0.7, (0.3, 0.12, 0.04))])
        col = mixc(nt, rmask, col, rc)
        h = math(nt, "ADD", h, math(nt, "MULTIPLY", rmask, 0.6))
    if grille:
        w = N(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
        setin(w, Scale=14.0)
        L(nt, p, w.inputs["Vector"])
        h = math(nt, "ADD", h, w.outputs[1])
    metal = metallic if rmask is None else math(nt, "SUBTRACT", metallic, math(nt, "MULTIPLY", rmask, metallic))
    r = rough if rmask is None else math(nt, "ADD", rough, math(nt, "MULTIPLY", rmask, 0.5))
    bsdf(nt, out, grime(nt, col, p, 0.45, 0.4), r, metal, normal=bump(nt, h, 0.25, 0.006))
    return m


def m_glass(name, inner=None, strength=0.0, folds=True):
    """Reflective window pane with an optional lit curtain behind it."""
    m, nt, out = fresh(name)
    p = pos(nt)
    glass = N(nt, "ShaderNodeBsdfPrincipled")
    setin(glass, Roughness=0.04)
    glass.inputs["Base Color"].default_value = (0.01, 0.012, 0.015, 1)
    glass.inputs["Coat Weight"].default_value = 1.0
    if inner is None:
        L(nt, glass.outputs[0], out.inputs["Surface"])
        return m
    w = N(nt, "ShaderNodeTexWave", wave_type="BANDS", wave_profile="SIN")
    setin(w, Scale=9.0, Distortion=1.5, Detail=2.0)
    L(nt, p, w.inputs["Vector"])
    fold = mrange(nt, w.outputs[1], 0.0, 1.0, 0.55, 1.0) if folds else 1.0
    em = N(nt, "ShaderNodeEmission")
    em.inputs["Color"].default_value = (*inner, 1)
    if folds:
        L(nt, math(nt, "MULTIPLY", fold, strength), em.inputs["Strength"])
    else:
        setin(em, Strength=strength)
    add = N(nt, "ShaderNodeAddShader")
    L(nt, glass.outputs[0], add.inputs[0])
    L(nt, em.outputs[0], add.inputs[1])
    L(nt, add.outputs[0], out.inputs["Surface"])
    return m


def m_emit(name, color, strength):
    m, nt, out = fresh(name)
    e = N(nt, "ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    setin(e, Strength=strength)
    L(nt, e.outputs[0], out.inputs["Surface"])
    return m


def m_dirt():
    m, nt, out = fresh("Dirt")
    p = pos(nt)
    col = ramp(nt, noise(nt, p, 0.06, 5), [(0.3, (0.2, 0.15, 0.11)), (0.7, (0.3, 0.23, 0.16))])
    col = mixc(nt, math(nt, "MULTIPLY", noise(nt, p, 1.2, 6), 0.5), col, (0.16, 0.12, 0.09))
    peb = voronoi(nt, p, 9.0)
    pm = mrange(nt, peb, 0.0, 0.1, 1.0, 0.0)
    pc = ramp(nt, noise(nt, p, 40, 2),[(0.3, (0.12, 0.1, 0.085)), (0.7, (0.38, 0.32, 0.26))])
    col = mixc(nt, math(nt, "MULTIPLY", pm, 0.8), col, pc)
    sand = voronoi(nt, p, 220)
    h = math(nt, "ADD", math(nt, "MULTIPLY", pm, 1.0), math(nt, "MULTIPLY", sand, 0.25))
    h = math(nt, "ADD", h, math(nt, "MULTIPLY", noise(nt, p, 3, 6), 0.5))
    bsdf(nt, out, col, 0.97, normal=bump(nt, h, 0.45, 0.03))
    return m


def m_gravel():
    m, nt, out = fresh("Gravel")
    p = pos(nt)
    v = voronoi(nt, p, 45)
    col = ramp(nt, noise(nt, p, 25, 3), [(0.2, (0.12, 0.1, 0.09)), (0.8, (0.33, 0.29, 0.25))])
    col = mixc(nt, mrange(nt, v, 0.0, 0.3, 0.0, 0.7), col, (0.05, 0.045, 0.04))
    bsdf(nt, out, col, 0.95, normal=bump(nt, math(nt, "SUBTRACT", 1.0, v), 0.6, 0.02))
    return m


def m_decal(name, color, rough, edge=0.25, opacity=0.85):
    """Soft-edged ground decal (oil stain / patch) on a thin plane."""
    m, nt, out = fresh(name)
    tc = N(nt, "ShaderNodeTexCoord")
    g = N(nt, "ShaderNodeVectorMath", operation="SUBTRACT")
    L(nt, tc.outputs["Generated"], g.inputs[0])
    g.inputs[1].default_value = (0.5, 0.5, 0.5)
    d = N(nt, "ShaderNodeVectorMath", operation="LENGTH")
    L(nt, g.outputs[0], d.inputs[0])
    dist = math(nt, "ADD", d.outputs[1], math(nt, "MULTIPLY", noise(nt, pos(nt), 3.5, 5), 0.25))
    a = math(nt, "MULTIPLY", mrange(nt, dist, 0.5 - edge, 0.62, 1.0, 0.0), opacity)
    b = N(nt, "ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value = (*color, 1)
    setin(b, Roughness=rough)
    tr = N(nt, "ShaderNodeBsdfTransparent")
    mx = N(nt, "ShaderNodeMixShader")
    L(nt, a, mx.inputs[0])
    L(nt, tr.outputs[0], mx.inputs[1])
    L(nt, b.outputs[0], mx.inputs[2])
    L(nt, mx.outputs[0], out.inputs["Surface"])
    return m


def m_carpaint(color):
    m, nt, out = fresh("CarPaint")
    p = pos(nt)
    flake = voronoi(nt, p, 900)
    col = mixc(nt, math(nt, "MULTIPLY", noise(nt, p, 2, 4), 0.12), color, (0.0, 0.0, 0.0), "MULTIPLY")
    # desert dust collects on upward faces
    nz = N(nt, "ShaderNodeSeparateXYZ")
    L(nt, sock(N(nt, "ShaderNodeNewGeometry"), "Normal", out=True), nz.inputs[0])
    dust = math(nt, "MULTIPLY", mrange(nt, nz.outputs[2], 0.5, 1.0), mrange(nt, noise(nt, p, 4, 6), 0.35, 0.7, 0.25, 0.7))
    col = mixc(nt, dust, col, (0.32, 0.26, 0.2))
    bsdf(nt, out, col, mrange(nt, dust, 0.0, 1.0, 0.3, 0.8), 0.35,
         normal=bump(nt, flake, 0.03, 0.001), Coat_Weight=mrange(nt, dust, 0.0, 1.0, 0.8, 0.1), Coat_Roughness=0.04)
    return m


def m_foliage(name, c1, c2, sss=0.15):
    m, nt, out = fresh(name)
    p = pos(nt)
    col = ramp(nt, noise(nt, p, 7, 4), [(0.3, c1), (0.7, c2)])
    bsdf(nt, out, col, 0.85, normal=bump(nt, noise(nt, p, 30, 4), 0.3, 0.01),
         Subsurface_Weight=sss, Specular_IOR_Level=0.15)
    return m


def m_bark(name, c1, c2):
    m, nt, out = fresh(name)
    p = pos(nt)
    v = N(nt, "ShaderNodeVectorMath", operation="MULTIPLY")
    L(nt, p, v.inputs[0])
    v.inputs[1].default_value = (6.0, 6.0, 1.0)
    shag = noise(nt, v.outputs[0], 6, 8, 0.7, 1.2)
    col = ramp(nt, shag, [(0.35, c1), (0.65, c2)])
    bsdf(nt, out, col, 0.9, normal=bump(nt, shag, 0.8, 0.04))
    return m


def m_flame():
    m, nt, out = fresh("p_flame")
    p = pos(nt)
    n = noise(nt, p, 6, 4, 0.6, 2.0)
    col = ramp(nt, n, [(0.2, (1.0, 0.22, 0.03)), (0.8, (1.0, 0.75, 0.3))])
    e = N(nt, "ShaderNodeEmission")
    L(nt, col, e.inputs["Color"])
    L(nt, mrange(nt, n, 0.2, 0.8, 4.0, 18.0), e.inputs["Strength"])
    tr = N(nt, "ShaderNodeBsdfTransparent")
    mx = N(nt, "ShaderNodeMixShader")
    L(nt, mrange(nt, n, 0.35, 0.55), mx.inputs[0])
    L(nt, tr.outputs[0], mx.inputs[1])
    L(nt, e.outputs[0], mx.inputs[2])
    L(nt, mx.outputs[0], out.inputs["Surface"])
    return m


def build_materials():
    m_asphalt()
    m_asphalt("iso_patch", 0.07, 0.04)
    m_concrete()
    m_stucco("MotelWall", (0.5, 0.36, 0.28), (0.66, 0.5, 0.39))
    m_stucco("OfficeWall", (0.46, 0.4, 0.32), (0.6, 0.53, 0.42))
    m_paint("Trim", (0.11, 0.24, 0.23), 0.65, wear=0.3)
    m_paint("Base", (0.22, 0.18, 0.16), 0.9, wear=0.0)
    m_paint("DoorRed", (0.4, 0.09, 0.07), 0.38, wear=0.2)
    m_paint("DoorTeal", (0.07, 0.27, 0.28), 0.38, wear=0.2)
    m_paint("p_chair", (0.12, 0.32, 0.26), 0.4, metal=0.6, wear=0.4)
    m_paint("p_dumpster", (0.05, 0.2, 0.13), 0.5, metal=0.5, wear=0.5)
    m_paint("p_wood", (0.2, 0.14, 0.09), 0.8, wear=0.0)
    m_paint("SignPole", (0.32, 0.12, 0.08), 0.5, metal=0.4, wear=0.5)
    m_roof()
    m_metal("Metal", (0.26, 0.26, 0.245), 0.5, rust=0.12, grille=True, metallic=0.3)
    m_metal("p_steel", (0.4, 0.4, 0.41), 0.35, rust=0.2)
    m_metal("p_barrel", (0.22, 0.12, 0.07), 0.55, rust=1.0)
    m_metal("SignMetal", (0.12, 0.12, 0.13), 0.35, rust=0.3)
    m_metal("Chrome", (0.9, 0.9, 0.92), 0.06)
    m_metal("p_dark", (0.06, 0.06, 0.065), 0.5, rust=0.2)
    m_glass("GlassDark")
    m_glass("CarGlass2")
    m_glass("CurtainWarm", (1.0, 0.55, 0.22), 2.2)
    m_glass("CurtainTV", (0.35, 0.6, 1.0), 1.6)
    m_glass("OfficeGlow", (1.0, 0.75, 0.45), 3.0, folds=False)
    m_emit("Sconce", (1.0, 0.72, 0.42), 14.0)
    m_emit("p_lamp", (1.0, 0.62, 0.28), 30.0)
    m_emit("Headlamp", (1.0, 0.92, 0.75), 4.0)
    m_emit("Taillamp", (0.6, 0.02, 0.02), 1.5)
    m_dirt()
    m_gravel()
    m_decal("iso_stain", (0.012, 0.012, 0.014), 0.25, 0.3, 0.75)
    m_carpaint((0.12, 0.34, 0.3))
    t = fresh("Tire")
    bsdf(t[1], t[2], (0.025, 0.025, 0.027), 0.85, normal=bump(t[1], noise(t[1], pos(t[1]), 120, 4), 0.2, 0.004))
    m_foliage("p_jtleaf", (0.035, 0.05, 0.025), (0.08, 0.1, 0.045), 0.0)
    m_foliage("p_scrub", (0.045, 0.05, 0.03), (0.1, 0.1, 0.06), 0.0)
    m_bark("p_jt", (0.06, 0.045, 0.035), (0.2, 0.15, 0.1))
    m_bark("p_tumble", (0.2, 0.15, 0.09), (0.38, 0.3, 0.2))
    m_flame()


# ------------------------------------------------------------------- geometry
SKIP_BEVEL = ("iso_", "c_", "HwDash", "HwEdge", "Park", "Lot", "Highway", "Apron", "Driveway",
              "p_Flame", "SignFaceInset", "VacFace", "p_JTh", "p_JTt", "p_Scrub", "rl_")


def bevel_all():
    car = {o.name for o in O["Car"].children_recursive}
    # downloaded assets (the BlendKit truck) are already detailed: leave them alone
    bought = {o.name for o in O["Truck"].children_recursive} if O.get("Truck") else set()
    for o in S.objects:
        if o.type != "MESH" or o.name.startswith(SKIP_BEVEL) or o.name in bought:
            continue
        for md in [md for md in o.modifiers if md.name.startswith("rl_")]:
            o.modifiers.remove(md)
        sc = sum(abs(v) for v in o.scale) / 3 or 1
        small = min(o.dimensions) or 0.1
        w = (0.09 if o.name.startswith("CarBody") else 0.04) if o.name in car else 0.035
        w = min(w, small * 0.2) / sc
        md = o.modifiers.new("rl_bevel", "BEVEL")
        md.width = w
        md.segments = 4 if o.name in car else 2
        md.limit_method = "ANGLE"
        md.angle_limit = math_rad(40)
        md.harden_normals = False
        md.use_clamp_overlap = True


def math_rad(d):
    return d * 3.14159265 / 180


def spikes_group(name, density, length, radius, jitter, mat):
    """GN: keep the source mesh as a shrunken core and grow spikes/leaves off it."""
    g = bpy.data.node_groups.get(name)
    if g:
        bpy.data.node_groups.remove(g)
    g = bpy.data.node_groups.new(name, "GeometryNodeTree")
    g.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    g.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nd, ln = g.nodes, g.links
    gi, go = nd.new("NodeGroupInput"), nd.new("NodeGroupOutput")
    core = nd.new("GeometryNodeTransform")
    core.inputs["Scale"].default_value = (0.75, 0.75, 0.75)
    ln.new(gi.outputs[0], core.inputs[0])
    dist = nd.new("GeometryNodeDistributePointsOnFaces")
    dist.inputs["Density"].default_value = density
    ln.new(gi.outputs[0], dist.inputs["Mesh"])
    cone = nd.new("GeometryNodeMeshCone")
    cone.inputs["Vertices"].default_value = 4
    cone.inputs["Radius Bottom"].default_value = radius
    cone.inputs["Depth"].default_value = length
    inst = nd.new("GeometryNodeInstanceOnPoints")
    ln.new(dist.outputs["Points"], inst.inputs["Points"])
    ln.new(sock(cone, "Mesh", out=True), inst.inputs["Instance"])
    # random tilt around the surface normal so they read as a messy cluster
    rnd = nd.new("FunctionNodeRandomValue")
    rnd.data_type = "FLOAT_VECTOR"
    rnd.inputs["Min"].default_value = (-jitter, -jitter, -3.14)
    rnd.inputs["Max"].default_value = (jitter, jitter, 3.14)
    rot = nd.new("FunctionNodeRotateRotation")
    ln.new(dist.outputs["Rotation"], rot.inputs["Rotation"])
    e2r = nd.new("FunctionNodeEulerToRotation")
    ln.new(sock(rnd, "Value", "VECTOR", out=True), e2r.inputs[0])
    ln.new(e2r.outputs[0], rot.inputs["Rotate By"])
    ln.new(rot.outputs[0], inst.inputs["Rotation"])
    rs = nd.new("FunctionNodeRandomValue")
    sock(rs, "Min", "VALUE").default_value = 0.55
    sock(rs, "Max", "VALUE").default_value = 1.25
    ln.new(sock(rs, "Value", "VALUE", out=True), inst.inputs["Scale"])
    real = nd.new("GeometryNodeRealizeInstances")
    ln.new(inst.outputs[0], real.inputs[0])
    smi = nd.new("GeometryNodeSetMaterial")
    ln.new(real.outputs[0], smi.inputs["Geometry"])
    smi.inputs["Material"].default_value = M[mat]
    join = nd.new("GeometryNodeJoinGeometry")
    ln.new(smi.outputs[0], join.inputs[0])
    ln.new(core.outputs[0], join.inputs[0])
    ln.new(join.outputs[0], go.inputs[0])
    return g


def foliage():
    jt = spikes_group("rl_yucca", 70.0, 0.55, 0.035, 0.35, "p_jtleaf")
    bush = spikes_group("rl_bush", 140.0, 0.22, 0.03, 1.2, "p_scrub")
    for o in S.objects:
        if o.type != "MESH":
            continue
        g = jt if o.name.startswith(("p_JTh", "p_JTt")) else bush if o.name.startswith("p_Scrub") else None
        if g is None:
            continue
        for md in [md for md in o.modifiers if md.name.startswith("rl_")]:
            o.modifiers.remove(md)
        md = o.modifiers.new("rl_gn", "NODES")
        md.node_group = g


def add_box(name, loc, size, mat, rot_z=0.0):
    o = O.get(name)
    if o is None:
        me = bpy.data.meshes.new(name)
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bm.to_mesh(me)
        bm.free()
        o = O.new(name, me)
        S.collection.objects.link(o)
    o.location, o.scale, o.rotation_euler = loc, size, (0, 0, rot_z)
    o.data.materials.clear()
    o.data.materials.append(M[mat])
    return o


def props():
    # concrete wheel stops at the head of each bay (between parking lines)
    for i, x in enumerate((-6.4, -2.8, 0.8, 4.4, 8.0, 11.6)):
        add_box(f"rl_WheelStop{i}", (x, 6.95, 0.19), (1.7, 0.18, 0.13), "Concrete")
    # door knobs + kick plates
    for o in list(S.objects):
        if o.name.startswith("A_Door") and "Num" not in o.name:
            x, y, _ = o.location
            add_box(f"rl_Knob_{o.name}", (x + 0.38, y - 0.11, 1.0), (0.07, 0.06, 0.07), "Chrome")
            add_box(f"rl_Kick_{o.name}", (x, y - 0.09, 0.2), (0.95, 0.02, 0.22), "p_steel")
        elif o.name.startswith("B_Door"):
            x, y, _ = o.location
            add_box(f"rl_Knob_{o.name}", (x + 0.11, y - 0.38, 1.0), (0.06, 0.07, 0.07), "Chrome")
            add_box(f"rl_Kick_{o.name}", (x + 0.09, y, 0.2), (0.02, 0.95, 0.22), "p_steel")
    # stucco foundation wear strip / downspouts at wing ends
    for i, (x, y) in enumerate(((9.95, 10.1), (-11.95, -10.45), (-16.95, 10.1))):
        add_box(f"rl_Downspout{i}", (x, y, 1.7), (0.1, 0.1, 3.4), "Trim")


MOTEL_EXCLUDE = [(-18.5, 14.5, -12.8, 15.8), (-200, 200, -26.5, -13.5), (0.0, 8.0, -18.0, -9.0)]


def scatter_group(name="rl_scatter", ground_rot=None, exclude=None, near=(75.0, 70.0),
                  rock_density=0.5, grass_density=0.5):
    """GN on a ground plane: pebbles + dry grass tufts, kept out of `exclude`
    (world-metre rects x0, x1, y0, y1) and limited to what the camera can see."""
    if ground_rot is None:
        ground_rot = O["iso_Ground"].rotation_euler.z
    if exclude is None:
        exclude = MOTEL_EXCLUDE
    g = bpy.data.node_groups.get(name)
    if g:
        bpy.data.node_groups.remove(g)
    g = bpy.data.node_groups.new(name, "GeometryNodeTree")
    g.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    g.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nd, ln = g.nodes, g.links
    gi, go = nd.new("NodeGroupInput"), nd.new("NodeGroupOutput")

    def fm(op, a, b=None):
        n = nd.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                ln.new(v, n.inputs[i])
        return n.outputs[0]

    def inside(px, py, x0, x1, y0, y1):
        a = fm("MULTIPLY", fm("GREATER_THAN", px, x0), fm("LESS_THAN", px, x1))
        b = fm("MULTIPLY", fm("GREATER_THAN", py, y0), fm("LESS_THAN", py, y1))
        return fm("MULTIPLY", a, b)

    posn = nd.new("GeometryNodeInputPosition")
    # the ground object may be rotated about Z; masks are authored in world metres
    wpos = nd.new("ShaderNodeVectorRotate")
    wpos.rotation_type = "Z_AXIS"
    wpos.inputs["Angle"].default_value = ground_rot
    ln.new(posn.outputs[0], wpos.inputs["Vector"])
    sep = nd.new("ShaderNodeSeparateXYZ")
    ln.new(wpos.outputs[0], sep.inputs[0])
    px, py = sep.outputs[0], sep.outputs[1]
    excl = None
    for r in exclude:
        e = inside(px, py, *r)
        excl = e if excl is None else fm("MAXIMUM", excl, e)
    # only within what the camera sees (|x - y| and |x + y| bands)
    nearm = fm("LESS_THAN", fm("ABSOLUTE", fm("SUBTRACT", px, py)), near[0])
    nearm = fm("MULTIPLY", nearm, fm("LESS_THAN", fm("ABSOLUTE", fm("ADD", px, py)), near[1]))
    tex = nd.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 0.12
    ln.new(wpos.outputs[0], tex.inputs["Vector"])
    clump = nd.new("ShaderNodeMapRange")
    ln.new(tex.outputs[0], clump.inputs[0])
    clump.inputs[1].default_value, clump.inputs[2].default_value = 0.4, 0.65
    mask = fm("MULTIPLY", fm("SUBTRACT", 1.0, excl), nearm)

    def layer(density, mesh_node, smin, smax, flat, mat, clumped):
        d = nd.new("GeometryNodeDistributePointsOnFaces")
        ln.new(gi.outputs[0], d.inputs["Mesh"])
        sel = fm("MULTIPLY", mask, clump.outputs[0]) if clumped else mask
        d.inputs["Density"].default_value = density
        dl = nd.new("GeometryNodeDeleteGeometry")
        dl.domain = "POINT"
        ln.new(d.outputs["Points"], dl.inputs["Geometry"])
        ln.new(fm("LESS_THAN", sel, 0.5), dl.inputs["Selection"])
        inst = nd.new("GeometryNodeInstanceOnPoints")
        ln.new(dl.outputs[0], inst.inputs["Points"])
        ln.new(next(s for s in mesh_node.outputs if s.type == "GEOMETRY"), inst.inputs["Instance"])
        rv = nd.new("FunctionNodeRandomValue")
        rv.data_type = "FLOAT_VECTOR"
        rv.inputs["Min"].default_value = (-0.25, -0.25, -3.14)
        rv.inputs["Max"].default_value = (0.25, 0.25, 3.14)
        e2r = nd.new("FunctionNodeEulerToRotation")
        ln.new(sock(rv, "Value", "VECTOR", out=True), e2r.inputs[0])
        ln.new(e2r.outputs[0], inst.inputs["Rotation"])
        rs = nd.new("FunctionNodeRandomValue")
        sock(rs, "Min", "VALUE").default_value = smin
        sock(rs, "Max", "VALUE").default_value = smax
        cx = nd.new("ShaderNodeCombineXYZ")
        s = sock(rs, "Value", "VALUE", out=True)
        ln.new(s, cx.inputs[0])
        ln.new(s, cx.inputs[1])
        ln.new(fm("MULTIPLY", s, flat), cx.inputs[2])
        ln.new(cx.outputs[0], inst.inputs["Scale"])
        r = nd.new("GeometryNodeRealizeInstances")
        ln.new(inst.outputs[0], r.inputs[0])
        sm = nd.new("GeometryNodeSetMaterial")
        ln.new(r.outputs[0], sm.inputs["Geometry"])
        sm.inputs["Material"].default_value = M[mat]
        return sm.outputs[0]

    rock = nd.new("GeometryNodeMeshIcoSphere")
    rock.inputs["Radius"].default_value = 1.0
    rock.inputs["Subdivisions"].default_value = 1
    tuft = nd.new("GeometryNodeObjectInfo")
    tuft.inputs["Object"].default_value = tuft_mesh()
    join = nd.new("GeometryNodeJoinGeometry")
    ln.new(gi.outputs[0], join.inputs[0])
    ln.new(layer(rock_density, rock, 0.03, 0.12, 0.45, "rl_rock", False), join.inputs[0])
    ln.new(layer(grass_density, tuft, 0.15, 0.35, 1.0, "rl_grass", True), join.inputs[0])
    ln.new(join.outputs[0], go.inputs[0])
    return g


def tuft_mesh():
    """A clump of thin grass blades leaning outwards (unit height)."""
    import bmesh, random as rnd
    rnd.seed(7)
    me = bpy.data.meshes.get("rl_tuft") or bpy.data.meshes.new("rl_tuft")
    bm = bmesh.new()
    for i in range(11):
        a = rnd.uniform(0, 6.283)
        lean = rnd.uniform(0.15, 0.7)
        h = rnd.uniform(0.6, 1.0)
        from math import cos, sin
        bx, by = cos(a) * 0.04, sin(a) * 0.04
        px, py = -sin(a) * 0.025, cos(a) * 0.025
        tip = bm.verts.new((bx + cos(a) * lean * h, by + sin(a) * lean * h, h))
        v1 = bm.verts.new((bx - px, by - py, 0))
        v2 = bm.verts.new((bx + px, by + py, 0))
        bm.faces.new((v1, v2, tip))
    bm.to_mesh(me)
    bm.free()
    o = O.get("rl_TuftSrc") or O.new("rl_TuftSrc", me)
    if o.name not in S.collection.objects:
        S.collection.objects.link(o)
    o.location = (0, 0, -50)  # parked under the ground plane, out of camera view
    return o


def ground_scatter():
    m, nt, out = fresh("rl_rock")
    p = pos(nt)
    bsdf(nt, out, ramp(nt, noise(nt, p, 3, 3), [(0.2, (0.17, 0.14, 0.11)), (0.8, (0.36, 0.31, 0.25))]), 0.85,
         normal=bump(nt, noise(nt, p, 40, 6), 0.5, 0.01))
    m, nt, out = fresh("rl_grass")
    p = pos(nt)
    bsdf(nt, out, ramp(nt, noise(nt, p, 1.5, 3), [(0.3, (0.18, 0.14, 0.07)), (0.7, (0.34, 0.28, 0.15))]), 0.9,
         normal=bump(nt, noise(nt, p, 200, 2), 0.8, 0.01), Specular_IOR_Level=0.15)
    o = O["iso_Ground"]
    for md in [md for md in o.modifiers if md.name.startswith("rl_")]:
        o.modifiers.remove(md)
    o.modifiers.new("rl_scatter", "NODES").node_group = scatter_group()


def parapets():
    """Solid parapet boxes -> coping ring around a recessed gravel roof."""
    import bmesh
    for n in ("WingA_parapet", "WingB_parapet", "OfficeParapet"):
        o = O[n]
        if o.get("rl_ring"):
            continue
        o.data = o.data.copy()
        if "Roof" not in [m.name for m in o.data.materials if m]:
            o.data.materials.append(M["Roof"])
        ri = [m.name for m in o.data.materials].index("Roof")
        bm = bmesh.new()
        bm.from_mesh(o.data)
        top = [f for f in bm.faces if f.normal.z > 0.9]
        sx, sy, sz = o.scale
        res = bmesh.ops.inset_region(bm, faces=top, thickness=0.2 / max(sx, sy), use_even_offset=True)
        bmesh.ops.translate(bm, verts=list({v for f in top for v in f.verts}), vec=(0, 0, -0.14 / sz))
        for f in top:
            f.material_index = ri
        bm.to_mesh(o.data)
        bm.free()
        o["rl_ring"] = True


def deoverlap():
    """Coplanar overlapping boxes shadow each other in Cycles; nudge the B wing."""
    for n in ("WingB_parapet", "WingB_roof", "WingB_base", "CanopyB", "WalkB"):
        o = O[n]
        if not o.get("rl_nudged"):
            o.location.z += 0.012
            o["rl_nudged"] = True


def bevel_new_props():
    for o in S.objects:
        if o.name.startswith("rl_") and o.type == "MESH" and not o.modifiers.get("rl_bevel"):
            md = o.modifiers.new("rl_bevel", "BEVEL")
            md.width = min(0.02, min(o.dimensions) * 0.2) / (sum(o.scale) / 3)
            md.segments = 2
            md.use_clamp_overlap = True


# ------------------------------------------------------------------- lighting
def add_point(name, loc, power, color, radius=0.08):
    o = O.get(name)
    if o is None:
        o = O.new(name, bpy.data.lights.new(name, "POINT"))
        S.collection.objects.link(o)
    o.location = loc
    o.data.energy, o.data.color, o.data.shadow_soft_size = power, color, radius
    return o


def lighting():
    warm = (1.0, 0.68, 0.4)
    for o in S.objects:
        if o.name.startswith("A_Sconce"):
            x, y, z = o.location
            add_point("rl_L_" + o.name, (x, y - 0.25, z - 0.05), 60, warm)
        elif o.name.startswith("B_Sconce"):
            x, y, z = o.location
            add_point("rl_L_" + o.name, (x + 0.25, y, z - 0.05), 60, warm)
    for o in S.objects:
        if o.name.startswith("CanopyGlow"):
            o.data.energy, o.data.shadow_soft_size = 220, 0.6
    O["LampSpot"].data.color = (1.0, 0.58, 0.22)  # sodium vapour
    O["LampSpot"].data.shadow_soft_size = 0.25
    O["BarrelFire"].data.shadow_soft_size = 0.3
    sun = O["DuskSun.001"].data
    sun.energy, sun.color, sun.angle = 2.6, (1.0, 0.52, 0.26), math_rad(1.5)
    O["CoolFill.001"].hide_render = True  # the sky now provides the cool fill

    w = S.world
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "MULTIPLE_SCATTERING"
    sky.sun_disc = False
    sky.sun_elevation = math_rad(1.0)
    sky.sun_rotation = O["DuskSun.001"].rotation_euler.z + 3.14159
    sky.air_density, sky.aerosol_density = 1.0, 2.5
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 0.25
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 0.75
    nt.links.new(sky.outputs[0], sock(tint, "A", "RGBA"))
    sock(tint, "B", "RGBA").default_value = (0.95, 0.62, 0.85, 1)
    nt.links.new(sock(tint, "Result", "RGBA", out=True), bg.inputs[0])
    nt.links.new(bg.outputs[0], out.inputs[0])

    # emissive backdrop cards must not light the scene
    for o in S.objects:
        if o.name.startswith(("iso_Sky", "iso_Ridge")):
            o.visible_diffuse = o.visible_glossy = o.visible_shadow = False
            o.visible_transmission = o.visible_volume_scatter = False


def sky_detail():
    """Add soft high cirrus to the sky card and rock texture to the ridges."""
    m = M["iso_SkyBB"]
    nt = m.node_tree
    em = next(n for n in nt.nodes if n.type == "EMISSION")
    rmp = next(n for n in nt.nodes if n.type == "VALTORGB")
    for n in [n for n in nt.nodes if n.name.startswith("rl_")]:
        nt.nodes.remove(n)
    p = sock(next(n for n in nt.nodes if n.type == "NEW_GEOMETRY"), "Position", out=True)
    v = N(nt, "ShaderNodeVectorMath", operation="MULTIPLY", name="rl_v")
    L(nt, p, v.inputs[0])
    v.inputs[1].default_value = (0.012, 0.012, 0.06)
    nn = N(nt, "ShaderNodeTexNoise", name="rl_n")
    setin(nn, Scale=3.0, Detail=8.0, Roughness=0.62, Distortion=0.4)
    L(nt, v.outputs[0], nn.inputs["Vector"])
    cl = N(nt, "ShaderNodeMapRange", name="rl_m")
    L(nt, nn.outputs[0], cl.inputs[0])
    cl.inputs[1].default_value, cl.inputs[2].default_value = 0.5, 0.75
    cl.inputs[3].default_value, cl.inputs[4].default_value = 0.0, 0.35
    mx = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type="SCREEN", name="rl_mix")
    L(nt, cl.outputs[0], mx.inputs[0])
    L(nt, rmp.outputs[0], sock(mx, "A", "RGBA"))
    sock(mx, "B", "RGBA").default_value = (1.0, 0.55, 0.45, 1)
    L(nt, sock(mx, "Result", "RGBA", out=True), em.inputs["Color"])

    for rn in ("iso_RidgeFar_g", "iso_RidgeMid_g", "iso_RidgeNear_g"):
        nt = M[rn].node_tree
        em = next(n for n in nt.nodes if n.type == "EMISSION")
        rmp = next(n for n in nt.nodes if n.type == "VALTORGB")
        for n in [n for n in nt.nodes if n.name.startswith("rl_")]:
            nt.nodes.remove(n)
        p = sock(next(n for n in nt.nodes if n.type == "NEW_GEOMETRY"), "Position", out=True)
        nn = N(nt, "ShaderNodeTexNoise", name="rl_n")
        sv = N(nt, "ShaderNodeVectorMath", operation="MULTIPLY", name="rl_sv")
        L(nt, p, sv.inputs[0])
        sv.inputs[1].default_value = (0.35, 0.35, 1.4)
        setin(nn, Scale=0.4, Detail=12.0, Roughness=0.7, Distortion=0.8)
        L(nt, sv.outputs[0], nn.inputs["Vector"])
        mr = N(nt, "ShaderNodeMapRange", name="rl_m")
        L(nt, nn.outputs[0], mr.inputs[0])
        mr.inputs[3].default_value, mr.inputs[4].default_value = 0.62, 1.25
        mx = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", name="rl_mix")
        mx.inputs[0].default_value = 1.0
        L(nt, rmp.outputs[0], sock(mx, "A", "RGBA"))
        cm = N(nt, "ShaderNodeCombineColor", name="rl_c")
        for i in range(3):
            L(nt, mr.outputs[0], cm.inputs[i])
        L(nt, cm.outputs[0], sock(mx, "B", "RGBA"))
        L(nt, sock(mx, "Result", "RGBA", out=True), em.inputs["Color"])


def render_settings():
    try:
        S.render.engine = "CYCLES"
    except TypeError as e:
        print(e)
    c = S.cycles
    c.device = "CPU"
    c.samples = 128
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.02
    c.use_denoising = True
    c.max_bounces, c.diffuse_bounces, c.glossy_bounces = 6, 3, 3
    c.transparent_max_bounces = 8
    c.caustics_reflective = c.caustics_refractive = False
    c.blur_glossy = 1.0
    c.sample_clamp_indirect = 6.0
    try:
        c.use_light_tree = True
    except AttributeError:
        pass
    try:
        S.view_settings.view_transform = "AgX"
        S.view_settings.look = "AgX - Medium High Contrast"
    except TypeError as e:
        print("view transform:", e)
    S.view_settings.exposure = 0.3


def build():
    build_materials()
    parapets()
    deoverlap()
    bevel_all()
    foliage()
    ground_scatter()
    props()
    bevel_new_props()
    lighting()
    sky_detail()
    render_settings()
    print("motel_real: built")


# Exec'd with __name__ == "motel_real" to rebuild the motel; other scene
# builders exec it under another name to reuse the helpers only.
if __name__ in ("motel_real", "__main__"):
    build()
