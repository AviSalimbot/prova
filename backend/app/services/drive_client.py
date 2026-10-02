"""Google Drive access for the backend. Two auth modes are supported:

- Service-account access (get_drive_service): used for read-only
  operations like listing/finding folders during import.
- User-token access (get_drive_service_for_user_token): used for
  UPLOADS in the clean-job pipeline. Service accounts have zero Drive
  storage quota of their own — any file they create fails with a 403
  storageQuotaExceeded — so uploads must be made under the signed-in
  user's own OAuth token instead, forwarded from the Flutter client.
"""

import io
import socket
import time
from functools import lru_cache
from typing import Optional

import httplib2
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials as UserCredentials
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload, MediaIoBaseUpload

from app.core.config import get_settings

_FOLDER_MIME = "application/vnd.google-apps.folder"
_SCOPES = ["https://www.googleapis.com/auth/drive"]

# Applied to every Drive HTTP request (list/create/download/upload).
# Without this, a stalled connection has no explicit bound and can hang
# on whatever ambient socket timeout happens to be in effect process-wide
# -- which is exactly what produced the bare `socket.timeout` deep in
# httplib2 rather than a clean, fast failure. 60s is generous for a
# single list/download/upload call; if Drive is actually unresponsive
# for that long, failing fast and retrying (see _with_retries) is far
# better than sitting on one dead socket indefinitely.
_REQUEST_TIMEOUT_SECONDS = 60

# A job like clean.py's walks hundreds of pages, making many hundreds of
# individual HTTP requests to Drive. Without retries, a single dropped
# connection or momentary 5xx from Google anywhere in that sequence
# kills the entire job -- which, for a long exam, can mean losing most
# of an hour of real work over one transient blip. Retries are only
# attempted for errors that are plausibly transient; a 403/404 from a
# genuinely missing folder will never succeed just by trying again, so
# those are deliberately NOT retried and fail immediately instead.
_MAX_RETRIES = 4
_RETRY_BASE_DELAY_SECONDS = 2.0


def _is_retryable(exc: Exception) -> bool:
    if isinstance(exc, (socket.timeout, TimeoutError, ConnectionError)):
        return True
    if isinstance(exc, HttpError):
        status = getattr(exc.resp, "status", None)
        return status in (429, 500, 502, 503, 504)
    return False


def _with_retries(fn, *args, **kwargs):
    """Calls fn(*args, **kwargs), retrying with exponential backoff on
    transient network/HTTP errors. Re-raises immediately on anything
    that isn't plausibly transient, and re-raises the last error once
    retries are exhausted.
    """
    last_exc: Optional[Exception] = None
    for attempt in range(_MAX_RETRIES + 1):
        try:
            return fn(*args, **kwargs)
        except Exception as exc:
            if not _is_retryable(exc) or attempt == _MAX_RETRIES:
                raise
            last_exc = exc
            delay = _RETRY_BASE_DELAY_SECONDS * (2**attempt)
            print(
                f"[drive_client] transient error ({exc!r}) on attempt "
                f"{attempt + 1}/{_MAX_RETRIES + 1}, retrying in {delay:.0f}s"
            )
            time.sleep(delay)
    # Unreachable in practice -- the loop above always either returns or
    # raises -- but keeps this function's control flow explicit.
    raise last_exc  # type: ignore[misc]


def _authed_http(creds) -> AuthorizedHttp:
    # build() accepts EITHER credentials= OR http=, not both -- to set an
    # explicit timeout we have to construct the AuthorizedHttp wrapper
    # ourselves (what build(credentials=...) would otherwise do for us
    # internally, but with httplib2's default, unbounded timeout).
    return AuthorizedHttp(creds, http=httplib2.Http(timeout=_REQUEST_TIMEOUT_SECONDS))


@lru_cache
def get_drive_service():
    settings = get_settings()
    creds = service_account.Credentials.from_service_account_file(
        settings.firebase_service_account_path, scopes=_SCOPES
    )
    return build("drive", "v3", http=_authed_http(creds), cache_discovery=False)


def get_drive_service_for_user_token(access_token: str):
    """Builds a Drive service using the SIGNED-IN USER's own OAuth
    access token (forwarded from the Flutter client), instead of the
    backend's service account. Service accounts have zero Drive storage
    quota of their own, so any file they create fails with a 403
    storageQuotaExceeded — using the real user's token means uploaded
    files are owned by (and count against) that person's own quota,
    which is the only option available on a personal (non-Workspace)
    Google account.
    """
    creds = UserCredentials(token=access_token)
    return build("drive", "v3", http=_authed_http(creds), cache_discovery=False)


def find_child_folder(service, parent_id: str, name: str):
    escaped = name.replace("'", "\\'")

    def _call():
        return (
            service.files()
            .list(
                q=f"'{parent_id}' in parents and name = '{escaped}' "
                f"and mimeType = '{_FOLDER_MIME}' and trashed = false",
                fields="files(id, name)",
                pageSize=1,
            )
            .execute()
        )

    result = _with_retries(_call)
    files = result.get("files", [])
    return files[0] if files else None


def find_or_create_child_folder(service, parent_id: str, name: str) -> str:
    existing = find_child_folder(service, parent_id, name)
    if existing:
        return existing["id"]

    def _call():
        return (
            service.files()
            .create(
                body={"name": name, "mimeType": _FOLDER_MIME, "parents": [parent_id]},
                fields="id",
            )
            .execute()
        )

    created = _with_retries(_call)
    return created["id"]


def list_child_folders(service, parent_id: str):
    def _call():
        return (
            service.files()
            .list(
                q=f"'{parent_id}' in parents and mimeType = '{_FOLDER_MIME}' "
                f"and trashed = false",
                fields="files(id, name)",
                orderBy="name",
                pageSize=1000,
            )
            .execute()
        )

    result = _with_retries(_call)
    return result.get("files", [])


def list_child_files(service, parent_id: str):
    def _call():
        return (
            service.files()
            .list(
                q=f"'{parent_id}' in parents and trashed = false",
                fields="files(id, name)",
                pageSize=1000,
            )
            .execute()
        )

    result = _with_retries(_call)
    return result.get("files", [])


def download_file_bytes(service, file_id: str) -> bytes:
    def _call():
        # buf is created fresh inside _call, not outside it, so a retry
        # starts the download into a brand-new, empty buffer rather than
        # resuming (or double-writing) into one left partially filled by
        # a previous failed attempt.
        request = service.files().get_media(fileId=file_id)
        buf = io.BytesIO()
        downloader = MediaIoBaseDownload(buf, request)
        done = False
        while not done:
            _, done = downloader.next_chunk()
        return buf.getvalue()

    return _with_retries(_call)


def upload_file_bytes(
    service, parent_id: str, name: str, data: bytes, mime_type: str = "image/png"
) -> str:
    def _call():
        # Likewise, a fresh BytesIO(data) per attempt -- `data` itself is
        # just the original immutable bytes, so re-wrapping it is cheap
        # and safe to repeat on retry.
        media = MediaIoBaseUpload(io.BytesIO(data), mimetype=mime_type, resumable=False)
        created = (
            service.files()
            .create(body={"name": name, "parents": [parent_id]}, media_body=media, fields="id")
            .execute()
        )
        return created["id"]

    return _with_retries(_call)