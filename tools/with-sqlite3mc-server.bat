@echo off
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PATH=D:\flutter\bin;%PATH%
python "%~dp0\with_sqlite3mc_server.py" 8765 %*
