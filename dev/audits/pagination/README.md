# GH#13 pagination validation

Validated on 2026-09-19. The live check uses generated single-request wrappers,
not ComptoxR's existing automatic paginator. It reads each environment's current
Swagger contract and calls only the method keyset read endpoints. No credentials
or production requests were used. Raw method records and cursor values are not
stored in this report.

| Check | Result |
|---|---|
| AMOS development, generated GET | Three calls at size two; five retained records with distinct internal IDs; `max_items` stop |
| AMOS development, generated filtered POST | Equality filter on one observed ID; one call, one record; `no_next_cursor` stop |
| AMOS development, ordinary generated GET | One call returned the original `pagination`/`results` envelope with two records |
| AMOS staging | HTTP 503 from both Swagger and a size-two method keyset GET; pagination validation blocked |
| Local page/offset | Empty and short pages, exact boundaries, bounded repetition, item slicing, request/decode/extraction errors, validation |
| Local cursor | AMOS-shaped envelopes, opaque token round-trip, initial/resume token, terminal token, repeated tokens and cycles, finite limits |
| Local next links | Body and HTTP Link-header extraction, relative URLs, repeated links/cycles, finite limits, origin checks and disabled redirects |
| Credential isolation | Authorization and API-key headers reached the intended localhost server; zero requests reached the second server |

Response fields observed on development: `results` and `pagination`, with
`hasNext`, `limit`, and `nextCursor` in `pagination`. The GET cursor is a query
argument; filtered POST places it in a JSON body with fixed filters. The script
fails if the observed shape, uniqueness, or expected stopping conditions change.
AMOS does not establish next-link behavior; those checks use deterministic local
servers, including changes of hostname, port, scheme, and redirects.

The timestamp, schema hash, endpoint, and counts are in
[amos-development.json](amos-development.json). The staging failure is recorded in
[amos-staging.json](amos-staging.json). These are snapshots, not availability guarantees.

Run local acceptance after installing the package:

```sh
Rscript tests/pagination.R
Rscript tests/pagination-cursors.R
```

Opt in to live reads explicitly:

```sh
Rscript dev/verify_amos_pagination.R development
Rscript dev/verify_amos_pagination.R staging
```

The live script fetches one schema, makes one single GET, three paginated GETs,
and one filtered read-only POST. Each attempt has a 20-second timeout and no
configured retries. It never switches environments after a failure.
