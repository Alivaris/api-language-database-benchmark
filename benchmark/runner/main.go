package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

type Result struct {
	Latency time.Duration
	Status  int
	Err     error
}

func percentile(values []time.Duration, p float64) time.Duration {
	if len(values) == 0 {
		return 0
	}

	sorted := make([]time.Duration, len(values))
	copy(sorted, values)

	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i] < sorted[j]
	})

	index := int(float64(len(sorted)-1) * p)

	return sorted[index]
}

func main() {
	url := flag.String(
		"url",
		"http://127.0.0.1:8080/health",
		"URL to benchmark",
	)

	concurrency := flag.Int(
		"concurrency",
		10,
		"number of concurrent workers",
	)

	duration := flag.Duration(
		"duration",
		30*time.Second,
		"benchmark duration",
	)

	timeout := flag.Duration(
		"timeout",
		10*time.Second,
		"HTTP request timeout",
	)

	flag.Parse()

	client := &http.Client{
		Timeout: *timeout,

		Transport: &http.Transport{
			MaxIdleConns:        *concurrency * 2,
			MaxIdleConnsPerHost: *concurrency * 2,
			MaxConnsPerHost:     *concurrency * 2,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	results := make(chan Result, 100000)

	stop := make(chan struct{})

	var wg sync.WaitGroup

	var total uint64
	var errors uint64

	start := time.Now()

	for worker := 0; worker < *concurrency; worker++ {
		wg.Add(1)

		go func() {
			defer wg.Done()

			for {
				select {
				case <-stop:
					return
				default:
				}

				requestStart := time.Now()

				resp, err := client.Get(*url)

				latency := time.Since(requestStart)

				if err != nil {
					atomic.AddUint64(&errors, 1)

					results <- Result{
						Latency: latency,
						Err:     err,
					}

					continue
				}

				_, readErr := io.Copy(io.Discard, resp.Body)
				resp.Body.Close()

				if readErr != nil {
					atomic.AddUint64(&errors, 1)
				}

				if resp.StatusCode < 200 || resp.StatusCode >= 300 {
					atomic.AddUint64(&errors, 1)
				}

				atomic.AddUint64(&total, 1)

				results <- Result{
					Latency: latency,
					Status:  resp.StatusCode,
					Err:     readErr,
				}
			}
		}()
	}

	go func() {
		time.Sleep(*duration)
		close(stop)
	}()

	go func() {
		wg.Wait()
		close(results)
	}()

	latencies := make([]time.Duration, 0, 100000)

	for result := range results {
		latencies = append(
			latencies,
			result.Latency,
		)
	}

	elapsed := time.Since(start)

	requestCount := atomic.LoadUint64(&total)
	errorCount := atomic.LoadUint64(&errors)

	var average time.Duration

	if len(latencies) > 0 {
		var sum time.Duration

		for _, latency := range latencies {
			sum += latency
		}

		average = sum / time.Duration(len(latencies))
	}

	rps := float64(requestCount) / elapsed.Seconds()

	fmt.Println()
	fmt.Println("========================================")
	fmt.Println("API BENCHMARK RESULTS")
	fmt.Println("========================================")
	fmt.Printf("URL:          %s\n", *url)
	fmt.Printf("Concurrency:  %d\n", *concurrency)
	fmt.Printf("Duration:     %s\n", elapsed.Round(time.Millisecond))
	fmt.Printf("Requests:     %d\n", requestCount)
	fmt.Printf("Errors:       %d\n", errorCount)
	fmt.Printf("Requests/sec: %.2f\n", rps)
	fmt.Println()
	fmt.Printf("Average:      %s\n", average)
	fmt.Printf("p50:          %s\n", percentile(latencies, 0.50))
	fmt.Printf("p95:          %s\n", percentile(latencies, 0.95))
	fmt.Printf("p99:          %s\n", percentile(latencies, 0.99))
	fmt.Printf("Max:          %s\n", percentile(latencies, 1.00))
	fmt.Println("========================================")
}
