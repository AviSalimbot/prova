"""Model registry API. Backs the Administration > Models tab and the
promotion criteria decision in Figure 11 ("Meets Promotion Criteria?")."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/model-versions", tags=["model-versions"])


@router.post("/{version_id}/promote")
def promote_version(version_id: str):
    """Manual override / confirmation path for Figure 11's "Promote
    Candidate" box. In the automated path this is called by the retraining
    cycle once it verifies: no degradation, McNemar significance, threshold met."""
    db = get_firestore_client()
    ref = db.collection(FirestorePaths.MODEL_VERSIONS).document(version_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Model version not found")

    from datetime import datetime, timezone

    ref.update({"status": "promoted", "promoted_at": datetime.now(timezone.utc)})
    return {"version_id": version_id, "status": "promoted"}


@router.post("/{version_id}/reject")
def reject_version(version_id: str):
    db = get_firestore_client()
    ref = db.collection(FirestorePaths.MODEL_VERSIONS).document(version_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Model version not found")

    ref.update({"status": "rejected"})
    return {"version_id": version_id, "status": "rejected"}
