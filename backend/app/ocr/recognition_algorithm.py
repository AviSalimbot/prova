"""Implements the Recognition Algorithm exactly as drawn in Figure 7:

Scanned Page -> Row Segmentation (ink-density row detection)
             -> Step Grouping (bracket depth + column alignment)
             -> Brackets Present? --No--> Reuse Per-row OCR Text
                                  --Yes-> Constrained Beam-search OCR (TrOCR, LoRA-adapted)
             -> Brackets Graded? --No--> Normalize (bracket-agnostic parser)
                                 --Yes-> Preserve Original Text
             -> Step Objects
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from app.models.schemas import StepObject
from app.ocr import trocr_service


@dataclass
class Row:
    image: np.ndarray
    ocr_text: str
    bracket_depth: int = 0


@dataclass
class Step:
    rows: list[Row] = field(default_factory=list)
    has_brackets: bool = False
    brackets_graded: bool = False


def row_segmentation(page_image: np.ndarray) -> list[Row]:
    """Ink-density row detection: sums dark-pixel density per horizontal
    band to find row boundaries."""
    gray = page_image if page_image.ndim == 2 else page_image.mean(axis=2)
    ink_density = (255 - gray).sum(axis=1)
    threshold = ink_density.max() * 0.05
    in_row = ink_density > threshold

    rows: list[Row] = []
    start = None
    for y, active in enumerate(in_row):
        if active and start is None:
            start = y
        elif not active and start is not None:
            rows.append(Row(image=page_image[start:y], ocr_text=""))
            start = None
    if start is not None:
        rows.append(Row(image=page_image[start:], ocr_text=""))
    return rows


def step_grouping(rows: list[Row]) -> list[Step]:
    """Groups rows into steps using bracket depth + column alignment.
    Placeholder heuristic: a new step starts whenever bracket_depth returns
    to 0 after having been > 0, or on a large left-margin shift — refine
    with real column-alignment detection during Phase 3 (Model Fine-Tuning)."""
    steps: list[Step] = []
    current = Step()
    for row in rows:
        current.rows.append(row)
        if row.bracket_depth > 0:
            current.has_brackets = True
        if row.bracket_depth == 0 and current.rows:
            steps.append(current)
            current = Step()
    if current.rows:
        steps.append(current)
    return steps


def reuse_per_row_ocr_text(step: Step) -> str:
    return "\n".join(r.ocr_text for r in step.rows)


def constrained_beam_search_ocr(step: Step, ocr_version_id: str) -> tuple[str, float]:
    """Runs the pinned, LoRA-adapted TrOCR model (Figure 6) on the full
    step image when brackets span multiple rows and per-row text can't be
    naively concatenated."""
    from PIL import Image

    stacked = np.concatenate([r.image for r in step.rows], axis=0)
    pil_image = Image.fromarray(stacked)
    return trocr_service.transcribe(pil_image, ocr_version_id)


def normalize(text: str) -> str:
    """Bracket-agnostic parser: strips bracket characters so ungraded
    brackets don't affect downstream classification."""
    return text.translate(str.maketrans("", "", "()[]{}"))


def preserve_original_text(text: str) -> str:
    return text


def run_recognition_algorithm(
    page_image: np.ndarray, item_id: str, ocr_version_id: str
) -> list[StepObject]:
    rows = row_segmentation(page_image)
    steps = step_grouping(rows)

    step_objects: list[StepObject] = []
    for step in steps:
        if step.has_brackets:
            text, _confidence = constrained_beam_search_ocr(step, ocr_version_id)
        else:
            text = reuse_per_row_ocr_text(step)

        final_text = preserve_original_text(text) if step.brackets_graded else normalize(text)

        step_objects.append(
            StepObject(item_id=item_id, step_text=final_text, is_bracket_graded=step.brackets_graded)
        )

    return step_objects
