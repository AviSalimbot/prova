"""Retraining API. Implements the top half of Figure 11: Retraining Trigger
(label accumulation or accuracy drift) -> Researcher Authorization -> Retrain
Classification Layer -> Evaluate on Regression Slice -> Meets Promotion
Criteria? The actual retrain job should run out-of-process (e.g. a Colab /
CI job) and call back into /model-versions to register the candidate."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter

from app.models.schemas import RetrainingCycleRequest
from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/retraining-cycles", tags=["retraining"])


@router.post("")
def trigger_retraining(request: RetrainingCycleRequest):
    """Records Researcher Authorization for a retraining cycle. Retraining
    applies to the classification layer only — the adjudicated
    gold-standard labels are error-category labels, not corrected
    transcriptions, so they supervise BERT, not TrOCR."""
    db = get_firestore_client()
    cycle_id = str(uuid.uuid4())

    cycle = {
        "trigger_condition": request.trigger_condition,
        "authorized_by": request.authorized_by,
        "training_manifest_id": "",  # TODO: filled in once the training job starts
        "candidate_version_id": "",  # TODO: filled in once the candidate is registered
        "outcome": "pending",
        "created_at": datetime.now(timezone.utc),
    }
    db.collection(FirestorePaths.RETRAINING_CYCLES).document(cycle_id).set(cycle)

    # TODO: enqueue the actual retraining job (Colab notebook / CI pipeline)
    # here. It should fine-tune on (error corpus + released adjudicated
    # labels), evaluate on the fixed regression slice (never released for
    # retraining), register a candidate ModelVersion, then PATCH this
    # cycle's candidate_version_id and outcome.

    return {"cycle_id": cycle_id, **cycle}
