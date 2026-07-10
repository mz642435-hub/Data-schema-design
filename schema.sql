-- Google Play Review Ingestion Database Schema
-- Purpose: Store source metadata, app metadata, ingestion runs,
-- raw reviews, processed reviews, and quality flags.

-- =========================
-- 1. Sources Table
-- =========================
CREATE TABLE sources (
    source_id SERIAL PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL UNIQUE,
    source_type VARCHAR(50),
    base_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 2. Apps Table
-- =========================
CREATE TABLE apps (
    app_id SERIAL PRIMARY KEY,
    source_id INT NOT NULL REFERENCES sources(source_id),

    platform_app_id VARCHAR(255) NOT NULL,
    app_name VARCHAR(255),
    developer_name VARCHAR(255),
    category VARCHAR(100),

    source_country VARCHAR(10),
    source_lang VARCHAR(10),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (source_id, platform_app_id, source_country, source_lang)
);

-- =========================
-- 3. Ingestion Runs Table
-- =========================
CREATE TABLE ingestion_runs (
    run_id SERIAL PRIMARY KEY,
    source_id INT NOT NULL REFERENCES sources(source_id),

    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    status VARCHAR(50),

    collection_method VARCHAR(100),
    parameters JSONB,

    total_reviews_fetched INT DEFAULT 0,
    new_reviews_inserted INT DEFAULT 0,
    duplicate_reviews_found INT DEFAULT 0,
    updated_reviews_found INT DEFAULT 0,

    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 4. Raw Reviews Table
-- =========================
CREATE TABLE raw_reviews (
    raw_review_id SERIAL PRIMARY KEY,

    source_id INT NOT NULL REFERENCES sources(source_id),
    app_id INT NOT NULL REFERENCES apps(app_id),
    run_id INT REFERENCES ingestion_runs(run_id),

    platform_review_id VARCHAR(255) NOT NULL,

    user_name TEXT,
    user_image TEXT,

    content_raw TEXT,
    score INT,
    thumbs_up_count INT,

    review_created_version VARCHAR(100),
    app_version VARCHAR(100),

    review_at TIMESTAMP,

    reply_content_raw TEXT,
    replied_at TIMESTAMP,

    source_lang VARCHAR(10),
    source_country VARCHAR(10),

    raw_payload JSONB,

    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (source_id, app_id, platform_review_id)
);

-- =========================
-- 5. Processed Reviews Table
-- =========================
CREATE TABLE processed_reviews (
    processed_review_id SERIAL PRIMARY KEY,

    raw_review_id INT NOT NULL UNIQUE REFERENCES raw_reviews(raw_review_id),

    content_clean TEXT,
    detected_language VARCHAR(20),

    review_length_chars INT,
    review_length_words INT,

    normalized_score INT,
    sentiment_label VARCHAR(50),

    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_version VARCHAR(50)
);

-- =========================
-- 6. Review Quality Flags Table
-- =========================
CREATE TABLE review_quality_flags (
    flag_id SERIAL PRIMARY KEY,

    raw_review_id INT NOT NULL UNIQUE REFERENCES raw_reviews(raw_review_id),

    is_missing_content BOOLEAN DEFAULT FALSE,
    is_short_review BOOLEAN DEFAULT FALSE,
    is_non_english BOOLEAN DEFAULT FALSE,
    is_missing_app_version BOOLEAN DEFAULT FALSE,
    is_duplicate_text BOOLEAN DEFAULT FALSE,
    has_url BOOLEAN DEFAULT FALSE,
    has_emoji_or_symbol BOOLEAN DEFAULT FALSE,
    has_developer_reply BOOLEAN DEFAULT FALSE,

    flag_notes TEXT,

    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 7. Useful Indexes
-- =========================

CREATE INDEX idx_raw_reviews_app_id
ON raw_reviews(app_id);

CREATE INDEX idx_raw_reviews_review_at
ON raw_reviews(review_at);

CREATE INDEX idx_raw_reviews_score
ON raw_reviews(score);

CREATE INDEX idx_raw_reviews_platform_review_id
ON raw_reviews(platform_review_id);

CREATE INDEX idx_processed_reviews_language
ON processed_reviews(detected_language);

CREATE INDEX idx_quality_flags_short_review
ON review_quality_flags(is_short_review);

CREATE INDEX idx_quality_flags_non_english
ON review_quality_flags(is_non_english);

CREATE INDEX idx_quality_flags_missing_app_version
ON review_quality_flags(is_missing_app_version);

-- =========================
-- 8. Example Initial Source Record
-- =========================

INSERT INTO sources (
    source_name,
    source_type,
    base_url
)
VALUES (
    'Google Play',
    'app_store',
    'https://play.google.com/store/apps'
)
ON CONFLICT (source_name) DO NOTHING;
