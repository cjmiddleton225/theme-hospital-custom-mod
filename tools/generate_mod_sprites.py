#!/usr/bin/env python3
"""Generate authentic 1997 Bullfrog Theme Hospital-style custom pixel-art PNG sprites
and compiled fallback sheet (`mod_sprites.{pal,tab,dat}`) for CorsixTH Pass 4.

Uses a 2x supersampled orthographic 2:1 isometric 3D z-buffered renderer with
Blinn-Phong specular lighting, crevice ambient occlusion, soft dithered floor
shadows, Bullfrog visual hierarchy (soft-edged 3D machines, 1px-outlined
characters), and quantization into the official 255-color MPalette.dat space.

Outputs into `CorsixTH/Bitmap/mod_sprites/`:
  - quoiging_chair_idle.png, quoiging_chair_active.png    (112x108)
  - quoiging_red_hands_01..04.png                         (96x96)
  - quoiging_silly_hat_01..04.png                         (48x48)
  - up_down_rig_idle.png, up_down_rig_active.png          (160x144)
  - up_down_leg_grab_01..02.png                           (96x112)
  - up_down_dangle_male_01..04.png                        (96x112)
  - up_down_dangle_female_01..04.png                      (96x112)
  - up_down_claw_hold_01..02.png                          (96x112)
  - mod_sprites.pal, mod_sprites.tab, mod_sprites.dat     (fallback sheet)

To customize art later, replace any PNG in `CorsixTH/Bitmap/mod_sprites/` and run:
    python tools/generate_mod_sprites.py --compile-only
"""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import numpy as np
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "CorsixTH" / "Bitmap" / "mod_sprites"

FRAME_NAMES: Tuple[str, ...] = (
    "quoiging_chair_idle.png",
    "quoiging_chair_active.png",
    "quoiging_red_hands_01.png",
    "quoiging_red_hands_02.png",
    "quoiging_red_hands_03.png",
    "quoiging_red_hands_04.png",
    "quoiging_silly_hat_01.png",
    "quoiging_silly_hat_02.png",
    "quoiging_silly_hat_03.png",
    "quoiging_silly_hat_04.png",
    "up_down_rig_idle.png",
    "up_down_rig_active.png",
    "up_down_leg_grab_01.png",
    "up_down_leg_grab_02.png",
    "up_down_dangle_male_01.png",
    "up_down_dangle_male_02.png",
    "up_down_dangle_male_03.png",
    "up_down_dangle_male_04.png",
    "up_down_dangle_female_01.png",
    "up_down_dangle_female_02.png",
    "up_down_dangle_female_03.png",
    "up_down_dangle_female_04.png",
    "up_down_claw_hold_01.png",
    "up_down_claw_hold_02.png",
)

OBSOLETE_FILES: Tuple[str, ...] = (
    "up_down_big_hands_01.png",
    "up_down_big_hands_02.png",
    "up_down_big_hands_03.png",
    "up_down_big_hands_04.png",
)

# Official 1997 Theme Hospital 255-color MPalette.dat (index 255 reserved for transparent magenta)
TH_PALETTE_LIST: List[Tuple[int, int, int]] = [
    (0, 0, 0), (203, 150, 154), (190, 134, 146), (178, 121, 134),
    (170, 109, 130), (158, 97, 121), (150, 89, 117), (138, 77, 109),
    (138, 65, 0), (154, 40, 0), (170, 48, 0), (186, 56, 4),
    (203, 69, 8), (219, 81, 12), (235, 93, 20), (255, 109, 28),
    (93, 93, 93), (81, 81, 81), (69, 69, 69), (60, 60, 60),
    (48, 48, 48), (32, 32, 32), (0, 130, 101), (8, 182, 125),
    (81, 195, 142), (81, 203, 190), (0, 105, 81), (255, 121, 0),
    (255, 154, 0), (255, 186, 0), (255, 219, 0), (255, 255, 0),
    (0, 0, 0), (69, 65, 97), (89, 81, 113), (109, 97, 130),
    (0, 0, 134), (4, 16, 150), (20, 40, 166), (36, 69, 182),
    (52, 97, 203), (73, 125, 219), (125, 125, 4), (125, 113, 4),
    (125, 105, 8), (125, 97, 12), (125, 89, 12), (125, 81, 16),
    (125, 77, 20), (243, 182, 178), (227, 121, 109), (215, 105, 89),
    (199, 85, 60), (186, 65, 36), (174, 48, 12), (162, 36, 0),
    (121, 44, 60), (138, 65, 85), (154, 89, 109), (182, 134, 154),
    (174, 73, 28), (154, 48, 32), (134, 36, 40), (113, 36, 52),
    (16, 4, 113), (0, 105, 85), (69, 85, 113), (77, 93, 125),
    (89, 101, 142), (101, 109, 154), (113, 117, 170), (125, 125, 182),
    (142, 138, 199), (158, 150, 215), (0, 89, 4), (0, 109, 4),
    (0, 134, 4), (0, 158, 4), (0, 182, 4), (0, 207, 4),
    (0, 231, 4), (0, 162, 125), (0, 154, 134), (0, 146, 138),
    (0, 134, 138), (0, 113, 130), (0, 93, 121), (0, 77, 113),
    (0, 65, 109), (219, 158, 150), (203, 142, 138), (190, 130, 125),
    (178, 117, 113), (162, 105, 105), (150, 93, 97), (138, 85, 89),
    (130, 81, 69), (0, 44, 182), (0, 93, 219), (170, 203, 255),
    (154, 174, 215), (154, 146, 199), (146, 138, 186), (142, 130, 178),
    (134, 125, 170), (130, 117, 162), (121, 113, 150), (117, 105, 142),
    (105, 93, 125), (101, 44, 44), (109, 56, 44), (117, 69, 44),
    (125, 89, 48), (28, 121, 170), (32, 130, 174), (36, 138, 178),
    (44, 146, 186), (48, 154, 190), (56, 166, 199), (60, 174, 203),
    (69, 182, 207), (77, 190, 215), (85, 203, 219), (89, 211, 227),
    (97, 219, 231), (113, 235, 243), (121, 243, 247), (154, 101, 4),
    (158, 109, 12), (166, 117, 24), (174, 130, 36), (178, 138, 44),
    (186, 150, 60), (195, 158, 73), (199, 170, 89), (207, 178, 101),
    (215, 190, 117), (219, 203, 134), (227, 211, 154), (235, 219, 170),
    (239, 231, 190), (247, 239, 207), (0, 85, 0), (4, 101, 0),
    (20, 121, 8), (36, 142, 16), (56, 162, 28), (56, 170, 36),
    (56, 178, 48), (60, 186, 69), (73, 195, 93), (89, 203, 117),
    (105, 211, 142), (117, 219, 162), (150, 235, 203), (170, 247, 223),
    (211, 255, 255), (101, 101, 101), (109, 109, 109), (121, 121, 121),
    (130, 130, 130), (142, 142, 142), (154, 154, 154), (162, 162, 162),
    (170, 170, 170), (182, 182, 182), (190, 190, 190), (203, 203, 203),
    (211, 211, 211), (223, 223, 223), (235, 235, 235), (243, 243, 243),
    (255, 255, 255), (182, 138, 134), (166, 125, 134), (170, 154, 138),
    (158, 142, 125), (150, 134, 121), (142, 146, 166), (142, 138, 162),
    (138, 138, 174), (0, 97, 8), (8, 109, 20), (85, 81, 97),
    (97, 93, 97), (89, 89, 97), (77, 77, 97), (97, 93, 134),
    (0, 85, 121), (0, 0, 4), (56, 24, 4), (65, 28, 4),
    (73, 32, 4), (81, 36, 4), (89, 40, 4), (97, 44, 4),
    (105, 48, 4), (113, 52, 4), (73, 93, 142), (73, 97, 162),
    (89, 97, 105), (81, 73, 85), (150, 142, 190), (134, 89, 65),
    (138, 93, 65), (130, 81, 52), (130, 85, 56), (138, 89, 56),
    (142, 97, 69), (121, 77, 48), (146, 105, 81), (146, 109, 97),
    (121, 73, 44), (146, 101, 73), (150, 105, 77), (146, 105, 89),
    (138, 85, 52), (142, 101, 81), (154, 117, 93), (130, 77, 48),
    (146, 93, 56), (150, 113, 85), (170, 186, 211), (142, 89, 52),
    (142, 105, 93), (130, 85, 65), (134, 93, 73), (146, 93, 65),
    (162, 117, 89), (154, 109, 81), (162, 154, 158), (154, 142, 146),
    (134, 105, 93), (150, 146, 154), (162, 174, 199), (134, 97, 81),
    (125, 77, 56), (158, 109, 97), (97, 81, 65), (154, 121, 65),
    (178, 130, 97), (154, 117, 101), (125, 85, 56), (117, 77, 48),
    (154, 162, 186), (0, 32, 56), (48, 0, 65), (56, 40, 65),
    (48, 81, 65), (24, 48, 89), (73, 89, 97), (121, 89, 97),
    (97, 81, 130), (105, 121, 130), (101, 85, 101),
]
TH_PALETTE = np.array(TH_PALETTE_LIST, dtype=np.float32)

BAYER2 = np.array([[0, 2], [3, 1]], dtype=np.float32) / 4.0 - 0.375

