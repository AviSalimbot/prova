"""Full-page worksheet cleaning for the Raw -> Cleaned Drive pipeline
(Activity Info screen's "Clean & upload" action). Distinct from
preprocessing/pipeline.py, which prepares an already-cropped answer box
for OCR — this operates on the full raw scan before that ever happens.

v3 changes vs. the previous version of this module:
  * remove_chroma_marks(): new first pass that removes pale pink pen strokes
    (scores, check marks, slashes) that the HSV/RGB test missed.
  * remove_teacher_red(): bright-pixel floor, pale-halo cleanup, and
    paper/ink-aware fill instead of cv2.inpaint (no smearing over handwriting).
  * Hysteresis thresholding + small-glyph rescue: thin printed text, i-dots and
    full stops survive; back-of-page bleed-through is still rejected.
  * Right-border repair spans exactly the box (found from the left border)
    and follows page skew.
  * Vectorised despeckle (no per-component Python loop) -> faster.
Public API is unchanged: clean_page(img_bgr, ...) -> np.ndarray (gray, 255=paper).
"""

from typing import Optional

import cv2
import numpy as np

def remove_teacher_red(
    img_bgr: np.ndarray,
    sat_min: int = 35,
    red_delta: int = 18,
    dilate: int = 0,
    halo_radius: int = 4,
    halo_delta: int = 8,
    val_min: int = 110,
    fill_mode: str = "redchannel",
    fill_radius: int = 9,
    red_ink_ratio: float = 0.65,
    ink_gb_ratio: float = 0.52,
    return_mask: bool = False,
):
    """
    Remove red/pink teacher marks BEFORE grayscale conversion.

    FIX: a second, gentler pass removes the pale pink halo that surrounds a
    detected red stroke.  It only looks within `halo_radius` px of already
    detected red and only at pixels that are clearly red-tinted
    (R > min(G,B) + halo_delta).  Black/blue ink is never red-tinted, so
    handwriting and printed text are left alone.
    FIX: red pixels must also be BRIGHT (HSV value >= val_min).  Real red
    pen on white paper is bright (V ~ 200+); the reddish colour fringes that
    JPEG/scanner chroma noise puts on the edges of black printed text,
    handwriting and borders are DARK (V ~ 50-90).  The old floor of 50 let
    those fringes through, so black text pixels were being "inpainted".
    If return_mask is True, returns (image, red_zone) where red_zone is the
    neighbourhood of the red marks (used to stay strict around them).

    Two tests are combined:
      - HSV hue/saturation test for normal red ink
      - RGB-channel difference test for faded red/pink ink

    Inpainting fills the small red-mark regions from nearby paper/background,
    rather than simply painting them white.
    """
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    b, g, r = cv2.split(img_bgr)
    h, s, v = cv2.split(hsv)

    # Red wraps around the HSV hue scale: roughly 0..12 and 168..179.
    red_hue = ((h <= 12) | (h >= 168)) & (s >= sat_min) & (v >= val_min)

    # Extra protection for faded red/pink marks whose hue is less obvious.
    ri = r.astype(np.int16)
    gi = g.astype(np.int16)
    bi = b.astype(np.int16)
    red_rgb = (
        (ri >= gi + red_delta)
        & (ri >= bi + red_delta)
        & (ri > 70)
    )

    mask = ((red_hue | red_rgb) & (v >= val_min)).astype(np.uint8) * 255

    if not np.any(mask):
        if return_mask:
            return img_bgr.copy(), np.zeros(mask.shape, dtype=np.uint8)
        return img_bgr.copy()

    # Pale pink halo around the detected strokes (see docstring).
    kz = 2 * halo_radius + 1
    zone = cv2.dilate(
        mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kz, kz))
    )
    tint = (ri >= np.minimum(gi, bi) + halo_delta) & (v >= val_min)
    mask = np.where((zone > 0) & (tint | (mask > 0)), 255, 0).astype(np.uint8)

    # Include the immediate anti-aliased edge of the red stroke.
    if dilate > 0:
        k = 2 * dilate + 1
        mask = cv2.dilate(
            mask,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)),
            iterations=1,
        )

    # Small radius is intentional: teacher marks are thin, and we do not want
    # to erase a large surrounding region.
    if fill_mode == "inpaint":
        out = cv2.inpaint(img_bgr, mask, 3, cv2.INPAINT_TELEA)
    elif fill_mode == "redchannel":
        # FIX (handwriting lost / smudged where a red mark crosses it):
        # red ink reflects red light, so it is BRIGHT in the red channel,
        # while black/blue ink absorbs red and stays DARK there.  Showing the
        # red channel for the flagged pixels therefore turns pure red ink
        # into paper-white but keeps any real ink underneath/through it.
        # Red pen itself is only mid-bright in the red channel (~0.75-0.9 of
        # paper), so on its own it would leave a faint grey ghost.  Therefore:
        # clearly dark in the red channel (< red_ink_ratio of the local paper
        # level) = real ink, keep that value; otherwise = red pen, set to paper.
        kf = 2 * fill_radius + 1
        paper_r = cv2.dilate(
            r, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kf, kf))
        )
        # The dark CORE of a thick red stroke is also low in the red channel,
        # but red pen is still fairly bright in green/blue (>= ~0.55 of paper),
        # whereas black/blue ink darkens ALL channels.  So "real ink" must be
        # dark in red AND clearly dark in min(G,B).
        gb = np.minimum(g, b)
        paper_gb = cv2.dilate(
            gb, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kf, kf))
        )
        is_ink = (r < red_ink_ratio * paper_r) & (
            gb < ink_gb_ratio * paper_gb
        )
        val = np.where(is_ink, r, paper_r).astype(np.uint8)
        out = img_bgr.copy()
        out[mask > 0] = val[mask > 0][:, None]
    else:
        # FIX (dark smudges where a red mark crosses handwriting): inpainting
        # copies colour from the neighbours, and next to a crossing those
        # neighbours are black ink, which smears into the gap and leaves blobs.
        # Instead fill each red pixel with the local PAPER level: the
        # per-channel maximum in a small window ignores dark ink entirely.
        kf = 2 * fill_radius + 1
        paper = cv2.dilate(
            img_bgr, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kf, kf))
        )
        out = img_bgr.copy()
        out[mask > 0] = paper[mask > 0]
    if return_mask:
        return out, zone
    return out

