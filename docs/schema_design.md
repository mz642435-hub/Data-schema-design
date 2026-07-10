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
```
---

## 3. Table Descriptions

### 3.1 `sources`

The `sources` table stores information about each data source used in the ingestion pipeline.

For the current stage, the main source is Google Play. However, this table makes the schema extensible because additional sources, such as the Apple App Store, can be added later without changing the overall database structure.

Important fields:

| Field         | Description                                  |
| ------------- | -------------------------------------------- |
| `source_id`   | Primary key for each source                  |
| `source_name` | Name of the source, such as Google Play      |
| `source_type` | Type of source, such as app store            |
| `base_url`    | Base URL of the source                       |
| `created_at`  | Timestamp when the source record was created |

Primary key:

```text
source_id
```

---

### 3.2 `apps`

The `apps` table stores app-level metadata.

For Google Play, the `platform_app_id` field stores the app package name, such as `com.spotify.music` or `com.duolingo`. Separating app metadata from review data avoids repeating the same app information across many review rows.

Important fields:

| Field             | Description                               |
| ----------------- | ----------------------------------------- |
| `app_id`          | Internal primary key for each app         |
| `source_id`       | Foreign key linking the app to its source |
| `platform_app_id` | Native app identifier from the platform   |
| `app_name`        | Name of the app                           |
| `developer_name`  | Name of the app developer                 |
| `category`        | App category                              |
| `source_country`  | Country used during collection            |
| `source_lang`     | Language used during collection           |
| `created_at`      | Timestamp when the app record was created |

Primary key:

```text
app_id
```

Foreign key:

```text
source_id → sources.source_id
```

Unique constraint:

```text
source_id + platform_app_id + source_country + source_lang
```

This prevents duplicate app records for the same source, app, country, and language combination.

---

### 3.3 `ingestion_runs`

The `ingestion_runs` table records each time the review collection pipeline is executed.

This table is important for traceability. It allows the team to understand when data was collected, what parameters were used, whether the run succeeded, and how many reviews were fetched, inserted, duplicated, or updated.

Important fields:

| Field                     | Description                                     |
| ------------------------- | ----------------------------------------------- |
| `run_id`                  | Primary key for each ingestion run              |
| `source_id`               | Foreign key linking the run to the data source  |
| `started_at`              | Timestamp when the ingestion run started        |
| `completed_at`            | Timestamp when the ingestion run completed      |
| `status`                  | Run status, such as success, failed, or partial |
| `collection_method`       | Method or tool used for collection              |
| `parameters`              | JSON object storing collection parameters       |
| `total_reviews_fetched`   | Total number of reviews fetched in the run      |
| `new_reviews_inserted`    | Number of new reviews inserted                  |
| `duplicate_reviews_found` | Number of duplicate reviews found               |
| `updated_reviews_found`   | Number of existing reviews updated              |
| `error_message`           | Error message if the run failed                 |
| `created_at`              | Timestamp when the run record was created       |

Primary key:

```text
run_id
```

Foreign key:

```text
source_id → sources.source_id
```

Example collection parameters:

```json
{
  "lang": "en",
  "country": "us",
  "sort": "NEWEST",
  "count_per_batch": 200,
  "target_per_app": 2500
}
```

---

### 3.4 `raw_reviews`

The `raw_reviews` table stores the original review records as collected from Google Play.

This is the core table of the schema. It preserves the raw review text, rating, timestamp, app version, developer reply fields, and original payload. Keeping the raw data is important because it allows future reprocessing if the cleaning or modeling logic changes.

Important fields:

| Field                    | Description                                         |
| ------------------------ | --------------------------------------------------- |
| `raw_review_id`          | Internal primary key for each raw review            |
| `source_id`              | Foreign key linking the review to the source        |
| `app_id`                 | Foreign key linking the review to the app           |
| `run_id`                 | Foreign key linking the review to the ingestion run |
| `platform_review_id`     | Native review ID from Google Play                   |
| `user_name`              | Displayed username of the reviewer                  |
| `user_image`             | Reviewer profile image URL                          |
| `content_raw`            | Original review text                                |
| `score`                  | Star rating given by the user                       |
| `thumbs_up_count`        | Number of thumbs-up votes on the review             |
| `review_created_version` | App version when the review was created             |
| `app_version`            | App version associated with the review              |
| `review_at`              | Timestamp when the review was posted or updated     |
| `reply_content_raw`      | Developer reply text, if available                  |
| `replied_at`             | Timestamp of developer reply, if available          |
| `source_lang`            | Language used during collection                     |
| `source_country`         | Country used during collection                      |
| `raw_payload`            | Full raw JSON payload from collection               |
| `collected_at`           | Timestamp when the review was collected             |
| `updated_at`             | Timestamp when the review record was last updated   |

Primary key:

```text
raw_review_id
```

Foreign keys:

```text
source_id → sources.source_id
app_id → apps.app_id
run_id → ingestion_runs.run_id
```

Unique constraint:

```text
source_id + app_id + platform_review_id
```

This unique constraint supports deduplication across repeated ingestion runs.

---

### 3.5 `processed_reviews`

The `processed_reviews` table stores cleaned and model-ready review fields.

This table is separated from `raw_reviews` so that the original collected review remains unchanged. If the team later updates the text-cleaning logic, language detection method, or sentiment labeling approach, the reviews can be reprocessed without recollecting the original data.

Important fields:

| Field                 | Description                                         |
| --------------------- | --------------------------------------------------- |
| `processed_review_id` | Primary key for each processed review               |
| `raw_review_id`       | Foreign key linking to the original raw review      |
| `content_clean`       | Cleaned review text                                 |
| `detected_language`   | Detected language of the review text                |
| `review_length_chars` | Review length measured in characters                |
| `review_length_words` | Review length measured in words                     |
| `normalized_score`    | Cleaned or standardized rating score                |
| `sentiment_label`     | Sentiment label derived from rating or model output |
| `processed_at`        | Timestamp when the review was processed             |
| `processing_version`  | Version of the processing logic used                |

Primary key:

```text
processed_review_id
```

Foreign key:

```text
raw_review_id → raw_reviews.raw_review_id
```

Unique constraint:

```text
raw_review_id
```

This means each raw review has one current processed review record.

---

### 3.6 `review_quality_flags`

The `review_quality_flags` table stores data quality indicators for each review.

Quality issues are tracked as flags instead of being immediately removed. This allows analysts to decide later whether to filter, segment, or separately analyze reviews with quality concerns.

Important fields:

| Field                    | Description                                           |
| ------------------------ | ----------------------------------------------------- |
| `flag_id`                | Primary key for each quality flag record              |
| `raw_review_id`          | Foreign key linking to the original raw review        |
| `is_missing_content`     | True if the review text is missing or empty           |
| `is_short_review`        | True if the review is very short                      |
| `is_non_english`         | True if the detected language is not English          |
| `is_missing_app_version` | True if app version information is missing            |
| `is_duplicate_text`      | True if the same review text appears multiple times   |
| `has_url`                | True if the review contains a URL                     |
| `has_emoji_or_symbol`    | True if the review contains emojis or unusual symbols |
| `has_developer_reply`    | True if a developer reply exists                      |
| `flag_notes`             | Optional notes about quality issues                   |
| `flagged_at`             | Timestamp when the review was flagged                 |

Primary key:

```text
flag_id
```

Foreign key:

```text
raw_review_id → raw_reviews.raw_review_id
```

Unique constraint:

```text
raw_review_id
```

This means each raw review has one current quality flag record.

---

## 4. Deduplication Logic

Google Play provides a stable review identifier called `reviewId`. In this schema, that value is stored as:

```text
platform_review_id
```

The main deduplication key is:

```text
source_id + app_id + platform_review_id
```

This combination is enforced in the `raw_reviews` table using the following unique constraint:

```sql
UNIQUE (source_id, app_id, platform_review_id)
```

This prevents the same review from being inserted multiple times across repeated ingestion runs.

The intended ingestion logic is:

```text
If a review is new:
    Insert it into raw_reviews.

