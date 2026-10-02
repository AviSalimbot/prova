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

import io
import re
import traceback
from datetime import datetime, timedelta, timezone
from typing import Literal

import cv2
import numpy as np
from fastapi import APIRouter, Depends, Header, HTTPException
from google.cloud.firestore import DELETE_FIELD, SERVER_TIMESTAMP, Increment
from googleapiclient.http import MediaIoBaseUpload
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

# A crop job still marked 'processing' after this long is assumed to have
# died (server restart, laptop sleep) and no longer blocks a new run.
_STALE_JOB_AFTER = timedelta(hours=3)


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


def _item_folder_name(item: int) -> str:
    """Drive folder name for one item: 1 -> "N001"."""
    return f"N{item:03d}"


def _upload_or_replace(service, parent_id: str, name: str, data: bytes) -> str:
    """Upload a PNG into [parent_id], replacing a same-named file if one is
    already there (Drive otherwise happily keeps duplicates, which is how a
    re-run used to pile up copies)."""
    existing = [
        f
        for f in drive_client.list_child_files(service, parent_id)
        if f["name"] == name
    ]
    media = MediaIoBaseUpload(io.BytesIO(data), mimetype="image/png", resumable=False)
    if existing:
        service.files().update(
            fileId=existing[0]["id"], media_body=media, fields="id"
        ).execute()
        return existing[0]["id"]
    return drive_client.upload_file_bytes(
        service, parent_id, name, data, mime_type="image/png"
    )


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

    # Refuse to start a second crop while one is already running -- two jobs
    # share the same croppedPageCount counter (the popup could read
    # "530 / 372 pages") and would each write their own copy of every crop.
    if exam_data.get("cropStatus") == "processing":
        started = exam_data.get("cropStartedAt")
        is_stale = (
            isinstance(started, datetime)
            and datetime.now(timezone.utc) - started > _STALE_JOB_AFTER
        )
        if not is_stale:
            raise HTTPException(
                status_code=409,
                detail="A crop job is already running for this exam.",
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
        participant_ref = db.collection(FirestorePaths.PARTICIPANTS).document(
            participant_id
        )

        # Only participant-code folders; skips stray folders like
        # "review_headers" instead of treating them as participants.
        if not re.fullmatch(r"P\d{3}", code):
            continue

        cropped_participant_folder_id = drive_client.find_or_create_child_folder(
            service, cropped_exam_folder_id, code
        )

        # One cleaned file per page number. Drive allows several files with
        # the same name in a folder; without this each duplicate would be
        # cropped and counted again.
        cleaned_by_page: dict = {}
        for f in drive_client.list_child_files(service, folder["id"]):
            m = _PAGE_NAME_RE.match(f["name"])
            if m:
                cleaned_by_page.setdefault(int(m.group(1)), f)
        cleaned_files = [cleaned_by_page[n] for n in sorted(cleaned_by_page)]

        # Same assembly as crop_answers.py's process_student(): crops are
        # buffered per item while the pages are read in order, and only
        # written out once the whole participant is done, so solution
        # numbering (item2_solution1, item2_solution2, ...) and the
        # "later filled answer box wins" rule come out exactly the same.
        item_solutions: dict = {}
        item_answers: dict = {}
        running_counter = 0

        for f in cleaned_files:
            try:
                cleaned_bytes = drive_client.download_file_bytes(service, f["id"])
                gray = _decode_gray(cleaned_bytes)
                page = process_page_gray(gray, use_ocr=True)
            except Exception:
                # One unreadable page must not abort the whole exam (the
                # original script skips it with a warning too).
                traceback.print_exc()
                page = None

            total_pages_processed += 1
            # Same incremental-progress rationale as clean.py.
            exam_ref.update(
                {"croppedPageCount": Increment(1), "updatedAt": SERVER_TIMESTAMP}
            )

            if page is None:
                continue

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
                    item_solutions.setdefault(item, []).append(crop)

            if not page.answer_empty and page.answer is not None:
                item_answers[item] = page.answer

        # Clear this participant's previous item docs first, so a re-run
        # that numbers things differently doesn't leave stale ones behind.
        for old in (
            db.collection(FirestorePaths.CROPPED_ITEMS)
            .where("participantId", "==", participant_id)
            .stream()
        ):
            old.reference.delete()

        items = sorted(item_solutions.keys() | item_answers.keys())
        for item in items:
            label = _item_folder_name(item)
            item_folder_id = drive_client.find_or_create_child_folder(
                service, cropped_participant_folder_id, label
            )

            solution_ids = []
            for idx, crop in enumerate(item_solutions.get(item, []), start=1):
                solution_ids.append(
                    _upload_or_replace(
                        service,
                        item_folder_id,
                        f"item{item}_solution{idx}.png",
                        _encode_png(crop),
                    )
                )

            answer_id = None
            if item in item_answers:
                answer_id = _upload_or_replace(
                    service,
                    item_folder_id,
                    f"item{item}_answer.png",
                    _encode_png(item_answers[item]),
                )

            db.collection(FirestorePaths.CROPPED_ITEMS).document(
                f"{participant_id}__{item}"
            ).set(
                {
                    "examId": exam_id,
                    "participantId": participant_id,
                    "item": item,
                    "label": label,
                    "folderId": item_folder_id,
                    "solutionFileIds": solution_ids,
                    "answerFileId": answer_id,
                    "updatedAt": SERVER_TIMESTAMP,
                }
            )

        # Denormalized so the Cropped participant list can show
        # "N items" without a query per row.
        participant_ref.set(
            {"croppedItemCount": len(items), "updatedAt": SERVER_TIMESTAMP},
            merge=True,
        )

    return total_pages_processed