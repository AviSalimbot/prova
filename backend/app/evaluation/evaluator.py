"""Evaluation service. Compares per-item results against gold-standard
labels (Figure 4), computes aggregate metrics (Figure 10: accuracy + Wilson
CI, per-class P/R/F1, confusion matrix), and decides whether the run meets
the minimum threshold for registration vs. diagnostic review.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from sklearn.metrics import (
    confusion_matrix as sk_confusion_matrix,
    f1_score,
    precision_recall_fscore_support,
)
from statsmodels.stats.proportion import proportion_confint

from app.classification.bert_service import ERROR_CATEGORIES


@dataclass
class EvaluationResult:
    accuracy: float
    confidence_interval: tuple[float, float]
    macro_f1: float
    weighted_f1: float
    category_frequency: dict[str, float]
    confusion: list[list[int]]
    per_class: dict[str, dict[str, float]] = field(default_factory=dict)
    meets_threshold: bool = False


def category_frequency(predicted_labels: list[str]) -> dict[str, float]:
    """Percentage of solutions assigned to each error category (Figure 4 output)."""
    total = len(predicted_labels) or 1
    return {cat: predicted_labels.count(cat) / total for cat in ERROR_CATEGORIES}


def evaluate(
    predicted_labels: list[str],
    gold_labels: list[str],
    minimum_accuracy_threshold: float = 0.70,
) -> EvaluationResult:
    """Compare predicted vs gold-standard (Figure 10: "Compare to Gold-standard")
    and compute aggregate metrics."""
    assert len(predicted_labels) == len(gold_labels), "predicted/gold length mismatch"

    correct = sum(p == g for p, g in zip(predicted_labels, gold_labels))
    n = len(gold_labels)
    accuracy = correct / n if n else 0.0

    # Wilson score interval — more reliable than the normal approximation
    # for the moderate sample sizes typical of a classroom validation slice.
    ci_low, ci_high = proportion_confint(correct, n, alpha=0.05, method="wilson") if n else (0.0, 0.0)

    precision, recall, f1, _support = precision_recall_fscore_support(
        gold_labels, predicted_labels, labels=ERROR_CATEGORIES, zero_division=0
    )
    per_class = {
        cat: {"precision": float(p), "recall": float(r), "f1": float(f)}
        for cat, p, r, f in zip(ERROR_CATEGORIES, precision, recall, f1)
    }

    macro_f1 = float(f1_score(gold_labels, predicted_labels, labels=ERROR_CATEGORIES, average="macro", zero_division=0))
    weighted_f1 = float(f1_score(gold_labels, predicted_labels, labels=ERROR_CATEGORIES, average="weighted", zero_division=0))

    confusion = sk_confusion_matrix(gold_labels, predicted_labels, labels=ERROR_CATEGORIES).tolist()

    return EvaluationResult(
        accuracy=accuracy,
        confidence_interval=(float(ci_low), float(ci_high)),
        macro_f1=macro_f1,
        weighted_f1=weighted_f1,
        category_frequency=category_frequency(predicted_labels),
        confusion=confusion,
        per_class=per_class,
        meets_threshold=accuracy >= minimum_accuracy_threshold,
    )
