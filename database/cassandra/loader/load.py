import csv
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

from cassandra.cluster import Cluster
from cassandra.query import ConsistencyLevel


HOST = os.getenv("CASSANDRA_HOST", "benchmark_cassandra")
PORT = int(os.getenv("CASSANDRA_PORT", "9042"))
WORKERS = int(os.getenv("WORKERS", "8"))
DATA_DIR = "/data"


cluster = Cluster([HOST], port=PORT)
session = cluster.connect("benchmark")


statements = {
    "parent_by_id": session.prepare("""
        INSERT INTO parent_by_id
        (id, account_number, status, created_at, payload)
        VALUES (?, ?, ?, ?, ?)
    """),

    "parent_by_account": session.prepare("""
        INSERT INTO parent_by_account
        (account_number, id, status, created_at, payload)
        VALUES (?, ?, ?, ?, ?)
    """),

    "parent_by_status": session.prepare("""
        INSERT INTO parent_by_status
        (status, id, account_number, created_at, payload)
        VALUES (?, ?, ?, ?, ?)
    """),

    "child_by_parent": session.prepare("""
        INSERT INTO child_by_parent
        (parent_id, id, sequence_number, value_number, payload)
        VALUES (?, ?, ?, ?, ?)
    """),

    "event_by_parent": session.prepare("""
        INSERT INTO event_by_parent
        (parent_id, event_time, id, event_type, payload)
        VALUES (?, ?, ?, ?, ?)
    """),
}


def parse_timestamp(value):
    return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")


def write_one(statement, values):
    return session.execute(
        statement,
        values,
        timeout=30
    )


def load_file(filename, statement, converter):
    path = os.path.join(DATA_DIR, filename)

    print(f"Starting {filename}...", flush=True)

    start = time.perf_counter()
    completed = 0
    futures = []

    with open(path, newline="") as f:
        reader = csv.reader(f)

        with ThreadPoolExecutor(max_workers=WORKERS) as executor:

            for row in reader:
                values = converter(row)

                futures.append(
                    executor.submit(
                        write_one,
                        statement,
                        values
                    )
                )

                if len(futures) >= 1000:
                    for future in as_completed(futures):
                        future.result()
                        completed += 1

                    futures.clear()

                    elapsed = time.perf_counter() - start
                    rate = completed / elapsed if elapsed else 0

                    if completed % 10000 == 0:
                        print(
                            f"{filename}: "
                            f"{completed:,} rows "
                            f"({rate:,.0f} rows/sec)",
                            flush=True
                        )

            for future in as_completed(futures):
                future.result()
                completed += 1

    elapsed = time.perf_counter() - start
    rate = completed / elapsed if elapsed else 0

    print(
        f"{filename}: COMPLETE "
        f"{completed:,} rows "
        f"in {elapsed:.2f}s "
        f"({rate:,.0f} rows/sec)",
        flush=True
    )


load_file(
    "parent_by_id.csv",
    statements["parent_by_id"],
    lambda r: (
        int(r[0]),
        int(r[1]),
        r[2],
        parse_timestamp(r[3]),
        r[4],
    ),
)


load_file(
    "parent_by_account.csv",
    statements["parent_by_account"],
    lambda r: (
        int(r[0]),
        int(r[1]),
        r[2],
        parse_timestamp(r[3]),
        r[4],
    ),
)


load_file(
    "parent_by_status.csv",
    statements["parent_by_status"],
    lambda r: (
        r[0],
        int(r[1]),
        int(r[2]),
        parse_timestamp(r[3]),
        r[4],
    ),
)


load_file(
    "child_by_parent.csv",
    statements["child_by_parent"],
    lambda r: (
        int(r[0]),
        int(r[1]),
        int(r[2]),
        int(r[3]),
        r[4],
    ),
)


load_file(
    "event_by_parent.csv",
    statements["event_by_parent"],
    lambda r: (
        int(r[0]),
        parse_timestamp(r[1]),
        int(r[2]),
        r[3],
        r[4],
    ),
)


cluster.shutdown()

print("ALL CASSANDRA DATA LOADED.", flush=True)
