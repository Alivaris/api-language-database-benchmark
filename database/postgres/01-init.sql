CREATE TABLE benchmark_parent (
    id BIGINT PRIMARY KEY,
    account_number BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_parent_account
    ON benchmark_parent(account_number);

CREATE INDEX idx_benchmark_parent_status
    ON benchmark_parent(status);

CREATE TABLE benchmark_child (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL REFERENCES benchmark_parent(id),
    sequence_number INTEGER NOT NULL,
    value_number INTEGER NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_child_parent
    ON benchmark_child(parent_id);

CREATE TABLE benchmark_event (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL REFERENCES benchmark_parent(id),
    event_type VARCHAR(20) NOT NULL,
    event_time TIMESTAMP NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_benchmark_event_parent
    ON benchmark_event(parent_id);

INSERT INTO benchmark_parent
SELECT
    n,
    ((n * 7919) % 10000) + 1,
    CASE
        WHEN n % 4 = 0 THEN 'complete'
        WHEN n % 4 = 1 THEN 'active'
        WHEN n % 4 = 2 THEN 'pending'
        ELSE 'archived'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('P', 256)
FROM generate_series(1, 100000) AS n;

INSERT INTO benchmark_child
SELECT
    n,
    ((n - 1) % 100000) + 1,
    ((n - 1) % 10) + 1,
    (n * 37) % 100000,
    repeat('C', 512)
FROM generate_series(1, 500000) AS n;

INSERT INTO benchmark_event
SELECT
    n,
    ((n - 1) % 100000) + 1,
    CASE
        WHEN n % 3 = 0 THEN 'update'
        WHEN n % 3 = 1 THEN 'sync'
        ELSE 'review'
    END,
    TIMESTAMP '2025-01-01 00:00:00'
        + (n % 31536000) * INTERVAL '1 second',
    repeat('E', 256)
FROM generate_series(1, 1000000) AS n;

ANALYZE;
