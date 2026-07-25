"""Allowlisted file access: the engine may only read user-selected files.

The Flutter side canonicalizes the paths the user picked and sends them in
each request. :func:`validate_selected_file` resolves symlinks and requires
the resolved path to equal one of the request's exact allowlisted paths,
then verifies regular-file type, extension and size limits. Any violation
raises :class:`PathAccessError` before a single byte is read by OCR.
"""

import os
import stat
from collections.abc import Iterable
from pathlib import Path

IMAGE_SUFFIXES = frozenset({".png", ".jpg", ".jpeg", ".bmp", ".webp"})

DEFAULT_MAX_FILE_BYTES = 20 * 1024 * 1024
DEFAULT_MAX_TOTAL_BYTES = 100 * 1024 * 1024


class PathAccessError(ValueError):
    """Raised when a requested file violates the selected-path boundary."""


def _canonical(path: str) -> str:
    return os.path.normcase(os.path.normpath(path))


def validate_selected_file(
    path: str | os.PathLike[str],
    allowed_paths: Iterable[str],
    *,
    allowed_suffixes: Iterable[str] = IMAGE_SUFFIXES,
    max_file_bytes: int = DEFAULT_MAX_FILE_BYTES,
) -> Path:
    """Resolve and validate one user-selected file against the allowlist.

    Returns the resolved path. Raises :class:`PathAccessError` when the
    resolved path is not an exact allowlisted path, is missing or not a
    regular file, has a disallowed extension, or exceeds ``max_file_bytes``.
    """
    resolved = Path(os.path.realpath(os.fspath(path)))
    allowed = {_canonical(str(entry)) for entry in allowed_paths}
    if _canonical(str(resolved)) not in allowed:
        raise PathAccessError("security.path_not_selected")
    try:
        info = resolved.stat()
    except OSError as exc:
        raise PathAccessError("security.not_regular_file") from exc
    if not stat.S_ISREG(info.st_mode):
        raise PathAccessError("security.not_regular_file")
    suffixes = {suffix.lower() for suffix in allowed_suffixes}
    if resolved.suffix.lower() not in suffixes:
        raise PathAccessError("security.unsupported_extension")
    if info.st_size > max_file_bytes:
        raise PathAccessError("security.file_too_large")
    return resolved


def validate_selected_files(
    paths: Iterable[str | os.PathLike[str]],
    allowed_paths: Iterable[str],
    *,
    allowed_suffixes: Iterable[str] = IMAGE_SUFFIXES,
    max_file_bytes: int = DEFAULT_MAX_FILE_BYTES,
    max_total_bytes: int = DEFAULT_MAX_TOTAL_BYTES,
) -> list[Path]:
    """Validate a batch of selected files, including the total size limit."""
    allowed = list(allowed_paths)
    resolved = [
        validate_selected_file(
            path,
            allowed,
            allowed_suffixes=allowed_suffixes,
            max_file_bytes=max_file_bytes,
        )
        for path in paths
    ]
    if sum(path.stat().st_size for path in resolved) > max_total_bytes:
        raise PathAccessError("security.total_too_large")
    return resolved
