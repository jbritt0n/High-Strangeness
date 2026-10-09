# Background render of the MotelIso exterior.
#   blender -b <copy.blend> --python bg_render_motel.py -- preview <out.png> <percent> <samples>
#   blender -b <copy.blend> --python bg_render_motel.py -- full <samples>
# "full" renders the raw frame + occluder masks into assets/art/iso/_source,
# then runs the hs_post paint/grade pass and cuts the occluder sprites.
import bpy, sys, os, json, time

argv = sys.argv[sys.argv.index("--") + 1:]
mode = argv[0]
S = bpy.data.scenes["MotelIso"]
if bpy.context.window is not None:
    bpy.context.window.scene = S
O = bpy.data.objects
BASE = r"C:\Users\jonathan.britton\OneDrive - WiseTech Global Pty Ltd\Documents\high_strangeness\assets\art\iso"
SRC = os.path.join(BASE, "_source")


def log(msg):
    print(msg, flush=True)
    with open(os.path.join(SRC, "_motel_progress.txt"), "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def render(path, samples, percent=100):
    S.cycles.samples = samples
    S.render.resolution_percentage = percent
    S.render.filepath = path
    S.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True, scene=S.name)


if mode == "preview":
    out, pct, spp = argv[1], int(argv[2]), int(argv[3])
    S.render.film_transparent = False
    S.render.image_settings.color_mode = "RGB"
    render(out, spp, pct)
    log("preview done " + out)
    sys.exit(0)

spp = int(argv[1])
exec(bpy.data.texts["hs_post"].as_string(), globals())
open(os.path.join(SRC, "_motel_progress.txt"), "w").close()
if mode == "full":
    S.render.film_transparent = False
    S.render.image_settings.color_mode = "RGB"
    log("raw start")
    render(os.path.join(SRC, "motel_raw.png"), spp)
    log("raw done")
# ("post" mode reuses the existing raw frame and only redoes masks + post)


def kids(name):
    return [O[name]] + list(O[name].children_recursive)


groups = {
    "occ_car": kids("Car"),
    "occ_sign": kids("Sign"),
    "occ_dumpster": [O["p_Dumpster"], O["p_DumpLid"]],
    "occ_lamp": [O["p_LampPole"], O["p_LampArm"], O["p_LampHead"]],
    "occ_barrel": [O["p_Barrel"], O["p_Flame"]],
}
# masks: everything except the group is a holdout; cheap settings, alpha only
S.cycles.use_denoising = False
S.cycles.max_bounces = 0
for o in S.objects:
    if o.type == "LIGHT":
        o.visible_camera = False  # sized lights would otherwise show up in every mask
    elif o.type == "MESH" and any(m and m.name == "iso_stain" for m in o.data.materials):
        o.hide_render = True  # soft-edged decals: holdout + transparency leaks partial alpha
allobjs = [o for o in S.objects if o.type in ("MESH", "CURVE", "FONT", "SURFACE")]
S.render.film_transparent = True
S.render.image_settings.color_mode = "RGBA"
for name, objs in groups.items():
    keep = {o.name for o in objs}
    for o in allobjs:
        o.is_holdout = o.name not in keep
    O["p_Flame"].hide_render = "p_Flame" not in keep  # transparent flame leaks like the decals
    render(os.path.join(SRC, name + "_mask.png"), 16)
    log("mask " + name)
for o in allobjs:
    o.is_holdout = False

proj = json.load(open(os.path.join(BASE, "projection.json")))


def P(x, y, z=0):
    return [proj["origin"][0] + proj["x"][0] * x + proj["y"][0] * y + proj["z"][0] * z,
            proj["origin"][1] + proj["x"][1] * x + proj["y"][1] * y + proj["z"][1] * z]


raw = load(os.path.join(SRC, "motel_raw.png"))[..., :3].copy()
final = paint_post(raw, bloom=float(os.environ.get("MOTEL_BLOOM", "0.6")),
                   paint_mix=float(os.environ.get("MOTEL_PAINT", "0.12")))
H, W, _ = final.shape
save_rgba(os.path.join(BASE, "motel_backdrop.png"),
          np.concatenate([final, np.ones((H, W, 1), dtype=np.float32)], -1))
piv = {"occ_car": P(-6.4, 4.8), "occ_sign": P(22.0, -6.0), "occ_dumpster": P(-3.0, -14.0),
       "occ_lamp": P(-4.0, -8.5), "occ_barrel": P(-9.4, -5.0)}
info = cut_sprites2(final, BASE, SRC, list(piv.keys()), piv)
json.dump(info, open(os.path.join(BASE, "occluders.json"), "w"), indent=1)
log("ALL DONE " + json.dumps(info))
