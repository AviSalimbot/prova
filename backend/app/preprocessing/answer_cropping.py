"""
answer_cropping.py
==================

Library form of crop_answers.py, used by app/api/crop.py (POST /crop/exam).
The per-page logic is unchanged; the file/folder CLI (argparse, batch
walking, writing PNGs to disk) was removed because the API downloads each
cleaned page from Drive, calls process_page_gray(), and uploads the
crops itself.

Automatic cropper for student answer-sheet pages ("template-2").

USAGE
-----
    from app.preprocessing.answer_cropping import process_page_gray
    page = process_page_gray(gray_ndarray, use_ocr=True)

INPUT ASSUMPTION (important)
-----------------------------
This script expects ALREADY-CLEANED scans (e.g. the output of a separate
clean_page.py-style pipeline): shading-normalized, thresholded, ink-on-white,
with any red teacher marks already removed. This script does NOT do any
red-mark handling and does not re-threshold aggressively -- it assumes the
input is close to bilevel already. Do not feed it raw phone photos.

PAGE LAYOUT (from the 4 example images analyzed)
--------------------------------------------------
Each "item" page has, top to bottom:
    Item #___            <- handwritten digit after printed "Item #"
    Problem: <equations> <- variable height (2-4 lines), so the boxes below
                             do NOT start at a fixed y across pages
    +-----------------------------+
    | Solution:                   |
    |   left half | right half    |  <- ONE bordered rectangle, ONE internal
    |             |               |     vertical divider (not centered --
    +-----------------------------+     it must be detected, not assumed)
    +-----------------------------+
    | Final Answer:               |  <- separate rectangle, NOT split.
    +-----------------------------+     There is only ONE answer box per
                                         item (confirmed by user), even if
                                         the item spans multiple pages.

A page can also be entirely blank (unused extra page) -- Item # blank,
both solution halves empty, Final Answer empty. Such pages contribute
nothing and are silently skipped.

ITEM-NUMBER RESOLUTION (per user instruction)
-----------------------------------------------
    1. If a digit can be read from the "Item #" region -> use it (this is
       "specified", and always wins).
    2. If the region is blank / unreadable -> fall back to a plain running
       counter (1, 2, 3, ...) over non-blank pages, in page order. We do
       NOT try to guess "this blank page is a continuation of the last
       item" -- per instruction, assume static sequential numbering unless
       a number is actually written down.

SOLUTION NUMBERING
------------------
Sequential per item, based only on non-empty boxes, in the order pages
were processed and left-column-before-right-column within a page:
    item1_solution1.png, item1_solution2.png, ...
Empty boxes are skipped entirely -- they do not consume a number.

ANSWER
------
One image per item: item{N}_answer.png. Across however many pages belong
to item N, whichever page's Final Answer box is non-empty is used. If more
than one page for the same item has a non-empty answer box (shouldn't
normally happen), the *last* one encountered wins and a warning is logged.

CALIBRATION NOTE
-----------------
Box-finding and empty/used thresholds below were tuned by inspecting the
four example images, not a large sample. The constants near the top of
this file (search for "TUNABLE") are the first place to adjust if this
misbehaves on real batches -- in particular MIN_INK_RATIO and
MIN_INK_COMPONENT_PX for the empty/used decision.
"""

import logging
import re
from dataclasses import dataclass
from typing import Optional

import cv2
import numpy as np

try:
    import pytesseract
    HAVE_TESSERACT = True
except ImportError:
    HAVE_TESSERACT = False

logger = logging.getLogger(__name__)


# --------------------------------------------------------------------------
# TUNABLE constants
# --------------------------------------------------------------------------
# A box's bounding rectangle must span at least this fraction of page width
# (resp. height, for the whole Solution+Answer block) to be considered a
# real form box (rules out small handwriting blobs that happen to form a
# closed loop, or a page where the layout wasn't found at all).
MIN_BOX_WIDTH_FRAC = 0.55
MIN_BOX_AREA_FRAC = 0.15   # here used as a min-height fraction of page height

