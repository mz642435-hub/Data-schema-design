# Google Play Review Database Schema Design

## 1. Purpose

This schema is designed for storing Google Play review data collected through a recurring ingestion pipeline.

The goal of the schema is to make the storage layer:

- Traceable
- Extensible
- Deduplicated
- Suitable for exploratory data analysis
- Suitable for downstream sentiment analysis and topic modeling

The schema supports app/source metadata, ingestion run tracking, raw review records, processed review fields, quality flags, timestamps, ratings, app version information, and developer reply fields when available.

---

## 2. Schema Overview

The database contains six main tables:

1. `sources`
2. `apps`
3. `ingestion_runs`
4. `raw_reviews`
5. `processed_reviews`
6. `review_quality_flags`

The relationship is:

```text
sources
  ↓
apps
  ↓
raw_reviews
  ↓
processed_reviews
  ↓
review_quality_flags

sources
  ↓
ingestion_runs
  ↓
raw_reviews
