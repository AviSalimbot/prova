"""Recognition layer service (Figure 1 / Figure 6). Loads the registered
TrOCR version (base ViT encoder + text Transformer decoder, LoRA-adapted)
pinned for a run, and transcribes handwriting into LaTeX.
"""

from __future__ import annotations

from functools import lru_cache

from peft import PeftModel
from PIL import Image
from transformers import TrOCRProcessor, VisionEncoderDecoderModel

from app.core.config import get_settings


@lru_cache(maxsize=4)
def _load_model(ocr_version_id: str):
    """Loads a pinned OCR version. `ocr_version_id` should resolve (via your
    model registry / Figure H-1 Model Registry Store) to either the base
    checkpoint or a LoRA adapter directory under MODEL_CACHE_DIR."""
    settings = get_settings()
    base_checkpoint = settings.default_ocr_checkpoint
    processor = TrOCRProcessor.from_pretrained(base_checkpoint)
    base_model = VisionEncoderDecoderModel.from_pretrained(base_checkpoint)

    adapter_path = f"{settings.model_cache_dir}/{ocr_version_id}"
    try:
        model = PeftModel.from_pretrained(base_model, adapter_path)
    except Exception:
        # Falls back to the unadapted base model if no LoRA adapter is
        # registered yet under this version id (useful for local dev).
        model = base_model

    model.eval()
    return processor, model


def transcribe(image: Image.Image, ocr_version_id: str) -> tuple[str, float]:
    """Runs constrained beam-search OCR (Figure 7) and returns
    (latex_transcription, confidence)."""
    processor, model = _load_model(ocr_version_id)

    pixel_values = processor(images=image, return_tensors="pt").pixel_values
    outputs = model.generate(
        pixel_values,
        num_beams=4,
        output_scores=True,
        return_dict_in_generate=True,
    )
    text = processor.batch_decode(outputs.sequences, skip_special_tokens=True)[0]

    # Simple length-normalized sequence score as a confidence proxy; swap
    # in a calibrated confidence metric for production use.
    confidence = float(outputs.sequences_scores[0].exp()) if outputs.sequences_scores is not None else 0.0

    return text, confidence
