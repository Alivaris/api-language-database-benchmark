# API Language & Database Benchmark

A reproducible benchmark project comparing API implementations across multiple programming languages and database systems.

This project started as a relatively simple question:

> How much does the programming language actually matter for a database-backed API?

It quickly became a much larger experiment involving isolated benchmarks, overload behavior, shared-server contention, database connection pools, runtime behavior, operating-system limits, and failure recovery.

Rather than testing only ideal laboratory conditions, this project also includes tests where many different applications compete for the same physical server resources at the same time.

The raw benchmark results are included in this repository.

---

## Why This Benchmark Exists

Most language benchmarks intentionally isolate the program being tested.

That is useful, but real servers often look very different.

A production server may have:

- multiple APIs
- background workers
- web applications
- databases
- mail services
- scheduled jobs
- containers
- monitoring
- other unrelated workloads

all competing for the same CPU, memory, scheduler time, sockets, and database resources.

This project therefore contains two different kinds of testing:

1. **Isolated benchmarks**
   - One API implementation under test
   - Controlled resource limits
   - Shared benchmark schema
   - Same endpoint and dataset

2. **Shared-host contention benchmarks**
   - All API implementations running simultaneously
   - All hitting the same PostgreSQL database
   - All competing for the same 12 CPU cores
   - Load generators also running on the same host
   - Designed to expose overload and resource-contention behavior

These tests answer different questions and should not be treated as interchangeable.

---

# Languages

The current benchmark contains 13 API implementations:

1. Go
2. Rust
3. Node.js / Fastify
4. Python / FastAPI
5. PHP / PHP-FPM + nginx
6. C++
7. Java / Vert.x
8. Elixir / Phoenix
9. Ruby / Roda + Puma
10. Haskell / Scotty + Warp
11. V / veb
12. Nim / Mummy
13. Zig / Zap

## Why Zig Is Number 13

Zig was not originally going to be tested.

The original benchmark was planned around twelve languages.

Then Nim produced unexpectedly strong results.

That exposed a flaw in the assumptions behind the benchmark itself: excluding a language because we expected another language to be faster defeated part of the purpose of doing the benchmark.

Zig was therefore added after the original twelve implementations were completed.

That decision turned out to be useful because Zig became one of the stronger implementations in several tests.

---

# Databases

The project currently includes benchmark environments for:

- PostgreSQL
- MariaDB
- CockroachDB
- Cassandra

MongoDB is also being considered for a later query-native benchmark.

The database implementations are not intended to force every database into an identical relational model when that would be inappropriate.

For example, Cassandra uses a denormalized query-oriented schema rather than pretending to be PostgreSQL.

---

# Benchmark Dataset

The relational benchmark currently uses three primary tables:

- `benchmark_parent`
- `benchmark_child`
- `benchmark_event`

The seeded dataset contains approximately:

- 100,000 parent rows
- 500,000 child rows
- 1,000,000 event rows

The data is deterministic so benchmark environments can reproduce the same logical dataset.

Generated Cassandra CSV files are intentionally not stored in Git because they are hundreds of megabytes in size.

They can be recreated using:

    database/cassandra/generate_seed.py

---

# Current API Contract

The benchmark API is designed around endpoints including:

    GET /health
    GET /parent/{id}
    GET /parent/{id}/children
    GET /parent/{id}/events
    GET /parent/{id}/bundle
    GET /account/{id}/parents
    POST /event

The first official language comparison concentrates on the hot indexed lookup:

    GET /parent/50000

Additional workloads will be tested separately.

---

# Benchmark Runner

The load generator is itself written in Go.

It records:

- successful requests
- errors
- requests per second
- average latency
- p50 latency
- p95 latency
- p99 latency
- maximum latency

The current runner timeout is 10 seconds.

Therefore, latency values clustered around 10 seconds during overload often represent the client timeout boundary rather than the server completing the request at exactly ten seconds.

The runner source is located at:

    benchmark/runner/

---

# Isolated Benchmark

The initial language comparison tests one API stack at a time.

Concurrency levels:

    1
    10
    50
    100
    250
    500
    1000

Each official level runs for approximately 30 seconds.

The goal is to measure:

- low-concurrency latency
- throughput growth
- saturation
- tail latency
- overload behavior
- error behavior

Raw results are stored under:

    benchmark/results/

---

# Shared-Host Contention Benchmark

The contention benchmark is intentionally different.

All 13 APIs run simultaneously.

All of them query the same PostgreSQL instance.

Each API is allowed to compete for the resources of the same physical server.

Current test machine:

    12 CPUs
    approximately 94 GiB RAM

During the shared-host test, each container is allowed access to all 12 CPUs and up to 90 GiB RAM.

Those values are ceilings, not reservations.

The Linux scheduler decides which programs actually receive CPU time when all applications compete simultaneously.

PostgreSQL is also allowed to compete for the same server resources.

For the contention benchmark:

    PostgreSQL max_connections = 2000

The API applications are restarted before each concurrency level so a failure caused by one overload level does not contaminate the next test.

PostgreSQL remains running so its caches remain warm.

Concurrency is applied independently to every language.

For example:

    concurrency 1    = 13 total clients
    concurrency 10   = 130 total clients
    concurrency 50   = 650 total clients
    concurrency 100  = 1,300 total clients
    concurrency 250  = 3,250 total clients
    concurrency 500  = 6,500 total clients
    concurrency 1000 = 13,000 total clients

The benchmark runners currently execute on the same server as the APIs.

This makes the test a **whole-machine contention benchmark**.

A future version will repeat the experiment using an external load-generation machine so that load-generator CPU usage does not compete with the APIs.

The contention scripts are located under:

    benchmark/contention/

Raw results are located under:

    benchmark/results/contention_13_official/

