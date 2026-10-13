# Background render of the GasIso scene (see gas_build.py).
#   blender -b <copy.blend> --python bg_render_gas.py -- preview <out.png> <percent> <samples>
#   blender -b <copy.blend> --python bg_render_gas.py -- full <samples>
# "full": raw backdrop, border-cropped occluder masks, hs_post grade, sprite
# cuts -> assets/art/iso/gas_backdrop.png, gs_occ_*.png, gas_sprites.json.
import bpy, sys, os, json, time
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
mode = argv[0]
S = bpy.data.scenes["GasIso"]
if bpy.context.window is not None:
    bpy.context.window.scene = S
BASE = r"C:\Users\jonathan.britton\OneDrive - WiseTech Global Pty Ltd\Documents\high_strangeness\assets\art\iso"
SRC = os.path.join(BASE, "_source")
proj = json.load(open(os.path.join(BASE, "projection.json")))


def P(x, y, z=0.0):
    return [proj["origin"][0] + proj["x"][0] * x + proj["y"][0] * y + proj["z"][0] * z,
            proj["origin"][1] + proj["x"][1] * x + proj["y"][1] * y + proj["z"][1] * z]


def log(msg):
    print(msg, flush=True)
    with open(os.path.join(SRC, "_gas_progress.txt"), "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def group(*prefixes):
    return [o for o in S.objects if o.name.startswith(prefixes)]


def screen_rect(objs, pad=24):
    xs, ys = [], []
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            sx, sy = P(w.x, w.y, w.z)
            xs.append(sx)
            ys.append(sy)
    W, H = S.render.resolution_x, S.render.resolution_y
    return (max(min(xs) - pad, 0), max(min(ys) - pad, 0), min(max(xs) + pad, W), min(max(ys) + pad, H))


def set_border(rect):
    if rect is None:
        S.render.use_border = False
        return
    W, H = S.render.resolution_x, S.render.resolution_y
    x0, y0, x1, y1 = rect
    S.render.use_border, S.render.use_crop_to_border = True, False
    S.render.border_min_x, S.render.border_max_x = x0 / W, x1 / W
    S.render.border_min_y, S.render.border_max_y = 1.0 - y1 / H, 1.0 - y0 / H


def render(path, samples, percent=100, rect=None):
    S.cycles.samples = samples
    S.render.resolution_percentage = percent
    set_border(rect)
    S.render.filepath = path
    S.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True, scene=S.name)


S.render.film_transparent = False
S.render.image_settings.color_mode = "RGB"
if mode == "preview":
    render(argv[1], int(argv[3]), int(argv[2]))
    log("preview done " + argv[1])
    sys.exit(0)

spp = int(argv[1])
exec(bpy.data.texts["hs_post"].as_string(), globals())
open(os.path.join(SRC, "_gas_progress.txt"), "w").close()
log("raw start")
render(os.path.join(SRC, "gas_raw.png"), spp)
log("raw done")

occluders = {
    "gs_occ_pumps": (group("gs_Pump"), (-3.0, 6.5)),
    "gs_occ_sign": (group("gs_Sign_"), (9.0, 6.5)),
    "gs_occ_tires": (group("gs_TireStack"), (6.4, 9.0)),
    "gs_occ_ice": (group("gs_Ice"), (-8.0, 9.3)),
    "gs_occ_phone": (group("gs_Phone_"), (-9.6, 8.4)),
    "gs_occ_air": (group("gs_Air_"), (3.6, 7.6)),
    # the canopy is always in front of the player (drawn above the y-sorted world)
    "gs_occ_canopy": (group("gs_Canopy_"), (-3.0, 3.9)),
    "gs_occ_palm": (group("gs_PalmSmall"), (11.9, 8.5)),
}
S.cycles.use_denoising = False
S.cycles.max_bounces = 0
for o in S.objects:
    if o.type == "LIGHT":
        o.visible_camera = False
allobjs = [o for o in S.objects if o.type in ("MESH", "CURVE", "FONT", "SURFACE")]
S.render.film_transparent = True
S.render.image_settings.color_mode = "RGBA"
for name, (objs, _) in occluders.items():
    keep = {o.name for o in objs}
    for o in allobjs:
        o.is_holdout = o.name not in keep
    render(os.path.join(SRC, name + "_mask.png"), 16, rect=screen_rect(objs))
    log("mask " + name)
for o in allobjs:
    o.is_holdout = False
set_border(None)

raw = load(os.path.join(SRC, "gas_raw.png"))[..., :3].copy()
final = paint_post(raw, bloom=float(os.environ.get("MOTEL_BLOOM", "0.6")),
                   paint_mix=float(os.environ.get("MOTEL_PAINT", "0.12")))
H, W, _ = final.shape
save_rgba(os.path.join(BASE, "gas_backdrop.png"), np.concatenate([final, np.ones((H, W, 1), dtype=np.float32)], -1))
piv = {n: P(*g) for n, (_, g) in occluders.items()}
info = {"occluders": cut_sprites2(final, BASE, SRC, list(occluders.keys()), piv)}
json.dump(info, open(os.path.join(BASE, "gas_sprites.json"), "w"), indent=1)
log("ALL DONE " + json.dumps(info))
