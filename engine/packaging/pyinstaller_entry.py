"""PyInstaller entry point: run the engine as ``python -m fundlens_engine``.

A plain ``__main__.py`` cannot be used as the spec entry script because its
relative imports need a package context, and a dynamic
``runpy.run_module('fundlens_engine')`` call is invisible to PyInstaller's
static analysis. Importing the server entry point directly makes the whole
package discoverable and preserves the module's behavior.
"""

from fundlens_engine.server import main

if __name__ == "__main__":
    main()
