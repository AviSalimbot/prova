"""Classification layer service (Figure 2 / Figure 8). Loads the registered
BERT version (fine-tuned on the Linear Algebra Error Corpus, optionally after
domain-adaptive MLM on AMPS) and classifies transcribed solutions into one
of the three cognitive error categories.
"""

from __future__ import annotations

from functools import lru_cache

import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer

from app.core.config import get_settings

# The three error categories the taxonomy in the proposal operationalizes
# for USC CS 3101N / MAT 1103 Linear Algebra content. Rename to match your
# finalized taxonomy from Appendix I.
ERROR_CATEGORIES = ["conceptual_error", "procedural_error", "no_error"]


@lru_cache(maxsize=4)
def _load_model(bert_version_id: str):
    settings = get_settings()
    base_checkpoint = settings.default_bert_checkpoint
    adapter_path = f"{settings.model_cache_dir}/{bert_version_id}"

    try:
        tokenizer = AutoTokenizer.from_pretrained(adapter_path)
        model = AutoModelForSequenceClassification.from_pretrained(adapter_path)
    except Exception:
        # Falls back to the un-fine-tuned base checkpoint for local dev.
        tokenizer = AutoTokenizer.from_pretrained(base_checkpoint)
        model = AutoModelForSequenceClassification.from_pretrained(
            base_checkpoint, num_labels=len(ERROR_CATEGORIES)
        )

    model.eval()
    return tokenizer, model


def classify(text: str, bert_version_id: str) -> tuple[str, dict[str, float]]:
    """Returns (predicted_label, class_probabilities)."""
    tokenizer, model = _load_model(bert_version_id)

    inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True)
    with torch.no_grad():
        logits = model(**inputs).logits
    probs = torch.softmax(logits, dim=-1).squeeze(0).tolist()

    class_probabilities = {cat: float(p) for cat, p in zip(ERROR_CATEGORIES, probs)}
    predicted_label = max(class_probabilities, key=class_probabilities.get)
    return predicted_label, class_probabilities
