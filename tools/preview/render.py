#!/usr/bin/env python3
"""
Renders pose frames exported by tools/preview/export.luau into a contact sheet PNG.

Each frame is a list of oriented boxes (Roblox parts). They are drawn with a simple flat-shaded
painter's algorithm from a few orthographic camera angles, so animation poses can be reviewed
without opening Roblox Studio.

    python3 tools/preview/render.py frames.json out.png
"""

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Camera angles: (label, yaw degrees around Y, pitch degrees). The character faces -Z.
# yaw 0 looks at the character's face from the front.
VIEWS = [
    ("front 3/4", -35.0, 12.0),
    ("side", -90.0, 4.0),
    ("top", -20.0, 70.0),
]

CELL_W, CELL_H = 250, 290
LABEL_H = 18
BG = (30, 31, 38)
GRID = (55, 57, 68)
LIGHT = np.array([0.45, 0.8, -0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def cframe_matrix(c):
    pos = np.array(c[0:3], dtype=float)
    rot = np.array(c[3:12], dtype=float).reshape(3, 3)
    return pos, rot


def camera_basis(yaw_deg, pitch_deg):
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    # Camera sits in front of the character (at -Z) rotated by yaw, raised by pitch, looking at origin.
    eye = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
    forward = -eye / np.linalg.norm(eye)
    world_up = np.array([0.0, 1.0, 0.0])
    right = np.cross(forward, world_up)
    if np.linalg.norm(right) < 1e-6:
        right = np.array([1.0, 0.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    return right, up, forward


def box_faces(size):
    sx, sy, sz = (s / 2 for s in size)
    v = np.array([
        [-sx, -sy, -sz], [sx, -sy, -sz], [sx, sy, -sz], [-sx, sy, -sz],
        [-sx, -sy, sz], [sx, -sy, sz], [sx, sy, sz], [-sx, sy, sz],
    ])
    faces = [
        [0, 3, 2, 1],  # -Z (front)
        [4, 5, 6, 7],  # +Z
        [0, 4, 7, 3],  # -X
        [1, 2, 6, 5],  # +X
        [3, 7, 6, 2],  # +Y
        [0, 1, 5, 4],  # -Y
    ]
    return v, faces


def wedge_faces(size):
    # Roblox WedgePart: full bottom, vertical back face at +Z, slope rising from front (-Z) to back.
    sx, sy, sz = (s / 2 for s in size)
    v = np.array([
        [-sx, -sy, -sz], [sx, -sy, -sz],  # front bottom edge
        [-sx, -sy, sz], [sx, -sy, sz],  # back bottom edge
        [-sx, sy, sz], [sx, sy, sz],  # back top edge
    ])
    faces = [
        [0, 1, 3, 2],  # bottom
        [2, 3, 5, 4],  # back
        [0, 4, 5, 1],  # slope
        [0, 2, 4],  # left side
        [1, 5, 3],  # right side
    ]
    return v, faces


def prism_faces(size, sides=10):
    # Roblox cylinders run along the part's X axis.
    length, diameter = size[0], min(size[1], size[2])
    r = diameter / 2
    verts = []
    for end in (-length / 2, length / 2):
        for i in range(sides):
            a = 2 * math.pi * i / sides
            verts.append([end, r * math.cos(a), r * math.sin(a)])
    v = np.array(verts)
    faces = [list(range(sides - 1, -1, -1)), list(range(sides, 2 * sides))]
    for i in range(sides):
        j = (i + 1) % sides
        faces.append([i, j, sides + j, sides + i])
    return v, faces


def sphere_faces(size, rings=6, segs=10):
    rx, ry, rz = (s / 2 for s in size)
    verts = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            verts.append([rx * math.sin(phi) * math.cos(th), ry * math.cos(phi), rz * math.sin(phi) * math.sin(th)])
    v = np.array(verts)
    faces = []
    for i in range(rings):
        for j in range(segs):
            a = i * segs + j
            b = i * segs + (j + 1) % segs
            c = (i + 1) * segs + (j + 1) % segs
            d = (i + 1) * segs + j
            faces.append([a, d, c, b])
    return v, faces


def part_polys(part):
    shape = part.get("shape", "Block")
    size = part["size"]
    if shape == "Wedge":
        v, faces = wedge_faces(size)
    elif shape == "Cylinder":
        v, faces = prism_faces(size)
    elif shape == "Ball":
        v, faces = sphere_faces(size)
    else:
        v, faces = box_faces(size)
    pos, rot = cframe_matrix(part["cf"])
    world = v @ rot.T + pos
    return world, faces


def shade(color, normal, alpha):
    lambert = max(0.0, float(np.dot(normal, LIGHT)))
    k = 0.42 + 0.58 * lambert
    return tuple(int(min(255, c * k)) for c in color) + (alpha,)


def render_cell(parts, view, scale, center, ground_y):
    _, yaw, pitch = view
    right, up, forward = camera_basis(yaw, pitch)
    img = Image.new("RGBA", (CELL_W, CELL_H - LABEL_H), BG + (255,))
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = CELL_W / 2, (CELL_H - LABEL_H) / 2

    def project(p):
        rel = p - center
        return (cx + float(np.dot(rel, right)) * scale, cy - float(np.dot(rel, up)) * scale)

    # Ground grid.
    for i in range(-6, 7):
        a = np.array([i * 2.0, ground_y, -12.0])
        b = np.array([i * 2.0, ground_y, 12.0])
        c = np.array([-12.0, ground_y, i * 2.0])
        d = np.array([12.0, ground_y, i * 2.0])
        draw.line([project(a), project(b)], fill=GRID, width=1)
        draw.line([project(c), project(d)], fill=GRID, width=1)
    # Facing arrow (character faces -Z).
    draw.line([project(np.array([0, ground_y, 0])), project(np.array([0, ground_y, -3]))], fill=(90, 200, 120), width=2)

    polys = []
    for part in parts:
        world, faces = part_polys(part)
        color = part.get("color", [200, 200, 200])
        alpha = int(255 * (1 - part.get("transparency", 0)))
        if alpha <= 0:
            continue
        for face in faces:
            pts = world[face]
            normal = np.cross(pts[1] - pts[0], pts[2] - pts[0])
            n = np.linalg.norm(normal)
            if n < 1e-9:
                continue
            normal /= n
            if np.dot(normal, forward) > 0:
                continue  # back face
            depth = float(np.mean(pts @ forward))
            polys.append((depth, [project(p) for p in pts], shade(color, normal, alpha)))
    polys.sort(key=lambda item: -item[0])
    for _, pts, fill in polys:
        draw.polygon(pts, fill=fill, outline=(0, 0, 0, 90))
    return img


VIEW_ALIASES = {"front": "front 3/4", "side": "side", "top": "top"}


def pick_views(data):
    names = data.get("views")
    if not names:
        return VIEWS
    wanted = [VIEW_ALIASES.get(n, n) for n in names]
    return [v for v in VIEWS if v[0] in wanted]


def render_sheet(data, out):
    """Rows of clips: each clip gets one strip per view, columns are keyframes."""
    rows = data["rows"]
    views = pick_views(data)
    all_pts = []
    for row in rows:
        for frame in row["frames"]:
            for part in frame["parts"]:
                world, _ = part_polys(part)
                all_pts.append(world)
    pts = np.concatenate(all_pts)
    center = (pts.min(axis=0) + pts.max(axis=0)) / 2
    extent = float(np.percentile(np.linalg.norm(pts - center, axis=1), 99))
    scale = min(CELL_W, CELL_H - LABEL_H) * 0.47 / max(extent, 1.0)
    ground_y = data.get("groundY", -3.0)
    cols = max(len(row["frames"]) for row in rows)
    strips = len(rows) * len(views)
    title_h = 26
    sheet = Image.new("RGB", (cols * CELL_W, strips * CELL_H + title_h), (20, 20, 26))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 12)
        title_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = title_font = ImageFont.load_default()
    draw.text((8, 5), data.get("title", ""), fill=(235, 235, 240), font=title_font)
    strip = 0
    for row in rows:
        for view in views:
            for c, frame in enumerate(row["frames"]):
                cell = render_cell(frame["parts"], view, scale, center, ground_y)
                x, y = c * CELL_W, title_h + strip * CELL_H
                sheet.paste(cell.convert("RGB"), (x, y + LABEL_H))
                prefix = row["title"] + " " if c == 0 else ""
                draw.text((x + 4, y + 2), f"{prefix}{frame.get('label', '')}", fill=(205, 205, 215), font=font)
                draw.line([(x, y), (x, y + CELL_H)], fill=(10, 10, 14))
            draw.line([(0, title_h + strip * CELL_H), (cols * CELL_W, title_h + strip * CELL_H)], fill=(70, 70, 90))
            strip += 1
    sheet.save(out)
    print(f"wrote {out} ({len(rows)} clips x {len(views)} views)")


def main():
    src, out = sys.argv[1], sys.argv[2]
    with open(src) as f:
        data = json.load(f)
    if data.get("rows"):
        render_sheet(data, out)
        return
    frames = data["frames"]
    views = pick_views(data)

    # One shared scale/centre for every frame so motion between frames reads correctly.
    all_pts = []
    for frame in frames:
        for part in frame["parts"]:
            world, _ = part_polys(part)
            all_pts.append(world)
    pts = np.concatenate(all_pts)
    center = (pts.min(axis=0) + pts.max(axis=0)) / 2
    extent = float(np.max(np.linalg.norm(pts - center, axis=1)))
    scale = min(CELL_W, CELL_H - LABEL_H) * 0.47 / max(extent, 1.0)
    ground_y = data.get("groundY", -3.0)

    cols = len(frames)
    rows = len(views)
    title_h = 26
    sheet = Image.new("RGB", (cols * CELL_W, rows * CELL_H + title_h), (20, 20, 26))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 13)
        title_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = title_font = ImageFont.load_default()
    draw.text((8, 5), data.get("title", ""), fill=(235, 235, 240), font=title_font)
    for r, view in enumerate(views):
        for c, frame in enumerate(frames):
            cell = render_cell(frame["parts"], view, scale, center, ground_y)
            x, y = c * CELL_W, title_h + r * CELL_H
            sheet.paste(cell.convert("RGB"), (x, y + LABEL_H))
            label = f"{frame.get('label', '')}  [{view[0]}]"
            draw.text((x + 6, y + 2), label, fill=(200, 200, 210), font=font)
            draw.line([(x, y), (x, y + CELL_H)], fill=(10, 10, 14))
    sheet.save(out)
    print(f"wrote {out} ({cols} frames x {rows} views)")


if __name__ == "__main__":
    main()