# A row/column is treated as "part of a printed rule line" once its ink
# density -- measured AFTER a long-run morphological opening, see
# `_long_run_ink()` below, not on the raw thresholded pixels -- exceeds
# this. The opening step already discards anything that isn't part of a
# continuous run at least LINE_RUN_FRAC of the page's width/height, which
# is what makes this threshold safe to keep low: real border lines survive
# opening at very high density (0.5-1.0 in practice), while paragraph text
# (e.g. an instructions block) is made of short strokes that the opening
# erases almost entirely, even on rows where raw ink density alone would
# have looked line-like. A pure raw-density threshold was tried first and
# had to be tuned per page (some genuine divider lines print faint enough
# to sit at ~0.42 density, while dense instruction paragraphs can reach
# ~0.38) -- there was no single raw-density cutoff that kept both. The
# opening step removes that ambiguity, so this threshold just needs to
# clear ordinary post-opening noise.
LINE_DENSITY_FRAC = 0.15

# Minimum length of a continuous ink run for it to survive the
# morphological opening used by `_long_run_ink()`, as a fraction of the
# image dimension being scanned (page width for horizontal lines, page
# height for vertical lines). Real printed rule lines run the full width/
# height of the box; ordinary handwriting strokes and printed text letters
# are far shorter than this even when densely packed.
LINE_RUN_FRAC = 0.30

# Ink density inside a (border-inset) box needed to call it "used".
# Cleaned input is expected to be near-bilevel, so this is a plain ink-pixel
# ratio, not an adaptive threshold.
INK_GRAY_THRESHOLD = 200          # pixel < this counts as "ink" (0-255 gray)
MIN_INK_RATIO = 0.0020            # ink_pixels / box_area
MIN_INK_COMPONENT_PX = 20         # ignore connected components smaller than this
                                   # (scanner dust / compression specks / a short
                                   # stray pencil tick a teacher left on an
                                   # otherwise-blank page)

# How far to inset from a detected box's own border before measuring ink,
# so the printed border line itself is never counted as content.
BOX_BORDER_INSET = 10

# Extra inset applied ONLY to the top edge when measuring emptiness (not
# when saving the crop) -- both the Solution and Final Answer boxes have a
# printed label ("Solution", "Final Answer") sitting just inside their top
# border, and that printed text must not be mistaken for student ink.
# Expressed as a fraction of page height since label font size scales with
# scan resolution, not box size; measured on real scans the label occupies
# roughly the first 40px of a ~2300px-tall page.
BOX_TOP_LABEL_INSET_FRAC = 0.025

# Region above the Solution box to search for the handwritten item number,
# as a fraction of page height/width. WIDTH is intentionally narrow: on
# pages where the Problem statement sits beside/above the "Item #" label
# (rather than on its own line, as on a page 1 with the full instructions
# header), a wide band pulls in digits from the problem's equations and
# the whitelisted-digit OCR has no way to tell those apart from the actual
# item number -- this is what caused item numbers to be misread. 0.18
# was measured to comfortably include the "Item #___" label and its
# handwritten digit on every example page while stopping short of any
# adjacent problem text.
ITEM_NUMBER_BAND_HEIGHT_FRAC = 0.10
ITEM_NUMBER_BAND_WIDTH_FRAC = 0.18

VALID_ITEM_NUMBERS = set(range(1, 21))  # sanity clamp for OCR misreads


# --------------------------------------------------------------------------
# Page geometry
# --------------------------------------------------------------------------
@dataclass
class BoxRect:
    x: int
    y: int
    w: int
    h: int

    @property
    def x2(self):
        return self.x + self.w

    @property
    def y2(self):
        return self.y + self.h


