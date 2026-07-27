# PyInstaller spec for the FundLens data engine (one-directory build).
#
# Produces dist/engine/fundlens_engine/fundlens_engine.exe via
# tools/build_engine.ps1. OCR models are collected from the deterministic
# staging directory engine/models (PADDLE_PDX_CACHE_HOME layout, i.e.
# models/official_models/...); build_engine.ps1 populates that directory
# before invoking PyInstaller and moves the collected copy up to
# <exe-dir>/models after the build, where the runtime hook finds it.

from pathlib import Path

from PyInstaller.utils.hooks import collect_all, copy_metadata

SPEC_DIR = Path(SPECPATH).resolve()
ENGINE_DIR = SPEC_DIR
MODELS_STAGING = ENGINE_DIR / "models"

datas = []
binaries = []
hiddenimports = []

# PaddleOCR / PaddleX / PaddlePaddle rely on lazy imports, plugin
# registries and data files; collect each package in full.
for package in ("paddleocr", "paddlex", "paddle"):
    pkg_datas, pkg_binaries, pkg_hiddenimports = collect_all(package)
    datas += pkg_datas
    binaries += pkg_binaries
    hiddenimports += pkg_hiddenimports

# paddlex checks `importlib.metadata.version()` for its "ocr" extra
# dependencies before creating the OCR pipeline; frozen apps do not see
# distribution metadata unless it is collected explicitly. Copy metadata
# for every candidate that is actually installed so the bundle's view
# matches the build venv (paddlex.utils.deps.EXTRAS["ocr"] / ["ocr-core"]).
import importlib.metadata as _importlib_metadata

for dist in (
    "beautifulsoup4",
    "einops",
    "ftfy",
    "imagesize",
    "Jinja2",
    "latex2mathml",
    "lxml",
    "opencv-contrib-python",
    "openpyxl",
    "premailer",
    "pyclipper",
    "pypdfium2",
    "python-bidi",
    "regex",
    "safetensors",
    "scikit-learn",
    "scipy",
    "sentencepiece",
    "shapely",
    "tiktoken",
    "tokenizers",
):
    try:
        datas += copy_metadata(dist)
    except _importlib_metadata.PackageNotFoundError:
        pass

# Only the models staged by build_engine.ps1 ship: the Chinese detection /
# recognition / textline-orientation set PaddleOCR downloads for
# PaddleOCR(use_textline_orientation=True, lang="ch") (for paddleocr 3.7:
# PP-OCRv5_mobile_det/rec, PP-LCNet_x1_0_textline_ori and companions).
if MODELS_STAGING.is_dir():
    datas.append((str(MODELS_STAGING), "models"))

a = Analysis(
    [str(ENGINE_DIR / "packaging" / "pyinstaller_entry.py")],
    pathex=[str(ENGINE_DIR / "src")],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[str(ENGINE_DIR / "packaging" / "pyinstaller_rth_models.py")],
    excludes=[
        # Test/dev tooling locked in requirements.lock but never shipped.
        # NOTE: setuptools must NOT be excluded: paddle imports it at
        # runtime (paddle.utils.cpp_extension).
        "pytest",
        "_pytest",
        "mypy",
        "ruff",
        "pip",
        "wheel",
        "IPython",
        "notebook",
        "tkinter",
    ],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="fundlens_engine",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="fundlens_engine",
)