def remove_chroma_marks(img_bgr, chroma_min=8, edge_min=5, grow=4,
                        ink_chroma_max=27, ink_dark_ratio=0.45, paper_radius=12):
    """
    v3: second pass for pale/pink teacher marks that survive remove_teacher_red.

    Red pen = high (R - mean(G,B)) vs the local paper tint; black/blue ink is
    neutral (or blue) so that value is ~0.  Seeds (chroma >= chroma_min) are
    grown by `grow` px through weaker pink (chroma >= edge_min) to take the
    anti-aliased edges.  Masked pixels become local paper, except pixels that
    are genuinely dark AND neutral (handwriting under the mark).
    Returns (image, zone) where zone = neighbourhood of the marks.
    """
    f = img_bgr.astype(np.float32)
    b, g, r = f[..., 0], f[..., 1], f[..., 2]
    chroma = r - 0.5 * (g + b)
    k = 2 * 25 + 1
    chroma = chroma - cv2.medianBlur(
        np.clip(chroma + 64, 0, 255).astype(np.uint8), k).astype(np.float32) + 64
    seed = (chroma >= chroma_min).astype(np.uint8) * 255
    if not seed.any():
        return img_bgr, np.zeros(seed.shape, np.uint8)
    # drop 1-2 px colour-noise specks that are not stroke-like
    n, lab, st, _ = cv2.connectedComponentsWithStats(seed, connectivity=8)
    keep = st[:, cv2.CC_STAT_AREA] >= 6
    keep[0] = False
    seed = np.where(keep[lab], 255, 0).astype(np.uint8)
    ke = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grow + 1, 2 * grow + 1))
    near = cv2.dilate(seed, ke)
    mask = np.where((near > 0) & (chroma >= edge_min), 255, 0).astype(np.uint8)
    mask = cv2.bitwise_or(mask, cv2.dilate(seed, cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (5, 5))))
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    kp = 2 * paper_radius + 1
    paper = cv2.dilate(gray, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kp, kp)))
    # Real ink darkens ALL channels; red pen stays fairly bright in G/B.
    gb = np.minimum(img_bgr[..., 0], img_bgr[..., 1])
    paper_gb = cv2.dilate(gb, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kp, kp)))
    is_ink = (gb < ink_dark_ratio * paper_gb) & (chroma < ink_chroma_max)
    out = img_bgr.copy()
    fill = (mask > 0) & ~is_ink
    out[fill] = paper[fill][:, None]
    zone = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    return out, zone

