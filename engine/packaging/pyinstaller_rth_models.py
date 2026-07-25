"""PyInstaller runtime hook: point PaddleOCR/PaddleX at the bundled models.

``tools/build_engine.ps1`` stages the downloaded inference models at
``<exe-dir>/models/official_models`` (the layout created when
``PADDLE_PDX_CACHE_HOME`` is set to ``<exe-dir>/models``). This hook makes the
frozen engine use that directory instead of downloading models into the
user's home directory. An explicit user setting still wins.
"""

import os
import sys

models_home = os.path.join(os.path.dirname(sys.executable), "models")
if os.path.isdir(models_home):
    os.environ.setdefault("PADDLE_PDX_CACHE_HOME", models_home)
