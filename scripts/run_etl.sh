#!/usr/bin/env bash
# Run the ETL pipeline end-to-end: parse -> clean -> categorize -> load -> export.
set -euo pipefail

cd "$(dirname "$0")/.."

python -m backend.etl.run --xml "${MOMO_XML_PATH:-data/raw/momo.xml}"