def _vertical_line_response(gray: np.ndarray) -> np.ndarray:
    """
    Return a 1-D score for long, continuous vertical dark lines.

    Morphological opening with a tall/narrow kernel suppresses handwriting and
    isolated specks while retaining the long form borders.
    """
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    ink = 255 - normalized
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 31))
    vertical = cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)

    # A light horizontal blur makes the x-position less sensitive to a
    # one-pixel scan wobble.
    vertical = cv2.GaussianBlur(vertical, (5, 1), 0)
    return vertical.mean(axis=0)
def _normalize(gray: np.ndarray) -> np.ndarray:
    """Shading-normalised grayscale (white page ~255)."""
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    return cv2.divide(gray, bg, scale=255)


def _horizontal_line_response(gray: np.ndarray) -> np.ndarray:
    """Kept for backward compatibility (no longer used by repair_faint_right_line)."""
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    ink = 255 - normalized
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (31, 3))
    horizontal = cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)
    return horizontal.mean(axis=1)



def _find_box_extent(gray: np.ndarray, x_left: int, min_frac: float = 0.25):
    """
    Return (top_y, bottom_y) of the worksheet box, measured from its LEFT
    border (which spans the whole box, solution area + final-answer area).

    The old code guessed these from fixed percentage bands of the page height,
    which on page 1 picked the "Name" underline as the top and the
    Final-Answer divider as the bottom.  Here we instead keep only very tall
    vertical ink runs near the left border, so header text, underlines and
    handwriting cannot influence the result.
    """
    h, w = gray.shape
    ink = (_normalize(gray) < 200).astype(np.uint8) * 255

    # Widen horizontally so a very slightly rotated scan still gives one
    # continuous run, then keep only runs >= min_frac of the page height.
    ink = cv2.dilate(ink, cv2.getStructuringElement(cv2.MORPH_RECT, (7, 1)))
    # Bridge small breaks (scan dropouts, a stray pen mark) so one gap in the
    # border does not make the whole border look "too short".
    ink = cv2.morphologyEx(
        ink, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (1, 31))
    )
    tall = cv2.morphologyEx(
        ink, cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (1, max(31, int(min_frac * h)))),
    )
    x0, x1 = max(0, x_left - 12), min(w, x_left + 13)
    rows = np.flatnonzero(tall[:, x0:x1].any(axis=1))
    if rows.size == 0:
        return None
    return int(rows[0]), int(rows[-1])


def _locate_line_x(gray, y_a, y_b, x_center, half_window):
    """Column (near x_center) with the strongest vertical ink over rows y_a..y_b."""
    h, w = gray.shape
    y_a, y_b = max(0, y_a), min(h, y_b)
    x0, x1 = max(0, x_center - half_window), min(w, x_center + half_window + 1)
    if y_b - y_a < 10 or x1 <= x0:
        return x_center
    ink = 255 - _normalize(gray)[y_a:y_b, x0:x1].astype(np.float32)
    col = cv2.GaussianBlur(ink.mean(axis=0).reshape(1, -1), (5, 1), 0).ravel()
    return int(x0 + np.argmax(col))


def repair_faint_right_line(
    gray: np.ndarray,
    strength_ratio: float = 0.35,
    thickness: int = 2,
    tolerance_fraction: float = 0.08,
) -> tuple[np.ndarray, bool]:
    """
    Reconstruct the rightmost form line ONLY if it is very faint/missing.

    The left and middle vertical borders give a reliable estimate of where the
    right border should be:   right ~= middle + (middle - left)

    A real right-line candidate is used when it is close to that predicted
    location.  Its strength is compared with the left/middle lines; if it is
    strong enough, nothing is drawn.

    FIX: the repaired line now spans exactly the box (top border -> bottom
    border), measured from the left border, and follows the page's slight
    skew by locating the line near its top and near its bottom.
    """
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

    # --- exact vertical extent of the box --------------------------------
    extent = _find_box_extent(gray, x_left)
    if extent is None or extent[1] <= extent[0] + 50:
        return gray, False          # cannot find the box reliably: do nothing
    top_y, bottom_y = extent

    # --- follow the skew: locate the line near each end ------------------
    band = max(40, int(0.12 * (bottom_y - top_y)))
    hw = max(8, int(0.01 * w))
    x_top = _locate_line_x(gray, top_y + 15, top_y + 15 + band, right_x, hw)
    x_bot = _locate_line_x(gray, bottom_y - 15 - band, bottom_y - 15, right_x, hw)
    # Reject a peak that wandered away from the main candidate (handwriting).
    if abs(x_top - right_x) > hw:
        x_top = right_x
    if abs(x_bot - right_x) > hw:
        x_bot = right_x

    repaired = gray.copy()
    cv2.line(
        repaired,
        (int(x_top), int(top_y)),
        (int(x_bot), int(bottom_y)),
        0,
        max(1, int(thickness)),
        cv2.LINE_AA,
    )
    return repaired, True