def deskew_page(gray: np.ndarray) -> np.ndarray:
    """
    Correct small rotation using the dominant long horizontal lines (box
    borders), which are far more reliable than trying to find the outer
    photo/page edge on an already-cleaned, tightly cropped scan.

    If no reliable line is found, the image is returned unchanged --
    a small residual skew is preferable to a bad "correction".
    """
    h, w = gray.shape
    bw = cv2.threshold(gray, INK_GRAY_THRESHOLD, 255, cv2.THRESH_BINARY_INV)[1]

    horiz_kernel = cv2.getStructuringElement(
        cv2.MORPH_RECT, (max(20, int(w * 0.4)), 1)
    )
    horiz = cv2.morphologyEx(bw, cv2.MORPH_OPEN, horiz_kernel)

    lines = cv2.HoughLinesP(
        horiz, 1, np.pi / 360, threshold=int(w * 0.3),
        minLineLength=int(w * 0.4), maxLineGap=20
    )
    if lines is None:
        return gray

    # cv2.HoughLinesP is documented as returning shape (N, 1, 4), and that's
    # what it does in most opencv-python builds -- but at least one install
    # (observed on macOS) returns (N, 4) instead. Indexing that as [:, 0]
    # then silently returns N individual int32 scalars (just the x1 column)
    # rather than N four-element rows, and unpacking a bare scalar into
    # (x1, y1, x2, y2) below raises "cannot unpack non-iterable numpy.int32
    # object" -- which happens on every single page, since this runs before
    # any of the actual box-detection logic. reshape(-1, 4) normalizes
    # either shape to rows of 4, so this works regardless of which
    # convention the installed OpenCV build uses.
    lines = np.asarray(lines).reshape(-1, 4)

    angles = []
    for x1, y1, x2, y2 in lines:
        if x2 == x1:
            continue
        angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
        if abs(angle) < 10:  # ignore anything that isn't nearly horizontal
            angles.append(angle)

    if not angles:
        return gray

    median_angle = float(np.median(angles))
    if abs(median_angle) < 0.2:
        return gray  # not worth rotating

    center = (w / 2, h / 2)
    m = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    return cv2.warpAffine(
        gray, m, (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT, borderValue=255
    )


def _long_run_ink(bw: np.ndarray, axis: int, run_frac: float) -> np.ndarray:
    """
    Return, for each row (axis=1) or column (axis=0) of a binary ink image,
    the ink density considering ONLY pixels that belong to a continuous
    run at least `run_frac` of the scanned dimension long.

    This is the key trick that makes rule-line detection robust: a plain
    ink-density-per-row count cannot reliably separate a genuine printed
    border line from a dense row of handwriting or printed paragraph text,
    because both can land in the same density range depending on scan
    quality (see LINE_DENSITY_FRAC's comment). But a border line IS, by
    construction, one long unbroken stroke spanning the box, while text is
    made of many short strokes with gaps between letters/words -- so a
    morphological opening with a kernel at least `run_frac` long erases
    ordinary text almost completely while leaving genuine rule lines
    (even faint/thin ones) largely intact, regardless of raw density.
    """
    h, w = bw.shape
    length = w if axis == 1 else h
    ksize = max(15, int(length * run_frac))
    if axis == 1:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (ksize, 1))
    else:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, ksize))
    opened = cv2.morphologyEx(bw, cv2.MORPH_OPEN, kernel)
    ink = opened.sum(axis=axis) / 255.0
    # axis=1 sums across each row (one value per row) -> divide by width;
    # axis=0 sums down each column (one value per column) -> divide by height.
    span = w if axis == 1 else h
    return ink / span


def _cluster_line_positions(is_line: np.ndarray, min_gap: int = 5) -> list[int]:
    """
    Given a 1-D boolean array flagging "this row/column looks like part of a
    printed rule line", collapse runs of adjacent True entries (a rule line
    is a few pixels thick) into a single center position per line.
    """
    idxs = np.where(is_line)[0]
    if idxs.size == 0:
        return []
    groups: list[list[int]] = [[int(idxs[0])]]
    for v in idxs[1:]:
        v = int(v)
        if v - groups[-1][-1] <= min_gap:
            groups[-1].append(v)
        else:
            groups.append([v])
    return [int(np.mean(g)) for g in groups]


