#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
[ -x backend/.venv/bin/python ] || { echo "Run ./setup_backend.sh first."; exit 1; }
backend/.venv/bin/python ml/generate_historical_dataset.py
backend/.venv/bin/python ml/train_model.py