MATERIALS = {
    "chrome":        ((198, 206, 214), 0.95, 28.0, 0.30, (220, 232, 244)),
    "chrome_dark":   ((122, 130, 142), 0.75, 22.0, 0.28, (165, 178, 195)),
    "steel":         ((140, 148, 158), 0.50, 16.0, 0.28, (170, 184, 200)),
    "steel_dark":    ((86,  94,  106), 0.38, 14.0, 0.26, (120, 134, 152)),
    "enamel":        ((224, 224, 216), 0.45, 20.0, 0.36, (210, 220, 230)),
    "enamel_cool":   ((196, 204, 212), 0.45, 18.0, 0.34, (200, 216, 230)),
    "teal":          ((42,  148, 168), 0.55, 18.0, 0.30, (120, 214, 224)),
    "teal_dark":     ((24,  96,  114), 0.40, 14.0, 0.28, (70,  160, 176)),
    "leather_red":   ((204, 46,  40),  0.45, 14.0, 0.32, (242, 132, 118)),
    "glove_red":     ((242, 50,  40),  0.72, 20.0, 0.38, (255, 174, 160)),
    "crimson_dark":  ((136, 26,  32),  0.30, 10.0, 0.28, (186, 78,  82)),
    "brass":         ((186, 138, 52),  0.72, 22.0, 0.30, (236, 204, 118)),
    "brass_dark":    ((128, 88,  32),  0.50, 16.0, 0.26, (186, 144, 68)),
    "wood":          ((142, 92,  48),  0.24, 10.0, 0.28, (186, 134, 84)),
    "rubber":        ((58,  60,  68),  0.18, 8.0,  0.25, (92,  98,  112)),
    "hazard_yel":    ((218, 170, 34),  0.28, 12.0, 0.34, (242, 214, 96)),
    "white_cloth":   ((228, 226, 220), 0.14, 6.0,  0.38, (216, 224, 234)),
    "dial_face":     ((236, 234, 222), 0.30, 14.0, 0.55, (245, 245, 240)),
    "led_green":     ((58,  204, 92),  0.60, 18.0, 0.65, (140, 244, 160)),
    "led_red":       ((224, 62,  42),  0.60, 18.0, 0.62, (250, 136, 108)),
    "led_amber":     ((236, 174, 42),  0.55, 16.0, 0.62, (250, 216, 110)),
    "feather_pink":  ((228, 144, 152), 0.20, 8.0,  0.42, (244, 194, 198)),
    "feather_cream": ((238, 224, 178), 0.20, 8.0,  0.44, (248, 240, 210)),
    "feather_teal":  ((92,  196, 192), 0.24, 8.0,  0.40, (164, 232, 228)),
    "skin":          ((218, 164, 136), 0.16, 8.0,  0.36, (238, 196, 172)),
    "skin_blush":    ((224, 132, 122), 0.16, 8.0,  0.36, (242, 170, 160)),
    "ochre_jacket":  ((186, 138, 44),  0.18, 8.0,  0.32, (226, 188, 92)),
    "jeans_blue":    ((86,  104, 138), 0.16, 8.0,  0.30, (132, 152, 188)),
    "skirt_blue":    ((94,  112, 144), 0.18, 8.0,  0.30, (144, 164, 198)),
    "hair_dark":     ((54,  40,  34),  0.30, 14.0, 0.24, (96,  76,  64)),
    "hair_blonde":   ((206, 166, 72),  0.32, 14.0, 0.34, (240, 214, 126)),
    "shoe_white":    ((204, 210, 216), 0.22, 10.0, 0.34, (228, 234, 240)),
    "hat_blue":      ((52,  106, 186), 0.30, 12.0, 0.32, (112, 164, 234)),
    "gold_star":     ((242, 206, 56),  0.65, 20.0, 0.58, (254, 242, 148)),
    "mouth_dark":    ((84,  28,  32),  0.08, 4.0,  0.22, (120, 48,  52)),
    "eye_dark":      ((26,  24,  30),  0.35, 16.0, 0.20, (70,  70,  84)),
    "teeth_white":   ((238, 238, 234), 0.25, 10.0, 0.55, (248, 248, 248)),
}


