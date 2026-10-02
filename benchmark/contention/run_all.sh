#!/usr/bin/env bash

set -u

NETWORK="api_benchmark_network"
IMAGE="api-benchmark-runner"
OUT="benchmark/results/contention_13"

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

run_level() {
  local CONCURRENCY="$1"
  local DURATION="$2"
  local DIR="${OUT}/c${CONCURRENCY}"

  mkdir -p "$DIR"

  echo
  echo "================================================="
  echo "13-WAY CONTENTION - CONCURRENCY ${CONCURRENCY} EACH"
  echo "TOTAL HTTP CLIENTS: $((CONCURRENCY * 13))"
  echo "================================================="

  PIDS=()

  for LANG in "${LANGS[@]}"
  do
    (
      docker run --rm \
        --network "$NETWORK" \
        "$IMAGE" \
        -url "${URLS[$LANG]}" \
        -concurrency "$CONCURRENCY" \
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
  echo "Completed concurrency ${CONCURRENCY}."
  echo

  for LANG in "${LANGS[@]}"
  do
    echo "---------- ${LANG^^} ----------"
    grep -E \
      'Requests:|Errors:|Requests/sec:|Average:|p50:|p95:|p99:|Max:' \
      "${DIR}/${LANG}.txt" || true
    echo
  done

  return "$FAIL"
}

if [ "$#" -ne 2 ]
then
  echo "Usage: $0 <concurrency-per-language> <duration-seconds>"
  exit 1
fi

run_level "$1" "$2"
