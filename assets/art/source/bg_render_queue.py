# Runs background renders one after another (they all want every CPU core).
#   blender -b --factory-startup --python bg_render_queue.py -- <wait_pid> <job> [<job> ...]
# job = "<blend>|<script>|<arg>,<arg>,..." with paths relative to this folder.
import bpy, sys, os, subprocess, time

argv = sys.argv[sys.argv.index("--") + 1:]
here = os.path.dirname(os.path.abspath(__file__))
wait_pid = int(argv[0])


def alive(pid):
    out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}"], capture_output=True, text=True).stdout
    return str(pid) in out


while wait_pid and alive(wait_pid):
    time.sleep(15)
env = dict(os.environ, MOTEL_PAINT="0.12", MOTEL_BLOOM="0.6")
for job in argv[1:]:
    blend, script, args = job.split("|")
    with open(os.path.join(here, "_queue_" + os.path.splitext(script)[0] + ".log"), "w") as log:
        subprocess.run([bpy.app.binary_path, "-b", "--factory-startup", os.path.join(here, blend), "--python",
                        os.path.join(here, script), "--"] + args.split(","), stdout=log, stderr=subprocess.STDOUT, env=env)
