"""Evaluation API. Pulls a run's per-item results + gold-standard labels,
runs the comparison (Figure 4), and registers a Report if the run meets the
minimum threshold, or flags it for diagnostic review otherwise (Figure 10)."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException

from app.evaluation.evaluator import evaluate
from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/evaluation", tags=["evaluation"])


@router.post("/{run_id}")
def evaluate_run(run_id: str, minimum_accuracy_threshold: float = 0.70):
    db = get_firestore_client()

    results = list(db.collection(FirestorePaths.RESULTS).where("run_id", "==", run_id).stream())
    if not results:
        raise HTTPException(status_code=404, detail="No results found for this run")

    predicted_labels: list[str] = []
    gold_labels: list[str] = []
    for doc in results:
        data = doc.to_dict()
        gold_doc = db.collection(FirestorePaths.GOLD_STANDARD_LABELS).document(data["item_id"]).get()
        if not gold_doc.exists:
            continue  # item not yet adjudicated — excluded from this evaluation slice
        predicted_labels.append(data["predicted_label"])
        gold_labels.append(gold_doc.to_dict()["final_label"])

    if not predicted_labels:
        raise HTTPException(status_code=409, detail="No adjudicated gold-standard labels yet for this run's items")

    outcome = evaluate(predicted_labels, gold_labels, minimum_accuracy_threshold)

    report_id = str(uuid.uuid4())
    report = {
        "run_id": run_id,
        "generated_by": "operator",  # TODO: pull from auth dependency
        "accuracy": outcome.accuracy,
        "confidence_interval": f"[{outcome.confidence_interval[0]:.3f}, {outcome.confidence_interval[1]:.3f}]",
        "macro_f1": outcome.macro_f1,
        "weighted_f1": outcome.weighted_f1,
        "cohens_kappa": 0.0,  # TODO: compute from the two annotators' raw labels, not gold vs predicted
        "category_frequency": outcome.category_frequency,
        "confusion_matrix": outcome.confusion,
        "generated_at": datetime.now(timezone.utc),
        "file_path": "",  # TODO: render + upload a PDF export, then set this
    }
    db.collection(FirestorePaths.REPORTS).document(report_id).set(report)

    return {
        "report_id": report_id,
        "meets_threshold": outcome.meets_threshold,
        **report,
    }