If a review already exists:
    Update fields that may have changed, such as:
    - content_raw
    - score
    - thumbs_up_count
    - review_created_version
    - app_version
    - review_at
    - reply_content_raw
    - replied_at
    - updated_at
```

This is important because users can update their Google Play reviews after posting them. A user may change the review text, update the rating, or revise the review after a new app version is released.

The schema therefore treats repeated collection as an opportunity to detect both new reviews and updated reviews.

---

## 5. Quality Flag Logic

The schema tracks quality issues using the `review_quality_flags` table.

Quality issues are stored as boolean flags instead of being filtered out immediately. This gives analysts flexibility later because different downstream tasks may require different filtering rules.

Suggested flag definitions:

```text
is_missing_content:
    True if content_raw is null or empty.

is_short_review:
    True if review_length_words <= 3.

is_non_english:
    True if detected_language is not English.

is_missing_app_version:
    True if app_version is null.

is_duplicate_text:
    True if the same review text appears multiple times for the same app.

has_url:
    True if content_raw contains "http", "https", or "www".

has_emoji_or_symbol:
    True if content_raw contains emojis, unusual symbols, or excessive special characters.

has_developer_reply:
    True if reply_content_raw is not null.
```

These flags help track common data quality concerns identified during the Google Play review EDA, including short reviews, missing app version values, non-English content, duplicated text, and formatting issues.

The quality flags do not automatically remove reviews from the dataset. Instead, they allow future users to decide whether to keep, remove, segment, or separately analyze flagged reviews.

For example:

```text
Sentiment analysis may still use short reviews.
Topic modeling may exclude very short reviews.
Version-level analysis may exclude reviews missing app_version.
Language-specific analysis may filter to detected_language = 'en'.
```

This approach preserves the data while making quality issues visible and measurable.

---

## 6. Design Trade-offs

### 6.1 Raw and processed data are separated

The schema separates `raw_reviews` from `processed_reviews`.

The `raw_reviews` table stores the original data exactly as collected from Google Play. The `processed_reviews` table stores cleaned and model-ready fields, such as cleaned text, detected language, review length, normalized score, and sentiment label.

This design increases storage slightly, but it improves traceability and reproducibility.

If the team later changes the text-cleaning method, language detection logic, or sentiment labeling approach, the raw review data can be reprocessed without recollecting it.

---

### 6.2 Quality issues are flagged, not deleted

The schema does not immediately remove short reviews, non-English reviews, missing app versions, duplicated text, or reviews with formatting issues.

Instead, these issues are stored in `review_quality_flags`.

This design is useful because different analysis tasks may require different filtering rules. For example, a short review such as “Great app” may be useful for sentiment analysis but not very useful for topic modeling.

Flagging quality issues allows the team to keep the dataset complete while still making quality concerns easy to identify.

---

### 6.3 App metadata is separated from review records

The `apps` table stores app-level metadata separately from the review data.

This avoids repeating the same app information in every review row and makes the schema easier to maintain as more apps are added.

For example, instead of storing the app name, developer name, category, country, and language repeatedly in every review row, the review can simply reference the internal `app_id`.

---

### 6.4 Ingestion runs are tracked separately

The `ingestion_runs` table records each time the collection pipeline is executed.

This supports traceability because the team can answer questions such as:

```text
When was this review collected?
Which collection method was used?
Which language and country settings were used?
How many reviews were fetched?
How many were new?
How many were duplicates?
Did the ingestion run succeed or fail?
```

This is important for a recurring pipeline because the same app may be collected many times over time.

---

### 6.5 The schema is designed for extensibility

Although the current pipeline focuses on Google Play, the schema is designed to support other sources in the future.

For example, the Apple App Store could be added as another record in the `sources` table. The `platform_app_id` field can store the native app identifier from each platform, and the `platform_review_id` field can store the native review identifier from each platform.

This avoids designing the schema only around one source and makes the pipeline easier to expand later.

---

## 7. Future Extensibility

The current schema is designed for Google Play reviews, but it can be extended to support additional data sources and additional downstream modeling tasks.

### 7.1 Adding the Apple App Store

If the Apple App Store is added later, it can be stored as a new record in the `sources` table.

Example:

```text
source_name: Apple App Store
source_type: app_store
base_url: https://apps.apple.com
```

Apple app IDs can be stored in the `platform_app_id` field, and Apple review IDs can be stored in the `platform_review_id` field.

This means the same `apps`, `ingestion_runs`, `raw_reviews`, `processed_reviews`, and `review_quality_flags` tables can support both Google Play and iOS reviews.

---

### 7.2 Supporting additional processing outputs

The `processed_reviews` table currently supports cleaned text, detected language, review length, normalized score, and sentiment label.

Later, this can be expanded to include fields such as:

```text
topic_label
aspect_label
model_sentiment_score
toxicity_score
feature_request_flag
bug_report_flag
complaint_category
```

These fields would support more advanced downstream analysis, such as aspect-based sentiment analysis, topic modeling, issue classification, and product feedback summarization.

---

### 7.3 Supporting review history

The current design stores one current record per platform review ID in `raw_reviews`.

If the team wants to preserve every historical version of an updated review, a future table could be added:

```text
review_history
```

This table could store snapshots of reviews whenever the content, rating, app version, or developer reply changes.

A possible design would include:

```text
history_id
raw_review_id
content_raw
score
app_version
reply_content_raw
snapshot_at
change_type
```

This is not required for the first version, but it may be useful if the team wants to analyze how reviews change over time.

---

### 7.4 Supporting app metadata snapshots

App-level metadata can also change over time. For example, app category, rating count, install count, or developer information may change.

If this becomes important, the team could add an app metadata snapshot table:

```text
app_metadata_snapshots
```

This would allow the pipeline to track changes in app-level metadata over time.

---

## 8. Summary

This schema supports the main requirements of the Google Play review ingestion pipeline.

It includes tables for:

```text
sources
apps
ingestion_runs
raw_reviews
processed_reviews
review_quality_flags
```

The design supports:

```text
source metadata
app metadata
ingestion run tracking
raw review storage
cleaned and processed review fields
quality flags
duplicate handling
timestamps
ratings
app version information
developer reply fields
future source expansion
```

The main deduplication key is:

```text
source_id + app_id + platform_review_id
```

This is appropriate for Google Play because each review has a stable `reviewId`.

The schema also separates raw data from processed data. This preserves the original collected reviews while allowing cleaned and model-ready fields to be generated separately.

Quality issues are tracked as flags instead of being removed immediately. This makes the dataset more flexible for future EDA, sentiment analysis, topic modeling, and product feedback analysis.

Overall, the schema is designed to be traceable, extensible, and useful for downstream analysis and modeling.
