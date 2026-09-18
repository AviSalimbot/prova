"""Cleaned -> Cropped answer-sheet pipeline, triggered from the Activity
Info screen's "Crop" button (Flutter: CropJobService).

Mirrors clean.py's structure and auth/Drive-token handling exactly.
Only the "activity_v1" template (crop_answers.py's page layout) has a
working implementation right now -- activity_v2 and exam are rejected
with a 400 until their own box-detection logic exists.

Cropping reads its input from each participant's CLEANED Drive folder
(not Raw) -- see answer_cropping.py's module docstring, carried over
from crop_answers.py: this pipeline assumes shading-normalized,
thresholded, ink-on-white pages with red marks already removed, which
is exactly clean.py's output, not a raw phone photo.
"""

import re
import traceback
from typing import Literal

import cv2
import numpy as np
from fastapi import APIRouter, Depends, Header, HTTPException
from google.cloud.firestore import DELETE_FIELD, SERVER_TIMESTAMP, Increment
from pydantic import BaseModel

from app.api.deps import require_active_user
from app.core.config import get_settings
from app.preprocessing.answer_cropping import process_page_gray
from app.services import drive_client
from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/crop", tags=["crop"])

_PAGE_NAME_RE = re.compile(r"^(\d+)\.\w+$")

# Keep in sync with CropTemplate.raw on the Flutter side
# (lib/features/assessments/domain/assessment.dart).
_IMPLEMENTED_TEMPLATES = {"activity_v1"}


class CropExamRequest(BaseModel):
    exam_id: str
    exam_name: str
    template: Literal["activity_v1", "activity_v2", "exam"]


def _sanitize_for_id(value: str) -> str:
    return re.sub(r"[/\\]", "_", value)


def _decode_gray(data: bytes) -> np.ndarray:
    arr = np.frombuffer(data, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError("Could not decode image")
    return img


def _encode_png(img: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", img)
    if not ok:
        raise ValueError("Could not encode cropped image")
    return buf.tobytes()


@router.post("/exam")
def crop_exam(
    body: CropExamRequest,
    uid: str = Depends(require_active_user),
    x_drive_access_token: str = Header(...),
):
    if body.template not in _IMPLEMENTED_TEMPLATES:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cropping template '{body.template}' is not implemented yet "
                f"-- only {sorted(_IMPLEMENTED_TEMPLATES)} are supported."
            ),
        )

    settings = get_settings()
    db = get_firestore_client()
    exam_ref = db.collection(FirestorePaths.EXAMS).document(body.exam_id)

    exam_data = (exam_ref.get()).to_dict() or {}
    if exam_data.get("cleanStatus") != "ready":
        # Mirrors the Flutter-side gate (croppedReady/cleanedReady) but
        # enforced server-side -- the client gate is only a UX
        # convenience and shouldn't be trusted on its own.
        raise HTTPException(
            status_code=409,
            detail="Exam must be cleaned (cleanStatus == 'ready') before cropping.",
        )

    exam_ref.update(
        {
            "cropStatus": "processing",
            "cropError": DELETE_FIELD,
            "croppedPageCount": 0,
            "cropStartedAt": SERVER_TIMESTAMP,
            "cropTemplate": body.template,
            "updatedAt": SERVER_TIMESTAMP,
        }
    )

    try:
        cropped_count = _run_crop_job(
            db, settings, body.exam_id, body.exam_name, x_drive_access_token
        )
        exam_ref.update(
            {
                "cropStatus": "ready",
                "croppedPageCount": cropped_count,
                "croppedAt": SERVER_TIMESTAMP,
                "updatedAt": SERVER_TIMESTAMP,
            }
        )
        return {"ok": True, "croppedPageCount": cropped_count}
    except Exception as e:
        traceback.print_exc()
        exam_ref.update(
            {
                "cropStatus": "failed",
                "cropError": str(e),
                "updatedAt": SERVER_TIMESTAMP,
            }
        )
        raise HTTPException(status_code=500, detail=str(e))


