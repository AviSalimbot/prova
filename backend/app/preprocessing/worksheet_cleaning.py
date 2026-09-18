"""Full-page worksheet cleaning for the Raw -> Cleaned Drive pipeline
(Activity Info screen's "Clean & upload" action). Distinct from
preprocessing/pipeline.py, which prepares an already-cropped answer box
for OCR — this operates on the full raw scan before that ever happens.
"""

from typing import Optional

import cv2
import numpy as np


def remove_teacher_red(
    img_bgr: np.ndarray,
    sat_min: int = 35,
    red_delta: int = 18,
    dilate: int = 0,
) -> np.ndarray:
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    b, g, r = cv2.split(img_bgr)
    h, s, v = cv2.split(hsv)

    red_hue = ((h <= 12) | (h >= 168)) & (s >= sat_min) & (v >= 50)

    ri = r.astype(np.int16)
    gi = g.astype(np.int16)
    bi = b.astype(np.int16)
    red_rgb = (
        (ri >= gi + red_delta)
        & (ri >= bi + red_delta)
        & (ri > 70)
    )

    mask = ((red_hue | red_rgb) & (v > 40)).astype(np.uint8) * 255

    if not np.any(mask):
        return img_bgr.copy()

    if dilate > 0:
        k = 2 * dilate + 1
        mask = cv2.dilate(
            mask,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)),
            iterations=1,
        )

    return cv2.inpaint(img_bgr, mask, 3, cv2.INPAINT_TELEA)


def _vertical_line_response(gray: np.ndarray) -> np.ndarray:
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    ink = 255 - normalized
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 31))
    vertical = cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)

    vertical = cv2.GaussianBlur(vertical, (5, 1), 0)
    return vertical.mean(axis=0)


def _horizontal_line_response(gray: np.ndarray) -> np.ndarray:
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    ink = 255 - normalized
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (31, 3))
    horizontal = cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)
    return horizontal.mean(axis=1)


def repair_faint_right_line(
    gray: np.ndarray,
    strength_ratio: float = 0.35,
    thickness: int = 2,
    tolerance_fraction: float = 0.08,
) -> tuple[np.ndarray, bool]:
    h, w = gray.shape
    profile = _vertical_line_response(gray)

    left_end = max(1, int(0.25 * w))
    mid_start = int(0.25 * w)
    mid_end = int(0.75 * w)

    x_left = int(np.argmax(profile[:left_end]))
    x_mid = int(np.argmax(profile[mid_start:mid_end]) + mid_start)

    left_strength = float(profile[x_left])
    mid_strength = float(profile[x_mid])
    reference_strength = float(np.median([left_strength, mid_strength]))

    expected_x = x_mid + (x_mid - x_left)

    search_start = int(0.75 * w)
    candidate_x = int(np.argmax(profile[search_start:]) + search_start)
    candidate_strength = float(profile[candidate_x])

    near_expected = abs(candidate_x - expected_x) <= tolerance_fraction * w

    if near_expected:
        right_x = candidate_x
        right_strength = candidate_strength
    else:
        right_x = expected_x
        right_strength = 0.0

    threshold = max(5.0, strength_ratio * reference_strength)
    needs_repair = reference_strength > 10.0 and right_strength < threshold

    if not needs_repair:
        return gray, False

    h_profile = _horizontal_line_response(gray)

    top_a = int(0.03 * h)
    top_b = int(0.20 * h)
    bottom_a = int(0.75 * h)
    bottom_b = int(0.98 * h)

    top_y = int(np.argmax(h_profile[top_a:top_b]) + top_a)
    bottom_y = int(np.argmax(h_profile[bottom_a:bottom_b]) + bottom_a)

    if bottom_y <= top_y + 50:
        top_y = int(0.07 * h)
        bottom_y = int(0.94 * h)

    repaired = gray.copy()

    thickness = max(1, int(thickness))
    cv2.line(
        repaired,
        (int(round(right_x)), top_y),
        (int(round(right_x)), bottom_y),
        0,
        thickness,
        cv2.LINE_AA,
    )

    return repaired, True


def _auto_threshold_offset(normalized: np.ndarray, min_c: int, max_c: int) -> int:
    otsu_t, _ = cv2.threshold(
        normalized, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )
    c = int(round(255 - otsu_t))
    return max(min_c, min(max_c, c))


def _protected_line_mask(
    normalized: np.ndarray, block_size: int, lenient_c: int, line_min_length_frac: float
) -> np.ndarray:
    lenient_bw = cv2.adaptiveThreshold(
        normalized, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        block_size, lenient_c,
    )
    lenient_inv = 255 - lenient_bw

    h, w = normalized.shape
    horiz_len = max(15, int(w * line_min_length_frac))
    vert_len = max(15, int(h * line_min_length_frac))
    horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (horiz_len, 1))
    vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vert_len))

    horiz_lines = cv2.morphologyEx(lenient_inv, cv2.MORPH_OPEN, horiz_kernel)
    vert_lines = cv2.morphologyEx(lenient_inv, cv2.MORPH_OPEN, vert_kernel)

    return cv2.bitwise_or(horiz_lines, vert_lines)


def clean_page(
    img_bgr: np.ndarray,
    block_size: int = 51,
    C: Optional[int] = None,
    despeckle: int = 15,
    min_c: int = 15,
    max_c: int = 120,
    protect_lines: bool = True,
    line_min_length_frac: float = 0.25,
    remove_red: bool = True,
    red_sat: int = 35,
    red_delta: int = 18,
    repair_right_line: bool = True,
    right_line_ratio: float = 0.35,
    right_line_thickness: int = 2,
    right_line_tolerance: float = 0.08,
) -> np.ndarray:
    if remove_red:
        img_bgr = remove_teacher_red(
            img_bgr, sat_min=red_sat, red_delta=red_delta, dilate=0
        )

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    if repair_right_line:
        gray, _ = repair_faint_right_line(
            gray,
            strength_ratio=right_line_ratio,
            thickness=right_line_thickness,
            tolerance_fraction=right_line_tolerance,
        )

    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    effective_c = (
        C if C is not None else _auto_threshold_offset(normalized, min_c, max_c)
    )

    if block_size % 2 == 0:
        block_size += 1
    bw = cv2.adaptiveThreshold(
        normalized, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        block_size, effective_c,
    )
    inv = 255 - bw

    if protect_lines:
        line_mask = _protected_line_mask(
            normalized, block_size, min_c, line_min_length_frac
        )
        inv = cv2.bitwise_or(inv, line_mask)

    if despeckle > 0:
        n, labels, stats, _ = cv2.connectedComponentsWithStats(inv, connectivity=8)
        clean_inv = np.zeros_like(inv)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= despeckle:
                clean_inv[labels == i] = 255
        inv = clean_inv

    return 255 - inv