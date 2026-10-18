# Production similarity-list contract remains unresolved

Reviewed 18 October 2026 for [Specmill #165](https://github.com/seanthimons/specmill/issues/165)
and [ComptoxR PR345](https://github.com/seanthimons/ComptoxR/pull/345).
This records a source/service dependency, not a generator regression or a service repair.

## Affected contract

- Public wrapper: `chemi_resolver_getsimilaritylist`.
- Operation: `POST /api/resolver/getsimilaritylist`.
- Archived schema: ComptoxR `schema/chemi-resolver-prod.json`.
- Request definition: `#/components/schemas/OrderSimilarityRequest`.
- Fresh production source: `https://hcd.rtpnc.epa.gov/api/resolver/api-docs`.

Both the archived and freshly retrieved OpenAPI 3.1 source declare `chemicals`
(an array of resolved chemicals), `get_chemicals` (an array of chemicals), and
optional `main` (a reference chemical). The fresh source SHA256 and credential-free
request/response evidence are retained in the ComptoxR migration artifacts referenced
by #165. This review performed no additional production requests.

## Observed evidence and limits

| Reviewed request | Observed production result | What it establishes |
| --- | --- | --- |
| Declared `chemicals`, `get_chemicals`, and `main` supplied together | HTTP 500; service reports `OrderSimilarityRequest.get_chemicals()` is null | The declared request does not establish a working production contract |
| Only `get_chemicals` renamed to undocumented `_chemicals`, with `main` | HTTP 200 with `[]`, including a self-reference control | A different response, without proof of correct nonempty similarity behavior |
| Undocumented alias without `main` | Service failure reporting `getMain()` is null | The source's optional reference declaration also needs owner review |

The legacy wrapper's nested resolver results and generic Chemi options do not
establish the intended wire contract either. Native generation can preserve the
received typed HTTP failure while the endpoint itself remains unresolved.
A successful empty response is not accepted as proof of nonempty similarity semantics.

## Retention decision

Keep the existing wrapper retained. Do not adopt `_chemicals`, infer required
reference/target fields, rewrite the archived schema, weaken validation, or patch
the request helper/executor to manufacture a successful migration. Other independently
verified resolver operations can continue migrating.

#165 stays open as the external dependency. This document does not close it.
No positive service result or complete endpoint migration is claimed.

## Evidence needed to resume

1. A service-owned, versioned production-compatible request/response contract,
   including actual JSON property names and required reference/target fields.
2. A positive nonempty reference/target control with its expected result, plus a
   clear meaning for valid empty results.
3. A separately archived source with URL, retrieval date, checksum and reviewed
   changes. Keep the original snapshot intact.
4. Exact offline received-request checks, source validation and generated-client
   freshness checks. Reassess supported mappings against that contract first.

Credential and call-level errors remain hard failures. Simulated credential tests
are not evidence of production credential failures. Upload/write operations are
outside this investigation.