def _norm(v: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(v)
    return v / n if n > 1e-8 else v


KEY_LIGHT = _norm(np.array([-0.55, -0.62, 0.56], dtype=np.float32))
FILL_LIGHT = _norm(np.array([0.62, 0.32, 0.72], dtype=np.float32))
VIEW_DIR = np.array([0.0, 0.0, 1.0], dtype=np.float32)
KEY_HALF = _norm(KEY_LIGHT + VIEW_DIR)


def iso_pt(origin: Tuple[float, float], wx: float, wy: float, wz: float) -> Tuple[float, float, float]:
    ox, oy = origin
    sx = ox + (wx - wy)
    sy = oy + 0.5 * (wx + wy) - wz
    sz = (wx + wy) * 0.85 + wz * 0.22
    return (sx, sy, sz)


class BullfrogCanvas:
    """2x supersampled orthographic Z-buffered 3D sprite renderer."""

    def __init__(self, width: int, height: int, ss: int = 2) -> None:
        self.w = width
        self.h = height
        self.ss = ss
        self.sw = width * ss
        self.sh = height * ss
        self.zbuf = np.full((self.sh, self.sw), -1e9, dtype=np.float32)
        self.rgb = np.zeros((self.sh, self.sw, 3), dtype=np.float32)
        self.alpha = np.zeros((self.sh, self.sw), dtype=np.float32)
        self.shadow = np.zeros((self.sh, self.sw), dtype=np.float32)
        self.tag = np.zeros((self.sh, self.sw), dtype=np.int16)

    def _shade(self, nx, ny, nz, mat_name: str, color_override=None, stripe_mask=None):
        base, spec_s, shin, amb, rim = MATERIALS[mat_name]
        if color_override is not None:
            base = color_override
        bcol = np.array(base, dtype=np.float32)
        rcol = np.array(rim, dtype=np.float32)

        ndotl = np.clip(nx * KEY_LIGHT[0] + ny * KEY_LIGHT[1] + nz * KEY_LIGHT[2], -0.25, 1.0)
        diff_key = np.clip((ndotl + 0.18) / 1.18, 0.0, 1.0)
        ndotf = np.clip(nx * FILL_LIGHT[0] + ny * FILL_LIGHT[1] + nz * FILL_LIGHT[2], 0.0, 1.0)
        ndoth = np.clip(nx * KEY_HALF[0] + ny * KEY_HALF[1] + nz * KEY_HALF[2], 0.0, 1.0)
        spec = (ndoth ** shin) * spec_s
        rim_f = np.clip(1.0 - np.abs(nz), 0.0, 1.0) ** 2.2 * 0.22

        lit = amb + diff_key * (1.02 - amb) + ndotf * 0.18
        out = bcol[None, :] * lit[:, None] + rcol[None, :] * (spec[:, None] * 0.9 + rim_f[:, None])
        if stripe_mask is not None:
            dark = np.array((42, 44, 52), dtype=np.float32)
            out = np.where(stripe_mask[:, None], dark[None, :] * (amb + diff_key[:, None] * 0.7), out)
        return np.clip(out, 0.0, 255.0)

    def _bbox(self, x0: float, y0: float, x1: float, y1: float, pad: int = 2) -> Tuple[int, int, int, int]:
        ss = self.ss
        ix0 = max(0, int(math.floor(min(x0, x1) * ss)) - pad * ss)
        ix1 = min(self.sw, int(math.ceil(max(x0, x1) * ss)) + pad * ss)
        iy0 = max(0, int(math.floor(min(y0, y1) * ss)) - pad * ss)
        iy1 = min(self.sh, int(math.ceil(max(y0, y1) * ss)) + pad * ss)
        return ix0, iy0, ix1, iy1

    def add_floor_shadow_ellipse(self, cx: float, cy: float, rx: float, ry: float, strength: float = 0.45) -> None:
        ix0, iy0, ix1, iy1 = self._bbox(cx - rx, cy - ry, cx + rx, cy + ry, pad=1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        xs = (np.arange(ix0, ix1, dtype=np.float32) + 0.5) / self.ss
        ys = (np.arange(iy0, iy1, dtype=np.float32) + 0.5) / self.ss
        X, Y = np.meshgrid(xs, ys)
        d2 = ((X - cx) / max(rx, 0.5)) ** 2 + ((Y - cy) / max(ry, 0.5)) ** 2
        m = d2 <= 1.0
        fall = np.clip(np.maximum(0.0, 1.0 - d2) ** 0.75, 0.0, 1.0) * strength
        sub = self.shadow[iy0:iy1, ix0:ix1]
        self.shadow[iy0:iy1, ix0:ix1] = np.where(m, np.maximum(sub, fall), sub)

    def add_ellipsoid(self, center, radii, mat: str, rot_deg: float = 0.0, tag: int = 1,
                      color_override=None, squash_z: float = 1.0) -> None:
        cx, cy, cz = center
        rx, ry, rz = radii
        rmax = max(rx, ry) + 1.0
        ix0, iy0, ix1, iy1 = self._bbox(cx - rmax, cy - rmax, cx + rmax, cy + rmax, pad=1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        xs = (np.arange(ix0, ix1, dtype=np.float32) + 0.5) / self.ss - cx
        ys = (np.arange(iy0, iy1, dtype=np.float32) + 0.5) / self.ss - cy
        X, Y = np.meshgrid(xs, ys)
        if abs(rot_deg) > 1e-4:
            rad = math.radians(rot_deg)
            c, s = math.cos(rad), math.sin(rad)
            Xr = X * c + Y * s
            Yr = -X * s + Y * c
        else:
            Xr, Yr = X, Y
            c, s = 1.0, 0.0

        u = Xr / max(rx, 0.25)
        v = Yr / max(ry, 0.25)
        r2 = u * u + v * v
        mask = r2 <= 1.0
        if not np.any(mask):
            return
        w = np.sqrt(np.maximum(0.0, 1.0 - r2[mask]))
        zval = cz + w * rz * squash_z

        sub_z = self.zbuf[iy0:iy1, ix0:ix1]
        vis = np.zeros_like(mask)
        vis[mask] = zval > sub_z[mask]
        if not np.any(vis):
            return

        um = u[vis] / max(rx, 0.25)
        vm = v[vis] / max(ry, 0.25)
        wm = np.sqrt(np.maximum(1e-6, 1.0 - (u[vis] ** 2 + v[vis] ** 2))) / max(rz, 0.25)
        nx = um * c - vm * s
        ny = um * s + vm * c
        nz = wm
        inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
        nx *= inv
        ny *= inv
        nz *= inv

        cols = self._shade(nx, ny, nz, mat, color_override=color_override)
        zv_vis = cz + np.sqrt(np.maximum(0.0, 1.0 - (u[vis] ** 2 + v[vis] ** 2))) * rz * squash_z

        self.zbuf[iy0:iy1, ix0:ix1][vis] = zv_vis
        self.rgb[iy0:iy1, ix0:ix1][vis] = cols
        self.alpha[iy0:iy1, ix0:ix1][vis] = 1.0
        self.tag[iy0:iy1, ix0:ix1][vis] = tag

    def add_capsule(self, p0, p1, r0: float, r1=None, mat: str = "chrome", tag: int = 1,
                    ribbed: float = 0.0, stripes: float = 0.0, cap_ends: bool = True,
                    color_override=None) -> None:
        if r1 is None:
            r1 = r0
        x0, y0, z0 = p0
        x1, y1, z1 = p1
        rmax = max(r0, r1) + 1.5
        ix0, iy0, ix1, iy1 = self._bbox(min(x0, x1) - rmax, min(y0, y1) - rmax,
                                        max(x0, x1) + rmax, max(y0, y1) + rmax, pad=1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        xs = (np.arange(ix0, ix1, dtype=np.float32) + 0.5) / self.ss
        ys = (np.arange(iy0, iy1, dtype=np.float32) + 0.5) / self.ss
        X, Y = np.meshgrid(xs, ys)

        dx, dy = x1 - x0, y1 - y0
        seg2 = dx * dx + dy * dy
        if seg2 < 1e-6:
            self.add_ellipsoid(p0, (r0, r0, r0), mat, tag=tag, color_override=color_override)
            return
        seg_len = math.sqrt(seg2)
        ux, uy = dx / seg_len, dy / seg_len
        px_v, py_v = -uy, ux

        rx_ = X - x0
        ry_ = Y - y0
        t_raw = (rx_ * ux + ry_ * uy) / seg_len
        t = np.clip(t_raw, 0.0, 1.0) if cap_ends else t_raw
        cx = x0 + t * dx
        cy = y0 + t * dy
        cz = z0 + t * (z1 - z0)
        rad = r0 + t * (r1 - r0)
        if ribbed > 0:
            rad = rad * (1.0 + 0.14 * np.sin(t * ribbed * math.pi * 2.0))

        ex = X - cx
        ey = Y - cy
        d2 = ex * ex + ey * ey
        mask = (d2 <= rad * rad) if cap_ends else ((t_raw >= 0.0) & (t_raw <= 1.0) & (d2 <= rad * rad))
        if not np.any(mask):
            return

        r_m = np.maximum(rad[mask], 0.25)
        h_m = np.sqrt(np.maximum(0.0, r_m * r_m - d2[mask]))
        zval = cz[mask] + h_m

        sub_z = self.zbuf[iy0:iy1, ix0:ix1]
        vis = np.zeros_like(mask)
        vis[mask] = zval > sub_z[mask]
        if not np.any(vis):
            return

        r_v = np.maximum(rad[vis], 0.25)
        nx = ex[vis] / r_v
        ny = ey[vis] / r_v
        nz = np.sqrt(np.maximum(1e-6, 1.0 - np.clip((ex[vis] ** 2 + ey[vis] ** 2) / (r_v * r_v), 0.0, 0.999)))
        if ribbed > 0:
            rib_n = 0.28 * np.cos(t[vis] * ribbed * math.pi * 2.0)
            nx = nx + ux * rib_n
            ny = ny + uy * rib_n
            inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
            nx *= inv
            ny *= inv
            nz *= inv

        smask = None
        if stripes > 0:
            smask = ((t[vis] * stripes + (ex[vis] * px_v + ey[vis] * py_v) * 0.08) % 1.0) > 0.5

        cols = self._shade(nx, ny, nz, mat, color_override=color_override, stripe_mask=smask)
        zv_vis = cz[vis] + np.sqrt(np.maximum(0.0, r_v * r_v - d2[vis]))
        self.zbuf[iy0:iy1, ix0:ix1][vis] = zv_vis
        self.rgb[iy0:iy1, ix0:ix1][vis] = cols
        self.alpha[iy0:iy1, ix0:ix1][vis] = 1.0
        self.tag[iy0:iy1, ix0:ix1][vis] = tag

    def add_iso_box(self, origin, wx0, wy0, wz0, wx1, wy1, wz1, mat: str, tag: int = 1,
                    bevel: float = 1.2, top_mat=None, left_mat=None, right_mat=None,
                    stripes_face=None) -> None:
        t_mat = top_mat or mat
        l_mat = left_mat or mat
        r_mat = right_mat or mat

        def P(wx, wy, wz):
            return iso_pt(origin, wx, wy, wz)

        faces = [
            (P(wx0, wy0, wz1), P(wx1, wy0, wz1), P(wx1, wy1, wz1), P(wx0, wy1, wz1),
             _norm(np.array([0.0, -0.76, 0.65], dtype=np.float32)), t_mat, "top"),
            (P(wx0, wy1, wz1), P(wx1, wy1, wz1), P(wx1, wy1, wz0), P(wx0, wy1, wz0),
             _norm(np.array([-0.68, 0.36, 0.64], dtype=np.float32)), l_mat, "left"),
            (P(wx1, wy0, wz1), P(wx1, wy1, wz1), P(wx1, wy1, wz0), P(wx1, wy0, wz0),
             _norm(np.array([0.68, 0.36, 0.64], dtype=np.float32)), r_mat, "right"),
        ]
        for q0, q1, q2, q3, nvec, fmat, fname in faces:
            self.add_quad(q0, q1, q2, q3, nvec, fmat, tag=tag, bevel=bevel,
                          stripes=(stripes_face == fname))

    def add_quad(self, p0, p1, p2, p3, normal, mat: str, tag: int = 1, bevel: float = 1.0,
                 stripes: bool = False, color_override=None) -> None:
        pts = [p0, p1, p2, p3]
        xs_p = [p[0] for p in pts]
        ys_p = [p[1] for p in pts]
        ix0, iy0, ix1, iy1 = self._bbox(min(xs_p), min(ys_p), max(xs_p), max(ys_p), pad=1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        xs = (np.arange(ix0, ix1, dtype=np.float32) + 0.5) / self.ss
        ys = (np.arange(iy0, iy1, dtype=np.float32) + 0.5) / self.ss
        X, Y = np.meshgrid(xs, ys)

        tris = [(p0, p1, p2), (p0, p2, p3)]
        cx_q = sum(xs_p) * 0.25
        cy_q = sum(ys_p) * 0.25
        w_q = max(1.0, max(xs_p) - min(xs_p))
        h_q = max(1.0, max(ys_p) - min(ys_p))

        for a, b, c in tris:
            ax, ay, az = a
            bx, by, bz = b
            cx_, cy_, cz = c
            denom = (by - cy_) * (ax - cx_) + (cx_ - bx) * (ay - cy_)
            if abs(denom) < 1e-6:
                continue
            w1 = ((by - cy_) * (X - cx_) + (cx_ - bx) * (Y - cy_)) / denom
            w2 = ((cy_ - ay) * (X - cx_) + (ax - cx_) * (Y - cy_)) / denom
            w3 = 1.0 - w1 - w2
            mask = (w1 >= -0.002) & (w2 >= -0.002) & (w3 >= -0.002)
            if not np.any(mask):
                continue
            zval = w1[mask] * az + w2[mask] * bz + w3[mask] * cz
            sub_z = self.zbuf[iy0:iy1, ix0:ix1]
            vis = np.zeros_like(mask)
            vis[mask] = zval > sub_z[mask]
            if not np.any(vis):
                continue

            dx_c = (X[vis] - cx_q) / (w_q * 0.55)
            dy_c = (Y[vis] - cy_q) / (h_q * 0.55)
            bv = 0.16 * bevel
            nx = normal[0] + dx_c * bv
            ny = normal[1] + dy_c * bv
            nz = np.full_like(nx, normal[2])
            inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
            nx *= inv
            ny *= inv
            nz *= inv

            smask = None
            if stripes:
                smask = (((X[vis] - min(xs_p)) * 0.22 + (Y[vis] - min(ys_p)) * 0.22) % 1.0) > 0.52

            cols = self._shade(nx, ny, nz, mat, color_override=color_override, stripe_mask=smask)
            zv_vis = w1[vis] * az + w2[vis] * bz + w3[vis] * cz
            self.zbuf[iy0:iy1, ix0:ix1][vis] = zv_vis
            self.rgb[iy0:iy1, ix0:ix1][vis] = cols
            self.alpha[iy0:iy1, ix0:ix1][vis] = 1.0
            self.tag[iy0:iy1, ix0:ix1][vis] = tag

    def add_iso_cylinder(self, origin, wx, wy, wz0, wz1, radius, mat: str, tag: int = 1,
                         top_mat=None, color_override=None) -> None:
        p0 = iso_pt(origin, wx, wy, wz0)
        p1 = iso_pt(origin, wx, wy, wz1)
        self.add_capsule(p0, p1, radius, radius, mat=mat, tag=tag, cap_ends=False, color_override=color_override)
        self.add_ellipsoid(p0, (radius, radius * 0.5, radius * 0.4), mat, tag=tag, color_override=color_override)
        self.add_ellipsoid((p1[0], p1[1], p1[2] + 0.5), (radius, radius * 0.52, radius * 0.22),
                           top_mat or mat, tag=tag, color_override=color_override)

    def add_gauge_dial(self, center, radius: float, needle_angle_deg: float = -35.0, tag: int = 1) -> None:
        cx, cy, cz = center
        self.add_ellipsoid((cx - 1.5, cy - 0.8, cz - 2.0), (radius + 1.8, radius + 1.4, radius * 0.8),
                           "chrome", tag=tag)
        self.add_ellipsoid((cx, cy, cz), (radius + 1.3, radius + 1.1, radius * 0.6), "chrome_dark", tag=tag)
        self.add_ellipsoid((cx + 0.4, cy + 0.2, cz + 1.6), (radius, radius * 0.92, 1.2), "dial_face", tag=tag)
        for deg in range(-135, -35, 18):
            rad = math.radians(deg)
            gx = cx + 0.4 + math.cos(rad) * radius * 0.66
            gy = cy + 0.2 + math.sin(rad) * radius * 0.60
            self.add_ellipsoid((gx, gy, cz + 2.8), (1.1, 1.0, 0.8), "led_green", tag=tag)
        for deg in range(-30, 35, 18):
            rad = math.radians(deg)
            gx = cx + 0.4 + math.cos(rad) * radius * 0.66
            gy = cy + 0.2 + math.sin(rad) * radius * 0.60
            self.add_ellipsoid((gx, gy, cz + 2.8), (1.1, 1.0, 0.8), "led_red", tag=tag)
        nr = math.radians(needle_angle_deg)
        nx_end = cx + 0.4 + math.cos(nr) * radius * 0.72
        ny_end = cy + 0.2 + math.sin(nr) * radius * 0.65
        self.add_capsule((cx + 0.4, cy + 0.2, cz + 3.4), (nx_end, ny_end, cz + 3.5), 0.7, 0.45,
                         mat="eye_dark", tag=tag)
        self.add_ellipsoid((cx + 0.4, cy + 0.2, cz + 3.8), (1.2, 1.2, 0.8), "brass", tag=tag)

    def finalize(self, quantize_to_th: bool = True, dither_strength: float = 9.0,
                 char_outline: bool = True, machine_soft_rim: bool = True) -> Image.Image:
        ss = self.ss
        h, w = self.h, self.w

        a_blk = self.alpha.reshape(h, ss, w, ss)
        opaque = a_blk.mean(axis=(1, 3)) >= 0.48
        w_sum = np.maximum(a_blk.sum(axis=(1, 3)), 1e-6)
        rgb_blk = (self.rgb * self.alpha[:, :, None]).reshape(h, ss, w, ss, 3)
        rgb_1x = rgb_blk.sum(axis=(1, 3)) / w_sum[:, :, None]

        z_1x = self.zbuf.reshape(h, ss, w, ss).max(axis=(1, 3))
        tag_1x = self.tag.reshape(h, ss, w, ss).max(axis=(1, 3))
        shad_1x = self.shadow.reshape(h, ss, w, ss).mean(axis=(1, 3))

        z_pad = np.pad(z_1x, 1, mode="edge")
        op_pad = np.pad(opaque, 1, mode="constant", constant_values=False)
        occ = np.zeros((h, w), dtype=np.float32)
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1)]:
            nz = z_pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
            nop = op_pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
            dz = np.where(nop & opaque, np.clip((nz - z_1x - 1.5) / 10.0, 0.0, 1.0), 0.0)
            occ += dz
        rgb_1x *= (1.0 - np.clip(occ * 0.11, 0.0, 0.34))[:, :, None]

        neigh_empty = (
            (~op_pad[:-2, 1:-1]) | (~op_pad[2:, 1:-1]) |
            (~op_pad[1:-1, :-2]) | (~op_pad[1:-1, 2:])
        )
        if machine_soft_rim:
            m_edge = opaque & (tag_1x == 1) & neigh_empty
            rgb_1x[m_edge] *= 0.70

        out_opaque = opaque.copy()
        if char_outline:
            c_mask = opaque & (tag_1x == 2)
            c_pad = np.pad(c_mask, 1, mode="constant", constant_values=False)
            c_dil = (
                c_pad[:-2, 1:-1] | c_pad[2:, 1:-1] |
                c_pad[1:-1, :-2] | c_pad[1:-1, 2:]
            )
            c_out = c_dil & (~opaque)
            rgb_1x[c_out] = np.array([28.0, 26.0, 34.0], dtype=np.float32)
            out_opaque |= c_out

        bayer_grid = np.tile(BAYER2, (h // 2 + 1, w // 2 + 1))[:h, :w]
        if np.any(shad_1x > 0.05):
            shad_pix = (~out_opaque) & (shad_1x > (0.36 + bayer_grid * 0.45))
            rgb_1x[shad_pix] = np.array([64.0, 62.0, 88.0], dtype=np.float32)
            out_opaque |= shad_pix

        rgb_1x = np.clip(rgb_1x, 0.0, 255.0)

        if quantize_to_th:
            ys, xs = np.nonzero(out_opaque)
            if len(ys) > 0:
                pix = np.clip(rgb_1x[ys, xs] + (bayer_grid[ys, xs] * dither_strength)[:, None], 0.0, 255.0)
                w_rgb = np.array([2.0, 4.0, 3.0], dtype=np.float32)
                matched = np.empty_like(pix)
                chunk = 2048
                for i in range(0, len(pix), chunk):
                    p_sub = pix[i:i + chunk]
                    diff = p_sub[:, None, :] - TH_PALETTE[None, :, :]
                    dist = (diff * diff * w_rgb[None, None, :]).sum(axis=2)
                    matched[i:i + chunk] = TH_PALETTE[np.argmin(dist, axis=1)]
                rgb_1x[ys, xs] = matched

        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[out_opaque, :3] = np.clip(np.round(rgb_1x[out_opaque]), 0, 255).astype(np.uint8)
        out[out_opaque, 3] = 255
        return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------------------
# Compact retro pixel text helper (for HA! / HEE! / HO! pops)
# ---------------------------------------------------------------------------
FONT_3X5 = {
    "H": ["101", "101", "111", "101", "101"],
    "A": ["010", "101", "111", "101", "101"],
    "E": ["111", "100", "110", "100", "111"],
    "O": ["010", "101", "101", "101", "010"],
    "!": ["1", "1", "1", "0", "1"],
}


def stamp_laugh_pop(img: Image.Image, cx: int, cy: int, text: str) -> None:
    """Compact Bullfrog-style retro comic pop tag quantized to MPalette tones."""
    bg_col = (247, 239, 207)
    fg_col = (186, 56, 4)
    rim_col = (113, 36, 52)
    d = ImageDraw.Draw(img)
    widths = [len(FONT_3X5[ch][0]) for ch in text]
    tw = sum(widths) + (len(text) - 1)
    pad_x, pad_y = 3, 2
    bw = tw + pad_x * 2
    bh = 5 + pad_y * 2
    x0 = int(cx - bw // 2)
    y0 = int(cy - bh // 2)
    d.rounded_rectangle([x0, y0, x0 + bw - 1, y0 + bh - 1], radius=2,
                        fill=bg_col + (255,), outline=rim_col + (255,))
    d.polygon([(cx - 2, y0 + bh - 1), (cx + 2, y0 + bh - 1), (cx, y0 + bh + 2)], fill=bg_col + (255,))
    d.line([(cx - 2, y0 + bh), (cx, y0 + bh + 2), (cx + 2, y0 + bh)], fill=rim_col + (255,))
    cur_x = x0 + pad_x
    for ch in text:
        rows = FONT_3X5[ch]
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == "1":
                    img.putpixel((cur_x + rx, y0 + pad_y + ry), fg_col + (255,))
        cur_x += len(rows[0]) + 1


# ---------------------------------------------------------------------------
# 1. QUOIGING CHAIR (112 x 108, floor center (56, 90), offset {-56, -78})
# ---------------------------------------------------------------------------
def build_quoiging_chair(active: bool = False) -> Image.Image:
    c = BullfrogCanvas(112, 108, ss=2)
    org = (56.0, 90.0)

    c.add_floor_shadow_ellipse(56, 90, 26, 13, strength=0.52)
    c.add_floor_shadow_ellipse(41, 83, 12, 6, strength=0.40)

    foot_coords = [(-16, 12), (16, 12), (14, -14), (-14, -14)]
    hub_bot = iso_pt(org, 0, 0, 5)
    for fx, fy in foot_coords:
        fp = iso_pt(org, fx, fy, 2)
        c.add_capsule(hub_bot, fp, 2.0, 1.7, mat="chrome", tag=1)
        c.add_ellipsoid(iso_pt(org, fx, fy, 1.2), (2.2, 1.8, 1.8), "rubber", tag=1)
        c.add_ellipsoid(iso_pt(org, fx, fy, 2.5), (1.8, 1.2, 1.2), "chrome_dark", tag=1)

    c.add_iso_cylinder(org, 0, 0, 3, 13, 6.2, mat="enamel_cool", top_mat="chrome", tag=1)
    c.add_iso_cylinder(org, 0, 0, 12, 19, 3.8, mat="chrome", top_mat="chrome", tag=1)
    c.add_capsule(iso_pt(org, 3, 2, 7), iso_pt(org, 13, 5, 5), 1.3, 1.2, mat="brass", tag=1)
    c.add_ellipsoid(iso_pt(org, 14, 5.5, 5), (2.8, 1.5, 1.1), "rubber", tag=1)

    tank_wx, tank_wy = -17.0, 2.0
    c.add_iso_cylinder(org, tank_wx, tank_wy, 4, 24, 6.4, mat="teal", top_mat="chrome", tag=1)
    c.add_ellipsoid(iso_pt(org, tank_wx, tank_wy, 24), (6.5, 3.4, 2.0), "chrome", tag=1)
    c.add_ellipsoid(iso_pt(org, tank_wx, tank_wy, 13), (6.6, 3.3, 1.2), "chrome_dark", tag=1)
    c.add_iso_cylinder(org, tank_wx, tank_wy, 24, 29, 2.2, mat="brass", top_mat="brass", tag=1)
    hose_pts = [
        iso_pt(org, tank_wx + 4, tank_wy, 21),
        iso_pt(org, tank_wx + 7, tank_wy - 2, 16),
        iso_pt(org, tank_wx + 10, tank_wy - 4, 18),
        iso_pt(org, -7, -4, 23),
    ]
    for i in range(len(hose_pts) - 1):
        c.add_capsule(hose_pts[i], hose_pts[i + 1], 1.9, 1.9, mat="leather_red", ribbed=4.0, tag=1)

    c.add_capsule(iso_pt(org, tank_wx, tank_wy, 28), iso_pt(org, tank_wx - 4.5, tank_wy + 1.0, 42),
                  1.5, 1.3, mat="chrome", tag=1)
    dial_c = iso_pt(org, tank_wx - 4.5, tank_wy + 1.0, 47)
    c.add_gauge_dial(dial_c, radius=7.4, needle_angle_deg=(12.0 if active else -112.0), tag=1)
    c.add_ellipsoid((dial_c[0], dial_c[1] - 8.8, dial_c[2] + 1.0), (2.2, 1.8, 1.8),
                    "led_green" if active else "led_amber", tag=1)

    c.add_iso_box(org, -11, -11, 18, 12, 11, 23, mat="enamel", top_mat="enamel", tag=1, bevel=1.3)
    c.add_iso_box(org, -9.5, -9.5, 22, 10.5, 9.5, 26.5, mat="leather_red", tag=1, bevel=1.6)
    c.add_capsule(iso_pt(org, 10.5, -8, 24.5), iso_pt(org, 10.5, 8.5, 24.5), 2.7, 2.7, mat="leather_red", tag=1)

    c.add_capsule(iso_pt(org, 10, -5, 20), iso_pt(org, 17, -5, 10), 1.4, 1.3, mat="chrome", tag=1)
    c.add_capsule(iso_pt(org, 10, 5, 20), iso_pt(org, 17, 5, 10), 1.4, 1.3, mat="chrome", tag=1)
    c.add_iso_box(org, 14, -7, 8.5, 20, 7, 10.5, mat="chrome_dark", top_mat="rubber", tag=1, bevel=0.8)

    c.add_iso_box(org, -13, -11, 22, -8, 11, 52, mat="enamel", tag=1, bevel=1.4)
    c.add_capsule(iso_pt(org, -9.5, -11.5, 22), iso_pt(org, -9.5, -11.5, 52), 1.6, 1.5, mat="chrome", tag=1)
    c.add_capsule(iso_pt(org, -9.5, 11.5, 22), iso_pt(org, -9.5, 11.5, 52), 1.6, 1.5, mat="chrome", tag=1)
    c.add_iso_box(org, -8.5, -9, 25, -5.5, 9, 50, mat="teal", tag=1, bevel=1.8)
    for wy_r in [-4.5, 0.0, 4.5]:
        c.add_capsule(iso_pt(org, -5.5, wy_r, 27), iso_pt(org, -5.5, wy_r, 48), 1.1, 1.1, mat="teal_dark", tag=1)
    c.add_capsule(iso_pt(org, -9.5, -7, 53.5), iso_pt(org, -9.5, 7, 53.5), 4.2, 4.2, mat="leather_red", tag=1)
    c.add_ellipsoid(iso_pt(org, -10.0, 0, 56.5), (5.5, 2.8, 3.0), "chrome", tag=1)

    for side_wy in [-11.5, 11.5]:
        c.add_capsule(iso_pt(org, 4, side_wy, 21), iso_pt(org, 4, side_wy, 31), 1.4, 1.4, mat="chrome", tag=1)
        c.add_capsule(iso_pt(org, -8, side_wy, 31), iso_pt(org, 9, side_wy, 31), 2.4, 2.2, mat="leather_red", tag=1)

    q_wx, q_wy = -6.0, 14.5
    c.add_iso_cylinder(org, q_wx, q_wy, 23, 33, 3.2, mat="brass", top_mat="brass_dark", tag=1)
    feathers = [
        (0, -1, 33, -4, 3, 45, "feather_pink"),
        (1, 0, 33, 2, 2, 46, "feather_cream"),
        (-1, 1, 33, -1, 5, 43, "feather_teal"),
    ]
    for dx0, dy0, z0, dx1, dy1, z1, fmat in feathers:
        p0 = iso_pt(org, q_wx + dx0, q_wy + dy0, z0)
        p1 = iso_pt(org, q_wx + dx1, q_wy + dy1, z1)
        c.add_capsule(p0, p1, 0.8, 0.6, mat="white_cloth", tag=1)
        c.add_ellipsoid(p1, (3.2, 2.1, 2.2), fmat, rot_deg=-25, tag=1)

    for side_sign, side_wy in [(-1, -13.0), (1, 13.0)]:
        shoulder = iso_pt(org, -10.5, side_wy, 42)
        c.add_ellipsoid(shoulder, (2.6, 2.4, 2.4), "brass", tag=1)
        if active:
            elbow = iso_pt(org, -4.0, side_wy + side_sign * 4.5, 50)
            wrist = iso_pt(org, 4.0, side_wy + side_sign * 1.5, 45)
        else:
            elbow = iso_pt(org, -13.5, side_wy + side_sign * 3.5, 47)
            wrist = iso_pt(org, -9.5, side_wy + side_sign * 4.5, 37)
        c.add_capsule(shoulder, elbow, 1.5, 1.3, mat="chrome", tag=1)
        c.add_ellipsoid(elbow, (2.0, 2.0, 2.0), "brass", tag=1)
        c.add_capsule(elbow, wrist, 1.3, 1.1, mat="chrome", tag=1)
        if not active:
            c.add_ellipsoid(wrist, (3.6, 3.0, 3.0), "glove_red", tag=1)

    return c.finalize(quantize_to_th=True, dither_strength=9.0, char_outline=False, machine_soft_rim=True)


# ---------------------------------------------------------------------------
# 2. QUOIGING RED HANDS TICKLE + LAUGHING OVERLAY (96 x 96, 4 frames)
# ---------------------------------------------------------------------------
def draw_big_red_glove(c: BullfrogCanvas, cx: float, cy: float, cz: float,
                       flip_x: float = 1.0, tilt_deg: float = 0.0, finger_phase: float = 0.0) -> None:
    rad = math.radians(tilt_deg)
    ca, sa = math.cos(rad), math.sin(rad)

    def pt(lx: float, ly: float, lz: float = 0.0) -> Tuple[float, float, float]:
        x_ = lx * flip_x
        rx = x_ * ca - ly * sa
        ry = x_ * sa + ly * ca
        return (cx + rx, cy + ry, cz + lz)

    c.add_capsule(pt(-13.5, -1.5, -1.0), pt(-13.5, 2.0, -1.0), 4.6, 4.4, mat="white_cloth", tag=2)
    c.add_capsule(pt(-9.5, -0.5, -0.2), pt(-9.5, 1.2, -0.2), 4.8, 4.7, mat="crimson_dark", tag=2)
    c.add_ellipsoid(pt(-1.5, 0.5, 1.0), (8.2, 6.4, 5.5), "glove_red", rot_deg=tilt_deg * flip_x, tag=2)
    c.add_capsule(pt(-2.5, -4.5, 2.0), pt(3.0, -8.5 + math.sin(finger_phase) * 1.4, 3.5),
                  3.2, 2.6, mat="glove_red", tag=2)

    for i, fy in enumerate([-4.6, -1.6, 1.5, 4.4]):
        wig = math.sin(finger_phase + i * 1.15) * 2.2
        c.add_capsule(pt(4.5, fy, 1.5), pt(10.8 + abs(wig) * 0.4, fy + wig, 2.8),
                      2.2, 1.7, mat="glove_red", tag=2)

    f_base = pt(6.5, -3.5, 3.0)
    f_mid = pt(12.5, -6.5 + math.sin(finger_phase) * 1.8, 4.2)
    f_tip = pt(16.5, -9.2 + math.cos(finger_phase) * 2.0, 4.8)
    c.add_capsule(f_base, f_tip, 0.7, 0.4, mat="white_cloth", tag=2)
    c.add_ellipsoid(f_mid, (3.6, 1.8, 1.8), "feather_pink", rot_deg=-25 * flip_x, tag=2)
    c.add_ellipsoid(f_tip, (3.2, 1.6, 1.6), "feather_cream", rot_deg=-30 * flip_x, tag=2)


def build_quoiging_tickle_frames() -> List[Image.Image]:
    frames: List[Image.Image] = []
    pops = [(56, 32, "HA!"), (38, 28, "HEE!"), (58, 30, "HA!"), (40, 32, "HO!")]
    for frame_idx in range(4):
        c = BullfrogCanvas(96, 96, ss=2)
        phase = (frame_idx / 4.0) * math.pi * 2.0
        osc_x = math.sin(phase) * 4.2
        osc_y = math.cos(phase * 2.0) * 2.5

        draw_big_red_glove(c, 27.5 + osc_x, 75.5 + osc_y, 20.0,
                           flip_x=1.0, tilt_deg=-8.0 + math.sin(phase) * 14.0, finger_phase=phase)
        draw_big_red_glove(c, 67.5 - osc_x, 76.0 - osc_y, 22.0,
                           flip_x=-1.0, tilt_deg=8.0 - math.sin(phase) * 14.0, finger_phase=phase + 1.8)

        head_x = 47.0 + math.sin(phase) * 0.9
        head_y = 61.5 + abs(math.cos(phase)) * 0.8
        c.add_ellipsoid((head_x - 3.0, head_y + 1.0, 28.0), (1.3, 1.0, 0.9), "skin_blush", tag=3)
        c.add_ellipsoid((head_x + 3.0, head_y + 1.0, 28.0), (1.3, 1.0, 0.9), "skin_blush", tag=3)
        c.add_ellipsoid((head_x, head_y + 2.6, 29.0), (2.2, 1.5 + 0.35 * math.sin(phase), 1.3), "mouth_dark", tag=3)
        c.add_ellipsoid((head_x, head_y + 1.9, 30.0), (1.7, 0.6, 1.0), "teeth_white", tag=3)

        tear_t = frame_idx % 4
        c.add_ellipsoid((head_x - 6.8 - tear_t * 1.1, head_y - 3.5 - (tear_t % 2) * 1.5, 30.0),
                        (1.2, 0.9, 1.0), "feather_teal", rot_deg=-30, tag=3)
        c.add_ellipsoid((head_x + 6.8 + tear_t * 1.1, head_y - 4.0 - ((tear_t + 1) % 2) * 1.5, 30.0),
                        (1.2, 0.9, 1.0), "feather_teal", rot_deg=30, tag=3)

        for side in (-1, 1):
            ax = 47.0 + side * (7.5 + (frame_idx % 2) * 2.4)
            ay = 72.0 + (frame_idx % 2) * 2.0
            c.add_ellipsoid((ax, ay, 26.0), (1.3, 1.3, 1.0), "gold_star", tag=3)

        img = c.finalize(quantize_to_th=True, dither_strength=8.0, char_outline=True, machine_soft_rim=False)
        px, py, ptxt = pops[frame_idx]
        stamp_laugh_pop(img, px, py, ptxt)
        frames.append(img)
    return frames


# ---------------------------------------------------------------------------
# 3. DOCTOR SILLY HAT (48 x 48, 4 frames)
# ---------------------------------------------------------------------------
def build_silly_hat_frames() -> List[Image.Image]:
    frames: List[Image.Image] = []
    for frame_idx in range(4):
        c = BullfrogCanvas(48, 48, ss=2)
        cx, cy = 24.0, 37.0

        c.add_ellipsoid((cx, cy - 1.5, 10.0), (7.2, 4.8, 5.5), "hat_blue", tag=2)
        c.add_ellipsoid((cx - 3.6, cy - 1.4, 11.2), (4.2, 4.0, 4.5), "glove_red", tag=2)
        c.add_ellipsoid((cx + 3.6, cy - 1.4, 11.2), (4.2, 4.0, 4.5), "teal", tag=2)
        c.add_capsule((cx - 6.8, cy + 1.0, 13.5), (cx + 6.8, cy + 1.0, 13.5), 1.6, 1.6, mat="brass", tag=2)

        bob = math.sin(frame_idx * math.pi * 0.5) * 1.1
        c.add_capsule((cx - 5.8, cy - 1.2, 11.0), (cx - 10.2, cy - 4.5 + bob, 11.5), 1.8, 1.1, mat="glove_red", tag=2)
        c.add_ellipsoid((cx - 10.8, cy - 4.8 + bob, 12.2), (1.7, 1.7, 1.6), "gold_star", tag=2)

        c.add_capsule((cx + 5.8, cy - 1.2, 11.0), (cx + 10.2, cy - 4.5 - bob, 11.5), 1.8, 1.1, mat="teal", tag=2)
        c.add_ellipsoid((cx + 10.8, cy - 4.8 - bob, 12.2), (1.7, 1.7, 1.6), "gold_star", tag=2)

        c.add_capsule((cx, cy - 5.5, 12.5), (cx, cy - 8.6, 13.0), 1.1, 1.0, mat="chrome", tag=2)
        c.add_ellipsoid((cx, cy - 9.0, 14.5), (1.7, 1.3, 1.4), "brass", tag=2)
        ang = frame_idx * (math.pi / 4.0)
        bx = math.cos(ang) * 7.2
        by = math.sin(ang) * 2.0
        c.add_capsule((cx - bx, cy - 9.0 - by, 14.0), (cx + bx, cy - 9.0 + by, 14.0), 1.3, 1.3,
                      mat="chrome" if frame_idx % 2 == 0 else "hazard_yel", tag=2)

        frames.append(c.finalize(quantize_to_th=True, dither_strength=6.0, char_outline=True, machine_soft_rim=False))
    return frames


# ---------------------------------------------------------------------------
# 4. UP-DOWN RIG GANTRY (160 x 144, offset {-64, -96} on {0,0})
# ---------------------------------------------------------------------------
def build_up_down_rig(active: bool = False) -> Image.Image:
    c = BullfrogCanvas(160, 144, ss=2)
    org0 = (64.0, 112.0)
    org1 = (96.0, 128.0)

    c.add_floor_shadow_ellipse(63, 114, 28, 14, strength=0.52)
    c.add_floor_shadow_ellipse(96, 129, 25, 12.5, strength=0.45)

    c.add_iso_box(org1, -17, -17, 0, 17, 17, 2.2, mat="steel_dark", top_mat="chrome_dark", tag=1, bevel=0.9)
    c.add_iso_box(org1, -14, -14, 2.0, 14, 14, 3.2, mat="rubber", top_mat="rubber", tag=1, bevel=0.6)
    c.add_ellipsoid(iso_pt(org1, 0, 0, 3.3), (12.5, 6.2, 0.8), "steel", tag=1)
    c.add_ellipsoid(iso_pt(org1, 0, 0, 3.6), (9.5, 4.7, 0.8), "teal_dark" if not active else "teal", tag=1)
    for cx_t, cy_t in [(-15, -15), (15, -15), (15, 15), (-15, 15)]:
        c.add_ellipsoid(iso_pt(org1, cx_t, cy_t, 2.8), (2.4, 1.3, 0.8), "hazard_yel", tag=1)

    c.add_iso_box(org0, -18, -16, 0, 18, 16, 6, mat="steel_dark", top_mat="steel", tag=1, bevel=1.0)
    c.add_iso_box(org0, -15, -13, 6, 14, 13, 38, mat="enamel", top_mat="enamel_cool", tag=1, bevel=1.3)
    c.add_iso_box(org0, -13, 12.2, 8, 11, 13.6, 15, mat="hazard_yel", tag=1, bevel=0.5, stripes_face="left")
    c.add_iso_box(org0, -11, 12.4, 18, 10, 13.8, 34, mat="steel_dark", tag=1, bevel=0.6)
    c.add_ellipsoid(iso_pt(org0, -6, 14.0, 29), (2.0, 1.8, 1.2), "led_green" if active else "led_amber", tag=1)
    c.add_ellipsoid(iso_pt(org0, -1, 14.0, 29), (1.7, 1.5, 1.1), "led_red" if active else "steel", tag=1)
    c.add_ellipsoid(iso_pt(org0, 4, 14.0, 29), (1.7, 1.5, 1.1), "teal", tag=1)
    c.add_gauge_dial(iso_pt(org0, 2, 14.5, 22), radius=4.6, needle_angle_deg=(20.0 if active else -110.0), tag=1)

    c.add_iso_cylinder(org0, 15, -8, 6, 30, 5.4, mat="teal", top_mat="chrome", tag=1)
    c.add_ellipsoid(iso_pt(org0, 15, -8, 30), (5.5, 2.8, 1.6), "chrome", tag=1)
    c.add_ellipsoid(iso_pt(org0, 15, -8, 18), (5.6, 2.8, 1.0), "chrome_dark", tag=1)
    c.add_capsule(iso_pt(org0, 15, -8, 31), iso_pt(org0, 1, -7, 41), 1.7, 1.7, mat="leather_red", ribbed=4.5, tag=1)

    lev_base = iso_pt(org0, -4, 9, 38)
    lev_tip = iso_pt(org0, -6, 15 if active else 7, 49 if active else 47)
    c.add_capsule(lev_base, lev_tip, 1.4, 1.1, mat="chrome", tag=1)
    c.add_ellipsoid(lev_tip, (2.8, 2.6, 2.6), "glove_red", tag=1)

    mast_x, mast_y = -6.0, -7.0
    c.add_iso_box(org0, mast_x - 5, mast_y - 5, 36, mast_x + 5, mast_y + 5, 96,
                  mat="steel", top_mat="chrome", tag=1, bevel=1.1)
    c.add_capsule(iso_pt(org0, mast_x + 5.5, mast_y + 3, 37), iso_pt(org0, mast_x + 5.5, mast_y + 3, 94),
                  1.7, 1.7, mat="chrome", tag=1)
    c.add_capsule(iso_pt(org0, mast_x - 5.5, mast_y + 3, 37), iso_pt(org0, mast_x - 5.5, mast_y + 3, 94),
                  1.7, 1.7, mat="chrome", tag=1)
    c.add_capsule(iso_pt(org0, 7, 2, 37), iso_pt(org0, mast_x + 3, mast_y + 3, 72),
                  2.4, 2.1, mat="chrome_dark", tag=1)

    pivot_p = iso_pt(org0, mast_x, mast_y, 96)
    c.add_iso_box(org0, mast_x - 7, mast_y - 7, 92, mast_x + 7, mast_y + 7, 104,
                  mat="enamel_cool", top_mat="chrome", tag=1, bevel=1.2)
    c.add_ellipsoid(iso_pt(org0, mast_x, mast_y, 106), (3.8, 3.0, 3.0),
                    "led_red" if active else "led_amber", tag=1)
    c.add_ellipsoid(iso_pt(org0, mast_x - 7, mast_y + 2, 98), (4.5, 4.8, 4.5), "brass", tag=1)

    boom_start = (pivot_p[0] + 2.0, pivot_p[1] - 1.0, pivot_p[2] + 4.0)
    pulley_top = (96.0, 14.0, pivot_p[2] + 18.0)
    c.add_capsule((boom_start[0], boom_start[1] - 4.0, boom_start[2]),
                  (pulley_top[0] + 2.0, pulley_top[1] - 4.0, pulley_top[2]), 3.2, 2.8, mat="steel", tag=1)
    c.add_capsule((boom_start[0], boom_start[1] + 2.5, boom_start[2]),
                  (pulley_top[0], pulley_top[1] + 1.5, pulley_top[2]), 2.5, 2.2, mat="chrome_dark", tag=1)
    c.add_capsule((boom_start[0] + 5.0, boom_start[1] - 1.0, boom_start[2] + 2.5),
                  (pulley_top[0] - 6.0, pulley_top[1] - 1.2, pulley_top[2] + 1.5),
                  3.2, 2.9, mat="hazard_yel", stripes=5.5, tag=1)
    c.add_capsule(iso_pt(org0, mast_x + 4, mast_y + 2, 74), (78.0, 18.0, pivot_p[2] + 12.0),
                  2.2, 1.8, mat="chrome", tag=1)

    c.add_ellipsoid((96.0, 15.0, pulley_top[2] + 4.0), (5.2, 5.2, 4.5), "chrome", tag=1)
    c.add_ellipsoid((96.0, 15.5, pulley_top[2] + 6.5), (2.4, 2.4, 2.4), "brass", tag=1)

    if not active:
        cable_bot = (96.0, 35.0, pulley_top[2] + 2.0)
        c.add_capsule((96.0, 17.0, pulley_top[2] + 2.0), cable_bot, 1.2, 1.2, mat="steel_dark", tag=1)
        c.add_ellipsoid((96.0, 36.0, pulley_top[2] + 4.0), (4.2, 3.0, 3.0), "brass", tag=1)
        c.add_capsule((94.0, 37.5, pulley_top[2] + 4.0), (88.5, 44.0, pulley_top[2] + 4.5), 2.1, 1.8, mat="glove_red", tag=1)
        c.add_capsule((88.5, 44.0, pulley_top[2] + 4.5), (92.0, 49.0, pulley_top[2] + 4.5), 1.8, 1.5, mat="chrome", tag=1)
        c.add_capsule((98.0, 37.5, pulley_top[2] + 4.0), (103.5, 44.0, pulley_top[2] + 4.5), 2.1, 1.8, mat="glove_red", tag=1)
        c.add_capsule((103.5, 44.0, pulley_top[2] + 4.5), (100.0, 49.0, pulley_top[2] + 4.5), 1.8, 1.5, mat="chrome", tag=1)

    return c.finalize(quantize_to_th=True, dither_strength=9.0, char_outline=False, machine_soft_rim=True)


# ---------------------------------------------------------------------------
# 5. UP-DOWN ANKLE-GRAB + UPSIDE-DOWN PATIENT ANIMATIONS (96 x 112)
# ---------------------------------------------------------------------------
def draw_ankle_clamp(c: BullfrogCanvas, cx: float, cy: float, cz: float,
                     closed: bool = True, cable_top_x: float = 48.0) -> None:
    c.add_capsule((cable_top_x, 0.0, cz - 1.0), (cx, cy - 5.0, cz - 1.0), 1.25, 1.25, mat="steel_dark", tag=1)
    c.add_ellipsoid((cx, cy - 4.0, cz + 3.0), (4.2, 3.0, 3.0), "brass", tag=1)
    c.add_ellipsoid((cx, cy - 5.5, cz + 4.2), (2.2, 1.6, 1.6), "chrome", tag=1)
    spread = 4.6 if closed else 8.8
    inward = 2.0 if closed else 4.8
    for sgn in (-1.0, 1.0):
        j0 = (cx + sgn * 2.2, cy - 2.0, cz + 3.5)
        j1 = (cx + sgn * spread, cy + 2.8, cz + 4.5)
        j2 = (cx + sgn * inward, cy + 6.4, cz + 5.0)
        c.add_capsule(j0, j1, 2.0, 1.8, mat="glove_red", tag=1)
        c.add_capsule(j1, j2, 1.8, 1.5, mat="leather_red" if closed else "chrome", tag=1)


def draw_dizzy_stars(c: BullfrogCanvas, hx: float, hy: float, cz: float, phase: float) -> None:
    for i in range(3):
        a = phase + i * (2.0 * math.pi / 3.0)
        sx = hx + math.cos(a) * 11.5
        sy = hy + math.sin(a) * 4.2
        sz = cz + math.sin(a) * 6.0
        c.add_ellipsoid((sx, sy, sz), (2.1, 0.9, 1.2), "gold_star", tag=3)
        c.add_ellipsoid((sx, sy, sz), (0.9, 2.1, 1.2), "gold_star", tag=3)


def build_up_down_leg_grab_frames() -> List[Image.Image]:
    frames: List[Image.Image] = []
    for frame_idx in range(2):
        c = BullfrogCanvas(96, 112, ss=2)
        if frame_idx == 0:
            draw_ankle_clamp(c, 50.0, 91.0, 22.0, closed=False)
        else:
            draw_ankle_clamp(c, 50.0, 98.0, 22.0, closed=True)
            for sx, sy in [(41, 100), (59, 101), (43, 105), (57, 106)]:
                c.add_ellipsoid((sx, sy, 28.0), (1.3, 1.3, 1.0), "gold_star", tag=3)
        frames.append(c.finalize(quantize_to_th=True, dither_strength=8.0, char_outline=False, machine_soft_rim=True))
    return frames


def build_up_down_dangle_frames(female: bool = False) -> List[Image.Image]:
    configs = [
        (49.0, 34.0, -28.0, 0.75, 18.0, 0.0),
        (46.5, 29.0, -14.0, 0.95, 12.0, 1.5),
        (48.0, 32.0,   1.0, 0.85, -3.0, 3.1),
        (49.5, 29.0,  15.0, 0.95, -14.0, 4.7),
    ]
    jacket_mat = "ochre_jacket"
    lower_mat = "skirt_blue" if female else "jeans_blue"
    hair_mat = "hair_blonde" if female else "hair_dark"

    frames: List[Image.Image] = []
    for clamp_x, clamp_y, tilt_deg, knee_bend, arm_sw, star_ph in configs:
        c = BullfrogCanvas(96, 112, ss=2)
        rad = math.radians(tilt_deg)
        ca, sa = math.cos(rad), math.sin(rad)
        anchor_x, anchor_y, base_z = clamp_x, clamp_y + 4.0, 20.0

        def bp(lx: float, ly: float, lz: float = 0.0) -> Tuple[float, float, float]:
            rx = lx * ca - ly * sa
            ry = lx * sa + ly * ca
            return (anchor_x + rx, anchor_y + ry, base_z + lz)

        c.add_ellipsoid(bp(1.5, -5.5, 1.5), (3.8, 2.3, 2.2), "shoe_white", rot_deg=tilt_deg - 15, tag=2)
        c.add_ellipsoid(bp(3.0, -6.2, 2.2), (1.8, 1.2, 1.2), "jeans_blue", tag=2)
        c.add_capsule(bp(0.0, -2.5, 0.5), bp(0.5, 8.5, 0.8), 2.2, 2.7,
                      mat="skin" if female else lower_mat, tag=2)
        c.add_capsule(bp(0.5, 8.5, 0.8), bp(2.2, 19.5, 1.2), 2.8, 3.3,
                      mat="skin" if female else lower_mat, tag=2)

        hip_l = bp(-3.8, 19.5, 1.0)
        knee_l = bp(-8.8 - knee_bend * 1.5, 12.0, 2.2)
        foot_l = bp(-12.5, 18.5 + knee_bend * 2.5, 2.6)
        c.add_capsule(hip_l, knee_l, 3.1, 2.5, mat="skin" if female else lower_mat, tag=2)
        c.add_capsule(knee_l, foot_l, 2.4, 2.0, mat="skin" if female else lower_mat, tag=2)
        c.add_ellipsoid(bp(-14.2, 19.8 + knee_bend * 2.5, 3.0), (3.6, 2.2, 2.1),
                        "shoe_white", rot_deg=tilt_deg + 35, tag=2)

        if female:
            c.add_capsule(bp(-0.8, 15.0, 1.8), bp(-0.8, 24.5, 2.4), 6.2, 5.4, mat=lower_mat, tag=2)
        else:
            c.add_ellipsoid(bp(-0.8, 20.5, 1.6), (6.0, 4.4, 4.2), lower_mat, rot_deg=tilt_deg, tag=2)

        c.add_capsule(bp(-0.8, 24.5, 2.2), bp(-0.8, 37.5, 2.6), 5.6, 6.4, mat=jacket_mat, tag=2)
        c.add_capsule(bp(-0.6, 26.5, 5.8), bp(-0.6, 38.5, 6.2), 1.6 if female else 0.9, 1.8 if female else 0.9,
                      mat="white_cloth" if female else "brass_dark", tag=2)
        c.add_ellipsoid(bp(-3.6, 39.2, 5.0), (2.5, 1.8, 1.8), jacket_mat, tag=2)
        c.add_ellipsoid(bp(2.4, 39.2, 5.0), (2.5, 1.8, 1.8), jacket_mat, tag=2)

        for sgn, sh_x in [(-1.0, -6.5), (1.0, 5.0)]:
            sh = bp(sh_x, 36.0, 1.8)
            elb = bp(sh_x + sgn * 3.8 + arm_sw * 0.14, 45.0, 2.4)
            hand = bp(sh_x + sgn * 2.5 + arm_sw * 0.28, 53.0, 3.0)
            c.add_capsule(sh, elb, 2.5, 2.1, mat=jacket_mat, tag=2)
            c.add_capsule(elb, hand, 2.0, 1.7, mat=jacket_mat, tag=2)
            c.add_ellipsoid(hand, (2.2, 2.2, 2.0), "skin", tag=2)

        neck = bp(-0.8, 41.2, 2.4)
        head = bp(-0.8, 47.0, 3.0)
        c.add_capsule(neck, head, 2.3, 2.3, mat="skin", tag=2)
        c.add_ellipsoid(head, (5.6, 5.8, 5.4), "skin", rot_deg=tilt_deg, tag=2)

        if female:
            c.add_ellipsoid(bp(-0.8, 51.5, 2.6), (6.0, 4.4, 4.5), hair_mat, rot_deg=tilt_deg, tag=2)
            c.add_capsule(bp(-5.2, 47.0, 2.2), bp(-6.8 + arm_sw * 0.12, 56.5, 2.6), 2.5, 1.6, mat=hair_mat, tag=2)
            c.add_capsule(bp(3.6, 47.0, 2.2), bp(5.2 + arm_sw * 0.12, 56.5, 2.6), 2.5, 1.6, mat=hair_mat, tag=2)
            c.add_capsule(bp(-0.8, 52.0, 2.0), bp(-0.8 + arm_sw * 0.14, 58.2, 2.4), 3.4, 2.0, mat=hair_mat, tag=2)
        else:
            c.add_ellipsoid(bp(-0.8, 50.8, 3.2), (5.5, 3.2, 4.6), hair_mat, rot_deg=tilt_deg, tag=2)
            c.add_ellipsoid(bp(-4.6, 48.5, 2.8), (1.8, 2.6, 2.6), hair_mat, tag=2)
            c.add_ellipsoid(bp(3.0, 48.5, 2.8), (1.8, 2.6, 2.6), hair_mat, tag=2)

        c.add_ellipsoid(bp(-2.8, 47.8, 8.2), (1.1, 1.1, 0.8), "eye_dark", tag=2)
        c.add_ellipsoid(bp(1.2, 47.8, 8.2), (1.1, 1.1, 0.8), "eye_dark", tag=2)
        c.add_ellipsoid(bp(-0.8, 44.2, 8.2), (1.4, 1.3, 0.8), "mouth_dark", tag=2)
        c.add_ellipsoid(bp(-4.0, 46.5, 7.6), (1.2, 0.9, 0.6), "skin_blush", tag=2)
        c.add_ellipsoid(bp(2.4, 46.5, 7.6), (1.2, 0.9, 0.6), "skin_blush", tag=2)

        draw_ankle_clamp(c, clamp_x, clamp_y, base_z + 2.0, closed=True)
        draw_dizzy_stars(c, head[0], head[1] + 5.0, base_z + 6.0, star_ph)
        c.add_floor_shadow_ellipse(48.0, 106.0, 14.0, 6.5, strength=0.38)

        frames.append(c.finalize(quantize_to_th=True, dither_strength=8.0, char_outline=True, machine_soft_rim=True))
    return frames


def build_up_down_claw_hold_frames() -> List[Image.Image]:
    frames: List[Image.Image] = []
    for frame_idx in range(2):
        c = BullfrogCanvas(96, 112, ss=2)
        dy = 0.0 if frame_idx == 0 else 2.5
        draw_ankle_clamp(c, 48.0, 30.0 + dy, 22.0, closed=True)
        draw_dizzy_stars(c, 48.0, 74.0 + dy, 26.0, frame_idx * 1.6)
        frames.append(c.finalize(quantize_to_th=True, dither_strength=8.0, char_outline=False, machine_soft_rim=True))
    return frames


def generate_pngs() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for obsolete in OBSOLETE_FILES:
        obs_path = OUT_DIR / obsolete
        if obs_path.exists():
            obs_path.unlink()

    all_frames: List[Image.Image] = []
    all_frames.append(build_quoiging_chair(active=False))
    all_frames.append(build_quoiging_chair(active=True))
    all_frames.extend(build_quoiging_tickle_frames())
    all_frames.extend(build_silly_hat_frames())
    all_frames.append(build_up_down_rig(active=False))
    all_frames.append(build_up_down_rig(active=True))
    all_frames.extend(build_up_down_leg_grab_frames())
    all_frames.extend(build_up_down_dangle_frames(female=False))
    all_frames.extend(build_up_down_dangle_frames(female=True))
    all_frames.extend(build_up_down_claw_hold_frames())

    assert len(all_frames) == len(FRAME_NAMES)
    for name, img in zip(FRAME_NAMES, all_frames):
        img.save(OUT_DIR / name, format="PNG")


def iter_rgba_pixels(img: Image.Image):
    rgba = img.convert("RGBA")
    getter = getattr(rgba, "get_flattened_data", None)
    if callable(getter):
        return getter()
    return rgba.getdata()


def encode_simple_th_chunks(indices: Sequence[int]) -> bytes:
    """Encode 8bpp palette indices (0..254 opaque, 255 transparent) into CorsixTH simple chunk format."""
    out = bytearray()
    n = len(indices)
    i = 0
    while i < n:
        if indices[i] == 255:
            run = 1
            while run < 128 and i + run < n and indices[i + run] == 255:
                run += 1
            out.append(256 - run)
            i += run
        else:
            run = 1
            while run < 127 and i + run < n and indices[i + run] != 255:
                run += 1
            out.append(run)
            out.extend(indices[i : i + run])
            i += run
    return bytes(out)


def build_shared_palette(images: Sequence[Image.Image]) -> Tuple[bytes, dict]:
    """Build an 8-bit 256-entry RGB palette (index 255 = transparent magenta)."""
    opaque_colors = []
    seen = set()
    for img in images:
        for r, g, b, a in iter_rgba_pixels(img):
            if a >= 128:
                if (r, g, b) == (255, 0, 255):
                    r = 254
                key = (r, g, b)
                if key not in seen:
                    seen.add(key)
                    opaque_colors.append(key)

    if len(opaque_colors) <= 255:
        pal_list = list(opaque_colors)
    else:
        strip = Image.new("RGB", (len(opaque_colors), 1))
        strip.putdata(opaque_colors)
        quantized = strip.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        raw_pal = quantized.getpalette()[: 255 * 3]
        pal_list = []
        used = set()
        for idx in range(0, len(raw_pal), 3):
            rgb = (raw_pal[idx], raw_pal[idx + 1], raw_pal[idx + 2])
            if rgb == (255, 0, 255):
                rgb = (254, 0, 255)
            if rgb not in used:
                used.add(rgb)
                pal_list.append(rgb)

    color_to_idx = {rgb: idx for idx, rgb in enumerate(pal_list)}
    pal_bytes = bytearray(256 * 3)
    for idx, (r, g, b) in enumerate(pal_list):
        pal_bytes[idx * 3 : idx * 3 + 3] = bytes((r, g, b))
    pal_bytes[255 * 3 : 255 * 3 + 3] = bytes((255, 0, 255))
    return bytes(pal_bytes), color_to_idx


def nearest_palette_index(rgb: Tuple[int, int, int], pal_list: Sequence[Tuple[int, int, int]]) -> int:
    r, g, b = rgb
    best_i = 0
    best_dist = 1 << 30
    for i, (pr, pg, pb) in enumerate(pal_list):
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < best_dist:
            best_dist = d
            best_i = i
    return best_i


def compile_fallback_sheet() -> None:
    """Compile all PNGs in mod_sprites/ into mod_sprites.{pal,tab,dat}."""
    images: List[Image.Image] = []
    for name in FRAME_NAMES:
        path = OUT_DIR / name
        if not path.is_file():
            raise FileNotFoundError(f"Missing expected PNG frame: {path}")
        img = Image.open(path).convert("RGBA")
        if img.width > 255 or img.height > 255:
            img = img.resize(
                (min(img.width, 255), min(img.height, 255)),
                resample=Image.Resampling.NEAREST,
            )
        images.append(img)

    pal_bytes, color_to_idx = build_shared_palette(images)
    pal_list = [
        (pal_bytes[i * 3], pal_bytes[i * 3 + 1], pal_bytes[i * 3 + 2])
        for i in range(len(color_to_idx))
    ]
    nearest_cache = dict(color_to_idx)

    tab_bytes = bytearray()
    dat_bytes = bytearray()
    for img in images:
        tab_bytes.extend(struct.pack("<IBB", len(dat_bytes), img.width, img.height))
        indices: List[int] = []
        for r, g, b, a in iter_rgba_pixels(img):
            if a < 128:
                indices.append(255)
            else:
                rgb = (254, g, b) if (r, g, b) == (255, 0, 255) else (r, g, b)
                idx = nearest_cache.get(rgb)
                if idx is None:
                    idx = nearest_palette_index(rgb, pal_list)
                    nearest_cache[rgb] = idx
                indices.append(idx)
        dat_bytes.extend(encode_simple_th_chunks(indices))

    (OUT_DIR / "mod_sprites.pal").write_bytes(pal_bytes)
    (OUT_DIR / "mod_sprites.tab").write_bytes(bytes(tab_bytes))
    (OUT_DIR / "mod_sprites.dat").write_bytes(bytes(dat_bytes))
    print(f"Compiled {len(images)} sprites ({len(color_to_idx)} unique palette colors) into {OUT_DIR}")


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--compile-only",
        action="store_true",
        help="Recompile mod_sprites.{pal,tab,dat} from existing PNGs without regenerating them.",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)

    if not args.compile_only:
        generate_pngs()
    compile_fallback_sheet()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
