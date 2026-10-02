CREATE TABLE benchmark_numbers (
    n BIGINT PRIMARY KEY
);

INSERT INTO benchmark_numbers (n)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < 1000000
)
SELECT n FROM seq;

CREATE TABLE benchmark_parent (
    id BIGINT PRIMARY KEY,
    account_number BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL,
    payload TEXT NOT NULL,
    INDEX idx_benchmark_parent_account (account_number),
    INDEX idx_benchmark_parent_status (status)
);

CREATE TABLE benchmark_child (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL,
    sequence_number INT NOT NULL,
    value_number INT NOT NULL,
    payload TEXT NOT NULL,
    INDEX idx_benchmark_child_parent (parent_id),
    CONSTRAINT fk_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES benchmark_parent(id)
);

CREATE TABLE benchmark_event (
    id BIGINT PRIMARY KEY,
    parent_id BIGINT NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    event_time DATETIME NOT NULL,
    payload TEXT NOT NULL,
    INDEX idx_benchmark_event_parent (parent_id),
    CONSTRAINT fk_event_parent
        FOREIGN KEY (parent_id)
        REFERENCES benchmark_parent(id)
);

INSERT INTO benchmark_parent
SELECT
    n,
    MOD(n * 7919, 10000) + 1,
    CASE
        WHEN MOD(n,4) = 0 THEN 'complete'
        WHEN MOD(n,4) = 1 THEN 'active'
        WHEN MOD(n,4) = 2 THEN 'pending'
        ELSE 'archived'
    END,
    DATE_ADD('2025-01-01 00:00:00',
        INTERVAL MOD(n,31536000) SECOND),
    REPEAT('P',256)
FROM benchmark_numbers
WHERE n <= 100000;

INSERT INTO benchmark_child
SELECT
    n,
    MOD(n - 1,100000) + 1,
    MOD(n - 1,10) + 1,
    MOD(n * 37,100000),
    REPEAT('C',512)
FROM benchmark_numbers
WHERE n <= 500000;

INSERT INTO benchmark_event
SELECT
    n,
    MOD(n - 1,100000) + 1,
    CASE
        WHEN MOD(n,3) = 0 THEN 'update'
        WHEN MOD(n,3) = 1 THEN 'sync'
        ELSE 'review'
    END,
    DATE_ADD('2025-01-01 00:00:00',
        INTERVAL MOD(n,31536000) SECOND),
    REPEAT('E',256)
FROM benchmark_numbers;

ANALYZE TABLE benchmark_parent;
ANALYZE TABLE benchmark_child;
ANALYZE TABLE benchmark_event;

DROP TABLE benchmark_numbers;
