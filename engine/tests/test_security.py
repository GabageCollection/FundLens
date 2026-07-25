"""Boundary tests for allowlisted file access (``fundlens_engine.security``)."""

import os
from pathlib import Path

import pytest

from fundlens_engine.security import (
    PathAccessError,
    validate_selected_file,
    validate_selected_files,
)


def _make_file(path: Path, size: int = 4) -> Path:
    path.write_bytes(b"\0" * size)
    return path


def test_engine_rejects_unselected_path(tmp_path) -> None:
    with pytest.raises(PathAccessError):
        validate_selected_file(str(tmp_path / "not-selected.png"), allowed_paths=[])


def test_accepts_exact_allowlisted_file(tmp_path) -> None:
    image = _make_file(tmp_path / "selected.png")

    resolved = validate_selected_file(str(image), allowed_paths=[str(image)])

    assert resolved == Path(os.path.realpath(image))
    assert resolved.read_bytes() == image.read_bytes()


def test_rejects_traversal_outside_allowlist(tmp_path) -> None:
    _make_file(tmp_path / "outside.png")
    sub = tmp_path / "sub"
    sub.mkdir()
    selected = _make_file(sub / "selected.png")

    with pytest.raises(PathAccessError, match="path_not_selected"):
        validate_selected_file(str(sub / ".." / "outside.png"), allowed_paths=[str(selected)])


def test_rejects_symlink_escape(tmp_path) -> None:
    secret = _make_file(tmp_path / "secret.png")
    link = tmp_path / "link.png"
    try:
        os.symlink(secret, link)
    except OSError as exc:
        pytest.skip(f"symlinks unavailable on this platform: {exc}")

    with pytest.raises(PathAccessError, match="path_not_selected"):
        validate_selected_file(str(link), allowed_paths=[str(link)])


def test_rejects_extension_spoofing(tmp_path) -> None:
    note = _make_file(tmp_path / "notes.txt")

    with pytest.raises(PathAccessError, match="unsupported_extension"):
        validate_selected_file(str(note), allowed_paths=[str(note)])


def test_rejects_non_regular_file(tmp_path) -> None:
    folder = tmp_path / "folder.png"
    folder.mkdir()

    with pytest.raises(PathAccessError, match="not_regular_file"):
        validate_selected_file(str(folder), allowed_paths=[str(folder)])


def test_rejects_missing_file(tmp_path) -> None:
    ghost = tmp_path / "ghost.png"

    with pytest.raises(PathAccessError, match="not_regular_file"):
        validate_selected_file(str(ghost), allowed_paths=[str(ghost)])


def test_rejects_oversize_file(tmp_path) -> None:
    big = _make_file(tmp_path / "big.png", size=64)

    with pytest.raises(PathAccessError, match="file_too_large"):
        validate_selected_file(str(big), allowed_paths=[str(big)], max_file_bytes=16)


def test_rejects_oversize_batch_total(tmp_path) -> None:
    first = _make_file(tmp_path / "a.png", size=10)
    second = _make_file(tmp_path / "b.png", size=10)

    with pytest.raises(PathAccessError, match="total_too_large"):
        validate_selected_files(
            [str(first), str(second)],
            allowed_paths=[str(first), str(second)],
            max_file_bytes=16,
            max_total_bytes=15,
        )


def test_batch_returns_resolved_paths_in_order(tmp_path) -> None:
    first = _make_file(tmp_path / "a.png", size=10)
    second = _make_file(tmp_path / "b.png", size=5)

    resolved = validate_selected_files([str(first), str(second)], allowed_paths=[str(second), str(first)])

    assert resolved == [Path(os.path.realpath(first)), Path(os.path.realpath(second))]
