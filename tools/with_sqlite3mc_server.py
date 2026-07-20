import os
import subprocess
import sys
import time
import urllib.request


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    dll_dir = os.path.join(repo_root, 'tools', 'sqlite3mc')
    original_cwd = os.getcwd()

    if not os.path.isdir(dll_dir):
        print(f'ERROR: sqlite3mc directory not found: {dll_dir}', file=sys.stderr)
        sys.exit(1)

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

        cmd = ' '.join(sys.argv[2:])
        result = subprocess.run(cmd, shell=True, cwd=original_cwd)
        sys.exit(result.returncode)
    finally:
        server_proc.terminate()
        try:
            server_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server_proc.kill()


if __name__ == '__main__':
    main()
