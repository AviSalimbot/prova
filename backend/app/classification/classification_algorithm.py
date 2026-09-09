"""Implements the Classification Algorithm exactly as drawn in Figure 9:

Step Objects -> Empty Solution Box? --Yes--> Tag No Solution -> BERT (answer only)
                                    --No---> BERT classification (full solution + answer)
             -> Confidence >= 0.65? --Yes--> Automated Label
                                    --No---> Manual Classification (expert annotator)
             -> [No-solution items always go to Manual Classification too]
             -> Disagreement (automated vs manual)? --No--> Classified Item
                                                     --Yes-> Adjudication -> Classified Item
"""

from __future__ import annotations

from dataclasses import dataclass

from app.classification import bert_service
from app.core.config import get_settings


@dataclass
class ClassificationOutcome:
    item_id: str
    predicted_label: str
    class_probabilities: dict[str, float]
    confidence: float
    routed_to_manual: bool
    no_solution: bool


def run_classification_algorithm(
    item_id: str,
    solution_text: str,
    answer_text: str,
    bert_version_id: str,
) -> ClassificationOutcome:
    settings = get_settings()
    no_solution = solution_text.strip() == ""

    text_for_model = answer_text if no_solution else f"{solution_text}\n{answer_text}"
    predicted_label, class_probabilities = bert_service.classify(text_for_model, bert_version_id)
    confidence = class_probabilities[predicted_label]

    routed_to_manual = no_solution or confidence < settings.classification_confidence_threshold

    return ClassificationOutcome(
        item_id=item_id,
        predicted_label=predicted_label,
        class_probabilities=class_probabilities,
        confidence=confidence,
        routed_to_manual=routed_to_manual,
        no_solution=no_solution,
    )


def resolve_with_manual_label(
    outcome: ClassificationOutcome, manual_label: str
) -> tuple[str, bool]:
    """Compares the automated prediction against the manual classification.
    Returns (final_label, needs_adjudication). If they agree, the manual
    label stands; if they disagree, the caller must route to the
    adjudication protocol (Appendix I, Section 4.6) and use its resolved
    label as the classified item."""
    agrees = manual_label == outcome.predicted_label
    return manual_label, not agrees