def _auto_threshold_offset(normalized: np.ndarray, min_c: int, max_c: int) -> int:
    """
    Automatically pick how far below the local background a pixel must be
    to count as real ink, tuned to THIS image's own histogram.

    We run Otsu's method on the shading-normalized grayscale image. Otsu
    finds the split point that best separates the image into two clusters
    (here: "page/background, including any bleed-through" vs "real ink").
    Converting that split point into an offset from white (255 - otsu_t)
    gives a per-image threshold offset: pages with only faint bleed-through
    naturally get a small offset, pages with strong bleed-through or heavy
    double-sided writing get a bigger one, and the result is clamped to a
    sane range so it never goes to an extreme on unusual pages.
    """
    otsu_t, _ = cv2.threshold(normalized, 0, 255,
                              cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    c = int(round(255 - otsu_t))
    return max(min_c, min(max_c, c))
def _protected_line_mask(normalized: np.ndarray, block_size: int, lenient_c: int,
                          line_min_length_frac: float) -> np.ndarray:
    """
    Find long straight horizontal/vertical ink runs (table borders, box
    outlines, rule lines) using a lenient threshold, so they survive even
    on pages where the main auto-detected offset would erase a faint or
    worn-looking printed line. Handwriting and bleed-through specks don't
    form long straight runs, so they are excluded by construction -- only
    genuine border-like lines make it through the morphological opening.
    Returns an "ink=255" mask, same convention as the despeckle step.
    """
    lenient_bw = cv2.adaptiveThreshold(
        normalized, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        block_size, lenient_c
    )
    lenient_inv = 255 - lenient_bw  # ink = 255

    h, w = normalized.shape
    horiz_len = max(15, int(w * line_min_length_frac))
    vert_len = max(15, int(h * line_min_length_frac))
    horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (horiz_len, 1))
    vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, vert_len))

    horiz_lines = cv2.morphologyEx(lenient_inv, cv2.MORPH_OPEN, horiz_kernel)
    vert_lines = cv2.morphologyEx(lenient_inv, cv2.MORPH_OPEN, vert_kernel)

    return cv2.bitwise_or(horiz_lines, vert_lines)
