#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
[ -x backend/.venv/bin/python ] || ./setup_backend.sh
./run_backend.sh &
API_PID=$!
trap 'kill $API_PID 2>/dev/null' EXIT
sleep 6
cd mobile && flutter pub get && flutter run -d chrome
