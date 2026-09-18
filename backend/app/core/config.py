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

    # Drive root folder IDs for the Raw -> Cleaned pipeline (must match
    # DriveImportService._rootFolderIds on the Flutter side)
    drive_raw_root_folder_id: str = "1ylUs0CO615F0XaM4C2Kp91r117xZ3PhC"
    drive_cleaned_root_folder_id: str = "14gWHkrzUUhTU2eR_00P3f9k1Zghl6W0X"
    drive_cropped_root_folder_id: str = "15vsMICDGFpvxH9sGDBvdXhcuioBYBeJO"

    cors_allow_origins: list[str] = ["http://localhost:*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()