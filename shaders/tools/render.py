#!/usr/bin/env python3
"""Headless shaderbg-compatible renderer.
usage: render.py shader.frag out.png [t1,t2,...] [WxH]
Renders each time to out_<t>.png (or out.png if a single time). Also prints
avg GPU ms per frame for a rough perf check."""
import sys, time, moderngl, numpy as np
from PIL import Image

frag_path, out = sys.argv[1], sys.argv[2]
times = [float(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "10").split(",")]
W, H = (int(v) for v in (sys.argv[4] if len(sys.argv) > 4 else "2560x1440").split("x"))

hdr = ("#version 450\nuniform vec3 iResolution; uniform float iTime; uniform float iTimeDelta;"
       " uniform int iFrame; uniform vec4 iMouse;\n")
src = hdr + open(frag_path).read() + "\nout vec4 fragColor; void main(){ mainImage(fragColor, gl_FragCoord.xy); }\n"
vs = "#version 450\nin vec2 pos; void main(){ gl_Position = vec4(pos,0,1); }"

ctx = moderngl.create_standalone_context(backend="egl")
try:
    prog = ctx.program(vertex_shader=vs, fragment_shader=src)
except moderngl.Error as e:
    print("COMPILE ERROR:\n", e); sys.exit(1)
vbo = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype="f4"))
vao = ctx.simple_vertex_array(prog, vbo, "pos")
fbo = ctx.simple_framebuffer((W, H))
fbo.use()

def setu(n, v):
    if n in prog: prog[n].value = v
setu("iResolution", (W, H, 1.0)); setu("iTimeDelta", 1 / 60); setu("iMouse", (0, 0, 0, 0))

for t in times:
    setu("iTime", t); setu("iFrame", int(t * 60))
    vao.render(moderngl.TRIANGLE_STRIP)
    img = Image.frombytes("RGB", (W, H), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
    name = out if len(times) == 1 else out.replace(".png", f"_{t:g}.png")
    img.resize((W // 2, H // 2), Image.LANCZOS).save(name)
    print("wrote", name)

# perf: 30 frames
ctx.finish(); t0 = time.time()
for i in range(30):
    setu("iTime", 5 + i / 60); vao.render(moderngl.TRIANGLE_STRIP)
ctx.finish()
print(f"~{(time.time() - t0) / 30 * 1000:.2f} ms/frame at {W}x{H}")
