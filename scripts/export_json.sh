#!/usr/bin/env bash
# Rebuild data/processed/dashboard.json from the current SQLite contents.
set -euo pipefail

cd "$(dirname "$0")/.."

python -m backend.etl.run --export-only \
    --out "${DASHBOARD_JSON_PATH:-data/processed/dashboard.json}"
