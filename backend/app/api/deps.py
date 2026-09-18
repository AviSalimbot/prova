"""Shared FastAPI dependencies. Currently just auth — evaluation.py and
other routers don't use this yet (see their TODO comments), but new
routers that need to know who's calling (like clean.py) should use this
rather than reinventing the check."""

from typing import Optional

from fastapi import Header, HTTPException
from firebase_admin import auth as fb_auth

from app.services.firebase_client import get_firebase_app, get_firestore_client
from app.services.firestore_paths import FirestorePaths


def require_active_user(authorization: Optional[str] = Header(default=None)) -> str:
    """Verifies a Firebase ID token and checks users/{uid}.status == 'active',
    mirroring AuthRepository's gate on the Flutter side. Returns the uid."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    id_token = authorization[len("Bearer ") :]

    # Ensure the Firebase Admin app is initialized before verifying —
    # verify_id_token needs the default app to already exist, and unlike
    # get_firestore_client() this is the first Firebase call on some
    # request paths (e.g. a fresh server hitting /clean/exam first).
    get_firebase_app()

    try:
        decoded = fb_auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid ID token: {e}")

    uid = decoded["uid"]
    db = get_firestore_client()
    user_doc = db.collection(FirestorePaths.USERS).document(uid).get()
    data = user_doc.to_dict() or {}
    if not user_doc.exists or data.get("status", "").lower() != "active":
        raise HTTPException(status_code=403, detail="Account is not active")

    return uid