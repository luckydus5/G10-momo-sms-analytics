# MoMo SMS Analytics Platform

> **Group 10** · ALU Software Engineering · Full-Stack Development Assessment

A data pipeline and analytics dashboard that transforms raw MTN Mobile Money SMS exports into structured, queryable transaction records — with visualizations, category breakdowns, and trend analysis.

---

## Team

| Name | Role | GitHub |
|---|---|---|
| Gabriel Mugisha | Team Lead · Backend Architecture | [@gabriel-mugisha](https://github.com/gabriel-mugisha) |
| Olivier Dusabamahoro | ETL Pipeline · Database Design | [@olivier-dusabamahoro](https://github.com/olivier-dusabamahoro) |
| James Kanneh | Frontend · Data Visualization | [@JamesKanneh]((https://github.com/JamesKanneh)) |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Data Source                          │
│                    data/raw/momo.xml                        │
└──────────────────────────┬──────────────────────────────────┘
                           │ XML stream
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      ETL Pipeline                           │
│  parse_xml.py ──► clean_normalize.py ──► categorize.py     │
│                                               │             │
│                                          load_db.py         │
└──────────────────────────┬──────────────────────────────────┘
                           │ structured records
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     Storage Layer                           │
│         SQLite (db.sqlite3)    dashboard.json              │
│              ↓                        ↓                    │
│         FastAPI /api          Static JSON export           │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP / JSON
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Frontend Dashboard                        │
│        index.html · chart_handler.js · styles.css          │
└─────────────────────────────────────────────────────────────┘
```

**Architecture diagram:** `architecture.drawio` in this repository  
**View on Draw.io:** [Open diagram](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/luckydus5/G10-momo-sms-analytics/main/architecture.drawio)

---

## Scrum Board

**Link:** [GitHub Projects Board](https://github.com/users/luckydus5/projects/1/views/1)

---

## Project Structure

```
G10-momo-sms-analytics/
├── README.md
├── CONTRIBUTING.md
├── .gitignore
├── .env.example
├── requirements.txt
├── architecture.drawio
├── frontend/
│   ├── index.html
│   ├── css/styles.css
│   └── js/
│       ├── chart_handler.js
│       ├── api.js
│       └── ui.js
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
├── data/
│   ├── raw/momo.xml
│   ├── processed/dashboard.json
│   ├── db.sqlite3
│   └── logs/
│       ├── etl.log
│       └── dead_letter/
└── scripts/
    ├── run_etl.sh
    ├── export_json.sh
    └── serve_frontend.sh
```

---

## Getting Started

```bash
git clone https://github.com/luckydus5/G10-momo-sms-analytics.git
cd G10-momo-sms-analytics
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python backend/etl/run.py --xml data/raw/momo.xml
bash scripts/serve_frontend.sh
# Open http://localhost:8000
```

---

## License

Submitted as part of a formative assessment at the African Leadership University.  
All code is original work produced by Group 10 members.
