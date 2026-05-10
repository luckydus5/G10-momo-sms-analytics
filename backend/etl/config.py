"""Central configuration for the ETL pipeline.

Reads paths and thresholds from environment variables (loaded from `.env` when
present) and falls back to sensible defaults relative to the repository root.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


REPO_ROOT = Path(__file__).resolve().parents[2]


def _resolve(env_var: str, default: str) -> Path:
    value = os.getenv(env_var, default)
    path = Path(value)
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path


MOMO_XML_PATH = _resolve("MOMO_XML_PATH", "data/raw/momo.xml")
DASHBOARD_JSON_PATH = _resolve("DASHBOARD_JSON_PATH", "data/processed/dashboard.json")
SQLITE_DB_PATH = _resolve("SQLITE_DB_PATH", "data/db.sqlite3")
ETL_LOG_PATH = _resolve("ETL_LOG_PATH", "data/logs/etl.log")
DEAD_LETTER_DIR = _resolve("DEAD_LETTER_DIR", "data/logs/dead_letter")


# Transaction categories — extend as new SMS body patterns are discovered.
CATEGORIES = (
    "incoming_money",
    "payment_to_code",
    "transfer_to_mobile",
    "bank_deposit",
    "airtime",
    "cash_power_bill",
    "third_party_initiated",
    "withdrawal_from_agent",
    "bank_transfer",
    "internet_bundle",
    "unknown",
)

DEFAULT_CATEGORY = "unknown"

# Validation thresholds
MIN_AMOUNT_RWF = 0
MAX_AMOUNT_RWF = 10_000_000
