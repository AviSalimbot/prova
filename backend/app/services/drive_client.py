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
from functools import lru_cache

from google.oauth2 import service_account
from google.oauth2.credentials import Credentials as UserCredentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload, MediaIoBaseUpload

from app.core.config import get_settings

_FOLDER_MIME = "application/vnd.google-apps.folder"
_SCOPES = ["https://www.googleapis.com/auth/drive"]


@lru_cache
def get_drive_service():
    settings = get_settings()
    creds = service_account.Credentials.from_service_account_file(
        settings.firebase_service_account_path, scopes=_SCOPES
    )
    return build("drive", "v3", credentials=creds, cache_discovery=False)


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
    return build("drive", "v3", credentials=creds, cache_discovery=False)


def find_child_folder(service, parent_id: str, name: str):
    escaped = name.replace("'", "\\'")
    result = (
        service.files()
        .list(
            q=f"'{parent_id}' in parents and name = '{escaped}' "
            f"and mimeType = '{_FOLDER_MIME}' and trashed = false",
            fields="files(id, name)",
            pageSize=1,
        )
        .execute()
    )
    files = result.get("files", [])
    return files[0] if files else None


def find_or_create_child_folder(service, parent_id: str, name: str) -> str:
    existing = find_child_folder(service, parent_id, name)
    if existing:
        return existing["id"]

    created = (
        service.files()
        .create(
            body={"name": name, "mimeType": _FOLDER_MIME, "parents": [parent_id]},
            fields="id",
        )
        .execute()
    )
    return created["id"]


def list_child_folders(service, parent_id: str):
    result = (
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
    return result.get("files", [])


def list_child_files(service, parent_id: str):
    result = (
        service.files()
        .list(
            q=f"'{parent_id}' in parents and trashed = false",
            fields="files(id, name)",
            pageSize=1000,
        )
        .execute()
    )
    return result.get("files", [])


def download_file_bytes(service, file_id: str) -> bytes:
    request = service.files().get_media(fileId=file_id)
    buf = io.BytesIO()
    downloader = MediaIoBaseDownload(buf, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()
    return buf.getvalue()


def upload_file_bytes(
    service, parent_id: str, name: str, data: bytes, mime_type: str = "image/png"
) -> str:
    media = MediaIoBaseUpload(io.BytesIO(data), mimetype=mime_type, resumable=False)
    created = (
        service.files()
        .create(body={"name": name, "parents": [parent_id]}, media_body=media, fields="id")
        .execute()
    )
    return created["id"]