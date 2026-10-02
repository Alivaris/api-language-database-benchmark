import csv
from datetime import datetime, timedelta
from pathlib import Path

out = Path("database/cassandra/data")
out.mkdir(parents=True, exist_ok=True)

base = datetime(2025, 1, 1)

print("Generating parent tables...")

with open(out / "parent_by_id.csv", "w", newline="") as f1, \
     open(out / "parent_by_account.csv", "w", newline="") as f2, \
     open(out / "parent_by_status.csv", "w", newline="") as f3:

    w1 = csv.writer(f1)
    w2 = csv.writer(f2)
    w3 = csv.writer(f3)

    for n in range(1, 100001):
        account = ((n * 7919) % 10000) + 1

        if n % 4 == 0:
            status = "complete"
        elif n % 4 == 1:
            status = "active"
        elif n % 4 == 2:
            status = "pending"
        else:
            status = "archived"

        created = (
            base + timedelta(seconds=n % 31536000)
        ).strftime("%Y-%m-%d %H:%M:%S")

        payload = "P" * 256

        w1.writerow([n, account, status, created, payload])
        w2.writerow([account, n, status, created, payload])
        w3.writerow([status, n, account, created, payload])


print("Generating children...")

with open(out / "child_by_parent.csv", "w", newline="") as f:
    w = csv.writer(f)

    for n in range(1, 500001):
        parent = ((n - 1) % 100000) + 1

        w.writerow([
            parent,
            n,
            ((n - 1) % 10) + 1,
            (n * 37) % 100000,
            "C" * 512
        ])


print("Generating events...")

with open(out / "event_by_parent.csv", "w", newline="") as f:
    w = csv.writer(f)

    for n in range(1, 1000001):
        parent = ((n - 1) % 100000) + 1

        if n % 3 == 0:
            event_type = "update"
        elif n % 3 == 1:
            event_type = "sync"
        else:
            event_type = "review"

        event_time = (
            base + timedelta(seconds=n % 31536000)
        ).strftime("%Y-%m-%d %H:%M:%S")

        w.writerow([
            parent,
            event_time,
            n,
            event_type,
            "E" * 256
        ])

print("Finished generating Cassandra benchmark data.")
