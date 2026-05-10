"""SQLite schema and upsert helpers for the ETL pipeline.

The schema is intentionally small: one `transactions` table for the cleaned
records and one `etl_runs` table for run-level metadata used by the dashboard
to display freshness. A `raw_messages` table preserves the original SMS body
so that re-categorization is possible without re-parsing the XML.
"""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterable, Iterator, Mapping

from . import config


SCHEMA = """
CREATE TABLE IF NOT EXISTS raw_messages (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    sms_id          TEXT UNIQUE,
    body            TEXT NOT NULL,
    received_at     TEXT NOT NULL,
    inserted_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transactions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_message_id  INTEGER NOT NULL REFERENCES raw_messages(id) ON DELETE CASCADE,
    txn_ref         TEXT UNIQUE,
    category        TEXT NOT NULL,
    direction       TEXT CHECK (direction IN ('in', 'out')),
    amount_rwf      INTEGER NOT NULL,
    fee_rwf         INTEGER NOT NULL DEFAULT 0,
    balance_rwf     INTEGER,
    counterparty    TEXT,
    phone           TEXT,
    occurred_at     TEXT NOT NULL,
    inserted_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_txn_category    ON transactions(category);
CREATE INDEX IF NOT EXISTS idx_txn_occurred_at ON transactions(occurred_at);
CREATE INDEX IF NOT EXISTS idx_txn_direction   ON transactions(direction);

CREATE TABLE IF NOT EXISTS etl_runs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    rows_parsed     INTEGER NOT NULL DEFAULT 0,
    rows_loaded     INTEGER NOT NULL DEFAULT 0,
    rows_failed     INTEGER NOT NULL DEFAULT 0,
    source_file     TEXT
);
"""


@contextmanager
def connect(db_path: Path | None = None) -> Iterator[sqlite3.Connection]:
    """Yield a SQLite connection with foreign keys enabled."""
    path = Path(db_path) if db_path else config.SQLITE_DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db(db_path: Path | None = None) -> None:
    """Create tables and indexes if they do not already exist."""
    with connect(db_path) as conn:
        conn.executescript(SCHEMA)


def upsert_transactions(
    conn: sqlite3.Connection, rows: Iterable[Mapping[str, object]]
) -> int:
    """Insert transactions, skipping duplicates by `txn_ref`. Returns row count."""
    sql = """
        INSERT OR IGNORE INTO transactions (
            raw_message_id, txn_ref, category, direction,
            amount_rwf, fee_rwf, balance_rwf,
            counterparty, phone, occurred_at
        ) VALUES (
            :raw_message_id, :txn_ref, :category, :direction,
            :amount_rwf, :fee_rwf, :balance_rwf,
            :counterparty, :phone, :occurred_at
        )
    """
    cursor = conn.executemany(sql, rows)
    return cursor.rowcount or 0
