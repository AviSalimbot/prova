"""Pydantic models mirroring Figure H-5 (ERD). These are the request/response
contracts for the API layer, and the shape the Firestore documents should
take (see app/services/firebase_client.py for how they get written)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class StepObject(BaseModel):
    """Output of the recognition algorithm (Figure 7) — one step of a
    solution, before classification."""

    item_id: str
    step_text: str
    is_bracket_graded: bool = False


class RunCreateRequest(BaseModel):
    ocr_version_id: str
    bert_version_id: str
    confidence_threshold: float = 0.65
    page_image_paths: list[str]
    data_separation: Literal["train", "validation"] = "validation"


class RunRecord(BaseModel):
    run_id: str
    initiated_by: str
    input_batch: str
    confidence_threshold: float
    data_separation: str
    status: Literal["pending", "running", "completed", "failed"]
    started_at: datetime | None = None
    completed_at: datetime | None = None
    config_snapshot: dict = Field(default_factory=dict)
    ocr_version_id: str
    bert_version_id: str


class ResultRecord(BaseModel):
    """Per-item result — the Pipe-and-Filter sink output (Figure 3)."""

    result_id: str
    run_id: str
    item_id: str
    latex_transcription: str
    ocr_confidence: float
    predicted_label: str
    class_probabilities: dict[str, float]
    flagged: bool = False
    flag_reason: str = ""


class AnnotatorLabelRecord(BaseModel):
    label_id: str
    item_id: str
    annotator_id: str
    label: str
    note: str = ""
    labeled_at: datetime | None = None
    revised_at: datetime | None = None


class GoldStandardLabelRecord(BaseModel):
    item_id: str
    adjudicated_by: str
    final_label: str
    resolution_source: Literal["agreement", "adjudication"]
    rationale: str = ""
    resolved_at: datetime | None = None


class ModelVersionRecord(BaseModel):
    version_id: str
    layer: Literal["recognition", "classification"]
    base_checkpoint: str
    adaptation_method: str
    training_manifest_id: str
    hyperparameters_json: dict = Field(default_factory=dict)
    promotion_metrics_json: dict = Field(default_factory=dict)
    status: Literal["candidate", "promoted", "rejected"] = "candidate"
    registered_at: datetime | None = None
    promoted_at: datetime | None = None


class ReportRecord(BaseModel):
    """Evaluation Report output (Figure 4 / Figure 10)."""

    report_id: str
    run_id: str
    generated_by: str
    accuracy: float
    confidence_interval: str  # Wilson CI, e.g. "[0.71, 0.79]"
    macro_f1: float
    weighted_f1: float
    cohens_kappa: float
    category_frequency: dict[str, float] = Field(default_factory=dict)
    confusion_matrix: list[list[int]] = Field(default_factory=list)
    generated_at: datetime | None = None
    file_path: str = ""


class RetrainingCycleRequest(BaseModel):
    trigger_condition: Literal["label_accumulation", "accuracy_drift"]
    authorized_by: str


class RetrainingCycleRecord(BaseModel):
    cycle_id: str
    trigger_condition: str
    authorized_by: str
    training_manifest_id: str
    candidate_version_id: str
    outcome: Literal["pending", "promoted", "rejected"] = "pending"
    created_at: datetime | None = None
