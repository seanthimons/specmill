# Issue 325: runtime concurrency and promise return

Localhost service, 0.2 s injected latency per request, 24 items, one request per item. Produced by `dev/measure_concurrency.R` with httr2 1.3.0.

The ceiling in YAML is the largest level; the session option lowers it.
The fixture speaks HTTP/1.1, and curl waits on HTTP/2 negotiation before
opening further connections (see tests/testthat/test-parallel-batches.R),
so the low levels gain less here than the latency alone predicts.

| concurrency | fan-out GET (s) | split POST (s) |
|---|---|---|
| 1 | 8.52 | 7.18 |
| 2 | 5.82 | 6.11 |
| 4 | 3.05 | 3.07 |
| 8 | 1.71 | 1.53 |

## Promise return

- A plain call held the session for 0.24 s.
- With the `async` request option on, the reviewed wrapper returned its promise after 0.01 s.
- A `shiny::ExtendedTask` wrapping that wrapper finished with status `success`; a 20 ms timer fired 11 times while it ran.
