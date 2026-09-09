"""Runs API. Implements the Application Track Pipe-and-Filter model
(Figure 3): scanned page -> [preprocess] -> [OCR filter] -> [classifier
filter] -> per-item result sink, with both model versions pinned for the
life of the run (Figure H-6 sequence diagram)."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

import numpy as np
from fastapi import APIRouter, HTTPException
from PIL import Image

from app.classification.classification_algorithm import run_classification_algorithm
from app.models.schemas import RunCreateRequest, RunRecord
from app.ocr.recognition_algorithm import run_recognition_algorithm
from app.preprocessing.pipeline import run_pipeline
from app.services.firebase_client import get_firestore_client
from app.services.firestore_paths import FirestorePaths

router = APIRouter(prefix="/runs", tags=["runs"])


@router.post("", response_model=RunRecord)
def create_run(request: RunCreateRequest):
    """Configures and starts a pipeline run — pins the OCR + BERT version
    pair for its full duration (Note under Figure 3)."""
    db = get_firestore_client()
    run_id = str(uuid.uuid4())

    run = RunRecord(
        run_id=run_id,
        initiated_by="operator",  # TODO: pull from an auth dependency
        input_batch=f"{len(request.page_image_paths)} page(s)",
        confidence_threshold=request.confidence_threshold,
        data_separation=request.data_separation,
        status="pending",
        started_at=datetime.now(timezone.utc),
        config_snapshot=request.model_dump(),
        ocr_version_id=request.ocr_version_id,
        bert_version_id=request.bert_version_id,
    )
    db.collection(FirestorePaths.RUNS).document(run_id).set(run.model_dump())

    # NOTE: for a real deployment, hand this off to a background worker/queue
    # instead of blocking the request. Kept synchronous here for clarity.
    _execute_run(run)

    return run


def _execute_run(run: RunRecord) -> None:
    db = get_firestore_client()
    run_ref = db.collection(FirestorePaths.RUNS).document(run.run_id)
    run_ref.update({"status": "running"})

    try:
        for page_path in run.config_snapshot.get("page_image_paths", []):
            image = np.array(Image.open(page_path).convert("L"))
            item_id = str(uuid.uuid4())

            step_objects = run_recognition_algorithm(image, item_id, run.ocr_version_id)
            full_text = "\n".join(s.step_text for s in step_objects)

            outcome = run_classification_algorithm(
                item_id=item_id,
                solution_text=full_text,
                answer_text=full_text.splitlines()[-1] if full_text else "",
                bert_version_id=run.bert_version_id,
            )

            result_id = str(uuid.uuid4())
            db.collection(FirestorePaths.RESULTS).document(result_id).set(
                {
                    "run_id": run.run_id,
                    "item_id": item_id,
                    "latex_transcription": full_text,
                    "ocr_confidence": 1.0,  # TODO: propagate real OCR confidence
                    "predicted_label": outcome.predicted_label,
                    "class_probabilities": outcome.class_probabilities,
                    "flagged": outcome.routed_to_manual,
                    "flag_reason": "low_confidence" if outcome.routed_to_manual else "",
                }
            )

        run_ref.update({"status": "completed", "completed_at": datetime.now(timezone.utc)})
    except Exception as exc:  # noqa: BLE001
        run_ref.update({"status": "failed"})
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/{run_id}/status")
def get_run_status(run_id: str):
    db = get_firestore_client()
    doc = db.collection(FirestorePaths.RUNS).document(run_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Run not found")
    return doc.to_dict()