def find_form_boxes(gray: np.ndarray) -> tuple[Optional[BoxRect], Optional[BoxRect]]:
    """
    Locate the Solution box and the Final Answer box on a page.
    """
    h, w = gray.shape
    bw = cv2.threshold(gray, INK_GRAY_THRESHOLD, 255, cv2.THRESH_BINARY_INV)[1]

    # --- 1. Horizontal lines: page top border, Solution/Answer divider,
    #         Answer bottom border -- found via long-run ink density (see
    #         _long_run_ink), not raw per-row ink density. A raw-density
    #         scan cannot reliably tell a genuine rule line apart from a
    #         dense block of printed/handwritten text: on real scans some
    #         genuine divider lines print as faint as ~0.42 density while
    #         a packed instructions paragraph can reach ~0.38, so no single
    #         raw-density cutoff keeps both. Long-run filtering sidesteps
    #         that: only pixels belonging to a continuous run spanning at
    #         least LINE_RUN_FRAC of the row survive, which text (made of
    #         short letter strokes) essentially never does, regardless of
    #         how densely packed it is.
    xin1, xin2 = int(0.05 * w), int(0.95 * w)
    row_frac = _long_run_ink(bw[:, xin1:xin2], axis=1, run_frac=LINE_RUN_FRAC)
    h_lines = _cluster_line_positions(row_frac > LINE_DENSITY_FRAC)

    if len(h_lines) < 2:
        return None, None

    top_y = h_lines[0]
    bottom_y = h_lines[-1]
    if bottom_y - top_y < MIN_BOX_AREA_FRAC * h:
        return None, None

    interior_h = h_lines[1:-1]
    divider_y = interior_h[0] if interior_h else None
    solution_bottom = divider_y if divider_y is not None else bottom_y

    # --- 2. Vertical lines: left border, left/right-solution divider,
    #         right border -- found the same long-run way, restricted to
    #         the Solution portion's row range, since the left/right
    #         divider does NOT continue down into the Final Answer box. ---
    yin1, yin2 = top_y + 10, solution_bottom - 10
    if yin2 <= yin1:
        return None, None
    col_frac = _long_run_ink(bw[yin1:yin2, :], axis=0, run_frac=LINE_RUN_FRAC)
    v_lines = _cluster_line_positions(col_frac > LINE_DENSITY_FRAC)

    if len(v_lines) < 2:
        return None, None
    if v_lines[-1] - v_lines[0] < MIN_BOX_WIDTH_FRAC * w:
        return None, None

    left_x, right_x = v_lines[0], v_lines[-1]

    solution_box = BoxRect(left_x, top_y, right_x - left_x, solution_bottom - top_y)
    answer_box = (
        BoxRect(left_x, divider_y, right_x - left_x, bottom_y - divider_y)
        if divider_y is not None else None
    )
    return solution_box, answer_box


def find_vertical_divider(gray: np.ndarray, box: BoxRect) -> int:
    """
    Find the internal vertical divider between the left/right solution
    halves, using the same long-run ink-density approach as
    find_form_boxes (robust to both the small gap where this line crosses
    the box's top/bottom border, and to handwriting that runs across or
    near the divider without actually being as long as a full rule line).
    Falls back to the horizontal midpoint if no clear line is detected.
    """
    bw = cv2.threshold(gray, INK_GRAY_THRESHOLD, 255, cv2.THRESH_BINARY_INV)[1]
    yin1, yin2 = box.y + 10, box.y2 - 10
    if yin2 <= yin1:
        return box.x + box.w // 2

    col_frac = _long_run_ink(bw[yin1:yin2, box.x:box.x2], axis=0, run_frac=LINE_RUN_FRAC)

    margin = max(1, int(box.w * 0.05))
    candidates = _cluster_line_positions(col_frac > LINE_DENSITY_FRAC)
    interior = [c for c in candidates if margin < c < box.w - margin]
    if not interior:
        return box.x + box.w // 2

    best = min(interior, key=lambda c: abs(c - box.w / 2))
    return box.x + best


def crop_gray(gray: np.ndarray, box: BoxRect) -> np.ndarray:
    return gray[box.y:box.y2, box.x:box.x2].copy()


def is_box_empty(gray: np.ndarray, box: BoxRect) -> bool:
    page_h = gray.shape[0]
    inset = BOX_BORDER_INSET
    top_inset = max(inset, int(BOX_TOP_LABEL_INSET_FRAC * page_h))

    x1 = box.x + inset
    y1 = box.y + top_inset
    x2 = box.x2 - inset
    y2 = box.y2 - inset
    if x2 <= x1 or y2 <= y1:
        return True

    roi = gray[y1:y2, x1:x2]
    bw = (roi < INK_GRAY_THRESHOLD).astype(np.uint8) * 255

    if not np.any(bw):
        return True

    n, labels, stats, _ = cv2.connectedComponentsWithStats(bw, connectivity=8)
    ink_px = 0
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= MIN_INK_COMPONENT_PX:
            ink_px += stats[i, cv2.CC_STAT_AREA]

    area = roi.shape[0] * roi.shape[1]
    ratio = ink_px / area if area else 0.0
    return ratio < MIN_INK_RATIO


