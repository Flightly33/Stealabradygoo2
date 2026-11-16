"""
Dev tool: draws the geometry exported by tools/export_scenes.luau.

This is a tiny software renderer (orthographic, painter's algorithm, flat
shading). It exists so the part-built models can be eyeballed without Roblox
Studio. It is NOT what the game looks like in Roblox - no lighting, materials,
particles, text or faces drawn with SurfaceGuis - but shapes, proportions,
colours and layout are faithful.

    python3 tools/render_scenes.py        # writes docs/preview-*.png
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENES = os.path.join(ROOT, "build", "scenes.json")
OUT = os.path.join(ROOT, "docs")

BG = (30, 27, 48)
LIGHT = (0.35, 0.75, 0.55)


def norm(v):
    length = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / length for c in v)


LIGHT = norm(LIGHT)


def view_matrix(yaw_deg, pitch_deg):
    """World -> view rotation. The camera looks along -Z in view space."""
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    cy, sy, cp, sp = math.cos(y), math.sin(y), math.cos(p), math.sin(p)
    ry = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    rx = ((1, 0, 0), (0, cp, -sp), (0, sp, cp))
    return tuple(tuple(sum(rx[i][k] * ry[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def apply(m, v):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def part_faces(part):
    """Returns a list of faces, each a list of world-space vertices."""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part["cf"]
    rot = ((r00, r01, r02), (r10, r11, r12), (r20, r21, r22))
    sx, sy, sz = (s / 2 for s in part["size"])

    def world(p):
        q = apply(rot, p)
        return (q[0] + x, q[1] + y, q[2] + z)

    shape = part["shape"]
    faces = []
    if shape == "Wedge":
        # Roblox WedgePart: full bottom, full back (+Z) face, slope down to the front
        c = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (-sx, sy, sz), (sx, sy, sz)]
        for idx in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)):
            faces.append([world(c[i]) for i in idx])
        return faces
    if shape == "Cylinder":
        # a Roblox cylinder's axis is its local X
        n = 14
        ring = [(math.cos(2 * math.pi * i / n) * sy, math.sin(2 * math.pi * i / n) * sz) for i in range(n)]
        for i in range(n):
            a, b = ring[i], ring[(i + 1) % n]
            faces.append([world((-sx, a[0], a[1])), world((sx, a[0], a[1])), world((sx, b[0], b[1])), world((-sx, b[0], b[1]))])
        faces.append([world((sx, a, b)) for a, b in ring])
        faces.append([world((-sx, a, b)) for a, b in reversed(ring)])
    elif shape == "Ball":
        # low-poly sphere
        rows, cols = 6, 10
        r = min(sx, sy, sz)

        def pt(i, j):
            theta = math.pi * i / rows
            phi = 2 * math.pi * j / cols
            return world((r * math.sin(theta) * math.cos(phi), r * math.cos(theta), r * math.sin(theta) * math.sin(phi)))

        for i in range(rows):
            for j in range(cols):
                faces.append([pt(i, j), pt(i, j + 1), pt(i + 1, j + 1), pt(i + 1, j)])
    else:
        c = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        for idx in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)):
            faces.append([world(c[i]) for i in idx])
    return faces


def terrain_parts(scene):
    """Turns recorded Terrain:Fill* calls into renderable pseudo-parts."""
    colors = scene.get("terrainColors", {})
    default = {"Water": [0.16, 0.66, 0.82], "Grass": [0.41, 0.75, 0.31], "Sand": [0.94, 0.86, 0.65]}
    out = []
    for op in scene.get("terrain", []):
        mat = op["material"]
        color = colors.get(mat) or default.get(mat) or [0.5, 0.5, 0.5]
        alpha = 0.75 if mat == "Water" else 1
        if op["op"] == "block":
            out.append({"name": "Terrain" + mat, "cf": op["cf"], "size": op["size"], "color": color, "shape": "Block", "alpha": alpha})
        elif op["op"] == "ball":
            c = op["center"]
            d = op["radius"] * 2
            out.append({"name": "Terrain" + mat, "cf": [c[0], c[1], c[2], 1, 0, 0, 0, 1, 0, 0, 0, 1], "size": [d, d, d], "color": color, "shape": "Ball", "alpha": alpha})
        elif op["op"] == "cylinder":
            x, y, z = op["cf"][0:3]
            d = op["radius"] * 2
            # terrain cylinders stand along Y; a part cylinder's axis is X
            out.append({"name": "Terrain" + mat, "cf": [x, y, z, 0, -1, 0, 1, 0, 0, 0, 0, 1], "size": [op["height"], d, d], "color": color, "shape": "Cylinder", "alpha": alpha})
    return out


def render(parts, yaw, pitch, size, pad=18, zoom=None, label=None, bounds=None):
    m = view_matrix(yaw, pitch)
    polys = []
    for part in parts:
        base = tuple(int(255 * c) for c in part["color"])
        for face in part_faces(part):
            pts = [apply(m, v) for v in face]
            # face normal from the first three vertices
            ax, ay, az = (pts[1][i] - pts[0][i] for i in range(3))
            bx, by, bz = (pts[2][i] - pts[0][i] for i in range(3))
            n = norm((ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx))
            if n[2] <= 0.02:
                continue  # facing away from the camera
            shade = 1.0 if part.get("neon") else 0.5 + 0.5 * max(0.0, sum(n[i] * LIGHT[i] for i in range(3)))
            color = tuple(min(255, int(c * shade)) for c in base)
            depth = sum(p[2] for p in pts) / len(pts)
            # The painter's algorithm cannot order a thin detail against the
            # big surface it sits on, so thin parts get a small nudge forward.
            if min(part["size"]) < 0.1:
                depth += 0.9
            polys.append((depth, [(p[0], p[1]) for p in pts], color, part.get("alpha", 1)))
    if not polys:
        return Image.new("RGB", size, BG)
    if bounds:
        min_x, max_x, min_y, max_y = bounds
    else:
        xs = [p[0] for _, pts, _, _ in polys for p in pts]
        ys = [p[1] for _, pts, _, _ in polys for p in pts]
        min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    w, h = size
    label_h = 26 if label else 0
    scale = zoom or min((w - 2 * pad) / max(max_x - min_x, 0.01), (h - 2 * pad - label_h) / max(max_y - min_y, 0.01))
    cx, cy = (min_x + max_x) / 2, (min_y + max_y) / 2

    image = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(image, "RGBA")
    for depth, pts, color, alpha in sorted(polys, key=lambda p: p[0]):
        screen = [(w / 2 + (px - cx) * scale, (h - label_h) / 2 - (py - cy) * scale) for px, py in pts]
        outline = tuple(int(c * 0.72) for c in color)
        draw.polygon(screen, fill=color + (int(255 * alpha),), outline=outline + (int(255 * alpha),))
    if label:
        draw.text((w / 2, h - label_h / 2 - 2), label, fill=(255, 255, 255), anchor="mm", font=font(15))
    return image


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def sheet(images, columns, title):
    w, h = images[0].size
    rows = math.ceil(len(images) / columns)
    out = Image.new("RGB", (w * columns, h * rows + 44), BG)
    ImageDraw.Draw(out).text((out.width / 2, 22), title, fill=(126, 232, 74), anchor="mm", font=font(24))
    for i, image in enumerate(images):
        out.paste(image, ((i % columns) * w, 44 + (i // columns) * h))
    return out


def main():
    if not os.path.exists(SCENES):
        sys.exit("build/scenes.json is missing - run: lune run tools/export_scenes.luau")
    with open(SCENES) as handle:
        scenes = json.load(handle)
    os.makedirs(OUT, exist_ok=True)
    groups = {}
    for scene in scenes:
        groups.setdefault(scene["group"], []).append(scene)
    for group in groups.values():
        group.sort(key=lambda s: s["order"])

    # Brady faces -Z, so the camera is turned 180 degrees to see his front.
    front = dict(yaw=205, pitch=10)

    # The ten stages at ONE shared scale so the growth is visible.
    stages = groups["stages"]
    tallest = max(max(p["cf"][1] + p["size"][1] / 2 for p in s["parts"]) for s in stages)
    zoom = 250 / (tallest + 0.6)
    images = [render(s["parts"], size=(210, 330), zoom=zoom, label=s["label"].split(" - ")[1], bounds=(-2.6, 2.6, -0.2, tallest + 0.3), **front) for s in stages]
    sheet(images, 5, "Raise Brady Goo - the ten stages (same scale)").save(os.path.join(OUT, "preview-stages.png"))

    images = [render(s["parts"], size=(250, 330), label=s["label"], **front) for s in groups["special"]]
    images += [render(s["parts"], size=(250, 330), label=s["label"], yaw=25, pitch=10) for s in groups["back"]]
    sheet(images, 5, "Outfits (age 25) + back views").save(os.path.join(OUT, "preview-outfits.png"))

    images = [render(s["parts"], size=(250, 230), label=s["label"], yaw=205, pitch=24) for s in groups["furniture"]]
    sheet(images, 4, "Furniture samples").save(os.path.join(OUT, "preview-furniture.png"))

    world = terrain_parts(groups["world"][0]) + groups["world"][0]["parts"]
    render(world, yaw=180, pitch=90, size=(900, 1100), label="Map - top down (north = clothing store, south = houses)").save(os.path.join(OUT, "preview-map.png"))
    render(world, yaw=215, pitch=38, size=(1300, 760)).save(os.path.join(OUT, "preview-map-angle.png"))

    images = []
    for s in groups["house"]:
        roofish = ("Roof", "Ridge", "Chimney", "Gable", "Fascia", "Attic", "Parapet", "Skylight", "AC")
        no_roof = [p for p in s["parts"] if not p["name"].startswith(roofish)]
        images.append(render(no_roof, yaw=180, pitch=90, size=(520, 520), zoom=7.6, label=s["label"] + " - inside, top down"))
        s["parts"] = [p for p in s["parts"] if p["name"] != "RoofGlow"] + [p for p in s["parts"] if p["name"] == "RoofGlow"]
        images.append(render(s["parts"], yaw=235, pitch=28, size=(520, 520), zoom=6.2, label=s["label"] + " - outside"))
    sheet(images, 2, "The house grows with Brady (same scale)").save(os.path.join(OUT, "preview-house.png"))

    images = []
    for s in groups.get("styles", []):
        images.append(render(s["parts"], yaw=235, pitch=24, size=(460, 400), label=s["label"]))
    if images:
        sheet(images, 3, "House styles").save(os.path.join(OUT, "preview-house-styles.png"))
    # close-up of the plaza / spawn area with terrain
    near = [p for p in world if abs(p["cf"][0]) < 95 and -110 < p["cf"][2] < 100 and max(p["size"]) < 300]
    render(near, yaw=200, pitch=32, size=(1300, 760), label="Plaza close-up").save(os.path.join(OUT, "preview-plaza.png"))
    print("wrote previews to", OUT)


if __name__ == "__main__":
    main()
