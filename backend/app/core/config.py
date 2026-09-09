from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central config. Copy `.env.example` to `.env` and fill in real values —
    never commit `.env` or the service account key."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Firebase Admin SDK
    firebase_service_account_path: str = "serviceAccountKey.json"
    firebase_storage_bucket: str = "prova-REPLACE_ME.appspot.com"

    # Model registry defaults (overridden per-run by the pinned version pair)
    default_ocr_checkpoint: str = "microsoft/trocr-base-handwritten"
    default_bert_checkpoint: str = "bert-base-multilingual-cased"

    # Classification confidence threshold (Figure 9)
    classification_confidence_threshold: float = 0.65

    # Where LoRA/fine-tuned weights are cached locally after pulling from
    # Google Drive / HF Model Hub (Figure H-1 hardware row)
    model_cache_dir: str = "./model_cache"

    cors_allow_origins: list[str] = ["http://localhost:*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
