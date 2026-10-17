#!/usr/bin/env bash
cd "$(dirname "$0")/backend" || exit 1
[ -x .venv/bin/python ] || { echo "Run ./setup_backend.sh first."; exit 1; }
.venv/bin/python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