---

# Important Early Findings

These are observations from the current implementations and current benchmark runs.

They are **not claims that one programming language is universally faster than another**.

Different frameworks, drivers, pool configurations, worker counts, runtime settings, and workloads can substantially change results.

## Peak Speed Is Not the Same as Overload Resilience

Some implementations delivered very high peak throughput but behaved poorly once concurrency exceeded their practical operating range.

Other implementations produced less peak throughput but continued returning successful responses during extreme overload.

Those are different engineering characteristics.

## Shared-Server Performance Can Look Very Different

Several languages behaved very differently when tested alone compared with when all thirteen APIs competed for the same machine.

This is one of the major reasons the contention benchmark exists.

A runtime's performance while owning the machine does not necessarily predict how it behaves while competing with unrelated workloads.

## Nim File Descriptor Failure

Nim/Mummy produced some of the highest throughput observed in the benchmark.

At extreme concurrency, however, the service terminated.

The immediate error was:

    Maximum number of descriptors is exhausted!

Investigation showed:

    soft nofile limit: 1024
    hard nofile limit: 524288

The process exhausted its soft file-descriptor limit.

The container was:

    OOMKilled=false

This is an important benchmark lesson.

What initially looked like a language or framework scalability failure was actually an operating-system/container resource limit.

A later production-style benchmark will normalize the file descriptor limit across implementations.

## Running Does Not Always Mean Healthy

During an earlier contention test, the Haskell container remained in the Docker `running` state while requests were failing.

Restarting the application restored normal operation.

This illustrates why container status alone is not sufficient evidence that an application is healthy.

---

# Benchmark Philosophy

The project follows several rules.

## Do Not Hide Failures

Crashes, timeout walls, configuration problems, dependency problems, and unexpected results are part of the benchmark.

They are documented rather than removed.

## Separate Our Mistakes From Toolchain Problems

Not every setup problem should count against a programming language.

Examples of mistakes made while constructing the benchmark include:

- Docker entrypoint mistakes
- assumptions about Docker image users
- incorrect framework API assumptions
- container lifetime mistakes

Those should not be described as language failures.

Real ecosystem or runtime friction is documented separately.

## Native Does Not Automatically Mean Fast

A native executable is not automatically the fastest database-backed HTTP API.

HTTP architecture, database drivers, connection pools, synchronization, scheduling, and framework design can dominate the cost of the endpoint.

## One Run Is Not Enough for Final Conclusions

The current repository preserves the first official runs.

Later benchmark phases will repeat important tests multiple times and use medians or distributions rather than treating one run as absolute truth.

---

# Planned Benchmark Expansion

Future tests are expected to include:

- repeated benchmark runs
- randomized parent IDs
- relational child queries
- event queries
- bundle queries
- pagination
- transactional writes
- batch writes
- aggregation
- large JSON responses
- CPU-bound workloads
- hashing workloads
- additional database comparisons
- optimized production configurations
- external load generation
- file-descriptor normalization
- worker/process tuning
- full 12-core runtime optimization

A browser/frontend benchmark is also being considered.

Possible browser targets include:

- JavaScript
- Rust/WASM
- C++/WASM
- C# / Blazor
- Dart
- Kotlin/Wasm
- AssemblyScript
- Go/WASM
- Python/PyScript

And yes, an Assembly implementation may eventually appear on the server side as an experimental control.

---

# Repository Layout

    api/
        cpp/
        elixir/
        go/
        haskell/
        java/
        nim/
        node/
        php/
        python/
        ruby/
        rust/
        v/
        zig/

    benchmark/
        contention/
        results/
        runner/

    database/
        cassandra/
        cockroach/
        mariadb/
        postgres/

    compose.yml

---

# Security Notice

Credentials such as:

    benchmark_password

are intentionally synthetic benchmark credentials.

They are not production credentials and should never be copied into a real production environment.

---

# Companion Book

A companion book is being written alongside this repository.

The goal of the book is not simply to publish a table of benchmark numbers.

It will document the entire process, including:

- benchmark design
- Docker setup
- database design
- deterministic data generation
- language implementation
- framework choices
- mistakes
- failed approaches
- dependency problems
- runtime behavior
- connection pooling
- concurrency
- overload behavior
- operating-system limits
- unexpected results
- lessons learned
- final comparisons

The mistakes are important.

In several cases, the most useful lessons came from something failing in a way we did not expect.

The repository will remain the source for the code and raw benchmark data, while the book will provide the narrative, explanation, analysis, and step-by-step reproduction guide.

## Planned Book Pricing and Availability

The goal of the companion book is not to maximize the price.

The goal is to make the complete benchmark, methodology, mistakes, and lessons learned available to as many people as possible at minimal cost.

The current target price for the digital book is:

- **$0.99 on Amazon Kindle**, if Amazon's pricing rules permit it
- similarly low-cost distribution through other platforms where practical

Kindle Unlimited is also being considered.

However, participation in Kindle Unlimited currently requires enrollment in Amazon KDP Select, which requires the digital edition of the book to remain exclusive to Amazon during the enrollment period.

Because the goal of this project is broad availability rather than exclusivity, a final decision about Kindle Unlimited has not yet been made.

The source code and raw benchmark results in this GitHub repository will remain available independently of the book.

---

# Project Status

This project is actively being developed.

Results currently in the repository should be considered benchmark observations, not universal rankings of programming languages.

The benchmark will continue to evolve as additional workloads, databases, configurations, and repeat runs are added.

If you reproduce one of these tests and obtain a different result, that is useful information.

Hardware, operating systems, runtime versions, kernel settings, database configuration, and framework versions all matter.

---

# Author / Project

Benchmark project maintained under the **Alivaris** GitHub account.

The companion book is being developed alongside the benchmark project.

