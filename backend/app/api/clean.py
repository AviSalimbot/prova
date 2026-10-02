"""Raw -> Cleaned worksheet scan pipeline, triggered from the Activity
Info screen's "Clean & upload" button (Flutter: CleanJobService).

Uploads use the SIGNED-IN USER's own Drive OAuth token (forwarded via
the X-Drive-Access-Token header), not the backend's service account —
service accounts have no Drive storage quota of their own. See
drive_client.get_drive_service_for_user_token for details.
"""

import re
import traceback

import cv2
import numpy as np
from fastapi import APIRouter, Depends, Header, HTTPException
from google.cloud.firestore import DELETE_FIELD, SERVER_TIMESTAMP, Increment
from pydantic import BaseModel

from app.api.deps import require_active_user
from app.core.config import get_settings
from app.preprocessing.worksheet_cleaning import clean_page
from app.services import drive_client
from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/clean", tags=["clean"])

_PAGE_NAME_RE = re.compile(r"^(\d+)\.\w+$")


class CleanExamRequest(BaseModel):
    exam_id: str
    exam_name: str


def _sanitize_for_id(value: str) -> str:
    return re.sub(r"[/\\]", "_", value)


def _decode_image(data: bytes) -> np.ndarray:
    arr = np.frombuffer(data, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image")
    return img


def _encode_png(img: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", img)
    if not ok:
        raise ValueError("Could not encode cleaned image")
    return buf.tobytes()


@router.post("/exam")
def clean_exam(
    body: CleanExamRequest,
    uid: str = Depends(require_active_user),
    x_drive_access_token: str = Header(...),
):
    settings = get_settings()
    db = get_firestore_client()
    exam_ref = db.collection(FirestorePaths.EXAMS).document(body.exam_id)

    # cleanedPageCount is reset to 0 (not left at whatever a previous run
    # left it at) and cleanStartedAt is set fresh, so the Flutter side's
    # cleanProgress/estimatedCleanRemaining getters -- which read both
    # live via examsStreamProvider -- report accurately from page one
    # instead of carrying over a stale value or a stale start time.
    exam_ref.update(
        {
            "cleanStatus": "processing",
            "cleanError": DELETE_FIELD,
            "cleanedPageCount": 0,
            "cleanStartedAt": SERVER_TIMESTAMP,
            "updatedAt": SERVER_TIMESTAMP,
        }
    )

    try:
        cleaned_count = _run_clean_job(
            db, settings, body.exam_id, body.exam_name, x_drive_access_token
        )
        exam_ref.update(
            {
                "cleanStatus": "ready",
                "cleanedPageCount": cleaned_count,
                "cleanedAt": SERVER_TIMESTAMP,
                "updatedAt": SERVER_TIMESTAMP,
            }
        )
        return {"ok": True, "cleanedPageCount": cleaned_count}
    except Exception as e:
        traceback.print_exc()
        exam_ref.update(
            {
                "cleanStatus": "failed",
                "cleanError": str(e),
                "updatedAt": SERVER_TIMESTAMP,
            }
        )
        raise HTTPException(status_code=500, detail=str(e))


def _fetch_already_cleaned_page_ids(db, exam_id: str) -> set:
    """Returns the set of page doc IDs that already have a cleanedFileId
    from a previous run of this job. Fetched once, up front, as a single
    query rather than a per-page .get() -- cheaper, and it's what makes
    the per-page skip check below a plain in-memory lookup.

    This is what makes re-clicking "Clean" after a partial failure safe:
    Drive uploads aren't idempotent the way the Firestore page-doc write
    is, so re-processing an already-cleaned page would leave a duplicate,
    orphaned file sitting in the Cleaned Drive folder alongside the one
    from the successful run.
    """
    docs = (
        db.collection(FirestorePaths.PAGES)
        .where("examId", "==", exam_id)
        .stream()
    )
    return {doc.id for doc in docs if (doc.to_dict() or {}).get("cleanedFileId")}


def _run_clean_job(
    db, settings, exam_id: str, exam_name: str, drive_access_token: str
) -> int:
    exam_ref = db.collection(FirestorePaths.EXAMS).document(exam_id)
    service = drive_client.get_drive_service_for_user_token(drive_access_token)

    raw_exam_folder = drive_client.find_child_folder(
        service, settings.drive_raw_root_folder_id, exam_name
    )
    if raw_exam_folder is None:
        raise ValueError(f"No Raw folder found for exam '{exam_name}'")

    cleaned_exam_folder_id = drive_client.find_or_create_child_folder(
        service, settings.drive_cleaned_root_folder_id, exam_name
    )

    participant_folders = drive_client.list_child_folders(
        service, raw_exam_folder["id"]
    )

    already_cleaned_page_ids = _fetch_already_cleaned_page_ids(db, exam_id)

    batch = db.batch()
    writes_in_batch = 0
    total_cleaned = 0

    def commit_if_needed():
        nonlocal batch, writes_in_batch
        if writes_in_batch >= 400:
            batch.commit()
            batch = db.batch()
            writes_in_batch = 0

    for folder in participant_folders:
        code = folder["name"]
        participant_id = _sanitize_for_id(f"{exam_id}__{code}")

        cleaned_participant_folder_id = drive_client.find_or_create_child_folder(
            service, cleaned_exam_folder_id, code
        )

        raw_files = drive_client.list_child_files(service, folder["id"])

        for f in raw_files:
            match = _PAGE_NAME_RE.match(f["name"])
            if not match:
                continue
            page_number = int(match.group(1))
            page_id = f"{participant_id}__{page_number}"

            if page_id in already_cleaned_page_ids:
                # Already cleaned and uploaded by a previous run -- skip
                # the Drive download/clean/upload entirely and just
                # count it, so a resumed job's progress bar still
                # reflects the TOTAL page count (matching pageCount),
                # not only the pages this particular run had to redo.
                total_cleaned += 1
                exam_ref.update(
                    {"cleanedPageCount": Increment(1), "updatedAt": SERVER_TIMESTAMP}
                )
                continue

            raw_bytes = drive_client.download_file_bytes(service, f["id"])
            img = _decode_image(raw_bytes)
            cleaned_img = clean_page(img)
            cleaned_bytes = _encode_png(cleaned_img)

            cleaned_file_id = drive_client.upload_file_bytes(
                service,
                cleaned_participant_folder_id,
                f"{page_number}.png",
                cleaned_bytes,
                mime_type="image/png",
            )

            page_ref = db.collection(FirestorePaths.PAGES).document(page_id)
            batch.set(
                page_ref,
                {"cleanedFileId": cleaned_file_id, "updatedAt": SERVER_TIMESTAMP},
                merge=True,
            )
            writes_in_batch += 1
            commit_if_needed()
            total_cleaned += 1

            # Incremental progress write, separate from the batched page-doc
            # writes above: this is what makes cleanProgress/
            # estimatedCleanRemaining on the Flutter side move page-by-page
            # instead of jumping from 0 to 100 only once the whole job
            # finishes. Kept as its own single-field Increment() (not folded
            # into the batch) so a page-doc write and the progress counter
            # can never silently drift if one succeeds and the other fails.
            exam_ref.update(
                {"cleanedPageCount": Increment(1), "updatedAt": SERVER_TIMESTAMP}
            )

    if writes_in_batch > 0:
        batch.commit()

    return total_cleaned