def _strip_underline(digit_gray: np.ndarray) -> np.ndarray:
    """
    The handwritten item digit sits on a printed underline. Left in place,
    Tesseract frequently reads "digit + underline" as a single unrelated
    glyph (observed: a handwritten "1" plus its underline gets read as
    "=", returning nothing even under a digit whitelist) rather than as a
    digit sitting above a line. This drops the underline itself -- the
    last distinct band of ink, once density and a gap above it mark it as
    a separate stroke from the digit -- and returns everything above it.
    If no such separate band is found (e.g. no underline in this crop),
    the image is returned unchanged.
    """
    bw = cv2.threshold(digit_gray, INK_GRAY_THRESHOLD, 255, cv2.THRESH_BINARY_INV)[1]
    h, w = bw.shape
    if h < 6 or w < 3:
        return digit_gray
    row_density = bw.sum(axis=1) / 255.0 / w

    idxs = np.where(row_density > 0.05)[0]
    if idxs.size == 0:
        return digit_gray
    groups: list[list[int]] = [[int(idxs[0])]]
    for v in idxs[1:]:
        v = int(v)
        if v - groups[-1][-1] <= 4:
            groups[-1].append(v)
        else:
            groups.append([v])
    if len(groups) < 2:
        return digit_gray

    last = groups[-1]
    last_peak = max(row_density[r] for r in last)
    # An underline is a thin, dense, separate band near the bottom of the
    # crop. If the last ink band looks like that, cut it off.
    if last_peak > 0.25:
        cutoff = last[0] - 2
        if cutoff > 5:
            return digit_gray[:cutoff, :]
    return digit_gray


def ocr_item_number(gray: np.ndarray, solution_box: BoxRect) -> Optional[int]:
    """
    Try to read the handwritten item number written on the printed
    "Item #___" label directly above the Solution box.

    This anchors on the printed "#" character (located via Tesseract's
    character-box output, run WITHOUT a digit whitelist so "#" is
    recognized as itself) and OCRs only the region to its right, rather
    than OCR-ing the whole label band with a digit whitelist. That
    band-wide approach was tried first and failed in two different ways:
    a wide band picked up digits from the Problem statement printed
    beside/above the label on some page layouts (an item 3 was misread as
    item 7 this way), and even a narrow band still had the "#" glyph
    itself misrecognized as a stray digit by the whitelist pass (since a
    whitelist forces every glyph to the closest allowed character rather
    than rejecting non-digits), producing a garbled multi-digit read.
    Anchoring on the actual "#" position and only OCR-ing what's to its
    right, after stripping its underline (see _strip_underline), avoids
    both failure modes.

    NOTE ON RELIABILITY: this is still handwritten-digit OCR, which has a
    real, irreducible error rate on messy handwriting -- e.g. a looped
    "3" can be confidently misread as "5", and a wrong-but-in-range read
    will NOT be caught by the VALID_ITEM_NUMBERS sanity clamp below, since
    the misread digit is still a plausible item number. This function
    returns None (triggering the sequential-numbering fallback, which
    does log a warning) whenever it can't find a clean, isolated digit,
    but a confident wrong read cannot be distinguished from a correct one
    without a human glancing at the page. Treat the numbering as
    best-effort and spot-check the --debug output on a real batch before
    trusting it unattended.
    """
    if not HAVE_TESSERACT:
        return None

    h, w = gray.shape
    band_h = int(h * ITEM_NUMBER_BAND_HEIGHT_FRAC)
    band_w = int(w * ITEM_NUMBER_BAND_WIDTH_FRAC)

    y2 = solution_box.y
    y1 = max(0, y2 - band_h)
    x1 = 0
    x2 = min(w, band_w)
    if y2 <= y1:
        return None

    band = gray[y1:y2, x1:x2]
    band2x = cv2.resize(band, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)

    try:
        boxes_str = pytesseract.image_to_boxes(band2x, config="--psm 6")
    except Exception:
        boxes_str = ""

    hash_box = None
    for line in boxes_str.splitlines():
        parts = line.split()
        if len(parts) != 6:
            continue
        ch, left, bottom, right, top, _page = parts
        if ch == "#":
            hash_box = (int(left), int(bottom), int(right), int(top))
            break

    if hash_box is None:
        # Couldn't anchor on the label at all -- unreadable, fall back to
        # sequential numbering rather than guessing from an unanchored crop.
        return None

    left, bottom, right, top = hash_box
    band_h2x, band_w2x = band2x.shape
    # image_to_boxes coordinates are bottom-left-origin; convert to the
    # usual top-left-origin row range before slicing the array.
    img_top = band_h2x - top
    img_bottom = band_h2x - bottom
    pad_y = int((img_bottom - img_top) * 0.6)
    dy1 = max(0, img_top - pad_y)
    dy2 = min(band_h2x, img_bottom + pad_y)
    dx1 = right + 5
    dx2 = band_w2x
    if dx2 <= dx1 or dy2 <= dy1:
        return None

    digit_crop = band2x[dy1:dy2, dx1:dx2]
    digit_crop = _strip_underline(digit_crop)
    digit_crop = cv2.resize(digit_crop, None, fx=3.0, fy=3.0, interpolation=cv2.INTER_CUBIC)
    digit_crop = cv2.copyMakeBorder(digit_crop, 15, 15, 15, 15,
                                     cv2.BORDER_CONSTANT, value=255)

    config = "--psm 7 -c tessedit_char_whitelist=0123456789"
    try:
        text = pytesseract.image_to_string(digit_crop, config=config)
    except Exception:
        return None

    digits = re.findall(r"\d+", text)
    if not digits:
        return None
    try:
        value = int(digits[0])
    except ValueError:
        return None

    return value if value in VALID_ITEM_NUMBERS else None


