import hashlib
import os
import subprocess
import sys
import time
import urllib.request

# SHA-256 of tools/sqlite3mc/sqlite3mc.x64.windows.dll, matching the pinned
# sqlite3 3.5.0 build hook (apps/fundlens_windows/pubspec.lock). The sqlite3
# hook verifies this exact hash; if the DLL and the lockfile drift apart the
# hook fails with "Hash of downloaded file ... expected ..." — update both
# together when bumping the sqlite3 package.
EXPECTED_DLL_SHA256 = '228e39a638c7f43bb5dfc8e3993ba264a18dfec4c697c2d855e97c59f1b239eb'
DLL_NAME = 'sqlite3mc.x64.windows.dll'


def _verify_dll(dll_dir):
    dll_path = os.path.join(dll_dir, DLL_NAME)
    if not os.path.isfile(dll_path):
        print(f'ERROR: {DLL_NAME} missing in {dll_dir}', file=sys.stderr)
        print('       Copy it from the main checkout (it is not committed).',
              file=sys.stderr)
        sys.exit(1)
    digest = hashlib.sha256()
    with open(dll_path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    if digest.hexdigest() != EXPECTED_DLL_SHA256:
        print(
            f'ERROR: {DLL_NAME} sha256 {digest.hexdigest()} does not match '
            f'pinned sqlite3 hook expectation {EXPECTED_DLL_SHA256}.',
            file=sys.stderr,
        )
        print('       The lockfile pins a different sqlite3 build. Update the '
              'DLL and EXPECTED_DLL_SHA256 together.', file=sys.stderr)
        sys.exit(1)


def _url_pattern_active(repo_root):
    """Whether the app pubspec still routes the sqlite3 hook at localhost.

    CI removes the url_pattern before running so the hook downloads from
    GitHub; in that case the local server (and its uncommitted DLL) is not
    needed at all.
    """
    pubspec = os.path.join(
        repo_root, 'apps', 'fundlens_windows', 'pubspec.yaml')
    try:
        with open(pubspec, encoding='utf-8') as handle:
            return 'url_pattern: http://localhost:8765' in handle.read()
    except OSError:
        return False


def _run_command(original_cwd):
    cmd = ' '.join(sys.argv[2:])
    return subprocess.run(cmd, shell=True, cwd=original_cwd).returncode


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    dll_dir = os.path.join(repo_root, 'tools', 'sqlite3mc')
    original_cwd = os.getcwd()

    # CI mode: url_pattern removed, hook downloads from GitHub — run the
    # command directly without the local server or DLL checks.
    if not _url_pattern_active(repo_root):
        if len(sys.argv) > 2:
            sys.exit(_run_command(original_cwd))
        print('sqlite3mc url_pattern not active; nothing to serve.')
        sys.exit(0)

    if not os.path.isdir(dll_dir):
        print(f'ERROR: sqlite3mc directory not found: {dll_dir}', file=sys.stderr)
        sys.exit(1)
    _verify_dll(dll_dir)

    # The committed pubspec.lock is resolved against the flutter-io.cn mirror;
    # a bare `flutter test` would re-resolve against pub.dev and upgrade
    # sqlite3 past the pinned version, breaking the hash check above. Default
    # the pub mirror env vars (still overridable from the caller).
    os.environ.setdefault('PUB_HOSTED_URL', 'https://pub.flutter-io.cn')
    os.environ.setdefault('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn')

    # Start a detached Python HTTP server in the DLL directory so the main
    # process keeps the original working directory for the actual command.
    server_proc = subprocess.Popen(
        [sys.executable, '-m', 'http.server', str(port)],
        cwd=dll_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        ready = False
        for _ in range(50):
            try:
                urllib.request.urlopen(f'http://127.0.0.1:{port}/', timeout=0.2)
                ready = True
                break
            except OSError:
                time.sleep(0.1)

        if not ready:
            print('ERROR: local sqlite3mc server did not start', file=sys.stderr)
            sys.exit(1)

        if len(sys.argv) <= 2:
            print(f'Local sqlite3mc server running on http://127.0.0.1:{port}/')
            print('Press Ctrl+C to stop.')
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                pass
            sys.exit(0)

        sys.exit(_run_command(original_cwd))
    finally:
        server_proc.terminate()
        try:
            server_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server_proc.kill()


if __name__ == '__main__':
    main()
