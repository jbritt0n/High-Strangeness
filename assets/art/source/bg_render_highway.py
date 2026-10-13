# Background render of the HighwayIso scene (see highway_build.py).
#   blender -b <copy.blend> --python bg_render_highway.py -- preview <out.png> <percent> <samples> [details]
#   blender -b <copy.blend> --python bg_render_highway.py -- full <samples>
# "full": raw backdrop (reading details hidden) + a details-visible pass over the
# pull-off only, border-cropped alpha masks for occluders and details, then the
# hs_post paint/grade pass. Occluders and details are cut from the graded images
# so they match the backdrop exactly. Writes assets/art/iso/highway_*.
import bpy, sys, os, json, time

argv = sys.argv[sys.argv.index("--") + 1:]
mode = argv[0]
S = bpy.data.scenes["HighwayIso"]
if bpy.context.window is not None:
    bpy.context.window.scene = S
O = bpy.data.objects
BASE = r"C:\Users\jonathan.britton\OneDrive - WiseTech Global Pty Ltd\Documents\high_strangeness\assets\art\iso"
SRC = os.path.join(BASE, "_source")
READINGS = ("light", "watcher", "planted", "shadow")

proj = json.load(open(os.path.join(BASE, "projection.json")))


def P(x, y, z=0.0):
    return [proj["origin"][0] + proj["x"][0] * x + proj["y"][0] * y + proj["z"][0] * z,
            proj["origin"][1] + proj["x"][1] * x + proj["y"][1] * y + proj["z"][1] * z]


def log(msg):
    print(msg, flush=True)
    with open(os.path.join(SRC, "_highway_progress.txt"), "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def details(reading=None):
    return [o for o in S.objects if o.name.startswith("hy_det_" + (reading + "_" if reading else ""))]


def items():
    return [o for o in S.objects if o.name.startswith(("hy_item_", "hk_item_"))]


def show_details(on):
    for o in details() + items():
        o.hide_render = not on


def screen_rect(objs, pad=24):
    """Pixel rect (x0, y0, x1, y1, top-left origin) covering the objects."""
    xs, ys = [], []
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ __import__("mathutils").Vector(c)
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


if mode == "preview":
    out, pct, spp = argv[1], int(argv[2]), int(argv[3])
    show_details(len(argv) > 4 and argv[4] == "details")
    S.render.film_transparent = False
    S.render.image_settings.color_mode = "RGB"
    render(out, spp, pct)
    log("preview done " + out)
    sys.exit(0)

spp = int(argv[1])
exec(bpy.data.texts["hs_post"].as_string(), globals())
open(os.path.join(SRC, "_highway_progress.txt"), "w").close()
S.render.film_transparent = False
S.render.image_settings.color_mode = "RGB"

show_details(False)
if mode == "full":
    log("raw start")
    render(os.path.join(SRC, "highway_raw.png"), spp)
    log("raw done")
# "details" mode reuses the existing raw frame (details/items are hidden in it anyway)
show_details(True)
det_rect = screen_rect(details() + items(), 40)
render(os.path.join(SRC, "highway_raw_details.png"), spp, rect=det_rect)
log("details pass done")


def group(*prefixes):
    return [o for o in S.objects if o.name.startswith(prefixes)]


occluders = {
    "hw_occ_marker": (group("hy_MM_"), (5.0, 6.8)),
    "hw_occ_tree": (group("hy_JT_occ_"), (3.5, 10.0)),
    "hw_occ_rocks": (group("hy_Rock"), (0.9, 10.9)),
}
# south-shoulder delineators the player can walk behind
for i, x in ((1, -12), (2, 0), (3, 12)):
    occluders[f"hw_occ_delin{i}"] = (group(f"hy_Delin{i}_"), (float(x), -6.6))

# masks: everything outside the group is a holdout; alpha only, border-cropped
S.cycles.use_denoising = False
S.cycles.max_bounces = 0
for o in S.objects:
    if o.type == "LIGHT":
        o.visible_camera = False
allobjs = [o for o in S.objects if o.type in ("MESH", "CURVE", "FONT", "SURFACE")]
S.render.film_transparent = True
S.render.image_settings.color_mode = "RGBA"
masks = {name: objs for name, (objs, _) in occluders.items()}
for r in READINGS:
    masks["hw_det_" + r] = details(r)
masks["hw_item_tire"] = [o for o in items() if o.name.startswith(("hy_item_tire", "hk_item_tire"))]
for name, objs in masks.items():
    keep = {o.name for o in objs}
    for o in allobjs:
        o.is_holdout = o.name not in keep
    render(os.path.join(SRC, name + "_mask.png"), 16, rect=screen_rect(objs))
    log("mask " + name)
for o in allobjs:
    o.is_holdout = False
set_border(None)

H = S.render.resolution_y
raw = load(os.path.join(SRC, "highway_raw.png"))[..., :3].copy()
# paste the details pass over the raw frame (only its border region was rendered)
x0, y0, x1, y1 = [int(v) for v in det_rect]
rd = load(os.path.join(SRC, "highway_raw_details.png"))[..., :3]
raw_d = raw.copy()
raw_d[H - y1:H - y0, x0:x1] = rd[H - y1:H - y0, x0:x1]

bloom = float(os.environ.get("MOTEL_BLOOM", "0.6"))
paint = float(os.environ.get("MOTEL_PAINT", "0.12"))
final = paint_post(raw, bloom=bloom, paint_mix=paint)
Hh, W, _ = final.shape
save_rgba(os.path.join(BASE, "highway_backdrop.png"),
          np.concatenate([final, np.ones((Hh, W, 1), dtype=np.float32)], -1))
final_d = paint_post(raw_d, bloom=bloom, paint_mix=paint)

piv = {name: P(*g) for name, (_, g) in occluders.items()}
info = {"occluders": cut_sprites2(final, BASE, SRC, list(occluders.keys()), piv)}
det_names = ["hw_det_" + r for r in READINGS] + ["hw_item_tire"]
info["details"] = cut_sprites2(final_d, BASE, SRC, det_names, {n: [0.0, 0.0] for n in det_names})
json.dump(info, open(os.path.join(BASE, "highway_sprites.json"), "w"), indent=1)
log("ALL DONE " + json.dumps(info))
