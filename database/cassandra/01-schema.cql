CREATE KEYSPACE IF NOT EXISTS benchmark
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
}
AND durable_writes = true;

USE benchmark;

CREATE TABLE IF NOT EXISTS parent_by_id (
    id bigint PRIMARY KEY,
    account_number bigint,
    status text,
    created_at timestamp,
    payload text
);

CREATE TABLE IF NOT EXISTS child_by_parent (
    parent_id bigint,
    id bigint,
    sequence_number int,
    value_number int,
    payload text,
    PRIMARY KEY (parent_id, id)
);

CREATE TABLE IF NOT EXISTS event_by_parent (
    parent_id bigint,
    event_time timestamp,
    id bigint,
    event_type text,
    payload text,
    PRIMARY KEY (parent_id, event_time, id)
) WITH CLUSTERING ORDER BY (
    event_time DESC,
    id DESC
);

CREATE TABLE IF NOT EXISTS parent_by_account (
    account_number bigint,
    id bigint,
    status text,
    created_at timestamp,
    payload text,
    PRIMARY KEY (account_number, id)
);

CREATE TABLE IF NOT EXISTS parent_by_status (
    status text,
    id bigint,
    account_number bigint,
    created_at timestamp,
    payload text,
    PRIMARY KEY (status, id)
);
