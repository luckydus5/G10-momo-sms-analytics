# MoMo SMS Analytics Platform

> **Group 10** · ALU Software Engineering · Full-Stack Development Assessment

A production-grade data pipeline and analytics dashboard that transforms raw MTN Mobile Money SMS exports into structured, queryable transaction records — complete with real-time visualizations, category breakdowns, and trend analysis.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Team](#team)
- [System Architecture](#system-architecture)
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

Mobile Money generates thousands of SMS notifications per user — transfers, merchant payments, airtime top-ups, bank deposits, fees, and reversals. This data lives trapped inside unstructured XML exports with no way to query, filter, or visualize it.

This platform solves that. It ingests raw `momo.xml` data, runs it through a multi-stage ETL pipeline, persists clean records to a relational database, and surfaces everything through an interactive browser dashboard — no cloud infrastructure required.

**Key capabilities:**

| Capability | Detail |
|---|---|
| XML ingestion | Streams and parses large XML exports without loading the full file into memory |
| Data normalization | Standardizes amounts (RWF), timestamps (ISO 8601), and phone numbers (E.164) |
| Auto-categorization | Classifies each transaction into one of 7 types using rule-based matching |
| Persistent storage | SQLite with full upsert support — re-running the pipeline never duplicates records |
| Dead-letter logging | Unparseable records are quarantined with full context for manual review |
| Static dashboard | Zero-dependency frontend — runs on any machine with Python installed |
| Optional REST API | FastAPI layer for teams that want to query transaction data programmatically |

---

## Team

| Name | Role | GitHub |
|---|---|---|
| Gabriel Mugisha | Team Lead · Backend Architecture | [@gabriel-mugisha](https://github.com/gabriel-mugisha) |
| Olivier Dusabamahoro | ETL Pipeline · Database Design | [@olivier-dusabamahoro](https://github.com/olivier-dusabamahoro) |
| James Kanneh | Frontend · Data Visualization | [@james-kanneh](https://github.com/james-kanneh) |

---

## System Architecture

Data moves through four clearly separated layers, each with a single responsibility:

```
┌─────────────────────────────────────────────────────────────┐
│                        Data Source                          │
│                    data/raw/momo.xml                        │
└──────────────────────────┬──────────────────────────────────┘
                           │ XML stream
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      ETL Pipeline                           │
│                                                             │
│  parse_xml.py ──► clean_normalize.py ──► categorize.py     │
│                                               │             │
│                                          load_db.py         │
└──────────────────────────┬──────────────────────────────────┘
                           │ structured records
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     Storage Layer                           │
│                                                             │
│         SQLite (db.sqlite3)    dashboard.json              │
│              ↓                        ↓                    │
│         FastAPI /api          Static JSON export           │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP / JSON
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Frontend Dashboard                        │
│                                                             │
│        index.html · chart_handler.js · styles.css          │
└─────────────────────────────────────────────────────────────┘
```

**Architecture diagram (visual):** `architecture.svg` in this repository  
**Editable version (Draw.io):** *(paste your Draw.io / Miro link here)*

---

## Project Structure

```
G10-momo-sms-analytics/
│
├── README.md                         # You are here
├── CONTRIBUTING.md                   # How to contribute and branch conventions
├── .gitignore                        # Ignores raw data, venv, __pycache__, .env
├── .env.example                      # Environment variable template
├── requirements.txt                  # All Python dependencies with pinned versions
├── architecture.svg                  # System architecture diagram
│
├── frontend/                         # Everything the browser touches
│   ├── index.html                    # Dashboard entry point
│   ├── css/
│   │   └── styles.css                # Layout, typography, component styles
│   └── js/
│       ├── chart_handler.js          # Chart.js chart initialization and rendering
│       ├── api.js                    # Fetch helpers for REST API or JSON file
│       └── ui.js                     # DOM utilities and filter controls
│
├── backend/                          # Server-side code
│   │
│   ├── etl/                          # Extract → Transform → Load pipeline
│   │   ├── __init__.py
│   │   ├── config.py                 # Paths, category rules, field mappings
│   │   ├── parse_xml.py              # XML streaming parser (ElementTree / lxml)
│   │   ├── clean_normalize.py        # Amount, date, phone number normalization
│   │   ├── categorize.py             # Rule-based transaction classification
│   │   ├── load_db.py                # SQLite table creation and upsert logic
│   │   └── run.py                    # CLI: runs the full pipeline end-to-end
│   │
│   ├── api/                          # Optional REST layer
│   │   ├── __init__.py
│   │   ├── app.py                    # FastAPI application and route definitions
│   │   ├── db.py                     # Database connection pool and query helpers
│   │   └── schemas.py                # Pydantic models for request / response validation
│   │
│   └── tests/                        # Unit and integration tests
│       ├── test_parse_xml.py
│       ├── test_clean_normalize.py
│       └── test_categorize.py
│
├── data/
│   ├── raw/                          # Source files — git-ignored
│   │   └── momo.xml
│   ├── processed/
│   │   └── dashboard.json            # Pre-aggregated summary for the static dashboard
│   ├── db.sqlite3                    # SQLite database — git-ignored
│   └── logs/
│       ├── etl.log                   # Timestamped run logs (INFO / WARNING / ERROR)
│       └── dead_letter/              # XML snippets that failed parsing, for manual review
│
└── scripts/
    ├── run_etl.sh                    # One-command pipeline runner
    ├── export_json.sh                # Regenerates data/processed/dashboard.json
    └── serve_frontend.sh             # Starts local HTTP server on port 8000
```

---

## Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| Language | Python 3.11 | Strong XML and data libraries; wide team familiarity |
| XML Parsing | `lxml` / `xml.etree.ElementTree` | lxml for speed on large files; ElementTree as fallback |
| Data Cleaning | `python-dateutil`, `re` | Robust date parsing; regex for phone/amount normalization |
| Database | SQLite 3 | Zero-setup relational storage; portable single-file DB |
| API | FastAPI + Pydantic | Auto-generated docs; fast async endpoints; type-safe models |
| Frontend | Vanilla HTML/CSS/JS | No build step; works offline; easy to extend |
| Charts | Chart.js | Lightweight; supports bar, line, doughnut charts |
| Testing | `pytest` | Simple, well-documented; integrates with CI |
| Version Control | Git + GitHub | Branching workflow; pull requests for code review |

---

## Getting Started

### Prerequisites

- Python 3.9 or higher
- Git
- A terminal (Bash, Zsh, or Git Bash on Windows)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/G10-momo-sms-analytics.git
cd G10-momo-sms-analytics

# 2. Create and activate a virtual environment
python -m venv venv

# On macOS / Linux:
source venv/bin/activate

# On Windows (Git Bash):
source venv/Scripts/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up environment variables
cp .env.example .env
# Edit .env if needed — defaults work out of the box for SQLite
```

### Running the ETL Pipeline

```bash
# Place your XML export in the data/raw/ directory, then run:
python backend/etl/run.py --xml data/raw/momo.xml

# Expected output:
# [INFO]  Parsed   1,243 records from momo.xml
# [INFO]  Cleaned  1,241 records (2 sent to dead_letter/)
# [INFO]  Loaded   1,241 records into data/db.sqlite3
# [INFO]  Exported data/processed/dashboard.json
# [INFO]  Pipeline completed in 1.3s
```

### Launching the Dashboard

```bash
bash scripts/serve_frontend.sh
# Open http://localhost:8000 in your browser
```

### Running the Optional REST API

```bash
uvicorn backend.api.app:app --reload
# API available at http://localhost:8001
# Interactive docs at http://localhost:8001/docs
```

### Running Tests

```bash
pytest backend/tests/ -v
```

---

## ETL Pipeline

The pipeline runs in four sequential stages:

**Stage 1 — Parse (`parse_xml.py`)**  
Streams the XML file using an iterative parser to avoid loading the full document into memory. Extracts raw field values from each `<sms>` element and passes them downstream as Python dictionaries.

**Stage 2 — Normalize (`clean_normalize.py`)**  
Cleans raw field values into consistent formats:
- Amounts: strips currency symbols, converts to float (e.g. `"RWF 5,000"` → `5000.0`)
- Dates: parses any recognizable date string to ISO 8601 (e.g. `"2024-03-15 10:22:31"`)
- Phones: normalizes to E.164 format (e.g. `"0788123456"` → `"+250788123456"`)

**Stage 3 — Categorize (`categorize.py`)**  
Applies rule-based classification to assign each transaction one of seven types:

| Category | Example trigger phrase |
|---|---|
| `transfer_sent` | "You have transferred" |
| `transfer_received` | "You have received" |
| `merchant_payment` | "Your payment of" |
| `airtime_topup` | "Your airtime purchase" |
| `bank_deposit` | "Your bank deposit" |
| `fee` | "Transaction fee" |
| `reversal` | "has been reversed" |

**Stage 4 — Load (`load_db.py`)**  
Upserts records into SQLite using the transaction reference number as the unique key. Re-running the pipeline on the same file is safe — no duplicates are created.

---

## Database Schema

```sql
CREATE TABLE transactions (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    ref_number       TEXT    UNIQUE NOT NULL,
    category         TEXT    NOT NULL,
    amount           REAL    NOT NULL,
    currency         TEXT    DEFAULT 'RWF',
    sender_phone     TEXT,
    receiver_phone   TEXT,
    timestamp        TEXT    NOT NULL,
    raw_message      TEXT,
    created_at       TEXT    DEFAULT (datetime('now'))
);

CREATE INDEX idx_category  ON transactions(category);
CREATE INDEX idx_timestamp ON transactions(timestamp);
```

---

## API Reference

When running the optional FastAPI server:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/transactions` | List all transactions (supports `?category=` and `?limit=` filters) |
| `GET` | `/transactions/{ref}` | Retrieve a single transaction by reference number |
| `GET` | `/analytics/summary` | Total volume, count, and breakdown by category |
| `GET` | `/analytics/trends` | Daily transaction totals for the past 30 days |

Full interactive documentation is available at `http://localhost:8001/docs` when the server is running.

---

## Scrum Board

The team manages all work using a Kanban board with three columns:

| Column | Purpose |
|---|---|
| **To Do** | Planned tasks not yet started |
| **In Progress** | Currently being developed |
| **Done** | Completed, reviewed, and merged |

Tasks created for Sprint 1 include repository setup, architecture diagram, XML parser research, database schema design, ETL skeleton, and frontend scaffolding.

**Scrum Board Link:** *(paste your GitHub Projects / Trello / Jira link here)*

---

## Contributing

Please read `CONTRIBUTING.md` before opening a pull request.

**Branch naming convention:**

```
feature/your-feature-name
fix/bug-description
docs/what-you-updated
```

**Workflow:**
1. Create a branch from `main`
2. Make your changes with clear commit messages
3. Open a pull request and request review from at least one teammate
4. Merge only after approval

---

## AI Usage Log

*(Paste your AI usage log link here — shared Google Doc, ChatGPT share link, etc.)*

---

## License

Submitted as part of a formative assessment at the African Leadership University.  
All code is original work produced by Group 10 members.
