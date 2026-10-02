#!/usr/bin/env bash

set -u

NETWORK="api_benchmark_network"
RUNNER="api-benchmark-runner"
OUT="benchmark/results/contention_13_official"
DURATION=30
SETTLE=15

LANGS=(
  go
  rust
  node
  python
  php
  cpp
  java
  elixir
  ruby
  haskell
  v
  nim
  zig
)

CONTAINERS=(
  benchmark_go_postgres
  benchmark_rust_postgres
  benchmark_node_postgres
  benchmark_python_postgres
  benchmark_php_postgres
  benchmark_cpp_postgres
  benchmark_java_postgres
  benchmark_elixir_postgres
  benchmark_ruby_postgres
  benchmark_haskell_postgres
  benchmark_v_postgres
  benchmark_nim_postgres
  benchmark_zig_postgres
)

declare -A URLS=(
  [go]="http://benchmark_go_postgres:8080/parent/50000"
  [rust]="http://benchmark_rust_postgres:8080/parent/50000"
  [node]="http://benchmark_node_postgres:8080/parent/50000"
  [python]="http://benchmark_python_postgres:8080/parent/50000"
  [php]="http://benchmark_php_postgres:8080/parent/50000"
  [cpp]="http://benchmark_cpp_postgres:8080/parent/50000"
  [java]="http://benchmark_java_postgres:8080/parent/50000"
  [elixir]="http://benchmark_elixir_postgres:8080/parent/50000"
  [ruby]="http://benchmark_ruby_postgres:8080/parent/50000"
  [haskell]="http://benchmark_haskell_postgres:8080/parent/50000"
  [v]="http://benchmark_v_postgres:8080/parent/50000"
  [nim]="http://benchmark_nim_postgres:8080/parent/50000"
  [zig]="http://benchmark_zig_postgres:8080/parent/50000"
)

LEVELS=(1 10 50 100 250 500 1000)

mkdir -p "$OUT"

for C in "${LEVELS[@]}"
do
  DIR="${OUT}/c${C}"
  mkdir -p "$DIR"

  echo
  echo "=========================================================="
  echo "13-WAY OFFICIAL CONTENTION"
  echo "CONCURRENCY PER LANGUAGE: $C"
  echo "TOTAL HTTP CLIENTS: $((C * 13))"
  echo "=========================================================="
  echo

  echo "Restarting all 13 API containers..."

  docker restart "${CONTAINERS[@]}" \
    > "${DIR}/restart.txt" 2>&1

  echo "Waiting ${SETTLE} seconds for applications to initialize..."
  sleep "$SETTLE"

  echo "Recording PostgreSQL connections before test..."

  docker exec benchmark_postgres \
    psql -U benchmark -d benchmark \
    -Atc "SELECT count(*) FROM pg_stat_activity;" \
    > "${DIR}/postgres_connections_before.txt"

  echo "Starting all 13 benchmark runners..."

  PIDS=()

  for LANG in "${LANGS[@]}"
  do
    (
      docker run --rm \
        --network "$NETWORK" \
        "$RUNNER" \
        -url "${URLS[$LANG]}" \
        -concurrency "$C" \
        -duration "${DURATION}s" \
        > "${DIR}/${LANG}.txt" 2>&1
    ) &

    PIDS+=("$!")
  done

  FAIL=0

  for PID in "${PIDS[@]}"
  do
    if ! wait "$PID"
    then
      FAIL=1
    fi
  done

  echo
  echo "All runners completed."
  echo

  docker exec benchmark_postgres \
    psql -U benchmark -d benchmark \
    -Atc "SELECT count(*) FROM pg_stat_activity;" \
    > "${DIR}/postgres_connections_after.txt"

  {
    echo "CONTAINER STATE AFTER C=${C}"
    echo

    for CONTAINER in "${CONTAINERS[@]}"
    do
      docker inspect "$CONTAINER" \
        --format '{{.Name}} Status={{.State.Status}} ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}'
    done
  } > "${DIR}/container_state.txt"

  echo "---------- RESULTS: C=${C} ----------"
  echo

  for LANG in "${LANGS[@]}"
  do
    echo "---------- ${LANG^^} ----------"

    grep -E \
      'Requests:|Errors:|Requests/sec:|Average:|p50:|p95:|p99:|Max:' \
      "${DIR}/${LANG}.txt" || true

    echo
  done

  BEFORE=$(cat "${DIR}/postgres_connections_before.txt")
  AFTER=$(cat "${DIR}/postgres_connections_after.txt")

  echo "PostgreSQL connections before: $BEFORE"
  echo "PostgreSQL connections after:  $AFTER"
  echo

  if [ "$FAIL" -ne 0 ]
  then
    echo "WARNING: At least one benchmark runner exited non-zero."
  fi

  echo
  echo "Cooling down for 15 seconds..."
  sleep 15
done

echo
echo "=========================================================="
echo "13-WAY CONTENTION SWEEP COMPLETE"
echo "Results saved under:"
echo "$OUT"
echo "=========================================================="
