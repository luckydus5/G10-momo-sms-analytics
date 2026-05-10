#!/usr/bin/env bash
# Serve the static dashboard at http://localhost:8000
set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${API_PORT:-8000}"
python -m http.server "$PORT" --directory frontend
