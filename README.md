# MoMo SMS Analytics Platform

> **Group 10** · ALU Software Engineering · Full-Stack Development Assessment

A production-grade data pipeline and analytics dashboard that transforms raw MTN Mobile Money SMS exports into structured, queryable transaction records — with real-time visualizations, category breakdowns, and trend analysis.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Team](#team)
- [System Architecture](#system-architecture)
- [Database Design](#database-design)
- [XML Data Analysis](#xml-data-analysis)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [ETL Pipeline](#etl-pipeline)
- [Database Schema](#database-schema)
- [API Reference](#api-reference)
- [Scrum Board](#scrum-board)
- [Contributing](#contributing)
- [AI Usage Log](#ai-usage-log)

---

## Project Overview

Mobile Money generates thousands of SMS notifications — transfers, merchant payments, airtime top-ups, bank deposits, fees, and reversals. This data lives trapped inside unstructured XML exports with no way to query, filter, or visualize it.

This platform solves that. It ingests raw `momo.xml` data (1,691 real SMS records spanning May–October 2024), runs it through a multi-stage ETL pipeline, persists clean records to a relational MySQL database, and surfaces everything through an interactive browser dashboard.

| Capability | Detail |
|---|---|
| XML ingestion | Streams and parses 1,691 SMS records from `modified_sms_v2.xml` |
| Pattern matching | Identifies 9 transaction types from SMS body text using regex rules |
| Data normalization | Standardizes amounts (RWF), timestamps (ISO 8601), phone numbers (E.164) |
| Auto-categorization | Classifies each SMS into one of 9 confirmed transaction types |
| Persistent storage | MySQL with full upsert — re-running never duplicates records |
| Dead-letter logging | OTP and promotional SMS quarantined for review (42 records skipped) |
| Static dashboard | Zero-dependency frontend — runs on any machine with Python |
| Optional REST API | FastAPI layer for programmatic data access |

---

## Team

| Name | Role | GitHub |
|---|---|---|
| Gabriel Mugisha | Team Lead · Backend Architecture | [@GabbyIT-Pixel](https://github.com/GabbyIT-Pixel) |
| Olivier Dusabamahoro | ETL Pipeline · Database Design · Scrum | [@luckydus5](https://github.com/luckydus5) |
| James Kanneh | Frontend · Data Visualization | [@JamesKanneh](https://github.com/JamesKanneh) |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Data Source                                    │
│         data/raw/modified_sms_v2.xml                       │
│         1,691 SMS records · May–Oct 2024                   │
└──────────────────────────┬──────────────────────────────────┘
                           │ XML stream
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   ETL Pipeline                              │
│                                                             │
│  parse_xml.py ──► clean_normalize.py ──► categorize.py     │
│                                               │             │
│                                          load_db.py         │
└──────────────────────────┬──────────────────────────────────┘
                           │ structured records
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Storage Layer                              │
│   MySQL (transactions, users, categories, logs, tags)      │
│              ↓                        ↓                    │
│         FastAPI /api          dashboard.json (static)      │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP / JSON
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                Frontend Dashboard                           │
│         index.html · chart_handler.js · styles.css         │
└─────────────────────────────────────────────────────────────┘
```

**Architecture diagram:** `architecture.drawio`
**View on Draw.io:** [Open diagram](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/luckydus5/G10-momo-sms-analytics/main/architecture.drawio)

---

## Database Design

### Entity Relationship Diagram

Share picture here:  

The database is built around six entities:

| Entity | Purpose |
|---|---|
| `TRANSACTIONS` | Core fact table — one row per parsed financial SMS |
| `USERS` | Account owner (Abebe Chala, ID 36521838) + all counterparties |
| `TRANSACTION_CATEGORIES` | 9 transaction types derived from real XML pattern analysis |
| `TAGS` | User-defined labels (e.g. groceries, rent, utilities) |
| `TRANSACTION_TAGS` | Junction table resolving M:N between transactions and tags |
| `SYSTEM_LOGS` | ETL audit trail and dead-letter queue |

### Design Rationale

The schema is structured around a single fact table (`TRANSACTIONS`) surrounded by dimension and lookup tables. This star-schema approach makes analytical queries fast — aggregations like total spending per category per month are a single `GROUP BY` with straightforward `JOIN`s.

The `TRANSACTIONS` table includes a `direction` column (`incoming`/`outgoing`/`neutral`) derived directly from the SMS body pattern, which is critical for net-flow analysis. Bank deposits and received transfers are `incoming`; merchant payments, transfers sent, and withdrawals are `outgoing`.

A single `counterparty_id` foreign key replaces the dual sender/receiver pattern because each MoMo SMS describes one side of a transaction from the account owner's perspective. The counterparty is always the other party — whether sender (for incoming) or receiver (for outgoing).

The `financial_tx_id` is nullable because bank deposits (`*113*R*`) do not include a TxId in their SMS body, only a `Financial Transaction Id`. The `sms_date_unix` and `sms_readable_date` columns preserve the original XML attributes verbatim for auditing.

The M:N relationship between transactions and tags is resolved with the `transaction_tags` junction table, whose composite primary key `(transaction_id, tag_id)` prevents duplicate tag assignments.

`SYSTEM_LOGS` with nullable `transaction_id` handles non-financial SMS (OTP notifications, promotional messages) that cannot be linked to a transaction but must still be logged for dead-letter review.

### Database Files

| File | Location | Description |
|---|---|---|
| ERD diagram | `docs/erd_diagram.svg` | Visual entity relationship diagram |
| SQL setup script | `database/database_setup.sql` | Full DDL, constraints, indexes, real sample data, CRUD queries |
| JSON schemas | `examples/json_schemas.json` | API response shapes for all entities |

---

## XML Data Analysis

Analysis of `modified_sms_v2.xml` (1,691 records, May–October 2024):

| Transaction Type | Count | % | SMS Pattern |
|---|---|---|---|
| Merchant Payment | 687 | 41.7% | `TxId: X. Your payment of X RWF to [name]` |
| Outgoing Transfer | 585 | 35.5% | `*165*S* X RWF transferred to [name] (phone)` |
| Bank Deposit | 248 | 15.0% | `*113*R* A bank deposit of X RWF` |
| Incoming Transfer | 63 | 3.8% | `You have received X RWF from [name]` |
| Third-Party Debit | 36 | 2.2% | `*164*S* transaction of X RWF by [company]` |
| Airtime Top-Up | 15 | 0.9% | `*162*TxId:X Your payment...to Airtime` |
| Utility Payment | 11 | 0.7% | `*162*TxId:X...MTN Cash Power with token` |
| Cash Withdrawal | 3 | 0.2% | `withdrawn X RWF...via agent: [name]` |
| Reversal | 1 | 0.1% | `*143*S* transaction...has been reversed` |
| OTP / Promo (skipped) | 42 | — | `one-time password` / promotional bundles |

**Account owner identified:** Abebe Chala CHEBUDIE · MoMo account `36521838`

---

## Project Structure

```
G10-momo-sms-analytics/
│
├── README.md
├── CONTRIBUTING.md
├── .gitignore
├── .env.example
├── requirements.txt
├── architecture.drawio
│
├── docs/
│   └── erd_diagram.svg
│
├── database/
│   └── database_setup.sql
│
├── examples/
│   └── json_schemas.json
│
├── frontend/
│   ├── index.html
│   ├── css/styles.css
│   └── js/
│       ├── chart_handler.js
│       ├── api.js
│       └── ui.js
│
├── backend/
│   ├── etl/
│   │   ├── config.py
│   │   ├── parse_xml.py
│   │   ├── clean_normalize.py
│   │   ├── categorize.py
│   │   ├── load_db.py
│   │   └── run.py
│   ├── api/
│   │   ├── app.py
│   │   ├── db.py
│   │   └── schemas.py
│   └── tests/
│       ├── test_parse_xml.py
│       ├── test_clean_normalize.py
│       └── test_categorize.py
│
├── data/
│   ├── raw/modified_sms_v2.xml
│   ├── processed/dashboard.json
│   └── logs/dead_letter/
│
└── scripts/
    ├── run_etl.sh
    ├── export_json.sh
    └── serve_frontend.sh
```

---

## Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| Language | Python 3.11 | Strong XML and data libraries |
| XML Parsing | `lxml` / `xml.etree.ElementTree` | Handles 1,691 records efficiently |
| Data Cleaning | `python-dateutil`, `re` | Robust date parsing; regex for SMS pattern matching |
| Database | MySQL 8.0 / SQLite 3 | MySQL for production; SQLite for local dev |
| API | FastAPI + Pydantic | Auto-generated docs; type-safe models |
| Frontend | Vanilla HTML/CSS/JS | No build step; works offline |
| Charts | Chart.js | Bar, line, doughnut chart support |
| Testing | `pytest` | Simple unit test framework |
| Version Control | Git + GitHub | Branching workflow; pull requests |

---

## Getting Started

```bash
# 1. Clone
git clone https://github.com/luckydus5/G10-momo-sms-analytics.git
cd G10-momo-sms-analytics

# 2. Virtual environment
python -m venv venv
source venv/bin/activate   # Windows: source venv/Scripts/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Environment variables
cp .env.example .env

# 5. Set up MySQL database
mysql -u root -p < database/database_setup.sql

# 6. Run ETL pipeline
python backend/etl/run.py --xml data/raw/modified_sms_v2.xml

# 7. Launch dashboard
bash scripts/serve_frontend.sh
# Open http://localhost:8000
```

---

## ETL Pipeline

**Stage 1 — Parse (`parse_xml.py`)**
Streams `modified_sms_v2.xml` using iterative `ElementTree` parsing. Extracts `body`, `date`, `readable_date` attributes from each `<sms>` element.

**Stage 2 — Normalize (`clean_normalize.py`)**
- Amounts: `"1,000 RWF"` → `1000.00`
- Dates: `"2024-05-10 16:30:51"` in body → `2024-05-10T16:30:51Z`
- Unix timestamps: `1715351458724` ms → stored as `sms_date_unix`
- Phones: `250791666666` → `+250791666666`

**Stage 3 — Categorize (`categorize.py`)**
Applies regex pattern matching to classify each SMS into one of 9 types. OTP and promotional messages are flagged as `PARSE_SKIP` and sent to dead-letter.

**Stage 4 — Load (`load_db.py`)**
Upserts on `financial_tx_id`. For records with no TxId (bank deposits), upserts on `(transaction_date, amount, category_id)` composite key to prevent duplicates.

---

## Database Schema

```sql
TRANSACTION_CATEGORIES  -- 9 types from XML pattern analysis
USERS                   -- account owner (36521838) + counterparties
TRANSACTIONS            -- fact table: one row per financial SMS
TAGS                    -- user-defined labels
TRANSACTION_TAGS        -- junction table (M:N)
SYSTEM_LOGS             -- ETL audit trail + dead-letter queue

-- Key design decisions from XML analysis:
direction ENUM('incoming','outgoing','neutral')  -- derived from SMS pattern
financial_tx_id VARCHAR(30) UNIQUE               -- NULL for bank deposits
sms_date_unix BIGINT                             -- preserves original XML date attr
counterparty_id FK -> users                      -- single party per SMS perspective
```

Full DDL: [`database/database_setup.sql`](database/database_setup.sql)

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/transactions` | List all transactions (`?category=`, `?direction=`, `?limit=`) |
| `GET` | `/transactions/{id}` | Single transaction by financial_tx_id |
| `GET` | `/analytics/summary` | Volume, count, breakdown by category and direction |
| `GET` | `/analytics/trends` | Daily totals grouped by month |
| `GET` | `/categories` | All 9 transaction categories |

Interactive docs: `http://localhost:8001/docs`

---

## Scrum Board

**Link:** [GitHub Projects Board](https://github.com/users/luckydus5/projects/1/views/1)

| Column | Purpose |
|---|---|
| **To Do** | Planned tasks not yet started |
| **In Progress** | Currently being developed |
| **Done** | Completed, reviewed, and merged |

---

## Contributing

See `CONTRIBUTING.md` for branch naming and workflow conventions.

```
feature/your-feature-name
fix/bug-description
docs/what-you-updated
```

---

## AI Usage Log

*(Paste your AI usage log Google Doc link here)*

---

## License

Submitted as part of a formative assessment at the African Leadership University.
All code is original work produced by Group 10 members.