@dataclass
class PageBoxes:
    left_solution: Optional[np.ndarray] = None
    right_solution: Optional[np.ndarray] = None
    answer: Optional[np.ndarray] = None
    left_empty: bool = True
    right_empty: bool = True
    answer_empty: bool = True
    item_number: Optional[int] = None
    debug_img: Optional[np.ndarray] = None


def make_debug_image(gray, solution_box, answer_box, divider_x,
                      left_empty, right_empty, answer_empty, item_number) -> np.ndarray:
    dbg = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    def draw_box(box, color, label_top, extra=""):
        if box is None:
            return
        cv2.rectangle(dbg, (box.x, box.y), (box.x2, box.y2), color, 3)
        cv2.putText(dbg, label_top + extra, (box.x + 5, max(20, box.y - 8)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)

    if solution_box is not None:
        draw_box(solution_box, (255, 0, 0), f"ITEM {item_number if item_number else '?'}")
        cv2.line(dbg, (divider_x, solution_box.y), (divider_x, solution_box.y2),
                 (0, 165, 255), 2)
        state_l = "EMPTY" if left_empty else "USED"
        state_r = "EMPTY" if right_empty else "USED"
        cv2.putText(dbg, f"SOL1 {state_l}",
                    (solution_box.x + 10, solution_box.y + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 128, 0), 2, cv2.LINE_AA)
        cv2.putText(dbg, f"SOL2 {state_r}",
                    (divider_x + 10, solution_box.y + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 128, 0), 2, cv2.LINE_AA)

    if answer_box is not None:
        state_a = "EMPTY" if answer_empty else "USED"
        draw_box(answer_box, (0, 0, 255), f"ANSWER {state_a}")

    return dbg


def process_page_gray(gray: np.ndarray, debug: bool = False,
                      use_ocr: bool = True) -> PageBoxes:
    """
    Run the full per-page pipeline on an already-loaded grayscale image
    (a cleaned page, e.g. downloaded from Drive and decoded with
    cv2.imdecode(..., IMREAD_GRAYSCALE)).

    Returns a PageBoxes with the solution/answer crops, which boxes are
    empty, and the OCR'd item number (None if unreadable or use_ocr is
    False -- the caller then falls back to sequential numbering).
    """
    gray = deskew_page(gray)

    solution_box, answer_box = find_form_boxes(gray)
    result = PageBoxes()

    if solution_box is None:
        if debug:
            result.debug_img = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        return result

    divider_x = find_vertical_divider(gray, solution_box)
    left_box = BoxRect(solution_box.x, solution_box.y,
                       divider_x - solution_box.x, solution_box.h)
    right_box = BoxRect(divider_x, solution_box.y,
                        solution_box.x2 - divider_x, solution_box.h)

    result.left_empty = is_box_empty(gray, left_box)
    result.right_empty = is_box_empty(gray, right_box)
    result.left_solution = crop_gray(gray, left_box)
    result.right_solution = crop_gray(gray, right_box)

    if answer_box is not None:
        result.answer_empty = is_box_empty(gray, answer_box)
        result.answer = crop_gray(gray, answer_box)
    else:
        result.answer_empty = True

    result.item_number = ocr_item_number(gray, solution_box) if use_ocr else None

    if debug:
        result.debug_img = make_debug_image(
            gray, solution_box, answer_box, divider_x,
            result.left_empty, result.right_empty, result.answer_empty,
            result.item_number
        )

    return result