def clean_page(img_bgr: np.ndarray, block_size: int = 51, C: Optional[int] = None,
                despeckle: int = 15, min_c: int = 15, max_c: int = 120,
                protect_lines: bool = True, line_min_length_frac: float = 0.25,
                remove_red: bool = True,
                red_sat: int = 35, red_delta: int = 18,
                repair_right_line: bool = True,
                right_line_ratio: float = 0.35,
                right_line_thickness: int = 2,
                right_line_tolerance: float = 0.08,
                grow_c: Optional[int] = None,
                rescue_small: bool = True,
                rescue_radius: int = 12,
                bridge: int = 5,
                grow_ratio: float = 0.5,
                red_val_min: int = 110,
                red_ink_gb_ratio: float = 0.52) -> np.ndarray:
    # ADDED: teacher-mark removal while color is still available.
    red_zone = None
    if remove_red:
        # v3: chroma pass FIRST - remove_teacher_red writes grey values over
        # the stroke, which destroys the colour evidence this pass relies on.
        img_bgr, zone2 = remove_chroma_marks(img_bgr)
        img_bgr, red_zone = remove_teacher_red(
            img_bgr, sat_min=red_sat, red_delta=red_delta, dilate=0,
            val_min=red_val_min, ink_gb_ratio=red_ink_gb_ratio,
            return_mask=True,
        )
        red_zone = cv2.bitwise_or(red_zone, zone2)

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # ADDED: repair only a genuinely faint/missing right form line.
    if repair_right_line:
        gray, _ = repair_faint_right_line(
            gray,
            strength_ratio=right_line_ratio,
            thickness=right_line_thickness,
            tolerance_fraction=right_line_tolerance,
        )

    # 1) Remove uneven lighting / paper shading so the whole page is a flat
    #    white background before we threshold. Big blur = smooth "background"
    #    estimate, then divide it out.
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=25)
    normalized = cv2.divide(gray, bg, scale=255)

    # 2) Decide how aggressive the threshold needs to be for THIS page.
    #    If the caller passed an explicit C, respect it exactly (manual
    #    override). Otherwise auto-detect per image.
    effective_c = C if C is not None else _auto_threshold_offset(normalized, min_c, max_c)

    # 3) Adaptive threshold: local neighborhood decides black/white cutoff,
    #    which is what makes it robust across the whole page even if
    #    lighting/paper tone drifts a bit page to page.
    if block_size % 2 == 0:
        block_size += 1
    bw = cv2.adaptiveThreshold(
        normalized, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        block_size, effective_c
    )
    inv = 255 - bw  # ink = white, for compositing/component analysis below

    # 3b) FIX (printed text was being eroded): the auto offset is chosen from
    #     Otsu, which is dominated by dark handwriting, so it lands at ~50-70
    #     and cuts the thin, light strokes of small printed text (the
    #     instructions) into fragments.  Hysteresis fixes this without letting
    #     bleed-through back in:
    #       * "strong" ink  = the result above (same threshold as before)
    #       * "weak" ink    = a more lenient threshold
    #     A weak pixel is kept ONLY if its connected stroke contains strong
    #     ink, so letters regain their full thin strokes/edges, while isolated
    #     faint bleed-through from the back of the page (which never contains
    #     strong ink) is still rejected.
    # Strong ink, widened by `bridge` px: the dot of an "i" or a hairline
    # fragment is often 1-3 px away from its stroke and too light to be
    # "strong" itself, so seeds are allowed to reach across that tiny gap.
    kb = 2 * bridge + 1
    strong_raw = inv.copy()
    strong = cv2.dilate(
        inv, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kb, kb))
    ) if bridge > 0 else inv.copy()
    if grow_c is None:
        grow_c = max(min_c, int(round(grow_ratio * effective_c)))
    if grow_c < effective_c:
        weak_bw = cv2.adaptiveThreshold(
            normalized, 255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            block_size, grow_c
        )
        weak = 255 - weak_bw
        n_w, lab_w = cv2.connectedComponents(weak, connectivity=8)
        seeded = np.zeros(n_w, dtype=bool)
        seeded[np.unique(lab_w[strong > 0])] = True
        seeded[0] = False
        grown = np.where(seeded[lab_w], 255, 0).astype(np.uint8)
        if red_zone is not None:
            # Right next to teacher marks stay as strict as before: no
            # lenient growth there (it would only fatten pink residue).
            grown = np.where(red_zone > 0, strong_raw, grown)
        inv = grown

    # 4) Protect table borders / box outlines: union in any long straight
    #    line found by the lenient pass, so a faint or worn-looking border
    #    survives even if the auto-detected offset above would have erased
    #    it. Must happen before despeckle so the merged result gets
    #    despeckled as one image (harmless for lines -- they're large
    #    connected components -- but keeps the pipeline simple).
    if protect_lines:
        line_mask = _protected_line_mask(normalized, block_size, min_c, line_min_length_frac)
        inv = cv2.bitwise_or(inv, line_mask)

    # 5) Despeckle: remove tiny isolated black dots (residual noise / dust)
    #    without eating real strokes. Use connected-component area filter,
    #    which is safer than a blanket erode for preserving thin pencil lines.
    if despeckle > 0:
        n, labels, stats, _ = cv2.connectedComponentsWithStats(inv, connectivity=8)
        areas = stats[:, cv2.CC_STAT_AREA]
        keep = areas >= despeckle
        keep[0] = False

        # FIX (i-dots, full stops, colons were being deleted): a tiny component
        # is ALSO kept when it (a) contains strong ink and (b) sits within a few
        # pixels of a real (large) component, i.e. it is part of a word/line of
        # text.  Isolated dust/bleed-through specks out in empty paper have no
        # large neighbour, so they are still removed.
        if rescue_small and rescue_radius > 0:
            big = np.where(keep[labels], 255, 0).astype(np.uint8)
            k = 2 * rescue_radius + 1
            near = cv2.dilate(
                big, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
            )
            has_strong = np.zeros(n, dtype=bool)
            has_strong[np.unique(labels[strong > 0])] = True
            near_ids = np.zeros(n, dtype=bool)
            near_ids[np.unique(labels[(near > 0) & (inv > 0)])] = True
            small = (~keep) & (areas >= 2)
            small[0] = False
            keep |= small & has_strong & near_ids

        inv = np.where(keep[labels], 255, 0).astype(np.uint8)

    return 255 - inv