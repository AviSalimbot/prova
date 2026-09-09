"""Firebase Admin SDK wiring — the backend's trusted path into Firestore +
Storage (Figure H-1: "Firebase" box, "Firestore + Storage, Admin auth")."""

from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore, storage

from app.core.config import get_settings


@lru_cache
def get_firebase_app() -> firebase_admin.App:
    settings = get_settings()
    cred = credentials.Certificate(settings.firebase_service_account_path)
    return firebase_admin.initialize_app(
        cred, {"storageBucket": settings.firebase_storage_bucket}
    )


def get_firestore_client():
    get_firebase_app()
    return firestore.client()


def get_storage_bucket():
    get_firebase_app()
    return storage.bucket()
