"""Reset an exam's CLEAN state in Firestore so Clean & upload can be re-run.

Deleting the Cleaned folders in Drive does not touch Firestore. After a
clean run, Firestore holds:
  - exams/{examId}: cleanStatus='ready', cleanedPageCount, cleanStartedAt,
    cleanedAt (and cleanError if it ever failed)
  - pages/*: a cleanedFileId on every page (pointing at Drive files that
    no longer exist once you delete the Cleaned folders)

This script resets both. Pages are matched by their examId field, which the
importer writes on every page doc.

Usage (from the backend folder, venv active):
    python scripts/reset_clean.py "Activity 1.1"                       # preview only
    python scripts/reset_clean.py "Activity 1.1" --yes                 # apply
    python scripts/reset_clean.py "Activity 1.1" --yes --include-crop  # also reset crop

--include-crop additionally resets cropStatus/counters on the exam and deletes
its croppedItems docs. Use it if you cropped before and want to redo that too
(crop reads from the Cleaned folder, so old crops are stale after a re-clean).
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from google.cloud.firestore import DELETE_FIELD, SERVER_TIMESTAMP  # noqa: E402

from app.services.firebase_client import get_firestore_client  # noqa: E402

CROPPED_ITEMS = "croppedItems"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exam_name", help='Exam name exactly as in the app, e.g. "Activity 1.1"')
    ap.add_argument("--yes", action="store_true", help="Actually apply (default is preview only)")
    ap.add_argument("--include-crop", action="store_true", help="Also reset crop state + delete croppedItems")
    args = ap.parse_args()

    db = get_firestore_client()

    exams = list(db.collection("exams").where("name", "==", args.exam_name).stream())
    if not exams:
        sys.exit(f'No exam named "{args.exam_name}" found.')
    if len(exams) > 1:
        sys.exit(f'{len(exams)} exams are named "{args.exam_name}"; resolve the duplicate first.')

    exam = exams[0]
    exam_id = exam.id
    data = exam.to_dict() or {}
    print(("APPLYING" if args.yes else "PREVIEW (nothing changed; add --yes to apply)")
          + f"\nexam: {args.exam_name} ({exam_id})")
    print(f"current cleanStatus={data.get('cleanStatus')} cleanedPageCount={data.get('cleanedPageCount')}"
          f" cropStatus={data.get('cropStatus')} croppedPageCount={data.get('croppedPageCount')}")

    # --- pages: drop cleanedFileId ---
    pages = list(db.collection("pages").where("examId", "==", exam_id).stream())
    with_cleaned = [p for p in pages if (p.to_dict() or {}).get("cleanedFileId")]
    print(f"pages for this exam: {len(pages)}, with cleanedFileId: {len(with_cleaned)}")

    if args.yes:
        for i in range(0, len(with_cleaned), 400):
            batch = db.batch()
            for p in with_cleaned[i : i + 400]:
                batch.update(p.reference, {"cleanedFileId": DELETE_FIELD})
            batch.commit()

    # --- exam doc ---
    exam_updates = {
        "cleanStatus": "not_started",
        "cleanedPageCount": 0,
        "cleanStartedAt": DELETE_FIELD,
        "cleanedAt": DELETE_FIELD,
        "cleanError": DELETE_FIELD,
        "updatedAt": SERVER_TIMESTAMP,
    }

    if args.include_crop:
        items = list(db.collection(CROPPED_ITEMS).where("examId", "==", exam_id).stream())
        print(f"croppedItems docs: {len(items)}")
        if args.yes:
            for i in range(0, len(items), 400):
                batch = db.batch()
                for d in items[i : i + 400]:
                    batch.delete(d.reference)
                batch.commit()
        exam_updates.update(
            {
                "cropStatus": "not_started",
                "croppedPageCount": 0,
                "cropStartedAt": DELETE_FIELD,
                "croppedAt": DELETE_FIELD,
                "cropError": DELETE_FIELD,
                "cropTemplate": DELETE_FIELD,
            }
        )

    if args.yes:
        exam.reference.update(exam_updates)
        print("Done. Reload the app; the Clean & upload button should be back.")
    else:
        print("Preview only. Re-run with --yes to apply.")


if __name__ == "__main__":
    main()