def _run_crop_job(
    db, settings, exam_id: str, exam_name: str, drive_access_token: str
) -> int:
    """
    Walks each participant's CLEANED folder page-by-page (mirroring
    clean.py's Raw walk), running process_page_gray on each, and uploads
    any non-empty solution/answer crops to a parallel Cropped Drive tree.

    Firestore write shape: unlike clean.py -- where each page maps to
    exactly one cleanedFileId -- an "item" here can span multiple pages,
    and a single page can produce zero, one, or several crop images. So
    results are written to a new `croppedItems/{participantId}__{item}`
    doc (solutionFileIds, answerFileId) rather than forced onto the
    per-page AssessmentPage.croppedFileId field the Raw/Cleaned variants
    use. See the flag at the end of this response -- the existing
    PagesGrid/PagePreviewDialog preview flow doesn't know how to browse
    this yet.
    """
    exam_ref = db.collection(FirestorePaths.EXAMS).document(exam_id)
    service = drive_client.get_drive_service_for_user_token(drive_access_token)

    cleaned_exam_folder = drive_client.find_child_folder(
        service, settings.drive_cleaned_root_folder_id, exam_name
    )
    if cleaned_exam_folder is None:
        raise ValueError(f"No Cleaned folder found for exam '{exam_name}'")

    cropped_exam_folder_id = drive_client.find_or_create_child_folder(
        service, settings.drive_cropped_root_folder_id, exam_name
    )

    participant_folders = drive_client.list_child_folders(
        service, cleaned_exam_folder["id"]
    )

    total_pages_processed = 0

    for folder in participant_folders:
        code = folder["name"]
        participant_id = _sanitize_for_id(f"{exam_id}__{code}")

        cropped_participant_folder_id = drive_client.find_or_create_child_folder(
            service, cropped_exam_folder_id, code
        )

        cleaned_files = sorted(
            drive_client.list_child_files(service, folder["id"]),
            key=lambda f: (
                int(m.group(1)) if (m := _PAGE_NAME_RE.match(f["name"])) else 0
            ),
        )

        item_solution_ids: dict[int, list[str]] = {}
        item_answer_ids: dict[int, str] = {}
        running_counter = 0

        for f in cleaned_files:
            match = _PAGE_NAME_RE.match(f["name"])
            if not match:
                continue

            cleaned_bytes = drive_client.download_file_bytes(service, f["id"])
            gray = _decode_gray(cleaned_bytes)
            page = process_page_gray(gray, use_ocr=True)

            total_pages_processed += 1
            # Same incremental-progress rationale as clean.py.
            exam_ref.update(
                {"croppedPageCount": Increment(1), "updatedAt": SERVER_TIMESTAMP}
            )

            page_is_blank = page.left_empty and page.right_empty and page.answer_empty
            if page_is_blank:
                continue

            if page.item_number is not None:
                item = page.item_number
                running_counter = max(running_counter, item)
            else:
                running_counter += 1
                item = running_counter

            for empty, crop in (
                (page.left_empty, page.left_solution),
                (page.right_empty, page.right_solution),
            ):
                if not empty and crop is not None:
                    idx = len(item_solution_ids.get(item, [])) + 1
                    file_id = drive_client.upload_file_bytes(
                        service,
                        cropped_participant_folder_id,
                        f"item{item}_solution{idx}.png",
                        _encode_png(crop),
                        mime_type="image/png",
                    )
                    item_solution_ids.setdefault(item, []).append(file_id)

            if not page.answer_empty and page.answer is not None:
                file_id = drive_client.upload_file_bytes(
                    service,
                    cropped_participant_folder_id,
                    f"item{item}_answer.png",
                    _encode_png(page.answer),
                    mime_type="image/png",
                )
                item_answer_ids[item] = file_id

        for item in sorted(item_solution_ids.keys() | item_answer_ids.keys()):
            item_ref = db.collection(FirestorePaths.CROPPED_ITEMS).document(
                f"{participant_id}__{item}"
            )
            item_ref.set(
                {
                    "examId": exam_id,
                    "participantId": participant_id,
                    "item": item,
                    "solutionFileIds": item_solution_ids.get(item, []),
                    "answerFileId": item_answer_ids.get(item),
                    "updatedAt": SERVER_TIMESTAMP,
                },
                merge=True,
            )

    return total_pages_processed